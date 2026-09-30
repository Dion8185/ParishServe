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

class ReceiptManagementView extends StatefulWidget {
  const ReceiptManagementView({super.key});

  @override
  State<ReceiptManagementView> createState() => _ReceiptManagementViewState();
}

class _ReceiptManagementViewState extends State<ReceiptManagementView> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Search & Filtering State
  String _searchQuery = '';
  String _selectedPaymentMode = 'All';
  String _selectedDateRangeFilter = 'All Dates';
  DateTimeRange? _customDateRange;
  String _sortBy = 'Date: Latest First';

  // Pagination State
  int _currentPage = 1;
  int _itemsPerPage = 10;

  final List<String> _paymentModeOptions = [
    'All',
    'Cash',
    'GCash',
    'Gratis',
    'Voided',
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
    _loadTransactions();
  }

  @override
  void dispose() {
    _searchController.dispose();
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
  // Data Filtering & Sorting Logic
  // ===========================================================================

  List<Map<String, dynamic>> get _filteredTransactions {
    var list = List<Map<String, dynamic>>.from(_transactions);

    // 1. Payment Tender Mode & Voided Filter
    if (_selectedPaymentMode == 'Voided') {
      list = list.where((t) => _isTransactionVoided(t)).toList();
    } else if (_selectedPaymentMode != 'All') {
      list = list.where((t) {
        if (_isTransactionVoided(t)) return false;
        final mode = _getTenderMode(t);
        return mode.toLowerCase() == _selectedPaymentMode.toLowerCase();
      }).toList();
    }

    // 2. Date Range Filter
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

    // 3. Search Query
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

    // 4. Sorting
    if (_sortBy == 'Date: Latest First') {
      list.sort((a, b) {
        final da = DateTime.tryParse(a['transaction_date']?.toString() ?? a['created_at']?.toString() ?? '') ?? DateTime(1970);
        final db = DateTime.tryParse(b['transaction_date']?.toString() ?? b['created_at']?.toString() ?? '') ?? DateTime(1970);
        return db.compareTo(da);
      });
    } else if (_sortBy == 'Date: Earliest First') {
      list.sort((a, b) {
        final da = DateTime.tryParse(a['transaction_date']?.toString() ?? a['created_at']?.toString() ?? '') ?? DateTime(1970);
        final db = DateTime.tryParse(b['transaction_date']?.toString() ?? b['created_at']?.toString() ?? '') ?? DateTime(1970);
        return da.compareTo(db);
      });
    } else if (_sortBy == 'Amount: Highest First') {
      list.sort((a, b) => _getAmount(b).compareTo(_getAmount(a)));
    } else if (_sortBy == 'Amount: Lowest First') {
      list.sort((a, b) => _getAmount(a).compareTo(_getAmount(b)));
    } else if (_sortBy == 'Payor Name (A-Z)') {
      list.sort((a, b) => (a['payor_name'] ?? '').toString().compareTo((b['payor_name'] ?? '').toString()));
    } else if (_sortBy == 'Receipt Number') {
      list.sort((a, b) => (b['receipt_number'] ?? '').toString().compareTo((a['receipt_number'] ?? '').toString()));
    }

    return list;
  }

  double get _totalCollectedToday {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return _transactions.where((t) {
      if (_isTransactionVoided(t)) return false;
      final date = (t['transaction_date'] ?? t['created_at'] ?? '').toString();
      return date.startsWith(today);
    }).fold(0.0, (sum, t) => sum + _getAmount(t));
  }

  double get _totalFilteredAmount {
    if (_selectedPaymentMode == 'Voided') {
      return _filteredTransactions.fold(0.0, (sum, t) => sum + _getAmount(t));
    }
    return _filteredTransactions
        .where((t) => !_isTransactionVoided(t))
        .fold(0.0, (sum, t) => sum + _getAmount(t));
  }

  int get _voidedCount => _transactions.where((t) => _isTransactionVoided(t)).length;

  int get _totalPages {
    final total = _filteredTransactions.length;
    if (total == 0) return 1;
    return (total / _itemsPerPage).ceil();
  }

  void _onFilterChanged() {
    setState(() => _currentPage = 1);
  }

  Future<void> _pickCustomDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
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
        _onFilterChanged();
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

  @override
  Widget build(BuildContext context) {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final cardWhite = ParishColors.cardWhite;
    final borderGrey = ParishColors.borderGrey;

    final filtered = _filteredTransactions;
    final totalItems = filtered.length;
    final start = (_currentPage - 1) * _itemsPerPage;
    final end = min(start + _itemsPerPage, totalItems);
    final pagedTransactions = (start >= totalItems) ? <Map<String, dynamic>>[] : filtered.sublist(start, end);

    return RefreshIndicator(
      onRefresh: _loadTransactions,
      color: ParishColors.marianBlue,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Parish Cashier & Receipts Desk',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textDark),
                      ),
                      Text(
                        'Issue ecclesiastical receipts, oversee voided records, and manage parish ledgers',
                        style: TextStyle(color: textMuted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.assessment_outlined, color: ParishColors.marianBlue),
                      onPressed: _openRemittanceReports,
                      tooltip: 'Remittance & Financial Reports',
                    ),
                    IconButton(
                      icon: const Icon(Icons.style_outlined, color: ParishColors.marianBlue),
                      onPressed: _openTemplateManager,
                      tooltip: 'Receipt Templates & Canvas Studio',
                    ),
                    IconButton(
                      icon: const Icon(Icons.tune, color: ParishColors.marianBlue),
                      onPressed: _openManageParticulars,
                      tooltip: 'Manage Catalog Particulars (CRUD)',
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: ParishColors.marianBlue),
                      onPressed: _loadTransactions,
                      tooltip: 'Reload Ledger',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Top Action Primary Buttons
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 800;
                return isWide
                    ? Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ParishColors.oliveGreen,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _launchPos,
                          icon: const Icon(Icons.point_of_sale, size: 22),
                          label: const Text(
                            'Launch POS Cashier Terminal',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: ParishColors.marianBlue, width: 1.5),
                            foregroundColor: ParishColors.marianBlue,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => showNewTransactionModal(context, onTransactionSaved: _loadTransactions),
                          icon: const Icon(Icons.receipt_long, size: 18),
                          label: const Text(
                            'Single Record Entry',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ParishColors.marianBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _openRemittanceReports,
                          icon: const Icon(Icons.assessment_outlined, size: 18),
                          label: const Text(
                            'Remittance Reports',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
                    : Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ParishColors.oliveGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _launchPos,
                        icon: const Icon(Icons.point_of_sale, size: 20),
                        label: const Text(
                          'Launch POS Cashier Terminal',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
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
                              label: const Text('Single Entry', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
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
                              label: const Text('Reports', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),

            // Live KPI Summary Metric Cards
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 700;
                return Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardWhite,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderGrey),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Today's Valid Intake", style: TextStyle(fontSize: 11.5, color: textMuted, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(
                              '₱ ${_totalCollectedToday.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: ParishColors.oliveGreen),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardWhite,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderGrey),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedPaymentMode == 'Voided'
                                  ? 'Total Voided Amount'
                                  : (_selectedDateRangeFilter == 'All Dates' ? 'Total Valid Intake' : '$_selectedDateRangeFilter Intake'),
                              style: TextStyle(
                                fontSize: 11.5,
                                color: _selectedPaymentMode == 'Voided' ? ParishColors.mercyRed : textMuted,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₱ ${_totalFilteredAmount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                color: _selectedPaymentMode == 'Voided' ? ParishColors.mercyRed : ParishColors.goldAccent,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (isWide) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardWhite,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: borderGrey),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Active / Voided Ratio', style: TextStyle(fontSize: 11.5, color: textMuted, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(
                                '${_transactions.length - _voidedCount} Valid • $_voidedCount Voided',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ParishColors.marianBlue),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 18),

            // Search Bar
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: cardWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderGrey),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 22, color: ParishColors.marianBlue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) {
                        setState(() => _searchQuery = val);
                        _onFilterChanged();
                      },
                      style: TextStyle(fontSize: 13.5, color: textDark),
                      decoration: InputDecoration(
                        hintText: 'Search receipts by payor, receipt #, service, notes, phone...',
                        hintStyle: TextStyle(fontSize: 12.5, color: textMuted),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                        _onFilterChanged();
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Filters & Sorters
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 650;
                return isWide
                    ? Row(
                  children: [
                    Expanded(child: _buildDateRangeDropdown()),
                    const SizedBox(width: 12),
                    Expanded(child: _buildSortDropdown()),
                  ],
                )
                    : Column(
                  children: [
                    _buildDateRangeDropdown(),
                    const SizedBox(height: 10),
                    _buildSortDropdown(),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),

            // Payment Tender & Voided Filter Tabs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _paymentModeOptions.map((mode) {
                  final isSelected = _selectedPaymentMode == mode;
                  Color activeColor = ParishColors.marianBlue;
                  if (mode == 'Cash') activeColor = ParishColors.oliveGreen;
                  if (mode == 'GCash') activeColor = const Color(0xFF005CEE);
                  if (mode == 'Gratis') activeColor = ParishColors.goldAccent;
                  if (mode == 'Voided') activeColor = ParishColors.mercyRed;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: InkWell(
                      onTap: () {
                        setState(() => _selectedPaymentMode = mode);
                        _onFilterChanged();
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: isSelected ? activeColor : cardWhite,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isSelected ? activeColor : borderGrey),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (mode == 'Cash') Icon(Icons.payments_outlined, size: 14, color: isSelected ? Colors.white : activeColor),
                            if (mode == 'GCash') Icon(Icons.qr_code_2, size: 14, color: isSelected ? Colors.white : activeColor),
                            if (mode == 'Gratis') Icon(Icons.volunteer_activism, size: 14, color: isSelected ? Colors.white : activeColor),
                            if (mode == 'Voided') Icon(Icons.block, size: 14, color: isSelected ? Colors.white : activeColor),
                            if (mode != 'All') const SizedBox(width: 5),
                            Text(
                              mode == 'All' ? 'All Tenders' : (mode == 'Voided' ? 'Voided ($_voidedCount)' : mode),
                              style: TextStyle(
                                color: isSelected ? Colors.white : textDark,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 18),

            // Receipts Heading & Active Counts
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedPaymentMode == 'Voided'
                      ? 'Voided / Cancelled Slips ($totalItems)'
                      : 'Ecclesiastical Receipts ($totalItems)',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textDark),
                ),
                Text(
                  'Page $_currentPage of $_totalPages',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textMuted),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Receipts Listing Content
            _buildReceiptsList(pagedTransactions, totalItems),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Receipts List Builder
  // ===========================================================================

  Widget _buildReceiptsList(List<Map<String, dynamic>> pagedTransactions, int totalItems) {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final cardWhite = ParishColors.cardWhite;
    final borderGrey = ParishColors.borderGrey;

    if (_isLoading) {
      return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
    }

    if (_errorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: ParishColors.mercyRedSurface, borderRadius: BorderRadius.circular(12)),
        child: Text('Error loading transactions: $_errorMessage', style: const TextStyle(color: ParishColors.mercyRed)),
      );
    }

    if (_filteredTransactions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: cardWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderGrey),
        ),
        child: Column(
          children: [
            Icon(Icons.receipt_long, size: 44, color: textMuted),
            const SizedBox(height: 10),
            Text(
              _selectedPaymentMode == 'Voided'
                  ? 'No voided transactions found.'
                  : 'No receipt transactions match your criteria.',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textDark),
            ),
            const SizedBox(height: 4),
            Text(
              'Adjust filters or search keywords above.',
              style: TextStyle(fontSize: 12, color: textMuted),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        ...pagedTransactions.map((t) {
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
        }),
        const SizedBox(height: 14),
        _buildPaginationToolbar(totalItems),
      ],
    );
  }

  // ===========================================================================
  // Dropdown Builders & Toolbar
  // ===========================================================================

  Widget _buildDateRangeDropdown() {
    String displayLabel = _selectedDateRangeFilter;
    if (_selectedDateRangeFilter == 'Custom Date Range' && _customDateRange != null) {
      final s = _customDateRange!.start;
      final e = _customDateRange!.end;
      displayLabel = '${s.month}/${s.day} – ${e.month}/${e.day}';
    }

    return InkWell(
      onTap: () {
        if (_selectedDateRangeFilter == 'Custom Date Range') {
          _pickCustomDateRange();
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        decoration: BoxDecoration(
          color: ParishColors.cardWhite,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ParishColors.borderGrey),
        ),
        child: Row(
          children: [
            const Icon(Icons.date_range, size: 18, color: ParishColors.marianBlue),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedDateRangeFilter,
                  isExpanded: true,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                  items: _dateRangeOptions.map((opt) {
                    return DropdownMenuItem(
                      value: opt,
                      child: Text(opt == 'Custom Date Range' && _customDateRange != null ? 'Custom: $displayLabel' : opt),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      if (val == 'Custom Date Range') {
                        _pickCustomDateRange();
                      } else {
                        setState(() {
                          _selectedDateRangeFilter = val;
                          _customDateRange = null;
                        });
                        _onFilterChanged();
                      }
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ParishColors.borderGrey),
      ),
      child: Row(
        children: [
          const Icon(Icons.sort, size: 18, color: ParishColors.marianBlue),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _sortBy,
                isExpanded: true,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                items: _sortOptions.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _sortBy = val);
                    _onFilterChanged();
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

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
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ParishColors.marianBlue),
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
                color: _currentPage > 1 ? ParishColors.marianBlue : ParishColors.borderGrey,
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
                color: _currentPage < totalPages ? ParishColors.marianBlue : ParishColors.borderGrey,
                onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}