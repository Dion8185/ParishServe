import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../services/death_service.dart';
import '../../validators/sacramental_validators.dart';
import '../dialogs/discard_entry_dialog.dart';

class DeathManualEntryPage extends StatefulWidget {
  final VoidCallback? onRecordSaved;
  final Map<String, dynamic>? initialData; // Enables Edit Record Mode

  const DeathManualEntryPage({
    super.key,
    this.onRecordSaved,
    this.initialData,
  });

  @override
  State<DeathManualEntryPage> createState() => _DeathManualEntryPageState();
}

class _DeathManualEntryPageState extends State<DeathManualEntryPage> {
  final _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();

  bool get isEditMode => widget.initialData != null;

  // Solemn Violet Theme Accent for Death & Burial Registers
  static const Color _deathViolet = Color(0xFF6B21A8);
  static const Color _violetSurface = Color(0xFFF3E8FF);

  // Pagination State (4 Google Forms-Style Sections)
  int _currentStep = 0;
  static const int _totalSteps = 4;

  static const List<String> _stepTitles = [
    'Canonical Record Reference',
    'Deceased Identity & Demographics (Defuncti)',
    'Next of Kin: Spouse or Parents',
    'Burial, Sacraments & Liturgical Rites',
  ];

  static const List<String> _stepDescriptions = [
    'Specify physical book, page, and line number from the canonical burial ledger.',
    'Full name of the deceased, whole number age at death (Aetas), civil status, and residence.',
    'Surviving spouse (if married/widowed) or parents (if unmarried/child).',
    'Date of death, date and place of burial, cause of death, and sacramental rites.',
  ];

  // 1. Canonical Record Reference (Page 1)
  final _bookNumberController = TextEditingController();
  final _pageNumberController = TextEditingController();
  final _lineNumberController = TextEditingController();

  // 2. Deceased Identity (Page 2)
  final _deceasedFirstNameController = TextEditingController();
  final _deceasedMiddleNameController = TextEditingController();
  final _deceasedLastNameController = TextEditingController();
  final _deceasedSuffixController = TextEditingController();
  String _gender = 'Male';
  final _ageController = TextEditingController();
  String _civilStatus = 'Single';
  final _residenceController = TextEditingController();

  // 3. Next of Kin (Page 3)
  final _spouseFirstNameController = TextEditingController();
  final _spouseMiddleNameController = TextEditingController();
  final _spouseLastNameController = TextEditingController();

  final _fatherFirstNameController = TextEditingController();
  final _fatherMiddleNameController = TextEditingController();
  final _fatherLastNameController = TextEditingController();

  final _motherFirstNameController = TextEditingController();
  final _motherMiddleNameController = TextEditingController();
  final _motherMaidenLastNameController = TextEditingController();

  // 4. Burial & Ministry (Page 4)
  DateTime? _dateOfDeath = DateTime.now();
  DateTime? _dateOfBurial = DateTime.now().add(const Duration(days: 3));
  final _placeOfBurialController = TextEditingController(text: 'Sta. Cruz Catholic Cemetery');
  final _causeOfDeathController = TextEditingController();
  bool _sacramentsReceived = true;
  String _liturgicalService = 'Funeral Mass';
  final _stipendController = TextEditingController();
  final _ministerFirstNameController = TextEditingController(text: 'Joseph');
  final _ministerMiddleNameController = TextEditingController();
  final _ministerLastNameController = TextEditingController(text: 'Santos');
  final _parishNameController = TextEditingController(text: 'St. John Paul II Parish');
  final _remarksController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;
  bool _dateOfDeathHasError = false;
  bool _dateOfBurialHasError = false;

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

    _deceasedFirstNameController.text = data['deceased_first_name']?.toString() ?? '';
    _deceasedMiddleNameController.text = data['deceased_middle_name']?.toString() ?? '';
    _deceasedLastNameController.text = data['deceased_last_name']?.toString() ?? '';
    _deceasedSuffixController.text = data['deceased_suffix']?.toString() ?? '';
    _gender = data['gender']?.toString() ?? 'Male';
    _ageController.text = data['age']?.toString() ?? '';
    _civilStatus = data['civil_status']?.toString() ?? 'Single';
    _residenceController.text = data['residence']?.toString() ?? '';

