import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/colors.dart';
import '../../navigation/presentation/main_navigation_shell.dart';
import '../services/auth_service.dart';

class ParishionerRegisterView extends StatefulWidget {
  const ParishionerRegisterView({super.key});

  @override
  State<ParishionerRegisterView> createState() => _ParishionerRegisterViewState();
}

class _ParishionerRegisterViewState extends State<ParishionerRegisterView> {
  final _formKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _otpController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _isAwaitingVerification = false;
  String? _errorMessage;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = 'Passwords do not match. Please re-enter your password.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await AuthService.registerParishioner(
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        username: _usernameController.text,
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (!mounted) return;

      if (result['requiresVerification'] == true) {
        // Switch view to 6-digit OTP entry screen
        setState(() {
          _isAwaitingVerification = true;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification code sent! Please check your email inbox (and spam folder).'),
            backgroundColor: ParishColors.marianBlue,
            duration: Duration(seconds: 5),
          ),
        );
      } else {
        final newUser = result['user'];
        _navigateToDashboard(newUser);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _handleVerifyOtp() async {
    setState(() => _errorMessage = null);
    final token = _otpController.text.trim();

    if (token.length < 6) {
      setState(() => _errorMessage = 'Please enter the full 6-digit verification code.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final verifiedUser = await AuthService.verifyEmailOtp(
        email: _emailController.text,
        token: token,
      );

      if (!mounted) return;
      _navigateToDashboard(verifiedUser);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _handleResendOtp() async {
    try {
      await AuthService.resendVerificationEmail(_emailController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A new verification code has been sent to your email.'),
          backgroundColor: ParishColors.oliveGreen,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error resending code: $e'), backgroundColor: ParishColors.mercyRed),
      );
    }
  }

  void _navigateToDashboard(dynamic user) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Welcome to ParishServe, ${user.firstName}! Account successfully verified.'),
        backgroundColor: ParishColors.oliveGreen,
        duration: const Duration(seconds: 4),
      ),
    );

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => MainNavigationShell(currentUser: user),
      ),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textDarkColor = ParishColors.textDark;
    final textMutedColor = ParishColors.textMuted;
    final cardWhiteColor = ParishColors.cardWhite;
    final borderGreyColor = ParishColors.borderGrey;

