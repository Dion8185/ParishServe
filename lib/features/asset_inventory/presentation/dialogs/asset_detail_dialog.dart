// =============================================================================
// FILE: lib/features/asset_inventory/presentation/dialogs/asset_detail_dialog.dart
// =============================================================================

import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/colors.dart';
import '../../../auth/services/auth_service.dart';
import '../../models/asset_audit_log_model.dart';
import '../../models/asset_model.dart';
import '../../models/asset_reference_models.dart';
import '../../services/asset_label_pdf_service.dart';
import '../../services/asset_reference_service.dart';
import '../../services/asset_service.dart';
import '../../utils/asset_image_watermark_util.dart';
import '../pages/asset_detail_page.dart';
import 'register_asset_dialog.dart';

/// Opens the asset detail view. Automatically transitions to the full-page experience
/// with Previous/Next navigation when an asset list is provided.
void showAssetDetailModal(
    BuildContext context, {
      required AssetModel asset,
      VoidCallback? onAssetUpdated,
      List<AssetModel>? assetList,
      int? initialIndex,
    }) {
  final list = (assetList != null && assetList.isNotEmpty) ? assetList : [asset];
  final idx = initialIndex ?? list.indexWhere((a) => a.assetId == asset.assetId);
  final safeIdx = idx >= 0 ? idx : 0;

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => AssetDetailPage(
        assets: list,
        initialIndex: safeIdx,
        onAssetUpdated: onAssetUpdated,
      ),
    ),
  );
}

class _AssetDetailDialog extends StatefulWidget {
  final AssetModel initialAsset;
  final VoidCallback? onAssetUpdated;

  const _AssetDetailDialog({
    super.key,
    required this.initialAsset,
    this.onAssetUpdated,
  });

  @override
  State<_AssetDetailDialog> createState() => _AssetDetailDialogState();
}

class _AssetDetailDialogState extends State<_AssetDetailDialog> {
  late AssetModel _asset;
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
  late String _conditionStatus;
  late String _operationalStatus;
  late String _modeOfAcquisition;

  // Standardized Canonical Options
  final List<String> _conditionOptions = AssetModel.standardConditions;
  final List<String> _operationalStatusOptions = AssetModel.standardStatuses;

  bool get _isEffectivelyArchived => _asset.isEffectivelyArchived;

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

  @override
  void initState() {
    super.initState();
    _initializeAsset(widget.initialAsset);
  }

  void _initializeAsset(AssetModel asset) {
    _asset = asset;
    _conditionStatus = AssetModel.normalizeCondition(_asset.conditionStatus);
    _operationalStatus = AssetModel.normalizeStatus(_asset.operationalStatus);
    _modeOfAcquisition = _asset.modeOfAcquisition;

    _nameController = TextEditingController(text: _asset.itemName);
    _quantityController = TextEditingController(text: '${_asset.quantity}');
    _unitPriceController = TextEditingController(
      text: _asset.unitPrice > 0
          ? AssetModel.formatCurrency(_asset.unitPrice)
          : '',
    );
    _dimensionsController = TextEditingController(
      text: _asset.dimensions ?? '',
    );
    _colorController = TextEditingController(text: _asset.color ?? '');
    _modelController = TextEditingController(text: _asset.model ?? '');
    _othersController = TextEditingController(text: _asset.others ?? '');
    _remarksController = TextEditingController(text: _asset.remarks ?? '');
    _rfidController = TextEditingController(text: _asset.rfidTag ?? '');

    _quantityController.addListener(() => setState(() {}));
    _unitPriceController.addListener(() => setState(() {}));

    _loadAuditHistory();
    _loadReferenceOptions();
  }

