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

  /// Generates printable sticker labels for an asset or property group.
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

    if (asset.isPropertyGroup && asset.childItems.isNotEmpty) {
      for (final child in asset.childItems) {
        pdf.addPage(
          pw.Page(
            pageFormat: pageFormat,
            build: (context) {
              return _buildSingleAssetSticker(child, fontRegular, fontBold, isChildUnit: true);
            },
          ),
        );
      }
    } else {
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build: (context) {
            return _buildSingleAssetSticker(asset, fontRegular, fontBold, isChildUnit: false);
          },
        ),
      );
    }

    return pdf.save();
  }

  /// Generates a full sheet of asset labels (A4 with 3x8 = 24 labels grid).
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

    final List<AssetModel> printableStickers = [];
    for (final asset in assets) {
      if (asset.isPropertyGroup && asset.childItems.isNotEmpty) {
        printableStickers.addAll(asset.childItems);
      } else {
        printableStickers.add(asset);
      }
    }

    const int labelsPerPage = 24;
    for (int i = 0; i < printableStickers.length; i += labelsPerPage) {
      final pageAssets = printableStickers.sublist(
        i,
        (i + labelsPerPage > printableStickers.length) ? printableStickers.length : i + labelsPerPage,
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
                return _buildSingleAssetSticker(asset, fontRegular, fontBold, isChildUnit: asset.itemSequenceInBatch != null);
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
  // Individual Sticker Layout Builder
  // ===========================================================================

  static pw.Widget _buildSingleAssetSticker(
      AssetModel asset,
      pw.Font fontRegular,
      pw.Font fontBold,
      {bool isChildUnit = false}
      ) {
    final qrData = asset.qrCodeToken.isNotEmpty ? asset.qrCodeToken : asset.controlNumber;

    // Uses clean base control number without redundant -001 suffix
    final displayControlNo = asset.controlNumber;

    // Resolve full readable names for Location and Classification
    final locationText = asset.locationName != null && asset.locationName!.isNotEmpty
        ? asset.locationName!
        : asset.locationAcronym;

    final classificationText = asset.classificationName != null && asset.classificationName!.isNotEmpty
        ? asset.classificationName!
        : asset.classificationAcronym;

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
                isChildUnit ? 'ITEM #${asset.propertyLabelSuffix}' : 'DSP-SJP2',
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

          // Right: Parish Branding & Control Coordinates
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
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
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 2.5, vertical: 0.8),
                      decoration: pw.BoxDecoration(
                        color: asset.unitPrice >= 10000.0 ? PdfColors.amber100 : PdfColors.blue50,
                        borderRadius: pw.BorderRadius.circular(2),
                      ),
                      child: pw.Text(
                        asset.inventorySectionCode,
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 4.5,
                          fontWeight: pw.FontWeight.bold,
                          color: asset.unitPrice >= 10000.0 ? goldAccent : marianBlue,
                        ),
                      ),
                    ),
                  ],
                ),
                pw.Text(
                  isChildUnit ? 'Property Group Item Unit' : 'Diocese of San Pablo • Property Tag',
                  style: pw.TextStyle(
                    font: fontRegular,
                    fontSize: 4.8,
                    color: textMuted,
                  ),
                ),
                pw.Container(
                  margin: const pw.EdgeInsets.symmetric(vertical: 1.5),
                  height: 0.5,
                  color: goldAccent,
                ),
                pw.Text(
                  displayControlNo,
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                    color: textDark,
                  ),
                  maxLines: 1,
                ),
                pw.SizedBox(height: 0.5),
                pw.Text(
                  asset.itemName,
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 6.0,
                    fontWeight: pw.FontWeight.bold,
                    color: marianBlue,
                  ),
                  maxLines: 1,
                ),
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        'Location: $locationText\nClassification: $classificationText',
                        style: pw.TextStyle(font: fontRegular, fontSize: 4.5, color: textMuted, lineSpacing: 1.1),
                        maxLines: 2,
                      ),
                    ),
                    pw.Text(
                      'Acq: ${asset.formattedAcquisitionDate}',
                      style: pw.TextStyle(font: fontBold, fontSize: 5.0, color: textDark),
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