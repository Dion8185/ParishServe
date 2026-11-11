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
}