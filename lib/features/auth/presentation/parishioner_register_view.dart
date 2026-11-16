import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/colors.dart';
import '../services/auth_service.dart';
import 'dialogs/login_help_dialog.dart';
import 'dialogs/terms_conditions_dialog.dart';
import 'otp_verification_view.dart';

class ParishionerRegisterView extends StatefulWidget {
  const ParishionerRegisterView({super.key});

  @override
  State<ParishionerRegisterView> createState() =>
      _ParishionerRegisterViewState();
}

class _ParishionerRegisterViewState extends State<ParishionerRegisterView> {
  final _formKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Focus nodes to track blur (only show errors when user leaves a field)
  final _firstNameFocus = FocusNode();
  final _lastNameFocus = FocusNode();
  final _usernameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();

  bool _firstNameBlurred = false;
  bool _lastNameBlurred = false;
  bool _usernameBlurred = false;
  bool _emailBlurred = false;
  bool _passwordBlurred = false;
  bool _confirmPasswordBlurred = false;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _hasAttemptedSubmit = false;
  bool _acceptedTerms = false;
  bool _showTermsError = false;
  String? _errorMessage;

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

  // QWERTY keyboard sequences used for anti-gibberish detection
  static const List<String> _keyboardWalks = [
    'asdf', 'sdfg', 'dfgh', 'fghj', 'ghjk', 'hjkl',
    'qwer', 'wert', 'erty', 'rtyu', 'tyui', 'yuio', 'uiop',
    'zxcv', 'xcvb', 'cvbn', 'vbnm',
    'fdsa', 'gfds', 'hgfd', 'jhgf', 'kjhg', 'lkjh',
    'rewq', 'trew', 'ytre', 'uytr', 'iuyt', 'poiuy',
    'vcxz', 'bvcx', 'nbvc', 'mnbv',
  ];

  @override
  void initState() {
    super.initState();

    _firstNameFocus.addListener(() {
      if (!_firstNameFocus.hasFocus) setState(() => _firstNameBlurred = true);
    });
    _lastNameFocus.addListener(() {
      if (!_lastNameFocus.hasFocus) setState(() => _lastNameBlurred = true);
    });
    _usernameFocus.addListener(() {
      if (!_usernameFocus.hasFocus) setState(() => _usernameBlurred = true);
    });
    _emailFocus.addListener(() {
      if (!_emailFocus.hasFocus) setState(() => _emailBlurred = true);
    });
    _passwordFocus.addListener(() {
      if (!_passwordFocus.hasFocus) setState(() => _passwordBlurred = true);
    });
    _confirmPasswordFocus.addListener(() {
      if (!_confirmPasswordFocus.hasFocus) {
        setState(() => _confirmPasswordBlurred = true);
      }
    });

    _passwordController.addListener(() => setState(() {}));
    _confirmPasswordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _firstNameFocus.dispose();
    _lastNameFocus.dispose();
    _usernameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();

    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // Validation Rules (Anti-Spam, Anti-Gibberish & Canonical Compliance)
  // ===========================================================================

  String? _validateName(String? value, String fieldLabel) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldLabel is required.';
    }
    if (value.startsWith(' ')) {
      return '$fieldLabel cannot start with a space.';
    }
    if (value.endsWith(' ')) {
      return '$fieldLabel cannot end with a space.';
    }
    if (value.contains(RegExp(r'\s{2,}'))) {
      return '$fieldLabel cannot contain consecutive spaces.';
    }

    final trimmed = value.trim();
    if (trimmed.length < 2) {
      return '$fieldLabel must be at least 2 characters.';
    }
    if (trimmed.length > 50) {
      return '$fieldLabel cannot exceed 50 characters.';
    }

    // 1. Basic allowed characters (letters, accents, hyphens, periods, apostrophes, spaces)
    final nameRegex = RegExp(r"^[a-zA-ZÀ-ÿ\u0100-\u024FÑñ\s.\-’']+$");
    if (!nameRegex.hasMatch(trimmed)) {
      return '$fieldLabel contains invalid characters.';
    }

    final lower = trimmed.toLowerCase();

    // 2. Reject 3 or more identical letters in a row
    if (RegExp(r'(.)\1{2,}', caseSensitive: false).hasMatch(trimmed)) {
      return '$fieldLabel cannot contain 3 or more of the same letter in a row.';
    }

