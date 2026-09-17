import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../services/confirmation_service.dart';

class ConfirmationManualEntryPage extends StatefulWidget {
  final VoidCallback? onRecordSaved;

  const ConfirmationManualEntryPage({super.key, this.onRecordSaved});

  @override
  State<ConfirmationManualEntryPage> createState() => _ConfirmationManualEntryPageState();
}

class _ConfirmationManualEntryPageState extends State<ConfirmationManualEntryPage> {
  final _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();

  // Pentecost Theme Accent for Confirmation
  static const Color _pentecostRed = Color(0xFFB91C1C);

  // Pagination State (5 Pages / Steps)
  int _currentStep = 0;
  static const int _totalSteps = 5;

  static const List<String> _stepTitles = [
    'Canonical Record Reference',
    "Confirmand's Personal Information",
    "Parents' Lineage & Origin",
    'Confirmation Sponsors',
    'Confirmation Administration & Minister',
  ];

  static const List<String> _stepDescriptions = [
    'Specify book, page, line, and entry classification from the physical register.',
    'Personal identification, age, required baptismal record, and residence.',
    'Parental lineage and canonical acknowledgment under Canon 877.',
    'Canonical sponsors (strictly limited to Sponsor 1 and optional Sponsor 2).',
    'Confirmation date, administering clergy, stipend, and canonical remarks.',
  ];

  // 1. Canonical Record Reference (Page 1)
  final _bookNumberController = TextEditingController();
  final _pageNumberController = TextEditingController();
  final _lineNumberController = TextEditingController();
  String _entryStatus = 'ORIGINAL';
  DateTime _registryDate = DateTime.now();

  // 2. Confirmand's Personal Information (Page 2)
  final _confirmandFirstNameController = TextEditingController();
  final _confirmandMiddleNameController = TextEditingController();
  final _confirmandLastNameController = TextEditingController();
  final _confirmandSuffixController = TextEditingController();
  DateTime? _dateOfBirth;
  final _ageController = TextEditingController();
  DateTime? _dateOfBaptism; // Required canonical date
  final _churchBaptizedController = TextEditingController(text: 'St. John Paul II Parish Church');
  final _addressController = TextEditingController();

  // 3. Father Information (Page 3 - Canon 877 §2)
  bool _fatherNotIndicated = false;
  final _fatherFirstNameController = TextEditingController();
  final _fatherMiddleNameController = TextEditingController();
  final _fatherLastNameController = TextEditingController();
  final _fatherOriginController = TextEditingController();

  // 4. Mother Information (Page 3)
  final _motherFirstNameController = TextEditingController();
  final _motherMiddleNameController = TextEditingController();
  final _motherMaidenLastNameController = TextEditingController();
  final _motherOriginController = TextEditingController();

  // 5. Sponsors (Page 4 - Strictly limited to 2)
  final _sponsor1FirstNameController = TextEditingController();
  final _sponsor1MiddleNameController = TextEditingController();
  final _sponsor1LastNameController = TextEditingController();
  final _sponsor1OriginAddressController = TextEditingController();

  final _sponsor2FirstNameController = TextEditingController();
  final _sponsor2MiddleNameController = TextEditingController();
  final _sponsor2LastNameController = TextEditingController();
  final _sponsor2OriginAddressController = TextEditingController();

  // 6. Administration Details (Page 5)
  DateTime? _dateOfConfirmation = DateTime.now();
  final _stipendController = TextEditingController();
  final _ministerFirstNameController = TextEditingController(text: 'Joseph');
  final _ministerMiddleNameController = TextEditingController();
  final _ministerLastNameController = TextEditingController(text: 'Santos');
  final _parishNameController = TextEditingController(text: 'St. John Paul II Parish');
  final _remarksController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;
  bool _dateOfBaptismHasError = false;
  bool _dateOfConfirmationHasError = false;

  @override
  void dispose() {
    _scrollController.dispose();
    _bookNumberController.dispose();
    _pageNumberController.dispose();
    _lineNumberController.dispose();
    _confirmandFirstNameController.dispose();
    _confirmandMiddleNameController.dispose();
    _confirmandLastNameController.dispose();
    _confirmandSuffixController.dispose();
    _ageController.dispose();
    _churchBaptizedController.dispose();
    _addressController.dispose();
    _fatherFirstNameController.dispose();
    _fatherMiddleNameController.dispose();
    _fatherLastNameController.dispose();
    _fatherOriginController.dispose();
    _motherFirstNameController.dispose();
    _motherMiddleNameController.dispose();
    _motherMaidenLastNameController.dispose();
    _motherOriginController.dispose();
    _sponsor1FirstNameController.dispose();
    _sponsor1MiddleNameController.dispose();
    _sponsor1LastNameController.dispose();
    _sponsor1OriginAddressController.dispose();
    _sponsor2FirstNameController.dispose();
    _sponsor2MiddleNameController.dispose();
    _sponsor2LastNameController.dispose();
    _sponsor2OriginAddressController.dispose();
    _stipendController.dispose();
    _ministerFirstNameController.dispose();
    _ministerMiddleNameController.dispose();
    _ministerLastNameController.dispose();
    _parishNameController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // Validation Helpers
  // ===========================================================================

  String? _validateName(String? value, String fieldName, {bool isRequired = true}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      if (isRequired) return '$fieldName is required.';
      return null;
    }
    if (text.length < 2) return '$fieldName must be at least 2 characters.';
    final nameRegExp = RegExp(r"^[a-zA-ZÀ-ÿÑñ\s\.\-\'’]+$");
    if (!nameRegExp.hasMatch(text)) {
      return 'Enter a valid name (letters only).';
    }
    return null;
  }

