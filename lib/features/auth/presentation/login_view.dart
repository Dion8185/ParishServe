import 'dart:ui';
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
        _showErrorDialog(
          'Invalid credentials. Please verify your email/username and password.',
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: ParishColors.mercyRed, size: 28),
            const SizedBox(width: 8),
            const Text(
              'Sign In Error',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(fontSize: 14, color: ParishColors.textDark),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ParishColors.marianBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildParishLogo() {
    const candidatePaths = [
      'images/logo-jp2.png',
      'images/logo.png',
      'images/jp2-logo.png',
      'assets/images/logo-jp2.png',
      'assets/images/jp2-logo.png',
    ];
    return _buildImageWithFallback(candidatePaths, 0);
  }

  Widget _buildImageWithFallback(List<String> paths, int index) {
    if (index >= paths.length) {
      return Container(
        color: ParishColors.marianBlueSurface,
        child: Icon(
          Icons.church_rounded,
          size: 52,
          color: ParishColors.marianBlue,
        ),
      );
    }
    return Image.asset(
      paths[index],
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return _buildImageWithFallback(paths, index + 1);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 480;

    return Scaffold(
      backgroundColor: const Color(0xFF060D17),
      body: Stack(
        children: [
          // 1. Crisp, High-Definition Church Facade Background
          Positioned.fill(
            child: Image.asset(
              'images/jp2-bg.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFF071224),
              ),
            ),
          ),

          // 2. Linear Tonal Depth Overlay (Maintains vertical text readability)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF061120).withOpacity(0.55),
                    const Color(0xFF081527).withOpacity(0.35),
                    const Color(0xFF030814).withOpacity(0.70),
                    const Color(0xFF020409).withOpacity(0.92),
                  ],
                  stops: const [0.0, 0.35, 0.75, 1.0],
                ),
              ),
            ),
          ),

          // 3. True Cinematic Radial Vignette (Deepens perimeter while spotlighting center)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.18,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    const Color(0xFF030814).withOpacity(0.40),
                    const Color(0xFF02050B).withOpacity(0.82),
                    const Color(0xFF010206).withOpacity(0.96),
                  ],
                  stops: const [0.0, 0.38, 0.68, 0.88, 1.0],
                ),
              ),
            ),
          ),

          // 4. Foreground Interactive Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 18.0 : 28.0,
                  vertical: 24.0,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Elevated Parish Crest Medallion with Dual-Ring Styling
                      Container(
                        width: 110,
                        height: 110,
                        padding: const EdgeInsets.all(4.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(
                            color: ParishColors.goldAccent,
                            width: 3.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.50),
                              blurRadius: 30,
                              offset: const Offset(0, 12),
                            ),
                            BoxShadow(
                              color: ParishColors.goldAccent.withOpacity(0.38),
                              blurRadius: 20,
                              spreadRadius: 2.0,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: _buildParishLogo(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Ecclesiastical Typography Hierarchy
                      const Text(
                        'St. John Paul II Parish',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.4,
                          shadows: [
                            Shadow(
                              color: Colors.black,
                              blurRadius: 12,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Diocese of San Pablo • Labuin, Sta. Cruz, Laguna',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFFF1F5F9),
                          letterSpacing: 0.2,
                          shadows: [
                            Shadow(
                              color: Colors.black87,
                              blurRadius: 8,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Translucent Capsule Pill (Apple HIG Material Look)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F1E36).withOpacity(0.75),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: ParishColors.goldAccent.withOpacity(0.90),
                              width: 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.20),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified_outlined,
                                size: 13,
                                color: ParishColors.goldAccent,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'ParishServe Portal',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: ParishColors.goldAccent,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 22),

                      // HIG Frosted Glass Surface Card
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 18.0, sigmaY: 18.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 26,
                              vertical: 28,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.96),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.95),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.38),
                                  blurRadius: 40,
                                  offset: const Offset(0, 18),
                                ),
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.12),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Portal Sign In',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.4,
                                    color: ParishColors.textDark,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Enter your username or registered email to sign in.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: ParishColors.textMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 22),

                                // Username or Email Field
                                Text(
                                  'Username or Email',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: ParishColors.textDark,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                TextField(
                                  controller: _identifierController,
                                  textInputAction: TextInputAction.next,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600,
                                    color: ParishColors.textDark,
                                  ),
                                  decoration: InputDecoration(
                                    prefixIcon: Icon(
                                      Icons.person_outline_rounded,
                                      color: ParishColors.marianBlue,
                                      size: 20,
                                    ),
                                    hintText: 'e.g. secretary or name@email.com',
                                    hintStyle: TextStyle(
                                      fontSize: 13.5,
                                      color: ParishColors.textMuted,
                                      fontWeight: FontWeight.normal,
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAFC),
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                      horizontal: 16,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: ParishColors.borderGrey.withOpacity(0.65),
                                        width: 1.0,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: ParishColors.marianBlue,
                                        width: 1.8,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),

                                // Password Field
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Password',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: ParishColors.textDark,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => showForgotPasswordDialog(context),
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: Text(
                                        'Forgot Password?',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: ParishColors.marianBlue,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 7),
                                TextField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.done,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600,
                                    color: ParishColors.textDark,
                                  ),
                                  onSubmitted: (_) => _handleLogin(),
                                  decoration: InputDecoration(
                                    prefixIcon: Icon(
                                      Icons.lock_outline_rounded,
                                      color: ParishColors.marianBlue,
                                      size: 20,
                                    ),
                                    hintText: 'Enter your password',
                                    hintStyle: TextStyle(
                                      fontSize: 13.5,
                                      color: ParishColors.textMuted,
                                      fontWeight: FontWeight.normal,
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        color: ParishColors.textMuted,
                                        size: 20,
                                      ),
                                      onPressed: () => setState(
                                            () => _obscurePassword = !_obscurePassword,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAFC),
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                      horizontal: 16,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: ParishColors.borderGrey.withOpacity(0.65),
                                        width: 1.0,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: ParishColors.marianBlue,
                                        width: 1.8,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // Primary Button: Log In
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: ParishColors.marianBlue,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    onPressed: _isLoading ? null : _handleLogin,
                                    child: _isLoading
                                        ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.2,
                                      ),
                                    )
                                        : const Text(
                                      'LOG IN TO PARISHSERVE',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Secondary Action: Registration Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: ParishColors.marianBlueSurface,
                                      side: BorderSide(
                                        color: ParishColors.marianBlue.withOpacity(0.22),
                                        width: 1.2,
                                      ),
                                      foregroundColor: ParishColors.marianBlue,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
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
                                      Icons.person_add_alt_1_rounded,
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
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Assistance Pill Button (Frosted Translucent Container)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F1E36).withOpacity(0.60),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.18),
                              width: 1.0,
                            ),
                          ),
                          child: InkWell(
                            onTap: () => showLoginHelpDialog(context),
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.help_outline_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Need assistance logging in? Tap here',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      decoration: TextDecoration.underline,
                                      decorationColor: Colors.white,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black54,
                                          blurRadius: 4,
                                          offset: Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Ecclesiastical Motto
                      Text(
                        'TOTUS TUUS',
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          fontStyle: FontStyle.italic,
                          color: ParishColors.goldAccent,
                          letterSpacing: 3.5,
                          shadows: const [
                            Shadow(
                              color: Colors.black,
                              blurRadius: 10,
                              offset: Offset(0, 1),
                            ),
                          ],
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
    );
  }
}