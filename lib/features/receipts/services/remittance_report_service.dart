import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/services/auth_service.dart';

enum RemittancePeriodType { daily, monthly, yearly }

class RemittanceItem {
  final String receiptNumber;
  final DateTime transactionDate;
  final String payorName;
  final String? payorContact;
  final String relatedService;
  final String details;
  final double amount;
  final String paymentMode;
  final String? encodedBy;

  const RemittanceItem({
    required this.receiptNumber,
    required this.transactionDate,
    required this.payorName,
    this.payorContact,
    required this.relatedService,
    required this.details,
    required this.amount,
    required this.paymentMode,
    this.encodedBy,
  });

  String get formattedDate {
    final y = transactionDate.year.toString();
    final m = transactionDate.month.toString().padLeft(2, '0');
    final d = transactionDate.day.toString().padLeft(2, '0');
    final h = transactionDate.hour.toString().padLeft(2, '0');
    final min = transactionDate.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min';
  }
}

class RemittanceReportData {
  final RemittancePeriodType periodType;
  final DateTime selectedDate;
  final String periodLabel;
  final List<RemittanceItem> validReceipts;
  final int totalCount;
  final double totalCash;
  final double totalGCash;
  final double totalRemittance;
  final int excludedVoidCount;
  final int excludedGratisCount;
  final DateTime generatedAt;
  final String generatedByName;
  final String generatedByRole;

  const RemittanceReportData({
    required this.periodType,
    required this.selectedDate,
    required this.periodLabel,
    required this.validReceipts,
    required this.totalCount,
    required this.totalCash,
    required this.totalGCash,
    required this.totalRemittance,
    required this.excludedVoidCount,
    required this.excludedGratisCount,
    required this.generatedAt,
    required this.generatedByName,
    required this.generatedByRole,
  });
}

class RemittanceReportService {
  RemittanceReportService._();

  static final SupabaseClient _client = Supabase.instance.client;

  static const List<String> monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  static bool _isVoided(Map<String, dynamic> row) {
    final status = (row['transaction_status'] ?? '').toString().toLowerCase();
    if (status.contains('void') || status.contains('cancel')) return true;
    final details = (row['transaction_details'] ?? '').toString().toUpperCase();
    return details.contains('[VOIDED') || details.contains('VOIDED ON');
  }

  static bool _isGratis(Map<String, dynamic> row, double amount) {
    if (amount <= 0.0) return true;
    final details = (row['transaction_details'] ?? '').toString().toLowerCase();
    final type = (row['transaction_type'] ?? '').toString().toLowerCase();
    return details.contains('tender mode: gratis') ||
        details.contains('gratis') ||
        type == 'gratis';
  }

  static String _resolveTenderMode(Map<String, dynamic> row) {
    final details = (row['transaction_details'] ?? '').toString().toLowerCase();
    final type = (row['transaction_type'] ?? '').toString().toLowerCase();

    if (details.contains('tender mode: gcash') || details.contains('gcash ref') || type == 'gcash') {
      return 'GCash';
    }
    if (details.contains('tender mode: gratis') || type == 'gratis') {
      return 'Gratis';
    }
    return 'Cash';
  }

  /// Queries all transactions within the selected period and builds the filtered remittance report data
  static Future<RemittanceReportData> fetchReportData({
    required RemittancePeriodType periodType,
    required DateTime targetDate,
  }) async {
    DateTime startDate;
    DateTime endDate;
    String periodLabel;

    switch (periodType) {
      case RemittancePeriodType.daily:
        startDate = DateTime(targetDate.year, targetDate.month, targetDate.day, 0, 0, 0);
        endDate = DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59, 59, 999);
        final monthStr = monthNames[targetDate.month - 1];
        periodLabel = '$monthStr ${targetDate.day}, ${targetDate.year}';
        break;

      case RemittancePeriodType.monthly:
        startDate = DateTime(targetDate.year, targetDate.month, 1, 0, 0, 0);
        final nextMonth = (targetDate.month == 12)
            ? DateTime(targetDate.year + 1, 1, 1)
            : DateTime(targetDate.year, targetDate.month + 1, 1);
        endDate = nextMonth.subtract(const Duration(milliseconds: 1));
        final monthStr = monthNames[targetDate.month - 1];
        periodLabel = '$monthStr ${targetDate.year}';
        break;

      case RemittancePeriodType.yearly:
        startDate = DateTime(targetDate.year, 1, 1, 0, 0, 0);
        endDate = DateTime(targetDate.year, 12, 31, 23, 59, 59, 999);
        periodLabel = 'Year ${targetDate.year}';
        break;
    }

