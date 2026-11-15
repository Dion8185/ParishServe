// =============================================================================
// FILE: lib/features/asset_inventory/utils/web_camera_helper_stub.dart
// =============================================================================

import 'dart:typed_data';

/// Fallback for non-web platforms (Android, iOS, macOS, Windows, Linux)
void stopAllWebCameraTracks() {}

/// Fallback returning null on non-web platforms
Uint8List? captureCurrentWebVideoFrame() => null;

/// Fallback returning null on non-web platforms
Future<Uint8List?> downscaleImageToJpegWeb(
    Uint8List rawBytes, {
      int maxWidth = 360,
      double quality = 0.82,
    }) async =>
    null;

/// Fallback returning null on non-web platforms
Future<Uint8List?> fetchImageBytesWeb(String url) async => null;