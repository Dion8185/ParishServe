import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/colors.dart';
import '../../services/auth_service.dart';
import '../../services/otp_rate_limiter.dart';

void showForgotPasswordDialog(
    BuildContext context, {
      String? initialIdentifier,
      int initialStep = 0,
    }) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _ForgotPasswordDialog(
      initialIdentifier: initialIdentifier,
      initialStep: initialStep,
    ),
  );
}

class _ForgotPasswordDialog extends StatefulWidget {
  final String? initialIdentifier;
  final int initialStep;

  const _ForgotPasswordDialog({
    this.initialIdentifier,
    this.initialStep = 0,
  });

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  final _step1FormKey = GlobalKey<FormState>();
  final _step2FormKey = GlobalKey<FormState>();
  final _step3FormKey = GlobalKey<FormState>();

  final _identifierController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // 3-Step Sequence:
  // 0 = Request Code (Username/Email)
  // 1 = Enter 6-Digit OTP Only (No login, stays in modal)
  // 2 = Set New Password & Confirm Password
  int _currentStep = 0;

  String _resolvedEmail = '';
  bool _isLoading = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;
  String? _infoBanner;

  Timer? _cooldownTimer;
  int _cooldownSeconds = 0;

  static const List<String> _predictableSequences = [
    '123', '234', '345', '456', '567', '678', '789',
    'abc', 'bcd', 'cde', 'def', 'qwe', 'wer', 'ert', 'rty',
    'asd', 'sdf', 'dfg', 'zxc', 'xcv',
    'password', 'admin', 'parish',
  ];

  @override
  void initState() {
    super.initState();

    if (widget.initialIdentifier != null && widget.initialIdentifier!.isNotEmpty) {
      _identifierController.text = widget.initialIdentifier!;
      if (widget.initialStep > 0) {
        _currentStep = widget.initialStep;
        _resolveAndSync(widget.initialIdentifier!);
      }
    }

    _newPasswordController.addListener(() => setState(() {}));
    _confirmPasswordController.addListener(() => setState(() {}));
  }

  Future<void> _resolveAndSync(String identifier) async {
    try {
      final email = await AuthService.resolveIdentifierToEmail(identifier);
      if (!mounted) return;
      setState(() {
        _resolvedEmail = email;
      });
      _syncCooldown(email);
    } catch (_) {}
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _identifierController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();

    // If dialog was closed before completing recovery, clean up the quarantined session
    AuthService.cancelPasswordRecovery();

    super.dispose();
  }

