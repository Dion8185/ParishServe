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
  final DateTime? dateOfAcquisition; // Nullable: allows recording year only
  final int acquisitionYear;
  final String modeOfAcquisition;

  // Pricing & Quantity structure
  final int quantity;
  final double unitPrice;
  final double totalCost;

  final String qrCodeToken;

  /// Standardized Physical Condition:
  /// 'Excellent', 'Good', 'Fair', 'Poor', 'Damaged'
  final String conditionStatus;

  /// Standardized Availability:
  /// 'In Used', 'In Storage', 'Disposed'
  final String operationalStatus;

  final bool isArchived;
  final DateTime? archivedAt;
  final String? archivedBy;
  final String? archiveReason;

  final String? bulkBatchId;
  final int? itemSequenceInBatch;

  final DateTime? lastAuditedAt;
  final String? auditedBy;
  final String? createdBy;
  final DateTime registrationDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // ===========================================================================
  // Standard Constants & Canonical Lists
  // ===========================================================================

  static const List<String> standardConditions = [
    'Excellent',
    'Good',
    'Fair',
    'Poor',
    'Damaged',
  ];

  static const Map<String, String> conditionDescriptions = {
    'Excellent': 'Almost like new, no noticeable wear',
    'Good': 'Functional with minimal normal wear',
    'Fair': 'Functional with noticeable wear',
    'Poor': 'Functional but requires attention or repair',
    'Damaged': 'Physical damage or unserviceable',
  };

  /// Canonical Availability options across the entire system
  static const List<String> standardAvailability = [
    'In Used',
    'In Storage',
    'Disposed',
  ];

  static const Map<String, String> availabilityDescriptions = {
    'In Used': 'Currently deployed and actively utilized',
    'In Storage': 'Kept in storage, sacristy, or reserve stock',
    'Disposed': 'Officially decommissioned, retired, or disposed',
  };

  static const List<String> standardStatuses = standardAvailability;
  static const Map<String, String> statusDescriptions = availabilityDescriptions;

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
    this.dateOfAcquisition,
    required this.acquisitionYear,
    this.modeOfAcquisition = 'Purchase',
    this.quantity = 1,
    this.unitPrice = 0.0,
    double? totalCost,
    required this.qrCodeToken,
    this.conditionStatus = 'Good',
    this.operationalStatus = 'In Storage',
    this.isArchived = false,
    this.archivedAt,
    this.archivedBy,
    this.archiveReason,
    this.bulkBatchId,
    this.itemSequenceInBatch,
    this.lastAuditedAt,
    this.auditedBy,
    this.createdBy,
    required this.registrationDate,
    this.createdAt,
    this.updatedAt,
  }) : totalCost = totalCost ?? (quantity * unitPrice);

  static String normalizeCondition(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'Good';
    final clean = raw.trim();

    for (final cond in standardConditions) {
      if (cond.toLowerCase() == clean.toLowerCase()) return cond;
    }

    final upper = clean.toUpperCase();
    if (upper.contains('EXCELLENT') || upper.contains('NEW')) return 'Excellent';
    if (upper.contains('GOOD') || upper.contains('VERIFIED')) return 'Good';
    if (upper.contains('FAIR')) return 'Fair';
    if (upper.contains('POOR') || upper.contains('REPAIR')) return 'Poor';
    if (upper.contains('DAMAGED') || upper.contains('UNSERVICEABLE') || upper.contains('UNUSABLE')) {
      return 'Damaged';
    }
    return 'Good';
  }

  static String normalizeStatus(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'In Storage';
    final clean = raw.trim();

    for (final st in standardAvailability) {
      if (st.toLowerCase() == clean.toLowerCase()) return st;
    }

    final lower = clean.toLowerCase();
    if (lower == 'in use' || lower == 'in used' || lower == 'active' || lower == 'deployed' || lower.contains('use')) {
      return 'In Used';
    }
    if (lower.contains('storage') || lower.contains('available') || lower.contains('reserved') || lower.contains('bodega') || lower.contains('sacristy')) {
      return 'In Storage';
    }
    if (lower.contains('disposed') || lower.contains('decommissioned') || lower.contains('retired') || lower.contains('condemned') || lower.contains('lost') || lower.contains('missing')) {
      return 'Disposed';
    }
    return 'In Storage';
  }

  /// Returns YYYY-MM-DD if full date is known, or just YYYY if month & day were optional.
  /// Never forces January 1!
  String get formattedAcquisitionDate {
    if (dateOfAcquisition == null) {
      return '$acquisitionYear';
    }
    return '${dateOfAcquisition!.year}-${dateOfAcquisition!.month.toString().padLeft(2, '0')}-${dateOfAcquisition!.day.toString().padLeft(2, '0')}';
  }

  String get formattedRegistrationDate {
    return '${registrationDate.year}-${registrationDate.month.toString().padLeft(2, '0')}-${registrationDate.day.toString().padLeft(2, '0')}';
  }

  String get formattedLastAuditedDate {
    if (lastAuditedAt == null) return 'Never Audited';
    return '${lastAuditedAt!.year}-${lastAuditedAt!.month.toString().padLeft(2, '0')}-${lastAuditedAt!.day.toString().padLeft(2, '0')}';
  }

  String get formattedUnitPrice => '₱ ${formatCurrency(unitPrice)}';
  String get formattedTotalCost => '₱ ${formatCurrency(totalCost)}';

  static String formatCurrency(double amount) {
    final parts = amount.toStringAsFixed(2).split('.');
    final integerPart = parts[0];
    final decimalPart = parts[1];

    final buffer = StringBuffer();
    for (int i = 0; i < integerPart.length; i++) {
      if (i > 0 && (integerPart.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(integerPart[i]);
    }
    return '${buffer.toString()}.$decimalPart';
  }

  String get inventorySection {
    if (unitPrice >= 10000.0) {
      return 'Section 1 — ₱10,000.00 and Above';
    } else {
      return 'Section 2 — Below ₱10,000.00';
    }
  }

  String get inventorySectionCode {
    return unitPrice >= 10000.0 ? 'Section 1' : 'Section 2';
  }

  bool get isEffectivelyArchived {
    if (isArchived) return true;
    final st = normalizeStatus(operationalStatus);
    return st == 'Disposed';
  }

  String get displayLocation {
    if (locationName != null && locationName!.isNotEmpty) {
      return '$locationName ($locationAcronym)';
    }
    return locationAcronym;
  }

  String get displayClassification {
    if (classificationName != null && classificationName!.isNotEmpty) {
      return '$classificationName ($classificationAcronym)';
    }
    return classificationAcronym;
  }

  Color get conditionColor {
    final normalized = normalizeCondition(conditionStatus);
    switch (normalized) {
      case 'Excellent':
        return const Color(0xFF0D9488);
      case 'Good':
        return ParishColors.oliveGreen;
      case 'Fair':
        return ParishColors.goldAccent;
      case 'Poor':
        return const Color(0xFFEA580C);
      case 'Damaged':
        return ParishColors.mercyRed;
      default:
        return const Color(0xFF64748B);
    }
  }

  Color get conditionSurfaceColor {
    final normalized = normalizeCondition(conditionStatus);
    switch (normalized) {
      case 'Excellent':
        return const Color(0xFFCCFBF1);
      case 'Good':
        return ParishColors.oliveGreenSurface;
      case 'Fair':
        return ParishColors.goldLight;
      case 'Poor':
        return const Color(0xFFFFEDD5);
      case 'Damaged':
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  Color get statusColor {
    final normalized = normalizeStatus(operationalStatus);
    switch (normalized) {
      case 'In Used':
        return ParishColors.marianBlue;
      case 'In Storage':
        return ParishColors.oliveGreen;
      case 'Disposed':
      default:
        return ParishColors.mercyRed;
    }
  }

  Color get statusSurfaceColor {
    final normalized = normalizeStatus(operationalStatus);
    switch (normalized) {
      case 'In Used':
        return ParishColors.marianBlueSurface;
      case 'In Storage':
        return ParishColors.oliveGreenSurface;
      case 'Disposed':
      default:
        return ParishColors.mercyRedSurface;
    }
  }

  IconData get classificationIcon {
    switch (classificationAcronym.toUpperCase()) {
      case 'SI':
        return Icons.person_pin;
      case 'SV':
        return Icons.wine_bar;
      case 'MI':
        return Icons.piano;
      case 'LB':
        return Icons.menu_book;
      case 'FF':
        return Icons.chair_outlined;
      case 'OE':
        return Icons.computer;
      case 'EE':
        return Icons.electrical_services;
      case 'HT':
        return Icons.build;
      default:
        return Icons.inventory_2_outlined;
    }
  }

  factory AssetModel.fromMap(
      Map<String, dynamic> map, {
        List<AssetModel> children = const [],
      }) {
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      return DateTime.tryParse(value.toString()) ?? DateTime.now();
    }

    DateTime? parseNullableDate(dynamic value) {
      if (value == null) return null;
      return DateTime.tryParse(value.toString());
    }

    final acqDate = parseNullableDate(map['date_of_acquisition'] ?? map['acquisition_date']);
    final int acqYear = int.tryParse(map['acquisition_year']?.toString() ?? '') ??
        (acqDate?.year ?? DateTime.now().year);

    String? classifName;
    if (map['asset_classifications'] is Map) {
      classifName =
          map['asset_classifications']['classification_name']?.toString();
    } else {
      classifName = map['category']?.toString();
    }

    String? locName;
    if (map['asset_locations'] is Map) {
      locName = map['asset_locations']['location_name']?.toString();
    } else {
      locName = map['storage_location']?.toString();
    }

    final int qty = int.tryParse(map['quantity']?.toString() ?? '') ?? 1;
    final double rawCost =
        double.tryParse(map['cost']?.toString() ?? '') ?? 0.0;
    final double uPrice = double.tryParse(
      map['unit_price']?.toString() ?? '',
    ) ??
        (rawCost > 0 ? (rawCost / (qty > 0 ? qty : 1)) : 0.0);
    final double totCost = double.tryParse(
      map['total_cost']?.toString() ?? '',
    ) ??
        (rawCost > 0 ? rawCost : (qty * uPrice));

    final rawCondition = map['condition_status']?.toString();
    final rawStatus = map['operational_status']?.toString() ??
        map['status']?.toString() ??
        'In Storage';

    return AssetModel(
      assetId: map['asset_id']?.toString() ??
          map['control_number']?.toString() ??
          '',
      controlNumber: map['control_number']?.toString() ?? '',
      itemName: map['item_name']?.toString() ?? '',
      classificationId: map['classification_id']?.toString(),
      classificationAcronym:
      map['classification_acronym']?.toString() ?? 'FF',
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
      modeOfAcquisition: map['mode_of_acquisition']?.toString() ??
          map['acquisition_mode']?.toString() ??
          'Purchase',
      quantity: qty > 0 ? qty : 1,
      unitPrice: uPrice >= 0 ? uPrice : 0.0,
      totalCost: totCost >= 0 ? totCost : 0.0,
      qrCodeToken: map['qr_code_token']?.toString() ??
          map['control_number']?.toString() ??
          '',
      conditionStatus: normalizeCondition(rawCondition),
      operationalStatus: normalizeStatus(rawStatus),
      isArchived: map['is_archived'] == true,
      archivedAt: parseNullableDate(map['archived_at']),
      archivedBy: map['archived_by']?.toString(),
      archiveReason: map['archive_reason']?.toString(),
      bulkBatchId: map['bulk_batch_id']?.toString(),
      itemSequenceInBatch:
      int.tryParse(map['item_sequence_in_batch']?.toString() ?? ''),
      lastAuditedAt: parseNullableDate(map['last_audited_at']),
      auditedBy: map['audited_by']?.toString(),
      createdBy: map['created_by']?.toString(),
      registrationDate:
      parseDate(map['registration_date'] ?? map['created_at']),
      createdAt: parseNullableDate(map['created_at']),
      updatedAt: parseNullableDate(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    final String? dateString = dateOfAcquisition != null
        ? '${dateOfAcquisition!.year}-${dateOfAcquisition!.month.toString().padLeft(2, '0')}-${dateOfAcquisition!.day.toString().padLeft(2, '0')}'
        : null;

    return {
      'asset_id': assetId,
      'control_number': controlNumber,
      'item_name': itemName.trim(),
      'classification_id': classificationId,
      'classification_acronym': classificationAcronym.trim().toUpperCase(),
      'location_id': locationId,
      'location_acronym': locationAcronym.trim().toUpperCase(),
      'dimensions':
      dimensions?.trim().isEmpty ?? true ? null : dimensions!.trim(),
      'color': color?.trim().isEmpty ?? true ? null : color!.trim(),
      'model': model?.trim().isEmpty ?? true ? null : model!.trim(),
      'others': others?.trim().isEmpty ?? true ? null : others!.trim(),
      'remarks': remarks?.trim().isEmpty ?? true ? null : remarks!.trim(),
      'photo_url': photoUrl?.trim().isEmpty ?? true ? null : photoUrl!.trim(),
      'date_of_acquisition': dateString,
      'acquisition_year': acquisitionYear,
      'mode_of_acquisition': modeOfAcquisition,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_cost': totalCost,
      'cost': totalCost,
      'qr_code_token': qrCodeToken,
      'condition_status': conditionStatus,
      'operational_status': operationalStatus,
      'is_archived': isArchived,
      'archived_at': archivedAt?.toIso8601String(),
      'archived_by': archivedBy,
      'archive_reason': archiveReason,
      'bulk_batch_id': bulkBatchId,
      'item_sequence_in_batch': itemSequenceInBatch,
      'last_audited_at': lastAuditedAt?.toIso8601String(),
      'audited_by': auditedBy,
      'created_by': createdBy,
      'registration_date': registrationDate.toIso8601String(),
      'category': classificationName ?? classificationAcronym,
      'storage_location': locationName ?? locationAcronym,
      'acquisition_date': dateString,
      'acquisition_mode': modeOfAcquisition,
      'description': remarks ?? others ?? itemName,
    };
  }
}