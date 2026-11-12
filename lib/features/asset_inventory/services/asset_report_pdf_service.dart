// =============================================================================
// FILE: lib/features/asset_inventory/services/asset_report_pdf_service.dart
// =============================================================================

import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/asset_model.dart';

// =============================================================================
// REPORT PROGRESS MONITORING
// =============================================================================

enum AssetReportProgressStage {
  preparing,
  downloadingImages,
  optimizingImages,
  generatingPdf,
  completed,
}

class AssetReportProgress {
  final AssetReportProgressStage stage;
  final int completed;
  final int total;
  final int failed;
  final int currentPage;
  final int totalPages;

  const AssetReportProgress({
    required this.stage,
    this.completed = 0,
    this.total = 0,
    this.failed = 0,
    this.currentPage = 0,
    this.totalPages = 0,
  });

  double get percentage {
    if (total <= 0) return 0;
    return (completed / total).clamp(0.0, 1.0);
  }

  String get stageLabel {
    switch (stage) {
      case AssetReportProgressStage.preparing:
        return 'Preparing report...';
      case AssetReportProgressStage.downloadingImages:
        return 'Downloading asset photographs...';
      case AssetReportProgressStage.optimizingImages:
        return 'Optimizing asset photographs...';
      case AssetReportProgressStage.generatingPdf:
        return 'Generating PDF document...';
      case AssetReportProgressStage.completed:
        return 'Report generation completed';
    }
  }
}

typedef AssetReportProgressCallback = void Function(
    AssetReportProgress progress,
    );

// =============================================================================
// PDF SERVICE
// =============================================================================

class AssetReportPdfService {
  AssetReportPdfService._();

  static const PdfColor marianBlue = PdfColor.fromInt(0xFF164E87);
  static const PdfColor marianNavy = PdfColor.fromInt(0xFF0F2942);
  static const PdfColor goldAccent = PdfColor.fromInt(0xFFD49B18);
  static const PdfColor textDark = PdfColors.black;
  static const PdfColor textMuted = PdfColor.fromInt(0xFF475569);
  static const PdfColor borderGrey = PdfColor.fromInt(0xFF94A3B8);
  static const PdfColor lightCardBg = PdfColor.fromInt(0xFFF8FAFC);

  static const double cardHeight = 352.0;

  // ---------------------------------------------------------------------------
  // PERFORMANCE CONFIGURATION
  // ---------------------------------------------------------------------------

  static const int maxImageDimension = 460;
  static const int maxConcurrentDownloads = 4;
  static const int maxConcurrentDownloadsWeb = 4;
  static const int maxConcurrentDownloadsDesktop = 6;
  static const int maxConcurrentDownloadsMobile = 3;
  static const int maxImageCacheBytes = 50 * 1024 * 1024;
  static const Duration imageDownloadTimeout = Duration(seconds: 12);
  static const Duration imageConnectionTimeout = Duration(seconds: 6);

  // ---------------------------------------------------------------------------
  // CACHED RESOURCES
  // ---------------------------------------------------------------------------

  static pw.Font? _cachedFontRegular;
  static pw.Font? _cachedFontBold;
  static pw.Font? _cachedFontItalic;
  static pw.Font? _cachedFontBoldItalic;

  // LRU image cache.
  static final LinkedHashMap<String, Uint8List> _globalImageCache =
  LinkedHashMap<String, Uint8List>();

  static int _currentImageCacheBytes = 0;

  // Prevents multiple simultaneous downloads of the same URL.
  static final Map<String, Future<Uint8List?>> _inFlightImages = {};

  // Reusable HTTP client.
  static final http.Client _httpClient = http.Client();

  // ---------------------------------------------------------------------------
  // PROGRESS HELPERS
  // ---------------------------------------------------------------------------

