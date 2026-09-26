// =============================================================================
// FILE: lib/features/asset_inventory/models/asset_model.dart
// =============================================================================

import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';

class AssetModel {
  final String assetId;
  final String controlNumber;
  final String itemName;
  final String? classificationId;
  final String classificationAcronym;
  final String? classificationName;
  final String? locationId;
  final String locationAcronym;
  final String? locationName;
  final String? dimensions;
  final String? color;
  final String? model;
  final String? others;
  final String? remarks;
  final String? photoUrl;
  final DateTime dateOfAcquisition;
  final int acquisitionYear;
  final String modeOfAcquisition;
  final double cost;
  final String? rfidTag;
  final String qrCodeToken;
  final String conditionStatus; // 'VERIFIED / GOOD', 'REQUIRES REPAIR', 'DAMAGED', 'MISSING', 'UNUSABLE'
  final String operationalStatus; // 'Active', 'In Storage', 'Under Maintenance', 'Decommissioned'
  final bool isArchived;
  final DateTime? archivedAt;
  final String? archivedBy;
  final String? archiveReason;
  final DateTime? lastAuditedAt;
  final String? auditedBy;
  final String? createdBy;
  final DateTime registrationDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AssetModel({
    required this.assetId,
    required this.controlNumber,
    required this.itemName,
    this.classificationId,
    required this.classificationAcronym,
    this.classificationName,
    this.locationId,
    required this.locationAcronym,
    this.locationName,
    this.dimensions,
    this.color,
    this.model,
    this.others,
    this.remarks,
    this.photoUrl,
    required this.dateOfAcquisition,
    required this.acquisitionYear,
    this.modeOfAcquisition = 'Purchase',
    this.cost = 0.0,
    this.rfidTag,
    required this.qrCodeToken,
    this.conditionStatus = 'VERIFIED / GOOD',
    this.operationalStatus = 'Active',
    this.isArchived = false,
    this.archivedAt,
    this.archivedBy,
    this.archiveReason,
    this.lastAuditedAt,
    this.auditedBy,
    this.createdBy,
    required this.registrationDate,
    this.createdAt,
    this.updatedAt,
  });

  /// Human-readable date formatted as YYYY-MM-DD
  String get formattedAcquisitionDate {
    return '${dateOfAcquisition.year}-${dateOfAcquisition.month.toString().padLeft(2, '0')}-${dateOfAcquisition.day.toString().padLeft(2, '0')}';
  }

  /// Formatted registration date
  String get formattedRegistrationDate {
    return '${registrationDate.year}-${registrationDate.month.toString().padLeft(2, '0')}-${registrationDate.day.toString().padLeft(2, '0')}';
  }

  /// Formatted last audit date
  String get formattedLastAuditedDate {
    if (lastAuditedAt == null) return 'Never Audited';
    return '${lastAuditedAt!.year}-${lastAuditedAt!.month.toString().padLeft(2, '0')}-${lastAuditedAt!.day.toString().padLeft(2, '0')}';
  }

  /// Display string for location (combining name and acronym)
  String get displayLocation {
    if (locationName != null && locationName!.isNotEmpty) {
      return '$locationName ($locationAcronym)';
    }
    return locationAcronym;
  }

  /// Display string for classification (combining name and acronym)
  String get displayClassification {
    if (classificationName != null && classificationName!.isNotEmpty) {
      return '$classificationName ($classificationAcronym)';
    }
    return classificationAcronym;
  }

  /// Adaptive badge color based on condition status
  Color get conditionColor {
    final status = conditionStatus.toUpperCase();
    if (status.contains('GOOD') || status.contains('VERIFIED')) {
      return ParishColors.oliveGreen;
    } else if (status.contains('REPAIR') || status.contains('MAINTENANCE')) {
      return ParishColors.goldAccent;
    } else if (status.contains('DAMAGED') || status.contains('MISSING') || status.contains('UNUSABLE')) {
      return ParishColors.mercyRed;
    }
    return ParishColors.marianBlue;
  }

