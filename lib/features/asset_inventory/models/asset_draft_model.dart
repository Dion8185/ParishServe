// =============================================================================
// FILE: lib/features/asset_inventory/models/asset_draft_model.dart
// =============================================================================

import 'dart:typed_data';
import 'asset_model.dart';

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
  final String? photoUrl;
  final Uint8List? localPhotoBytes;
  final String? photoFileName;
  final String? createdBy;
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
    this.operationalStatus = 'In Storage',
    this.dimensions,
    this.color,
    this.model,
    this.others,
    this.remarks,
    this.rfidTag,
    this.photoUrl,
    this.localPhotoBytes,
    this.photoFileName,
    this.createdBy,
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
    if ((photoUrl == null || photoUrl!.trim().isEmpty) &&
        (localPhotoBytes == null || localPhotoBytes!.isEmpty)) {
      missing.add('Photograph');
    }
    if (unitPrice <= 0) missing.add('Acquisition Cost');
    if (dimensions == null || dimensions!.trim().isEmpty) missing.add('Dimensions');
    return missing;
  }

  bool get isReadyToRegister => missingChecklist.isEmpty;

  Map<String, dynamic> toMap() {
    return {
      'draft_id': draftId,
      'item_name': itemName.trim().isEmpty ? null : itemName.trim(),
      'location_id': locationId,
      'location_acronym': locationAcronym.trim().toUpperCase(),
      'location_name': locationName,
      'classification_id': classificationId,
      'classification_acronym': classificationAcronym.trim().toUpperCase(),
      'classification_name': classificationName,
      'sequence_number': sequenceNumber.trim().isEmpty ? '001' : sequenceNumber.trim(),
      'quantity': quantity > 0 ? quantity : 1,
      'unit_price': unitPrice >= 0.0 ? unitPrice : 0.0,
      'total_cost': totalCost >= 0.0 ? totalCost : (quantity * unitPrice),
      'date_of_acquisition': formattedAcquisitionDate,
      'mode_of_acquisition': modeOfAcquisition,
      'condition_status': conditionStatus,
      'operational_status': operationalStatus,
      'dimensions': dimensions?.trim().isEmpty ?? true ? null : dimensions!.trim(),
      'color': color?.trim().isEmpty ?? true ? null : color!.trim(),
      'model': model?.trim().isEmpty ?? true ? null : model!.trim(),
      'others': others?.trim().isEmpty ?? true ? null : others!.trim(),
      'remarks': remarks?.trim().isEmpty ?? true ? null : remarks!.trim(),
      'rfid_tag': rfidTag?.trim().isEmpty ?? true ? null : rfidTag!.trim(),
      'photo_url': photoUrl?.trim().isEmpty ?? true ? null : photoUrl!.trim(),
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory AssetDraftModel.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      return DateTime.tryParse(value.toString()) ?? DateTime.now();
    }

    final acqDate = parseDate(map['date_of_acquisition']);
    final int qty = int.tryParse(map['quantity']?.toString() ?? '') ?? 1;
    final double uPrice = double.tryParse(map['unit_price']?.toString() ?? '') ?? 0.0;
    final double totCost = double.tryParse(map['total_cost']?.toString() ?? '') ?? (qty * uPrice);

    final rawStatus = map['operational_status']?.toString() ?? map['status']?.toString();

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
      quantity: qty,
      unitPrice: uPrice,
      totalCost: totCost,
      dateOfAcquisition: acqDate,
      modeOfAcquisition: map['mode_of_acquisition']?.toString() ?? 'Purchase',
      conditionStatus: map['condition_status']?.toString() ?? 'Good',
      operationalStatus: AssetModel.normalizeStatus(rawStatus),
      dimensions: map['dimensions']?.toString(),
      color: map['color']?.toString(),
      model: map['model']?.toString(),
      others: map['others']?.toString(),
      remarks: map['remarks']?.toString(),
      rfidTag: map['rfid_tag']?.toString(),
      photoUrl: map['photo_url']?.toString(),
      createdBy: map['created_by']?.toString(),
      createdAt: parseDate(map['created_at']),
      updatedAt: parseDate(map['updated_at']),
    );
  }

  AssetDraftModel copyWith({
    String? draftId,
    String? itemName,
    String? locationId,
    String? locationAcronym,
    String? locationName,
    String? classificationId,
    String? classificationAcronym,
    String? classificationName,
    String? sequenceNumber,
    int? quantity,
    double? unitPrice,
    double? totalCost,
    DateTime? dateOfAcquisition,
    String? modeOfAcquisition,
    String? conditionStatus,
    String? operationalStatus,
    String? dimensions,
    String? color,
    String? model,
    String? others,
    String? remarks,
    String? rfidTag,
    String? photoUrl,
    Uint8List? localPhotoBytes,
    String? photoFileName,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final newQty = quantity ?? this.quantity;
    final newUnitPrice = unitPrice ?? this.unitPrice;
    final newTotalCost = totalCost ?? (newQty * newUnitPrice);

    return AssetDraftModel(
      draftId: draftId ?? this.draftId,
      itemName: itemName ?? this.itemName,
      locationId: locationId ?? this.locationId,
      locationAcronym: locationAcronym ?? this.locationAcronym,
      locationName: locationName ?? this.locationName,
      classificationId: classificationId ?? this.classificationId,
      classificationAcronym: classificationAcronym ?? this.classificationAcronym,
      classificationName: classificationName ?? this.classificationName,
      sequenceNumber: sequenceNumber ?? this.sequenceNumber,
      quantity: newQty,
      unitPrice: newUnitPrice,
      totalCost: newTotalCost,
      dateOfAcquisition: dateOfAcquisition ?? this.dateOfAcquisition,
      modeOfAcquisition: modeOfAcquisition ?? this.modeOfAcquisition,
      conditionStatus: conditionStatus ?? this.conditionStatus,
      operationalStatus: operationalStatus ?? this.operationalStatus,
      dimensions: dimensions ?? this.dimensions,
      color: color ?? this.color,
      model: model ?? this.model,
      others: others ?? this.others,
      remarks: remarks ?? this.remarks,
      rfidTag: rfidTag ?? this.rfidTag,
      photoUrl: photoUrl ?? this.photoUrl,
      localPhotoBytes: localPhotoBytes ?? this.localPhotoBytes,
      photoFileName: photoFileName ?? this.photoFileName,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
