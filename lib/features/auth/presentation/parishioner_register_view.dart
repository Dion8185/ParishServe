import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/colors.dart';
import '../services/auth_service.dart';
import 'otp_verification_view.dart';

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
  String? _errorMessage;

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
      if (!_confirmPasswordFocus.hasFocus) setState(() => _confirmPasswordBlurred = true);
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

    // 2. Reject 3 or more identical letters in a row (e.g. aaaaaaaaaa, bbbb, xxx)
    // Legitimate double-letters like 'Aaron' or 'Lloyd' are fully permitted.
    if (RegExp(r'(.)\1{2,}', caseSensitive: false).hasMatch(trimmed)) {
      return '$fieldLabel cannot contain 3 or more of the same letter in a row.';
    }

    // 3. Reject repetitive syllable mashing (e.g. asdasdasd, qweqweqwe, hahahaha)
    if (RegExp(r'(.{2,4})\1{2,}', caseSensitive: false).hasMatch(lower)) {
      return 'Please enter a valid $fieldLabel (repetitive pattern detected).';
    }

    // 4. Reject 4-character keyboard walks (e.g. asdf, qwer, zxcv)
    for (final walk in _keyboardWalks) {
      if (lower.contains(walk)) {
        return '$fieldLabel cannot be a keyboard sequence (e.g. "$walk").';
      }
    }

    // 5. Pronounceability / Vowel check: Names of 3+ letters must contain at least 1 vowel sound (a,e,i,o,u,y, accents)
    final onlyLetters = lower.replaceAll(RegExp(r'[^a-zà-ÿñ]'), '');
    if (onlyLetters.length >= 3) {
      final hasVowel = RegExp(r'[aeiouyà-ÿ]').hasMatch(onlyLetters);
      if (!hasVowel) {
        return '$fieldLabel must contain at least one vowel.';
      }

      // 6. Reject 5 or more consecutive consonants (e.g. bcdfgh)
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

    // Reject repetitive spam (e.g. asdasdasd)
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

    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
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

    // Non-space character count (spaces cannot cheat the minimum length)
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

  bool get _hasMinRealLength => _passwordController.text.replaceAll(' ', '').length >= 8;
  bool get _hasNoOuterSpaces =>
      _passwordController.text.isNotEmpty &&
          !_passwordController.text.startsWith(' ') &&
          !_passwordController.text.endsWith(' ');
  bool get _hasUppercase => RegExp(r'[A-Z]').hasMatch(_passwordController.text);
  bool get _hasSpecialChar =>
      RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=\[\]\\/~`]').hasMatch(_passwordController.text);
  bool get _hasNumber => RegExp(r'[0-9]').hasMatch(_passwordController.text);
  bool get _isNotPredictable => !_containsPredictablePatterns(_passwordController.text);

  int get _strengthScore {
    final text = _passwordController.text;
    final nonSpaceLength = text.replaceAll(' ', '').length;
    if (nonSpaceLength == 0) return 0;

    int score = 0;
    if (_hasMinRealLength && _hasNoOuterSpaces) score++;
    if (_hasUppercase) score++;
    if (_hasSpecialChar) score++;
    if (_hasNumber) score++;

    // Penalty: passwords with predictable walks or under 10 chars are capped at Fair
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
    });

    if (!_formKey.currentState!.validate()) return;

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
              'Parishioner Registration',
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
                    child: const Icon(
                      Icons.person_add_alt_1,
                      size: 36,
                      color: ParishColors.marianBlue,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Text(
                    'Create Your Parishioner Account',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: ParishColors.marianBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Book sacrament appointments, request mass intentions, and track your contributions.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: textMutedColor, height: 1.4),
                  ),
                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: cardWhiteColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderGreyColor, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Form(
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
                                      focusNode: _firstNameFocus,
                                      keyboardType: TextInputType.name,
                                      textCapitalization: TextCapitalization.words,
                                      autofillHints: const [AutofillHints.givenName],
                                      onChanged: (_) {
                                        if (_hasAttemptedSubmit || _firstNameBlurred) {
                                          _formKey.currentState?.validate();
                                        }
                                      },
                                      validator: (v) {
                                        if (!_hasAttemptedSubmit && !_firstNameBlurred) return null;
                                        return _validateName(v, 'First name');
                                      },
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
                                      focusNode: _lastNameFocus,
                                      keyboardType: TextInputType.name,
                                      textCapitalization: TextCapitalization.words,
                                      autofillHints: const [AutofillHints.familyName],
                                      onChanged: (_) {
                                        if (_hasAttemptedSubmit || _lastNameBlurred) {
                                          _formKey.currentState?.validate();
                                        }
                                      },
                                      validator: (v) {
                                        if (!_hasAttemptedSubmit && !_lastNameBlurred) return null;
                                        return _validateName(v, 'Last name');
                                      },
                                      style: TextStyle(fontSize: 14, color: textDarkColor),
                                      decoration: _inputDecoration(hint: 'e.g. Santos'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // 2. Username Field
                          _buildFieldLabel('Username *'),
                          TextFormField(
                            controller: _usernameController,
                            focusNode: _usernameFocus,
                            keyboardType: TextInputType.text,
                            inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
                            autofillHints: const [AutofillHints.username],
                            onChanged: (_) {
                              if (_hasAttemptedSubmit || _usernameBlurred) {
                                _formKey.currentState?.validate();
                              }
                            },
                            validator: (v) {
                              if (!_hasAttemptedSubmit && !_usernameBlurred) return null;
                              return _validateUsername(v);
                            },
                            style: TextStyle(fontSize: 14, color: textDarkColor),
                            decoration: _inputDecoration(
                              hint: 'e.g. mariasantos_01',
                              prefixIcon: const Icon(Icons.alternate_email, size: 18, color: ParishColors.marianBlue),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // 3. Email Field
                          _buildFieldLabel('Email Address *'),
                          TextFormField(
                            controller: _emailController,
                            focusNode: _emailFocus,
                            keyboardType: TextInputType.emailAddress,
                            inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
                            autofillHints: const [AutofillHints.email],
                            onChanged: (_) {
                              if (_hasAttemptedSubmit || _emailBlurred) {
                                _formKey.currentState?.validate();
                              }
                            },
                            validator: (v) {
                              if (!_hasAttemptedSubmit && !_emailBlurred) return null;
                              return _validateEmail(v);
                            },
                            style: TextStyle(fontSize: 14, color: textDarkColor),
                            decoration: _inputDecoration(
                              hint: 'name@email.com',
                              prefixIcon: const Icon(Icons.email_outlined, size: 18, color: ParishColors.marianBlue),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // 4. Password Field
                          _buildFieldLabel('Password *'),
                          TextFormField(
                            controller: _passwordController,
                            focusNode: _passwordFocus,
                            obscureText: _obscurePassword,
                            keyboardType: TextInputType.visiblePassword,
                            autofillHints: const [AutofillHints.newPassword],
                            onChanged: (_) {
                              if (_hasAttemptedSubmit || _passwordBlurred) {
                                _formKey.currentState?.validate();
                              }
                            },
                            validator: (v) {
                              if (!_hasAttemptedSubmit && !_passwordBlurred) return null;
                              return _validatePassword(v);
                            },
                            style: TextStyle(fontSize: 14, color: textDarkColor),
                            decoration: _inputDecoration(
                              hint: 'Min. 8 chars with uppercase & symbol',
                              prefixIcon: const Icon(Icons.lock_outline, size: 18, color: ParishColors.marianBlue),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                  size: 20,
                                  color: textMutedColor,
                                ),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Live Password Strength Meter
                          _buildPasswordStrengthWidget(),
                          const SizedBox(height: 14),

                          // 5. Confirm Password Field
                          _buildFieldLabel('Confirm Password *'),
                          TextFormField(
                            controller: _confirmPasswordController,
                            focusNode: _confirmPasswordFocus,
                            obscureText: _obscureConfirmPassword,
                            keyboardType: TextInputType.visiblePassword,
                            autofillHints: const [AutofillHints.newPassword],
                            onChanged: (_) {
                              if (_hasAttemptedSubmit || _confirmPasswordBlurred || _confirmPasswordController.text.isNotEmpty) {
                                _formKey.currentState?.validate();
                              }
                            },
                            validator: (v) {
                              // Only show if user has interacted with confirm password or tried submitting
                              if (!_hasAttemptedSubmit && !_confirmPasswordBlurred && (_confirmPasswordController.text.isEmpty)) {
                                return null;
                              }
                              return _validateConfirmPassword(v);
                            },
                            style: TextStyle(fontSize: 14, color: textDarkColor),
                            decoration: _inputDecoration(
                              hint: 'Re-enter your password exactly',
                              prefixIcon: const Icon(Icons.lock_outline, size: 18, color: ParishColors.marianBlue),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                                  size: 20,
                                  color: textMutedColor,
                                ),
                                onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

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
                                    'Protected under RA 10173 and Canonical Archive Standards. A 6-digit verification code will be sent to your email.',
                                    style: TextStyle(fontSize: 11, color: textMutedColor, height: 1.35),
                                  ),
                                ),
                              ],
                            ),
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

  // ===========================================================================
  // Visual Password Strength Meter & Checklist
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
              Text(
                strengthLabel,
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: strengthColor),
              ),
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
          const SizedBox(height: 10),

          // Live Criteria Checklist
          _buildChecklistItem('At least 8 non-space characters', _hasMinRealLength && _hasNoOuterSpaces),
          _buildChecklistItem('At least 1 uppercase letter (A-Z) (Required)', _hasUppercase),
          _buildChecklistItem('At least 1 special character (!@#\$...) (Required)', _hasSpecialChar),
          _buildChecklistItem('At least 1 number (0-9)', _hasNumber),
          _buildChecklistItem('No predictable patterns (123, asd, passwords)', _isNotPredictable),
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
            isSatisfied ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 14,
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
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: ParishColors.mercyRed, width: 1.2)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: ParishColors.mercyRed, width: 1.8)),
      errorStyle: const TextStyle(fontSize: 11.5, color: ParishColors.mercyRed, fontWeight: FontWeight.w500),
    );
  }
}