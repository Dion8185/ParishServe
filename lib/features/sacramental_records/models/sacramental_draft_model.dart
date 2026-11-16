// =============================================================================
// FILE: lib/features/sacramental_records/models/sacramental_draft_model.dart
// =============================================================================

import 'dart:convert';

class SacramentalDraftModel {
  final String draftId;
  final String sacramentType;
  final String displayTitle;
  final String? bookReference;
  final Map<String, dynamic> draftData;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SacramentalDraftModel({
    required this.draftId,
    required this.sacramentType,
    required this.displayTitle,
    this.bookReference,
    required this.draftData,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SacramentalDraftModel.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic> parsedData = {};
    final rawData = map['draft_data'];
    if (rawData is Map<String, dynamic>) {
      parsedData = Map<String, dynamic>.from(rawData);
    } else if (rawData is Map) {
      parsedData = Map<String, dynamic>.from(rawData);
    } else if (rawData is String && rawData.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawData);
        if (decoded is Map) {
          parsedData = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }

    final rawTitle = map['display_title']?.toString().trim();
    final effectiveTitle =
    (rawTitle != null && rawTitle.isNotEmpty) ? rawTitle : 'Untitled Draft';

    return SacramentalDraftModel(
      draftId: map['draft_id']?.toString() ?? '',
      sacramentType: map['sacrament_type']?.toString() ?? 'Baptism',
      displayTitle: effectiveTitle,
      bookReference: map['book_reference']?.toString(),
      draftData: parsedData,
      createdBy: map['created_by']?.toString(),
      createdAt:
      DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt:
      DateTime.tryParse(map['updated_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'draft_id': draftId,
      'sacrament_type': sacramentType,
      'display_title': displayTitle,
      'book_reference': bookReference,
      'draft_data': draftData,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toSqliteMap() {
    return {
      'draft_id': draftId,
      'sacrament_type': sacramentType,
      'display_title': displayTitle,
      'book_reference': bookReference,
      'draft_data': jsonEncode(draftData),
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}