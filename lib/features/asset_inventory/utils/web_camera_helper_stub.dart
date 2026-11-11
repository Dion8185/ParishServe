// =============================================================================
// FILE: lib/features/asset_inventory/utils/web_camera_helper_stub.dart
// =============================================================================

import 'dart:typed_data';

/// Fallback for non-web platforms (Android, iOS, macOS, Windows, Linux)
void stopAllWebCameraTracks() {}

/// Fallback returning null on non-web platforms
Uint8List? captureCurrentWebVideoFrame() => null;