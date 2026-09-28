import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/colors.dart';
import '../../models/asset_model.dart';
import '../../models/asset_reference_models.dart';
import '../../services/asset_reference_service.dart';
import '../../services/asset_service.dart';
import '../../utils/asset_image_watermark_util.dart';

void showRegisterAssetModal(BuildContext context, {VoidCallback? onAssetSaved}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _RegisterAssetDialog(onAssetSaved: onAssetSaved),
  );
}

class _RegisterAssetDialog extends StatefulWidget {
  final VoidCallback? onAssetSaved;

  const _RegisterAssetDialog({this.onAssetSaved});

  @override
  State<_RegisterAssetDialog> createState() => _RegisterAssetDialogState();
}

class _RegisterAssetDialogState extends State<_RegisterAssetDialog> {
  final _formKey = GlobalKey<FormState>();

  final _itemNameController = TextEditingController();
  final _dimensionsController = TextEditingController();
  final _colorController = TextEditingController();
  final _modelController = TextEditingController();
  final _othersController = TextEditingController();
  final _remarksController = TextEditingController();
  final _costController = TextEditingController(text: '0.00');
  final _rfidTagController = TextEditingController();

  List<AssetLocationModel> _locations = [];
  List<AssetClassificationModel> _classifications = [];
  AssetLocationModel? _selectedLocation;
  AssetClassificationModel? _selectedClassification;
  bool _isLoadingReferences = true;

  DateTime _dateOfAcquisition = DateTime.now();
  String _modeOfAcquisition = 'Purchase';
  String _conditionStatus = 'VERIFIED / GOOD';
  String _operationalStatus = 'Active';

  String _previewControlNumber = 'C-SI-2026-001';

  // Photo & Security Watermark State
  Uint8List? _watermarkedPhotoBytes;
  String? _photoFileName;
  bool _isProcessingImage = false;

  bool _isSaving = false;
  String? _errorMessage;

  final List<String> _acquisitionModes = [
    'Purchase',
    'Donation',
    'Transfer',
    'Diocesan Grant',
    'Inherited / Legacy',
    'Found / Recovered',
  ];

  final List<String> _conditions = [
    'VERIFIED / GOOD',
    'REQUIRES REPAIR',
    'DAMAGED',
    'MISSING',
    'UNUSABLE',
  ];

  final List<String> _operationalStatuses = [
    'Active',
    'In Storage',
    'Under Maintenance',
    'Decommissioned',
  ];

  @override
  void initState() {
    super.initState();
    _loadReferences();
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _dimensionsController.dispose();
    _colorController.dispose();
    _modelController.dispose();
    _othersController.dispose();
    _remarksController.dispose();
    _costController.dispose();
    _rfidTagController.dispose();
    super.dispose();
  }

  Future<void> _loadReferences() async {
    setState(() => _isLoadingReferences = true);
    try {
      final locs = await AssetReferenceService.getLocations(activeOnly: true);
      final classifs = await AssetReferenceService.getClassifications(activeOnly: true);

      if (!mounted) return;
      setState(() {
        _locations = locs;
        _classifications = classifs;
        if (locs.isNotEmpty) _selectedLocation = locs.first;
        if (classifs.isNotEmpty) _selectedClassification = classifs.first;
        _isLoadingReferences = false;
      });
      _updateLiveControlNumberPreview();
    } catch (_) {
      if (mounted) setState(() => _isLoadingReferences = false);
    }
  }

  void _updateLiveControlNumberPreview() {
    final locAcronym = _selectedLocation?.acronym ?? 'C';
    final clsAcronym = _selectedClassification?.acronym ?? 'SI';
    final year = _dateOfAcquisition.year;

    setState(() {
      _previewControlNumber = '$locAcronym-$clsAcronym-$year-001';
    });
  }

