import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/services/auth_service.dart';

class SecretaryService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Fetch all ecclesiastical receipts for cashiering and remittance
  static Future<List<Map<String, dynamic>>> getTransactions() async {
    final response = await _client
        .from('parish_transactions')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Register a new transaction and automatically generate a unique sequential receipt number
  static Future<Map<String, dynamic>> createTransaction({
    required String payerName,
    required String transactionType,
    required double amountReceived,
    String? remarks,
  }) async {
    final receiptNo = await _generateReceiptNumber();
    final transactionId = 'TXN-${DateTime.now().millisecondsSinceEpoch}';

    final userId = AuthService.currentUser?.userId ?? 'S26-0003'; // Fallback to default secretary ID

    final data = {
      'transaction_id': transactionId,
      'receipt_number': receiptNo,
      'payer_name': payerName.trim(),
      'transaction_type': transactionType,
      'amount_received': amountReceived,
      'transaction_status': 'PAID',
      'issued_by': userId,
      'remarks': remarks,
      'created_at': DateTime.now().toIso8601String(),
    };

    final response = await _client
        .from('parish_transactions')
        .insert(data)
        .select()
        .single();

    return response;
  }

  /// Fetch all active parish appointments
  static Future<List<Map<String, dynamic>>> getAppointments() async {
    final response = await _client
        .from('service_appointments')
        .select()
        .order('scheduled_datetime', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Schedule a new service appointment
  static Future<Map<String, dynamic>> createAppointment({
    required String serviceName,
    required String requesterName,
    required String contactNumber,
    required DateTime scheduledDatetime,
    required String officiant,
    required String feeStatus,
  }) async {
    final appointmentId = 'APT-2026-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final userId = AuthService.currentUser?.userId ?? 'S26-0003';

    final data = {
      'appointment_id': appointmentId,
      'service_name': serviceName,
      'requester_name': requesterName.trim(),
      'contact_number': contactNumber.trim(),
      'scheduled_datetime': scheduledDatetime.toIso8601String(),
      'officiant': officiant,
      'appointment_status': 'CONFIRMED',
      'fee_status': feeStatus,
      'created_by': userId,
      'created_at': DateTime.now().toIso8601String(),
    };

    final response = await _client
        .from('service_appointments')
        .insert(data)
        .select()
        .single();

    return response;
  }

  /// Helper to generate sequential receipt numbers: REC-YYYY-XXXX
  static Future<String> _generateReceiptNumber() async {
    final year = DateTime.now().year;
    try {
      final res = await _client
          .from('parish_transactions')
          .select('receipt_number')
          .like('receipt_number', 'REC-$year-%');

      int highest = 880; // Baseline offset
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
      return 'REC-$year-${DateTime.now().second.toString().padLeft(5, '0')}';
    }
  }
}