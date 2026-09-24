import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../auth/services/auth_service.dart';

class ReceiptPdfGenerator {
  ReceiptPdfGenerator._();

  static const PdfColor marianBlue = PdfColor.fromInt(0xFF164E87);
  static const PdfColor goldAccent = PdfColor.fromInt(0xFFD49B18);
  static const PdfColor textDark = PdfColor.fromInt(0xFF1E293B);
  static const PdfColor textMuted = PdfColor.fromInt(0xFF64748B);
  static const PdfColor borderGrey = PdfColor.fromInt(0xFFCBD5E1);

  /// Generates an official ecclesiastical receipt (80mm POS thermal roll format or standard slip)
  static Future<Uint8List> generateReceiptPdf({
    required String receiptNumber,
    required String payorName,
    String? payorContact,
    required String relatedService,
    required String transactionDetails,
    required double amount,
    String paymentMode = 'Cash',
    String? dateString,
    bool isThermalRoll = true,
  }) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final issuedDate = dateString ??
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final cashierName = AuthService.currentUser?.fullName ?? 'Parish Secretariat';

    // 80mm Thermal Receipt format vs Standard Slip (A6)
    final pageFormat = isThermalRoll
        ? const PdfPageFormat(
      80 * PdfPageFormat.mm,
      double.infinity,
      marginAll: 4 * PdfPageFormat.mm,
    )
        : PdfPageFormat.a6;

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // Parish Header
                pw.Text(
                  'DIOCESE OF SAN PABLO',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: textMuted,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'ST. JOHN PAUL II PARISH',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: marianBlue,
                  ),
                ),
                pw.Text(
                  'Brgy. Labuin, Santa Cruz, Laguna',
                  style: const pw.TextStyle(fontSize: 8, color: textMuted),
                ),
                pw.SizedBox(height: 6),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: goldAccent, width: 0.8),
                    borderRadius: pw.BorderRadius.circular(3),
                  ),
                  child: pw.Text(
                    'OFFICIAL ECCLESIASTICAL RECEIPT',
                    style: pw.TextStyle(
                      fontSize: 7.5,
                      fontWeight: pw.FontWeight.bold,
                      color: marianBlue,
                    ),
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Divider(thickness: 0.6, color: borderGrey),

                // Receipt Metadata
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Receipt No:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    pw.Text(receiptNumber, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: marianBlue)),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Date / Time:', style: const pw.TextStyle(fontSize: 8, color: textMuted)),
                    pw.Text(issuedDate, style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Cashier / Desk:', style: const pw.TextStyle(fontSize: 8, color: textMuted)),
                    pw.Text(cashierName, style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
                pw.Divider(thickness: 0.6, color: borderGrey),

                // Payor Info
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('PAYOR:', style: pw.TextStyle(fontSize: 7.5, color: textMuted, fontWeight: pw.FontWeight.bold)),
                      pw.Text(payorName, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: textDark)),
                      if (payorContact != null && payorContact.isNotEmpty)
                        pw.Text('Contact: $payorContact', style: const pw.TextStyle(fontSize: 7.5, color: textMuted)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Divider(thickness: 0.6, color: borderGrey),

                // Items / Offering Description
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text('PARTICULARS / OFFERING:', style: pw.TextStyle(fontSize: 7.5, color: textMuted, fontWeight: pw.FontWeight.bold)),
                ),
                pw.SizedBox(height: 4),
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text(
                    transactionDetails.isNotEmpty ? transactionDetails : relatedService,
                    style: const pw.TextStyle(fontSize: 8, color: textDark, lineSpacing: 1.5),
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Divider(thickness: 0.6, color: borderGrey),

                // Financial Summary
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Payment Mode:', style: const pw.TextStyle(fontSize: 8.5)),
                    pw.Text(paymentMode.toUpperCase(), style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('TOTAL AMOUNT:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.Text(
                      'PHP ${amount.toStringAsFixed(2)}',
                      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: marianBlue),
                    ),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Divider(thickness: 0.6, color: borderGrey),

                // Canonical Footer
                pw.SizedBox(height: 4),
                pw.Text(
                  'Thank you for your generous stewardship and offering.',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 7.5, color: textMuted),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'TOTUS TUUS',
                  style: pw.TextStyle(
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                    color: goldAccent,
                    letterSpacing: 1.2,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'This canonical receipt confirms voluntary spiritual stipend / parish contribution.',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 6.5, color: textMuted),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Sends the compiled receipt directly to the OS print spooler / thermal printer
  static Future<void> printReceipt({
    required String receiptNumber,
    required String payorName,
    String? payorContact,
    required String relatedService,
    required String transactionDetails,
    required double amount,
    String paymentMode = 'Cash',
    String? dateString,
  }) async {
    final pdfBytes = await generateReceiptPdf(
      receiptNumber: receiptNumber,
      payorName: payorName,
      payorContact: payorContact,
      relatedService: relatedService,
      transactionDetails: transactionDetails,
      amount: amount,
      paymentMode: paymentMode,
      dateString: dateString,
      isThermalRoll: true,
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdfBytes,
      name: 'Receipt_$receiptNumber',
    );
  }
}