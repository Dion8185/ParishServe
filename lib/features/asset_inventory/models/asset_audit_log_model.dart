// =============================================================================
// FILE: lib/features/asset_inventory/models/asset_audit_log_model.dart
// =============================================================================

class AssetAuditLogModel {
  final String auditId;
  final String assetId;
  final String controlNumber;
  final String? auditedBy;
  final String? auditorName;
  final String? previousCondition;
  final String newCondition;
  final String? previousLocation;
  final String? newLocation;
  final String auditMethod; // 'QR_SCAN', 'RFID_NFC', 'MANUAL'
  final String? auditNotes;
  final DateTime auditedAt;

  const AssetAuditLogModel({
    required this.auditId,
    required this.assetId,
    required this.controlNumber,
    this.auditedBy,
    this.auditorName,
    this.previousCondition,
    required this.newCondition,
    this.previousLocation,
    this.newLocation,
    this.auditMethod = 'QR_SCAN',
    this.auditNotes,
    required this.auditedAt,
  });

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

    return AssetAuditLogModel(
      auditId: map['audit_id']?.toString() ?? '',
      assetId: map['asset_id']?.toString() ?? '',
      controlNumber: map['control_number']?.toString() ?? '',
      auditedBy: map['audited_by']?.toString(),
      auditorName: auditor,
      previousCondition: map['previous_condition']?.toString(),
      newCondition: map['new_condition']?.toString() ?? 'VERIFIED / GOOD',
      previousLocation: map['previous_location']?.toString(),
      newLocation: map['new_location']?.toString(),
      auditMethod: map['audit_method']?.toString() ?? 'QR_SCAN',
      auditNotes: map['audit_notes']?.toString(),
      auditedAt: DateTime.tryParse(map['audited_at']?.toString() ?? '') ?? DateTime.now(),
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
      'previous_location': previousLocation,
      'new_location': newLocation,
      'audit_method': auditMethod,
      'audit_notes': auditNotes,
      'audited_at': auditedAt.toIso8601String(),
    };
  }
}