// =============================================================================
// FILE: lib/features/asset_inventory/presentation/dialogs/audit_scan_dialog.dart
// =============================================================================

import 'dart:async';
import 'dart:io' show Platform;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/constants/colors.dart';
import '../../models/asset_model.dart';
import '../../services/asset_service.dart';
import '../../utils/asset_image_watermark_util.dart';
import '../../utils/web_camera_helper.dart';

void showAuditScanModal(BuildContext context, {VoidCallback? onScanCompleted}) {
  showDialog(
    context: context,
    builder: (ctx) => _AuditScanDialog(onScanCompleted: onScanCompleted),
  );
}

enum AuditScanMode { selectMode, liveCamera, nfcListening, manualEntry }

class _AuditScanDialog extends StatefulWidget {
  final VoidCallback? onScanCompleted;

  const _AuditScanDialog({super.key, this.onScanCompleted});

  @override
  State<_AuditScanDialog> createState() => _AuditScanDialogState();
}

class _AuditScanDialogState extends State<_AuditScanDialog> {
  AuditScanMode _currentScanMode = AuditScanMode.selectMode;
  AuditScanMode _lastActiveMode = AuditScanMode.liveCamera;

  final TextEditingController _manualInputController = TextEditingController();
  final TextEditingController _nfcInputController = TextEditingController();
  final TextEditingController _auditNotesController = TextEditingController();
  final TextEditingController _quantityChangeReasonController =
      TextEditingController();
  final TextEditingController _quantityInputController =
      TextEditingController();

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
  String _selectedStatus = 'Available';
  int _auditQuantity = 1;
  bool _isRecordingAudit = false;

  final List<String> _conditionOptions = [
    'VERIFIED / GOOD',
    'REQUIRES REPAIR',
    'DAMAGED',
    'MISSING',
    'UNUSABLE',
  ];

  final List<String> _operationalStatusOptions = [
    'Available',

    'In Storage',
    'Under Maintenance',
    'Damaged',
    'Missing',
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

  int get _quantityDifference {
    if (_scannedAsset == null) return 0;
    return _auditQuantity - _scannedAsset!.quantity;
  }

  @override
  void initState() {
    super.initState();
    _manualInputController.addListener(_onManualInputChanged);
    _initScannerController();
  }

  void _initScannerController() {
    if (!_isLiveCameraSupported) return;
    try {
      _scannerController ??= MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
        torchEnabled: false,
        autoStart: false,
      );
    } catch (e) {
      debugPrint('Error initializing MobileScannerController: $e');
    }
  }

  @override
  void deactivate() {
    _safeStopCamera();
    super.deactivate();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _manualInputController.removeListener(_onManualInputChanged);
    _manualInputController.dispose();
    _nfcInputController.dispose();
    _auditNotesController.dispose();
    _quantityChangeReasonController.dispose();
    _quantityInputController.dispose();

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

    // Explicitly release browser media stream tracks on Flutter Web
    WebCameraHelper.releaseCamera();

    if (mounted) {
      setState(() => _isTorchOn = false);
    }
  }

