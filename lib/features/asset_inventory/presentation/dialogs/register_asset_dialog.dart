// =============================================================================
// FILE: lib/features/asset_inventory/presentation/dialogs/register_asset_dialog.dart
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

void showRegisterAssetModal(BuildContext context, {VoidCallback? onAssetSaved}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _RegisterAssetDialog(onAssetSaved: onAssetSaved),
  );
}

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

class _RegisterAssetDialog extends StatefulWidget {
  final VoidCallback? onAssetSaved;

  const _RegisterAssetDialog({this.onAssetSaved});

  @override
  State<_RegisterAssetDialog> createState() => _RegisterAssetDialogState();
}

class _RegisterAssetDialogState extends State<_RegisterAssetDialog> {
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
  final _sequenceNumberController = TextEditingController(text: '001');

  List<AssetLocationModel> _locations = [];
  List<AssetClassificationModel> _classifications = [];
  AssetLocationModel? _selectedLocation;
  AssetClassificationModel? _selectedClassification;
  bool _isLoadingReferences = true;
  bool _isLoadingSequence = false;

  DateTime _dateOfAcquisition = DateTime.now();
  String _modeOfAcquisition = 'Purchase';
  String _conditionStatus = 'Good';
  String _operationalStatus = 'Available';

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

  // Standardized Canonical Condition Options
  final List<String> _conditions = AssetModel.standardConditions;

  // Standardized Canonical Status Options
  final List<String> _operationalStatuses = AssetModel.standardStatuses;

  @override
  void initState() {
    super.initState();
    _loadReferences();
    _quantityController.addListener(() => setState(() {}));
    _unitPriceController.addListener(() => setState(() {}));
    _sequenceNumberController.addListener(() => setState(() {}));
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
    _sequenceNumberController.dispose();
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
    if (_parsedUnitPrice >= 10000.0) {
      return 'Section 1 — ₱10,000.00 and Above';
    } else {
      return 'Section 2 — Below ₱10,000.00';
    }
  }

  String get _controlNumberPrefix {
    final locAcronym = _selectedLocation?.acronym ?? 'C';
    final clsAcronym = _selectedClassification?.acronym ?? 'FF';
    final year = _dateOfAcquisition.year;
    return '$locAcronym-$clsAcronym $year-';
  }

  String get _fullControlNumber {
    final seq = _sequenceNumberController.text.trim();
    return '$_controlNumberPrefix$seq';
  }

  Future<void> _loadReferences() async {
    setState(() => _isLoadingReferences = true);
    try {
      final locs = await AssetReferenceService.getLocations(activeOnly: true);
      final classifs =
      await AssetReferenceService.getClassifications(activeOnly: true);

      if (!mounted) return;
      setState(() {
        _locations = locs;
        _classifications = classifs;
        if (locs.isNotEmpty) _selectedLocation = locs.first;
        if (classifs.isNotEmpty) _selectedClassification = classifs.first;
        _isLoadingReferences = false;
      });
      await _fetchAutoSequenceNumber();
    } catch (_) {
      if (mounted) setState(() => _isLoadingReferences = false);
    }
  }

