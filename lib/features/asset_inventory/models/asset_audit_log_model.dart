// =============================================================================
// FILE: lib/features/asset_inventory/models/asset_audit_log_model.dart
// =============================================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Represents a classified batch of units under a single quantified asset
class AssetQuantityDistribution {
  final String utilizationStatus; // 'In Used', 'In Storage', 'Disposed'
  final String physicalCondition; // 'Excellent', 'Good', 'Fair', 'Poor', 'Damaged'
  final int quantity;

  const AssetQuantityDistribution({
    required this.utilizationStatus,
    required this.physicalCondition,
    required this.quantity,
  });

  static const List<String> standardUtilizationStatuses = [
    'In Used',
    'In Storage',
    'Disposed',
  ];

  static const List<String> standardPhysicalConditions = [
    'Excellent',
    'Good',
    'Fair',
    'Poor',
    'Damaged',
  ];

  Map<String, dynamic> toMap() {
    return {
      'status': utilizationStatus,
      'condition': physicalCondition,
      'quantity': quantity,
    };
  }

  factory AssetQuantityDistribution.fromMap(Map<String, dynamic> map) {
    final rawStatus = map['status']?.toString() ?? 'In Used';
    String normStatus = 'In Used';
    final lower = rawStatus.toLowerCase();
    if (lower.contains('storage') || lower.contains('available') || lower.contains('reserved')) {
      normStatus = 'In Storage';
    } else if (lower.contains('disposed') || lower.contains('decommissioned')) {
      normStatus = 'Disposed';
    } else if (lower.contains('use') || lower == 'active') {
      normStatus = 'In Used';
    }

    return AssetQuantityDistribution(
      utilizationStatus: normStatus,
      physicalCondition: map['condition']?.toString() ?? 'Good',
      quantity: int.tryParse(map['quantity']?.toString() ?? '') ?? 1,
    );
  }

  String get summary => '$quantity $utilizationStatus ($physicalCondition)';
}

class AssetAuditLogModel {
  final String auditId;
  final String assetId;
  final String controlNumber;
  final String? auditedBy;
  final String? auditorName;
  final String? previousCondition;
  final String newCondition;
  final String? previousStatus;
  final String? newStatus;
  final String? previousLocation;
  final String? newLocation;
  final String auditMethod; // 'QR_SCAN', 'MANUAL'
  final String? auditNotes;
  final DateTime auditedAt;

  // Quantity Tracking and Adjustment History
  final int? previousQuantity;
  final int? newQuantity;
  final int? quantityChange;
  final String? quantityChangeReason;

  // Quantified Asset Condition & Utilization Distribution
  final List<AssetQuantityDistribution>? quantityDistribution;

  const AssetAuditLogModel({
    required this.auditId,
    required this.assetId,
    required this.controlNumber,
    this.auditedBy,
    this.auditorName,
    this.previousCondition,
    required this.newCondition,
    this.previousStatus,
    this.newStatus,
    this.previousLocation,
    this.newLocation,
    this.auditMethod = 'QR_SCAN',
    this.auditNotes,
    required this.auditedAt,
    this.previousQuantity,
    this.newQuantity,
    this.quantityChange,
    this.quantityChangeReason,
    this.quantityDistribution,
  });

  bool get hasQuantityAdjustment =>
      quantityChange != null && quantityChange != 0;

  bool get hasQuantityDistribution =>
      quantityDistribution != null && quantityDistribution!.isNotEmpty;

  String get formattedQuantityChange {
    if (!hasQuantityAdjustment) return 'No quantity change';
    final sign =
    quantityChange! > 0 ? '+${quantityChange!}' : '${quantityChange!}';
    return '$sign units (from $previousQuantity to $nextQty)';
  }

  int? get nextQty => newQuantity;

  /// Formatted breakdown summary for audit log tiles
  String get formattedDistributionSummary {
    if (!hasQuantityDistribution) return '';
    return quantityDistribution!
        .map((d) => '${d.quantity}x ${d.utilizationStatus} (${d.physicalCondition})')
        .join(', ');
  }

  /// Clean user notes without the automated metadata headers
  String get cleanNotes {
    if (auditNotes == null) return '';
    String notes = auditNotes!;

    // 1. Clean QTY_ADJUST header
    notes = notes.replaceAll(RegExp(r'\[QTY_ADJUST:.*?\]\n?'), '');

    // 2. Clean QTY_DISTRIBUTION header handling nested JSON array brackets
    const prefix = '[QTY_DISTRIBUTION:';
    while (notes.contains(prefix)) {
      final startIndex = notes.indexOf(prefix);
      final jsonStart = notes.indexOf('[', startIndex + prefix.length);

      if (jsonStart != -1) {
        int depth = 0;
        int jsonEnd = -1;
        for (int i = jsonStart; i < notes.length; i++) {
          if (notes[i] == '[') depth++;
          if (notes[i] == ']') {
            depth--;
            if (depth == 0) {
              jsonEnd = i;
              break;
            }
          }
        }

        if (jsonEnd != -1) {
          final outerEnd = notes.indexOf(']', jsonEnd + 1);
          final endOfTag = outerEnd != -1 ? outerEnd + 1 : jsonEnd + 1;
          notes = notes.substring(0, startIndex) + notes.substring(endOfTag);
        } else {
          notes = notes.replaceFirst(RegExp(r'\[QTY_DISTRIBUTION:.*?\]\n?'), '');
        }
      } else {
        notes = notes.replaceFirst(RegExp(r'\[QTY_DISTRIBUTION:.*?\]\n?'), '');
      }
    }

    return notes.trim();
  }

