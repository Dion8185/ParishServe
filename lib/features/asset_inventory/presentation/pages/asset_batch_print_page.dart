// =============================================================================
// FILE: lib/features/asset_inventory/presentation/pages/asset_batch_print_page.dart
// =============================================================================

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../../../core/constants/colors.dart';
import '../../models/asset_model.dart';
import '../../services/asset_label_pdf_service.dart';

class AssetBatchPrintPage extends StatefulWidget {
  final List<AssetModel> availableAssets;

  const AssetBatchPrintPage({super.key, required this.availableAssets});

  @override
  State<AssetBatchPrintPage> createState() => _AssetBatchPrintPageState();
}

class _AssetBatchPrintPageState extends State<AssetBatchPrintPage> {
  final Set<String> _selectedAssetIds = {};
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  bool _isGeneratingPdf = false;
  bool _isPreviewingPdf = false;

  bool get _isBusy => _isGeneratingPdf || _isPreviewingPdf;

  @override
  void initState() {
    super.initState();
    _selectedAssetIds.addAll(widget.availableAssets.map((a) => a.assetId));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AssetModel> get _displayedAssets {
    if (_searchQuery.trim().isEmpty) return widget.availableAssets;
    final q = _searchQuery.toLowerCase().trim();
    return widget.availableAssets.where((a) {
      return a.controlNumber.toLowerCase().contains(q) ||
          a.itemName.toLowerCase().contains(q) ||
          a.displayLocation.toLowerCase().contains(q) ||
          a.displayClassification.toLowerCase().contains(q);
    }).toList();
  }

  bool get _isAllSelected =>
      _displayedAssets.isNotEmpty &&
          _displayedAssets.every((a) => _selectedAssetIds.contains(a.assetId));

  void _toggleSelectAll(bool? selectAll) {
    setState(() {
      if (selectAll == true) {
        _selectedAssetIds.addAll(_displayedAssets.map((a) => a.assetId));
      } else {
        for (final a in _displayedAssets) {
          _selectedAssetIds.remove(a.assetId);
        }
      }
    });
  }

  // ===========================================================================
  // 1. Interactive Print Preview Action
  // ===========================================================================

  Future<void> _previewSelectedLabels() async {
    final selectedList = widget.availableAssets
        .where((a) => _selectedAssetIds.contains(a.assetId))
        .toList();

    if (selectedList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one asset tag to preview.'),
          backgroundColor: ParishColors.goldAccent,
        ),
      );
      return;
    }

    setState(() => _isPreviewingPdf = true);

