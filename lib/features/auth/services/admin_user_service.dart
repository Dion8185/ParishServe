import 'package:flutter/foundation.dart';
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

    // Normal admin can see operational staff and parishioners, but not other admins/superadmins
    if (callerRole == 'admin') {
      return allUsers.where((u) {
        final r = u.userRole.toLowerCase();
        return r != 'admin' && r != 'superadmin';
      }).toList();
    }

    // Superadmin sees all accounts
    return allUsers;
  }

  /// Create a new user account with Supabase Auth registration
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

    // Check uniqueness in public.users
    final existingUser = await _client
        .from('users')
        .select('username')
        .or('username.eq.$cleanUsername,email.eq.$cleanEmail')
        .maybeSingle();

    if (existingUser != null) {
      throw 'An account with that username or email already exists.';
    }

    // Provision in Supabase Auth using an isolated client instance
    // (This prevents the active Admin's current session from being overwritten)
    try {
      final tempClient = SupabaseClient(
        'https://wdosrvmkgdrkcotlkzgi.supabase.co',
        'sb_publishable_wzE6ee-MEqpM8Qz7H8awDQ_4q1i2oJq',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );

      await tempClient.auth.signUp(
        email: cleanEmail,
        password: password,
        data: {
          'username': cleanUsername,
          'first_name': firstName.trim(),
          'last_name': lastName.trim(),
        },
      );
    } catch (e) {
      debugPrint('Notice: Supabase Auth provision response: $e');
    }

    final userId = await _generateUserId();

    final userMap = {
      'user_id': userId,
      'username': cleanUsername,
      'email': cleanEmail,
      'password': password,
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