    final response = await _client
        .from('parish_transactions')
        .select()
        .gte('transaction_date', startDate.toIso8601String())
        .lte('transaction_date', endDate.toIso8601String())
        .order('transaction_date', ascending: true);

    final rawList = List<Map<String, dynamic>>.from(response);

    final List<RemittanceItem> validReceipts = [];
    int voidCount = 0;
    int gratisCount = 0;
    double cashSum = 0.0;
    double gcashSum = 0.0;

    for (final row in rawList) {
      final double amount = (row['transaction_amount'] is num)
          ? (row['transaction_amount'] as num).toDouble()
          : (double.tryParse(row['transaction_amount']?.toString() ?? '0') ?? 0.0);

      // 1. Exclude Voided Receipts
      if (_isVoided(row)) {
        voidCount++;
        continue;
      }

      // 2. Exclude Gratis Receipts
      if (_isGratis(row, amount)) {
        gratisCount++;
        continue;
      }

      final mode = _resolveTenderMode(row);
      if (mode == 'GCash') {
        gcashSum += amount;
      } else {
        cashSum += amount;
      }

      final txDate = DateTime.tryParse(row['transaction_date']?.toString() ?? row['created_at']?.toString() ?? '') ?? DateTime.now();

      validReceipts.add(
        RemittanceItem(
          receiptNumber: (row['receipt_number'] ?? 'REC-XXXX').toString(),
          transactionDate: txDate,
          payorName: (row['payor_name'] ?? 'Parishioner').toString().trim(),
          payorContact: row['payor_contact']?.toString().trim(),
          relatedService: (row['related_service'] ?? row['transaction_type'] ?? 'Parish Offering').toString().trim(),
          details: (row['transaction_details'] ?? '').toString().trim(),
          amount: amount,
          paymentMode: mode,
          encodedBy: row['encoded_by']?.toString(),
        ),
      );
    }

    final currentUser = AuthService.currentUser;

