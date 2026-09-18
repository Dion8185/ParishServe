import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../services/matrimony_service.dart';
import '../dialogs/discard_entry_dialog.dart';

class MatrimonyManualEntryPage extends StatefulWidget {
  final VoidCallback? onRecordSaved;

  const MatrimonyManualEntryPage({super.key, this.onRecordSaved});

  @override
  State<MatrimonyManualEntryPage> createState() => _MatrimonyManualEntryPageState();
}

class _MatrimonyManualEntryPageState extends State<MatrimonyManualEntryPage> {
  final _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();

  // Royal Amethyst / Burgundy Theme Accent for Matrimony
  static const Color _matrimonyBurgundy = Color(0xFF9D174D);
  static const Color _burgundySurface = Color(0xFFFCE7F3);

  // Pagination State (5 Google Forms-Style Sections)
  int _currentStep = 0;
  static const int _totalSteps = 5;

  static const List<String> _stepTitles = [
    'Canonical Record Reference',
    "Groom's Personal & Parental Info",
    "Bride's Personal & Parental Info",
    'Primary & Additional Witnesses / Sponsors',
    'Marriage Ceremony & Civil Compliance',
  ];

  static const List<String> _stepDescriptions = [
    'Specify book, page, line, and registration status from the physical marriage register.',
    'Groom identification, civil status, residence, and parents lineage.',
    'Bride identification, civil status, residence, and parents lineage.',
    'Strictly 2 Primary Sponsors plus dynamic additional witnesses (using [+] Add Witness).',
    'Date of matrimony, solemnizing minister, CRASM credentials, and marriage license info.',
  ];

  // 1. Canonical Record Reference (Page 1)
  final _bookNumberController = TextEditingController();
  final _pageNumberController = TextEditingController();
  final _lineNumberController = TextEditingController();
  String _entryStatus = 'ORIGINAL';
  DateTime _registryDate = DateTime.now();

  // 2. Groom Information (Page 2)
  final _groomFirstNameController = TextEditingController();
  final _groomMiddleNameController = TextEditingController();
  final _groomLastNameController = TextEditingController();
  final _groomSuffixController = TextEditingController();
  String _groomCivilStatus = 'Single';
  final _groomAgeController = TextEditingController();
  DateTime? _groomDateOfBirth;
  final _groomPlaceOfBirthController = TextEditingController();
  final _groomAddressController = TextEditingController();
  final _groomFatherFirstNameController = TextEditingController();
  final _groomFatherMiddleNameController = TextEditingController();
  final _groomFatherLastNameController = TextEditingController();
  final _groomMotherFirstNameController = TextEditingController();
  final _groomMotherMiddleNameController = TextEditingController();
  final _groomMotherMaidenLastController = TextEditingController();

  // 3. Bride Information (Page 3)
  final _brideFirstNameController = TextEditingController();
  final _brideMiddleNameController = TextEditingController();
  final _brideLastNameController = TextEditingController();
  final _brideSuffixController = TextEditingController();
  String _brideCivilStatus = 'Single';
  final _brideAgeController = TextEditingController();
  DateTime? _brideDateOfBirth;
  final _bridePlaceOfBirthController = TextEditingController();
  final _brideAddressController = TextEditingController();
  final _brideFatherFirstNameController = TextEditingController();
  final _brideFatherMiddleNameController = TextEditingController();
  final _brideFatherLastNameController = TextEditingController();
  final _brideMotherFirstNameController = TextEditingController();
  final _brideMotherMiddleNameController = TextEditingController();
  final _brideMotherMaidenLastController = TextEditingController();

  // 4. Sponsors (Page 4)
  final _sponsor1FirstNameController = TextEditingController();
  final _sponsor1MiddleNameController = TextEditingController();
  final _sponsor1LastNameController = TextEditingController();
  final _sponsor1OriginAddressController = TextEditingController();

  final _sponsor2FirstNameController = TextEditingController();
  final _sponsor2MiddleNameController = TextEditingController();
  final _sponsor2LastNameController = TextEditingController();
  final _sponsor2OriginAddressController = TextEditingController();

  // Dynamic Other Sponsors List (Plus button implementation)
  final List<TextEditingController> _otherSponsorControllers = [];

  // 5. Ceremony & Legal Details (Page 5)
  DateTime? _dateOfMarriage = DateTime.now();
  String _marriageType = 'Between Catholics';
  bool _isFilipinoForeigner = false;
  final _marriageLicenseNoController = TextEditingController();
  DateTime? _licenseDateRegistered;
  final _licensePlaceIssuedController = TextEditingController();

