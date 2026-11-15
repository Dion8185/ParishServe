// =============================================================================
// FILE: lib/features/asset_inventory/utils/web_camera_helper.dart
// =============================================================================

import 'dart:typed_data';
import 'web_camera_helper_stub.dart'
if (dart.library.html) 'web_camera_helper_web.dart';

class WebCameraHelper {
  WebCameraHelper._();

  /// Stops all active webcam hardware tracks in the browser DOM.
  static void releaseCamera() {
    stopAllWebCameraTracks();
  }

  /// Captures the current camera video frame directly to a byte array on Web.
  static Uint8List? captureFrame() {
    return captureCurrentWebVideoFrame();
  }

  /// Fetches image bytes on Web using cache-reload CORS fetch fallback.
  static Future<Uint8List?> fetchImageBytes(String url) {
    return fetchImageBytesWeb(url);
  }

  /// Decodes and downscales an image to a lightweight JPEG on Web using native
  /// <img> + <canvas>, returning null on non-web platforms.
  static Future<Uint8List?> downscaleImageToJpegForPdf(
      Uint8List rawBytes, {
        int maxWidth = 360,
        double quality = 0.82,
      }) {
    return downscaleImageToJpegWeb(
      rawBytes,
      maxWidth: maxWidth,
      quality: quality,
    );
  }
}