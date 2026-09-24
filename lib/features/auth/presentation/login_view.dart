import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../services/auth_service.dart';
import 'dialogs/forgot_password_dialog.dart';
import 'dialogs/login_help_dialog.dart';
import 'otp_verification_view.dart';
import 'parishioner_register_view.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text;

    if (identifier.isEmpty || password.isEmpty) {
      _showErrorDialog('Please enter both your username/email and password.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = await AuthService.login(
        identifier: identifier,
        password: password,
      );

      if (!mounted) return;

      if (user == null) {
        _showErrorDialog('Invalid credentials. Please verify your email/username and password.');
      }
      // Note: On successful authentication, AuthGate's stream automatically detects
      // the new session and transitions to the appropriate portal.
    } on EmailNotConfirmedException catch (e) {
      if (!mounted) return;

      // Automatically route unverified accounts directly to the OTP screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpVerificationView(email: e.email),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: ParishColors.mercyRed, size: 28),
            SizedBox(width: 8),
            Text('Sign In Error', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(message, style: TextStyle(fontSize: 14, color: ParishColors.textDark)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ParishColors.marianBlue,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ParishColors.backgroundLight,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(
                      color: ParishColors.marianBlueSurface,
                      shape: BoxShape.circle,
                      border: Border.all(color: ParishColors.goldAccent, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.church, size: 48, color: ParishColors.marianBlue),
                  ),
                  const SizedBox(height: 14),

                  const Text(
                    'St. John Paul II Parish',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: ParishColors.marianBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Diocese of San Pablo • Labuin, Sta. Cruz, Laguna',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ParishColors.textMuted),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: ParishColors.goldLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: ParishColors.goldAccent, width: 1.2),
                    ),
                    child: Text(
                      'ParishServe Portal',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Form Container Card
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: ParishColors.cardWhite,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: ParishColors.borderGrey, width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Portal Sign In',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Enter your username or registered email to sign in.',
                          style: TextStyle(fontSize: 13, color: ParishColors.textMuted),
                        ),
                        const SizedBox(height: 20),

                        const Text('Username or Email', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _identifierController,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.person_outline, color: ParishColors.marianBlue),
                            hintText: 'e.g. secretary or name@email.com',
                            hintStyle: TextStyle(fontSize: 13, color: ParishColors.textMuted),
                            filled: true,
                            fillColor: ParishColors.backgroundLight,
                            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Password Label Row with "Forgot Password?" Button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            TextButton(
                              onPressed: () => showForgotPasswordDialog(context),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: ParishColors.marianBlue,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          onSubmitted: (_) => _handleLogin(),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.lock_outline, color: ParishColors.marianBlue),
                            hintText: 'Enter your password',
                            hintStyle: TextStyle(fontSize: 13, color: ParishColors.textMuted),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: ParishColors.textMuted),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            filled: true,
                            fillColor: ParishColors.backgroundLight,
                            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ParishColors.marianBlue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _isLoading ? null : _handleLogin,
                            child: _isLoading
                                ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                                : const Text(
                              'LOG IN TO PARISHSERVE',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Self-Registration for Parishioners
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: ParishColors.marianBlue, width: 1.5),
                              foregroundColor: ParishColors.marianBlue,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _isLoading
                                ? null
                                : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ParishionerRegisterView(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.person_add_alt_1, size: 18),
                            label: const Text(
                              'New Parishioner? Register Account',
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.help_outline, size: 18, color: ParishColors.textMuted),
                      const SizedBox(width: 4),
                      TextButton(
                        onPressed: () => showLoginHelpDialog(context),
                        child: const Text(
                          'Need assistance logging in? Tap here',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ParishColors.marianBlue),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),
                  const Text(
                    'TOTUS TUUS',
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 13,
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
}