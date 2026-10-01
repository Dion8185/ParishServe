import 'dart:async';
import 'dart:io' show Platform;
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/constants/colors.dart';
import '../../models/asset_model.dart';
import '../../services/asset_service.dart';
import '../../utils/asset_image_watermark_util.dart';
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
  AuditScanMode _lastActiveMode = AuditScanMode.liveCamera;

  final TextEditingController _manualInputController = TextEditingController();
  final TextEditingController _nfcInputController = TextEditingController();
  final TextEditingController _auditNotesController = TextEditingController();

  MobileScannerController? _scannerController;

  bool _isSearching = false;
  String? _searchError;
  String? _successBannerMessage;
  bool _hasProcessedScan = false;
  bool _isTorchOn = false;
  bool _cameraPermissionDenied = false;

  // Autocomplete live suggestion state
  List<AssetModel> _liveSuggestions = [];
  bool _isLoadingSuggestions = false;
  Timer? _debounceTimer;

  // Audit state once an asset is located
  AssetModel? _scannedAsset;
  String _selectedCondition = 'VERIFIED / GOOD';
  String _selectedStatus = 'Active';
  bool _isRecordingAudit = false;

  final List<String> _conditionOptions = [
    'VERIFIED / GOOD',
    'REQUIRES REPAIR',
    'DAMAGED',
    'MISSING',
    'UNUSABLE',
  ];

  final List<String> _operationalStatusOptions = [
    'Active',
    'In Storage',
    'Under Maintenance',
    'Decommissioned',
  ];

  bool get _isLiveCameraSupported {
    if (kIsWeb) return true;
    try {
      return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _manualInputController.addListener(_onManualInputChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _manualInputController.removeListener(_onManualInputChanged);
    _manualInputController.dispose();
    _nfcInputController.dispose();
    _auditNotesController.dispose();
    _safeDisposeScanner();
    super.dispose();
  }

  void _safeDisposeScanner() {
    try {
      _scannerController?.dispose();
    } catch (_) {}
    _scannerController = null;
  }

  void _onManualInputChanged() {
    final query = _manualInputController.text.trim();
    if (query.isEmpty) {
      if (_liveSuggestions.isNotEmpty) {
        setState(() {
          _liveSuggestions = [];
          _isLoadingSuggestions = false;
        });
      }
      return;
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () async {
      if (!mounted) return;
      setState(() => _isLoadingSuggestions = true);

      final results = await AssetService.searchAssetSuggestions(query);
      if (!mounted) return;

      setState(() {
        _liveSuggestions = results;
        _isLoadingSuggestions = false;
      });
    });
  }

  void _startCameraScanner() {
    setState(() {
      _searchError = null;
      _successBannerMessage = null;
      _hasProcessedScan = false;
      _scannedAsset = null;
      _cameraPermissionDenied = false;
      _liveSuggestions = [];
      _safeDisposeScanner();

      if (_isLiveCameraSupported) {
        try {
          _scannerController = MobileScannerController(
            detectionSpeed: DetectionSpeed.normal,
            facing: CameraFacing.back,
            torchEnabled: false,
            autoStart: true,
          );
        } catch (_) {
          _scannerController = null;
        }
      }
      _currentScanMode = AuditScanMode.liveCamera;
      _lastActiveMode = AuditScanMode.liveCamera;
    });
  }

  void _startNfcListener() {
    setState(() {
      _searchError = null;
      _successBannerMessage = null;
      _hasProcessedScan = false;
      _scannedAsset = null;
      _liveSuggestions = [];
      _safeDisposeScanner();
      _currentScanMode = AuditScanMode.nfcListening;
      _lastActiveMode = AuditScanMode.nfcListening;
    });
  }

  void _startManualLookup() {
    setState(() {
      _searchError = null;
      _successBannerMessage = null;
      _hasProcessedScan = false;
      _scannedAsset = null;
      _liveSuggestions = [];
      _safeDisposeScanner();
      _currentScanMode = AuditScanMode.manualEntry;
      _lastActiveMode = AuditScanMode.manualEntry;
    });
  }

  void _resetToModeSelection() {
    setState(() {
      _safeDisposeScanner();
      _currentScanMode = AuditScanMode.selectMode;
      _scannedAsset = null;
      _searchError = null;
      _successBannerMessage = null;
      _hasProcessedScan = false;
      _isSearching = false;
      _cameraPermissionDenied = false;
      _liveSuggestions = [];
      _auditNotesController.clear();
      _manualInputController.clear();
      _nfcInputController.clear();
    });
  }

  void _armForNextScan() {
    setState(() {
      _scannedAsset = null;
      _searchError = null;
      _hasProcessedScan = false;
      _isSearching = false;
      _liveSuggestions = [];
      _auditNotesController.clear();
      _manualInputController.clear();
      _nfcInputController.clear();
    });

    if (_lastActiveMode == AuditScanMode.liveCamera) {
      _startCameraScanner();
    } else if (_lastActiveMode == AuditScanMode.nfcListening) {
      _startNfcListener();
    } else {
      _startManualLookup();
    }
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
      _successBannerMessage = null;
      _scannedAsset = null;
      _liveSuggestions = [];
    });

    try {
      final asset = await AssetService.findAssetByIdentifier(clean);
      if (!mounted) return;

      if (asset != null) {
        _safeDisposeScanner();
        setState(() {
          _scannedAsset = asset;
          _selectedCondition = asset.conditionStatus;
          _selectedStatus = asset.operationalStatus;
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

    final completedControlNo = _scannedAsset!.controlNumber;
    final verifiedCondition = _selectedCondition;
    final verifiedStatus = _selectedStatus;
    final isDecom = verifiedStatus.trim().toLowerCase() == 'decommissioned';

    try {
      await AssetService.recordAuditScan(
        assetId: _scannedAsset!.assetId,
        controlNumber: completedControlNo,
        newCondition: verifiedCondition,
        previousCondition: _scannedAsset!.conditionStatus,
        newStatus: verifiedStatus,
        previousStatus: _scannedAsset!.operationalStatus,
        previousLocation: _scannedAsset!.displayLocation,
        newLocation: _scannedAsset!.displayLocation,
        auditMethod: method,
        auditNotes: _auditNotesController.text.trim(),
      );

      if (!mounted) return;

      widget.onScanCompleted?.call();

      setState(() {
        _isRecordingAudit = false;
        _scannedAsset = null;
        _hasProcessedScan = false;
        _searchError = null;
        _liveSuggestions = [];
        _auditNotesController.clear();
        _manualInputController.clear();
        _nfcInputController.clear();
        _successBannerMessage = isDecom
            ? 'Audit saved: $completedControlNo verified as $verifiedCondition & marked Decommissioned (Archived).'
            : 'Audit saved for $completedControlNo: $verifiedCondition • Status: $verifiedStatus.';
      });

      if (_lastActiveMode == AuditScanMode.liveCamera) {
        _startCameraScanner();
      } else if (_lastActiveMode == AuditScanMode.nfcListening) {
        _startNfcListener();
      } else {
        _startManualLookup();
      }
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: Container(
        width: 640,
        constraints: const BoxConstraints(maxHeight: 760),
        child: Column(
          children: [
            // Modal Header Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mobile Field Audit & Verification',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textDark),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Continuous audit workflow: Scan or enter subsequent assets seamlessly',
                          style: TextStyle(fontSize: 11, color: textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Modal Body Area
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Persistent Success Banner after submitting previous item
                    if (_successBannerMessage != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: ParishColors.oliveGreenSurface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: ParishColors.oliveGreen
                                  .withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle,
                                color: ParishColors.oliveGreen, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _successBannerMessage!,
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: ParishColors.oliveGreen),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              color: ParishColors.oliveGreen,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => setState(
                                      () => _successBannerMessage = null),
                            ),
                          ],
                        ),
                      ),
                    ],

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
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
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
                      icon: const Icon(Icons.swap_horiz, size: 16),
                      label: const Text('Change Mode'),
                    )
                  else
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Finish & Close',
                          style: TextStyle(
                              color: textMuted, fontWeight: FontWeight.bold)),
                    ),

                  if (_scannedAsset != null)
                    Row(
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: borderGrey),
                            foregroundColor: textDark,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                          ),
                          onPressed: _armForNextScan,
                          icon: const Icon(Icons.skip_next, size: 16),
                          label: const Text('Skip / Next'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ParishColors.oliveGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
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
                            _isRecordingAudit ? 'Saving...' : 'Save & Next',
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
  // 1. Mode Selection Grid
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
          'Choose your scanning tool. Once an audit is saved, the scanner stays active to verify the next item seamlessly.',
          style: TextStyle(fontSize: 12, color: textMuted),
        ),
        const SizedBox(height: 14),

        _buildMethodCard(
          title: 'Camera QR Code Scanner',
          subtitle:
          'Rapid optical scanning for printed physical QR stickers on furniture, equipment, and books.',
          icon: Icons.camera_alt_outlined,
          badgeLabel: 'RAPID SCAN',
          badgeColor: ParishColors.marianBlue,
          onTap: _startCameraScanner,
        ),
        const SizedBox(height: 10),

        _buildMethodCard(
          title: 'NFC / RFID Wireless Sensor',
          subtitle:
          'Continuous tag detection for sacred metal vessels and high-value parish furnishings.',
          icon: Icons.nfc,
          badgeLabel: 'WIRELESS',
          badgeColor: ParishColors.goldAccent,
          onTap: _startNfcListener,
        ),
        const SizedBox(height: 10),

        _buildMethodCard(
          title: 'Manual Control # & Token',
          subtitle:
          'Lookup by Diocesan Control # (e.g. C-SI-2008-001) with live matching suggestions as you type.',
          icon: Icons.keyboard_outlined,
          badgeLabel: 'MANUAL',
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: ParishColors.backgroundLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderGrey),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
              ),
              child: Icon(icon, color: badgeColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: textDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badgeLabel,
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                            color: badgeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: textMuted),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.arrow_forward_ios, size: 12, color: borderGrey),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 2. Camera Viewfinder with Native Desktop / Windows Fallback Handling
  // ===========================================================================

  Widget _buildLiveCameraScannerView() {
    if (!_isLiveCameraSupported) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ParishColors.borderGrey),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.desktop_windows_outlined,
                size: 44, color: ParishColors.marianBlueLight),
            const SizedBox(height: 10),
            const Text(
              'Desktop Environment Detected',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              'Live camera streaming in Flutter is optimized for Android, iOS, macOS, and Web. On Windows, you can scan QR codes from saved photos or use an attached USB/Bluetooth barcode scanner directly into the field below.',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75), fontSize: 11.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ParishColors.marianBlue,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _pickImageAndScan,
                  icon: const Icon(Icons.image, size: 18),
                  label: const Text('Select Image with QR Code'),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white70),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _startManualLookup,
                  icon: const Icon(Icons.keyboard, size: 18),
                  label: const Text('Type / USB Scan Control #'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Icon(Icons.videocam_outlined,
                      color: ParishColors.marianBlue, size: 18),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Live Camera Scanner Active',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: ParishColors.marianBlue,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: _resetToModeSelection,
              icon: const Icon(Icons.close, size: 14),
              label: const Text('Switch Mode', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 270,
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
                                size: 40,
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
                                    fontSize: 13.5),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                isPermission
                                    ? 'Camera access was not granted. Please allow camera permissions in your device settings.'
                                    : 'Camera stream notice: ${error.errorDetails?.message ?? error.toString()}',
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.75),
                                    fontSize: 11),
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
                                    label: const Text('Retry'),
                                  ),
                                  const SizedBox(width: 8),
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
                  width: 170,
                  height: 170,
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
        const SizedBox(height: 6),
        Center(
          child: Text(
            'Scan any asset QR label. Audit form opens automatically.',
            style: TextStyle(fontSize: 11, color: ParishColors.textMuted),
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
      padding: const EdgeInsets.all(18),
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
                  Icon(Icons.nfc, size: 22, color: ParishColors.goldAccent),
                  const SizedBox(width: 8),
                  Text(
                    'NFC / RFID Wireless Sensor Active',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: ParishColors.goldAccent),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: _resetToModeSelection,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.sensors, size: 42, color: ParishColors.goldAccent),
          ),
          const SizedBox(height: 12),
          Text(
            'Hold Device Near 13.56 MHz RFID / NFC Tag',
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 13.5, color: textDark),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'For sacred metal vessels (chalices, ciboria) and consecrated furnishings.',
            style: TextStyle(fontSize: 11, color: textMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nfcInputController,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold),
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
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () =>
                    _searchAndLoadAsset(_nfcInputController.text),
                child: const Text('Read Tag',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 4. Manual Control Number Lookup with Live Autocomplete Suggestions
  // ===========================================================================

  Widget _buildManualLookupView() {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final borderGrey = ParishColors.borderGrey;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ParishColors.backgroundLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Manual Control Number / USB Scanner',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: _resetToModeSelection,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Type to see matching assets instantly, or use an attached barcode reader.',
            style: TextStyle(fontSize: 11, color: textMuted),
          ),
          const SizedBox(height: 10),

          // Search Field
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _manualInputController,
                  autofocus: true,
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: 'e.g. C-SI-2008-001 or Pew',
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    suffixIcon: _isLoadingSuggestions
                        ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                        : (_manualInputController.text.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        _manualInputController.clear();
                        setState(() => _liveSuggestions = []);
                      },
                    )
                        : null),
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
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () =>
                    _searchAndLoadAsset(_manualInputController.text),
                icon: const Icon(Icons.search, size: 16),
                label: const Text('Search',
                    style:
                    TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
              ),
            ],
          ),

          // Real-time Matching Autocomplete Suggestions Container
          if (_liveSuggestions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ParishColors.marianBlue.withValues(alpha: 0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _liveSuggestions.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final suggestion = _liveSuggestions[index];

                  return InkWell(
                    onTap: () {
                      _manualInputController.text = suggestion.controlNumber;
                      _searchAndLoadAsset(suggestion.controlNumber);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          Icon(suggestion.classificationIcon,
                              size: 16, color: ParishColors.marianBlue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      suggestion.controlNumber,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: ParishColors.marianBlue,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        '• ${suggestion.itemName}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                          color: textDark,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  'Loc: ${suggestion.displayLocation} • ${suggestion.conditionStatus}',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_ios,
                              size: 10, color: Colors.grey),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // 5. Verification & Inspection Form: Displays Reference Image + Fields
  // ===========================================================================

  Widget _buildAssetAuditVerificationForm() {
    final asset = _scannedAsset!;
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final borderGrey = ParishColors.borderGrey;
    final isDecom = _selectedStatus == 'Decommissioned';

    return Container(
      padding: const EdgeInsets.all(16),
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
                      color: ParishColors.oliveGreen, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    'Asset Found in Registry',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
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
                    TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const Divider(height: 16),

          // Photo & Details Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo Thumbnail with Watermarked Preview on Tap
              Tooltip(
                message: asset.photoUrl != null && asset.photoUrl!.isNotEmpty
                    ? 'Tap to preview photo with security watermark'
                    : 'No photo uploaded',
                child: InkWell(
                  onTap: asset.photoUrl != null && asset.photoUrl!.isNotEmpty
                      ? () => AssetImageWatermarkUtil.showImagePreviewModal(
                    context,
                    imageProvider: NetworkImage(asset.photoUrl!),
                    title: asset.itemName,
                    controlNumber: asset.controlNumber,
                  )
                      : null,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: ParishColors.backgroundLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: asset.photoUrl != null
                            ? ParishColors.goldAccent
                            : borderGrey,
                        width: asset.photoUrl != null ? 1.5 : 1.0,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: asset.photoUrl != null && asset.photoUrl!.isNotEmpty
                          ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            asset.photoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                              child: Icon(asset.classificationIcon,
                                  size: 28,
                                  color: ParishColors.marianBlue),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              color: Colors.black54,
                              padding:
                              const EdgeInsets.symmetric(vertical: 2),
                              child: const Text(
                                'PREVIEW',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 6.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                          : Center(
                        child: Icon(asset.classificationIcon,
                            size: 32, color: ParishColors.marianBlue),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Asset Description Metadata
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      asset.itemName,
                      style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                          color: textDark),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Control #: ${asset.controlNumber}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: ParishColors.marianBlue),
                    ),
                    Text(
                      'Location: ${asset.displayLocation}',
                      style: TextStyle(fontSize: 11.5, color: textMuted),
                    ),
                    Text(
                      'Classification: ${asset.displayClassification}',
                      style: TextStyle(fontSize: 11.5, color: textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Audit Field 1: Physical Condition Dropdown
          Text(
            '1. Verified Physical Condition (Inspect On-Site) *',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: textDark),
          ),
          const SizedBox(height: 5),
          DropdownButtonFormField<String>(
            value: _selectedCondition,
            isExpanded: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: ParishColors.backgroundLight,
              isDense: true,
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            items: _conditionOptions
                .map((c) => DropdownMenuItem(
                value: c,
                child: Text(c, style: const TextStyle(fontSize: 12.5))))
                .toList(),
            onChanged: (val) => setState(() => _selectedCondition = val!),
          ),
          const SizedBox(height: 12),

          // Audit Field 2: Operational Status Dropdown
          Text(
            '2. Verified Operational / Administrative Status *',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: textDark),
          ),
          const SizedBox(height: 5),
          DropdownButtonFormField<String>(
            value: _selectedStatus,
            isExpanded: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: ParishColors.backgroundLight,
              isDense: true,
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            items: _operationalStatusOptions
                .map((s) => DropdownMenuItem(
                value: s,
                child: Text(
                  s == 'Decommissioned'
                      ? 'Decommissioned (Transfers to Archive)'
                      : s,
                  style: const TextStyle(fontSize: 12.5),
                  overflow: TextOverflow.ellipsis,
                )))
                .toList(),
            onChanged: (val) => setState(() => _selectedStatus = val!),
          ),
          if (isDecom) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ParishColors.mercyRedSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: ParishColors.mercyRed.withValues(alpha: 0.4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 16, color: ParishColors.mercyRed),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Warning: Confirming "Decommissioned" status will move this asset to the Archive quarantine upon saving.',
                      style: TextStyle(
                          fontSize: 11,
                          color: ParishColors.mercyRed,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Audit Field 3: Inspection Notes
          Text(
            '3. Auditor Inspection Notes (Optional):',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: textDark),
          ),
          const SizedBox(height: 5),
          TextField(
            controller: _auditNotesController,
            maxLines: 2,
            style: TextStyle(fontSize: 12.5, color: textDark),
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