  /// Adaptive badge background surface color
  Color get conditionSurfaceColor {
    final status = conditionStatus.toUpperCase();
    if (status.contains('GOOD') || status.contains('VERIFIED')) {
      return ParishColors.oliveGreenSurface;
    } else if (status.contains('REPAIR') || status.contains('MAINTENANCE')) {
      return ParishColors.goldLight;
    } else if (status.contains('DAMAGED') || status.contains('MISSING') || status.contains('UNUSABLE')) {
      return ParishColors.mercyRedSurface;
    }
    return ParishColors.marianBlueSurface;
  }

  /// Icon based on classification acronym
  IconData get classificationIcon {
    switch (classificationAcronym.toUpperCase()) {
      case 'SI': // Sacred Image
        return Icons.person_pin;
      case 'SV': // Sacred Vessel
        return Icons.wine_bar;
      case 'MI': // Musical Instrument
        return Icons.piano;
      case 'LB': // Liturgical Book
        return Icons.menu_book;
      case 'FF': // Furniture and Fixtures
        return Icons.chair_outlined;
      case 'OE': // Office Equipment
        return Icons.computer;
      case 'EE': // Electrical Equipment
        return Icons.electrical_services;
      case 'HT': // Hand Tools
        return Icons.build;
      default:
        return Icons.inventory_2_outlined;
    }
  }

