import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../services/receipt_pdf_generator.dart';

void showReceiptDetailModal(
    BuildContext context, {
      required String receiptNo,
      required String payer,
      required String purpose,
      required String amount,
      required String date,
      String? payorContact,
      String? transactionDetails,
      String paymentMode = 'Cash',
    }) {
  showDialog(
    context: context,
    builder: (ctx) => _ReceiptDetailDialog(
      receiptNo: receiptNo,
      payer: payer,
      purpose: purpose,
      amount: amount,
      date: date,
      payorContact: payorContact,
      transactionDetails: transactionDetails,
      paymentMode: paymentMode,
    ),
  );
}

class _ReceiptDetailDialog extends StatefulWidget {
  final String receiptNo;
  final String payer;
  final String purpose;
  final String amount;
  final String date;
  final String? payorContact;
  final String? transactionDetails;
  final String paymentMode;

  const _ReceiptDetailDialog({
    required this.receiptNo,
    required this.payer,
    required this.purpose,
    required this.amount,
    required this.date,
    this.payorContact,
    this.transactionDetails,
    this.paymentMode = 'Cash',
  });

  @override
  State<_ReceiptDetailDialog> createState() => _ReceiptDetailDialogState();
}

class _ReceiptDetailDialogState extends State<_ReceiptDetailDialog> {
  bool _isPrinting = false;

  double get _numericAmount {
    final clean = widget.amount.replaceAll('₱', '').replaceAll(',', '').trim();
    return double.tryParse(clean) ?? 0.0;
  }

  Future<void> _handlePrint() async {
    setState(() => _isPrinting = true);
    try {
      await ReceiptPdfGenerator.printReceipt(
        receiptNumber: widget.receiptNo,
        payorName: widget.payer,
        payorContact: widget.payorContact,
        relatedService: widget.purpose,
        transactionDetails: widget.transactionDetails ?? widget.purpose,
        amount: _numericAmount,
        paymentMode: widget.paymentMode,
        dateString: widget.date,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Print error: $e'), backgroundColor: ParishColors.mercyRed),
      );
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColorMuted = ParishColors.textMuted;
    final textDark = ParishColors.textDark;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: ParishColors.cardWhite,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ParishColors.oliveGreenSurface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.receipt_long, color: ParishColors.oliveGreen, size: 22),
              ),
              const SizedBox(width: 10),
              const Text('Parish Receipt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: ParishColors.marianBlueSurface,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              widget.receiptNo,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ParishColors.marianBlue),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PAYOR:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColorMuted)),
            Text(widget.payer, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDark)),
            if (widget.payorContact != null && widget.payorContact!.isNotEmpty)
              Text('Contact: ${widget.payorContact}', style: TextStyle(fontSize: 12, color: textColorMuted)),
            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Date Issued:', style: TextStyle(fontSize: 12.5, color: textColorMuted)),
                Text(widget.date, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: textDark)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Payment Mode:', style: TextStyle(fontSize: 12.5, color: textColorMuted)),
                Text(widget.paymentMode.toUpperCase(), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: textDark)),
              ],
            ),
            const Divider(height: 20),

            Text('PURPOSE / PARTICULARS:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColorMuted)),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ParishColors.backgroundLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ParishColors.borderGrey),
              ),
              child: Text(
                (widget.transactionDetails != null && widget.transactionDetails!.isNotEmpty)
                    ? widget.transactionDetails!
                    : widget.purpose,
                style: TextStyle(fontSize: 12.5, color: textDark, height: 1.4),
              ),
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ParishColors.oliveGreenSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ParishColors.oliveGreen.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Amount Paid:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  Text(
                    widget.amount,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: ParishColors.oliveGreen),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Close', style: TextStyle(color: textColorMuted)),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: ParishColors.marianBlue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _isPrinting ? null : _handlePrint,
          icon: _isPrinting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.print, size: 18),
          label: Text(_isPrinting ? 'Printing...' : 'Print / Reprint Receipt'),
        ),
      ],
    );
  }
}