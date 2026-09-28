import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class AssetImageWatermarkUtil {
  AssetImageWatermarkUtil._();

  /// Automatically embeds a canonical diocesan security watermark into raw image bytes
  /// using Flutter's native `dart:ui.Canvas` engine with proportional auto-scaling
  /// to ensure text never clips or overflows the image boundaries.
  static Future<Uint8List> applySecurityWatermark({
    required Uint8List rawImageBytes,
    String? assetIdentifier, // Control # (e.g. C-SI-2008-001) or Asset ID
    DateTime? captureTime,
  }) async {
    final Completer<ui.Image> completer = Completer();
    ui.decodeImageFromList(rawImageBytes, (ui.Image img) {
      completer.complete(img);
    });

    final ui.Image originalImage = await completer.future;
    final int imgWidth = originalImage.width;
    final int imgHeight = originalImage.height;

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, imgWidth.toDouble(), imgHeight.toDouble()),
    );

    // 1. Draw the original asset photograph
    canvas.drawImage(originalImage, Offset.zero, Paint());

    // 2. Prepare text contents
    final timeStamp = captureTime ?? DateTime.now();
    final formattedTime =
        '${timeStamp.year}-${timeStamp.month.toString().padLeft(2, '0')}-${timeStamp.day.toString().padLeft(2, '0')} '
        '${timeStamp.hour.toString().padLeft(2, '0')}:${timeStamp.minute.toString().padLeft(2, '0')}:${timeStamp.second.toString().padLeft(2, '0')} PST';

    final idText = (assetIdentifier != null && assetIdentifier.trim().isNotEmpty)
        ? assetIdentifier.trim().toUpperCase()
        : 'PENDING REGISTRATION';

    const String line1Text = 'SAINT JOHN PAUL II PARISH • DIOCESE OF SAN PABLO';
    final String line2Text = 'DIOCESAN CONTROL NO: $idText';
    final String line3Text = 'SECURED ON: $formattedTime • CANON 1283';

    // 3. Calculate proportional margins and maximum allowed text width
    final double horizontalPadding = (imgWidth * 0.04).clamp(12.0, 48.0);
    final double maxTextWidth = imgWidth - (horizontalPadding * 2);

    // 4. Compute optimal font sizes that fit horizontally within maxTextWidth
    // Scale baseline based on image width rather than height to prevent overflow
    double primaryFontSize = (imgWidth * 0.030).clamp(10.0, 38.0);
    double secondaryFontSize = (primaryFontSize * 0.78).clamp(8.5, 30.0);
    double tertiaryFontSize = (primaryFontSize * 0.65).clamp(7.5, 24.0);

    // Auto-fit Line 1 (Parish & Diocese) so it NEVER wraps or overflows
    TextPainter testPainter = TextPainter(
      text: TextSpan(
        text: line1Text,
        style: TextStyle(
          fontSize: primaryFontSize,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    if (testPainter.width > maxTextWidth && testPainter.width > 0) {
      final double ratio = maxTextWidth / testPainter.width;
      primaryFontSize = max(8.0, primaryFontSize * ratio * 0.96);
      secondaryFontSize = max(7.0, secondaryFontSize * ratio * 0.96);
      tertiaryFontSize = max(6.5, tertiaryFontSize * ratio * 0.96);
    }

    // Auto-fit Line 2 (Control Number) if it is long
    TextPainter testLine2Painter = TextPainter(
      text: TextSpan(
        text: line2Text,
        style: TextStyle(
          fontSize: secondaryFontSize,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    if (testLine2Painter.width > maxTextWidth && testLine2Painter.width > 0) {
      final double ratio = maxTextWidth / testLine2Painter.width;
      secondaryFontSize = max(6.5, secondaryFontSize * ratio * 0.96);
    }

    // 5. Build final layout text painters
    final TextPainter parishPainter = TextPainter(
      text: TextSpan(
        text: line1Text,
        style: TextStyle(
          color: const Color(0xFFF8FAFC), // Parchment White
          fontSize: primaryFontSize,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.6,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxTextWidth);

    final TextPainter idPainter = TextPainter(
      text: TextSpan(
        text: line2Text,
        style: TextStyle(
          color: const Color(0xFFD49B18), // Eucharistic Gold
          fontSize: secondaryFontSize,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.4,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxTextWidth);

    final TextPainter timestampPainter = TextPainter(
      text: TextSpan(
        text: line3Text,
        style: TextStyle(
          color: const Color(0xFFCBD5E1), // Crisp Silver Slate
          fontSize: tertiaryFontSize,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxTextWidth);

    // 6. Dynamically compute required banner height from laid out text heights
    final double lineSpacing = (primaryFontSize * 0.28).clamp(3.0, 10.0);
    final double verticalPadding = (primaryFontSize * 0.60).clamp(8.0, 24.0);

    final double totalTextHeight = parishPainter.height +
        lineSpacing +
        idPainter.height +
        lineSpacing +
        timestampPainter.height;

    final double bannerHeight = totalTextHeight + (verticalPadding * 2);
    final double bannerTop = imgHeight - bannerHeight;

    // 7. Draw semi-transparent dark navy banner
    final Paint barPaint = Paint()
      ..color = const Color(0xDD0F172A) // 87% opacity deep Marian slate
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(0, bannerTop, imgWidth.toDouble(), bannerHeight),
      barPaint,
    );

    // 8. Draw Diocesan Gold decorative top separator line
    final double goldLineThickness = (bannerHeight * 0.025).clamp(2.0, 5.0);
    final Paint goldLinePaint = Paint()
      ..color = const Color(0xFFD49B18)
      ..strokeWidth = goldLineThickness
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(0, bannerTop),
      Offset(imgWidth.toDouble(), bannerTop),
      goldLinePaint,
    );

    // 9. Paint lines of text onto canvas
    double currentY = bannerTop + verticalPadding;

    parishPainter.paint(canvas, Offset(horizontalPadding, currentY));
    currentY += parishPainter.height + lineSpacing;

    idPainter.paint(canvas, Offset(horizontalPadding, currentY));
    currentY += idPainter.height + lineSpacing;

    timestampPainter.paint(canvas, Offset(horizontalPadding, currentY));

    // 10. Render picture to byte buffer
    final ui.Picture picture = recorder.endRecording();
    final ui.Image watermarkedImage = await picture.toImage(imgWidth, imgHeight);
    final ByteData? byteData = await watermarkedImage.toByteData(format: ui.ImageByteFormat.png);

    if (byteData == null) {
      return rawImageBytes;
    }

    return byteData.buffer.asUint8List();
  }

  /// Opens an interactive full-resolution image preview dialog showing the watermark
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
          constraints: const BoxConstraints(maxWidth: 820, maxHeight: 720),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF334155)),
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 24, offset: Offset(0, 10)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E293B),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_outlined, color: Color(0xFFD49B18), size: 22),
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
                              'Control #: $controlNumber • Security Watermark Applied',
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
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

              // Zoomable Image View
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
                            return const Center(child: CircularProgressIndicator(color: Colors.white));
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

              // Footer Note
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E293B),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline, size: 14, color: Color(0xFFD49B18)),
                    SizedBox(width: 6),
                    Text(
                      'Automated security watermark embedded for asset protection & inventory audits.',
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