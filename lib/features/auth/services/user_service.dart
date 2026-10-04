// =============================================================================
// FILE: lib/features/auth/services/user_service.dart
// =============================================================================

import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

class UserService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Fetch service appointments booked by the currently logged-in parishioner
  static Future<List<Map<String, dynamic>>> getMyBookings() async {
    final user = AuthService.currentUser;
    if (user == null) return [];

    final userId = user.userId;
    final cleanEmail = user.email.trim().toLowerCase();
    final cleanName = user.fullName.trim();

    try {
      final idMatches = await _client
          .from('appointments')
          .select()
          .eq('created_by', userId)
          .order('requested_date', ascending: true);

      if ((idMatches as List).isNotEmpty) {
        return List<Map<String, dynamic>>.from(idMatches);
      }

      if (cleanEmail.isNotEmpty) {
        final emailMatches = await _client
            .from('appointments')
            .select()
            .ilike('email', cleanEmail)
            .order('requested_date', ascending: true);

        if ((emailMatches as List).isNotEmpty) {
          return List<Map<String, dynamic>>.from(emailMatches);
        }
      }

      if (cleanName.isNotEmpty) {
        final nameMatches = await _client
            .from('appointments')
            .select()
            .ilike('requester_name', '%$cleanName%')
            .order('requested_date', ascending: true);

        if ((nameMatches as List).isNotEmpty) {
          return List<Map<String, dynamic>>.from(nameMatches);
        }
      }

      return [];
    } catch (_) {
      return [];
    }
  }

  /// Fetch ecclesiastical payment receipts belonging to the current parishioner,
  /// including receipts automatically issued for Pabuklat record requests, appointments, and direct offerings.
  static Future<List<Map<String, dynamic>>> getMyReceipts() async {
    final user = AuthService.currentUser;
    if (user == null) return [];

    final cleanName = user.fullName.trim();
    final userId = user.userId;

    try {
      // 1. Collect user's service_request_ids (Pabuklat requests)
      final userRequests = await _client
          .from('service_requests')
          .select('service_request_id')
          .eq('created_by', userId);

      final List<String> requestIds = (userRequests as List)
          .map((r) => r['service_request_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();

      // 2. Collect user's appointment_ids
      final userAppointments = await _client
          .from('appointments')
          .select('appointment_id')
          .eq('created_by', userId);

      final List<String> appointmentIds = (userAppointments as List)
          .map((a) => a['appointment_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();

      // 3. Query parish_transactions matching payor_name
      final nameQuery = await _client
          .from('parish_transactions')
          .select()
          .ilike('payor_name', '%$cleanName%')
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> combinedTransactions =
      List<Map<String, dynamic>>.from(nameQuery);
      final Set<String> existingTxnIds =
      combinedTransactions.map((t) => t['transaction_id'].toString()).toSet();

      // 4. Query transactions linked directly to user's Pabuklat requests
      if (requestIds.isNotEmpty) {
        final requestTxns = await _client
            .from('parish_transactions')
            .select()
            .inFilter('related_request_id', requestIds)
            .order('created_at', ascending: false);

        for (final row in requestTxns as List) {
          final map = Map<String, dynamic>.from(row);
          if (!existingTxnIds.contains(map['transaction_id'].toString())) {
            combinedTransactions.add(map);
            existingTxnIds.add(map['transaction_id'].toString());
          }
        }
      }

      // 5. Query transactions linked directly to user's appointments
      if (appointmentIds.isNotEmpty) {
        final appointmentTxns = await _client
            .from('parish_transactions')
            .select()
            .inFilter('related_appointment_id', appointmentIds)
            .order('created_at', ascending: false);

        for (final row in appointmentTxns as List) {
          final map = Map<String, dynamic>.from(row);
          if (!existingTxnIds.contains(map['transaction_id'].toString())) {
            combinedTransactions.add(map);
            existingTxnIds.add(map['transaction_id'].toString());
          }
        }
      }

      // Sort by transaction_date / created_at descending
      combinedTransactions.sort((a, b) {
        final da = DateTime.tryParse(a['transaction_date']?.toString() ?? a['created_at']?.toString() ?? '') ?? DateTime(1970);
        final db = DateTime.tryParse(b['transaction_date']?.toString() ?? b['created_at']?.toString() ?? '') ?? DateTime(1970);
        return db.compareTo(da);
      });

      return combinedTransactions;
    } catch (_) {
      return [];
    }
  }

  /// Fetch Pabuklat / certificate requests submitted by the current parishioner
  static Future<List<Map<String, dynamic>>> getMyServiceRequests() async {
    final user = AuthService.currentUser;
    if (user == null) return [];

    try {
      final response = await _client
          .from('service_requests')
          .select()
          .eq('created_by', user.userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (_) {
      return [];
    }
  }

  /// Submit a Pabuklat (Certificate Request) into the service_requests table
  static Future<void> createServiceRequest({
    required String requesterName,
    required String contactNumber,
    required String serviceType,
    required String details,
  }) async {
    final userId = AuthService.currentUser?.userId;
    final requestId = 'REQ-${DateTime.now().millisecondsSinceEpoch}';

    final payload = {
      'service_request_id': requestId,
      'requester_name': requesterName.trim(),
      'contact_number': contactNumber.trim(),
      'email': AuthService.currentUser?.email,
      'service_type': serviceType,
      'service_request_details': details.trim(),
      'request_status': 'submitted',
      'created_by': userId,
      'created_at': DateTime.now().toIso8601String(),
    };

    await _client.from('service_requests').insert(payload);
  }
}