    _spouseFirstNameController.text = data['spouse_first_name']?.toString() ?? '';
    _spouseMiddleNameController.text = data['spouse_middle_name']?.toString() ?? '';
    _spouseLastNameController.text = data['spouse_last_name']?.toString() ?? '';

    _fatherFirstNameController.text = data['father_first_name']?.toString() ?? '';
    _fatherMiddleNameController.text = data['father_middle_name']?.toString() ?? '';
    _fatherLastNameController.text = data['father_last_name']?.toString() ?? '';

    _motherFirstNameController.text = data['mother_first_name']?.toString() ?? '';
    _motherMiddleNameController.text = data['mother_middle_name']?.toString() ?? '';
    _motherMaidenLastNameController.text = data['mother_maiden_last_name']?.toString() ?? '';

    _dateOfDeath = DateTime.tryParse(data['date_of_death']?.toString() ?? '');
    _dateOfBurial = DateTime.tryParse(data['date_of_burial']?.toString() ?? '');
    _placeOfBurialController.text = data['place_of_burial']?.toString() ?? '';
    _causeOfDeathController.text = data['cause_of_death']?.toString() ?? '';
    _sacramentsReceived = data['sacraments_received'] == true;

    _liturgicalService = data['liturgical_service']?.toString() ?? 'Funeral Mass';
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
    _deceasedFirstNameController.dispose();
    _deceasedMiddleNameController.dispose();
    _deceasedLastNameController.dispose();
    _deceasedSuffixController.dispose();
    _ageController.dispose();
    _residenceController.dispose();
    _spouseFirstNameController.dispose();
    _spouseMiddleNameController.dispose();
    _spouseLastNameController.dispose();
    _fatherFirstNameController.dispose();
    _fatherMiddleNameController.dispose();
    _fatherLastNameController.dispose();
    _motherFirstNameController.dispose();
    _motherMiddleNameController.dispose();
    _motherMaidenLastNameController.dispose();
    _placeOfBurialController.dispose();
    _causeOfDeathController.dispose();
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
    DateTime initialDate = (dateType == 0) ? (_dateOfDeath ?? now) : (_dateOfBurial ?? now);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(now.add(const Duration(days: 30))) ? now : initialDate,
      firstDate: DateTime(1900),
      lastDate: now.add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        if (dateType == 0) {
          _dateOfDeath = picked;
          _dateOfDeathHasError = false;
        } else {
          _dateOfBurial = picked;
          _dateOfBurialHasError = false;
        }
      });
    }
  }

  bool _validateStep(int step) {
    setState(() => _errorMessage = null);

    final isStepValid = _formKey.currentState?.validate() ?? true;
    if (!isStepValid) {
      setState(() => _errorMessage = 'Please complete all required fields on this page.');
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
      return true;
    } else if (step == 3) {
      final burialError = SacramentalValidators.validateBurialDate(_dateOfBurial, _dateOfDeath);
      if (burialError != null) {
        setState(() {
          if (_dateOfDeath == null) {
            _dateOfDeathHasError = true;
          } else {
            _dateOfBurialHasError = true;
          }
          _errorMessage = burialError;
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
        accentColor: _deathViolet,
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
      final recordMap = {
        'book_number': _bookNumberController.text.trim(),
        'page_number': _pageNumberController.text.trim(),
        'line_number': _lineNumberController.text.trim(),

        'deceased_first_name': _deceasedFirstNameController.text.trim(),
        'deceased_middle_name': _deceasedMiddleNameController.text.trim().isEmpty ? null : _deceasedMiddleNameController.text.trim(),
        'deceased_last_name': _deceasedLastNameController.text.trim(),
        'deceased_suffix': _deceasedSuffixController.text.trim().isEmpty ? null : _deceasedSuffixController.text.trim(),
        'gender': _gender,
        'age': _ageController.text.trim(),
        'civil_status': _civilStatus,
        'residence': _residenceController.text.trim(),

        'spouse_first_name': _spouseFirstNameController.text.trim().isEmpty ? null : _spouseFirstNameController.text.trim(),
        'spouse_middle_name': _spouseMiddleNameController.text.trim().isEmpty ? null : _spouseMiddleNameController.text.trim(),
        'spouse_last_name': _spouseLastNameController.text.trim().isEmpty ? null : _spouseLastNameController.text.trim(),

        'father_first_name': _fatherFirstNameController.text.trim().isEmpty ? null : _fatherFirstNameController.text.trim(),
        'father_middle_name': _fatherMiddleNameController.text.trim().isEmpty ? null : _fatherMiddleNameController.text.trim(),
        'father_last_name': _fatherLastNameController.text.trim().isEmpty ? null : _fatherLastNameController.text.trim(),

        'mother_first_name': _motherFirstNameController.text.trim().isEmpty ? null : _motherFirstNameController.text.trim(),
        'mother_middle_name': _motherMiddleNameController.text.trim().isEmpty ? null : _motherMiddleNameController.text.trim(),
        'mother_maiden_last_name': _motherMaidenLastNameController.text.trim().isEmpty ? null : _motherMaidenLastNameController.text.trim(),

        'date_of_death': _dateOfDeath!.toIso8601String().substring(0, 10),
        'date_of_burial': _dateOfBurial!.toIso8601String().substring(0, 10),
        'place_of_burial': _placeOfBurialController.text.trim(),
        'cause_of_death': _causeOfDeathController.text.trim().isEmpty ? null : _causeOfDeathController.text.trim(),
        'sacraments_received': _sacramentsReceived,
        'sacraments_notes': null,

        'liturgical_service': _liturgicalService,
        'stipend': _stipendController.text.trim().isNotEmpty ? double.parse(_stipendController.text.trim()) : 0.00,
        'minister_first_name': _ministerFirstNameController.text.trim(),
        'minister_middle_name': _ministerMiddleNameController.text.trim().isEmpty ? null : _ministerMiddleNameController.text.trim(),
        'minister_last_name': _ministerLastNameController.text.trim(),

        'remarks': _remarksController.text.trim().isEmpty ? null : _remarksController.text.trim(),
        'parish_name': _parishNameController.text.trim(),
      };

      if (isEditMode) {
        await DeathService.updateDeathRecord(
          widget.initialData!['record_id'].toString(),
          recordMap,
        );
      } else {
        await DeathService.insertManualDeathRecord(recordMap);
      }

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditMode
              ? 'Death record updated successfully in Liber Defunctorum.'
              : 'Death record successfully registered in Liber Defunctorum.'),
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
          accentColor: _deathViolet,
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
            icon: const Icon(Icons.arrow_back, color: _deathViolet, size: 26),
            onPressed: _isSubmitting
                ? null
                : () async {
              final shouldExit = await showDiscardConfirmationDialog(
                context,
                accentColor: _deathViolet,
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
                isEditMode ? 'Edit Death Record' : 'Death & Burial Manual Entry',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDarkColor),
              ),
              Text(
                isEditMode
                    ? 'Modifying Canonical Record: ${widget.initialData!['record_id']}'
                    : 'Canonical Registry Book (Liber Defunctorum • Libro de Entierros)',
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
                                    color: _deathViolet,
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
                                valueColor: const AlwaysStoppedAnimation<Color>(_deathViolet),
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

                  // Bottom Actions
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
                                      : _deathViolet,
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
                                      ? (isEditMode ? 'Update Death Record' : 'Save Death Record')
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
                              width: isMobile ? 180 : 250,
                              height: 48,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _currentStep == _totalSteps - 1
                                      ? ParishColors.oliveGreen
                                      : _deathViolet,
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
                                      ? (isEditMode ? 'Update Death Record' : 'Save Death Record')
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
        return _buildStep2DeceasedIdentity(isMobile: isMobile);
      case 2:
        return _buildStep3NextOfKin(isMobile: isMobile);
      case 3:
        return _buildStep4BurialAndMinistry(isMobile: isMobile);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStep1CanonicalReference({required bool isMobile, required bool isSmallMobile}) {
    return _buildSectionCard(
      title: isEditMode
          ? 'Physical Register Book Coordinates (Coordinates Locked)'
          : 'Physical Register Book Coordinates',
      icon: Icons.menu_book,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isEditMode) ...[
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: _violetSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _deathViolet.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock, size: 16, color: _deathViolet),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Book, Page, and Line coordinates are permanent canonical coordinates and cannot be modified.',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _deathViolet),
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
        ],
      ),
    );
  }

  Widget _buildStep2DeceasedIdentity({required bool isMobile}) {
    return _buildSectionCard(
      title: 'Canonical Identity of the Deceased (Defuncti)',
      icon: Icons.person,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAdaptivePair(
            isStacked: isMobile,
            first: _buildTextFormField(
              controller: _deceasedFirstNameController,
              label: 'First Name',
              isRequired: true,
              validator: (v) => SacramentalValidators.validateName(v, 'First name'),
            ),
            second: _buildTextFormField(
              controller: _deceasedMiddleNameController,
              label: 'Middle Name (Optional)',
              isRequired: false,
              validator: (v) => SacramentalValidators.validateName(v, 'Middle name', isRequired: false),
            ),
          ),
          _buildAdaptivePair(
            isStacked: isMobile,
            first: _buildTextFormField(
              controller: _deceasedLastNameController,
              label: 'Last Name',
              isRequired: true,
              validator: (v) => SacramentalValidators.validateName(v, 'Last name'),
            ),
            second: _buildTextFormField(
              controller: _deceasedSuffixController,
              label: 'Suffix',
              isRequired: false,
            ),
          ),
          _buildAdaptivePair(
            isStacked: isMobile,
            first: _buildDropdownField(
              label: 'Gender',
              isRequired: true,
              value: _gender,
              items: const ['Male', 'Female'],
              onChanged: (val) => setState(() => _gender = val!),
            ),
            second: _buildTextFormField(
              controller: _ageController,
              label: 'Age at Death (Whole Number)',
              isRequired: true,
              keyboardType: TextInputType.number,
              validator: (v) => SacramentalValidators.validateWholeNumberAge(v, isRequired: true),
            ),
          ),
          _buildAdaptivePair(
            isStacked: isMobile,
            first: _buildDropdownField(
              label: 'Civil Status (Status)',
              isRequired: true,
              value: _civilStatus,
              items: const ['Single', 'Married', 'Widow', 'Widower', 'Child'],
              onChanged: (val) => setState(() => _civilStatus = val!),
            ),
            second: _buildTextFormField(
              controller: _residenceController,
              label: 'Residence Address (Residentia)',
              isRequired: true,
              validator: (v) => SacramentalValidators.validateRequiredText(v, 'Residence address'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3NextOfKin({required bool isMobile}) {
    return Column(
      children: [
        _buildSectionCard(
          title: 'Surviving Spouse (Uxor vel Maritus)',
          icon: Icons.favorite_border,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAdaptivePair(
                isStacked: isMobile,
                first: _buildTextFormField(
                  controller: _spouseFirstNameController,
                  label: "Spouse's First Name",
                  isRequired: false,
                  validator: (v) => SacramentalValidators.validateName(v, "Spouse's first name", isRequired: false),
                ),
                second: _buildTextFormField(
                  controller: _spouseMiddleNameController,
                  label: "Spouse's Middle Name",
                  isRequired: false,
                  validator: (v) => SacramentalValidators.validateName(v, "Spouse's middle name", isRequired: false),
                ),
              ),
              _buildTextFormField(
                controller: _spouseLastNameController,
                label: "Spouse's Last Name",
                isRequired: false,
                validator: (v) => SacramentalValidators.validateName(v, "Spouse's last name", isRequired: false),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          title: "Parents' Lineage (Parentes)",
          icon: Icons.people_outline,
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
              _buildTextFormField(
                controller: _fatherLastNameController,
                label: "Father's Last Name",
                isRequired: false,
                validator: (v) => SacramentalValidators.validateName(v, "Father's last name", isRequired: false),
              ),
              const Divider(height: 24),
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
              _buildTextFormField(
                controller: _motherMaidenLastNameController,
                label: "Mother's Maiden Last Name",
                isRequired: false,
                validator: (v) => SacramentalValidators.validateName(v, "Mother's maiden last name", isRequired: false),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep4BurialAndMinistry({required bool isMobile}) {
    return _buildSectionCard(
      title: 'Burial, Sacraments & Clergy (Sepelii & Ministri)',
      icon: Icons.church,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAdaptivePair(
            isStacked: isMobile,
            first: _buildDatePickerField(
              label: 'Date of Death (Defunctionis)',
              isRequired: true,
              value: _dateOfDeath,
              hasError: _dateOfDeathHasError,
              onTap: () => _selectDate(context, 0),
            ),
            second: _buildDatePickerField(
              label: 'Date of Burial (Sepelii)',
              isRequired: true,
              value: _dateOfBurial,
              hasError: _dateOfBurialHasError,
              onTap: () => _selectDate(context, 1),
            ),
          ),
          _buildAdaptivePair(
            isStacked: isMobile,
            first: _buildTextFormField(
              controller: _placeOfBurialController,
              label: 'Place of Burial / Cemetery (Sepelii Locus)',
              isRequired: true,
              validator: (v) => SacramentalValidators.validateRequiredText(v, 'Place of burial'),
            ),
            second: _buildTextFormField(
              controller: _causeOfDeathController,
              label: 'Cause of Death (Causa Mortis)',
              isRequired: false,
            ),
          ),
          const Divider(height: 24),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeColor: _deathViolet,
            title: const Text('Sacraments Administered Before Death (Sacramenta)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: const Text('Penance, Viaticum, or Anointing of the Sick (Ut / Non)', style: TextStyle(fontSize: 11)),
            value: _sacramentsReceived,
            onChanged: (val) => setState(() => _sacramentsReceived = val),
          ),
          const Divider(height: 24),
          _buildAdaptivePair(
            isStacked: isMobile,
            first: _buildDropdownField(
              label: 'Liturgical Service',
              isRequired: true,
              value: _liturgicalService,
              items: const ['Funeral Mass', 'Funeral Blessing'],
              onChanged: (val) => setState(() => _liturgicalService = val!),
            ),
            second: _buildTextFormField(
              controller: _stipendController,
              label: 'Stipend (₱)',
              isRequired: false,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: SacramentalValidators.validateStipend,
            ),
          ),
          _buildAdaptivePair(
            isStacked: isMobile,
            first: _buildTextFormField(
              controller: _ministerFirstNameController,
              label: 'Officiating Priest First Name',
              isRequired: true,
              validator: (v) => SacramentalValidators.validateName(v, 'Minister first name'),
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
            validator: (v) => SacramentalValidators.validateName(v, 'Minister last name'),
          ),
          _buildTextFormField(
            controller: _parishNameController,
            label: 'Parish Name',
            isRequired: true,
            validator: (v) => SacramentalValidators.validateRequiredText(v, 'Parish name'),
          ),
          _buildTextFormField(
            controller: _remarksController,
            label: 'Remarks / Observanda',
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
              color: _deathViolet,
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
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _deathViolet, letterSpacing: 1.0),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: _violetSurface, borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        isEditMode ? 'Edit Record Mode' : 'Burial Register',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _deathViolet),
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
              Icon(icon, size: 20, color: _deathViolet),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _deathViolet)),
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
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _deathViolet, width: 1.8)),
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
                  const Icon(Icons.calendar_month, size: 20, color: _deathViolet),
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
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _deathViolet, width: 1.8)),
            ),
          ),
        ],
      ),
    );
  }
}