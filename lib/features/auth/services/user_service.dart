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

  /// Fetch ecclesiastical payment receipts belonging to the current parishioner
  static Future<List<Map<String, dynamic>>> getMyReceipts() async {
    final user = AuthService.currentUser;
    if (user == null) return [];

    final cleanName = user.fullName.trim();

    try {
      final response = await _client
          .from('parish_transactions')
          .select()
          .ilike('payor_name', '%$cleanName%')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
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