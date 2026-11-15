// =============================================================================
// FILE: lib/features/asset_inventory/utils/asset_image_watermark_util.dart
// =============================================================================

import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'web_camera_helper.dart';

class AssetImageWatermarkUtil {
  AssetImageWatermarkUtil._();

  /// Standard export resolution boundaries (long edge)
  static const double defaultMaxLongEdge = 1280.0;
  static const double pdfMaxLongEdge = 500.0;

  // ===========================================================================
  // 1. Fast JPG/JPEG Converter (Preserves Aspect Ratio, High Speed)
  // ===========================================================================

  /// Automatically converts any uploaded image format (PNG, WebP, HEIC/AVIF, GIF, etc.)
  /// to optimized JPG/JPEG format while strictly preserving the original aspect ratio.
  ///
  /// - Automatically composites any transparency onto pure opaque white (#FFFFFF)
  ///   so transparent PNGs don't develop dark/black borders.
  /// - Bypasses re-encoding if the source is already a clean JPEG below the max resolution.
  /// - Runs with GPU-accelerated canvas/codec scaling for maximum speed.
  static Future<Uint8List> convertToJpg(
      Uint8List rawBytes, {
        int maxDimension = 1280,
        double quality = 0.88,
      }) async {
    if (rawBytes.isEmpty) return rawBytes;

    final bool isAlreadyJpeg = rawBytes.length >= 3 &&
        rawBytes[0] == 0xFF &&
        rawBytes[1] == 0xD8 &&
        rawBytes[2] == 0xFF;

    // Fast path on Web: Native <img> + <canvas> hardware downscaling
    if (kIsWeb) {
      final webJpeg = await WebCameraHelper.downscaleImageToJpegForPdf(
        rawBytes,
        maxWidth: maxDimension,
        quality: quality,
      );
      if (webJpeg != null && webJpeg.isNotEmpty) {
        return webJpeg;
      }
    }

    try {
      final ui.Codec codec = await ui.instantiateImageCodec(rawBytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image image = frameInfo.image;

      final int origWidth = image.width;
      final int origHeight = image.height;
      final int longEdge = max(origWidth, origHeight);

      // If already a compact JPEG below maxDimension, keep it directly to avoid recompression delay
      if (isAlreadyJpeg && longEdge <= maxDimension) {
        try {
          image.dispose();
        } catch (_) {}
        try {
          codec.dispose();
        } catch (_) {}
        return rawBytes;
      }

      double targetWidth = origWidth.toDouble();
      double targetHeight = origHeight.toDouble();

      if (longEdge > maxDimension && longEdge > 0) {
        final double scale = maxDimension / longEdge;
        targetWidth = (origWidth * scale).roundToDouble();
        targetHeight = (origHeight * scale).roundToDouble();
      }

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(
        recorder,
        Rect.fromLTWH(0, 0, targetWidth, targetHeight),
      );

      // Composite onto opaque white base to prevent transparent PNGs from turning black
      canvas.drawRect(
        Rect.fromLTWH(0, 0, targetWidth, targetHeight),
        Paint()..color = const Color(0xFFFFFFFF),
      );

      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, origWidth.toDouble(), origHeight.toDouble()),
        Rect.fromLTWH(0, 0, targetWidth, targetHeight),
        Paint()..filterQuality = FilterQuality.medium,
      );

      final ui.Picture picture = recorder.endRecording();
      final ui.Image renderedImage = await picture.toImage(
        targetWidth.toInt(),
        targetHeight.toInt(),
      );

      // Encode as clean image bytes
      final ByteData? byteData = await renderedImage.toByteData(
        format: ui.ImageByteFormat.png, // PNG byteData is converted to JPEG on web or kept clean
      );

      try {
        image.dispose();
      } catch (_) {}
      try {
        renderedImage.dispose();
      } catch (_) {}
      try {
        picture.dispose();
      } catch (_) {}
      try {
        codec.dispose();
      } catch (_) {}

      if (byteData != null) {
        final converted = byteData.buffer.asUint8List();
        // If web downscaler is available, wrap into JPEG bytes
        if (kIsWeb) {
          final reJpeg = await WebCameraHelper.downscaleImageToJpegForPdf(
            converted,
            maxWidth: maxDimension,
            quality: quality,
          );
          if (reJpeg != null && reJpeg.isNotEmpty) return reJpeg;
        }
        return converted;
      }
    } catch (e) {
      debugPrint('Notice in convertToJpg: $e');
    }
    return rawBytes;
  }

  // ===========================================================================
  // 2. Hardware Image Compressor
  // ===========================================================================

  static Future<Uint8List> compressImage(
      Uint8List rawBytes, {
        int maxDimension = 1280,
      }) async {
    return convertToJpg(rawBytes, maxDimension: maxDimension);
  }

  static Future<Uint8List> compressForPdf(
      Uint8List rawBytes, {
        int maxDimension = 500,
      }) async {
    return convertToJpg(rawBytes, maxDimension: maxDimension, quality: 0.82);
  }

  // ===========================================================================
  // 3. Security Watermark Application
  // ===========================================================================

  /// Applies a full-frame diagonal tiled security watermark:
  /// - Text: `SJP2-DSP | <Diocesan Control Number>` (e.g. SJP2-DSP | C-FF 2026-0001)
  /// - Layout: Diagonal (-30°) tiled across the entire image area in staggered brick pattern
  /// - Opacity: 25% to 35%
  static Future<Uint8List> applySecurityWatermark({
    required Uint8List rawImageBytes,
    String? assetIdentifier,
    DateTime? captureTime,
    double maxDimension = defaultMaxLongEdge,
  }) async {
    final Completer<ui.Image> completer = Completer();
    ui.decodeImageFromList(rawImageBytes, (ui.Image img) {
      completer.complete(img);
    });

    final ui.Image originalImage = await completer.future;
    final int origWidth = originalImage.width;
    final int origHeight = originalImage.height;

    final double longEdge = max(origWidth, origHeight).toDouble();
    double targetWidth = origWidth.toDouble();
    double targetHeight = origHeight.toDouble();

    if (longEdge > maxDimension && longEdge > 0) {
      final double scale = maxDimension / longEdge;
      targetWidth = (origWidth * scale).roundToDouble();
      targetHeight = (origHeight * scale).roundToDouble();
    }

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, targetWidth, targetHeight),
    );

    // Opaque white base
    canvas.drawRect(
      Rect.fromLTWH(0, 0, targetWidth, targetHeight),
      Paint()..color = const Color(0xFFFFFFFF),
    );

    // Draw scaled background image
    final Rect srcRect = Rect.fromLTWH(0, 0, origWidth.toDouble(), origHeight.toDouble());
    final Rect dstRect = Rect.fromLTWH(0, 0, targetWidth, targetHeight);

    canvas.drawImageRect(
      originalImage,
      srcRect,
      dstRect,
      Paint()..filterQuality = FilterQuality.high,
    );

    // Extract sanitized Diocesan Control Number
    String controlNo = 'PENDING-REG';
    if (assetIdentifier != null && assetIdentifier.trim().isNotEmpty) {
      final trimmed = assetIdentifier.trim();
      if (trimmed.contains('•')) {
        controlNo = trimmed.split('•').first.trim().toUpperCase();
      } else {
        controlNo = trimmed.toUpperCase();
      }
    }

    final String watermarkText = controlNo.startsWith('SJP2-DSP')
        ? controlNo
        : 'SJP2-DSP | $controlNo';

    final double shortEdge = min(targetWidth, targetHeight);
    final double fontSize = (shortEdge * 0.032).clamp(18.0, 36.0);

    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: watermarkText,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
          fontFamily: 'Courier',
          color: const Color(0x48FFFFFF),
          shadows: const [
            Shadow(
              color: Color(0x28000000),
              offset: Offset(1.0, 1.0),
              blurRadius: 2.0,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    canvas.translate(targetWidth / 2, targetHeight / 2);
    const double rotationAngle = -pi / 6;
    canvas.rotate(rotationAngle);

    final double diagonal = sqrt((targetWidth * targetWidth) + (targetHeight * targetHeight));
    final double textW = textPainter.width;
    final double textH = textPainter.height;

    final double spacingX = textW * 0.55;
    final double spacingY = textH * 3.4;

    final double stepX = textW + spacingX;
    final double stepY = textH + spacingY;

    int row = 0;
    for (double y = -diagonal; y <= diagonal; y += stepY) {
      final double rowOffset = (row % 2 == 0) ? 0.0 : (stepX / 2);
      for (double x = -diagonal - stepX; x <= diagonal + stepX; x += stepX) {
        textPainter.paint(canvas, Offset(x + rowOffset, y));
      }
      row++;
    }

    canvas.restore();

    final ui.Picture picture = recorder.endRecording();
    final ui.Image watermarkedImage = await picture.toImage(
      targetWidth.toInt(),
      targetHeight.toInt(),
    );
    final ByteData? byteData = await watermarkedImage.toByteData(
      format: ui.ImageByteFormat.png,
    );

    try {
      originalImage.dispose();
    } catch (_) {}
    try {
      watermarkedImage.dispose();
    } catch (_) {}
    try {
      picture.dispose();
    } catch (_) {}

    if (byteData == null) {
      return rawImageBytes;
    }

    final outBytes = byteData.buffer.asUint8List();

    // Ensure final output on web is wrapped in JPEG
    if (kIsWeb) {
      final webJpeg = await WebCameraHelper.downscaleImageToJpegForPdf(
        outBytes,
        maxWidth: targetWidth.toInt(),
        quality: 0.90,
      );
      if (webJpeg != null && webJpeg.isNotEmpty) return webJpeg;
    }

    return outBytes;
  }

  // ===========================================================================
  // 4. Interactive Full-Resolution Preview Modal
  // ===========================================================================

  static void showImagePreviewModal(
      BuildContext context, {
        required ImageProvider imageProvider,
        required String title,
        String? controlNumber,
      }) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxWidth: 860, maxHeight: 760),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF334155)),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E293B),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_outlined,
                      color: Color(0xFFD49B18),
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (controlNumber != null && controlNumber.isNotEmpty)
                            Text(
                              'Control #: $controlNumber • Anti-Tamper Security Photo',
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 11.5,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4.0,
                    child: Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image(
                          image: imageProvider,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(color: Colors.white),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Text(
                                'Failed to display image preview',
                                style: TextStyle(color: Colors.white70),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E293B),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.security, size: 14, color: Color(0xFFD49B18)),
                    SizedBox(width: 6),
                    Text(
                      'Tiled security watermark embedded across the image for diocesan property protection.',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}