// =============================================================================
// FILE: lib/features/asset_inventory/presentation/dialogs/asset_report_filter_dialog.dart
// =============================================================================

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../../../core/constants/colors.dart';
import '../../models/asset_model.dart';
import '../../services/asset_report_pdf_service.dart';

enum AssetReportFormat { photographicCards, ledgerTable }

void showAssetReportFilterModal(
    BuildContext context, {
      required List<AssetModel> allAssets,
    }) {
  showDialog(
    context: context,
    builder: (ctx) => _AssetReportFilterDialog(allAssets: allAssets),
  );
}

class _AssetReportFilterDialog extends StatefulWidget {
  final List<AssetModel> allAssets;

  const _AssetReportFilterDialog({super.key, required this.allAssets});

  @override
  State<_AssetReportFilterDialog> createState() =>
      _AssetReportFilterDialogState();
}

class _AssetReportFilterDialogState extends State<_AssetReportFilterDialog> {
  AssetReportFormat _selectedFormat = AssetReportFormat.photographicCards;
  String _selectedSection = 'All'; // 'All', 'Section 1', 'Section 2'
  String _dateScope = 'All Dates'; // 'All Dates', 'Custom Range'

  DateTimeRange? _selectedDateRange;
  String _dateFieldToFilter =
      'Acquisition Date'; // 'Acquisition Date' or 'Registration Date'

  bool _includeArchived = false;
  bool _isGenerating = false;
  String _activeOperation = ''; // 'printing', 'previewing', 'downloading'

  final List<String> _sectionOptions = [
    'All',
    'Section 1 (≥ ₱10,000.00)',
    'Section 2 (< ₱10,000.00)',
  ];

  List<AssetModel> get _filteredAssets {
    var list = widget.allAssets;

    // 1. Archive filter
    if (!_includeArchived) {
      list = list.where((a) => !a.isEffectivelyArchived).toList();
    }

    // 2. Section filter
    if (_selectedSection.contains('Section 1')) {
      list = list.where((a) => a.unitPrice >= 10000.0).toList();
    } else if (_selectedSection.contains('Section 2')) {
      list = list.where((a) => a.unitPrice < 10000.0).toList();
    }

    // 3. Date range filter with null-safe handling for acquisition dates
    if (_dateScope == 'Custom Range' && _selectedDateRange != null) {
      final start = DateTime(
        _selectedDateRange!.start.year,
        _selectedDateRange!.start.month,
        _selectedDateRange!.start.day,
      );
      final end = DateTime(
        _selectedDateRange!.end.year,
        _selectedDateRange!.end.month,
        _selectedDateRange!.end.day,
        23,
        59,
        59,
      );

      list = list.where((a) {
        if (_dateFieldToFilter == 'Acquisition Date') {
          if (a.dateOfAcquisition != null) {
            final targetDate = a.dateOfAcquisition!;
            return targetDate.isAfter(start.subtract(const Duration(seconds: 1))) &&
                targetDate.isBefore(end.add(const Duration(seconds: 1)));
          } else {
            // When only acquisition year is known, check if it falls within the year span
            return a.acquisitionYear >= start.year && a.acquisitionYear <= end.year;
          }
        } else {
          final targetDate = a.registrationDate;
          return targetDate.isAfter(start.subtract(const Duration(seconds: 1))) &&
              targetDate.isBefore(end.add(const Duration(seconds: 1)));
        }
      }).toList();
    }

    // Sort by control number
    list.sort((a, b) => a.controlNumber.compareTo(b.controlNumber));
    return list;
  }

  double get _totalValuation {
    return _filteredAssets.fold<double>(0.0, (sum, a) => sum + a.totalCost);
  }

