// =============================================================================
// FILE: lib/features/asset_inventory/presentation/pages/asset_audit_scanner_page.dart
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

enum AuditScanMode { selectMode, liveCamera, nfcListening, manualEntry }

class AssetAuditScannerPage extends StatefulWidget {
  final VoidCallback? onScanCompleted;

  const AssetAuditScannerPage({super.key, this.onScanCompleted});

  @override
  State<AssetAuditScannerPage> createState() => _AssetAuditScannerPageState();
}

class _AssetAuditScannerPageState extends State<AssetAuditScannerPage> {
  AuditScanMode _currentScanMode = AuditScanMode.liveCamera;
  AuditScanMode _lastActiveMode = AuditScanMode.liveCamera;

  final TextEditingController _manualInputController = TextEditingController();
  final TextEditingController _nfcInputController = TextEditingController();
  final TextEditingController _auditNotesController = TextEditingController();
  final TextEditingController _quantityChangeReasonController = TextEditingController();
  final TextEditingController _quantityInputController = TextEditingController();

  MobileScannerController? _scannerController;

  bool _isSearching = false;
  String? _searchError;
  String? _successBannerMessage;
  bool _hasProcessedScan = false;
  bool _isTorchOn = false;
  bool _cameraPermissionDenied = false;

  List<AssetModel> _liveSuggestions = [];
  bool _isLoadingSuggestions = false;
  Timer? _debounceTimer;

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
    'In Use',
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
    _safeStartCamera();
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
      debugPrint('Error creating MobileScannerController: $e');
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
      debugPrint('Error starting camera: $e');
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
    setState(() {
      _searchError = null;
      _hasProcessedScan = false;
      _scannedAsset = null;
      _liveSuggestions = [];
      _currentScanMode = AuditScanMode.nfcListening;
      _lastActiveMode = AuditScanMode.nfcListening;
    });

