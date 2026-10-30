// =============================================================================
// FILE: lib/features/asset_inventory/presentation/pages/asset_batch_print_page.dart
// =============================================================================

import 'package:flutter/material.dart';
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
        SnackBar(content: Text('Print error: $e'), backgroundColor: ParishColors.mercyRed),
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
            Text('Batch Asset QR Tag Printing',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark)),
            Text('Select property items to compile onto A4 sheets (24 tags/page)',
                style: TextStyle(fontSize: 12, color: textMuted)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: selectedCount > 0 ? ParishColors.goldAccent : borderGrey,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: (_isGeneratingPdf || selectedCount == 0) ? null : _printSelectedLabels,
              icon: _isGeneratingPdf
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.print, size: 18),
              label: Text(_isGeneratingPdf ? 'Generating PDF...' : 'Print $selectedCount Tag(s)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Controls Bar
            Container(
              padding: const EdgeInsets.all(16),
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
                        const Icon(Icons.search, size: 20, color: ParishColors.marianBlue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) => setState(() => _searchQuery = val),
                            decoration: const InputDecoration(
                              hintText: 'Filter by control number, asset name, or location...',
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
                            onChanged: _toggleSelectAll,
                          ),
                          Text(_isAllSelected ? 'Deselect All' : 'Select All (${displayed.length})',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: selectedCount > 0 ? ParishColors.oliveGreenSurface : ParishColors.backgroundLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: selectedCount > 0 ? ParishColors.oliveGreen : borderGrey),
                        ),
                        child: Text(
                          '$selectedCount of ${widget.availableAssets.length} Selected',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: selectedCount > 0 ? ParishColors.oliveGreen : textMuted),
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
                  ? Center(child: Text('No matching assets found.', style: TextStyle(color: textMuted)))
                  : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: displayed.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final a = displayed[index];
                  final isSelected = _selectedAssetIds.contains(a.assetId);

                  return InkWell(
                    onTap: () {
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
                        color: isSelected ? ParishColors.marianBlueSurface.withOpacity(0.4) : cardWhite,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? ParishColors.marianBlue : borderGrey,
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: isSelected,
                            activeColor: ParishColors.marianBlue,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedAssetIds.add(a.assetId);
                                } else {
                                  _selectedAssetIds.remove(a.assetId);
                                }
                              });
                            },
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(a.controlNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ParishColors.marianBlue)),
                                Text(a.itemName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textDark)),
                                Text('${a.displayClassification} • ${a.displayLocation}', style: TextStyle(fontSize: 11.5, color: textMuted)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('Acq: ${a.acquisitionYear}', style: TextStyle(fontSize: 11, color: textMuted)),
                              Text(a.formattedUnitPrice, style: const TextStyle(fontWeight: FontWeight.bold, color: ParishColors.oliveGreen)),
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
  }
}