    try {
      final pdfBytes =
      await AssetLabelPdfService.generateBatchAssetLabelsPdf(selectedList);
      if (!mounted) return;
      setState(() => _isPreviewingPdf = false);

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
                      Icons.qr_code,
                      color: ParishColors.marianBlue,
                    ),
                    title: Text(
                      'Batch Asset QR Tags Preview (${selectedList.length} items)',
                      style: TextStyle(
                        color: ParishColors.textDark,
                        fontSize: isScreenMobile ? 13 : 15,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
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
                    useActions: true,
                    canChangeOrientation: false,
                    canChangePageFormat: false,
                    canDebug: false,
                    dynamicLayout: false,
                    enableScrollToPage: true,
                    pdfFileName:
                    'Asset_Tags_${DateTime.now().millisecondsSinceEpoch}.pdf',
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
      setState(() => _isPreviewingPdf = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Preview error: $e'),
          backgroundColor: ParishColors.mercyRed,
        ),
      );
    }
  }

  // ===========================================================================
  // 2. Direct Batch Print Action
  // ===========================================================================

  Future<void> _printSelectedLabels() async {
    final selectedList = widget.availableAssets
        .where((a) => _selectedAssetIds.contains(a.assetId))
        .toList();

    if (selectedList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one asset tag to print.'),
          backgroundColor: ParishColors.goldAccent,
        ),
      );
      return;
    }

    setState(() => _isGeneratingPdf = true);

    try {
      await AssetLabelPdfService.printBatchAssetLabels(selectedList);
      if (!mounted) return;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Print error: $e'),
          backgroundColor: ParishColors.mercyRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final cardWhite = ParishColors.cardWhite;
    final borderGrey = ParishColors.borderGrey;

    final displayed = _displayedAssets;
    final selectedCount = _selectedAssetIds.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 650;

        return Scaffold(
          backgroundColor: ParishColors.backgroundLight,
          appBar: AppBar(
            backgroundColor: cardWhite,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back,
                color: ParishColors.marianBlue,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Batch Asset QR Tag Printing',
                  style: TextStyle(
                    fontSize: isMobile ? 15 : 18,
                    fontWeight: FontWeight.bold,
                    color: textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Select property items to compile onto A4 sheets (21 tags/page)',
                  style: TextStyle(
                    fontSize: isMobile ? 10.5 : 12,
                    color: textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            actions: [
              // Preview Tags Action
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 4 : 6,
                  vertical: 8,
                ),
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ParishColors.marianBlue,
                    side: const BorderSide(color: ParishColors.marianBlue),
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 8 : 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: (_isBusy || selectedCount == 0)
                      ? null
                      : _previewSelectedLabels,
                  icon: _isPreviewingPdf
                      ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.visibility_outlined, size: 16),
                  label: Text(
                    isMobile ? 'Preview' : 'Preview Tags',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isMobile ? 11.5 : 12.5,
                    ),
                  ),
                ),
              ),

              // Print Action
              Padding(
                padding: EdgeInsets.only(
                  right: isMobile ? 8 : 14,
                  top: 8,
                  bottom: 8,
                ),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: selectedCount > 0
                        ? ParishColors.goldAccent
                        : borderGrey,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 10 : 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: (_isBusy || selectedCount == 0)
                      ? null
                      : _printSelectedLabels,
                  icon: _isGeneratingPdf
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
                    _isGeneratingPdf
                        ? 'Printing...'
                        : (isMobile
                        ? 'Print ($selectedCount)'
                        : 'Print $selectedCount Tag(s)'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isMobile ? 11.5 : 12.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                // Controls Bar
                Container(
                  padding: EdgeInsets.all(isMobile ? 12 : 16),
                  color: cardWhite,
                  child: Column(
                    children: [
                      Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: ParishColors.backgroundLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderGrey),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.search,
                              size: 20,
                              color: ParishColors.marianBlue,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                onChanged: (val) =>
                                    setState(() => _searchQuery = val),
                                style: TextStyle(fontSize: 13, color: textDark),
                                decoration: InputDecoration(
                                  hintText:
                                  'Filter by control number, asset name, or location...',
                                  hintStyle: TextStyle(
                                    fontSize: 12.5,
                                    color: textMuted,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ),
                            if (_searchQuery.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Checkbox(
                                value: _isAllSelected,
                                activeColor: ParishColors.marianBlue,
                                visualDensity: VisualDensity.compact,
                                onChanged: _isBusy ? null : _toggleSelectAll,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isMobile
                                    ? (_isAllSelected
                                    ? 'Deselect'
                                    : 'All (${displayed.length})')
                                    : (_isAllSelected
                                    ? 'Deselect All'
                                    : 'Select All (${displayed.length})'),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: isMobile ? 12 : 13,
                                  color: textDark,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: selectedCount > 0
                                  ? ParishColors.oliveGreenSurface
                                  : ParishColors.backgroundLight,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: selectedCount > 0
                                    ? ParishColors.oliveGreen
                                    : borderGrey,
                              ),
                            ),
                            child: Text(
                              isMobile
                                  ? '$selectedCount / ${widget.availableAssets.length} Selected'
                                  : '$selectedCount of ${widget.availableAssets.length} Selected',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: selectedCount > 0
                                    ? ParishColors.oliveGreen
                                    : textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Selectable List
                Expanded(
                  child: displayed.isEmpty
                      ? Center(
                    child: Text(
                      'No matching assets found.',
                      style: TextStyle(color: textMuted),
                    ),
                  )
                      : ListView.separated(
                    padding: EdgeInsets.all(isMobile ? 12 : 16),
                    itemCount: displayed.length,
                    separatorBuilder: (_, __) =>
                    const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final a = displayed[index];
                      final isSelected = _selectedAssetIds.contains(
                        a.assetId,
                      );

                      return InkWell(
                        onTap: _isBusy
                            ? null
                            : () {
                          setState(() {
                            if (isSelected) {
                              _selectedAssetIds.remove(a.assetId);
                            } else {
                              _selectedAssetIds.add(a.assetId);
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? ParishColors.marianBlueSurface
                                .withOpacity(0.4)
                                : cardWhite,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? ParishColors.marianBlue
                                  : borderGrey,
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Checkbox(
                                value: isSelected,
                                activeColor: ParishColors.marianBlue,
                                visualDensity: VisualDensity.compact,
                                onChanged: _isBusy
                                    ? null
                                    : (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedAssetIds.add(
                                        a.assetId,
                                      );
                                    } else {
                                      _selectedAssetIds.remove(
                                        a.assetId,
                                      );
                                    }
                                  });
                                },
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          a.controlNumber,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color:
                                            ParishColors.marianBlue,
                                          ),
                                        ),
                                        if (a.quantity > 1) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 5,
                                              vertical: 1,
                                            ),
                                            decoration: BoxDecoration(
                                              color: ParishColors
                                                  .marianBlueSurface,
                                              borderRadius:
                                              BorderRadius.circular(
                                                3,
                                              ),
                                            ),
                                            child: Text(
                                              '${a.quantity} units',
                                              style: const TextStyle(
                                                fontSize: 9,
                                                fontWeight:
                                                FontWeight.bold,
                                                color: ParishColors
                                                    .marianBlue,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      a.itemName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: textDark,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '${a.displayClassification} • ${a.displayLocation}',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: textMuted,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Acq: ${a.acquisitionYear}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: textMuted,
                                    ),
                                  ),
                                  Text(
                                    a.formattedUnitPrice,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: ParishColors.oliveGreen,
                                    ),
                                  ),
                                ],
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
          ),
        );
      },
    );
  }
}