  void _resetEditControllers() {
    _nameController.text = _asset.itemName;
    _quantityController.text = '${_asset.quantity}';
    _unitPriceController.text = _asset.unitPrice > 0
        ? AssetModel.formatCurrency(_asset.unitPrice)
        : '';
    _dimensionsController.text = _asset.dimensions ?? '';
    _colorController.text = _asset.color ?? '';
    _modelController.text = _asset.model ?? '';
    _othersController.text = _asset.others ?? '';
    _remarksController.text = _asset.remarks ?? '';
    _rfidController.text = _asset.rfidTag ?? '';
    _conditionStatus = AssetModel.normalizeCondition(_asset.conditionStatus);
    _operationalStatus = AssetModel.normalizeStatus(_asset.operationalStatus);
    _modeOfAcquisition = _asset.modeOfAcquisition;
    _newWatermarkedPhotoBytes = null;
    _newPhotoFileName = null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _unitPriceController.dispose();
    _dimensionsController.dispose();
    _colorController.dispose();
    _modelController.dispose();
    _othersController.dispose();
    _remarksController.dispose();
    _rfidController.dispose();
    super.dispose();
  }

  Future<void> _loadReferenceOptions() async {
    try {
      final locs = await AssetReferenceService.getLocations(activeOnly: false);
      final classifs = await AssetReferenceService.getClassifications(
        activeOnly: false,
      );
      if (!mounted) return;
      setState(() {
        _locations = locs;
        _classifications = classifs;
        _selectedLocation = locs.firstWhere(
              (l) =>
          l.acronym.toUpperCase() == _asset.locationAcronym.toUpperCase(),
          orElse: () => locs.first,
        );
        _selectedClassification = classifs.firstWhere(
              (c) =>
          c.acronym.toUpperCase() ==
              _asset.classificationAcronym.toUpperCase(),
          orElse: () => classifs.first,
        );
      });
    } catch (_) {}
  }

  Future<void> _loadAuditHistory() async {
    setState(() => _isLoadingHistory = true);
    try {
      final history = await AssetService.getAssetAuditHistory(_asset.assetId);
      if (!mounted) return;
      setState(() {
        _auditHistory = history;
        _isLoadingHistory = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingHistory = false);
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

  Future<void> _capturePhotoWithCamera() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 92,
      );

      if (photo != null) {
        final Uint8List rawBytes = await photo.readAsBytes();
        await _processAndWatermarkNewImage(
          rawBytes,
          photo.name.isNotEmpty ? photo.name : 'camera_photo.jpg',
        );
      }
    } catch (e) {
      debugPrint('Camera error: $e');
    }
  }

  Future<void> _processAndWatermarkNewImage(
      Uint8List rawBytes,
      String filename,
      ) async {
    setState(() => _isProcessingImage = true);

    try {
      final idLabel =
          '${_asset.controlNumber} • ${_nameController.text.trim()}';

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
      title: _asset.itemName,
      controlNumber: _asset.controlNumber,
    );
  }

