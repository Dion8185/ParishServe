import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/mass_intention_model.dart';

class MassIntentionPdfService {
  MassIntentionPdfService._();

  static const PdfColor marianBlue = PdfColor.fromInt(0xFF164E87);
  static const PdfColor textDark = PdfColor.fromInt(0xFF1E293B);
  static const PdfColor textMuted = PdfColor.fromInt(0xFF64748B);
  static const PdfColor borderGrey = PdfColor.fromInt(0xFFCBD5E1);

  /// Generates the liturgical Mass Intention Slip for the altar.
  /// In strict accordance with liturgical guidelines, this slip ONLY includes:
  /// 1. Mass Information (Day of the week, Date, and Mass Time)
  /// 2. Clean categorized intentions (Thanksgiving, Repose of Souls, Special, Others)
  /// All financial details, requester names, phone numbers, and payment modes are strictly excluded.
  static Future<Uint8List> generateMassIntentionSlipPdf({
    required String massDayOfWeek,
    required String massDate,
    required String massTime,
    required List<MassIntentionModel> intentions,
  }) async {
    final pdf = pw.Document();

    final baseFont = await PdfGoogleFonts.arimoRegular();
    final boldFont = await PdfGoogleFonts.arimoBold();
    final italicFont = await PdfGoogleFonts.arimoItalic();

    // Aggregate unique petitions across all approved intention slips for this Mass
    final List<String> thanksgivingList = [];
    final List<String> reposeSoulsList = [];
    final List<String> specialIntentionsList = [];
    final List<String> otherIntentionsList = [];

    for (final item in intentions) {
      if (item.isRejected) continue; // Skip rejected/cancelled intentions

      for (final t in item.thanksgivingList) {
        final clean = t.trim();
        if (clean.isNotEmpty && !thanksgivingList.contains(clean)) {
          thanksgivingList.add(clean);
        }
      }

      for (final r in item.reposeSoulsList) {
        final clean = r.trim();
        if (clean.isNotEmpty && !reposeSoulsList.contains(clean)) {
          reposeSoulsList.add(clean);
        }
      }

      for (final s in item.specialIntentionsList) {
        final clean = s.trim();
        if (clean.isNotEmpty && !specialIntentionsList.contains(clean)) {
          specialIntentionsList.add(clean);
        }
      }

      if (item.otherIntentions != null && item.otherIntentions!.trim().isNotEmpty) {
        final clean = item.otherIntentions!.trim();
        if (!otherIntentionsList.contains(clean)) {
          otherIntentionsList.add(clean);
        }
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        header: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                'DIOCESE OF SAN PABLO',
                style: pw.TextStyle(font: boldFont, fontSize: 9, color: textMuted),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'SAINT JOHN PAUL II PARISH',
                style: pw.TextStyle(font: boldFont, fontSize: 16, color: marianBlue),
              ),
              pw.Text(
                'Labuin, Santa Cruz, Laguna',
                style: pw.TextStyle(font: baseFont, fontSize: 8.5, color: textMuted),
              ),
              pw.SizedBox(height: 8),

              // Liturgical Mass Header Box
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: marianBlue, width: 1.5),
                  borderRadius: pw.BorderRadius.circular(6),
                  color: PdfColors.grey100,
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'HOLY MASS INTENTIONS',
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 13,
                        color: marianBlue,
                        letterSpacing: 1.2,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      '$massDayOfWeek, $massDate at $massTime',
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 12,
                        color: textDark,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),
            ],
          );
        },
        footer: (context) {
          return pw.Column(
            children: [
              pw.Divider(thickness: 0.8, color: borderGrey),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Page ${context.pageNumber} of ${context.pagesCount}',
                    style: pw.TextStyle(font: baseFont, fontSize: 8, color: textMuted),
                  ),
                  pw.Text(
                    'TOTUS TUUS',
                    style: pw.TextStyle(font: boldFont, fontSize: 8, fontStyle: pw.FontStyle.italic, color: textMuted),
                  ),
                ],
              ),
            ],
          );
        },
        build: (context) {
          return [
            // 1. Thanksgiving Category
            if (thanksgivingList.isNotEmpty) ...[
              _buildCategoryBlock(
                title: 'PASASALAMAT / THANKSGIVING',
                items: thanksgivingList,
                boldFont: boldFont,
                baseFont: baseFont,
                accentColor: marianBlue,
              ),
              pw.SizedBox(height: 16),
            ],

            // 2. Repose of Souls Category
            if (reposeSoulsList.isNotEmpty) ...[
              _buildCategoryBlock(
                title: 'PARA SA KALULUWA / REPOSE OF THE SOULS',
                items: reposeSoulsList,
                boldFont: boldFont,
                baseFont: baseFont,
                accentColor: PdfColors.purple800,
              ),
              pw.SizedBox(height: 16),
            ],

            // 3. Special Intentions Category
            if (specialIntentionsList.isNotEmpty) ...[
              _buildCategoryBlock(
                title: 'NATATANGING KAHILINGAN / SPECIAL INTENTIONS',
                items: specialIntentionsList,
                boldFont: boldFont,
                baseFont: baseFont,
                accentColor: PdfColors.green800,
              ),
              pw.SizedBox(height: 16),
            ],

            // 4. Other Petitions Category
            if (otherIntentionsList.isNotEmpty) ...[
              _buildCategoryBlock(
                title: 'IBA PANG KAHILINGAN / OTHER INTENTIONS',
                items: otherIntentionsList,
                boldFont: boldFont,
                baseFont: baseFont,
                accentColor: PdfColors.amber900,
              ),
              pw.SizedBox(height: 16),
            ],

            if (thanksgivingList.isEmpty &&
                reposeSoulsList.isEmpty &&
                specialIntentionsList.isEmpty &&
                otherIntentionsList.isEmpty)
              pw.Center(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.all(32),
                  child: pw.Text(
                    'No Mass intentions registered for this liturgical celebration.',
                    style: pw.TextStyle(font: italicFont, fontSize: 11, color: textMuted),
                  ),
                ),
              ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildCategoryBlock({
    required String title,
    required List<String> items,
    required pw.Font boldFont,
    required pw.Font baseFont,
    required PdfColor accentColor,
  }) {
    return pw.Container(
      width: double.infinity,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: borderGrey, width: 0.8),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey200,
              borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  title,
                  style: pw.TextStyle(font: boldFont, fontSize: 9.5, color: accentColor),
                ),
                pw.Text(
                  '${items.length} intention(s)',
                  style: pw.TextStyle(font: boldFont, fontSize: 8.5, color: textMuted),
                ),
              ],
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(10),
            child: pw.Wrap(
              spacing: 12,
              runSpacing: 6,
              children: items.map((item) {
                return pw.Row(
                  mainAxisSize: pw.MainAxisSize.min,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('• ', style: pw.TextStyle(font: boldFont, fontSize: 10, color: accentColor)),
                    pw.Text(
                      item,
                      style: pw.TextStyle(font: baseFont, fontSize: 10, color: textDark),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// Prints or previews the clean liturgical Mass Intention Slip
  static Future<void> printMassIntentionSlip({
    required String massDayOfWeek,
    required String massDate,
    required String massTime,
    required List<MassIntentionModel> intentions,
  }) async {
    final pdfBytes = await generateMassIntentionSlipPdf(
      massDayOfWeek: massDayOfWeek,
      massDate: massDate,
      massTime: massTime,
      intentions: intentions,
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdfBytes,
      name: 'Mass_Intentions_${massDate.replaceAll('-', '')}',
    );
  }
}