  String get formattedAuditedAt {
    return '${auditedAt.year}-${auditedAt.month.toString().padLeft(2, '0')}-${auditedAt.day.toString().padLeft(2, '0')} '
        '${auditedAt.hour.toString().padLeft(2, '0')}:${auditedAt.minute.toString().padLeft(2, '0')}';
  }

  factory AssetAuditLogModel.fromMap(Map<String, dynamic> map) {
    String? auditor;
    if (map['users'] is Map) {
      final u = map['users'];
      auditor = '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim();
    }

    final rawNotes = map['audit_notes']?.toString();

    // 1. Parse automated quantity adjustment metadata from audit notes
    int? prevQty;
    int? nextQty;
    int? changeQty;
    String? reasonQty;

    if (rawNotes != null && rawNotes.contains('[QTY_ADJUST:')) {
      final match = RegExp(
        r'\[QTY_ADJUST: from (\d+) to (\d+) \(([+-]?\d+)\) \| REASON: (.*?)\]',
      ).firstMatch(rawNotes);

      if (match != null) {
        prevQty = int.tryParse(match.group(1) ?? '');
        nextQty = int.tryParse(match.group(2) ?? '');
        changeQty = int.tryParse(match.group(3) ?? '');
        reasonQty = match.group(4)?.trim();
      }
    }

    // 2. Parse quantity-based distribution breakdown using bracket depth matching
    List<AssetQuantityDistribution>? parsedDistribution;
    if (rawNotes != null && rawNotes.contains('[QTY_DISTRIBUTION:')) {
      try {
        const prefix = '[QTY_DISTRIBUTION:';
        final startIndex = rawNotes.indexOf(prefix);
        final jsonStart = rawNotes.indexOf('[', startIndex + prefix.length);

        if (jsonStart != -1) {
          int depth = 0;
          int jsonEnd = -1;
          for (int i = jsonStart; i < rawNotes.length; i++) {
            if (rawNotes[i] == '[') depth++;
            if (rawNotes[i] == ']') {
              depth--;
              if (depth == 0) {
                jsonEnd = i;
                break;
              }
            }
          }

          if (jsonEnd != -1) {
            final jsonStr = rawNotes.substring(jsonStart, jsonEnd + 1);
            final List<dynamic> list = jsonDecode(jsonStr);
            parsedDistribution = list
                .map((item) => AssetQuantityDistribution.fromMap(
                item as Map<String, dynamic>))
                .toList();
          }
        }
      } catch (e) {
        debugPrint('Notice parsing quantity distribution: $e');
      }
    }

    return AssetAuditLogModel(
      auditId: map['audit_id']?.toString() ?? '',
      assetId: map['asset_id']?.toString() ?? '',
      controlNumber: map['control_number']?.toString() ?? '',
      auditedBy: map['audited_by']?.toString(),
      auditorName: auditor,
      previousCondition: map['previous_condition']?.toString(),
      newCondition: map['new_condition']?.toString() ?? 'VERIFIED / GOOD',
      previousStatus: map['previous_status']?.toString(),
      newStatus: map['new_status']?.toString(),
      previousLocation: map['previous_location']?.toString(),
      newLocation: map['new_location']?.toString(),
      auditMethod: map['audit_method']?.toString() ?? 'QR_SCAN',
      auditNotes: rawNotes,
      auditedAt: DateTime.tryParse(map['audited_at']?.toString() ?? '') ??
          DateTime.now(),
      previousQuantity: prevQty,
      newQuantity: nextQty,
      quantityChange: changeQty,
      quantityChangeReason: reasonQty,
      quantityDistribution: parsedDistribution,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'audit_id': auditId,
      'asset_id': assetId,
      'control_number': controlNumber,
      'audited_by': auditedBy,
      'previous_condition': previousCondition,
      'new_condition': newCondition,
      'previous_status': previousStatus,
      'new_status': newStatus,
      'previous_location': previousLocation,
      'new_location': newLocation,
      'audit_method': auditMethod,
      'audit_notes': auditNotes,
      'audited_at': auditedAt.toIso8601String(),
    };
  }
}