  Future<void> _saveAssetUpdates() async {
    setState(() => _isUpdating = true);
    try {
      String? photoUrlToSave = _asset.photoUrl;

      if (_newWatermarkedPhotoBytes != null && _newPhotoFileName != null) {
        final uploaded = await AssetService.uploadAssetPhoto(
          assetId: _asset.assetId,
          fileBytes: _newWatermarkedPhotoBytes!,
          fileName: _newPhotoFileName!,
        );
        if (uploaded != null) {
          photoUrlToSave = uploaded;
        }
      }

      final updated = await AssetService.updateAsset(
        assetId: _asset.assetId,
        itemName: _nameController.text.trim(),
        classificationAcronym: _asset.classificationAcronym,
        locationAcronym: _asset.locationAcronym,
        locationName: _asset.locationName,
        dimensions: _dimensionsController.text.trim(),
        color: _colorController.text.trim(),
        model: _modelController.text.trim(),
        others: _othersController.text.trim(),
        remarks: _remarksController.text.trim(),
        photoUrl: photoUrlToSave,
        dateOfAcquisition: _asset.dateOfAcquisition,
        modeOfAcquisition: _modeOfAcquisition,
        quantity: _editQuantity,
        unitPrice: _editUnitPrice,
        rfidTag: _rfidController.text.trim(),
        conditionStatus: _conditionStatus,
        operationalStatus: _operationalStatus,
      );

      if (!mounted) return;
      setState(() {
        _asset = updated;
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
            _operationalStatus == 'Retired' || _operationalStatus == 'Disposed'
                ? 'Item marked as $_operationalStatus and moved to Archive.'
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
              'Are you sure you want to archive "${_asset.itemName}" (${_asset.controlNumber})?',
              style: TextStyle(fontSize: 13, color: ParishColors.textDark),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonController,
              style: TextStyle(fontSize: 13, color: ParishColors.textDark),
              decoration: InputDecoration(
                labelText: 'Reason for Archiving *',
                labelStyle: TextStyle(color: ParishColors.textDark),
                hintText: 'e.g. Broken beyond repair, replaced by newer unit',
                hintStyle: TextStyle(
                  fontSize: 12.5,
                  color: ParishColors.textMuted,
                ),
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
        assetId: _asset.assetId,
        reason: reasonController.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context);
      widget.onAssetUpdated?.call();
    }
  }

  Future<void> _restoreAsset() async {
    await AssetService.restoreAsset(_asset.assetId);
    if (!mounted) return;
    Navigator.pop(context);
    widget.onAssetUpdated?.call();
  }

  Future<void> _printLabelSticker() async {
    await AssetLabelPdfService.printSingleAssetLabel(_asset);
  }

  @override
  Widget build(BuildContext context) {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final cardWhite = ParishColors.cardWhite;
    final borderGrey = ParishColors.borderGrey;
    final isArchived = _isEffectivelyArchived;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 620;

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: cardWhite,
          insetPadding: EdgeInsets.symmetric(
            horizontal: isMobile ? 12 : 24,
            vertical: isMobile ? 14 : 24,
          ),
          child: Container(
            width: 820,
            constraints: const BoxConstraints(maxHeight: 840),
            child: Column(
              children: [
                // Header Banner
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 14 : 20,
                    vertical: isMobile ? 12 : 16,
                  ),
                  decoration: BoxDecoration(
                    color: isArchived
                        ? ParishColors.mercyRedSurface
                        : ParishColors.marianBlueSurface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    border: Border(bottom: BorderSide(color: borderGrey)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isArchived
                              ? ParishColors.mercyRed
                              : ParishColors.marianBlue,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _asset.classificationIcon,
                          color: Colors.white,
                          size: isMobile ? 18 : 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    _asset.controlNumber,
                                    style: TextStyle(
                                      fontSize: isMobile ? 14.5 : 16.5,
                                      fontWeight: FontWeight.bold,
                                      color: isArchived
                                          ? ParishColors.mercyRed
                                          : ParishColors.marianBlue,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _asset.conditionSurfaceColor,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: _asset.conditionColor.withOpacity(
                                        0.4,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    _asset.conditionStatus.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.bold,
                                      color: _asset.conditionColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Registered: ${_asset.formattedRegistrationDate} • ID: ${_asset.assetId}',
                              style: TextStyle(
                                fontSize: isMobile ? 10.5 : 11.5,
                                color: textMuted,
                              ),
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

                // Content Area
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isMobile ? 14 : 20),
                    child: _isEditing
                        ? _buildEditForm(isMobile)
                        : _buildViewDetails(isMobile),
                  ),
                ),

                // Footer Actions
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 12 : 20,
                    vertical: isMobile ? 10 : 14,
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
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ParishColors.marianBlue,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _printLabelSticker,
                        icon: const Icon(Icons.qr_code, size: 15),
                        label: const Text('Print QR Tag'),
                      ),
                      Row(
                        children: [
                          if (_canModify) ...[
                            if (_isEditing) ...[
                              TextButton(
                                onPressed: _isUpdating
                                    ? null
                                    : () {
                                  _resetEditControllers();
                                  setState(() => _isEditing = false);
                                },
                                child: const Text('Cancel'),
                              ),
                              const SizedBox(width: 6),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: ParishColors.oliveGreen,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: _isUpdating ? null : _saveAssetUpdates,
                                child: Text(_isUpdating ? 'Saving...' : 'Save'),
                              ),
                            ] else ...[
                              OutlinedButton.icon(
                                onPressed: () => setState(() => _isEditing = true),
                                icon: const Icon(Icons.edit_outlined, size: 15),
                                label: const Text('Edit'),
                              ),
                            ],
                          ],
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
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
      },
    );
  }

  Widget _buildViewDetails(bool isMobile) {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final borderGrey = ParishColors.borderGrey;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: _asset.photoUrl != null && _asset.photoUrl!.isNotEmpty
                  ? () => _openInteractivePreview(NetworkImage(_asset.photoUrl!))
                  : null,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: ParishColors.backgroundLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderGrey),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: _asset.photoUrl != null && _asset.photoUrl!.isNotEmpty
                      ? Image.network(_asset.photoUrl!, fit: BoxFit.cover)
                      : Icon(_asset.classificationIcon, color: ParishColors.marianBlue, size: 36),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _asset.itemName,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: _asset.statusSurfaceColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Status: ${_asset.operationalStatus}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _asset.statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildDataRow(Icons.category_outlined, 'Classification', _asset.displayClassification),
        _buildDataRow(Icons.location_on_outlined, 'Location', _asset.displayLocation),
        _buildDataRow(Icons.calendar_today_outlined, 'Acquisition', '${_asset.formattedAcquisitionDate} (${_asset.modeOfAcquisition})'),
        _buildDataRow(Icons.menu_book, 'Section', _asset.inventorySection),
        const Divider(height: 16),
        Row(
          children: [
            Expanded(child: _buildSpecItem('Quantity', '${_asset.quantity} units')),
            Expanded(child: _buildSpecItem('Unit Price', _asset.formattedUnitPrice)),
            Expanded(child: _buildSpecItem('Total Cost', _asset.formattedTotalCost)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildSpecItem('Size', _asset.dimensions ?? '—')),
            Expanded(child: _buildSpecItem('Color', _asset.color ?? '—')),
            Expanded(child: _buildSpecItem('Model', _asset.model ?? '—')),
          ],
        ),
      ],
    );
  }

