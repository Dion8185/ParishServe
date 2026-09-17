import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';

class AdminUserService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Fetch all system users for Admin management dashboard
  static Future<List<UserModel>> getAllUsers() async {
    final response = await _client
        .from('users')
        .select()
        .order('created_at', ascending: false);

    return (response as List)
        .map((row) => UserModel.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Create a new user account (Admin function)
  static Future<UserModel> createUser({
    required String username,
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String userRole,
  }) async {
    final userId = await _generateUserId();

    final userMap = {
      'user_id': userId,
      'username': username.trim(),
      'email': email.trim(),
      'password': password, // Stored per current project pattern
      'first_name': firstName.trim(),
      'last_name': lastName.trim(),
      'user_role': userRole,
      'account_status': true,
      'created_at': DateTime.now().toIso8601String(),
    };

    final response = await _client
        .from('users')
        .insert(userMap)
        .select()
        .single();

    return UserModel.fromMap(response);
  }

  /// Update an existing user account
  static Future<void> updateUser({
    required String userId,
    required String username,
    required String email,
    required String firstName,
    required String lastName,
    required String userRole,
    required bool accountStatus,
  }) async {
    await _client.from('users').update({
      'username': username.trim(),
      'email': email.trim(),
      'first_name': firstName.trim(),
      'last_name': lastName.trim(),
      'user_role': userRole,
      'account_status': accountStatus,
    }).eq('user_id', userId);
  }

  /// Soft deactivate or reactivate user account instead of hard deletion
  static Future<void> setAccountStatus(String userId, bool isActive) async {
    await _client.from('users').update({
      'account_status': isActive,
    }).eq('user_id', userId);
  }

  /// Generates canonical User ID formatted as S26-XXXX
  static Future<String> _generateUserId() async {
    final now = DateTime.now();
    final yearSuffix = (now.year % 100).toString().padLeft(2, '0');

    try {
      final records = await _client
          .from('users')
          .select('user_id')
          .like('user_id', 'S$yearSuffix-%');

      int highest = 0;
      for (final item in records) {
        final id = item['user_id']?.toString() ?? '';
        final parts = id.split('-');
        if (parts.length >= 2) {
          final seq = int.tryParse(parts[1]);
          if (seq != null && seq > highest) {
            highest = seq;
          }
        }
      }

      final nextSeq = (highest + 1).toString().padLeft(4, '0');
      return 'S$yearSuffix-$nextSeq';
    } catch (_) {
      final timestampSeq = (now.millisecondsSinceEpoch % 10000).toString().padLeft(4, '0');
      return 'S$yearSuffix-$timestampSeq';
    }
  }
}