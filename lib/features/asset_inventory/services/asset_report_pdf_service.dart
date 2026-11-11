// =============================================================================
// FILE: lib/features/asset_inventory/services/asset_report_pdf_service.dart
// =============================================================================

import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/asset_model.dart';

class AssetReportPdfService {
  AssetReportPdfService._();

  static const PdfColor marianBlue = PdfColor.fromInt(0xFF164E87);
  static const PdfColor marianNavy = PdfColor.fromInt(0xFF0F2942);
  static const PdfColor goldAccent = PdfColor.fromInt(0xFFD49B18);
  static const PdfColor textDark = PdfColors.black;
  static const PdfColor textMuted = PdfColor.fromInt(0xFF475569);
  static const PdfColor borderGrey = PdfColor.fromInt(0xFF94A3B8);
  static const PdfColor lightCardBg = PdfColor.fromInt(0xFFF8FAFC);

  // Exact card dimensions calibrated so 2 cards fit safely on A4 without clipping
  static const double cardHeight = 352.0;

  // In-memory static caches for high-speed instant re-renders
  static pw.Font? _cachedFontRegular;
  static pw.Font? _cachedFontBold;
  static pw.Font? _cachedFontItalic;
  static pw.Font? _cachedFontBoldItalic;
  static final Map<String, Uint8List> _globalImageCache = {};

  /// Loads and caches all required Google Fonts concurrently
  static Future<List<pw.Font>> _loadFontsConcurrently() async {
    if (_cachedFontRegular != null &&
        _cachedFontBold != null &&
        _cachedFontItalic != null &&
        _cachedFontBoldItalic != null) {
      return [
        _cachedFontRegular!,
        _cachedFontBold!,
        _cachedFontItalic!,
        _cachedFontBoldItalic!,
      ];
    }

    final results = await Future.wait([
      PdfGoogleFonts.arimoRegular(),
      PdfGoogleFonts.arimoBold(),
      PdfGoogleFonts.arimoItalic(),
      PdfGoogleFonts.arimoBoldItalic(),
    ]);

    _cachedFontRegular = results[0];
    _cachedFontBold = results[1];
    _cachedFontItalic = results[2];
    _cachedFontBoldItalic = results[3];

    return results;
  }

  // ===========================================================================
  // 1. Photographic Inventory Cards Report (2 Cards per A4 Page)
  // ===========================================================================

  /// Generates the photographic inventory report (2 items per A4 portrait page)
  /// matching the specified reference photo card design.
  static Future<Uint8List> generatePhotographicReportPdf(
      List<AssetModel> assets, {
        String? dateRangeLabel,
        String? sectionLabel,
      }) async {
    const pageFormat = PdfPageFormat.a4;

    // Load fonts and preload all asset photographs in parallel
    final fontsFuture = _loadFontsConcurrently();

    final Map<String, Uint8List?> photoCache = {};
    final photoFetchFutures = assets
        .where((a) => a.photoUrl != null && a.photoUrl!.trim().isNotEmpty)
        .map((asset) async {
      final url = asset.photoUrl!.trim();
      if (_globalImageCache.containsKey(url)) {
        photoCache[asset.assetId] = _globalImageCache[url];
        return;
      }
      try {
        final res = await http.get(Uri.parse(url)).timeout(
          const Duration(seconds: 4),
        );
        if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
          _globalImageCache[url] = res.bodyBytes;
          photoCache[asset.assetId] = res.bodyBytes;
        }
      } catch (_) {
        photoCache[asset.assetId] = null;
      }
    });

    final results = await Future.wait([
      fontsFuture,
      Future.wait(photoFetchFutures),
    ]);