  factory AssetModel.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      return DateTime.tryParse(value.toString()) ?? DateTime.now();
    }

    DateTime? parseNullableDate(dynamic value) {
      if (value == null) return null;
      return DateTime.tryParse(value.toString());
    }

    final acqDate = parseDate(map['date_of_acquisition'] ?? map['acquisition_date']);
    final int acqYear = int.tryParse(map['acquisition_year']?.toString() ?? '') ?? acqDate.year;

    // Join resolution for classifications and locations if included in query
    String? classifName;
    if (map['asset_classifications'] is Map) {
      classifName = map['asset_classifications']['classification_name']?.toString();
    } else {
      classifName = map['category']?.toString();
    }

    String? locName;
    if (map['asset_locations'] is Map) {
      locName = map['asset_locations']['location_name']?.toString();
    } else {
      locName = map['storage_location']?.toString();
    }

    return AssetModel(
      assetId: map['asset_id']?.toString() ?? map['control_number']?.toString() ?? '',
      controlNumber: map['control_number']?.toString() ?? '',
      itemName: map['item_name']?.toString() ?? '',
      classificationId: map['classification_id']?.toString(),
      classificationAcronym: map['classification_acronym']?.toString() ?? 'FF',
      classificationName: classifName,
      locationId: map['location_id']?.toString(),
      locationAcronym: map['location_acronym']?.toString() ?? 'C',
      locationName: locName,
      dimensions: map['dimensions']?.toString(),
      color: map['color']?.toString(),
      model: map['model']?.toString(),
      others: map['others']?.toString(),
      remarks: map['remarks']?.toString(),
      photoUrl: map['photo_url']?.toString(),
      dateOfAcquisition: acqDate,
      acquisitionYear: acqYear,
      modeOfAcquisition: map['mode_of_acquisition']?.toString() ?? map['acquisition_mode']?.toString() ?? 'Purchase',
      cost: double.tryParse(map['cost']?.toString() ?? '0') ?? 0.0,
      rfidTag: map['rfid_tag']?.toString(),
      qrCodeToken: map['qr_code_token']?.toString() ?? map['control_number']?.toString() ?? '',
      conditionStatus: map['condition_status']?.toString() ?? 'VERIFIED / GOOD',
      operationalStatus: map['operational_status']?.toString() ?? 'Active',
      isArchived: map['is_archived'] == true,
      archivedAt: parseNullableDate(map['archived_at']),
      archivedBy: map['archived_by']?.toString(),
      archiveReason: map['archive_reason']?.toString(),
      lastAuditedAt: parseNullableDate(map['last_audited_at']),
      auditedBy: map['audited_by']?.toString(),
      createdBy: map['created_by']?.toString(),
      registrationDate: parseDate(map['registration_date'] ?? map['created_at']),
      createdAt: parseNullableDate(map['created_at']),
      updatedAt: parseNullableDate(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'asset_id': assetId,
      'control_number': controlNumber,
      'item_name': itemName.trim(),
      'classification_id': classificationId,
      'classification_acronym': classificationAcronym.trim().toUpperCase(),
      'location_id': locationId,
      'location_acronym': locationAcronym.trim().toUpperCase(),
      'dimensions': dimensions?.trim().isEmpty ?? true ? null : dimensions!.trim(),
      'color': color?.trim().isEmpty ?? true ? null : color!.trim(),
      'model': model?.trim().isEmpty ?? true ? null : model!.trim(),
      'others': others?.trim().isEmpty ?? true ? null : others!.trim(),
      'remarks': remarks?.trim().isEmpty ?? true ? null : remarks!.trim(),
      'photo_url': photoUrl?.trim().isEmpty ?? true ? null : photoUrl!.trim(),
      'date_of_acquisition': formattedAcquisitionDate,
      'acquisition_year': acquisitionYear,
      'mode_of_acquisition': modeOfAcquisition,
      'cost': cost,
      'rfid_tag': rfidTag?.trim().isEmpty ?? true ? null : rfidTag!.trim(),
      'qr_code_token': qrCodeToken,
      'condition_status': conditionStatus,
      'operational_status': operationalStatus,
      'is_archived': isArchived,
      'archived_at': archivedAt?.toIso8601String(),
      'archived_by': archivedBy,
      'archive_reason': archiveReason,
      'last_audited_at': lastAuditedAt?.toIso8601String(),
      'audited_by': auditedBy,
      'created_by': createdBy,
      'registration_date': registrationDate.toIso8601String(),
      // Legacy column compatibility
      'category': classificationName ?? classificationAcronym,
      'storage_location': locationName ?? locationAcronym,
      'acquisition_date': formattedAcquisitionDate,
      'acquisition_mode': modeOfAcquisition,
      'description': remarks ?? others ?? itemName,
    };
  }

  AssetModel copyWith({
    String? assetId,
    String? controlNumber,
    String? itemName,
    String? classificationId,
    String? classificationAcronym,
    String? classificationName,
    String? locationId,
    String? locationAcronym,
    String? locationName,
    String? dimensions,
    String? color,
    String? model,
    String? others,
    String? remarks,
    String? photoUrl,
    DateTime? dateOfAcquisition,
    int? acquisitionYear,
    String? modeOfAcquisition,
    double? cost,
    String? rfidTag,
    String? qrCodeToken,
    String? conditionStatus,
    String? operationalStatus,
    bool? isArchived,
    DateTime? archivedAt,
    String? archivedBy,
    String? archiveReason,
    DateTime? lastAuditedAt,
    String? auditedBy,
    String? createdBy,
    DateTime? registrationDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AssetModel(
      assetId: assetId ?? this.assetId,
      controlNumber: controlNumber ?? this.controlNumber,
      itemName: itemName ?? this.itemName,
      classificationId: classificationId ?? this.classificationId,
      classificationAcronym: classificationAcronym ?? this.classificationAcronym,
      classificationName: classificationName ?? this.classificationName,
      locationId: locationId ?? this.locationId,
      locationAcronym: locationAcronym ?? this.locationAcronym,
      locationName: locationName ?? this.locationName,
      dimensions: dimensions ?? this.dimensions,
      color: color ?? this.color,
      model: model ?? this.model,
      others: others ?? this.others,
      remarks: remarks ?? this.remarks,
      photoUrl: photoUrl ?? this.photoUrl,
      dateOfAcquisition: dateOfAcquisition ?? this.dateOfAcquisition,
      acquisitionYear: acquisitionYear ?? this.acquisitionYear,
      modeOfAcquisition: modeOfAcquisition ?? this.modeOfAcquisition,
      cost: cost ?? this.cost,
      rfidTag: rfidTag ?? this.rfidTag,
      qrCodeToken: qrCodeToken ?? this.qrCodeToken,
      conditionStatus: conditionStatus ?? this.conditionStatus,
      operationalStatus: operationalStatus ?? this.operationalStatus,
      isArchived: isArchived ?? this.isArchived,
      archivedAt: archivedAt ?? this.archivedAt,
      archivedBy: archivedBy ?? this.archivedBy,
      archiveReason: archiveReason ?? this.archiveReason,
      lastAuditedAt: lastAuditedAt ?? this.lastAuditedAt,
      auditedBy: auditedBy ?? this.auditedBy,
      createdBy: createdBy ?? this.createdBy,
      registrationDate: registrationDate ?? this.registrationDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}