    return Scaffold(
      backgroundColor: ParishColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: cardWhiteColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: ParishColors.marianBlue, size: 26),
          onPressed: _isLoading ? null : () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isAwaitingVerification ? 'Email Verification' : 'Parishioner Registration',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDarkColor),
            ),
            Text(
              'St. John Paul II Parish Client Portal',
              style: TextStyle(fontSize: 12, color: textMutedColor),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: ParishColors.marianBlueSurface,
                      shape: BoxShape.circle,
                      border: Border.all(color: ParishColors.goldAccent, width: 2.5),
                    ),
                    child: Icon(
                      _isAwaitingVerification ? Icons.mark_email_read_outlined : Icons.person_add_alt_1,
                      size: 36,
                      color: ParishColors.marianBlue,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Text(
                    _isAwaitingVerification ? 'Check Your Email' : 'Create Your Parishioner Account',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: ParishColors.marianBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isAwaitingVerification
                        ? 'We sent a verification link and 6-digit code to\n${_emailController.text}'
                        : 'Book sacrament appointments, request mass intentions, and track your contributions.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: textMutedColor, height: 1.4),
                  ),
                  const SizedBox(height: 20),

                  // Form Container Card
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: cardWhiteColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderGreyColor, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: _isAwaitingVerification
                        ? Column(
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
                        _buildFieldLabel('Enter 6-Digit Verification Code *'),
                        TextFormField(
                          controller: _otpController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
                          decoration: _inputDecoration(hint: '000000').copyWith(counterText: ''),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ParishColors.marianBlue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _isLoading ? null : _handleVerifyOtp,
                            child: _isLoading
                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                : const Text('VERIFY & CONTINUE', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Center(
                          child: TextButton(
                            onPressed: _isLoading ? null : _handleResendOtp,
                            child: const Text(
                              'Didn\'t receive a code? Resend email',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ParishColors.marianBlue),
                            ),
                          ),
                        ),
                      ],
                    )
                        : Form(
                      key: _formKey,
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
                                crossAxisAlignment: CrossAxisAlignment.start,
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

                          // 1. Legal Name Fields
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildFieldLabel('First Name *'),
                                    TextFormField(
                                      controller: _firstNameController,
                                      textCapitalization: TextCapitalization.words,
                                      validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
                                      style: TextStyle(fontSize: 14, color: textDarkColor),
                                      decoration: _inputDecoration(hint: 'e.g. Maria'),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildFieldLabel('Last Name *'),
                                    TextFormField(
                                      controller: _lastNameController,
                                      textCapitalization: TextCapitalization.words,
                                      validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
                                      style: TextStyle(fontSize: 14, color: textDarkColor),
                                      decoration: _inputDecoration(hint: 'e.g. Santos'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // 2. Username
                          _buildFieldLabel('Username *'),
                          TextFormField(
                            controller: _usernameController,
                            inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
                            validator: (v) => (v?.trim().length ?? 0) < 3 ? 'Min 3 characters' : null,
                            style: TextStyle(fontSize: 14, color: textDarkColor),
                            decoration: _inputDecoration(
                              hint: 'e.g. mariasantos',
                              prefixIcon: const Icon(Icons.alternate_email, size: 18, color: ParishColors.marianBlue),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // 3. Email
                          _buildFieldLabel('Email Address *'),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) => !(v?.contains('@') ?? false) ? 'Valid email required' : null,
                            style: TextStyle(fontSize: 14, color: textDarkColor),
                            decoration: _inputDecoration(
                              hint: 'name@email.com',
                              prefixIcon: const Icon(Icons.email_outlined, size: 18, color: ParishColors.marianBlue),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // 4. Password
                          _buildFieldLabel('Password *'),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            validator: (v) => (v?.length ?? 0) < 6 ? 'Min 6 characters' : null,
                            style: TextStyle(fontSize: 14, color: textDarkColor),
                            decoration: _inputDecoration(
                              hint: 'Minimum 6 characters',
                              prefixIcon: const Icon(Icons.lock_outline, size: 18, color: ParishColors.marianBlue),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 20, color: textMutedColor),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // 5. Confirm Password
                          _buildFieldLabel('Confirm Password *'),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            validator: (v) => v != _passwordController.text ? 'Passwords do not match' : null,
                            style: TextStyle(fontSize: 14, color: textDarkColor),
                            decoration: _inputDecoration(
                              hint: 'Re-enter your password',
                              prefixIcon: const Icon(Icons.lock_outline, size: 18, color: ParishColors.marianBlue),
                              suffixIcon: IconButton(
                                icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility, size: 20, color: textMutedColor),
                                onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Data Privacy Notice
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: ParishColors.backgroundLight,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: borderGreyColor),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.verified_user_outlined, size: 18, color: ParishColors.oliveGreen),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Protected under RA 10173 and Catholic Archival Standards. A verification code will be sent to your email.',
                                    style: TextStyle(fontSize: 11, color: textMutedColor, height: 1.35),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Submit Button
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ParishColors.marianBlue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: _isLoading ? null : _handleRegister,
                              child: _isLoading
                                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                  : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.mark_email_unread_outlined, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'REGISTER & SEND CODE',
                                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  if (!_isAwaitingVerification) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Already have an account?', style: TextStyle(fontSize: 13, color: textMutedColor)),
                        TextButton(
                          onPressed: _isLoading ? null : () => Navigator.pop(context),
                          child: const Text(
                            'Sign In here',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ParishColors.marianBlue),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),

                  const Text(
                    'TOTUS TUUS',
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontStyle: FontStyle.italic,
                      color: ParishColors.goldAccent,
                      letterSpacing: 2.0,
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

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text(
        label,
        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: ParishColors.textDark),
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint, Widget? prefixIcon, Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: ParishColors.backgroundLight,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ParishColors.borderGrey)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ParishColors.borderGrey)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: ParishColors.marianBlue, width: 1.8)),
    );
  }
}