import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';

void showReceiptDetailModal(
    BuildContext context, {
      required String receiptNo,
      required String payer,
      required String purpose,
      required String amount,
      required String date,
    }) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Parish Receipt', style: TextStyle(fontWeight: FontWeight.bold)),
          Text(receiptNo, style: const TextStyle(fontSize: 13, color: ParishColors.marianBlue)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Payer: $payer', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text('Purpose: $purpose', style: const TextStyle(fontSize: 14, color: ParishColors.textMuted)),
          Text('Date: $date', style: const TextStyle(fontSize: 13, color: ParishColors.textMuted)),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Amount:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text(amount, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: ParishColors.oliveGreen)),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: ParishColors.marianBlue, foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(ctx),
          icon: const Icon(Icons.print, size: 18),
          label: const Text('Reprint'),
        ),
      ],
    ),
  );
}