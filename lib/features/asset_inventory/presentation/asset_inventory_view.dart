// =============================================================================
// FILE: lib/features/asset_inventory/presentation/asset_inventory_view.dart
// =============================================================================

import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/services/records_sync_service.dart';
import '../models/asset_model.dart';
import '../models/asset_reference_models.dart';
import '../services/asset_reference_service.dart';
import '../services/asset_service.dart';
import 'dialogs/asset_report_filter_dialog.dart';
import 'pages/asset_audit_scanner_page.dart';
import 'pages/asset_batch_print_page.dart';
import 'pages/asset_detail_page.dart';
import 'pages/asset_references_page.dart';
import 'pages/register_asset_page.dart';
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
  final FocusNode _searchFocusNode = FocusNode();
  late TabController _sectionTabController;
  late AnimationController _skeletonAnimController;
  late Animation<double> _skeletonOpacityAnimation;

  List<AssetModel> _assets = [];
  List<AssetLocationModel> _locations = [];
  List<AssetClassificationModel> _classifications = [];

  bool _isLoading = true;
  String? _errorMessage;

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

  // Standardized Canonical Condition Options
  final List<String> _conditionOptions = [
    'All',
    ...AssetModel.standardConditions,
  ];

  // Standardized Canonical Status Options
  final List<String> _operationalStatusOptions = [
    'All',
    ...AssetModel.standardStatuses,
  ];

  AssetViewMode _viewMode = AssetViewMode.cards;

  // Standardized 1-Indexed Pagination State
  int _currentPage = 1;
  int _itemsPerPage = 10;

  @override
  void initState() {
    super.initState();
    // 4 Tabs: All Active, Section I Assets (>=10k), Section II Assets (<10k), Archived
    _sectionTabController = TabController(length: 4, vsync: this);
    _sectionTabController.addListener(() {
      if (!_sectionTabController.indexIsChanging) {
        setState(() {
          _currentPage = 1;
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

    RecordsSyncService.instance.checkConnectivity();
    RecordsSyncService.instance.updatePendingCount();
    _loadAllData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
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
    return a.isEffectivelyArchived;
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
      _currentPage = 1;
    });
  }

  // ===========================================================================
  // Data Filtering & Tab Segregation
  // ===========================================================================

  List<AssetModel> get _filteredAssets {
    var list = _assets;

    // 1. Tab Bar Segregation (Active Sections vs Dedicated Archive Tab)
    if (_sectionTabController.index == 3) {
      list = list.where((a) => _isAssetArchived(a)).toList();
    } else {
      list = list.where((a) => !_isAssetArchived(a)).toList();

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

    // 3. Storage Location Filter
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
      AssetModel.normalizeCondition(a.conditionStatus)
          .toLowerCase() ==
          _selectedCondition.toLowerCase())
          .toList();
    }

    // 5. Operational Status Filter (Active Tab only)
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

    // 7. Sort Order
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

  // ===========================================================================
  // Summary Counts
  // ===========================================================================

  int get _activeCount => _assets.where((a) => !_isAssetArchived(a)).length;
  int get _archivedCount => _assets.where((a) => _isAssetArchived(a)).length;

  int get _section1Count =>
      _assets.where((a) => !_isAssetArchived(a) && a.unitPrice >= 10000.0).length;

  int get _section2Count =>
      _assets.where((a) => !_isAssetArchived(a) && a.unitPrice < 10000.0).length;

  int get _needsAttentionCount => _assets.where((a) {
    if (_isAssetArchived(a)) return false;
    final c = AssetModel.normalizeCondition(a.conditionStatus);
    return c == 'Poor' || c == 'Damaged' || c == 'Unserviceable';
  }).length;

  int get _totalPages {
    final total = _filteredAssets.length;
    if (total == 0) return 1;
    return (total / _itemsPerPage).ceil();
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

  // ===========================================================================
  // Navigation Handlers
  // ===========================================================================

  void _openRegisterAssetPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RegisterAssetPage(onAssetSaved: _loadAllData),
      ),
    );
  }

  void _openAuditScannerPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AssetAuditScannerPage(onScanCompleted: _loadAllData),
      ),
    );
  }

  void _openBatchPrintPage() {
    final list = _filteredAssets;
    if (list.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No items match the current filter to print tags.'),
          backgroundColor: ParishColors.goldAccent,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AssetBatchPrintPage(availableAssets: list),
      ),
    );
  }

  void _openReportGeneratorDialog() {
    showAssetReportFilterModal(context, allAssets: _assets);
  }

  void _openManageReferencesPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AssetReferencesPage(onReferencesUpdated: _loadAllData),
      ),
    );
  }

  void _openAssetDetailPage(AssetModel asset, int indexInFiltered) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AssetDetailPage(
          assets: _filteredAssets,
          initialIndex: indexInFiltered,
          onAssetUpdated: _loadAllData,
        ),
      ),
    );
  }

  // ===========================================================================
  // Filter & Sort Bottom Sheet
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
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: 'All', child: Text('All Categories')),
                      ..._classifications.map((c) => DropdownMenuItem(
                          value: c.acronym,
                          child: Text('${c.classificationName} (${c.acronym})'))),
                    ],
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
                        setState(() {
                          _selectedLocation = val;
                          _currentPage = 1;
                        });
                        setSheetState(() {});
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  // 4. Item Condition Filter (Standardized)
                  Text(
                    'Item Physical Condition',
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

                  // 5. Item Operational Status Filter (Standardized)
                  if (_sectionTabController.index != 3) ...[
                    Text(
                      'Operational Status',
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

                  // Apply & Close Button
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
  // Hero Header with Sync Status Ribbon
  // ===========================================================================

  Widget _buildHeroHeader(bool isMobile) {
    final fade = ParishColors.cardWhite;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'images/jp2-bg.png',
              fit: BoxFit.cover,
              alignment: const Alignment(0.35, -0.55),
              errorBuilder: (_, __, ___) =>
                  Container(color: ParishColors.marianBlueSurface),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    fade.withOpacity(0.96),
                    fade.withOpacity(isMobile ? 0.88 : 0.80),
                    fade.withOpacity(isMobile ? 0.25 : 0.0),
                  ],
                  stops: [0.0, isMobile ? 0.62 : 0.45, isMobile ? 1.0 : 0.85],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, fade.withOpacity(0.55)],
                  stops: const [0.55, 1.0],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
                isMobile ? 16 : 24, isMobile ? 16 : 22, isMobile ? 12 : 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 56,
                            height: 3,
                            decoration: BoxDecoration(
                              color: ParishColors.goldAccent,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Parish Asset Inventory',
                            style: TextStyle(
                              fontFamily: 'Georgia',
                              fontFamilyFallback: const ['Times New Roman', 'serif'],
                              fontSize: isMobile ? 24 : 38,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                              color: ParishColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$_activeCount active items tracked across parish locations and facilities',
                            style: TextStyle(
                              fontSize: isMobile ? 12.0 : 14,
                              fontStyle: FontStyle.italic,
                              color: ParishColors.textDark.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildOverflowMenu(),
                  ],
                ),
                SizedBox(height: isMobile ? 28 : 50),
                _buildSyncStatusBar(isMobile),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverflowMenu() {
    return Container(
      decoration: BoxDecoration(
        color: ParishColors.cardWhite.withOpacity(0.9),
        shape: BoxShape.circle,
        border: Border.all(color: ParishColors.borderGrey),
      ),
      child: PopupMenuButton<String>(
        icon: Icon(Icons.more_vert, color: ParishColors.textMuted, size: 22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: ParishColors.cardWhite,
        onSelected: (val) {
          if (val == 'reports') {
            _openReportGeneratorDialog();
          } else if (val == 'references') {
            _openManageReferencesPage();
          } else if (val == 'scanner') {
            _openAuditScannerPage();
          } else if (val == 'batch_print') {
            _openBatchPrintPage();
          } else if (val == 'refresh') {
            _loadAllData();
            RecordsSyncService.instance.checkConnectivity();
          }
        },
        itemBuilder: (ctx) => [
          const PopupMenuItem(
            value: 'reports',
            child: Row(
              children: [
                Icon(Icons.picture_as_pdf_outlined,
                    size: 18, color: ParishColors.marianBlue),
                SizedBox(width: 10),
                Text('Generate PDF Reports',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'references',
            child: Row(
              children: [
                Icon(Icons.tune, size: 18, color: ParishColors.marianBlue),
                SizedBox(width: 10),
                Text('Locations & Classifications',
                    style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'scanner',
            child: Row(
              children: [
                Icon(Icons.qr_code_scanner,
                    size: 18, color: ParishColors.oliveGreen),
                SizedBox(width: 10),
                Text('Open Audit Scanner', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'batch_print',
            child: Row(
              children: [
                Icon(Icons.print_outlined,
                    size: 18, color: ParishColors.goldAccent),
                SizedBox(width: 10),
                Text('Batch Print Tags', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'refresh',
            child: Row(
              children: [
                Icon(Icons.refresh, size: 18),
                SizedBox(width: 10),
                Text('Reload Ledger', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncStatusBar(bool isMobile) {
    return ValueListenableBuilder<RecordsSyncStatus>(
      valueListenable: RecordsSyncService.syncStatusNotifier,
      builder: (context, status, _) {
        return ValueListenableBuilder<int>(
          valueListenable: RecordsSyncService.pendingSyncCountNotifier,
          builder: (context, pendingCount, _) {
            Color pillColor;
            Color textColor;
            IconData statusIcon;
            String statusLabel;

            if (status == RecordsSyncStatus.offline) {
              pillColor = Colors.amber.shade50;
              textColor = Colors.amber.shade900;
              statusIcon = Icons.cloud_off;
              statusLabel = pendingCount > 0
                  ? 'Offline • Working Locally ($pendingCount pending)'
                  : 'Offline • Working Locally';
            } else if (status == RecordsSyncStatus.syncing) {
              pillColor = Colors.blue.shade50;
              textColor = Colors.blue.shade900;
              statusIcon = Icons.sync;
              statusLabel = 'Syncing inventory ledger with Supabase cloud...';
            } else if (pendingCount > 0) {
              pillColor = Colors.orange.shade50;
              textColor = Colors.orange.shade900;
              statusIcon = Icons.upload_file;
              statusLabel =
              'Online • $pendingCount asset change(s) queued (Tap to Sync Now)';
            } else {
              pillColor = const Color(0xFFE8F5E9);
              textColor = const Color(0xFF2E7D32);
              statusIcon = Icons.check_circle;
              statusLabel =
              'Online • Property ledger & QR codes synchronized';
            }

            final canSync =
                pendingCount > 0 && status != RecordsSyncStatus.syncing;

            return InkWell(
              onTap: canSync
                  ? () => RecordsSyncService.instance.syncPendingChanges()
                  : null,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: pillColor.withOpacity(0.94),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: textColor.withOpacity(0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(statusIcon, size: 18, color: textColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                            fontSize: 12.0,
                            fontWeight: FontWeight.w700,
                            color: textColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!isMobile)
                      ValueListenableBuilder<DateTime?>(
                        valueListenable:
                        RecordsSyncService.lastSyncedAtNotifier,
                        builder: (context, lastSync, _) {
                          final text = lastSync != null
                              ? lastSync.toLocal().toString().substring(0, 16)
                              : 'Never';
                          return Padding(
                            padding: const EdgeInsets.only(left: 10),
                            child: Text(
                              'Last sync: $text',
                              style: TextStyle(
                                  fontSize: 11.5,
                                  color: textColor.withOpacity(0.85)),
                            ),
                          );
                        },
                      ),
                    const SizedBox(width: 10),
                    Icon(Icons.refresh, size: 17, color: textColor),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // Action Cards Toolbar
  // ===========================================================================

  Widget _buildActionCardsRow(bool isDesktop, bool isMobile) {
    final registerCard = _buildDashboardActionCard(
      title: 'Register Item',
      subtitle: isMobile
          ? 'Add property or fixtures'
          : 'Add property, vestments & fixtures',
      icon: Icons.post_add,
      isSolidBlue: true,
      isMobile: isMobile,
      onTap: _openRegisterAssetPage,
    );

    final scannerCard = _buildDashboardActionCard(
      title: 'Audit Scanner',
      subtitle: isMobile
          ? 'Scan QR / RFID tags'
          : 'Scan QR/RFID tags to verify items',
      icon: Icons.qr_code_scanner,
      isSolidBlue: false,
      borderColor: ParishColors.borderGrey,
      iconColor: ParishColors.marianBlue,
      isMobile: isMobile,
      onTap: _openAuditScannerPage,
    );

    final reportsCard = _buildDashboardActionCard(
      title: 'Print Reports',
      subtitle: isMobile
          ? 'PDF cards & ledgers'
          : 'A4 photographic cards & ledger tables',
      icon: Icons.picture_as_pdf_outlined,
      isSolidBlue: false,
      borderColor: ParishColors.oliveGreen,
      iconColor: ParishColors.oliveGreen,
      titleColor: ParishColors.oliveGreen,
      isMobile: isMobile,
      onTap: _openReportGeneratorDialog,
    );

    final printCard = _buildDashboardActionCard(
      title: 'Batch Print Tags',
      subtitle:
      isMobile ? 'Print sticker sheets' : 'Generate printable QR sticker sheets',
      icon: Icons.print_outlined,
      isSolidBlue: false,
      borderColor: ParishColors.goldAccent,
      iconColor: ParishColors.goldAccent,
      titleColor: ParishColors.goldAccent,
      isMobile: isMobile,
      onTap: _openBatchPrintPage,
    );

    if (isDesktop) {
      return Row(
        children: [
          Expanded(child: registerCard),
          const SizedBox(width: 12),
          Expanded(child: scannerCard),
          const SizedBox(width: 12),
          Expanded(child: reportsCard),
          const SizedBox(width: 12),
          Expanded(child: printCard),
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: registerCard),
            const SizedBox(width: 10),
            Expanded(child: reportsCard),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: scannerCard),
            const SizedBox(width: 10),
            Expanded(child: printCard),
          ],
        ),
      ],
    );
  }

  Widget _buildDashboardActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    bool isSolidBlue = false,
    bool isMobile = false,
    Color? borderColor,
    Color? iconColor,
    Color? titleColor,
    required VoidCallback onTap,
  }) {
    final bgColor =
    isSolidBlue ? ParishColors.marianBlue : ParishColors.cardWhite;
    final primaryTextColor =
    isSolidBlue ? Colors.white : (titleColor ?? ParishColors.textDark);
    final secondaryTextColor =
    isSolidBlue ? Colors.white70 : ParishColors.textMuted;
    final resolvedIconColor =
    isSolidBlue ? Colors.white : (iconColor ?? ParishColors.marianBlue);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: isMobile ? 66 : 72,
        padding:
        EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSolidBlue
                ? Colors.transparent
                : (borderColor ?? ParishColors.borderGrey),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isSolidBlue ? 0.08 : 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: isMobile ? 38 : 44,
              height: isMobile ? 38 : 44,
              decoration: BoxDecoration(
                color: isSolidBlue
                    ? Colors.white.withOpacity(0.18)
                    : (iconColor?.withOpacity(0.12) ??
                    ParishColors.marianBlueSurface),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon,
                  color: resolvedIconColor, size: isMobile ? 19 : 22),
            ),
            SizedBox(width: isMobile ? 10 : 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: isMobile ? 13.0 : 14.5,
                      fontWeight: FontWeight.bold,
                      color: primaryTextColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: isMobile ? 10.5 : 11.5,
                      color: secondaryTextColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Asset Inventory KPI Overview Deck
  // ===========================================================================

  Widget _buildAssetOverviewDeck(bool isMobile) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final int crossAxisCount = width > 1050 ? 5 : (width > 600 ? 3 : 2);
        final double itemWidth =
            (width - ((crossAxisCount - 1) * 10)) / crossAxisCount;

        final items = [
          _buildKpiCard(
            label: 'All Active Items',
            value: '$_activeCount',
            subtitle: 'In active parish use',
            icon: Icons.inventory_2_outlined,
            color: ParishColors.marianBlue,
            surfaceColor: ParishColors.marianBlueSurface,
            isSelected: _sectionTabController.index == 0 &&
                _selectedCondition == 'All',
            onTap: () => setState(() {
              _sectionTabController.index = 0;
              _selectedCondition = 'All';
              _currentPage = 1;
            }),
          ),
          _buildKpiCard(
            label: 'Section I (≥₱10k)',
            value: '$_section1Count',
            subtitle: 'High-value property',
            icon: Icons.account_balance_outlined,
            color: ParishColors.goldAccent,
            surfaceColor: ParishColors.goldLight,
            isSelected: _sectionTabController.index == 1,
            onTap: () => setState(() {
              _sectionTabController.index = 1;
              _currentPage = 1;
            }),
          ),
          _buildKpiCard(
            label: 'Section II (<₱10k)',
            value: '$_section2Count',
            subtitle: 'Standard furnishings',
            icon: Icons.category_outlined,
            color: ParishColors.oliveGreen,
            surfaceColor: ParishColors.oliveGreenSurface,
            isSelected: _sectionTabController.index == 2,
            onTap: () => setState(() {
              _sectionTabController.index = 2;
              _currentPage = 1;
            }),
          ),
          _buildKpiCard(
            label: 'Needs Attention',
            value: '$_needsAttentionCount',
            subtitle: 'Poor / Damaged state',
            icon: Icons.build_circle_outlined,
            color: const Color(0xFFD97706),
            surfaceColor: const Color(0xFFFFFBEB),
            isSelected: _selectedCondition == 'Poor' ||
                _selectedCondition == 'Damaged' ||
                _selectedCondition == 'Unserviceable',
            onTap: () => setState(() {
              if (_selectedCondition == 'Damaged') {
                _selectedCondition = 'All';
              } else {
                _sectionTabController.index = 0;
                _selectedCondition = 'Damaged';
              }
              _currentPage = 1;
            }),
          ),
          _buildKpiCard(
            label: 'Archived',
            value: '$_archivedCount',
            subtitle: 'Retired or Disposed',
            icon: Icons.archive_outlined,
            color: ParishColors.mercyRed,
            surfaceColor: ParishColors.mercyRedSurface,
            isSelected: _sectionTabController.index == 3,
            onTap: () => setState(() {
              _sectionTabController.index = 3;
              _currentPage = 1;
            }),
          ),
        ];

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children:
          items.map((w) => SizedBox(width: itemWidth, child: w)).toList(),
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String label,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color surfaceColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? surfaceColor : ParishColors.cardWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : ParishColors.borderGrey,
            width: isSelected ? 1.6 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(isSelected ? 0.08 : 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : surfaceColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color,
                        height: 1.1),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected
                          ? ParishColors.textDark
                          : ParishColors.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 9.5,
                      color: ParishColors.textDark.withOpacity(0.6),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Search & Filter Bar
  // ===========================================================================

  Widget _buildSearchAndFilterRow(bool isMobile) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: ParishColors.cardWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ParishColors.borderGrey, width: 1),
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
                const Icon(Icons.search,
                    size: 21, color: ParishColors.marianBlue),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: (val) => setState(() {
                      _searchQuery = val;
                      _currentPage = 1;
                    }),
                    style:
                    TextStyle(fontSize: 14, color: ParishColors.textDark),
                    decoration: InputDecoration(
                      hintText: isMobile
                          ? 'Search items, control #, room...'
                          : 'Search by item name, control number, location, or room...',
                      hintStyle:
                      TextStyle(fontSize: 13, color: ParishColors.textMuted),
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
        InkWell(
          onTap: _openFilterAndSortBottomSheet,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 46,
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16),
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
    );
  }

  // ===========================================================================
  // Section Header with Tabs and View Toggle
  // ===========================================================================

  Widget _buildSectionHeader(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 4,
              height: 38,
              decoration: BoxDecoration(
                color: ParishColors.goldAccent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Parish Property Ledger',
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontFamilyFallback: const ['Times New Roman', 'serif'],
                      fontSize: isMobile ? 17 : 20,
                      fontWeight: FontWeight.w800,
                      color: ParishColors.textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Browse assets, inspect photographic details, and print reports.',
                    style: TextStyle(
                      fontSize: isMobile ? 11.5 : 13,
                      color: ParishColors.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: ParishColors.cardWhite,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: ParishColors.borderGrey),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inventory_2_outlined,
                      size: 14, color: ParishColors.textDark),
                  const SizedBox(width: 5),
                  Text(
                    '${_filteredAssets.length} items',
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: ParishColors.textDark),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Tabs + View Toggle Row
        Row(
          children: [
            Expanded(
              child: Container(
                height: 38,
                decoration: BoxDecoration(
                  color: ParishColors.cardWhite,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ParishColors.borderGrey),
                ),
                child: TabBar(
                  controller: _sectionTabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  padding: EdgeInsets.zero,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 4),
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
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          isMobile
                              ? 'All ($_activeCount)'
                              : 'All Active ($_activeCount)',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 11.5),
                        ),
                      ),
                    ),
                    Tab(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          isMobile
                              ? 'Sec 1 ($_section1Count)'
                              : 'Section I ($_section1Count)',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 11.5),
                        ),
                      ),
                    ),
                    Tab(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          isMobile
                              ? 'Sec 2 ($_section2Count)'
                              : 'Section II ($_section2Count)',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 11.5),
                        ),
                      ),
                    ),
                    Tab(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          isMobile
                              ? 'Archived ($_archivedCount)'
                              : 'Archived ($_archivedCount)',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 11.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),

            Container(
              height: 36,
              decoration: BoxDecoration(
                color: ParishColors.cardWhite,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ParishColors.borderGrey),
              ),
              child: ToggleButtons(
                isSelected: [
                  _viewMode == AssetViewMode.cards,
                  _viewMode == AssetViewMode.table,
                ],
                onPressed: (idx) => setState(() {
                  _viewMode =
                  idx == 0 ? AssetViewMode.cards : AssetViewMode.table;
                }),
                borderRadius: BorderRadius.circular(7),
                selectedColor: Colors.white,
                fillColor: ParishColors.marianBlue,
                color: ParishColors.textMuted,
                constraints: const BoxConstraints(minHeight: 32, minWidth: 34),
                children: const [
                  Tooltip(message: 'Card View', child: Icon(Icons.grid_view, size: 16)),
                  Tooltip(message: 'Table View', child: Icon(Icons.table_chart, size: 16)),
                ],
              ),
            ),
          ],
        ),

        // Active Filter Badges
        if (_hasActiveFilters) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (_selectedCategory != 'All')
                _buildActiveFilterChip('Category: $_selectedCategory', () {
                  setState(() {
                    _selectedCategory = 'All';
                    _currentPage = 1;
                  });
                }),
              if (_selectedLocation != 'All')
                _buildActiveFilterChip('Location: $_selectedLocation', () {
                  setState(() {
                    _selectedLocation = 'All';
                    _currentPage = 1;
                  });
                }),
              if (_selectedCondition != 'All')
                _buildActiveFilterChip('Condition: $_selectedCondition', () {
                  setState(() {
                    _selectedCondition = 'All';
                    _currentPage = 1;
                  });
                }),
              if (_selectedOperationalStatus != 'All' &&
                  _sectionTabController.index != 3)
                _buildActiveFilterChip('Status: $_selectedOperationalStatus', () {
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
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildActiveFilterChip(String label, VoidCallback onDeleted) {
    return Chip(
      label: Text(label,
          style: TextStyle(fontSize: 11, color: ParishColors.textDark)),
      backgroundColor: ParishColors.marianBlueSurface,
      deleteIcon: const Icon(Icons.close, size: 13),
      onDeleted: onDeleted,
      visualDensity: VisualDensity.compact,
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
                  border: Border.all(
                      color: ParishColors.borderGrey.withOpacity(0.4)),
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
  // Build Main Dashboard Shell
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredAssets;
    final totalCount = filtered.length;
    final start = (_currentPage - 1) * _itemsPerPage;
    final end = min(start + _itemsPerPage, totalCount);
    final paged = (start >= totalCount)
        ? <AssetModel>[]
        : filtered.sublist(start, end);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double screenWidth = constraints.maxWidth;
        final bool isDesktop = screenWidth >= 1080;
        final bool isMobile = screenWidth < 650;

        return RefreshIndicator(
          onRefresh: _loadAllData,
          color: ParishColors.marianBlue,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 14 : 28,
              vertical: isMobile ? 14 : 24,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1400),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Hero Header with Sync Status Ribbon
                    _buildHeroHeader(isMobile),
                    const SizedBox(height: 16),

                    // 2. Action Cards Toolbar
                    _buildActionCardsRow(isDesktop, isMobile),
                    const SizedBox(height: 16),

                    // 3. User-Friendly Asset Inventory KPI Overview Deck
                    if (!isMobile &&
                        _searchQuery.isEmpty &&
                        !_hasActiveFilters) ...[
                      _buildAssetOverviewDeck(isMobile),
                      const SizedBox(height: 18),
                    ],

                    // 4. Search & Filter Bar
                    _buildSearchAndFilterRow(isMobile),
                    const SizedBox(height: 20),

                    // 5. Section Header + Tabs + View Mode Toggle
                    _buildSectionHeader(isMobile),
                    const SizedBox(height: 14),

                    // 6. Main Content Area
                    if (_isLoading)
                      _buildSkeletonLoading(constraints.maxWidth)
                    else if (_errorMessage != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: ParishColors.mercyRedSurface,
                            borderRadius: BorderRadius.circular(12)),
                        child: Text(
                            'Error loading inventory: $_errorMessage',
                            style: const TextStyle(
                                color: ParishColors.mercyRed)),
                      )
                    else if (totalCount == 0)
                        _buildEmptyState()
                      else ...[
                          if (_viewMode == AssetViewMode.cards)
                            ...paged.map((a) {
                              final originalIndex =
                              filtered.indexWhere((item) => item.assetId == a.assetId);
                              return InkWell(
                                onTap: () => _openAssetDetailPage(
                                    a, originalIndex >= 0 ? originalIndex : 0),
                                child: AssetItemCard(
                                  asset: a,
                                  onRefresh: _loadAllData,
                                ),
                              );
                            })
                          else
                            _buildFullWidthResponsiveTable(
                                paged, filtered, constraints.maxWidth),
                          const SizedBox(height: 14),
                          _buildPaginationToolbar(totalCount, isMobile),
                        ],

                    SizedBox(
                      height: isMobile
                          ? (96.0 + MediaQuery.paddingOf(context).bottom)
                          : 48.0,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // Responsive DataTable View
  // ===========================================================================

  Widget _buildFullWidthResponsiveTable(
      List<AssetModel> pageAssets,
      List<AssetModel> fullFilteredAssets,
      double availableWidth,
      ) {
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
                        'Control Number', 'Control Number')),
                DataColumn(
                    label: _buildSortableColumnLabel('Item Name', 'Item Name')),
                const DataColumn(label: Text('Qty')),
                const DataColumn(label: Text('Category')),
                const DataColumn(label: Text('Storage Location')),
                DataColumn(
                    label: _buildSortableColumnLabel(
                        'Year', 'Acquisition Year')),
                DataColumn(
                    label: _buildSortableColumnLabel(
                        'Unit Price', 'Price / Unit')),
                DataColumn(
                    label: _buildSortableColumnLabel(
                        'Total Cost', 'Total Cost')),
                const DataColumn(label: Text('Condition')),
                const DataColumn(label: Text('Status')),
                const DataColumn(label: Text('Action')),
              ],
              rows: pageAssets.map((a) {
                final bool isDecom = a.isEffectivelyArchived;
                final originalIndex = fullFilteredAssets
                    .indexWhere((item) => item.assetId == a.assetId);

                return DataRow(cells: [
                  DataCell(
                    Text(
                      a.controlNumber,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDecom
                            ? ParishColors.mercyRed
                            : ParishColors.marianBlue,
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
                  DataCell(Text(a.formattedUnitPrice,
                      style: const TextStyle(fontWeight: FontWeight.bold))),
                  DataCell(Text(a.formattedTotalCost,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: ParishColors.oliveGreen))),
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
                        color: a.statusSurfaceColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        a.operationalStatus,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 10.5,
                          color: a.statusColor,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    TextButton.icon(
                      style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact),
                      onPressed: () => _openAssetDetailPage(
                        a,
                        originalIndex >= 0 ? originalIndex : 0,
                      ),
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

  // ===========================================================================
  // Standardized Pagination Toolbar
  // ===========================================================================

  Widget _buildPaginationToolbar(int totalItems, bool isMobile) {
    final totalPages = _totalPages;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 14, vertical: 8),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ParishColors.borderGrey),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text('Show: ',
                  style: TextStyle(fontSize: 12, color: ParishColors.textMuted)),
              DropdownButton<int>(
                value: _itemsPerPage,
                isDense: true,
                underline: const SizedBox.shrink(),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: ParishColors.marianBlueAdaptive),
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
                    ? ParishColors.marianBlueAdaptive
                    : ParishColors.borderGrey,
                onPressed: _currentPage > 1
                    ? () => setState(() => _currentPage--)
                    : null,
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: ParishColors.marianBlueSurface,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Page $_currentPage of $totalPages',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: ParishColors.marianBlueAdaptive,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 22),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: _currentPage < totalPages
                    ? ParishColors.marianBlueAdaptive
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
  // Empty State
  // ===========================================================================

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
          Icon(Icons.inventory_2_outlined,
              size: 44, color: ParishColors.textMuted),
          const SizedBox(height: 10),
          Text(
            _searchQuery.isNotEmpty
                ? 'No items match your search.'
                : 'No items registered under this section yet.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: ParishColors.textDark),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap "Register Item" above to add parish property and generate tags.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: ParishColors.textMuted),
          ),
        ],
      ),
    );
  }
}