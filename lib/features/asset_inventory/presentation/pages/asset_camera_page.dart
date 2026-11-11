// =============================================================================
// FILE: lib/features/asset_inventory/presentation/pages/asset_camera_page.dart
// =============================================================================

import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/constants/colors.dart';
import '../../utils/asset_image_watermark_util.dart';
import '../../utils/web_camera_helper.dart';

enum AssetCameraRatio {
  landscape3R, // 5" x 3.5" (10:7 ratio ≈ 1.4286)
  portrait3R, // 3.5" x 5" (7:10 ratio = 0.7000)
}

class AssetCameraPage extends StatefulWidget {
  final String assetIdentifier;

  const AssetCameraPage({
    super.key,
    required this.assetIdentifier,
  });

  @override
  State<AssetCameraPage> createState() => _AssetCameraPageState();
}

class _AssetCameraPageState extends State<AssetCameraPage> {
  MobileScannerController? _scannerController;
  AssetCameraRatio _selectedRatio = AssetCameraRatio.landscape3R;
  bool _isTorchOn = false;
  bool _isProcessing = false;
  bool _cameraPermissionDenied = false;

  bool get _isLiveCameraSupported {
    if (kIsWeb) return true;
    try {
      return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
    } catch (_) {
      return false;
    }
  }

  double get _targetAspectRatio {
    switch (_selectedRatio) {
      case AssetCameraRatio.landscape3R:
        return 10.0 / 7.0; // 5 x 3.5 inches
      case AssetCameraRatio.portrait3R:
        return 7.0 / 10.0; // 3.5 x 5 inches
    }
  }

  @override
  void initState() {
    super.initState();
    _initScanner();
  }

