import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../dialogs/receipt_detail_dialog.dart';

class ReceiptCard extends StatelessWidget {
  final String receiptNo;
  final String payer;
  final String purpose;
  final String amount;
  final String date;
  final String status;

  const ReceiptCard({
    super.key,
    required this.receiptNo,
    required this.payer,
    required this.purpose,
    required this.amount,
    required this.date,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => showReceiptDetailModal(
        context,
        receiptNo: receiptNo,
        payer: payer,
        purpose: purpose,
        amount: amount,
        date: date,
      ),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ParishColors.cardWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ParishColors.borderGrey),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ParishColors.oliveGreenSurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.description, color: ParishColors.oliveGreen, size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        receiptNo,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ParishColors.marianBlue),
                      ),
                      Text(
                        amount,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: ParishColors.textDark),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(payer, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
                  Text(purpose, style: TextStyle(fontSize: 13, color: ParishColors.textMuted)),
                  const SizedBox(height: 4),
                  Text(date, style: TextStyle(fontSize: 12, color: ParishColors.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}