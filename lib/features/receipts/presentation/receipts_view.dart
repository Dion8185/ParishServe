// =============================================================================
// FILE: lib/features/receipts/presentation/receipts_view.dart (PART 1 OF 2)
// =============================================================================

import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../services/secretary_service.dart';
import 'dialogs/manage_particulars_dialog.dart';
import 'dialogs/new_transaction_dialog.dart';
import 'dialogs/receipt_detail_dialog.dart';
import 'dialogs/remittance_report_dialog.dart';
import 'pages/pos_cashier_page.dart';
import 'pages/receipt_template_management_page.dart';
import 'widgets/receipt_card.dart';

enum ReceiptViewMode { cards, table }

class ReceiptManagementView extends StatefulWidget {
  const ReceiptManagementView({super.key});

  @override
  State<ReceiptManagementView> createState() => _ReceiptManagementViewState();
}

class _ReceiptManagementViewState extends State<ReceiptManagementView>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _mainTabController;
  late AnimationController _skeletonAnimController;
  late Animation<double> _skeletonOpacityAnimation;

  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;
  String? _errorMessage;

  // View Mode: Cards vs Table
  ReceiptViewMode _viewMode = ReceiptViewMode.cards;

  // Search, Filter & Sort State (Matching Assets & Appointments)
  String _searchQuery = '';
  String _selectedPaymentMode = 'All';
  String _selectedDateRangeFilter = 'All Dates';
  DateTimeRange? _customDateRange;
  String _sortBy = 'Date: Latest First';
  bool _sortAscending = false;

  // Pagination State
  int _currentPage = 1;
  int _itemsPerPage = 10;

  final List<String> _paymentModeOptions = [
    'All',
    'Cash',
    'GCash',
    'Gratis',
  ];

  final List<String> _dateRangeOptions = [
    'All Dates',
    'Today',
    'This Week',
    'This Month',
    'Custom Date Range',
  ];

  final List<String> _sortOptions = [
    'Date: Latest First',
    'Date: Earliest First',
    'Amount: Highest First',
    'Amount: Lowest First',
    'Payor Name (A-Z)',
    'Receipt Number',
  ];

  @override
  void initState() {
    super.initState();
    // 2 Tabs: Active Receipts (Legitimate Ledger) & Voided Archive
    _mainTabController = TabController(length: 2, vsync: this);
    _mainTabController.addListener(() {
      if (!_mainTabController.indexIsChanging) {
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

    _loadTransactions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mainTabController.dispose();
    _skeletonAnimController.dispose();
    super.dispose();
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await SecretaryService.getTransactions();
      if (!mounted) return;
      setState(() {
        _transactions = data;
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

  bool _isTransactionVoided(Map<String, dynamic> t) {
    final status = (t['transaction_status'] ?? '').toString().toLowerCase();
    if (status.contains('void') || status.contains('cancel')) return true;
    final details = (t['transaction_details'] ?? '').toString().toUpperCase();
    return details.contains('[VOIDED') || details.contains('VOIDED ON');
  }

  String _getTenderMode(Map<String, dynamic> t) {
    final details = (t['transaction_details'] ?? '').toString().toLowerCase();
    final type = (t['transaction_type'] ?? '').toString().toLowerCase();

    if (details.contains('tender mode: gcash') || details.contains('gcash ref') || type == 'gcash') {
      return 'GCash';
    }
    if (details.contains('tender mode: gratis') || type == 'gratis') {
      return 'Gratis';
    }
    return 'Cash';
  }

  double _getAmount(Map<String, dynamic> t) {
    final raw = t['transaction_amount'];
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw?.toString() ?? '0') ?? 0.0;
  }

  // ===========================================================================
  // Data Filtering & Segregation
  // ===========================================================================

  // 1. Legitimate Active Transactions (Strictly Excludes Voided)
  List<Map<String, dynamic>> get _activeTransactions {
    var list = _transactions.where((t) => !_isTransactionVoided(t)).toList();

    if (_selectedPaymentMode != 'All') {
      list = list.where((t) {
        final mode = _getTenderMode(t);
        return mode.toLowerCase() == _selectedPaymentMode.toLowerCase();
      }).toList();
    }

    list = _applyDateRangeAndSearch(list);
    _applySorting(list);
    return list;
  }

  // 2. Voided Archive Slips (Strictly Isolated to Prevent Ledger Clutter)
  List<Map<String, dynamic>> get _voidedTransactions {
    var list = _transactions.where((t) => _isTransactionVoided(t)).toList();

    list = _applyDateRangeAndSearch(list);
    _applySorting(list);
    return list;
  }

  List<Map<String, dynamic>> get _currentTabTransactions {
    return _mainTabController.index == 0 ? _activeTransactions : _voidedTransactions;
  }

  List<Map<String, dynamic>> _applyDateRangeAndSearch(List<Map<String, dynamic>> list) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_selectedDateRangeFilter == 'Today') {
      list = list.where((t) {
        final d = DateTime.tryParse(t['transaction_date']?.toString() ?? t['created_at']?.toString() ?? '');
        if (d == null) return false;
        return d.year == today.year && d.month == today.month && d.day == today.day;
      }).toList();
    } else if (_selectedDateRangeFilter == 'This Week') {
      final startOfWeek = today.subtract(Duration(days: today.weekday % 7));
      final endOfWeek = startOfWeek.add(const Duration(days: 6, hours: 23, minutes: 59));
      list = list.where((t) {
        final d = DateTime.tryParse(t['transaction_date']?.toString() ?? t['created_at']?.toString() ?? '');
        if (d == null) return false;
        return !d.isBefore(startOfWeek) && !d.isAfter(endOfWeek);
      }).toList();
    } else if (_selectedDateRangeFilter == 'This Month') {
      list = list.where((t) {
        final d = DateTime.tryParse(t['transaction_date']?.toString() ?? t['created_at']?.toString() ?? '');
        if (d == null) return false;
        return d.year == today.year && d.month == today.month;
      }).toList();
    } else if (_selectedDateRangeFilter == 'Custom Date Range' && _customDateRange != null) {
      final start = DateTime(_customDateRange!.start.year, _customDateRange!.start.month, _customDateRange!.start.day);
      final end = DateTime(_customDateRange!.end.year, _customDateRange!.end.month, _customDateRange!.end.day, 23, 59, 59);
      list = list.where((t) {
        final d = DateTime.tryParse(t['transaction_date']?.toString() ?? t['created_at']?.toString() ?? '');
        if (d == null) return false;
        return !d.isBefore(start) && !d.isAfter(end);
      }).toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      list = list.where((t) {
        final payer = (t['payor_name'] ?? '').toString().toLowerCase();
        final rNo = (t['receipt_number'] ?? '').toString().toLowerCase();
        final service = (t['related_service'] ?? '').toString().toLowerCase();
        final details = (t['transaction_details'] ?? '').toString().toLowerCase();
        final contact = (t['payor_contact'] ?? '').toString().toLowerCase();
        return payer.contains(q) ||
            rNo.contains(q) ||
            service.contains(q) ||
            details.contains(q) ||
            contact.contains(q);
      }).toList();
    }

    return list;
  }

  void _applySorting(List<Map<String, dynamic>> list) {
    list.sort((a, b) {
      int comparison = 0;
      switch (_sortBy) {
        case 'Date: Latest First':
          final da = DateTime.tryParse(a['transaction_date']?.toString() ?? a['created_at']?.toString() ?? '') ?? DateTime(1970);
          final db = DateTime.tryParse(b['transaction_date']?.toString() ?? b['created_at']?.toString() ?? '') ?? DateTime(1970);
          comparison = db.compareTo(da);
          break;
        case 'Date: Earliest First':
          final da = DateTime.tryParse(a['transaction_date']?.toString() ?? a['created_at']?.toString() ?? '') ?? DateTime(1970);
          final db = DateTime.tryParse(b['transaction_date']?.toString() ?? b['created_at']?.toString() ?? '') ?? DateTime(1970);
          comparison = da.compareTo(db);
          break;
        case 'Amount: Highest First':
          comparison = _getAmount(b).compareTo(_getAmount(a));
          break;
        case 'Amount: Lowest First':
          comparison = _getAmount(a).compareTo(_getAmount(b));
          break;
        case 'Payor Name (A-Z)':
          comparison = (a['payor_name'] ?? '').toString().toLowerCase().compareTo((b['payor_name'] ?? '').toString().toLowerCase());
          break;
        case 'Receipt Number':
        default:
          comparison = (b['receipt_number'] ?? '').toString().compareTo((a['receipt_number'] ?? '').toString());
          break;
      }
      return _sortAscending ? -comparison : comparison;
    });
  }

  // ===========================================================================
  // Summary Stats & Metrics
  // ===========================================================================

  double get _totalCollectedToday {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return _transactions.where((t) {
      if (_isTransactionVoided(t)) return false;
      final date = (t['transaction_date'] ?? t['created_at'] ?? '').toString();
      return date.startsWith(today);
    }).fold(0.0, (sum, t) => sum + _getAmount(t));
  }

  double get _totalValidIntake {
    return _transactions
        .where((t) => !_isTransactionVoided(t))
        .fold(0.0, (sum, t) => sum + _getAmount(t));
  }

  double get _totalGCashIntake {
    return _transactions
        .where((t) => !_isTransactionVoided(t) && _getTenderMode(t) == 'GCash')
        .fold(0.0, (sum, t) => sum + _getAmount(t));
  }

  int get _voidedCount => _transactions.where((t) => _isTransactionVoided(t)).length;

  int get _totalPages {
    final total = _currentTabTransactions.length;
    if (total == 0) return 1;
    return (total / _itemsPerPage).ceil();
  }

  int get _activeFilterCount {
    int count = 0;
    if (_selectedPaymentMode != 'All') count++;
    if (_selectedDateRangeFilter != 'All Dates') count++;
    if (_sortBy != 'Date: Latest First' || _sortAscending) count++;
    return count;
  }

  bool get _hasActiveFilters => _activeFilterCount > 0;

  void _resetFilters() {
    setState(() {
      _selectedPaymentMode = 'All';
      _selectedDateRangeFilter = 'All Dates';
      _customDateRange = null;
      _sortBy = 'Date: Latest First';
      _sortAscending = false;
      _currentPage = 1;
    });
  }

  Future<void> _pickCustomDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _customDateRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 7)),
            end: now,
          ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: ParishColors.marianBlue,
              onPrimary: Colors.white,
              surface: ParishColors.cardWhite,
              onSurface: ParishColors.textDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _selectedDateRangeFilter = 'Custom Date Range';
        _currentPage = 1;
      });
    }
  }

  void _launchPos() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PosCashierPage(onTransactionCompleted: _loadTransactions),
      ),
    );
  }

  void _openManageParticulars() {
    showManageParticularsModal(
      context,
      onParticularsUpdated: _loadTransactions,
    );
  }

  void _openTemplateManager() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ReceiptTemplateManagementPage(),
      ),
    );
  }

  void _openRemittanceReports() {
    showRemittanceReportModal(context);
  }

  // ===========================================================================
  // Filter & Sort Bottom Sheet (Matching Assets Module)
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
                        'Filter & Sort Receipts',
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

                  // 1. Sort Sequence
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
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          items: _sortOptions
                              .map((opt) => DropdownMenuItem(value: opt, child: Text(opt, style: const TextStyle(fontSize: 13))))
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: Icon(
                          _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
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

                  // 2. Date Range Filter
                  Text(
                    'Date Range Filter',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: ParishColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _selectedDateRangeFilter,
                    isExpanded: true,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: _dateRangeOptions.map((opt) {
                      String label = opt;
                      if (opt == 'Custom Date Range' && _customDateRange != null) {
                        label =
                        'Custom: ${_customDateRange!.start.month}/${_customDateRange!.start.day} - ${_customDateRange!.end.month}/${_customDateRange!.end.day}';
                      }
                      return DropdownMenuItem(value: opt, child: Text(label, style: const TextStyle(fontSize: 13)));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        if (val == 'Custom Date Range') {
                          _pickCustomDateRange().then((_) {
                            setSheetState(() {});
                          });
                        } else {
                          setState(() {
                            _selectedDateRangeFilter = val;
                            _customDateRange = null;
                            _currentPage = 1;
                          });
                          setSheetState(() {});
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  // 3. Payment Mode Filter (For Active Tab)
                  if (_mainTabController.index == 0) ...[
                    Text(
                      'Payment Tender Mode',
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
                        children: _paymentModeOptions.map((mode) {
                          final isSelected = _selectedPaymentMode == mode;
                          Color activeColor = ParishColors.marianBlue;
                          if (mode == 'Cash') activeColor = ParishColors.oliveGreen;
                          if (mode == 'GCash') activeColor = const Color(0xFF005CEE);
                          if (mode == 'Gratis') activeColor = ParishColors.goldAccent;

                          return Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: ChoiceChip(
                              label: Text(mode),
                              selected: isSelected,
                              selectedColor: activeColor,
                              backgroundColor: ParishColors.backgroundLight,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : ParishColors.textDark,
                                fontWeight: FontWeight.bold,
                                fontSize: 11.5,
                              ),
                              onSelected: (_) {
                                setState(() {
                                  _selectedPaymentMode = mode;
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Apply & Close', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
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
  // Build Main Shell (Anchored to Top on Desktop)
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final textDarkColor = ParishColors.textDark;
    final cardWhiteColor = ParishColors.cardWhite;
    final borderGreyColor = ParishColors.borderGrey;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 650;
        final currentItems = _currentTabTransactions;
        final totalCount = currentItems.length;
        final double viewportHeight = constraints.hasBoundedHeight ? constraints.maxHeight : 0.0;

        // Container explicitly claims available height on desktop and anchors child to topCenter
        return Container(
          width: double.infinity,
          height: constraints.hasBoundedHeight ? constraints.maxHeight : null,
          alignment: Alignment.topCenter,
          child: RefreshIndicator(
            onRefresh: _loadTransactions,
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
                    // 1. Header (Clean title, subtext removed for clean presentation)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Parish Cashier & Receipts Desk',
                            style: TextStyle(
                              fontSize: isMobile ? 18 : 22,
                              fontWeight: FontWeight.bold,
                              color: textDarkColor,
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.assessment_outlined, color: ParishColors.marianBlue, size: 20),
                              onPressed: _openRemittanceReports,
                              tooltip: 'Remittance & Financial Reports',
                            ),
                            IconButton(
                              icon: const Icon(Icons.style_outlined, color: ParishColors.marianBlue, size: 20),
                              onPressed: _openTemplateManager,
                              tooltip: 'Receipt Templates & Canvas Studio',
                            ),
                            IconButton(
                              icon: const Icon(Icons.tune, color: ParishColors.marianBlue, size: 20),
                              onPressed: _openManageParticulars,
                              tooltip: 'Manage Catalog Particulars (CRUD)',
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh, color: ParishColors.marianBlue, size: 20),
                              onPressed: _loadTransactions,
                              tooltip: 'Reload Ledger',
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 2. Primary Action Buttons
                    _buildActionButtons(isMobile),
                    const SizedBox(height: 12),

                    // 3. Compact Stats Row (Matching Assets Module)
                    _buildCompactStatsRow(),
                    const SizedBox(height: 14),

                    // 4. Main Module Switcher (Active Receipts vs Voided Archive)
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: cardWhiteColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderGreyColor),
                      ),
                      child: TabBar(
                        controller: _mainTabController,
                        labelColor: Colors.white,
                        unselectedLabelColor: ParishColors.textMuted,
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicator: BoxDecoration(
                          color: _mainTabController.index == 1
                              ? ParishColors.mercyRed
                              : ParishColors.marianBlue,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        tabs: [
                          Tab(
                            child: Text(
                              isMobile
                                  ? 'Active (${_transactions.length - _voidedCount})'
                                  : 'Active Receipts (${_transactions.length - _voidedCount})',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 11 : 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Tab(
                            child: Text(
                              isMobile
                                  ? 'Voided ($_voidedCount)'
                                  : 'Voided Archive ($_voidedCount)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 11 : 12),
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
                        color: cardWhiteColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderGreyColor),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search, size: 20, color: ParishColors.marianBlue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: (val) {
                                setState(() {
                                  _searchQuery = val;
                                  _currentPage = 1;
                                });
                              },
                              style: TextStyle(fontSize: 13, color: textDarkColor),
                              decoration: InputDecoration(
                                hintText: 'Search by payor, receipt #, service, notes...',
                                hintStyle: TextStyle(fontSize: 12, color: ParishColors.textMuted),
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
                                  _currentPage = 1;
                                });
                              },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 6. Filter & Sort Toolbar with Card / Table View Toggle
                    Row(
                      children: [
                        InkWell(
                          onTap: _openFilterAndSortBottomSheet,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            height: 36,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: _hasActiveFilters ? ParishColors.marianBlueSurface : cardWhiteColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _hasActiveFilters ? ParishColors.marianBlue : borderGreyColor,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.tune,
                                  size: 15,
                                  color: _hasActiveFilters ? ParishColors.marianBlue : ParishColors.textMuted,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _hasActiveFilters
                                      ? 'Filter & Sort ($_activeFilterCount)'
                                      : 'Filter & Sort',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: _hasActiveFilters ? ParishColors.marianBlue : textDarkColor,
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
                            color: ParishColors.textMuted,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          height: 32,
                          decoration: BoxDecoration(
                            color: cardWhiteColor,
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(color: borderGreyColor),
                          ),
                          child: ToggleButtons(
                            isSelected: [
                              _viewMode == ReceiptViewMode.cards,
                              _viewMode == ReceiptViewMode.table,
                            ],
                            onPressed: (idx) => setState(() {
                              _viewMode = idx == 0 ? ReceiptViewMode.cards : ReceiptViewMode.table;
                            }),
                            borderRadius: BorderRadius.circular(6),
                            selectedColor: Colors.white,
                            fillColor: ParishColors.marianBlue,
                            color: ParishColors.textMuted,
                            constraints: const BoxConstraints(minHeight: 28, minWidth: 32),
                            children: const [
                              Tooltip(message: 'Card View', child: Icon(Icons.grid_view, size: 14)),
                              Tooltip(message: 'Table View', child: Icon(Icons.table_chart, size: 14)),
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
                          if (_selectedDateRangeFilter != 'All Dates')
                            _buildActiveFilterChip('Range: $_selectedDateRangeFilter', () {
                              setState(() {
                                _selectedDateRangeFilter = 'All Dates';
                                _customDateRange = null;
                                _currentPage = 1;
                              });
                            }),
                          if (_selectedPaymentMode != 'All' && _mainTabController.index == 0)
                            _buildActiveFilterChip('Tender: $_selectedPaymentMode', () {
                              setState(() {
                                _selectedPaymentMode = 'All';
                                _currentPage = 1;
                              });
                            }),
                          if (_sortBy != 'Date: Latest First' || _sortAscending)
                            _buildActiveFilterChip('Sorted: $_sortBy', () {
                              setState(() {
                                _sortBy = 'Date: Latest First';
                                _sortAscending = false;
                              });
                            }),
                          ActionChip(
                            label: const Text(
                              'Clear',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: ParishColors.mercyRed,
                              ),
                            ),
                            backgroundColor: ParishColors.mercyRedSurface,
                            side: BorderSide(color: ParishColors.mercyRed.withOpacity(0.3)),
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            visualDensity: VisualDensity.compact,
                            onPressed: _resetFilters,
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),

                    // 8. Tab Content / Anti-Shift Skeleton Loader
                    if (_isLoading)
                      _buildSkeletonLoading(constraints.maxWidth)
                    else if (_mainTabController.index == 0)
                      _buildActiveReceiptsTab(constraints.maxWidth)
                    else
                      _buildVoidedReceiptsTab(constraints.maxWidth),
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
// FILE: lib/features/receipts/presentation/receipts_view.dart (PART 2 OF 2)
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
            onPressed: _launchPos,
            icon: const Icon(Icons.point_of_sale, size: 18),
            label: const Text(
              'Launch POS Cashier Terminal',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 42,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: ParishColors.marianBlue, width: 1.5),
                    foregroundColor: ParishColors.marianBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => showNewTransactionModal(context, onTransactionSaved: _loadTransactions),
                  icon: const Icon(Icons.receipt_long, size: 16),
                  label: const Text('Single Entry', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 42,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ParishColors.marianBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _openRemittanceReports,
                  icon: const Icon(Icons.assessment_outlined, size: 16),
                  label: const Text('Reports', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ],
    )
        : Row(
      children: [
        Expanded(
          flex: 4,
          child: SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: ParishColors.oliveGreen,
                foregroundColor: Colors.white,
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _launchPos,
              icon: const Icon(Icons.point_of_sale, size: 18),
              label: const Text(
                'Launch POS Cashier Terminal',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: SizedBox(
            height: 44,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: ParishColors.marianBlue, width: 1.5),
                foregroundColor: ParishColors.marianBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => showNewTransactionModal(context, onTransactionSaved: _loadTransactions),
              icon: const Icon(Icons.receipt_long, size: 16),
              label: const Text(
                'Single Entry',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: ParishColors.marianBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _openRemittanceReports,
              icon: const Icon(Icons.assessment_outlined, size: 16),
              label: const Text(
                'Remittance Reports',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // Compact Stats Row (Matching Assets & Appointments Modules)
  // ===========================================================================
  Widget _buildCompactStatsRow() {
    final validSlipsCount = _transactions.length - _voidedCount;

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
              'Valid Slips',
              '$validSlipsCount',
              ParishColors.marianBlue,
            ),
          ),
          Container(width: 1, height: 20, color: ParishColors.borderGrey),
          Expanded(
            child: _buildCompactStatItem(
              "Today's Intake",
              '₱${_totalCollectedToday.toStringAsFixed(0)}',
              ParishColors.oliveGreen,
            ),
          ),
          Container(width: 1, height: 20, color: ParishColors.borderGrey),
          Expanded(
            child: _buildCompactStatItem(
              'Total Intake',
              '₱${_totalValidIntake.toStringAsFixed(0)}',
              ParishColors.goldAccent,
            ),
          ),
          Container(width: 1, height: 20, color: ParishColors.borderGrey),
          Expanded(
            child: _buildCompactStatItem(
              'GCash Intake',
              '₱${_totalGCashIntake.toStringAsFixed(0)}',
              const Color(0xFF005CEE),
            ),
          ),
          Container(width: 1, height: 20, color: ParishColors.borderGrey),
          Expanded(
            child: _buildCompactStatItem(
              'Voided Slips',
              '$_voidedCount',
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
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: color),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: ParishColors.textMuted),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildActiveFilterChip(String label, VoidCallback onDeleted) {
    return Chip(
      label: Text(label, style: TextStyle(fontSize: 10, color: ParishColors.textDark)),
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
                      width: 44,
                      height: 44,
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
                            width: 150,
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
                            width: 170,
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
  // TAB 1: ACTIVE RECEIPTS LEDGER (Strictly Excludes Voided Records)
  // ===========================================================================
  Widget _buildActiveReceiptsTab(double availableWidth) {
    final list = _activeTransactions;
    final totalItems = list.length;
    final start = (_currentPage - 1) * _itemsPerPage;
    final end = min(start + _itemsPerPage, totalItems);
    final paged = (start >= totalItems) ? <Map<String, dynamic>>[] : list.sublist(start, end);

    if (_errorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: ParishColors.mercyRedSurface, borderRadius: BorderRadius.circular(12)),
        child: Text('Error loading transactions: $_errorMessage', style: const TextStyle(color: ParishColors.mercyRed)),
      );
    }

    if (list.isEmpty) {
      return _buildEmptyState('No active ecclesiastical receipts match your criteria.');
    }

    return Column(
      children: [
        if (_viewMode == ReceiptViewMode.cards)
          ...paged.map((t) => _buildReceiptCardItem(t))
        else
          _buildReceiptsTableView(paged, availableWidth, isVoidTab: false),
        const SizedBox(height: 14),
        _buildPaginationToolbar(totalItems),
      ],
    );
  }

  // ===========================================================================
  // TAB 2: VOIDED ARCHIVE (Strictly Isolated to Protect Legitimate Ledgers)
  // ===========================================================================
  Widget _buildVoidedReceiptsTab(double availableWidth) {
    final list = _voidedTransactions;
    final totalItems = list.length;
    final start = (_currentPage - 1) * _itemsPerPage;
    final end = min(start + _itemsPerPage, totalItems);
    final paged = (start >= totalItems) ? <Map<String, dynamic>>[] : list.sublist(start, end);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Isolation Info Banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ParishColors.mercyRedSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ParishColors.mercyRed.withOpacity(0.4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.block, color: ParishColors.mercyRed, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ISOLATED VOIDED & CANCELLED RECEIPTS',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ParishColors.mercyRed),
                    ),
                    Text(
                      'Nullified and cancelled receipts are preserved here for financial transparency. Amounts are excluded from canonical remittance summaries.',
                      style: TextStyle(fontSize: 11, color: ParishColors.textDark),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        if (list.isEmpty)
          _buildEmptyState('No voided receipt slips found on record.')
        else if (_viewMode == ReceiptViewMode.table)
          ...[
            _buildReceiptsTableView(paged, availableWidth, isVoidTab: true),
            const SizedBox(height: 14),
            _buildPaginationToolbar(totalItems),
          ]
        else
          ...[
            ...paged.map((t) => _buildReceiptCardItem(t)),
            const SizedBox(height: 14),
            _buildPaginationToolbar(totalItems),
          ],
      ],
    );
  }

  Widget _buildReceiptCardItem(Map<String, dynamic> t) {
    final String rNo = (t['receipt_number'] ?? 'REC-XXXX').toString();
    final String payor = (t['payor_name'] ?? 'Parishioner').toString();
    final String service = (t['related_service'] ?? t['transaction_type'] ?? 'Parish Service').toString();
    final double amountVal = _getAmount(t);
    final String amount = '₱ ${amountVal.toStringAsFixed(2)}';
    final String dateRaw = (t['transaction_date'] ?? t['created_at'] ?? '').toString();
    final String date = dateRaw.length >= 10 ? dateRaw.substring(0, 10) : dateRaw;
    final String status = (t['transaction_status'] ?? 'paid').toString().toUpperCase();
    final String mode = _getTenderMode(t);
    final String? contact = t['payor_contact']?.toString();
    final String? details = t['transaction_details']?.toString();
    final bool isVoided = _isTransactionVoided(t);

    return ReceiptCard(
      receiptNo: rNo,
      payer: payor,
      purpose: service,
      amount: amount,
      date: date,
      status: status,
      payorContact: contact,
      transactionDetails: details,
      paymentMode: mode,
      isVoided: isVoided,
      transactionId: t['transaction_id']?.toString(),
      onTap: () {
        showReceiptDetailModal(
          context,
          receiptNo: rNo,
          payer: payor,
          purpose: service,
          amount: amount,
          date: date,
          payorContact: contact,
          transactionDetails: details,
          paymentMode: mode,
          transactionId: t['transaction_id']?.toString(),
          status: status,
          onTransactionUpdated: _loadTransactions,
        );
      },
    );
  }

  // ===========================================================================
  // Responsive DataTable View (Full Width with Horizontal Scroll)
  // ===========================================================================
  Widget _buildReceiptsTableView(List<Map<String, dynamic>> items, double availableWidth, {required bool isVoidTab}) {
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
              headingRowColor: WidgetStateProperty.all(
                isVoidTab ? ParishColors.mercyRedSurface : ParishColors.marianBlueSurface,
              ),
              headingTextStyle: TextStyle(
                fontWeight: FontWeight.bold,
                color: isVoidTab ? ParishColors.mercyRed : ParishColors.marianBlue,
                fontSize: 12.5,
              ),
              dataTextStyle: TextStyle(fontSize: 12.5, color: ParishColors.textDark),
              columnSpacing: 16,
              horizontalMargin: 14,
              columns: const [
                DataColumn(label: Text('Receipt #')),
                DataColumn(label: Text('Date & Time')),
                DataColumn(label: Text('Payor Name')),
                DataColumn(label: Text('Particulars / Service')),
                DataColumn(label: Text('Tender')),
                DataColumn(label: Text('Amount')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Action')),
              ],
              rows: items.map((t) {
                final String rNo = (t['receipt_number'] ?? 'REC-XXXX').toString();
                final String payor = (t['payor_name'] ?? 'Parishioner').toString();
                final String service = (t['related_service'] ?? t['transaction_type'] ?? 'Parish Service').toString();
                final double amountVal = _getAmount(t);
                final String dateRaw = (t['transaction_date'] ?? t['created_at'] ?? '').toString();
                final String date = dateRaw.length >= 10 ? dateRaw.substring(0, 10) : dateRaw;
                final String status = (t['transaction_status'] ?? 'paid').toString().toUpperCase();
                final String mode = _getTenderMode(t);
                final String? contact = t['payor_contact']?.toString();
                final String? details = t['transaction_details']?.toString();
                final bool isVoided = _isTransactionVoided(t);

                Color tenderColor = ParishColors.oliveGreen;
                if (mode == 'GCash') tenderColor = const Color(0xFF005CEE);
                if (mode == 'Gratis') tenderColor = ParishColors.goldAccent;

                return DataRow(cells: [
                  DataCell(Text(
                    rNo,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isVoided ? ParishColors.mercyRed : ParishColors.marianBlue,
                    ),
                  )),
                  DataCell(Text(date)),
                  DataCell(Text(payor, style: const TextStyle(fontWeight: FontWeight.w600))),
                  DataCell(ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: Text(service, maxLines: 1, overflow: TextOverflow.ellipsis),
                  )),
                  DataCell(Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isVoided ? ParishColors.mercyRedSurface : tenderColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isVoided ? 'VOIDED' : mode.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: isVoided ? ParishColors.mercyRed : tenderColor,
                      ),
                    ),
                  )),
                  DataCell(Text(
                    '₱ ${amountVal.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isVoided ? ParishColors.mercyRed : ParishColors.oliveGreen,
                      decoration: isVoided ? TextDecoration.lineThrough : null,
                    ),
                  )),
                  DataCell(Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isVoided ? ParishColors.mercyRedSurface : ParishColors.oliveGreenSurface,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isVoided ? 'VOID' : status,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: isVoided ? ParishColors.mercyRed : ParishColors.oliveGreen,
                      ),
                    ),
                  )),
                  DataCell(
                    TextButton.icon(
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      onPressed: () {
                        showReceiptDetailModal(
                          context,
                          receiptNo: rNo,
                          payer: payor,
                          purpose: service,
                          amount: '₱ ${amountVal.toStringAsFixed(2)}',
                          date: date,
                          payorContact: contact,
                          transactionDetails: details,
                          paymentMode: mode,
                          transactionId: t['transaction_id']?.toString(),
                          status: status,
                          onTransactionUpdated: _loadTransactions,
                        );
                      },
                      icon: const Icon(Icons.visibility, size: 14),
                      label: const Text('View', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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

  Widget _buildEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ParishColors.borderGrey),
      ),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined, size: 40, color: ParishColors.textMuted),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: ParishColors.textDark),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Pagination Toolbar (Kept Intact)
  // ===========================================================================
  Widget _buildPaginationToolbar(int totalItems) {
    final totalPages = _totalPages;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ParishColors.borderGrey),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text('Show: ', style: TextStyle(fontSize: 12, color: ParishColors.textMuted)),
              DropdownButton<int>(
                value: _itemsPerPage,
                isDense: true,
                underline: const SizedBox.shrink(),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ParishColors.marianBlueAdaptive),
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
                color: _currentPage > 1 ? ParishColors.marianBlueAdaptive : ParishColors.borderGrey,
                onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
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
                color: _currentPage < totalPages ? ParishColors.marianBlueAdaptive : ParishColors.borderGrey,
                onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}