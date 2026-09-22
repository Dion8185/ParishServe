import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../services/baptism_service.dart';
import '../dialogs/discard_entry_dialog.dart';

class BaptismManualEntryPage extends StatefulWidget {
  final VoidCallback? onRecordSaved;
  final Map<String, dynamic>? initialData; // Passing initialData activates Edit Record Mode

  const BaptismManualEntryPage({
    super.key,
    this.onRecordSaved,
    this.initialData,
  });

  @override
  State<BaptismManualEntryPage> createState() => _BaptismManualEntryPageState();
}

class _BaptismManualEntryPageState extends State<BaptismManualEntryPage> {
  final _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();

  bool get isEditMode => widget.initialData != null;

  // Pagination State (5 Pages / Steps)
  int _currentStep = 0;
  static const int _totalSteps = 5;

  static const List<String> _stepTitles = [
    'Canonical Record Reference',
    "Child's Personal Information",
    "Parents' Lineage & Origin",
    'Godparents / Sponsors',
    'Baptism & Minister Details',
  ];

  static const List<String> _stepDescriptions = [
    'Specify book, page, line, and entry classification from the physical ledger.',
    'Enter canonical identification of the child as inscribed in the register.',
    'Record parental lineage and paternity acknowledgment under Canon 877.',
    'Record canonical sponsors and additional witnesses (using [+] Add Godparent).',
    'Administration date, place of baptism, clergy, stipend, and marginal notations.',
  ];

  // Canonical options for Legitimacy
  static const List<String> _canonicalStatusOptions = [
    'Natural (Nat.)',
    'Catholic (Cath.)',
    'Aglipay (Agl.)',
    'Protestant (Prot.)',
    'Civil (Civ.)',
    'Others (Specify)',
  ];

  // 1. Canonical Record Reference (Page 1)
  final _bookNumberController = TextEditingController();
  final _pageNumberController = TextEditingController();
  final _lineNumberController = TextEditingController();
  String _entryStatus = 'ORIGINAL';
  DateTime _registryDate = DateTime.now();

  // 2. Child Information (Page 2)
  final _childFirstNameController = TextEditingController();
  final _childMiddleNameController = TextEditingController();
  final _childLastNameController = TextEditingController();
  final _childSuffixController = TextEditingController();
  DateTime? _dateOfBirth;
  final _ageController = TextEditingController();
  final _placeOfBirthController = TextEditingController();
  String _gender = 'Male';
  String _legitimacy = 'Catholic (Cath.)';
  final _legitimacyOtherController = TextEditingController();

  // 3. Parents Information (Page 3)
  bool _fatherNotIndicated = false;
  final _fatherFirstNameController = TextEditingController();
  final _fatherMiddleNameController = TextEditingController();
  final _fatherLastNameController = TextEditingController();
  final _fatherPlaceOfBirthController = TextEditingController();

  final _motherFirstNameController = TextEditingController();
  final _motherMiddleNameController = TextEditingController();
  final _motherMaidenLastNameController = TextEditingController();
  final _motherPlaceOfBirthController = TextEditingController();

  final _parentsContactNumberController = TextEditingController();
  final _parentsResidenceController = TextEditingController();

  // 4. Sponsors Information (Page 4)
  final _sponsor1FirstNameController = TextEditingController();
  final _sponsor1MiddleNameController = TextEditingController();
  final _sponsor1LastNameController = TextEditingController();
  final _sponsor1ResidenceController = TextEditingController();

  final _sponsor2FirstNameController = TextEditingController();
  final _sponsor2MiddleNameController = TextEditingController();
  final _sponsor2LastNameController = TextEditingController();
  final _sponsor2ResidenceController = TextEditingController();

  // Dynamic Other Godparents List (Plus button implementation)
  final List<TextEditingController> _otherGodparentControllers = [];

  // 5. Baptism & Minister Details (Page 5)
  final _parishChurchController = TextEditingController(text: 'St. John Paul II Parish Church');
  final _ministerFirstNameController = TextEditingController(text: 'Joseph');
  final _ministerMiddleNameController = TextEditingController();
  final _ministerLastNameController = TextEditingController(text: 'Santos');
  DateTime? _dateOfBaptism = DateTime.now();
  final _stipendController = TextEditingController();
  final _remarksController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;
  bool _dateOfBirthHasError = false;
  bool _dateOfBaptismHasError = false;

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

