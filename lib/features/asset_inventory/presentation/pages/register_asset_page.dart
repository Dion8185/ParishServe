// =============================================================================
// FILE: lib/features/asset_inventory/presentation/pages/register_asset_page.dart
// =============================================================================

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
import '../dialogs/register_asset_dialog.dart'; // Reuses currency formatter

class RegisterAssetPage extends StatefulWidget {
  final VoidCallback? onAssetSaved;

  const RegisterAssetPage({super.key, this.onAssetSaved});

  @override
  State<RegisterAssetPage> createState() => _RegisterAssetPageState();
}

class _RegisterAssetPageState extends State<RegisterAssetPage> {
  final _formKey = GlobalKey<FormState>();

  final _itemNameController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _unitPriceController = TextEditingController();
  final _dimensionsController = TextEditingController();
  final _colorController = TextEditingController();
  final _modelController = TextEditingController();
  final _othersController = TextEditingController();
  final _remarksController = TextEditingController();
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

  String _previewControlNumber = 'C-FF 2026-001';

  Uint8List? _watermarkedPhotoBytes;
  String? _photoFileName;
  bool _isProcessingImage = false;
  bool _isSaving = false;
  String? _errorMessage;

  final List<String> _acquisitionModes = ['Purchase', 'Donation', 'Transfer', 'Diocesan Grant', 'Inherited / Legacy'];
  final List<String> _conditions = ['VERIFIED / GOOD', 'REQUIRES REPAIR', 'DAMAGED', 'MISSING', 'UNUSABLE'];

  @override
  void initState() {
    super.initState();
    _loadReferences();
    _quantityController.addListener(() => setState(() {}));
    _unitPriceController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _quantityController.dispose();
    _unitPriceController.dispose();
    _dimensionsController.dispose();
    _colorController.dispose();
    _modelController.dispose();
    _othersController.dispose();
    _remarksController.dispose();
    _rfidTagController.dispose();
    super.dispose();
  }

  int get _parsedQuantity {
    final qty = int.tryParse(_quantityController.text.trim());
    return (qty != null && qty > 0) ? qty : 1;
  }

  double get _parsedUnitPrice {
    final clean = _unitPriceController.text.replaceAll(',', '').trim();
    if (clean.isEmpty) return 0.0;
    return double.tryParse(clean) ?? 0.0;
  }

  double get _calculatedTotalCost => _parsedQuantity * _parsedUnitPrice;

  String get _determinedInventorySection {
    return _parsedUnitPrice >= 10000.0 ? 'Section 1 — ₱10,000.00 and Above' : 'Section 2 — Below ₱10,000.00';
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
    final clsAcronym = _selectedClassification?.acronym ?? 'FF';
    final year = _dateOfAcquisition.year;
    final qty = _parsedQuantity;

    setState(() {
      _previewControlNumber = qty > 1
          ? '$locAcronym-$clsAcronym $year-001 (Property Group Folder • $qty Units)'
          : '$locAcronym-$clsAcronym $year-001';
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
      setState(() => _dateOfAcquisition = picked);
      _updateLiveControlNumberPreview();
    }
  }

  Future<void> _pickImageFromDevice() async {
    try {
      final dynamic result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['jpg', 'jpeg', 'png', 'webp']);
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
      debugPrint('Error selecting image: $e');
    }
  }

