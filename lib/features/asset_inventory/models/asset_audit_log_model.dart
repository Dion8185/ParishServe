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
  final String? previousStatus;
  final String? newStatus;
  final String? previousLocation;
  final String? newLocation;
  final String auditMethod; // 'QR_SCAN', 'RFID_NFC', 'MANUAL'
  final String? auditNotes;
  final DateTime auditedAt;

  // Quantity Tracking and Adjustment History
  final int? previousQuantity;
  final int? newQuantity;
  final int? quantityChange;
  final String? quantityChangeReason;

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
  });

  bool get hasQuantityAdjustment =>
      quantityChange != null && quantityChange != 0;

  String get formattedQuantityChange {
    if (!hasQuantityAdjustment) return 'No quantity change';
    final sign = quantityChange! > 0 ? '+${quantityChange!}' : '${quantityChange!}';
    return '$sign units (from $previousQuantity to $newQuantity)';
  }

  /// Clean user notes without the automated quantity adjustment tracking header
  String get cleanNotes {
    if (auditNotes == null) return '';
    return auditNotes!
        .replaceAll(RegExp(r'\[QTY_ADJUST:.*?\]\n?'), '')
        .trim();
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

    // Parse automated quantity adjustment metadata from audit notes if present
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
      auditedAt: DateTime.tryParse(map['audited_at']?.toString() ?? '') ?? DateTime.now(),
      previousQuantity: prevQty,
      newQuantity: nextQty,
      quantityChange: changeQty,
      quantityChangeReason: reasonQty,
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