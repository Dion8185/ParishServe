import 'dart:convert';
import 'dart:typed_data';
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

  String get dateOnly {
    final y = transactionDate.year.toString();
    final m = transactionDate.month.toString().padLeft(2, '0');
    final d = transactionDate.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
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

class FundDistributionRow {
  final RemittanceItem item;
  final Map<String, double> allocations;

  const FundDistributionRow({
    required this.item,
    required this.allocations,
  });
}

class FundReceiptsBreakdown {
  final List<FundDistributionRow> rows;
  final Map<String, double> columnTotals;
  final double grandAmountTotal;

  // 60% / 40% Mass Intention Split
  final double massIntention60;
  final double massIntention40;
  final double miCollection60;
  final double miCollection40;

  // Summary Blocks
  final double sacramentSubtotal;
  final double parishFundSubtotal;
  final double grandSummaryTotal;
  final double variance;

  const FundReceiptsBreakdown({
    required this.rows,
    required this.columnTotals,
    required this.grandAmountTotal,
    required this.massIntention60,
    required this.massIntention40,
    required this.miCollection60,
    required this.miCollection40,
    required this.sacramentSubtotal,
    required this.parishFundSubtotal,
    required this.grandSummaryTotal,
    required this.variance,
  });

  double col(String key) => columnTotals[key] ?? 0.0;
}

class RemittanceReportService {
  RemittanceReportService._();

  static final SupabaseClient _client = Supabase.instance.client;

  static const List<String> monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  // Canonical 18 Fund Receipts Columns (Cols G through X)
  static const List<Map<String, String>> fundColumns = [
    {'key': 'donation_parish', 'label': 'Donation for Parish'},
    {'key': 'subsidy', 'label': 'Subsidy'},
    {'key': 'baptism', 'label': 'Baptism'},
    {'key': 'baptism_add', 'label': 'additional sponsor/donation'},
    {'key': 'confirmation', 'label': 'CONFIRMATION'},
    {'key': 'confirmation_add', 'label': 'additional/donation'},
    {'key': 'permission', 'label': 'permission'},
    {'key': 'funeral_mass', 'label': 'funeral mass'},
    {'key': 'funeral_blessing', 'label': 'funeral blessing'},
    {'key': 'certificates', 'label': 'certificates'},
    {'key': 'wedding', 'label': 'wedding'},
    {'key': 'marriage_banns', 'label': 'marriage banns'},
    {'key': 'mass_intentions', 'label': 'mass intentions'},
    {'key': 'balik_handog', 'label': 'Balik Handog'},
    {'key': 'weekday_coll', 'label': 'Weekday Collection'},
    {'key': 'sunday_coll', 'label': 'Sunday Collection'},
    {'key': 'special_coll', 'label': 'Special Collection'},
    {'key': 'mi_coll', 'label': 'MI/ Collection'},
  ];

  static String _matchFundColumnKey(String title) {
    final lower = title.toLowerCase().trim();

    if (lower.contains('additional sponsor') ||
        (lower.contains('baptism') && lower.contains('add'))) {
      return 'baptism_add';
    }
    if ((lower.contains('confirmation') && lower.contains('add')) ||
        lower.startsWith('additional/donation') ||
        lower.startsWith('additional / donation')) {
      return 'confirmation_add';
    }
    if (lower.contains('certificate') || lower.contains('pabuklat')) {
      return 'certificates';
    }
    if (lower.contains('baptism')) {
      return 'baptism';
    }
    if (lower.contains('confirmation')) {
      return 'confirmation';
    }
    if (lower.contains('permission')) {
      return 'permission';
    }
    if (lower.contains('funeral blessing')) {
      return 'funeral_blessing';
    }
    if (lower.contains('funeral')) {
      return 'funeral_mass';
    }
    if (lower.contains('marriage banns') || lower.contains('banns')) {
      return 'marriage_banns';
    }
    if (lower.contains('wedding') ||
        lower.contains('nuptial') ||
        lower.contains('marriage')) {
      return 'wedding';
    }
    if (lower.contains('mi / collection') ||
        lower.contains('mi/ collection') ||
        lower.contains('mi collection')) {
      return 'mi_coll';
    }
    if (lower.contains('mass') ||
        lower.contains('intention') ||
        lower.contains('thanksgiving') ||
        lower.contains('repose') ||
        lower.contains('petition')) {
      return 'mass_intentions';
    }
    if (lower.contains('balik handog')) {
      return 'balik_handog';
    }
    if (lower.contains('weekday collection')) {
      return 'weekday_coll';
    }
    if (lower.contains('sunday collection')) {
      return 'sunday_coll';
    }
    if (lower.contains('special collection')) {
      return 'special_coll';
    }
    if (lower.contains('subsidy')) {
      return 'subsidy';
    }
    return 'donation_parish';
  }

  /// Parses itemized lines from `details` or falls back to `relatedService`
  static Map<String, double> _allocateItemToColumns(RemittanceItem item) {
    final Map<String, double> allocations = {};

    // Attempt to parse itemized POS lines: "• Title xQty\n  @ ₱Price = ₱Total"
    final lines = item.details.split('\n').map((l) => l.trim()).toList();
    String? pendingTitle;
    double parsedSum = 0.0;

    for (final line in lines) {
      if (line.startsWith('•') || line.startsWith('-')) {
        final clean = line.replaceFirst(RegExp(r'^[•\-]\s*'), '').trim();
        final beforeQty = clean
            .replaceAll(RegExp(r'\s*x\d+$', caseSensitive: false), '')
            .trim();
        if (clean.contains('@') && clean.contains('=')) {
          final eqParts = clean.split('=');
          final titleSide = eqParts[0]
              .split('@')[0]
              .trim()
              .replaceAll(RegExp(r'\s*x\d+$', caseSensitive: false), '');
          final amtStr = eqParts.last.replaceAll(RegExp(r'[^0-9.]'), '');
          final amt = double.tryParse(amtStr) ?? 0.0;
          if (amt > 0) {
            final key = _matchFundColumnKey(titleSide);
            allocations[key] = (allocations[key] ?? 0.0) + amt;
            parsedSum += amt;
          }
          pendingTitle = null;
        } else {
          pendingTitle = beforeQty;
        }
      } else if (pendingTitle != null &&
          line.contains('@') &&
          line.contains('=')) {
        final amtStr = line.split('=').last.replaceAll(RegExp(r'[^0-9.]'), '');
        final amt = double.tryParse(amtStr) ?? 0.0;
        if (amt > 0) {
          final key = _matchFundColumnKey(pendingTitle);
          allocations[key] = (allocations[key] ?? 0.0) + amt;
          parsedSum += amt;
        }
        pendingTitle = null;
      }
    }

    // If itemized lines did not sum to item.amount, allocate full amount by relatedService
    if (allocations.isEmpty || (parsedSum - item.amount).abs() > 0.05) {
      allocations.clear();
      final key = _matchFundColumnKey(item.relatedService);
      allocations[key] = item.amount;
    }

    return allocations;
  }

  /// Computes the complete Fund Receipts breakdown matching the Nov2026 Excel Template
  static FundReceiptsBreakdown computeFundBreakdown(List<RemittanceItem> items) {
    final List<FundDistributionRow> rows = [];
    final Map<String, double> totals = {
      for (final col in fundColumns) col['key']!: 0.0,
    };
    double grandAmount = 0.0;

    for (final item in items) {
      final alloc = _allocateItemToColumns(item);
      rows.add(FundDistributionRow(item: item, allocations: alloc));
      grandAmount += item.amount;
      alloc.forEach((key, val) {
        totals[key] = (totals[key] ?? 0.0) + val;
      });
    }

    final miTotal = totals['mass_intentions'] ?? 0.0;
    final miCollTotal = totals['mi_coll'] ?? 0.0;

    final mi60 = miTotal * 0.60;
    final mi40 = miTotal * 0.40;
    final miColl60 = miCollTotal * 0.60;
    final miColl40 = miCollTotal * 0.40;

    final sacramentSubtotal = (totals['baptism'] ?? 0.0) +
        (totals['confirmation'] ?? 0.0) +
        (totals['permission'] ?? 0.0) +
        (totals['certificates'] ?? 0.0) +
        (totals['marriage_banns'] ?? 0.0) +
        (totals['funeral_mass'] ?? 0.0) +
        (totals['funeral_blessing'] ?? 0.0) +
        mi60 +
        miColl60 +
        (totals['wedding'] ?? 0.0);

    final parishFundSubtotal = (totals['weekday_coll'] ?? 0.0) +
        (totals['sunday_coll'] ?? 0.0) +
        (totals['special_coll'] ?? 0.0) +
        mi40 +
        miColl40 +
        (totals['balik_handog'] ?? 0.0) +
        (totals['baptism_add'] ?? 0.0) +
        (totals['confirmation_add'] ?? 0.0) +
        (totals['donation_parish'] ?? 0.0) +
        (totals['subsidy'] ?? 0.0);

    final grandSummaryTotal = sacramentSubtotal + parishFundSubtotal;
    final variance = grandAmount - grandSummaryTotal;

    return FundReceiptsBreakdown(
      rows: rows,
      columnTotals: totals,
      grandAmountTotal: grandAmount,
      massIntention60: mi60,
      massIntention40: mi40,
      miCollection60: miColl60,
      miCollection40: miColl40,
      sacramentSubtotal: sacramentSubtotal,
      parishFundSubtotal: parishFundSubtotal,
      grandSummaryTotal: grandSummaryTotal,
      variance: variance,
    );
  }

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
    final paymentMode = (row['payment_mode'] ?? '').toString().toLowerCase();
    if (paymentMode.contains('gcash') || paymentMode.contains('online')) {
      return 'GCash';
    }
    if (paymentMode.contains('cheque') || paymentMode.contains('check')) {
      return 'Cheque';
    }
    if (paymentMode.contains('gratis')) {
      return 'Gratis';
    }

    final details = (row['transaction_details'] ?? '').toString().toLowerCase();
    final type = (row['transaction_type'] ?? '').toString().toLowerCase();

    if (details.contains('tender mode: gcash') ||
        details.contains('gcash ref') ||
        type == 'gcash') {
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
        startDate =
            DateTime(targetDate.year, targetDate.month, targetDate.day, 0, 0, 0);
        endDate = DateTime(
            targetDate.year, targetDate.month, targetDate.day, 23, 59, 59, 999);
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
          : (double.tryParse(row['transaction_amount']?.toString() ?? '0') ??
          0.0);

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

      final txDate = DateTime.tryParse(row['transaction_date']?.toString() ??
          row['created_at']?.toString() ??
          '') ??
          DateTime.now();

      validReceipts.add(
        RemittanceItem(
          receiptNumber: (row['receipt_number'] ?? 'REC-XXXX').toString(),
          transactionDate: txDate,
          payorName: (row['payor_name'] ?? 'Parishioner').toString().trim(),
          payorContact: row['payor_contact']?.toString().trim(),
          relatedService: (row['related_service'] ??
              row['transaction_type'] ??
              'Parish Offering')
              .toString()
              .trim(),
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

  static Future<Uint8List> generatePdfReport(
      RemittanceReportData report) async {
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
                        style: pw.TextStyle(
                            font: boldFont, fontSize: 8.5, color: textMuted),
                      ),
                      pw.Text(
                        'ST. JOHN PAUL II PARISH',
                        style: pw.TextStyle(
                            font: boldFont, fontSize: 14, color: marianBlue),
                      ),
                      pw.Text(
                        'Barangay Labuin, Santa Cruz, Laguna, Philippines',
                        style: pw.TextStyle(
                            font: baseFont, fontSize: 8, color: textMuted),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: goldAccent, width: 1),
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text(
                          'OFFICIAL REMITTANCE REPORT',
                          style: pw.TextStyle(
                              font: boldFont, fontSize: 8.5, color: marianBlue),
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'Period: ${report.periodLabel.toUpperCase()}',
                        style: pw.TextStyle(
                            font: boldFont, fontSize: 9.5, color: textDark),
                      ),
                      pw.Text(
                        'Generated: $genDateStr | Page ${context.pageNumber} of ${context.pagesCount}',
                        style: pw.TextStyle(
                            font: baseFont, fontSize: 7.5, color: textMuted),
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
                  _buildPdfKpiCell('Valid Receipts Count',
                      '${report.totalCount} receipts', baseFont, boldFont),
                  _buildPdfKpiCell(
                      'Cash Collections',
                      'P ${report.totalCash.toStringAsFixed(2)}',
                      baseFont,
                      boldFont),
                  _buildPdfKpiCell(
                      'GCash Collections',
                      'P ${report.totalGCash.toStringAsFixed(2)}',
                      baseFont,
                      boldFont),
                  _buildPdfKpiCell(
                      'TOTAL REMITTANCE',
                      'P ${report.totalRemittance.toStringAsFixed(2)}',
                      baseFont,
                      boldFont,
                      isPrimary: true),
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
                  style: pw.TextStyle(
                      font: italicFont, fontSize: 7, color: textMuted),
                ),
                pw.Text(
                  'Currency: Philippine Peso (PHP)',
                  style: pw.TextStyle(
                      font: baseFont, fontSize: 7, color: textMuted),
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
                    _buildTableCell('PARTICULARS / SERVICE', boldFont,
                        isHeader: true),
                    _buildTableCell('TENDER', boldFont,
                        isHeader: true, align: pw.TextAlign.center),
                    _buildTableCell('AMOUNT (PHP)', boldFont,
                        isHeader: true, align: pw.TextAlign.right),
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
                      _buildTableCell(r.paymentMode.toUpperCase(), baseFont,
                          align: pw.TextAlign.center),
                      _buildTableCell(r.amount.toStringAsFixed(2), boldFont,
                          align: pw.TextAlign.right),
                    ],
                  );
                }),
                // Table Total Row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('TOTAL',
                          style: pw.TextStyle(font: boldFont, fontSize: 8.5)),
                    ),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('')),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('')),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(
                        'Total Included: ${report.totalCount} Valid Receipts',
                        style: pw.TextStyle(
                            font: boldFont, fontSize: 8, color: textMuted),
                      ),
                    ),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('')),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(
                        'P ${report.totalRemittance.toStringAsFixed(2)}',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                            font: boldFont, fontSize: 9.5, color: marianBlue),
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
                _buildSignatoryLine(
                    'Prepared by (Cashier / Desk):',
                    report.generatedByName,
                    report.generatedByRole,
                    boldFont,
                    baseFont),
                _buildSignatoryLine(
                    'Verified by (Parish Secretariat / PFC):',
                    'Parish Secretary',
                    'Head of Administration',
                    boldFont,
                    baseFont),
                _buildSignatoryLine(
                    'Approved by (Parish Priest):',
                    'Rev. Fr. Roy G. Reyes',
                    'Parish Priest',
                    boldFont,
                    baseFont),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildPdfKpiCell(
      String label, String value, pw.Font baseFont, pw.Font boldFont,
      {bool isPrimary = false}) {
    return pw.Column(
      children: [
        pw.Text(label,
            style: pw.TextStyle(
                font: baseFont, fontSize: 7, color: PdfColors.grey700)),
        pw.SizedBox(height: 1),
        pw.Text(
          value,
          style: pw.TextStyle(
            font: boldFont,
            fontSize: isPrimary ? 10.5 : 9.5,
            fontWeight: pw.FontWeight.bold,
            color: isPrimary
                ? const PdfColor.fromInt(0xFF164E87)
                : PdfColors.black,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildTableCell(String text, pw.Font font,
      {bool isHeader = false, pw.TextAlign align = pw.TextAlign.left}) {
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

  static pw.Widget _buildSignatoryLine(String title, String name,
      String subtitle, pw.Font boldFont, pw.Font baseFont) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(title,
            style: pw.TextStyle(
                font: baseFont, fontSize: 7, color: PdfColors.grey700)),
        pw.SizedBox(height: 24),
        pw.Container(width: 170, height: 0.8, color: PdfColors.black),
        pw.SizedBox(height: 2),
        pw.Text(name, style: pw.TextStyle(font: boldFont, fontSize: 8.5)),
        pw.Text(subtitle,
            style: pw.TextStyle(
                font: baseFont, fontSize: 7, color: PdfColors.grey700)),
      ],
    );
  }

  // ===========================================================================
  // Excel-Compatible Fund Receipts Template Export (Mirrors Nov2026 Sheet)
  // Generates UTF-8 with BOM CSV that Microsoft Excel & Google Sheets open natively
  // ===========================================================================

  static String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  static String _fmtAmt(double value) =>
      value == 0.0 ? '' : value.toStringAsFixed(2);

  static Uint8List generateExcelCompatibleCsv(RemittanceReportData report) {
    final buffer = StringBuffer();
    final breakdown = computeFundBreakdown(report.validReceipts);

    // UTF-8 BOM so Microsoft Excel immediately displays currency symbols and text without corruption
    buffer.write('\uFEFF');

    // Rows 1-4: Canonical Template Header
    buffer.writeln(',SAINT JOHN PAUL II PARISH,,,,,,,,,,,,,,,,,,,,,,');
    buffer.writeln(',Fund Receipts,,,,,,,,,,,,,,,,,,,,,,');
    buffer.writeln(',${_escapeCsv(report.periodLabel)},,,,,,,,,,,,,,,,,,,,,,');
    buffer.writeln(',,,,,,,,,,,,,,,,,,,,,,,');

    // Row 5: Column Headers (Cols A..X)
    final headerCells = [
      '',
      'Date',
      'OR NO.',
      'Donor',
      'PARTICULARS',
      'AMOUNT',
      ...fundColumns.map((c) => _escapeCsv(c['label']!)),
    ];
    buffer.writeln(headerCells.join(','));
    buffer.writeln(',,,,,,,,,,,,,,,,,,,,,,,');

    // Data Rows
    for (int i = 0; i < breakdown.rows.length; i++) {
      final row = breakdown.rows[i];
      final item = row.item;
      final rowCells = [
        '${i + 1}',
        _escapeCsv(item.dateOnly),
        _escapeCsv(item.receiptNumber),
        _escapeCsv(item.payorName),
        _escapeCsv(item.relatedService),
        item.amount.toStringAsFixed(2),
        ...fundColumns.map((c) => _fmtAmt(row.allocations[c['key']!] ?? 0.0)),
      ];
      buffer.writeln(rowCells.join(','));
    }

    buffer.writeln(',,,,,,,,,,,,,,,,,,,,,,,');

    // Sub total & Total Rows
    final totalCells = [
      '',
      '',
      '',
      '',
      'Total',
      breakdown.grandAmountTotal.toStringAsFixed(2),
      ...fundColumns
          .map((c) => breakdown.col(c['key']!).toStringAsFixed(2)),
    ];
    buffer.writeln(totalCells.join(','));

    // 60% / 40% Mass Intention Split Rows (Cols S & X)
    final row60 = List<String>.filled(24, '');
    row60[4] = 'Mass Intention Split (60%)';
    row60[18] = breakdown.massIntention60.toStringAsFixed(2); // Col S
    row60[23] = breakdown.miCollection60.toStringAsFixed(2); // Col X
    buffer.writeln(row60.join(','));

    final row40 = List<String>.filled(24, '');
    row40[4] = 'Mass Intention Split (40%)';
    row40[18] = breakdown.massIntention40.toStringAsFixed(2); // Col S
    row40[23] = breakdown.miCollection40.toStringAsFixed(2); // Col X
    buffer.writeln(row40.join(','));
    buffer.writeln(',,,,,,,,,,,,,,,,,,,,,,,');

    // Sacrament Summary Block
    buffer.writeln(',,,,Sacrament,,,,,,,,,,,,,,,,,,,');
    buffer.writeln(
        ',,,,Baptism Infant,,${breakdown.col('baptism').toStringAsFixed(2)},,,,,,,,,,,,,,,,,');
    buffer.writeln(
        ',,,,Confirmation,,${breakdown.col('confirmation').toStringAsFixed(2)},,,,,,,,,,,,,,,,,');
    buffer.writeln(
        ',,,,Permission,,${breakdown.col('permission').toStringAsFixed(2)},,,,,,,,,,,,,,,,,');
    buffer.writeln(
        ',,,,Certificates,,${breakdown.col('certificates').toStringAsFixed(2)},,,,,,,,,,,,,,,,,');
    buffer.writeln(
        ',,,,Marriage Banns,,${breakdown.col('marriage_banns').toStringAsFixed(2)},,,,,,,,,,,,,,,,,');
    buffer.writeln(
        ',,,,Funeral Mass,,${breakdown.col('funeral_mass').toStringAsFixed(2)},,,,,,,,,,,,,,,,,');
    buffer.writeln(
        ',,,,Funeral Blessing,,${breakdown.col('funeral_blessing').toStringAsFixed(2)},,,,,,,,,,,,,,,,,');
    buffer.writeln(
        ',,,,Mass Intention (60%),,${breakdown.massIntention60.toStringAsFixed(2)},,,,,,,,,,,,,,,,,');
    buffer.writeln(
        ',,,,Mass Intention Collection (60%),,${breakdown.miCollection60.toStringAsFixed(2)},${(breakdown.massIntention60 + breakdown.miCollection60).toStringAsFixed(2)},,,,,,,,,,,,,,,,');
    buffer.writeln(
        ',,,,Wedding,,${breakdown.col('wedding').toStringAsFixed(2)},,,,,,,,,,,,,,,,,');
    buffer.writeln(
        ',,,,Sub total,,${breakdown.sacramentSubtotal.toStringAsFixed(2)},,,,,,,,,,,,,,,,,');
    buffer.writeln(',,,,,,,,,,,,,,,,,,,,,,,');

    // Parish Fund Summary Block
    buffer.writeln(',,,,Parish Fund,,,,,,,,,,,,,,,,,,,');
    buffer.writeln(
        ',,,,Weekday Collection,,${breakdown.col('weekday_coll').toStringAsFixed(2)},,,,,,,,,,,,,,,,,');
    buffer.writeln(
        ',,,,Sunday Collection,,${breakdown.col('sunday_coll').toStringAsFixed(2)},,,,,,,,,,,,,,,,,');
    buffer.writeln(
        ',,,,Special Collection,,${breakdown.col('special_coll').toStringAsFixed(2)},,,,,,,,,,,,,,,,,');
    buffer.writeln(
        ',,,,Mass Intention (40%),,${breakdown.massIntention40.toStringAsFixed(2)},,,,,,,,,,,,,,,,,');
    buffer.writeln(
        ',,,,Mass Intention Collection (40%),,${breakdown.miCollection40.toStringAsFixed(2)},${(breakdown.massIntention40 + breakdown.miCollection40).toStringAsFixed(2)},,,,,,,,,,,,,,,,');
    buffer.writeln(
        ',,,,Donation Balik Handog,,${breakdown.col('balik_handog').toStringAsFixed(2)},,,,,,,,,,,,,,,,,');
    buffer.writeln(
        ',,,,Donation additional sponsors,,${(breakdown.col('baptism_add') + breakdown.col('confirmation_add')).toStringAsFixed(2)},,,,,,,,,,,,,,,,,');
    final combinedDonations = breakdown.col('balik_handog') +
        breakdown.col('baptism_add') +
        breakdown.col('confirmation_add') +
        breakdown.col('donation_parish');
    buffer.writeln(
        ',,,,Donation from Parishioners,,${breakdown.col('donation_parish').toStringAsFixed(2)},${combinedDonations.toStringAsFixed(2)},,,,,,,,,,,,,,,,');
    buffer.writeln(
        ',Prepared by:,,,Subsidy from Diocese,,${breakdown.col('subsidy').toStringAsFixed(2)},,,,,,,,,,,,,,,,,');
    buffer.writeln(
        ',,,,Sub total,,${breakdown.parishFundSubtotal.toStringAsFixed(2)},,,,,,,,,,,,,,,,,');
    buffer.writeln(
        ',,,,Total,,${breakdown.grandSummaryTotal.toStringAsFixed(2)},,,,,,,,,,,,,,,,,');
    buffer.writeln(
        ',${_escapeCsv(report.generatedByName)},,,Variance Check (Amount - Total),,${breakdown.variance.toStringAsFixed(2)},,,,,,,,,,,,,,,,,');

    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  /// Triggers print or layout preview for PDF
  static Future<void> exportPdf(RemittanceReportData report) async {
    final pdfBytes = await generatePdfReport(report);
    final periodSlug =
    report.periodLabel.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    await Printing.layoutPdf(
      onLayout: (format) async => pdfBytes,
      name: 'Remittance_Report_$periodSlug',
    );
  }

  /// Exports an Excel-compatible spreadsheet file (.csv) matching the Fund Receipts template
  static Future<void> exportExcel(RemittanceReportData report) async {
    final excelBytes = generateExcelCompatibleCsv(report);
    final periodSlug =
    report.periodLabel.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final filename = 'FundReceipts_$periodSlug.csv';

    await Printing.sharePdf(
      bytes: excelBytes,
      filename: filename,
    );
  }
}