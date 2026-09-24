import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import 'auth_service.dart';

class AdminUserService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Fetch all users subject to caller's administrative role hierarchy
  static Future<List<UserModel>> getAllUsers() async {
    final response = await _client
        .from('users')
        .select()
        .order('created_at', ascending: false);

    final allUsers = (response as List)
        .map((row) => UserModel.fromMap(row as Map<String, dynamic>))
        .toList();

    final callerRole = AuthService.currentUser?.userRole.toLowerCase() ?? '';

    // Normal admin can manage operational staff and parishioners, but not other admins/superadmins
    if (callerRole == 'admin') {
      return allUsers.where((u) {
        final r = u.userRole.toLowerCase();
        return r != 'admin' && r != 'superadmin';
      }).toList();
    }

    // Superadmin sees all accounts
    return allUsers;
  }

  /// Create a new user account atomically across auth.users and public.users via RPC
  static Future<UserModel> createUser({
    required String username,
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String userRole,
  }) async {
    final callerRole = AuthService.currentUser?.userRole.toLowerCase() ?? '';

    // Security check: Normal admin cannot grant admin or superadmin privileges
    if (callerRole != 'superadmin' &&
        (userRole.toLowerCase() == 'admin' || userRole.toLowerCase() == 'superadmin')) {
      throw 'Unauthorized: Only Super Administrators can provision administrative accounts.';
    }

    final cleanEmail = email.trim();
    final cleanUsername = username.trim();

    // Call the PostgreSQL function which atomically provisions auth.users,
    // auto-confirms the email, hashes the password, and inserts into public.users.
    final response = await _client.rpc('admin_create_user', params: {
      'p_email': cleanEmail,
      'p_password': password,
      'p_username': cleanUsername,
      'p_first_name': firstName.trim(),
      'p_last_name': lastName.trim(),
      'p_user_role': userRole,
    });

    if (response == null) {
      throw 'Failed to provision user. Empty response received from server.';
    }

    final userMap = Map<String, dynamic>.from(response as Map);
    return UserModel.fromMap(userMap);
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
    final callerRole = AuthService.currentUser?.userRole.toLowerCase() ?? '';

    if (callerRole != 'superadmin' &&
        (userRole.toLowerCase() == 'admin' || userRole.toLowerCase() == 'superadmin')) {
      throw 'Unauthorized: Only Super Administrators can assign administrative roles.';
    }

    await _client.from('users').update({
      'username': username.trim(),
      'email': email.trim(),
      'first_name': firstName.trim(),
      'last_name': lastName.trim(),
      'user_role': userRole,
      'account_status': accountStatus,
    }).eq('user_id', userId);
  }

  /// Soft deactivate or reactivate user account
  static Future<void> setAccountStatus(String targetUserId, bool isActive) async {
    final currentUserId = AuthService.currentUser?.userId;

    // Self-lockout prevention
    if (targetUserId == currentUserId) {
      throw 'Action denied: You cannot deactivate your own administrative account.';
    }

    await _client.from('users').update({
      'account_status': isActive,
    }).eq('user_id', targetUserId);
  }

  /// Fallback generator for sequential User IDs (used when needed outside RPC)
  static Future<String> generateUserId() async {
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