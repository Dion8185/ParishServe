// =============================================================================
// FILE: lib/features/asset_inventory/models/asset_reference_models.dart
// =============================================================================

import 'package:flutter/material.dart';

/// Model representing a Diocesan Location reference entry
class AssetLocationModel {
  final String locationId;
  final String acronym;
  final String locationName;
  final String? description;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AssetLocationModel({
    required this.locationId,
    required this.acronym,
    required this.locationName,
    this.description,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  String get displayName => '$locationName ($acronym)';

  factory AssetLocationModel.fromMap(Map<String, dynamic> map) {
    return AssetLocationModel(
      locationId: map['location_id']?.toString() ?? '',
      acronym: map['acronym']?.toString().toUpperCase() ?? '',
      locationName: map['location_name']?.toString() ?? '',
      description: map['description']?.toString(),
      isActive: map['is_active'] ?? true,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'location_id': locationId,
      'acronym': acronym.trim().toUpperCase(),
      'location_name': locationName.trim(),
      'description': description?.trim().isEmpty ?? true ? null : description!.trim(),
      'is_active': isActive,
    };
  }

  AssetLocationModel copyWith({
    String? locationId,
    String? acronym,
    String? locationName,
    String? description,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AssetLocationModel(
      locationId: locationId ?? this.locationId,
      acronym: acronym ?? this.acronym,
      locationName: locationName ?? this.locationName,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Model representing a Diocesan Asset Classification reference entry
class AssetClassificationModel {
  final String classificationId;
  final String acronym;
  final String classificationName;
  final String? description;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AssetClassificationModel({
    required this.classificationId,
    required this.acronym,
    required this.classificationName,
    this.description,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  String get displayName => '$classificationName ($acronym)';

  IconData get icon {
    switch (acronym.toUpperCase()) {
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

  factory AssetClassificationModel.fromMap(Map<String, dynamic> map) {
    return AssetClassificationModel(
      classificationId: map['classification_id']?.toString() ?? '',
      acronym: map['acronym']?.toString().toUpperCase() ?? '',
      classificationName: map['classification_name']?.toString() ?? '',
      description: map['description']?.toString(),
      isActive: map['is_active'] ?? true,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'classification_id': classificationId,
      'acronym': acronym.trim().toUpperCase(),
      'classification_name': classificationName.trim(),
      'description': description?.trim().isEmpty ?? true ? null : description!.trim(),
      'is_active': isActive,
    };
  }

  AssetClassificationModel copyWith({
    String? classificationId,
    String? acronym,
    String? classificationName,
    String? description,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AssetClassificationModel(
      classificationId: classificationId ?? this.classificationId,
      acronym: acronym ?? this.acronym,
      classificationName: classificationName ?? this.classificationName,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}