    _childFirstNameController.text = data['child_first_name']?.toString() ?? '';
    _childMiddleNameController.text = data['child_middle_name']?.toString() ?? '';
    _childLastNameController.text = data['child_last_name']?.toString() ?? '';
    _childSuffixController.text = data['child_suffix']?.toString() ?? '';
    _dateOfBirth = DateTime.tryParse(data['date_of_birth']?.toString() ?? '');
    _ageController.text = data['age']?.toString() ?? '';
    _placeOfBirthController.text = data['place_of_birth']?.toString() ?? '';
    _gender = data['gender']?.toString() ?? 'Male';

    final rawLegitimacy = data['legitimacy']?.toString() ?? 'Catholic (Cath.)';
    if (_canonicalStatusOptions.contains(rawLegitimacy)) {
      _legitimacy = rawLegitimacy;
    } else if (rawLegitimacy.startsWith('Others')) {
      _legitimacy = 'Others (Specify)';
      _legitimacyOtherController.text = rawLegitimacy
          .replaceFirst('Others (', '')
          .replaceFirst(')', '')
          .replaceFirst('Others', '')
          .trim();
    }

    _fatherFirstNameController.text = data['father_first_name']?.toString() ?? '';
    _fatherMiddleNameController.text = data['father_middle_name']?.toString() ?? '';
    _fatherLastNameController.text = data['father_last_name']?.toString() ?? '';
    _fatherPlaceOfBirthController.text = data['father_place_of_birth']?.toString() ?? '';
    _fatherNotIndicated = _fatherFirstNameController.text.toLowerCase() == 'not indicated';

    _motherFirstNameController.text = data['mother_first_name']?.toString() ?? '';
    _motherMiddleNameController.text = data['mother_middle_name']?.toString() ?? '';
    _motherMaidenLastNameController.text = data['mother_maiden_last_name']?.toString() ?? '';
    _motherPlaceOfBirthController.text = data['mother_place_of_birth']?.toString() ?? '';

    _parentsContactNumberController.text = data['parents_contact_number']?.toString() ?? '';
    _parentsResidenceController.text = data['parents_residence']?.toString() ?? '';

    _sponsor1FirstNameController.text = data['sponsor_1_first_name']?.toString() ?? '';
    _sponsor1MiddleNameController.text = data['sponsor_1_middle_name']?.toString() ?? '';
    _sponsor1LastNameController.text = data['sponsor_1_last_name']?.toString() ?? '';
    _sponsor1ResidenceController.text = data['sponsor_1_residence']?.toString() ?? '';

    _sponsor2FirstNameController.text = data['sponsor_2_first_name']?.toString() ?? '';
    _sponsor2MiddleNameController.text = data['sponsor_2_middle_name']?.toString() ?? '';
    _sponsor2LastNameController.text = data['sponsor_2_last_name']?.toString() ?? '';
    _sponsor2ResidenceController.text = data['sponsor_2_residence']?.toString() ?? '';

    final rawGodparents = data['other_godparents']?.toString() ?? '';
    if (rawGodparents.trim().isNotEmpty) {
      final list = rawGodparents.contains('\n')
          ? rawGodparents.split('\n')
          : rawGodparents.split(',');
      for (var gp in list) {
        if (gp.trim().isNotEmpty) {
          _otherGodparentControllers.add(TextEditingController(text: gp.trim()));
        }
      }
    }

