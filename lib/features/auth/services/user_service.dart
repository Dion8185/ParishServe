import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

class UserService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Fetch service appointments booked by the currently logged-in parishioner
  static Future<List<Map<String, dynamic>>> getMyBookings() async {
    final userId = AuthService.currentUser?.userId;
    if (userId == null) return [];

    final response = await _client
        .from('service_appointments')
        .select()
        .eq('created_by', userId)
        .order('scheduled_datetime', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Fetch ecclesiastical payment receipts belonging to the current parishioner
  static Future<List<Map<String, dynamic>>> getMyReceipts() async {
    final userId = AuthService.currentUser?.userId;
    if (userId == null) return [];

    final response = await _client
        .from('parish_transactions')
        .select()
        .eq('issued_by', userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }
}