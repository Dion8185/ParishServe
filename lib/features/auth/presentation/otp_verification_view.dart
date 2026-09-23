import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/colors.dart';
import '../services/auth_service.dart';
import '../services/otp_rate_limiter.dart';

class OtpVerificationView extends StatefulWidget {
  final String email;

  const OtpVerificationView({super.key, required this.email});

  @override
  State<OtpVerificationView> createState() => _OtpVerificationViewState();
}

class _OtpVerificationViewState extends State<OtpVerificationView> {
  final TextEditingController _otpController = TextEditingController();
  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorMessage;
  String? _successMessage;

  Timer? _cooldownTimer;
  int _cooldownSeconds = 0;

  @override
  void initState() {
    super.initState();
    _checkCooldown();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _checkCooldown() {
    final remaining = OtpRateLimiter.getRemainingCooldownSeconds(widget.email);
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

  Future<void> _verifyOtp() async {
    setState(() {
      _errorMessage = null;
      _successMessage = null;
    });

    final token = _otpController.text.trim();
    if (token.length < 6) {
      setState(() => _errorMessage = 'Please enter the full 6-digit verification code.');
      return;
    }

    setState(() => _isVerifying = true);

    try {
      final user = await AuthService.verifyEmailOtp(
        email: widget.email,
        token: token,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Account verified! Welcome to ParishServe, ${user.firstName}.'),
          backgroundColor: ParishColors.oliveGreen,
          duration: const Duration(seconds: 3),
        ),
      );

      // Pop back to root; AuthGate will immediately detect the active session and render the portal
      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _resendOtp() async {
    setState(() {
      _errorMessage = null;
      _successMessage = null;
      _isResending = true;
    });

    try {
      await AuthService.resendVerificationEmail(widget.email);

      if (!mounted) return;

      setState(() {
        _successMessage = 'A fresh verification code has been dispatched to your email.';
        _cooldownSeconds = 60;
      });

      _startCooldownTimer();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textDarkColor = ParishColors.textDark;
    final textMutedColor = ParishColors.textMuted;
    final cardWhiteColor = ParishColors.cardWhite;
    final borderGreyColor = ParishColors.borderGrey;
    final hasHourlyLimit = OtpRateLimiter.hasExceededHourlyLimit(widget.email);

    return Scaffold(
      backgroundColor: ParishColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: cardWhiteColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: ParishColors.marianBlue, size: 26),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Email Verification',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDarkColor),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: ParishColors.marianBlueSurface,
                      shape: BoxShape.circle,
                      border: Border.all(color: ParishColors.goldAccent, width: 2.5),
                    ),
                    child: const Icon(Icons.mark_email_read_outlined, size: 38, color: ParishColors.marianBlue),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'Confirm Your Account',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: ParishColors.marianBlue,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Enter the 6-digit code sent to\n${widget.email}',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13.5, color: textMutedColor, height: 1.4),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '(If your existing code has not expired, you can enter it directly below)',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: textMutedColor),
                  ),
                  const SizedBox(height: 24),

                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: cardWhiteColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderGreyColor, width: 1.5),
                    ),
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

                        if (_successMessage != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: ParishColors.oliveGreenSurface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: ParishColors.oliveGreen),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_outline, color: ParishColors.oliveGreen, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _successMessage!,
                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: ParishColors.oliveGreen),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        Text(
                          '6-Digit Verification Code',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDarkColor),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _otpController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          textAlign: TextAlign.center,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 8),
                          decoration: InputDecoration(
                            hintText: '000000',
                            counterText: '',
                            filled: true,
                            fillColor: ParishColors.backgroundLight,
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 20),

                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ParishColors.marianBlue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _isVerifying ? null : _verifyOtp,
                            child: _isVerifying
                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                : const Text(
                              'VERIFY & CONTINUE',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Resend Section with 60s Cooldown & 3/hr Limit
                        Center(
                          child: hasHourlyLimit
                              ? Column(
                            children: [
                              Text(
                                'Hourly resend limit reached (3/hour).',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ParishColors.mercyRed),
                              ),
                              Text(
                                'Please check your inbox or wait before requesting another code.',
                                style: TextStyle(fontSize: 11, color: textMutedColor),
                              ),
                            ],
                          )
                              : _cooldownSeconds > 0
                              ? Text(
                            'Resend available in ${_cooldownSeconds}s',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textMutedColor),
                          )
                              : TextButton.icon(
                            onPressed: _isResending ? null : _resendOtp,
                            icon: const Icon(Icons.refresh, size: 16, color: ParishColors.marianBlue),
                            label: const Text(
                              'Request New Verification Code',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ParishColors.marianBlue),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Back to Sign In',
                      style: TextStyle(fontSize: 13, color: textMutedColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}