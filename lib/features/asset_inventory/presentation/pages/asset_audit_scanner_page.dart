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
import '../../models/asset_audit_log_model.dart';
import '../../models/asset_model.dart';
import '../../services/asset_service.dart';
import '../../utils/asset_image_watermark_util.dart';
import '../../utils/web_camera_helper.dart';

enum AuditScanMode { selectMode, liveCamera, manualEntry }

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

  // Located asset state
  AssetModel? _scannedAsset;
  bool _isRecordingAudit = false;

  // Quantity-based distribution state
  final List<_DistributionRowState> _distributionEntries = [];
  List<AssetQuantityDistribution>? _previousDistribution;
  String? _previousAuditDate;

  bool get _isLiveCameraSupported {
    if (kIsWeb) return true;
    try {
      return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
    } catch (_) {
      return false;
    }
  }

  // ===========================================================================
  // Live Quantity Reconciliation Calculations
  // ===========================================================================

  int get _totalVerifiedQuantity {
    return _distributionEntries.fold(0, (sum, entry) => sum + entry.quantity);
  }

  int get _inUsedQuantity {
    return _distributionEntries
        .where((e) => AssetModel.normalizeStatus(e.status) == 'In Used')
        .fold(0, (sum, entry) => sum + entry.quantity);
  }

  int get _inStorageQuantity {
    return _distributionEntries
        .where((e) => AssetModel.normalizeStatus(e.status) == 'In Storage')
        .fold(0, (sum, entry) => sum + entry.quantity);
  }

  int get _disposedQuantity {
    return _distributionEntries
        .where((e) => AssetModel.normalizeStatus(e.status) == 'Disposed')
        .fold(0, (sum, entry) => sum + entry.quantity);
  }

  int get _damagedQuantity {
    return _distributionEntries
        .where((e) => e.condition == 'Damaged')
        .fold(0, (sum, entry) => sum + entry.quantity);
  }

  int get _unaccountedQuantity {
    if (_scannedAsset == null) return 0;
    return _scannedAsset!.quantity - _totalVerifiedQuantity;
  }

  bool get _isReconciled {
    if (_scannedAsset == null) return false;
    return _totalVerifiedQuantity == _scannedAsset!.quantity &&
        _totalVerifiedQuantity > 0;
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
    _auditNotesController.dispose();
    _clearDistributionEntries();

    _safeStopCamera();

    try {
      _scannerController?.dispose();
    } catch (_) {}
    _scannerController = null;

    super.dispose();
  }

  void _clearDistributionEntries() {
    for (final e in _distributionEntries) {
      e.dispose();
    }
    _distributionEntries.clear();
  }

  Future<void> _safeStopCamera() async {
    try {
      if (_scannerController != null) {
        await _scannerController!.stop();
      }
    } catch (_) {}

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
      _manualInputController.clear();
      _previousDistribution = null;
      _previousAuditDate = null;
      _clearDistributionEntries();
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

  // ===========================================================================
  // Search & Load Asset: Retrieves & Pre-populates Previous Audit Distribution
  // ===========================================================================

  Future<void> _searchAndLoadAsset(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchError = null;
      _successBannerMessage = null;
      _scannedAsset = null;
      _liveSuggestions = [];
      _clearDistributionEntries();
      _previousDistribution = null;
      _previousAuditDate = null;
    });

    await _safeStopCamera();

    try {
      final asset = await AssetService.findAssetByIdentifier(clean);
      if (!mounted) return;

      if (asset != null) {
        // Fetch latest audit history to extract previous distribution baseline
        List<AssetQuantityDistribution>? lastDist;
        String? lastAuditDate;

        try {
          final history = await AssetService.getAssetAuditHistory(asset.assetId);
          if (history.isNotEmpty) {
            for (final log in history) {
              if (log.hasQuantityDistribution) {
                lastDist = log.quantityDistribution;
                lastAuditDate = log.formattedAuditedAt;
                break;
              }
            }
          }
        } catch (e) {
          debugPrint('Notice loading previous audit distribution: $e');
        }

        // Initialize distribution entries from previous audit baseline if available
        if (lastDist != null && lastDist.isNotEmpty) {
          for (final d in lastDist) {
            _distributionEntries.add(
              _DistributionRowState(
                status: d.utilizationStatus,
                condition: d.physicalCondition,
                quantity: d.quantity,
                onChanged: () => setState(() {}),
              ),
            );
          }
        } else {
          // Fallback to default single combination matching asset registered totals
          final defaultStatus = AssetModel.normalizeStatus(asset.operationalStatus);
          final defaultCondition =
          AssetQuantityDistribution.standardPhysicalConditions.contains(
              asset.conditionStatus)
              ? asset.conditionStatus
              : 'Good';

          _distributionEntries.add(
            _DistributionRowState(
              status: defaultStatus,
              condition: defaultCondition,
              quantity: asset.quantity,
              onChanged: () => setState(() {}),
            ),
          );
        }

        setState(() {
          _scannedAsset = asset;
          _previousDistribution = lastDist;
          _previousAuditDate = lastAuditDate;
          _isSearching = false;
        });
      } else {
        setState(() {
          _searchError =
          'No item record found for "$clean". Please verify the Control Number or QR Code.';
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

  // ===========================================================================
  // Distribution Management Actions
  // ===========================================================================

  void _addDistributionEntry() {
    if (_scannedAsset == null) return;

    final int defaultQty =
    _unaccountedQuantity > 0 ? _unaccountedQuantity : 1;

    setState(() {
      _distributionEntries.add(
        _DistributionRowState(
          status: 'In Used',
          condition: 'Good',
          quantity: defaultQty,
          onChanged: () => setState(() {}),
        ),
      );
    });
  }

  void _removeDistributionEntry(int index) {
    if (_distributionEntries.length <= 1) return;
    setState(() {
      _distributionEntries[index].dispose();
      _distributionEntries.removeAt(index);
    });
  }

  void _restorePreviousDistribution() {
    if (_previousDistribution == null || _previousDistribution!.isEmpty) return;
    _clearDistributionEntries();
    setState(() {
      for (final d in _previousDistribution!) {
        _distributionEntries.add(
          _DistributionRowState(
            status: d.utilizationStatus,
            condition: d.physicalCondition,
            quantity: d.quantity,
            onChanged: () => setState(() {}),
          ),
        );
      }
    });
  }

  List<AssetQuantityDistribution> _consolidateDistributions() {
    final Map<String, int> map = {};

    for (final entry in _distributionEntries) {
      if (entry.quantity > 0) {
        final key = '${entry.status}|||${entry.condition}';
        map[key] = (map[key] ?? 0) + entry.quantity;
      }
    }

    return map.entries.map((e) {
      final parts = e.key.split('|||');
      return AssetQuantityDistribution(
        utilizationStatus: parts[0],
        physicalCondition: parts[1],
        quantity: e.value,
      );
    }).toList();
  }

  // ===========================================================================
  // Save Audit Verification
  // ===========================================================================

  Future<void> _commitAuditInspection(String method) async {
    if (_scannedAsset == null) return;

    if (!_isReconciled) {
      setState(() {
        _searchError = _unaccountedQuantity > 0
            ? 'Cannot save: $_unaccountedQuantity unit(s) remain unaccounted for ($_totalVerifiedQuantity of ${_scannedAsset!.quantity}).'
            : 'Cannot save: Total verified exceeds registered total by ${-_unaccountedQuantity} unit(s).';
      });
      return;
    }

    setState(() => _isRecordingAudit = true);

    final asset = _scannedAsset!;
    final completedControlNo = asset.controlNumber;
    final consolidated = _consolidateDistributions();

    final inUsedTotal = _inUsedQuantity;
    final inStorageTotal = _inStorageQuantity;
    final disposedTotal = _disposedQuantity;
    String dominantStatus = 'In Storage';
    if (inUsedTotal >= inStorageTotal && inUsedTotal >= disposedTotal) {
      dominantStatus = 'In Used';
    } else if (disposedTotal > inUsedTotal && disposedTotal > inStorageTotal) {
      dominantStatus = 'Disposed';
    } else {
      dominantStatus = 'In Storage';
    }

    final Map<String, int> condCounts = {};
    for (final d in consolidated) {
      condCounts[d.physicalCondition] =
          (condCounts[d.physicalCondition] ?? 0) + d.quantity;
    }
    String dominantCondition = 'Good';
    int maxConditionCount = -1;
    condCounts.forEach((cond, count) {
      if (count > maxConditionCount) {
        maxConditionCount = count;
        dominantCondition = cond;
      }
    });

    try {
      await AssetService.recordAuditScan(
        assetId: asset.assetId,
        controlNumber: completedControlNo,
        newCondition: dominantCondition,
        previousCondition: asset.conditionStatus,
        newStatus: dominantStatus,
        previousStatus: asset.operationalStatus,
        previousLocation: asset.displayLocation,
        newLocation: asset.displayLocation,
        auditMethod: method,
        auditNotes: _auditNotesController.text.trim(),
        quantityDistribution: consolidated,
      );

      if (!mounted) return;
      widget.onScanCompleted?.call();

      final summaryBreakdown = consolidated
          .map((d) =>
      '${d.quantity}x ${d.utilizationStatus} [${d.physicalCondition}]')
          .join(', ');

      setState(() {
        _isRecordingAudit = false;
        _scannedAsset = null;
        _hasProcessedScan = false;
        _searchError = null;
        _liveSuggestions = [];
        _auditNotesController.clear();
        _manualInputController.clear();
        _previousDistribution = null;
        _previousAuditDate = null;
        _clearDistributionEntries();
        _successBannerMessage =
        'Verification saved for $completedControlNo (${asset.quantity} units reconciled): $summaryBreakdown.';
      });

      if (_lastActiveMode == AuditScanMode.liveCamera) {
        await _startCameraScanner();
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 650;

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
                icon: const Icon(
                  Icons.arrow_back,
                  color: ParishColors.marianBlue,
                ),
                onPressed: _handlePop,
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Item Inventory Audit',
                    style: TextStyle(
                      fontSize: isMobile ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                  Text(
                    'Physical condition, utilization classification & quantity reconciliation',
                    style: TextStyle(
                      fontSize: isMobile ? 10.5 : 12,
                      color: textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(
                    Icons.mode_standby,
                    color: ParishColors.marianBlue,
                  ),
                  tooltip: 'Change Mode',
                  onPressed: _resetToModeSelection,
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 12 : 20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 860),
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
                              border: Border.all(
                                color:
                                ParishColors.oliveGreen.withOpacity(0.4),
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
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: ParishColors.oliveGreen,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 16),
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
                                      fontSize: 12.5,
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
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: cardWhite,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: borderGrey),
                            ),
                            child: Row(
                              children: [
                                _buildModeTab(
                                  AuditScanMode.liveCamera,
                                  isMobile ? 'Camera' : 'Camera QR',
                                  Icons.qr_code_scanner,
                                  isMobile,
                                ),
                                _buildModeTab(
                                  AuditScanMode.manualEntry,
                                  isMobile ? 'Search' : 'Search Number',
                                  Icons.keyboard_outlined,
                                  isMobile,
                                ),
                              ],
                            ),
                          ),

                          if (_currentScanMode == AuditScanMode.selectMode)
                            _buildModeSelectionGrid()
                          else if (_currentScanMode == AuditScanMode.liveCamera)
                            _buildLiveCameraScannerView()
                          else if (_currentScanMode ==
                                AuditScanMode.manualEntry)
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
                          _buildAssetAuditVerificationForm(isMobile),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // Top View Mode Selector Helpers
  // ===========================================================================

  Widget _buildModeTab(
      AuditScanMode mode,
      String label,
      IconData icon,
      bool isMobile,
      ) {
    final isSelected = _currentScanMode == mode;
    return Expanded(
      child: InkWell(
        onTap: () {
          if (mode == AuditScanMode.liveCamera) _startCameraScanner();
          if (mode == AuditScanMode.manualEntry) _startManualLookup();
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: isMobile ? 8 : 10),
          decoration: BoxDecoration(
            color: isSelected ? ParishColors.marianBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: isMobile ? 15 : 16,
                color: isSelected ? Colors.white : ParishColors.textMuted,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: isMobile ? 11.5 : 12.5,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : ParishColors.textMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
        _buildMethodCard(
          'QR Code Camera Scanner',
          'Scan printed stickers on parish items.',
          Icons.camera_alt,
          ParishColors.marianBlue,
          _startCameraScanner,
        ),
        const SizedBox(height: 10),
        _buildMethodCard(
          'Control Number Search',
          'Find items directly by Control Number or name.',
          Icons.keyboard,
          ParishColors.oliveGreen,
          _startManualLookup,
        ),
      ],
    );
  }

  Widget _buildMethodCard(
      String title,
      String subtitle,
      IconData icon,
      Color color,
      VoidCallback onTap,
      ) {
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
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: ParishColors.textMuted,
                    ),
                  ),
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
            const Text(
              'Desktop Camera Unavailable',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Upload a saved QR photo or search by Control Number.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: ParishColors.marianBlue,
                foregroundColor: Colors.white,
              ),
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
                    border: Border.all(
                      color: ParishColors.goldAccent,
                      width: 3,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                Positioned(
                  bottom: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            _isTorchOn ? Icons.flash_on : Icons.flash_off,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () async {
                            if (_scannerController == null) return;
                            await _scannerController!.toggleTorch();
                            setState(() => _isTorchOn = !_isTorchOn);
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.cameraswitch,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () async {
                            if (_scannerController == null) return;
                            await _scannerController!.switchCamera();
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.photo_library,
                            color: Colors.white,
                            size: 20,
                          ),
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
          const Text(
            'Search Item Number or Name',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _manualInputController,
            autofocus: true,
            style: TextStyle(fontSize: 13.5, color: ParishColors.textDark),
            decoration: InputDecoration(
              hintText: 'e.g. C-EE 2024-0001 or Flat Screen TV',
              hintStyle: TextStyle(
                fontSize: 12.5,
                color: ParishColors.textMuted,
              ),
              filled: true,
              fillColor: ParishColors.backgroundLight,
              border: const OutlineInputBorder(),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: ParishColors.borderGrey),
              ),
              isDense: true,
              suffixIcon: _isLoadingSuggestions
                  ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
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
                    title: Text(
                      s.controlNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: ParishColors.marianBlue,
                      ),
                    ),
                    subtitle: Text(
                      '${s.itemName} • Qty: ${s.quantity} • ${s.displayLocation}',
                      style: TextStyle(color: ParishColors.textMuted),
                    ),
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
  // VERIFICATION INTERFACE: Quantity-Based Distribution
  // ===========================================================================

  Widget _buildAssetAuditVerificationForm(bool isMobile) {
    final asset = _scannedAsset!;
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final borderGrey = ParishColors.borderGrey;

    return Container(
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: ParishColors.marianBlue.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. ITEM FOUND IN REGISTRY HEADER
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: isMobile ? 64 : 76,
                height: isMobile ? 64 : 76,
                decoration: BoxDecoration(
                  color: ParishColors.backgroundLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderGrey),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: asset.photoUrl != null && asset.photoUrl!.isNotEmpty
                      ? InkWell(
                    onTap: () {
                      AssetImageWatermarkUtil.showImagePreviewModal(
                        context,
                        imageProvider: NetworkImage(asset.photoUrl!),
                        title: asset.itemName,
                        controlNumber: asset.controlNumber,
                      );
                    },
                    child: Image.network(asset.photoUrl!,
                        fit: BoxFit.cover),
                  )
                      : Center(
                    child: Icon(asset.classificationIcon,
                        size: 32, color: ParishColors.marianBlue),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Flexible(
                          child: Text(
                            asset.controlNumber,
                            style: TextStyle(
                              fontFamily: 'Courier',
                              fontSize: isMobile ? 13 : 15,
                              fontWeight: FontWeight.w800,
                              color: ParishColors.marianBlue,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: ParishColors.marianBlueSurface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color:
                                ParishColors.marianBlue.withOpacity(0.4)),
                          ),
                          child: Text(
                            '${asset.quantity} registered unit(s)',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: ParishColors.marianBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      asset.itemName,
                      style: TextStyle(
                        fontSize: isMobile ? 15.5 : 18,
                        fontWeight: FontWeight.bold,
                        color: textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${asset.displayClassification} • ${asset.displayLocation}',
                      style: TextStyle(fontSize: 11.5, color: textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 2. ASSET INFORMATION SPECIFICATION CARD
          Container(
            width: double.infinity,
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
                        'Acquisition Date',
                        '${asset.formattedAcquisitionDate} (${asset.modeOfAcquisition})',
                      ),
                    ),
                    Expanded(
                      child: _buildSpecItem(
                        'Unit Price',
                        asset.formattedUnitPrice,
                        color: ParishColors.oliveGreen,
                      ),
                    ),
                    Expanded(
                      child: _buildSpecItem(
                        'Total Value',
                        asset.formattedTotalCost,
                        color: ParishColors.oliveGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildSpecItem('Color', asset.color ?? '—'),
                    ),
                    Expanded(
                      child: _buildSpecItem(
                          'Dimension', asset.dimensions ?? '—'),
                    ),
                    Expanded(
                      child: _buildSpecItem('Model', asset.model ?? '—'),
                    ),
                  ],
                ),
                if (asset.others != null &&
                    asset.others!.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildSpecItem('Other Descriptions', asset.others!.trim()),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 3. LIVE QUANTITY SUMMARY DECK
          _buildLiveQuantitySummaryDeck(isMobile),

          const SizedBox(height: 16),

          // 4. QUANTITY DISTRIBUTION TABLE / CARDS
          _buildQuantityDistributionSection(isMobile),

          const SizedBox(height: 16),

          // 5. INSPECTION NOTES
          Text(
            'Inspection Notes (Optional)',
            style: TextStyle(
              fontSize: 12.5,
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
              'e.g. Verified across main sanctuary and sacristy. 5 damaged units awaiting carpenter.',
              hintStyle: TextStyle(fontSize: 12, color: textMuted),
              filled: true,
              fillColor: ParishColors.backgroundLight,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: borderGrey),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: borderGrey),
              ),
            ),
          ),

          const SizedBox(height: 18),

          // 6. ACTION BUTTONS (Save locked until 100% reconciled)
          isMobile
              ? Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isReconciled
                        ? ParishColors.oliveGreen
                        : ParishColors.borderGrey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: (_isReconciled && !_isRecordingAudit)
                      ? () => _commitAuditInspection(
                    _currentScanMode == AuditScanMode.manualEntry
                        ? 'MANUAL'
                        : 'QR_SCAN',
                  )
                      : null,
                  icon: _isRecordingAudit
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(
                    _isRecordingAudit
                        ? 'Saving...'
                        : (_isReconciled
                        ? 'Save Verification'
                        : 'Reconcile Quantities to Save'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _startCameraScanner,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  child: const Text('Cancel / Next Item'),
                ),
              ),
            ],
          )
              : Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: _startCameraScanner,
                child: const Text('Cancel / Next Item'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isReconciled
                      ? ParishColors.oliveGreen
                      : ParishColors.borderGrey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: (_isReconciled && !_isRecordingAudit)
                    ? () => _commitAuditInspection(
                  _currentScanMode == AuditScanMode.manualEntry
                      ? 'MANUAL'
                      : 'QR_SCAN',
                )
                    : null,
                icon: _isRecordingAudit
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(Icons.check_circle_outline),
                label: Text(
                  _isRecordingAudit
                      ? 'Saving...'
                      : (_isReconciled
                      ? 'Save Verification'
                      : 'Reconcile Quantities to Save'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Live Quantity Summary Deck Helper
  // ===========================================================================

  Widget _buildLiveQuantitySummaryDeck(bool isMobile) {
    final asset = _scannedAsset!;
    final verified = _totalVerifiedQuantity;
    final diff = _unaccountedQuantity;

    Color reconciliationPillColor;
    Color reconciliationTextColor;
    IconData reconciliationIcon;
    String reconciliationLabel;

    if (_isReconciled) {
      reconciliationPillColor = ParishColors.oliveGreenSurface;
      reconciliationTextColor = ParishColors.oliveGreen;
      reconciliationIcon = Icons.check_circle;
      reconciliationLabel =
      'All ${asset.quantity} unit(s) fully verified and reconciled.';
    } else if (diff > 0) {
      reconciliationPillColor = const Color(0xFFFFFBEB);
      reconciliationTextColor = const Color(0xFFD97706);
      reconciliationIcon = Icons.warning_amber_rounded;
      reconciliationLabel =
      '$diff unit(s) unaccounted for ($verified of ${asset.quantity} verified).';
    } else {
      reconciliationPillColor = ParishColors.mercyRedSurface;
      reconciliationTextColor = ParishColors.mercyRed;
      reconciliationIcon = Icons.error_outline;
      reconciliationLabel =
      'Total verified exceeds registered count by ${-diff} unit(s) ($verified of ${asset.quantity}).';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isReconciled
              ? ParishColors.oliveGreen.withOpacity(0.4)
              : const Color(0xFFF59E0B).withOpacity(0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'LIVE QUANTITY RECONCILIATION',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: ParishColors.textMuted,
                ),
              ),
              Text(
                '$verified / ${asset.quantity} Verified',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _isReconciled
                      ? ParishColors.oliveGreen
                      : const Color(0xFFD97706),
                ),
              ),
            ],
          ),
          const Divider(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceAround,
            children: [
              _buildMiniMetricBadge(
                  'Registered', '${asset.quantity}', ParishColors.textDark),
              _buildMiniMetricBadge(
                  'Total Verified',
                  '$verified',
                  _isReconciled
                      ? ParishColors.oliveGreen
                      : const Color(0xFFD97706)),
              _buildMiniMetricBadge(
                  'In Used', '$_inUsedQuantity', ParishColors.marianBlue),
              _buildMiniMetricBadge(
                  'In Storage', '$_inStorageQuantity', ParishColors.oliveGreen),
              _buildMiniMetricBadge(
                  'Damaged', '$_damagedQuantity', ParishColors.mercyRed),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: reconciliationPillColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: reconciliationTextColor.withOpacity(0.35),
              ),
            ),
            child: Row(
              children: [
                Icon(reconciliationIcon,
                    size: 16, color: reconciliationTextColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    reconciliationLabel,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: reconciliationTextColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetricBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: ParishColors.backgroundLight,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ParishColors.borderGrey.withOpacity(0.6)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: ParishColors.textMuted,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Quantity Distribution Table / Entry Rows (With Previous Baseline Bar)
  // ===========================================================================

  Widget _buildQuantityDistributionSection(bool isMobile) {
    final bool hasPrevDist =
        _previousDistribution != null && _previousDistribution!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quantity Distribution',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: ParishColors.textDark,
                  ),
                ),
                Text(
                  'Categorize units by physical condition and utilization status',
                  style: TextStyle(
                    fontSize: 11,
                    color: ParishColors.textMuted,
                  ),
                ),
              ],
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: ParishColors.marianBlue,
                foregroundColor: Colors.white,
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _addDistributionEntry,
              icon: const Icon(Icons.add, size: 15),
              label: const Text('Add Combination',
                  style: TextStyle(
                      fontSize: 11.5, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // PREVIOUS AUDIT DISTRIBUTION BASELINE BANNER
        if (hasPrevDist) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ParishColors.marianBlueSurface.withOpacity(0.4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: ParishColors.marianBlue.withOpacity(0.35),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.history,
                          size: 15,
                          color: ParishColors.marianBlue,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'PREVIOUS VERIFICATION BASELINE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.4,
                            color: ParishColors.marianBlue,
                          ),
                        ),
                        if (_previousAuditDate != null) ...[
                          const SizedBox(width: 4),
                          Text(
                            '($_previousAuditDate)',
                            style: TextStyle(
                              fontSize: 10,
                              color: ParishColors.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                    InkWell(
                      onTap: _restorePreviousDistribution,
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        child: Row(
                          children: [
                            const Icon(Icons.restore,
                                size: 13, color: ParishColors.marianBlue),
                            const SizedBox(width: 3),
                            Text(
                              'Restore Last Audit',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: ParishColors.marianBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _previousDistribution!.map((d) {
                    final bool isDamaged =
                        d.physicalCondition.toLowerCase() == 'damaged';
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: isDamaged
                            ? ParishColors.mercyRedSurface
                            : Colors.white,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: isDamaged
                              ? ParishColors.mercyRed.withOpacity(0.4)
                              : ParishColors.borderGrey,
                        ),
                      ),
                      child: Text(
                        '${d.quantity}x ${d.utilizationStatus} (${d.physicalCondition})',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: isDamaged
                              ? ParishColors.mercyRed
                              : ParishColors.textDark,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],

        ..._distributionEntries.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ParishColors.cardWhite,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ParishColors.borderGrey),
            ),
            child: isMobile
                ? Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Combination #${index + 1}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: ParishColors.textMuted,
                      ),
                    ),
                    if (_distributionEntries.length > 1)
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            size: 18, color: ParishColors.mercyRed),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () =>
                            _removeDistributionEntry(index),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatusDropdown(item),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildConditionDropdown(item),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Allocated Units:',
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold),
                    ),
                    _buildQuantityStepper(item),
                  ],
                ),
              ],
            )
                : Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _buildStatusDropdown(item),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: _buildConditionDropdown(item),
                ),
                const SizedBox(width: 10),
                _buildQuantityStepper(item),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: _distributionEntries.length > 1
                        ? ParishColors.mercyRed
                        : ParishColors.borderGrey,
                  ),
                  onPressed: _distributionEntries.length > 1
                      ? () => _removeDistributionEntry(index)
                      : null,
                  tooltip: 'Remove Row',
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStatusDropdown(_DistributionRowState item) {
    final effectiveStatus = AssetModel.normalizeStatus(item.status);
    return DropdownButtonFormField<String>(
      value: effectiveStatus,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Availability',
        labelStyle: TextStyle(fontSize: 11, color: ParishColors.textMuted),
        filled: true,
        fillColor: ParishColors.backgroundLight,
        isDense: true,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      items:
      AssetQuantityDistribution.standardUtilizationStatuses.map((st) {
        return DropdownMenuItem(
          value: st,
          child: Text(st, style: const TextStyle(fontSize: 12.5)),
        );
      }).toList(),
      onChanged: (val) {
        if (val != null) {
          setState(() => item.status = val);
        }
      },
    );
  }

  Widget _buildConditionDropdown(_DistributionRowState item) {
    return DropdownButtonFormField<String>(
      value: item.condition,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Physical Condition',
        labelStyle: TextStyle(fontSize: 11, color: ParishColors.textMuted),
        filled: true,
        fillColor: ParishColors.backgroundLight,
        isDense: true,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      items: AssetQuantityDistribution.standardPhysicalConditions
          .map((cond) {
        return DropdownMenuItem(
          value: cond,
          child: Text(
            cond,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight:
              cond == 'Damaged' ? FontWeight.bold : FontWeight.normal,
              color: cond == 'Damaged'
                  ? ParishColors.mercyRed
                  : ParishColors.textDark,
            ),
          ),
        );
      }).toList(),
      onChanged: (val) {
        if (val != null) {
          setState(() => item.condition = val);
        }
      },
    );
  }

  Widget _buildQuantityStepper(_DistributionRowState item) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          padding: EdgeInsets.zero,
          style: IconButton.styleFrom(
            backgroundColor: ParishColors.backgroundLight,
          ),
          icon: const Icon(Icons.remove, size: 14),
          onPressed: item.quantity > 1
              ? () {
            item.setQuantity(item.quantity - 1);
            setState(() {});
          }
              : null,
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 52,
          child: TextField(
            controller: item.quantityController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            style:
            const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding:
              EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              border: OutlineInputBorder(),
            ),
            onChanged: (val) {
              setState(() {});
            },
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          padding: EdgeInsets.zero,
          style: IconButton.styleFrom(
            backgroundColor: ParishColors.backgroundLight,
          ),
          icon: const Icon(Icons.add, size: 14),
          onPressed: () {
            item.setQuantity(item.quantity + 1);
            setState(() {});
          },
        ),
      ],
    );
  }

  Widget _buildSpecItem(String label, String value, {Color? color}) {
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
            color: color ?? ParishColors.textDark,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// =============================================================================
// Helper State Representation for Distribution Row Inputs
// =============================================================================

class _DistributionRowState {
  String status;
  String condition;
  final TextEditingController quantityController;
  final VoidCallback onChanged;

  _DistributionRowState({
    required this.status,
    required this.condition,
    required int quantity,
    required this.onChanged,
  }) : quantityController = TextEditingController(text: '$quantity') {
    quantityController.addListener(onChanged);
  }

  int get quantity => int.tryParse(quantityController.text.trim()) ?? 0;

  void setQuantity(int val) {
    final safeVal = val > 0 ? val : 1;
    quantityController.text = '$safeVal';
  }

  void dispose() {
    quantityController.removeListener(onChanged);
    quantityController.dispose();
  }
}