import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import 'otp_rate_limiter.dart';

/// Exception thrown when valid credentials are provided
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

/// Exception thrown when a user attempts to log in but has an active
/// unexpired password recovery OTP code in progress.
class ActivePasswordRecoveryException implements Exception {
  final String email;
  final String message;

  ActivePasswordRecoveryException({
    required this.email,
    this.message = 'An active password recovery code was recently requested for this account.',
  });

  @override
  String toString() => message;
}

class AuthService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// In-memory cache of the active user profile
  static UserModel? currentUser;

  /// Quarantine flag: True while the user is actively resetting their password.
  /// Prevents AuthGate from auto-redirecting to the dashboard when verifyOTP succeeds.
  static bool isPasswordRecoveryInProgress = false;

  /// Check if an active Supabase auth session exists in storage (Web or Mobile)
  static bool get hasActiveSession =>
      _client.auth.currentSession != null && !isPasswordRecoveryInProgress;

  /// Resolves a username or email input into the canonical registered email
  static Future<String> resolveIdentifierToEmail(String identifier) async {
    final clean = identifier.trim();
    if (clean.contains('@')) return clean.toLowerCase();

    final userRecord = await _client
        .from('users')
        .select('email')
        .ilike('username', clean)
        .maybeSingle();

    if (userRecord == null) {
      throw 'No registered account found matching username "$clean".';
    }

    return userRecord['email'].toString().trim().toLowerCase();
  }

  /// Authenticate staff or parishioners using Supabase Auth
  static Future<UserModel?> login({
    required String identifier, // username or email
    required String password,
  }) async {
    final emailToUse = await resolveIdentifierToEmail(identifier);

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

      // If login failed and this user has an active password recovery in flight,
      // redirect them straight to the recovery code screen
      if (OtpRateLimiter.hasActiveRecovery(emailToUse)) {
        throw ActivePasswordRecoveryException(email: emailToUse);
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
    // If user is currently recovering their password, DO NOT hydrate profile or enter dashboard
    if (isPasswordRecoveryInProgress) {
      currentUser = null;
      return null;
    }

    try {
      final session = _client.auth.currentSession;
      if (session == null || session.user.email == null) {
        currentUser = null;
        return null;
      }

      final email = session.user.email!;
      final user = await fetchProfileByEmail(email);

      if (user == null || !user.accountStatus) {
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

    final existing = await _client
        .from('users')
        .select('username')
        .ilike('username', cleanUsername)
        .maybeSingle();

    if (existing != null) {
      throw 'Username "$cleanUsername" is already taken. Please choose another username.';
    }

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

    OtpRateLimiter.recordSignupRequest(cleanEmail);
    OtpRateLimiter.recordResendAttempt(cleanEmail);

    final userId = await _generateParishionerId();

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

  /// Verify 6-digit signup OTP sent by email
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

    OtpRateLimiter.recordResendAttempt(cleanEmail);

    await _client.auth.resend(
      type: OtpType.signup,
      email: cleanEmail,
    );
  }

  // ===========================================================================
  // PASSWORD RECOVERY / FORGOT PASSWORD METHODS (DECOUPLED 3-STEP FLOW)
  // ===========================================================================

  /// Step 1: Sends a password recovery OTP code with cooldown and hourly rate limit tracking
  static Future<String> sendPasswordResetEmail(String identifier) async {
    final emailToUse = await resolveIdentifierToEmail(identifier);

    // Verify account exists in public.users
    final user = await fetchProfileByEmail(emailToUse);
    if (user == null) {
      throw 'No registered account found with email "$emailToUse".';
    }
    if (!user.accountStatus) {
      throw 'This account has been deactivated. Please contact the Parish Administrator.';
    }

    // Enforce 60s cooldown and 3/hour limit before dispatching
    OtpRateLimiter.recordResendAttempt(emailToUse);

    // Trigger Supabase GoTrue password reset
    await _client.auth.resetPasswordForEmail(emailToUse);

    // Record recovery state as active
    OtpRateLimiter.recordRecoveryRequest(emailToUse);

    return emailToUse;
  }

  /// Step 2: Verifies the 6-digit recovery OTP and unlocks recovery session in quarantine
  static Future<void> verifyRecoveryOtp({
    required String email,
    required String token,
  }) async {
    // Set quarantine flag BEFORE verifying OTP so AuthGate does not navigate to the dashboard
    isPasswordRecoveryInProgress = true;

    try {
      final response = await _client.auth.verifyOTP(
        email: email.trim(),
        token: token.trim(),
        type: OtpType.recovery,
      );

      if (response.user == null) {
        throw 'Invalid or expired recovery code. Please check your email or request a new code.';
      }
    } catch (_) {
      // If verification failed, reset quarantine flag
      isPasswordRecoveryInProgress = false;
      rethrow;
    }
  }

  /// Step 3: Updates the password across auth.users & public.users, then terminates recovery session
  static Future<void> completePasswordReset({
    required String email,
    required String newPassword,
  }) async {
    final cleanEmail = email.trim();

    try {
      // 1. Update password in Supabase Auth (using the quarantined recovery session)
      await _client.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      // 2. Keep public.users password column synchronized
      await _client
          .from('users')
          .update({'password': newPassword})
          .ilike('email', cleanEmail);

      // 3. Clear active recovery state from tracker
      OtpRateLimiter.clearRecovery(cleanEmail);
    } finally {
      // 4. Terminate recovery session and reset quarantine flag
      // so user must sign in cleanly through the login form with their new password
      await _client.auth.signOut();
      isPasswordRecoveryInProgress = false;
      currentUser = null;
    }
  }

  /// Cancels an in-progress recovery and cleans up the temporary session
  static Future<void> cancelPasswordRecovery() async {
    if (isPasswordRecoveryInProgress) {
      isPasswordRecoveryInProgress = false;
      currentUser = null;
      try {
        await _client.auth.signOut();
      } catch (_) {}
    }
  }

  /// Terminate session across Web and Mobile
  static Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } finally {
      isPasswordRecoveryInProgress = false;
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