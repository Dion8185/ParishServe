import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
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

  // New photo bytes if captured/uploaded during edit mode
  Uint8List? _newWatermarkedPhotoBytes;
  String? _newPhotoFileName;

  // Edit Mode Controllers
  late TextEditingController _nameController;
  late TextEditingController _dimensionsController;
  late TextEditingController _colorController;
  late TextEditingController _modelController;
  late TextEditingController _othersController;
  late TextEditingController _remarksController;
  late TextEditingController _costController;
  late TextEditingController _rfidController;

  List<AssetLocationModel> _locations = [];
  List<AssetClassificationModel> _classifications = [];
  AssetLocationModel? _selectedLocation;
  AssetClassificationModel? _selectedClassification;
  late String _conditionStatus;
  late String _operationalStatus;
  late String _modeOfAcquisition;

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

  @override
  void initState() {
    super.initState();
    _asset = widget.initialAsset;
    _conditionStatus = _asset.conditionStatus;
    _operationalStatus = _asset.operationalStatus;
    _modeOfAcquisition = _asset.modeOfAcquisition;

    _nameController = TextEditingController(text: _asset.itemName);
    _dimensionsController = TextEditingController(text: _asset.dimensions ?? '');
    _colorController = TextEditingController(text: _asset.color ?? '');
    _modelController = TextEditingController(text: _asset.model ?? '');
    _othersController = TextEditingController(text: _asset.others ?? '');
    _remarksController = TextEditingController(text: _asset.remarks ?? '');
    _costController = TextEditingController(text: _asset.cost.toStringAsFixed(2));
    _rfidController = TextEditingController(text: _asset.rfidTag ?? '');

    _loadAuditHistory();
    _loadReferenceOptions();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dimensionsController.dispose();
    _colorController.dispose();
    _modelController.dispose();
    _othersController.dispose();
    _remarksController.dispose();
    _costController.dispose();
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

  /// Option 1: Upload existing image from device storage / gallery
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

  /// Option 2: Capture a new image directly with device camera
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
      debugPrint('Error capturing photo from camera: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Camera access error: $e. You can also upload an image using "Upload Image".'),
            backgroundColor: ParishColors.goldAccent,
          ),
        );
      }
    }
  }

  /// Automatically applies embedded security watermark
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Security watermark embedded! Tap the photo thumbnail to inspect preview.'),
          backgroundColor: ParishColors.oliveGreen,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      debugPrint('Error watermarking image: $e');
      if (!mounted) return;
      setState(() {
        _newWatermarkedPhotoBytes = rawBytes;
        _newPhotoFileName = filename;
        _isProcessingImage = false;
      });
    }
  }

  /// Opens full zoomable preview modal showing watermark
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
      final double costVal = double.tryParse(_costController.text.trim()) ?? _asset.cost;
      String? photoUrlToSave = _asset.photoUrl;

      // Upload new watermarked photo if user captured or uploaded one
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
        classificationId: _selectedClassification?.classificationId ?? _asset.classificationId,
        classificationAcronym: _selectedClassification?.acronym ?? _asset.classificationAcronym,
        locationId: _selectedLocation?.locationId ?? _asset.locationId,
        locationAcronym: _selectedLocation?.acronym ?? _asset.locationAcronym,
        locationName: _selectedLocation?.locationName ?? _asset.locationName,
        dimensions: _dimensionsController.text.trim(),
        color: _colorController.text.trim(),
        model: _modelController.text.trim(),
        others: _othersController.text.trim(),
        remarks: _remarksController.text.trim(),
        photoUrl: photoUrlToSave,
        dateOfAcquisition: _asset.dateOfAcquisition,
        modeOfAcquisition: _modeOfAcquisition,
        cost: costVal,
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
          content: Text(_operationalStatus == 'Decommissioned'
              ? 'Asset marked as Decommissioned and moved to Archive quarantine.'
              : 'Asset record updated successfully.'),
          backgroundColor: _operationalStatus == 'Decommissioned' ? ParishColors.goldAccent : ParishColors.oliveGreen,
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
        title: const Row(
          children: [
            Icon(Icons.archive_outlined, color: ParishColors.mercyRed, size: 24),
            SizedBox(width: 8),
            Text('Archive Diocesan Asset?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Archiving marks "${_asset.itemName}" (${_asset.controlNumber}) as Decommissioned and transfers it to the Archive quarantine, while preserving historical audit logs.',
              style: TextStyle(fontSize: 13, color: ParishColors.textDark, height: 1.35),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for Archiving / Decommissioning *',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
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
            child: const Text('Archive Asset'),
          ),
        ],
      ),
    );

    if (confirmed == true && reasonController.text.trim().isNotEmpty) {
      try {
        await AssetService.archiveAsset(
          assetId: _asset.assetId,
          reason: reasonController.text.trim(),
        );

        if (!mounted) return;
        Navigator.pop(context);
        widget.onAssetUpdated?.call();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Asset "${_asset.controlNumber}" moved to archive quarantine.'),
            backgroundColor: ParishColors.mercyRed,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: ParishColors.mercyRed),
        );
      }
    }
  }

  Future<void> _restoreAsset() async {
    try {
      await AssetService.restoreAsset(_asset.assetId);
      if (!mounted) return;
      Navigator.pop(context);
      widget.onAssetUpdated?.call();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Asset "${_asset.controlNumber}" restored to active inventory (Status: Active).'),
          backgroundColor: ParishColors.oliveGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: ParishColors.mercyRed),
      );
    }
  }

  Future<void> _printLabelSticker() async {
    try {
      await AssetLabelPdfService.printSingleAssetLabel(_asset);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Print error: $e'), backgroundColor: ParishColors.mercyRed),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final cardWhite = ParishColors.cardWhite;
    final borderGrey = ParishColors.borderGrey;
    final isArchived = _isEffectivelyArchived;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: cardWhite,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        width: 780,
        constraints: const BoxConstraints(maxHeight: 780),
        child: Column(
          children: [
            // Dialog Header Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isArchived ? ParishColors.mercyRedSurface : ParishColors.marianBlueSurface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: borderGrey)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isArchived ? ParishColors.mercyRed : ParishColors.marianBlue,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _asset.classificationIcon,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _asset.controlNumber,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isArchived ? ParishColors.mercyRed : ParishColors.marianBlue,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _asset.conditionSurfaceColor,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: _asset.conditionColor.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                _asset.conditionStatus.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: _asset.conditionColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Asset ID: ${_asset.assetId} • Registered: ${_asset.formattedRegistrationDate}',
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

            // Content Area (View Mode vs Edit Mode)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: _isEditing ? _buildEditForm() : _buildViewDetails(),
              ),
            ),

            // Footer Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: cardWhite,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                border: Border(top: BorderSide(color: borderGrey)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left: Print Label Sticker & Archive Actions
                  Row(
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ParishColors.marianBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _printLabelSticker,
                        icon: const Icon(Icons.qr_code, size: 16),
                        label: const Text('Print QR Tag', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      if (_canArchive)
                        isArchived
                            ? OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: ParishColors.oliveGreen,
                            side: const BorderSide(color: ParishColors.oliveGreen),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _restoreAsset,
                          icon: const Icon(Icons.restore, size: 16),
                          label: const Text('Restore', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        )
                            : OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: ParishColors.mercyRed,
                            side: const BorderSide(color: ParishColors.mercyRed),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _confirmArchiveAsset,
                          icon: const Icon(Icons.archive_outlined, size: 16),
                          label: const Text('Archive', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),

                  // Right: Edit/Save or Close Button
                  Row(
                    children: [
                      if (_canModify) ...[
                        if (_isEditing) ...[
                          TextButton(
                            onPressed: _isUpdating ? null : () => setState(() => _isEditing = false),
                            child: Text('Cancel', style: TextStyle(color: textMuted)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ParishColors.oliveGreen,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            ),
                            onPressed: _isUpdating ? null : _saveAssetUpdates,
                            icon: _isUpdating
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.save, size: 16),
                            label: Text(_isUpdating ? 'Saving...' : 'Save Changes', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                          ),
                        ] else ...[
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: ParishColors.marianBlue),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => setState(() => _isEditing = true),
                            icon: const Icon(Icons.edit_outlined, size: 16, color: ParishColors.marianBlue),
                            label: const Text('Edit Details', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ParishColors.marianBlue)),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ],
                      if (!_isEditing)
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Close', style: TextStyle(color: textMuted, fontWeight: FontWeight.bold)),
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
  // View Mode: Complete Information & Audit History
  // ===========================================================================

  Widget _buildViewDetails() {
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
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: ParishColors.mercyRedSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ParishColors.mercyRed.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.archive_outlined, color: ParishColors.mercyRed, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ARCHIVED / DECOMMISSIONED PROPERTY',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ParishColors.mercyRed),
                      ),
                      Text(
                        _asset.archiveReason != null && _asset.archiveReason!.isNotEmpty
                            ? 'Reason: ${_asset.archiveReason}'
                            : 'This asset is decommissioned from active parish operations and quarantined in the archives.',
                        style: TextStyle(fontSize: 11.5, color: textDark),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        // Top Section: Reference Photo & Primary Particulars
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Interactive Photo Box with Watermark Preview on Tap
            Tooltip(
              message: _asset.photoUrl != null && _asset.photoUrl!.isNotEmpty
                  ? 'Tap to preview photo with security watermark'
                  : 'No photo uploaded',
              child: InkWell(
                onTap: _asset.photoUrl != null && _asset.photoUrl!.isNotEmpty
                    ? () => _openInteractivePreview(NetworkImage(_asset.photoUrl!))
                    : null,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: ParishColors.backgroundLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _asset.photoUrl != null ? ParishColors.goldAccent : borderGrey,
                      width: _asset.photoUrl != null ? 1.5 : 1.0,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: _asset.photoUrl != null && _asset.photoUrl!.isNotEmpty
                        ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          _asset.photoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Icon(_asset.classificationIcon, size: 48, color: ParishColors.marianBlue),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            color: Colors.black54,
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.zoom_in, color: Colors.white, size: 10),
                                SizedBox(width: 3),
                                Text(
                                  'WATERMARKED',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 7.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                        : Center(
                      child: Icon(_asset.classificationIcon, size: 48, color: ParishColors.marianBlue),
                    ),
                  ),
                ),
              ),
            ),
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
                  _buildDataRow(Icons.payments_outlined, 'Cost / Value', '₱ ${_asset.cost.toStringAsFixed(2)}'),
                  if (_asset.rfidTag != null && _asset.rfidTag!.isNotEmpty)
                    _buildDataRow(Icons.nfc, 'RFID / NFC Tag', _asset.rfidTag!),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Specifications & Dimensions
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
                children: [
                  Expanded(child: _buildSpecItem('Dimensions', _asset.dimensions ?? '—')),
                  Expanded(child: _buildSpecItem('Primary Color', _asset.color ?? '—')),
                  Expanded(child: _buildSpecItem('Model / Brand', _asset.model ?? '—')),
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
                const SizedBox(height: 8),
                Text('Inscriptions / Other Details: ${_asset.others}', style: TextStyle(fontSize: 12, color: textDark)),
              ],
              if (_asset.remarks != null && _asset.remarks!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('Remarks / Maintenance: ${_asset.remarks}', style: TextStyle(fontSize: 12, color: textMuted)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Historical Audit Trail
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Audit Inspection History', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textDark)),
            Text('${_auditHistory.length} audit entries', style: TextStyle(fontSize: 12, color: textMuted)),
          ],
        ),
        const SizedBox(height: 10),

        if (_isLoadingHistory)
          const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
        else if (_auditHistory.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ParishColors.backgroundLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderGrey),
            ),
            child: Center(
              child: Text('No field audit records logged yet.', style: TextStyle(fontSize: 12.5, color: textMuted)),
            ),
          )
        else
          Column(
            children: _auditHistory.map((log) => _buildAuditLogTile(log)).toList(),
          ),
      ],
    );
  }

  Widget _buildAuditLogTile(AssetAuditLogModel log) {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ParishColors.backgroundLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ParishColors.borderGrey),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            log.auditMethod == 'RFID_NFC' ? Icons.nfc : Icons.qr_code_scanner,
            size: 18,
            color: ParishColors.marianBlue,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Condition: ${log.newCondition}',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: textDark),
                    ),
                    Text(
                      log.formattedAuditedAt,
                      style: TextStyle(fontSize: 11, color: textMuted),
                    ),
                  ],
                ),
                if (log.newLocation != null && log.newLocation!.isNotEmpty)
                  Text('Location: ${log.newLocation}', style: TextStyle(fontSize: 11.5, color: textMuted)),
                if (log.auditNotes != null && log.auditNotes!.isNotEmpty)
                  Text('Notes: ${log.auditNotes}', style: TextStyle(fontSize: 11.5, color: textDark)),
                if (log.auditorName != null)
                  Text('Audited By: ${log.auditorName}', style: TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Edit Mode: Field Form with Photo Watermark Capture / Upload
  // ===========================================================================

  Widget _buildEditForm() {
    final textDark = ParishColors.textDark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Diocesan Control Number Notice (Immutable)
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
              const Icon(Icons.lock_outline, size: 18, color: ParishColors.marianBlue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Diocesan Control Number (${_asset.controlNumber}) is permanently locked and protected against unauthorized reassignment.',
                  style: const TextStyle(fontSize: 11.5, color: ParishColors.marianBlue, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),

        // Photo Update Section with Watermark
        Text('Asset Documentation Photo & Security Watermark', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ParishColors.backgroundLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ParishColors.borderGrey),
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
                    border: Border.all(color: ParishColors.borderGrey),
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
                          ? 'New Watermarked Photo Selected'
                          : (_asset.photoUrl != null ? 'Current Photo on File' : 'No photo uploaded'),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: _newWatermarkedPhotoBytes != null ? ParishColors.oliveGreen : textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text('Auto-stamps parish name, date, time, and control number.', style: TextStyle(fontSize: 11, color: ParishColors.textMuted)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ParishColors.marianBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          onPressed: _isProcessingImage ? null : _capturePhotoWithCamera,
                          icon: const Icon(Icons.camera_alt, size: 14),
                          label: const Text('Take Photo', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: ParishColors.marianBlue,
                            side: const BorderSide(color: ParishColors.marianBlue),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          onPressed: _isProcessingImage ? null : _pickImageFromDevice,
                          icon: const Icon(Icons.upload_file, size: 14),
                          label: const Text('Upload Image', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
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
        TextFormField(
          controller: _nameController,
          decoration: _inputDecoration(),
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Classification *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<AssetClassificationModel>(
                    value: _selectedClassification,
                    isExpanded: true,
                    decoration: _inputDecoration(),
                    items: _classifications.map((c) => DropdownMenuItem(value: c, child: Text('${c.classificationName} (${c.acronym})'))).toList(),
                    onChanged: (val) => setState(() => _selectedClassification = val),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Location *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<AssetLocationModel>(
                    value: _selectedLocation,
                    isExpanded: true,
                    decoration: _inputDecoration(),
                    items: _locations.map((l) => DropdownMenuItem(value: l, child: Text('${l.locationName} (${l.acronym})'))).toList(),
                    onChanged: (val) => setState(() => _selectedLocation = val),
                  ),
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
                  Text('Condition Status *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
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
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Operational Status *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _operationalStatus,
                    decoration: _inputDecoration(),
                    items: const [
                      DropdownMenuItem(value: 'Active', child: Text('Active')),
                      DropdownMenuItem(value: 'In Storage', child: Text('In Storage')),
                      DropdownMenuItem(value: 'Under Maintenance', child: Text('Under Maintenance')),
                      DropdownMenuItem(value: 'Decommissioned', child: Text('Decommissioned (Archived)')),
                    ],
                    onChanged: (val) => setState(() => _operationalStatus = val!),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (_operationalStatus == 'Decommissioned') ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ParishColors.goldLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ParishColors.goldAccent),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: ParishColors.goldAccent),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Setting Operational Status to "Decommissioned" will automatically transfer this asset to the Archive quarantine.',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: ParishColors.goldAccent),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Acquisition Cost (₱)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
                  const SizedBox(height: 6),
                  TextFormField(controller: _costController, decoration: _inputDecoration()),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('RFID / NFC Tag ID', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
                  const SizedBox(height: 6),
                  TextFormField(controller: _rfidController, decoration: _inputDecoration(hint: 'e.g. 04:A2:4B:9C')),
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
                  Text('Dimensions', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
                  const SizedBox(height: 6),
                  TextFormField(controller: _dimensionsController, decoration: _inputDecoration()),
                ],
              ),
            ),
            const SizedBox(width: 10),
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
            const SizedBox(width: 10),
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

  Widget _buildDataRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: ParishColors.marianBlue),
          const SizedBox(width: 8),
          Text('$label: ', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: ParishColors.textMuted)),
          Expanded(child: Text(value, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: ParishColors.textDark))),
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
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: highlightRed ? ParishColors.mercyRed : ParishColors.textDark,
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: ParishColors.backgroundLight,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ParishColors.borderGrey)),
    );
  }
}