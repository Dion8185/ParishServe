import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import 'otp_rate_limiter.dart';

/// Custom exception thrown when valid credentials are provided
/// but the account's email has not been verified yet.
class EmailNotConfirmedException implements Exception {
  final String email;
  final String message;

  EmailNotConfirmedException({
    required this.email,
    this.message = 'Your email address is not yet verified. Please enter the verification code sent to your email.',
  });

  @override
  String toString() => message;
}

class AuthService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// In-memory cache of the active user profile
  static UserModel? currentUser;

  /// Check if an active Supabase auth session exists in storage (Web or Mobile)
  static bool get hasActiveSession => _client.auth.currentSession != null;

  /// Authenticate staff or parishioners using Supabase Auth
  static Future<UserModel?> login({
    required String identifier, // username or email
    required String password,
  }) async {
    final cleanIdentifier = identifier.trim();
    String emailToUse = cleanIdentifier;

    // 1. Resolve username to email via public.users if no '@' is present
    if (!cleanIdentifier.contains('@')) {
      final userRecord = await _client
          .from('users')
          .select('email')
          .ilike('username', cleanIdentifier)
          .maybeSingle();

      if (userRecord == null) {
        throw 'No account found matching username "$cleanIdentifier".';
      }
      emailToUse = userRecord['email'];
    }

    // 2. Authenticate through Supabase Auth
    try {
      final authResponse = await _client.auth.signInWithPassword(
        email: emailToUse,
        password: password,
      );

      if (authResponse.user == null) {
        throw 'Invalid credentials. Please verify your email and password.';
      }
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      // Intercept unconfirmed email error (Code 400) from Supabase GoTrue
      if (msg.contains('email not confirmed') || msg.contains('not confirmed')) {
        throw EmailNotConfirmedException(email: emailToUse);
      }
      rethrow;
    }

    // 3. Hydrate profile from public.users
    final user = await fetchProfileByEmail(emailToUse);

    if (user == null) {
      await _client.auth.signOut();
      throw 'User profile record not found in parish database.';
    }

    // 4. Verify account active status
    if (!user.accountStatus) {
      await _client.auth.signOut();
      currentUser = null;
      throw 'This account has been deactivated. Please contact the Parish Administrator.';
    }

    currentUser = user;
    return user;
  }

  /// Restores session on app startup (e.g., after F5 on web or app restart on mobile)
  static Future<UserModel?> restoreSession() async {
    try {
      final session = _client.auth.currentSession;
      if (session == null || session.user.email == null) {
        currentUser = null;
        return null;
      }

      final email = session.user.email!;
      final user = await fetchProfileByEmail(email);

      if (user == null || !user.accountStatus) {
        // Account deleted or deactivated while session was idle
        await _client.auth.signOut();
        currentUser = null;
        return null;
      }

      currentUser = user;
      return user;
    } catch (e) {
      debugPrint('Error restoring session: $e');
      currentUser = null;
      return null;
    }
  }

  /// Helper: Fetch profile directly from public.users by email
  static Future<UserModel?> fetchProfileByEmail(String email) async {
    try {
      final profile = await _client
          .from('users')
          .select()
          .ilike('email', email.trim())
          .maybeSingle();

      if (profile == null) return null;
      return UserModel.fromMap(profile);
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
      return null;
    }
  }

  /// Sign up a new parishioner with Supabase Auth + public.users profile
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

    // Check if username is already taken
    final existing = await _client
        .from('users')
        .select('username')
        .ilike('username', cleanUsername)
        .maybeSingle();

    if (existing != null) {
      throw 'Username "$cleanUsername" is already taken. Please choose another username.';
    }

    // 1. Sign up user in Supabase Auth (Dispatches OTP or confirmation email)
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

    // Track initial registration as first dispatch in rate limiter
    OtpRateLimiter.recordResendAttempt(cleanEmail);

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

  /// Verify 6-digit OTP sent by email
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

    // Clear rate limit history upon successful confirmation
    OtpRateLimiter.clearHistory(email);

    final user = await fetchProfileByEmail(email);
    if (user == null) {
      throw 'User profile not found in parish database.';
    }

    currentUser = user;
    return user;
  }

  /// Resend verification OTP code with 60s cooldown and 3/hr rate limit
  static Future<void> resendVerificationEmail(String email) async {
    final cleanEmail = email.trim();

    // Enforce 60s cooldown and 3 resubmissions/hr limit
    OtpRateLimiter.recordResendAttempt(cleanEmail);

    await _client.auth.resend(
      type: OtpType.signup,
      email: cleanEmail,
    );
  }

  /// Terminate session across Web and Mobile
  static Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } finally {
      currentUser = null;
    }
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