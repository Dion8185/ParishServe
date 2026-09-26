import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/asset_model.dart';

class AssetLabelPdfService {
  AssetLabelPdfService._();

  static const PdfColor marianBlue = PdfColor.fromInt(0xFF164E87);
  static const PdfColor goldAccent = PdfColor.fromInt(0xFFD49B18);
  static const PdfColor textDark = PdfColor.fromInt(0xFF1E293B);
  static const PdfColor textMuted = PdfColor.fromInt(0xFF64748B);
  static const PdfColor borderGrey = PdfColor.fromInt(0xFFCBD5E1);

  /// Generates a single compact printable asset property tag (e.g. 70mm x 35mm sticker label)
  static Future<Uint8List> generateSingleAssetLabelPdf(AssetModel asset) async {
    const pageFormat = PdfPageFormat(
      70 * PdfPageFormat.mm,
      38 * PdfPageFormat.mm,
      marginAll: 2 * PdfPageFormat.mm,
    );

    final fontRegular = await PdfGoogleFonts.arimoRegular();
    final fontBold = await PdfGoogleFonts.arimoBold();

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: fontRegular,
        bold: fontBold,
      ),
    );

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (context) {
          return _buildSingleAssetSticker(asset, fontRegular, fontBold);
        },
      ),
    );

    return pdf.save();
  }

  /// Generates a full sheet of asset labels (A4 with 3x8 = 24 labels grid)
  static Future<Uint8List> generateBatchAssetLabelsPdf(List<AssetModel> assets) async {
    const pageFormat = PdfPageFormat.a4;
    final fontRegular = await PdfGoogleFonts.arimoRegular();
    final fontBold = await PdfGoogleFonts.arimoBold();

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: fontRegular,
        bold: fontBold,
      ),
    );

    // 24 labels per A4 page (3 columns x 8 rows)
    const int labelsPerPage = 24;
    for (int i = 0; i < assets.length; i += labelsPerPage) {
      final pageAssets = assets.sublist(
        i,
        (i + labelsPerPage > assets.length) ? assets.length : i + labelsPerPage,
      );

      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          build: (context) {
            return pw.GridView(
              crossAxisCount: 3,
              childAspectRatio: 1.85,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: pageAssets.map((asset) {
                return _buildSingleAssetSticker(asset, fontRegular, fontBold);
              }).toList(),
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  /// Prints single asset sticker directly to OS printer / print dialog
  static Future<void> printSingleAssetLabel(AssetModel asset) async {
    final pdfBytes = await generateSingleAssetLabelPdf(asset);
    await Printing.layoutPdf(
      onLayout: (format) async => pdfBytes,
      name: 'AssetLabel_${asset.controlNumber}',
    );
  }

  /// Prints multiple asset stickers
  static Future<void> printBatchAssetLabels(List<AssetModel> assets) async {
    final pdfBytes = await generateBatchAssetLabelsPdf(assets);
    await Printing.layoutPdf(
      onLayout: (format) async => pdfBytes,
      name: 'ParishAssets_Labels_${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  // ===========================================================================
  // Individual Sticker Layout Builder
  // ===========================================================================

  static pw.Widget _buildSingleAssetSticker(
      AssetModel asset,
      pw.Font fontRegular,
      pw.Font fontBold,
      ) {
    // The QR data embeds the unique permanent token or control number for instant verification lookup
    final qrData = asset.qrCodeToken.isNotEmpty ? asset.qrCodeToken : asset.controlNumber;

    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(5),
        border: pw.Border.all(color: marianBlue, width: 1.2),
      ),
      padding: const pw.EdgeInsets.all(5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // Left: Scannable QR Code
          pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Container(
                width: 48,
                height: 48,
                padding: const pw.EdgeInsets.all(2),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  border: pw.Border.all(color: borderGrey, width: 0.6),
                  borderRadius: pw.BorderRadius.circular(3),
                ),
                child: pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: qrData,
                ),
              ),
              pw.SizedBox(height: 1),
              pw.Text(
                'DSP-SJP2',
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 5.5,
                  fontWeight: pw.FontWeight.bold,
                  color: marianBlue,
                ),
              ),
            ],
          ),
          pw.SizedBox(width: 6),

          // Right: Parish Branding & Diocesan Control Coordinates
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  'ST. JOHN PAUL II PARISH',
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 6.5,
                    fontWeight: pw.FontWeight.bold,
                    color: marianBlue,
                  ),
                  maxLines: 1,
                ),
                pw.Text(
                  'Diocese of San Pablo • Property Tag',
                  style: pw.TextStyle(
                    font: fontRegular,
                    fontSize: 5.0,
                    color: textMuted,
                  ),
                ),
                pw.Container(
                  margin: const pw.EdgeInsets.symmetric(vertical: 2),
                  height: 0.5,
                  color: goldAccent,
                ),
                pw.Text(
                  asset.controlNumber,
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                    color: textDark,
                  ),
                  maxLines: 1,
                ),
                pw.SizedBox(height: 1),
                pw.Text(
                  asset.itemName,
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 6.5,
                    fontWeight: pw.FontWeight.bold,
                    color: marianBlue,
                  ),
                  maxLines: 1,
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Loc: ${asset.locationAcronym} • Cls: ${asset.classificationAcronym}',
                      style: pw.TextStyle(font: fontRegular, fontSize: 5.0, color: textMuted),
                    ),
                    pw.Text(
                      'Acq: ${asset.acquisitionYear}',
                      style: pw.TextStyle(font: fontRegular, fontSize: 5.0, color: textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}