    _parishChurchController.text = data['place_of_baptism']?.toString() ??
        data['parish_name']?.toString() ??
        'St. John Paul II Parish Church';
    _ministerFirstNameController.text = data['minister_first_name']?.toString() ?? '';
    _ministerMiddleNameController.text = data['minister_middle_name']?.toString() ?? '';
    _ministerLastNameController.text = data['minister_last_name']?.toString() ?? '';
    _dateOfBaptism = DateTime.tryParse(data['date_of_baptism']?.toString() ?? '');
    _stipendController.text = data['stipend']?.toString() ?? '';
    _remarksController.text = data['remarks']?.toString() ?? '';
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _bookNumberController.dispose();
    _pageNumberController.dispose();
    _lineNumberController.dispose();
    _childFirstNameController.dispose();
    _childMiddleNameController.dispose();
    _childLastNameController.dispose();
    _childSuffixController.dispose();
    _ageController.dispose();
    _placeOfBirthController.dispose();
    _legitimacyOtherController.dispose();
    _fatherFirstNameController.dispose();
    _fatherMiddleNameController.dispose();
    _fatherLastNameController.dispose();
    _fatherPlaceOfBirthController.dispose();
    _motherFirstNameController.dispose();
    _motherMiddleNameController.dispose();
    _motherMaidenLastNameController.dispose();
    _motherPlaceOfBirthController.dispose();
    _parentsContactNumberController.dispose();
    _parentsResidenceController.dispose();
    _sponsor1FirstNameController.dispose();
    _sponsor1MiddleNameController.dispose();
    _sponsor1LastNameController.dispose();
    _sponsor1ResidenceController.dispose();
    _sponsor2FirstNameController.dispose();
    _sponsor2MiddleNameController.dispose();
    _sponsor2LastNameController.dispose();
    _sponsor2ResidenceController.dispose();
    for (var c in _otherGodparentControllers) {
      c.dispose();
    }
    _parishChurchController.dispose();
    _ministerFirstNameController.dispose();
    _ministerMiddleNameController.dispose();
    _ministerLastNameController.dispose();
    _stipendController.dispose();
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

  String? _validatePhoneNumber(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;

    final clean = text.replaceAll(RegExp(r'[\s\-]'), '');
    final phoneRegExp = RegExp(r'^(09\d{9}|\+639\d{9}|\d{7,10})$');
    if (!phoneRegExp.hasMatch(clean)) {
      return 'Enter a valid phone number (e.g., 09171234567).';
    }
    return null;
  }

  String? _validateStipend(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;

    final amount = double.tryParse(text);
    if (amount == null || amount < 0) {
      return 'Enter a valid amount (e.g., 150.00).';
    }
    return null;
  }

