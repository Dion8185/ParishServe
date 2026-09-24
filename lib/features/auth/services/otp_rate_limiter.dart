class OtpRateLimiter {
  // In-memory record of resend timestamps keyed by email
  static final Map<String, List<DateTime>> _resendHistory = {};

  // Tracks active password recovery requests: email -> timestamp
  static final Map<String, DateTime> _activeRecoveryRequests = {};

  // Tracks active signup verification requests: email -> timestamp
  static final Map<String, DateTime> _activeSignupRequests = {};

  static const int maxResendsPerHour = 3;
  static const Duration cooldownDuration = Duration(seconds: 60);
  static const Duration windowDuration = Duration(hours: 1);
  static const Duration otpValidityDuration = Duration(hours: 1);

  /// Cleans up resend attempts older than 1 hour
  static List<DateTime> _getRecentAttempts(String email) {
    final now = DateTime.now();
    final cleanEmail = email.trim().toLowerCase();
    final history = _resendHistory[cleanEmail] ?? [];

    final recent = history.where((t) => now.difference(t) < windowDuration).toList();
    _resendHistory[cleanEmail] = recent;
    return recent;
  }

  /// Returns remaining retry quota for the current 1-hour window (e.g., 2 of 3)
  static int getRemainingAttempts(String email) {
    final recent = _getRecentAttempts(email);
    final remaining = maxResendsPerHour - recent.length;
    return remaining > 0 ? remaining : 0;
  }

  /// Returns total attempts used within the current 1-hour window
  static int getAttemptsUsed(String email) {
    return _getRecentAttempts(email).length;
  }

  /// Checks if user is currently within the 60-second cooldown
  static int getRemainingCooldownSeconds(String email) {
    final recent = _getRecentAttempts(email);
    if (recent.isEmpty) return 0;

    final lastAttempt = recent.last;
    final elapsed = DateTime.now().difference(lastAttempt);
    final remaining = cooldownDuration.inSeconds - elapsed.inSeconds;

    return remaining > 0 ? remaining : 0;
  }

  /// Checks if user has exceeded the 3 resends per hour limit
  static bool hasExceededHourlyLimit(String email) {
    final recent = _getRecentAttempts(email);
    return recent.length >= maxResendsPerHour;
  }

  /// Returns remaining time (in minutes) until the oldest attempt in the window expires
  static int getMinutesUntilNextAvailableSlot(String email) {
    final recent = _getRecentAttempts(email);
    if (recent.isEmpty || recent.length < maxResendsPerHour) return 0;

    final oldestAttemptInWindow = recent.first;
    final elapsed = DateTime.now().difference(oldestAttemptInWindow);
    final remainingMinutes = (windowDuration.inMinutes - elapsed.inMinutes);

    return remainingMinutes > 0 ? remainingMinutes : 1;
  }

  /// Records a new resend attempt if permitted. Throws an error message if blocked.
  static void recordResendAttempt(String email) {
    final cleanEmail = email.trim().toLowerCase();

    // 1. Check 60s cooldown
    final cooldown = getRemainingCooldownSeconds(cleanEmail);
    if (cooldown > 0) {
      throw 'Please wait $cooldown second(s) before requesting another code.';
    }

    // 2. Check 3 per hour limit
    if (hasExceededHourlyLimit(cleanEmail)) {
      final mins = getMinutesUntilNextAvailableSlot(cleanEmail);
      throw 'Rate limit reached: Maximum $maxResendsPerHour resend requests per hour. Please try again in ~$mins minute(s).';
    }

    // Record the timestamp
    final history = _resendHistory.putIfAbsent(cleanEmail, () => []);
    history.add(DateTime.now());
  }

  // ===========================================================================
  // ACTIVE OTP TRACKING (PASSWORD RECOVERY & SIGNUP)
  // ===========================================================================

  /// Records that a password recovery OTP was requested for this email
  static void recordRecoveryRequest(String email) {
    final cleanEmail = email.trim().toLowerCase();
    _activeRecoveryRequests[cleanEmail] = DateTime.now();
  }

  /// Checks if there is an unexpired recovery OTP active for this email (within 1 hour)
  static bool hasActiveRecovery(String email) {
    final cleanEmail = email.trim().toLowerCase();
    final timestamp = _activeRecoveryRequests[cleanEmail];
    if (timestamp == null) return false;

    final isStillValid = DateTime.now().difference(timestamp) < otpValidityDuration;
    if (!isStillValid) {
      _activeRecoveryRequests.remove(cleanEmail);
      return false;
    }
    return true;
  }

  /// Clears recovery state when password is reset successfully
  static void clearRecovery(String email) {
    _activeRecoveryRequests.remove(email.trim().toLowerCase());
  }

  /// Records that a signup confirmation OTP was requested for this email
  static void recordSignupRequest(String email) {
    final cleanEmail = email.trim().toLowerCase();
    _activeSignupRequests[cleanEmail] = DateTime.now();
  }

  /// Checks if there is an unexpired signup OTP active for this email
  static bool hasActiveSignup(String email) {
    final cleanEmail = email.trim().toLowerCase();
    final timestamp = _activeSignupRequests[cleanEmail];
    if (timestamp == null) return false;

    final isStillValid = DateTime.now().difference(timestamp) < otpValidityDuration;
    if (!isStillValid) {
      _activeSignupRequests.remove(cleanEmail);
      return false;
    }
    return true;
  }

  /// Clears rate limit data when account is successfully verified
  static void clearHistory(String email) {
    final clean = email.trim().toLowerCase();
    _resendHistory.remove(clean);
    _activeSignupRequests.remove(clean);
    _activeRecoveryRequests.remove(clean);
  }
}