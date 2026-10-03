// =============================================================================
// FILE: lib/features/asset_inventory/presentation/asset_inventory_view.dart (PART 1 OF 2)
// =============================================================================

import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../models/asset_model.dart';
import '../models/asset_reference_models.dart';
import '../services/asset_reference_service.dart';
import '../services/asset_service.dart';
import 'dialogs/asset_detail_dialog.dart';
import 'dialogs/audit_scan_dialog.dart';
import 'dialogs/batch_print_tags_dialog.dart';
import 'dialogs/manage_asset_references_dialog.dart';
import 'dialogs/register_asset_dialog.dart';
import 'widgets/asset_item_card.dart';

enum AssetViewMode { cards, table }

class AssetInventoryView extends StatefulWidget {
  const AssetInventoryView({super.key});

  @override
  State<AssetInventoryView> createState() => _AssetInventoryViewState();
}

class _AssetInventoryViewState extends State<AssetInventoryView>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _sectionTabController;
  late AnimationController _skeletonAnimController;
  late Animation<double> _skeletonOpacityAnimation;

  List<AssetModel> _assets = [];
  List<AssetLocationModel> _locations = [];
  List<AssetClassificationModel> _classifications = [];

  bool _isLoading = true;
  String? _errorMessage;

  String _searchQuery = '';
  String _selectedCategory = 'All'; // Classification filter
  String _selectedLocation = 'All';
  String _selectedCondition = 'All';
  String _selectedOperationalStatus = 'All';

  // Sorting State
  String _sortBy = 'Control Number';
  bool _sortAscending = true;

  final List<String> _sortOptions = [
    'Control Number',
    'Asset Name',
    'Price / Unit',
    'Total Cost',
    'Acquisition Year',
    'Registration Date',
  ];

  final List<String> _conditionOptions = [
    'All',
    'VERIFIED / GOOD',
    'REQUIRES REPAIR',
    'DAMAGED',
    'MISSING',
    'UNUSABLE',
  ];

  final List<String> _operationalStatusOptions = [
    'All',
    'Active',
    'In Storage',
    'Under Maintenance',
  ];

  AssetViewMode _viewMode = AssetViewMode.cards;
  int _currentPage = 0;
  int _rowsPerPage = 10;

  @override
  void initState() {
    super.initState();
    // 4 Tabs: All Active, Section 1 (>=10k), Section 2 (<10k), Archived & Decom
    _sectionTabController = TabController(length: 4, vsync: this);
    _sectionTabController.addListener(() {
      if (!_sectionTabController.indexIsChanging) {
        setState(() {
          _currentPage = 0;
        });
      }
    });

    _skeletonAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _skeletonOpacityAnimation = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _skeletonAnimController, curve: Curves.easeInOut),
    );

    _loadAllData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _sectionTabController.dispose();
    _skeletonAnimController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final assetsFuture = AssetService.getAssets(includeArchived: true);
      final locsFuture = AssetReferenceService.getLocations(activeOnly: false);
      final classifs = AssetReferenceService.getClassifications(activeOnly: false);

      final results = await Future.wait([assetsFuture, locsFuture, classifs]);

      if (!mounted) return;
      setState(() {
        _assets = results[0] as List<AssetModel>;
        _locations = results[1] as List<AssetLocationModel>;
        _classifications = results[2] as List<AssetClassificationModel>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  bool _isAssetArchived(AssetModel a) {
    return a.isArchived ||
        a.operationalStatus.trim().toLowerCase() == 'decommissioned';
  }

  int _compareControlNumbers(String a, String b) {
    final aParts = a.split('-');
    final bParts = b.split('-');

    if (aParts.length >= 4 && bParts.length >= 4) {
      final prefixA = '${aParts[0]}-${aParts[1]}-${aParts[2]}';
      final prefixB = '${bParts[0]}-${bParts[1]}-${bParts[2]}';
      final prefixComp = prefixA.compareTo(prefixB);
      if (prefixComp != 0) return prefixComp;

      final seqA = int.tryParse(aParts[3]) ?? 0;
      final seqB = int.tryParse(bParts[3]) ?? 0;
      return seqA.compareTo(seqB);
    }
    return a.compareTo(b);
  }

  void _onSortChanged(String field) {
    setState(() {
      if (_sortBy == field) {
        _sortAscending = !_sortAscending;
      } else {
        _sortBy = field;
        _sortAscending = true;
      }
      _currentPage = 0;
    });
  }

  List<AssetModel> get _filteredAssets {
    var list = _assets;

    // 1. Tab Bar Segregation (Active Sections vs Dedicated Archive Tab)
    if (_sectionTabController.index == 3) {
      // Tab 3: Dedicated Archived & Decommissioned Quarantine
      list = list.where((a) => _isAssetArchived(a)).toList();
    } else {
      // Tabs 0, 1, 2: Active Inventory Only (Strictly Excludes Archived/Decom)
      list = list.where((a) => !_isAssetArchived(a)).toList();

      if (_sectionTabController.index == 1) {
        list = list.where((a) => a.unitPrice >= 10000.0).toList();
      } else if (_sectionTabController.index == 2) {
        list = list.where((a) => a.unitPrice < 10000.0).toList();
      }
    }

    // 2. Category / Classification Filter
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
      a.conditionStatus.toUpperCase() ==
          _selectedCondition.toUpperCase())
          .toList();
    }

    // 5. Operational Status Filter (Active Tab only)
    if (_sectionTabController.index != 3 && _selectedOperationalStatus != 'All') {
      list = list
          .where((a) =>
      a.operationalStatus.toLowerCase() ==
          _selectedOperationalStatus.toLowerCase())
          .toList();
    }

    // 6. Search Query (Searches control number, name, child items, RFID, model)
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      list = list.where((a) {
        final matchesGroup = a.controlNumber.toLowerCase().contains(q) ||
            a.itemName.toLowerCase().contains(q) ||
            (a.model ?? '').toLowerCase().contains(q) ||
            (a.color ?? '').toLowerCase().contains(q) ||
            (a.rfidTag ?? '').toLowerCase().contains(q) ||
            a.displayLocation.toLowerCase().contains(q) ||
            a.displayClassification.toLowerCase().contains(q);

        final matchesChild = a.childItems.any((child) =>
        child.controlNumber.toLowerCase().contains(q) ||
            child.itemName.toLowerCase().contains(q) ||
            (child.rfidTag ?? '').toLowerCase().contains(q));

        return matchesGroup || matchesChild;
      }).toList();
    }

    // 7. Sort Order
    list.sort((a, b) {
      int comparison = 0;
      switch (_sortBy) {
        case 'Control Number':
          comparison = _compareControlNumbers(a.controlNumber, b.controlNumber);
          break;
        case 'Asset Name':
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

  int get _activeCount => _assets.where((a) => !_isAssetArchived(a)).length;
  int get _archivedCount => _assets.where((a) => _isAssetArchived(a)).length;

  int get _section1Count =>
      _assets.where((a) => !_isAssetArchived(a) && a.unitPrice >= 10000.0).length;

  int get _section2Count =>
      _assets.where((a) => !_isAssetArchived(a) && a.unitPrice < 10000.0).length;

  int get _activeFilterCount {
    int count = 0;
    if (_selectedCategory != 'All') count++;
    if (_selectedLocation != 'All') count++;
    if (_selectedCondition != 'All') count++;
    if (_selectedOperationalStatus != 'All' && _sectionTabController.index != 3) count++;
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
      _currentPage = 0;
    });
  }

  void _openBatchPrintSelectionModal() {
    final list = _filteredAssets;
    if (list.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No assets available to print under the current filter.'),
          backgroundColor: ParishColors.goldAccent,
        ),
      );
      return;
    }

    showBatchPrintTagsModal(
      context,
      availableAssets: list,
    );
  }

  void _openManageReferences() {
    showManageAssetReferencesModal(
      context,
      onReferencesUpdated: _loadAllData,
    );
  }

  // ===========================================================================
  // Filter & Sort Bottom Sheet (All-in-One Engine)
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
                        'Filter & Sort Inventory',
                        style: TextStyle(
                          fontSize: 17,
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
                          child: const Text('Reset All',
                              style: TextStyle(
                                  color: ParishColors.mercyRed,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                        ),
                    ],
                  ),
                  const Divider(height: 14),

                  // 1. Sort Sequence
                  Text('Sort Sequence',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: ParishColors.textDark)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _sortBy,
                          isExpanded: true,
                          decoration: InputDecoration(
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

                  // 2. Classification Filter
                  Text('Property Classification',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: ParishColors.textDark)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    isExpanded: true,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: 'All', child: Text('All Classifications')),
                      ..._classifications.map((c) => DropdownMenuItem(
                          value: c.acronym,
                          child: Text('${c.classificationName} (${c.acronym})'))),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedCategory = val);
                        setSheetState(() {});
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  // 3. Storage Location Filter
                  Text('Storage Location',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: ParishColors.textDark)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _selectedLocation,
                    isExpanded: true,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: 'All', child: Text('All Locations')),
                      ..._locations.map((l) => DropdownMenuItem(
                          value: l.acronym,
                          child: Text('${l.locationName} (${l.acronym})'))),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedLocation = val);
                        setSheetState(() {});
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  // 4. Physical Condition Filter
                  Text('Physical Condition',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: ParishColors.textDark)),
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
                              color: isSelected ? Colors.white : ParishColors.textDark,
                              fontWeight: FontWeight.bold,
                              fontSize: 11.5,
                            ),
                            onSelected: (_) {
                              setState(() => _selectedCondition = cond);
                              setSheetState(() {});
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 5. Operational Status Filter (Only when in active tabs)
                  if (_sectionTabController.index != 3) ...[
                    Text('Operational Status',
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: ParishColors.textDark)),
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
                                color: isSelected ? Colors.white : ParishColors.textDark,
                                fontWeight: FontWeight.bold,
                                fontSize: 11.5,
                              ),
                              onSelected: (_) {
                                setState(() => _selectedOperationalStatus = st);
                                setSheetState(() {});
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],

                  // Apply & Close
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
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // Build Method (Anchored to Top on Desktop)
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final cardWhite = ParishColors.cardWhite;
    final borderGrey = ParishColors.borderGrey;

    final filtered = _filteredAssets;
    final totalCount = filtered.length;
    final int totalPages =
    (totalCount / _rowsPerPage).ceil() > 0 ? (totalCount / _rowsPerPage).ceil() : 1;
    if (_currentPage >= totalPages) _currentPage = totalPages > 0 ? totalPages - 1 : 0;

    final startIndex = _currentPage * _rowsPerPage;
    final endIndex = (startIndex + _rowsPerPage > totalCount)
        ? totalCount
        : startIndex + _rowsPerPage;
    final paged = (startIndex >= totalCount)
        ? <AssetModel>[]
        : filtered.sublist(startIndex, endIndex);

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 650;
        final double viewportHeight = constraints.hasBoundedHeight ? constraints.maxHeight : 0.0;

        // Container explicitly claims available height on desktop and anchors child to topCenter
        return Container(
          width: double.infinity,
          height: constraints.hasBoundedHeight ? constraints.maxHeight : null,
          alignment: Alignment.topCenter,
          child: RefreshIndicator(
            onRefresh: _loadAllData,
            color: ParishColors.marianBlue,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 14 : 20,
                vertical: isMobile ? 12 : 18,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: max(0.0, viewportHeight - (isMobile ? 24 : 36)),
                  minWidth: double.infinity,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    // 1. Header Title & Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Parish Asset Inventory',
                            style: TextStyle(
                              fontSize: isMobile ? 18 : 22,
                              fontWeight: FontWeight.bold,
                              color: textDark,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.print_outlined,
                              color: ParishColors.goldAccent, size: 20),
                          tooltip: 'Select & Print Tags (Batch)',
                          onPressed: _openBatchPrintSelectionModal,
                        ),
                        IconButton(
                          icon: const Icon(Icons.settings_suggest_outlined,
                              color: ParishColors.marianBlue, size: 20),
                          tooltip: 'Manage Locations & Classifications',
                          onPressed: _openManageReferences,
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh,
                              color: ParishColors.marianBlue, size: 20),
                          tooltip: 'Reload Records',
                          onPressed: _loadAllData,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 2. Primary Action Buttons
                    _buildActionButtons(isMobile),
                    const SizedBox(height: 12),

                    // 3. Compact Stats Bar
                    _buildCompactStatsRow(),
                    const SizedBox(height: 14),

                    // 4. TabBar (All Active, Sec I, Sec II, Archived/Decom)
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: cardWhite,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderGrey),
                      ),
                      child: TabBar(
                        controller: _sectionTabController,
                        labelColor: Colors.white,
                        unselectedLabelColor: textMuted,
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
                              isMobile ? 'Active ($_activeCount)' : 'All Active ($_activeCount)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 10.5 : 11.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Tab(
                            child: Text(
                              isMobile ? 'Sec I ($_section1Count)' : 'Sec 1 (≥₱10k) ($_section1Count)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 10.5 : 11.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Tab(
                            child: Text(
                              isMobile ? 'Sec II ($_section2Count)' : 'Sec 2 (<₱10k) ($_section2Count)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 10.5 : 11.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Tab(
                            child: Text(
                              isMobile ? 'Archived ($_archivedCount)' : 'Archived & Decom ($_archivedCount)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 10.5 : 11.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 5. Search Bar (Compact 44dp height)
                    Container(
                      width: double.infinity,
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: cardWhite,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderGrey),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search,
                              size: 20, color: ParishColors.marianBlue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: (val) => setState(() {
                                _searchQuery = val;
                                _currentPage = 0;
                              }),
                              style: TextStyle(fontSize: 13, color: textDark),
                              decoration: InputDecoration(
                                hintText: 'Search by Control #, group name, RFID...',
                                hintStyle:
                                TextStyle(fontSize: 12, color: textMuted),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
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
                                setState(() {
                                  _searchQuery = '';
                                  _currentPage = 0;
                                });
                              },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 6. Filter & Sort Bar with View Mode Switcher
                    Row(
                      children: [
                        InkWell(
                          onTap: _openFilterAndSortBottomSheet,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            height: 36,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: _hasActiveFilters
                                  ? ParishColors.marianBlueSurface
                                  : cardWhite,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _hasActiveFilters
                                    ? ParishColors.marianBlue
                                    : borderGrey,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.tune,
                                  size: 15,
                                  color: _hasActiveFilters
                                      ? ParishColors.marianBlue
                                      : textMuted,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _hasActiveFilters
                                      ? 'Filter & Sort ($_activeFilterCount)'
                                      : 'Filter & Sort',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: _hasActiveFilters
                                        ? ParishColors.marianBlue
                                        : textDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '$totalCount items',
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: textMuted),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          height: 32,
                          decoration: BoxDecoration(
                            color: cardWhite,
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(color: borderGrey),
                          ),
                          child: ToggleButtons(
                            isSelected: [
                              _viewMode == AssetViewMode.cards,
                              _viewMode == AssetViewMode.table
                            ],
                            onPressed: (idx) => setState(() => _viewMode =
                            idx == 0 ? AssetViewMode.cards : AssetViewMode.table),
                            borderRadius: BorderRadius.circular(6),
                            selectedColor: Colors.white,
                            fillColor: ParishColors.marianBlue,
                            color: textMuted,
                            constraints:
                            const BoxConstraints(minHeight: 28, minWidth: 32),
                            children: const [
                              Tooltip(
                                  message: 'Card View',
                                  child: Icon(Icons.grid_view, size: 14)),
                              Tooltip(
                                  message: 'Table View',
                                  child: Icon(Icons.table_chart, size: 14)),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // 7. Active Filter Chips Row
                    if (_hasActiveFilters) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (_selectedCategory != 'All')
                            _buildActiveFilterChip('Cat: $_selectedCategory', () {
                              setState(() => _selectedCategory = 'All');
                            }),
                          if (_selectedLocation != 'All')
                            _buildActiveFilterChip('Loc: $_selectedLocation', () {
                              setState(() => _selectedLocation = 'All');
                            }),
                          if (_selectedCondition != 'All')
                            _buildActiveFilterChip('Cond: $_selectedCondition', () {
                              setState(() => _selectedCondition = 'All');
                            }),
                          if (_selectedOperationalStatus != 'All' && _sectionTabController.index != 3)
                            _buildActiveFilterChip('Status: $_selectedOperationalStatus', () {
                              setState(() => _selectedOperationalStatus = 'All');
                            }),
                          if (_sortBy != 'Control Number' || !_sortAscending)
                            _buildActiveFilterChip('Sorted: $_sortBy', () {
                              setState(() {
                                _sortBy = 'Control Number';
                                _sortAscending = true;
                              });
                            }),
                          ActionChip(
                            label: const Text('Clear',
                                style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: ParishColors.mercyRed)),
                            backgroundColor: ParishColors.mercyRedSurface,
                            side: BorderSide(
                                color: ParishColors.mercyRed.withOpacity(0.3)),
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            visualDensity: VisualDensity.compact,
                            onPressed: _resetFilters,
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),

                    // 8. Main Content View / Anti-Shift Skeleton Loader
                    if (_isLoading)
                      _buildSkeletonLoading(constraints.maxWidth)
                    else if (_errorMessage != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                            color: ParishColors.mercyRedSurface,
                            borderRadius: BorderRadius.circular(10)),
                        child: Text('Error: $_errorMessage',
                            style: const TextStyle(color: ParishColors.mercyRed)),
                      )
                    else if (totalCount == 0)
                        _buildEmptyState()
                      else if (_viewMode == AssetViewMode.cards)
                          ...paged.map(
                                  (a) => AssetItemCard(asset: a, onRefresh: _loadAllData))
                        else
                          _buildFullWidthResponsiveTable(paged, constraints.maxWidth),

                    const SizedBox(height: 14),
                    if (totalCount > 0 && !_isLoading)
                      _buildPaginationFooter(
                          totalCount, totalPages, startIndex, endIndex),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

// --- END OF PART 1 ---

// =============================================================================
// FILE: lib/features/asset_inventory/presentation/asset_inventory_view.dart (PART 2 OF 2)
// =============================================================================

  // ===========================================================================
  // Top Action Buttons
  // ===========================================================================
  Widget _buildActionButtons(bool isMobile) {
    return isMobile
        ? Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: ParishColors.oliveGreen,
              foregroundColor: Colors.white,
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => showRegisterAssetModal(context, onAssetSaved: _loadAllData),
            icon: const Icon(Icons.add, size: 18),
            label: const Text(
              '+ Register Asset / Group',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: ParishColors.marianBlue, width: 1.5),
              foregroundColor: ParishColors.marianBlue,
              backgroundColor: ParishColors.marianBlueSurface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => showAuditScanModal(context, onScanCompleted: _loadAllData),
            icon: const Icon(Icons.qr_code_scanner, size: 18),
            label: const Text(
              'Field Audit Scanner',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    )
        : Row(
      children: [
        Expanded(
          flex: 5,
          child: SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: ParishColors.oliveGreen,
                foregroundColor: Colors.white,
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => showRegisterAssetModal(context, onAssetSaved: _loadAllData),
              icon: const Icon(Icons.add, size: 18),
              label: const Text(
                'Register Asset / Group',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 5,
          child: SizedBox(
            height: 44,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: ParishColors.marianBlue, width: 1.5),
                foregroundColor: ParishColors.marianBlue,
                backgroundColor: ParishColors.marianBlueSurface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => showAuditScanModal(context, onScanCompleted: _loadAllData),
              icon: const Icon(Icons.qr_code_scanner, size: 18),
              label: const Text(
                'Field Audit',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // Compact Stats Row (Matching Appointments & Receipts Modules)
  // ===========================================================================
  Widget _buildCompactStatsRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ParishColors.borderGrey),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildCompactStatItem(
              'Total Active',
              '$_activeCount',
              ParishColors.marianBlue,
            ),
          ),
          Container(width: 1, height: 20, color: ParishColors.borderGrey),
          Expanded(
            child: _buildCompactStatItem(
              'Sec I (≥₱10k)',
              '$_section1Count',
              ParishColors.goldAccent,
            ),
          ),
          Container(width: 1, height: 20, color: ParishColors.borderGrey),
          Expanded(
            child: _buildCompactStatItem(
              'Sec II (<₱10k)',
              '$_section2Count',
              ParishColors.oliveGreen,
            ),
          ),
          Container(width: 1, height: 20, color: ParishColors.borderGrey),
          Expanded(
            child: _buildCompactStatItem(
              'Archived',
              '$_archivedCount',
              ParishColors.mercyRed,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStatItem(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: ParishColors.textMuted,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildActiveFilterChip(String label, VoidCallback onDeleted) {
    return Chip(
      label: Text(label,
          style: TextStyle(fontSize: 10, color: ParishColors.textDark)),
      backgroundColor: ParishColors.marianBlueSurface,
      deleteIcon: const Icon(Icons.close, size: 12),
      onDeleted: onDeleted,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  // ===========================================================================
  // Anti-Layout-Shift Skeleton Loader
  // ===========================================================================
  Widget _buildSkeletonLoading(double availableWidth) {
    return AnimatedBuilder(
      animation: _skeletonOpacityAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _skeletonOpacityAnimation.value,
          child: Column(
            children: List.generate(4, (index) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                height: 96,
                decoration: BoxDecoration(
                  color: ParishColors.cardWhite,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ParishColors.borderGrey.withOpacity(0.4)),
                ),
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: ParishColors.borderGrey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            height: 14,
                            width: 160,
                            decoration: BoxDecoration(
                              color: ParishColors.borderGrey.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 16,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: ParishColors.borderGrey.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 12,
                            width: 200,
                            decoration: BoxDecoration(
                              color: ParishColors.borderGrey.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // Responsive DataTable View (Full Width with Horizontal Scroll)
  // ===========================================================================
  Widget _buildFullWidthResponsiveTable(
      List<AssetModel> assets, double availableWidth) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ParishColors.borderGrey),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: max(availableWidth, 980)),
            child: DataTable(
              headingRowColor:
              WidgetStateProperty.all(ParishColors.marianBlueSurface),
              headingTextStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                color: ParishColors.marianBlue,
                fontSize: 12.5,
              ),
              dataTextStyle: TextStyle(
                fontSize: 12.5,
                color: ParishColors.textDark,
              ),
              columnSpacing: 18,
              horizontalMargin: 16,
              columns: [
                DataColumn(label: _buildSortableColumnLabel('Control Number', 'Control Number')),
                DataColumn(label: _buildSortableColumnLabel('Asset Name / Group', 'Asset Name')),
                const DataColumn(label: Text('Qty')),
                const DataColumn(label: Text('Classification')),
                const DataColumn(label: Text('Location')),
                DataColumn(label: _buildSortableColumnLabel('Year', 'Acquisition Year')),
                DataColumn(label: _buildSortableColumnLabel('Price / Unit', 'Price / Unit')),
                DataColumn(label: _buildSortableColumnLabel('Total Cost', 'Total Cost')),
                const DataColumn(label: Text('Condition')),
                const DataColumn(label: Text('Status')),
                const DataColumn(label: Text('Action')),
              ],
              rows: assets.map((a) {
                final bool isDecom = a.operationalStatus == 'Decommissioned' || a.isArchived;

                return DataRow(cells: [
                  DataCell(
                    Text(
                      a.controlNumber,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDecom ? ParishColors.mercyRed : ParishColors.marianBlue,
                      ),
                    ),
                  ),
                  DataCell(
                    Row(
                      children: [
                        Text(
                          a.isPropertyGroup ? a.itemName.replaceAll(RegExp(r'\s*(—|-)?\s*\d{3}$'), '').trim() : a.itemName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (a.isPropertyGroup) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: ParishColors.marianBlueSurface,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              '(${a.quantity})',
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: ParishColors.marianBlue),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  DataCell(Text('${a.quantity}')),
                  DataCell(Text(a.displayClassification)),
                  DataCell(Text(a.displayLocation)),
                  DataCell(Text('${a.acquisitionYear}')),
                  DataCell(Text(a.formattedUnitPrice, style: const TextStyle(fontWeight: FontWeight.bold))),
                  DataCell(Text(a.formattedTotalCost, style: const TextStyle(fontWeight: FontWeight.bold, color: ParishColors.oliveGreen))),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: a.conditionSurfaceColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        a.conditionStatus,
                        style: TextStyle(
                          color: a.conditionColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDecom
                            ? ParishColors.mercyRedSurface
                            : ParishColors.backgroundLight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isDecom ? 'DECOMMISSIONED' : a.operationalStatus,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 10.5,
                          color: isDecom
                              ? ParishColors.mercyRed
                              : ParishColors.textDark,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    TextButton.icon(
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      onPressed: () => showAssetDetailModal(context,
                          asset: a, onAssetUpdated: _loadAllData),
                      icon: const Icon(Icons.visibility, size: 14),
                      label: const Text('View',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ]);
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSortableColumnLabel(String label, String field) {
    final bool isSorted = _sortBy == field;
    return InkWell(
      onTap: () => _onSortChanged(field),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (isSorted) ...[
            const SizedBox(width: 4),
            Icon(
              _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 14,
              color: ParishColors.marianBlue,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaginationFooter(
      int totalCount, int totalPages, int startIndex, int endIndex) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ParishColors.borderGrey),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing ${startIndex + 1}–$endIndex of $totalCount items',
            style: TextStyle(fontSize: 12, color: ParishColors.textMuted),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.first_page, size: 20),
                onPressed: _currentPage > 0 ? () => setState(() => _currentPage = 0) : null,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 20),
                onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
              ),
              Text(
                '${_currentPage + 1} / $totalPages',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ParishColors.textDark),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 20),
                onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
              ),
              IconButton(
                icon: const Icon(Icons.last_page, size: 20),
                onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage = totalPages - 1) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ParishColors.borderGrey),
      ),
      child: Column(
        children: [
          Icon(Icons.inventory_2_outlined, size: 48, color: ParishColors.borderGrey),
          const SizedBox(height: 12),
          Text(
            _searchQuery.isNotEmpty
                ? 'No registered assets or groups match your search.'
                : 'No assets registered under this inventory section yet.',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: ParishColors.textDark),
          ),
          const SizedBox(height: 4),
          Text('Tap "+ Register Asset / Group" above to record parish properties.',
              style: TextStyle(fontSize: 12, color: ParishColors.textMuted)),
        ],
      ),
    );
  }
}