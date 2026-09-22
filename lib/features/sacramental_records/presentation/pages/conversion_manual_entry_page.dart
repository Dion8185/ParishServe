import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../services/conversion_service.dart';
import '../../validators/sacramental_validators.dart';
import '../dialogs/discard_entry_dialog.dart';

class ConversionManualEntryPage extends StatefulWidget {
  final VoidCallback? onRecordSaved;
  final Map<String, dynamic>? initialData; // Enables Edit Record Mode

  const ConversionManualEntryPage({
    super.key,
    this.onRecordSaved,
    this.initialData,
  });

  @override
  State<ConversionManualEntryPage> createState() => _ConversionManualEntryPageState();
}

class _ConversionManualEntryPageState extends State<ConversionManualEntryPage> {
  final _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();

  bool get isEditMode => widget.initialData != null;

  // Olive Green Theme Accent for Conversion & Reception records
  static const Color _conversionOlive = Color(0xFF2D6A4F);
  static const Color _oliveSurface = Color(0xFFEDF7F2);

  // Pagination State (4 Google Forms-Style Sections)
  int _currentStep = 0;
  static const int _totalSteps = 4;

  static const List<String> _stepTitles = [
    'Canonical Coordinates & Reception Date',
    'Person Received & Prior Baptism (Receptorum)',
    'Parents & Religious Affiliation (Parentum)',
    'Witnesses, Minister & Offering (Testium)',
  ];

  static const List<String> _stepDescriptions = [
    'Physical register book, page, line, and date of reception into full communion.',
    'Identity of the candidate and prior non-Catholic baptism credentials.',
    'Parental lineage and respective religious backgrounds (Optional).',
    'Canonical witnesses (sponsors), presiding priest, and offering stipend.',
  ];

  // Canonical Options for Prior Non-Catholic Baptism from the Registry Book (BAPTISMI Ecclesia)
  static const List<String> _priorChurchOptions = [
    'None / Not Specified',
    'LUTH: Lutheran Church of the Philippines',
    'PEC: Philippine Episcopal Church',
    'UCCP: United Church of Christ in the Philippines',
    'IEMELIF: Iglesia Evangelica Metodista en las Islas Filipinas',
    'METH: Methodist Church in the Philippines',
    'CPBC: Convention of Philippine Baptist churches',
    'PRES: Presbyterian Church',
    '7ADV: Seventh-Day Adventist Church',
    'Others (Specify)',
  ];

  // 1. Canonical Coordinates & Date (Page 1)
  final _bookNumberController = TextEditingController();
  final _pageNumberController = TextEditingController();
  final _lineNumberController = TextEditingController();
  DateTime? _dateOfReception = DateTime.now();

  // 2. Convert Identity & Prior Baptism (Page 2)
  final _convertFirstNameController = TextEditingController();
  final _convertMiddleNameController = TextEditingController();
  final _convertLastNameController = TextEditingController();
  final _convertSuffixController = TextEditingController();
  DateTime? _dateOfBirth;
  final _placeOfBirthController = TextEditingController();
  DateTime? _priorBaptismDate;
  String _priorBaptismChurch = 'None / Not Specified';
  final _priorBaptismChurchOtherController = TextEditingController();
  final _priorBaptismPlaceController = TextEditingController();

  // 3. Parents & Religious Affiliation (Page 3 - Optional)
  final _fatherFirstNameController = TextEditingController();
  final _fatherMiddleNameController = TextEditingController();
  final _fatherLastNameController = TextEditingController();
  final _fatherReligionController = TextEditingController();

  final _motherFirstNameController = TextEditingController();
  final _motherMiddleNameController = TextEditingController();
  final _motherMaidenLastNameController = TextEditingController();
  final _motherReligionController = TextEditingController();

  // 4. Witnesses, Offering & Minister (Page 4)
  final _witness1FirstNameController = TextEditingController();
  final _witness1MiddleNameController = TextEditingController();
  final _witness1LastNameController = TextEditingController();

