import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import 'dialogs/new_transaction_dialog.dart';
import 'widgets/receipt_card.dart';

class ReceiptManagementView extends StatelessWidget {
  const ReceiptManagementView({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Parish Receipts', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const Text('Issue ecclesiastical receipts & manage service fees', style: TextStyle(color: ParishColors.textMuted)),
          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: ParishColors.oliveGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => showNewTransactionModal(context),
              icon: const Icon(Icons.receipt, size: 26),
              label: const Text('+ Record New Transaction', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 24),

          const Text('Recent Ecclesiastical Receipts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          const ReceiptCard(
            receiptNo: 'REC-2026-00892',
            payer: 'Theresa Sanchez',
            purpose: 'Baptismal Certificate Request (Pabuklat)',
            amount: '₱ 150.00',
            date: 'Today, 10:15 AM',
            status: 'PAID',
          ),
          const ReceiptCard(
            receiptNo: 'REC-2026-00891',
            payer: 'Fernando Gomez',
            purpose: 'Thanksgiving Mass Intention',
            amount: '₱ 300.00',
            date: 'Today, 09:30 AM',
            status: 'PAID',
          ),
          const ReceiptCard(
            receiptNo: 'REC-2026-00890',
            payer: 'Anonymous Benefactor',
            purpose: 'Church Altar Repair Donation',
            amount: '₱ 1,000.00',
            date: 'Yesterday, 04:00 PM',
            status: 'PAID',
          ),
        ],
      ),
    );
  }
}