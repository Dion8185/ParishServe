// =============================================================================
// FILE: lib/features/asset_inventory/utils/web_camera_helper_web.dart
// =============================================================================

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

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