  final _solemnizerFirstNameController = TextEditingController(text: 'Joseph');
  final _solemnizerMiddleNameController = TextEditingController();
  final _solemnizerLastNameController = TextEditingController(text: 'Santos');
  final _crasmNumberController = TextEditingController();
  DateTime? _crasmValidityDate;
  final _stipendController = TextEditingController();
  final _parishNameController = TextEditingController(text: 'St. John Paul II Parish');
  final _remarksController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;
  bool _dateOfMarriageHasError = false;

  @override
  void dispose() {
    _scrollController.dispose();
    _bookNumberController.dispose();
    _pageNumberController.dispose();
    _lineNumberController.dispose();
    _groomFirstNameController.dispose();
    _groomMiddleNameController.dispose();
    _groomLastNameController.dispose();
    _groomSuffixController.dispose();
    _groomAgeController.dispose();
    _groomPlaceOfBirthController.dispose();
    _groomAddressController.dispose();
    _groomFatherFirstNameController.dispose();
    _groomFatherMiddleNameController.dispose();
    _groomFatherLastNameController.dispose();
    _groomMotherFirstNameController.dispose();
    _groomMotherMiddleNameController.dispose();
    _groomMotherMaidenLastController.dispose();
    _brideFirstNameController.dispose();
    _brideMiddleNameController.dispose();
    _brideLastNameController.dispose();
    _brideSuffixController.dispose();
    _brideAgeController.dispose();
    _bridePlaceOfBirthController.dispose();
    _brideAddressController.dispose();
    _brideFatherFirstNameController.dispose();
    _brideFatherMiddleNameController.dispose();
    _brideFatherLastNameController.dispose();
    _brideMotherFirstNameController.dispose();
    _brideMotherMiddleNameController.dispose();
    _brideMotherMaidenLastController.dispose();
    _sponsor1FirstNameController.dispose();
    _sponsor1MiddleNameController.dispose();
    _sponsor1LastNameController.dispose();
    _sponsor1OriginAddressController.dispose();
    _sponsor2FirstNameController.dispose();
    _sponsor2MiddleNameController.dispose();
    _sponsor2LastNameController.dispose();
    _sponsor2OriginAddressController.dispose();
    for (var c in _otherSponsorControllers) {
      c.dispose();
    }
    _marriageLicenseNoController.dispose();
    _licensePlaceIssuedController.dispose();
    _solemnizerFirstNameController.dispose();
    _solemnizerMiddleNameController.dispose();
    _solemnizerLastNameController.dispose();
    _crasmNumberController.dispose();
    _stipendController.dispose();
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
      return 'Enter a valid amount (e.g. 500.00).';
    }
    return null;
  }

  Future<void> _selectDate(BuildContext context, int dateType) async {
    // 0: Registry, 1: Groom DOB, 2: Bride DOB, 3: Marriage Date, 4: License Registered, 5: CRASM Validity
    final now = DateTime.now();
    DateTime initialDate = now;

    if (dateType == 0) initialDate = _registryDate;
    if (dateType == 1) initialDate = _groomDateOfBirth ?? DateTime(now.year - 25, 1, 1);
    if (dateType == 2) initialDate = _brideDateOfBirth ?? DateTime(now.year - 23, 1, 1);
    if (dateType == 3) initialDate = _dateOfMarriage ?? now;
    if (dateType == 4) initialDate = _licenseDateRegistered ?? now;
    if (dateType == 5) initialDate = _crasmValidityDate ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(now) && dateType < 3 ? now : initialDate,
      firstDate: DateTime(1900),
      lastDate: now.add(const Duration(days: 3650)),
    );

    if (picked != null) {
      setState(() {
        if (dateType == 0) _registryDate = picked;
        if (dateType == 1) _groomDateOfBirth = picked;
        if (dateType == 2) _brideDateOfBirth = picked;
        if (dateType == 3) {
          _dateOfMarriage = picked;
          _dateOfMarriageHasError = false;
        }
        if (dateType == 4) _licenseDateRegistered = picked;
        if (dateType == 5) _crasmValidityDate = picked;
      });
    }
  }

  void _addOtherSponsorField() {
    setState(() {
      _otherSponsorControllers.add(TextEditingController());
    });
  }

  void _removeOtherSponsorField(int index) {
    setState(() {
      _otherSponsorControllers[index].dispose();
      _otherSponsorControllers.removeAt(index);
    });
  }

  // ===========================================================================
  // Step Validation with Live Form State Checking
  // ===========================================================================

  bool _validateStep(int step) {
    setState(() => _errorMessage = null);

    final isStepValid = _formKey.currentState?.validate() ?? true;

    if (!isStepValid) {
      setState(() => _errorMessage = 'Please correct the highlighted errors below before proceeding.');
      return false;
    }

    if (step == 0) {
      final b = int.tryParse(_bookNumberController.text.trim());
      final p = int.tryParse(_pageNumberController.text.trim());
      final l = int.tryParse(_lineNumberController.text.trim());

      if (b == null || b < 1 || b > 200) {
        setState(() => _errorMessage = 'Book number must be between 1 and 200.');
        return false;
      }
      if (p == null || p < 1 || p > 100) {
        setState(() => _errorMessage = 'Page number must be between 1 and 100.');
        return false;
      }
      if (l == null || l < 1 || l > 10) {
        setState(() => _errorMessage = 'Line number must be between 1 and 10.');
        return false;
      }
      return true;
    } else if (step == 4) {
      if (_dateOfMarriage == null) {
        setState(() {
          _dateOfMarriageHasError = true;
          _errorMessage = 'Date of Marriage is required.';
        });
        return false;
      }
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

  Future<void> _goToPreviousStep() async {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _errorMessage = null;
      });
      _scrollToTop();
    } else {
      final shouldExit = await showDiscardConfirmationDialog(
        context,
        accentColor: _matrimonyBurgundy,
      );
      if (shouldExit && mounted) {
        Navigator.pop(context);
      }
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
      List<String> collectedOtherSponsors = _otherSponsorControllers
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      final recordMap = {
        'book_number': _bookNumberController.text.trim(),
        'page_number': _pageNumberController.text.trim(),
        'line_number': _lineNumberController.text.trim(),
        'registry_date': _registryDate.toIso8601String().substring(0, 10),
        'entry_status': _entryStatus,

        // Groom
        'groom_first_name': _groomFirstNameController.text.trim(),
        'groom_middle_name': _groomMiddleNameController.text.trim().isEmpty ? null : _groomMiddleNameController.text.trim(),
        'groom_last_name': _groomLastNameController.text.trim(),
        'groom_suffix': _groomSuffixController.text.trim().isEmpty ? null : _groomSuffixController.text.trim(),
        'groom_civil_status': _groomCivilStatus,
        'groom_age': int.parse(_groomAgeController.text.trim()),
        'groom_date_of_birth': _groomDateOfBirth?.toIso8601String().substring(0, 10),
        'groom_place_of_birth': _groomPlaceOfBirthController.text.trim().isEmpty ? null : _groomPlaceOfBirthController.text.trim(),
        'groom_address': _groomAddressController.text.trim(),
        'groom_father_first_name': _groomFatherFirstNameController.text.trim(),
        'groom_father_middle_name': _groomFatherMiddleNameController.text.trim().isEmpty ? null : _groomFatherMiddleNameController.text.trim(),
        'groom_father_last_name': _groomFatherLastNameController.text.trim(),
        'groom_mother_first_name': _groomMotherFirstNameController.text.trim(),
        'groom_mother_middle_name': _groomMotherMiddleNameController.text.trim().isEmpty ? null : _groomMotherMiddleNameController.text.trim(),
        'groom_mother_maiden_last': _groomMotherMaidenLastController.text.trim(),

        // Bride
        'bride_first_name': _brideFirstNameController.text.trim(),
        'bride_middle_name': _brideMiddleNameController.text.trim().isEmpty ? null : _brideMiddleNameController.text.trim(),
        'bride_last_name': _brideLastNameController.text.trim(),
        'bride_suffix': _brideSuffixController.text.trim().isEmpty ? null : _brideSuffixController.text.trim(),
        'bride_civil_status': _brideCivilStatus,
        'bride_age': int.parse(_brideAgeController.text.trim()),
        'bride_date_of_birth': _brideDateOfBirth?.toIso8601String().substring(0, 10),
        'bride_place_of_birth': _bridePlaceOfBirthController.text.trim().isEmpty ? null : _bridePlaceOfBirthController.text.trim(),
        'bride_address': _brideAddressController.text.trim(),
        'bride_father_first_name': _brideFatherFirstNameController.text.trim(),
        'bride_father_middle_name': _brideFatherMiddleNameController.text.trim().isEmpty ? null : _brideFatherMiddleNameController.text.trim(),
        'bride_father_last_name': _brideFatherLastNameController.text.trim(),
        'bride_mother_first_name': _brideMotherFirstNameController.text.trim(),
        'bride_mother_middle_name': _brideMotherMiddleNameController.text.trim().isEmpty ? null : _brideMotherMiddleNameController.text.trim(),
        'bride_mother_maiden_last': _brideMotherMaidenLastController.text.trim(),

        // Sponsors
        'sponsor_1_first_name': _sponsor1FirstNameController.text.trim(),
        'sponsor_1_middle_name': _sponsor1MiddleNameController.text.trim().isEmpty ? null : _sponsor1MiddleNameController.text.trim(),
        'sponsor_1_last_name': _sponsor1LastNameController.text.trim(),
        'sponsor_1_origin_address': _sponsor1OriginAddressController.text.trim().isEmpty ? null : _sponsor1OriginAddressController.text.trim(),
        'sponsor_2_first_name': _sponsor2FirstNameController.text.trim(),
        'sponsor_2_middle_name': _sponsor2MiddleNameController.text.trim().isEmpty ? null : _sponsor2MiddleNameController.text.trim(),
        'sponsor_2_last_name': _sponsor2LastNameController.text.trim(),
        'sponsor_2_origin_address': _sponsor2OriginAddressController.text.trim().isEmpty ? null : _sponsor2OriginAddressController.text.trim(),
        'other_sponsors': collectedOtherSponsors.join('\n'),

        // Ceremony Details
        'date_of_marriage': _dateOfMarriage!.toIso8601String().substring(0, 10),
        'marriage_type': _marriageType,
        'is_filipino_foreigner': _isFilipinoForeigner,
        'marriage_license_no': _marriageLicenseNoController.text.trim().isEmpty ? null : _marriageLicenseNoController.text.trim(),
        'license_date_registered': _licenseDateRegistered?.toIso8601String().substring(0, 10),
        'license_place_issued': _licensePlaceIssuedController.text.trim().isEmpty ? null : _licensePlaceIssuedController.text.trim(),

        // Minister
        'solemnizer_first_name': _solemnizerFirstNameController.text.trim(),
        'solemnizer_middle_name': _solemnizerMiddleNameController.text.trim().isEmpty ? null : _solemnizerMiddleNameController.text.trim(),
        'solemnizer_last_name': _solemnizerLastNameController.text.trim(),
        'crasm_number': _crasmNumberController.text.trim().isEmpty ? null : _crasmNumberController.text.trim(),
        'crasm_validity_date': _crasmValidityDate?.toIso8601String().substring(0, 10),
        'stipend': _stipendController.text.trim().isNotEmpty ? double.parse(_stipendController.text.trim()) : 0.00,
        'remarks': _remarksController.text.trim().isEmpty ? null : _remarksController.text.trim(),
        'parish_name': _parishNameController.text.trim(),
      };

      await MatrimonyService.insertManualMatrimonyRecord(recordMap);

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Matrimony record successfully registered in Liber Matrimoniorum.'),
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_isSubmitting) return;
        final shouldExit = await showDiscardConfirmationDialog(
          context,
          accentColor: _matrimonyBurgundy,
        );
        if (shouldExit && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: ParishColors.backgroundLight,
        appBar: AppBar(
          backgroundColor: cardWhiteColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: _matrimonyBurgundy, size: 26),
            onPressed: _isSubmitting
                ? null
                : () async {
              final shouldExit = await showDiscardConfirmationDialog(
                context,
                accentColor: _matrimonyBurgundy,
              );
              if (shouldExit && context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Matrimony Manual Entry',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDarkColor),
              ),
              Text(
                'Canonical Registry Book (Liber Matrimoniorum)',
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
                                    color: _matrimonyBurgundy,
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
                                valueColor: const AlwaysStoppedAnimation<Color>(_matrimonyBurgundy),
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
                            autovalidateMode: AutovalidateMode.onUserInteraction, // Live real-time validation feedback
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildGoogleFormsSectionHeader(
                                  title: _stepTitles[_currentStep],
                                  description: _stepDescriptions[_currentStep],
                                  stepIndex: _currentStep,
                                ),
                                const SizedBox(height: 16),

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

                                _buildActiveStepContent(isMobile: isMobile, isSmallMobile: isSmallMobile),
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Sticky Bottom Bar
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
                                      : _matrimonyBurgundy,
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
                                      : (_currentStep == _totalSteps - 1 ? 'Save Matrimony Record' : 'Continue / Next'),
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
                              width: isMobile ? 190 : 260,
                              height: 48,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _currentStep == _totalSteps - 1
                                      ? ParishColors.oliveGreen
                                      : _matrimonyBurgundy,
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
                                      : (_currentStep == _totalSteps - 1 ? 'Save Matrimony Record' : 'Next Section'),
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
      ),
    );
  }

  // ===========================================================================
  // Step Views Router
  // ===========================================================================

  Widget _buildActiveStepContent({required bool isMobile, required bool isSmallMobile}) {
    switch (_currentStep) {
      case 0:
        return _buildStep1CanonicalReference(isMobile: isMobile, isSmallMobile: isSmallMobile);
      case 1:
        return _buildStep2GroomInformation(isMobile: isMobile);
      case 2:
        return _buildStep3BrideInformation(isMobile: isMobile);
      case 3:
        return _buildStep4SponsorsInformation(isMobile: isMobile);
      case 4:
        return _buildStep5CeremonyAndLegal(isMobile: isMobile);
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
              _buildTextFormField(controller: _bookNumberController, label: 'Book No.', isRequired: true, keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Required' : null),
              _buildTextFormField(controller: _pageNumberController, label: 'Page No.', isRequired: true, keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Required' : null),
              _buildTextFormField(controller: _lineNumberController, label: 'Line No.', isRequired: true, keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Required' : null),
            ],
          )
              : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildTextFormField(controller: _bookNumberController, label: 'Book No.', isRequired: true, keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Required' : null)),
              const SizedBox(width: 12),
              Expanded(child: _buildTextFormField(controller: _pageNumberController, label: 'Page No.', isRequired: true, keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Required' : null)),
              const SizedBox(width: 12),
              Expanded(child: _buildTextFormField(controller: _lineNumberController, label: 'Line No.', isRequired: true, keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Required' : null)),
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

  // STEP 2: Groom Information
  Widget _buildStep2GroomInformation({required bool isMobile}) {
    return Column(
      children: [
        _buildSectionCard(
          title: "Groom's Personal Particulars",
          icon: Icons.male,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAdaptivePair(
                isStacked: isMobile,
                first: _buildTextFormField(
                  controller: _groomFirstNameController,
                  label: "Groom's First Name",
                  isRequired: true,
                  validator: (val) => _validateName(val, "Groom's first name"),
                ),
                second: _buildTextFormField(
                  controller: _groomMiddleNameController,
                  label: 'Middle Name',
                  isRequired: false,
                ),
              ),
              _buildAdaptivePair(
                isStacked: isMobile,
                first: _buildTextFormField(
                  controller: _groomLastNameController,
                  label: "Groom's Last Name",
                  isRequired: true,
                  validator: (val) => _validateName(val, "Groom's last name"),
                ),
                second: _buildTextFormField(
                  controller: _groomSuffixController,
                  label: 'Suffix',
                  isRequired: false,
                ),
              ),
              _buildAdaptivePair(
                isStacked: isMobile,
                first: _buildDropdownField(
                  label: 'Civil Status',
                  isRequired: true,
                  value: _groomCivilStatus,
                  items: const ['Single', 'Widower', 'Annulled', 'Divorced'],
                  onChanged: (val) => setState(() => _groomCivilStatus = val!),
                ),
                second: _buildTextFormField(
                  controller: _groomAgeController,
                  label: 'Age',
                  isRequired: true,
                  keyboardType: TextInputType.number,
                  validator: (val) => int.tryParse(val?.trim() ?? '') == null ? 'Enter valid age' : null,
                ),
              ),
              _buildAdaptivePair(
                isStacked: isMobile,
                first: _buildDatePickerField(
                  label: 'Date of Birth (Optional)',
                  isRequired: false,
                  value: _groomDateOfBirth,
                  hasError: false,
                  onTap: () => _selectDate(context, 1),
                ),
                second: _buildTextFormField(
                  controller: _groomPlaceOfBirthController,
                  label: 'Place of Birth',
                  isRequired: false,
                ),
              ),
              _buildTextFormField(
                controller: _groomAddressController,
                label: "Groom's Residential Address",
                isRequired: true,
                validator: (val) => _validateRequiredText(val, "Groom's address"),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          title: "Groom's Parents",
          icon: Icons.people,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAdaptivePair(
                isStacked: isMobile,
                first: _buildTextFormField(
                  controller: _groomFatherFirstNameController,
                  label: "Father's First Name",
                  isRequired: true,
                  validator: (val) => _validateName(val, "Father's first name"),
                ),
                second: _buildTextFormField(
                  controller: _groomFatherMiddleNameController,
                  label: "Father's Middle Name",
                  isRequired: false,
                ),
              ),
              _buildTextFormField(
                controller: _groomFatherLastNameController,
                label: "Father's Last Name",
                isRequired: true,
                validator: (val) => _validateName(val, "Father's last name"),
              ),
              const Divider(height: 24),
              _buildAdaptivePair(
                isStacked: isMobile,
                first: _buildTextFormField(
                  controller: _groomMotherFirstNameController,
                  label: "Mother's First Name",
                  isRequired: true,
                  validator: (val) => _validateName(val, "Mother's first name"),
                ),
                second: _buildTextFormField(
                  controller: _groomMotherMiddleNameController,
                  label: "Mother's Middle Name",
                  isRequired: false,
                ),
              ),
              _buildTextFormField(
                controller: _groomMotherMaidenLastController,
                label: "Mother's Maiden Last Name",
                isRequired: true,
                validator: (val) => _validateName(val, "Mother's maiden last name"),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // STEP 3: Bride Information
  Widget _buildStep3BrideInformation({required bool isMobile}) {
    return Column(
      children: [
        _buildSectionCard(
          title: "Bride's Personal Particulars",
          icon: Icons.female,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAdaptivePair(
                isStacked: isMobile,
                first: _buildTextFormField(
                  controller: _brideFirstNameController,
                  label: "Bride's First Name",
                  isRequired: true,
                  validator: (val) => _validateName(val, "Bride's first name"),
                ),
                second: _buildTextFormField(
                  controller: _brideMiddleNameController,
                  label: 'Middle Name',
                  isRequired: false,
                ),
              ),
              _buildAdaptivePair(
                isStacked: isMobile,
                first: _buildTextFormField(
                  controller: _brideLastNameController,
                  label: "Bride's Last Name",
                  isRequired: true,
                  validator: (val) => _validateName(val, "Bride's last name"),
                ),
                second: _buildTextFormField(
                  controller: _brideSuffixController,
                  label: 'Suffix',
                  isRequired: false,
                ),
              ),
              _buildAdaptivePair(
                isStacked: isMobile,
                first: _buildDropdownField(
                  label: 'Civil Status',
                  isRequired: true,
                  value: _brideCivilStatus,
                  items: const ['Single', 'Widow', 'Annulled', 'Divorced'],
                  onChanged: (val) => setState(() => _brideCivilStatus = val!),
                ),
                second: _buildTextFormField(
                  controller: _brideAgeController,
                  label: 'Age',
                  isRequired: true,
                  keyboardType: TextInputType.number,
                  validator: (val) => int.tryParse(val?.trim() ?? '') == null ? 'Enter valid age' : null,
                ),
              ),
              _buildAdaptivePair(
                isStacked: isMobile,
                first: _buildDatePickerField(
                  label: 'Date of Birth (Optional)',
                  isRequired: false,
                  value: _brideDateOfBirth,
                  hasError: false,
                  onTap: () => _selectDate(context, 2),
                ),
                second: _buildTextFormField(
                  controller: _bridePlaceOfBirthController,
                  label: 'Place of Birth',
                  isRequired: false,
                ),
              ),
              _buildTextFormField(
                controller: _brideAddressController,
                label: "Bride's Residential Address",
                isRequired: true,
                validator: (val) => _validateRequiredText(val, "Bride's address"),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          title: "Bride's Parents",
          icon: Icons.people,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAdaptivePair(
                isStacked: isMobile,
                first: _buildTextFormField(
                  controller: _brideFatherFirstNameController,
                  label: "Father's First Name",
                  isRequired: true,
                  validator: (val) => _validateName(val, "Father's first name"),
                ),
                second: _buildTextFormField(
                  controller: _brideFatherMiddleNameController,
                  label: "Father's Middle Name",
                  isRequired: false,
                ),
              ),
              _buildTextFormField(
                controller: _brideFatherLastNameController,
                label: "Father's Last Name",
                isRequired: true,
                validator: (val) => _validateName(val, "Father's last name"),
              ),
              const Divider(height: 24),
              _buildAdaptivePair(
                isStacked: isMobile,
                first: _buildTextFormField(
                  controller: _brideMotherFirstNameController,
                  label: "Mother's First Name",
                  isRequired: true,
                  validator: (val) => _validateName(val, "Mother's first name"),
                ),
                second: _buildTextFormField(
                  controller: _brideMotherMiddleNameController,
                  label: "Mother's Middle Name",
                  isRequired: false,
                ),
              ),
              _buildTextFormField(
                controller: _brideMotherMaidenLastController,
                label: "Mother's Maiden Last Name",
                isRequired: true,
                validator: (val) => _validateName(val, "Mother's maiden last name"),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // STEP 4: Sponsors (Primary + Dynamic Other Sponsors with [+] Add Witness)
  Widget _buildStep4SponsorsInformation({required bool isMobile}) {
    return Column(
      children: [
        _buildSectionCard(
          title: 'Primary Sponsors (Witnesses 1 & 2)',
          icon: Icons.verified_user,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Primary Sponsor 1 (Ninong / Ninang)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _matrimonyBurgundy)),
              const SizedBox(height: 8),
              _buildAdaptivePair(
                isStacked: isMobile,
                first: _buildTextFormField(controller: _sponsor1FirstNameController, label: 'First Name', isRequired: true, validator: (v) => _validateName(v, 'Sponsor 1 first name')),
                second: _buildTextFormField(controller: _sponsor1MiddleNameController, label: 'Middle Name', isRequired: false),
              ),
              _buildAdaptivePair(
                isStacked: isMobile,
                first: _buildTextFormField(controller: _sponsor1LastNameController, label: 'Last Name', isRequired: true, validator: (v) => _validateName(v, 'Sponsor 1 last name')),
                second: _buildTextFormField(controller: _sponsor1OriginAddressController, label: 'Origin / Address', isRequired: false),
              ),
              const Divider(height: 28),
              const Text('Primary Sponsor 2 (Ninong / Ninang)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _matrimonyBurgundy)),
              const SizedBox(height: 8),
              _buildAdaptivePair(
                isStacked: isMobile,
                first: _buildTextFormField(controller: _sponsor2FirstNameController, label: 'First Name', isRequired: true, validator: (v) => _validateName(v, 'Sponsor 2 first name')),
                second: _buildTextFormField(controller: _sponsor2MiddleNameController, label: 'Middle Name', isRequired: false),
              ),
              _buildAdaptivePair(
                isStacked: isMobile,
                first: _buildTextFormField(controller: _sponsor2LastNameController, label: 'Last Name', isRequired: true, validator: (v) => _validateName(v, 'Sponsor 2 last name')),
                second: _buildTextFormField(controller: _sponsor2OriginAddressController, label: 'Origin / Address', isRequired: false),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          title: 'Additional Secondary Sponsors / Witnesses',
          icon: Icons.people_outline,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Click "[+] Add Witness / Sponsor" to include additional secondary sponsors individually.',
                style: TextStyle(fontSize: 12, color: ParishColors.textMuted),
              ),
              const SizedBox(height: 12),
              ..._otherSponsorControllers.asMap().entries.map((entry) {
                int idx = entry.key;
                var controller = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: controller,
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'Witness / Sponsor #${idx + 1} Full Name & Residence',
                            filled: true,
                            fillColor: ParishColors.backgroundLight,
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: ParishColors.mercyRed),
                        onPressed: () => _removeOtherSponsorField(idx),
                        tooltip: 'Remove Witness',
                      ),
                    ],
                  ),
                );
              }).toList(),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _matrimonyBurgundy, width: 1.5),
                    foregroundColor: _matrimonyBurgundy,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _addOtherSponsorField,
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('Add Witness / Sponsor', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // STEP 5: Ceremony & Civil Compliance
  Widget _buildStep5CeremonyAndLegal({required bool isMobile}) {
    return _buildSectionCard(
      title: 'Marriage Ceremony, License & Officiating Minister',
      icon: Icons.church,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDatePickerField(
            label: 'Date of Marriage',
            isRequired: true,
            value: _dateOfMarriage,
            hasError: _dateOfMarriageHasError,
            onTap: () => _selectDate(context, 3),
          ),
          _buildAdaptivePair(
            isStacked: isMobile,
            first: _buildDropdownField(
              label: 'Marriage Type',
              isRequired: true,
              value: _marriageType,
              items: const ['Between Catholics', 'Mixed Marriage', 'Disparity of Cults'],
              onChanged: (val) => setState(() => _marriageType = val!),
            ),
            second: Padding(
              padding: const EdgeInsets.only(top: 24.0),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: _matrimonyBurgundy,
                title: const Text('Filipino / Foreigner Status', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                value: _isFilipinoForeigner,
                onChanged: (val) => setState(() => _isFilipinoForeigner = val),
              ),
            ),
          ),
          const Divider(height: 24),
          const Text('Civil Marriage License Compliance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _matrimonyBurgundy)),
          const SizedBox(height: 10),
          _buildAdaptivePair(
            isStacked: isMobile,
            first: _buildTextFormField(controller: _marriageLicenseNoController, label: 'Marriage License No.', isRequired: false),
            second: _buildDatePickerField(label: 'Date Registered', isRequired: false, value: _licenseDateRegistered, hasError: false, onTap: () => _selectDate(context, 4)),
          ),
          _buildTextFormField(controller: _licensePlaceIssuedController, label: 'Place Issued', isRequired: false),
          const Divider(height: 24),
          const Text('Solemnizing Minister & CRASM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _matrimonyBurgundy)),
          const SizedBox(height: 10),
          _buildAdaptivePair(
            isStacked: isMobile,
            first: _buildTextFormField(controller: _solemnizerFirstNameController, label: 'Minister First Name', isRequired: true, validator: (v) => _validateName(v, 'Minister first name')),
            second: _buildTextFormField(controller: _solemnizerMiddleNameController, label: 'Middle Name', isRequired: false),
          ),
          _buildTextFormField(controller: _solemnizerLastNameController, label: 'Minister Last Name', isRequired: true, validator: (v) => _validateName(v, 'Minister last name')),
          _buildAdaptivePair(
            isStacked: isMobile,
            first: _buildTextFormField(controller: _crasmNumberController, label: 'CRASM Number', isRequired: false),
            second: _buildDatePickerField(label: 'CRASM Validity Date', isRequired: false, value: _crasmValidityDate, hasError: false, onTap: () => _selectDate(context, 5)),
          ),
          _buildAdaptivePair(
            isStacked: isMobile,
            first: _buildTextFormField(controller: _parishNameController, label: 'Parish Name', isRequired: true, validator: (v) => _validateRequiredText(v, 'Parish name')),
            second: _buildTextFormField(controller: _stipendController, label: 'Stipend (₱)', isRequired: false, keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: _validateStipend),
          ),
          _buildTextFormField(controller: _remarksController, label: 'Remarks / Marginal Notations', isRequired: false, maxLines: 2),
        ],
      ),
    );
  }

  // ===========================================================================
  // Google Forms Header & UI Blocks
  // ===========================================================================

  Widget _buildGoogleFormsSectionHeader({required String title, required String description, required int stepIndex}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ParishColors.borderGrey),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 8,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: _matrimonyBurgundy,
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
                    Text('SECTION ${stepIndex + 1} OF $_totalSteps', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _matrimonyBurgundy, letterSpacing: 1.0)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: _burgundySurface, borderRadius: BorderRadius.circular(6)),
                      child: const Text('Matrimony Register', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _matrimonyBurgundy)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
                const SizedBox(height: 4),
                Text(description, style: TextStyle(fontSize: 13, color: ParishColors.textMuted, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdaptivePair({required bool isStacked, required Widget first, required Widget second, int flexFirst = 1, int flexSecond = 1}) {
    if (isStacked) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [first, second]);
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

  Widget _buildSectionCard({required String title, required IconData icon, required Widget child}) {
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
              Icon(icon, size: 20, color: _matrimonyBurgundy),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _matrimonyBurgundy)),
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
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ParishColors.textDark),
          children: [
            TextSpan(text: label),
            if (isRequired) const TextSpan(text: ' *', style: TextStyle(color: ParishColors.mercyRed, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildTextFormField({required TextEditingController controller, required String label, required bool isRequired, bool enabled = true, TextInputType keyboardType = TextInputType.text, int maxLines = 1, String? Function(String?)? validator}) {
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
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: ParishColors.borderGrey)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: ParishColors.borderGrey)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _matrimonyBurgundy, width: 1.8)),
              errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: ParishColors.mercyRed, width: 1.2)),
              focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: ParishColors.mercyRed, width: 1.8)),
              errorStyle: const TextStyle(color: ParishColors.mercyRed, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePickerField({required String label, required bool isRequired, required DateTime? value, required bool hasError, required VoidCallback onTap}) {
    final borderColor = hasError ? ParishColors.mercyRed : ParishColors.borderGrey;
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
                  Text(value != null ? value.toIso8601String().substring(0, 10) : 'YYYY-MM-DD', style: TextStyle(fontSize: 14, color: value != null ? ParishColors.textDark : ParishColors.textMuted)),
                  const Icon(Icons.calendar_month, size: 20, color: _matrimonyBurgundy),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField({required String label, required bool isRequired, required String value, required List<String> items, required void Function(String?) onChanged}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldLabel(label, isRequired: isRequired),
          DropdownButtonFormField<String>(
            value: value,
            items: items.map((item) => DropdownMenuItem(value: item, child: Text(item, style: TextStyle(fontSize: 13, color: ParishColors.textDark)))).toList(),
            onChanged: onChanged,
            style: TextStyle(fontSize: 13, color: ParishColors.textDark),
            decoration: InputDecoration(
              filled: true,
              fillColor: ParishColors.backgroundLight,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: ParishColors.borderGrey)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: ParishColors.borderGrey)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _matrimonyBurgundy, width: 1.8)),
            ),
          ),
        ],
      ),
    );
  }
}