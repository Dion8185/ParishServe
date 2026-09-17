import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../receipts/services/secretary_service.dart';

class PfcDashboardWidget extends StatefulWidget {
  const PfcDashboardWidget({super.key});

  @override
  State<PfcDashboardWidget> createState() => _PfcDashboardWidgetState();
}

class _PfcDashboardWidgetState extends State<PfcDashboardWidget> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _transactions = [];
  double _totalCollections = 0.0;

  @override
  void initState() {
    super.initState();
    _loadAuditData();
  }

  Future<void> _loadAuditData() async {
    setState(() => _isLoading = true);
    try {
      final txns = await SecretaryService.getTransactions();
      double sum = 0.0;
      for (var t in txns) {
        sum += double.tryParse(t['amount_received'].toString()) ?? 0.0;
      }
      if (!mounted) return;
      setState(() {
        _transactions = txns;
        _totalCollections = sum;
      });
    } catch (e) {
      debugPrint('Error loading audit data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // PFC Header Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: ParishColors.oliveGreenSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ParishColors.oliveGreen, width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ParishColors.oliveGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.analytics, size: 32, color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Parish Finance Council Audit Desk',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Independent Financial Inspection & Asset Valuation Review (Read-Only)',
                        style: TextStyle(fontSize: 13, color: ParishColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Financial Analytics Summary Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: ParishColors.cardWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ParishColors.borderGrey),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Monthly Collection Audit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: ParishColors.marianBlueSurface,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('Audited & Verified', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ParishColors.marianBlue)),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Gross Collections Recognized:', style: TextStyle(fontSize: 14, color: ParishColors.textMuted)),
                    Text('₱ ${_totalCollections.toStringAsFixed(2)}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: ParishColors.oliveGreen)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Audited Receipts:', style: TextStyle(fontSize: 13, color: ParishColors.textMuted)),
                    Text('${_transactions.length} Entries', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Read-Only Transaction Inspection Trail
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Official Receipt Audit Trail', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
              Text('Read-Only Access', style: TextStyle(fontSize: 13, color: ParishColors.textMuted)),
            ],
          ),
          const SizedBox(height: 10),

          _isLoading
              ? const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
              : _transactions.isEmpty
              ? Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: ParishColors.cardWhite, borderRadius: BorderRadius.circular(12)),
            child: const Text('No transactions recorded for audit.'),
          )
              : Column(
            children: _transactions.map((txn) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: ParishColors.cardWhite,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ParishColors.borderGrey),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long, color: ParishColors.marianBlue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(txn['receipt_number'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ParishColors.marianBlue)),
                          Text('Payer: ${txn['payer_name']} (${txn['transaction_type']})', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
                        ],
                      ),
                    ),
                    Text(
                      '₱ ${txn['amount_received']}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ParishColors.oliveGreen),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}