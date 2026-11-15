// =============================================================================
// FILE: lib/features/asset_inventory/services/asset_report_pdf_service.dart
// =============================================================================

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/asset_model.dart';
import '../utils/web_camera_helper.dart';

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
  final double progress;
  final String? detailLabel;

  const AssetReportProgress({
    required this.stage,
    this.completed = 0,
    this.total = 0,
    this.failed = 0,
    this.currentPage = 0,
    this.totalPages = 0,
    this.progress = 0.0,
    this.detailLabel,
  });

  double get percentage {
    if (progress > 0.0) return progress.clamp(0.0, 1.0).toDouble();
    if (total <= 0) return 0.0;
    return (completed / total).clamp(0.0, 1.0).toDouble();
  }

  String get stageLabel {
    switch (stage) {
      case AssetReportProgressStage.preparing:
        return 'Preparing report data & fonts...';
      case AssetReportProgressStage.downloadingImages:
        return 'Downloading asset photographs...';
      case AssetReportProgressStage.optimizingImages:
        return 'Preparing photographs for PDF...';
      case AssetReportProgressStage.generatingPdf:
        return 'Compiling PDF document...';
      case AssetReportProgressStage.completed:
        return 'Report generation completed';
    }
  }
}

typedef AssetReportProgressCallback = void Function(
    AssetReportProgress progress,
    );

// =============================================================================
// PREPARED IMAGE DESCRIPTOR
// =============================================================================

class _PreparedPdfImage {
  final Uint8List bytes;
  final bool isDirectEncoded;
  final int width;
  final int height;

  const _PreparedPdfImage.direct(this.bytes)
      : isDirectEncoded = true,
        width = 0,
        height = 0;

  const _PreparedPdfImage.rgba({
    required this.bytes,
    required this.width,
    required this.height,
  }) : isDirectEncoded = false;

  int get byteSize => bytes.lengthInBytes;

