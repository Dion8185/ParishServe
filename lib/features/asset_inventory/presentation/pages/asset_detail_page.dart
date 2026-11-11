// =============================================================================
// FILE: lib/features/asset_inventory/presentation/pages/asset_detail_page.dart
// =============================================================================

import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/colors.dart';
import '../../../auth/services/auth_service.dart';
import '../../models/asset_audit_log_model.dart';
import '../../models/asset_model.dart';
import '../../models/asset_reference_models.dart';
import '../../services/asset_label_pdf_service.dart';
import '../../services/asset_reference_service.dart';
import '../../services/asset_service.dart';
import '../../utils/asset_image_watermark_util.dart';
import 'asset_camera_page.dart';

class ThousandsSeparatorCurrencyFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final clean = newValue.text.replaceAll(',', '');
    if (!RegExp(r'^\d*(\.\d{0,2})?$').hasMatch(clean)) {
      return oldValue;
    }

    final parts = clean.split('.');
    final integerPart = parts[0];
    final decimalPart = parts.length > 1 ? parts[1] : null;

    final buffer = StringBuffer();
    for (int i = 0; i < integerPart.length; i++) {
      if (i > 0 && (integerPart.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(integerPart[i]);
    }

    String formatted = buffer.toString();
    if (decimalPart != null) {
      formatted += '.$decimalPart';
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class AssetDetailPage extends StatefulWidget {
  final List<AssetModel> assets;
  final int initialIndex;
  final VoidCallback? onAssetUpdated;

  const AssetDetailPage({
    super.key,
    required this.assets,
    required this.initialIndex,
    this.onAssetUpdated,
  });

  @override
  State<AssetDetailPage> createState() => _AssetDetailPageState();
}

class _AssetDetailPageState extends State<AssetDetailPage> {
  late List<AssetModel> _assetList;
  late int _currentIndex;

  AssetModel get _currentAsset => _assetList[_currentIndex];

  bool _isLoadingHistory = false;
  List<AssetAuditLogModel> _auditHistory = [];

  bool _isEditing = false;
  bool _isUpdating = false;
  bool _isProcessingImage = false;

  Uint8List? _newWatermarkedPhotoBytes;
  String? _newPhotoFileName;

  late TextEditingController _nameController;
  late TextEditingController _quantityController;
  late TextEditingController _unitPriceController;
  late TextEditingController _dimensionsController;
  late TextEditingController _colorController;
  late TextEditingController _modelController;
  late TextEditingController _othersController;
  late TextEditingController _remarksController;
  late TextEditingController _rfidController;

  List<AssetLocationModel> _locations = [];
  List<AssetClassificationModel> _classifications = [];
  AssetLocationModel? _selectedLocation;
  AssetClassificationModel? _selectedClassification;

  // Separated inline date mechanism (Month & Day are optional, no future dates allowed)
  late int _selectedYear;
  int? _selectedMonth; // null = optional/unspecified, NEVER forced to January
  int? _selectedDay; // null = optional/unspecified, NEVER forced to 1st

  late String _conditionStatus;
  late String _operationalStatus;
  late String _modeOfAcquisition;

  final List<String> _acquisitionModes = [
    'Purchase',
    'Donation',
    'Transfer',
    'Diocesan Grant',
    'Inherited / Legacy',
    'Found / Recovered',
  ];

  final List<String> _conditionOptions = AssetModel.standardConditions;
  final List<String> _operationalStatusOptions = AssetModel.standardAvailability;

  static const List<String> _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  bool get _hasPrevious => _currentIndex > 0;
  bool get _hasNext => _currentIndex < _assetList.length - 1;

  bool get _canModify {
    final user = AuthService.currentUser;
    if (user == null) return true;
    final role = user.userRole
        .toLowerCase()
        .replaceAll('_', '')
        .replaceAll(' ', '')
        .trim();
    return role == 'superadmin' ||
        role == 'admin' ||
        role == 'parishpriest' ||
        role == 'secretary' ||
        role == 'encoder' ||
        role.isEmpty;
  }

  bool get _canArchive {
    final user = AuthService.currentUser;
    if (user == null) return true;
    final role = user.userRole
        .toLowerCase()
        .replaceAll('_', '')
        .replaceAll(' ', '')
        .trim();
    return role == 'superadmin' ||
        role == 'admin' ||
        role == 'parishpriest' ||
        role.isEmpty;
  }

  int get _editQuantity {
    final q = int.tryParse(_quantityController.text.trim());
    return (q != null && q > 0) ? q : 1;
  }

  double get _editUnitPrice {
    final clean = _unitPriceController.text.replaceAll(',', '').trim();
    if (clean.isEmpty) return 0.0;
    return double.tryParse(clean) ?? 0.0;
  }

  double get _editCalculatedTotalCost => _editQuantity * _editUnitPrice;

  String get _editDeterminedSection {
    return _editUnitPrice >= 10000.0
        ? 'Section 1 — ₱10,000.00 and Above'
        : 'Section 2 — Below ₱10,000.00';
  }

  /// Returns null if month or day was left optional, completely preventing false "January 1" outputs
  DateTime? get _effectiveDateOfAcquisition {
    if (_selectedMonth != null && _selectedDay != null) {
      return DateTime(_selectedYear, _selectedMonth!, _selectedDay!);
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _assetList = List.from(widget.assets);
    _currentIndex = widget.initialIndex
        .clamp(0, _assetList.isEmpty ? 0 : _assetList.length - 1);
    _initializeCurrentAsset();
    _loadReferenceOptions();
  }

  void _initializeCurrentAsset() {
    final asset = _currentAsset;
    final now = DateTime.now();

    _conditionStatus = AssetModel.normalizeCondition(asset.conditionStatus);
    _operationalStatus = AssetModel.normalizeStatus(asset.operationalStatus);
    _modeOfAcquisition = asset.modeOfAcquisition;

    final initialDate = asset.dateOfAcquisition;
    final cappedYear = (initialDate != null && initialDate.year > now.year)
        ? now.year
        : (asset.acquisitionYear > now.year ? now.year : asset.acquisitionYear);
    _selectedYear = cappedYear;

    // Only populate month/day if explicitly recorded; otherwise keep null
    if (initialDate != null) {
      if (_selectedYear == now.year && initialDate.month > now.month) {
        _selectedMonth = now.month;
      } else {
        _selectedMonth = initialDate.month;
      }

      if (_selectedYear == now.year &&
          _selectedMonth == now.month &&
          initialDate.day > now.day) {
        _selectedDay = now.day;
      } else {
        _selectedDay = initialDate.day;
      }
    } else {
      _selectedMonth = null;
      _selectedDay = null;
    }

    _nameController = TextEditingController(text: asset.itemName);
    _quantityController = TextEditingController(text: '${asset.quantity}');
    _unitPriceController = TextEditingController(
      text:
      asset.unitPrice > 0 ? AssetModel.formatCurrency(asset.unitPrice) : '',
    );
    _dimensionsController = TextEditingController(text: asset.dimensions ?? '');
    _colorController = TextEditingController(text: asset.color ?? '');
    _modelController = TextEditingController(text: asset.model ?? '');
    _othersController = TextEditingController(text: asset.others ?? '');
    _remarksController = TextEditingController(text: asset.remarks ?? '');
    _rfidController = TextEditingController(text: asset.rfidTag ?? '');

    _quantityController.addListener(() => setState(() {}));
    _unitPriceController.addListener(() => setState(() {}));

    _newWatermarkedPhotoBytes = null;
    _newPhotoFileName = null;
    _isEditing = false;

    _loadAuditHistory();
  }

  void _disposeControllers() {
    _nameController.dispose();
    _quantityController.dispose();
    _unitPriceController.dispose();
    _dimensionsController.dispose();
    _colorController.dispose();
    _modelController.dispose();
    _othersController.dispose();
    _remarksController.dispose();
    _rfidController.dispose();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _navigateToPrevious() {
    if (!_hasPrevious) return;
    _disposeControllers();
    setState(() {
      _currentIndex--;
      _initializeCurrentAsset();
    });
  }

  void _navigateToNext() {
    if (!_hasNext) return;
    _disposeControllers();
    setState(() {
      _currentIndex++;
      _initializeCurrentAsset();
    });
  }

  Future<void> _loadReferenceOptions() async {
    try {
      final locs = await AssetReferenceService.getLocations(activeOnly: false);
      final classifs =
      await AssetReferenceService.getClassifications(activeOnly: false);
      if (!mounted) return;
      setState(() {
        _locations = locs;
        _classifications = classifs;
        _selectedLocation = locs.firstWhere(
              (l) =>
          l.acronym.toUpperCase() ==
              _currentAsset.locationAcronym.toUpperCase(),
          orElse: () => locs.first,
        );
        _selectedClassification = classifs.firstWhere(
              (c) =>
          c.acronym.toUpperCase() ==
              _currentAsset.classificationAcronym.toUpperCase(),
          orElse: () => classifs.first,
        );
      });
    } catch (_) {}
  }

  Future<void> _loadAuditHistory() async {
    setState(() => _isLoadingHistory = true);
    try {
      final history =
      await AssetService.getAssetAuditHistory(_currentAsset.assetId);
      if (!mounted) return;
      setState(() {
        _auditHistory = history;
        _isLoadingHistory = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  // ===========================================================================
  // Dedicated 3R Camera Launch (Landscape & Portrait Framing)
  // ===========================================================================

  Future<void> _openDedicated3RCameraPage() async {
    final idLabel =
        '${_currentAsset.controlNumber} • ${_nameController.text.trim()}';

    final Uint8List? capturedWatermarkedBytes =
    await Navigator.push<Uint8List>(
      context,
      MaterialPageRoute(
        builder: (_) => AssetCameraPage(assetIdentifier: idLabel),
      ),
    );

    if (capturedWatermarkedBytes != null &&
        capturedWatermarkedBytes.isNotEmpty) {
      setState(() {
        _newWatermarkedPhotoBytes = capturedWatermarkedBytes;
        _newPhotoFileName =
        'photo_3R_${DateTime.now().millisecondsSinceEpoch}.png';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '3R photographic evidence captured and security watermark applied successfully.',
            ),
            backgroundColor: ParishColors.oliveGreen,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _pickImageFromDevice() async {
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
          Uint8List? rawBytes;
          try {
            rawBytes = await (file as dynamic).readAsBytes();
          } catch (_) {
            try {
              rawBytes = (file as dynamic).bytes;
            } catch (_) {}
          }

          String? name;
          try {
            name = (file as dynamic).name;
          } catch (_) {}

          if (rawBytes != null) {
            await _processAndWatermarkNewImage(
              rawBytes,
              name ?? 'asset_photo.jpg',
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error uploading image: $e');
    }
  }

  Future<void> _processAndWatermarkNewImage(
      Uint8List rawBytes,
      String filename,
      ) async {
    setState(() => _isProcessingImage = true);

    try {
      final idLabel =
          '${_currentAsset.controlNumber} • ${_nameController.text.trim()}';

      final watermarked = await AssetImageWatermarkUtil.applySecurityWatermark(
        rawImageBytes: rawBytes,
        assetIdentifier: idLabel,
        captureTime: DateTime.now(),
      );

      if (!mounted) return;
      setState(() {
        _newWatermarkedPhotoBytes = watermarked;
        _newPhotoFileName = filename;
        _isProcessingImage = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _newWatermarkedPhotoBytes = rawBytes;
        _newPhotoFileName = filename;
        _isProcessingImage = false;
      });
    }
  }

  void _openInteractivePreview(ImageProvider imageProvider) {
    AssetImageWatermarkUtil.showImagePreviewModal(
      context,
      imageProvider: imageProvider,
      title: _currentAsset.itemName,
      controlNumber: _currentAsset.controlNumber,
    );
  }

  Future<void> _saveAssetUpdates() async {
    // Strict validation: verify date cannot be in the future
    final now = DateTime.now();
    if (_selectedYear > now.year ||
        (_selectedYear == now.year &&
            _selectedMonth != null &&
            _selectedMonth! > now.month) ||
        (_selectedYear == now.year &&
            _selectedMonth != null &&
            _selectedMonth == now.month &&
            _selectedDay != null &&
            _selectedDay! > now.day)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Date of acquisition cannot be set to a future date.'),
          backgroundColor: ParishColors.mercyRed,
        ),
      );
      return;
    }

    setState(() => _isUpdating = true);
    try {
      String? photoUrlToSave = _currentAsset.photoUrl;

      if (_newWatermarkedPhotoBytes != null && _newPhotoFileName != null) {
        final uploaded = await AssetService.uploadAssetPhoto(
          assetId: _currentAsset.assetId,
          fileBytes: _newWatermarkedPhotoBytes!,
          fileName: _newPhotoFileName!,
        );
        if (uploaded != null) {
          photoUrlToSave = uploaded;
        }
      }

      final updated = await AssetService.updateAsset(
        assetId: _currentAsset.assetId,
        itemName: _nameController.text.trim(),
        classificationAcronym: _currentAsset.classificationAcronym,
        locationAcronym: _currentAsset.locationAcronym,
        locationName: _currentAsset.locationName,
        dimensions: _dimensionsController.text.trim(),
        color: _colorController.text.trim(),
        model: _modelController.text.trim(),
        others: _othersController.text.trim(),
        remarks: _remarksController.text.trim(),
        photoUrl: photoUrlToSave,
        dateOfAcquisition: _effectiveDateOfAcquisition,
        acquisitionYear: _selectedYear,
        modeOfAcquisition: _modeOfAcquisition,
        quantity: _editQuantity,
        unitPrice: _editUnitPrice,
        rfidTag: _rfidController.text.trim(),
        conditionStatus: _conditionStatus,
        operationalStatus: _operationalStatus,
      );

      if (!mounted) return;
      setState(() {
        _assetList[_currentIndex] = updated;
        _newWatermarkedPhotoBytes = null;
        _newPhotoFileName = null;
        _isEditing = false;
        _isUpdating = false;
      });

      widget.onAssetUpdated?.call();
      _loadAuditHistory();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _operationalStatus == 'Disposed'
                ? 'Item marked as Disposed and moved to Archive.'
                : 'Item record updated successfully.',
          ),
          backgroundColor: ParishColors.oliveGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUpdating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Update failed: $e'),
          backgroundColor: ParishColors.mercyRed,
        ),
      );
    }
  }

  Future<void> _confirmArchiveAsset() async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Archive Parish Item?',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: ParishColors.textDark,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to archive "${_currentAsset.itemName}" (${_currentAsset.controlNumber})?',
              style: TextStyle(fontSize: 13, color: ParishColors.textDark),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonController,
              style: TextStyle(fontSize: 13, color: ParishColors.textDark),
              decoration: InputDecoration(
                labelText: 'Reason for Archiving *',
                labelStyle: TextStyle(color: ParishColors.textDark),
                border: const OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: ParishColors.borderGrey),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: ParishColors.textMuted),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ParishColors.mercyRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (reasonController.text.trim().isNotEmpty) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirmed == true && reasonController.text.trim().isNotEmpty) {
      await AssetService.archiveAsset(
        assetId: _currentAsset.assetId,
        reason: reasonController.text.trim(),
      );
      if (!mounted) return;
      widget.onAssetUpdated?.call();
      Navigator.pop(context);
    }
  }

  Future<void> _restoreAsset() async {
    await AssetService.restoreAsset(_currentAsset.assetId);
    if (!mounted) return;
    widget.onAssetUpdated?.call();
    Navigator.pop(context);
  }

  Future<void> _printLabelSticker() async {
    await AssetLabelPdfService.printSingleAssetLabel(_currentAsset);
  }

  @override
  Widget build(BuildContext context) {
    final asset = _currentAsset;
    final isArchived = asset.isEffectivelyArchived;
    final totalCount = _assetList.length;
    final currentPos = _currentIndex + 1;

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final bool isMobile = screenWidth < 700;

        return Scaffold(
          backgroundColor: ParishColors.backgroundLight,
          appBar: AppBar(
            backgroundColor: ParishColors.cardWhite,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: ParishColors.marianBlue),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        asset.controlNumber,
                        style: TextStyle(
                          fontSize: isMobile ? 15 : 18,
                          fontWeight: FontWeight.bold,
                          color: isArchived
                              ? ParishColors.mercyRed
                              : ParishColors.marianBlue,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: asset.conditionSurfaceColor,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: asset.conditionColor.withOpacity(0.4),
                        ),
                      ),
                      child: Text(
                        asset.conditionStatus.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: asset.conditionColor,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  asset.itemName,
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 12.5,
                    color: ParishColors.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            actions: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: ParishColors.marianBlueSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: ParishColors.marianBlue.withOpacity(0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, size: 22),
                      padding: EdgeInsets.zero,
                      constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                      color: _hasPrevious
                          ? ParishColors.marianBlue
                          : ParishColors.borderGrey,
                      tooltip: 'Previous Item',
                      onPressed: _hasPrevious ? _navigateToPrevious : null,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        '$currentPos / $totalCount',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: ParishColors.marianBlue,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, size: 22),
                      padding: EdgeInsets.zero,
                      constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                      color: _hasNext
                          ? ParishColors.marianBlue
                          : ParishColors.borderGrey,
                      tooltip: 'Next Item',
                      onPressed: _hasNext ? _navigateToNext : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 14 : 24,
                vertical: isMobile ? 14 : 22,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isMobile) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                side: BorderSide(color: ParishColors.borderGrey),
                              ),
                              onPressed:
                              _hasPrevious ? _navigateToPrevious : null,
                              icon: const Icon(Icons.arrow_back, size: 14),
                              label: const Text('Previous',
                                  style: TextStyle(fontSize: 11)),
                            ),
                            Text(
                              'Item $currentPos of $totalCount',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: ParishColors.textMuted,
                              ),
                            ),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                side: BorderSide(color: ParishColors.borderGrey),
                              ),
                              onPressed: _hasNext ? _navigateToNext : null,
                              icon: const Icon(Icons.arrow_forward, size: 14),
                              label: const Text('Next',
                                  style: TextStyle(fontSize: 11)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],

                      if (_isEditing)
                        _buildEditFormCard(isMobile)
                      else
                        _buildViewDetails(isMobile),

                      const SizedBox(height: 18),

                      _buildBottomActionBar(isMobile, isArchived),
                      const SizedBox(height: 36),
                    ],
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
  // View Details Mode: Executive Card UI for Diocesan Inventory Records
  // ===========================================================================

  Widget _buildViewDetails(bool isMobile) {
    final asset = _currentAsset;
    final textDark = ParishColors.textDark;
    final isArchived = asset.isEffectivelyArchived;

    final inventoryDateStr = asset.lastAuditedAt != null
        ? asset.formattedLastAuditedDate
        : asset.formattedRegistrationDate;

    final String costFormatted = asset.quantity > 1
        ? '${asset.formattedTotalCost} (${asset.formattedUnitPrice}/unit)'
        : asset.formattedTotalCost;

    final bool hasOtherDescriptions =
        asset.others != null && asset.others!.trim().isNotEmpty;
    final bool hasRfid =
        asset.rfidTag != null && asset.rfidTag!.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isArchived) ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: ParishColors.mercyRedSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ParishColors.mercyRed.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.archive_outlined,
                  color: ParishColors.mercyRed,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ARCHIVED / DISPOSED ITEM',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: ParishColors.mercyRed,
                        ),
                      ),
                      Text(
                        asset.archiveReason != null &&
                            asset.archiveReason!.isNotEmpty
                            ? 'Reason: ${asset.archiveReason}'
                            : 'This item has been officially disposed.',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        // 1. HERO HEADER: Watermarked Photo + Canonical Identity & Badges
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: ParishColors.cardWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ParishColors.borderGrey),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: EdgeInsets.all(isMobile ? 14 : 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPhotoThumbnail(size: isMobile ? 96 : 130),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4.5),
                      decoration: BoxDecoration(
                        color: isArchived
                            ? ParishColors.mercyRedSurface
                            : ParishColors.goldLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isArchived
                              ? ParishColors.mercyRed.withOpacity(0.6)
                              : ParishColors.goldAccent.withOpacity(0.8),
                          width: 1.2,
                        ),
                      ),
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 2,
                        children: [
                          Icon(
                            Icons.qr_code_2,
                            size: 16,
                            color: isArchived
                                ? ParishColors.mercyRed
                                : ParishColors.goldAccent,
                          ),
                          Text(
                            'DIOCESAN CONTROL NO:',
                            style: TextStyle(
                              fontSize: isMobile ? 9.5 : 10.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              color: isArchived
                                  ? ParishColors.mercyRed
                                  : ParishColors.goldAccent,
                            ),
                          ),
                          Text(
                            asset.controlNumber,
                            style: TextStyle(
                              fontFamily: 'Courier',
                              fontSize: isMobile ? 12.5 : 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                              color: isArchived
                                  ? ParishColors.mercyRed
                                  : ParishColors.textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    Text(
                      asset.itemName,
                      style: TextStyle(
                        fontSize: isMobile ? 17 : 22,
                        fontWeight: FontWeight.bold,
                        color: textDark,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: asset.unitPrice >= 10000.0
                                ? ParishColors.goldLight
                                : ParishColors.marianBlueSurface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: asset.unitPrice >= 10000.0
                                  ? ParishColors.goldAccent
                                  : ParishColors.marianBlue,
                              width: 1.0,
                            ),
                          ),
                          child: Text(
                            asset.inventorySection,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: asset.unitPrice >= 10000.0
                                  ? ParishColors.goldAccent
                                  : ParishColors.marianBlue,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: asset.statusSurfaceColor,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: asset.statusColor.withOpacity(0.3)),
                          ),
                          child: Text(
                            asset.operationalStatus,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: asset.statusColor,
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

        const SizedBox(height: 16),

        // 2. PARISH BOOK OF INVENTORY RECORD CARD
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: ParishColors.cardWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ParishColors.borderGrey),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: EdgeInsets.all(isMobile ? 14 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ParishColors.marianBlueSurface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.menu_book_rounded,
                      size: 18,
                      color: ParishColors.marianBlue,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Parish Book of Inventory Record',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: ParishColors.textDark,
                          ),
                        ),
                        Text(
                          'Canonical particulars formatted for official diocesan ledger verification',
                          style: TextStyle(
                            fontSize: 11,
                            color: ParishColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 22),

              isMobile
                  ? Column(
                children: [
                  _buildInfoTile('Control Number', asset.controlNumber,
                      Icons.qr_code,
                      isMono: true),
                  const SizedBox(height: 8),
                  _buildInfoTile('Date of Inventory', inventoryDateStr,
                      Icons.event_note_outlined),
                ],
              )
                  : Row(
                children: [
                  Expanded(
                    child: _buildInfoTile(
                        'Control Number',
                        asset.controlNumber,
                        Icons.qr_code,
                        isMono: true),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInfoTile('Date of Inventory',
                        inventoryDateStr, Icons.event_note_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              isMobile
                  ? Column(
                children: [
                  _buildInfoTile('Item Name', asset.itemName,
                      Icons.inventory_2_outlined),
                  const SizedBox(height: 8),
                  _buildInfoTile('Storage Location', asset.displayLocation,
                      Icons.location_on_outlined),
                  const SizedBox(height: 8),
                  _buildInfoTile(
                      'Date Acquired',
                      asset.formattedAcquisitionDate,
                      Icons.calendar_today_outlined),
                  const SizedBox(height: 8),
                  _buildInfoTile('Mode of Acquisition',
                      asset.modeOfAcquisition, Icons.shopping_bag_outlined),
                  const SizedBox(height: 8),
                  _buildInfoTile('Cost of Acquisition', costFormatted,
                      Icons.payments_outlined,
                      isPrice: true),
                ],
              )
                  : Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoTile('Item Name', asset.itemName,
                            Icons.inventory_2_outlined),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInfoTile(
                            'Storage Location',
                            asset.displayLocation,
                            Icons.location_on_outlined),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoTile(
                            'Date Acquired',
                            asset.formattedAcquisitionDate,
                            Icons.calendar_today_outlined),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInfoTile(
                            'Mode of Acquisition',
                            asset.modeOfAcquisition,
                            Icons.shopping_bag_outlined),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildInfoTile('Cost of Acquisition', costFormatted,
                      Icons.payments_outlined,
                      isPrice: true),
                ],
              ),

              const SizedBox(height: 16),

              // Physical Specifications
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: ParishColors.backgroundLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: ParishColors.borderGrey.withOpacity(0.7)),
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.straighten_outlined,
                            size: 16, color: ParishColors.marianBlue),
                        const SizedBox(width: 8),
                        Text(
                          'PHYSICAL SPECIFICATIONS & DIMENSIONS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: ParishColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),

                    isMobile
                        ? Column(
                      children: [
                        _buildSpecCard(
                          label: 'Dimension',
                          value: asset.dimensions ?? '—',
                          icon: Icons.aspect_ratio_outlined,
                        ),
                        const SizedBox(height: 8),
                        _buildSpecCard(
                          label: 'Color',
                          value: asset.color ?? '—',
                          icon: Icons.palette_outlined,
                        ),
                        const SizedBox(height: 8),
                        _buildSpecCard(
                          label: 'Model',
                          value: asset.model ?? '—',
                          icon: Icons.devices_other_outlined,
                        ),
                      ],
                    )
                        : Row(
                      children: [
                        Expanded(
                          child: _buildSpecCard(
                            label: 'Dimension',
                            value: asset.dimensions ?? '—',
                            icon: Icons.aspect_ratio_outlined,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildSpecCard(
                            label: 'Color',
                            value: asset.color ?? '—',
                            icon: Icons.palette_outlined,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildSpecCard(
                            label: 'Model',
                            value: asset.model ?? '—',
                            icon: Icons.devices_other_outlined,
                          ),
                        ),
                      ],
                    ),

                    if (hasOtherDescriptions) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: ParishColors.borderGrey.withOpacity(0.8)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(Icons.description_outlined,
                                  size: 16, color: ParishColors.marianBlue),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'OTHER DESCRIPTIONS',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                      color: ParishColors.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    asset.others!.trim(),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: ParishColors.textDark,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (hasRfid) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: ParishColors.borderGrey.withOpacity(0.8)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.nfc,
                                size: 16, color: ParishColors.marianBlue),
                            const SizedBox(width: 8),
                            Text(
                              'WIRELESS RFID / NFC: ',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.4,
                                color: ParishColors.textMuted,
                              ),
                            ),
                            Text(
                              asset.rfidTag!.trim(),
                              style: const TextStyle(
                                fontFamily: 'Courier',
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: ParishColors.marianBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Remarks
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: ParishColors.backgroundLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: ParishColors.borderGrey.withOpacity(0.7)),
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.notes_rounded,
                            size: 15, color: ParishColors.marianBlue),
                        const SizedBox(width: 6),
                        Text(
                          'REMARKS & MAINTENANCE OBSERVATIONS',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: ParishColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      (asset.remarks != null && asset.remarks!.trim().isNotEmpty)
                          ? asset.remarks!.trim()
                          : (asset.quantity > 1
                          ? 'Quantity: ${asset.quantity} units. Condition: ${asset.conditionStatus.toUpperCase()} • Availability: ${asset.operationalStatus}'
                          : 'Condition: ${asset.conditionStatus.toUpperCase()} • Availability: ${asset.operationalStatus}'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        height: 1.45,
                        color: ParishColors.textDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 3. AVAILABILITY & LIVE VALUATION METRICS DECK
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ParishColors.cardWhite,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ParishColors.borderGrey),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'AVAILABILITY & VALUATION METRICS',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.6,
                      color: ParishColors.textMuted,
                    ),
                  ),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: asset.conditionSurfaceColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Condition: ${asset.conditionStatus}',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: asset.conditionColor,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMetricCell('Quantity', '${asset.quantity} unit(s)',
                      ParishColors.marianBlue),
                  Container(
                      width: 1, height: 32, color: ParishColors.borderGrey),
                  _buildMetricCell('Price / Unit', asset.formattedUnitPrice,
                      ParishColors.marianBlue),
                  Container(
                      width: 1, height: 32, color: ParishColors.borderGrey),
                  _buildMetricCell('Total Valuation', asset.formattedTotalCost,
                      ParishColors.oliveGreen),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 4. AUDIT & ADJUSTMENT HISTORY
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ParishColors.cardWhite,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ParishColors.borderGrey),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Audit & Adjustment History',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                  Text(
                    '${_auditHistory.length} record(s)',
                    style:
                    TextStyle(fontSize: 11.5, color: ParishColors.textMuted),
                  ),
                ],
              ),
              const Divider(height: 18),
              if (_isLoadingHistory)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_auditHistory.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'No physical audits or quantity adjustments recorded yet.',
                      style: TextStyle(
                          fontSize: 12, color: ParishColors.textMuted),
                    ),
                  ),
                )
              else
                ..._auditHistory.map((log) => _buildAuditLogTile(log)),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // Modular Tile & Spec Card Helpers
  // ===========================================================================

  Widget _buildSpecCard({
    required String label,
    required String value,
    required IconData icon,
  }) {
    final bool isEmpty = value.trim().isEmpty || value.trim() == '—';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ParishColors.borderGrey.withOpacity(0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: ParishColors.marianBlue),
              const SizedBox(width: 6),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.4,
                  color: ParishColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isEmpty
                  ? ParishColors.textMuted.withOpacity(0.6)
                  : ParishColors.textDark,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon,
      {bool isMono = false, bool isPrice = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: ParishColors.backgroundLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ParishColors.borderGrey.withOpacity(0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: ParishColors.marianBlue),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                    color: ParishColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: isMono ? 'Courier' : null,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isPrice ? ParishColors.oliveGreen : ParishColors.textDark,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCell(String title, String value, Color color) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
              fontSize: 11,
              color: ParishColors.textMuted,
              fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
              color: color),
        ),
      ],
    );
  }

  // ===========================================================================
  // UI Helpers: General Headers & Floating Label Input Decoration (No Hint Text)
  // ===========================================================================

  Widget _buildGeneralHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: ParishColors.textDark,
        letterSpacing: 0.2,
      ),
    );
  }

  InputDecoration _floatingInputDecoration({
    required String labelText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: ParishColors.textMuted,
      ),
      floatingLabelStyle: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.bold,
        color: ParishColors.marianBlue,
      ),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: ParishColors.backgroundLight,
      isDense: true,
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: ParishColors.borderGrey),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: ParishColors.borderGrey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide:
        const BorderSide(color: ParishColors.marianBlue, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: ParishColors.mercyRed, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: ParishColors.mercyRed, width: 1.5),
      ),
    );
  }

  // ===========================================================================
  // Separated Inline Date Selector (Month, Day, Year with Year Capped at Now)
  // ===========================================================================

  Widget _buildSeparatedDateSelectors(bool isMobile) {
    final now = DateTime.now();

    // Strict validation: do not allow future years
    final years = List<int>.generate(
      now.year - 1940 + 1,
          (i) => now.year - i,
    );

    // Calculate maximum days in selected month
    int maxDays = 31;
    if (_selectedMonth != null) {
      if ([4, 6, 9, 11].contains(_selectedMonth)) {
        maxDays = 30;
      } else if (_selectedMonth == 2) {
        final isLeap = (_selectedYear % 4 == 0 &&
            (_selectedYear % 100 != 0 || _selectedYear % 400 == 0));
        maxDays = isLeap ? 29 : 28;
      }
    }

    // If current year and current month are selected, cap maxDays at today
    if (_selectedYear == now.year &&
        _selectedMonth != null &&
        _selectedMonth == now.month) {
      if (now.day < maxDays) {
        maxDays = now.day;
      }
    }

    final days = List<int>.generate(maxDays, (i) => i + 1);

    // Max selectable months for current year
    final int maxMonthIndex =
    _selectedYear == now.year ? now.month : 12;

    return Row(
      children: [
        // Month Dropdown (Optional, starts null, never forced to January)
        Expanded(
          flex: isMobile ? 4 : 5,
          child: DropdownButtonFormField<int?>(
            value: _selectedMonth,
            isExpanded: true,
            decoration: _floatingInputDecoration(
              labelText: 'Month',
            ),
            items: [
              DropdownMenuItem<int?>(
                value: null,
                child: Text(
                  'Month (Optional)',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: ParishColors.textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ...List.generate(maxMonthIndex, (index) {
                final monthNum = index + 1;
                return DropdownMenuItem<int?>(
                  value: monthNum,
                  child: Text(
                    _monthNames[index],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: ParishColors.textDark,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }),
            ],
            onChanged: (val) {
              setState(() {
                _selectedMonth = val;
                if (_selectedDay != null && _selectedDay! > maxDays) {
                  _selectedDay = maxDays;
                }
              });
            },
          ),
        ),
        const SizedBox(width: 8),

        // Day Dropdown (Optional, starts null, never forced to 1st)
        Expanded(
          flex: isMobile ? 3 : 3,
          child: DropdownButtonFormField<int?>(
            value: (_selectedDay != null && _selectedDay! <= maxDays)
                ? _selectedDay
                : null,
            isExpanded: true,
            decoration: _floatingInputDecoration(
              labelText: 'Day',
            ),
            items: [
              DropdownMenuItem<int?>(
                value: null,
                child: Text(
                  'Day',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: ParishColors.textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ...days.map(
                    (d) => DropdownMenuItem<int?>(
                  value: d,
                  child: Text(
                    '$d',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: ParishColors.textDark,
                    ),
                  ),
                ),
              ),
            ],
            onChanged: (val) => setState(() => _selectedDay = val),
          ),
        ),
        const SizedBox(width: 8),

        // Year Dropdown (Required, strictly no future years)
        Expanded(
          flex: isMobile ? 4 : 4,
          child: DropdownButtonFormField<int>(
            value: _selectedYear,
            isExpanded: true,
            decoration: _floatingInputDecoration(
              labelText: 'Year *',
            ),
            items: years.map((y) {
              return DropdownMenuItem<int>(
                value: y,
                child: Text(
                  '$y',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: ParishColors.textDark,
                  ),
                ),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _selectedYear = val;
                  if (_selectedYear == now.year &&
                      _selectedMonth != null &&
                      _selectedMonth! > now.month) {
                    _selectedMonth = now.month;
                  }
                  if (_selectedYear == now.year &&
                      _selectedMonth != null &&
                      _selectedMonth == now.month &&
                      _selectedDay != null &&
                      _selectedDay! > now.day) {
                    _selectedDay = now.day;
                  }
                });
              }
            },
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // Responsive Edit Form Card Mode (General Headers & Floating Labels)
  // ===========================================================================

  Widget _buildEditFormCard(bool isMobile) {
    final asset = _currentAsset;
    final textDark = ParishColors.textDark;
    final borderGrey = ParishColors.borderGrey;

    return Container(
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderGrey),
      ),
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: ParishColors.marianBlueSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ParishColors.marianBlue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_outline,
                    size: 18, color: ParishColors.marianBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Control Number (${asset.controlNumber}) and Category are locked to preserve canonical ledger integrity.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: ParishColors.marianBlue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Photo Upload / Camera Strip
          _buildGeneralHeader('Photographic Evidence'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ParishColors.backgroundLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderGrey),
            ),
            child: Row(
              children: [
                InkWell(
                  onTap: () {
                    if (_newWatermarkedPhotoBytes != null) {
                      _openInteractivePreview(
                          MemoryImage(_newWatermarkedPhotoBytes!));
                    } else if (asset.photoUrl != null &&
                        asset.photoUrl!.isNotEmpty) {
                      _openInteractivePreview(NetworkImage(asset.photoUrl!));
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderGrey),
                    ),
                    child: _isProcessingImage
                        ? const Center(
                        child: CircularProgressIndicator(strokeWidth: 2))
                        : _newWatermarkedPhotoBytes != null
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: Image.memory(
                        _newWatermarkedPhotoBytes!,
                        fit: BoxFit.cover,
                      ),
                    )
                        : (asset.photoUrl != null &&
                        asset.photoUrl!.isNotEmpty)
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: Image.network(
                        asset.photoUrl!,
                        fit: BoxFit.cover,
                      ),
                    )
                        : const Icon(Icons.photo_outlined,
                        size: 36, color: ParishColors.marianBlue),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _newWatermarkedPhotoBytes != null
                            ? 'New 3R Photo Attached'
                            : (asset.photoUrl != null
                            ? 'Current Photo Registered'
                            : 'No photo uploaded'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _newWatermarkedPhotoBytes != null
                              ? ParishColors.oliveGreen
                              : textDark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          // Dedicated 3R Camera Launch Button
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ParishColors.marianBlue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                            ),
                            onPressed: _isProcessingImage
                                ? null
                                : _openDedicated3RCameraPage,
                            icon: const Icon(Icons.camera_alt, size: 14),
                            label: const Text(
                              '3R Camera',
                              style: TextStyle(
                                  fontSize: 11.5, fontWeight: FontWeight.bold),
                            ),
                          ),

                          // File Picker Upload Button
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: ParishColors.marianBlue,
                              side:
                              const BorderSide(color: ParishColors.marianBlue),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                            ),
                            onPressed: _isProcessingImage
                                ? null
                                : _pickImageFromDevice,
                            icon: const Icon(Icons.upload_file, size: 14),
                            label: const Text('Upload',
                                style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold)),
                          ),

                          if (_newWatermarkedPhotoBytes != null ||
                              (asset.photoUrl != null &&
                                  asset.photoUrl!.isNotEmpty)) ...[
                            TextButton.icon(
                              onPressed: () {
                                if (_newWatermarkedPhotoBytes != null) {
                                  _openInteractivePreview(
                                      MemoryImage(_newWatermarkedPhotoBytes!));
                                } else if (asset.photoUrl != null) {
                                  _openInteractivePreview(
                                      NetworkImage(asset.photoUrl!));
                                }
                              },
                              icon: const Icon(Icons.zoom_in, size: 14),
                              label: const Text('Inspect',
                                  style: TextStyle(fontSize: 11.5)),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // General Header: Name
          _buildGeneralHeader('Name'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _nameController,
            style: TextStyle(
              fontSize: 14,
              color: textDark,
              fontWeight: FontWeight.bold,
            ),
            decoration: _floatingInputDecoration(
              labelText: 'Item Name *',
            ),
          ),
          const SizedBox(height: 18),

          // General Header: Date of Acquisition (Separated Inline Dropdowns, No Future Dates)
          _buildGeneralHeader('Date of Acquisition'),
          const SizedBox(height: 8),
          _buildSeparatedDateSelectors(isMobile),
          const SizedBox(height: 18),

          // General Header: Acquisition Method
          _buildGeneralHeader('Acquisition Method'),
          const SizedBox(height: 8),
          _buildAcquisitionModeDropdown(),
          const SizedBox(height: 18),

          // General Header: Quantity & Valuation
          _buildGeneralHeader('Quantity & Valuation'),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: TextStyle(
                    fontSize: 14,
                    color: textDark,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: _floatingInputDecoration(
                    labelText: 'Quantity *',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: _unitPriceController,
                  keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [ThousandsSeparatorCurrencyFormatter()],
                  style: TextStyle(
                    fontSize: 14,
                    color: textDark,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: _floatingInputDecoration(
                    labelText: 'Price per Unit (₱)',
                    prefixIcon: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 12),
                      child: Text('₱',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, color: textDark)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: ParishColors.backgroundLight,
              borderRadius: BorderRadius.circular(8),
              border:
              Border.all(color: ParishColors.oliveGreen.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total: ₱ ${AssetModel.formatCurrency(_editCalculatedTotalCost)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: ParishColors.oliveGreen,
                  ),
                ),
                Text(
                  _editDeterminedSection,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: ParishColors.marianBlue,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // General Header: Condition & Availability
          _buildGeneralHeader('Condition & Availability'),
          const SizedBox(height: 8),
          isMobile
              ? Column(
            children: [
              _buildConditionDropdown(),
              const SizedBox(height: 12),
              _buildOperationalStatusDropdown(),
            ],
          )
              : Row(
            children: [
              Expanded(
                child: _buildConditionDropdown(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildOperationalStatusDropdown(),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // General Header: Wireless Identification
          _buildGeneralHeader('Wireless Identification'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _rfidController,
            style: TextStyle(
              fontSize: 13.5,
              color: textDark,
              fontWeight: FontWeight.bold,
            ),
            decoration: _floatingInputDecoration(
              labelText: 'Wireless RFID / NFC Tag (Optional)',
            ),
          ),
          const SizedBox(height: 18),

          // General Header: Dimensions & Make
          _buildGeneralHeader('Dimensions & Make'),
          const SizedBox(height: 8),
          isMobile
              ? Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _dimensionsController,
                      style: TextStyle(
                        fontSize: 13,
                        color: textDark,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: _floatingInputDecoration(
                        labelText: 'Dimensions',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _colorController,
                      style: TextStyle(
                        fontSize: 13,
                        color: textDark,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: _floatingInputDecoration(
                        labelText: 'Color',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _modelController,
                style: TextStyle(
                  fontSize: 13,
                  color: textDark,
                  fontWeight: FontWeight.bold,
                ),
                decoration: _floatingInputDecoration(
                  labelText: 'Model / Maker',
                ),
              ),
            ],
          )
              : Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _dimensionsController,
                  style: TextStyle(
                    fontSize: 13,
                    color: textDark,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: _floatingInputDecoration(
                    labelText: 'Size / Dimensions',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _colorController,
                  style: TextStyle(
                    fontSize: 13,
                    color: textDark,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: _floatingInputDecoration(
                    labelText: 'Color',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _modelController,
                  style: TextStyle(
                    fontSize: 13,
                    color: textDark,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: _floatingInputDecoration(
                    labelText: 'Model / Brand',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // General Header: Additional Details
          _buildGeneralHeader('Additional Details & Inscriptions'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _othersController,
            maxLines: 2,
            style: TextStyle(
              fontSize: 13,
              color: textDark,
              fontWeight: FontWeight.bold,
            ),
            decoration: _floatingInputDecoration(
              labelText: 'Other Descriptions / Inscriptions',
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _remarksController,
            maxLines: 2,
            style: TextStyle(
              fontSize: 13,
              color: textDark,
              fontWeight: FontWeight.bold,
            ),
            decoration: _floatingInputDecoration(
              labelText: 'Remarks & Maintenance Observations',
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Bottom Action Bar
  // ===========================================================================

  Widget _buildBottomActionBar(bool isMobile, bool isArchived) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 18,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ParishColors.borderGrey),
      ),
      child: isMobile
          ? Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ParishColors.marianBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: _printLabelSticker,
                  icon: const Icon(Icons.qr_code, size: 16),
                  label: const Text('Print QR Tag',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
              if (_canArchive) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: isArchived
                      ? OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ParishColors.oliveGreen,
                      side: const BorderSide(
                          color: ParishColors.oliveGreen),
                      padding:
                      const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: _restoreAsset,
                    icon: const Icon(Icons.restore, size: 16),
                    label: const Text('Restore',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  )
                      : OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ParishColors.mercyRed,
                      side: const BorderSide(
                          color: ParishColors.mercyRed),
                      padding:
                      const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: _confirmArchiveAsset,
                    icon:
                    const Icon(Icons.archive_outlined, size: 16),
                    label: const Text('Archive',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_canModify) ...[
                if (_isEditing) ...[
                  TextButton(
                    onPressed: _isUpdating
                        ? null
                        : () => setState(() => _isEditing = false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ParishColors.oliveGreen,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _isUpdating ? null : _saveAssetUpdates,
                    icon: _isUpdating
                        ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                        : const Icon(Icons.save, size: 16),
                    label: Text(_isUpdating ? 'Saving...' : 'Save Changes'),
                  ),
                ] else ...[
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _isEditing = true),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit Details'),
                  ),
                ],
              ],
            ],
          ),
        ],
      )
          : Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ParishColors.marianBlue,
                  foregroundColor: Colors.white,
                ),
                onPressed: _printLabelSticker,
                icon: const Icon(Icons.qr_code, size: 16),
                label: const Text('Print QR Tag',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),
              if (_canArchive)
                isArchived
                    ? OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ParishColors.oliveGreen,
                    side: const BorderSide(
                        color: ParishColors.oliveGreen),
                  ),
                  onPressed: _restoreAsset,
                  icon: const Icon(Icons.restore, size: 16),
                  label: const Text('Restore Asset'),
                )
                    : OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ParishColors.mercyRed,
                    side: const BorderSide(
                        color: ParishColors.mercyRed),
                  ),
                  onPressed: _confirmArchiveAsset,
                  icon:
                  const Icon(Icons.archive_outlined, size: 16),
                  label: const Text('Archive Item'),
                ),
            ],
          ),
          Row(
            children: [
              if (_canModify) ...[
                if (_isEditing) ...[
                  TextButton(
                    onPressed: _isUpdating
                        ? null
                        : () => setState(() => _isEditing = false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ParishColors.oliveGreen,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _isUpdating ? null : _saveAssetUpdates,
                    icon: _isUpdating
                        ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                        : const Icon(Icons.save, size: 16),
                    label: Text(_isUpdating ? 'Saving...' : 'Save Changes'),
                  ),
                ] else ...[
                  OutlinedButton.icon(
                    style: ElevatedButton.styleFrom(
                      side: const BorderSide(
                          color: ParishColors.marianBlue, width: 1.4),
                      backgroundColor: ParishColors.marianBlueSurface,
                    ),
                    onPressed: () => setState(() => _isEditing = true),
                    icon: const Icon(Icons.edit_outlined,
                        size: 16, color: ParishColors.marianBlue),
                    label: const Text('Edit Details',
                        style: TextStyle(
                            color: ParishColors.marianBlue,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Helper Widgets
  // ===========================================================================

  Widget _buildPhotoThumbnail({required double size}) {
    final asset = _currentAsset;
    final borderGrey = ParishColors.borderGrey;

    return Tooltip(
      message: asset.photoUrl != null && asset.photoUrl!.isNotEmpty
          ? 'Tap to inspect photo with security watermark'
          : 'No photo uploaded',
      child: InkWell(
        onTap: asset.photoUrl != null && asset.photoUrl!.isNotEmpty
            ? () => _openInteractivePreview(NetworkImage(asset.photoUrl!))
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: ParishColors.backgroundLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
              asset.photoUrl != null ? ParishColors.goldAccent : borderGrey,
              width: asset.photoUrl != null ? 1.5 : 1.0,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: asset.photoUrl != null && asset.photoUrl!.isNotEmpty
                ? Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  asset.photoUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Center(
                    child: Icon(asset.classificationIcon,
                        size: 36, color: ParishColors.marianBlue),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: Colors.black54,
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: const Text(
                      'WATERMARKED',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 7.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            )
                : Center(
              child: Icon(asset.classificationIcon,
                  size: 36, color: ParishColors.marianBlue),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAuditLogTile(AssetAuditLogModel log) {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;

    final int totalDistQty = log.quantityDistribution != null
        ? log.quantityDistribution!.fold<int>(0, (sum, d) => sum + d.quantity)
        : 0;
    final bool showDistributionCard = log.hasQuantityDistribution && totalDistQty > 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: log.hasQuantityAdjustment
            ? ParishColors.goldLight.withOpacity(0.4)
            : (showDistributionCard
            ? ParishColors.marianBlueSurface.withOpacity(0.3)
            : ParishColors.backgroundLight),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: log.hasQuantityAdjustment
              ? ParishColors.goldAccent.withOpacity(0.6)
              : (showDistributionCard
              ? ParishColors.marianBlue.withOpacity(0.35)
              : ParishColors.borderGrey),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                log.auditMethod == 'RFID_NFC'
                    ? Icons.nfc
                    : Icons.qr_code_scanner,
                size: 16,
                color: ParishColors.marianBlue,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Condition: ${log.newCondition}',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: textDark),
                        ),
                        Text(
                          log.formattedAuditedAt,
                          style: TextStyle(fontSize: 10.5, color: textMuted),
                        ),
                      ],
                    ),
                    if (log.newStatus != null && log.newStatus!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text('Availability: ${log.newStatus}',
                          style: TextStyle(fontSize: 11, color: textMuted)),
                    ],
                    if (log.newLocation != null &&
                        log.newLocation!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text('Location: ${log.newLocation}',
                          style: TextStyle(fontSize: 11, color: textMuted)),
                    ],
                  ],
                ),
              ),
            ],
          ),

          if (showDistributionCard) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: ParishColors.marianBlue.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.pie_chart_outline_rounded,
                        size: 14,
                        color: ParishColors.marianBlue,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'VERIFIED QUANTITY DISTRIBUTION',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: ParishColors.marianBlue,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$totalDistQty units reconciled',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: ParishColors.textDark,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: log.quantityDistribution!.map((dist) {
                      final bool isDamaged =
                          dist.physicalCondition.toLowerCase() == 'damaged';
                      final bool isInUse =
                      dist.utilizationStatus.toLowerCase().contains('use');

                      Color badgeBg;
                      Color badgeBorder;
                      Color badgeText;

                      if (isDamaged) {
                        badgeBg = ParishColors.mercyRedSurface;
                        badgeBorder = ParishColors.mercyRed.withOpacity(0.5);
                        badgeText = ParishColors.mercyRed;
                      } else if (isInUse) {
                        badgeBg = ParishColors.marianBlueSurface;
                        badgeBorder = ParishColors.marianBlue.withOpacity(0.3);
                        badgeText = ParishColors.marianBlue;
                      } else {
                        badgeBg = ParishColors.oliveGreenSurface;
                        badgeBorder = ParishColors.oliveGreen.withOpacity(0.3);
                        badgeText = ParishColors.oliveGreen;
                      }

                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: badgeBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${dist.quantity}x ',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: badgeText,
                              ),
                            ),
                            Text(
                              '${dist.utilizationStatus} ',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: ParishColors.textDark,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(
                                    color: badgeBorder.withOpacity(0.6)),
                              ),
                              child: Text(
                                dist.physicalCondition,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: badgeText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],

          if (log.hasQuantityAdjustment) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border:
                Border.all(color: ParishColors.goldAccent.withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        (log.quantityChange ?? 0) > 0
                            ? Icons.add_circle
                            : Icons.remove_circle,
                        size: 14,
                        color: (log.quantityChange ?? 0) > 0
                            ? ParishColors.oliveGreen
                            : ParishColors.mercyRed,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Official Quantity Adjustment: ${log.formattedQuantityChange}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: (log.quantityChange ?? 0) > 0
                              ? ParishColors.oliveGreen
                              : ParishColors.mercyRed,
                        ),
                      ),
                    ],
                  ),
                  if (log.quantityChangeReason != null &&
                      log.quantityChangeReason!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Reason: ${log.quantityChangeReason}',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: textDark),
                    ),
                  ],
                ],
              ),
            ),
          ],

          if (log.cleanNotes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Notes: ${log.cleanNotes}',
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: textDark)),
          ],
          if (log.auditorName != null) ...[
            const SizedBox(height: 4),
            Text(
              'Audited by: ${log.auditorName}',
              style: TextStyle(
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.bold,
                  color: textMuted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConditionDropdown() {
    final effective = AssetModel.normalizeCondition(_conditionStatus);
    final items = List<String>.from(_conditionOptions);
    if (!items.contains(effective)) items.add(effective);

    return DropdownButtonFormField<String>(
      value: effective,
      decoration: _floatingInputDecoration(
        labelText: 'Item Condition *',
      ),
      items: items.map((c) {
        final desc = AssetModel.conditionDescriptions[c] ?? '';
        return DropdownMenuItem(
          value: c,
          child: Text(
            desc.isNotEmpty ? '$c ($desc)' : c,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: ParishColors.textDark),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (val) {
        if (val != null) setState(() => _conditionStatus = val);
      },
    );
  }

  Widget _buildOperationalStatusDropdown() {
    final effective = AssetModel.normalizeStatus(_operationalStatus);
    final items = List<String>.from(_operationalStatusOptions);
    if (!items.contains(effective)) items.add(effective);

    return DropdownButtonFormField<String>(
      value: effective,
      decoration: _floatingInputDecoration(
        labelText: 'Availability *',
      ),
      items: items.map((s) {
        final desc = AssetModel.availabilityDescriptions[s] ?? '';
        return DropdownMenuItem(
          value: s,
          child: Text(
            desc.isNotEmpty ? '$s — $desc' : s,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: ParishColors.textDark),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (val) {
        if (val != null) setState(() => _operationalStatus = val);
      },
    );
  }

  Widget _buildAcquisitionModeDropdown() {
    return DropdownButtonFormField<String>(
      value: _modeOfAcquisition,
      isExpanded: true,
      decoration: _floatingInputDecoration(
        labelText: 'How Acquired *',
      ),
      items: _acquisitionModes
          .map((m) => DropdownMenuItem(value: m, child: Text(m)))
          .toList(),
      onChanged: (val) => setState(() => _modeOfAcquisition = val!),
    );
  }
}