    // 3. Reject repetitive syllable mashing
    if (RegExp(r'(.{2,4})\1{2,}', caseSensitive: false).hasMatch(lower)) {
      return 'Please enter a valid $fieldLabel (repetitive pattern detected).';
    }

    // 4. Reject 4-character keyboard walks
    for (final walk in _keyboardWalks) {
      if (lower.contains(walk)) {
        return '$fieldLabel cannot be a keyboard sequence (e.g. "$walk").';
      }
    }

    // 5. Pronounceability / Vowel check
    final onlyLetters = lower.replaceAll(RegExp(r'[^a-zà-ÿñ]'), '');
    if (onlyLetters.length >= 3) {
      final hasVowel = RegExp(r'[aeiouyà-ÿ]').hasMatch(onlyLetters);
      if (!hasVowel) {
        return '$fieldLabel must contain at least one vowel.';
      }

      // 6. Reject 5 or more consecutive consonants
      if (RegExp(r'[bcdfghjklmnpqrstvwxz]{5,}').hasMatch(onlyLetters)) {
        return '$fieldLabel contains too many consecutive consonants.';
      }
    }

    return null;
  }

  String? _validateUsername(String? value) {
    if (value == null || value.isEmpty) {
      return 'Username is required.';
    }
    if (value.contains(' ')) {
      return 'Username cannot contain spaces.';
    }
    final trimmed = value.trim();
    if (trimmed.length < 3) {
      return 'Username must be at least 3 characters.';
    }
    if (trimmed.length > 30) {
      return 'Username cannot exceed 30 characters.';
    }

    // Reject repetitive spam
    if (RegExp(r'(.{2,})\1{2,}', caseSensitive: false).hasMatch(trimmed)) {
      return 'Username contains an invalid repetitive pattern.';
    }

    final usernameRegex = RegExp(r'^[a-zA-Z0-9_\-]+$');
    if (!usernameRegex.hasMatch(trimmed)) {
      return 'Only letters, numbers, underscores (_), and hyphens (-) are allowed.';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email address is required.';
    }
    if (value.contains(' ')) {
      return 'Email address cannot contain spaces.';
    }
    final trimmed = value.trim();
    if (trimmed.length > 254) {
      return 'Email address cannot exceed 254 characters.';
    }

    final emailRegex =
        RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(trimmed)) {
      return 'Please enter a valid email address (e.g. name@domain.com).';
    }
    return null;
  }

  bool _containsPredictablePatterns(String password) {
    final lower = password.toLowerCase();
    const commonSequences = [
      '123', '234', '345', '456', '567', '678', '789',
      'abc', 'bcd', 'cde', 'def', 'qwe', 'wer', 'ert', 'rty',
      'asd', 'sdf', 'dfg', 'zxc', 'xcv',
      'password', 'admin', 'parish',
    ];
    for (final seq in commonSequences) {
      if (lower.contains(seq)) return true;
    }
    return false;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required.';
    }
    if (value.startsWith(' ') || value.endsWith(' ')) {
      return 'Password cannot begin or end with spaces.';
    }

    final nonSpaceCount = value.replaceAll(' ', '').length;
    if (nonSpaceCount < 8) {
      return 'Password must contain at least 8 non-space characters.';
    }
    if (value.length > 128) {
      return 'Password cannot exceed 128 characters.';
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Password must include at least one uppercase letter (A-Z).';
    }
    if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=\[\]\\/~`]').hasMatch(value)) {
      return 'Password must include at least one special character.';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Password must include at least one number (0-9).';
    }

    if (_containsPredictablePatterns(value)) {
      return 'Password is too predictable. Avoid sequences like 123, asd, or common words.';
    }

    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password.';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match.';
    }
    return null;
  }

  // ===========================================================================
  // Password Strength Evaluation
  // ===========================================================================

  bool get _hasMinRealLength =>
      _passwordController.text.replaceAll(' ', '').length >= 8;
  bool get _hasNoOuterSpaces =>
      _passwordController.text.isNotEmpty &&
      !_passwordController.text.startsWith(' ') &&
      !_passwordController.text.endsWith(' ');
  bool get _hasUppercase => RegExp(r'[A-Z]').hasMatch(_passwordController.text);
  bool get _hasSpecialChar =>
      RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=\[\]\\/~`]')
          .hasMatch(_passwordController.text);
  bool get _hasNumber => RegExp(r'[0-9]').hasMatch(_passwordController.text);
  bool get _isNotPredictable =>
      !_containsPredictablePatterns(_passwordController.text);

  int get _strengthScore {
    final text = _passwordController.text;
    final nonSpaceLength = text.replaceAll(' ', '').length;
    if (nonSpaceLength == 0) return 0;

    int score = 0;
    if (_hasMinRealLength && _hasNoOuterSpaces) score++;
    if (_hasUppercase) score++;
    if (_hasSpecialChar) score++;
    if (_hasNumber) score++;

    if (_containsPredictablePatterns(text) || nonSpaceLength < 10) {
      if (score > 2) score = 2;
    }

    return score;
  }

  // ===========================================================================
  // Form Submission
  // ===========================================================================

  Future<void> _handleRegister() async {
    setState(() {
      _hasAttemptedSubmit = true;
      _errorMessage = null;
      _showTermsError = !_acceptedTerms;
    });

    if (!_formKey.currentState!.validate() || !_acceptedTerms) return;

    setState(() => _isLoading = true);

    try {
      final cleanEmail = _emailController.text.trim();

      final result = await AuthService.registerParishioner(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        username: _usernameController.text.trim(),
        email: cleanEmail,
        password: _passwordController.text,
      );

      if (!mounted) return;

      if (result['requiresVerification'] == true) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OtpVerificationView(email: cleanEmail),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
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
                    children: [
                      // Back to Login Button
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, size: 22),
                        color: _eucharisticGoldLight,
                        tooltip: 'Back to Sign In',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        onPressed:
                            _isLoading ? null : () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      // Parish Crest
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
                      // Typography
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
              ),
            ),

            // ===================================================================
            // 2. ATMOSPHERIC CATHEDRAL VAULT BACKGROUND & REGISTRATION CARD
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
                        width: 760,
                        height: 760,
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
                          constraints: const BoxConstraints(maxWidth: 580),
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
                                      // Registration Form Section
                                      // -----------------------------------------
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: isCompact ? 18.0 : 32.0,
                                          vertical: 26.0,
                                        ),
                                        child: Form(
                                          key: _formKey,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Center(
                                                child: Column(
                                                  children: const [
                                                    Text(
                                                      'Parishioner Registration',
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
                                                      'Register to request sacramental services and mass intentions.',
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: TextStyle(
                                                        fontSize: 12.5,
                                                        color: _textSlateMuted,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 22),

                                              if (_errorMessage != null) ...[
                                                Container(
                                                  width: double.infinity,
                                                  padding:
                                                      const EdgeInsets.all(12),
                                                  margin: const EdgeInsets.only(
                                                      bottom: 16),
                                                  decoration: BoxDecoration(
                                                    color: ParishColors
                                                        .mercyRedSurface,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                    border: Border.all(
                                                      color: ParishColors
                                                          .mercyRed
                                                          .withOpacity(0.5),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      const Icon(
                                                        Icons
                                                            .error_outline_rounded,
                                                        color: ParishColors
                                                            .mercyRed,
                                                        size: 19,
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                          _errorMessage!,
                                                          style: const TextStyle(
                                                            fontSize: 12.5,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: ParishColors
                                                                .mercyRed,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],

                                              // 1. Legal Name Fields
                                              Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        _buildInputLabel(
                                                          label: 'First Name *',
                                                          icon: Icons
                                                              .person_outline_rounded,
                                                        ),
                                                        const SizedBox(height: 7),
                                                        TextFormField(
                                                          controller:
                                                              _firstNameController,
                                                          focusNode:
                                                              _firstNameFocus,
                                                          keyboardType:
                                                              TextInputType.name,
                                                          textCapitalization:
                                                              TextCapitalization
                                                                  .words,
                                                          autofillHints: const [
                                                            AutofillHints
                                                                .givenName
                                                          ],
                                                          style: const TextStyle(
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color:
                                                                _textCharcoal,
                                                          ),
                                                          onChanged: (_) {
                                                            if (_hasAttemptedSubmit ||
                                                                _firstNameBlurred) {
                                                              _formKey
                                                                  .currentState
                                                                  ?.validate();
                                                            }
                                                          },
                                                          validator: (v) {
                                                            if (!_hasAttemptedSubmit &&
                                                                !_firstNameBlurred) {
                                                              return null;
                                                            }
                                                            return _validateName(
                                                                v, 'First name');
                                                          },
                                                          decoration:
                                                              _fieldDecoration(
                                                            hint: 'e.g. Maria',
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        _buildInputLabel(
                                                          label: 'Last Name *',
                                                          icon: Icons
                                                              .person_outline_rounded,
                                                        ),
                                                        const SizedBox(height: 7),
                                                        TextFormField(
                                                          controller:
                                                              _lastNameController,
                                                          focusNode:
                                                              _lastNameFocus,
                                                          keyboardType:
                                                              TextInputType.name,
                                                          textCapitalization:
                                                              TextCapitalization
                                                                  .words,
                                                          autofillHints: const [
                                                            AutofillHints
                                                                .familyName
                                                          ],
                                                          style: const TextStyle(
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color:
                                                                _textCharcoal,
                                                          ),
                                                          onChanged: (_) {
                                                            if (_hasAttemptedSubmit ||
                                                                _lastNameBlurred) {
                                                              _formKey
                                                                  .currentState
                                                                  ?.validate();
                                                            }
                                                          },
                                                          validator: (v) {
                                                            if (!_hasAttemptedSubmit &&
                                                                !_lastNameBlurred) {
                                                              return null;
                                                            }
                                                            return _validateName(
                                                                v, 'Last name');
                                                          },
                                                          decoration:
                                                              _fieldDecoration(
                                                            hint: 'e.g. Santos',
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 16),

                                              // 2. Username Field
                                              _buildInputLabel(
                                                label: 'Username *',
                                                icon: Icons
                                                    .alternate_email_rounded,
                                              ),
                                              const SizedBox(height: 7),
                                              TextFormField(
                                                controller:
                                                    _usernameController,
                                                focusNode: _usernameFocus,
                                                keyboardType:
                                                    TextInputType.text,
                                                inputFormatters: [
                                                  FilteringTextInputFormatter
                                                      .deny(RegExp(r'\s'))
                                                ],
                                                autofillHints: const [
                                                  AutofillHints.username
                                                ],
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: _textCharcoal,
                                                ),
                                                onChanged: (_) {
                                                  if (_hasAttemptedSubmit ||
                                                      _usernameBlurred) {
                                                    _formKey.currentState
                                                        ?.validate();
                                                  }
                                                },
                                                validator: (v) {
                                                  if (!_hasAttemptedSubmit &&
                                                      !_usernameBlurred) {
                                                    return null;
                                                  }
                                                  return _validateUsername(v);
                                                },
                                                decoration: _fieldDecoration(
                                                  hint: 'e.g. mariasantos_01',
                                                ),
                                              ),
                                              const SizedBox(height: 16),

                                              // 3. Email Address
                                              _buildInputLabel(
                                                label: 'Email Address *',
                                                icon: Icons.email_outlined,
                                              ),
                                              const SizedBox(height: 7),
                                              TextFormField(
                                                controller: _emailController,
                                                focusNode: _emailFocus,
                                                keyboardType:
                                                    TextInputType.emailAddress,
                                                inputFormatters: [
                                                  FilteringTextInputFormatter
                                                      .deny(RegExp(r'\s'))
                                                ],
                                                autofillHints: const [
                                                  AutofillHints.email
                                                ],
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: _textCharcoal,
                                                ),
                                                onChanged: (_) {
                                                  if (_hasAttemptedSubmit ||
                                                      _emailBlurred) {
                                                    _formKey.currentState
                                                        ?.validate();
                                                  }
                                                },
                                                validator: (v) {
                                                  if (!_hasAttemptedSubmit &&
                                                      !_emailBlurred) {
                                                    return null;
                                                  }
                                                  return _validateEmail(v);
                                                },
                                                decoration: _fieldDecoration(
                                                  hint: 'name@email.com',
                                                ),
                                              ),
                                              const SizedBox(height: 16),

                                              // 4. Password Field
                                              _buildInputLabel(
                                                label: 'Password *',
                                                icon:
                                                    Icons.lock_outline_rounded,
                                              ),
                                              const SizedBox(height: 7),
                                              TextFormField(
                                                controller:
                                                    _passwordController,
                                                focusNode: _passwordFocus,
                                                obscureText: _obscurePassword,
                                                keyboardType: TextInputType
                                                    .visiblePassword,
                                                autofillHints: const [
                                                  AutofillHints.newPassword
                                                ],
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: _textCharcoal,
                                                ),
                                                onChanged: (_) {
                                                  if (_hasAttemptedSubmit ||
                                                      _passwordBlurred) {
                                                    _formKey.currentState
                                                        ?.validate();
                                                  }
                                                },
                                                validator: (v) {
                                                  if (!_hasAttemptedSubmit &&
                                                      !_passwordBlurred) {
                                                    return null;
                                                  }
                                                  return _validatePassword(v);
                                                },
                                                decoration: _fieldDecoration(
                                                  hint:
                                                      'Min. 8 chars with uppercase & symbol',
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
                                              const SizedBox(height: 10),

                                              // Live Password Strength Checklist
                                              _buildPasswordStrengthWidget(),
                                              const SizedBox(height: 16),

                                              // 5. Confirm Password
                                              _buildInputLabel(
                                                label: 'Confirm Password *',
                                                icon:
                                                    Icons.lock_outline_rounded,
                                              ),
                                              const SizedBox(height: 7),
                                              TextFormField(
                                                controller:
                                                    _confirmPasswordController,
                                                focusNode:
                                                    _confirmPasswordFocus,
                                                obscureText:
                                                    _obscureConfirmPassword,
                                                keyboardType: TextInputType
                                                    .visiblePassword,
                                                autofillHints: const [
                                                  AutofillHints.newPassword
                                                ],
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: _textCharcoal,
                                                ),
                                                onChanged: (_) {
                                                  if (_hasAttemptedSubmit ||
                                                      _confirmPasswordBlurred ||
                                                      _confirmPasswordController
                                                          .text.isNotEmpty) {
                                                    _formKey.currentState
                                                        ?.validate();
                                                  }
                                                },
                                                validator: (v) {
                                                  if (!_hasAttemptedSubmit &&
                                                      !_confirmPasswordBlurred &&
                                                      _confirmPasswordController
                                                          .text.isEmpty) {
                                                    return null;
                                                  }
                                                  return _validateConfirmPassword(
                                                      v);
                                                },
                                                decoration: _fieldDecoration(
                                                  hint:
                                                      'Re-enter your password exactly',
                                                  suffixIcon: IconButton(
                                                    icon: Icon(
                                                      _obscureConfirmPassword
                                                          ? Icons
                                                              .visibility_off_outlined
                                                          : Icons
                                                              .visibility_outlined,
                                                      color: _textSlateMuted,
                                                      size: 19,
                                                    ),
                                                    onPressed: () => setState(
                                                      () =>
                                                          _obscureConfirmPassword =
                                                              !_obscureConfirmPassword,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 16),

                                              // 6. Terms and Conditions Acceptance
                                              Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Checkbox(
                                                    value: _acceptedTerms,
                                                    activeColor:
                                                        _chanceryNavyLight,
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              4),
                                                    ),
                                                    onChanged: (val) {
                                                      setState(() {
                                                        _acceptedTerms =
                                                            val ?? false;
                                                        if (_acceptedTerms) {
                                                          _showTermsError =
                                                              false;
                                                        }
                                                      });
                                                    },
                                                  ),
                                                  Expanded(
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              top: 8.0),
                                                      child: Wrap(
                                                        crossAxisAlignment:
                                                            WrapCrossAlignment
                                                                .center,
                                                        children: [
                                                          const Text(
                                                            'I agree to the ',
                                                            style: TextStyle(
                                                              fontSize: 12.5,
                                                              color:
                                                                  _textCharcoal,
                                                            ),
                                                          ),
                                                          InkWell(
                                                            onTap: () =>
                                                                showTermsAndConditionsModal(
                                                              context,
                                                              isReadOnly: false,
                                                              onAccepted: () =>
                                                                  setState(() {
                                                                _acceptedTerms =
                                                                    true;
                                                                _showTermsError =
                                                                    false;
                                                              }),
                                                            ),
                                                            child: const Text(
                                                              'Terms and Data Privacy Policy',
                                                              style: TextStyle(
                                                                fontSize: 12.5,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color:
                                                                    _chanceryNavyLight,
                                                                decoration:
                                                                    TextDecoration
                                                                        .underline,
                                                                decorationColor:
                                                                    _chanceryNavyLight,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (_showTermsError) ...[
                                                const Padding(
                                                  padding: EdgeInsets.only(
                                                      left: 12, top: 4),
                                                  child: Text(
                                                    'You must accept the Terms and Conditions to register.',
                                                    style: TextStyle(
                                                      color:
                                                          ParishColors.mercyRed,
                                                      fontSize: 11.5,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                              const SizedBox(height: 14),

                                              // Privacy Archive Notice Box
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: _warmInputFill,
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  border: Border.all(
                                                    color: _warmInputBorder,
                                                  ),
                                                ),
                                                child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: const [
                                                    Icon(
                                                      Icons
                                                          .verified_user_outlined,
                                                      size: 17,
                                                      color:
                                                          ParishColors.oliveGreen,
                                                    ),
                                                    SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        'Protected under RA 10173 and Canonical Archive Standards. A 6-digit verification code will be sent to your email.',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: _textSlateMuted,
                                                          height: 1.35,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 24),

                                              // Primary Submit Button
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
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10),
                                                    ),
                                                  ),
                                                  onPressed: _isLoading
                                                      ? null
                                                      : _handleRegister,
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
                                                            Icon(
                                                              Icons
                                                                  .mark_email_unread_outlined,
                                                              size: 18,
                                                            ),
                                                            SizedBox(width: 8),
                                                            Text(
                                                              'Register & Send Code',
                                                              style: TextStyle(
                                                                fontSize: 14,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                letterSpacing:
                                                                    0.3,
                                                              ),
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

                                              // Secondary Action: Return to Login
                                              SizedBox(
                                                width: double.infinity,
                                                height: 46,
                                                child: OutlinedButton.icon(
                                                  style:
                                                      OutlinedButton.styleFrom(
                                                    backgroundColor:
                                                        _warmInputFill,
                                                    side: const BorderSide(
                                                      color: _chanceryNavyLight,
                                                      width: 1.2,
                                                    ),
                                                    foregroundColor:
                                                      _chanceryNavyLight,
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10),
                                                    ),
                                                  ),
                                                  onPressed: _isLoading
                                                      ? null
                                                      : () =>
                                                          Navigator.pop(context),
                                                  icon: const Icon(
                                                    Icons.login_rounded,
                                                    size: 18,
                                                  ),
                                                  label: const Text(
                                                    'Already have an account? Sign In',
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

  // ===========================================================================
  // Visual Password Strength Checklist
  // ===========================================================================

  Widget _buildPasswordStrengthWidget() {
    final text = _passwordController.text;
    if (text.isEmpty) return const SizedBox.shrink();

    final score = _strengthScore;
    Color strengthColor = ParishColors.mercyRed;
    String strengthLabel = 'Weak';

    if (score == 2) {
      strengthColor = Colors.orange;
      strengthLabel = 'Fair';
    } else if (score == 3) {
      strengthColor = _eucharisticGold;
      strengthLabel = 'Good';
    } else if (score >= 4) {
      strengthColor = ParishColors.oliveGreen;
      strengthLabel = 'Strong';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _warmInputFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _warmInputBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Password Strength:',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: _textCharcoal,
                ),
              ),
              Text(
                strengthLabel,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: strengthColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (score / 4.0).clamp(0.2, 1.0),
              minHeight: 5,
              backgroundColor: _warmInputBorder.withOpacity(0.5),
              valueColor: AlwaysStoppedAnimation<Color>(strengthColor),
            ),
          ),
          const SizedBox(height: 10),
          _buildChecklistItem(
            'At least 8 non-space characters',
            _hasMinRealLength && _hasNoOuterSpaces,
          ),
          _buildChecklistItem(
            'At least 1 uppercase letter (A-Z) (Required)',
            _hasUppercase,
          ),
          _buildChecklistItem(
            'At least 1 special character (!@#\$...) (Required)',
            _hasSpecialChar,
          ),
          _buildChecklistItem(
            'At least 1 number (0-9)',
            _hasNumber,
          ),
          _buildChecklistItem(
            'No predictable patterns (123, asd, passwords)',
            _isNotPredictable,
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistItem(String label, bool isSatisfied) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3.0),
      child: Row(
        children: [
          Icon(
            isSatisfied
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked,
            size: 14,
            color: isSatisfied
                ? ParishColors.oliveGreen
                : _textSlateMuted.withOpacity(0.6),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSatisfied ? FontWeight.bold : FontWeight.normal,
                color: isSatisfied ? _textCharcoal : _textSlateMuted,
              ),
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide:
            const BorderSide(color: ParishColors.mercyRed, width: 1.2),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide:
            BorderSide(color: ParishColors.mercyRed, width: 1.6),
      ),
      errorStyle: const TextStyle(
        fontSize: 11.5,
        color: ParishColors.mercyRed,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