  Future<void> _fetchAutoSequenceNumber() async {
    if (_selectedLocation == null || _selectedClassification == null) return;

    setState(() => _isLoadingSequence = true);
    try {
      final nextSeq = await AssetService.getNextControlNumberSequence(
        locationAcronym: _selectedLocation!.acronym,
        classificationAcronym: _selectedClassification!.acronym,
        acquisitionYear: _dateOfAcquisition.year,
      );

      if (!mounted) return;
      setState(() {
        _sequenceNumberController.text = nextSeq.toString().padLeft(3, '0');
        _isLoadingSequence = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingSequence = false);
    }
  }

  Future<void> _pickDateOfAcquisition() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfAcquisition,
      firstDate: DateTime(1900),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      final yearChanged = picked.year != _dateOfAcquisition.year;
      setState(() => _dateOfAcquisition = picked);
      if (yearChanged) {
        await _fetchAutoSequenceNumber();
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
            await _processAndWatermarkImage(
              rawBytes,
              name ?? 'asset_photo.jpg',
            );
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
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 92,
      );

      if (photo != null) {
        final Uint8List rawBytes = await photo.readAsBytes();
        await _processAndWatermarkImage(
          rawBytes,
          photo.name.isNotEmpty ? photo.name : 'camera_photo.jpg',
        );
      }
    } catch (e) {
      debugPrint('Camera error: $e');
    }
  }

  Future<void> _processAndWatermarkImage(
      Uint8List rawBytes,
      String filename,
      ) async {
    setState(() => _isProcessingImage = true);

    try {
      final assetIdLabel = _itemNameController.text.trim().isNotEmpty
          ? '$_fullControlNumber • ${_itemNameController.text.trim()}'
          : _fullControlNumber;

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
        SnackBar(
          content: const Text(
            'Security watermark applied. Tap preview to inspect full size.',
          ),
          backgroundColor: ParishColors.oliveGreen,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      debugPrint('Watermarking note: $e');
      if (!mounted) return;
      setState(() {
        _watermarkedPhotoBytes = rawBytes;
        _photoFileName = filename;
        _isProcessingImage = false;
      });
    }
  }

  void _openInteractiveImagePreview() {
    if (_watermarkedPhotoBytes == null) return;
    AssetImageWatermarkUtil.showImagePreviewModal(
      context,
      imageProvider: MemoryImage(_watermarkedPhotoBytes!),
      title: _itemNameController.text.trim().isNotEmpty
          ? _itemNameController.text.trim()
          : 'Item Photo',
      controlNumber: _fullControlNumber,
    );
  }

  Future<void> _submitAsset() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) return;
    if (_selectedLocation == null) {
      setState(() => _errorMessage = 'Please select a storage location.');
      return;
    }
    if (_selectedClassification == null) {
      setState(() => _errorMessage = 'Please select an item category.');
      return;
    }

    final seq = _sequenceNumberController.text.trim();
    if (seq.isEmpty) {
      setState(
              () => _errorMessage = 'Please provide the sequence number suffix.');
      return;
    }

    final int qty = _parsedQuantity;
    if (qty <= 0) {
      setState(() => _errorMessage = 'Quantity must be at least 1.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final double unitPriceValue = _parsedUnitPrice;
      String? uploadedPhotoUrl;

      if (_watermarkedPhotoBytes != null && _photoFileName != null) {
        final tempId =
            'AST-${DateTime.now().millisecondsSinceEpoch % 100000}';
        uploadedPhotoUrl = await AssetService.uploadAssetPhoto(
          assetId: tempId,
          fileBytes: _watermarkedPhotoBytes!,
          fileName: _photoFileName!,
        );
      }

      final fullControlNo = _fullControlNumber;

      final AssetModel createdAsset = await AssetService.registerAsset(
        itemName: _itemNameController.text.trim(),
        quantity: qty,
        unitPrice: unitPriceValue,
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
        customControlNumber: fullControlNo,
      );

      if (!mounted) return;
      Navigator.pop(context);
      widget.onAssetSaved?.call();

      final summaryText = qty > 1
          ? 'Registered successfully: ${createdAsset.itemName} ($qty units) • Control #: ${createdAsset.controlNumber}'
          : 'Registered successfully: ${createdAsset.itemName} • Control #: ${createdAsset.controlNumber}';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(summaryText),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 620;

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: cardWhite,
          insetPadding: EdgeInsets.symmetric(
            horizontal: isMobile ? 12 : 16,
            vertical: isMobile ? 14 : 20,
          ),
          child: Container(
            width: 720,
            constraints: const BoxConstraints(maxHeight: 840),
            child: Column(
              children: [
                // Header Banner
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 16 : 22,
                    vertical: isMobile ? 12 : 16,
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
                          Icons.add_box_outlined,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Register New Item',
                              style: TextStyle(
                                fontSize: isMobile ? 15.5 : 17,
                                fontWeight: FontWeight.bold,
                                color: textDark,
                              ),
                            ),
                            Text(
                              'Record parish property with an automated control number and quantity count',
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
                        onPressed:
                        _isSaving ? null : () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // Form Body
                Expanded(
                  child: _isLoadingReferences
                      ? const Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                    padding: EdgeInsets.all(isMobile ? 14 : 22),
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
                                border: Border.all(
                                  color: ParishColors.mercyRed,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: ParishColors.mercyRed,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
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

                          // Control Number Configuration Card (Auto-generated prefix with editable suffix)
                          _buildControlNumberCard(isMobile),
                          const SizedBox(height: 18),

                          // Item Name
                          _buildLabel('Item Name *'),
                          TextFormField(
                            controller: _itemNameController,
                            validator: (v) => (v?.trim().isEmpty ?? true)
                                ? 'Please enter the item name.'
                                : null,
                            style: TextStyle(
                              fontSize: 14,
                              color: textDark,
                            ),
                            decoration: _inputDecoration(
                              hint:
                              'e.g. Wooden Church Pew, Monoblock Chair, Flat Screen TV',
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Quantity & Pricing Card
                          Container(
                            padding: EdgeInsets.all(isMobile ? 12 : 16),
                            decoration: BoxDecoration(
                              color: ParishColors.backgroundLight,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: borderGrey),
                            ),
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Quantity & Value',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.bold,
                                        color: ParishColors.marianBlue,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _parsedUnitPrice >= 10000.0
                                            ? ParishColors.goldLight
                                            : ParishColors
                                            .marianBlueSurface,
                                        borderRadius:
                                        BorderRadius.circular(6),
                                        border: Border.all(
                                          color: _parsedUnitPrice >=
                                              10000.0
                                              ? ParishColors.goldAccent
                                              : ParishColors.marianBlue,
                                          width: 1.2,
                                        ),
                                      ),
                                      child: Text(
                                        _determinedInventorySection
                                            .toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: _parsedUnitPrice >=
                                              10000.0
                                              ? ParishColors.goldAccent
                                              : ParishColors.marianBlue,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Multiple units sharing the same specifications share 1 Control Number.',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: textMuted,
                                  ),
                                ),
                                const Divider(height: 20),
                                Row(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          _buildLabel('Quantity *'),
                                          TextFormField(
                                            controller:
                                            _quantityController,
                                            keyboardType:
                                            TextInputType.number,
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly
                                            ],
                                            validator: (v) {
                                              final num = int.tryParse(
                                                  v?.trim() ?? '');
                                              if (num == null ||
                                                  num <= 0) {
                                                return 'Min 1';
                                              }
                                              return null;
                                            },
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: textDark,
                                            ),
                                            decoration: _inputDecoration(
                                              hint: 'e.g. 16',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          _buildLabel(
                                              'Price per Unit (₱)'),
                                          TextFormField(
                                            controller:
                                            _unitPriceController,
                                            keyboardType:
                                            const TextInputType
                                                .numberWithOptions(
                                              decimal: true,
                                            ),
                                            inputFormatters: [
                                              ThousandsSeparatorCurrencyFormatter()
                                            ],
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: textDark,
                                            ),
                                            decoration: _inputDecoration(
                                              hint: 'e.g. 2,500.00',
                                              prefixIcon: Padding(
                                                padding:
                                                const EdgeInsets
                                                    .symmetric(
                                                  horizontal: 10,
                                                  vertical: 12,
                                                ),
                                                child: Text(
                                                  '₱',
                                                  style: TextStyle(
                                                    fontWeight:
                                                    FontWeight.bold,
                                                    fontSize: 15,
                                                    color: textDark,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius:
                                    BorderRadius.circular(10),
                                    border: Border.all(
                                      color: ParishColors.oliveGreen
                                          .withOpacity(0.5),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Total Cost:',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.bold,
                                              color: textMuted,
                                            ),
                                          ),
                                          Text(
                                            '$_parsedQuantity unit(s) × ₱ ${AssetModel.formatCurrency(_parsedUnitPrice)}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        '₱ ${AssetModel.formatCurrency(_calculatedTotalCost)}',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: ParishColors.oliveGreen,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Category & Storage Location
                          isMobile
                              ? Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Category *'),
                              _buildClassificationDropdown(),
                              const SizedBox(height: 12),
                              _buildLabel('Storage Location *'),
                              _buildLocationDropdown(),
                            ],
                          )
                              : Row(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    _buildLabel('Category *'),
                                    _buildClassificationDropdown(),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    _buildLabel(
                                        'Storage Location *'),
                                    _buildLocationDropdown(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Acquisition Date & How Acquired
                          isMobile
                              ? Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Acquisition Date *'),
                              _buildAcquisitionDateTile(
                                borderGrey,
                                textDark,
                              ),
                              const SizedBox(height: 12),
                              _buildLabel('How Acquired *'),
                              _buildAcquisitionModeDropdown(),
                            ],
                          )
                              : Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    _buildLabel(
                                        'Acquisition Date *'),
                                    _buildAcquisitionDateTile(
                                      borderGrey,
                                      textDark,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    _buildLabel('How Acquired *'),
                                    _buildAcquisitionModeDropdown(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // RFID Tag (Optional)
                          _buildLabel(
                              'Wireless RFID / NFC Tag (Optional)'),
                          TextFormField(
                            controller: _rfidTagController,
                            style: TextStyle(
                              fontSize: 13.5,
                              color: textDark,
                            ),
                            decoration: _inputDecoration(
                              hint: 'e.g. 04:A2:4B:9C',
                              prefixIcon: const Icon(
                                Icons.nfc,
                                size: 16,
                                color: ParishColors.marianBlue,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Condition & Status (Standardized)
                          isMobile
                              ? Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Item Condition *'),
                              _buildConditionDropdown(),
                              const SizedBox(height: 12),
                              _buildLabel('Item Status *'),
                              _buildOperationalStatusDropdown(),
                            ],
                          )
                              : Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    _buildLabel('Item Condition *'),
                                    _buildConditionDropdown(),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    _buildLabel('Item Status *'),
                                    _buildOperationalStatusDropdown(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Dimensions, Color, Model
                          isMobile
                              ? Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        _buildLabel('Dimensions'),
                                        TextFormField(
                                          controller:
                                          _dimensionsController,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: textDark,
                                          ),
                                          decoration:
                                          _inputDecoration(
                                            hint:
                                            'e.g. 50 inch, 10 ft x 3 ft',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        _buildLabel('Color'),
                                        TextFormField(
                                          controller:
                                          _colorController,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: textDark,
                                          ),
                                          decoration:
                                          _inputDecoration(
                                            hint:
                                            'e.g. Black, Dark Walnut',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildLabel('Model'),
                              TextFormField(
                                controller: _modelController,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: textDark,
                                ),
                                decoration: _inputDecoration(
                                  hint:
                                  'e.g. Samsung, Custom Woodcraft',
                                ),
                              ),
                            ],
                          )
                              : Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    _buildLabel(
                                        'Size / Dimensions (Optional)'),
                                    TextFormField(
                                      controller:
                                      _dimensionsController,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: textDark,
                                      ),
                                      decoration: _inputDecoration(
                                        hint:
                                        'e.g. 50 inch, 10 ft x 3 ft',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    _buildLabel('Color'),
                                    TextFormField(
                                      controller: _colorController,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: textDark,
                                      ),
                                      decoration: _inputDecoration(
                                        hint:
                                        'e.g. Black, Dark Walnut',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    _buildLabel('Model'),
                                    TextFormField(
                                      controller: _modelController,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: textDark,
                                      ),
                                      decoration: _inputDecoration(
                                        hint:
                                        'e.g. Samsung, Custom Woodcraft',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // Photo Section
                          Row(
                            mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                            children: [
                              _buildLabel('Item Photo'),
                              if (_watermarkedPhotoBytes != null)
                                InkWell(
                                  onTap: _openInteractiveImagePreview,
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.zoom_in,
                                        size: 16,
                                        color: ParishColors.marianBlue,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Inspect Preview',
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
                                width: _watermarkedPhotoBytes != null
                                    ? 1.5
                                    : 1.0,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                InkWell(
                                  onTap: _watermarkedPhotoBytes != null
                                      ? _openInteractiveImagePreview
                                      : null,
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    width: 90,
                                    height: 90,
                                    decoration: BoxDecoration(
                                      color:
                                      ParishColors.marianBlueSurface,
                                      borderRadius:
                                      BorderRadius.circular(10),
                                      border: Border.all(
                                        color: _watermarkedPhotoBytes !=
                                            null
                                            ? ParishColors.goldAccent
                                            : borderGrey,
                                        width: 2,
                                      ),
                                    ),
                                    child: _isProcessingImage
                                        ? const Center(
                                      child:
                                      CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                        : _watermarkedPhotoBytes != null
                                        ? ClipRRect(
                                      borderRadius:
                                      BorderRadius.circular(
                                          8),
                                      child: Image.memory(
                                        _watermarkedPhotoBytes!,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                        : const Icon(
                                      Icons.image_outlined,
                                      color: ParishColors
                                          .marianBlue,
                                      size: 36,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _watermarkedPhotoBytes != null
                                            ? 'Security Watermark Embedded'
                                            : 'Take or Upload Item Photo',
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.bold,
                                          color: _watermarkedPhotoBytes !=
                                              null
                                              ? ParishColors.oliveGreen
                                              : textDark,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Photos are stamped with permanent control number and timestamp.',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: textMuted,
                                          height: 1.35,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          ElevatedButton.icon(
                                            style:
                                            ElevatedButton.styleFrom(
                                              backgroundColor:
                                              ParishColors.marianBlue,
                                              foregroundColor:
                                              Colors.white,
                                              padding: const EdgeInsets
                                                  .symmetric(
                                                horizontal: 12,
                                                vertical: 8,
                                              ),
                                            ),
                                            onPressed: _isProcessingImage
                                                ? null
                                                : _capturePhotoWithCamera,
                                            icon: const Icon(
                                              Icons.camera_alt,
                                              size: 16,
                                            ),
                                            label: const Text(
                                              'Camera',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight:
                                                FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          OutlinedButton.icon(
                                            style:
                                            OutlinedButton.styleFrom(
                                              foregroundColor:
                                              ParishColors.marianBlue,
                                              side: const BorderSide(
                                                color: ParishColors
                                                    .marianBlue,
                                              ),
                                              padding: const EdgeInsets
                                                  .symmetric(
                                                horizontal: 12,
                                                vertical: 8,
                                              ),
                                            ),
                                            onPressed: _isProcessingImage
                                                ? null
                                                : _pickImageFromDevice,
                                            icon: const Icon(
                                              Icons.file_upload_outlined,
                                              size: 16,
                                            ),
                                            label: const Text(
                                              'Upload Image',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight:
                                                FontWeight.bold,
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

                          _buildLabel('Additional Details / Markings'),
                          TextFormField(
                            controller: _othersController,
                            maxLines: 2,
                            style: TextStyle(
                              fontSize: 13,
                              color: textDark,
                            ),
                            decoration: _inputDecoration(
                              hint:
                              'e.g. Inscribed "Donated by Santos Family"',
                            ),
                          ),
                          const SizedBox(height: 14),

                          _buildLabel('Notes & Maintenance Remarks'),
                          TextFormField(
                            controller: _remarksController,
                            maxLines: 2,
                            style: TextStyle(
                              fontSize: 13,
                              color: textDark,
                            ),
                            decoration: _inputDecoration(
                              hint:
                              'e.g. Inspected and placed in main church nave',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Modal Actions
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 16 : 22,
                    vertical: isMobile ? 12 : 14,
                  ),
                  decoration: BoxDecoration(
                    color: cardWhite,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(20),
                    ),
                    border: Border(top: BorderSide(color: borderGrey)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed:
                        _isSaving ? null : () => Navigator.pop(context),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 13.5,
                            color: textMuted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 44,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ParishColors.marianBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                            ),
                          ),
                          onPressed: _isSaving ? null : _submitAsset,
                          icon: _isSaving
                              ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                              : const Icon(Icons.check, size: 18),
                          label: Text(
                            _isSaving
                                ? 'Registering...'
                                : 'Save & Register Item',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                            ),
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
      },
    );
  }

  /// Builds the interactive Control Number Card allowing the user to modify the last
  /// segment (sequence number), auto-populated from database ledger analysis.
  Widget _buildControlNumberCard(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ParishColors.goldLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ParishColors.goldAccent.withOpacity(0.6),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.qr_code_2,
                color: ParishColors.goldAccent,
                size: 22,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Assigned Diocesan Control Number',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: ParishColors.goldAccent,
                  ),
                ),
              ),
              if (_isLoadingSequence)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: ParishColors.goldAccent,
                  ),
                )
              else
                Tooltip(
                  message: 'Re-sync sequence from latest database entry',
                  child: InkWell(
                    onTap: _fetchAutoSequenceNumber,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.refresh,
                            size: 14,
                            color: ParishColors.goldAccent.withOpacity(0.9),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Auto-fill',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: ParishColors.goldAccent.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Locked Canonical Prefix Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: ParishColors.borderGrey,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                     Icon(
                      Icons.lock_outline,
                      size: 13,
                      color: ParishColors.textMuted,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _controlNumberPrefix,
                      style: TextStyle(
                        fontFamily: 'Courier',
                        fontSize: isMobile ? 12.5 : 14,
                        fontWeight: FontWeight.bold,
                        color: ParishColors.textDark,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Editable Sequence Suffix Box
              Expanded(
                child: TextFormField(
                  controller: _sequenceNumberController,
                  keyboardType: TextInputType.text,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(6),
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                  ],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Required';
                    }
                    return null;
                  },
                  style: TextStyle(
                    fontFamily: 'Courier',
                    fontSize: isMobile ? 13 : 14.5,
                    fontWeight: FontWeight.bold,
                    color: ParishColors.marianBlue,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 9,
                    ),
                    hintText: '001',
                    hintStyle: TextStyle(
                      color: ParishColors.textMuted,
                      fontSize: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: ParishColors.goldAccent,
                        width: 1.2,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: ParishColors.goldAccent.withOpacity(0.8),
                        width: 1.2,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: ParishColors.marianBlue,
                        width: 1.6,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 13,
                color: ParishColors.textMuted,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Full Control Number: $_fullControlNumber (Last part can be modified during registration; locked afterwards).',
                  style: TextStyle(
                    fontSize: 11,
                    color: ParishColors.textDark.withOpacity(0.75),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClassificationDropdown() {
    return DropdownButtonFormField<AssetClassificationModel>(
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
          _fetchAutoSequenceNumber();
        }
      },
    );
  }

  Widget _buildLocationDropdown() {
    return DropdownButtonFormField<AssetLocationModel>(
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
          _fetchAutoSequenceNumber();
        }
      },
    );
  }

  Widget _buildAcquisitionDateTile(Color borderGrey, Color textDark) {
    return InkWell(
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
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: textDark,
              ),
            ),
            const Icon(
              Icons.calendar_month,
              size: 18,
              color: ParishColors.marianBlue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAcquisitionModeDropdown() {
    return DropdownButtonFormField<String>(
      value: _modeOfAcquisition,
      isExpanded: true,
      decoration: _inputDecoration(),
      items: _acquisitionModes
          .map(
            (m) => DropdownMenuItem(
          value: m,
          child: Text(m, style: const TextStyle(fontSize: 13)),
        ),
      )
          .toList(),
      onChanged: (val) => setState(() => _modeOfAcquisition = val!),
    );
  }

  Widget _buildConditionDropdown() {
    return DropdownButtonFormField<String>(
      value: _conditionStatus,
      isExpanded: true,
      decoration: _inputDecoration(),
      items: _conditions.map((c) {
        final desc = AssetModel.conditionDescriptions[c] ?? '';
        return DropdownMenuItem(
          value: c,
          child: Text(
            desc.isNotEmpty ? '$c ($desc)' : c,
            style: const TextStyle(fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (val) => setState(() => _conditionStatus = val!),
    );
  }

  Widget _buildOperationalStatusDropdown() {
    return DropdownButtonFormField<String>(
      value: _operationalStatus,
      isExpanded: true,
      decoration: _inputDecoration(),
      items: _operationalStatuses.map((s) {
        final desc = AssetModel.statusDescriptions[s] ?? '';
        return DropdownMenuItem(
          value: s,
          child: Text(
            desc.isNotEmpty ? '$s ($desc)' : s,
            style: const TextStyle(fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (val) => setState(() => _operationalStatus = val!),
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: ParishColors.textDark,
        ),
      ),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
        borderSide: const BorderSide(color: ParishColors.marianBlue, width: 1.5),
      ),
    );
  }
}