  final _witness2FirstNameController = TextEditingController();
  final _witness2MiddleNameController = TextEditingController();
  final _witness2LastNameController = TextEditingController();

  final _stipendController = TextEditingController();
  final _ministerFirstNameController = TextEditingController(text: 'Joseph');
  final _ministerMiddleNameController = TextEditingController();
  final _ministerLastNameController = TextEditingController(text: 'Santos');
  final _parishNameController = TextEditingController(text: 'St. John Paul II Parish');
  final _remarksController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;
  bool _dateOfReceptionHasError = false;
  bool _dateOfBirthHasError = false;

  @override
  void initState() {
    super.initState();
    if (isEditMode) {
      _populateExistingData(widget.initialData!);
    }
  }

  void _populateExistingData(Map<String, dynamic> data) {
    _bookNumberController.text = data['book_number']?.toString() ?? '';
    _pageNumberController.text = data['page_number']?.toString() ?? '';
    _lineNumberController.text = data['line_number']?.toString() ?? '';
    _dateOfReception = DateTime.tryParse(data['date_of_reception']?.toString() ?? '');

    _convertFirstNameController.text = data['convert_first_name']?.toString() ?? '';
    _convertMiddleNameController.text = data['convert_middle_name']?.toString() ?? '';
    _convertLastNameController.text = data['convert_last_name']?.toString() ?? '';
    _convertSuffixController.text = data['convert_suffix']?.toString() ?? '';
    _dateOfBirth = DateTime.tryParse(data['date_of_birth']?.toString() ?? '');
    _placeOfBirthController.text = data['place_of_birth']?.toString() ?? '';

    _priorBaptismDate = DateTime.tryParse(data['prior_baptism_date']?.toString() ?? '');
    final rawChurch = data['prior_baptism_church']?.toString();
    if (rawChurch == null || rawChurch.trim().isEmpty) {
      _priorBaptismChurch = 'None / Not Specified';
    } else if (_priorChurchOptions.contains(rawChurch)) {
      _priorBaptismChurch = rawChurch;
    } else {
      _priorBaptismChurch = 'Others (Specify)';
      _priorBaptismChurchOtherController.text = rawChurch;
    }
    _priorBaptismPlaceController.text = data['prior_baptism_place']?.toString() ?? '';

    _fatherFirstNameController.text = data['father_first_name']?.toString() ?? '';
    _fatherMiddleNameController.text = data['father_middle_name']?.toString() ?? '';
    _fatherLastNameController.text = data['father_last_name']?.toString() ?? '';
    _fatherReligionController.text = data['father_religion']?.toString() ?? '';

    _motherFirstNameController.text = data['mother_first_name']?.toString() ?? '';
    _motherMiddleNameController.text = data['mother_middle_name']?.toString() ?? '';
    _motherMaidenLastNameController.text = data['mother_maiden_last_name']?.toString() ?? '';
    _motherReligionController.text = data['mother_religion']?.toString() ?? '';

    _witness1FirstNameController.text = data['witness_1_first_name']?.toString() ?? '';
    _witness1MiddleNameController.text = data['witness_1_middle_name']?.toString() ?? '';
    _witness1LastNameController.text = data['witness_1_last_name']?.toString() ?? '';

    _witness2FirstNameController.text = data['witness_2_first_name']?.toString() ?? '';
    _witness2MiddleNameController.text = data['witness_2_middle_name']?.toString() ?? '';
    _witness2LastNameController.text = data['witness_2_last_name']?.toString() ?? '';

    _stipendController.text = data['stipend']?.toString() ?? '';
    _ministerFirstNameController.text = data['minister_first_name']?.toString() ?? '';
    _ministerMiddleNameController.text = data['minister_middle_name']?.toString() ?? '';
    _ministerLastNameController.text = data['minister_last_name']?.toString() ?? '';
    _parishNameController.text = data['parish_name']?.toString() ?? 'St. John Paul II Parish';
    _remarksController.text = data['remarks']?.toString() ?? '';
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _bookNumberController.dispose();
    _pageNumberController.dispose();
    _lineNumberController.dispose();
    _convertFirstNameController.dispose();
    _convertMiddleNameController.dispose();
    _convertLastNameController.dispose();
    _convertSuffixController.dispose();
    _placeOfBirthController.dispose();
    _priorBaptismChurchOtherController.dispose();
    _priorBaptismPlaceController.dispose();
    _fatherFirstNameController.dispose();
    _fatherMiddleNameController.dispose();
    _fatherLastNameController.dispose();
    _fatherReligionController.dispose();
    _motherFirstNameController.dispose();
    _motherMiddleNameController.dispose();
    _motherMaidenLastNameController.dispose();
    _motherReligionController.dispose();
    _witness1FirstNameController.dispose();
    _witness1MiddleNameController.dispose();
    _witness1LastNameController.dispose();
    _witness2FirstNameController.dispose();
    _witness2MiddleNameController.dispose();
    _witness2LastNameController.dispose();
    _stipendController.dispose();
    _ministerFirstNameController.dispose();
    _ministerMiddleNameController.dispose();
    _ministerLastNameController.dispose();
    _parishNameController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, int dateType) async {
    final now = DateTime.now();
    DateTime initialDate;

    if (dateType == 0) {
      initialDate = _dateOfReception ?? now;
    } else if (dateType == 1) {
      initialDate = _dateOfBirth ?? DateTime(now.year - 20, 1, 1);
    } else {
      initialDate = _priorBaptismDate ?? DateTime(now.year - 19, 1, 1);
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(now) && dateType != 0 ? now : initialDate,
      firstDate: DateTime(1900),
      lastDate: dateType == 0 ? now.add(const Duration(days: 365)) : now,
    );

    if (picked != null) {
      setState(() {
        if (dateType == 0) {
          _dateOfReception = picked;
          _dateOfReceptionHasError = false;
        } else if (dateType == 1) {
          _dateOfBirth = picked;
          _dateOfBirthHasError = false;
        } else {
          _priorBaptismDate = picked;
        }
      });
    }
  }