  Widget _buildEditForm(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Item Name *'),
        TextFormField(controller: _nameController, decoration: _inputDecoration()),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Quantity *'),
                  TextFormField(controller: _quantityController, decoration: _inputDecoration()),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Price / Unit (₱)'),
                  TextFormField(controller: _unitPriceController, decoration: _inputDecoration()),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Condition *'),
                  _buildConditionDropdown(),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Status *'),
                  _buildOperationalStatusDropdown(),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConditionDropdown() {
    final effectiveCondition = AssetModel.normalizeCondition(_conditionStatus);
    final items = List<String>.from(_conditionOptions);
    if (!items.contains(effectiveCondition)) items.add(effectiveCondition);

    return DropdownButtonFormField<String>(
      value: effectiveCondition,
      decoration: _inputDecoration(),
      items: items.map((c) {
        return DropdownMenuItem(
          value: c,
          child: Text(c, style: TextStyle(fontSize: 13, color: ParishColors.textDark)),
        );
      }).toList(),
      onChanged: (val) {
        if (val != null) setState(() => _conditionStatus = val);
      },
    );
  }

  Widget _buildOperationalStatusDropdown() {
    final effectiveStatus = AssetModel.normalizeStatus(_operationalStatus);
    final items = List<String>.from(_operationalStatusOptions);
    if (!items.contains(effectiveStatus)) items.add(effectiveStatus);

    return DropdownButtonFormField<String>(
      value: effectiveStatus,
      decoration: _inputDecoration(),
      items: items.map((s) {
        return DropdownMenuItem(
          value: s,
          child: Text(s, style: TextStyle(fontSize: 13, color: ParishColors.textDark)),
        );
      }).toList(),
      onChanged: (val) {
        if (val != null) setState(() => _operationalStatus = val);
      },
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: ParishColors.textDark,
        ),
      ),
    );
  }

  Widget _buildDataRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: ParishColors.marianBlue),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: ParishColors.textMuted,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: ParishColors.textDark,
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
            fontSize: 10.5,
            color: ParishColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: ParishColors.textDark,
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({String? hint, Widget? prefixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 12.5, color: ParishColors.textMuted),
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: ParishColors.backgroundLight,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
        borderSide: BorderSide(color: ParishColors.marianBlue, width: 1.5),
      ),
    );
  }
}