  String? _validateRequiredText(String? value, String fieldName) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '$fieldName is required.';
    if (text.length < 2) return '$fieldName must be at least 2 characters.';
    return null;
  }

  String? _validateStipend(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final amount = double.tryParse(text);
    if (amount == null || amount < 0) {
      return 'Enter a valid amount (e.g. 200.00).';
    }
    return null;
  }

  Future<void> _selectDate(BuildContext context, int dateType) async {
    // 0: Registry Date, 1: Date of Birth, 2: Date of Baptism, 3: Date of Confirmation
    final now = DateTime.now();
    DateTime initialDate;

    if (dateType == 0) {
      initialDate = _registryDate;
    } else if (dateType == 1) {
      initialDate = _dateOfBirth ?? DateTime(now.year - 12, 1, 1);
    } else if (dateType == 2) {
      initialDate = _dateOfBaptism ?? DateTime(now.year - 11, 1, 1);
    } else {
      initialDate = _dateOfConfirmation ?? now;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(now) ? now : initialDate,
      firstDate: DateTime(1900),
      lastDate: now.add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        if (dateType == 0) {
          _registryDate = picked;
        } else if (dateType == 1) {
          _dateOfBirth = picked;
          final diffYears = (DateTime.now().difference(picked).inDays / 365).floor();
          _ageController.text = diffYears >= 0 ? '$diffYears' : '0';
        } else if (dateType == 2) {
          _dateOfBaptism = picked;
          _dateOfBaptismHasError = false;
        } else {
          _dateOfConfirmation = picked;
          _dateOfConfirmationHasError = false;
        }
      });
    }
  }

  void _onFatherNotIndicatedToggle(bool? value) {
    setState(() {
      _fatherNotIndicated = value ?? false;
      if (_fatherNotIndicated) {
        _fatherFirstNameController.text = 'Not Indicated';
        _fatherMiddleNameController.clear();
        _fatherLastNameController.text = 'Not Indicated';
        _fatherOriginController.clear();
      } else {
        _fatherFirstNameController.clear();
        _fatherMiddleNameController.clear();
        _fatherLastNameController.clear();
        _fatherOriginController.clear();
      }
    });
  }

  // ===========================================================================
  // Step-by-Step Google Forms Pagination Logic
  // ===========================================================================

  bool _validateStep(int step) {
    setState(() => _errorMessage = null);

    if (step == 0) {
      // Step 1: Canonical Reference
      final b = int.tryParse(_bookNumberController.text.trim());
      final p = int.tryParse(_pageNumberController.text.trim());
      final l = int.tryParse(_lineNumberController.text.trim());

      if (b == null || b < 1 || b > 200) {
        setState(() => _errorMessage = 'Book number must be a valid number between 1 and 200.');
        return false;
      }
      if (p == null || p < 1 || p > 100) {
        setState(() => _errorMessage = 'Page number must be a valid number between 1 and 100.');
        return false;
      }
      if (l == null || l < 1 || l > 10) {
        setState(() => _errorMessage = 'Line number must be a valid number between 1 and 10.');
        return false;
      }
      return true;
    } else if (step == 1) {
      // Step 2: Confirmand Information
      final fnErr = _validateName(_confirmandFirstNameController.text, 'Confirmand First Name', isRequired: true);
      if (fnErr != null) {
        setState(() => _errorMessage = fnErr);
        return false;
      }
      final lnErr = _validateName(_confirmandLastNameController.text, 'Confirmand Last Name', isRequired: true);
      if (lnErr != null) {
        setState(() => _errorMessage = lnErr);
        return false;
      }
      if (_dateOfBaptism == null) {
        setState(() {
          _dateOfBaptismHasError = true;
          _errorMessage = 'Date of Baptism is required for confirmation registration.';
        });
        return false;
      }
      if (_dateOfBirth != null && _dateOfBaptism!.isBefore(_dateOfBirth!)) {
        setState(() {
          _dateOfBaptismHasError = true;
          _errorMessage = 'Date of Baptism cannot be earlier than Date of Birth.';
        });
        return false;
      }
      final cbErr = _validateRequiredText(_churchBaptizedController.text, 'Church Baptized');
      if (cbErr != null) {
        setState(() => _errorMessage = cbErr);
        return false;
      }
      return true;
    } else if (step == 2) {
      // Step 3: Parents Information
      if (!_fatherNotIndicated) {
        final ffnErr = _validateName(_fatherFirstNameController.text, "Father's first name", isRequired: true);
        if (ffnErr != null) {
          setState(() => _errorMessage = ffnErr);
          return false;
        }
        final flnErr = _validateName(_fatherLastNameController.text, "Father's last name", isRequired: true);
        if (flnErr != null) {
          setState(() => _errorMessage = flnErr);
          return false;
        }
      }
      final mfnErr = _validateName(_motherFirstNameController.text, "Mother's first name", isRequired: true);
      if (mfnErr != null) {
        setState(() => _errorMessage = mfnErr);
        return false;
      }
      final mlnErr = _validateName(_motherMaidenLastNameController.text, "Mother's maiden last name", isRequired: true);
      if (mlnErr != null) {
        setState(() => _errorMessage = mlnErr);
        return false;
      }
      return true;
    } else if (step == 3) {
      // Step 4: Confirmation Sponsors (Max 2)
      final s1FnErr = _validateName(_sponsor1FirstNameController.text, 'Sponsor 1 First Name', isRequired: true);
      if (s1FnErr != null) {
        setState(() => _errorMessage = s1FnErr);
        return false;
      }
      final s1LnErr = _validateName(_sponsor1LastNameController.text, 'Sponsor 1 Last Name', isRequired: true);
      if (s1LnErr != null) {
        setState(() => _errorMessage = s1LnErr);
        return false;
      }
      if (_sponsor2FirstNameController.text.trim().isNotEmpty) {
        final s2LnErr = _validateName(_sponsor2LastNameController.text, 'Sponsor 2 Last Name', isRequired: true);
        if (s2LnErr != null) {
          setState(() => _errorMessage = s2LnErr);
          return false;
        }
      }
      return true;
    } else if (step == 4) {
      // Step 5: Administration Details
      final pnErr = _validateRequiredText(_parishNameController.text, 'Parish Name');
      if (pnErr != null) {
        setState(() => _errorMessage = pnErr);
        return false;
      }
      final mfnErr = _validateName(_ministerFirstNameController.text, 'Minister first name', isRequired: true);
      if (mfnErr != null) {
        setState(() => _errorMessage = mfnErr);
        return false;
      }
      final mlnErr = _validateName(_ministerLastNameController.text, 'Minister last name', isRequired: true);
      if (mlnErr != null) {
        setState(() => _errorMessage = mlnErr);
        return false;
      }
      if (_dateOfConfirmation == null) {
        setState(() {
          _dateOfConfirmationHasError = true;
          _errorMessage = 'Date of Confirmation is required.';
        });
        return false;
      }
      if (_dateOfBaptism != null && _dateOfConfirmation!.isBefore(_dateOfBaptism!)) {
        setState(() {
          _dateOfConfirmationHasError = true;
          _errorMessage = 'Date of Confirmation cannot be earlier than Date of Baptism.';
        });
        return false;
      }
      final stErr = _validateStipend(_stipendController.text);
      if (stErr != null) {
        setState(() => _errorMessage = stErr);
        return false;
      }
      return true;
    }
    return true;
  }

  void _goToNextStep() {
    if (_validateStep(_currentStep)) {
      if (_currentStep < _totalSteps - 1) {
        setState(() {
          _currentStep++;
          _errorMessage = null;
        });
        _scrollToTop();
      } else {
        _submitForm();
      }
    }
  }

  void _goToPreviousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _errorMessage = null;
      });
      _scrollToTop();
    } else {
      Navigator.pop(context);
    }
  }

  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ===========================================================================
  // Final Form Submission
  // ===========================================================================

  Future<void> _submitForm() async {
    for (int s = 0; s < _totalSteps; s++) {
      if (!_validateStep(s)) {
        setState(() => _currentStep = s);
        _scrollToTop();
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      final int parsedAge = int.tryParse(_ageController.text.trim()) ?? 0;
      final double parsedStipend = _stipendController.text.trim().isNotEmpty
          ? (double.tryParse(_stipendController.text.trim()) ?? 0.00)
          : 0.00;

      final recordMap = {
        'book_number': _bookNumberController.text.trim(),
        'page_number': _pageNumberController.text.trim(),
        'line_number': _lineNumberController.text.trim(),
        'registry_date': _registryDate.toIso8601String().substring(0, 10),
        'entry_status': _entryStatus,

        'confirmand_first_name': _confirmandFirstNameController.text.trim(),
        'confirmand_middle_name': _confirmandMiddleNameController.text.trim().isEmpty ? null : _confirmandMiddleNameController.text.trim(),
        'confirmand_last_name': _confirmandLastNameController.text.trim(),
        'confirmand_suffix': _confirmandSuffixController.text.trim().isEmpty ? null : _confirmandSuffixController.text.trim(),
        'date_of_birth': _dateOfBirth?.toIso8601String().substring(0, 10),
        'age': parsedAge,
        'date_of_baptism': _dateOfBaptism!.toIso8601String().substring(0, 10),
        'church_baptized': _churchBaptizedController.text.trim(),
        'address': _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),

        'father_first_name': _fatherFirstNameController.text.trim(),
        'father_middle_name': _fatherMiddleNameController.text.trim().isEmpty ? null : _fatherMiddleNameController.text.trim(),
        'father_last_name': _fatherLastNameController.text.trim(),
        'father_origin': _fatherOriginController.text.trim().isEmpty ? null : _fatherOriginController.text.trim(),

        'mother_first_name': _motherFirstNameController.text.trim(),
        'mother_middle_name': _motherMiddleNameController.text.trim().isEmpty ? null : _motherMiddleNameController.text.trim(),
        'mother_maiden_last_name': _motherMaidenLastNameController.text.trim(),
        'mother_origin': _motherOriginController.text.trim().isEmpty ? null : _motherOriginController.text.trim(),

        'sponsor_1_first_name': _sponsor1FirstNameController.text.trim(),
        'sponsor_1_middle_name': _sponsor1MiddleNameController.text.trim().isEmpty ? null : _sponsor1MiddleNameController.text.trim(),
        'sponsor_1_last_name': _sponsor1LastNameController.text.trim(),
        'sponsor_1_origin_address': _sponsor1OriginAddressController.text.trim().isEmpty ? null : _sponsor1OriginAddressController.text.trim(),

        'sponsor_2_first_name': _sponsor2FirstNameController.text.trim().isEmpty ? null : _sponsor2FirstNameController.text.trim(),
        'sponsor_2_middle_name': _sponsor2MiddleNameController.text.trim().isEmpty ? null : _sponsor2MiddleNameController.text.trim(),
        'sponsor_2_last_name': _sponsor2LastNameController.text.trim().isEmpty ? null : _sponsor2LastNameController.text.trim(),
        'sponsor_2_origin_address': _sponsor2OriginAddressController.text.trim().isEmpty ? null : _sponsor2OriginAddressController.text.trim(),

        'date_of_confirmation': _dateOfConfirmation!.toIso8601String().substring(0, 10),
        'stipend': parsedStipend,
        'minister_first_name': _ministerFirstNameController.text.trim(),
        'minister_middle_name': _ministerMiddleNameController.text.trim().isEmpty ? null : _ministerMiddleNameController.text.trim(),
        'minister_last_name': _ministerLastNameController.text.trim(),
        'parish_name': _parishNameController.text.trim(),
        'remarks': _remarksController.text.trim().isEmpty ? null : _remarksController.text.trim(),
      };

      await ConfirmationService.insertManualConfirmationRecord(recordMap);

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Confirmation record registered successfully in Liber Confirmatorum.'),
          backgroundColor: ParishColors.oliveGreen,
          duration: Duration(seconds: 3),
        ),
      );

      widget.onRecordSaved?.call();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
          icon: const Icon(Icons.arrow_back, color: _pentecostRed, size: 26),
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Confirmation Manual Entry',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDarkColor),
            ),
            Text(
              'Canonical Registry Book (Liber Confirmatorum)',
              style: TextStyle(fontSize: 12, color: textMutedColor),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double availableWidth = constraints.maxWidth;
            final bool isMobile = availableWidth < 600;
            final bool isSmallMobile = availableWidth < 480;
            final double horizontalPadding = isMobile ? 16.0 : (availableWidth < 1024 ? 28.0 : 40.0);

            return Column(
              children: [
                // Google Forms Progress Banner
                Container(
                  width: double.infinity,
                  color: cardWhiteColor,
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 12),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 960),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Section ${_currentStep + 1} of $_totalSteps',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _pentecostRed,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                '${((_currentStep + 1) / _totalSteps * 100).toInt()}% Completed',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: textMutedColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (_currentStep + 1) / _totalSteps,
                              minHeight: 6,
                              backgroundColor: ParishColors.borderGrey.withOpacity(0.4),
                              valueColor: const AlwaysStoppedAnimation<Color>(_pentecostRed),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Divider(height: 1, color: borderGreyColor),

                // Form Page Content
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 18),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 960),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Google Forms Header Card
                              _buildGoogleFormsSectionHeader(
                                title: _stepTitles[_currentStep],
                                description: _stepDescriptions[_currentStep],
                                stepIndex: _currentStep,
                              ),
                              const SizedBox(height: 16),

                              // Validation Banner
                              if (_errorMessage != null) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: ParishColors.mercyRedSurface,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: ParishColors.mercyRed),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_outline, color: ParishColors.mercyRed, size: 22),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          _errorMessage!,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: ParishColors.mercyRed,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // Paginated Step View Switcher
                              _buildActiveStepContent(isMobile: isMobile, isSmallMobile: isSmallMobile),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Responsive Sticky Bottom Navigation Bar (Back, Next, Submit)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 14),
                  decoration: BoxDecoration(
                    color: cardWhiteColor,
                    border: Border(top: BorderSide(color: borderGreyColor)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, -3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 960),
                      child: isSmallMobile
                          ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _currentStep == _totalSteps - 1
                                    ? ParishColors.oliveGreen
                                    : _pentecostRed,
                                foregroundColor: Colors.white,
                                elevation: 1,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: _isSubmitting ? null : _goToNextStep,
                              icon: _isSubmitting
                                  ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                                  : Icon(
                                _currentStep == _totalSteps - 1 ? Icons.check : Icons.arrow_forward,
                                size: 20,
                              ),
                              label: Text(
                                _isSubmitting
                                    ? 'Registering...'
                                    : (_currentStep == _totalSteps - 1 ? 'Save Confirmation Record' : 'Continue / Next'),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: borderGreyColor, width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: _isSubmitting ? null : _goToPreviousStep,
                              child: Text(
                                _currentStep == 0 ? 'Discard / Exit' : 'Back to Previous Page',
                                style: TextStyle(fontSize: 14, color: textMutedColor),
                              ),
                            ),
                          ),
                        ],
                      )
                          : Row(
                        children: [
                          SizedBox(
                            width: isMobile ? 130 : 160,
                            height: 48,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: borderGreyColor, width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: _isSubmitting ? null : _goToPreviousStep,
                              child: Text(
                                _currentStep == 0 ? 'Discard / Exit' : 'Back',
                                style: TextStyle(fontSize: 14, color: textMutedColor),
                              ),
                            ),
                          ),
                          const Spacer(),
                          SizedBox(
                            width: isMobile ? 180 : 250,
                            height: 48,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _currentStep == _totalSteps - 1
                                    ? ParishColors.oliveGreen
                                    : _pentecostRed,
                                foregroundColor: Colors.white,
                                elevation: 1,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: _isSubmitting ? null : _goToNextStep,
                              icon: _isSubmitting
                                  ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                                  : Icon(
                                _currentStep == _totalSteps - 1 ? Icons.check : Icons.arrow_forward,
                                size: 20,
                              ),
                              label: Text(
                                _isSubmitting
                                    ? 'Registering...'
                                    : (_currentStep == _totalSteps - 1 ? 'Save Confirmation Record' : 'Next Section'),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ===========================================================================
  // Step Content Views
  // ===========================================================================

  Widget _buildActiveStepContent({required bool isMobile, required bool isSmallMobile}) {
    switch (_currentStep) {
      case 0:
        return _buildStep1CanonicalReference(isMobile: isMobile, isSmallMobile: isSmallMobile);
      case 1:
        return _buildStep2ConfirmandInformation(isMobile: isMobile);
      case 2:
        return _buildStep3ParentsInformation(isMobile: isMobile);
      case 3:
        return _buildStep4SponsorsInformation(isMobile: isMobile);
      case 4:
        return _buildStep5AdministrationDetails(isMobile: isMobile);
      default:
        return const SizedBox.shrink();
    }
  }

  // STEP 1: Canonical Reference
  Widget _buildStep1CanonicalReference({required bool isMobile, required bool isSmallMobile}) {
    return _buildSectionCard(
      title: 'Canonical Ledger Designation',
      icon: Icons.menu_book,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          isSmallMobile
              ? Column(
            children: [
              _buildTextFormField(
                controller: _bookNumberController,
                label: 'Book No.',
                isRequired: true,
                keyboardType: TextInputType.number,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Book number is required';
                  final num = int.tryParse(val.trim());
                  if (num == null) return 'Numbers only';
                  if (num < 1 || num > 200) return 'Must be between 1 and 200';
                  return null;
                },
              ),
              _buildTextFormField(
                controller: _pageNumberController,
                label: 'Page No.',
                isRequired: true,
                keyboardType: TextInputType.number,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Page number is required';
                  final num = int.tryParse(val.trim());
                  if (num == null) return 'Numbers only';
                  if (num < 1 || num > 100) return 'Must be between 1 and 100';
                  return null;
                },
              ),
              _buildTextFormField(
                controller: _lineNumberController,
                label: 'Line No.',
                isRequired: true,
                keyboardType: TextInputType.number,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Line number is required';
                  final num = int.tryParse(val.trim());
                  if (num == null) return 'Numbers only';
                  if (num < 1 || num > 10) return 'Must be between 1 and 10';
                  return null;
                },
              ),
            ],
          )
              : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildTextFormField(
                  controller: _bookNumberController,
                  label: 'Book No.',
                  isRequired: true,
                  keyboardType: TextInputType.number,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Required';
                    final num = int.tryParse(val.trim());
                    if (num == null) return 'Numbers only';
                    if (num < 1 || num > 200) return '1 to 200 only';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextFormField(
                  controller: _pageNumberController,
                  label: 'Page No.',
                  isRequired: true,
                  keyboardType: TextInputType.number,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Required';
                    final num = int.tryParse(val.trim());
                    if (num == null) return 'Numbers only';
                    if (num < 1 || num > 100) return '1 to 100 only';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextFormField(
                  controller: _lineNumberController,
                  label: 'Line No.',
                  isRequired: true,
                  keyboardType: TextInputType.number,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Required';
                    final num = int.tryParse(val.trim());
                    if (num == null) return 'Numbers only';
                    if (num < 1 || num > 10) return '1 to 10 only';
                    return null;
                  },
                ),
              ),
            ],
          ),
          _buildAdaptivePair(
            isStacked: isMobile,
            first: _buildDropdownField(
              label: 'Entry Status',
              isRequired: true,
              value: _entryStatus,
              items: const ['ORIGINAL', 'CORRECTED', 'INCOMPLETE'],
              onChanged: (val) => setState(() => _entryStatus = val!),
            ),
            second: _buildDatePickerField(
              label: 'Registry Date',
              isRequired: true,
              value: _registryDate,
              hasError: false,
              onTap: () => _selectDate(context, 0),
            ),
          ),
        ],
      ),
    );
  }

  // STEP 2: Confirmand Information
  Widget _buildStep2ConfirmandInformation({required bool isMobile}) {
    return _buildSectionCard(
      title: "Confirmand's Canonical Identification",
      icon: Icons.local_fire_department,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAdaptivePair(
            isStacked: isMobile,
            first: _buildTextFormField(
              controller: _confirmandFirstNameController,
              label: 'Confirmand First Name',
              isRequired: true,
              validator: (val) => _validateName(val, 'Confirmand first name', isRequired: true),
            ),
            second: _buildTextFormField(
              controller: _confirmandMiddleNameController,
              label: 'Middle Name',
              isRequired: false,
              validator: (val) => _validateName(val, 'Middle name', isRequired: false),
            ),
            flexFirst: 2,
            flexSecond: 1,
          ),
          _buildAdaptivePair(
            isStacked: isMobile,
            first: _buildTextFormField(
              controller: _confirmandLastNameController,
              label: 'Confirmand Last Name',
              isRequired: true,
              validator: (val) => _validateName(val, 'Confirmand last name', isRequired: true),
            ),
            second: _buildTextFormField(
              controller: _confirmandSuffixController,
              label: 'Suffix',
              isRequired: false,
            ),
            flexFirst: 2,
            flexSecond: 1,
          ),
          _buildAdaptivePair(
            isStacked: isMobile,
            first: _buildDatePickerField(
              label: 'Date of Birth (Optional)',
              isRequired: false,
              value: _dateOfBirth,
              hasError: false,
              onTap: () => _selectDate(context, 1),
            ),
            second: _buildTextFormField(
              controller: _ageController,
              label: 'Age',
              isRequired: false,
              keyboardType: TextInputType.number,
            ),
          ),
          _buildAdaptivePair(
            isStacked: isMobile,
            first: _buildDatePickerField(
              label: 'Date of Baptism',
              isRequired: true,
              value: _dateOfBaptism,
              hasError: _dateOfBaptismHasError,
              onTap: () => _selectDate(context, 2),
            ),
            second: _buildTextFormField(
              controller: _churchBaptizedController,
              label: 'Church Baptized',
              isRequired: true,
              validator: (val) => _validateRequiredText(val, 'Church baptized'),
            ),
          ),
          _buildTextFormField(
            controller: _addressController,
            label: 'Address / Residence',
            isRequired: false,
          ),
        ],
      ),
    );
  }

  // STEP 3: Parents Information
  Widget _buildStep3ParentsInformation({required bool isMobile}) {
    return Column(
      children: [
        // Father's Information
        _buildSectionCard(
          title: "Father's Lineage & Canon 877 §2",
          icon: Icons.person,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: _pentecostRed,
                title: const Text(
                  'Father not indicated / acknowledged in COLB (Canon 877 §2)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Fills canonical placeholder and displays "—" on issued certificates.',
                  style: TextStyle(fontSize: 11),
                ),
                value: _fatherNotIndicated,
                onChanged: _onFatherNotIndicatedToggle,
              ),
              const SizedBox(height: 6),
              _buildAdaptivePair(
                isStacked: isMobile,
                first: _buildTextFormField(
                  controller: _fatherFirstNameController,
                  label: 'Father First Name',
                  isRequired: !_fatherNotIndicated,
                  enabled: !_fatherNotIndicated,
                  validator: (val) => !_fatherNotIndicated ? _validateName(val, "Father's first name", isRequired: true) : null,
                ),
                second: _buildTextFormField(
                  controller: _fatherMiddleNameController,
                  label: 'Middle Name',
                  isRequired: false,
                  enabled: !_fatherNotIndicated,
                  validator: (val) => !_fatherNotIndicated ? _validateName(val, "Father's middle name", isRequired: false) : null,
                ),
              ),
              _buildAdaptivePair(
                isStacked: isMobile,
                first: _buildTextFormField(
                  controller: _fatherLastNameController,
                  label: 'Father Last Name',
                  isRequired: !_fatherNotIndicated,
                  enabled: !_fatherNotIndicated,
                  validator: (val) => !_fatherNotIndicated ? _validateName(val, "Father's last name", isRequired: true) : null,
                ),
                second: _buildTextFormField(
                  controller: _fatherOriginController,
                  label: 'Place of Origin',
                  isRequired: false,
                  enabled: !_fatherNotIndicated,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Mother's Information
        _buildSectionCard(
          title: "Mother's Lineage & Origin",
          icon: Icons.person_outline,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAdaptivePair(
                isStacked: isMobile,
                first: _buildTextFormField(
                  controller: _motherFirstNameController,
                  label: 'Mother First Name',
                  isRequired: true,
                  validator: (val) => _validateName(val, "Mother's first name", isRequired: true),
                ),
                second: _buildTextFormField(
                  controller: _motherMiddleNameController,
                  label: 'Middle Name',
                  isRequired: false,
                  validator: (val) => _validateName(val, "Mother's middle name", isRequired: false),
                ),
              ),
              _buildAdaptivePair(
                isStacked: isMobile,
                first: _buildTextFormField(
                  controller: _motherMaidenLastNameController,
                  label: 'Mother Maiden Last Name',
                  isRequired: true,
                  validator: (val) => _validateName(val, "Mother's maiden last name", isRequired: true),
                ),
                second: _buildTextFormField(
                  controller: _motherOriginController,
                  label: 'Place of Origin',
                  isRequired: false,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // STEP 4: Sponsors Information
  Widget _buildStep4SponsorsInformation({required bool isMobile}) {
    return _buildSectionCard(
      title: 'Confirmation Sponsors (Strictly Max 2)',
      icon: Icons.people_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Canonical Confirmation registers limit sponsors to Sponsor 1 (Required) and Sponsor 2 (Optional).',
            style: TextStyle(fontSize: 12, color: _pentecostRed, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),

          // Sponsor 1
          _buildAdaptivePair(
            isStacked: isMobile,
            first: _buildTextFormField(
              controller: _sponsor1FirstNameController,
              label: 'Sponsor 1 First Name',
              isRequired: true,
              validator: (val) => _validateName(val, 'Sponsor 1 first name', isRequired: true),
            ),
            second: _buildTextFormField(
              controller: _sponsor1MiddleNameController,
              label: 'Middle Name',
              isRequired: false,
              validator: (val) => _validateName(val, 'Sponsor 1 middle name', isRequired: false),
            ),
          ),
          _buildAdaptivePair(
            isStacked: isMobile,
            first: _buildTextFormField(
              controller: _sponsor1LastNameController,
              label: 'Sponsor 1 Last Name',
              isRequired: true,
              validator: (val) => _validateName(val, 'Sponsor 1 last name', isRequired: true),
            ),
            second: _buildTextFormField(
              controller: _sponsor1OriginAddressController,
              label: 'Sponsor 1 Origin / Address',
              isRequired: false,
            ),
          ),

          const Divider(height: 28),

          // Sponsor 2 (Optional)
          _buildAdaptivePair(
            isStacked: isMobile,
            first: _buildTextFormField(
              controller: _sponsor2FirstNameController,
              label: 'Sponsor 2 First Name (Optional)',
              isRequired: false,
              validator: (val) => _validateName(val, 'Sponsor 2 first name', isRequired: false),
            ),
            second: _buildTextFormField(
              controller: _sponsor2MiddleNameController,
              label: 'Middle Name',
              isRequired: false,
              validator: (val) => _validateName(val, 'Sponsor 2 middle name', isRequired: false),
            ),
          ),
          _buildAdaptivePair(
            isStacked: isMobile,
            first: _buildTextFormField(
              controller: _sponsor2LastNameController,
              label: 'Sponsor 2 Last Name',
              isRequired: false,
              validator: (val) => _validateName(val, 'Sponsor 2 last name', isRequired: false),
            ),
            second: _buildTextFormField(
              controller: _sponsor2OriginAddressController,
              label: 'Sponsor 2 Origin / Address',
              isRequired: false,
            ),
          ),
        ],
      ),
    );
  }

  // STEP 5: Administration Details
  Widget _buildStep5AdministrationDetails({required bool isMobile}) {
    return _buildSectionCard(
      title: 'Confirmation Administration & Minister Details',
      icon: Icons.church,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextFormField(
            controller: _parishNameController,
            label: 'Parish Name',
            isRequired: true,
            validator: (val) => _validateRequiredText(val, 'Parish name'),
          ),
          _buildAdaptivePair(
            isStacked: isMobile,
            first: _buildTextFormField(
              controller: _ministerFirstNameController,
              label: 'Minister / Bishop First Name',
              isRequired: true,
              validator: (val) => _validateName(val, 'Minister first name', isRequired: true),
            ),
            second: _buildTextFormField(
              controller: _ministerMiddleNameController,
              label: 'Middle Name',
              isRequired: false,
              validator: (val) => _validateName(val, 'Minister middle name', isRequired: false),
            ),
          ),
          _buildTextFormField(
            controller: _ministerLastNameController,
            label: 'Minister / Bishop Last Name',
            isRequired: true,
            validator: (val) => _validateName(val, 'Minister last name', isRequired: true),
          ),
          _buildAdaptivePair(
            isStacked: isMobile,
            first: _buildDatePickerField(
              label: 'Date of Confirmation',
              isRequired: true,
              value: _dateOfConfirmation,
              hasError: _dateOfConfirmationHasError,
              onTap: () => _selectDate(context, 3),
            ),
            second: _buildTextFormField(
              controller: _stipendController,
              label: 'Stipend (₱)',
              isRequired: false,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: _validateStipend,
            ),
          ),
          _buildTextFormField(
            controller: _remarksController,
            label: 'Canonical Remarks / Marginal Notations',
            isRequired: false,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Google Forms Visual Components
  // ===========================================================================

  Widget _buildGoogleFormsSectionHeader({
    required String title,
    required String description,
    required int stepIndex,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ParishColors.borderGrey),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Google Forms Top Color Bar (Pentecost Red)
          Container(
            height: 8,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: _pentecostRed,
              borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'SECTION ${stepIndex + 1} OF $_totalSteps',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _pentecostRed,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDF2F2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Canonical Step',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _pentecostRed,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ParishColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: ParishColors.textMuted,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdaptivePair({
    required bool isStacked,
    required Widget first,
    required Widget second,
    int flexFirst = 1,
    int flexSecond = 1,
  }) {
    if (isStacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [first, second],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: flexFirst, child: first),
        const SizedBox(width: 12),
        Expanded(flex: flexSecond, child: second),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ParishColors.borderGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: _pentecostRed),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: _pentecostRed,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label, {bool isRequired = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: ParishColors.textDark,
          ),
          children: [
            TextSpan(text: label),
            if (isRequired)
              const TextSpan(
                text: ' *',
                style: TextStyle(
                  color: _pentecostRed,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required bool isRequired,
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldLabel(label, isRequired: isRequired),
          TextFormField(
            controller: controller,
            enabled: enabled,
            keyboardType: keyboardType,
            maxLines: maxLines,
            validator: validator,
            style: TextStyle(fontSize: 14, color: enabled ? ParishColors.textDark : ParishColors.textMuted),
            decoration: InputDecoration(
              filled: true,
              fillColor: enabled ? ParishColors.backgroundLight : ParishColors.borderGrey.withOpacity(0.2),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: ParishColors.borderGrey),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: ParishColors.borderGrey),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _pentecostRed, width: 1.8),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _pentecostRed, width: 1.2),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _pentecostRed, width: 1.8),
              ),
              errorStyle: const TextStyle(
                color: _pentecostRed,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePickerField({
    required String label,
    required bool isRequired,
    required DateTime? value,
    required bool hasError,
    required VoidCallback onTap,
  }) {
    final borderColor = hasError ? _pentecostRed : ParishColors.borderGrey;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldLabel(label, isRequired: isRequired),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: ParishColors.backgroundLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor, width: hasError ? 1.4 : 1.0),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    value != null ? value.toIso8601String().substring(0, 10) : 'YYYY-MM-DD',
                    style: TextStyle(
                      fontSize: 14,
                      color: value != null ? ParishColors.textDark : ParishColors.textMuted,
                    ),
                  ),
                  Icon(
                    Icons.calendar_month,
                    size: 20,
                    color: _pentecostRed,
                  ),
                ],
              ),
            ),
          ),
          if (hasError)
            const Padding(
              padding: EdgeInsets.only(top: 6, left: 12),
              child: Text(
                'Date selection is required.',
                style: TextStyle(color: _pentecostRed, fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required bool isRequired,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldLabel(label, isRequired: isRequired),
          DropdownButtonFormField<String>(
            value: value,
            items: items.map((item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(item, style: TextStyle(fontSize: 13, color: ParishColors.textDark)),
              );
            }).toList(),
            onChanged: onChanged,
            style: TextStyle(fontSize: 13, color: ParishColors.textDark),
            decoration: InputDecoration(
              filled: true,
              fillColor: ParishColors.backgroundLight,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: ParishColors.borderGrey),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: ParishColors.borderGrey),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _pentecostRed, width: 1.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}