    await _safeStopCamera();
  }

  Future<void> _startManualLookup() async {
    setState(() {
      _searchError = null;
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

    // Unmount scanner widget before killing camera hardware
    setState(() {
      _isSearching = true;
      _searchError = null;
      _successBannerMessage = null;
      _scannedAsset = null;
      _liveSuggestions = [];
    });

    // Stop camera and release tracks so the camera turns off
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
          _searchError = 'No item record found for "$clean". Please check the Control Number, RFID tag, or QR Code.';
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
              final BarcodeCapture? capture = await _scannerController!.analyzeImage(filePath);
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
            content: Text('No clear QR code detected in the selected image. Please try another photo.'),
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
        _searchError = 'Please provide a reason for the quantity change (${qtyChange > 0 ? "+$qtyChange" : "$qtyChange"} units).';
      });
      return;
    }

    setState(() => _isRecordingAudit = true);

    final asset = _scannedAsset!;
    final completedControlNo = asset.controlNumber;
    final verifiedCondition = _selectedCondition;
    final verifiedStatus = _selectedStatus;

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
        qtySummary = '$newQty units (${qtyChange > 0 ? "+$qtyChange" : "$qtyChange"})';
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
        _successBannerMessage = 'Audit saved for $completedControlNo: $qtySummary • $verifiedCondition • Status: $verifiedStatus.';
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

  Future<void> _handlePop() async {
    // Unmount scanner view and release web camera tracks before leaving screen
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
        await _handlePop();
      },
      child: Scaffold(
        backgroundColor: ParishColors.backgroundLight,
        appBar: AppBar(
          backgroundColor: cardWhite,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: ParishColors.marianBlue),
            onPressed: _handlePop,
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Item Inventory Audit',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark)),
              Text('Scan QR stickers, read wireless tags, or search item numbers',
                  style: TextStyle(fontSize: 12, color: textMuted)),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.mode_standby, color: ParishColors.marianBlue),
              tooltip: 'Change Mode',
              onPressed: _resetToModeSelection,
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_successBannerMessage != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: ParishColors.oliveGreenSurface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: ParishColors.oliveGreen.withOpacity(0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: ParishColors.oliveGreen, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _successBannerMessage!,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ParishColors.oliveGreen),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => setState(() => _successBannerMessage = null),
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
                            const Icon(Icons.warning_amber_rounded, color: ParishColors.mercyRed, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_searchError!,
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: ParishColors.mercyRed)),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (_scannedAsset == null) ...[
                      // Mode Switcher Tabs
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: cardWhite,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderGrey),
                        ),
                        child: Row(
                          children: [
                            _buildModeTab(AuditScanMode.liveCamera, 'Camera QR', Icons.qr_code_scanner),
                            _buildModeTab(AuditScanMode.nfcListening, 'Wireless Tag', Icons.nfc),
                            _buildModeTab(AuditScanMode.manualEntry, 'Search Number', Icons.keyboard_outlined),
                          ],
                        ),
                      ),

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
                          padding: EdgeInsets.all(32.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_scannedAsset != null) ...[
                      const SizedBox(height: 10),
                      _buildAssetAuditVerificationForm(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeTab(AuditScanMode mode, String label, IconData icon) {
    final isSelected = _currentScanMode == mode;
    return Expanded(
      child: InkWell(
        onTap: () {
          if (mode == AuditScanMode.liveCamera) _startCameraScanner();
          if (mode == AuditScanMode.nfcListening) _startNfcListener();
          if (mode == AuditScanMode.manualEntry) _startManualLookup();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? ParishColors.marianBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? Colors.white : ParishColors.textMuted),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : ParishColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeSelectionGrid() {
    return Column(
      children: [
        _buildMethodCard('QR Code Camera Scanner', 'Scan printed stickers on parish items.', Icons.camera_alt, ParishColors.marianBlue, _startCameraScanner),
        const SizedBox(height: 10),
        _buildMethodCard('Wireless Tag Reader', 'Detect RFID or NFC tags on metal vessels and furnishings.', Icons.nfc, ParishColors.goldAccent, _startNfcListener),
        const SizedBox(height: 10),
        _buildMethodCard('Control Number Search', 'Find items directly by Control Number or name.', Icons.keyboard, ParishColors.oliveGreen, _startManualLookup),
      ],
    );
  }

  Widget _buildMethodCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ParishColors.cardWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ParishColors.borderGrey),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold)),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: ParishColors.textMuted)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveCameraScannerView() {
    if (!_isLiveCameraSupported) {
      return Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            const Icon(Icons.desktop_windows, size: 48, color: Colors.white70),
            const SizedBox(height: 12),
            const Text('Desktop Camera Unavailable', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 6),
            const Text('Upload a saved QR photo or search by Control Number.', style: TextStyle(color: Colors.white70, fontSize: 12), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: ParishColors.marianBlue, foregroundColor: Colors.white),
              onPressed: _pickImageAndScan,
              icon: const Icon(Icons.image),
              label: const Text('Upload QR Photo'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          height: 340,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ParishColors.borderGrey),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_scannerController != null && !_cameraPermissionDenied)
                  MobileScanner(
                    controller: _scannerController!,
                    onDetect: _handleBarcodeDetected,
                  ),
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: ParishColors.goldAccent, width: 3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                Positioned(
                  bottom: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(_isTorchOn ? Icons.flash_on : Icons.flash_off, color: Colors.white, size: 20),
                          onPressed: () async {
                            if (_scannerController == null) return;
                            await _scannerController!.toggleTorch();
                            setState(() => _isTorchOn = !_isTorchOn);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.cameraswitch, color: Colors.white, size: 20),
                          onPressed: () async {
                            if (_scannerController == null) return;
                            await _scannerController!.switchCamera();
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.photo_library, color: Colors.white, size: 20),
                          onPressed: _pickImageAndScan,
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

  Widget _buildNfcReaderView() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ParishColors.goldLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ParishColors.goldAccent.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          const Icon(Icons.sensors, size: 54, color: ParishColors.goldAccent),
          const SizedBox(height: 12),
          Text('Hold Device Near Wireless Tag',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: ParishColors.textDark)),
          const SizedBox(height: 4),
          Text('For sacred vessels and items with attached tags.',
              style: TextStyle(fontSize: 12, color: ParishColors.textMuted)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nfcInputController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. 04:A2:4B:9C',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: _searchAndLoadAsset,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: ParishColors.goldAccent, foregroundColor: Colors.white),
                onPressed: () => _searchAndLoadAsset(_nfcInputController.text),
                child: const Text('Find Tag'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildManualLookupView() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ParishColors.borderGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Search Item Number or Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 6),
          TextField(
            controller: _manualInputController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'e.g. C-FF 2026-001 or Church Pew',
              filled: true,
              fillColor: ParishColors.backgroundLight,
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: _isLoadingSuggestions
                  ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)))
                  : null,
            ),
            onSubmitted: _searchAndLoadAsset,
          ),
          if (_liveSuggestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(
                border: Border.all(color: ParishColors.borderGrey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _liveSuggestions.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, idx) {
                  final s = _liveSuggestions[idx];
                  return ListTile(
                    dense: true,
                    title: Text(s.controlNumber, style: const TextStyle(fontWeight: FontWeight.bold, color: ParishColors.marianBlue)),
                    subtitle: Text('${s.itemName} • Qty: ${s.quantity} • ${s.displayLocation}'),
                    onTap: () {
                      _manualInputController.text = s.controlNumber;
                      _searchAndLoadAsset(s.controlNumber);
                    },
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
  // 5. Complete Inline Specifications & Verification Form
  // ===========================================================================

  Widget _buildAssetAuditVerificationForm() {
    final asset = _scannedAsset!;
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final borderGrey = ParishColors.borderGrey;
    final int qtyDiff = _quantityDifference;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ParishColors.oliveGreen, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.check_circle, color: ParishColors.oliveGreen, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Item Found in Registry',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: ParishColors.oliveGreen),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: ParishColors.marianBlueSurface, borderRadius: BorderRadius.circular(6)),
                child: Text('${asset.quantity} unit(s) registered', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: ParishColors.marianBlue)),
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
                    width: 84,
                    height: 84,
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
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(asset.itemName, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textDark)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text('Control No: ${asset.controlNumber}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ParishColors.marianBlue)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: asset.conditionSurfaceColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            asset.conditionStatus,
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: asset.conditionColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Category: ${asset.displayClassification} • Location: ${asset.displayLocation}', style: TextStyle(fontSize: 12, color: textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Full Specs Grid
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
                    Expanded(child: _buildSpecItem('Current Status', asset.operationalStatus)),
                    Expanded(child: _buildSpecItem('Acquisition Date', '${asset.formattedAcquisitionDate} (${asset.modeOfAcquisition})')),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildSpecItem('Size / Dimensions', asset.dimensions ?? '—')),
                    Expanded(child: _buildSpecItem('Color', asset.color ?? '—')),
                    Expanded(child: _buildSpecItem('Brand / Model', asset.model ?? '—')),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildSpecItem('Unit Price', asset.formattedUnitPrice)),
                    Expanded(child: _buildSpecItem('Total Value', asset.formattedTotalCost)),
                    if (asset.rfidTag != null && asset.rfidTag!.isNotEmpty)
                      Expanded(child: _buildSpecItem('RFID Tag', asset.rfidTag!)),
                  ],
                ),
                if (asset.others != null && asset.others!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Markings / Details: ${asset.others}', style: TextStyle(fontSize: 11.5, color: textDark)),
                ],
                if (asset.remarks != null && asset.remarks!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Notes: ${asset.remarks}', style: TextStyle(fontSize: 11.5, color: textMuted)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 1. QUANTITY ADJUSTMENT TRACKING
          Container(
            padding: const EdgeInsets.all(14),
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
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ParishColors.marianBlue),
                    ),
                    if (qtyDiff != 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: qtyDiff > 0 ? ParishColors.oliveGreenSurface : ParishColors.mercyRedSurface,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          qtyDiff > 0 ? '+$qtyDiff units added' : '$qtyDiff units deducted',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: qtyDiff > 0 ? ParishColors.oliveGreen : ParishColors.mercyRed,
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
                          Text('Previous: ${asset.quantity} units', style: TextStyle(fontSize: 11.5, color: textMuted)),
                          const SizedBox(height: 2),
                          Text('Updated Total: $_auditQuantity units',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: qtyDiff != 0 ? ParishColors.marianBlue : textDark,
                              )),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: ParishColors.backgroundLight,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.remove, size: 18),
                          onPressed: _auditQuantity > 0
                              ? () => setState(() {
                            _auditQuantity--;
                            _quantityInputController.text = '$_auditQuantity';
                          })
                              : null,
                        ),
                        SizedBox(
                          width: 56,
                          child: TextField(
                            controller: _quantityInputController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.add, size: 18),
                          onPressed: () => setState(() {
                            _auditQuantity++;
                            _quantityInputController.text = '$_auditQuantity';
                          }),
                        ),
                      ],
                    ),
                  ],
                ),

                if (qtyDiff != 0) ...[
                  const SizedBox(height: 10),
                  Text('Reason for Quantity Change *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: textDark)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _quantityChangeReasonController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. 2 units damaged during parish event, or new donation received',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 2. STATUS & CONDITION
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Verified Condition *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: _selectedCondition,
                      decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                      items: _conditionOptions.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12.5)))).toList(),
                      onChanged: (val) => setState(() => _selectedCondition = val!),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Current Item Status *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: _selectedStatus,
                      decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                      items: _operationalStatusOptions.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12.5)))).toList(),
                      onChanged: (val) => setState(() => _selectedStatus = val!),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3. INSPECTION NOTES
          const Text('Inspection Notes (Optional)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          TextField(
            controller: _auditNotesController,
            maxLines: 2,
            decoration: const InputDecoration(hintText: 'e.g. In good condition, verified on-site in main church nave', border: OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 18),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: _startCameraScanner,
                child: const Text('Cancel / Next Item'),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ParishColors.oliveGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                onPressed: _isRecordingAudit
                    ? null
                    : () => _commitAuditInspection(_currentScanMode == AuditScanMode.nfcListening ? 'RFID_NFC' : 'QR_SCAN'),
                icon: _isRecordingAudit
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check),
                label: Text(_isRecordingAudit ? 'Saving...' : 'Save Audit', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpecItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: ParishColors.textMuted, fontWeight: FontWeight.w600)),
        Text(value, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: ParishColors.textDark), maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}