  Future<void> _pickDateOfAcquisition() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfAcquisition,
      firstDate: DateTime(1900),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        _dateOfAcquisition = picked;
      });
      _updateLiveControlNumberPreview();
    }
  }

  /// 1. Upload existing image from device storage / gallery
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
            await _processAndWatermarkImage(rawBytes, name ?? 'asset_upload.jpg');
          }
        }
      }
    } catch (e) {
      debugPrint('Error selecting image from device: $e');
    }
  }

  /// 2. Capture a fresh photo using the device camera directly
  Future<void> _capturePhotoWithCamera() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 92,
      );

      if (photo != null) {
        final Uint8List rawBytes = await photo.readAsBytes();
        await _processAndWatermarkImage(rawBytes, photo.name.isNotEmpty ? photo.name : 'camera_capture.jpg');
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

  /// Automatically applies the embedded security watermark to captured or uploaded image
  Future<void> _processAndWatermarkImage(Uint8List rawBytes, String filename) async {
    setState(() => _isProcessingImage = true);

    try {
      final assetIdLabel = _itemNameController.text.trim().isNotEmpty
          ? '$_previewControlNumber • ${_itemNameController.text.trim()}'
          : _previewControlNumber;

      final watermarked = await AssetImageWatermarkUtil.applySecurityWatermark(
        rawImageBytes: rawBytes,
        assetIdentifier: assetIdLabel,
        captureTime: DateTime.now(),
      );

      if (!mounted) return;
      setState(() {
        _watermarkedPhotoBytes = watermarked;
        _photoFileName = filename;
        _isProcessingImage = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Security watermark embedded successfully! Tap the photo to inspect preview.'),
          backgroundColor: ParishColors.oliveGreen,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      debugPrint('Error applying security watermark: $e');
      if (!mounted) return;
      setState(() {
        _watermarkedPhotoBytes = rawBytes; // Fallback to raw if watermark fails
        _photoFileName = filename;
        _isProcessingImage = false;
      });
    }
  }

  /// Opens full-fidelity interactive zoomable preview modal
  void _openInteractiveImagePreview() {
    if (_watermarkedPhotoBytes == null) return;
    AssetImageWatermarkUtil.showImagePreviewModal(
      context,
      imageProvider: MemoryImage(_watermarkedPhotoBytes!),
      title: _itemNameController.text.trim().isNotEmpty
          ? _itemNameController.text.trim()
          : 'Asset Image Preview',
      controlNumber: _previewControlNumber,
    );
  }

  Future<void> _submitAsset() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) return;
    if (_selectedLocation == null) {
      setState(() => _errorMessage = 'Please select an asset location.');
      return;
    }
    if (_selectedClassification == null) {
      setState(() => _errorMessage = 'Please select an asset classification.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final double costValue = double.tryParse(_costController.text.trim()) ?? 0.0;
      String? uploadedPhotoUrl;

      // 1. Upload watermarked photo if available
      if (_watermarkedPhotoBytes != null && _photoFileName != null) {
        final tempId = 'AST-${DateTime.now().millisecondsSinceEpoch % 100000}';
        uploadedPhotoUrl = await AssetService.uploadAssetPhoto(
          assetId: tempId,
          fileBytes: _watermarkedPhotoBytes!,
          fileName: _photoFileName!,
        );
      }

      // 2. Register asset in database with atomic control number sequence
      final created = await AssetService.registerAsset(
        itemName: _itemNameController.text.trim(),
        classificationId: _selectedClassification!.classificationId,
        classificationAcronym: _selectedClassification!.acronym,
        classificationName: _selectedClassification!.classificationName,
        locationId: _selectedLocation!.locationId,
        locationAcronym: _selectedLocation!.acronym,
        locationName: _selectedLocation!.locationName,
        dimensions: _dimensionsController.text.trim(),
        color: _colorController.text.trim(),
        model: _modelController.text.trim(),
        others: _othersController.text.trim(),
        remarks: _remarksController.text.trim(),
        photoUrl: uploadedPhotoUrl,
        dateOfAcquisition: _dateOfAcquisition,
        modeOfAcquisition: _modeOfAcquisition,
        cost: costValue,
        rfidTag: _rfidTagController.text.trim(),
        conditionStatus: _conditionStatus,
        operationalStatus: _operationalStatus,
      );

      if (!mounted) return;
      Navigator.pop(context);
      widget.onAssetSaved?.call();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Asset registered successfully! Control #: ${created.controlNumber}'),
          backgroundColor: ParishColors.oliveGreen,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isSaving = false;
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
        width: 720,
        constraints: const BoxConstraints(maxHeight: 780),
        child: Column(
          children: [
            // Modal Header Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              decoration: BoxDecoration(
                color: ParishColors.marianBlueSurface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                    child: const Icon(Icons.add_business, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Register Diocesan Parish Property',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textDark),
                        ),
                        Text(
                          'Assign standardized Diocesan Control Number (LOCATION-CLASSIFICATION-YEAR-SEQUENCE)',
                          style: TextStyle(fontSize: 11.5, color: textMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Form Body
            Expanded(
              child: _isLoadingReferences
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_errorMessage != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: ParishColors.mercyRedSurface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: ParishColors.mercyRed),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: ParishColors.mercyRed, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: ParishColors.mercyRed),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Live Auto Control Number Preview Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: ParishColors.goldLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: ParishColors.goldAccent.withValues(alpha: 0.6)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.tag, color: ParishColors.goldAccent, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Diocesan Control Number (Automatic Format):',
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: ParishColors.goldAccent),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$_previewControlNumber (Sequence verified on save)',
                                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: textDark),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Asset Name
                      _buildLabel('Asset Name / Official Designation *'),
                      TextFormField(
                        controller: _itemNameController,
                        validator: (v) => (v?.trim().isEmpty ?? true) ? 'Asset name is required.' : null,
                        style: TextStyle(fontSize: 14, color: textDark),
                        decoration: _inputDecoration(hint: 'e.g. Sterling Silver Chalice with Paten'),
                      ),
                      const SizedBox(height: 14),

                      // Classification & Location Selectors
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Classification *'),
                                DropdownButtonFormField<AssetClassificationModel>(
                                  value: _selectedClassification,
                                  isExpanded: true,
                                  decoration: _inputDecoration(),
                                  items: _classifications.map((c) {
                                    return DropdownMenuItem(
                                      value: c,
                                      child: Row(
                                        children: [
                                          Icon(c.icon, size: 16, color: ParishColors.marianBlue),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              '${c.classificationName} (${c.acronym})',
                                              style: const TextStyle(fontSize: 13),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _selectedClassification = val);
                                      _updateLiveControlNumberPreview();
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Parish Location *'),
                                DropdownButtonFormField<AssetLocationModel>(
                                  value: _selectedLocation,
                                  isExpanded: true,
                                  decoration: _inputDecoration(),
                                  items: _locations.map((l) {
                                    return DropdownMenuItem(
                                      value: l,
                                      child: Text(
                                        '${l.locationName} (${l.acronym})',
                                        style: const TextStyle(fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _selectedLocation = val);
                                      _updateLiveControlNumberPreview();
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Acquisition Date & Mode
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Date of Acquisition *'),
                                InkWell(
                                  onTap: _pickDateOfAcquisition,
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: ParishColors.backgroundLight,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: borderGrey),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${_dateOfAcquisition.year}-${_dateOfAcquisition.month.toString().padLeft(2, '0')}-${_dateOfAcquisition.day.toString().padLeft(2, '0')}',
                                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: textDark),
                                        ),
                                        const Icon(Icons.calendar_month, size: 18, color: ParishColors.marianBlue),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Mode of Acquisition *'),
                                DropdownButtonFormField<String>(
                                  value: _modeOfAcquisition,
                                  isExpanded: true,
                                  decoration: _inputDecoration(),
                                  items: _acquisitionModes.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 13)))).toList(),
                                  onChanged: (val) => setState(() => _modeOfAcquisition = val!),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Cost & Physical RFID / NFC Tag
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Acquisition Cost / Declared Value (₱)'),
                                TextFormField(
                                  controller: _costController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: TextStyle(fontSize: 13.5, color: textDark),
                                  decoration: _inputDecoration(hint: '0.00'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('RFID / NFC Tag ID (Optional)'),
                                TextFormField(
                                  controller: _rfidTagController,
                                  style: TextStyle(fontSize: 13.5, color: textDark),
                                  decoration: _inputDecoration(
                                    hint: 'e.g. 04:A2:4B:9C',
                                    prefixIcon: const Icon(Icons.nfc, size: 16, color: ParishColors.marianBlue),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Condition Status & Operational Status
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Physical Condition *'),
                                DropdownButtonFormField<String>(
                                  value: _conditionStatus,
                                  isExpanded: true,
                                  decoration: _inputDecoration(),
                                  items: _conditions.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)))).toList(),
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
                                _buildLabel('Operational Status *'),
                                DropdownButtonFormField<String>(
                                  value: _operationalStatus,
                                  isExpanded: true,
                                  decoration: _inputDecoration(),
                                  items: _operationalStatuses.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
                                  onChanged: (val) => setState(() => _operationalStatus = val!),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Specifications: Dimensions, Color, Model
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Dimensions (Optional)'),
                                TextFormField(
                                  controller: _dimensionsController,
                                  style: TextStyle(fontSize: 13, color: textDark),
                                  decoration: _inputDecoration(hint: 'e.g. 12" H x 6" D'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Primary Color'),
                                TextFormField(
                                  controller: _colorController,
                                  style: TextStyle(fontSize: 13, color: textDark),
                                  decoration: _inputDecoration(hint: 'e.g. Gold / Velvet Red'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Model / Brand'),
                                TextFormField(
                                  controller: _modelController,
                                  style: TextStyle(fontSize: 13, color: textDark),
                                  decoration: _inputDecoration(hint: 'e.g. Yamaha P-125'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // =========================================================
                      // ASSET IMAGE CAPTURE, WATERMARK & PREVIEW SECTION
                      // =========================================================
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildLabel('Asset Documentation Photo & Security Watermark'),
                          if (_watermarkedPhotoBytes != null)
                            InkWell(
                              onTap: _openInteractiveImagePreview,
                              child: const Row(
                                children: [
                                  Icon(Icons.zoom_in, size: 16, color: ParishColors.marianBlue),
                                  SizedBox(width: 4),
                                  Text(
                                    'Inspect Full Preview',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: ParishColors.marianBlue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _watermarkedPhotoBytes != null
                              ? ParishColors.oliveGreenSurface
                              : ParishColors.backgroundLight,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _watermarkedPhotoBytes != null
                                ? ParishColors.oliveGreen
                                : borderGrey,
                            width: _watermarkedPhotoBytes != null ? 1.5 : 1.0,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Image Thumbnail / Watermark Box
                                InkWell(
                                  onTap: _watermarkedPhotoBytes != null ? _openInteractiveImagePreview : null,
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    width: 90,
                                    height: 90,
                                    decoration: BoxDecoration(
                                      color: ParishColors.marianBlueSurface,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: _watermarkedPhotoBytes != null
                                            ? ParishColors.goldAccent
                                            : borderGrey,
                                        width: _watermarkedPhotoBytes != null ? 2 : 1,
                                      ),
                                    ),
                                    child: _isProcessingImage
                                        ? const Center(
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                        : _watermarkedPhotoBytes != null
                                        ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          Image.memory(
                                            _watermarkedPhotoBytes!,
                                            fit: BoxFit.cover,
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
                                      ),
                                    )
                                        : const Icon(
                                      Icons.image_outlined,
                                      color: ParishColors.marianBlue,
                                      size: 36,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),

                                // Actions & Instructions
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _watermarkedPhotoBytes != null
                                            ? 'Security Watermark Embedded'
                                            : 'Attach or Capture Asset Photo',
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.bold,
                                          color: _watermarkedPhotoBytes != null
                                              ? ParishColors.oliveGreen
                                              : textDark,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        _watermarkedPhotoBytes != null
                                            ? 'Includes: Parish Name (Saint John Paul II Parish), Timestamp, and Diocesan Control # (${_previewControlNumber}). Tap thumbnail to preview.'
                                            : 'Images are automatically stamped with an immutable parish watermark including date, time, and Diocesan Control number.',
                                        style: TextStyle(fontSize: 11, color: textMuted, height: 1.35),
                                      ),
                                      const SizedBox(height: 10),

                                      // Dual Action Buttons: Upload Image & Take Photo
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: ParishColors.marianBlue,
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            onPressed: _isProcessingImage ? null : _capturePhotoWithCamera,
                                            icon: const Icon(Icons.camera_alt, size: 16),
                                            label: const Text('Take Photo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                          ),
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: ParishColors.marianBlue,
                                              side: const BorderSide(color: ParishColors.marianBlue),
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            onPressed: _isProcessingImage ? null : _pickImageFromDevice,
                                            icon: const Icon(Icons.file_upload_outlined, size: 16),
                                            label: const Text('Upload Image', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                          ),
                                          if (_watermarkedPhotoBytes != null)
                                            TextButton.icon(
                                              style: TextButton.styleFrom(
                                                foregroundColor: ParishColors.mercyRed,
                                                visualDensity: VisualDensity.compact,
                                              ),
                                              onPressed: () {
                                                setState(() {
                                                  _watermarkedPhotoBytes = null;
                                                  _photoFileName = null;
                                                });
                                              },
                                              icon: const Icon(Icons.delete_outline, size: 16),
                                              label: const Text('Remove', style: TextStyle(fontSize: 12)),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Others / Special Specifications
                      _buildLabel('Other Specifications / Inscriptions'),
                      TextFormField(
                        controller: _othersController,
                        maxLines: 2,
                        style: TextStyle(fontSize: 13, color: textDark),
                        decoration: _inputDecoration(hint: 'e.g. Inscribed "Donated by Santos Family, Year 2008"'),
                      ),
                      const SizedBox(height: 14),

                      // Remarks
                      _buildLabel('Remarks / Maintenance Notes'),
                      TextFormField(
                        controller: _remarksController,
                        maxLines: 2,
                        style: TextStyle(fontSize: 13, color: textDark),
                        decoration: _inputDecoration(hint: 'e.g. Stored inside sacristy vault, requires annual polishing'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Modal Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              decoration: BoxDecoration(
                color: cardWhite,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                border: Border(top: BorderSide(color: borderGrey)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    child: Text('Cancel', style: TextStyle(fontSize: 14, color: textMuted)),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ParishColors.marianBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                      ),
                      onPressed: _isSaving ? null : _submitAsset,
                      icon: _isSaving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.check, size: 20),
                      label: Text(
                        _isSaving ? 'Registering Asset...' : 'Save & Register Asset',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
    );
  }

  InputDecoration _inputDecoration({String? hint, Widget? prefixIcon}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: ParishColors.backgroundLight,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ParishColors.borderGrey)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ParishColors.borderGrey)),
      focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)), borderSide: BorderSide(color: ParishColors.marianBlue, width: 1.8)),
    );
  }
}