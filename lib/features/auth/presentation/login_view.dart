import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../services/auth_service.dart';
import 'auth_gate.dart';
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
        _showErrorDialog(
          'Invalid credentials. Please verify your email/username and password.',
        );
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthGate()),
              (route) => false,
        );
      }
    } on EmailNotConfirmedException catch (e) {
      if (!mounted) return;

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: ParishColors.cardWhite,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: ParishColors.mercyRedSurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: ParishColors.mercyRed,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Sign In Error',
              style: TextStyle(
                fontFamily: 'serif',
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: ParishColors.textDark,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(
            fontSize: 13.5,
            color: ParishColors.textDark,
            height: 1.4,
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ParishColors.marianBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Try Again',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParishLogo({double size = 42}) {
    const candidatePaths = [
      'images/logo-jp2.png',
      'images/logo.png',
      'images/jp2-logo.png',
      'assets/images/logo-jp2.png',
      'assets/images/jp2-logo.png',
    ];
    return _buildImageWithFallback(candidatePaths, 0, size);
  }

  Widget _buildImageWithFallback(List<String> paths, int index, double size) {
    if (index >= paths.length) {
      return Container(
        width: size,
        height: size,
        color: ParishColors.marianBlueSurface,
        child: Icon(
          Icons.church_rounded,
          size: size * 0.62,
          color: ParishColors.marianBlue,
        ),
      );
    }
    return Image.asset(
      paths[index],
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return _buildImageWithFallback(paths, index + 1, size);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 680;

    return Scaffold(
      backgroundColor: ParishColors.backgroundLight,
      body: Column(
        children: [
          // ===================================================================
          // 1. CHANCERY TOP HEADER BAR (Matching MainNavigationShell)
          // ===================================================================
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: ParishColors.cardWhite,
              border: Border(
                bottom: BorderSide(
                  color: ParishColors.goldAccent.withOpacity(0.85),
                  width: 1.5,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 16.0 : 36.0,
              vertical: 12.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Upper Left: Official Crest + Typography
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        color: ParishColors.cardWhite,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: ParishColors.goldAccent,
                          width: 1.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: ParishColors.marianBlue.withOpacity(0.10),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(9.5),
                        child: _buildParishLogo(size: 38),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'St. John Paul II Parish',
                          style: TextStyle(
                            fontFamily: 'serif',
                            fontSize: 16.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
                            color: ParishColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Diocese of San Pablo • Labuin, Sta. Cruz, Laguna',
                          style: TextStyle(
                            fontSize: isCompact ? 10.5 : 11.5,
                            fontWeight: FontWeight.w500,
                            color: ParishColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ===================================================================
          // 2. MAIN BODY (With Clean Stack Background & Centered Login Card)
          // ===================================================================
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background Church Watermark 1 (jp2-bg1)
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.07,
                    child: Image.asset(
                      'images/jp2-bg2.png',
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),

                // Center Scrollable View
                SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompact ? 16.0 : 24.0,
                        vertical: 24.0,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 540),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Main Login Card
                            Container(
                              decoration: BoxDecoration(
                                color: ParishColors.cardWhite,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: ParishColors.borderGrey,
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF18334D)
                                        .withOpacity(0.06),
                                    blurRadius: 22,
                                    offset: const Offset(0, 8),
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.02),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.stretch,
                                  children: [
                                    // -----------------------------------------
                                    // Parish Branding Banner
                                    // -----------------------------------------
                                    Container(
                                      height: 155,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: ParishColors.marianBlueSurface,
                                      ),
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Positioned.fill(
                                            child: Image.asset(
                                              'images/jp2-bg.png',
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                              const SizedBox.shrink(),
                                            ),
                                          ),
                                          Positioned.fill(
                                            child: Container(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                  colors: [
                                                    ParishColors.cardWhite
                                                        .withOpacity(0.72),
                                                    ParishColors.cardWhite
                                                        .withOpacity(0.93),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16.0,
                                              vertical: 12.0,
                                            ),
                                            child: Column(
                                              mainAxisAlignment:
                                              MainAxisAlignment.center,
                                              children: [
                                                Container(
                                                  width: 52,
                                                  height: 52,
                                                  padding:
                                                  const EdgeInsets.all(2.5),
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color:
                                                    ParishColors.cardWhite,
                                                    border: Border.all(
                                                      color: ParishColors
                                                          .goldAccent,
                                                      width: 2.0,
                                                    ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black
                                                            .withOpacity(0.08),
                                                        blurRadius: 8,
                                                        offset:
                                                        const Offset(0, 3),
                                                      ),
                                                    ],
                                                  ),
                                                  child: ClipOval(
                                                    child: _buildParishLogo(
                                                        size: 46),
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  'St. John Paul II Parish',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontFamily: 'serif',
                                                    fontSize: 19.5,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: -0.2,
                                                    color:
                                                    ParishColors.textDark,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                                  children: [
                                                    Container(
                                                      width: 30,
                                                      height: 1,
                                                      color: ParishColors
                                                          .goldAccent,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      'ParishServe Portal',
                                                      style: TextStyle(
                                                        fontSize: 11.5,
                                                        fontWeight:
                                                        FontWeight.w700,
                                                        color: ParishColors
                                                            .marianBlue,
                                                        letterSpacing: 0.8,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      width: 30,
                                                      height: 1,
                                                      color: ParishColors
                                                          .goldAccent,
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // -----------------------------------------
                                    // Login Form Section
                                    // -----------------------------------------
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isCompact ? 20.0 : 32.0,
                                        vertical: 24.0,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          Center(
                                            child: Column(
                                              children: [
                                                Text(
                                                  'Portal Sign In',
                                                  style: TextStyle(
                                                    fontSize: 21,
                                                    fontWeight:
                                                    FontWeight.bold,
                                                    color:
                                                    ParishColors.textDark,
                                                    letterSpacing: -0.3,
                                                  ),
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  'Sign in to continue.',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color:
                                                    ParishColors.textMuted,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 20),

                                          // Field 1: Identifier
                                          _buildInputLabel(
                                            label: 'Username or Email',
                                            icon: Icons.person_outline_rounded,
                                          ),
                                          const SizedBox(height: 7),
                                          TextField(
                                            controller: _identifierController,
                                            textInputAction:
                                            TextInputAction.next,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: ParishColors.textDark,
                                            ),
                                            decoration: _fieldDecoration(
                                              hint: 'e.g. name@email.com',
                                            ),
                                          ),
                                          const SizedBox(height: 16),

                                          // Field 2: Password
                                          Row(
                                            mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                            children: [
                                              _buildInputLabel(
                                                label: 'Password',
                                                icon: Icons
                                                    .lock_outline_rounded,
                                              ),
                                              TextButton(
                                                onPressed: () =>
                                                    showForgotPasswordDialog(
                                                        context),
                                                style: TextButton.styleFrom(
                                                  padding: EdgeInsets.zero,
                                                  minimumSize: Size.zero,
                                                  tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                                ),
                                                child: Text(
                                                  'Forgot Password?',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight:
                                                    FontWeight.w700,
                                                    color:
                                                    ParishColors.marianBlue,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 7),
                                          TextField(
                                            controller: _passwordController,
                                            obscureText: _obscurePassword,
                                            textInputAction:
                                            TextInputAction.done,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: ParishColors.textDark,
                                            ),
                                            onSubmitted: (_) => _handleLogin(),
                                            decoration: _fieldDecoration(
                                              hint: 'Enter your password',
                                              suffixIcon: IconButton(
                                                icon: Icon(
                                                  _obscurePassword
                                                      ? Icons
                                                      .visibility_off_outlined
                                                      : Icons
                                                      .visibility_outlined,
                                                  color:
                                                  ParishColors.textMuted,
                                                  size: 19,
                                                ),
                                                onPressed: () => setState(
                                                      () => _obscurePassword =
                                                  !_obscurePassword,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 22),

                                          // Primary Action: Sign In →
                                          SizedBox(
                                            width: double.infinity,
                                            height: 48,
                                            child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                ParishColors.marianBlue,
                                                foregroundColor: Colors.white,
                                                elevation: 0,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                  BorderRadius.circular(10),
                                                ),
                                              ),
                                              onPressed: _isLoading
                                                  ? null
                                                  : _handleLogin,
                                              child: _isLoading
                                                  ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                CircularProgressIndicator(
                                                  color: Colors.white,
                                                  strokeWidth: 2.2,
                                                ),
                                              )
                                                  : Row(
                                                mainAxisAlignment:
                                                MainAxisAlignment
                                                    .center,
                                                children: const [
                                                  Text(
                                                    'Sign In',
                                                    style: TextStyle(
                                                      fontSize: 14.5,
                                                      fontWeight:
                                                      FontWeight
                                                          .bold,
                                                      letterSpacing:
                                                      0.3,
                                                    ),
                                                  ),
                                                  SizedBox(width: 8),
                                                  Icon(
                                                    Icons
                                                        .arrow_forward_rounded,
                                                    size: 16,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 14),

                                          // "or" Divider
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Divider(
                                                  color:
                                                  ParishColors.borderGrey,
                                                  thickness: 1.0,
                                                ),
                                              ),
                                              Padding(
                                                padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 12.0),
                                                child: Text(
                                                  'or',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color:
                                                    ParishColors.textMuted,
                                                    fontWeight:
                                                    FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                child: Divider(
                                                  color:
                                                  ParishColors.borderGrey,
                                                  thickness: 1.0,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 14),

                                          // Secondary Action: Register Account
                                          SizedBox(
                                            width: double.infinity,
                                            height: 46,
                                            child: OutlinedButton.icon(
                                              style:
                                              OutlinedButton.styleFrom(
                                                backgroundColor:
                                                ParishColors.cardWhite,
                                                side: BorderSide(
                                                  color: ParishColors
                                                      .marianBlue
                                                      .withOpacity(0.55),
                                                  width: 1.2,
                                                ),
                                                foregroundColor:
                                                ParishColors.marianBlue,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                  BorderRadius.circular(10),
                                                ),
                                              ),
                                              onPressed: _isLoading
                                                  ? null
                                                  : () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                    const ParishionerRegisterView(),
                                                  ),
                                                );
                                              },
                                              icon: const Icon(
                                                Icons.person_add_alt_outlined,
                                                size: 18,
                                              ),
                                              label: const Text(
                                                'New Parishioner? Register Account',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // =================================================
                            // 3. FOOTER ASSISTANCE NOTICE
                            // =================================================
                            InkWell(
                              onTap: () => showLoginHelpDialog(context),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.headset_mic_outlined,
                                      size: 16,
                                      color: ParishColors.marianBlue,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Need assistance? ',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: ParishColors.textMuted,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      'Contact the Parish Office',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: ParishColors.marianBlue,
                                        decoration: TextDecoration.underline,
                                        decorationColor:
                                        ParishColors.marianBlue,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputLabel({required String label, required IconData icon}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: ParishColors.marianBlue),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: ParishColors.textDark,
          ),
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration({
    required String hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontSize: 13.5,
        color: ParishColors.textMuted.withOpacity(0.65),
        fontWeight: FontWeight.normal,
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: ParishColors.backgroundLight,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        vertical: 13,
        horizontal: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: ParishColors.borderGrey, width: 1.0),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: ParishColors.borderGrey, width: 1.0),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: ParishColors.marianBlue, width: 1.6),
      ),
    );
  }
}