  Future<void> _selectDate(BuildContext context, int dateType) async {
    final now = DateTime.now();
    DateTime initialDate;

    if (dateType == 0) {
      initialDate = _registryDate;
    } else if (dateType == 1) {
      initialDate = _dateOfBirth ?? DateTime(now.year, 1, 1);
    } else {
      initialDate = _dateOfBaptism ?? now;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(now) ? now : initialDate,
      firstDate: DateTime(1900),
      lastDate: dateType == 1 ? now : now.add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        if (dateType == 0) {
          _registryDate = picked;
        } else if (dateType == 1) {
          _dateOfBirth = picked;
          _dateOfBirthHasError = false;

          final diffYears = (DateTime.now().difference(picked).inDays / 365).floor();
          if (diffYears >= 1) {
            _ageController.text = '$diffYears yr(s) old';
          } else {
            final diffMonths = (DateTime.now().difference(picked).inDays / 30).floor();
            _ageController.text = '$diffMonths mo(s) old';
          }
        } else {
          _dateOfBaptism = picked;
          _dateOfBaptismHasError = false;
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
        _fatherPlaceOfBirthController.clear();

        if (_legitimacy == 'Catholic (Cath.)') {
          _legitimacy = 'Natural (Nat.)';
        }
      } else {
        _fatherFirstNameController.clear();
        _fatherMiddleNameController.clear();
        _fatherLastNameController.clear();
        _fatherPlaceOfBirthController.clear();
      }
    });
  }

  void _addOtherGodparentField() {
    setState(() {
      _otherGodparentControllers.add(TextEditingController());
    });
  }

  void _removeOtherGodparentField(int index) {
    setState(() {
      _otherGodparentControllers[index].dispose();
      _otherGodparentControllers.removeAt(index);
    });
  }

  // ===========================================================================
  // Step-by-Step Google Forms Pagination Logic with Live Validation
  // ===========================================================================

  bool _validateStep(int step) {
    setState(() => _errorMessage = null);

    final isStepValid = _formKey.currentState?.validate() ?? true;
    if (!isStepValid) {
      setState(() => _errorMessage = 'Please correct the highlighted errors below before proceeding.');
      return false;
    }

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
      // Step 2: Child Information
      if (_dateOfBirth == null) {
        setState(() {
          _dateOfBirthHasError = true;
          _errorMessage = 'Date of Birth is required.';
        });
        return false;
      }
      if (_dateOfBirth!.isAfter(DateTime.now())) {
        setState(() {
          _dateOfBirthHasError = true;
          _errorMessage = 'Date of Birth cannot be in the future.';
        });
        return false;
      }
      if (_legitimacy == 'Others (Specify)' && _legitimacyOtherController.text.trim().isEmpty) {
        setState(() => _errorMessage = 'Please specify the legitimacy denomination.');
        return false;
      }
      return true;
    } else if (step == 4) {
      // Step 5: Administration Details
      if (_dateOfBaptism == null) {
        setState(() {
          _dateOfBaptismHasError = true;
          _errorMessage = 'Date of Baptism is required.';
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
        accentColor: ParishColors.marianBlue,
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

  // ===========================================================================
  // Final Form Submission (Insert or Update)
  // ===========================================================================

  Future<void> _submitForm() async {
    for (int s = 0; s < _totalSteps; s++) {
      if (!_validateStep(s)) {
        setState(() => _currentStep = s);
        _scrollToTop();
        return;
      }
    }

    final String finalLegitimacy = _legitimacy == 'Others (Specify)'
        ? (_legitimacyOtherController.text.trim().isNotEmpty
        ? 'Others (${_legitimacyOtherController.text.trim()})'
        : 'Others')
        : _legitimacy;

    setState(() => _isSubmitting = true);

    try {
      final parishChurch = _parishChurchController.text.trim();
      List<String> collectedOtherGodparents = _otherGodparentControllers
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      final recordMap = {
        'book_number': _bookNumberController.text.trim(),
        'page_number': _pageNumberController.text.trim(),
        'line_number': _lineNumberController.text.trim(),
        'registry_date': _registryDate.toIso8601String().substring(0, 10),
        'entry_status': _entryStatus,

        'child_first_name': _childFirstNameController.text.trim(),
        'child_middle_name': _childMiddleNameController.text.trim().isEmpty ? null : _childMiddleNameController.text.trim(),
        'child_last_name': _childLastNameController.text.trim(),
        'child_suffix': _childSuffixController.text.trim().isEmpty ? null : _childSuffixController.text.trim(),

        'date_of_birth': _dateOfBirth!.toIso8601String().substring(0, 10),
        'age': _ageController.text.trim().isEmpty ? null : _ageController.text.trim(),
        'place_of_birth': _placeOfBirthController.text.trim(),
        'gender': _gender,
        'legitimacy': finalLegitimacy,

        'father_first_name': _fatherFirstNameController.text.trim(),
        'father_middle_name': _fatherMiddleNameController.text.trim().isEmpty ? null : _fatherMiddleNameController.text.trim(),
        'father_last_name': _fatherLastNameController.text.trim(),
        'father_place_of_birth': _fatherPlaceOfBirthController.text.trim().isEmpty ? null : _fatherPlaceOfBirthController.text.trim(),

        'mother_first_name': _motherFirstNameController.text.trim(),
        'mother_middle_name': _motherMiddleNameController.text.trim().isEmpty ? null : _motherMiddleNameController.text.trim(),
        'mother_maiden_last_name': _motherMaidenLastNameController.text.trim(),
        'mother_place_of_birth': _motherPlaceOfBirthController.text.trim().isEmpty ? null : _motherPlaceOfBirthController.text.trim(),

        'parents_contact_number': _parentsContactNumberController.text.trim().isEmpty ? null : _parentsContactNumberController.text.trim(),
        'parents_residence': _parentsResidenceController.text.trim().isEmpty ? null : _parentsResidenceController.text.trim(),
        'parents_marriage_type': null,

        'sponsor_1_first_name': _sponsor1FirstNameController.text.trim(),
        'sponsor_1_middle_name': _sponsor1MiddleNameController.text.trim().isEmpty ? null : _sponsor1MiddleNameController.text.trim(),
        'sponsor_1_last_name': _sponsor1LastNameController.text.trim(),
        'sponsor_1_residence': _sponsor1ResidenceController.text.trim().isEmpty ? null : _sponsor1ResidenceController.text.trim(),

        'sponsor_2_first_name': _sponsor2FirstNameController.text.trim(),
        'sponsor_2_middle_name': _sponsor2MiddleNameController.text.trim().isEmpty ? null : _sponsor2MiddleNameController.text.trim(),
        'sponsor_2_last_name': _sponsor2LastNameController.text.trim(),
        'sponsor_2_residence': _sponsor2ResidenceController.text.trim().isEmpty ? null : _sponsor2ResidenceController.text.trim(),

        'other_godparents': collectedOtherGodparents.join('\n'),

        'parish_name': parishChurch,
        'place_of_baptism': parishChurch,

        'minister_first_name': _ministerFirstNameController.text.trim(),
        'minister_middle_name': _ministerMiddleNameController.text.trim().isEmpty ? null : _ministerMiddleNameController.text.trim(),
        'minister_last_name': _ministerLastNameController.text.trim(),

        'date_of_baptism': _dateOfBaptism!.toIso8601String().substring(0, 10),
        'stipend': _stipendController.text.trim().isNotEmpty ? double.tryParse(_stipendController.text.trim()) : null,
        'remarks': _remarksController.text.trim().isEmpty ? null : _remarksController.text.trim(),
      };

      if (isEditMode) {
        await BaptismService.updateBaptismRecord(
          widget.initialData!['record_id'].toString(),
          recordMap,
        );
      } else {
        await BaptismService.insertManualBaptismRecord(recordMap);
      }

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditMode
              ? 'Baptism record updated successfully in Liber Baptismorum.'
              : 'Baptism record registered successfully in Liber Baptismorum.'),
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
          accentColor: ParishColors.marianBlue,
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
            icon: const Icon(Icons.arrow_back, color: ParishColors.marianBlue, size: 26),
            onPressed: _isSubmitting
                ? null
                : () async {
              final shouldExit = await showDiscardConfirmationDialog(
                context,
                accentColor: ParishColors.marianBlue,
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
                isEditMode ? 'Edit Baptism Record' : 'Baptism Manual Entry',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDarkColor),
              ),
              Text(
                isEditMode
                    ? 'Modifying Canonical Record: ${widget.initialData!['record_id']}'
                    : 'Canonical Registry Book (Liber Baptismorum)',
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
                  // Progress Banner
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
                                    color: ParishColors.marianBlue,
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
                                valueColor: const AlwaysStoppedAnimation<Color>(ParishColors.marianBlue),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Divider(height: 1, color: borderGreyColor),

                  // Form Content
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

                  // Sticky Bottom Actions
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
                                      : ParishColors.marianBlue,
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
                                      ? (isEditMode ? 'Update Baptism Record' : 'Save Baptism Record')
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
                                      : ParishColors.marianBlue,
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
                                      ? (isEditMode ? 'Update Baptism Record' : 'Save Baptism Record')
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

  // ===========================================================================
  // Step Content Views
  // ===========================================================================

  Widget _buildActiveStepContent({required bool isMobile, required bool isSmallMobile}) {
    switch (_currentStep) {
      case 0:
        return _buildStep1CanonicalReference(isMobile: isMobile, isSmallMobile: isSmallMobile);
      case 1:
        return _buildStep2ChildInformation(isMobile: isMobile);
      case 2:
        return _buildStep3ParentsInformation(isMobile: isMobile);
      case 3:
        return _buildStep4GodparentsInformation(isMobile: isMobile);
      case 4:
        return _buildStep5AdministrationDetails(isMobile: isMobile);
      default:
        return const SizedBox.shrink();
    }
  }

  // STEP 1: Canonical Reference (Book, Page, Line locked in Edit Mode)
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
                color: ParishColors.marianBlueSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ParishColors.marianBlue.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock, size: 16, color: ParishColors.marianBlue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Book, Page, and Line coordinates are immutable physical coordinates and cannot be modified.',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ParishColors.marianBlue),
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
                enabled: !isEditMode, // Locked in Edit Mode
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
                enabled: !isEditMode, // Locked in Edit Mode
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
                  enabled: !isEditMode, // Locked in Edit Mode
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
                  enabled: !isEditMode, // Locked in Edit Mode
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
                  enabled: !isEditMode, // Locked in Edit Mode
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

  // STEP 2: Child Information
  Widget _buildStep2ChildInformation({required bool isMobile}) {
    return _buildSectionCard(
      title: "Child's Canonical Identification",
      icon: Icons.child_care,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAdaptivePair(
            isStacked: isMobile,
            first: _buildTextFormField(
              controller: _childFirstNameController,
              label: 'First Name',
              isRequired: true,
              validator: (val) => _validateName(val, 'First name', isRequired: true),
            ),
            second: _buildTextFormField(
              controller: _childMiddleNameController,
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
              controller: _childLastNameController,
              label: 'Last Name',
              isRequired: true,
              validator: (val) => _validateName(val, 'Last name', isRequired: true),
            ),
            second: _buildTextFormField(
              controller: _childSuffixController,
              label: 'Suffix',
              isRequired: false,
            ),
            flexFirst: 2,
            flexSecond: 1,
          ),
          _buildAdaptivePair(
            isStacked: isMobile,
            first: _buildDatePickerField(
              label: 'Date of Birth',
              isRequired: true,
              value: _dateOfBirth,
              hasError: _dateOfBirthHasError,
              onTap: () => _selectDate(context, 1),
            ),
            second: _buildTextFormField(
              controller: _ageController,
              label: 'Age',
              isRequired: false,
            ),
          ),
          _buildTextFormField(
            controller: _placeOfBirthController,
            label: 'Place of Birth',
            isRequired: true,
            validator: (val) => _validateRequiredText(val, 'Place of birth'),
          ),
          _buildAdaptivePair(
            isStacked: isMobile,
            first: _buildDropdownField(
              label: 'Gender',
              isRequired: false,
              value: _gender,
              items: const ['Male', 'Female'],
              onChanged: (val) => setState(() => _gender = val!),
            ),
            second: _buildDropdownField(
              label: 'Legitimacy',
              isRequired: false,
              value: _legitimacy,
              items: _canonicalStatusOptions,
              onChanged: (val) => setState(() => _legitimacy = val!),
            ),
          ),
          if (_legitimacy == 'Others (Specify)') ...[
            _buildTextFormField(
              controller: _legitimacyOtherController,
              label: 'Specify Legitimacy / Denomination',
              isRequired: true,
              validator: (val) {
                if (_legitimacy == 'Others (Specify)' && (val == null || val.trim().isEmpty)) {
                  return 'Please specify the denomination or type.';
                }
                return null;
              },
            ),
          ],
        ],
      ),
    );
  }

  // STEP 3: Parents Information
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
                activeColor: ParishColors.marianBlue,
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
                  controller: _fatherPlaceOfBirthController,
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
          title: "Mother's Lineage & Residence",
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
                  label: 'Maiden Last Name',
                  isRequired: true,
                  validator: (val) => _validateName(val, "Mother's maiden last name", isRequired: true),
                ),
                second: _buildTextFormField(
                  controller: _motherPlaceOfBirthController,
                  label: 'Place of Origin',
                  isRequired: false,
                ),
              ),
              const Divider(height: 24),
              _buildAdaptivePair(
                isStacked: isMobile,
                first: _buildTextFormField(
                  controller: _parentsContactNumberController,
                  label: 'Parents Contact Number',
                  isRequired: false,
                  keyboardType: TextInputType.phone,
                  validator: _validatePhoneNumber,
                ),
                second: _buildTextFormField(
                  controller: _parentsResidenceController,
                  label: 'Parents Residence / Address',
                  isRequired: false,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // STEP 4: Godparents / Sponsors
  Widget _buildStep4GodparentsInformation({required bool isMobile}) {
    return Column(
      children: [
        _buildSectionCard(
          title: 'Primary Sponsors (Godparents 1 & 2)',
          icon: Icons.people_outline,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Canonical entries require Sponsor 1 and Sponsor 2.',
                style: TextStyle(fontSize: 12, color: ParishColors.marianBlue, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 14),
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
                  controller: _sponsor1ResidenceController,
                  label: 'Sponsor 1 Residence',
                  isRequired: false,
                ),
              ),
              const Divider(height: 28),
              _buildAdaptivePair(
                isStacked: isMobile,
                first: _buildTextFormField(
                  controller: _sponsor2FirstNameController,
                  label: 'Sponsor 2 First Name',
                  isRequired: true,
                  validator: (val) => _validateName(val, 'Sponsor 2 first name', isRequired: true),
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
                  isRequired: true,
                  validator: (val) => _validateName(val, 'Sponsor 2 last name', isRequired: true),
                ),
                second: _buildTextFormField(
                  controller: _sponsor2ResidenceController,
                  label: 'Sponsor 2 Residence',
                  isRequired: false,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          title: 'Additional Godparents / Witnesses',
          icon: Icons.group_add_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Click "[+] Add Godparent" to include additional secondary sponsors individually.',
                style: TextStyle(fontSize: 12, color: ParishColors.textMuted),
              ),
              const SizedBox(height: 12),
              ..._otherGodparentControllers.asMap().entries.map((entry) {
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
                            labelText: 'Godparent / Witness #${idx + 1} Full Name & Residence',
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
                        onPressed: () => _removeOtherGodparentField(idx),
                        tooltip: 'Remove Godparent',
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
                    side: const BorderSide(color: ParishColors.marianBlue, width: 1.5),
                    foregroundColor: ParishColors.marianBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _addOtherGodparentField,
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('Add Godparent', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // STEP 5: Administration Details
  Widget _buildStep5AdministrationDetails({required bool isMobile}) {
    return _buildSectionCard(
      title: 'Baptism Administration & Minister Details',
      icon: Icons.church,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextFormField(
            controller: _parishChurchController,
            label: 'Parish / Church of Baptism',
            isRequired: true,
            validator: (val) => _validateRequiredText(val, 'Parish / Church of baptism'),
          ),
          _buildAdaptivePair(
            isStacked: isMobile,
            first: _buildTextFormField(
              controller: _ministerFirstNameController,
              label: 'Minister First Name',
              isRequired: true,
              validator: (val) => _validateName(val, 'Minister first name', isRequired: true),
            ),
            second: _buildTextFormField(
              controller: _ministerMiddleNameController,
              label: 'Minister Middle Name',
              isRequired: false,
              validator: (val) => _validateName(val, 'Minister middle name', isRequired: false),
            ),
          ),
          _buildTextFormField(
            controller: _ministerLastNameController,
            label: 'Minister Last Name',
            isRequired: true,
            validator: (val) => _validateName(val, 'Minister last name', isRequired: true),
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
          Container(
            height: 8,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: ParishColors.marianBlue,
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
                        color: ParishColors.marianBlue,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: ParishColors.marianBlueSurface,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isEditMode ? 'Edit Record Mode' : 'Canonical Step',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: ParishColors.marianBlue,
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
              Icon(icon, size: 20, color: ParishColors.marianBlue),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: ParishColors.marianBlue,
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
                  color: ParishColors.mercyRed,
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
                borderSide: const BorderSide(color: ParishColors.marianBlue, width: 1.8),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: ParishColors.mercyRed, width: 1.2),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: ParishColors.mercyRed, width: 1.8),
              ),
              errorStyle: const TextStyle(
                color: ParishColors.mercyRed,
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
                    color: hasError ? ParishColors.mercyRed : ParishColors.marianBlue,
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
                style: TextStyle(color: ParishColors.mercyRed, fontSize: 12, fontWeight: FontWeight.w500),
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
                child: Text(
                  item,
                  style: TextStyle(fontSize: 13, color: ParishColors.textDark),
                ),
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
                borderSide: const BorderSide(color: ParishColors.marianBlue, width: 1.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}