import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../services/secretary_service.dart';
import 'dialogs/manage_particulars_dialog.dart';
import 'dialogs/new_transaction_dialog.dart';
import 'dialogs/receipt_detail_dialog.dart';
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
  String _searchQuery = '';
  String _filterStatus = 'All';

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

  List<Map<String, dynamic>> get _filteredTransactions {
    var list = _transactions;
    if (_filterStatus != 'All') {
      list = list.where((t) {
        final status = (t['transaction_status'] ?? 'paid').toString().toLowerCase();
        return status == _filterStatus.toLowerCase();
      }).toList();
    }
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      list = list.where((t) {
        final payer = (t['payor_name'] ?? '').toString().toLowerCase();
        final rNo = (t['receipt_number'] ?? '').toString().toLowerCase();
        final service = (t['related_service'] ?? '').toString().toLowerCase();
        return payer.contains(q) || rNo.contains(q) || service.contains(q);
      }).toList();
    }
    return list;
  }

  double get _totalCollectedToday {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return _transactions.where((t) {
      final date = (t['transaction_date'] ?? '').toString();
      return date.startsWith(today);
    }).fold(0.0, (sum, t) => sum + (double.tryParse(t['transaction_amount']?.toString() ?? '0') ?? 0.0));
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

  @override
  Widget build(BuildContext context) {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final cardWhite = ParishColors.cardWhite;
    final borderGrey = ParishColors.borderGrey;

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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Parish Cashier & Receipts',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textDark),
                    ),
                    Text(
                      'Issue ecclesiastical receipts, process walk-in collections, and customize templates',
                      style: TextStyle(color: textMuted, fontSize: 13),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.style_outlined, color: ParishColors.marianBlue),
                      onPressed: _openTemplateManager,
                      tooltip: 'Receipt Templates & Canvas Designer',
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

            // Top Action Cards: POS Cashier, Single Entry, and Template Studio
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 700;
                return isWide
                    ? Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: SizedBox(
                        height: 54,
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
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 54,
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
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 54,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: ParishColors.goldAccent, width: 1.5),
                            foregroundColor: ParishColors.goldAccent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _openTemplateManager,
                          icon: const Icon(Icons.design_services_outlined, size: 18),
                          label: const Text(
                            'Receipt Templates',
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
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
                              label: const Text('Single Entry', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: ParishColors.goldAccent, width: 1.5),
                                foregroundColor: ParishColors.goldAccent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: _openTemplateManager,
                              icon: const Icon(Icons.design_services_outlined, size: 16),
                              label: const Text('Templates', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
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

            // Daily Summary Cards
            Row(
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
                        Text("Today's Total Intake", style: TextStyle(fontSize: 12, color: textMuted, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          '₱ ${_totalCollectedToday.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: ParishColors.oliveGreen),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
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
                        Text('Ledger Records', style: TextStyle(fontSize: 12, color: textMuted, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          '${_transactions.length} Receipts',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: ParishColors.marianBlue),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Search Bar
            Container(
              height: 48,
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
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: TextStyle(fontSize: 13.5, color: textDark),
                      decoration: InputDecoration(
                        hintText: 'Search receipts by payor name, receipt number, or service...',
                        hintStyle: TextStyle(fontSize: 12.5, color: textMuted),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Receipts Listing
            Text(
              'Ecclesiastical Receipts (${_filteredTransactions.length})',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark),
            ),
            const SizedBox(height: 12),

            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
            else if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: ParishColors.mercyRedSurface, borderRadius: BorderRadius.circular(12)),
                child: Text('Error loading transactions: $_errorMessage', style: const TextStyle(color: ParishColors.mercyRed)),
              )
            else if (_filteredTransactions.isEmpty)
                Container(
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
                      Text('No receipt transactions found.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textDark)),
                      const SizedBox(height: 4),
                      Text('Tap "Launch POS Cashier Terminal" or "Single Entry" above to process transactions.', style: TextStyle(fontSize: 12, color: textMuted)),
                    ],
                  ),
                )
              else
                ..._filteredTransactions.map((t) {
                  final rNo = t['receipt_number'] ?? 'REC-XXXX';
                  final payor = t['payor_name'] ?? 'Parishioner';
                  final service = t['related_service'] ?? t['transaction_type'] ?? 'Parish Service';
                  final amountVal = double.tryParse(t['transaction_amount']?.toString() ?? '0') ?? 0.0;
                  final amount = 'P ${amountVal.toStringAsFixed(2)}';
                  final dateRaw = (t['transaction_date'] ?? t['created_at'] ?? '').toString();
                  final date = dateRaw.length >= 10 ? dateRaw.substring(0, 10) : dateRaw;
                  final status = (t['transaction_status'] ?? 'paid').toString().toUpperCase();

                  return ReceiptCard(
                    receiptNo: rNo,
                    payer: payor,
                    purpose: service,
                    amount: amount,
                    date: date,
                    status: status,
                    payorContact: t['payor_contact']?.toString(),
                    transactionDetails: t['transaction_details']?.toString(),
                    paymentMode: (t['transaction_type'] ?? 'cash').toString(),
                  );
                }),
          ],
        ),
      ),
    );
  }
}