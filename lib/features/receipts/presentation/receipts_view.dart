// =============================================================================
// FILE: lib/features/receipts/presentation/receipts_view.dart
// =============================================================================

import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/services/records_sync_service.dart';
import '../services/secretary_service.dart';
import 'dialogs/new_transaction_dialog.dart';
import 'dialogs/receipt_detail_dialog.dart';
import 'pages/particulars_catalog_page.dart';
import 'pages/pos_cashier_page.dart';
import 'pages/receipt_template_management_page.dart';
import 'pages/remittance_report_page.dart';

enum ReceiptViewMode { cards, table }

class ReceiptManagementView extends StatefulWidget {
  const ReceiptManagementView({super.key});

  @override
  State<ReceiptManagementView> createState() => _ReceiptManagementViewState();
}

class _ReceiptManagementViewState extends State<ReceiptManagementView>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  late TabController _mainTabController;
  late AnimationController _skeletonAnimController;
  late Animation<double> _skeletonOpacityAnimation;

  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;
  String? _errorMessage;

  ReceiptViewMode _viewMode = ReceiptViewMode.cards;

  String _searchQuery = '';
  String _selectedPaymentMode = 'All';
  String _selectedDateRangeFilter = 'All Dates';
  DateTimeRange? _customDateRange;
  String _sortBy = 'Date: Latest First';
  bool _sortAscending = false;

  int _currentPage = 1;
  int _itemsPerPage = 10;

  final List<String> _paymentModeOptions = ['All', 'Cash', 'GCash', 'Gratis'];
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
    _mainTabController = TabController(length: 2, vsync: this);
    _mainTabController.addListener(() {
      if (!_mainTabController.indexIsChanging) {
        setState(() => _currentPage = 1);
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
    _loadTransactions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
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
  // Summary Aggregates
  // ===========================================================================

  int get _voidedCount => _transactions.where((t) => _isTransactionVoided(t)).length;
  int get _activeCount => _transactions.length - _voidedCount;

  double get _totalCollectedToday {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return _transactions.where((t) {
      if (_isTransactionVoided(t)) return false;
      final date = (t['transaction_date'] ?? t['created_at'] ?? '').toString();
      return date.startsWith(today);
    }).fold(0.0, (sum, t) => sum + _getAmount(t));
  }

  int get _todayTransactionsCount {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return _transactions.where((t) {
      if (_isTransactionVoided(t)) return false;
      final date = (t['transaction_date'] ?? t['created_at'] ?? '').toString();
      return date.startsWith(today);
    }).length;
  }

  double get _totalValidIntake =>
      _transactions.where((t) => !_isTransactionVoided(t)).fold(0.0, (sum, t) => sum + _getAmount(t));

  double get _totalCashIntake => _transactions
      .where((t) => !_isTransactionVoided(t) && _getTenderMode(t) == 'Cash')
      .fold(0.0, (sum, t) => sum + _getAmount(t));

  double get _totalGCashIntake => _transactions
      .where((t) => !_isTransactionVoided(t) && _getTenderMode(t) == 'GCash')
      .fold(0.0, (sum, t) => sum + _getAmount(t));

  // ===========================================================================
  // Filter Engine
  // ===========================================================================

  List<Map<String, dynamic>> get _activeTransactions {
    var list = _transactions.where((t) => !_isTransactionVoided(t)).toList();

    if (_selectedPaymentMode != 'All') {
      list = list.where((t) => _getTenderMode(t).toLowerCase() == _selectedPaymentMode.toLowerCase()).toList();
    }

    list = _applyDateRangeAndSearch(list);
    _applySorting(list);
    return list;
  }

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
        return payer.contains(q) || rNo.contains(q) || service.contains(q) || details.contains(q) || contact.contains(q);
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
      initialDateRange: _customDateRange ?? DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now),
    );

    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _selectedDateRangeFilter = 'Custom Date Range';
        _currentPage = 1;
      });
    }
  }

  // ===========================================================================
  // Navigation & Actions
  // ===========================================================================

  void _launchPos() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PosCashierPage(onTransactionCompleted: _loadTransactions)),
    );
  }

  void _openRemittanceReportsPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RemittanceReportPage()),
    );
  }

  void _openParticularsCatalogPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ParticularsCatalogPage()),
    ).then((_) => _loadTransactions());
  }

  void _openTemplateManagerPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ReceiptTemplateManagementPage()),
    );
  }

  // ===========================================================================
  // Hero Header with Restored Sync Status Ribbon
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
              errorBuilder: (_, __, ___) => Container(color: ParishColors.marianBlueSurface),
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
            padding: EdgeInsets.fromLTRB(isMobile ? 16 : 24, isMobile ? 16 : 22, isMobile ? 12 : 16, 14),
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
                            'Receipts & Cashier POS',
                            style: TextStyle(
                              fontFamily: 'Georgia',
                              fontFamilyFallback: const ['Times New Roman', 'serif'],
                              fontSize: isMobile ? 26 : 38,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                              color: ParishColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$_activeCount active transactions across parish financial accounts',
                            style: TextStyle(
                              fontSize: isMobile ? 12.5 : 14,
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
                SizedBox(height: isMobile ? 44 : 64),
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
          if (val == 'catalog') {
            _openParticularsCatalogPage();
          } else if (val == 'templates') {
            _openTemplateManagerPage();
          } else if (val == 'reports') {
            _openRemittanceReportsPage();
          } else if (val == 'refresh') {
            _loadTransactions();
            RecordsSyncService.instance.checkConnectivity();
          }
        },
        itemBuilder: (ctx) => [
          const PopupMenuItem(
            value: 'catalog',
            child: Row(
              children: [
                Icon(Icons.tune, size: 18, color: ParishColors.marianBlue),
                SizedBox(width: 10),
                Text('Offerings Catalog', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'templates',
            child: Row(
              children: [
                Icon(Icons.style_outlined, size: 18, color: ParishColors.goldAccent),
                SizedBox(width: 10),
                Text('Receipt Templates Studio', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'reports',
            child: Row(
              children: [
                Icon(Icons.assessment_outlined, size: 18, color: ParishColors.oliveGreen),
                SizedBox(width: 10),
                Text('Remittance Reports', style: TextStyle(fontSize: 13)),
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
              statusLabel = 'Syncing records with Supabase cloud...';
            } else if (pendingCount > 0) {
              pillColor = Colors.orange.shade50;
              textColor = Colors.orange.shade900;
              statusIcon = Icons.upload_file;
              statusLabel = 'Online • $pendingCount record(s) queued (Tap to Sync Now)';
            } else {
              pillColor = const Color(0xFFE8F5E9);
              textColor = const Color(0xFF2E7D32);
              statusIcon = Icons.check_circle;
              statusLabel = 'Online • All transactions synchronized';
            }

            final canSync = pendingCount > 0 && status != RecordsSyncStatus.syncing;

            return InkWell(
              onTap: canSync ? () => RecordsSyncService.instance.syncPendingChanges() : null,
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
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: textColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!isMobile)
                      ValueListenableBuilder<DateTime?>(
                        valueListenable: RecordsSyncService.lastSyncedAtNotifier,
                        builder: (context, lastSync, _) {
                          final text = lastSync != null
                              ? lastSync.toLocal().toString().substring(0, 16)
                              : 'Never';
                          return Padding(
                            padding: const EdgeInsets.only(left: 10),
                            child: Text(
                              'Last sync: $text',
                              style: TextStyle(fontSize: 11.5, color: textColor.withOpacity(0.85)),
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
  // Action Cards
  // ===========================================================================

  Widget _buildActionCardsRow(bool isDesktop) {
    final posCard = _buildDashboardActionCard(
      title: 'POS Cashier Terminal',
      subtitle: 'Express checkout and payment handling',
      icon: Icons.point_of_sale,
      isSolidBlue: true,
      onTap: _launchPos,
    );

    final singleReceiptCard = _buildDashboardActionCard(
      title: 'Single Receipt Entry',
      subtitle: 'Manual receipt recording',
      icon: Icons.receipt_long,
      isSolidBlue: false,
      borderColor: ParishColors.borderGrey,
      iconColor: ParishColors.marianBlue,
      onTap: () => showNewTransactionModal(context, onTransactionSaved: _loadTransactions),
    );

    final reportsCard = _buildDashboardActionCard(
      title: 'Remittance Reports',
      subtitle: 'Daily closing balances and ledgers',
      icon: Icons.assessment_outlined,
      isSolidBlue: false,
      borderColor: ParishColors.goldAccent,
      iconColor: ParishColors.goldAccent,
      titleColor: ParishColors.goldAccent,
      onTap: _openRemittanceReportsPage,
    );

    if (isDesktop) {
      return Row(
        children: [
          Expanded(child: posCard),
          const SizedBox(width: 16),
          Expanded(child: singleReceiptCard),
          const SizedBox(width: 16),
          Expanded(child: reportsCard),
        ],
      );
    }

    return Column(
      children: [
        posCard,
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: singleReceiptCard),
            const SizedBox(width: 10),
            Expanded(child: reportsCard),
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
    Color? borderColor,
    Color? iconColor,
    Color? titleColor,
    required VoidCallback onTap,
  }) {
    final bgColor = isSolidBlue ? ParishColors.marianBlue : ParishColors.cardWhite;
    final primaryTextColor = isSolidBlue ? Colors.white : (titleColor ?? ParishColors.textDark);
    final secondaryTextColor = isSolidBlue ? Colors.white70 : ParishColors.textMuted;
    final resolvedIconColor = isSolidBlue ? Colors.white : (iconColor ?? ParishColors.marianBlue);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSolidBlue ? Colors.transparent : (borderColor ?? ParishColors.borderGrey),
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
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSolidBlue
                    ? Colors.white.withOpacity(0.18)
                    : (iconColor?.withOpacity(0.12) ?? ParishColors.marianBlueSurface),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: resolvedIconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
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
                      fontSize: 11.5,
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
  // Distinct Financial Overview Deck (KPI Strips)
  // ===========================================================================

  Widget _buildFinancialOverviewDeck(bool isMobile) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final int crossAxisCount = width > 1050 ? 5 : (width > 600 ? 3 : 2);
        final double itemWidth = (width - ((crossAxisCount - 1) * 12)) / crossAxisCount;

        final items = [
          _buildKpiCard(
            label: "Today's Intake",
            value: '₱${_totalCollectedToday.toStringAsFixed(0)}',
            subtitle: '$_todayTransactionsCount transactions',
            icon: Icons.today_outlined,
            color: ParishColors.oliveGreen,
            surfaceColor: ParishColors.oliveGreenSurface,
            onTap: () => setState(() {
              _mainTabController.index = 0;
              _selectedDateRangeFilter = 'Today';
              _currentPage = 1;
            }),
          ),
          _buildKpiCard(
            label: 'Total Collections',
            value: '₱${_totalValidIntake.toStringAsFixed(0)}',
            subtitle: '$_activeCount valid slips',
            icon: Icons.account_balance_wallet_outlined,
            color: ParishColors.marianBlue,
            surfaceColor: ParishColors.marianBlueSurface,
            onTap: () => setState(() {
              _mainTabController.index = 0;
              _selectedDateRangeFilter = 'All Dates';
              _selectedPaymentMode = 'All';
              _currentPage = 1;
            }),
          ),
          _buildKpiCard(
            label: 'Cash Tendered',
            value: '₱${_totalCashIntake.toStringAsFixed(0)}',
            subtitle: 'Physical bank notes',
            icon: Icons.payments_outlined,
            color: const Color(0xFF164E87),
            surfaceColor: const Color(0xFFEDF4FB),
            onTap: () => setState(() {
              _mainTabController.index = 0;
              _selectedPaymentMode = 'Cash';
              _currentPage = 1;
            }),
          ),
          _buildKpiCard(
            label: 'GCash Intake',
            value: '₱${_totalGCashIntake.toStringAsFixed(0)}',
            subtitle: 'Digital e-wallet',
            icon: Icons.qr_code_2,
            color: const Color(0xFF005CEE),
            surfaceColor: const Color(0xFFEEF4FF),
            onTap: () => setState(() {
              _mainTabController.index = 0;
              _selectedPaymentMode = 'GCash';
              _currentPage = 1;
            }),
          ),
          _buildKpiCard(
            label: 'Voided Slips',
            value: '$_voidedCount',
            subtitle: 'Audit excluded',
            icon: Icons.block,
            color: ParishColors.mercyRed,
            surfaceColor: ParishColors.mercyRedSurface,
            onTap: () => setState(() {
              _mainTabController.index = 1;
              _currentPage = 1;
            }),
          ),
        ];

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: items.map((w) => SizedBox(width: itemWidth, child: w)).toList(),
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
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: ParishColors.cardWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: ParishColors.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 10.5, color: ParishColors.textDark.withOpacity(0.7)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
                const Icon(Icons.search, size: 21, color: ParishColors.marianBlue),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: (val) => setState(() {
                      _searchQuery = val;
                      _currentPage = 1;
                    }),
                    style: TextStyle(fontSize: 14, color: ParishColors.textDark),
                    decoration: InputDecoration(
                      hintText: isMobile
                          ? 'Search payor, receipt #, service...'
                          : 'Search by payor name, receipt number, service, or notes...',
                      hintStyle: TextStyle(fontSize: 13, color: ParishColors.textMuted),
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
              color: _hasActiveFilters ? ParishColors.marianBlueSurface : ParishColors.cardWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _hasActiveFilters ? ParishColors.marianBlue : ParishColors.borderGrey,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.tune,
                  size: 18,
                  color: _hasActiveFilters ? ParishColors.marianBlue : ParishColors.textDark,
                ),
                if (!isMobile || _hasActiveFilters) ...[
                  const SizedBox(width: 8),
                  Text(
                    _hasActiveFilters ? 'Filter ($_activeFilterCount)' : 'Filter',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _hasActiveFilters ? ParishColors.marianBlue : ParishColors.textDark,
                    ),
                  ),
                ],
                const SizedBox(width: 4),
                Icon(
                  Icons.expand_more,
                  size: 18,
                  color: _hasActiveFilters ? ParishColors.marianBlue : ParishColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // Section Header with Tabs and View Mode Controls
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
                    'Parish Receipts Ledger',
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontFamilyFallback: const ['Times New Roman', 'serif'],
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: ParishColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Audit official receipts, monitor collections, and inspect voided slips.',
                    style: TextStyle(fontSize: 13, color: ParishColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
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
                  Icon(Icons.receipt_long_outlined, size: 15, color: ParishColors.textDark),
                  const SizedBox(width: 5),
                  Text(
                    '${_currentTabTransactions.length} records',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ParishColors.textDark),
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
            Container(
              height: 38,
              decoration: BoxDecoration(
                color: ParishColors.cardWhite,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ParishColors.borderGrey),
              ),
              child: TabBar(
                controller: _mainTabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: Colors.white,
                unselectedLabelColor: ParishColors.textMuted,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: _mainTabController.index == 1 ? ParishColors.mercyRed : ParishColors.marianBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                tabs: [
                  Tab(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        'Active Receipts ($_activeCount)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ),
                  Tab(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        'Voided Archive ($_voidedCount)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),

            Container(
              height: 36,
              decoration: BoxDecoration(
                color: ParishColors.cardWhite,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ParishColors.borderGrey),
              ),
              child: ToggleButtons(
                isSelected: [
                  _viewMode == ReceiptViewMode.cards,
                  _viewMode == ReceiptViewMode.table,
                ],
                onPressed: (idx) => setState(() {
                  _viewMode = idx == 0 ? ReceiptViewMode.cards : ReceiptViewMode.table;
                }),
                borderRadius: BorderRadius.circular(7),
                selectedColor: Colors.white,
                fillColor: ParishColors.marianBlue,
                color: ParishColors.textMuted,
                constraints: const BoxConstraints(minHeight: 32, minWidth: 36),
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
                label: const Text('Reset', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: ParishColors.mercyRed)),
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
      label: Text(label, style: TextStyle(fontSize: 11, color: ParishColors.textDark)),
      backgroundColor: ParishColors.marianBlueSurface,
      deleteIcon: const Icon(Icons.close, size: 13),
      onDeleted: onDeleted,
      visualDensity: VisualDensity.compact,
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

                  Text(
                    'Sort Sequence',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: ParishColors.textDark),
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

                  Text(
                    'Date Range Filter',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: ParishColors.textDark),
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
                          _pickCustomDateRange().then((_) => setSheetState(() {}));
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

                  if (_mainTabController.index == 0) ...[
                    Text(
                      'Payment Tender Mode',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: ParishColors.textDark),
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
  // Skeleton Loader
  // ===========================================================================

  Widget _buildSkeletonLoading() {
    return AnimatedBuilder(
      animation: _skeletonOpacityAnimation,
      builder: (context, child) => Opacity(
        opacity: _skeletonOpacityAnimation.value,
        child: Column(
          children: List.generate(
            4,
                (index) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              height: 88,
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
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // Build Main Dashboard Shell
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double screenWidth = constraints.maxWidth;
        final bool isDesktop = screenWidth >= 1080;
        final bool isMobile = screenWidth < 650;

        return RefreshIndicator(
          onRefresh: _loadTransactions,
          color: ParishColors.marianBlue,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 28,
              vertical: isMobile ? 14 : 24,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1400),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Hero Header with Reverted Sync Ribbon
                    _buildHeroHeader(isMobile),
                    const SizedBox(height: 16),

                    // 2. Action Cards
                    _buildActionCardsRow(isDesktop),
                    const SizedBox(height: 16),

                    // 3. Financial KPI Overview Deck
                    if (_searchQuery.isEmpty && !_hasActiveFilters) ...[
                      _buildFinancialOverviewDeck(isMobile),
                      const SizedBox(height: 18),
                    ],

                    // 4. Search & Filter Bar
                    _buildSearchAndFilterRow(isMobile),
                    const SizedBox(height: 20),

                    // 5. Section Header + Tabs + View Mode Toggle
                    _buildSectionHeader(isMobile),
                    const SizedBox(height: 14),

                    // 6. Transactions List / Table
                    if (_isLoading)
                      _buildSkeletonLoading()
                    else if (_mainTabController.index == 0)
                      _buildReceiptsListSection(constraints.maxWidth, isVoidTab: false)
                    else
                      _buildReceiptsListSection(constraints.maxWidth, isVoidTab: true),

                    const SizedBox(height: 40),
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
  // Receipts List & Table Presentation
  // ===========================================================================

  Widget _buildReceiptsListSection(double availableWidth, {required bool isVoidTab}) {
    final list = isVoidTab ? _voidedTransactions : _activeTransactions;
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isVoidTab) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: ParishColors.mercyRedSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ParishColors.mercyRed.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.block, color: ParishColors.mercyRed, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Voided & cancelled receipts are archived here for financial audit. Amounts are excluded from collection balances.',
                    style: TextStyle(fontSize: 12, color: ParishColors.mercyRed, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],

        if (list.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(36),
            decoration: BoxDecoration(
              color: ParishColors.cardWhite,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ParishColors.borderGrey),
            ),
            child: Column(
              children: [
                Icon(Icons.search_off_outlined, size: 40, color: ParishColors.textMuted),
                const SizedBox(height: 10),
                Text(
                  isVoidTab ? 'No voided receipts found on record.' : 'No receipts match your search or filters.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                ),
              ],
            ),
          )
        else ...[
          if (_viewMode == ReceiptViewMode.cards)
            ...paged.map((t) => _buildReceiptCard(t))
          else
            _buildReceiptsTableView(paged, availableWidth, isVoidTab: isVoidTab),
          const SizedBox(height: 14),
          _buildPaginationToolbar(totalItems),
        ],
      ],
    );
  }

  Widget _buildReceiptCard(Map<String, dynamic> t) {
    final String rNo = (t['receipt_number'] ?? 'REC-XXXX').toString();
    final String payor = (t['payor_name'] ?? 'Parishioner').toString();
    final String service = (t['related_service'] ?? t['transaction_type'] ?? 'Parish Service').toString();
    final double amountVal = _getAmount(t);
    final String dateRaw = (t['transaction_date'] ?? t['created_at'] ?? '').toString();
    final String date = dateRaw.length >= 10 ? dateRaw.substring(0, 10) : dateRaw;
    final String status = (t['transaction_status'] ?? 'paid').toString().toUpperCase();
    final String mode = _getTenderMode(t);
    final bool isVoided = _isTransactionVoided(t);

    Color themeColor = ParishColors.marianBlue;
    Color surfaceColor = ParishColors.marianBlueSurface;
    IconData icon = Icons.receipt_long;

    if (isVoided) {
      themeColor = ParishColors.mercyRed;
      surfaceColor = ParishColors.mercyRedSurface;
      icon = Icons.block;
    } else if (mode == 'Cash') {
      themeColor = ParishColors.oliveGreen;
      surfaceColor = ParishColors.oliveGreenSurface;
      icon = Icons.payments_outlined;
    } else if (mode == 'GCash') {
      themeColor = const Color(0xFF005CEE);
      surfaceColor = const Color(0xFFEEF4FF);
      icon = Icons.qr_code_2;
    } else if (mode == 'Gratis') {
      themeColor = ParishColors.goldAccent;
      surfaceColor = const Color(0xFFFFF7E6);
      icon = Icons.volunteer_activism_outlined;
    }

    return InkWell(
      onTap: () {
        showReceiptDetailModal(
          context,
          receiptNo: rNo,
          payer: payor,
          purpose: service,
          amount: '₱ ${amountVal.toStringAsFixed(2)}',
          date: date,
          payorContact: t['payor_contact']?.toString(),
          transactionDetails: t['transaction_details']?.toString(),
          paymentMode: mode,
          transactionId: t['transaction_id']?.toString(),
          status: status,
          onTransactionUpdated: _loadTransactions,
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ParishColors.cardWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: themeColor.withOpacity(0.35), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: themeColor.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: themeColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: themeColor.withOpacity(0.4)),
                        ),
                        child: Text(
                          isVoided ? 'VOIDED SLIP' : mode.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: themeColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Text(
                        rNo,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ParishColors.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),

                  Text(
                    payor,
                    style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                  ),
                  const SizedBox(height: 2),

                  Text(
                    service,
                    style: TextStyle(fontSize: 12, color: ParishColors.textDark.withOpacity(0.85)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '₱ ${amountVal.toStringAsFixed(2)} • $date',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: themeColor,
                          decoration: isVoided ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      Row(
                        children: [
                          Text('Inspect', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: themeColor)),
                          const SizedBox(width: 2),
                          Icon(Icons.arrow_forward, size: 13, color: themeColor),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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
                          payorContact: t['payor_contact']?.toString(),
                          transactionDetails: t['transaction_details']?.toString(),
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

  // ===========================================================================
  // Pagination Toolbar
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