  void _syncCooldown(String email) {
    final remaining = OtpRateLimiter.getRemainingCooldownSeconds(email);
    setState(() {
      _cooldownSeconds = remaining;
    });

    if (_cooldownSeconds > 0) {
      _startCooldownTimer();
    }
  }

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_cooldownSeconds > 1) {
          _cooldownSeconds--;
        } else {
          _cooldownSeconds = 0;
          timer.cancel();
        }
      });
    });
  }

  // ===========================================================================
  // Password Strength Getters
  // ===========================================================================

  bool get _hasMinRealLength => _newPasswordController.text.replaceAll(' ', '').length >= 8;
  bool get _hasNoOuterSpaces =>
      _newPasswordController.text.isNotEmpty &&
          !_newPasswordController.text.startsWith(' ') &&
          !_newPasswordController.text.endsWith(' ');
  bool get _hasUppercase => RegExp(r'[A-Z]').hasMatch(_newPasswordController.text);
  bool get _hasSpecialChar =>
      RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=\[\]\\/~`]').hasMatch(_newPasswordController.text);
  bool get _hasNumber => RegExp(r'[0-9]').hasMatch(_newPasswordController.text);
  bool get _isNotPredictable {
    final lower = _newPasswordController.text.toLowerCase();
    for (final seq in _predictableSequences) {
      if (lower.contains(seq)) return false;
    }
    return true;
  }

  int get _strengthScore {
    final text = _newPasswordController.text;
    final nonSpaceLength = text.replaceAll(' ', '').length;
    if (nonSpaceLength == 0) return 0;

    int score = 0;
    if (_hasMinRealLength && _hasNoOuterSpaces) score++;
    if (_hasUppercase) score++;
    if (_hasSpecialChar) score++;
    if (_hasNumber) score++;

    if (!_isNotPredictable || nonSpaceLength < 10) {
      if (score > 2) score = 2;
    }

    return score;
  }

  // ===========================================================================
  // Step 1: Send Recovery Code
  // ===========================================================================

  Future<void> _handleRequestCode() async {
    setState(() {
      _errorMessage = null;
      _infoBanner = null;
    });

    if (!_step1FormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = await AuthService.resolveIdentifierToEmail(_identifierController.text.trim());
      final remaining = OtpRateLimiter.getRemainingCooldownSeconds(email);
      final hasActiveCode = OtpRateLimiter.hasActiveRecovery(email);

      // Block duplicate dispatch if an active recovery code is running
      if (remaining > 0 || hasActiveCode) {
        if (!mounted) return;
        setState(() {
          _resolvedEmail = email;
          _currentStep = 1;
          _isLoading = false;
          _infoBanner = 'An active recovery code was already sent to this account. Enter the 6-digit code below.';
        });
        _syncCooldown(email);
        return;
      }

      await AuthService.sendPasswordResetEmail(email);

      if (!mounted) return;

      setState(() {
        _resolvedEmail = email;
        _currentStep = 1;
        _isLoading = false;
        _infoBanner = null;
      });

      _syncCooldown(email);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  // ===========================================================================
  // Step 2: Resend Code Action
  // ===========================================================================

  Future<void> _handleResendCode() async {
    setState(() {
      _errorMessage = null;
      _infoBanner = null;
      _isLoading = true;
    });

    try {
      await AuthService.sendPasswordResetEmail(_resolvedEmail);

      if (!mounted) return;

      final remainingAttempts = OtpRateLimiter.getRemainingAttempts(_resolvedEmail);

      setState(() {
        _isLoading = false;
        _infoBanner = 'A fresh recovery code was sent. ($remainingAttempts of ${OtpRateLimiter.maxResendsPerHour} retries left this hour).';
      });

      _syncCooldown(_resolvedEmail);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Recovery code sent. ($remainingAttempts of ${OtpRateLimiter.maxResendsPerHour} retries remaining this hour).'),
          backgroundColor: ParishColors.oliveGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  // ===========================================================================
  // Step 2: Verify Recovery OTP Code Only (No Login, Advances to Step 3)
  // ===========================================================================

  Future<void> _handleVerifyOtp() async {
    setState(() {
      _errorMessage = null;
      _infoBanner = null;
    });

    if (!_step2FormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Verifies OTP and locks session in quarantine (AuthGate will NOT route to dashboard)
      await AuthService.verifyRecoveryOtp(
        email: _resolvedEmail,
        token: _otpController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        _currentStep = 2; // Advance strictly to Step 3 (Create New Password)
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  // ===========================================================================
  // Step 3: Complete Password Reset (Terminates Session & Returns to Login)
  // ===========================================================================

  Future<void> _handleCompleteReset() async {
    setState(() => _errorMessage = null);
    if (!_step3FormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Updates password in auth.users and public.users, signs out, and resets quarantine
      await AuthService.completePasswordReset(
        email: _resolvedEmail,
        newPassword: _newPasswordController.text,
      );

      if (!mounted) return;

      Navigator.pop(context); // Close recovery dialog

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password successfully changed! Please log in with your new password.'),
          backgroundColor: ParishColors.oliveGreen,
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textDarkColor = ParishColors.textDark;
    final textMutedColor = ParishColors.textMuted;
    final borderGreyColor = ParishColors.borderGrey;

    String headerTitle;
    String headerSubtitle;

    if (_currentStep == 0) {
      headerTitle = 'Password Recovery';
      headerSubtitle = 'Step 1 of 3: Request Recovery Code';
    } else if (_currentStep == 1) {
      headerTitle = 'Enter Verification Code';
      headerSubtitle = 'Step 2 of 3: Verify 6-Digit Code';
    } else {
      headerTitle = 'Create New Password';
      headerSubtitle = 'Step 3 of 3: Set & Confirm Password';
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      backgroundColor: ParishColors.cardWhite,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: double.maxFinite,
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 720),
        child: Column(
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: BoxDecoration(
                color: ParishColors.marianBlueSurface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                border: Border(bottom: BorderSide(color: borderGreyColor)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: ParishColors.marianBlue,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _currentStep == 0
                          ? Icons.lock_reset
                          : (_currentStep == 1 ? Icons.mark_email_read_outlined : Icons.vpn_key_outlined),
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          headerTitle,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textDarkColor,
                          ),
                        ),
                        Text(
                          headerSubtitle,
                          style: TextStyle(fontSize: 12, color: textMutedColor),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Modal Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_errorMessage != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: ParishColors.mercyRedSurface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: ParishColors.mercyRed),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: ParishColors.mercyRed, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: ParishColors.mercyRed),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (_infoBanner != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: ParishColors.marianBlueSurface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: ParishColors.marianBlue.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: ParishColors.marianBlue, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _infoBanner!,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textDarkColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (_currentStep == 0)
                      _buildStep1Form()
                    else if (_currentStep == 1)
                      _buildStep2Form()
                    else
                      _buildStep3Form(),
                  ],
                ),
              ),
            ),

            // Modal Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: ParishColors.cardWhite,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
                border: Border(top: BorderSide(color: borderGreyColor)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                      if (_currentStep == 1) {
                        setState(() {
                          _currentStep = 0;
                          _errorMessage = null;
                          _infoBanner = null;
                        });
                      } else {
                        Navigator.pop(context);
                      }
                    },
                    child: Text(
                      _currentStep == 1 ? 'Change Account' : 'Cancel',
                      style: TextStyle(fontSize: 14, color: textMutedColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 46,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ParishColors.marianBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                      ),
                      onPressed: _isLoading ? null : _handleActionButton,
                      icon: _isLoading
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.arrow_forward, size: 18),
                      label: Text(
                        _isLoading ? 'Processing...' : _actionButtonLabel,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleActionButton() {
    if (_currentStep == 0) {
      _handleRequestCode();
    } else if (_currentStep == 1) {
      _handleVerifyOtp();
    } else {
      _handleCompleteReset();
    }
  }

  String get _actionButtonLabel {
    if (_currentStep == 0) return 'Send Recovery Code';
    if (_currentStep == 1) return 'Verify Code';
    return 'Save & Reset Password';
  }

  // ---------------------------------------------------------------------------
  // Step 1: Identifier Input Form
  // ---------------------------------------------------------------------------
  Widget _buildStep1Form() {
    return Form(
      key: _step1FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trouble signing in?',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ParishColors.textDark),
          ),
          const SizedBox(height: 6),
          Text(
            'Enter your username or registered parish email below. If an active recovery code was already requested, you will automatically proceed to the code verification screen.',
            style: TextStyle(fontSize: 13, color: ParishColors.textMuted, height: 1.4),
          ),
          const SizedBox(height: 20),

          Text(
            'Username or Email Address *',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ParishColors.textDark),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _identifierController,
            style: const TextStyle(fontSize: 14),
            decoration: _inputDecoration(
              hint: 'e.g. secretary or name@email.com',
              prefixIcon: const Icon(Icons.person_outline, color: ParishColors.marianBlue),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Please enter your username or email address.';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 2: Code Verification ONLY with Rate Limit Quota Display
  // ---------------------------------------------------------------------------
  Widget _buildStep2Form() {
    final hasHourlyLimit = OtpRateLimiter.hasExceededHourlyLimit(_resolvedEmail);
    final remainingAttempts = OtpRateLimiter.getRemainingAttempts(_resolvedEmail);
    final minutesWait = OtpRateLimiter.getMinutesUntilNextAvailableSlot(_resolvedEmail);

    return Form(
      key: _step2FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ParishColors.marianBlueSurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.mail_outline, size: 20, color: ParishColors.marianBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Recovery code dispatched to: $_resolvedEmail',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: ParishColors.marianBlue),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'Enter 6-Digit Recovery Code *',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ParishColors.textDark),
          ),
          const SizedBox(height: 4),
          Text(
            'Please check your email inbox and enter the 6-digit verification code below.',
            style: TextStyle(fontSize: 12.5, color: ParishColors.textMuted),
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 8),
            decoration: _inputDecoration(hint: '000000').copyWith(counterText: ''),
            validator: (v) {
              if (v == null || v.trim().length < 6) {
                return 'Please enter the full 6-digit recovery code.';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Cooldown Timer and Hourly Rate Limit Quota Display
          Center(
            child: hasHourlyLimit
                ? Column(
              children: [
                const Text(
                  'Hourly rate limit reached (0 of 3 retries remaining).',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ParishColors.mercyRed),
                ),
                const SizedBox(height: 2),
                Text(
                  'Please try again in ~$minutesWait minute(s) or use the code in your email.',
                  style: TextStyle(fontSize: 11.5, color: ParishColors.textMuted),
                ),
              ],
            )
                : Column(
              children: [
                if (_cooldownSeconds > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: ParishColors.backgroundLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: ParishColors.borderGrey),
                    ),
                    child: Text(
                      'Resend code in ${_cooldownSeconds}s',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: ParishColors.textMuted),
                    ),
                  )
                else
                  TextButton.icon(
                    onPressed: _isLoading ? null : _handleResendCode,
                    icon: const Icon(Icons.refresh, size: 16, color: ParishColors.marianBlue),
                    label: const Text(
                      'Request New Code',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ParishColors.marianBlue),
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  'Retries remaining: $remainingAttempts of ${OtpRateLimiter.maxResendsPerHour} this hour',
                  style: TextStyle(fontSize: 11, color: ParishColors.textMuted, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 3: New Password & Confirmation Form
  // ---------------------------------------------------------------------------
  Widget _buildStep3Form() {
    return Form(
      key: _step3FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ParishColors.oliveGreenSurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle_outline, size: 20, color: ParishColors.oliveGreen),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Code verified! You may now create a new password.',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: ParishColors.oliveGreen),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          Text(
            'New Password *',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ParishColors.textDark),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _newPasswordController,
            obscureText: _obscureNewPassword,
            style: const TextStyle(fontSize: 14),
            decoration: _inputDecoration(
              hint: 'Min. 8 chars with uppercase & symbol',
              prefixIcon: const Icon(Icons.lock_outline, color: ParishColors.marianBlue),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureNewPassword ? Icons.visibility_off : Icons.visibility,
                  size: 20,
                  color: ParishColors.textMuted,
                ),
                onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'New password is required.';
              if (v.startsWith(' ') || v.endsWith(' ')) return 'Password cannot start or end with spaces.';
              if (v.replaceAll(' ', '').length < 8) return 'Must contain at least 8 non-space characters.';
              if (!RegExp(r'[A-Z]').hasMatch(v)) return 'Must include at least one uppercase letter (A-Z).';
              if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=\[\]\\/~`]').hasMatch(v)) {
                return 'Must include at least one special character.';
              }
              if (!RegExp(r'[0-9]').hasMatch(v)) return 'Must include at least one number (0-9).';
              if (!_isNotPredictable) return 'Password is too predictable (avoid 123, asd, passwords).';
              return null;
            },
          ),
          const SizedBox(height: 10),

          // Live Strength Indicator
          _buildPasswordStrengthWidget(),
          const SizedBox(height: 16),

          Text(
            'Confirm New Password *',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ParishColors.textDark),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            style: const TextStyle(fontSize: 14),
            decoration: _inputDecoration(
              hint: 'Re-enter your new password exactly',
              prefixIcon: const Icon(Icons.lock_outline, color: ParishColors.marianBlue),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                  size: 20,
                  color: ParishColors.textMuted,
                ),
                onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Please confirm your new password.';
              if (v != _newPasswordController.text) return 'Passwords do not match.';
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordStrengthWidget() {
    final text = _newPasswordController.text;
    if (text.isEmpty) return const SizedBox.shrink();

    final score = _strengthScore;
    Color strengthColor = ParishColors.mercyRed;
    String strengthLabel = 'Weak';

    if (score == 2) {
      strengthColor = Colors.orange;
      strengthLabel = 'Fair';
    } else if (score == 3) {
      strengthColor = ParishColors.goldAccent;
      strengthLabel = 'Good';
    } else if (score >= 4) {
      strengthColor = ParishColors.oliveGreen;
      strengthLabel = 'Strong';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ParishColors.backgroundLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ParishColors.borderGrey.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Password Strength:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
              Text(strengthLabel, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: strengthColor)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (score / 4.0).clamp(0.2, 1.0),
              minHeight: 5,
              backgroundColor: ParishColors.borderGrey.withOpacity(0.3),
              valueColor: AlwaysStoppedAnimation<Color>(strengthColor),
            ),
          ),
          const SizedBox(height: 8),

          _buildChecklistItem('At least 8 non-space characters', _hasMinRealLength && _hasNoOuterSpaces),
          _buildChecklistItem('At least 1 uppercase letter (A-Z)', _hasUppercase),
          _buildChecklistItem('At least 1 special character (!@#\$...)', _hasSpecialChar),
          _buildChecklistItem('At least 1 number (0-9)', _hasNumber),
          _buildChecklistItem('No predictable sequences (123, asd)', _isNotPredictable),
        ],
      ),
    );
  }

  Widget _buildChecklistItem(String label, bool isSatisfied) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2.0),
      child: Row(
        children: [
          Icon(
            isSatisfied ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 13,
            color: isSatisfied ? ParishColors.oliveGreen : ParishColors.textMuted.withOpacity(0.6),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSatisfied ? FontWeight.bold : FontWeight.normal,
              color: isSatisfied ? ParishColors.textDark : ParishColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({String hint = '', Widget? prefixIcon, Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint.isNotEmpty ? hint : null,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: ParishColors.backgroundLight,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ParishColors.borderGrey)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ParishColors.borderGrey)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: ParishColors.marianBlue, width: 1.8)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: ParishColors.mercyRed, width: 1.2)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: ParishColors.mercyRed, width: 1.8)),
      errorStyle: const TextStyle(fontSize: 11.5, color: ParishColors.mercyRed, fontWeight: FontWeight.w500),
    );
  }
}