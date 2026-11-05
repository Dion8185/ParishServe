// =============================================================================
// FILE: lib/features/asset_inventory/services/asset_label_pdf_service.dart
// =============================================================================

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

  // Exact fixed card dimensions matching Image 1 (fits 3 columns on standard A4)
  static const double stickerWidth = 63.0 * PdfPageFormat.mm; // ~178.6 pt
  static const double stickerHeight = 35.0 * PdfPageFormat.mm; // ~99.2 pt

  /// Generates a single printable sticker label centered on label roll paper
  static Future<Uint8List> generateSingleAssetLabelPdf(AssetModel asset) async {
    const pageFormat = PdfPageFormat(
      70 * PdfPageFormat.mm,
      38 * PdfPageFormat.mm,
      marginAll: 1.5 * PdfPageFormat.mm,
    );

    final fontRegular = await PdfGoogleFonts.arimoRegular();
    final fontBold = await PdfGoogleFonts.arimoBold();

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
    );

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (context) {
          return pw.Center(
            child: _buildSingleAssetSticker(asset, fontRegular, fontBold),
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Generates batch asset labels on standard A4 sheet in fixed-size cards (3 columns, up to 21 labels per page)
  static Future<Uint8List> generateBatchAssetLabelsPdf(
    List<AssetModel> assets,
  ) async {
    const pageFormat = PdfPageFormat.a4;
    final fontRegular = await PdfGoogleFonts.arimoRegular();
    final fontBold = await PdfGoogleFonts.arimoBold();

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
    );

    const int labelsPerPage = 21; // 3 columns x 7 rows
    for (int i = 0; i < assets.length; i += labelsPerPage) {
      final pageAssets = assets.sublist(
        i,
        (i + labelsPerPage > assets.length) ? assets.length : i + labelsPerPage,
      );

      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.symmetric(
            horizontal: 7.0 * PdfPageFormat.mm,
            vertical: 9.0 * PdfPageFormat.mm,
          ),
          build: (context) {
            return pw.Wrap(
              spacing: 3.5 * PdfPageFormat.mm,
              runSpacing: 4.5 * PdfPageFormat.mm,
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

  static Future<void> printSingleAssetLabel(AssetModel asset) async {
    final pdfBytes = await generateSingleAssetLabelPdf(asset);
    await Printing.layoutPdf(
      onLayout: (format) async => pdfBytes,
      name: 'AssetLabel_${asset.controlNumber}',
    );
  }

  static Future<void> printBatchAssetLabels(List<AssetModel> assets) async {
    final pdfBytes = await generateBatchAssetLabelsPdf(assets);
    await Printing.layoutPdf(
      onLayout: (format) async => pdfBytes,
      name: 'ParishAssets_Labels_${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  // ===========================================================================
  // Reference Sticker Layout (Fixed Size matching Image 1 exactly)
  // ===========================================================================

  static pw.Widget _buildSingleAssetSticker(
    AssetModel asset,
    pw.Font fontRegular,
    pw.Font fontBold,
  ) {
    final qrData = asset.qrCodeToken.isNotEmpty
        ? asset.qrCodeToken
        : asset.controlNumber;
    final displayControlNo = asset.controlNumber;

    final locationText =
        asset.locationName != null && asset.locationName!.isNotEmpty
        ? asset.locationName!
        : asset.locationAcronym;

    final classificationText =
        asset.classificationName != null && asset.classificationName!.isNotEmpty
        ? asset.classificationName!
        : asset.classificationAcronym;

    return pw.Container(
      width: stickerWidth,
      height: stickerHeight,
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: marianBlue, width: 1.2),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // Left: Scannable QR Code Box
          pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Container(
                width: 44,
                height: 44,
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
              pw.SizedBox(height: 2),
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
          pw.SizedBox(width: 5),

          // Right: Parish Details & Control Coordinates
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                // Top Header Row: Parish Title, Section Badge & Qty
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'ST. JOHN PAUL II PARISH',
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 6.2,
                              fontWeight: pw.FontWeight.bold,
                              color: marianBlue,
                            ),
                            maxLines: 1,
                          ),
                          pw.Text(
                            'Diocese of San Pablo • Property Tag',
                            style: pw.TextStyle(
                              font: fontRegular,
                              fontSize: 4.6,
                              color: textMuted,
                            ),
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 3.5,
                            vertical: 1.0,
                          ),
                          decoration: pw.BoxDecoration(
                            color: asset.unitPrice >= 10000.0
                                ? PdfColors.amber100
                                : PdfColors.blue50,
                            borderRadius: pw.BorderRadius.circular(2.5),
                          ),
                          child: pw.Text(
                            asset.inventorySectionCode,
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 4.5,
                              fontWeight: pw.FontWeight.bold,
                              color: asset.unitPrice >= 10000.0
                                  ? goldAccent
                                  : marianBlue,
                            ),
                          ),
                        ),
                        if (asset.quantity > 1) ...[
                          pw.SizedBox(height: 1),
                          pw.Text(
                            'Qty: ${asset.quantity}',
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 5.0,
                              color: marianBlue,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),

                // Gold Accent Separator Line
                pw.Container(
                  margin: const pw.EdgeInsets.symmetric(vertical: 1.0),
                  height: 0.8,
                  color: goldAccent,
                ),

                // Control Number
                pw.Text(
                  displayControlNo,
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 8.8,
                    fontWeight: pw.FontWeight.bold,
                    color: textDark,
                  ),
                  maxLines: 1,
                ),

                // Item Name
                pw.Text(
                  asset.itemName,
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 6.2,
                    fontWeight: pw.FontWeight.bold,
                    color: marianBlue,
                  ),
                  maxLines: 1,
                ),

                // Bottom Metadata Row: Location, Classification & Acq Date
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Location: $locationText',
                            style: pw.TextStyle(
                              font: fontRegular,
                              fontSize: 4.3,
                              color: textMuted,
                            ),
                            maxLines: 1,
                          ),
                          pw.Text(
                            'Classification: $classificationText',
                            style: pw.TextStyle(
                              font: fontRegular,
                              fontSize: 4.3,
                              color: textMuted,
                            ),
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                    pw.Text(
                      'Acq: ${asset.formattedAcquisitionDate}',
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 4.8,
                        color: textDark,
                      ),
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
