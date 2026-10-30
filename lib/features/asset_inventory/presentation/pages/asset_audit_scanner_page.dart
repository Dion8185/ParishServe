// =============================================================================
// FILE: lib/features/asset_inventory/presentation/pages/asset_audit_scanner_page.dart
// =============================================================================

import 'dart:async';
import 'dart:io' show Platform;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/constants/colors.dart';
import '../../models/asset_model.dart';
import '../../services/asset_service.dart';
import '../dialogs/asset_detail_dialog.dart';

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
  String _selectedStatus = 'Active';
  bool _auditEntireGroup = true;
  bool _isRecordingAudit = false;

  final List<String> _conditionOptions = [
    'VERIFIED / GOOD',
    'REQUIRES REPAIR',
    'DAMAGED',
    'MISSING',
    'UNUSABLE',
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
    _startCameraScanner();
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
      _hasProcessedScan = false;
      _isSearching = false;
      _cameraPermissionDenied = false;
      _liveSuggestions = [];
      _auditNotesController.clear();
      _manualInputController.clear();
      _nfcInputController.clear();
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
          _auditEntireGroup = asset.isPropertyGroup;
          _isSearching = false;
        });
      } else {
        setState(() {
          _searchError = 'No asset record found matching "$clean". Please verify the Control Number or RFID.';
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not detect a clear QR code from the selected image.'),
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
        auditEntireGroup: asset.isPropertyGroup && _auditEntireGroup,
        groupAssetIds: asset.isPropertyGroup && _auditEntireGroup
            ? asset.childItems.map((c) => c.assetId).toList()
            : [],
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
        _successBannerMessage = asset.isPropertyGroup && _auditEntireGroup
            ? 'Property Group $completedControlNo (All ${asset.quantity} units) verified as $verifiedCondition!'
            : 'Audit recorded for $completedControlNo ($verifiedCondition).';
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

    return Scaffold(
      backgroundColor: ParishColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: cardWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: ParishColors.marianBlue),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Field Inventory Audit Scanner',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark)),
            Text('Scan QR stickers, read wireless RFID tags, or search control numbers',
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
                          _buildModeTab(AuditScanMode.nfcListening, 'RFID / NFC', Icons.nfc),
                          _buildModeTab(AuditScanMode.manualEntry, 'Control #', Icons.keyboard_outlined),
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
        _buildMethodCard('Camera QR Scanner', 'Real-time camera detection for printed stickers.', Icons.camera_alt, ParishColors.marianBlue, _startCameraScanner),
        const SizedBox(height: 10),
        _buildMethodCard('Wireless RFID / NFC', 'Sensor detection for metal vessels and sacred images.', Icons.nfc, ParishColors.goldAccent, _startNfcListener),
        const SizedBox(height: 10),
        _buildMethodCard('Control Number Search', 'Direct search with live autocomplete results.', Icons.keyboard, ParishColors.oliveGreen, _startManualLookup),
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
            const Text('Desktop Camera Unsupported', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 6),
            const Text('Upload a saved QR code image or use Control Number search on desktop.', style: TextStyle(color: Colors.white70, fontSize: 12), textAlign: TextAlign.center),
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
          Text('Hold Device Near 13.56 MHz RFID / NFC Tag',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: ParishColors.textDark)),
          const SizedBox(height: 4),
          Text('Optimal for sacred vessels and consecrated parish furnishings.',
              style: TextStyle(fontSize: 12, color: ParishColors.textMuted)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nfcInputController,
                  decoration: const InputDecoration(
                    hintText: 'Or enter Tag UID (e.g. 04:A2:4B:9C)',
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
                child: const Text('Read Tag'),
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
          const Text('Search Control Number', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 6),
          TextField(
            controller: _manualInputController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'e.g. C-SI-2008-001 or Pew',
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
                    subtitle: Text('${s.itemName} • ${s.displayLocation}'),
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

  Widget _buildAssetAuditVerificationForm() {
    final asset = _scannedAsset!;
    final textDark = ParishColors.textDark;
    final isGroup = asset.isPropertyGroup;

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
              Row(
                children: [
                  const Icon(Icons.check_circle, color: ParishColors.oliveGreen, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    isGroup ? 'Property Group Found (${asset.quantity} Units)' : 'Asset Found in Registry',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: ParishColors.oliveGreen),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => showAssetDetailModal(context, asset: asset),
                child: const Text('View Full Specs', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const Divider(height: 18),
          Text(asset.itemName, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textDark)),
          const SizedBox(height: 2),
          Text('Control #: ${asset.controlNumber}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ParishColors.marianBlue)),
          Text('Location: ${asset.displayLocation} • Acq: ${asset.acquisitionYear}', style: TextStyle(fontSize: 12, color: ParishColors.textMuted)),
          const SizedBox(height: 16),

          if (isGroup) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: ParishColors.marianBlueSurface, borderRadius: BorderRadius.circular(8)),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: ParishColors.oliveGreen,
                title: const Text('Batch Audit Entire Property Group', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: Text('Apply verified condition to all ${asset.quantity} units simultaneously.', style: const TextStyle(fontSize: 11)),
                value: _auditEntireGroup,
                onChanged: (val) => setState(() => _auditEntireGroup = val),
              ),
            ),
            const SizedBox(height: 14),
          ],

          const Text('Verified Physical Condition *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _selectedCondition,
            decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
            items: _conditionOptions.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (val) => setState(() => _selectedCondition = val!),
          ),
          const SizedBox(height: 12),

          const Text('Inspection Notes (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          TextField(
            controller: _auditNotesController,
            maxLines: 2,
            decoration: const InputDecoration(hintText: 'e.g. In good condition, verified on-site in main nave', border: OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 18),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: _startCameraScanner,
                child: const Text('Cancel / Next Scan'),
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
                label: Text(_isRecordingAudit ? 'Saving...' : 'Save & Continue Scanning', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}