import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../services/confirmation_service.dart';
import '../../validators/sacramental_validators.dart';
import '../dialogs/discard_entry_dialog.dart';

class ConfirmationManualEntryPage extends StatefulWidget {
  final VoidCallback? onRecordSaved;
  final Map<String, dynamic>? initialData; // Enables Edit Record Mode

  const ConfirmationManualEntryPage({
    super.key,
    this.onRecordSaved,
    this.initialData,
  });

  @override
  State<ConfirmationManualEntryPage> createState() => _ConfirmationManualEntryPageState();
}

class _ConfirmationManualEntryPageState extends State<ConfirmationManualEntryPage> {
  final _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();

  bool get isEditMode => widget.initialData != null;

  // Pentecost Theme Accent for Confirmation
  static const Color _pentecostRed = Color(0xFFB91C1C);
  static const Color _pentecostSurface = Color(0xFFFDF2F2);

  // Pagination State (5 Pages / Steps)
  int _currentStep = 0;
  static const int _totalSteps = 5;

  static const List<String> _stepTitles = [
    'Canonical Record Reference',
    "Confirmand's Personal Information",
    "Parents' Lineage & Origin",
    'Confirmation Sponsors (Max 2)',
    'Confirmation Administration & Minister',
  ];

  static const List<String> _stepDescriptions = [
    'Specify book, page, line, and entry classification from the physical register.',
    'Personal identification, age, required baptismal record, and residence.',
    'Parental lineage and canonical acknowledgment under Canon 877.',
    'Canonical sponsors (strictly limited to Sponsor 1 and Sponsor 2).',
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
  DateTime? _dateOfBaptism;
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
    _entryStatus = data['entry_status']?.toString() ?? 'ORIGINAL';
    _registryDate = DateTime.tryParse(data['registry_date']?.toString() ?? '') ?? DateTime.now();

    _confirmandFirstNameController.text = data['confirmand_first_name']?.toString() ?? '';
    _confirmandMiddleNameController.text = data['confirmand_middle_name']?.toString() ?? '';
    _confirmandLastNameController.text = data['confirmand_last_name']?.toString() ?? '';
    _confirmandSuffixController.text = data['confirmand_suffix']?.toString() ?? '';
    _dateOfBirth = DateTime.tryParse(data['date_of_birth']?.toString() ?? '');
    _ageController.text = data['age']?.toString() ?? '';
    _dateOfBaptism = DateTime.tryParse(data['date_of_baptism']?.toString() ?? '');
    _churchBaptizedController.text = data['church_baptized']?.toString() ?? '';
    _addressController.text = data['address']?.toString() ?? '';

    _fatherFirstNameController.text = data['father_first_name']?.toString() ?? '';
    _fatherMiddleNameController.text = data['father_middle_name']?.toString() ?? '';
    _fatherLastNameController.text = data['father_last_name']?.toString() ?? '';
    _fatherOriginController.text = data['father_origin']?.toString() ?? '';
    _fatherNotIndicated = _fatherFirstNameController.text.toLowerCase() == 'not indicated';

    _motherFirstNameController.text = data['mother_first_name']?.toString() ?? '';
    _motherMiddleNameController.text = data['mother_middle_name']?.toString() ?? '';
    _motherMaidenLastNameController.text = data['mother_maiden_last_name']?.toString() ?? '';
    _motherOriginController.text = data['mother_origin']?.toString() ?? '';

    _sponsor1FirstNameController.text = data['sponsor_1_first_name']?.toString() ?? '';
    _sponsor1MiddleNameController.text = data['sponsor_1_middle_name']?.toString() ?? '';
    _sponsor1LastNameController.text = data['sponsor_1_last_name']?.toString() ?? '';
    _sponsor1OriginAddressController.text = data['sponsor_1_origin_address']?.toString() ?? '';

    _sponsor2FirstNameController.text = data['sponsor_2_first_name']?.toString() ?? '';
    _sponsor2MiddleNameController.text = data['sponsor_2_middle_name']?.toString() ?? '';
    _sponsor2LastNameController.text = data['sponsor_2_last_name']?.toString() ?? '';
    _sponsor2OriginAddressController.text = data['sponsor_2_origin_address']?.toString() ?? '';

    _dateOfConfirmation = DateTime.tryParse(data['date_of_confirmation']?.toString() ?? '');
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

  Future<void> _selectDate(BuildContext context, int dateType) async {
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
  // Step-by-Step Google Forms Pagination Logic with Canonical Validators
  // ===========================================================================

  bool _validateStep(int step) {
    setState(() => _errorMessage = null);

    final isStepValid = _formKey.currentState?.validate() ?? true;
    if (!isStepValid) {
      setState(() => _errorMessage = 'Please correct the highlighted errors below before proceeding.');
      return false;
    }

    if (step == 0) {
      // Step 1: Canonical Coordinates Bounds
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
      return true;
    } else if (step == 1) {
      // Step 2: Confirmand Information & Prior Baptism
      if (_dateOfBaptism == null) {
        setState(() {
          _dateOfBaptismHasError = true;
          _errorMessage = 'Date of Baptism is required for confirmation registration.';
        });
        return false;
      }

      final baptismError = SacramentalValidators.validateBaptismDate(_dateOfBaptism, _dateOfBirth);
      if (baptismError != null) {
        setState(() {
          _dateOfBaptismHasError = true;
          _errorMessage = baptismError;
        });
        return false;
      }
      return true;
    } else if (step == 4) {
      // Step 5: Administration & Confirmation Chronology
      final confError = SacramentalValidators.validateConfirmationDate(_dateOfConfirmation, _dateOfBaptism);
      if (confError != null) {
        setState(() {
          _dateOfConfirmationHasError = true;
          _errorMessage = confError;
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
        accentColor: _pentecostRed,
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

      if (isEditMode) {
        await ConfirmationService.updateConfirmationRecord(
          widget.initialData!['record_id'].toString(),
          recordMap,
        );
      } else {
        await ConfirmationService.insertManualConfirmationRecord(recordMap);
      }

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditMode
              ? 'Confirmation record updated successfully in Liber Confirmatorum.'
              : 'Confirmation record registered successfully in Liber Confirmatorum.'),
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
          accentColor: _pentecostRed,
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
            icon: const Icon(Icons.arrow_back, color: _pentecostRed, size: 26),
            onPressed: _isSubmitting
                ? null
                : () async {
              final shouldExit = await showDiscardConfirmationDialog(
                context,
                accentColor: _pentecostRed,
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
                isEditMode ? 'Edit Confirmation Record' : 'Confirmation Manual Entry',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDarkColor),
              ),
              Text(
                isEditMode
                    ? 'Modifying Canonical Record: ${widget.initialData!['record_id']}'
                    : 'Canonical Registry Book (Liber Confirmatorum)',
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
                                      ? 'Editing Section ${_currentStep + 1} of $_totalSteps'
                                      : 'Section ${_currentStep + 1} of $_totalSteps',
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
                                      ? (isEditMode ? 'Updating...' : 'Registering...')
                                      : (_currentStep == _totalSteps - 1
                                      ? (isEditMode ? 'Update Confirmation Record' : 'Save Confirmation Record')
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
                              width: isMobile ? 210 : 270,
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
                                      ? (isEditMode ? 'Updating...' : 'Registering...')
                                      : (_currentStep == _totalSteps - 1
                                      ? (isEditMode ? 'Update Confirmation Record' : 'Save Confirmation Record')
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

  Widget _buildStep1CanonicalReference({required bool isMobile, required bool isSmallMobile}) {
    return _buildSectionCard(
      title: isEditMode
          ? 'Canonical Ledger Designation (Coordinates Locked)'
          : 'Canonical Ledger Designation',
      icon: Icons.menu_book,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isEditMode) ...[
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: _pentecostSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _pentecostRed.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock, size: 16, color: _pentecostRed),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Book, Page, and Line coordinates are immutable physical coordinates and cannot be modified.',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _pentecostRed),
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
              validator: (val) => SacramentalValidators.validateName(val, 'Confirmand first name', isRequired: true),
            ),
            second: _buildTextFormField(
              controller: _confirmandMiddleNameController,
              label: 'Middle Name',
              isRequired: false,
              validator: (val) => SacramentalValidators.validateName(val, 'Middle name', isRequired: false),
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
              validator: (val) => SacramentalValidators.validateName(val, 'Confirmand last name', isRequired: true),
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
              validator: (val) => SacramentalValidators.validateWholeNumberAge(val, isRequired: false),
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
              validator: (val) => SacramentalValidators.validateRequiredText(val, 'Church baptized'),
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

  Widget _buildStep3ParentsInformation({required bool isMobile}) {
    return Column(
      children: [
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
                  validator: (val) => !_fatherNotIndicated ? SacramentalValidators.validateName(val, "Father's first name", isRequired: true) : null,
                ),
                second: _buildTextFormField(
                  controller: _fatherMiddleNameController,
                  label: 'Middle Name',
                  isRequired: false,
                  enabled: !_fatherNotIndicated,
                  validator: (val) => !_fatherNotIndicated ? SacramentalValidators.validateName(val, "Father's middle name", isRequired: false) : null,
                ),
              ),
              _buildAdaptivePair(
                isStacked: isMobile,
                first: _buildTextFormField(
                  controller: _fatherLastNameController,
                  label: 'Father Last Name',
                  isRequired: !_fatherNotIndicated,
                  enabled: !_fatherNotIndicated,
                  validator: (val) => !_fatherNotIndicated ? SacramentalValidators.validateName(val, "Father's last name", isRequired: true) : null,
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
                  validator: (val) => SacramentalValidators.validateName(val, "Mother's first name", isRequired: true),
                ),
                second: _buildTextFormField(
                  controller: _motherMiddleNameController,
                  label: 'Middle Name',
                  isRequired: false,
                  validator: (val) => SacramentalValidators.validateName(val, "Mother's middle name", isRequired: false),
                ),
              ),
              _buildAdaptivePair(
                isStacked: isMobile,
                first: _buildTextFormField(
                  controller: _motherMaidenLastNameController,
                  label: 'Mother Maiden Last Name',
                  isRequired: true,
                  validator: (val) => SacramentalValidators.validateName(val, "Mother's maiden last name", isRequired: true),
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
          _buildAdaptivePair(
            isStacked: isMobile,
            first: _buildTextFormField(
              controller: _sponsor1FirstNameController,
              label: 'Sponsor 1 First Name',
              isRequired: true,
              validator: (val) => SacramentalValidators.validateName(val, 'Sponsor 1 first name', isRequired: true),
            ),
            second: _buildTextFormField(
              controller: _sponsor1MiddleNameController,
              label: 'Middle Name',
              isRequired: false,
              validator: (val) => SacramentalValidators.validateName(val, 'Sponsor 1 middle name', isRequired: false),
            ),
          ),
          _buildAdaptivePair(
            isStacked: isMobile,
            first: _buildTextFormField(
              controller: _sponsor1LastNameController,
              label: 'Sponsor 1 Last Name',
              isRequired: true,
              validator: (val) => SacramentalValidators.validateName(val, 'Sponsor 1 last name', isRequired: true),
            ),
            second: _buildTextFormField(
              controller: _sponsor1OriginAddressController,
              label: 'Sponsor 1 Origin / Address',
              isRequired: false,
            ),
          ),
          const Divider(height: 28),
          _buildAdaptivePair(
            isStacked: isMobile,
            first: _buildTextFormField(
              controller: _sponsor2FirstNameController,
              label: 'Sponsor 2 First Name (Optional)',
              isRequired: false,
              validator: (val) => SacramentalValidators.validateName(val, 'Sponsor 2 first name', isRequired: false),
            ),
            second: _buildTextFormField(
              controller: _sponsor2MiddleNameController,
              label: 'Middle Name',
              isRequired: false,
              validator: (val) => SacramentalValidators.validateName(val, 'Sponsor 2 middle name', isRequired: false),
            ),
          ),
          _buildAdaptivePair(
            isStacked: isMobile,
            first: _buildTextFormField(
              controller: _sponsor2LastNameController,
              label: 'Sponsor 2 Last Name',
              isRequired: false,
              validator: (val) => SacramentalValidators.validateName(val, 'Sponsor 2 last name', isRequired: false),
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
            validator: (val) => SacramentalValidators.validateRequiredText(val, 'Parish name'),
          ),
          _buildAdaptivePair(
            isStacked: isMobile,
            first: _buildTextFormField(
              controller: _ministerFirstNameController,
              label: 'Minister / Bishop First Name',
              isRequired: true,
              validator: (val) => SacramentalValidators.validateName(val, 'Minister first name', isRequired: true),
            ),
            second: _buildTextFormField(
              controller: _ministerMiddleNameController,
              label: 'Middle Name',
              isRequired: false,
              validator: (val) => SacramentalValidators.validateName(val, 'Minister middle name', isRequired: false),
            ),
          ),
          _buildTextFormField(
            controller: _ministerLastNameController,
            label: 'Minister / Bishop Last Name',
            isRequired: true,
            validator: (val) => SacramentalValidators.validateName(val, 'Minister last name', isRequired: true),
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
              validator: SacramentalValidators.validateStipend,
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
                      isEditMode
                          ? 'EDITING SECTION ${stepIndex + 1} OF $_totalSteps'
                          : 'SECTION ${stepIndex + 1} OF $_totalSteps',
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
                        color: _pentecostSurface,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isEditMode ? 'Edit Record Mode' : 'Canonical Step',
                        style: const TextStyle(
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