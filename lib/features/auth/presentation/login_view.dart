import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // Diocesan Chancery & Cathedral Architecture Palette
  static const Color _chanceryMidnight = Color(0xFF0A1C30);
  static const Color _chanceryNavyMid = Color(0xFF0F2C4C);
  static const Color _chanceryNavyLight = Color(0xFF164E87);
  static const Color _eucharisticGold = Color(0xFFD49B18);
  static const Color _eucharisticGoldLight = Color(0xFFE8B949);
  static const Color _warmManuscriptParchment = Color(0xFFFAF7F2);
  static const Color _warmInputFill = Color(0xFFF3EFE7);
  static const Color _warmInputBorder = Color(0xFFDDD5C8);
  static const Color _textCharcoal = Color(0xFF1A2633);
  static const Color _textSlateMuted = Color(0xFF5E6D7E);

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
        backgroundColor: _warmManuscriptParchment,
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
            const Text(
              'Sign In Error',
              style: TextStyle(
                fontFamily: 'serif',
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: _textCharcoal,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 13.5,
            color: _textCharcoal,
            height: 1.4,
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _chanceryNavyLight,
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
        color: _chanceryNavyMid,
        child: Icon(
          Icons.church_rounded,
          size: size * 0.62,
          color: _eucharisticGoldLight,
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _chanceryMidnight,
        body: Column(
          children: [
            // ===================================================================
            // 1. ELEVATED DIOCESAN CHANCERY HEADER (ISOLATED FROM STATUS BAR)
            // ===================================================================
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _chanceryMidnight,
                    Color(0xFF0D253F),
                    _chanceryNavyMid,
                  ],
                ),
                border: Border(
                  bottom: BorderSide(
                    color: _eucharisticGold.withOpacity(0.85),
                    width: 1.5,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 16.0 : 36.0,
                    vertical: 12.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Left: Official Crest + Latin/Diocesan Typography
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              padding: const EdgeInsets.all(2.5),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(
                                  color: _eucharisticGold,
                                  width: 2.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _eucharisticGold.withOpacity(0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: _buildParishLogo(size: 38),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'St. John Paul II Parish',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: 'serif',
                                      fontSize: 16.5,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.2,
                                      color: Color(0xFFFAF7F0),
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    'Diocese of San Pablo • Santa Cruz, Laguna',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: isCompact ? 10.5 : 11.5,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFFD6C8B4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Right Badge: Liturgical Motto (Hidden on micro screens)
                      if (!isCompact)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _chanceryNavyLight.withOpacity(0.35),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _eucharisticGold.withOpacity(0.65),
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.shield_outlined,
                                size: 13,
                                color: _eucharisticGoldLight,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'TOTUS TUUS',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                  color: _eucharisticGoldLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // ===================================================================
            // 2. ATMOSPHERIC CATHEDRAL VAULT BACKGROUND & ILLUMINATED CARD
            // ===================================================================
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Layer A: Deep Liturgical Nocturnal Gradient
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            _chanceryMidnight,
                            Color(0xFF0F263D),
                            Color(0xFF14324F),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Layer B: Warm Candlelight / Amber Halo Centered behind the Form
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        width: 700,
                        height: 700,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              _eucharisticGold.withOpacity(0.12),
                              _chanceryNavyLight.withOpacity(0.08),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.45, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Layer C: Subtle Architectural Church Silhouette
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.05,
                      child: Image.asset(
                        'images/jp2-bg2.jpg',
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),

                  // Center Scrollable View
                  SafeArea(
                    top: false,
                    child: Center(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.symmetric(
                          horizontal: isCompact ? 16.0 : 24.0,
                          vertical: 24.0,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Illuminated Manuscript Registry Card
                              Container(
                                decoration: BoxDecoration(
                                  color: _warmManuscriptParchment,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: _eucharisticGold.withOpacity(0.45),
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.40),
                                      blurRadius: 36,
                                      offset: const Offset(0, 14),
                                    ),
                                    BoxShadow(
                                      color: _eucharisticGold.withOpacity(0.10),
                                      blurRadius: 12,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      // -----------------------------------------
                                      // Parish Seal Banner (Deep Marian Vault)
                                      // -----------------------------------------
                                      Container(
                                        height: 165,
                                        width: double.infinity,
                                        decoration: const BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              _chanceryMidnight,
                                              _chanceryNavyMid,
                                              _chanceryNavyLight,
                                            ],
                                          ),
                                        ),
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            Positioned.fill(
                                              child: Opacity(
                                                opacity: 0.12,
                                                child: Image.asset(
                                                  'images/jp2-bg.png',
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) =>
                                                      const SizedBox.shrink(),
                                                ),
                                              ),
                                            ),
                                            // Golden Accent Ribbon
                                            Positioned(
                                              bottom: 0,
                                              left: 0,
                                              right: 0,
                                              child: Container(
                                                height: 3,
                                                color: _eucharisticGold,
                                              ),
                                            ),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 16.0,
                                                vertical: 14.0,
                                              ),
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Container(
                                                    width: 54,
                                                    height: 54,
                                                    padding:
                                                        const EdgeInsets.all(2.5),
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: Colors.white,
                                                      border: Border.all(
                                                        color: _eucharisticGold,
                                                        width: 2.2,
                                                      ),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black
                                                              .withOpacity(
                                                                  0.35),
                                                          blurRadius: 10,
                                                          offset:
                                                              const Offset(0, 4),
                                                        ),
                                                      ],
                                                    ),
                                                    child: ClipOval(
                                                      child: _buildParishLogo(
                                                          size: 48),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 10),
                                                  const Text(
                                                    'St. John Paul II Parish',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      fontFamily: 'serif',
                                                      fontSize: 20,
                                                      fontWeight: FontWeight.bold,
                                                      letterSpacing: 0.2,
                                                      color: Colors.white,
                                                      shadows: [
                                                        Shadow(
                                                          color: Colors.black45,
                                                          blurRadius: 4,
                                                          offset: Offset(0, 1),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(height: 5),
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.center,
                                                    children: [
                                                      Container(
                                                        width: 32,
                                                        height: 1.2,
                                                        color:
                                                            _eucharisticGold,
                                                      ),
                                                      const SizedBox(width: 8),
                                                      const Text(
                                                        'PARISHSERVE PORTAL',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          color:
                                                              _eucharisticGoldLight,
                                                          letterSpacing: 1.4,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Container(
                                                        width: 32,
                                                        height: 1.2,
                                                        color:
                                                            _eucharisticGold,
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
                                          vertical: 26.0,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Center(
                                              child: Column(
                                                children: const [
                                                  Text(
                                                    'Portal Sign In',
                                                    style: TextStyle(
                                                      fontSize: 21,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: _textCharcoal,
                                                      letterSpacing: -0.3,
                                                    ),
                                                  ),
                                                  SizedBox(height: 4),
                                                  Text(
                                                    'Sign in to access your ecclesiastical services.',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: _textSlateMuted,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 22),

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
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: _textCharcoal,
                                              ),
                                              decoration: _fieldDecoration(
                                                hint: 'e.g. name@email.com',
                                              ),
                                            ),
                                            const SizedBox(height: 18),

                                            // Field 2: Password
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
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
                                                  child: const Text(
                                                    'Forgot Password?',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: _chanceryNavyLight,
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
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: _textCharcoal,
                                              ),
                                              onSubmitted: (_) =>
                                                  _handleLogin(),
                                              decoration: _fieldDecoration(
                                                hint: 'Enter your password',
                                                suffixIcon: IconButton(
                                                  icon: Icon(
                                                    _obscurePassword
                                                        ? Icons
                                                            .visibility_off_outlined
                                                        : Icons
                                                            .visibility_outlined,
                                                    color: _textSlateMuted,
                                                    size: 19,
                                                  ),
                                                  onPressed: () => setState(
                                                    () => _obscurePassword =
                                                        !_obscurePassword,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 24),

                                            // Primary Action: Sign In
                                            SizedBox(
                                              width: double.infinity,
                                              height: 48,
                                              child: ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      _chanceryNavyLight,
                                                  foregroundColor: Colors.white,
                                                  elevation: 2,
                                                  shadowColor:
                                                      _chanceryNavyLight
                                                          .withOpacity(0.5),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
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
                                            const SizedBox(height: 16),

                                            // "or" Divider
                                            Row(
                                              children: const [
                                                Expanded(
                                                  child: Divider(
                                                    color: _warmInputBorder,
                                                    thickness: 1.0,
                                                  ),
                                                ),
                                                Padding(
                                                  padding:
                                                      EdgeInsets.symmetric(
                                                          horizontal: 12.0),
                                                  child: Text(
                                                    'or',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: _textSlateMuted,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Divider(
                                                    color: _warmInputBorder,
                                                    thickness: 1.0,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 16),

                                            // Secondary Action: Register Account
                                            SizedBox(
                                              width: double.infinity,
                                              height: 46,
                                              child: OutlinedButton.icon(
                                                style: OutlinedButton.styleFrom(
                                                  backgroundColor:
                                                      _warmInputFill,
                                                  side: const BorderSide(
                                                    color: _chanceryNavyLight,
                                                    width: 1.2,
                                                  ),
                                                  foregroundColor:
                                                      _chanceryNavyLight,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
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
                              const SizedBox(height: 22),

                              // =================================================
                              // 3. FOOTER ASSISTANCE NOTICE (WARM CONTRAST)
                              // =================================================
                              InkWell(
                                onTap: () => showLoginHelpDialog(context),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _chanceryNavyMid.withOpacity(0.55),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: _eucharisticGold.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(
                                        Icons.headset_mic_outlined,
                                        size: 15,
                                        color: _eucharisticGoldLight,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Need assistance? ',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFFD3DCE6),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        'Contact the Parish Office',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: _eucharisticGoldLight,
                                          decoration: TextDecoration.underline,
                                          decorationColor:
                                              _eucharisticGoldLight,
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
      ),
    );
  }

  Widget _buildInputLabel({required String label, required IconData icon}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: _chanceryNavyLight),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: _textCharcoal,
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
        color: _textSlateMuted.withOpacity(0.65),
        fontWeight: FontWeight.normal,
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: _warmInputFill,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        vertical: 13,
        horizontal: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _warmInputBorder, width: 1.0),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _warmInputBorder, width: 1.0),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: _chanceryNavyLight, width: 1.6),
      ),
    );
  }
}
