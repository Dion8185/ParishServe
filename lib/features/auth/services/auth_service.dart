import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';

class AuthService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Authenticate staff using Username or Email + Password
  static Future<UserModel?> login({
    required String identifier, // username or email
    required String password,
  }) async {
    final cleanIdentifier = identifier.trim();

    final response = await _client
        .from('users')
        .select()
        .or('username.eq.$cleanIdentifier,email.eq.$cleanIdentifier')
        .eq('password', password)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return UserModel.fromMap(response);
  }
}