    final fonts = results[0] as List<pw.Font>;
    final fontRegular = fonts[0];
    final fontBold = fonts[1];
    final fontItalic = fonts[2];
    final fontBoldItalic = fonts[3];

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: fontRegular,
        bold: fontBold,
        italic: fontItalic,
        boldItalic: fontBoldItalic,
      ),
    );

    const int itemsPerPage = 2;
    for (int i = 0; i < assets.length; i += itemsPerPage) {
      final pageAssets = assets.sublist(
        i,
        (i + itemsPerPage > assets.length) ? assets.length : i + itemsPerPage,
      );

      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.symmetric(
            horizontal: 8.0 * PdfPageFormat.mm,
            vertical: 6.0 * PdfPageFormat.mm,
          ),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Compact Header
                _buildReportHeader(
                  title: 'PARISH BOOK OF INVENTORY — PHOTOGRAPHIC INVENTORY',
                  dateRangeLabel: dateRangeLabel,
                  sectionLabel: sectionLabel,
                  fontRegular: fontRegular,
                  fontBold: fontBold,
                ),
                pw.SizedBox(height: 5),

                // Cards List (2 items per page)
                ...pageAssets.map((asset) {
                  final imageBytes = photoCache[asset.assetId];
                  final isLastOnPage =
                      pageAssets.indexOf(asset) == pageAssets.length - 1;

                  return pw.Padding(
                    padding: pw.EdgeInsets.only(bottom: isLastOnPage ? 0 : 16),
                    child: pw.SizedBox(
                      height: cardHeight,
                      child: _buildPhotographicCard(
                        asset,
                        imageBytes,
                        fontRegular,
                        fontBold,
                        fontItalic,
                      ),
                    ),
                  );
                }),

                pw.Spacer(),

                // Page numbering footer
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    'Page ${context.pageNumber} of ${context.pagesCount}',
                    style: pw.TextStyle(
                      font: fontRegular,
                      fontSize: 7.5,
                      color: textMuted,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  /// Builds a single photographic inventory card matching the exact boxed form layout:
  /// Left: Photo. Right: Boxed form with black ink and full underlined rows.
  static pw.Widget _buildPhotographicCard(
      AssetModel asset,
      Uint8List? imageBytes,
      pw.Font fontRegular,
      pw.Font fontBold,
      pw.Font fontItalic,
      ) {
    final inventoryDateStr = asset.lastAuditedAt != null
        ? asset.formattedLastAuditedDate
        : asset.formattedRegistrationDate;

    // Cost of Acquisition formatting rule:
    // If quantity == 1: "P96,000"
    // If quantity > 1:  "P96,000 (P1,000 per unit)"
    final String formattedTotalOnly =
        'P${AssetModel.formatCurrency(asset.totalCost)}';
    final String formattedCostOfAcquisition = asset.quantity > 1
        ? '$formattedTotalOnly (P${AssetModel.formatCurrency(asset.unitPrice)} per unit)'
        : formattedTotalOnly;

    // Remarks rule: If quantified > 1, put quantity on remarks line
    final String remarksLead =
    asset.quantity > 1 ? 'Quantity: ${asset.quantity} units. ' : '';
    final String baseRemarks =
    asset.remarks != null && asset.remarks!.isNotEmpty
        ? asset.remarks!
        : 'Condition: ${asset.conditionStatus.toUpperCase()} • Availability: ${asset.operationalStatus}';
    final String fullRemarksText = '$remarksLead$baseRemarks';

    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: PdfColors.black, width: 0.8),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // Left side: Item Photograph
          pw.Expanded(
            flex: 10,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(6),
              color: PdfColors.grey100,
              child: imageBytes != null
                  ? pw.Image(
                pw.MemoryImage(imageBytes),
                fit: pw.BoxFit.contain,
              )
                  : pw.Center(
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text(
                      '[ NO PHOTO ATTACHED ]',
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 10,
                        color: textMuted,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      asset.itemName,
                      style: pw.TextStyle(
                        font: fontRegular,
                        fontSize: 8.5,
                        color: textMuted,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Right side: Boxed Evidence Form matching reference image
          pw.Expanded(
            flex: 12,
            child: pw.Container(
              margin: const pw.EdgeInsets.all(4),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: 0.8),
              ),
              padding: const pw.EdgeInsets.fromLTRB(8, 6, 8, 4),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // Top Header: Control No. and Date of Inventory
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.end,
                        children: [
                          pw.Text(
                            'Control No.: ',
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 9.0,
                              color: PdfColors.black,
                            ),
                          ),
                          pw.Container(
                            width: 135,
                            decoration: const pw.BoxDecoration(
                              border: pw.Border(
                                bottom: pw.BorderSide(
                                    color: PdfColors.black, width: 0.8),
                              ),
                            ),
                            padding: const pw.EdgeInsets.only(bottom: 0.5),
                            child: pw.Text(
                              asset.controlNumber,
                              style: pw.TextStyle(
                                font: fontBold,
                                fontSize: 9.0,
                                color: PdfColors.black,
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 1.5),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.end,
                        children: [
                          pw.Text(
                            'Date of Inventory: ',
                            style: pw.TextStyle(
                              font: fontItalic,
                              fontSize: 9.0,
                              color: PdfColors.black,
                            ),
                          ),
                          pw.Container(
                            width: 135,
                            decoration: const pw.BoxDecoration(
                              border: pw.Border(
                                bottom: pw.BorderSide(
                                    color: PdfColors.black, width: 0.8),
                              ),
                            ),
                            padding: const pw.EdgeInsets.only(bottom: 0.5),
                            child: pw.Text(
                              inventoryDateStr,
                              style: pw.TextStyle(
                                font: fontBold,
                                fontSize: 8.5,
                                color: PdfColors.black,
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Main Properties
                  _buildFormLine(
                    'Item:',
                    asset.itemName,
                    fontBold,
                    fontBold,
                  ),
                  _buildFormLine(
                    'Location:',
                    asset.displayLocation,
                    fontBold,
                    fontBold,
                  ),
                  _buildFormLine(
                    'Date Acquired:',
                    asset.formattedAcquisitionDate,
                    fontBold,
                    fontBold,
                  ),
                  _buildFormLine(
                    'Mode of Acquisition:',
                    asset.modeOfAcquisition,
                    fontBold,
                    fontBold,
                  ),
                  _buildFormLine(
                    'Cost of Acquisition:',
                    formattedCostOfAcquisition,
                    fontBold,
                    fontBold,
                  ),

                  // Description Block
                  pw.Text(
                    'Description:',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 8.5,
                      color: PdfColors.black,
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 16),
                    child: pw.Column(
                      children: [
                        _buildFormLine(
                          'Dimension:',
                          asset.dimensions ?? '',
                          fontItalic,
                          fontBold,
                        ),
                        _buildFormLine(
                          'Color:',
                          asset.color ?? '',
                          fontItalic,
                          fontBold,
                        ),
                        _buildFormLine(
                          'Model:',
                          asset.model ?? '',
                          fontItalic,
                          fontBold,
                        ),
                        _buildFormLine(
                          'Others:',
                          asset.others ?? '',
                          fontItalic,
                          fontBold,
                        ),
                        // 2 blank underline lines under Others
                        _buildEmptyUnderline(),
                        _buildEmptyUnderline(),
                      ],
                    ),
                  ),

                  // Remarks Section
                  pw.Text(
                    'Remarks:',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 8.5,
                      color: PdfColors.black,
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 16),
                    child: pw.Column(
                      children: [
                        _buildUnderlinedTextLine(
                          fullRemarksText,
                          fontBold,
                        ),
                        _buildEmptyUnderline(),
                        _buildEmptyUnderline(),
                        _buildEmptyUnderline(),
                        _buildEmptyUnderline(),
                        pw.SizedBox(height: 30),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      );
  }


  /// Builds a form label followed by an underline with bold black answer
  static pw.Widget _buildFormLine(
      String label,
      String value,
      pw.Font labelFont,
      pw.Font valueFont,
      ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 0.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              font: labelFont,
              fontSize: 8.5,
              color: PdfColors.black,
            ),
          ),
          pw.SizedBox(width: 4),
          pw.Expanded(
            child: pw.Container(
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.black, width: 0.65),
                ),
              ),
              padding: const pw.EdgeInsets.only(bottom: 0.5),
              child: pw.Text(
                value,
                style: pw.TextStyle(
                  font: valueFont,
                  fontSize: 8.2,
                  color: PdfColors.black,
                ),
                maxLines: 1,
                overflow: pw.TextOverflow.clip,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds an underlined line containing text for remarks
  static pw.Widget _buildUnderlinedTextLine(String text, pw.Font font) {
    return pw.Container(
      width: double.infinity,
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.black, width: 0.65),
        ),
      ),
      padding: const pw.EdgeInsets.only(bottom: 0.5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: 7.8,
          color: PdfColors.black,
        ),
        maxLines: 1,
        overflow: pw.TextOverflow.clip,
      ),
    );
  }

  /// Builds a blank underline matching the notebook-style underlines in the image
  static pw.Widget _buildEmptyUnderline() {
    return pw.Container(
      height: 7.8,
      width: double.infinity,
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.black, width: 0.65),
        ),
      ),
    );
  }

  // ===========================================================================
  // 2. Comprehensive 13-Column Tabular Ledger Report (A4 Landscape)
  // ===========================================================================

  /// Generates the canonical 13-column table report on standard A4 Landscape.
  static Future<Uint8List> generateTableReportPdf(
      List<AssetModel> assets, {
        String? dateRangeLabel,
        String? sectionLabel,
      }) async {
    final pageFormat = PdfPageFormat.a4.landscape;

    // Use fast cached fonts
    final fonts = await _loadFontsConcurrently();
    final fontRegular = fonts[0];
    final fontBold = fonts[1];

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
    );

    // Calculate valuation totals
    final int totalUnits = assets.fold<int>(0, (sum, a) => sum + a.quantity);
    final double grandTotalCost =
    assets.fold<double>(0.0, (sum, a) => sum + a.totalCost);

    const int rowsPerPage = 12;
    for (int i = 0; i < assets.length; i += rowsPerPage) {
      final pageAssets = assets.sublist(
        i,
        (i + rowsPerPage > assets.length) ? assets.length : i + rowsPerPage,
      );
      final isLastPage = (i + rowsPerPage) >= assets.length;

      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.symmetric(
            horizontal: 8.0 * PdfPageFormat.mm,
            vertical: 8.0 * PdfPageFormat.mm,
          ),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Report Header
                _buildReportHeader(
                  title: 'PARISH PROPERTY & INVENTORY LISTING',
                  dateRangeLabel: dateRangeLabel,
                  sectionLabel: sectionLabel,
                  fontRegular: fontRegular,
                  fontBold: fontBold,
                  isLandscape: true,
                ),
                pw.SizedBox(height: 5),

                // Table Header + Rows (13 Columns)
                pw.Expanded(
                  child: pw.Table(
                    border: pw.TableBorder.all(
                      color: borderGrey,
                      width: 0.5,
                    ),
                    columnWidths: const {
                      0: pw.FlexColumnWidth(2.0), // Control Number
                      1: pw.FlexColumnWidth(2.6), // Item / Particulars
                      2: pw.FlexColumnWidth(1.8), // Location
                      3: pw.FlexColumnWidth(1.5), // Date of Inventory
                      4: pw.FlexColumnWidth(1.4), // Date Acquired
                      5: pw.FlexColumnWidth(1.5), // Mode of Acq
                      6: pw.FlexColumnWidth(0.8), // Quantity
                      7: pw.FlexColumnWidth(2.1), // Amount
                      8: pw.FlexColumnWidth(1.4), // Dimensions
                      9: pw.FlexColumnWidth(1.1), // Color
                      10: pw.FlexColumnWidth(1.5), // Model
                      11: pw.FlexColumnWidth(1.8), // Details / Markings
                      12: pw.FlexColumnWidth(2.2), // Remarks / Status
                    },
                    children: [
                      // Header Row
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: marianBlue),
                        children: [
                          _buildTableHeaderCell('Control No.', fontBold),
                          _buildTableHeaderCell('Item / Particulars', fontBold),
                          _buildTableHeaderCell('Location', fontBold),
                          _buildTableHeaderCell('Date of Inv.', fontBold),
                          _buildTableHeaderCell('Date Acquired', fontBold),
                          _buildTableHeaderCell('Mode of Acq.', fontBold),
                          _buildTableHeaderCell('Qty', fontBold),
                          _buildTableHeaderCell('Amount (P)', fontBold),
                          _buildTableHeaderCell('Dimensions', fontBold),
                          _buildTableHeaderCell('Color', fontBold),
                          _buildTableHeaderCell('Model', fontBold),
                          _buildTableHeaderCell('Details / Markings', fontBold),
                          _buildTableHeaderCell('Remarks / Status', fontBold),
                        ],
                      ),

                      // Data Rows
                      ...pageAssets.map((asset) {
                        final inventoryDateStr = asset.lastAuditedAt != null
                            ? asset.formattedLastAuditedDate
                            : asset.formattedRegistrationDate;

                        return pw.TableRow(
                          decoration: pw.BoxDecoration(
                            color: pageAssets.indexOf(asset) % 2 == 0
                                ? PdfColors.white
                                : lightCardBg,
                          ),
                          children: [
                            _buildTableCell(
                              asset.controlNumber,
                              fontBold,
                              textColor: marianBlue,
                            ),
                            _buildTableCell(asset.itemName, fontBold),
                            _buildTableCell(
                              asset.displayLocation,
                              fontRegular,
                            ),
                            _buildTableCell(
                              inventoryDateStr,
                              fontRegular,
                            ),
                            _buildTableCell(
                              asset.formattedAcquisitionDate,
                              fontRegular,
                            ),
                            _buildTableCell(
                              asset.modeOfAcquisition,
                              fontRegular,
                            ),
                            _buildTableCell(
                              '${asset.quantity}',
                              fontBold,
                              align: pw.TextAlign.center,
                            ),
                            _buildTableCell(
                              'Unit: P${AssetModel.formatCurrency(asset.unitPrice)}\nTotal: P${AssetModel.formatCurrency(asset.totalCost)}',
                              fontRegular,
                            ),
                            _buildTableCell(
                              asset.dimensions ?? '—',
                              fontRegular,
                            ),
                            _buildTableCell(
                              asset.color ?? '—',
                              fontRegular,
                            ),
                            _buildTableCell(
                              asset.model ?? '—',
                              fontRegular,
                            ),
                            _buildTableCell(
                              asset.others ?? '—',
                              fontRegular,
                            ),
                            _buildTableCell(
                              '${asset.conditionStatus.toUpperCase()} • ${asset.operationalStatus}\n${asset.remarks ?? ""}'
                                  .trim(),
                              fontRegular,
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),

                // Grand Totals & Signatories block on final page
                if (isLastPage) ...[
                  pw.SizedBox(height: 5),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3.5,
                    ),
                    decoration: pw.BoxDecoration(
                      color: lightCardBg,
                      border: pw.Border.all(color: borderGrey, width: 0.5),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'TOTAL COUNT: ${assets.length} Item Line(s) • TOTAL QUANTITY: $totalUnits Unit(s)',
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 8.5,
                            color: marianBlue,
                          ),
                        ),
                        pw.Text(
                          'VALUATION GRAND TOTAL: P ${AssetModel.formatCurrency(grandTotalCost)}',
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 9.5,
                            color: PdfColors.green800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  _buildSignaturesBlock(fontRegular, fontBold),
                ],

                // Footer
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'St. John Paul II Parish • Generated on ${DateTime.now().toLocal().toString().substring(0, 16)}',
                      style: pw.TextStyle(
                        font: fontRegular,
                        fontSize: 7.2,
                        color: textMuted,
                      ),
                    ),
                    pw.Text(
                      'Page ${context.pageNumber} of ${context.pagesCount}',
                      style: pw.TextStyle(
                        font: fontRegular,
                        fontSize: 7.2,
                        color: textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  // ===========================================================================
  // Shared Header & Cell Helpers
  // ===========================================================================

  static pw.Widget _buildReportHeader({
    required String title,
    String? dateRangeLabel,
    String? sectionLabel,
    required pw.Font fontRegular,
    required pw.Font fontBold,
    bool isLandscape = false,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: goldAccent, width: 1.2),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'DIOCESE OF SAN PABLO • ST. JOHN PAUL II PARISH',
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: isLandscape ? 11 : 9.5,
                  color: marianNavy,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 1),
              pw.Text(
                title,
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: isLandscape ? 9.5 : 8.5,
                  color: marianBlue,
                ),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              if (sectionLabel != null && sectionLabel.isNotEmpty)
                pw.Text(
                  'Scope: $sectionLabel',
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 7.5,
                    color: PdfColors.black,
                  ),
                ),
              if (dateRangeLabel != null && dateRangeLabel.isNotEmpty)
                pw.Text(
                  'Range: $dateRangeLabel',
                  style: pw.TextStyle(
                    font: fontRegular,
                    fontSize: 7.5,
                    color: textMuted,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTableHeaderCell(String text, pw.Font fontBold) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 2.5, vertical: 3.5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: fontBold,
          fontSize: 6.8,
          color: PdfColors.white,
          fontWeight: pw.FontWeight.bold,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _buildTableCell(
      String text,
      pw.Font font, {
        PdfColor textColor = PdfColors.black,
        pw.TextAlign align = pw.TextAlign.left,
      }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 2.5, vertical: 2.5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: 6.5,
          color: textColor,
        ),
        textAlign: align,
      ),
    );
  }

  static pw.Widget _buildSignaturesBlock(
      pw.Font fontRegular, pw.Font fontBold) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Container(
                width: 140,
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.black, width: 0.8),
                  ),
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Parish Secretary',
                style: pw.TextStyle(font: fontRegular, fontSize: 7.5),
              ),
            ],
          ),
        ),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Container(
                width: 140,
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.black, width: 0.8),
                  ),
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Parish Priest',
                style: pw.TextStyle(font: fontBold, fontSize: 7.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // Interactive Printing Triggers
  // ===========================================================================

  static Future<void> printPhotographicReport(
      List<AssetModel> assets, {
        String? dateRangeLabel,
        String? sectionLabel,
      }) async {
    final pdfBytes = await generatePhotographicReportPdf(
      assets,
      dateRangeLabel: dateRangeLabel,
      sectionLabel: sectionLabel,
    );
    await Printing.layoutPdf(
      onLayout: (format) async => pdfBytes,
      name:
      'Photographic_Inventory_Report_${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  static Future<void> printTableReport(
      List<AssetModel> assets, {
        String? dateRangeLabel,
        String? sectionLabel,
      }) async {
    final pdfBytes = await generateTableReportPdf(
      assets,
      dateRangeLabel: dateRangeLabel,
      sectionLabel: sectionLabel,
    );
    await Printing.layoutPdf(
      onLayout: (format) async => pdfBytes,
      name: 'Inventory_Ledger_Table_${DateTime.now().millisecondsSinceEpoch}',
    );
  }
}