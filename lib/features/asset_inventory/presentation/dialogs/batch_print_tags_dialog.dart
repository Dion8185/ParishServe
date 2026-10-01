import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../models/asset_model.dart';
import '../../services/asset_label_pdf_service.dart';

void showBatchPrintTagsModal(
    BuildContext context, {
      required List<AssetModel> availableAssets,
    }) {
  showDialog(
    context: context,
    builder: (ctx) => _BatchPrintTagsDialog(availableAssets: availableAssets),
  );
}

class _BatchPrintTagsDialog extends StatefulWidget {
  final List<AssetModel> availableAssets;

  const _BatchPrintTagsDialog({required this.availableAssets});

  @override
  State<_BatchPrintTagsDialog> createState() => _BatchPrintTagsDialogState();
}

class _BatchPrintTagsDialogState extends State<_BatchPrintTagsDialog> {
  final Set<String> _selectedAssetIds = {};
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  bool _isGeneratingPdf = false;

  @override
  void initState() {
    super.initState();
    // Default to selecting all active assets in the current view
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
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isGeneratingPdf = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Print error: $e'),
          backgroundColor: ParishColors.mercyRed,
        ),
      );
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
        final bool isMobile = constraints.maxWidth < 600;

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: cardWhite,
          insetPadding: EdgeInsets.symmetric(
            horizontal: isMobile ? 12 : 24,
            vertical: isMobile ? 14 : 24,
          ),
          child: Container(
            width: 700,
            constraints: const BoxConstraints(maxHeight: 740),
            child: Column(
              children: [
                // Header Banner
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 16 : 20,
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
                          color: ParishColors.goldAccent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.print_outlined,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Select Tags for Batch Printing',
                              style: TextStyle(
                                fontSize: isMobile ? 15.5 : 17,
                                fontWeight: FontWeight.bold,
                                color: textDark,
                              ),
                            ),
                            Text(
                              'Select which asset property stickers to include on the A4 print sheet',
                              style: TextStyle(
                                  fontSize: isMobile ? 11 : 12, color: textMuted),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // Controls: Search & Select All Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    children: [
                      // Search inside selection dialog
                      Container(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: ParishColors.backgroundLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderGrey),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search,
                                size: 18, color: ParishColors.marianBlue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                onChanged: (val) =>
                                    setState(() => _searchQuery = val),
                                style: TextStyle(
                                    fontSize: 13, color: textDark),
                                decoration: InputDecoration(
                                  hintText:
                                  'Filter by Control #, name, location...',
                                  hintStyle: TextStyle(
                                      fontSize: 12, color: textMuted),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ),
                            if (_searchQuery.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Select All Row with Counter
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          InkWell(
                            onTap: () => _toggleSelectAll(!_isAllSelected),
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Checkbox(
                                    value: _isAllSelected,
                                    activeColor: ParishColors.marianBlue,
                                    visualDensity: VisualDensity.compact,
                                    onChanged: _toggleSelectAll,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _isAllSelected
                                        ? 'Deselect All'
                                        : 'Select All Displayed',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: textDark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
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
                              '$selectedCount of ${widget.availableAssets.length} Selected',
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

                // Selectable Asset List
                Expanded(
                  child: displayed.isEmpty
                      ? Center(
                    child: Text(
                      'No asset items match your search filter.',
                      style: TextStyle(color: textMuted, fontSize: 13),
                    ),
                  )
                      : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    itemCount: displayed.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final asset = displayed[index];
                      final isSelected =
                      _selectedAssetIds.contains(asset.assetId);

                      return InkWell(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedAssetIds.remove(asset.assetId);
                            } else {
                              _selectedAssetIds.add(asset.assetId);
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? ParishColors.marianBlueSurface
                                .withValues(alpha: 0.5)
                                : ParishColors.cardWhite,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? ParishColors.marianBlue
                                  : borderGrey,
                              width: isSelected ? 1.4 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Checkbox(
                                value: isSelected,
                                activeColor: ParishColors.marianBlue,
                                visualDensity: VisualDensity.compact,
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedAssetIds
                                          .add(asset.assetId);
                                    } else {
                                      _selectedAssetIds
                                          .remove(asset.assetId);
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
                                          asset.controlNumber,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12.5,
                                            color:
                                            ParishColors.marianBlue,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 5,
                                              vertical: 1),
                                          decoration: BoxDecoration(
                                            color:
                                            asset.unitPrice >= 10000.0
                                                ? ParishColors
                                                .goldLight
                                                : ParishColors
                                                .marianBlueSurface,
                                            borderRadius:
                                            BorderRadius.circular(3),
                                          ),
                                          child: Text(
                                            asset.inventorySectionCode,
                                            style: TextStyle(
                                              fontSize: 8.5,
                                              fontWeight: FontWeight.bold,
                                              color: asset.unitPrice >=
                                                  10000.0
                                                  ? ParishColors.goldAccent
                                                  : ParishColors
                                                  .marianBlue,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      asset.itemName,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.bold,
                                        color: textDark,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '${asset.displayClassification} • ${asset.displayLocation}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Acq: ${asset.acquisitionYear}',
                                    style: TextStyle(
                                        fontSize: 11, color: textMuted),
                                  ),
                                  Text(
                                    asset.formattedUnitPrice,
                                    style: const TextStyle(
                                      fontSize: 12,
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

                // Footer Actions
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 16 : 20,
                    vertical: isMobile ? 10 : 14,
                  ),
                  decoration: BoxDecoration(
                    color: cardWhite,
                    borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(20)),
                    border: Border(top: BorderSide(color: borderGrey)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: _isGeneratingPdf
                            ? null
                            : () => Navigator.pop(context),
                        child: Text('Cancel',
                            style: TextStyle(color: textMuted, fontSize: 13)),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: selectedCount > 0
                              ? ParishColors.goldAccent
                              : ParishColors.borderGrey,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: (_isGeneratingPdf || selectedCount == 0)
                            ? null
                            : _printSelectedLabels,
                        icon: _isGeneratingPdf
                            ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.print, size: 16),
                        label: Text(
                          _isGeneratingPdf
                              ? 'Generating PDF...'
                              : 'Print $selectedCount Tag(s)',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
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