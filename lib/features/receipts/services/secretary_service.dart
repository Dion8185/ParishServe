// =============================================================================
// FILE: lib/features/receipts/services/secretary_service.dart
// =============================================================================

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/services/auth_service.dart';

class SecretaryService {
  static final SupabaseClient _client = Supabase.instance.client;

  static String? _cachedValidTransactionType;
  static String? _cachedValidVoidStatus;

  /// Fetch all ecclesiastical receipts for cashiering and remittance
  static Future<List<Map<String, dynamic>>> getTransactions() async {
    final response = await _client
        .from('parish_transactions')
        .select()
        .order('transaction_date', ascending: false)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Fetch all service requests (Pabuklat record requests) for Secretary review
  static Future<List<Map<String, dynamic>>> getServiceRequests() async {
    final response = await _client
        .from('service_requests')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Update service request status (Secretary approval/rejection and pickup date assignment)
  static Future<void> updateServiceRequestStatus({
    required String serviceRequestId,
    required String requestStatus,
    DateTime? pickupDate,
    String? rejectionReason,
  }) async {
    final secretaryId = AuthService.currentUser?.userId;

    final updateMap = {
      'request_status': requestStatus,
      'reviewed_by': secretaryId,
    };

    if (pickupDate != null) {
      updateMap['pickup_date'] = pickupDate.toIso8601String().substring(0, 10);
    }
    if (rejectionReason != null && rejectionReason.trim().isNotEmpty) {
      updateMap['rejection_reason'] = rejectionReason.trim();
    }

    await _client
        .from('service_requests')
        .update(updateMap)
        .eq('service_request_id', serviceRequestId);
  }

  /// Register a new transaction with automatic enum resolution
  static Future<Map<String, dynamic>> createTransaction({
    required String payorName,
    String? payorContact,
    required String relatedService,
    required String transactionDetails,
    required double transactionAmount,
    String? transactionType,
    String? relatedAppointmentId,
    String? relatedRequestId,
    String? relatedIssuanceId,
    DateTime? transactionDate,
  }) async {
    final receiptNo = await _generateReceiptNumber();
    final transactionId = 'TXN-${DateTime.now().millisecondsSinceEpoch}';
    final userId = AuthService.currentUser?.userId ?? 'S26-0003';
    final effectiveDate = (transactionDate ?? DateTime.now()).toIso8601String();

    final cleanService = relatedService.trim();
    final safeService = cleanService.length > 90
        ? '${cleanService.substring(0, 87)}...'
        : cleanService;

    if (_cachedValidTransactionType == null) {
      try {
        final existing = await _client
            .from('parish_transactions')
            .select('transaction_type')
            .limit(1)
            .maybeSingle();

        if (existing != null && existing['transaction_type'] != null) {
          final foundType = existing['transaction_type'].toString().trim();
          if (foundType.isNotEmpty) {
            _cachedValidTransactionType = foundType;
          }
        }
      } catch (_) {}
    }

    final List<String> candidatePool = [
      if (_cachedValidTransactionType != null) _cachedValidTransactionType!,
      if (transactionType != null && transactionType.isNotEmpty) transactionType,
      'certificate',
      'Certificate',
      'donation',
      'Donation',
      'stipend',
      'Stipend',
      'mass_intention',
      'Mass Intention',
      'sacrament',
      'Sacrament',
      'service',
      'Service',
      'offering',
      'Offering',
      'fee',
      'Fee',
      'appointment',
      'service_request',
      'walk_in',
      'walk-in',
      'Walk-In',
      'onsite',
      'other',
      'Other',
      'income',
    ];

    final uniqueCandidates = candidatePool.toSet().toList();
    PostgrestException? lastEnumError;

    for (final candidate in uniqueCandidates) {
      final data = {
        'transaction_id': transactionId,
        'receipt_number': receiptNo,
        'payor_name': payorName.trim(),
        'payor_contact': (payorContact != null && payorContact.trim().isNotEmpty)
            ? payorContact.trim()
            : null,
        'transaction_date': effectiveDate,
        'transaction_type': candidate,
        'related_service': safeService,
        'transaction_details': transactionDetails.trim(),
        'transaction_amount': transactionAmount,
        'payment_required_status': transactionAmount > 0,
        'transaction_status': 'paid',
        'related_appointment_id': relatedAppointmentId,
        'related_request_id': relatedRequestId,
        'related_issuance_id': relatedIssuanceId,
        'encoded_by': userId,
        'created_at': DateTime.now().toIso8601String(),
      };

      try {
        final response = await _client
            .from('parish_transactions')
            .insert(data)
            .select()
            .single();

        _cachedValidTransactionType = candidate;
        return response;
      } on PostgrestException catch (e) {
        if (e.code == '22P02' && e.message.contains('transaction_type')) {
          lastEnumError = e;
          continue;
        }
        rethrow;
      }
    }

    if (lastEnumError != null) {
      throw 'Invalid transaction_type enum value in database.';
    }

    throw 'Failed to record transaction in parish ledger.';
  }

  /// Voids an existing ecclesiastical receipt
  static Future<Map<String, dynamic>> voidTransaction({
    required String transactionId,
    required String reason,
  }) async {
    if (reason.trim().isEmpty) {
      throw 'A void reason is required for canonical audit compliance.';
    }

    final currentUser = AuthService.currentUser;
    final userId = currentUser?.userId ?? 'S26-0003';
    final userFullName = currentUser?.fullName ?? 'Parish Staff';
    final now = DateTime.now();
    final dateStamp =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final existing = await _client
        .from('parish_transactions')
        .select()
        .eq('transaction_id', transactionId)
        .single();

    final currentDetails = existing['transaction_details']?.toString() ?? '';
    final voidAuditLog =
        '[VOIDED on $dateStamp by $userFullName ($userId)]: Reason: ${reason.trim()}';
    final updatedDetails = currentDetails.isEmpty
        ? voidAuditLog
        : '$currentDetails\n$voidAuditLog';

    final candidateStatuses = [
      if (_cachedValidVoidStatus != null) _cachedValidVoidStatus!,
      'cancelled',
      'voided',
      'void',
      'Cancelled',
      'Voided',
      'Void',
    ].toSet().toList();

    PostgrestException? lastError;

    for (final status in candidateStatuses) {
      try {
        final response = await _client
            .from('parish_transactions')
            .update({
          'transaction_status': status,
          'transaction_details': updatedDetails,
        })
            .eq('transaction_id', transactionId)
            .select()
            .single();

        _cachedValidVoidStatus = status;

        try {
          await _client.from('pastoral_audit_logs').insert({
            'log_id': 'LOG-${now.millisecondsSinceEpoch}',
            'priest_id': userId,
            'action_type': 'RECEIPT_VOIDED',
            'target_reference_id': existing['receipt_number'] ?? transactionId,
            'justification': 'Voided Receipt ${existing['receipt_number']}. Reason: ${reason.trim()}',
            'created_at': now.toIso8601String(),
          });
        } catch (_) {}

        return response;
      } on PostgrestException catch (e) {
        if (e.code == '22P02' && e.message.contains('transaction_status')) {
          lastError = e;
          continue;
        }
        rethrow;
      }
    }

    if (lastError != null) {
      throw 'Could not void receipt due to database enum mismatch.';
    }

    throw 'Failed to void transaction.';
  }

  static Future<String> _generateReceiptNumber() async {
    final year = DateTime.now().year;
    try {
      final res = await _client
          .from('parish_transactions')
          .select('receipt_number')
          .like('receipt_number', 'REC-$year-%')
          .order('receipt_number', ascending: false)
          .limit(20);

      int highest = 890;
      for (final item in res) {
        final rNo = item['receipt_number']?.toString() ?? '';
        final parts = rNo.split('-');
        if (parts.length >= 3) {
          final seq = int.tryParse(parts[2]);
          if (seq != null && seq > highest) {
            highest = seq;
          }
        }
      }
      final nextSeq = (highest + 1).toString().padLeft(5, '0');
      return 'REC-$year-$nextSeq';
    } catch (_) {
      final fallback = (DateTime.now().millisecondsSinceEpoch % 100000)
          .toString()
          .padLeft(5, '0');
      return 'REC-$year-$fallback';
    }
  }
}