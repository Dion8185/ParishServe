
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
  static const PdfColor textDark = PdfColor.fromInt(0xFF000000);
  static const PdfColor textMuted = PdfColor.fromInt(0xFF718096);
  static const PdfColor borderGrey = PdfColor.fromInt(0xFFCBD5E1);

  // ===========================================================================
  // STICKER DIMENSIONS
  // ===========================================================================

  static const double stickerWidth = 62.5 * PdfPageFormat.mm;
  static const double stickerHeight = 35.0 * PdfPageFormat.mm;

  static const double colSpacing = 4.0 * PdfPageFormat.mm;
  static const double rowSpacing = 4.5 * PdfPageFormat.mm;

  static const double horizontalMargin = 7.0 * PdfPageFormat.mm;
  static const double verticalMargin = 9.0 * PdfPageFormat.mm;

  // ===========================================================================
  // SINGLE ASSET LABEL
  // ===========================================================================

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
      theme: pw.ThemeData.withFont(
        base: fontRegular,
        bold: fontBold,
      ),
    );

    if (specificUnitIndex != null && specificUnitIndex > 0) {
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

  // ===========================================================================
  // BATCH ASSET LABELS
  // A4 PORTRAIT: 3 COLUMNS x 7 ROWS = 21 LABELS PER PAGE
  // ===========================================================================

  static Future<Uint8List> generateBatchAssetLabelsPdf(
      List<AssetModel> assets, {
        bool expandQuantified = true,
      }) async {
    const pageFormat = PdfPageFormat.a4;

    final fontRegular = await PdfGoogleFonts.arimoRegular();
    final fontBold = await PdfGoogleFonts.arimoBold();

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: fontRegular,
        bold: fontBold,
      ),
    );

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

    const int labelsPerPage = 21;

    for (int i = 0; i < stickerList.length; i += labelsPerPage) {
      final pageStickers = stickerList.sublist(
        i,
        (i + labelsPerPage > stickerList.length)
            ? stickerList.length
            : i + labelsPerPage,
      );

      final List<List<_StickerDescriptor>> rowsOfThree = [];

      for (int r = 0; r < pageStickers.length; r += 3) {
        rowsOfThree.add(
          pageStickers.sublist(
            r,
            (r + 3 > pageStickers.length)
                ? pageStickers.length
                : r + 3,
          ),
        );
      }

      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.symmetric(
            horizontal: horizontalMargin,
            vertical: verticalMargin,
          ),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                for (int rIdx = 0; rIdx < rowsOfThree.length; rIdx++) ...[
                  if (rIdx > 0)
                    pw.SizedBox(height: rowSpacing),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.start,
                    children: [
                      for (
                      int cIdx = 0;
                      cIdx < rowsOfThree[rIdx].length;
                      cIdx++
                      ) ...[
                        if (cIdx > 0)
                          pw.SizedBox(width: colSpacing),
                        _buildSingleAssetSticker(
                          rowsOfThree[rIdx][cIdx].asset,
                          fontRegular,
                          fontBold,
                          subUnitIndex:
                          rowsOfThree[rIdx][cIdx].subUnitIndex,
                          totalUnits:
                          rowsOfThree[rIdx][cIdx].totalUnits,
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  // ===========================================================================
  // PRINTING METHODS
  // ===========================================================================

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
  // DATE FORMATTING
  // ===========================================================================

  static String _formatPrettyDate(DateTime? date) {
    if (date == null) return '';

    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  // ===========================================================================
  // ASSET STICKER DESIGN
  // ===========================================================================

  static pw.Widget _buildSingleAssetSticker(
      AssetModel asset,
      pw.Font fontRegular,
      pw.Font fontBold, {
        int? subUnitIndex,
        int? totalUnits,
      }) {
    final bool isSerializedUnit =
        subUnitIndex != null &&
            totalUnits != null &&
            totalUnits > 1;

    // Display-only suffix for quantified assets.
    // Example: C-FF-2026-001#01
    final String subSuffix = isSerializedUnit
        ? ' #${subUnitIndex.toString().padLeft(2, '0')}'
        : '';

    final String displayControlNo =
        '${asset.controlNumber}$subSuffix';

    // IMPORTANT:
    // QR DATA REMAINS COMPLETELY UNCHANGED.
    // Do not append the quantified unit suffix to the QR payload.
    final String qrData = asset.qrCodeToken.isNotEmpty
        ? asset.qrCodeToken
        : asset.controlNumber;

    final locationText =
    asset.locationName != null &&
        asset.locationName!.isNotEmpty
        ? asset.locationName!
        : asset.locationAcronym;

    final classificationText =
    asset.classificationName != null &&
        asset.classificationName!.isNotEmpty
        ? asset.classificationName!
        : asset.classificationAcronym;

    final formattedAcqDate =
    asset.dateOfAcquisition != null
        ? _formatPrettyDate(asset.dateOfAcquisition)
        : '${asset.acquisitionYear}';

    // =========================================================================
    // MAIN STICKER CONTAINER
    // =========================================================================

    return pw.Container(
      width: stickerWidth,
      height: stickerHeight,
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(6.0),
        border: pw.Border.all(
          color: marianBlue,
          width: 1.2,
        ),
      ),
      padding: const pw.EdgeInsets.symmetric(
        horizontal: 4.5,
        vertical: 3.5,
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // ===================================================================
          // LEFT SECTION: QR CODE AND PARISH IDENTIFIER
          // ===================================================================

          pw.SizedBox(
            width: 42,
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Container(
                  width: 42,
                  height: 42,
                  padding: const pw.EdgeInsets.all(1.5),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    border: pw.Border.all(
                      color: borderGrey,
                      width: 0.6,
                    ),
                    borderRadius: pw.BorderRadius.circular(3),
                  ),
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: qrData,
                    drawText: false,
                  ),
                ),
                pw.SizedBox(height: 1.5),
                pw.Text(
                  'DSP-SJP2',
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 5.8,
                    fontWeight: pw.FontWeight.bold,
                    color: marianBlue,
                  ),
                  maxLines: 1,
                ),
              ],
            ),
          ),

          pw.SizedBox(width: 6.0),

          // ===================================================================
          // RIGHT SECTION: ASSET INFORMATION
          // ===================================================================

          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                // SECTION BADGE

                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 4.5,
                      vertical: 1.2,
                    ),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFE7F1FC),
                      borderRadius: pw.BorderRadius.circular(3.5),
                    ),
                    child: pw.Text(
                      asset.inventorySectionCode,
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 5.2,
                        fontWeight: pw.FontWeight.bold,
                        color: marianBlue,
                      ),
                    ),
                  ),
                ),

                // PARISH HEADER

                pw.SizedBox(
                  width: double.infinity,
                  child: pw.Text(
                    'Saint John Paul II Parish - Asset Tag',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 7.2,
                      fontWeight: pw.FontWeight.bold,
                      color: marianBlue,
                    ),
                    maxLines: 1,
                  ),
                ),

                // GOLD SEPARATOR

                pw.Container(
                  width: double.infinity,
                  height: 1.0,
                  color: goldAccent,
                ),

                // CONTROL NUMBER

                pw.Center(
                  child: pw.Text(
                    displayControlNo,
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 12.0,
                      fontWeight: pw.FontWeight.bold,
                      color: textDark,
                    ),
                    maxLines: 1,
                  ),
                ),

                // ASSET NAME

                pw.Center(
                  child: pw.Text(
                    asset.itemName,
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 9.8,
                      fontWeight: pw.FontWeight.bold,
                      color: marianBlue,
                    ),
                    maxLines: 1,
                  ),
                ),

                // DATE ACQUIRED

                pw.Text(
                  'Date Acquired: $formattedAcqDate',
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 6.8,
                    fontWeight: pw.FontWeight.bold,
                    color: textDark,
                  ),
                  maxLines: 1,
                ),

                // LOCATION AND CLASSIFICATION

                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Location: $locationText',
                      style: pw.TextStyle(
                        font: fontRegular,
                        fontSize: 6.2,
                        color: textMuted,
                      ),
                      maxLines: 1,
                    ),
                    pw.Text(
                      'Classification: $classificationText',
                      style: pw.TextStyle(
                        font: fontRegular,
                        fontSize: 6.2,
                        color: textMuted,
                      ),
                      maxLines: 1,
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

// =============================================================================
// STICKER DESCRIPTOR
// =============================================================================

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