  void _initScanner() {
    if (!_isLiveCameraSupported) return;
    try {
      _scannerController = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
        torchEnabled: false,
        autoStart: true,
      );
    } catch (e) {
      debugPrint('Error creating camera scanner controller: $e');
    }
  }

  @override
  void deactivate() {
    _safeStopCamera();
    super.deactivate();
  }

  @override
  void dispose() {
    _safeStopCamera();
    try {
      _scannerController?.dispose();
    } catch (_) {}
    _scannerController = null;
    super.dispose();
  }

  Future<void> _safeStopCamera() async {
    try {
      if (_scannerController != null) {
        await _scannerController!.stop();
      }
    } catch (_) {}

    WebCameraHelper.releaseCamera();
  }

  Future<void> _handleClose() async {
    await _safeStopCamera();
    if (mounted) {
      Navigator.pop(context, null);
    }
  }

  Future<void> _toggleTorch() async {
    if (_scannerController == null) return;
    try {
      await _scannerController!.toggleTorch();
      setState(() => _isTorchOn = !_isTorchOn);
    } catch (_) {}
  }

  Future<void> _switchCamera() async {
    if (_scannerController == null) return;
    try {
      await _scannerController!.switchCamera();
    } catch (_) {}
  }

  // ===========================================================================
  // Frame Capture, 3R Aspect Ratio Cropping, and Watermarking
  // ===========================================================================

  Future<void> _capturePhoto() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      Uint8List? rawBytes;

      if (kIsWeb) {
        rawBytes = WebCameraHelper.captureFrame();
      } else {
        // Native mobile fallback if video canvas element is not in DOM
        await _safeStopCamera();
        final picker = ImagePicker();
        final photo = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 95,
        );
        if (photo != null) {
          rawBytes = await photo.readAsBytes();
        }
      }

      if (rawBytes == null || rawBytes.isEmpty) {
        setState(() => _isProcessing = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Could not capture image from stream. Please ensure camera is active.'),
              backgroundColor: ParishColors.goldAccent,
            ),
          );
        }
        return;
      }

      // Crop the snapshot to match the selected 3R aspect ratio
      final croppedBytes = await _cropImageTo3RRatio(rawBytes, _targetAspectRatio);

      // Apply diocesan diagonal tiled security watermark
      final watermarkedBytes = await AssetImageWatermarkUtil.applySecurityWatermark(
        rawImageBytes: croppedBytes,
        assetIdentifier: widget.assetIdentifier,
        captureTime: DateTime.now(),
      );

      await _safeStopCamera();

      if (mounted) {
        Navigator.pop(context, watermarkedBytes);
      }
    } catch (e) {
      debugPrint('Error capturing 3R photo: $e');
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Capture error: $e'),
            backgroundColor: ParishColors.mercyRed,
          ),
        );
      }
    }
  }

  /// Crops any raw image to the exact 3R aspect ratio (10:7 or 7:10)
  Future<Uint8List> _cropImageTo3RRatio(
      Uint8List rawBytes,
      double targetRatio,
      ) async {
    final Completer<ui.Image> completer = Completer();
    ui.decodeImageFromList(rawBytes, (ui.Image img) {
      completer.complete(img);
    });

    final ui.Image image = await completer.future;
    final double imgW = image.width.toDouble();
    final double imgH = image.height.toDouble();
    final double currentRatio = imgW / imgH;

    double cropW = imgW;
    double cropH = imgH;

    if (currentRatio > targetRatio) {
      // Source image is wider than 3R target -> trim horizontal margins
      cropW = imgH * targetRatio;
    } else {
      // Source image is taller than 3R target -> trim vertical margins
      cropH = imgW / targetRatio;
    }

    final double cropX = (imgW - cropW) / 2.0;
    final double cropY = (imgH - cropH) / 2.0;

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, cropW, cropH),
    );

    canvas.drawImageRect(
      image,
      Rect.fromLTWH(cropX, cropY, cropW, cropH),
      Rect.fromLTWH(0, 0, cropW, cropH),
      Paint()..filterQuality = FilterQuality.high,
    );

    final ui.Picture picture = recorder.endRecording();
    final ui.Image croppedImage = await picture.toImage(
      cropW.toInt(),
      cropH.toInt(),
    );

    final ByteData? byteData = await croppedImage.toByteData(
      format: ui.ImageByteFormat.png,
    );

    return byteData != null ? byteData.buffer.asUint8List() : rawBytes;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double screenWidth = constraints.maxWidth;
        final double screenHeight = constraints.maxHeight;
        final bool isMobile = screenWidth < 650;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            await _handleClose();
          },
          child: Scaffold(
            backgroundColor: const Color(0xFF0F172A),
            body: SafeArea(
              child: Stack(
                children: [
                  // 1. Live Camera Viewfinder
                  Positioned.fill(
                    child: _isLiveCameraSupported &&
                        _scannerController != null &&
                        !_cameraPermissionDenied
                        ? MobileScanner(
                      controller: _scannerController!,
                      onDetect: (_) {},
                      errorBuilder: (ctx, err) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Text(
                              'Camera error: ${err.errorDetails?.message ?? "Permission required"}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      },
                    )
                        : const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    ),
                  ),

                  // 2. Translucent Mask with 3R Cutout Viewport
                  Positioned.fill(
                    child: _build3RMaskOverlay(
                      screenWidth: screenWidth,
                      screenHeight: screenHeight,
                      isMobile: isMobile,
                    ),
                  ),

                  // 3. Top Header Bar (Close Button, Title & Identifier)
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: Row(
                      children: [
                        IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black54,
                            padding: const EdgeInsets.all(10),
                          ),
                          icon: const Icon(Icons.close, color: Colors.white, size: 22),
                          tooltip: 'Close Camera',
                          onPressed: _isProcessing ? null : _handleClose,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                '3R Photo Capture',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                widget.assetIdentifier,
                                style: const TextStyle(
                                  color: Color(0xFFD49B18),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black54,
                            padding: const EdgeInsets.all(10),
                          ),
                          icon: Icon(
                            _isTorchOn ? Icons.flash_on : Icons.flash_off,
                            color: Colors.white,
                            size: 20,
                          ),
                          tooltip: 'Flash',
                          onPressed: _isProcessing ? null : _toggleTorch,
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black54,
                            padding: const EdgeInsets.all(10),
                          ),
                          icon: const Icon(Icons.cameraswitch, color: Colors.white, size: 20),
                          tooltip: 'Switch Camera',
                          onPressed: _isProcessing ? null : _switchCamera,
                        ),
                      ],
                    ),
                  ),

                  // 4. Bottom Controls: 3R Aspect Ratio Selector & Shutter Button
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 3R Ratio Segmented Selector
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildRatioTab(
                                label: '3R Landscape (5 × 3.5)',
                                icon: Icons.crop_landscape,
                                isSelected:
                                _selectedRatio == AssetCameraRatio.landscape3R,
                                onTap: () => setState(() =>
                                _selectedRatio = AssetCameraRatio.landscape3R),
                              ),
                              const SizedBox(width: 4),
                              _buildRatioTab(
                                label: '3R Portrait (3.5 × 5)',
                                icon: Icons.crop_portrait,
                                isSelected:
                                _selectedRatio == AssetCameraRatio.portrait3R,
                                onTap: () => setState(() =>
                                _selectedRatio = AssetCameraRatio.portrait3R),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Shutter Button Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: _isProcessing ? null : _capturePhoto,
                              child: Container(
                                width: 72,
                                height: 72,
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3.5,
                                  ),
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _isProcessing
                                        ? Colors.white54
                                        : ParishColors.goldAccent,
                                  ),
                                  child: _isProcessing
                                      ? const Center(
                                    child: SizedBox(
                                      width: 26,
                                      height: 26,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    ),
                                  )
                                      : const Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _selectedRatio == AssetCameraRatio.landscape3R
                              ? '3R Landscape • Standard 10:7 print ratio'
                              : '3R Portrait • Standard 7:10 print ratio',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 5. Processing / Watermarking Overlay
                  if (_isProcessing)
                    Container(
                      color: Colors.black54,
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              color: Color(0xFFD49B18),
                              strokeWidth: 3,
                            ),
                            SizedBox(height: 14),
                            Text(
                              'Cropping to 3R & embedding watermark...',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // 3R Viewfinder Mask Overlay Painter
  // ===========================================================================

  Widget _build3RMaskOverlay({
    required double screenWidth,
    required double screenHeight,
    required bool isMobile,
  }) {
    // Available bounding area for the viewport
    final double maxWidth = screenWidth - 36;
    final double maxHeight = screenHeight - 240;

    double boxWidth;
    double boxHeight;

    if (_selectedRatio == AssetCameraRatio.landscape3R) {
      boxWidth = maxWidth.clamp(280.0, 720.0);
      boxHeight = boxWidth / (10.0 / 7.0);
      if (boxHeight > maxHeight) {
        boxHeight = maxHeight;
        boxWidth = boxHeight * (10.0 / 7.0);
      }
    } else {
      boxHeight = maxHeight.clamp(320.0, 620.0);
      boxWidth = boxHeight * (7.0 / 10.0);
      if (boxWidth > maxWidth) {
        boxWidth = maxWidth;
        boxHeight = boxWidth / (7.0 / 10.0);
      }
    }

    return Center(
      child: Container(
        width: boxWidth,
        height: boxHeight,
        decoration: BoxDecoration(
          border: Border.all(
            color: const Color(0xFFD49B18),
            width: 2.5,
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.55),
              spreadRadius: 2000,
            ),
          ],
        ),
        child: Stack(
          children: [
            // Rule of thirds grid lines
            Column(
              children: [
                const Spacer(flex: 1),
                Divider(color: Colors.white.withOpacity(0.2), height: 1),
                const Spacer(flex: 1),
                Divider(color: Colors.white.withOpacity(0.2), height: 1),
                const Spacer(flex: 1),
              ],
            ),
            Row(
              children: [
                const Spacer(flex: 1),
                VerticalDivider(color: Colors.white.withOpacity(0.2), width: 1),
                const Spacer(flex: 1),
                VerticalDivider(color: Colors.white.withOpacity(0.2), width: 1),
                const Spacer(flex: 1),
              ],
            ),
            // Corner target indicators
            Align(
              alignment: Alignment.topLeft,
              child: _buildCornerWidget(),
            ),
            Align(
              alignment: Alignment.topRight,
              child: Transform.rotate(angle: pi / 2, child: _buildCornerWidget()),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Transform.rotate(angle: -pi / 2, child: _buildCornerWidget()),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: Transform.rotate(angle: pi, child: _buildCornerWidget()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCornerWidget() {
    return Container(
      width: 18,
      height: 18,
      margin: const EdgeInsets.all(4),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFD49B18), width: 3),
          left: BorderSide(color: Color(0xFFD49B18), width: 3),
        ),
      ),
    );
  }

  Widget _buildRatioTab({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD49B18) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : Colors.white70,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}