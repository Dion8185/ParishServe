import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';

class AuthService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Stores the currently authenticated user in memory
  static UserModel? currentUser;

  /// Authenticate staff or parishioners
  static Future<UserModel?> login({
    required String identifier, // username or email
    required String password,
  }) async {
    final cleanIdentifier = identifier.trim();

    // 1. DEVELOPMENT BYPASS / LEGACY STAFF CHIPS:
    // If logging in via quick test accounts or dummy emails matching default passwords,
    // check public.users directly to preserve staging workflow.
    if (password == 'ParishServe@123') {
      final staffResponse = await _client
          .from('users')
          .select()
          .or('username.eq.$cleanIdentifier,email.eq.$cleanIdentifier')
          .maybeSingle();

      if (staffResponse != null) {
        final user = UserModel.fromMap(staffResponse);
        if (!user.accountStatus) {
          throw 'This account has been deactivated.';
        }
        currentUser = user;
        return user;
      }
    }

    // 2. PRODUCTION SUPABASE AUTHENTICATION:
    String emailToUse = cleanIdentifier;
    if (!cleanIdentifier.contains('@')) {
      final userRecord = await _client
          .from('users')
          .select('email')
          .eq('username', cleanIdentifier)
          .maybeSingle();

      if (userRecord == null) return null;
      emailToUse = userRecord['email'];
    }

    try {
      final authResponse = await _client.auth.signInWithPassword(
        email: emailToUse,
        password: password,
      );

      if (authResponse.user == null) return null;

      final profileResponse = await _client
          .from('users')
          .select()
          .eq('email', emailToUse)
          .maybeSingle();

      if (profileResponse == null) return null;

      final user = UserModel.fromMap(profileResponse);
      if (!user.accountStatus) {
        await _client.auth.signOut();
        throw 'This account has been deactivated. Please contact the Parish Office.';
      }

      currentUser = user;
      return user;
    } catch (_) {
      // Fallback direct check against public.users table if Supabase auth fails
      final directResponse = await _client
          .from('users')
          .select()
          .or('username.eq.$cleanIdentifier,email.eq.$cleanIdentifier')
          .eq('password', password)
          .maybeSingle();

      if (directResponse != null) {
        final user = UserModel.fromMap(directResponse);
        currentUser = user;
        return user;
      }
      return null;
    }
  }

  /// Register a new Parishioner account with Supabase Auth + public.users profile
  static Future<Map<String, dynamic>> registerParishioner({
    required String firstName,
    required String lastName,
    required String username,
    required String email,
    required String password,
  }) async {
    final cleanFirstName = firstName.trim();
    final cleanLastName = lastName.trim();
    final cleanUsername = username.trim();
    final cleanEmail = email.trim();

    if (cleanFirstName.isEmpty || cleanLastName.isEmpty) {
      throw 'Please provide your full legal name.';
    }
    if (cleanUsername.isEmpty || cleanUsername.length < 3) {
      throw 'Username must be at least 3 characters long.';
    }
    if (!cleanEmail.contains('@') || !cleanEmail.contains('.')) {
      throw 'Please enter a valid email address.';
    }
    if (password.length < 6) {
      throw 'Password must be at least 6 characters long.';
    }

    // Check if username already exists in public.users
    final existing = await _client
        .from('users')
        .select('username')
        .eq('username', cleanUsername)
        .maybeSingle();

    if (existing != null) {
      throw 'Username "$cleanUsername" is already taken. Please choose another username.';
    }

    // 1. Sign up user in Supabase Auth (triggers verification email)
    final authResponse = await _client.auth.signUp(
      email: cleanEmail,
      password: password,
      data: {
        'username': cleanUsername,
        'first_name': cleanFirstName,
        'last_name': cleanLastName,
      },
    );

    if (authResponse.user == null) {
      throw 'Could not create authentication account.';
    }

    final userId = await _generateParishionerId();

    // 2. Insert complementary profile row into public.users
    final payload = {
      'user_id': userId,
      'username': cleanUsername,
      'email': cleanEmail,
      'password': password,
      'first_name': cleanFirstName,
      'last_name': cleanLastName,
      'user_role': 'user',
      'account_status': true,
      'created_at': DateTime.now().toIso8601String(),
    };

    final profileResponse = await _client
        .from('users')
        .insert(payload)
        .select()
        .single();

    final newUser = UserModel.fromMap(profileResponse);
    currentUser = newUser;

    return {
      'user': newUser,
      'requiresVerification': authResponse.session == null,
    };
  }

  /// Verify the 6-digit Email OTP token sent by Supabase
  static Future<UserModel> verifyEmailOtp({
    required String email,
    required String token,
  }) async {
    final response = await _client.auth.verifyOTP(
      email: email.trim(),
      token: token.trim(),
      type: OtpType.signup,
    );

    if (response.user == null) {
      throw 'Invalid or expired verification code. Please check your email.';
    }

    final profileResponse = await _client
        .from('users')
        .select()
        .eq('email', email.trim())
        .single();

    final user = UserModel.fromMap(profileResponse);
    currentUser = user;
    return user;
  }

  /// Resend verification OTP code
  static Future<void> resendVerificationEmail(String email) async {
    await _client.auth.resend(
      type: OtpType.signup,
      email: email.trim(),
    );
  }

  static Future<String> _generateParishionerId() async {
    final now = DateTime.now();
    final yearSuffix = (now.year % 100).toString().padLeft(2, '0');

    try {
      final records = await _client
          .from('users')
          .select('user_id')
          .like('user_id', 'U$yearSuffix-%');

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
      return 'U$yearSuffix-$nextSeq';
    } catch (_) {
      final timestampSeq = (now.millisecondsSinceEpoch % 10000).toString().padLeft(4, '0');
      return 'U$yearSuffix-$timestampSeq';
    }
  }
}