// =============================================================================
// FILE: lib/features/asset_inventory/presentation/pages/asset_batch_print_page.dart
// =============================================================================

import 'dart:math';
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

class _AssetBatchPrintPageState extends State<AssetBatchPrintPage>
    with SingleTickerProviderStateMixin {
  final Set<String> _selectedAssetIds = {};
  final TextEditingController _searchController = TextEditingController();

  late TabController _sectionTabController;

  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _selectedLocation = 'All';
  String _selectedCondition = 'All';
  String _selectedOperationalStatus = 'All';

  // Sorting State
  String _sortBy = 'Control Number';
  bool _sortAscending = true;

  final List<String> _sortOptions = [
    'Control Number',
    'Item Name',
    'Price / Unit',
    'Total Cost',
    'Acquisition Year',
    'Registration Date',
  ];

  final List<String> _conditionOptions = [
    'All',
    ...AssetModel.standardConditions,
  ];

  final List<String> _operationalStatusOptions = [
    'All',
    ...AssetModel.standardAvailability,
  ];

  // Pagination State
  int _currentPage = 1;
  int _itemsPerPage = 10;

  bool _isGeneratingPdf = false;
  bool _isPreviewingPdf = false;

  bool get _isBusy => _isGeneratingPdf || _isPreviewingPdf;

  @override
  void initState() {
    super.initState();
    _selectedAssetIds.addAll(widget.availableAssets.map((a) => a.assetId));

    _sectionTabController = TabController(length: 4, vsync: this);
    _sectionTabController.addListener(() {
      if (!_sectionTabController.indexIsChanging) {
        setState(() {
          _currentPage = 1;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _sectionTabController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // Control Number Numerical Sorting Helper
  // ===========================================================================

  int _extractEndingSequence(String controlNumber) {
    if (controlNumber.isEmpty) return 0;
    final clean = controlNumber.trim();
    final base = clean.contains('/') ? clean.split('/').first.trim() : clean;

    final lastDash = base.lastIndexOf('-');
    if (lastDash != -1 && lastDash < base.length - 1) {
      final suffix = base.substring(lastDash + 1).trim();
      final directParsed = int.tryParse(suffix);
      if (directParsed != null) return directParsed;

      final match = RegExp(r'\d+').firstMatch(suffix);
      if (match != null) {
        final parsed = int.tryParse(match.group(0)!);
        if (parsed != null) return parsed;
      }
    }

    final allMatches = RegExp(r'\d+').allMatches(base);
    if (allMatches.isNotEmpty) {
      return int.tryParse(allMatches.last.group(0)!) ?? 0;
    }

    return 0;
  }

  int _compareControlNumbers(String a, String b) {
    final numA = _extractEndingSequence(a);
    final numB = _extractEndingSequence(b);
    final comp = numA.compareTo(numB);
    if (comp != 0) return comp;
    return a.compareTo(b);
  }

  // ===========================================================================
  // Sectioning & Filtering Pipeline
  // ===========================================================================

  int get _activeCount =>
      widget.availableAssets.where((a) => !a.isEffectivelyArchived).length;
  int get _section1Count => widget.availableAssets
      .where((a) => !a.isEffectivelyArchived && a.unitPrice >= 10000.0)
      .length;
  int get _section2Count => widget.availableAssets
      .where((a) => !a.isEffectivelyArchived && a.unitPrice < 10000.0)
      .length;
  int get _archivedCount =>
      widget.availableAssets.where((a) => a.isEffectivelyArchived).length;

  List<String> get _availableCategories {
    final set = <String>{};
    for (final a in widget.availableAssets) {
      if (a.classificationAcronym.isNotEmpty) {
        set.add(a.classificationAcronym.toUpperCase());
      }
    }
    final list = set.toList()..sort();
    return ['All', ...list];
  }

  List<String> get _availableLocations {
    final set = <String>{};
    for (final a in widget.availableAssets) {
      if (a.locationAcronym.isNotEmpty) {
        set.add(a.locationAcronym.toUpperCase());
      }
    }
    final list = set.toList()..sort();
    return ['All', ...list];
  }

  List<AssetModel> get _filteredAssets {
    var list = widget.availableAssets;

    // 1. Section Tab Filter
    if (_sectionTabController.index == 3) {
      list = list.where((a) => a.isEffectivelyArchived).toList();
    } else {
      list = list.where((a) => !a.isEffectivelyArchived).toList();
      if (_sectionTabController.index == 1) {
        list = list.where((a) => a.unitPrice >= 10000.0).toList();
      } else if (_sectionTabController.index == 2) {
        list = list.where((a) => a.unitPrice < 10000.0).toList();
      }
    }

    // 2. Category Filter
    if (_selectedCategory != 'All') {
      list = list
          .where((a) =>
      a.classificationAcronym.toUpperCase() ==
          _selectedCategory.toUpperCase())
          .toList();
    }

    // 3. Location Filter
    if (_selectedLocation != 'All') {
      list = list
          .where((a) =>
      a.locationAcronym.toUpperCase() ==
          _selectedLocation.toUpperCase())
          .toList();
    }

    // 4. Condition Filter
    if (_selectedCondition != 'All') {
      list = list
          .where((a) =>
      AssetModel.normalizeCondition(a.conditionStatus).toLowerCase() ==
          _selectedCondition.toLowerCase())
          .toList();
    }

    // 5. Availability Filter
    if (_sectionTabController.index != 3 &&
        _selectedOperationalStatus != 'All') {
      list = list
          .where((a) =>
      AssetModel.normalizeStatus(a.operationalStatus).toLowerCase() ==
          _selectedOperationalStatus.toLowerCase())
          .toList();
    }

    // 6. Search Query
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      list = list.where((a) {
        return a.controlNumber.toLowerCase().contains(q) ||
            a.itemName.toLowerCase().contains(q) ||
            (a.model ?? '').toLowerCase().contains(q) ||
            (a.color ?? '').toLowerCase().contains(q) ||
            (a.rfidTag ?? '').toLowerCase().contains(q) ||
            a.displayLocation.toLowerCase().contains(q) ||
            a.displayClassification.toLowerCase().contains(q);
      }).toList();
    }

    // 7. Sorting
    list.sort((a, b) {
      int comparison = 0;
      switch (_sortBy) {
        case 'Control Number':
          comparison =
              _compareControlNumbers(a.controlNumber, b.controlNumber);
          break;
        case 'Item Name':
          comparison =
              a.itemName.toLowerCase().compareTo(b.itemName.toLowerCase());
          break;
        case 'Price / Unit':
          comparison = a.unitPrice.compareTo(b.unitPrice);
          break;
        case 'Total Cost':
          comparison = a.totalCost.compareTo(b.totalCost);
          break;
        case 'Acquisition Year':
          comparison = a.acquisitionYear.compareTo(b.acquisitionYear);
          break;
        case 'Registration Date':
        default:
          comparison = a.registrationDate.compareTo(b.registrationDate);
          break;
      }
      return _sortAscending ? comparison : -comparison;
    });

    return list;
  }

  int get _totalPages {
    final total = _filteredAssets.length;
    if (total == 0) return 1;
    return (total / _itemsPerPage).ceil();
  }

  List<AssetModel> get _pagedAssets {
    final list = _filteredAssets;
    final total = list.length;
    final start = (_currentPage - 1) * _itemsPerPage;
    if (start >= total) return [];
    final end = min(start + _itemsPerPage, total);
    return list.sublist(start, end);
  }

  int get _activeFilterCount {
    int count = 0;
    if (_selectedCategory != 'All') count++;
    if (_selectedLocation != 'All') count++;
    if (_selectedCondition != 'All') count++;
    if (_selectedOperationalStatus != 'All' &&
        _sectionTabController.index != 3) {
      count++;
    }
    if (_sortBy != 'Control Number' || !_sortAscending) count++;
    return count;
  }

  bool get _hasActiveFilters => _activeFilterCount > 0;

  void _resetFilters() {
    setState(() {
      _selectedCategory = 'All';
      _selectedLocation = 'All';
      _selectedCondition = 'All';
      _selectedOperationalStatus = 'All';
      _sortBy = 'Control Number';
      _sortAscending = true;
      _currentPage = 1;
    });
  }

  bool get _isAllFilteredSelected {
    final filtered = _filteredAssets;
    if (filtered.isEmpty) return false;
    return filtered.every((a) => _selectedAssetIds.contains(a.assetId));
  }

  void _toggleSelectAllFiltered(bool? selectAll) {
    setState(() {
      final filtered = _filteredAssets;
      if (selectAll == true) {
        for (final a in filtered) {
          _selectedAssetIds.add(a.assetId);
        }
      } else {
        for (final a in filtered) {
          _selectedAssetIds.remove(a.assetId);
        }
      }
    });
  }

  // ===========================================================================
  // Filter & Sort Bottom Sheet Modal
  // ===========================================================================

  void _openFilterAndSortBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ParishColors.cardWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 14,
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: ParishColors.borderGrey,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filter & Sort Tags',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.bold,
                          color: ParishColors.textDark,
                        ),
                      ),
                      if (_hasActiveFilters)
                        TextButton(
                          onPressed: () {
                            _resetFilters();
                            setSheetState(() {});
                            Navigator.pop(ctx);
                          },
                          child: const Text(
                            'Reset All',
                            style: TextStyle(
                              color: ParishColors.mercyRed,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const Divider(height: 14),

                  // 1. Sort Order
                  Text(
                    'Sort Sequence',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: ParishColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _sortBy,
                          isExpanded: true,
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          items: _sortOptions
                              .map((opt) => DropdownMenuItem(
                              value: opt,
                              child: Text(opt,
                                  style: const TextStyle(fontSize: 13))))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _sortBy = val);
                              setSheetState(() {});
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: ParishColors.marianBlueSurface,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: Icon(
                          _sortAscending
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: 18,
                          color: ParishColors.marianBlue,
                        ),
                        onPressed: () {
                          setState(() => _sortAscending = !_sortAscending);
                          setSheetState(() {});
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 2. Category Filter
                  Text(
                    'Classification Category',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: ParishColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    isExpanded: true,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    items: _availableCategories
                        .map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(c == 'All' ? 'All Categories' : c,
                          style: const TextStyle(fontSize: 13)),
                    ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedCategory = val;
                          _currentPage = 1;
                        });
                        setSheetState(() {});
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  // 3. Storage Location Filter
                  Text(
                    'Storage Location',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: ParishColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _selectedLocation,
                    isExpanded: true,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    items: _availableLocations
                        .map((l) => DropdownMenuItem(
                      value: l,
                      child: Text(l == 'All' ? 'All Locations' : l,
                          style: const TextStyle(fontSize: 13)),
                    ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedLocation = val;
                          _currentPage = 1;
                        });
                        setSheetState(() {});
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  // 4. Physical Condition
                  Text(
                    'Physical Condition',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: ParishColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _conditionOptions.map((cond) {
                        final isSelected = _selectedCondition == cond;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: ChoiceChip(
                            label: Text(cond),
                            selected: isSelected,
                            selectedColor: ParishColors.marianBlue,
                            backgroundColor: ParishColors.backgroundLight,
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : ParishColors.textDark,
                              fontWeight: FontWeight.bold,
                              fontSize: 11.5,
                            ),
                            onSelected: (_) {
                              setState(() {
                                _selectedCondition = cond;
                                _currentPage = 1;
                              });
                              setSheetState(() {});
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 5. Availability Status
                  if (_sectionTabController.index != 3) ...[
                    Text(
                      'Availability Status',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: ParishColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _operationalStatusOptions.map((st) {
                          final isSelected = _selectedOperationalStatus == st;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: ChoiceChip(
                              label: Text(st),
                              selected: isSelected,
                              selectedColor: ParishColors.marianBlue,
                              backgroundColor: ParishColors.backgroundLight,
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : ParishColors.textDark,
                                fontWeight: FontWeight.bold,
                                fontSize: 11.5,
                              ),
                              onSelected: (_) {
                                setState(() {
                                  _selectedOperationalStatus = st;
                                  _currentPage = 1;
                                });
                                setSheetState(() {});
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],

                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ParishColors.marianBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Apply & Close',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. Direct Print Action
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

  // ===========================================================================
  // 2. Interactive In-App Print Preview Action
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
  // Main Page Build
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final cardWhite = ParishColors.cardWhite;
    final borderGrey = ParishColors.borderGrey;

    final filtered = _filteredAssets;
    final paged = _pagedAssets;
    final selectedCount = _selectedAssetIds.length;
    final filteredCount = filtered.length;

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
            actions: const [],
          ),
          body: SafeArea(
            child: Column(
              children: [
                // Controls Bar: Search / Filter Bar at Top, Centered Section Tabs Below
                Container(
                  padding: EdgeInsets.all(isMobile ? 10 : 14),
                  color: cardWhite,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Search & Filter Bar Row (Matched exactly with AssetInventoryView search bar style)
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 46,
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: ParishColors.cardWhite,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: ParishColors.borderGrey, width: 1),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.search,
                                    size: 21,
                                    color: ParishColors.marianBlue,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextField(
                                      controller: _searchController,
                                      onChanged: (val) => setState(() {
                                        _searchQuery = val;
                                        _currentPage = 1;
                                      }),
                                      style: TextStyle(
                                          fontSize: 14, color: ParishColors.textDark),
                                      decoration: InputDecoration(
                                        hintText: isMobile
                                            ? 'Search items, control #, room...'
                                            : 'Search by item name, control number, location, or room...',
                                        hintStyle: TextStyle(
                                            fontSize: 13,
                                            color: ParishColors.textMuted),
                                        border: InputBorder.none,
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  if (_searchQuery.isNotEmpty)
                                    IconButton(
                                      icon: const Icon(Icons.clear, size: 17),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {
                                          _searchQuery = '';
                                          _currentPage = 1;
                                        });
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Filter Trigger Button
                          InkWell(
                            onTap: _openFilterAndSortBottomSheet,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              height: 46,
                              padding: EdgeInsets.symmetric(
                                  horizontal: isMobile ? 12 : 16),
                              decoration: BoxDecoration(
                                color: _hasActiveFilters
                                    ? ParishColors.marianBlueSurface
                                    : ParishColors.cardWhite,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _hasActiveFilters
                                      ? ParishColors.marianBlue
                                      : ParishColors.borderGrey,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.tune,
                                    size: 18,
                                    color: _hasActiveFilters
                                        ? ParishColors.marianBlue
                                        : ParishColors.textDark,
                                  ),
                                  if (!isMobile || _hasActiveFilters) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      _hasActiveFilters
                                          ? 'Filter ($_activeFilterCount)'
                                          : 'Filter',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: _hasActiveFilters
                                            ? ParishColors.marianBlue
                                            : ParishColors.textDark,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.expand_more,
                                    size: 18,
                                    color: _hasActiveFilters
                                        ? ParishColors.marianBlue
                                        : ParishColors.textMuted,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // 2. Centered Section Tabs Bar (Swapped to second line)
                      Center(
                        child: Container(
                          height: 38,
                          constraints: const BoxConstraints(maxWidth: 520),
                          decoration: BoxDecoration(
                            color: ParishColors.backgroundLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: borderGrey),
                          ),
                          child: TabBar(
                            controller: _sectionTabController,
                            isScrollable: false,
                            tabAlignment: TabAlignment.fill,
                            padding: EdgeInsets.zero,
                            labelPadding: EdgeInsets.zero,
                            labelColor: Colors.white,
                            unselectedLabelColor: ParishColors.textMuted,
                            indicatorSize: TabBarIndicatorSize.tab,
                            indicator: BoxDecoration(
                              color: _sectionTabController.index == 3
                                  ? ParishColors.mercyRed
                                  : ParishColors.marianBlue,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            tabs: [
                              Tab(
                                child: Text(
                                  'All (${_activeCount})',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11.5),
                                ),
                              ),
                              Tab(
                                child: Text(
                                  'Sec 1 (${_section1Count})',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11.5),
                                ),
                              ),
                              Tab(
                                child: Text(
                                  'Sec 2 (${_section2Count})',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11.5),
                                ),
                              ),
                              Tab(
                                child: Text(
                                  'Arch (${_archivedCount})',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Active Filter Chips
                      if (_hasActiveFilters) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (_selectedCategory != 'All')
                              _buildActiveFilterChip(
                                  'Category: $_selectedCategory', () {
                                setState(() {
                                  _selectedCategory = 'All';
                                  _currentPage = 1;
                                });
                              }),
                            if (_selectedLocation != 'All')
                              _buildActiveFilterChip(
                                  'Location: $_selectedLocation', () {
                                setState(() {
                                  _selectedLocation = 'All';
                                  _currentPage = 1;
                                });
                              }),
                            if (_selectedCondition != 'All')
                              _buildActiveFilterChip(
                                  'Condition: $_selectedCondition', () {
                                setState(() {
                                  _selectedCondition = 'All';
                                  _currentPage = 1;
                                });
                              }),
                            if (_selectedOperationalStatus != 'All' &&
                                _sectionTabController.index != 3)
                              _buildActiveFilterChip(
                                  'Availability: $_selectedOperationalStatus',
                                      () {
                                    setState(() {
                                      _selectedOperationalStatus = 'All';
                                      _currentPage = 1;
                                    });
                                  }),
                            if (_sortBy != 'Control Number' || !_sortAscending)
                              _buildActiveFilterChip('Sorted: $_sortBy', () {
                                setState(() {
                                  _sortBy = 'Control Number';
                                  _sortAscending = true;
                                });
                              }),
                            ActionChip(
                              label: const Text('Reset',
                                  style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: ParishColors.mercyRed)),
                              backgroundColor: ParishColors.mercyRedSurface,
                              onPressed: _resetFilters,
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),

                      // Selection Toolbar: Select All in Filter vs Counter
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          InkWell(
                            onTap: _isBusy || filtered.isEmpty
                                ? null
                                : () => _toggleSelectAllFiltered(
                                !_isAllFilteredSelected),
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Checkbox(
                                    value: _isAllFilteredSelected,
                                    activeColor: ParishColors.marianBlue,
                                    visualDensity: VisualDensity.compact,
                                    onChanged: _isBusy || filtered.isEmpty
                                        ? null
                                        : _toggleSelectAllFiltered,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _isAllFilteredSelected
                                        ? 'Deselect All Filtered ($filteredCount)'
                                        : 'Select All Filtered ($filteredCount)',
                                    style: TextStyle(
                                      fontSize: isMobile ? 12 : 13,
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

                // Selectable Asset List (Paged)
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inventory_2_outlined,
                              size: 40, color: textMuted),
                          const SizedBox(height: 8),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No assets match your search.'
                                : 'No items registered under this section yet.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                      : ListView.separated(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 12 : 16,
                      vertical: 8,
                    ),
                    itemCount: paged.length,
                    separatorBuilder: (_, __) =>
                    const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final asset = paged[index];
                      final isSelected =
                      _selectedAssetIds.contains(asset.assetId);

                      return InkWell(
                        onTap: _isBusy
                            ? null
                            : () {
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
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? ParishColors.marianBlueSurface
                                .withOpacity(0.5)
                                : cardWhite,
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
                                onChanged: _isBusy
                                    ? null
                                    : (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedAssetIds.add(
                                        asset.assetId,
                                      );
                                    } else {
                                      _selectedAssetIds.remove(
                                        asset.assetId,
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
                                          asset.controlNumber,
                                          style: const TextStyle(
                                            fontFamily: 'Courier',
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
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: asset.unitPrice >=
                                                10000.0
                                                ? ParishColors.goldLight
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
                                                  ? ParishColors
                                                  .goldAccent
                                                  : ParishColors
                                                  .marianBlue,
                                            ),
                                          ),
                                        ),
                                        if (asset.quantity > 1) ...[
                                          const SizedBox(width: 4),
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
                                              '${asset.quantity} units',
                                              style: const TextStyle(
                                                fontSize: 8.5,
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
                                      asset.itemName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13.5,
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
                                    'Acq: ${asset.acquisitionYear}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: textMuted,
                                    ),
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

                // Pagination Toolbar
                if (filteredCount > 0)
                  _buildPaginationToolbar(filteredCount, isMobile),

                // Footer Actions: Cancel, Preview, and Print
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 14 : 20,
                    vertical: isMobile ? 10 : 14,
                  ),
                  decoration: BoxDecoration(
                    color: cardWhite,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(20),
                    ),
                    border: Border(top: BorderSide(color: borderGrey)),
                  ),
                  child: isMobile
                      ? _buildMobileFooter(selectedCount, textMuted, borderGrey)
                      : _buildDesktopFooter(selectedCount, textMuted, borderGrey),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // Filter Chip Helper
  // ===========================================================================

  Widget _buildActiveFilterChip(String label, VoidCallback onDeleted) {
    return Chip(
      label: Text(label, style: TextStyle(fontSize: 11, color: ParishColors.textDark)),
      backgroundColor: ParishColors.marianBlueSurface,
      deleteIcon: const Icon(Icons.close, size: 13),
      onDeleted: onDeleted,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }

  // ===========================================================================
  // Pagination Toolbar
  // ===========================================================================

  Widget _buildPaginationToolbar(int totalItems, bool isMobile) {
    final totalPages = _totalPages;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 14, vertical: 8),
      decoration: BoxDecoration(
        color: ParishColors.backgroundLight,
        border: Border(top: BorderSide(color: ParishColors.borderGrey)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text('Show: ',
                  style:
                  TextStyle(fontSize: 12, color: ParishColors.textMuted)),
              DropdownButton<int>(
                value: _itemsPerPage,
                isDense: true,
                underline: const SizedBox.shrink(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: ParishColors.marianBlue,
                ),
                items: const [
                  DropdownMenuItem(value: 10, child: Text('10')),
                  DropdownMenuItem(value: 25, child: Text('25')),
                  DropdownMenuItem(value: 50, child: Text('50')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _itemsPerPage = val;
                      _currentPage = 1;
                    });
                  }
                },
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 22),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: _currentPage > 1
                    ? ParishColors.marianBlue
                    : ParishColors.borderGrey,
                onPressed: _currentPage > 1
                    ? () => setState(() => _currentPage--)
                    : null,
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: ParishColors.cardWhite,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: ParishColors.borderGrey),
                ),
                child: Text(
                  'Page $_currentPage of $totalPages ($totalItems items)',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: ParishColors.marianBlue,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 22),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: _currentPage < totalPages
                    ? ParishColors.marianBlue
                    : ParishColors.borderGrey,
                onPressed: _currentPage < totalPages
                    ? () => setState(() => _currentPage++)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Responsive Desktop & Mobile Footers
  // ===========================================================================

  Widget _buildDesktopFooter(
      int selectedCount,
      Color textMuted,
      Color borderGrey,
      ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton(
          onPressed: _isBusy ? null : () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(color: textMuted, fontSize: 13),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: ParishColors.marianBlue,
                side: const BorderSide(color: ParishColors.marianBlue),
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
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
              label: const Text(
                'Preview Tags',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: selectedCount > 0
                    ? ParishColors.goldAccent
                    : ParishColors.borderGrey,
                foregroundColor: Colors.white,
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
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
                    ? 'Generating...'
                    : 'Print $selectedCount Tag(s)',
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

  Widget _buildMobileFooter(
      int selectedCount,
      Color textMuted,
      Color borderGrey,
      ) {
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
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: (_isBusy || selectedCount == 0)
                    ? null
                    : _previewSelectedLabels,
                icon: _isPreviewingPdf
                    ? const SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.visibility_outlined, size: 15),
                label: const Text(
                  'Preview',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: selectedCount > 0
                      ? ParishColors.goldAccent
                      : ParishColors.borderGrey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: (_isBusy || selectedCount == 0)
                    ? null
                    : _printSelectedLabels,
                icon: _isGeneratingPdf
                    ? const SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(Icons.print, size: 15),
                label: Text(
                  _isGeneratingPdf ? 'Printing...' : 'Print ($selectedCount)',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: _isBusy ? null : () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(color: textMuted, fontSize: 12),
          ),
        ),
      ],
    );
  }
}