  bool _validateStep(int step) {
    setState(() => _errorMessage = null);

    final isStepValid = _formKey.currentState?.validate() ?? true;
    if (!isStepValid) {
      setState(() => _errorMessage = 'Please correct the highlighted errors below before proceeding.');
      return false;
    }

    if (step == 0) {
      final bookError = SacramentalValidators.validateBookNumber(_bookNumberController.text);
      if (bookError != null) {
        setState(() => _errorMessage = bookError);
        return false;
      }
      final pageError = SacramentalValidators.validatePageNumber(_pageNumberController.text);
      if (pageError != null) {
        setState(() => _errorMessage = pageError);
        return false;
      }
      final lineError = SacramentalValidators.validateLineNumber(_lineNumberController.text);
      if (lineError != null) {
        setState(() => _errorMessage = lineError);
        return false;
      }
      if (_dateOfReception == null) {
        setState(() {
          _dateOfReceptionHasError = true;
          _errorMessage = 'Date of Reception into Full Communion is required.';
        });
        return false;
      }
      return true;
    } else if (step == 1) {
      final dobError = SacramentalValidators.validateDateOfBirth(_dateOfBirth);
      if (dobError != null) {
        setState(() {
          _dateOfBirthHasError = true;
          _errorMessage = dobError;
        });
        return false;
      }

      final receptionError = SacramentalValidators.validateReceptionDate(_dateOfReception, _dateOfBirth);
      if (receptionError != null) {
        setState(() => _errorMessage = receptionError);
        return false;
      }

      final priorBaptismError = SacramentalValidators.validatePriorBaptismDate(_priorBaptismDate, _dateOfBirth);
      if (priorBaptismError != null) {
        setState(() => _errorMessage = priorBaptismError);
        return false;
      }

      if (_priorBaptismChurch == 'Others (Specify)' && _priorBaptismChurchOtherController.text.trim().isEmpty) {
        setState(() => _errorMessage = 'Please specify the prior church / denomination.');
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
        accentColor: _conversionOlive,
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
      final double stipendValue = _stipendController.text.trim().isNotEmpty
          ? (double.tryParse(_stipendController.text.trim()) ?? 0.00)
          : 0.00;

      String? finalPriorChurch;
      if (_priorBaptismChurch == 'Others (Specify)') {
        finalPriorChurch = _priorBaptismChurchOtherController.text.trim().isNotEmpty
            ? _priorBaptismChurchOtherController.text.trim()
            : 'Others';
      } else if (_priorBaptismChurch != 'None / Not Specified') {
        finalPriorChurch = _priorBaptismChurch;
      } else {
        finalPriorChurch = null;
      }

      final recordMap = {
        'book_number': _bookNumberController.text.trim(),
        'page_number': _pageNumberController.text.trim(),
        'line_number': _lineNumberController.text.trim(),
        'date_of_reception': _dateOfReception!.toIso8601String().substring(0, 10),

        'convert_first_name': _convertFirstNameController.text.trim(),
        'convert_middle_name': _convertMiddleNameController.text.trim().isEmpty ? null : _convertMiddleNameController.text.trim(),
        'convert_last_name': _convertLastNameController.text.trim(),
        'convert_suffix': _convertSuffixController.text.trim().isEmpty ? null : _convertSuffixController.text.trim(),

        'date_of_birth': _dateOfBirth!.toIso8601String().substring(0, 10),
        'place_of_birth': _placeOfBirthController.text.trim(),

        'prior_baptism_date': _priorBaptismDate?.toIso8601String().substring(0, 10),
        'prior_baptism_church': finalPriorChurch,
        'prior_baptism_place': _priorBaptismPlaceController.text.trim().isEmpty ? null : _priorBaptismPlaceController.text.trim(),

        'father_first_name': _fatherFirstNameController.text.trim().isEmpty ? null : _fatherFirstNameController.text.trim(),
        'father_middle_name': _fatherMiddleNameController.text.trim().isEmpty ? null : _fatherMiddleNameController.text.trim(),
        'father_last_name': _fatherLastNameController.text.trim().isEmpty ? null : _fatherLastNameController.text.trim(),
        'father_religion': _fatherReligionController.text.trim().isEmpty ? null : _fatherReligionController.text.trim(),

        'mother_first_name': _motherFirstNameController.text.trim().isEmpty ? null : _motherFirstNameController.text.trim(),
        'mother_middle_name': _motherMiddleNameController.text.trim().isEmpty ? null : _motherMiddleNameController.text.trim(),
        'mother_maiden_last_name': _motherMaidenLastNameController.text.trim().isEmpty ? null : _motherMaidenLastNameController.text.trim(),
        'mother_religion': _motherReligionController.text.trim().isEmpty ? null : _motherReligionController.text.trim(),

        'witness_1_first_name': _witness1FirstNameController.text.trim(),
        'witness_1_middle_name': _witness1MiddleNameController.text.trim().isEmpty ? null : _witness1MiddleNameController.text.trim(),
        'witness_1_last_name': _witness1LastNameController.text.trim(),

        'witness_2_first_name': _witness2FirstNameController.text.trim().isEmpty ? null : _witness2FirstNameController.text.trim(),
        'witness_2_middle_name': _witness2MiddleNameController.text.trim().isEmpty ? null : _witness2MiddleNameController.text.trim(),
        'witness_2_last_name': _witness2LastNameController.text.trim().isEmpty ? null : _witness2LastNameController.text.trim(),

        'is_gratis': stipendValue == 0.00,
        'stipend': stipendValue,
        'minister_first_name': _ministerFirstNameController.text.trim(),
        'minister_middle_name': _ministerMiddleNameController.text.trim().isEmpty ? null : _ministerMiddleNameController.text.trim(),
        'minister_last_name': _ministerLastNameController.text.trim(),

        'remarks': _remarksController.text.trim().isEmpty ? null : _remarksController.text.trim(),
        'parish_name': _parishNameController.text.trim(),
      };

      if (isEditMode) {
        await ConversionService.updateConversionRecord(
          widget.initialData!['record_id'].toString(),
          recordMap,
        );
      } else {
        await ConversionService.insertManualConversionRecord(recordMap);
      }

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditMode
              ? 'Conversion record updated successfully in Liber Conversorum.'
              : 'Conversion record successfully registered in Liber Conversorum.'),
          backgroundColor: ParishColors.oliveGreen,
          duration: const Duration(seconds: 3),
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
          accentColor: _conversionOlive,
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
            icon: const Icon(Icons.arrow_back, color: _conversionOlive, size: 26),
            onPressed: _isSubmitting
                ? null
                : () async {
              final shouldExit = await showDiscardConfirmationDialog(
                context,
                accentColor: _conversionOlive,
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
                isEditMode ? 'Edit Conversion Record' : 'Conversion Manual Entry',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDarkColor),
              ),
              Text(
                isEditMode
                    ? 'Modifying Canonical Record: ${widget.initialData!['record_id']}'
                    : 'Canonical Registry Book (Liber Conversorum)',
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
                                  isEditMode
                                      ? 'EDITING SECTION ${_currentStep + 1} OF $_totalSteps'
                                      : 'SECTION ${_currentStep + 1} OF $_totalSteps',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _conversionOlive,
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
                                valueColor: const AlwaysStoppedAnimation<Color>(_conversionOlive),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Divider(height: 1, color: borderGreyColor),

                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 18),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 960),
                          child: Form(
                            key: _formKey,
                            autovalidateMode: AutovalidateMode.onUserInteraction,
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

                  // Bottom Action Buttons
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
                                      : _conversionOlive,
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
                                      ? (isEditMode ? 'Updating...' : 'Registering...')
                                      : (_currentStep == _totalSteps - 1
                                      ? (isEditMode ? 'Update Conversion Record' : 'Save Conversion Record')
                                      : 'Continue / Next'),
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
                              width: isMobile ? 180 : 260,
                              height: 48,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _currentStep == _totalSteps - 1
                                      ? ParishColors.oliveGreen
                                      : _conversionOlive,
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
                                      ? (isEditMode ? 'Updating...' : 'Registering...')
                                      : (_currentStep == _totalSteps - 1
                                      ? (isEditMode ? 'Update Conversion Record' : 'Save Conversion Record')
                                      : 'Next Section'),
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

  Widget _buildActiveStepContent({required bool isMobile, required bool isSmallMobile}) {
    switch (_currentStep) {
      case 0:
        return _buildStep1CanonicalCoordinates(isMobile: isMobile, isSmallMobile: isSmallMobile);
      case 1:
        return _buildStep2ConvertIdentity(isMobile: isMobile);
      case 2:
        return _buildStep3ParentsInfo(isMobile: isMobile);
      case 3:
        return _buildStep4WitnessesAndOffering(isMobile: isMobile);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStep1CanonicalCoordinates({required bool isMobile, required bool isSmallMobile}) {
    return _buildSectionCard(
      title: isEditMode
          ? 'Canonical Coordinates & Reception Date (Coordinates Locked)'
          : 'Canonical Coordinates & Reception Date (Conversionis)',
      icon: Icons.menu_book,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isEditMode) ...[
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: _oliveSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _conversionOlive.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock, size: 16, color: _conversionOlive),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Book, Page, and Line coordinates are permanent canonical coordinates and cannot be modified.',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _conversionOlive),
                    ),
                  ),
                ],
              ),
            ),
          ],
          isSmallMobile
              ? Column(
            children: [
              _buildTextFormField(
                controller: _bookNumberController,
                label: 'Book No.',
                isRequired: true,
                enabled: !isEditMode, // Locked in Edit Mode
                keyboardType: TextInputType.number,
                validator: SacramentalValidators.validateBookNumber,
              ),
              _buildTextFormField(
                controller: _pageNumberController,
                label: 'Page No.',
                isRequired: true,
                enabled: !isEditMode,
                keyboardType: TextInputType.number,
                validator: SacramentalValidators.validatePageNumber,
              ),
              _buildTextFormField(
                controller: _lineNumberController,
                label: 'Line No.',
                isRequired: true,
                enabled: !isEditMode,
                keyboardType: TextInputType.number,
                validator: SacramentalValidators.validateLineNumber,
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
                  enabled: !isEditMode,
                  keyboardType: TextInputType.number,
                  validator: SacramentalValidators.validateBookNumber,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextFormField(
                  controller: _pageNumberController,
                  label: 'Page No.',
                  isRequired: true,
                  enabled: !isEditMode,
                  keyboardType: TextInputType.number,
                  validator: SacramentalValidators.validatePageNumber,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextFormField(
                  controller: _lineNumberController,
                  label: 'Line No.',
                  isRequired: true,
                  enabled: !isEditMode,
                  keyboardType: TextInputType.number,
                  validator: SacramentalValidators.validateLineNumber,
                ),
              ),
            ],
          ),
          _buildDatePickerField(
            label: 'Date of Reception into Full Communion *',
            isRequired: true,
            value: _dateOfReception,
            hasError: _dateOfReceptionHasError,
            onTap: () => _selectDate(context, 0),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2ConvertIdentity({required bool isMobile}) {
    return Column(
      children: [
        _buildSectionCard(
          title: 'Identity of the Person Received (Receptorum)',
          icon: Icons.person,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAdaptivePair(
                isStacked: isMobile,
                first: _buildTextFormField(
                  controller: _convertFirstNameController,
                  label: 'First Name',
                  isRequired: true,
                  validator: (v) => SacramentalValidators.validateName(v, 'First name', isRequired: true),
                ),
                second: _buildTextFormField(
                  controller: _convertMiddleNameController,
                  label: 'Middle Name (Optional)',
                  isRequired: false,
                  validator: (v) => SacramentalValidators.validateName(v, 'Middle name', isRequired: false),
                ),
              ),
              _buildAdaptivePair(
                isStacked: isMobile,
                first: _buildTextFormField(
                  controller: _convertLastNameController,
                  label: 'Last Name',
                  isRequired: true,
                  validator: (v) => SacramentalValidators.validateName(v, 'Last name', isRequired: true),
                ),
                second: _buildTextFormField(
                  controller: _convertSuffixController,
                  label: 'Suffix',
                  isRequired: false,
                ),
              ),
              _buildAdaptivePair(
                isStacked: isMobile,
                first: _buildDatePickerField(
                  label: 'Date of Birth (Nativitatis) *',
                  isRequired: true,
                  value: _dateOfBirth,
                  hasError: _dateOfBirthHasError,
                  onTap: () => _selectDate(context, 1),
                ),
                second: _buildTextFormField(
                  controller: _placeOfBirthController,
                  label: 'Place of Birth',
                  isRequired: true,
                  validator: (v) => SacramentalValidators.validateRequiredText(v, 'Place of birth'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          title: 'Prior Non-Catholic Baptism Details (BAPTISMI Ecclesia)',
          icon: Icons.water_drop_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDatePickerField(
                label: 'Prior Baptism Date (Optional)',
                isRequired: false,
                value: _priorBaptismDate,
                hasError: false,
                onTap: () => _selectDate(context, 2),
              ),
              _buildAdaptivePair(
                isStacked: isMobile,
                first: _buildDropdownField(
                  label: 'Prior Church / Denomination',
                  isRequired: false,
                  value: _priorBaptismChurch,
                  items: _priorChurchOptions,
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _priorBaptismChurch = val;
                      });
                    }
                  },
                ),
                second: _buildTextFormField(
                  controller: _priorBaptismPlaceController,
                  label: 'Congregation Location / Municipality',
                  isRequired: false,
                ),
              ),
              if (_priorBaptismChurch == 'Others (Specify)') ...[
                const SizedBox(height: 4),
                _buildTextFormField(
                  controller: _priorBaptismChurchOtherController,
                  label: 'Specify Prior Church / Denomination *',
                  isRequired: true,
                  validator: (v) {
                    if (_priorBaptismChurch == 'Others (Specify)' && (v == null || v.trim().isEmpty)) {
                      return 'Please specify the prior church / denomination.';
                    }
                    return null;
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep3ParentsInfo({required bool isMobile}) {
    return Column(
      children: [
        _buildSectionCard(
          title: "Father's Lineage & Religion (Pater) - Optional",
          icon: Icons.people,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAdaptivePair(
                isStacked: isMobile,
                first: _buildTextFormField(
                  controller: _fatherFirstNameController,
                  label: "Father's First Name",
                  isRequired: false,
                  validator: (v) => SacramentalValidators.validateName(v, "Father's first name", isRequired: false),
                ),
                second: _buildTextFormField(
                  controller: _fatherMiddleNameController,
                  label: "Father's Middle Name",
                  isRequired: false,
                  validator: (v) => SacramentalValidators.validateName(v, "Father's middle name", isRequired: false),
                ),
              ),
              _buildAdaptivePair(
                isStacked: isMobile,
                first: _buildTextFormField(
                  controller: _fatherLastNameController,
                  label: "Father's Last Name",
                  isRequired: false,
                  validator: (v) => SacramentalValidators.validateName(v, "Father's last name", isRequired: false),
                ),
                second: _buildTextFormField(
                  controller: _fatherReligionController,
                  label: "Father's Religion (e.g. Catholic, Methodist)",
                  isRequired: false,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          title: "Mother's Lineage & Religion (Mater) - Optional",
          icon: Icons.people_outline,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAdaptivePair(
                isStacked: isMobile,
                first: _buildTextFormField(
                  controller: _motherFirstNameController,
                  label: "Mother's First Name",
                  isRequired: false,
                  validator: (v) => SacramentalValidators.validateName(v, "Mother's first name", isRequired: false),
                ),
                second: _buildTextFormField(
                  controller: _motherMiddleNameController,
                  label: "Mother's Middle Name",
                  isRequired: false,
                  validator: (v) => SacramentalValidators.validateName(v, "Mother's middle name", isRequired: false),
                ),
              ),
              _buildAdaptivePair(
                isStacked: isMobile,
                first: _buildTextFormField(
                  controller: _motherMaidenLastNameController,
                  label: "Mother's Maiden Last Name",
                  isRequired: false,
                  validator: (v) => SacramentalValidators.validateName(v, "Mother's maiden last name", isRequired: false),
                ),
                second: _buildTextFormField(
                  controller: _motherReligionController,
                  label: "Mother's Religion",
                  isRequired: false,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep4WitnessesAndOffering({required bool isMobile}) {
    return _buildSectionCard(
      title: 'Witnesses, Minister & Offering (Testium & Ministri)',
      icon: Icons.church,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Primary Witness (Sponsor 1) *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _conversionOlive)),
          const SizedBox(height: 8),
          _buildAdaptivePair(
            isStacked: isMobile,
            first: _buildTextFormField(
              controller: _witness1FirstNameController,
              label: 'Witness 1 First Name',
              isRequired: true,
              validator: (v) => SacramentalValidators.validateName(v, 'Witness 1 first name', isRequired: true),
            ),
            second: _buildTextFormField(
              controller: _witness1MiddleNameController,
              label: 'Middle Name (Optional)',
              isRequired: false,
              validator: (v) => SacramentalValidators.validateName(v, 'Witness 1 middle name', isRequired: false),
            ),
          ),
          _buildTextFormField(
            controller: _witness1LastNameController,
            label: 'Witness 1 Last Name',
            isRequired: true,
            validator: (v) => SacramentalValidators.validateName(v, 'Witness 1 last name', isRequired: true),
          ),
          const Divider(height: 24),
          const Text('Secondary Witness (Sponsor 2 - Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _conversionOlive)),
          const SizedBox(height: 8),
          _buildAdaptivePair(
            isStacked: isMobile,
            first: _buildTextFormField(
              controller: _witness2FirstNameController,
              label: 'Witness 2 First Name',
              isRequired: false,
              validator: (v) => SacramentalValidators.validateName(v, 'Witness 2 first name', isRequired: false),
            ),
            second: _buildTextFormField(
              controller: _witness2MiddleNameController,
              label: 'Middle Name (Optional)',
              isRequired: false,
              validator: (v) => SacramentalValidators.validateName(v, 'Witness 2 middle name', isRequired: false),
            ),
          ),
          _buildTextFormField(
            controller: _witness2LastNameController,
            label: 'Witness 2 Last Name',
            isRequired: false,
            validator: (v) => SacramentalValidators.validateName(v, 'Witness 2 last name', isRequired: false),
          ),
          const Divider(height: 24),
          _buildTextFormField(
            controller: _stipendController,
            label: 'Stipend (₱) (Leave blank or 0 for Gratis)',
            isRequired: false,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: SacramentalValidators.validateStipend,
          ),
          const Divider(height: 24),
          _buildAdaptivePair(
            isStacked: isMobile,
            first: _buildTextFormField(
              controller: _ministerFirstNameController,
              label: 'Officiating Priest First Name',
              isRequired: true,
              validator: (v) => SacramentalValidators.validateName(v, 'Minister first name', isRequired: true),
            ),
            second: _buildTextFormField(
              controller: _ministerMiddleNameController,
              label: 'Middle Name (Optional)',
              isRequired: false,
              validator: (v) => SacramentalValidators.validateName(v, 'Minister middle name', isRequired: false),
            ),
          ),
          _buildTextFormField(
            controller: _ministerLastNameController,
            label: 'Officiating Priest Last Name',
            isRequired: true,
            validator: (v) => SacramentalValidators.validateName(v, 'Minister last name', isRequired: true),
          ),
          _buildTextFormField(
            controller: _parishNameController,
            label: 'Parish Name',
            isRequired: true,
            validator: (v) => SacramentalValidators.validateRequiredText(v, 'Parish name'),
          ),
          _buildTextFormField(
            controller: _remarksController,
            label: 'Remarks (Observanda: Confirmation, Marriage noted)',
            isRequired: false,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

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
              color: _conversionOlive,
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
                      isEditMode
                          ? 'EDITING SECTION ${stepIndex + 1} OF $_totalSteps'
                          : 'SECTION ${stepIndex + 1} OF $_totalSteps',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _conversionOlive, letterSpacing: 1.0),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: _oliveSurface, borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        isEditMode ? 'Edit Record Mode' : 'Conversion Register',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _conversionOlive),
                      ),
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
              Icon(icon, size: 20, color: _conversionOlive),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _conversionOlive)),
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
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: ParishColors.borderGrey)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: ParishColors.borderGrey)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _conversionOlive, width: 1.8)),
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
                  const Icon(Icons.calendar_month, size: 20, color: _conversionOlive),
                ],
              ),
            ),
          ),
          if (hasError)
            const Padding(
              padding: EdgeInsets.only(top: 6, left: 12),
              child: Text('Date selection is required.', style: TextStyle(color: ParishColors.mercyRed, fontSize: 12, fontWeight: FontWeight.w500)),
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
            isExpanded: true,
            items: items.map((item) => DropdownMenuItem(
              value: item,
              child: Text(
                item,
                style: TextStyle(fontSize: 13, color: ParishColors.textDark),
                overflow: TextOverflow.ellipsis,
              ),
            )).toList(),
            onChanged: onChanged,
            style: TextStyle(fontSize: 13, color: ParishColors.textDark),
            decoration: InputDecoration(
              filled: true,
              fillColor: ParishColors.backgroundLight,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: ParishColors.borderGrey)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: ParishColors.borderGrey)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _conversionOlive, width: 1.8)),
            ),
          ),
        ],
      ),
    );
  }
}