  static void _notify(
      AssetReportProgressCallback? callback, {
        required AssetReportProgressStage stage,
        int completed = 0,
        int total = 0,
        int failed = 0,
        int currentPage = 0,
        int totalPages = 0,
      }) {
    callback?.call(
      AssetReportProgress(
        stage: stage,
        completed: completed,
        total: total,
        failed: failed,
        currentPage: currentPage,
        totalPages: totalPages,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FONT LOADING
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // PLATFORM CONCURRENCY
  // ---------------------------------------------------------------------------

  static int _getDownloadConcurrency() {
    if (kIsWeb) return maxConcurrentDownloadsWeb;

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return maxConcurrentDownloadsMobile;

      case TargetPlatform.windows:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
        return maxConcurrentDownloadsDesktop;

      default:
        return maxConcurrentDownloads;
    }
  }

  // ---------------------------------------------------------------------------
  // LRU IMAGE CACHE
  // ---------------------------------------------------------------------------

  static Uint8List? _getCachedImage(String url) {
    final image = _globalImageCache.remove(url);
    if (image == null) return null;

    // Reinsert to mark as recently used.
    _globalImageCache[url] = image;
    return image;
  }

  static void _cacheImage(String url, Uint8List bytes) {
    final previous = _globalImageCache.remove(url);
    if (previous != null) {
      _currentImageCacheBytes -= previous.lengthInBytes;
    }

    if (bytes.lengthInBytes > maxImageCacheBytes) return;

    // Remove least recently used entries when memory limit is reached.
    while (_currentImageCacheBytes + bytes.lengthInBytes > maxImageCacheBytes) {
      if (_globalImageCache.isEmpty) break;

      final oldestKey = _globalImageCache.keys.first;
      final removed = _globalImageCache.remove(oldestKey);

      if (removed != null) {
        _currentImageCacheBytes -= removed.lengthInBytes;
      }
    }

    _globalImageCache[url] = bytes;
    _currentImageCacheBytes += bytes.lengthInBytes;
  }

  // ---------------------------------------------------------------------------
  // IMAGE OPTIMIZATION
  // ---------------------------------------------------------------------------

  /// Decodes and downsamples images while preserving their aspect ratio.
  /// Bypasses ImageDescriptor for full cross-platform compatibility.
  static Future<Uint8List> _optimizeImageForPdf(
      Uint8List rawBytes, {
        int maxDimension = maxImageDimension,
      }) async {
    ui.Codec? codec;
    ui.Image? image;

    try {
      codec = await ui.instantiateImageCodec(
        rawBytes,
        targetWidth: maxDimension,
        allowUpscaling: false,
      );

      final frameInfo = await codec.getNextFrame();
      image = frameInfo.image;

      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData != null) {
        return byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        );
      }
    } catch (e) {
      debugPrint('Asset PDF image optimization failed: $e');
    } finally {
      image?.dispose();
      codec?.dispose();
    }

    return rawBytes;
  }

  // ---------------------------------------------------------------------------
  // IMAGE DOWNLOADING
  // ---------------------------------------------------------------------------

