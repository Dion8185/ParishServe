// =============================================================================
// FILE: lib/features/asset_inventory/utils/web_camera_helper_web.dart
// =============================================================================

import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:math';
import 'dart:typed_data';

/// Scans the browser DOM for active video stream tracks and explicitly stops them
/// so Chrome, Edge, Safari, and Firefox turn off the webcam light and camera icon.
void stopAllWebCameraTracks() {
  try {
    final videoElements = html.document.querySelectorAll('video');
    for (final element in videoElements) {
      if (element is html.VideoElement) {
        final stream = element.srcObject;
        if (stream is html.MediaStream) {
          final tracks = stream.getTracks();
          for (final track in tracks) {
            try {
              track.stop();
            } catch (_) {}
          }
          element.srcObject = null;
        }
      }
    }
  } catch (_) {}
}

/// Captures the current visible frame from any active HTML video element in the DOM
/// and returns it as a JPEG encoded Uint8List directly in browser memory without
/// triggering page reloads, tab suspension, or navigation resets.
Uint8List? captureCurrentWebVideoFrame() {
  try {
    final videoElements = html.document.querySelectorAll('video');
    for (final element in videoElements) {
      if (element is html.VideoElement) {
        final int w = element.videoWidth > 0
            ? element.videoWidth
            : (element.clientWidth > 0 ? element.clientWidth : 640);
        final int h = element.videoHeight > 0
            ? element.videoHeight
            : (element.clientHeight > 0 ? element.clientHeight : 480);

        if (w > 0 && h > 0) {
          final canvas = html.CanvasElement(width: w, height: h);
          final ctx = canvas.context2D;
          ctx.drawImageScaled(element, 0, 0, w, h);
          final dataUrl = canvas.toDataUrl('image/jpeg', 0.92);
          final commaIndex = dataUrl.indexOf(',');
          if (commaIndex != -1) {
            final base64String = dataUrl.substring(commaIndex + 1);
            return base64Decode(base64String);
          }
        }
      }
    }
  } catch (_) {}
  return null;
}

String _detectImageMimeType(Uint8List bytes) {
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return 'image/png';
  }
  if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
    return 'image/jpeg';
  }
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return 'image/webp';
  }
  if (bytes.length >= 6 &&
      bytes[0] == 0x47 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46) {
    return 'image/gif';
  }
  return 'image/png';
}

/// Fetches image bytes on Web while bypassing non-CORS <img> disk cache poisoning.
Future<Uint8List?> fetchImageBytesWeb(String url) async {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return null;

  // 1. Try Fetch API with cache: 'reload' and mode: 'cors' (preserves signed URLs)
  try {
    final dynamic response = await html.window.fetch(trimmed, {
      'method': 'GET',
      'mode': 'cors',
      'cache': 'reload',
    });

    final bool ok = (response as dynamic).ok as bool? ?? false;
    if (ok) {
      final dynamic blob = await (response as dynamic).blob();
      if (blob is html.Blob) {
        final reader = html.FileReader();
        final completer = Completer<Uint8List?>();

        reader.onLoadEnd.first.then((_) {
          if (completer.isCompleted) return;
          final result = reader.result;
          if (result is ByteBuffer) {
            completer.complete(result.asUint8List());
          } else if (result is Uint8List) {
            completer.complete(result);
          } else {
            completer.complete(null);
          }
        });
        reader.onError.first.then((_) {
          if (!completer.isCompleted) completer.complete(null);
        });

        reader.readAsArrayBuffer(blob);
        final bytes = await completer.future.timeout(
          const Duration(seconds: 15),
          onTimeout: () => null,
        );
        if (bytes != null && bytes.isNotEmpty) {
          return bytes;
        }
      }
    }
  } catch (_) {}

  // 2. Fallback: XHR with cache-busting query param for unsigned public URLs
  try {
    final lower = trimmed.toLowerCase();
    final isSigned = lower.contains('token=') ||
        lower.contains('signature=') ||
        lower.contains('x-amz-signature=');

    final targetUrl = isSigned
        ? trimmed
        : '$trimmed${trimmed.contains('?') ? '&' : '?'}_pdf_cb=${DateTime.now().millisecondsSinceEpoch}';

    final req = await html.HttpRequest.request(
      targetUrl,
      method: 'GET',
      responseType: 'arraybuffer',
    ).timeout(const Duration(seconds: 15));

    if (req.status == 200 && req.response is ByteBuffer) {
      final bytes = (req.response as ByteBuffer).asUint8List();
      if (bytes.isNotEmpty) return bytes;
    }
  } catch (_) {}

  return null;
}

/// Decodes and downscales any image (PNG, JPEG, WebP, AVIF, etc.) using the
/// browser's native <img> + <canvas> pipeline, bypassing Chromium's buggy
/// WebCodecs ImageDecoder API and returning a tiny, fast-embedding JPEG.
Future<Uint8List?> downscaleImageToJpegWeb(
    Uint8List rawBytes, {
      int maxWidth = 360,
      double quality = 0.82,
    }) async {
  if (rawBytes.isEmpty) return null;
  String? objectUrl;
  try {
    final cleanBytes = rawBytes.offsetInBytes == 0 &&
        rawBytes.lengthInBytes == rawBytes.buffer.lengthInBytes
        ? rawBytes
        : Uint8List.fromList(rawBytes);

    final mimeType = _detectImageMimeType(cleanBytes);
    final blob = html.Blob([cleanBytes], mimeType);
    objectUrl = html.Url.createObjectUrlFromBlob(blob);

    final img = html.ImageElement();
    final completer = Completer<bool>();

    img.onLoad.first.then((_) {
      if (!completer.isCompleted) completer.complete(true);
    });
    img.onError.first.then((_) {
      if (!completer.isCompleted) completer.complete(false);
    });

    img.src = objectUrl;

    final loaded = await completer.future.timeout(
      const Duration(seconds: 6),
      onTimeout: () => false,
    );
    if (!loaded) return null;

    final int naturalW = img.naturalWidth;
    final int naturalH = img.naturalHeight;
    if (naturalW <= 0 || naturalH <= 0) return null;

    int targetW = naturalW;
    int targetH = naturalH;
    final int longEdge = max(naturalW, naturalH);
    if (longEdge > maxWidth) {
      final double scale = maxWidth / longEdge;
      targetW = (naturalW * scale).round().clamp(1, 2000);
      targetH = (naturalH * scale).round().clamp(1, 2000);
    }

    final canvas = html.CanvasElement(width: targetW, height: targetH);
    final ctx = canvas.context2D;
    ctx.fillStyle = '#FFFFFF';
    ctx.fillRect(0, 0, targetW, targetH);
    ctx.drawImageScaled(img, 0, 0, targetW, targetH);

    final dataUrl = canvas.toDataUrl('image/jpeg', quality);
    final commaIndex = dataUrl.indexOf(',');
    if (commaIndex == -1) return null;
    return base64Decode(dataUrl.substring(commaIndex + 1));
  } catch (_) {
    return null;
  } finally {
    if (objectUrl != null) {
      try {
        html.Url.revokeObjectUrl(objectUrl);
      } catch (_) {}
    }
  }
}