// =============================================================================
// FILE: lib/features/asset_inventory/utils/web_camera_helper.dart
// =============================================================================

import 'web_camera_helper_stub.dart'
if (dart.library.html) 'web_camera_helper_web.dart';

class WebCameraHelper {
  WebCameraHelper._();

  static void releaseCamera() {
    stopAllWebCameraTracks();
  }
}