  Future<void> _capturePhotoWithCamera() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 92);
      if (photo != null) {
        final Uint8List rawBytes = await photo.readAsBytes();
        await _processAndWatermarkImage(rawBytes, photo.name.isNotEmpty ? photo.name : 'camera_capture.jpg');
      }
    } catch (e) {
      debugPrint('Error capturing photo: $e');
    }
  }

  Future<void> _processAndWatermarkImage(Uint8List rawBytes, String filename) async {
    setState(() => _isProcessingImage = true);
    try {
      final label = _itemNameController.text.trim().isNotEmpty
          ? '$_previewControlNumber • ${_itemNameController.text.trim()}'
          : _previewControlNumber;

      final watermarked = await AssetImageWatermarkUtil.applySecurityWatermark(
        rawImageBytes: rawBytes,
        assetIdentifier: label,
        captureTime: DateTime.now(),
      );

      if (!mounted) return;
      setState(() {
        _watermarkedPhotoBytes = watermarked;
        _photoFileName = filename;
        _isProcessingImage = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _watermarkedPhotoBytes = rawBytes;
        _photoFileName = filename;
        _isProcessingImage = false;
      });
    }
  }

  Future<void> _submitAsset() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) return;
    if (_selectedLocation == null) {
      setState(() => _errorMessage = 'Please select a storage location.');
      return;
    }
    if (_selectedClassification == null) {
      setState(() => _errorMessage = 'Please select a property classification.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      String? uploadedPhotoUrl;
      if (_watermarkedPhotoBytes != null && _photoFileName != null) {
        final tempId = 'AST-${DateTime.now().millisecondsSinceEpoch % 100000}';
        uploadedPhotoUrl = await AssetService.uploadAssetPhoto(
          assetId: tempId,
          fileBytes: _watermarkedPhotoBytes!,
          fileName: _photoFileName!,
        );
      }

      await AssetService.registerBulkAssets(
        itemName: _itemNameController.text.trim(),
        quantity: _parsedQuantity,
        unitPrice: _parsedUnitPrice,
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
        rfidTag: _rfidTagController.text.trim(),
        conditionStatus: _conditionStatus,
        operationalStatus: _operationalStatus,
      );

      if (!mounted) return;
      Navigator.pop(context);
      widget.onAssetSaved?.call();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Asset registered successfully in the Book of Inventory.'),
          backgroundColor: ParishColors.oliveGreen,
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
            Text('Register Parish Property / Asset Group',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark)),
            Text('Assign standardized Diocesan Control Numbers & record property groups',
                style: TextStyle(fontSize: 12, color: textMuted)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: ParishColors.oliveGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _isSaving ? null : _submitAsset,
              icon: _isSaving
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check, size: 18),
              label: Text(_isSaving ? 'Registering...' : 'Register Asset', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: _isLoadingReferences
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
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
                      child: Text(_errorMessage!, style: const TextStyle(color: ParishColors.mercyRed, fontWeight: FontWeight.bold)),
                    ),
                  ],

                  // Control Number Preview Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: ParishColors.goldLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ParishColors.goldAccent.withOpacity(0.6)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.folder_copy_outlined, color: ParishColors.goldAccent, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Diocesan Control Number Preview:',
                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: ParishColors.goldAccent)),
                              const SizedBox(height: 2),
                              Text(_previewControlNumber,
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textDark)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  TextFormField(
                    controller: _itemNameController,
                    validator: (v) => (v?.trim().isEmpty ?? true) ? 'Asset name is required.' : null,
                    decoration: const InputDecoration(labelText: 'Asset Name / Designation * (e.g. Church Pew)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),

                  // Quantity & Valuation Box
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: cardWhite,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderGrey),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Quantity & Valuation Parameters', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: ParishColors.marianBlueSurface, borderRadius: BorderRadius.circular(6)),
                              child: Text(_determinedInventorySection, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ParishColors.marianBlue)),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _quantityController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                onChanged: (_) => _updateLiveControlNumberPreview(),
                                decoration: const InputDecoration(labelText: 'Quantity *', border: OutlineInputBorder()),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _unitPriceController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [ThousandsSeparatorCurrencyFormatter()],
                                decoration: const InputDecoration(labelText: 'Unit Price (₱)', prefixText: '₱ ', border: OutlineInputBorder()),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total Valuation Cost:', style: TextStyle(color: textMuted, fontWeight: FontWeight.bold)),
                            Text('₱ ${AssetModel.formatCurrency(_calculatedTotalCost)}',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ParishColors.oliveGreen)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Locations & Classification
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<AssetClassificationModel>(
                          value: _selectedClassification,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Classification *', border: OutlineInputBorder()),
                          items: _classifications.map((c) => DropdownMenuItem(value: c, child: Text('${c.classificationName} (${c.acronym})'))).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedClassification = val);
                              _updateLiveControlNumberPreview();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<AssetLocationModel>(
                          value: _selectedLocation,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Location *', border: OutlineInputBorder()),
                          items: _locations.map((l) => DropdownMenuItem(value: l, child: Text('${l.locationName} (${l.acronym})'))).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedLocation = val);
                              _updateLiveControlNumberPreview();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Acquisition Date & Mode
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _pickDateOfAcquisition,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                            decoration: BoxDecoration(
                              color: ParishColors.backgroundLight,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: borderGrey),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${_dateOfAcquisition.year}-${_dateOfAcquisition.month.toString().padLeft(2, '0')}-${_dateOfAcquisition.day.toString().padLeft(2, '0')}'),
                                const Icon(Icons.calendar_today, size: 18, color: ParishColors.marianBlue),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _modeOfAcquisition,
                          decoration: const InputDecoration(labelText: 'Acquisition Mode *', border: OutlineInputBorder()),
                          items: _acquisitionModes.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                          onChanged: (val) => setState(() => _modeOfAcquisition = val!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Condition & Operational Status
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _conditionStatus,
                          decoration: const InputDecoration(labelText: 'Physical Condition *', border: OutlineInputBorder()),
                          items: _conditions.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                          onChanged: (val) => setState(() => _conditionStatus = val!),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _operationalStatus,
                          decoration: const InputDecoration(labelText: 'Operational Status *', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'Active', child: Text('Active')),
                            DropdownMenuItem(value: 'In Storage', child: Text('In Storage')),
                            DropdownMenuItem(value: 'Under Maintenance', child: Text('Under Maintenance')),
                          ],
                          onChanged: (val) => setState(() => _operationalStatus = val!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Watermarked Photo Capture Box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _watermarkedPhotoBytes != null ? ParishColors.oliveGreenSurface : cardWhite,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _watermarkedPhotoBytes != null ? ParishColors.oliveGreen : borderGrey),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: ParishColors.backgroundLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: borderGrey),
                          ),
                          child: _isProcessingImage
                              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                              : _watermarkedPhotoBytes != null
                              ? ClipRRect(borderRadius: BorderRadius.circular(9), child: Image.memory(_watermarkedPhotoBytes!, fit: BoxFit.cover))
                              : const Icon(Icons.image, size: 36, color: ParishColors.marianBlue),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _watermarkedPhotoBytes != null ? 'Security Watermark Embedded' : 'Capture or Upload Asset Photo',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: textDark),
                              ),
                              const SizedBox(height: 4),
                              Text('Photos are stamped with permanent control number and timestamp.', style: TextStyle(fontSize: 11.5, color: textMuted)),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                children: [
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(backgroundColor: ParishColors.marianBlue, foregroundColor: Colors.white),
                                    onPressed: _isProcessingImage ? null : _capturePhotoWithCamera,
                                    icon: const Icon(Icons.camera_alt, size: 16),
                                    label: const Text('Camera'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: _isProcessingImage ? null : _pickImageFromDevice,
                                    icon: const Icon(Icons.upload_file, size: 16),
                                    label: const Text('Upload Image'),
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

                  TextFormField(
                    controller: _remarksController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Remarks & Maintenance Notes', border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}