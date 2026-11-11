// =============================================================================
// FILE: lib/features/asset_inventory/utils/web_camera_helper_web.dart
// =============================================================================

import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
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