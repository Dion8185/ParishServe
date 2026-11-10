// =============================================================================
// FILE: lib/features/asset_inventory/models/asset_draft_model.dart
// =============================================================================

import 'dart:convert';
import 'dart:typed_data';

class AssetDraftModel {
  final String draftId;
  final String itemName;
  final String? locationId;
  final String locationAcronym;
  final String? locationName;
  final String? classificationId;
  final String classificationAcronym;
  final String? classificationName;
  final String sequenceNumber;
  final int quantity;
  final double unitPrice;
  final double totalCost;
  final DateTime dateOfAcquisition;
  final String modeOfAcquisition;
  final String conditionStatus;
  final String operationalStatus;
  final String? dimensions;
  final String? color;
  final String? model;
  final String? others;
  final String? remarks;
  final String? rfidTag;
  final Uint8List? photoBytes;
  final String? photoFileName;
  final DateTime createdAt;
  final DateTime updatedAt;

  AssetDraftModel({
    required this.draftId,
    required this.itemName,
    this.locationId,
    required this.locationAcronym,
    this.locationName,
    this.classificationId,
    required this.classificationAcronym,
    this.classificationName,
    required this.sequenceNumber,
    this.quantity = 1,
    this.unitPrice = 0.0,
    double? totalCost,
    required this.dateOfAcquisition,
    this.modeOfAcquisition = 'Purchase',
    this.conditionStatus = 'Good',
    this.operationalStatus = 'Available',
    this.dimensions,
    this.color,
    this.model,
    this.others,
    this.remarks,
    this.rfidTag,
    this.photoBytes,
    this.photoFileName,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : totalCost = totalCost ?? (quantity * unitPrice),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  String get controlNumberPrefix =>
      '${locationAcronym.toUpperCase()}-${classificationAcronym.toUpperCase()} ${dateOfAcquisition.year}-';

  String get fullControlNumber => '$controlNumberPrefix${sequenceNumber.trim()}';

  String get formattedAcquisitionDate {
    return '${dateOfAcquisition.year}-${dateOfAcquisition.month.toString().padLeft(2, '0')}-${dateOfAcquisition.day.toString().padLeft(2, '0')}';
  }

  String get formattedUpdatedAt {
    return '${updatedAt.year}-${updatedAt.month.toString().padLeft(2, '0')}-${updatedAt.day.toString().padLeft(2, '0')} '
        '${updatedAt.hour.toString().padLeft(2, '0')}:${updatedAt.minute.toString().padLeft(2, '0')}';
  }

  /// Evaluates fields to provide visual completion hints on the drafts page
  List<String> get missingChecklist {
    final List<String> missing = [];
    if (itemName.trim().isEmpty) missing.add('Item Name');
    if (photoBytes == null || photoBytes!.isEmpty) missing.add('Photograph');
    if (unitPrice <= 0) missing.add('Acquisition Cost');
    if (dimensions == null || dimensions!.trim().isEmpty) missing.add('Dimensions');
    return missing;
  }

  bool get isReadyToRegister => missingChecklist.isEmpty;

  Map<String, dynamic> toMap() {
    return {
      'draft_id': draftId,
      'item_name': itemName,
      'location_id': locationId,
      'location_acronym': locationAcronym,
      'location_name': locationName,
      'classification_id': classificationId,
      'classification_acronym': classificationAcronym,
      'classification_name': classificationName,
      'sequence_number': sequenceNumber,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_cost': totalCost,
      'date_of_acquisition': dateOfAcquisition.toIso8601String(),
      'mode_of_acquisition': modeOfAcquisition,
      'condition_status': conditionStatus,
      'operational_status': operationalStatus,
      'dimensions': dimensions,
      'color': color,
      'model': model,
      'others': others,
      'remarks': remarks,
      'rfid_tag': rfidTag,
      'photo_bytes': photoBytes != null ? base64Encode(photoBytes!) : null,
      'photo_file_name': photoFileName,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory AssetDraftModel.fromMap(Map<String, dynamic> map) {
    Uint8List? decodedPhoto;
    if (map['photo_bytes'] != null && map['photo_bytes'].toString().isNotEmpty) {
      try {
        decodedPhoto = base64Decode(map['photo_bytes'].toString());
      } catch (_) {}
    }

    return AssetDraftModel(
      draftId: map['draft_id']?.toString() ?? '',
      itemName: map['item_name']?.toString() ?? '',
      locationId: map['location_id']?.toString(),
      locationAcronym: map['location_acronym']?.toString() ?? 'C',
      locationName: map['location_name']?.toString(),
      classificationId: map['classification_id']?.toString(),
      classificationAcronym: map['classification_acronym']?.toString() ?? 'FF',
      classificationName: map['classification_name']?.toString(),
      sequenceNumber: map['sequence_number']?.toString() ?? '001',
      quantity: int.tryParse(map['quantity']?.toString() ?? '') ?? 1,
      unitPrice: double.tryParse(map['unit_price']?.toString() ?? '') ?? 0.0,
      totalCost: double.tryParse(map['total_cost']?.toString() ?? ''),
      dateOfAcquisition: DateTime.tryParse(map['date_of_acquisition']?.toString() ?? '') ?? DateTime.now(),
      modeOfAcquisition: map['mode_of_acquisition']?.toString() ?? 'Purchase',
      conditionStatus: map['condition_status']?.toString() ?? 'Good',
      operationalStatus: map['operational_status']?.toString() ?? 'Available',
      dimensions: map['dimensions']?.toString(),
      color: map['color']?.toString(),
      model: map['model']?.toString(),
      others: map['others']?.toString(),
      remarks: map['remarks']?.toString(),
      rfidTag: map['rfid_tag']?.toString(),
      photoBytes: decodedPhoto,
      photoFileName: map['photo_file_name']?.toString(),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? ''),
    );
  }

  String toJson() => jsonEncode(toMap());
  factory AssetDraftModel.fromJson(String source) => AssetDraftModel.fromMap(jsonDecode(source));
}