import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../models/asset_model.dart';
import '../models/asset_reference_models.dart';
import '../services/asset_label_pdf_service.dart';
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
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _sectionTabController;

  List<AssetModel> _assets = [];
  List<AssetLocationModel> _locations = [];
  List<AssetClassificationModel> _classifications = [];

  bool _isLoading = true;
  String? _errorMessage;

  String _searchQuery = '';
  String _selectedCategory = 'All'; // Classification filter
  String _selectedLocation = 'All';
  String _selectedCondition = 'All';
  String _statusTab = 'Active'; // 'Active' or 'Archived'

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

  AssetViewMode _viewMode = AssetViewMode.cards;
  int _currentPage = 0;
  int _rowsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _sectionTabController = TabController(length: 3, vsync: this);
    _sectionTabController.addListener(() {
      if (!_sectionTabController.indexIsChanging) {
        setState(() {
          _currentPage = 0;
        });
      }
    });
    _loadAllData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _sectionTabController.dispose();
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
      final classifsFuture =
      AssetReferenceService.getClassifications(activeOnly: false);

      final results =
      await Future.wait([assetsFuture, locsFuture, classifsFuture]);

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

  List<AssetModel> get _filteredAssets {
    var list = _assets;

    // 1. Active vs Archived
    if (_statusTab == 'Active') {
      list = list.where((a) => !_isAssetArchived(a)).toList();
    } else {
      list = list.where((a) => _isAssetArchived(a)).toList();
    }

    // 2. Canonical Book Section Tabs
    if (_sectionTabController.index == 1) {
      list = list.where((a) => a.unitPrice >= 10000.0).toList();
    } else if (_sectionTabController.index == 2) {
      list = list.where((a) => a.unitPrice < 10000.0).toList();
    }

    // 3. Category / Classification Filter
    if (_selectedCategory != 'All') {
      list = list
          .where((a) =>
      a.classificationAcronym.toUpperCase() ==
          _selectedCategory.toUpperCase())
          .toList();
    }

    // 4. Location Filter
    if (_selectedLocation != 'All') {
      list = list
          .where((a) =>
      a.locationAcronym.toUpperCase() ==
          _selectedLocation.toUpperCase())
          .toList();
    }

    // 5. Condition Filter
    if (_selectedCondition != 'All') {
      list = list
          .where((a) =>
      a.conditionStatus.toUpperCase() ==
          _selectedCondition.toUpperCase())
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
    if (_statusTab != 'Active') count++;
    if (_sortBy != 'Control Number' || !_sortAscending) count++;
    return count;
  }

  bool get _hasActiveFilters => _activeFilterCount > 0;

  void _resetFilters() {
    setState(() {
      _selectedCategory = 'All';
      _selectedLocation = 'All';
      _selectedCondition = 'All';
      _statusTab = 'Active';
      _sortBy = 'Control Number';
      _sortAscending = true;
      _currentPage = 0;
    });
  }

  /// Opens the interactive tag selection dialog where the user chooses
  /// exactly which asset stickers to include on the A4 batch print sheet.
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

  /// Centralized Modal Filter Sheet containing Classification, Location, Condition, and Status
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
                  // Handle bar
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

                  // 1. Sort Section
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
                        tooltip: _sortAscending ? 'Ascending' : 'Descending',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 2. Active vs Archived Status Filter
                  Text('Registry Status',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: ParishColors.textDark)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Active Inventory')),
                          selected: _statusTab == 'Active',
                          selectedColor: ParishColors.marianBlue,
                          labelStyle: TextStyle(
                            color: _statusTab == 'Active'
                                ? Colors.white
                                : ParishColors.textDark,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          onSelected: (val) {
                            setState(() => _statusTab = 'Active');
                            setSheetState(() {});
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Archived / Decom')),
                          selected: _statusTab == 'Archived',
                          selectedColor: ParishColors.marianBlue,
                          labelStyle: TextStyle(
                            color: _statusTab == 'Archived'
                                ? Colors.white
                                : ParishColors.textDark,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          onSelected: (val) {
                            setState(() => _statusTab = 'Archived');
                            setSheetState(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 3. Classification Filter Dropdown
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

                  // 4. Location Filter Dropdown
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

                  // 5. Physical Condition Filter Dropdown
                  Text('Physical Condition',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: ParishColors.textDark)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _selectedCondition,
                    isExpanded: true,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'All', child: Text('All Conditions')),
                      DropdownMenuItem(
                          value: 'VERIFIED / GOOD',
                          child: Text('VERIFIED / GOOD')),
                      DropdownMenuItem(
                          value: 'REQUIRES REPAIR',
                          child: Text('REQUIRES REPAIR')),
                      DropdownMenuItem(
                          value: 'DAMAGED', child: Text('DAMAGED')),
                      DropdownMenuItem(
                          value: 'MISSING', child: Text('MISSING')),
                      DropdownMenuItem(
                          value: 'UNUSABLE', child: Text('UNUSABLE')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedCondition = val);
                        setSheetState(() {});
                      }
                    },
                  ),
                  const SizedBox(height: 18),

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

        return RefreshIndicator(
          onRefresh: _loadAllData,
          color: ParishColors.marianBlue,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 14 : 20,
              vertical: isMobile ? 12 : 18,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header Title & Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Parish Asset Inventory',
                            style: TextStyle(
                              fontSize: isMobile ? 18 : 22,
                              fontWeight: FontWeight.bold,
                              color: textDark,
                            ),
                          ),
                          Text(
                            'Manages parish assets, properties, and inventory records.',
                            style: TextStyle(color: textMuted, fontSize: 11.5),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
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

                // 2. Action Buttons: + Register as Primary, Field Audit as Prominent Companion
                Row(
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
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => showRegisterAssetModal(context,
                              onAssetSaved: _loadAllData),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text(
                            'Register Asset',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.bold),
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
                            side: const BorderSide(
                                color: ParishColors.marianBlue, width: 1.5),
                            foregroundColor: ParishColors.marianBlue,
                            backgroundColor: ParishColors.marianBlueSurface,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => showAuditScanModal(context,
                              onScanCompleted: _loadAllData),
                          icon: const Icon(Icons.qr_code_scanner, size: 18),
                          label: const Text(
                            'Field Audit',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 3. Compact 4-Pill Statistics Row
                _buildCompactStatsRow(),
                const SizedBox(height: 14),

                // 4. Compact Section Tabs (All Assets, Section 1, Section 2)
                Container(
                  height: 38,
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
                      color: ParishColors.marianBlue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    tabs: [
                      Tab(
                        child: Text(
                          'All (${_statusTab == "Active" ? _activeCount : _archivedCount})',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isMobile ? 11 : 12),
                        ),
                      ),
                      Tab(
                        child: Text(
                          isMobile
                              ? 'Sec 1 (≥₱10k)'
                              : 'Section 1 (≥₱10,000.00)',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isMobile ? 11 : 12),
                        ),
                      ),
                      Tab(
                        child: Text(
                          isMobile
                              ? 'Sec 2 (<₱10k)'
                              : 'Section 2 (<₱10,000.00)',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isMobile ? 11 : 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // 5. Full-Width Single-Line Search Bar
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
                            hintText: 'Search by Control #, name, location, RFID...',
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

                // 6. Secondary Toolbar: Filter & Sort Trigger + View Toggle
                Row(
                  children: [
                    // Unified "Filter & Sort" Modal Trigger
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

                    // Items Count Indicator
                    Text(
                      '$totalCount items',
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: textMuted),
                    ),
                    const SizedBox(width: 10),

                    // Card / Table View Toggle
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

                // Active Filter Summary Badges (If any active)
                if (_hasActiveFilters) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (_statusTab != 'Active')
                        _buildActiveFilterChip('Status: $_statusTab', () {
                          setState(() => _statusTab = 'Active');
                        }),
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
                      ActionChip(
                        label: const Text('Clear',
                            style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: ParishColors.mercyRed)),
                        backgroundColor: ParishColors.mercyRedSurface,
                        side: BorderSide(
                            color: ParishColors.mercyRed.withValues(alpha: 0.3)),
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        visualDensity: VisualDensity.compact,
                        onPressed: _resetFilters,
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),

                // 7. Content View (Cards vs Full-Width Table)
                if (_isLoading)
                  const Center(
                      child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator()))
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

                // 8. Pagination Footer
                if (totalCount > 0)
                  _buildPaginationFooter(
                      totalCount, totalPages, startIndex, endIndex),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // Compact 4-Pill Statistics Widget
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
              'Total',
              '$_activeCount',
              ParishColors.marianBlue,
            ),
          ),
          Container(width: 1, height: 20, color: ParishColors.borderGrey),
          Expanded(
            child: _buildCompactStatItem(
              'Sec 1',
              '$_section1Count',
              ParishColors.goldAccent,
            ),
          ),
          Container(width: 1, height: 20, color: ParishColors.borderGrey),
          Expanded(
            child: _buildCompactStatItem(
              'Sec 2',
              '$_section2Count',
              ParishColors.oliveGreen,
            ),
          ),
          Container(width: 1, height: 20, color: ParishColors.borderGrey),
          Expanded(
            child: _buildCompactStatItem(
              'Archived',
              '$_archivedCount',
              const Color(0xFF64748B),
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
  // Full-Width Responsive Table Layout
  // ===========================================================================

  Widget _buildFullWidthResponsiveTable(
      List<AssetModel> assets, double availableWidth) {
    final bool isWideDesktop = availableWidth >= 1100;

    if (isWideDesktop) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: ParishColors.cardWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ParishColors.borderGrey),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            columnWidths: const {
              0: FlexColumnWidth(1.8), // Control #
              1: FlexColumnWidth(2.2), // Asset Name
              2: FlexColumnWidth(0.6), // Qty
              3: FlexColumnWidth(2.0), // Classification
              4: FlexColumnWidth(1.3), // Location
              5: FlexColumnWidth(0.8), // Year
              6: FlexColumnWidth(1.4), // Price/Unit
              7: FlexColumnWidth(1.4), // Total Cost
              8: FlexColumnWidth(1.5), // Condition
              9: FlexColumnWidth(1.2), // Status
              10: FixedColumnWidth(80), // Action
            },
            children: [
              TableRow(
                decoration:
                BoxDecoration(color: ParishColors.marianBlueSurface),
                children: [
                  _buildHeaderCell('Control #', sortField: 'Control Number'),
                  _buildHeaderCell('Asset Name', sortField: 'Asset Name'),
                  _buildHeaderCell('Qty'),
                  _buildHeaderCell('Classification'),
                  _buildHeaderCell('Location'),
                  _buildHeaderCell('Year', sortField: 'Acquisition Year'),
                  _buildHeaderCell('Price / Unit', sortField: 'Price / Unit'),
                  _buildHeaderCell('Total Cost', sortField: 'Total Cost'),
                  _buildHeaderCell('Condition'),
                  _buildHeaderCell('Status'),
                  _buildHeaderCell('Action', align: TextAlign.center),
                ],
              ),
              ...assets.map((a) {
                return TableRow(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: ParishColors.borderGrey.withOpacity(0.4),
                      ),
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 12),
                      child: Text(
                        a.controlNumber,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: ParishColors.marianBlue,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 12),
                      child: Text(
                        a.itemName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 12),
                      child: Text('${a.quantity}',
                          style: const TextStyle(fontSize: 12.5)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 12),
                      child: Text(
                        a.displayClassification,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 12),
                      child: Text(
                        a.displayLocation,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 12),
                      child: Text('${a.acquisitionYear}',
                          style: const TextStyle(fontSize: 12)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 12),
                      child: Text(
                        a.formattedUnitPrice,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 12),
                      child: Text(
                        a.formattedTotalCost,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: ParishColors.oliveGreen,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: a.conditionSurfaceColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            a.conditionStatus,
                            style: TextStyle(
                              color: a.conditionColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 9.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: a.operationalStatus == 'Decommissioned'
                                ? ParishColors.mercyRedSurface
                                : ParishColors.backgroundLight,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            a.operationalStatus,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                              color: a.operationalStatus == 'Decommissioned'
                                  ? ParishColors.mercyRed
                                  : ParishColors.textDark,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 8),
                      child: Center(
                        child: IconButton(
                          icon: const Icon(Icons.visibility_outlined,
                              size: 18, color: ParishColors.marianBlue),
                          tooltip: 'View Details',
                          onPressed: () => showAssetDetailModal(context,
                              asset: a, onAssetUpdated: _loadAllData),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      );
    }

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
                DataColumn(
                  label: _buildSortableColumnLabel(
                      'Control Number', 'Control Number'),
                  onSort: (columnIndex, ascending) =>
                      _onSortChanged('Control Number'),
                ),
                DataColumn(
                  label:
                  _buildSortableColumnLabel('Asset Name', 'Asset Name'),
                  onSort: (columnIndex, ascending) =>
                      _onSortChanged('Asset Name'),
                ),
                const DataColumn(label: Text('Qty')),
                const DataColumn(label: Text('Classification')),
                const DataColumn(label: Text('Location')),
                DataColumn(
                  label: _buildSortableColumnLabel('Year', 'Acquisition Year'),
                  onSort: (columnIndex, ascending) =>
                      _onSortChanged('Acquisition Year'),
                ),
                DataColumn(
                  label:
                  _buildSortableColumnLabel('Price / Unit', 'Price / Unit'),
                  onSort: (columnIndex, ascending) =>
                      _onSortChanged('Price / Unit'),
                ),
                DataColumn(
                  label:
                  _buildSortableColumnLabel('Total Cost', 'Total Cost'),
                  onSort: (columnIndex, ascending) =>
                      _onSortChanged('Total Cost'),
                ),
                const DataColumn(label: Text('Condition')),
                const DataColumn(label: Text('Status')),
                const DataColumn(label: Text('Action')),
              ],
              rows: assets.map((a) {
                return DataRow(cells: [
                  DataCell(
                    Text(
                      a.controlNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: ParishColors.marianBlue,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      a.itemName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataCell(Text('${a.quantity}')),
                  DataCell(Text(a.displayClassification)),
                  DataCell(Text(a.displayLocation)),
                  DataCell(Text('${a.acquisitionYear}')),
                  DataCell(
                    Text(
                      a.formattedUnitPrice,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  DataCell(
                    Text(
                      a.formattedTotalCost,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: ParishColors.oliveGreen,
                      ),
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: a.operationalStatus == 'Decommissioned'
                            ? ParishColors.mercyRedSurface
                            : ParishColors.backgroundLight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        a.operationalStatus,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 10.5,
                          color: a.operationalStatus == 'Decommissioned'
                              ? ParishColors.mercyRed
                              : ParishColors.textDark,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    TextButton.icon(
                      style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact),
                      onPressed: () => showAssetDetailModal(context,
                          asset: a, onAssetUpdated: _loadAllData),
                      icon: const Icon(Icons.visibility, size: 14),
                      label: const Text('View',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold)),
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

  Widget _buildHeaderCell(String label,
      {String? sortField, TextAlign align = TextAlign.left}) {
    final bool isSorted = sortField != null && _sortBy == sortField;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: InkWell(
        onTap: sortField != null ? () => _onSortChanged(sortField) : null,
        child: Row(
          mainAxisAlignment: align == TextAlign.center
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                  color: ParishColors.marianBlue,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isSorted) ...[
              const SizedBox(width: 4),
              Icon(
                _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 13,
                color: ParishColors.marianBlue,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSortableColumnLabel(String label, String field) {
    final bool isSorted = _sortBy == field;
    return Row(
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
    );
  }

  Widget _buildPaginationFooter(
      int totalCount, int totalPages, int startIndex, int endIndex) {
    final cardWhite = ParishColors.cardWhite;
    final borderGrey = ParishColors.borderGrey;
    final textMuted = ParishColors.textMuted;
    final textDark = ParishColors.textDark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderGrey),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing ${startIndex + 1}–$endIndex of $totalCount items',
            style: TextStyle(fontSize: 12, color: textMuted),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.first_page, size: 20),
                onPressed:
                _currentPage > 0 ? () => setState(() => _currentPage = 0) : null,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 20),
                onPressed:
                _currentPage > 0 ? () => setState(() => _currentPage--) : null,
              ),
              Text(
                '${_currentPage + 1} / $totalPages',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: textDark),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 20),
                onPressed: _currentPage < totalPages - 1
                    ? () => setState(() => _currentPage++)
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.last_page, size: 20),
                onPressed: _currentPage < totalPages - 1
                    ? () => setState(() => _currentPage = totalPages - 1)
                    : null,
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
                ? 'No registered assets match your search.'
                : 'No assets registered under this inventory section yet.',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: ParishColors.textDark),
          ),
          const SizedBox(height: 4),
          Text('Tap "+ Register Asset" above to record parish properties.',
              style:
              TextStyle(fontSize: 12, color: ParishColors.textMuted)),
        ],
      ),
    );
  }
}