  pw.ImageProvider toPdfImage() {
    if (isDirectEncoded) {
      return pw.MemoryImage(bytes);
    }
    return pw.RawImage(
      bytes: bytes,
      width: width,
      height: height,
    );
  }
}

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

  static const int maxPdfImageWidth = 360;
  static const int maxDirectJpegBytes = 180 * 1024;
  static const int maxConcurrentDownloads = 3;
  static const int maxConcurrentDownloadsWeb = 3;
  static const int maxConcurrentDownloadsDesktop = 4;
  static const int maxConcurrentDownloadsMobile = 3;
  static const int maxImageCacheBytes = 60 * 1024 * 1024;
  static const Duration imageDownloadTimeout = Duration(seconds: 25);

  // Tracks failed image count from the most recent photographic report build
  static int lastFailedPhotoCount = 0;

  // ---------------------------------------------------------------------------
  // CACHED RESOURCES
  // ---------------------------------------------------------------------------

  static pw.Font? _cachedFontRegular;
  static pw.Font? _cachedFontBold;
  static pw.Font? _cachedFontItalic;
  static pw.Font? _cachedFontBoldItalic;

  // LRU cache of already-prepared PDF image payloads.
  static final LinkedHashMap<String, _PreparedPdfImage> _globalImageCache =
  LinkedHashMap<String, _PreparedPdfImage>();

  static int _currentImageCacheBytes = 0;

  // Deduplicates concurrent downloads/preparations for identical URLs.
  static final Map<String, Future<_PreparedPdfImage?>> _inFlightImages = {};

  // Reusable HTTP client.
  static final http.Client _httpClient = http.Client();

  // ---------------------------------------------------------------------------
  // PROGRESS HELPER
  // ---------------------------------------------------------------------------

  static void _notify(
      AssetReportProgressCallback? callback, {
        required AssetReportProgressStage stage,
        required double progress,
        int completed = 0,
        int total = 0,
        int failed = 0,
        int currentPage = 0,
        int totalPages = 0,
        String? detailLabel,
      }) {
    callback?.call(
      AssetReportProgress(
        stage: stage,
        completed: completed,
        total: total,
        failed: failed,
        currentPage: currentPage,
        totalPages: totalPages,
        progress: progress.clamp(0.0, 1.0).toDouble(),
        detailLabel: detailLabel,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FONT LOADING (Cached after first call)
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

  static _PreparedPdfImage? _getCachedImage(String url) {
    final image = _globalImageCache.remove(url);
    if (image == null) return null;
    _globalImageCache[url] = image;
    return image;
  }

  static void _cacheImage(String url, _PreparedPdfImage prepared) {
    final previous = _globalImageCache.remove(url);
    if (previous != null) {
      _currentImageCacheBytes -= previous.byteSize;
    }

    if (prepared.byteSize > maxImageCacheBytes) return;

    while (_currentImageCacheBytes + prepared.byteSize > maxImageCacheBytes) {
      if (_globalImageCache.isEmpty) break;
      final oldestKey = _globalImageCache.keys.first;
      final removed = _globalImageCache.remove(oldestKey);
      if (removed != null) {
        _currentImageCacheBytes -= removed.byteSize;
      }
    }

    _globalImageCache[url] = prepared;
    _currentImageCacheBytes += prepared.byteSize;
  }

  // ---------------------------------------------------------------------------
  // IMAGE DECODING & PDF PREPARATION
  // ---------------------------------------------------------------------------

  static bool _isJpegBytes(Uint8List bytes) {
    return bytes.length > 3 && bytes[0] == 0xFF && bytes[1] == 0xD8;
  }

  static bool _isPngBytes(Uint8List bytes) {
    return bytes.length > 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47;
  }

  /// Decodes and downscales via Flutter's native codec, composites onto a white
  /// background, and exports a clean PNG for pw.MemoryImage (avoids RawImage
  /// premultiplied-alpha and /SMask quirks across PDF viewers).
  static Future<_PreparedPdfImage?> _extractPngFromCodec(
      Uint8List rawBytes, {
        int? targetWidth,
      }) async {
    ui.Codec? codec;
    ui.Image? image;
    ui.Image? renderedImage;
    try {
      codec = await ui.instantiateImageCodec(
        rawBytes,
        targetWidth: targetWidth,
        allowUpscaling: false,
      );
      final frameInfo = await codec.getNextFrame();
      image = frameInfo.image;

      int outW = image.width;
      int outH = image.height;
      final int longEdge = max(outW, outH);

      if (longEdge > maxPdfImageWidth) {
        final double scale = maxPdfImageWidth / longEdge;
        outW = max(1, (outW * scale).round());
        outH = max(1, (outH * scale).round());
      }

      // Composite onto opaque white canvas and encode as clean PNG
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(
        recorder,
        ui.Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble()),
      );
      canvas.drawRect(
        ui.Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble()),
        ui.Paint()..color = const ui.Color(0xFFFFFFFF),
      );
      canvas.drawImageRect(
        image,
        ui.Rect.fromLTWH(
          0,
          0,
          image.width.toDouble(),
          image.height.toDouble(),
        ),
        ui.Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble()),
        ui.Paint()..filterQuality = ui.FilterQuality.medium,
      );

      final picture = recorder.endRecording();
      renderedImage = await picture.toImage(outW, outH);
      try {
        picture.dispose();
      } catch (_) {}

      final pngData = await renderedImage.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (pngData != null && pngData.lengthInBytes > 0) {
        final pngBytes = pngData.buffer.asUint8List(
          pngData.offsetInBytes,
          pngData.lengthInBytes,
        );
        return _PreparedPdfImage.direct(pngBytes);
      }

      // Fallback to rawRgba if PNG byteData is unavailable
      final rawData = await renderedImage.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (rawData != null &&
          rawData.lengthInBytes == outW * outH * 4) {
        final rgbaBytes = rawData.buffer.asUint8List(
          rawData.offsetInBytes,
          rawData.lengthInBytes,
        );
        return _PreparedPdfImage.rgba(
          bytes: rgbaBytes,
          width: outW,
          height: outH,
        );
      }
    } finally {
      try {
        renderedImage?.dispose();
      } catch (_) {}
      try {
        image?.dispose();
      } catch (_) {}
      try {
        codec?.dispose();
      } catch (_) {}
    }
    return null;
  }

  static Future<_PreparedPdfImage?> _prepareImageForPdf(
      Uint8List rawBytes,
      ) async {
    if (rawBytes.isEmpty) return null;

    if (_isJpegBytes(rawBytes) && rawBytes.lengthInBytes <= maxDirectJpegBytes) {
      return _PreparedPdfImage.direct(rawBytes);
    }

    if (kIsWeb) {
      final webJpeg = await WebCameraHelper.downscaleImageToJpegForPdf(
        rawBytes,
        maxWidth: maxPdfImageWidth,
        quality: 0.82,
      );
      if (webJpeg != null && webJpeg.isNotEmpty) {
        return _PreparedPdfImage.direct(webJpeg);
      }
    }

    try {
      final result = await _extractPngFromCodec(
        rawBytes,
        targetWidth: maxPdfImageWidth,
      );
      if (result != null) return result;
    } catch (_) {
      try {
        final fallback = await _extractPngFromCodec(rawBytes);
        if (fallback != null) return fallback;
      } catch (e) {
        debugPrint('Asset PDF image preparation error: $e');
      }
    }

    if (_isJpegBytes(rawBytes) || _isPngBytes(rawBytes)) {
      return _PreparedPdfImage.direct(rawBytes);
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // IMAGE DOWNLOADING (With Web CORS Cache-Bypass & Supabase Storage Fallback)
  // ---------------------------------------------------------------------------

  static Future<Uint8List?> _downloadFromSupabaseStorage(
      String urlOrPath,
      ) async {
    try {
      final storage = Supabase.instance.client.storage;
      final trimmed = urlOrPath.trim();
      if (trimmed.isEmpty) return null;

      final uri =
          Uri.tryParse(trimmed) ?? Uri.tryParse(Uri.encodeFull(trimmed));

      if (uri != null && uri.hasScheme) {
        final segments = uri.pathSegments;
        final objIdx = segments.indexOf('object');
        if (objIdx != -1 && objIdx + 3 < segments.length) {
          final bucket = segments[objIdx + 2];
          final objectPath = Uri.decodeComponent(
            segments.sublist(objIdx + 3).join('/'),
          );
          if (bucket.isNotEmpty && objectPath.isNotEmpty) {
            final bytes = await storage
                .from(bucket)
                .download(objectPath)
                .timeout(imageDownloadTimeout);
            if (bytes.isNotEmpty) return bytes;
          }
        }
      } else {
        final cleanPath =
        trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
        final bytes = await storage
            .from('certificate-assets')
            .download(cleanPath)
            .timeout(imageDownloadTimeout);
        if (bytes.isNotEmpty) return bytes;
      }
    } catch (e) {
      debugPrint('Asset PDF Supabase storage download fallback failed: $e');
    }
    return null;
  }

  static Future<Uint8List?> _downloadImage(String url) async {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) return null;

    if (cleanUrl.startsWith('data:image')) {
      try {
        final commaIndex = cleanUrl.indexOf(',');
        if (commaIndex == -1) return null;
        return base64Decode(cleanUrl.substring(commaIndex + 1));
      } catch (_) {
        return null;
      }
    }

    Uri? uri = Uri.tryParse(cleanUrl);
    if (uri == null || !uri.hasScheme) {
      final encoded = Uri.encodeFull(cleanUrl);
      uri = Uri.tryParse(encoded);
    }

    // Relative storage path (no http/https scheme)
    if (uri == null || !uri.hasScheme) {
      return _downloadFromSupabaseStorage(cleanUrl);
    }

    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final response =
        await _httpClient.get(uri).timeout(imageDownloadTimeout);

        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          return response.bodyBytes;
        }
        debugPrint(
          'Asset PDF image request failed (${response.statusCode}): $uri',
        );
        if (attempt == 0 &&
            (response.statusCode == 429 || response.statusCode >= 500)) {
          await Future.delayed(const Duration(milliseconds: 350));
          continue;
        }
        break;
      } on TimeoutException catch (e) {
        if (attempt == 0) {
          debugPrint('Asset PDF image download timed out, retrying: $uri');
          continue;
        }
        debugPrint('Asset PDF image download timed out: $e');
      } catch (e) {
        debugPrint('Asset PDF HTTP image download error ($uri): $e');
        break;
      }
    }

    // Web fallback: bypass non-CORS <img> disk cache using Fetch cache:'reload'
    if (kIsWeb) {
      final webBytes = await WebCameraHelper.fetchImageBytes(uri.toString());
      if (webBytes != null && webBytes.isNotEmpty) {
        return webBytes;
      }
    }

    // Authenticated Supabase Storage SDK fallback
    final storageBytes = await _downloadFromSupabaseStorage(cleanUrl);
    if (storageBytes != null && storageBytes.isNotEmpty) {
      return storageBytes;
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // BOUNDED CONCURRENT IMAGE PRELOADING (Strictly Monotonic Progress)
  // ---------------------------------------------------------------------------

  static Future<Map<String, _PreparedPdfImage?>> _preloadAndPreparePhotos(
      List<AssetModel> assets, {
        AssetReportProgressCallback? onProgress,
      }) async {
    final Map<String, _PreparedPdfImage?> cache = {};
    lastFailedPhotoCount = 0;

    final targets = assets
        .where(
          (asset) =>
      asset.photoUrl != null && asset.photoUrl!.trim().isNotEmpty,
    )
        .toList();

    if (targets.isEmpty) {
      _notify(
        onProgress,
        stage: AssetReportProgressStage.optimizingImages,
        progress: 0.72,
        completed: 0,
        total: 0,
        detailLabel: 'No photographs attached — ready to build PDF',
      );
      return cache;
    }

    final int totalCount = targets.length;
    final int totalSteps = totalCount * 2;
    final int concurrency = _getDownloadConcurrency();

    int nextIndex = 0;
    int downloadedCount = 0;
    int preparedCount = 0;
    int failedCount = 0;
    double highestProgress = 0.10;

    void emitMonotonicProgress(AssetReportProgressStage stage, String detail) {
      final double fraction =
      ((downloadedCount + preparedCount) / totalSteps).clamp(0.0, 1.0);
      final double nextProgress = 0.10 + (0.62 * fraction);
      highestProgress = max(highestProgress, nextProgress);

      _notify(
        onProgress,
        stage: stage,
        progress: highestProgress,
        completed: stage == AssetReportProgressStage.downloadingImages
            ? downloadedCount
            : preparedCount,
        total: totalCount,
        failed: failedCount,
        detailLabel: detail,
      );
    }

    Future<_PreparedPdfImage?> fetchAndPrepareUrl(String url) async {
      final cached = _getCachedImage(url);
      if (cached != null) {
        downloadedCount++;
        emitMonotonicProgress(
          AssetReportProgressStage.downloadingImages,
          'Loaded $downloadedCount of $totalCount photo(s) (cached)',
        );
        preparedCount++;
        emitMonotonicProgress(
          AssetReportProgressStage.optimizingImages,
          'Prepared $preparedCount of $totalCount photo(s)',
        );
        return cached;
      }

      final existing = _inFlightImages[url];
      if (existing != null) {
        final result = await existing;
        downloadedCount++;
        preparedCount++;
        if (result == null) failedCount++;
        emitMonotonicProgress(
          AssetReportProgressStage.optimizingImages,
          'Prepared $preparedCount of $totalCount photo(s)',
        );
        return result;
      }

      final completerFuture = () async {
        final rawBytes = await _downloadImage(url);
        downloadedCount++;
        emitMonotonicProgress(
          AssetReportProgressStage.downloadingImages,
          'Downloaded $downloadedCount of $totalCount photo(s)',
        );

        if (rawBytes == null || rawBytes.isEmpty) {
          failedCount++;
          preparedCount++;
          emitMonotonicProgress(
            AssetReportProgressStage.optimizingImages,
            'Prepared $preparedCount of $totalCount photo(s)',
          );
          return null;
        }

        final prepared = await _prepareImageForPdf(rawBytes);
        if (prepared != null) {
          _cacheImage(url, prepared);
        } else {
          failedCount++;
        }

        preparedCount++;
        emitMonotonicProgress(
          AssetReportProgressStage.optimizingImages,
          'Prepared $preparedCount of $totalCount photo(s)',
        );
        return prepared;
      }();

      _inFlightImages[url] = completerFuture;
      try {
        return await completerFuture;
      } finally {
        _inFlightImages.remove(url);
      }
    }

    Future<void> worker() async {
      while (true) {
        if (nextIndex >= targets.length) return;
        final index = nextIndex++;
        final asset = targets[index];
        final url = asset.photoUrl!.trim();

        try {
          cache[asset.assetId] = await fetchAndPrepareUrl(url);
        } catch (e) {
          cache[asset.assetId] = null;
          failedCount++;
          debugPrint('Failed preparing photo for ${asset.assetId}: $e');
        }
      }
    }

    await Future.wait(
      List.generate(
        concurrency.clamp(1, targets.length),
            (_) => worker(),
      ),
    );

    lastFailedPhotoCount = failedCount;
    return cache;
  }

  // ===========================================================================
  // CONTROL NUMBER NUMERICAL SORTING
  // ===========================================================================

  static int _extractEndingSequence(String controlNumber) {
    if (controlNumber.isEmpty) return 0;

    final clean = controlNumber.trim();
    final base = clean.contains('/') ? clean.split('/').first.trim() : clean;

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
      progress: 0.03,
      completed: 0,
      total: sortedAssets.length,
      detailLabel: 'Sorting ${sortedAssets.length} item(s) & loading fonts...',
    );

    final results = await Future.wait([
      _loadFontsConcurrently(),
      _preloadAndPreparePhotos(
        sortedAssets,
        onProgress: onProgress,
      ),
    ]);

    final fonts = results[0] as List<pw.Font>;
    final fontRegular = fonts[0];
    final fontBold = fonts[1];
    final fontItalic = fonts[2];
    final fontBoldItalic = fonts[3];

    final photoCache = results[1] as Map<String, _PreparedPdfImage?>;

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: fontRegular,
        bold: fontBold,
        italic: fontItalic,
        boldItalic: fontBoldItalic,
      ),
    );

    const int itemsPerPage = 2;
    final int totalPages = max(1, (sortedAssets.length / itemsPerPage).ceil());

    for (int i = 0; i < sortedAssets.length; i += itemsPerPage) {
      final pageAssets = sortedAssets.sublist(
        i,
        (i + itemsPerPage > sortedAssets.length)
            ? sortedAssets.length
            : i + itemsPerPage,
      );

      final int currentPage = (i ~/ itemsPerPage) + 1;
      final double pageProgress = 0.72 + (0.13 * (currentPage / totalPages));

      _notify(
        onProgress,
        stage: AssetReportProgressStage.generatingPdf,
        progress: pageProgress,
        completed: currentPage,
        total: totalPages,
        currentPage: currentPage,
        totalPages: totalPages,
        detailLabel: 'Assembling page $currentPage of $totalPages...',
      );

      if (currentPage % 5 == 0) {
        await Future.delayed(Duration.zero);
      }

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
                  title: 'PARISH BOOK OF INVENTORY — PHOTOGRAPHIC INVENTORY',
                  dateRangeLabel: dateRangeLabel,
                  sectionLabel: sectionLabel,
                  fontRegular: fontRegular,
                  fontBold: fontBold,
                ),
                pw.SizedBox(height: 5),
                ...pageAssets.map((asset) {
                  final preparedImage = photoCache[asset.assetId];
                  final isLastOnPage =
                      pageAssets.indexOf(asset) == pageAssets.length - 1;

                  return pw.Padding(
                    padding: pw.EdgeInsets.only(
                      bottom: isLastOnPage ? 0 : 16,
                    ),
                    child: pw.SizedBox(
                      height: cardHeight,
                      child: _buildPhotographicCard(
                        asset,
                        preparedImage,
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

    _notify(
      onProgress,
      stage: AssetReportProgressStage.generatingPdf,
      progress: 0.88,
      completed: totalPages,
      total: totalPages,
      currentPage: totalPages,
      totalPages: totalPages,
      detailLabel: 'Writing & compressing $totalPages PDF page(s)...',
    );
    await Future.delayed(const Duration(milliseconds: 24));

    final bytes = await pdf.save();

    _notify(
      onProgress,
      stage: AssetReportProgressStage.completed,
      progress: 1.0,
      completed: totalPages,
      total: totalPages,
      currentPage: totalPages,
      totalPages: totalPages,
      detailLabel: 'PDF ready ($totalPages page(s))',
    );

    return bytes;
  }

  // ===========================================================================
  // PHOTOGRAPHIC CARD BUILDER
  // ===========================================================================

  static pw.Widget _buildPhotographicCard(
      AssetModel asset,
      _PreparedPdfImage? preparedImage,
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

    final String baseRemarks = asset.remarks != null && asset.remarks!.isNotEmpty
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
          // Left side: Item Photograph (vertically & horizontally centered in the frame)
          pw.Expanded(
            flex: 10,
            child: pw.Container(
              alignment: pw.Alignment.center,
              padding: const pw.EdgeInsets.all(6),
              color: PdfColors.grey100,
              child: preparedImage != null
                  ? pw.Center(
                child: pw.Image(
                  preparedImage.toPdfImage(),
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
      progress: 0.08,
      completed: 0,
      total: sortedAssets.length,
      detailLabel:
      'Sorting ${sortedAssets.length} ledger row(s) & loading fonts...',
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
    final int totalPages = max(1, (sortedAssets.length / rowsPerPage).ceil());

    for (int i = 0; i < sortedAssets.length; i += rowsPerPage) {
      final pageAssets = sortedAssets.sublist(
        i,
        (i + rowsPerPage > sortedAssets.length)
            ? sortedAssets.length
            : i + rowsPerPage,
      );

      final isLastPage = (i + rowsPerPage) >= sortedAssets.length;
      final int currentPage = (i ~/ rowsPerPage) + 1;
      final double pageProgress = 0.20 + (0.50 * (currentPage / totalPages));

      _notify(
        onProgress,
        stage: AssetReportProgressStage.generatingPdf,
        progress: pageProgress,
        completed: currentPage,
        total: totalPages,
        currentPage: currentPage,
        totalPages: totalPages,
        detailLabel: 'Assembling ledger page $currentPage of $totalPages...',
      );

      if (currentPage % 4 == 0) {
        await Future.delayed(Duration.zero);
      }

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

    _notify(
      onProgress,
      stage: AssetReportProgressStage.generatingPdf,
      progress: 0.78,
      completed: totalPages,
      total: totalPages,
      currentPage: totalPages,
      totalPages: totalPages,
      detailLabel: 'Writing & compressing $totalPages ledger page(s)...',
    );
    await Future.delayed(const Duration(milliseconds: 24));

    final bytes = await pdf.save();

    _notify(
      onProgress,
      stage: AssetReportProgressStage.completed,
      progress: 1.0,
      completed: totalPages,
      total: totalPages,
      currentPage: totalPages,
      totalPages: totalPages,
      detailLabel: 'PDF ready ($totalPages page(s))',
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