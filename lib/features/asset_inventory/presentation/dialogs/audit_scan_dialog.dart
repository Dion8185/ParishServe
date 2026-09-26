import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/constants/colors.dart';
import '../../models/asset_model.dart';
import '../../services/asset_service.dart';
import 'asset_detail_dialog.dart';

void showAuditScanModal(BuildContext context, {VoidCallback? onScanCompleted}) {
  showDialog(
    context: context,
    builder: (ctx) => _AuditScanDialog(onScanCompleted: onScanCompleted),
  );
}

enum AuditScanMode { selectMode, liveCamera, nfcListening, manualEntry }

class _AuditScanDialog extends StatefulWidget {
  final VoidCallback? onScanCompleted;

  const _AuditScanDialog({this.onScanCompleted});

  @override
  State<_AuditScanDialog> createState() => _AuditScanDialogState();
}

class _AuditScanDialogState extends State<_AuditScanDialog> {
  AuditScanMode _currentScanMode = AuditScanMode.selectMode;

  final TextEditingController _manualInputController = TextEditingController();
  final TextEditingController _nfcInputController = TextEditingController();
  final TextEditingController _auditNotesController = TextEditingController();

  MobileScannerController? _scannerController;

  bool _isSearching = false;
  String? _searchError;
  bool _hasProcessedScan = false;
  bool _isTorchOn = false;
  bool _cameraPermissionDenied = false;

  // Audit state once an asset is located
  AssetModel? _scannedAsset;
  String _selectedCondition = 'VERIFIED / GOOD';
  bool _isRecordingAudit = false;

  final List<String> _conditionOptions = [
    'VERIFIED / GOOD',
    'REQUIRES REPAIR',
    'DAMAGED',
    'MISSING',
    'UNUSABLE',
  ];

  @override
  void dispose() {
    _manualInputController.dispose();
    _nfcInputController.dispose();
    _auditNotesController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  void _startCameraScanner() {
    setState(() {
      _searchError = null;
      _hasProcessedScan = false;
      _scannedAsset = null;
      _cameraPermissionDenied = false;
      _scannerController?.dispose();
      _scannerController = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
        torchEnabled: false,
        autoStart: true,
      );
      _currentScanMode = AuditScanMode.liveCamera;
    });
  }

  void _startNfcListener() {
    setState(() {
      _searchError = null;
      _hasProcessedScan = false;
      _scannedAsset = null;
      _scannerController?.dispose();
      _scannerController = null;
      _currentScanMode = AuditScanMode.nfcListening;
    });
  }

  void _startManualLookup() {
    setState(() {
      _searchError = null;
      _hasProcessedScan = false;
      _scannedAsset = null;
      _scannerController?.dispose();
      _scannerController = null;
      _currentScanMode = AuditScanMode.manualEntry;
    });
  }

  void _resetToModeSelection() {
    setState(() {
      _scannerController?.dispose();
      _scannerController = null;
      _currentScanMode = AuditScanMode.selectMode;
      _scannedAsset = null;
      _searchError = null;
      _hasProcessedScan = false;
      _isSearching = false;
      _cameraPermissionDenied = false;
    });
  }

