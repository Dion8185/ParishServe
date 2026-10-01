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
import 'register_asset_dialog.dart';

void showAssetDetailModal(
    BuildContext context, {
      required AssetModel asset,
      VoidCallback? onAssetUpdated,
    }) {
  showDialog(
    context: context,
    builder: (ctx) => _AssetDetailDialog(
      initialAsset: asset,
      onAssetUpdated: onAssetUpdated,
    ),
  );
}

class _AssetDetailDialog extends StatefulWidget {
  final AssetModel initialAsset;
  final VoidCallback? onAssetUpdated;

  const _AssetDetailDialog({
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

  List<AssetModel> _groupSiblingUnits = [];
  bool _isLoadingSiblings = false;

  bool get _isEffectivelyArchived =>
      _asset.isArchived || _asset.operationalStatus.trim().toLowerCase() == 'decommissioned';

  bool get _canModify {
    final role = AuthService.currentUser?.userRole.toLowerCase() ?? '';
    return role == 'superadmin' ||
        role == 'admin' ||
        role == 'parishpriest' ||
        role == 'secretary' ||
        role == 'encoder';
  }

  bool get _canArchive {
    final role = AuthService.currentUser?.userRole.toLowerCase() ?? '';
    return role == 'superadmin' || role == 'admin' || role == 'parishpriest';
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
        ? 'Section 1 — 10,000.00 and Above'
        : 'Section 2 — Below 10,000.00';
  }

  String get _cleanBaseGroupName {
    return _asset.itemName.replaceAll(RegExp(r'\s*(—|-)?\s*\d{3}$'), '').trim();
  }

  @override
  void initState() {
    super.initState();
    _initializeAsset(widget.initialAsset);
  }

  void _initializeAsset(AssetModel asset) {
    _asset = asset;
    _conditionStatus = _asset.conditionStatus;
    _operationalStatus = _asset.operationalStatus;
    _modeOfAcquisition = _asset.modeOfAcquisition;

    _nameController = TextEditingController(text: _asset.itemName);
    _quantityController = TextEditingController(text: '${_asset.quantity}');
    _unitPriceController = TextEditingController(
      text: _asset.unitPrice > 0 ? AssetModel.formatCurrency(_asset.unitPrice) : '',
    );
    _dimensionsController = TextEditingController(text: _asset.dimensions ?? '');
    _colorController = TextEditingController(text: _asset.color ?? '');
    _modelController = TextEditingController(text: _asset.model ?? '');
    _othersController = TextEditingController(text: _asset.others ?? '');
    _remarksController = TextEditingController(text: _asset.remarks ?? '');
    _rfidController = TextEditingController(text: _asset.rfidTag ?? '');

    _quantityController.addListener(() => setState(() {}));
    _unitPriceController.addListener(() => setState(() {}));

    _loadAuditHistory();
    _loadReferenceOptions();
    _loadGroupSiblingUnits();
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
      final classifs = await AssetReferenceService.getClassifications(activeOnly: false);
      if (!mounted) return;
      setState(() {
        _locations = locs;
        _classifications = classifs;
        _selectedLocation = locs.firstWhere(
              (l) => l.acronym.toUpperCase() == _asset.locationAcronym.toUpperCase(),
          orElse: () => locs.first,
        );
        _selectedClassification = classifs.firstWhere(
              (c) => c.acronym.toUpperCase() == _asset.classificationAcronym.toUpperCase(),
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

  Future<void> _loadGroupSiblingUnits() async {
    if (_asset.bulkBatchId == null || _asset.bulkBatchId!.isEmpty) {
      if (_asset.childItems.isNotEmpty) {
        setState(() => _groupSiblingUnits = _asset.childItems);
      } else {
        setState(() => _groupSiblingUnits = [_asset]);
      }
      return;
    }

    setState(() => _isLoadingSiblings = true);
    try {
      final allMatching = await AssetService.getAssets(includeArchived: true);
      final siblings = allMatching.where((a) =>
      a.controlNumber == _asset.controlNumber ||
          a.bulkBatchId == _asset.bulkBatchId
      ).toList();

      List<AssetModel> units = [];
      for (final s in siblings) {
        if (s.childItems.isNotEmpty) {
          units.addAll(s.childItems);
        } else {
          units.add(s);
        }
      }

      units.sort((a, b) => (a.itemSequenceInBatch ?? 0).compareTo(b.itemSequenceInBatch ?? 0));

      if (!mounted) return;
      setState(() {
        _groupSiblingUnits = units.isNotEmpty ? units : [_asset];
        _isLoadingSiblings = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _groupSiblingUnits = _asset.childItems.isNotEmpty ? _asset.childItems : [_asset];
          _isLoadingSiblings = false;
        });
      }
    }
  }

  void _switchToUnit(AssetModel targetUnit) {
    setState(() {
      _isEditing = false;
      _newWatermarkedPhotoBytes = null;
      _newPhotoFileName = null;
    });
    _initializeAsset(targetUnit);
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
            await _processAndWatermarkNewImage(rawBytes, name ?? 'asset_photo.jpg');
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
          photo.name.isNotEmpty ? photo.name : 'camera_capture.jpg',
        );
      }
    } catch (e) {
      debugPrint('Camera error: $e');
    }
  }

  Future<void> _processAndWatermarkNewImage(Uint8List rawBytes, String filename) async {
    setState(() => _isProcessingImage = true);

    try {
      final idLabel = '${_asset.controlNumber} • ${_nameController.text.trim()}';

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
      _loadGroupSiblingUnits();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_operationalStatus == 'Decommissioned'
              ? 'Asset marked as Decommissioned and moved to Archive quarantine.'
              : 'Asset record updated successfully.'),
          backgroundColor: _operationalStatus == 'Decommissioned'
              ? ParishColors.goldAccent
              : ParishColors.oliveGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUpdating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: $e'), backgroundColor: ParishColors.mercyRed),
      );
    }
  }