  Future<void> _safeStartCamera() async {
    if (!_isLiveCameraSupported) return;
    _initScannerController();
    try {
      if (_scannerController != null) {
        try {
          if (!_scannerController!.value.isRunning) {
            await _scannerController!.start();
          }
        } catch (_) {
          await _scannerController!.start();
        }
      }
    } catch (e) {
      debugPrint('Error starting camera in dialog: $e');
    }
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

  String _normalizeStatus(String raw) {
    final clean = raw.trim();
    if (clean.toLowerCase() == 'active') return 'Available';
    for (final opt in _operationalStatusOptions) {
      if (opt.toLowerCase() == clean.toLowerCase()) return opt;
    }
    return 'Available';
  }

  Future<void> _startCameraScanner() async {
    setState(() {
      _searchError = null;
      _successBannerMessage = null;
      _hasProcessedScan = false;
      _scannedAsset = null;
      _cameraPermissionDenied = false;
      _liveSuggestions = [];
      _currentScanMode = AuditScanMode.liveCamera;
      _lastActiveMode = AuditScanMode.liveCamera;
    });

    await _safeStartCamera();
  }

  Future<void> _startNfcListener() async {
    // Unmount scanner first, then power down sensor
    setState(() {
      _searchError = null;
      _successBannerMessage = null;
      _hasProcessedScan = false;
      _scannedAsset = null;
      _liveSuggestions = [];
      _currentScanMode = AuditScanMode.nfcListening;
      _lastActiveMode = AuditScanMode.nfcListening;
    });

    await _safeStopCamera();
  }

  Future<void> _startManualLookup() async {
    // Unmount scanner first, then power down sensor
    setState(() {
      _searchError = null;
      _successBannerMessage = null;
      _hasProcessedScan = false;
      _scannedAsset = null;
      _liveSuggestions = [];
      _currentScanMode = AuditScanMode.manualEntry;
      _lastActiveMode = AuditScanMode.manualEntry;
    });

    await _safeStopCamera();
  }

  Future<void> _resetToModeSelection() async {
    setState(() {
      _currentScanMode = AuditScanMode.selectMode;
      _scannedAsset = null;
      _searchError = null;
      _successBannerMessage = null;
      _hasProcessedScan = false;
      _isSearching = false;
      _cameraPermissionDenied = false;
      _liveSuggestions = [];
      _auditNotesController.clear();
      _quantityChangeReasonController.clear();
      _manualInputController.clear();
      _nfcInputController.clear();
    });

    await _safeStopCamera();
  }

  void _armForNextScan() {
    setState(() {
      _scannedAsset = null;
      _searchError = null;
      _hasProcessedScan = false;
      _isSearching = false;
      _liveSuggestions = [];
      _auditNotesController.clear();
      _quantityChangeReasonController.clear();
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

    // Transition state immediately so scanner view unmounts cleanly
    setState(() {
      _isSearching = true;
      _searchError = null;
      _successBannerMessage = null;
      _scannedAsset = null;
      _liveSuggestions = [];
    });

    // Safely stop camera preview while inspecting specs
    await _safeStopCamera();

    try {
      final asset = await AssetService.findAssetByIdentifier(clean);
      if (!mounted) return;

      if (asset != null) {
        setState(() {
          _scannedAsset = asset;
          _selectedCondition = asset.conditionStatus;
          _selectedStatus = _normalizeStatus(asset.operationalStatus);
          _auditQuantity = asset.quantity;
          _quantityInputController.text = '${asset.quantity}';
          _quantityChangeReasonController.clear();
          _isSearching = false;
        });
      } else {
        setState(() {
          _searchError =
              'No item record found for "$clean". Please check the Control Number, RFID tag, or QR Code.';
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
            _initScannerController();
            if (_scannerController != null) {
              final BarcodeCapture? capture = await _scannerController!
                  .analyzeImage(filePath);
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
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No clear QR code detected in the selected image. Please try another photo.',
            ),
            backgroundColor: ParishColors.goldAccent,
          ),
        );
      }
    } catch (e) {
      debugPrint('QR image pick error: $e');
    }
  }

  Future<void> _commitAuditInspection(String method) async {
    if (_scannedAsset == null) return;

    final int previousQty = _scannedAsset!.quantity;
    final int newQty = _auditQuantity;
    final int qtyChange = newQty - previousQty;

    if (qtyChange != 0 && _quantityChangeReasonController.text.trim().isEmpty) {
      setState(() {
        _searchError =
            'Please provide a reason for the quantity change (${qtyChange > 0 ? "+$qtyChange" : "$qtyChange"} units).';
      });
      return;
    }

    setState(() => _isRecordingAudit = true);

    final asset = _scannedAsset!;
    final completedControlNo = asset.controlNumber;
    final verifiedCondition = _selectedCondition;
    final verifiedStatus = _selectedStatus;
    final isDecom = verifiedStatus.trim().toLowerCase() == 'decommissioned';

    try {
      await AssetService.recordAuditScan(
        assetId: asset.assetId,
        controlNumber: completedControlNo,
        newCondition: verifiedCondition,
        previousCondition: asset.conditionStatus,
        newStatus: verifiedStatus,
        previousStatus: asset.operationalStatus,
        previousLocation: asset.displayLocation,
        newLocation: asset.displayLocation,
        auditMethod: method,
        auditNotes: _auditNotesController.text.trim(),
        previousQuantity: previousQty,
        newQuantity: newQty,
        quantityChangeReason: _quantityChangeReasonController.text.trim(),
      );

      if (!mounted) return;

      widget.onScanCompleted?.call();

      String qtySummary = '$newQty units';
      if (qtyChange != 0) {
        qtySummary =
            '$newQty units (${qtyChange > 0 ? "+$qtyChange" : "$qtyChange"})';
      }

      setState(() {
        _isRecordingAudit = false;
        _scannedAsset = null;
        _hasProcessedScan = false;
        _searchError = null;
        _liveSuggestions = [];
        _auditNotesController.clear();
        _quantityChangeReasonController.clear();
        _manualInputController.clear();
        _nfcInputController.clear();
        _successBannerMessage = isDecom
            ? 'Audit saved: $completedControlNo verified as $verifiedCondition and marked as Decommissioned.'
            : 'Audit saved for $completedControlNo: $qtySummary • $verifiedCondition • Status: $verifiedStatus.';
      });

      if (_lastActiveMode == AuditScanMode.liveCamera) {
        await _startCameraScanner();
      } else if (_lastActiveMode == AuditScanMode.nfcListening) {
        await _startNfcListener();
      } else {
        await _startManualLookup();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searchError = 'Failed to save audit record: $e';
        _isRecordingAudit = false;
      });
    }
  }

  Future<void> _handleModalDismiss() async {
    if (mounted) {
      setState(() => _currentScanMode = AuditScanMode.selectMode);
    }
    await _safeStopCamera();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final cardWhite = ParishColors.cardWhite;
    final borderGrey = ParishColors.borderGrey;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleModalDismiss();
      },
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: cardWhite,
        insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Container(
          width: 720,
          constraints: const BoxConstraints(maxHeight: 820),
          child: Column(
            children: [
              // Header Banner
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: ParishColors.marianBlueSurface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  border: Border(bottom: BorderSide(color: borderGrey)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: ParishColors.marianBlue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.qr_code_scanner,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Inventory Item Audit',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Verify item condition, current status, and track quantity changes',
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
                      onPressed: _handleModalDismiss,
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
                      if (_successBannerMessage != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: ParishColors.oliveGreenSurface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: ParishColors.oliveGreen.withValues(
                                alpha: 0.4,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: ParishColors.oliveGreen,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _successBannerMessage!,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: ParishColors.oliveGreen,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 16),
                                color: ParishColors.oliveGreen,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => setState(
                                  () => _successBannerMessage = null,
                                ),
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
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: ParishColors.mercyRed,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _searchError!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: ParishColors.mercyRed,
                                  ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: cardWhite,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
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
                        onPressed: _handleModalDismiss,
                        child: Text(
                          'Finish & Close',
                          style: TextStyle(
                            color: textMuted,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                    if (_scannedAsset != null)
                      Row(
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: borderGrey),
                              foregroundColor: textDark,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                            ),
                            onPressed: _armForNextScan,
                            icon: const Icon(Icons.skip_next, size: 16),
                            label: const Text('Next Item'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ParishColors.oliveGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: _isRecordingAudit
                                ? null
                                : () => _commitAuditInspection(
                                    _currentScanMode ==
                                            AuditScanMode.nfcListening
                                        ? 'RFID_NFC'
                                        : 'QR_SCAN',
                                  ),
                            icon: _isRecordingAudit
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.check_circle_outline,
                                    size: 18,
                                  ),
                            label: Text(
                              _isRecordingAudit ? 'Saving...' : 'Save Audit',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
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
          'Choose Audit Method',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: textDark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Select your scanning tool to inspect parish properties.',
          style: TextStyle(fontSize: 12, color: textMuted),
        ),
        const SizedBox(height: 14),

        _buildMethodCard(
          title: 'QR Code Camera Scanner',
          subtitle: 'Scan printed QR stickers on items using your camera.',
          icon: Icons.camera_alt_outlined,
          badgeLabel: 'CAMERA',
          badgeColor: ParishColors.marianBlue,
          onTap: _startCameraScanner,
        ),
        const SizedBox(height: 10),

        _buildMethodCard(
          title: 'Wireless RFID / NFC Sensor',
          subtitle:
              'Detect wireless RFID or NFC tags on metal vessels and furnishings.',
          icon: Icons.nfc,
          badgeLabel: 'WIRELESS',
          badgeColor: ParishColors.goldAccent,
          onTap: _startNfcListener,
        ),
        const SizedBox(height: 10),

        _buildMethodCard(
          title: 'Control Number Search',
          subtitle:
              'Search directly by Control Number or item name with instant suggestions.',
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
                          horizontal: 5,
                          vertical: 1.5,
                        ),
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
  // 2. Camera Viewfinder
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
            const Icon(
              Icons.desktop_windows_outlined,
              size: 44,
              color: ParishColors.marianBlueLight,
            ),
            const SizedBox(height: 10),
            const Text(
              'Desktop Environment Detected',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Upload a QR photo or use the Control Number search to audit items.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 11.5,
              ),
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
                  label: const Text('Upload QR Photo'),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white70),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _startManualLookup,
                  icon: const Icon(Icons.keyboard, size: 18),
                  label: const Text('Search by Number'),
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
            const Row(
              children: [
                Icon(
                  Icons.videocam_outlined,
                  color: ParishColors.marianBlue,
                  size: 18,
                ),
                SizedBox(width: 6),
                Text(
                  'Camera Scanner Active',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: ParishColors.marianBlue,
                  ),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: _resetToModeSelection,
              icon: const Icon(Icons.close, size: 14),
              label: const Text('Change Mode', style: TextStyle(fontSize: 12)),
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
                      return Container(
                        color: const Color(0xFF0F172A),
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.no_photography_outlined,
                                size: 40,
                                color: ParishColors.mercyRed,
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Camera Unavailable',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 14),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: ParishColors.marianBlue,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: _pickImageAndScan,
                                icon: const Icon(Icons.image, size: 16),
                                label: const Text('Upload QR Photo'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                // Center Reticle
                Container(
                  width: 170,
                  height: 170,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: ParishColors.goldAccent,
                      width: 2.5,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),

                Positioned(
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
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
                              setState(() => _isTorchOn = !_isTorchOn);
                            } catch (_) {}
                          },
                          tooltip: 'Flashlight',
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.cameraswitch,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () async {
                            if (_scannerController == null) return;
                            try {
                              await _scannerController!.switchCamera();
                            } catch (_) {}
                          },
                          tooltip: 'Switch Camera',
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.photo_library_outlined,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: _pickImageAndScan,
                          tooltip: 'Upload QR Photo',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
        border: Border.all(
          color: ParishColors.goldAccent.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.nfc, size: 22, color: ParishColors.goldAccent),
                  SizedBox(width: 8),
                  Text(
                    'Wireless Sensor Active',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: ParishColors.goldAccent,
                    ),
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
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.sensors,
              size: 42,
              color: ParishColors.goldAccent,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Hold Device Near Wireless Tag',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13.5,
              color: textDark,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'For items attached with RFID or NFC tags.',
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
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. 04:A2:4B:9C',
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onSubmitted: _searchAndLoadAsset,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ParishColors.goldAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => _searchAndLoadAsset(_nfcInputController.text),
                child: const Text(
                  'Find Tag',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 4. Manual Control Number Lookup
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
                'Search by Control Number or Name',
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
            'Enter the Control Number or item name to locate it directly.',
            style: TextStyle(fontSize: 11, color: textMuted),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _manualInputController,
                  autofocus: true,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. C-FF 2026-001 or Church Pew',
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () =>
                    _searchAndLoadAsset(_manualInputController.text),
                icon: const Icon(Icons.search, size: 16),
                label: const Text(
                  'Search',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          if (_liveSuggestions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: ParishColors.marianBlue.withValues(alpha: 0.3),
                ),
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
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            suggestion.classificationIcon,
                            size: 16,
                            color: ParishColors.marianBlue,
                          ),
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
                                  'Location: ${suggestion.displayLocation} • Qty: ${suggestion.quantity} • ${suggestion.conditionStatus}',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
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
  // 5. Complete Inline Specifications & Audit Verification Form
  // ===========================================================================

  Widget _buildAssetAuditVerificationForm() {
    final asset = _scannedAsset!;
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final borderGrey = ParishColors.borderGrey;

    final int qtyDiff = _quantityDifference;

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
          // Header Banner
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: ParishColors.oliveGreen,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Item Found in Registry',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: ParishColors.oliveGreen,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: ParishColors.marianBlueSurface,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${asset.quantity} unit(s) registered',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: ParishColors.marianBlue,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 18),

          // COMPLETE SPECIFICATIONS PANEL
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (asset.photoUrl != null && asset.photoUrl!.isNotEmpty) ...[
                InkWell(
                  onTap: () {
                    AssetImageWatermarkUtil.showImagePreviewModal(
                      context,
                      imageProvider: NetworkImage(asset.photoUrl!),
                      title: asset.itemName,
                      controlNumber: asset.controlNumber,
                    );
                  },
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderGrey),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: Image.network(asset.photoUrl!, fit: BoxFit.cover),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      asset.itemName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          'Control No: ${asset.controlNumber}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: ParishColors.marianBlue,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: asset.conditionSurfaceColor,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            asset.conditionStatus,
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                              color: asset.conditionColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Category: ${asset.displayClassification} • Location: ${asset.displayLocation}',
                      style: TextStyle(fontSize: 11.5, color: textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Detailed Specs Grid
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ParishColors.backgroundLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderGrey),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildSpecItem(
                        'Current Status',
                        asset.operationalStatus,
                      ),
                    ),
                    Expanded(
                      child: _buildSpecItem(
                        'Acquisition Date',
                        '${asset.formattedAcquisitionDate} (${asset.modeOfAcquisition})',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildSpecItem(
                        'Size / Dimensions',
                        asset.dimensions ?? '—',
                      ),
                    ),
                    Expanded(
                      child: _buildSpecItem('Color', asset.color ?? '—'),
                    ),
                    Expanded(
                      child: _buildSpecItem(
                        'Brand / Model',
                        asset.model ?? '—',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildSpecItem(
                        'Unit Price',
                        asset.formattedUnitPrice,
                      ),
                    ),
                    Expanded(
                      child: _buildSpecItem(
                        'Total Value',
                        asset.formattedTotalCost,
                      ),
                    ),
                    if (asset.rfidTag != null && asset.rfidTag!.isNotEmpty)
                      Expanded(
                        child: _buildSpecItem('RFID Tag', asset.rfidTag!),
                      ),
                  ],
                ),
                if (asset.others != null && asset.others!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Markings / Details: ${asset.others}',
                    style: TextStyle(fontSize: 11, color: textDark),
                  ),
                ],
                if (asset.remarks != null && asset.remarks!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Notes: ${asset.remarks}',
                    style: TextStyle(fontSize: 11, color: textMuted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 1. QUANTITY ADJUSTMENT TRACKING
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ParishColors.cardWhite,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: qtyDiff != 0 ? ParishColors.goldAccent : borderGrey,
                width: qtyDiff != 0 ? 1.5 : 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Quantity Count & Adjustments',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: ParishColors.marianBlue,
                      ),
                    ),
                    if (qtyDiff != 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: qtyDiff > 0
                              ? ParishColors.oliveGreenSurface
                              : ParishColors.mercyRedSurface,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          qtyDiff > 0
                              ? '+$qtyDiff units added'
                              : '$qtyDiff units deducted',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: qtyDiff > 0
                                ? ParishColors.oliveGreen
                                : ParishColors.mercyRed,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Previous: ${asset.quantity} units',
                            style: TextStyle(fontSize: 11, color: textMuted),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Updated Total: $_auditQuantity units',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: qtyDiff != 0
                                  ? ParishColors.marianBlue
                                  : textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: ParishColors.backgroundLight,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.remove, size: 16),
                          onPressed: _auditQuantity > 0
                              ? () => setState(() {
                                  _auditQuantity--;
                                  _quantityInputController.text =
                                      '$_auditQuantity';
                                })
                              : null,
                        ),
                        SizedBox(
                          width: 50,
                          child: TextField(
                            controller: _quantityInputController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 8),
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (val) {
                              final parsed = int.tryParse(val.trim());
                              if (parsed != null && parsed >= 0) {
                                setState(() => _auditQuantity = parsed);
                              }
                            },
                          ),
                        ),
                        IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: ParishColors.backgroundLight,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.add, size: 16),
                          onPressed: () => setState(() {
                            _auditQuantity++;
                            _quantityInputController.text = '$_auditQuantity';
                          }),
                        ),
                      ],
                    ),
                  ],
                ),

                // Accountability Reason Required if Quantity Changed
                if (qtyDiff != 0) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Reason for Quantity Change *',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _quantityChangeReasonController,
                    decoration: const InputDecoration(
                      hintText:
                          'e.g. 2 units damaged during parish event, or new donation received',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 2. ITEM STATUS & CONDITION
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verified Condition *',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: _selectedCondition,
                      isExpanded: true,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: ParishColors.backgroundLight,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: _conditionOptions
                          .map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Text(
                                c,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _selectedCondition = val!),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Item Status *',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: _selectedStatus,
                      isExpanded: true,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: ParishColors.backgroundLight,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: _operationalStatusOptions
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text(
                                s,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _selectedStatus = val!),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3. INSPECTION NOTES
          Text(
            'Inspection Notes (Optional)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: textDark,
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _auditNotesController,
            maxLines: 2,
            style: TextStyle(fontSize: 12.5, color: textDark),
            decoration: InputDecoration(
              hintText:
                  'e.g. Verified in church sacristy, clean and ready for use',
              filled: true,
              fillColor: ParishColors.backgroundLight,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: ParishColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: ParishColors.textDark,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