    return RemittanceReportData(
      periodType: periodType,
      selectedDate: targetDate,
      periodLabel: periodLabel,
      validReceipts: validReceipts,
      totalCount: validReceipts.length,
      totalCash: cashSum,
      totalGCash: gcashSum,
      totalRemittance: cashSum + gcashSum,
      excludedVoidCount: voidCount,
      excludedGratisCount: gratisCount,
      generatedAt: DateTime.now(),
      generatedByName: currentUser?.fullName ?? 'Parish Secretariat',
      generatedByRole: currentUser?.roleDisplay ?? 'Parish Staff',
    );
  }

  // ===========================================================================
  // PDF Export Engine (Print-ready A4 Landscape Canonical Report)
  // ===========================================================================

  static Future<Uint8List> generatePdfReport(RemittanceReportData report) async {
    final pdf = pw.Document();

    final baseFont = await PdfGoogleFonts.arimoRegular();
    final boldFont = await PdfGoogleFonts.arimoBold();
    final italicFont = await PdfGoogleFonts.arimoItalic();

    const marianBlue = PdfColor.fromInt(0xFF164E87);
    const goldAccent = PdfColor.fromInt(0xFFD49B18);
    const textDark = PdfColor.fromInt(0xFF1E293B);
    const textMuted = PdfColor.fromInt(0xFF64748B);
    const borderGrey = PdfColor.fromInt(0xFFCBD5E1);

    final genDateStr =
        '${report.generatedAt.year}-${report.generatedAt.month.toString().padLeft(2, '0')}-${report.generatedAt.day.toString().padLeft(2, '0')} ${report.generatedAt.hour.toString().padLeft(2, '0')}:${report.generatedAt.minute.toString().padLeft(2, '0')}';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        header: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'DIOCESE OF SAN PABLO',
                        style: pw.TextStyle(font: boldFont, fontSize: 8.5, color: textMuted),
                      ),
                      pw.Text(
                        'ST. JOHN PAUL II PARISH',
                        style: pw.TextStyle(font: boldFont, fontSize: 14, color: marianBlue),
                      ),
                      pw.Text(
                        'Barangay Labuin, Santa Cruz, Laguna, Philippines',
                        style: pw.TextStyle(font: baseFont, fontSize: 8, color: textMuted),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: goldAccent, width: 1),
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text(
                          'OFFICIAL REMITTANCE REPORT',
                          style: pw.TextStyle(font: boldFont, fontSize: 8.5, color: marianBlue),
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'Period: ${report.periodLabel.toUpperCase()}',
                        style: pw.TextStyle(font: boldFont, fontSize: 9.5, color: textDark),
                      ),
                      pw.Text(
                        'Generated: $genDateStr | Page ${context.pageNumber} of ${context.pagesCount}',
                        style: pw.TextStyle(font: baseFont, fontSize: 7.5, color: textMuted),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(thickness: 1, color: marianBlue),
              pw.SizedBox(height: 6),
            ],
          );
        },
        build: (context) {
          return [
            // KPI Summary Row
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(4),
                border: pw.Border.all(color: borderGrey, width: 0.6),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildPdfKpiCell('Valid Receipts Count', '${report.totalCount} receipts', baseFont, boldFont),
                  _buildPdfKpiCell('Cash Collections', 'P ${report.totalCash.toStringAsFixed(2)}', baseFont, boldFont),
                  _buildPdfKpiCell('GCash Collections', 'P ${report.totalGCash.toStringAsFixed(2)}', baseFont, boldFont),
                  _buildPdfKpiCell('TOTAL REMITTANCE', 'P ${report.totalRemittance.toStringAsFixed(2)}', baseFont, boldFont, isPrimary: true),
                ],
              ),
            ),
            pw.SizedBox(height: 4),

            // Exclusion notice banner
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  '* Note: Excluded ${report.excludedVoidCount} voided receipt(s) and ${report.excludedGratisCount} gratis slip(s) from remittance figures.',
                  style: pw.TextStyle(font: italicFont, fontSize: 7, color: textMuted),
                ),
                pw.Text(
                  'Currency: Philippine Peso (PHP)',
                  style: pw.TextStyle(font: baseFont, fontSize: 7, color: textMuted),
                ),
              ],
            ),
            pw.SizedBox(height: 8),

            // Structured Table
            pw.Table(
              border: pw.TableBorder.all(color: borderGrey, width: 0.5),
              columnWidths: const {
                0: pw.FixedColumnWidth(85),
                1: pw.FixedColumnWidth(90),
                2: pw.FlexColumnWidth(2.5),
                3: pw.FlexColumnWidth(3.0),
                4: pw.FixedColumnWidth(55),
                5: pw.FixedColumnWidth(80),
              },
              children: [
                // Table Header
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _buildTableCell('RECEIPT NO.', boldFont, isHeader: true),
                    _buildTableCell('DATE / TIME', boldFont, isHeader: true),
                    _buildTableCell('PAYOR NAME', boldFont, isHeader: true),
                    _buildTableCell('PARTICULARS / SERVICE', boldFont, isHeader: true),
                    _buildTableCell('TENDER', boldFont, isHeader: true, align: pw.TextAlign.center),
                    _buildTableCell('AMOUNT (PHP)', boldFont, isHeader: true, align: pw.TextAlign.right),
                  ],
                ),
                // Table Rows
                ...report.validReceipts.map((r) {
                  return pw.TableRow(
                    children: [
                      _buildTableCell(r.receiptNumber, boldFont),
                      _buildTableCell(r.formattedDate, baseFont),
                      _buildTableCell(r.payorName, boldFont),
                      _buildTableCell(r.relatedService, baseFont),
                      _buildTableCell(r.paymentMode.toUpperCase(), baseFont, align: pw.TextAlign.center),
                      _buildTableCell(r.amount.toStringAsFixed(2), boldFont, align: pw.TextAlign.right),
                    ],
                  );
                }),
                // Table Total Row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('TOTAL', style: pw.TextStyle(font: boldFont, fontSize: 8.5)),
                    ),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('')),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('')),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(
                        'Total Included: ${report.totalCount} Valid Receipts',
                        style: pw.TextStyle(font: boldFont, fontSize: 8, color: textMuted),
                      ),
                    ),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('')),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(
                        'P ${report.totalRemittance.toStringAsFixed(2)}',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(font: boldFont, fontSize: 9.5, color: marianBlue),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 24),

            // Signatory Block
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildSignatoryLine('Prepared by (Cashier / Desk):', report.generatedByName, report.generatedByRole, boldFont, baseFont),
                _buildSignatoryLine('Verified by (Parish Secretariat / PFC):', 'Parish Secretary', 'Head of Administration', boldFont, baseFont),
                _buildSignatoryLine('Approved by (Parish Priest):', 'Rev. Fr. Roy G. Reyes', 'Parish Priest', boldFont, baseFont),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildPdfKpiCell(String label, String value, pw.Font baseFont, pw.Font boldFont, {bool isPrimary = false}) {
    return pw.Column(
      children: [
        pw.Text(label, style: pw.TextStyle(font: baseFont, fontSize: 7, color: PdfColors.grey700)),
        pw.SizedBox(height: 1),
        pw.Text(
          value,
          style: pw.TextStyle(
            font: boldFont,
            fontSize: isPrimary ? 10.5 : 9.5,
            fontWeight: pw.FontWeight.bold,
            color: isPrimary ? const PdfColor.fromInt(0xFF164E87) : PdfColors.black,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildTableCell(String text, pw.Font font, {bool isHeader = false, pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3.5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          font: font,
          fontSize: isHeader ? 7.5 : 7.5,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static pw.Widget _buildSignatoryLine(String title, String name, String subtitle, pw.Font boldFont, pw.Font baseFont) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(title, style: pw.TextStyle(font: baseFont, fontSize: 7, color: PdfColors.grey700)),
        pw.SizedBox(height: 24),
        pw.Container(width: 170, height: 0.8, color: PdfColors.black),
        pw.SizedBox(height: 2),
        pw.Text(name, style: pw.TextStyle(font: boldFont, fontSize: 8.5)),
        pw.Text(subtitle, style: pw.TextStyle(font: baseFont, fontSize: 7, color: PdfColors.grey700)),
      ],
    );
  }

  // ===========================================================================
  // Excel-Compatible Spreadsheet Export (Zero External Packages Required)
  // Generates UTF-8 with BOM CSV that Microsoft Excel & Google Sheets open natively
  // ===========================================================================

  static String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  static Uint8List generateExcelCompatibleCsv(RemittanceReportData report) {
    final buffer = StringBuffer();

    // UTF-8 BOM so Microsoft Excel immediately displays currency symbols and text without corruption
    buffer.write('\uFEFF');

    // Header Metadata Rows
    buffer.writeln('ST. JOHN PAUL II PARISH - DIOCESE OF SAN PABLO');
    buffer.writeln('Barangay Labuin, Santa Cruz, Laguna, Philippines');
    buffer.writeln('Official Remittance Report - Covered Period: ${_escapeCsv(report.periodLabel)}');
    final genDateStr =
        '${report.generatedAt.year}-${report.generatedAt.month.toString().padLeft(2, '0')}-${report.generatedAt.day.toString().padLeft(2, '0')} ${report.generatedAt.hour.toString().padLeft(2, '0')}:${report.generatedAt.minute.toString().padLeft(2, '0')}';
    buffer.writeln('Generated By: ${_escapeCsv("${report.generatedByName} (${report.generatedByRole})")} on $genDateStr');
    buffer.writeln('');

    // Summary Section
    buffer.writeln('FINANCIAL REMITTANCE SUMMARY');
    buffer.writeln('Valid Receipts Count,${report.totalCount}');
    buffer.writeln('Cash Intake (PHP),${report.totalCash.toStringAsFixed(2)}');
    buffer.writeln('GCash Intake (PHP),${report.totalGCash.toStringAsFixed(2)}');
    buffer.writeln('TOTAL REMITTANCE (PHP),${report.totalRemittance.toStringAsFixed(2)}');
    buffer.writeln('Excluded Voided Slips,${report.excludedVoidCount}');
    buffer.writeln('Excluded Gratis Slips,${report.excludedGratisCount}');
    buffer.writeln('');

    // Table Column Headers
    buffer.writeln('Receipt Number,Date & Time,Payor Name,Contact Number,Particulars / Offering Service,Payment Mode,Amount (PHP)');

    // Data Rows
    for (final item in report.validReceipts) {
      final line = [
        _escapeCsv(item.receiptNumber),
        _escapeCsv(item.formattedDate),
        _escapeCsv(item.payorName),
        _escapeCsv(item.payorContact ?? '-'),
        _escapeCsv(item.relatedService),
        _escapeCsv(item.paymentMode.toUpperCase()),
        item.amount.toStringAsFixed(2),
      ].join(',');
      buffer.writeln(line);
    }

    // Total Row
    buffer.writeln('TOTAL,,,,Grand Total (${report.totalCount} Receipts),,${report.totalRemittance.toStringAsFixed(2)}');
    buffer.writeln('');
    buffer.writeln('');

    // Signatories Block
    buffer.writeln('Prepared by:,${_escapeCsv(report.generatedByName)},Verified by:,Parish Secretary / PFC,Approved by:,Rev. Fr. Roy G. Reyes');

    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  /// Triggers print or layout preview for PDF
  static Future<void> exportPdf(RemittanceReportData report) async {
    final pdfBytes = await generatePdfReport(report);
    final periodSlug = report.periodLabel.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    await Printing.layoutPdf(
      onLayout: (format) async => pdfBytes,
      name: 'Remittance_Report_$periodSlug',
    );
  }

  /// Exports an Excel-compatible spreadsheet file (.csv) without dependency conflicts
  static Future<void> exportExcel(RemittanceReportData report) async {
    final excelBytes = generateExcelCompatibleCsv(report);
    final periodSlug = report.periodLabel.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final filename = 'Remittance_Report_$periodSlug.csv';

    await Printing.sharePdf(
      bytes: excelBytes,
      filename: filename,
    );
  }
}