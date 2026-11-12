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

/// Opens the Report Generator as a full page.
/// Preserved as a top-level helper for backward compatibility across the app.
void showAssetReportFilterModal(
    BuildContext context, {
      required List<AssetModel> allAssets,
    }) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => AssetReportFilterPage(allAssets: allAssets),
    ),
  );
}

class AssetReportFilterPage extends StatefulWidget {
  final List<AssetModel> allAssets;

  const AssetReportFilterPage({super.key, required this.allAssets});

  @override
  State<AssetReportFilterPage> createState() => _AssetReportFilterPageState();
}

class _AssetReportFilterPageState extends State<AssetReportFilterPage> {
  AssetReportFormat _selectedFormat = AssetReportFormat.photographicCards;
  String _selectedSection = 'All';
  String _dateScope = 'All Dates';

  DateTimeRange? _selectedDateRange;
  String _dateFieldToFilter = 'Acquisition Date';

  bool _includeArchived = false;
  bool _isGenerating = false;
  String _activeOperation = '';

  // Progress Monitor State
  String _progressMessage = 'Preparing your report...';
  AssetReportProgress? _reportProgress;

  // Individual item inclusion / exclusion state
  final Set<String> _selectedAssetIds = {};
  final TextEditingController _itemSearchController = TextEditingController();
  String _itemSearchQuery = '';
  int _itemPickerTab = 0; // 0 = Scope Filtered, 1 = All Assets, 2 = Selected Only

  // PDF Document Cache
  Uint8List? _cachedPdfBytes;
  String? _cachedPdfKey;

  final List<String> _sectionOptions = [
    'All',
    'Section 1 (≥ ₱10,000.00)',
    'Section 2 (< ₱10,000.00)',
  ];

  @override
  void initState() {
    super.initState();
    _syncSelectedIdsWithScope();
  }

  @override
  void dispose() {
    _itemSearchController.dispose();
    super.dispose();
  }

  void _invalidatePdfCache() {
    _cachedPdfBytes = null;
    _cachedPdfKey = null;
  }

  /// Synchronizes selected asset IDs with the active section/date scope.
  void _syncSelectedIdsWithScope() {
    final scopeAssets = _scopeFilteredAssets;
    _selectedAssetIds.clear();
    _selectedAssetIds.addAll(scopeAssets.map((a) => a.assetId));
    _invalidatePdfCache();
  }