  Future<void> _confirmArchiveAsset() async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Archive Diocesan Asset?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to archive "${_asset.itemName}" (${_asset.controlNumber})?', style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 14),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(labelText: 'Reason for Archiving *', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ParishColors.mercyRed, foregroundColor: Colors.white),
            onPressed: () {
              if (reasonController.text.trim().isNotEmpty) Navigator.pop(ctx, true);
            },
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirmed == true && reasonController.text.trim().isNotEmpty) {
      await AssetService.archiveAsset(assetId: _asset.assetId, reason: reasonController.text.trim());
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
        final bool isMobile = constraints.maxWidth < 600;

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                // Dialog Header Banner
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 14 : 20,
                    vertical: isMobile ? 12 : 16,
                  ),
                  decoration: BoxDecoration(
                    color: isArchived ? ParishColors.mercyRedSurface : ParishColors.marianBlueSurface,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    border: Border(bottom: BorderSide(color: borderGrey)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isArchived ? ParishColors.mercyRed : ParishColors.marianBlue,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(_asset.classificationIcon, color: Colors.white, size: isMobile ? 18 : 22),
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
                                      color: isArchived ? ParishColors.mercyRed : ParishColors.marianBlue,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _asset.conditionSurfaceColor,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: _asset.conditionColor.withValues(alpha: 0.4)),
                                  ),
                                  child: Text(
                                    _asset.conditionStatus.toUpperCase(),
                                    style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: _asset.conditionColor),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Registered: ${_asset.formattedRegistrationDate} • ID: ${_asset.assetId}',
                              style: TextStyle(fontSize: isMobile ? 10.5 : 11.5, color: textMuted),
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

                // Responsive Property Group Unit Selector Bar (Wrapped in Flexible/Expanded to prevent vertical wrapping)
                if (_groupSiblingUnits.length > 1) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: ParishColors.backgroundLight,
                      border: Border(bottom: BorderSide(color: borderGrey)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PROPERTY GROUP: $_cleanBaseGroupName',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ParishColors.marianBlue),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_groupSiblingUnits.length} total units inside this group',
                                style: TextStyle(fontSize: 10, color: textMuted),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: ParishColors.marianBlue.withValues(alpha: 0.4)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<AssetModel>(
                              value: _groupSiblingUnits.firstWhere(
                                    (u) => u.assetId == _asset.assetId,
                                orElse: () => _groupSiblingUnits.first,
                              ),
                              isDense: true,
                              icon: const Icon(Icons.arrow_drop_down, color: ParishColors.marianBlue, size: 20),
                              items: _groupSiblingUnits.map((unit) {
                                return DropdownMenuItem<AssetModel>(
                                  value: unit,
                                  child: Text(
                                    'Unit #${unit.propertyLabelSuffix} (${unit.conditionStatus})',
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: ParishColors.marianBlue),
                                  ),
                                );
                              }).toList(),
                              onChanged: (selected) {
                                if (selected != null) _switchToUnit(selected);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: borderGrey)),
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(34, 34),
                          ),
                          icon: const Icon(Icons.chevron_left, size: 16, color: ParishColors.marianBlue),
                          tooltip: 'Previous Unit',
                          onPressed: () {
                            final currentIndex = _groupSiblingUnits.indexWhere((u) => u.assetId == _asset.assetId);
                            if (currentIndex > 0) _switchToUnit(_groupSiblingUnits[currentIndex - 1]);
                          },
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: borderGrey)),
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(34, 34),
                          ),
                          icon: const Icon(Icons.chevron_right, size: 16, color: ParishColors.marianBlue),
                          tooltip: 'Next Unit',
                          onPressed: () {
                            final currentIndex = _groupSiblingUnits.indexWhere((u) => u.assetId == _asset.assetId);
                            if (currentIndex != -1 && currentIndex < _groupSiblingUnits.length - 1) {
                              _switchToUnit(_groupSiblingUnits[currentIndex + 1]);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],

                // Content Area
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isMobile ? 14 : 20),
                    child: _isEditing ? _buildEditForm() : _buildViewDetails(isMobile),
                  ),
                ),

                // Footer Actions
                Container(
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 20, vertical: isMobile ? 10 : 14),
                  decoration: BoxDecoration(
                    color: cardWhite,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                    border: Border(top: BorderSide(color: borderGrey)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ParishColors.marianBlue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _printLabelSticker,
                            icon: const Icon(Icons.qr_code, size: 15),
                            label: Text(isMobile ? 'Tag' : 'Print QR Tag', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 6),
                          if (_canArchive)
                            isArchived
                                ? OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(foregroundColor: ParishColors.oliveGreen, side: const BorderSide(color: ParishColors.oliveGreen)),
                              onPressed: _restoreAsset,
                              icon: const Icon(Icons.restore, size: 15),
                              label: const Text('Restore', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                            )
                                : OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(foregroundColor: ParishColors.mercyRed, side: const BorderSide(color: ParishColors.mercyRed)),
                              onPressed: _confirmArchiveAsset,
                              icon: const Icon(Icons.archive_outlined, size: 15),
                              label: const Text('Archive', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_canModify) ...[
                            if (_isEditing) ...[
                              TextButton(
                                onPressed: _isUpdating ? null : () => setState(() => _isEditing = false),
                                child: Text('Cancel', style: TextStyle(color: textMuted, fontSize: 12)),
                              ),
                              const SizedBox(width: 4),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: ParishColors.oliveGreen, foregroundColor: Colors.white),
                                onPressed: _isUpdating ? null : _saveAssetUpdates,
                                icon: _isUpdating
                                    ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Icon(Icons.save, size: 15),
                                label: Text(_isUpdating ? 'Saving...' : 'Save', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ] else ...[
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(side: const BorderSide(color: ParishColors.marianBlue)),
                                onPressed: () => setState(() => _isEditing = true),
                                icon: const Icon(Icons.edit_outlined, size: 15, color: ParishColors.marianBlue),
                                label: const Text('Edit Details', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: ParishColors.marianBlue)),
                              ),
                              const SizedBox(width: 6),
                            ],
                          ],
                          if (!_isEditing)
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text('Close', style: TextStyle(color: textMuted, fontWeight: FontWeight.bold, fontSize: 12)),
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
    final isArchived = _isEffectivelyArchived;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isArchived) ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: ParishColors.mercyRedSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ParishColors.mercyRed.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.archive_outlined, color: ParishColors.mercyRed, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ARCHIVED / DECOMMISSIONED PROPERTY',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: ParishColors.mercyRed),
                      ),
                      Text(
                        _asset.archiveReason != null && _asset.archiveReason!.isNotEmpty
                            ? 'Reason: ${_asset.archiveReason}'
                            : 'This asset is decommissioned from active parish operations.',
                        style: TextStyle(fontSize: 11, color: textDark),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        if (isMobile) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildPhotoThumbnail(size: 90),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _asset.itemName,
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textDark),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: _asset.unitPrice >= 10000.0 ? ParishColors.goldLight : ParishColors.marianBlueSurface,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _asset.inventorySection,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _asset.unitPrice >= 10000.0 ? ParishColors.goldAccent : ParishColors.marianBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ParishColors.backgroundLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderGrey),
            ),
            child: Column(
              children: [
                _buildDataRow(Icons.category_outlined, 'Classification', _asset.displayClassification),
                _buildDataRow(Icons.location_on_outlined, 'Location', _asset.displayLocation),
                _buildDataRow(Icons.calendar_today_outlined, 'Acquisition', '${_asset.formattedAcquisitionDate} (${_asset.modeOfAcquisition})'),
                if (_asset.rfidTag != null && _asset.rfidTag!.isNotEmpty)
                  _buildDataRow(Icons.nfc, 'RFID / NFC Tag', _asset.rfidTag!),
              ],
            ),
          ),
        ] else ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPhotoThumbnail(size: 130),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _asset.itemName,
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: textDark),
                    ),
                    const SizedBox(height: 6),
                    _buildDataRow(Icons.category_outlined, 'Classification', _asset.displayClassification),
                    _buildDataRow(Icons.location_on_outlined, 'Location', _asset.displayLocation),
                    _buildDataRow(Icons.calendar_today_outlined, 'Acquisition', '${_asset.formattedAcquisitionDate} (${_asset.modeOfAcquisition})'),
                    _buildDataRow(Icons.menu_book, 'Book of Inventory', _asset.inventorySection),
                    if (_asset.rfidTag != null && _asset.rfidTag!.isNotEmpty)
                      _buildDataRow(Icons.nfc, 'RFID / NFC Tag', _asset.rfidTag!),
                  ],
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ParishColors.oliveGreen.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text('Unit Identifier', style: TextStyle(fontSize: 10.5, color: textMuted, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text('Unit #${_asset.propertyLabelSuffix}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ParishColors.marianBlue)),
                ],
              ),
              Container(width: 1, height: 28, color: ParishColors.borderGrey),
              Column(
                children: [
                  Text('Price per Unit', style: TextStyle(fontSize: 10.5, color: textMuted, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(_asset.formattedUnitPrice, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ParishColors.marianBlue)),
                ],
              ),
              Container(width: 1, height: 28, color: ParishColors.borderGrey),
              Column(
                children: [
                  Text('Total Cost', style: TextStyle(fontSize: 10.5, color: textMuted, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(_asset.formattedTotalCost, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ParishColors.oliveGreen)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ParishColors.backgroundLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderGrey),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('PHYSICAL SPECIFICATIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textMuted)),
              const Divider(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildSpecItem('Dimensions', _asset.dimensions ?? '—')),
                  const SizedBox(width: 8),
                  Expanded(child: _buildSpecItem('Primary Color', _asset.color ?? '—')),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildSpecItem('Model / Brand', _asset.model ?? '—')),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSpecItem(
                      'Operational Status',
                      _asset.operationalStatus,
                      highlightRed: _asset.operationalStatus == 'Decommissioned',
                    ),
                  ),
                ],
              ),
              if (_asset.others != null && _asset.others!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('Inscriptions / Specs: ${_asset.others}', style: TextStyle(fontSize: 12, color: textDark)),
              ],
              if (_asset.remarks != null && _asset.remarks!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('Remarks: ${_asset.remarks}', style: TextStyle(fontSize: 11.5, color: textMuted)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Audit Inspection History', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: textDark)),
            Text('${_auditHistory.length} entries', style: TextStyle(fontSize: 11.5, color: textMuted)),
          ],
        ),
        const SizedBox(height: 8),
        if (_isLoadingHistory)
          const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
        else if (_auditHistory.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ParishColors.backgroundLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderGrey),
            ),
            child: Center(
              child: Text('No field audit records logged yet.', style: TextStyle(fontSize: 12, color: textMuted)),
            ),
          )
        else
          Column(
            children: _auditHistory.map((log) => _buildAuditLogTile(log)).toList(),
          ),
      ],
    );
  }

  Widget _buildPhotoThumbnail({required double size}) {
    final borderGrey = ParishColors.borderGrey;

    return Tooltip(
      message: _asset.photoUrl != null && _asset.photoUrl!.isNotEmpty
          ? 'Tap to preview photo with security watermark'
          : 'No photo uploaded',
      child: InkWell(
        onTap: _asset.photoUrl != null && _asset.photoUrl!.isNotEmpty
            ? () => _openInteractivePreview(NetworkImage(_asset.photoUrl!))
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: ParishColors.backgroundLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _asset.photoUrl != null ? ParishColors.goldAccent : borderGrey,
              width: _asset.photoUrl != null ? 1.5 : 1.0,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: _asset.photoUrl != null && _asset.photoUrl!.isNotEmpty
                ? Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  _asset.photoUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Center(
                    child: Icon(_asset.classificationIcon, size: 36, color: ParishColors.marianBlue),
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
                        fontSize: 7.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            )
                : Center(
              child: Icon(_asset.classificationIcon, size: 36, color: ParishColors.marianBlue),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAuditLogTile(AssetAuditLogModel log) {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: ParishColors.backgroundLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ParishColors.borderGrey),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            log.auditMethod == 'RFID_NFC' ? Icons.nfc : Icons.qr_code_scanner,
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
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textDark),
                    ),
                    Text(
                      log.formattedAuditedAt,
                      style: TextStyle(fontSize: 10.5, color: textMuted),
                    ),
                  ],
                ),
                if (log.newLocation != null && log.newLocation!.isNotEmpty)
                  Text('Location: ${log.newLocation}', style: TextStyle(fontSize: 11, color: textMuted)),
                if (log.auditNotes != null && log.auditNotes!.isNotEmpty)
                  Text('Notes: ${log.auditNotes}', style: TextStyle(fontSize: 11, color: textDark)),
                if (log.auditorName != null)
                  Text('Audited By: ${log.auditorName}', style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditForm() {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final borderGrey = ParishColors.borderGrey;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: ParishColors.marianBlueSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ParishColors.marianBlue.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.lock_outline, size: 16, color: ParishColors.marianBlue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Diocesan Control Number (${_asset.controlNumber}) and Classification are permanently locked to protect inventory integrity.',
                  style: const TextStyle(fontSize: 11.5, color: ParishColors.marianBlue, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        Text('Asset Documentation Photo & Security Watermark', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
        const SizedBox(height: 6),
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
                    _openInteractivePreview(MemoryImage(_newWatermarkedPhotoBytes!));
                  } else if (_asset.photoUrl != null && _asset.photoUrl!.isNotEmpty) {
                    _openInteractivePreview(NetworkImage(_asset.photoUrl!));
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderGrey),
                  ),
                  child: _isProcessingImage
                      ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                      : _newWatermarkedPhotoBytes != null
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: Image.memory(_newWatermarkedPhotoBytes!, fit: BoxFit.cover),
                  )
                      : (_asset.photoUrl != null && _asset.photoUrl!.isNotEmpty)
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: Image.network(_asset.photoUrl!, fit: BoxFit.cover),
                  )
                      : const Icon(Icons.photo_outlined, size: 32, color: ParishColors.marianBlue),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _newWatermarkedPhotoBytes != null
                          ? 'New Watermarked Photo'
                          : (_asset.photoUrl != null ? 'Current Photo' : 'No photo uploaded'),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: _newWatermarkedPhotoBytes != null ? ParishColors.oliveGreen : textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ParishColors.marianBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          onPressed: _isProcessingImage ? null : _capturePhotoWithCamera,
                          icon: const Icon(Icons.camera_alt, size: 13),
                          label: const Text('Camera', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        OutlinedButton.icon(
                          style: ElevatedButton.styleFrom(
                            foregroundColor: ParishColors.marianBlue,
                            side: const BorderSide(color: ParishColors.marianBlue),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          onPressed: _isProcessingImage ? null : _pickImageFromDevice,
                          icon: const Icon(Icons.upload_file, size: 13),
                          label: const Text('Upload', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text('Asset Designation / Item Name *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
        const SizedBox(height: 6),
        TextFormField(controller: _nameController, decoration: _inputDecoration()),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Quantity *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: _inputDecoration(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Unit Price (₱)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _unitPriceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [ThousandsSeparatorCurrencyFormatter()],
                    decoration: _inputDecoration(
                      prefixIcon: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        child: Text('₱', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: ParishColors.backgroundLight,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ParishColors.oliveGreen.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total: ₱ ${AssetModel.formatCurrency(_editCalculatedTotalCost)}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ParishColors.oliveGreen),
              ),
              Text(
                _editDeterminedSection,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ParishColors.marianBlue),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Classification (Locked)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textMuted)),
                  const SizedBox(height: 6),
                  TextFormField(initialValue: _asset.displayClassification, enabled: false, decoration: _inputDecoration()),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Location (Locked)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textMuted)),
                  const SizedBox(height: 6),
                  TextFormField(initialValue: _asset.displayLocation, enabled: false, decoration: _inputDecoration()),
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
                  Text('Condition *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _conditionStatus,
                    decoration: _inputDecoration(),
                    items: const [
                      DropdownMenuItem(value: 'VERIFIED / GOOD', child: Text('VERIFIED / GOOD')),
                      DropdownMenuItem(value: 'REQUIRES REPAIR', child: Text('REQUIRES REPAIR')),
                      DropdownMenuItem(value: 'DAMAGED', child: Text('DAMAGED')),
                      DropdownMenuItem(value: 'MISSING', child: Text('MISSING')),
                      DropdownMenuItem(value: 'UNUSABLE', child: Text('UNUSABLE')),
                    ],
                    onChanged: (val) => setState(() => _conditionStatus = val!),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Status *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _operationalStatus,
                    decoration: _inputDecoration(),
                    items: const [
                      DropdownMenuItem(value: 'Active', child: Text('Active')),
                      DropdownMenuItem(value: 'In Storage', child: Text('In Storage')),
                      DropdownMenuItem(value: 'Under Maintenance', child: Text('Under Maintenance')),
                      DropdownMenuItem(value: 'Decommissioned', child: Text('Decommissioned')),
                    ],
                    onChanged: (val) => setState(() => _operationalStatus = val!),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildLabel('RFID / NFC Tag ID (Optional)'),
        TextFormField(controller: _rfidController, decoration: _inputDecoration(hint: 'e.g. 04:A2:4B:9C')),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dimensions', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
                  const SizedBox(height: 6),
                  TextFormField(controller: _dimensionsController, decoration: _inputDecoration()),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Color', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
                  const SizedBox(height: 6),
                  TextFormField(controller: _colorController, decoration: _inputDecoration()),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Model', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
                  const SizedBox(height: 6),
                  TextFormField(controller: _modelController, decoration: _inputDecoration()),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text('Other Specifications', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
        const SizedBox(height: 6),
        TextFormField(controller: _othersController, maxLines: 2, decoration: _inputDecoration()),
        const SizedBox(height: 12),
        Text('Remarks & Maintenance Notes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
        const SizedBox(height: 6),
        TextFormField(controller: _remarksController, maxLines: 2, decoration: _inputDecoration()),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
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
          Text('$label: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ParishColors.textMuted)),
          Expanded(child: Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ParishColors.textDark))),
        ],
      ),
    );
  }

  Widget _buildSpecItem(String label, String value, {bool highlightRed = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10.5, color: ParishColors.textMuted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: highlightRed ? ParishColors.mercyRed : ParishColors.textDark,
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({String? hint, Widget? prefixIcon}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: ParishColors.backgroundLight,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ParishColors.borderGrey)),
    );
  }
}