  Future<void> _pickCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 365)),
            end: DateTime.now(),
          ),
      firstDate: DateTime(1900),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: ParishColors.marianBlue,
              onPrimary: Colors.white,
              onSurface: ParishColors.textDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
        _dateScope = 'Custom Range';
      });
    }
  }

  String _buildDateRangeLabel() {
    if (_dateScope == 'Custom Range' && _selectedDateRange != null) {
      final startStr =
          '${_selectedDateRange!.start.year}-${_selectedDateRange!.start.month.toString().padLeft(2, '0')}-${_selectedDateRange!.start.day.toString().padLeft(2, '0')}';
      final endStr =
          '${_selectedDateRange!.end.year}-${_selectedDateRange!.end.month.toString().padLeft(2, '0')}-${_selectedDateRange!.end.day.toString().padLeft(2, '0')}';
      return '$startStr to $endStr ($_dateFieldToFilter)';
    }
    return 'All Registered Dates';
  }

  String _buildSectionLabel() {
    return _selectedSection == 'All'
        ? 'All Book of Inventory Sections'
        : _selectedSection;
  }

  String _generateFileName() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return _selectedFormat == AssetReportFormat.photographicCards
        ? 'Photographic_Inventory_$timestamp.pdf'
        : 'Inventory_Listing_$timestamp.pdf';
  }

  Future<Uint8List?> _buildPdfBytes() async {
    final targets = _filteredAssets;
    if (targets.isEmpty) return null;

    final dateRangeLabel = _buildDateRangeLabel();
    final sectionLabel = _buildSectionLabel();

    if (_selectedFormat == AssetReportFormat.photographicCards) {
      return await AssetReportPdfService.generatePhotographicReportPdf(
        targets,
        dateRangeLabel: dateRangeLabel,
        sectionLabel: sectionLabel,
      );
    } else {
      return await AssetReportPdfService.generateTableReportPdf(
        targets,
        dateRangeLabel: dateRangeLabel,
        sectionLabel: sectionLabel,
      );
    }
  }

  // ===========================================================================
  // 1. Direct Print Action
  // ===========================================================================

  Future<void> _handlePrintReport() async {
    final targets = _filteredAssets;
    if (targets.isEmpty) {
      _showEmptySnackBar();
      return;
    }

    setState(() {
      _isGenerating = true;
      _activeOperation = 'printing';
    });

    try {
      final dateRangeLabel = _buildDateRangeLabel();
      final sectionLabel = _buildSectionLabel();

      if (_selectedFormat == AssetReportFormat.photographicCards) {
        await AssetReportPdfService.printPhotographicReport(
          targets,
          dateRangeLabel: dateRangeLabel,
          sectionLabel: sectionLabel,
        );
      } else {
        await AssetReportPdfService.printTableReport(
          targets,
          dateRangeLabel: dateRangeLabel,
          sectionLabel: sectionLabel,
        );
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isGenerating = false);
      _showErrorSnackBar('Report printing failed: $e');
    }
  }

  // ===========================================================================
  // 2. Interactive In-App PDF Preview Action (Fast, Clean, No Toolbar)
  // ===========================================================================

  Future<void> _handlePreviewPdf() async {
    final targets = _filteredAssets;
    if (targets.isEmpty) {
      _showEmptySnackBar();
      return;
    }

    setState(() {
      _isGenerating = true;
      _activeOperation = 'previewing';
    });

    try {
      final pdfBytes = await _buildPdfBytes();
      if (!mounted) return;
      setState(() => _isGenerating = false);

      if (pdfBytes == null) {
        _showEmptySnackBar();
        return;
      }

      final fileName = _generateFileName();
      final previewTitle = _selectedFormat == AssetReportFormat.photographicCards
          ? 'Photographic Evidence Preview'
          : 'Property & Inventory Listing Preview';

      showDialog(
        context: context,
        builder: (ctx) {
          final isScreenMobile = MediaQuery.of(ctx).size.width < 650;

          return Dialog(
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            insetPadding: EdgeInsets.symmetric(
              horizontal: isScreenMobile ? 8 : 24,
              vertical: isScreenMobile ? 12 : 24,
            ),
            backgroundColor: Colors.white,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 980,
                height: 820,
                child: Scaffold(
                  backgroundColor: Colors.white,
                  appBar: AppBar(
                    backgroundColor: ParishColors.marianBlueSurface,
                    elevation: 0,
                    leading: const Icon(
                      Icons.picture_as_pdf,
                      color: ParishColors.marianBlue,
                    ),
                    title: Text(
                      previewTitle,
                      style: TextStyle(
                        color: ParishColors.textDark,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    actions: [
                      IconButton(
                        icon: Icon(Icons.close, color: ParishColors.textDark),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                  body: PdfPreview(
                    build: (format) async => pdfBytes,
                    useActions: false,
                    canChangeOrientation: false,
                    canChangePageFormat: false,
                    canDebug: false,
                    dynamicLayout: false,
                    enableScrollToPage: true,
                    pdfFileName: fileName,
                    loadingWidget: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isGenerating = false);
      _showErrorSnackBar('Preview generation failed: $e');
    }
  }

  // ===========================================================================
  // 3. Direct PDF Download / Share Action
  // ===========================================================================

  Future<void> _handleDownloadPdf() async {
    final targets = _filteredAssets;
    if (targets.isEmpty) {
      _showEmptySnackBar();
      return;
    }

    setState(() {
      _isGenerating = true;
      _activeOperation = 'downloading';
    });

    try {
      final pdfBytes = await _buildPdfBytes();
      if (!mounted) return;
      setState(() => _isGenerating = false);

      if (pdfBytes == null) {
        _showEmptySnackBar();
        return;
      }

      final fileName = _generateFileName();
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: fileName,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Document ready for download: $fileName'),
          backgroundColor: ParishColors.oliveGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isGenerating = false);
      _showErrorSnackBar('Download failed: $e');
    }
  }

  void _showEmptySnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content:
        Text('No assets match the selected criteria to generate a report.'),
        backgroundColor: ParishColors.goldAccent,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: ParishColors.mercyRed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final borderGrey = ParishColors.borderGrey;
    final filtered = _filteredAssets;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 650;

        return Dialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: ParishColors.cardWhite,
          insetPadding: EdgeInsets.symmetric(
            horizontal: isMobile ? 12 : 24,
            vertical: isMobile ? 14 : 24,
          ),
          child: Container(
            width: 720,
            constraints: const BoxConstraints(maxHeight: 760),
            child: Column(
              children: [
                // Header Banner
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 16 : 22,
                    vertical: isMobile ? 12 : 16,
                  ),
                  decoration: BoxDecoration(
                    color: ParishColors.marianBlueSurface,
                    borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                    border: Border(bottom: BorderSide(color: borderGrey)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: ParishColors.marianBlue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.picture_as_pdf_outlined,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Generate Inventory Reports',
                              style: TextStyle(
                                fontSize: isMobile ? 16 : 18,
                                fontWeight: FontWeight.bold,
                                color: textDark,
                              ),
                            ),
                            Text(
                              'Preview, download, or print photographic evidence cards and 13-column ledgers',
                              style: TextStyle(
                                  fontSize: isMobile ? 11 : 12,
                                  color: textMuted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed:
                        _isGenerating ? null : () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // Form Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isMobile ? 14 : 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Choose Report Format
                        Text(
                          '1. Select Report Format *',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: textDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildFormatSelectorCard(
                                title: 'Photographic Cards',
                                subtitle:
                                '2 items per A4 page • Photos & specifications form',
                                icon: Icons.photo_library_outlined,
                                isSelected: _selectedFormat ==
                                    AssetReportFormat.photographicCards,
                                onTap: () => setState(
                                      () => _selectedFormat =
                                      AssetReportFormat.photographicCards,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildFormatSelectorCard(
                                title: 'Tabular Ledger',
                                subtitle:
                                '13 columns • A4 Landscape with location & inventory dates',
                                icon: Icons.table_chart_outlined,
                                isSelected: _selectedFormat ==
                                    AssetReportFormat.ledgerTable,
                                onTap: () => setState(
                                      () => _selectedFormat =
                                      AssetReportFormat.ledgerTable,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // 2. Book of Inventory Section Scope
                        Text(
                          '2. Book of Inventory Section *',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: textDark,
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _selectedSection,
                          isExpanded: true,
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            filled: true,
                            fillColor: ParishColors.backgroundLight,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: borderGrey),
                            ),
                          ),
                          items: _sectionOptions.map((sec) {
                            return DropdownMenuItem(
                              value: sec,
                              child: Text(sec,
                                  style:
                                  TextStyle(fontSize: 13, color: textDark)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedSection = val);
                            }
                          },
                        ),
                        const SizedBox(height: 18),

                        // 3. Date Range Scope
                        Text(
                          '3. Date Range Filtering',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: textDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('All Registered Items'),
                              selected: _dateScope == 'All Dates',
                              selectedColor: ParishColors.marianBlue,
                              labelStyle: TextStyle(
                                color: _dateScope == 'All Dates'
                                    ? Colors.white
                                    : textDark,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              onSelected: (_) =>
                                  setState(() => _dateScope = 'All Dates'),
                            ),
                            ChoiceChip(
                              label: Text(
                                _selectedDateRange == null
                                    ? 'Pick Custom Date Range'
                                    : '${_selectedDateRange!.start.month}/${_selectedDateRange!.start.day}/${_selectedDateRange!.start.year} - ${_selectedDateRange!.end.month}/${_selectedDateRange!.end.day}/${_selectedDateRange!.end.year}',
                              ),
                              selected: _dateScope == 'Custom Range',
                              selectedColor: ParishColors.marianBlue,
                              labelStyle: TextStyle(
                                color: _dateScope == 'Custom Range'
                                    ? Colors.white
                                    : textDark,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              onSelected: (_) => _pickCustomDateRange(),
                            ),
                          ],
                        ),

                        if (_dateScope == 'Custom Range') ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Text(
                                'Filter by: ',
                                style:
                                TextStyle(fontSize: 12, color: textMuted),
                              ),
                              const SizedBox(width: 6),
                              DropdownButton<String>(
                                value: _dateFieldToFilter,
                                isDense: true,
                                underline: const SizedBox.shrink(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: ParishColors.marianBlue,
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'Acquisition Date',
                                    child: Text('Acquisition Date'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Registration Date',
                                    child: Text('Registration Date'),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _dateFieldToFilter = val);
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 16),

                        // 4. Archive Toggle
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          activeColor: ParishColors.oliveGreen,
                          title: Text(
                            'Include Decommissioned / Retired Items',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: textDark,
                            ),
                          ),
                          subtitle: Text(
                            'Append assets that have been officially retired or disposed',
                            style: TextStyle(fontSize: 11, color: textMuted),
                          ),
                          value: _includeArchived,
                          onChanged: (val) =>
                              setState(() => _includeArchived = val),
                        ),
                        const SizedBox(height: 16),

                        // Preview Summary Box
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: ParishColors.oliveGreenSurface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: ParishColors.oliveGreen.withOpacity(0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Matching Assets for Report',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: ParishColors.oliveGreen,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${filtered.length} item line(s) selected',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                      color: textDark,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    'Total Valuation',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: ParishColors.oliveGreen,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '₱ ${AssetModel.formatCurrency(_totalValuation)}',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: ParishColors.oliveGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Multi-Action Responsive Footer
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 14 : 22,
                    vertical: isMobile ? 12 : 14,
                  ),
                  decoration: BoxDecoration(
                    color: ParishColors.cardWhite,
                    borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(20)),
                    border: Border(top: BorderSide(color: borderGrey)),
                  ),
                  child: isMobile
                      ? _buildMobileFooter(filtered.length)
                      : _buildDesktopFooter(filtered.length, textMuted),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // Responsive Desktop & Mobile Footers
  // ===========================================================================

  Widget _buildDesktopFooter(int itemCount, Color textMuted) {
    final bool canProceed = !_isGenerating && itemCount > 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton(
          onPressed: _isGenerating ? null : () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: textMuted)),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Preview Button
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: ParishColors.marianBlue,
                side: const BorderSide(color: ParishColors.marianBlue),
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: canProceed ? _handlePreviewPdf : null,
              icon: (_isGenerating && _activeOperation == 'previewing')
                  ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.visibility_outlined, size: 17),
              label: const Text('Preview PDF',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            const SizedBox(width: 8),

            // Download Button
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: ParishColors.oliveGreen,
                side: const BorderSide(color: ParishColors.oliveGreen),
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: canProceed ? _handleDownloadPdf : null,
              icon: (_isGenerating && _activeOperation == 'downloading')
                  ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: ParishColors.oliveGreen,
                ),
              )
                  : const Icon(Icons.download_outlined, size: 17),
              label: const Text('Download PDF',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            const SizedBox(width: 8),

            // Print Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: ParishColors.marianBlue,
                foregroundColor: Colors.white,
                padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: canProceed ? _handlePrintReport : null,
              icon: (_isGenerating && _activeOperation == 'printing')
                  ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
                  : const Icon(Icons.print, size: 17),
              label: Text(
                _isGenerating && _activeOperation == 'printing'
                    ? 'Preparing...'
                    : 'Print ($itemCount)',
                style:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMobileFooter(int itemCount) {
    final bool canProceed = !_isGenerating && itemCount > 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: ParishColors.marianBlue,
                  side: const BorderSide(color: ParishColors.marianBlue),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: canProceed ? _handlePreviewPdf : null,
                icon: (_isGenerating && _activeOperation == 'previewing')
                    ? const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.visibility_outlined, size: 15),
                label: const Text('Preview',
                    style:
                    TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: ParishColors.oliveGreen,
                  side: const BorderSide(color: ParishColors.oliveGreen),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: canProceed ? _handleDownloadPdf : null,
                icon: (_isGenerating && _activeOperation == 'downloading')
                    ? const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: ParishColors.oliveGreen,
                  ),
                )
                    : const Icon(Icons.download_outlined, size: 15),
                label: const Text('Download',
                    style:
                    TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton(
              onPressed: _isGenerating ? null : () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(fontSize: 12)),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ParishColors.marianBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: canProceed ? _handlePrintReport : null,
                icon: (_isGenerating && _activeOperation == 'printing')
                    ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(Icons.print, size: 16),
                label: Text(
                  _isGenerating && _activeOperation == 'printing'
                      ? 'Building...'
                      : 'Print ($itemCount Items)',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12.5),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFormatSelectorCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? ParishColors.marianBlueSurface
              : ParishColors.backgroundLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
            isSelected ? ParishColors.marianBlue : ParishColors.borderGrey,
            width: isSelected ? 1.6 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: isSelected
                      ? ParishColors.marianBlue
                      : ParishColors.textMuted,
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_circle,
                    size: 16,
                    color: ParishColors.marianBlue,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? ParishColors.marianBlue
                    : ParishColors.textDark,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 10.5, color: ParishColors.textMuted),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}