  Future<void> _handleBarcodeDetected(BarcodeCapture capture) async {
    if (_hasProcessedScan || _isSearching || _scannedAsset != null) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue != null && rawValue.trim().isNotEmpty) {
        _hasProcessedScan = true;
        await _searchAndLoadAsset(rawValue.trim());
        break;
      }
    }
  }

  Future<void> _searchAndLoadAsset(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchError = null;
      _scannedAsset = null;
    });

    try {
      final asset = await AssetService.findAssetByIdentifier(clean);
      if (!mounted) return;

      if (asset != null) {
        _scannerController?.dispose();
        _scannerController = null;
        setState(() {
          _scannedAsset = asset;
          _selectedCondition = asset.conditionStatus;
          _isSearching = false;
        });
      } else {
        setState(() {
          _searchError =
          'No asset record found matching "$clean". Please verify the Control Number, RFID, or QR Token.';
          _isSearching = false;
          _hasProcessedScan = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searchError = e.toString().replaceFirst('Exception: ', '');
        _isSearching = false;
        _hasProcessedScan = false;
      });
    }
  }

  Future<void> _pickImageAndScan() async {
    try {
      final dynamic result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      );

      if (result != null) {
        dynamic file;
        if (result is List && result.isNotEmpty) {
          file = result.first;
        } else {
          try {
            final files = (result as dynamic).files;
            if (files != null && files.isNotEmpty) file = files.first;
          } catch (_) {
            file = result;
          }
        }

        if (file != null) {
          String? filePath;
          try {
            filePath = (file as dynamic).path;
          } catch (_) {}

          if (filePath != null && filePath.isNotEmpty) {
            _scannerController ??= MobileScannerController();
            final BarcodeCapture? capture =
            await _scannerController!.analyzeImage(filePath);
            if (capture != null && capture.barcodes.isNotEmpty) {
              final raw = capture.barcodes.first.rawValue;
              if (raw != null) {
                await _searchAndLoadAsset(raw);
                return;
              }
            }
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Could not detect a clear QR code from the selected image. Please try another photo or enter manually.'),
            backgroundColor: ParishColors.goldAccent,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error picking image for barcode analysis: $e');
    }
  }

  Future<void> _commitAuditInspection(String method) async {
    if (_scannedAsset == null) return;

    setState(() => _isRecordingAudit = true);

    try {
      await AssetService.recordAuditScan(
        assetId: _scannedAsset!.assetId,
        controlNumber: _scannedAsset!.controlNumber,
        newCondition: _selectedCondition,
        previousCondition: _scannedAsset!.conditionStatus,
        previousLocation: _scannedAsset!.displayLocation,
        newLocation: _scannedAsset!.displayLocation,
        auditMethod: method,
        auditNotes: _auditNotesController.text.trim(),
      );

      if (!mounted) return;
      Navigator.pop(context);
      widget.onScanCompleted?.call();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Audit recorded for ${_scannedAsset!.controlNumber}: $_selectedCondition'),
          backgroundColor: ParishColors.oliveGreen,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searchError = 'Failed to log audit inspection: $e';
        _isRecordingAudit = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final cardWhite = ParishColors.cardWhite;
    final borderGrey = ParishColors.borderGrey;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: cardWhite,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        width: 640,
        constraints: const BoxConstraints(maxHeight: 760),
        child: Column(
          children: [
            // Modal Header Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: ParishColors.marianBlueSurface,
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: borderGrey)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ParishColors.marianBlue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.qr_code_scanner,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mobile Field Audit & Verification',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: textDark),
                        ),
                        Text(
                          'Choose between Camera QR Scanner, NFC/RFID Reader, or Manual Lookup',
                          style: TextStyle(fontSize: 11.5, color: textMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Modal Body Area
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_searchError != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: ParishColors.mercyRedSurface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: ParishColors.mercyRed),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                color: ParishColors.mercyRed, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _searchError!,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: ParishColors.mercyRed),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (_scannedAsset == null) ...[
                      if (_currentScanMode == AuditScanMode.selectMode)
                        _buildModeSelectionGrid()
                      else if (_currentScanMode == AuditScanMode.liveCamera)
                        _buildLiveCameraScannerView()
                      else if (_currentScanMode == AuditScanMode.nfcListening)
                          _buildNfcReaderView()
                        else if (_currentScanMode == AuditScanMode.manualEntry)
                            _buildManualLookupView(),
                    ],

                    if (_isSearching)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(28.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_scannedAsset != null)
                      _buildAssetAuditVerificationForm(),
                  ],
                ),
              ),
            ),

            // Modal Footer Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: cardWhite,
                borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(20)),
                border: Border(top: BorderSide(color: borderGrey)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentScanMode != AuditScanMode.selectMode &&
                      _scannedAsset == null)
                    TextButton.icon(
                      onPressed: _resetToModeSelection,
                      icon: const Icon(Icons.arrow_back, size: 16),
                      label: const Text('Back to Options'),
                    )
                  else
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Close', style: TextStyle(color: textMuted)),
                    ),

                  if (_scannedAsset != null)
                    Row(
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: borderGrey),
                            foregroundColor: textDark,
                          ),
                          onPressed: _resetToModeSelection,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Audit Another'),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ParishColors.oliveGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _isRecordingAudit
                              ? null
                              : () => _commitAuditInspection(
                            _currentScanMode ==
                                AuditScanMode.nfcListening
                                ? 'RFID_NFC'
                                : (_currentScanMode ==
                                AuditScanMode.liveCamera
                                ? 'QR_SCAN'
                                : 'MANUAL'),
                          ),
                          icon: _isRecordingAudit
                              ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.check_circle_outline,
                              size: 18),
                          label: Text(
                            _isRecordingAudit
                                ? 'Saving Audit...'
                                : 'Confirm Audit Inspection',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. Initial Mode Selection: Choose Between Camera Scanner, NFC, or Manual
  // ===========================================================================

  Widget _buildModeSelectionGrid() {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Audit Verification Method',
          style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.bold, color: textDark),
        ),
        const SizedBox(height: 4),
        Text(
          'Choose the appropriate scanning tool based on the physical asset tag.',
          style: TextStyle(fontSize: 12, color: textMuted),
        ),
        const SizedBox(height: 16),

        _buildMethodCard(
          title: 'Camera QR Code Scanner',
          subtitle:
          'Open camera viewfinder to scan printed physical QR stickers on furniture, equipment, and books.',
          icon: Icons.camera_alt_outlined,
          badgeLabel: 'OPTICAL QR',
          badgeColor: ParishColors.marianBlue,
          onTap: _startCameraScanner,
        ),
        const SizedBox(height: 12),

        _buildMethodCard(
          title: 'NFC / RFID Wireless Sensor',
          subtitle:
          'Tap or hold device against 13.56 MHz HF tags affixed to sacred vessels and metal furnishings.',
          icon: Icons.nfc,
          badgeLabel: 'WIRELESS NFC',
          badgeColor: ParishColors.goldAccent,
          onTap: _startNfcListener,
        ),
        const SizedBox(height: 12),

        _buildMethodCard(
          title: 'Manual Control # & Token Lookup',
          subtitle:
          'Type Diocesan Control # (e.g. C-SI-2008-001) or asset token if label is damaged or inaccessible.',
          icon: Icons.keyboard_outlined,
          badgeLabel: 'MANUAL KEYBOARD',
          badgeColor: ParishColors.oliveGreen,
          onTap: _startManualLookup,
        ),
      ],
    );
  }

  Widget _buildMethodCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required String badgeLabel,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final borderGrey = ParishColors.borderGrey;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ParishColors.backgroundLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderGrey),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
              ),
              child: Icon(icon, color: badgeColor, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: textDark),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badgeLabel,
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: badgeColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11.5, color: textMuted),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: borderGrey),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 2. Camera Viewfinder with Explicit Permission & Lifecycle Management
  // ===========================================================================

  Widget _buildLiveCameraScannerView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.videocam_outlined,
                    color: ParishColors.marianBlue, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Live Camera Scanner Active',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: ParishColors.marianBlue),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: _resetToModeSelection,
              icon: const Icon(Icons.close, size: 16),
              label: const Text('Cancel Camera'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 280,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ParishColors.borderGrey),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_scannerController != null && !_cameraPermissionDenied)
                  MobileScanner(
                    controller: _scannerController!,
                    onDetect: _handleBarcodeDetected,
                    errorBuilder: (context, error) {
                      final isPermission = error.errorCode ==
                          MobileScannerErrorCode.permissionDenied ||
                          error.toString().toLowerCase().contains('permission');

                      return Container(
                        color: const Color(0xFF0F172A),
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isPermission
                                    ? Icons.security_outlined
                                    : Icons.no_photography_outlined,
                                size: 42,
                                color: ParishColors.mercyRed,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                isPermission
                                    ? 'Camera Permission Required'
                                    : 'Camera Unavailable',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                isPermission
                                    ? 'Camera access was not granted. Please allow camera permissions in your device settings or browser.'
                                    : 'Failed to access camera: ${error.errorDetails?.message ?? error.toString()}',
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.75),
                                    fontSize: 11.5),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 14),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: ParishColors.marianBlue,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () {
                                      _startCameraScanner();
                                    },
                                    icon: const Icon(Icons.refresh, size: 16),
                                    label: const Text('Retry Permission'),
                                  ),
                                  const SizedBox(width: 10),
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Colors.white70),
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: _pickImageAndScan,
                                    icon: const Icon(Icons.image, size: 16),
                                    label: const Text('Scan Photo'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  )
                else
                  Container(
                    color: const Color(0xFF0F172A),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.camera_alt_outlined,
                              color: Colors.white70, size: 36),
                          const SizedBox(height: 8),
                          const Text(
                            'Camera Stopped',
                            style: TextStyle(color: Colors.white, fontSize: 13),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ParishColors.marianBlue,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _startCameraScanner,
                            child: const Text('Start Camera'),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Center Focus Reticle
                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    border:
                    Border.all(color: ParishColors.goldAccent, width: 2.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),

                // Controls Overlay
                Positioned(
                  bottom: 12,
                  child: Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            _isTorchOn ? Icons.flash_on : Icons.flash_off,
                            color: _isTorchOn
                                ? ParishColors.goldAccent
                                : Colors.white,
                            size: 20,
                          ),
                          onPressed: () async {
                            if (_scannerController == null) return;
                            try {
                              await _scannerController!.toggleTorch();
                              setState(() {
                                _isTorchOn = !_isTorchOn;
                              });
                            } catch (_) {}
                          },
                          tooltip: 'Toggle Flashlight',
                        ),
                        IconButton(
                          icon: const Icon(Icons.cameraswitch,
                              color: Colors.white, size: 20),
                          onPressed: () async {
                            if (_scannerController == null) return;
                            try {
                              await _scannerController!.switchCamera();
                            } catch (_) {}
                          },
                          tooltip: 'Switch Camera',
                        ),
                        IconButton(
                          icon: const Icon(Icons.photo_library_outlined,
                              color: Colors.white, size: 20),
                          onPressed: _pickImageAndScan,
                          tooltip: 'Select Photo to Scan',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Align the printed property QR tag inside the golden reticle.',
            style: TextStyle(fontSize: 11.5, color: ParishColors.textMuted),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // 3. NFC / RFID Sensor Mode
  // ===========================================================================

  Widget _buildNfcReaderView() {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: ParishColors.goldLight,
        borderRadius: BorderRadius.circular(16),
        border:
        Border.all(color: ParishColors.goldAccent.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.nfc, size: 24, color: ParishColors.goldAccent),
                  const SizedBox(width: 8),
                  Text(
                    'NFC / RFID Wireless Sensor Active',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: ParishColors.goldAccent),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: _resetToModeSelection,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.sensors, size: 48, color: ParishColors.goldAccent),
          ),
          const SizedBox(height: 14),
          Text(
            'Hold Device Near 13.56 MHz RFID / NFC Tag',
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 14, color: textDark),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'For sacred metal vessels (chalices, ciboria, monstrances) and consecrated furnishings.',
            style: TextStyle(fontSize: 11.5, color: textMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nfcInputController,
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: 'Or enter RFID Tag UID (e.g. 04:A2:4B:9C)',
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onSubmitted: _searchAndLoadAsset,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ParishColors.goldAccent,
                  foregroundColor: Colors.white,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () =>
                    _searchAndLoadAsset(_nfcInputController.text),
                child: const Text('Read Tag',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 4. Manual Control Number / Asset ID Lookup
  // ===========================================================================

  Widget _buildManualLookupView() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ParishColors.backgroundLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ParishColors.borderGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Manual Diocesan Control Number Lookup',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: _resetToModeSelection,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Type the exact control number stamped or recorded in the Diocesan Book of Inventory.',
            style: TextStyle(fontSize: 11.5, color: ParishColors.textMuted),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _manualInputController,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: 'e.g. C-SI-2008-001 or AST-XXXXX',
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onSubmitted: _searchAndLoadAsset,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ParishColors.marianBlue,
                  foregroundColor: Colors.white,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () =>
                    _searchAndLoadAsset(_manualInputController.text),
                icon: const Icon(Icons.search, size: 16),
                label: const Text('Search',
                    style:
                    TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 5. Verification & Inspection Form (Rendered Once an Asset is Located)
  // ===========================================================================

  Widget _buildAssetAuditVerificationForm() {
    final asset = _scannedAsset!;
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ParishColors.oliveGreen, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: ParishColors.oliveGreen.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: ParishColors.oliveGreen, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Asset Found in Registry',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        color: ParishColors.oliveGreen),
                  ),
                ],
              ),
              TextButton(
                style:
                TextButton.styleFrom(visualDensity: VisualDensity.compact),
                onPressed: () {
                  showAssetDetailModal(context, asset: asset);
                },
                child: const Text('View Full History',
                    style:
                    TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const Divider(height: 18),

          Text(
            asset.itemName,
            style: TextStyle(
                fontSize: 16.5, fontWeight: FontWeight.bold, color: textDark),
          ),
          const SizedBox(height: 4),
          Text(
            'Control #: ${asset.controlNumber} • Location: ${asset.displayLocation}',
            style: TextStyle(fontSize: 12.5, color: textMuted),
          ),
          Text(
            'Classification: ${asset.displayClassification} • Acquired: ${asset.acquisitionYear} (${asset.modeOfAcquisition})',
            style: TextStyle(fontSize: 12, color: textMuted),
          ),
          const SizedBox(height: 16),

          Text(
            'Verified Physical Condition (Update on Inspection):',
            style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.bold, color: textDark),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _selectedCondition,
            isExpanded: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: ParishColors.backgroundLight,
              isDense: true,
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            items: _conditionOptions
                .map((c) => DropdownMenuItem(
                value: c,
                child: Text(c, style: const TextStyle(fontSize: 13))))
                .toList(),
            onChanged: (val) => setState(() => _selectedCondition = val!),
          ),
          const SizedBox(height: 12),

          Text(
            'Auditor Inspection Notes (Optional):',
            style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.bold, color: textDark),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _auditNotesController,
            maxLines: 2,
            style: TextStyle(fontSize: 13, color: textDark),
            decoration: InputDecoration(
              hintText:
              'e.g. Verified physically inside sacristy vault, good condition',
              filled: true,
              fillColor: ParishColors.backgroundLight,
              isDense: true,
              border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }
}