  static Future<Uint8List?> _downloadImage(String url) async {
    try {
      if (url.startsWith('data:image')) {
        final commaIndex = url.indexOf(',');
        if (commaIndex == -1) return null;
        return base64Decode(url.substring(commaIndex + 1));
      }

      final uri = Uri.tryParse(url);
      if (uri == null || !uri.hasScheme) return null;

      final response = await _httpClient
          .get(uri)
          .timeout(imageDownloadTimeout);

      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        debugPrint('Asset PDF image request failed: ${response.statusCode}');
        return null;
      }

      return response.bodyBytes;
    } catch (e) {
      debugPrint('Asset PDF image download failed: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // DEDUPLICATED IMAGE PROCESSING
  // ---------------------------------------------------------------------------

  static Future<Uint8List?> _getOrProcessImage(String url) async {
    final cached = _getCachedImage(url);
    if (cached != null) return cached;

    final existing = _inFlightImages[url];
    if (existing != null) {
      return existing;
    }

    final future = _processImage(url);
    _inFlightImages[url] = future;

    try {
      return await future;
    } finally {
      _inFlightImages.remove(url);
    }
  }

  static Future<Uint8List?> _processImage(String url) async {
    try {
      final rawBytes = await _downloadImage(url);
      if (rawBytes == null || rawBytes.isEmpty) return null;

      final optimized = await _optimizeImageForPdf(rawBytes);
      _cacheImage(url, optimized);
      return optimized;
    } catch (e) {
      debugPrint('Asset PDF image processing error: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // BOUNDED CONCURRENT IMAGE PRELOADING
  // ---------------------------------------------------------------------------

  static Future<Map<String, Uint8List?>> _preloadAndOptimizePhotos(
      List<AssetModel> assets, {
        AssetReportProgressCallback? onProgress,
      }) async {
    final Map<String, Uint8List?> cache = {};

    final targets = assets
        .where(
          (asset) =>
      asset.photoUrl != null &&
          asset.photoUrl!.trim().isNotEmpty,
    )
        .toList();

    if (targets.isEmpty) {
      _notify(
        onProgress,
        stage: AssetReportProgressStage.optimizingImages,
        completed: 0,
        total: 0,
      );
      return cache;
    }

    final int concurrency = _getDownloadConcurrency();

    int nextIndex = 0;
    int completed = 0;
    int failed = 0;

    Future<void> worker() async {
      while (true) {
        if (nextIndex >= targets.length) return;

        final index = nextIndex++;
        final asset = targets[index];
        final url = asset.photoUrl!.trim();

        try {
          final cachedImage = _getCachedImage(url);

          Uint8List? imageBytes;

          if (cachedImage != null) {
            imageBytes = cachedImage;
          } else {
            _notify(
              onProgress,
              stage: AssetReportProgressStage.downloadingImages,
              completed: completed,
              total: targets.length,
              failed: failed,
            );

            imageBytes = await _getOrProcessImage(url);
          }

          if (imageBytes != null) {
            cache[asset.assetId] = imageBytes;
          } else {
            cache[asset.assetId] = null;
            failed++;
          }
        } catch (e) {
          cache[asset.assetId] = null;
          failed++;
          debugPrint('Failed processing asset ${asset.assetId}: $e');
        } finally {
          completed++;
          _notify(
            onProgress,
            stage: AssetReportProgressStage.optimizingImages,
            completed: completed,
            total: targets.length,
            failed: failed,
          );
        }
      }
    }

    await Future.wait(
      List.generate(
        concurrency.clamp(1, targets.length),
            (_) => worker(),
      ),
    );

    return cache;
  }

  // ===========================================================================
  // CONTROL NUMBER NUMERICAL SORTING
  // ===========================================================================

  static int _extractEndingSequence(String controlNumber) {
    if (controlNumber.isEmpty) return 0;

    final clean = controlNumber.trim();
    final base = clean.contains('/')
        ? clean.split('/').first.trim()
        : clean;

    final lastDash = base.lastIndexOf('-');

    if (lastDash != -1 && lastDash < base.length - 1) {
      final suffix = base.substring(lastDash + 1).trim();
      final directParsed = int.tryParse(suffix);

      if (directParsed != null) return directParsed;

      final match = RegExp(r'\d+').firstMatch(suffix);
      if (match != null) {
        final parsed = int.tryParse(match.group(0)!);
        if (parsed != null) return parsed;
      }
    }

    final allMatches = RegExp(r'\d+').allMatches(base);
    if (allMatches.isNotEmpty) {
      return int.tryParse(allMatches.last.group(0)!) ?? 0;
    }

    return 0;
  }

  static int _compareByEndingSequence(
      AssetModel a,
      AssetModel b,
      ) {
    final numA = _extractEndingSequence(a.controlNumber);
    final numB = _extractEndingSequence(b.controlNumber);

    final comp = numA.compareTo(numB);
    if (comp != 0) return comp;

    return a.controlNumber.compareTo(b.controlNumber);
  }

  // ===========================================================================
  // MULTI-LINE TEXT WRAPPER FOR RULED NOTEBOOK LINES
  // ===========================================================================

  /// Splits long text across lined spaces so text never clips on line 1,
  /// continuing seamlessly onto line 2, line 3, etc.
  static List<String> _wrapTextToLines(
      String text, {
        required int firstLineLimit,
        required int otherLinesLimit,
        required int maxLines,
      }) {
    if (text.trim().isEmpty) return [];

    final List<String> lines = [];
    final paragraphs = text.trim().split('\n');
    int limit = firstLineLimit;

    for (final paragraph in paragraphs) {
      if (lines.length >= maxLines) break;
      final clean = paragraph.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (clean.isEmpty) continue;

      final words = clean.split(' ');
      String currentLine = '';

      for (final word in words) {
        if (lines.length >= maxLines) break;
        final test = currentLine.isEmpty ? word : '$currentLine $word';

        if (test.length <= limit) {
          currentLine = test;
        } else {
          if (currentLine.isNotEmpty) {
            lines.add(currentLine);
            if (lines.length >= maxLines) {
              currentLine = '';
              break;
            }
            limit = otherLinesLimit;
          }

          if (word.length > limit) {
            String remaining = word;
            while (remaining.length > limit && lines.length < maxLines - 1) {
              lines.add(remaining.substring(0, limit));
              remaining = remaining.substring(limit);
              limit = otherLinesLimit;
            }
            currentLine = remaining;
          } else {
            currentLine = word;
          }
        }
      }

      if (currentLine.isNotEmpty && lines.length < maxLines) {
        lines.add(currentLine);
        limit = otherLinesLimit;
      }
    }

    return lines;
  }

  // ===========================================================================
  // 1. PHOTOGRAPHIC INVENTORY CARDS REPORT
  // ===========================================================================

  static Future<Uint8List> generatePhotographicReportPdf(
      List<AssetModel> assets, {
        String? dateRangeLabel,
        String? sectionLabel,
        AssetReportProgressCallback? onProgress,
      }) async {
    const pageFormat = PdfPageFormat.a4;

    final sortedAssets = List<AssetModel>.from(assets)
      ..sort(_compareByEndingSequence);

    _notify(
      onProgress,
      stage: AssetReportProgressStage.preparing,
      completed: 0,
      total: sortedAssets.length,
    );

    final results = await Future.wait([
      _loadFontsConcurrently(),
      _preloadAndOptimizePhotos(
        sortedAssets,
        onProgress: onProgress,
      ),
    ]);

    final fonts = results[0] as List<pw.Font>;
    final fontRegular = fonts[0];
    final fontBold = fonts[1];
    final fontItalic = fonts[2];
    final fontBoldItalic = fonts[3];

    final photoCache = results[1] as Map<String, Uint8List?>;

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: fontRegular,
        bold: fontBold,
        italic: fontItalic,
        boldItalic: fontBoldItalic,
      ),
    );

    const int itemsPerPage = 2;
    final int totalPages = (sortedAssets.length / itemsPerPage).ceil();

    for (int i = 0; i < sortedAssets.length; i += itemsPerPage) {
      final pageAssets = sortedAssets.sublist(
        i,
        (i + itemsPerPage > sortedAssets.length)
            ? sortedAssets.length
            : i + itemsPerPage,
      );

      final int currentPage = (i ~/ itemsPerPage) + 1;

      _notify(
        onProgress,
        stage: AssetReportProgressStage.generatingPdf,
        completed: currentPage,
        total: totalPages,
        currentPage: currentPage,
        totalPages: totalPages,
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
                _buildReportHeader(
                  title:
                  'PARISH BOOK OF INVENTORY — PHOTOGRAPHIC INVENTORY',
                  dateRangeLabel: dateRangeLabel,
                  sectionLabel: sectionLabel,
                  fontRegular: fontRegular,
                  fontBold: fontBold,
                ),
                pw.SizedBox(height: 5),
                ...pageAssets.map((asset) {
                  final imageBytes = photoCache[asset.assetId];
                  final isLastOnPage =
                      pageAssets.indexOf(asset) ==
                          pageAssets.length - 1;

                  return pw.Padding(
                    padding: pw.EdgeInsets.only(
                      bottom: isLastOnPage ? 0 : 16,
                    ),
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

    final bytes = await pdf.save();

    _notify(
      onProgress,
      stage: AssetReportProgressStage.completed,
      completed: totalPages,
      total: totalPages,
      currentPage: totalPages,
      totalPages: totalPages,
    );

    return bytes;
  }

  // ===========================================================================
  // PHOTOGRAPHIC CARD BUILDER
  // ===========================================================================

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

    final String formattedTotalOnly =
        'P${AssetModel.formatCurrency(asset.totalCost)}';

    final String formattedCostOfAcquisition = asset.quantity > 1
        ? '$formattedTotalOnly (P${AssetModel.formatCurrency(asset.unitPrice)} per unit)'
        : formattedTotalOnly;

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
        border: pw.Border.all(
          color: PdfColors.black,
          width: 0.8,
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // Left side: Item Photograph (vertically & horizontally centered)
          pw.Expanded(
            flex: 10,
            child: pw.Container(
              alignment: pw.Alignment.center,
              padding: const pw.EdgeInsets.all(6),
              color: PdfColors.grey100,
              child: imageBytes != null
                  ? pw.Center(
                child: pw.Image(
                  pw.MemoryImage(imageBytes),
                  fit: pw.BoxFit.contain,
                  alignment: pw.Alignment.center,
                ),
              )
                  : pw.Center(
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
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
          // Right side: Boxed Form with unbroken lined entries
          pw.Expanded(
            flex: 12,
            child: pw.Container(
              margin: const pw.EdgeInsets.all(4),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(
                  color: PdfColors.black,
                  width: 0.8,
                ),
              ),
              padding: const pw.EdgeInsets.fromLTRB(8, 6, 8, 4),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
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
                                  color: PdfColors.black,
                                  width: 0.8,
                                ),
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
                                  color: PdfColors.black,
                                  width: 0.8,
                                ),
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
                        // Multi-line continuation for Others (fills all 3 lines without clipping)
                        ..._buildOthersBlock(
                          asset.others ?? '',
                          fontItalic,
                          fontBold,
                        ),
                      ],
                    ),
                  ),
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
                        // Multi-line continuation for Remarks (fills up to 5 lines)
                        ..._buildRemarksBlock(
                          fullRemarksText,
                          fontBold,
                        ),
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

  // ===========================================================================
  // MULTI-LINE SECTIONS FOR OTHERS AND REMARKS
  // ===========================================================================

  /// Renders exactly 3 full-width ruled lines for "Others:".
  /// If the text is long, it wraps naturally onto lines 2 and 3 instead of cutting off.
  static List<pw.Widget> _buildOthersBlock(
      String othersText,
      pw.Font labelFont,
      pw.Font valueFont,
      ) {
    final lines = _wrapTextToLines(
      othersText,
      firstLineLimit: 52,
      otherLinesLimit: 64,
      maxLines: 3,
    );

    final line1Text = lines.isNotEmpty ? lines[0] : '';
    final line2Text = lines.length > 1 ? lines[1] : '';
    final line3Text = lines.length > 2 ? lines[2] : '';

    return [
      _buildFormLine('Others:', line1Text, labelFont, valueFont),
      line2Text.isNotEmpty
          ? _buildUnderlinedTextLine(line2Text, valueFont)
          : _buildEmptyUnderline(),
      line3Text.isNotEmpty
          ? _buildUnderlinedTextLine(line3Text, valueFont)
          : _buildEmptyUnderline(),
    ];
  }

  /// Renders exactly 5 full-width ruled lines for "Remarks:".
  /// Text continues onto lines 2, 3, 4, 5 without being clipped.
  static List<pw.Widget> _buildRemarksBlock(
      String remarksText,
      pw.Font valueFont,
      ) {
    final lines = _wrapTextToLines(
      remarksText,
      firstLineLimit: 64,
      otherLinesLimit: 64,
      maxLines: 5,
    );

    return [
      for (int i = 0; i < 5; i++)
        if (i < lines.length && lines[i].isNotEmpty)
          _buildUnderlinedTextLine(lines[i], valueFont)
        else
          _buildEmptyUnderline(),
    ];
  }

  // ===========================================================================
  // PHOTOGRAPHIC CARD HELPERS
  // ===========================================================================

  static pw.Widget _buildFormLine(
      String label,
      String value,
      pw.Font labelFont,
      pw.Font valueFont,
      ) {
    final double valueFontSize = value.length > 36 ? 7.4 : 8.2;

    return pw.Container(
      height: 11.0,
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
                  bottom: pw.BorderSide(
                    color: PdfColors.black,
                    width: 0.65,
                  ),
                ),
              ),
              padding: const pw.EdgeInsets.only(bottom: 0.5),
              child: pw.Text(
                value,
                style: pw.TextStyle(
                  font: valueFont,
                  fontSize: valueFontSize,
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

  static pw.Widget _buildUnderlinedTextLine(
      String text,
      pw.Font font, {
        double fontSize = 8.2,
      }) {
    return pw.Container(
      height: 10.5,
      width: double.infinity,
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(
            color: PdfColors.black,
            width: 0.65,
          ),
        ),
      ),
      padding: const pw.EdgeInsets.only(bottom: 0.5),
      alignment: pw.Alignment.bottomLeft,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: fontSize,
          color: PdfColors.black,
        ),
        maxLines: 1,
        overflow: pw.TextOverflow.clip,
      ),
    );
  }

  static pw.Widget _buildEmptyUnderline() {
    return pw.Container(
      height: 10.5,
      width: double.infinity,
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(
            color: PdfColors.black,
            width: 0.65,
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 2. COMPREHENSIVE TABULAR LEDGER REPORT
  // ===========================================================================

  static Future<Uint8List> generateTableReportPdf(
      List<AssetModel> assets, {
        String? dateRangeLabel,
        String? sectionLabel,
        AssetReportProgressCallback? onProgress,
      }) async {
    final pageFormat = PdfPageFormat.a4.landscape;

    final sortedAssets = List<AssetModel>.from(assets)
      ..sort(_compareByEndingSequence);

    _notify(
      onProgress,
      stage: AssetReportProgressStage.preparing,
      completed: 0,
      total: sortedAssets.length,
    );

    final fonts = await _loadFontsConcurrently();
    final fontRegular = fonts[0];
    final fontBold = fonts[1];

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: fontRegular,
        bold: fontBold,
      ),
    );

    final int totalUnits =
    sortedAssets.fold<int>(0, (sum, a) => sum + a.quantity);

    final double grandTotalCost =
    sortedAssets.fold<double>(0.0, (sum, a) => sum + a.totalCost);

    const int rowsPerPage = 20;

    final int totalPages =
    (sortedAssets.length / rowsPerPage).ceil();

    for (int i = 0; i < sortedAssets.length; i += rowsPerPage) {
      final pageAssets = sortedAssets.sublist(
        i,
        (i + rowsPerPage > sortedAssets.length)
            ? sortedAssets.length
            : i + rowsPerPage,
      );

      final isLastPage = (i + rowsPerPage) >= sortedAssets.length;
      final int currentPage = (i ~/ rowsPerPage) + 1;

      _notify(
        onProgress,
        stage: AssetReportProgressStage.generatingPdf,
        completed: currentPage,
        total: totalPages,
        currentPage: currentPage,
        totalPages: totalPages,
      );

      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.symmetric(
            horizontal: 7.0 * PdfPageFormat.mm,
            vertical: 5.0 * PdfPageFormat.mm,
          ),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildReportHeader(
                  title: 'PARISH PROPERTY & INVENTORY LISTING',
                  dateRangeLabel: dateRangeLabel,
                  sectionLabel: sectionLabel,
                  fontRegular: fontRegular,
                  fontBold: fontBold,
                  isLandscape: true,
                ),
                pw.SizedBox(height: 3.5),
                pw.Expanded(
                  child: pw.Table(
                    border: pw.TableBorder.all(
                      color: borderGrey,
                      width: 0.5,
                    ),
                    columnWidths: const {
                      0: pw.FlexColumnWidth(2.1),
                      1: pw.FlexColumnWidth(2.7),
                      2: pw.FlexColumnWidth(1.8),
                      3: pw.FlexColumnWidth(1.4),
                      4: pw.FlexColumnWidth(1.4),
                      5: pw.FlexColumnWidth(1.4),
                      6: pw.FlexColumnWidth(0.7),
                      7: pw.FlexColumnWidth(2.2),
                      8: pw.FlexColumnWidth(1.3),
                      9: pw.FlexColumnWidth(1.0),
                      10: pw.FlexColumnWidth(1.3),
                      11: pw.FlexColumnWidth(1.7),
                      12: pw.FlexColumnWidth(2.7),
                    },
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(
                          color: marianBlue,
                        ),
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
                      ...pageAssets.map((asset) {
                        final inventoryDateStr =
                        asset.lastAuditedAt != null
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
                if (isLastPage) ...[
                  pw.SizedBox(height: 3.5),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3.0,
                    ),
                    decoration: pw.BoxDecoration(
                      color: lightCardBg,
                      border: pw.Border.all(
                        color: borderGrey,
                        width: 0.5,
                      ),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'TOTAL COUNT: ${sortedAssets.length} Item Line(s) • TOTAL QUANTITY: $totalUnits Unit(s)',
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 8.8,
                            color: marianBlue,
                          ),
                        ),
                        pw.Text(
                          'VALUATION GRAND TOTAL: P ${AssetModel.formatCurrency(grandTotalCost)}',
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 9.8,
                            color: PdfColors.green800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                pw.SizedBox(height: 3),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'St. John Paul II Parish • Generated on ${DateTime.now().toLocal().toString().substring(0, 16)}',
                      style: pw.TextStyle(
                        font: fontRegular,
                        fontSize: 7.5,
                        color: textMuted,
                      ),
                    ),
                    pw.Text(
                      'Page ${context.pageNumber} of ${context.pagesCount}',
                      style: pw.TextStyle(
                        font: fontRegular,
                        fontSize: 7.5,
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

    final bytes = await pdf.save();

    _notify(
      onProgress,
      stage: AssetReportProgressStage.completed,
      completed: totalPages,
      total: totalPages,
      currentPage: totalPages,
      totalPages: totalPages,
    );

    return bytes;
  }

  // ===========================================================================
  // SHARED HEADER & CELL HELPERS
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
      padding: const pw.EdgeInsets.only(bottom: 3.5),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(
            color: goldAccent,
            width: 1.2,
          ),
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
                  fontSize: isLandscape ? 11.5 : 9.5,
                  color: marianNavy,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 1),
              pw.Text(
                title,
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: isLandscape ? 10.0 : 8.5,
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
                    fontSize: 8.0,
                    color: PdfColors.black,
                  ),
                ),
              if (dateRangeLabel != null && dateRangeLabel.isNotEmpty)
                pw.Text(
                  'Range: $dateRangeLabel',
                  style: pw.TextStyle(
                    font: fontRegular,
                    fontSize: 8.0,
                    color: textMuted,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTableHeaderCell(
      String text,
      pw.Font fontBold,
      ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(
        horizontal: 2.0,
        vertical: 3.0,
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: fontBold,
          fontSize: 7.6,
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
      padding: const pw.EdgeInsets.symmetric(
        horizontal: 2.0,
        vertical: 1.8,
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: 7.2,
          color: textColor,
        ),
        textAlign: align,
      ),
    );
  }

  // ===========================================================================
  // INTERACTIVE PRINTING TRIGGERS
  // ===========================================================================

  static Future<void> printPhotographicReport(
      List<AssetModel> assets, {
        String? dateRangeLabel,
        String? sectionLabel,
        AssetReportProgressCallback? onProgress,
      }) async {
    final pdfBytes = await generatePhotographicReportPdf(
      assets,
      dateRangeLabel: dateRangeLabel,
      sectionLabel: sectionLabel,
      onProgress: onProgress,
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
        AssetReportProgressCallback? onProgress,
      }) async {
    final pdfBytes = await generateTableReportPdf(
      assets,
      dateRangeLabel: dateRangeLabel,
      sectionLabel: sectionLabel,
      onProgress: onProgress,
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdfBytes,
      name:
      'Inventory_Ledger_Table_${DateTime.now().millisecondsSinceEpoch}',
    );
  }
}