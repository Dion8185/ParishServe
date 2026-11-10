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

  // Exact fixed card dimensions matching Diocesan physical label specification (fits 3 columns on standard A4)
  static const double stickerWidth = 63.0 * PdfPageFormat.mm; // ~178.6 pt
  static const double stickerHeight = 35.0 * PdfPageFormat.mm; // ~99.2 pt

  /// Generates a single printable sticker label (or expanded sub-unit roll if quantified).
  /// If [expandQuantified] is true and asset has quantity > 1, generates individual
  /// serialized stickers: `C-FF 2026-0001/01` to `C-FF 2026-0001/NN`.
  static Future<Uint8List> generateSingleAssetLabelPdf(
      AssetModel asset, {
        bool expandQuantified = true,
        int? specificUnitIndex,
      }) async {
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

    if (specificUnitIndex != null && specificUnitIndex > 0) {
      // Print specific single sub-unit (e.g. reprint #4)
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build: (context) {
            return pw.Center(
              child: _buildSingleAssetSticker(
                asset,
                fontRegular,
                fontBold,
                subUnitIndex: specificUnitIndex,
                totalUnits: asset.quantity,
              ),
            );
          },
        ),
      );
    } else if (expandQuantified && asset.quantity > 1) {
      // Print roll of individual serialized labels: /01, /02, ... /NN
      for (int unit = 1; unit <= asset.quantity; unit++) {
        pdf.addPage(
          pw.Page(
            pageFormat: pageFormat,
            build: (context) {
              return pw.Center(
                child: _buildSingleAssetSticker(
                  asset,
                  fontRegular,
                  fontBold,
                  subUnitIndex: unit,
                  totalUnits: asset.quantity,
                ),
              );
            },
          ),
        );
      }
    } else {
      // Master summary label
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build: (context) {
            return pw.Center(
              child: _buildSingleAssetSticker(
                asset,
                fontRegular,
                fontBold,
              ),
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  /// Generates batch asset labels on standard A4 sheet in fixed-size cards (3 columns x 7 rows, 21 labels per page).
  /// When [expandQuantified] is true, items with quantity > 1 generate individual serialized stickers:
  /// e.g. `C-FF 2026-0001/01` through `C-FF 2026-0001/20`.
  static Future<Uint8List> generateBatchAssetLabelsPdf(
      List<AssetModel> assets, {
        bool expandQuantified = true,
      }) async {
    const pageFormat = PdfPageFormat.a4;
    final fontRegular = await PdfGoogleFonts.arimoRegular();
    final fontBold = await PdfGoogleFonts.arimoBold();

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
    );

    // Flatten assets into individual sticker descriptors
    final List<_StickerDescriptor> stickerList = [];
    for (final asset in assets) {
      if (expandQuantified && asset.quantity > 1) {
        for (int unit = 1; unit <= asset.quantity; unit++) {
          stickerList.add(
            _StickerDescriptor(
              asset: asset,
              subUnitIndex: unit,
              totalUnits: asset.quantity,
            ),
          );
        }
      } else {
        stickerList.add(
          _StickerDescriptor(
            asset: asset,
            subUnitIndex: null,
            totalUnits: asset.quantity,
          ),
        );
      }
    }

    const int labelsPerPage = 21; // 3 columns x 7 rows
    for (int i = 0; i < stickerList.length; i += labelsPerPage) {
      final pageStickers = stickerList.sublist(
        i,
        (i + labelsPerPage > stickerList.length)
            ? stickerList.length
            : i + labelsPerPage,
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
              children: pageStickers.map((desc) {
                return _buildSingleAssetSticker(
                  desc.asset,
                  fontRegular,
                  fontBold,
                  subUnitIndex: desc.subUnitIndex,
                  totalUnits: desc.totalUnits,
                );
              }).toList(),
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  static Future<void> printSingleAssetLabel(
      AssetModel asset, {
        bool expandQuantified = true,
        int? specificUnitIndex,
      }) async {
    final pdfBytes = await generateSingleAssetLabelPdf(
      asset,
      expandQuantified: expandQuantified,
      specificUnitIndex: specificUnitIndex,
    );
    await Printing.layoutPdf(
      onLayout: (format) async => pdfBytes,
      name: 'AssetLabel_${asset.controlNumber}',
    );
  }

  static Future<void> printBatchAssetLabels(
      List<AssetModel> assets, {
        bool expandQuantified = true,
      }) async {
    final pdfBytes = await generateBatchAssetLabelsPdf(
      assets,
      expandQuantified: expandQuantified,
    );
    await Printing.layoutPdf(
      onLayout: (format) async => pdfBytes,
      name: 'ParishAssets_Labels_${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  // ===========================================================================
  // Reference Sticker Layout (Fixed Size with Serialized Quantified Sub-Numbering)
  // ===========================================================================

  static pw.Widget _buildSingleAssetSticker(
      AssetModel asset,
      pw.Font fontRegular,
      pw.Font fontBold, {
        int? subUnitIndex,
        int? totalUnits,
      }) {
    final bool isSerializedUnit = subUnitIndex != null &&
        totalUnits != null &&
        totalUnits > 1;

    final String subSuffix =
    isSerializedUnit ? '/${subUnitIndex.toString().padLeft(2, '0')}' : '';

    final String displayControlNo = '${asset.controlNumber}$subSuffix';

    // QR payload embeds exact serialized sub-unit so scanner verifies specific unit directly
    final String baseQr = asset.qrCodeToken.isNotEmpty
        ? asset.qrCodeToken
        : asset.controlNumber;
    final String qrData = '$baseQr$subSuffix';

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
                // Top Header Row: Parish Title, Section Badge & Unit Suffix Tag
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
                        if (isSerializedUnit) ...[
                          pw.SizedBox(height: 1),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                              horizontal: 2.5,
                              vertical: 0.5,
                            ),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.blue100,
                              borderRadius: pw.BorderRadius.circular(2),
                            ),
                            child: pw.Text(
                              'Unit $subUnitIndex of $totalUnits',
                              style: pw.TextStyle(
                                font: fontBold,
                                fontSize: 4.5,
                                color: marianBlue,
                              ),
                            ),
                          ),
                        ] else if (asset.quantity > 1) ...[
                          pw.SizedBox(height: 1),
                          pw.Text(
                            'Total Qty: ${asset.quantity}',
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

                // Serialized Control Number
                pw.Text(
                  displayControlNo,
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: isSerializedUnit ? 8.2 : 8.8,
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

class _StickerDescriptor {
  final AssetModel asset;
  final int? subUnitIndex;
  final int? totalUnits;

  const _StickerDescriptor({
    required this.asset,
    this.subUnitIndex,
    this.totalUnits,
  });
}