  /// Candidates matching the Section, Date Range, and Archive toggles.
  List<AssetModel> get _scopeFilteredAssets {
    var list = widget.allAssets;

    if (!_includeArchived) {
      list = list.where((a) => !a.isEffectivelyArchived).toList();
    }

    if (_selectedSection.contains('Section 1')) {
      list = list.where((a) => a.unitPrice >= 10000.0).toList();
    } else if (_selectedSection.contains('Section 2')) {
      list = list.where((a) => a.unitPrice < 10000.0).toList();
    }

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
            return targetDate.isAfter(
                start.subtract(const Duration(seconds: 1))) &&
                targetDate.isBefore(end.add(const Duration(seconds: 1)));
          } else {
            return a.acquisitionYear >= start.year &&
                a.acquisitionYear <= end.year;
          }
        } else {
          final targetDate = a.registrationDate;
          return targetDate.isAfter(
              start.subtract(const Duration(seconds: 1))) &&
              targetDate.isBefore(end.add(const Duration(seconds: 1)));
        }
      }).toList();
    }

    return list;
  }

  /// All eligible assets that can be browsed / searched.
  List<AssetModel> get _allEligibleAssets {
    var list = widget.allAssets;

    if (!_includeArchived) {
      list = list.where((a) => !a.isEffectivelyArchived).toList();
    }

    return list;
  }

  /// The final list of assets explicitly selected by the user.
  List<AssetModel> get _selectedAssetsForReport {
    return widget.allAssets
        .where((a) => _selectedAssetIds.contains(a.assetId))
        .toList();
  }

  /// Filtered items displayed in the item picker.
  List<AssetModel> get _displayedPickerAssets {
    List<AssetModel> source;

    if (_itemPickerTab == 0) {
      source = _scopeFilteredAssets;
    } else if (_itemPickerTab == 1) {
      source = _allEligibleAssets;
    } else {
      source = _selectedAssetsForReport;
    }

    if (_itemSearchQuery.trim().isEmpty) return source;

    final q = _itemSearchQuery.toLowerCase().trim();

    return source.where((a) {
      return a.controlNumber.toLowerCase().contains(q) ||
          a.itemName.toLowerCase().contains(q) ||
          a.displayLocation.toLowerCase().contains(q) ||
          a.displayClassification.toLowerCase().contains(q) ||
          (a.model ?? '').toLowerCase().contains(q) ||
          (a.others ?? '').toLowerCase().contains(q);
    }).toList();
  }

  double get _totalValuation {
    return _selectedAssetsForReport.fold<double>(
      0.0,
          (sum, a) => sum + a.totalCost,
    );
  }

  // ===========================================================================
  // PROGRESS MONITOR
  // ===========================================================================

  double _overallProgress(AssetReportProgress progress) {
    final stageProgress = progress.total <= 0
        ? 0.0
        : (progress.completed / progress.total).clamp(0.0, 1.0).toDouble();

    switch (progress.stage) {
      case AssetReportProgressStage.preparing:
        return 0.05 * stageProgress;
      case AssetReportProgressStage.downloadingImages:
        return 0.05 + (0.20 * stageProgress);
      case AssetReportProgressStage.optimizingImages:
        return 0.25 + (0.25 * stageProgress);
      case AssetReportProgressStage.generatingPdf:
        return 0.50 + (0.45 * stageProgress);
      case AssetReportProgressStage.completed:
        return 1.0;
    }
  }

  String _progressDetail(AssetReportProgress progress) {
    if (progress.stage == AssetReportProgressStage.generatingPdf &&
        progress.totalPages > 0) {
      return 'Page ${progress.currentPage} of ${progress.totalPages}';
    }

    if (progress.total > 0) {
      return '${progress.completed} of ${progress.total} completed';
    }

    return '${_selectedAssetsForReport.length} asset(s) included in this report';
  }

  void _handleReportProgress(AssetReportProgress progress) {
    if (!mounted) return;

    setState(() {
      _reportProgress = progress;
      _progressMessage = progress.stageLabel;
    });
  }

  Widget _buildProgressMonitor(bool isMobile) {
    final operationIcon = _activeOperation == 'printing'
        ? Icons.print_outlined
        : _activeOperation == 'previewing'
        ? Icons.visibility_outlined
        : Icons.download_outlined;

    final operationColor = _activeOperation == 'downloading'
        ? ParishColors.oliveGreen
        : ParishColors.marianBlue;

    final selectedCount = _selectedAssetsForReport.length;
    final progress = _reportProgress;
    final overallProgress =
    progress == null ? null : _overallProgress(progress);
    final percentage = overallProgress == null
        ? null
        : (overallProgress * 100).round();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: ParishColors.marianBlueSurface.withOpacity(0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ParishColors.marianBlue.withOpacity(0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                operationIcon,
                color: operationColor,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _progressMessage,
                      style: TextStyle(
                        fontSize: isMobile ? 12.5 : 13.5,
                        fontWeight: FontWeight.bold,
                        color: ParishColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      progress == null
                          ? '$selectedCount asset(s) included in this report'
                          : _progressDetail(progress),
                      style: TextStyle(
                        fontSize: isMobile ? 10.5 : 11.5,
                        color: ParishColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (percentage != null)
                Text(
                  '$percentage%',
                  style: TextStyle(
                    fontSize: isMobile ? 12.5 : 14,
                    fontWeight: FontWeight.bold,
                    color: operationColor,
                  ),
                )
              else
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: operationColor,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: overallProgress,
              minHeight: 6,
              backgroundColor: Colors.white,
              color: operationColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            progress?.stage == AssetReportProgressStage.generatingPdf &&
                progress!.currentPage >= progress.totalPages &&
                progress.totalPages > 0
                ? 'Finalizing the PDF document. Please wait...'
                : 'Processing documents and images. Please avoid closing this page.',
            style: TextStyle(
              fontSize: isMobile ? 10 : 11,
              color: ParishColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  void _startProgress(String operation) {
    setState(() {
      _isGenerating = true;
      _activeOperation = operation;
      _reportProgress = null;

      switch (operation) {
        case 'printing':
          _progressMessage = 'Preparing report for printing...';
          break;
        case 'previewing':
          _progressMessage = 'Generating PDF preview...';
          break;
        case 'downloading':
          _progressMessage = 'Preparing PDF for download...';
          break;
        default:
          _progressMessage = 'Preparing your report...';
      }
    });
  }

  void _finishProgress() {
    if (!mounted) return;

    setState(() {
      _isGenerating = false;
      _activeOperation = '';
      _progressMessage = '';
      _reportProgress = null;
    });
  }

  // ===========================================================================
  // Date Range
  // ===========================================================================

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
        _syncSelectedIdsWithScope();
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

  String _computeCacheKey(List<AssetModel> targets) {
    final sortedIds = targets.map((a) => a.assetId).toList()..sort();

    return '${_selectedFormat.name}|$_selectedSection|$_dateScope|'
        '${_selectedDateRange?.start.millisecondsSinceEpoch}|'
        '${_selectedDateRange?.end.millisecondsSinceEpoch}|'
        '$_dateFieldToFilter|$_includeArchived|${targets.length}|'
        '${sortedIds.join(",")}';
  }

  Future<Uint8List?> _buildPdfBytes() async {
    final targets = _selectedAssetsForReport;

    if (targets.isEmpty) return null;

    final currentKey = _computeCacheKey(targets);

    if (_cachedPdfBytes != null && _cachedPdfKey == currentKey) {
      return _cachedPdfBytes;
    }

    await Future.delayed(const Duration(milliseconds: 16));

    final dateRangeLabel = _buildDateRangeLabel();
    final sectionLabel = _buildSectionLabel();

    Uint8List result;

    if (_selectedFormat == AssetReportFormat.photographicCards) {
      result = await AssetReportPdfService.generatePhotographicReportPdf(
        targets,
        dateRangeLabel: dateRangeLabel,
        sectionLabel: sectionLabel,
        onProgress: _handleReportProgress,
      );
    } else {
      result = await AssetReportPdfService.generateTableReportPdf(
        targets,
        dateRangeLabel: dateRangeLabel,
        sectionLabel: sectionLabel,
        onProgress: _handleReportProgress,
      );
    }

    _cachedPdfBytes = result;
    _cachedPdfKey = currentKey;

    return result;
  }

  // ===========================================================================
  // 1. Direct Print Action
  // ===========================================================================

  Future<void> _handlePrintReport() async {
    final targets = _selectedAssetsForReport;

    if (targets.isEmpty) {
      _showEmptySnackBar();
      return;
    }

    _startProgress('printing');

    try {
      final pdfBytes = await _buildPdfBytes();

      if (!mounted) return;

      _finishProgress();

      if (pdfBytes == null) {
        _showEmptySnackBar();
        return;
      }

      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: _generateFileName(),
      );
    } catch (e) {
      if (!mounted) return;

      _finishProgress();
      _showErrorSnackBar('Report printing failed: $e');
    }
  }

  // ===========================================================================
  // 2. Interactive In-App PDF Preview
  // ===========================================================================

  Future<void> _handlePreviewPdf() async {
    final targets = _selectedAssetsForReport;

    if (targets.isEmpty) {
      _showEmptySnackBar();
      return;
    }

    _startProgress('previewing');

    try {
      final pdfBytes = await _buildPdfBytes();

      if (!mounted) return;

      _finishProgress();

      if (pdfBytes == null) {
        _showEmptySnackBar();
        return;
      }

      final fileName = _generateFileName();

      final previewTitle =
      _selectedFormat == AssetReportFormat.photographicCards
          ? 'Photographic Evidence Preview'
          : 'Property & Inventory Listing Preview';

      showDialog(
        context: context,
        builder: (ctx) {
          final isScreenMobile = MediaQuery.of(ctx).size.width < 650;

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
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
                        icon: const Icon(
                          Icons.print,
                          color: ParishColors.marianBlue,
                        ),
                        tooltip: 'Print Now',
                        onPressed: () => Printing.layoutPdf(
                          onLayout: (format) async => pdfBytes,
                          name: fileName,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.download,
                          color: ParishColors.oliveGreen,
                        ),
                        tooltip: 'Download PDF',
                        onPressed: () => Printing.sharePdf(
                          bytes: pdfBytes,
                          filename: fileName,
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          color: ParishColors.textDark,
                        ),
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
                    dpi: 140,
                    maxPageWidth: 720,
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

      _finishProgress();
      _showErrorSnackBar('Preview generation failed: $e');
    }
  }

  // ===========================================================================
  // 3. Direct PDF Download / Share Action
  // ===========================================================================

  Future<void> _handleDownloadPdf() async {
    final targets = _selectedAssetsForReport;

    if (targets.isEmpty) {
      _showEmptySnackBar();
      return;
    }

    _startProgress('downloading');

    try {
      final pdfBytes = await _buildPdfBytes();

      if (!mounted) return;

      _finishProgress();

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

      _finishProgress();
      _showErrorSnackBar('Download failed: $e');
    }
  }

  void _showEmptySnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Please select at least 1 item to include in the report.',
        ),
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

  // ===========================================================================
  // Selection Toggling Helpers
  // ===========================================================================

  void _toggleAssetSelection(String assetId) {
    setState(() {
      if (_selectedAssetIds.contains(assetId)) {
        _selectedAssetIds.remove(assetId);
      } else {
        _selectedAssetIds.add(assetId);
      }

      _invalidatePdfCache();
    });
  }

  void _selectAllDisplayed() {
    setState(() {
      for (final a in _displayedPickerAssets) {
        _selectedAssetIds.add(a.assetId);
      }

      _invalidatePdfCache();
    });
  }

  void _deselectAllDisplayed() {
    setState(() {
      for (final a in _displayedPickerAssets) {
        _selectedAssetIds.remove(a.assetId);
      }

      _invalidatePdfCache();
    });
  }

  // ===========================================================================
  // Main Build: Full-Page Layout
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final cardWhite = ParishColors.cardWhite;
    final borderGrey = ParishColors.borderGrey;
    final selectedCount = _selectedAssetsForReport.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double screenWidth = constraints.maxWidth;
        final bool isMobile = screenWidth < 680;

        return Scaffold(
          backgroundColor: ParishColors.backgroundLight,
          appBar: AppBar(
            backgroundColor: cardWhite,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: ParishColors.marianBlue),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Generate Inventory Reports',
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.bold,
                    color: textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Photographic evidence cards & 20-row diocesan ledger with custom item selection',
                  style: TextStyle(
                    fontSize: isMobile ? 10.5 : 12,
                    color: textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1.0),
              child: Divider(height: 1, color: borderGrey.withOpacity(0.5)),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 14 : 24,
                vertical: isMobile ? 14 : 22,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Choose Report Format
                      _buildSectionHeader(
                        title: '1. Select Report Format *',
                        textDark: textDark,
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
                              onTap: () {
                                if (_selectedFormat !=
                                    AssetReportFormat.photographicCards) {
                                  setState(() {
                                    _selectedFormat =
                                        AssetReportFormat.photographicCards;
                                    _invalidatePdfCache();
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildFormatSelectorCard(
                              title: 'Tabular Ledger',
                              subtitle:
                              '20 entries per A4 Landscape • Arranged by Control # suffix',
                              icon: Icons.table_chart_outlined,
                              isSelected: _selectedFormat ==
                                  AssetReportFormat.ledgerTable,
                              onTap: () {
                                if (_selectedFormat !=
                                    AssetReportFormat.ledgerTable) {
                                  setState(() {
                                    _selectedFormat =
                                        AssetReportFormat.ledgerTable;
                                    _invalidatePdfCache();
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // 2. Book of Inventory Section Scope & Filtering
                      _buildSectionHeader(
                        title: '2. Book of Inventory Scope & Date Filters',
                        textDark: textDark,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: EdgeInsets.all(isMobile ? 14 : 18),
                        decoration: BoxDecoration(
                          color: cardWhite,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderGrey),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Book of Inventory Section',
                              style: TextStyle(
                                fontSize: 13,
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
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                filled: true,
                                fillColor: ParishColors.backgroundLight,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: borderGrey),
                                ),
                              ),
                              items: _sectionOptions.map((sec) {
                                return DropdownMenuItem(
                                  value: sec,
                                  child: Text(
                                    sec,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: textDark,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: _isGenerating
                                  ? null
                                  : (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedSection = val;
                                    _syncSelectedIdsWithScope();
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Date Scope',
                              style: TextStyle(
                                fontSize: 13,
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
                                  onSelected: _isGenerating
                                      ? null
                                      : (_) => setState(() {
                                    _dateScope = 'All Dates';
                                    _syncSelectedIdsWithScope();
                                  }),
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
                                  onSelected: _isGenerating
                                      ? null
                                      : (_) => _pickCustomDateRange(),
                                ),
                              ],
                            ),

                            if (_dateScope == 'Custom Range') ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Text(
                                    'Filter by: ',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: textMuted,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  DropdownButton<String>(
                                    value: _dateFieldToFilter,
                                    isDense: true,
                                    underline: const SizedBox.shrink(),
                                    style: const TextStyle(
                                      fontSize: 12.5,
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
                                    onChanged: _isGenerating
                                        ? null
                                        : (val) {
                                      if (val != null) {
                                        setState(() {
                                          _dateFieldToFilter = val;
                                          _syncSelectedIdsWithScope();
                                        });
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 12),
                            const Divider(height: 18),
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
                                style: TextStyle(
                                  fontSize: 11,
                                  color: textMuted,
                                ),
                              ),
                              value: _includeArchived,
                              onChanged: _isGenerating
                                  ? null
                                  : (val) => setState(() {
                                _includeArchived = val;
                                _syncSelectedIdsWithScope();
                              }),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 3. Individual Item Selection Checklist
                      _buildIndividualItemPickerSection(
                        isMobile,
                        borderGrey,
                        cardWhite,
                        textDark,
                        textMuted,
                      ),
                      const SizedBox(height: 20),

                      // 4. Selected Summary Box
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: selectedCount > 0
                              ? ParishColors.oliveGreenSurface
                              : const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selectedCount > 0
                                ? ParishColors.oliveGreen.withOpacity(0.4)
                                : const Color(0xFFF59E0B).withOpacity(0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    selectedCount > 0
                                        ? 'Matching Assets for Report'
                                        : 'No Items Selected',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: selectedCount > 0
                                          ? ParishColors.oliveGreen
                                          : const Color(0xFFD97706),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    selectedCount > 0
                                        ? '$selectedCount item(s) selected for report'
                                        : 'Select at least 1 item in the checklist above',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: selectedCount > 0
                                          ? textDark
                                          : const Color(0xFFD97706),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'Total Valuation',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: ParishColors.oliveGreen,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '₱ ${AssetModel.formatCurrency(_totalValuation)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: ParishColors.oliveGreen,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 5. Actions Card with Progress Monitor
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(isMobile ? 14 : 20),
                        decoration: BoxDecoration(
                          color: cardWhite,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderGrey),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isGenerating) ...[
                              _buildProgressMonitor(isMobile),
                              const SizedBox(height: 16),
                            ],
                            if (isMobile)
                              _buildMobileFooter(selectedCount)
                            else
                              _buildDesktopFooter(selectedCount, textMuted),
                          ],
                        ),
                      ),
                      SizedBox(height: isMobile ? 36 : 56),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // Section Header Helper
  // ===========================================================================

  Widget _buildSectionHeader({
    required String title,
    required Color textDark,
  }) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: textDark,
      ),
    );
  }

  // ===========================================================================
  // Individual Item Selection Checklist & Scope Filter Widget
  // ===========================================================================

  Widget _buildIndividualItemPickerSection(
      bool isMobile,
      Color borderGrey,
      Color cardWhite,
      Color textDark,
      Color textMuted,
      ) {
    final displayed = _displayedPickerAssets;
    final totalScopeCount = _scopeFilteredAssets.length;
    final totalEligibleCount = _allEligibleAssets.length;
    final totalSelectedCount = _selectedAssetIds.length;

    final bool allDisplayedSelected = displayed.isNotEmpty &&
        displayed.every((a) => _selectedAssetIds.contains(a.assetId));

    return Container(
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderGrey),
      ),
      padding: EdgeInsets.all(isMobile ? 14 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '3. Individual Item Selection & Exclusions',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Check/uncheck items to include or exclude. Search to cherry-pick items from other sections.',
                      style: TextStyle(
                        fontSize: 11,
                        color: textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4.5,
                ),
                decoration: BoxDecoration(
                  color: totalSelectedCount > 0
                      ? ParishColors.marianBlueSurface
                      : ParishColors.backgroundLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$totalSelectedCount Selected',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: totalSelectedCount > 0
                        ? ParishColors.marianBlue
                        : textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Scope View Tabs
          Container(
            decoration: BoxDecoration(
              color: ParishColors.backgroundLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: borderGrey.withOpacity(0.6),
              ),
            ),
            padding: const EdgeInsets.all(3.5),
            child: Row(
              children: [
                _buildPickerTab(0, 'Scope Filter ($totalScopeCount)'),
                _buildPickerTab(1, 'All Assets ($totalEligibleCount)'),
                _buildPickerTab(2, 'Selected ($totalSelectedCount)'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Search Field
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: ParishColors.backgroundLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderGrey),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                const Icon(
                  Icons.search,
                  size: 18,
                  color: ParishColors.marianBlue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _itemSearchController,
                    enabled: !_isGenerating,
                    onChanged: (val) {
                      setState(() => _itemSearchQuery = val);
                    },
                    style: TextStyle(
                      fontSize: 13,
                      color: textDark,
                    ),
                    decoration: InputDecoration(
                      hintText:
                      'Search by control #, item name, location, or description...',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: textMuted,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (_itemSearchQuery.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _isGenerating
                        ? null
                        : () {
                      _itemSearchController.clear();
                      setState(() => _itemSearchQuery = '');
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Quick Selection Toolbar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing ${displayed.length} item(s)',
                style: TextStyle(
                  fontSize: 11.5,
                  color: textMuted,
                ),
              ),
              TextButton(
                onPressed: _isGenerating || displayed.isEmpty
                    ? null
                    : (allDisplayedSelected
                    ? _deselectAllDisplayed
                    : _selectAllDisplayed),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(
                  allDisplayedSelected
                      ? 'Deselect Displayed'
                      : 'Select All Displayed',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: ParishColors.marianBlue,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 10),

          // Selectable Items Checklist (Expanded to 300px height for comfortable page view)
          Container(
            height: isMobile ? 260 : 300,
            decoration: BoxDecoration(
              color: ParishColors.backgroundLight.withOpacity(0.4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: borderGrey.withOpacity(0.6),
              ),
            ),
            child: displayed.isEmpty
                ? Center(
              child: Text(
                _itemSearchQuery.isNotEmpty
                    ? 'No items match "$_itemSearchQuery"'
                    : 'No items found in this tab.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: textMuted,
                ),
              ),
            )
                : ListView.separated(
              padding: const EdgeInsets.all(8),
              itemCount: displayed.length,
              separatorBuilder: (_, __) =>
              const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final asset = displayed[index];
                final isSelected =
                _selectedAssetIds.contains(asset.assetId);

                return InkWell(
                  onTap: _isGenerating
                      ? null
                      : () => _toggleAssetSelection(asset.assetId),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? ParishColors.marianBlueSurface
                          .withOpacity(0.55)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? ParishColors.marianBlue
                            : borderGrey.withOpacity(0.5),
                        width: isSelected ? 1.3 : 0.8,
                      ),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: isSelected,
                          activeColor: ParishColors.marianBlue,
                          visualDensity: VisualDensity.compact,
                          onChanged: _isGenerating
                              ? null
                              : (_) => _toggleAssetSelection(
                            asset.assetId,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                crossAxisAlignment:
                                WrapCrossAlignment.center,
                                spacing: 6,
                                runSpacing: 2,
                                children: [
                                  Text(
                                    asset.controlNumber,
                                    style: const TextStyle(
                                      fontFamily: 'Courier',
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: ParishColors.marianBlue,
                                    ),
                                  ),
                                  Container(
                                    padding:
                                    const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: asset.unitPrice >= 10000.0
                                          ? ParishColors.goldLight
                                          : ParishColors
                                          .marianBlueSurface,
                                      borderRadius:
                                      BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      asset.inventorySectionCode,
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color:
                                        asset.unitPrice >= 10000.0
                                            ? ParishColors.goldAccent
                                            : ParishColors
                                            .marianBlue,
                                      ),
                                    ),
                                  ),
                                  if (asset.quantity > 1)
                                    Text(
                                      '(${asset.quantity}x)',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: textMuted,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                asset.itemName,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: textDark,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${asset.displayLocation} • Acq: ${asset.formattedAcquisitionDate}',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: textMuted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          asset.formattedTotalCost,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: ParishColors.oliveGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickerTab(int tabIndex, String label) {
    final bool isSelected = _itemPickerTab == tabIndex;

    return Expanded(
      child: InkWell(
        onTap: _isGenerating
            ? null
            : () => setState(() => _itemPickerTab = tabIndex),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight:
              isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected
                  ? ParishColors.marianBlue
                  : ParishColors.textMuted,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
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
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _isGenerating ? null : () => Navigator.pop(context),
          child: Text(
            'Back to Inventory',
            style: TextStyle(color: textMuted, fontWeight: FontWeight.bold),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: ParishColors.marianBlue,
                side: const BorderSide(
                  color: ParishColors.marianBlue,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: canProceed ? _handlePreviewPdf : null,
              icon: (_isGenerating && _activeOperation == 'previewing')
                  ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
                  : const Icon(
                Icons.visibility_outlined,
                size: 17,
              ),
              label: const Text(
                'Preview PDF',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: ParishColors.oliveGreen,
                side: const BorderSide(
                  color: ParishColors.oliveGreen,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
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
                  : const Icon(
                Icons.download_outlined,
                size: 17,
              ),
              label: const Text(
                'Download PDF',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: ParishColors.marianBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
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
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
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
                  side: const BorderSide(
                    color: ParishColors.marianBlue,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: canProceed ? _handlePreviewPdf : null,
                icon: (_isGenerating && _activeOperation == 'previewing')
                    ? const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(
                  Icons.visibility_outlined,
                  size: 15,
                ),
                label: const Text(
                  'Preview',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: ParishColors.oliveGreen,
                  side: const BorderSide(
                    color: ParishColors.oliveGreen,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
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
                    : const Icon(
                  Icons.download_outlined,
                  size: 15,
                ),
                label: const Text(
                  'Download',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton(
              onPressed: _isGenerating ? null : () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ParishColors.marianBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
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
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
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
      onTap: _isGenerating ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? ParishColors.marianBlueSurface
              : ParishColors.backgroundLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? ParishColors.marianBlue
                : ParishColors.borderGrey,
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
              style: TextStyle(
                fontSize: 10.5,
                color: ParishColors.textMuted,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}