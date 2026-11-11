// =============================================================================
// FILE: lib/features/asset_inventory/presentation/pages/register_asset_page.dart
// =============================================================================

import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/colors.dart';
import '../../models/asset_draft_model.dart';
import '../../models/asset_model.dart';
import '../../models/asset_reference_models.dart';
import '../../services/asset_draft_service.dart';
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

class RegisterAssetPage extends StatefulWidget {
  final VoidCallback? onAssetSaved;
  final AssetDraftModel? initialDraft;

  const RegisterAssetPage({
    super.key,
    this.onAssetSaved,
    this.initialDraft,
  });

  @override
  State<RegisterAssetPage> createState() => _RegisterAssetPageState();
}

class _RegisterAssetPageState extends State<RegisterAssetPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _itemNameController;
  late final TextEditingController _quantityController;
  late final TextEditingController _unitPriceController;
  late final TextEditingController _dimensionsController;
  late final TextEditingController _colorController;
  late final TextEditingController _modelController;
  late final TextEditingController _othersController;
  late final TextEditingController _remarksController;
  late final TextEditingController _rfidTagController;
  late final TextEditingController _sequenceNumberController;

  List<AssetLocationModel> _locations = [];
  List<AssetClassificationModel> _classifications = [];
  AssetLocationModel? _selectedLocation;
  AssetClassificationModel? _selectedClassification;
  bool _isLoadingReferences = true;
  bool _isLoadingSequence = false;

  // Separated inline date mechanism (Month & Day are optional, no future dates allowed)
  late int _selectedYear;
  int? _selectedMonth; // null = optional/unspecified, NEVER forced to January
  int? _selectedDay; // null = optional/unspecified, NEVER forced to 1st

  late String _modeOfAcquisition;
  late String _conditionStatus;
  late String _operationalStatus;

  String? _existingPhotoUrl;
  Uint8List? _watermarkedPhotoBytes;
  String? _photoFileName;
  bool _isProcessingImage = false;
  bool _isSaving = false;
  bool _isSavingDraft = false;
  String? _errorMessage;

  final List<String> _acquisitionModes = [
    'Purchase',
    'Donation',
    'Transfer',
    'Diocesan Grant',
    'Inherited / Legacy',
    'Found / Recovered',
  ];

  final List<String> _conditions = AssetModel.standardConditions;
  final List<String> _operationalStatuses = AssetModel.standardAvailability;

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

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final d = widget.initialDraft;

    _itemNameController = TextEditingController(text: d?.itemName ?? '');
    _quantityController = TextEditingController(text: '${d?.quantity ?? 1}');
    _unitPriceController = TextEditingController(
      text: (d != null && d.unitPrice > 0)
          ? AssetModel.formatCurrency(d.unitPrice)
          : '',
    );
    _dimensionsController = TextEditingController(text: d?.dimensions ?? '');
    _colorController = TextEditingController(text: d?.color ?? '');
    _modelController = TextEditingController(text: d?.model ?? '');
    _othersController = TextEditingController(text: d?.others ?? '');
    _remarksController = TextEditingController(text: d?.remarks ?? '');
    _rfidTagController = TextEditingController(text: d?.rfidTag ?? '');
    _sequenceNumberController =
        TextEditingController(text: d?.sequenceNumber ?? '001');

    final initialDate = d?.dateOfAcquisition;

    // Strict validation: cap at current year to prevent future dates
    final cappedYear = (initialDate != null && initialDate.year > now.year)
        ? now.year
        : (initialDate?.year ?? now.year);
    _selectedYear = cappedYear;

    // Month and day are strictly optional: null by default unless explicitly saved in draft
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

    _modeOfAcquisition = d?.modeOfAcquisition ?? 'Purchase';
    _conditionStatus = AssetModel.normalizeCondition(d?.conditionStatus);
    _operationalStatus = AssetModel.normalizeStatus(d?.operationalStatus);
    _existingPhotoUrl = d?.photoUrl;
    _watermarkedPhotoBytes = d?.localPhotoBytes;
    _photoFileName = d?.photoFileName;

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

  /// Returns null if month or day was left optional, completely preventing false "January 1" outputs
  DateTime? get _effectiveDateOfAcquisition {
    if (_selectedMonth != null && _selectedDay != null) {
      return DateTime(_selectedYear, _selectedMonth!, _selectedDay!);
    }
    return null;
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
    return _parsedUnitPrice >= 10000.0
        ? 'Section 1 — ₱10,000.00 and Above'
        : 'Section 2 — Below ₱10,000.00';
  }

  String get _controlNumberPrefix {
    final locAcronym = _selectedLocation?.acronym ?? 'C';
    final clsAcronym = _selectedClassification?.acronym ?? 'FF';
    return '$locAcronym-$clsAcronym $_selectedYear-';
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

        if (widget.initialDraft != null) {
          _selectedLocation = locs.firstWhere(
                (l) =>
            l.acronym.toUpperCase() ==
                widget.initialDraft!.locationAcronym.toUpperCase(),
            orElse: () => locs.isNotEmpty ? locs.first : null as dynamic,
          );
          _selectedClassification = classifs.firstWhere(
                (c) =>
            c.acronym.toUpperCase() ==
                widget.initialDraft!.classificationAcronym.toUpperCase(),
            orElse: () =>
            classifs.isNotEmpty ? classifs.first : null as dynamic,
          );
        } else {
          if (locs.isNotEmpty) _selectedLocation = locs.first;
          if (classifs.isNotEmpty) _selectedClassification = classifs.first;
        }

        _isLoadingReferences = false;
      });

      if (widget.initialDraft == null) {
        await _fetchAutoSequenceNumber();
      }
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
        acquisitionYear: _selectedYear,
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

  Future<void> _openDedicated3RCameraPage() async {
    final idLabel = _itemNameController.text.trim().isNotEmpty
        ? '$_fullControlNumber • ${_itemNameController.text.trim()}'
        : _fullControlNumber;

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
        _watermarkedPhotoBytes = capturedWatermarkedBytes;
        _photoFileName =
        'photo_3R_${DateTime.now().millisecondsSinceEpoch}.png';
        _existingPhotoUrl = null;
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

  Future<void> _processAndWatermarkImage(
      Uint8List rawBytes,
      String filename,
      ) async {
    setState(() => _isProcessingImage = true);
    try {
      final label = _itemNameController.text.trim().isNotEmpty
          ? '$_fullControlNumber • ${_itemNameController.text.trim()}'
          : _fullControlNumber;

      final watermarked = await AssetImageWatermarkUtil.applySecurityWatermark(
        rawImageBytes: rawBytes,
        assetIdentifier: label,
        captureTime: DateTime.now(),
      );

      if (!mounted) return;
      setState(() {
        _watermarkedPhotoBytes = watermarked;
        _photoFileName = filename;
        _existingPhotoUrl = null;
        _isProcessingImage = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Security watermark embedded. Tap thumbnail to inspect full preview.',
          ),
          backgroundColor: ParishColors.oliveGreen,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _watermarkedPhotoBytes = rawBytes;
        _photoFileName = filename;
        _existingPhotoUrl = null;
        _isProcessingImage = false;
      });
    }
  }

  void _openInteractiveImagePreview() {
    ImageProvider? provider;
    if (_watermarkedPhotoBytes != null) {
      provider = MemoryImage(_watermarkedPhotoBytes!);
    } else if (_existingPhotoUrl != null && _existingPhotoUrl!.isNotEmpty) {
      provider = NetworkImage(_existingPhotoUrl!);
    }

    if (provider == null) return;

    AssetImageWatermarkUtil.showImagePreviewModal(
      context,
      imageProvider: provider,
      title: _itemNameController.text.trim().isNotEmpty
          ? _itemNameController.text.trim()
          : 'Item Photo',
      controlNumber: _fullControlNumber,
    );
  }

  Future<void> _saveAsDraft() async {
    setState(() {
      _isSavingDraft = true;
      _errorMessage = null;
    });

    try {
      final draftId = widget.initialDraft?.draftId ??
          'DRAFT-${DateTime.now().millisecondsSinceEpoch}';

      String? uploadedDraftUrl = _existingPhotoUrl;

      if (_watermarkedPhotoBytes != null && _photoFileName != null) {
        final uploaded = await AssetDraftService.uploadDraftPhoto(
          draftId: draftId,
          fileBytes: _watermarkedPhotoBytes!,
          fileName: _photoFileName!,
        );
        if (uploaded != null) {
          uploadedDraftUrl = uploaded;
        }
      }

      final draft = AssetDraftModel(
        draftId: draftId,
        itemName: _itemNameController.text.trim(),
        locationId: _selectedLocation?.locationId,
        locationAcronym: _selectedLocation?.acronym ?? 'C',
        locationName: _selectedLocation?.locationName,
        classificationId: _selectedClassification?.classificationId,
        classificationAcronym: _selectedClassification?.acronym ?? 'FF',
        classificationName: _selectedClassification?.classificationName,
        sequenceNumber: _sequenceNumberController.text.trim().isNotEmpty
            ? _sequenceNumberController.text.trim()
            : '001',
        quantity: _parsedQuantity,
        unitPrice: _parsedUnitPrice,
        totalCost: _calculatedTotalCost,
        dateOfAcquisition: _effectiveDateOfAcquisition ?? DateTime(_selectedYear, 1, 1),
        modeOfAcquisition: _modeOfAcquisition,
        conditionStatus: _conditionStatus,
        operationalStatus: _operationalStatus,
        dimensions: _dimensionsController.text.trim().isNotEmpty
            ? _dimensionsController.text.trim()
            : null,
        color: _colorController.text.trim().isNotEmpty
            ? _colorController.text.trim()
            : null,
        model: _modelController.text.trim().isNotEmpty
            ? _modelController.text.trim()
            : null,
        others: _othersController.text.trim().isNotEmpty
            ? _othersController.text.trim()
            : null,
        remarks: _remarksController.text.trim().isNotEmpty
            ? _remarksController.text.trim()
            : null,
        rfidTag: _rfidTagController.text.trim().isNotEmpty
            ? _rfidTagController.text.trim()
            : null,
        photoUrl: uploadedDraftUrl,
        localPhotoBytes: _watermarkedPhotoBytes,
        photoFileName: _photoFileName,
        updatedAt: DateTime.now(),
      );

      await AssetDraftService.saveDraft(draft);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Draft saved to cloud. You can resume editing anytime across your devices.',
          ),
          backgroundColor: ParishColors.oliveGreen,
          duration: Duration(seconds: 3),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to save cloud draft: $e';
        _isSavingDraft = false;
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
      setState(() => _errorMessage = 'Please select an item category.');
      return;
    }

    final seq = _sequenceNumberController.text.trim();
    if (seq.isEmpty) {
      setState(
              () => _errorMessage = 'Please specify the sequence number suffix.');
      return;
    }

    final int qty = _parsedQuantity;
    if (qty <= 0) {
      setState(() => _errorMessage = 'Quantity must be at least 1.');
      return;
    }

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
      setState(() =>
      _errorMessage = 'Date of acquisition cannot be set to a future date.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      String? uploadedPhotoUrl = _existingPhotoUrl;
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

      // Passes null dateOfAcquisition if month and day are optional, preserving only acquisitionYear
      final createdAsset = await AssetService.registerAsset(
        itemName: _itemNameController.text.trim(),
        quantity: qty,
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
        dateOfAcquisition: _effectiveDateOfAcquisition,
        acquisitionYear: _selectedYear,
        modeOfAcquisition: _modeOfAcquisition,
        rfidTag: _rfidTagController.text.trim(),
        conditionStatus: _conditionStatus,
        operationalStatus: _operationalStatus,
        customControlNumber: fullControlNo,
      );

      if (widget.initialDraft != null) {
        await AssetDraftService.deleteDraft(widget.initialDraft!.draftId);
      }

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
        final bool isMobile = constraints.maxWidth < 650;

        return Scaffold(
          backgroundColor: ParishColors.backgroundLight,
          appBar: AppBar(
            backgroundColor: cardWhite,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back,
                color: ParishColors.marianBlue,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.initialDraft != null
                            ? 'Resume Registration'
                            : 'Register New Item',
                        style: TextStyle(
                          fontSize: isMobile ? 16 : 18,
                          fontWeight: FontWeight.bold,
                          color: textDark,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.initialDraft != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: ParishColors.goldLight,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color:
                              ParishColors.goldAccent.withOpacity(0.5)),
                        ),
                        child: const Text(
                          'CLOUD DRAFT',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: ParishColors.goldAccent,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  'Record parish property with automated control number and quantity count',
                  style: TextStyle(
                    fontSize: isMobile ? 10.5 : 12,
                    color: textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          body: _isLoadingReferences
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 14 : 24,
              vertical: isMobile ? 14 : 24,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
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
                                color: ParishColors.mercyRed),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline,
                                  color: ParishColors.mercyRed,
                                  size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: ParishColors.mercyRed,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // 1. Photographic Evidence Section
                      _buildFormSectionCard(
                        title: 'Photographic Evidence',
                        subtitle:
                        'Capture 3R photo (10:7 Landscape or 7:10 Portrait) or upload image',
                        icon: Icons.camera_alt_outlined,
                        iconColor: ParishColors.marianBlue,
                        child: _buildPhotoUploadBox(isMobile, borderGrey,
                            cardWhite, textDark, textMuted),
                      ),
                      const SizedBox(height: 18),

                      // 2. Item Identification & Control Number Section
                      _buildFormSectionCard(
                        title: 'Item Identification & Control Number',
                        subtitle:
                        'Canonical control coding, naming, and diocesan classifications',
                        icon: Icons.qr_code_2,
                        iconColor: ParishColors.goldAccent,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildControlNumberCard(isMobile),
                            const SizedBox(height: 18),

                            // General Header: Name
                            _buildGeneralHeader('Name'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _itemNameController,
                              validator: (v) =>
                              (v?.trim().isEmpty ?? true)
                                  ? 'Please enter the item name.'
                                  : null,
                              style: TextStyle(
                                  fontSize: 14,
                                  color: textDark,
                                  fontWeight: FontWeight.bold),
                              decoration: _floatingInputDecoration(
                                labelText: 'Item Name *',
                              ),
                            ),
                            const SizedBox(height: 18),

                            // General Header: Location & Classification
                            _buildGeneralHeader('Location & Classification'),
                            const SizedBox(height: 8),
                            isMobile
                                ? Column(
                              children: [
                                _buildClassificationDropdown(),
                                const SizedBox(height: 12),
                                _buildLocationDropdown(),
                              ],
                            )
                                : Row(
                              children: [
                                Expanded(
                                  child:
                                  _buildClassificationDropdown(),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildLocationDropdown(),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // 3. Acquisition Date, Valuation & Method Section
                      _buildFormSectionCard(
                        title: 'Acquisition & Valuation',
                        subtitle:
                        'Acquisition date (separated inline), value tiering, and quantity count',
                        icon: Icons.payments_outlined,
                        iconColor: ParishColors.oliveGreen,
                        headerTrailing: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _parsedUnitPrice >= 10000.0
                                ? ParishColors.goldLight
                                : ParishColors.marianBlueSurface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _parsedUnitPrice >= 10000.0
                                  ? ParishColors.goldAccent
                                  : ParishColors.marianBlue,
                              width: 1.2,
                            ),
                          ),
                          child: Text(
                            _determinedInventorySection.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _parsedUnitPrice >= 10000.0
                                  ? ParishColors.goldAccent
                                  : ParishColors.marianBlue,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // General Header: Date of Acquisition
                            _buildGeneralHeader('Date of Acquisition'),
                            const SizedBox(height: 8),

                            // Separated Inline Date Dropdowns (Month, Day, Year) - No future dates, Month & Day optional
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
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: _quantityController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter
                                          .digitsOnly,
                                    ],
                                    validator: (v) {
                                      final num = int.tryParse(
                                          v?.trim() ?? '');
                                      if (num == null || num <= 0) {
                                        return 'Min 1';
                                      }
                                      return null;
                                    },
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: textDark,
                                    ),
                                    decoration: _floatingInputDecoration(
                                      labelText: 'Quantity *',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    controller: _unitPriceController,
                                    keyboardType: const TextInputType
                                        .numberWithOptions(
                                      decimal: true,
                                    ),
                                    inputFormatters: [
                                      ThousandsSeparatorCurrencyFormatter(),
                                    ],
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: textDark,
                                    ),
                                    decoration: _floatingInputDecoration(
                                      labelText: 'Price per Unit (₱)',
                                      prefixIcon: Padding(
                                        padding:
                                        const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 12,
                                        ),
                                        child: Text(
                                          '₱',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: textDark,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: ParishColors.backgroundLight,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: ParishColors.oliveGreen
                                        .withOpacity(0.4)),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Calculated Total Cost:',
                                    style: TextStyle(
                                      color: textMuted,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    '₱ ${AssetModel.formatCurrency(_calculatedTotalCost)}',
                                    style: const TextStyle(
                                      fontSize: 17,
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
                      const SizedBox(height: 18),

                      // 4. Physical Specifications & Descriptions Section
                      _buildFormSectionCard(
                        title: 'Physical Specifications & Status',
                        subtitle:
                        'Dimensions, color, model, condition, availability, and notes',
                        icon: Icons.tune,
                        iconColor: ParishColors.goldAccent,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                                  child:
                                  _buildOperationalStatusDropdown(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),

                            // General Header: Wireless Identification
                            _buildGeneralHeader('Wireless Identification'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _rfidTagController,
                              style: TextStyle(
                                  fontSize: 13.5,
                                  color: textDark,
                                  fontWeight: FontWeight.bold),
                              decoration: _floatingInputDecoration(
                                labelText:
                                'Wireless RFID / NFC Tag (Optional)',
                                prefixIcon: const Icon(Icons.nfc,
                                    size: 16,
                                    color: ParishColors.marianBlue),
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
                                        controller:
                                        _dimensionsController,
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: textDark,
                                            fontWeight:
                                            FontWeight.bold),
                                        decoration:
                                        _floatingInputDecoration(
                                          labelText: 'Dimensions',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextFormField(
                                        controller:
                                        _colorController,
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: textDark,
                                            fontWeight:
                                            FontWeight.bold),
                                        decoration:
                                        _floatingInputDecoration(
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
                                      fontWeight: FontWeight.bold),
                                  decoration:
                                  _floatingInputDecoration(
                                    labelText: 'Model / Maker',
                                  ),
                                ),
                              ],
                            )
                                : Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller:
                                    _dimensionsController,
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: textDark,
                                        fontWeight:
                                        FontWeight.bold),
                                    decoration:
                                    _floatingInputDecoration(
                                      labelText:
                                      'Size / Dimensions',
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
                                        fontWeight:
                                        FontWeight.bold),
                                    decoration:
                                    _floatingInputDecoration(
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
                                        fontWeight:
                                        FontWeight.bold),
                                    decoration:
                                    _floatingInputDecoration(
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
                                  fontWeight: FontWeight.bold),
                              decoration: _floatingInputDecoration(
                                labelText:
                                'Other Descriptions / Inscriptions',
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _remarksController,
                              maxLines: 2,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: textDark,
                                  fontWeight: FontWeight.bold),
                              decoration: _floatingInputDecoration(
                                labelText:
                                'Remarks & Maintenance Observations',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 5. Form Actions Section Card
                      _buildFormActionSection(
                          isMobile, cardWhite, borderGrey, textMuted),
                      const SizedBox(height: 48),
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
                _fetchAutoSequenceNumber();
              }
            },
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // Section Cards & Form Fields
  // ===========================================================================

  Widget _buildFormSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Widget child,
    Widget? headerTrailing,
  }) {
    return Container(
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
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: ParishColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: ParishColors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (headerTrailing != null) headerTrailing,
            ],
          ),
          const Divider(height: 22),
          child,
        ],
      ),
    );
  }

  Widget _buildControlNumberCard(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ParishColors.goldLight,
        borderRadius: BorderRadius.circular(12),
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
              const Icon(Icons.qr_code_2,
                  color: ParishColors.goldAccent, size: 22),
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
                      strokeWidth: 2, color: ParishColors.goldAccent),
                )
              else
                Tooltip(
                  message: 'Re-sync sequence from latest database entry',
                  child: InkWell(
                    onTap: _fetchAutoSequenceNumber,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.refresh,
                              size: 14,
                              color: ParishColors.goldAccent.withOpacity(0.9)),
                          const SizedBox(width: 4),
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
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ParishColors.borderGrey),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline,
                        size: 13, color: ParishColors.textMuted),
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
                    labelText: 'Sequence',
                    labelStyle: TextStyle(
                      fontSize: 12,
                      color: ParishColors.textMuted,
                    ),
                    floatingLabelStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: ParishColors.marianBlue,
                    ),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                          color: ParishColors.goldAccent, width: 1.2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                          color: ParishColors.goldAccent.withOpacity(0.8),
                          width: 1.2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                          color: ParishColors.marianBlue, width: 1.6),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.info_outline,
                  size: 13, color: ParishColors.textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Full Control Number: $_fullControlNumber (Last part can be modified during registration; locked afterwards).',
                  style: TextStyle(
                      fontSize: 11,
                      color: ParishColors.textDark.withOpacity(0.75)),
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

  Widget _buildPhotoUploadBox(
      bool isMobile,
      Color borderGrey,
      Color cardWhite,
      Color textDark,
      Color textMuted,
      ) {
    final bool hasNewPhoto = _watermarkedPhotoBytes != null;
    final bool hasExistingPhoto =
        _existingPhotoUrl != null && _existingPhotoUrl!.isNotEmpty;
    final bool hasAnyPhoto = hasNewPhoto || hasExistingPhoto;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hasAnyPhoto
            ? ParishColors.oliveGreenSurface
            : ParishColors.backgroundLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasAnyPhoto ? ParishColors.oliveGreen : borderGrey,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo Thumbnail Box
          InkWell(
            onTap: hasAnyPhoto ? _openInteractiveImagePreview : null,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: hasAnyPhoto ? ParishColors.goldAccent : borderGrey,
                ),
              ),
              child: _isProcessingImage
                  ? const Center(
                  child: CircularProgressIndicator(strokeWidth: 2))
                  : hasNewPhoto
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Image.memory(
                  _watermarkedPhotoBytes!,
                  fit: BoxFit.cover,
                ),
              )
                  : hasExistingPhoto
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Image.network(
                  _existingPhotoUrl!,
                  fit: BoxFit.cover,
                ),
              )
                  : const Icon(
                Icons.photo_camera_outlined,
                size: 38,
                color: ParishColors.marianBlue,
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Labels and Buttons Strip
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasAnyPhoto
                      ? (hasNewPhoto
                      ? '3R Watermarked Photo Embedded'
                      : 'Cloud Photo Attached')
                      : 'Capture 3R Photo or Upload File',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                      color: textDark),
                ),
                const SizedBox(height: 4),
                Text(
                  '3R standard framing (5×3.5 Landscape or 3.5×5 Portrait) calibrated for official inventory cards.',
                  style: TextStyle(fontSize: 11.5, color: textMuted),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // Dedicated 3R Camera Launch Button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ParishColors.marianBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      onPressed: _isProcessingImage
                          ? null
                          : _openDedicated3RCameraPage,
                      icon: const Icon(Icons.camera_alt, size: 16),
                      label: const Text('3R Camera'),
                    ),

                    // Upload Image from Files
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ParishColors.marianBlue,
                        side:
                        const BorderSide(color: ParishColors.marianBlue),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      onPressed: _isProcessingImage
                          ? null
                          : _pickImageFromDevice,
                      icon: const Icon(Icons.upload_file, size: 16),
                      label: const Text('Upload Image'),
                    ),

                    // Inspect Full Watermarked Preview
                    if (hasAnyPhoto) ...[
                      TextButton.icon(
                        onPressed: _openInteractiveImagePreview,
                        icon: const Icon(Icons.zoom_in, size: 16),
                        label: const Text('Inspect'),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _watermarkedPhotoBytes = null;
                            _existingPhotoUrl = null;
                            _photoFileName = null;
                          });
                        },
                        icon: const Icon(Icons.delete_outline,
                            size: 16, color: ParishColors.mercyRed),
                        label: const Text(
                          'Remove',
                          style: TextStyle(color: ParishColors.mercyRed),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormActionSection(
      bool isMobile,
      Color cardWhite,
      Color borderGrey,
      Color textMuted,
      ) {
    final bool isBusy = _isSaving || _isSavingDraft;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderGrey),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 14 : 20,
        vertical: 14,
      ),
      child: isMobile
          ? Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: ParishColors.marianBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 1,
              ),
              onPressed: isBusy ? null : _submitAsset,
              icon: _isSaving
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
                  : const Icon(Icons.check, size: 18),
              label: Text(
                _isSaving ? 'Registering...' : 'Save & Register Item',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: ParishColors.goldAccent,
                side: const BorderSide(color: ParishColors.goldAccent),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: isBusy ? null : _saveAsDraft,
              icon: _isSavingDraft
                  ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: ParishColors.goldAccent),
              )
                  : const Icon(Icons.cloud_upload_outlined, size: 16),
              label: Text(
                _isSavingDraft
                    ? 'Saving Cloud Draft...'
                    : 'Save as Cloud Draft',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: TextButton(
              onPressed: isBusy ? null : () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: textMuted)),
            ),
          ),
        ],
      )
          : Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: textMuted,
              side: BorderSide(color: borderGrey),
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: isBusy ? null : () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: ParishColors.goldAccent,
                  side: const BorderSide(
                      color: ParishColors.goldAccent, width: 1.2),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: isBusy ? null : _saveAsDraft,
                icon: _isSavingDraft
                    ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: ParishColors.goldAccent),
                )
                    : const Icon(Icons.cloud_upload_outlined, size: 16),
                label: Text(
                  _isSavingDraft
                      ? 'Saving Cloud Draft...'
                      : 'Save as Cloud Draft',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ParishColors.marianBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 26, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 1,
                ),
                onPressed: isBusy ? null : _submitAsset,
                icon: _isSaving
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
                    : const Icon(Icons.check, size: 18),
                label: Text(
                  _isSaving ? 'Registering...' : 'Save & Register Item',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
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
      decoration: _floatingInputDecoration(
        labelText: 'Category *',
      ),
      items: _classifications.map((c) {
        return DropdownMenuItem(
          value: c,
          child: Text('${c.classificationName} (${c.acronym})',
              style: const TextStyle(fontSize: 13)),
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
      decoration: _floatingInputDecoration(
        labelText: 'Storage Location *',
      ),
      items: _locations.map((l) {
        return DropdownMenuItem(
          value: l,
          child: Text('${l.locationName} (${l.acronym})',
              style: const TextStyle(fontSize: 13)),
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

  Widget _buildConditionDropdown() {
    return DropdownButtonFormField<String>(
      value: _conditionStatus,
      isExpanded: true,
      decoration: _floatingInputDecoration(
        labelText: 'Item Condition *',
      ),
      items: _conditions.map((c) {
        final desc = AssetModel.conditionDescriptions[c] ?? '';
        return DropdownMenuItem(
          value: c,
          child: Text(
            desc.isNotEmpty ? '$c ($desc)' : c,
            style: const TextStyle(fontSize: 13),
          ),
        );
      }).toList(),
      onChanged: (val) => setState(() => _conditionStatus = val!),
    );
  }

  Widget _buildOperationalStatusDropdown() {
    return DropdownButtonFormField<String>(
      value: AssetModel.normalizeStatus(_operationalStatus),
      isExpanded: true,
      decoration: _floatingInputDecoration(
        labelText: 'Availability *',
      ),
      items: _operationalStatuses.map((s) {
        final desc = AssetModel.availabilityDescriptions[s] ?? '';
        return DropdownMenuItem(
          value: s,
          child: Text(
            desc.isNotEmpty ? '$s — $desc' : s,
            style: const TextStyle(fontSize: 13),
          ),
        );
      }).toList(),
      onChanged: (val) => setState(() => _operationalStatus = val!),
    );
  }
}