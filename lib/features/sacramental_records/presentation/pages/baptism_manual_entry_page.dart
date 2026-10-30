// =============================================================================
// FILE: lib/features/sacramental_records/presentation/pages/baptism_manual_entry_page.dart
// =============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../services/baptism_service.dart';
import '../../validators/sacramental_validators.dart';
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

  // Canonical options for Legitimacy
  static const List<String> _canonicalStatusOptions = [
    'Natural (Nat.)',
    'Catholic (Cath.)',
    'Aglipay (Agl.)',
    'Protestant (Prot.)',
    'Civil (Civ.)',
    'Others (Specify)',
  ];

  // 1. Canonical Record Reference
  final _bookNumberController = TextEditingController();
  final _pageNumberController = TextEditingController();
  final _lineNumberController = TextEditingController();
  String _entryStatus = 'ORIGINAL';
  DateTime _registryDate = DateTime.now();

  // Live Duplicate Checker State
  Timer? _coordinateDebounce;
  bool _isCheckingCoordinateDuplicate = false;
  String? _coordinateDuplicateError;

  // 2. Child Information
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

  // 3. Parents Information
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

  // 4. Sponsors Information
  final _sponsor1FirstNameController = TextEditingController();
  final _sponsor1MiddleNameController = TextEditingController();
  final _sponsor1LastNameController = TextEditingController();
  final _sponsor1ResidenceController = TextEditingController();

  final _sponsor2FirstNameController = TextEditingController();
  final _sponsor2MiddleNameController = TextEditingController();
  final _sponsor2LastNameController = TextEditingController();
  final _sponsor2ResidenceController = TextEditingController();

  // Dynamic Other Godparents List
  final List<TextEditingController> _otherGodparentControllers = [];

  // 5. Baptism & Minister Details
  final _parishChurchController = TextEditingController(text: 'St. John Paul II Parish');
  final _ministerFirstNameController = TextEditingController(text: 'Roy');
  final _ministerMiddleNameController = TextEditingController();
  final _ministerLastNameController = TextEditingController(text: 'Reyes');
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
    } else {
      _bookNumberController.addListener(_onCoordinateChanged);
      _pageNumberController.addListener(_onCoordinateChanged);
      _lineNumberController.addListener(_onCoordinateChanged);
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
        'St. John Paul II Parish';
    _ministerFirstNameController.text = data['minister_first_name']?.toString() ?? '';
    _ministerMiddleNameController.text = data['minister_middle_name']?.toString() ?? '';
    _ministerLastNameController.text = data['minister_last_name']?.toString() ?? '';
    _dateOfBaptism = DateTime.tryParse(data['date_of_baptism']?.toString() ?? '');
    _stipendController.text = data['stipend']?.toString() ?? '';
    _remarksController.text = data['remarks']?.toString() ?? '';

    _recomputeAge();
  }

  void _onCoordinateChanged() {
    _coordinateDebounce?.cancel();
    _coordinateDebounce = Timer(const Duration(milliseconds: 350), _checkCoordinatesLive);
  }

  Future<void> _checkCoordinatesLive() async {
    final b = _bookNumberController.text.trim();
    final p = _pageNumberController.text.trim();
    final l = _lineNumberController.text.trim();

    if (b.isEmpty || p.isEmpty || l.isEmpty) {
      if (mounted && _coordinateDuplicateError != null) {
        setState(() => _coordinateDuplicateError = null);
      }
      return;
    }

    if (mounted) setState(() => _isCheckingCoordinateDuplicate = true);

    final dupError = await SacramentalValidators.checkCoordinateDuplicate(
      tableName: 'baptism_records',
      bookNumber: b,
      pageNumber: p,
      lineNumber: l,
      excludeRecordId: isEditMode ? widget.initialData!['record_id']?.toString() : null,
    );

    if (mounted) {
      setState(() {
        _coordinateDuplicateError = dupError;
        _isCheckingCoordinateDuplicate = false;
      });
    }
  }

  @override
  void dispose() {
    _coordinateDebounce?.cancel();
    _scrollController.dispose();
    _bookNumberController.removeListener(_onCoordinateChanged);
    _pageNumberController.removeListener(_onCoordinateChanged);
    _lineNumberController.removeListener(_onCoordinateChanged);
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

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _recomputeAge() {
    if (_dateOfBirth != null && _dateOfBaptism != null) {
      _ageController.text = SacramentalValidators.calculateFormattedAge(
        _dateOfBirth!,
        _dateOfBaptism!,
      );
    }
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
      lastDate: now,
    );

    if (picked != null) {
      setState(() {
        if (dateType == 0) {
          _registryDate = picked;
        } else if (dateType == 1) {
          _dateOfBirth = picked;
          _dateOfBirthHasError = false;
          _recomputeAge();
        } else {
          _dateOfBaptism = picked;
          _dateOfBaptismHasError = false;
          _recomputeAge();
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

  bool _validateAllFields() {
    setState(() => _errorMessage = null);

    final isFormValid = _formKey.currentState?.validate() ?? false;
    if (!isFormValid) {
      setState(() => _errorMessage = 'Please review the highlighted fields below before saving.');
      _scrollToTop();
      return false;
    }

    if (_coordinateDuplicateError != null) {
      setState(() => _errorMessage = _coordinateDuplicateError);
      _scrollToTop();
      return false;
    }

    final bookError = SacramentalValidators.validateBookNumber(_bookNumberController.text);
    if (bookError != null) {
      setState(() => _errorMessage = bookError);
      _scrollToTop();
      return false;
    }

    final pageError = SacramentalValidators.validatePageNumber(_pageNumberController.text);
    if (pageError != null) {
      setState(() => _errorMessage = pageError);
      _scrollToTop();
      return false;
    }

    final lineError = SacramentalValidators.validateLineNumber(_lineNumberController.text);
    if (lineError != null) {
      setState(() => _errorMessage = lineError);
      _scrollToTop();
      return false;
    }

    final regDateError = SacramentalValidators.validateNotFutureDate(_registryDate, 'Registry Date');
    if (regDateError != null) {
      setState(() => _errorMessage = regDateError);
      _scrollToTop();
      return false;
    }

    final dobError = SacramentalValidators.validateDateOfBirth(_dateOfBirth, isRequired: true);
    if (dobError != null) {
      setState(() {
        _dateOfBirthHasError = true;
        _errorMessage = dobError;
      });
      _scrollToTop();
      return false;
    }

    final placeError = SacramentalValidators.validatePlace(
      _placeOfBirthController.text,
      'Place of birth',
      isRequired: true,
      maxLength: 100,
    );
    if (placeError != null) {
      setState(() => _errorMessage = placeError);
      _scrollToTop();
      return false;
    }

    if (_legitimacy == 'Others (Specify)' && _legitimacyOtherController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please specify the legitimacy denomination.');
      _scrollToTop();
      return false;
    }

    final baptismError = SacramentalValidators.validateBaptismDate(_dateOfBaptism, _dateOfBirth);
    if (baptismError != null) {
      setState(() {
        _dateOfBaptismHasError = true;
        _errorMessage = baptismError;
      });
      _scrollToTop();
      return false;
    }

    return true;
  }

  Future<void> _submitForm() async {
    if (!_validateAllFields()) return;

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
      _scrollToTop();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textDarkColor = ParishColors.textDark;
    final textMutedColor = ParishColors.textMuted;
    final cardWhiteColor = ParishColors.cardWhite;

    return PopScope(
      canPop: !_isSubmitting,
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
            icon: Icon(Icons.arrow_back, color: ParishColors.marianBlue, size: 26),
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
          actions: [
            // Always-available Jump to Top button in AppBar
            IconButton(
              icon: Icon(Icons.vertical_align_top, color: ParishColors.marianBlue, size: 22),
              tooltip: 'Jump to Top',
              onPressed: _scrollToTop,
            ),
          ],
        ),
        // Permanent Floating "Back to Top" Action Button (Guaranteed Visible)
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: ParishColors.marianBlue,
          foregroundColor: Colors.white,
          elevation: 3,
          onPressed: _scrollToTop,
          icon: const Icon(Icons.arrow_upward, size: 18),
          label: const Text(
            'Back to Top',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double availableWidth = constraints.maxWidth;
              // Responsive wide breakpoint: $\ge 900$ expands field rows horizontally
              final bool isWide = availableWidth >= 900;
              final double horizontalPadding = isWide ? 32.0 : (availableWidth < 650 ? 14.0 : 22.0);

              return Stack(
                children: [
                  SingleChildScrollView(
                    controller: _scrollController,
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 20),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: isWide ? 1080 : 760),
                        child: Form(
                          key: _formKey,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1. Google Forms Header
                              _buildGoogleFormsHeaderCard(),
                              const SizedBox(height: 16),

                              // Error Alert Banner
                              if (_errorMessage != null) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: ParishColors.mercyRedSurface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: ParishColors.mercyRed),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.error_outline, color: ParishColors.mercyRed, size: 24),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          _errorMessage!,
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.bold,
                                            color: ParishColors.mercyRed,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // 2. Canonical Coordinates Card
                              _buildSection1Coordinates(isWide: isWide),
                              const SizedBox(height: 16),

                              // 3. Child's Personal Info Card
                              _buildSection2Child(isWide: isWide),
                              const SizedBox(height: 16),

                              // 4. Parents' Information Card (Father & Mother Unified)
                              _buildSection3Parents(isWide: isWide),
                              const SizedBox(height: 16),

                              // 5. Sponsors & Godparents Card (Primary & Additional Unified)
                              _buildSection4Godparents(isWide: isWide),
                              const SizedBox(height: 16),

                              // 6. Baptism Administration & Clergy Card
                              _buildSection5Administration(isWide: isWide),
                              const SizedBox(height: 24),

                              // 7. Bottom Submission Bar (with explicit Back to Top button)
                              _buildBottomSubmissionBar(isWide: isWide),
                              const SizedBox(height: 50),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Non-Dismissible Focused Loading Overlay
                  if (_isSubmitting)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withOpacity(0.55),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: ParishColors.goldAccent,
                            strokeWidth: 4.5,
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
  // Section 1: Canonical Coordinates Card
  // ===========================================================================

  Widget _buildGoogleFormsHeaderCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ParishColors.borderGrey),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 9,
            width: double.infinity,
            decoration: BoxDecoration(
              color: ParishColors.marianBlue,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'LIBER BAPTISMORUM',
                      style: TextStyle(
                        fontSize: 12,
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
                        isEditMode ? 'Edit Record Mode' : 'Canonical Registration Form',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: ParishColors.marianBlue,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Canonical Baptismal Entry',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: ParishColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Complete all fields in accordance with Canon 535 and the physical church ledger. All sections flow naturally below.',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: ParishColors.textMuted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection1Coordinates({required bool isWide}) {
    final bool hasDup = _coordinateDuplicateError != null;

    return _buildSectionCard(
      title: '1. Canonical Record Reference (Physical Ledger Coordinates)',
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
              child: Row(
                children: [
                  Icon(Icons.lock, size: 16, color: ParishColors.marianBlue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Book, Page, and Line coordinates are permanent physical coordinates and cannot be altered.',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ParishColors.marianBlue),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (hasDup) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: ParishColors.mercyRedSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ParishColors.mercyRed, width: 1.2),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: ParishColors.mercyRed, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _coordinateDuplicateError!,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: ParishColors.mercyRed,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Book, Page, Line (3 Columns on Desktop/Tablet, Responsive on Phone)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildTextFormField(
                  controller: _bookNumberController,
                  label: 'Book No.',
                  isRequired: true,
                  enabled: !isEditMode,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
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
                  maxLength: 4,
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
                  maxLength: 4,
                  validator: SacramentalValidators.validateLineNumber,
                ),
              ),
            ],
          ),

          if (_isCheckingCoordinateDuplicate)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
              child: Row(
                children: [
                  SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.8, color: ParishColors.marianBlue)),
                  const SizedBox(width: 8),
                  Text('Checking physical ledger coordinates...', style: TextStyle(fontSize: 11, color: ParishColors.textMuted)),
                ],
              ),
            ),

          // Entry Status & Registry Date
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildDropdownField(
                  label: 'Entry Status',
                  isRequired: true,
                  value: _entryStatus,
                  items: const ['ORIGINAL', 'CORRECTED', 'INCOMPLETE'],
                  onChanged: (val) => setState(() => _entryStatus = val!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDatePickerField(
                  label: 'Registry Date',
                  isRequired: true,
                  value: _registryDate,
                  hasError: false,
                  onTap: () => _selectDate(context, 0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 2: Child's Personal Information Card
  // ===========================================================================

  Widget _buildSection2Child({required bool isWide}) {
    final bool hasBirthIndicated = _dateOfBirth != null;

    return _buildSectionCard(
      title: "2. Child's Canonical Identification",
      icon: Icons.child_care,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isWide) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: _buildTextFormField(
                    controller: _childFirstNameController,
                    label: 'First Name',
                    isRequired: true,
                    maxLength: 50,
                    validator: (val) => SacramentalValidators.validateName(val, 'First name', isRequired: true, maxLength: 50),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _buildTextFormField(
                    controller: _childMiddleNameController,
                    label: 'Middle Name',
                    isRequired: false,
                    maxLength: 50,
                    validator: (val) => SacramentalValidators.validateName(val, 'Middle name', isRequired: false, maxLength: 50),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: _buildTextFormField(
                    controller: _childLastNameController,
                    label: 'Last Name',
                    isRequired: true,
                    maxLength: 50,
                    validator: (val) => SacramentalValidators.validateName(val, 'Last name', isRequired: true, maxLength: 50),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: _buildTextFormField(
                    controller: _childSuffixController,
                    label: 'Suffix',
                    isRequired: false,
                    maxLength: 15,
                    validator: SacramentalValidators.validateSuffix,
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: _buildTextFormField(
                    controller: _childFirstNameController,
                    label: 'First Name',
                    isRequired: true,
                    maxLength: 50,
                    validator: (val) => SacramentalValidators.validateName(val, 'First name', isRequired: true, maxLength: 50),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: _buildTextFormField(
                    controller: _childMiddleNameController,
                    label: 'Middle Name',
                    isRequired: false,
                    maxLength: 50,
                    validator: (val) => SacramentalValidators.validateName(val, 'Middle name', isRequired: false, maxLength: 50),
                  ),
                ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: _buildTextFormField(
                    controller: _childLastNameController,
                    label: 'Last Name',
                    isRequired: true,
                    maxLength: 50,
                    validator: (val) => SacramentalValidators.validateName(val, 'Last name', isRequired: true, maxLength: 50),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: _buildTextFormField(
                    controller: _childSuffixController,
                    label: 'Suffix',
                    isRequired: false,
                    maxLength: 15,
                    validator: SacramentalValidators.validateSuffix,
                  ),
                ),
              ],
            ),
          ],

          // DOB, Age, Place of Birth
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: isWide ? 3 : 2,
                child: _buildDatePickerField(
                  label: 'Date of Birth',
                  isRequired: true,
                  value: _dateOfBirth,
                  hasError: _dateOfBirthHasError,
                  onTap: () => _selectDate(context, 1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: isWide ? 2 : 1,
                child: _buildTextFormField(
                  controller: _ageController,
                  label: hasBirthIndicated ? 'Age (Autocomputed)' : 'Age at Baptism',
                  isRequired: false,
                  enabled: !hasBirthIndicated,
                  maxLength: 30,
                ),
              ),
              if (isWide) ...[
                const SizedBox(width: 12),
                Expanded(
                  flex: 4,
                  child: _buildTextFormField(
                    controller: _placeOfBirthController,
                    label: 'Place of Birth',
                    isRequired: true,
                    maxLength: 100,
                    validator: (val) => SacramentalValidators.validatePlace(val, 'Place of birth', isRequired: true, maxLength: 100),
                  ),
                ),
              ],
            ],
          ),

          if (!isWide) ...[
            _buildTextFormField(
              controller: _placeOfBirthController,
              label: 'Place of Birth',
              isRequired: true,
              maxLength: 100,
              validator: (val) => SacramentalValidators.validatePlace(val, 'Place of birth', isRequired: true, maxLength: 100),
            ),
          ],

          // Gender & Legitimacy
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildDropdownField(
                  label: 'Gender',
                  isRequired: false,
                  value: _gender,
                  items: const ['Male', 'Female'],
                  onChanged: (val) => setState(() => _gender = val!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDropdownField(
                  label: 'Legitimacy',
                  isRequired: false,
                  value: _legitimacy,
                  items: _canonicalStatusOptions,
                  onChanged: (val) => setState(() => _legitimacy = val!),
                ),
              ),
            ],
          ),

          if (_legitimacy == 'Others (Specify)') ...[
            _buildTextFormField(
              controller: _legitimacyOtherController,
              label: 'Specify Legitimacy / Denomination',
              isRequired: true,
              maxLength: 100,
              validator: (val) {
                if (_legitimacy == 'Others (Specify)' && (val == null || val.trim().isEmpty)) {
                  return 'Please specify the denomination or type.';
                }
                return SacramentalValidators.validatePlace(val, 'Legitimacy denomination', isRequired: true, maxLength: 100);
              },
            ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 3: Parents' Lineage & Residence Card (Unified)
  // ===========================================================================

  Widget _buildSection3Parents({required bool isWide}) {
    return _buildSectionCard(
      title: "3. Parents' Lineage & Residence",
      icon: Icons.people,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Father's Information", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: ParishColors.marianBlue)),
          const SizedBox(height: 4),

          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            activeColor: ParishColors.marianBlue,
            title: const Text(
              'Father not indicated / acknowledged in COLB (Canon 877 §2)',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              'Fills canonical placeholder and displays "—" on issued certificates.',
              style: TextStyle(fontSize: 12),
            ),
            value: _fatherNotIndicated,
            onChanged: _onFatherNotIndicatedToggle,
          ),
          const SizedBox(height: 6),

          if (isWide) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: _buildTextFormField(
                    controller: _fatherFirstNameController,
                    label: 'Father First Name',
                    isRequired: !_fatherNotIndicated,
                    enabled: !_fatherNotIndicated,
                    maxLength: 50,
                    validator: (val) => !_fatherNotIndicated ? SacramentalValidators.validateName(val, "Father's first name", isRequired: true, maxLength: 50) : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _buildTextFormField(
                    controller: _fatherMiddleNameController,
                    label: 'Middle Name',
                    isRequired: false,
                    enabled: !_fatherNotIndicated,
                    maxLength: 50,
                    validator: (val) => !_fatherNotIndicated ? SacramentalValidators.validateName(val, "Father's middle name", isRequired: false, maxLength: 50) : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: _buildTextFormField(
                    controller: _fatherLastNameController,
                    label: 'Father Last Name',
                    isRequired: !_fatherNotIndicated,
                    enabled: !_fatherNotIndicated,
                    maxLength: 50,
                    validator: (val) => !_fatherNotIndicated ? SacramentalValidators.validateName(val, "Father's last name", isRequired: true, maxLength: 50) : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: _buildTextFormField(
                    controller: _fatherPlaceOfBirthController,
                    label: 'Place of Origin',
                    isRequired: false,
                    enabled: !_fatherNotIndicated,
                    maxLength: 100,
                    validator: (val) => !_fatherNotIndicated ? SacramentalValidators.validatePlace(val, "Father's place of origin", isRequired: false, maxLength: 100) : null,
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildTextFormField(
                    controller: _fatherFirstNameController,
                    label: 'Father First Name',
                    isRequired: !_fatherNotIndicated,
                    enabled: !_fatherNotIndicated,
                    maxLength: 50,
                    validator: (val) => !_fatherNotIndicated ? SacramentalValidators.validateName(val, "Father's first name", isRequired: true, maxLength: 50) : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextFormField(
                    controller: _fatherMiddleNameController,
                    label: 'Middle Name',
                    isRequired: false,
                    enabled: !_fatherNotIndicated,
                    maxLength: 50,
                    validator: (val) => !_fatherNotIndicated ? SacramentalValidators.validateName(val, "Father's middle name", isRequired: false, maxLength: 50) : null,
                  ),
                ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildTextFormField(
                    controller: _fatherLastNameController,
                    label: 'Father Last Name',
                    isRequired: !_fatherNotIndicated,
                    enabled: !_fatherNotIndicated,
                    maxLength: 50,
                    validator: (val) => !_fatherNotIndicated ? SacramentalValidators.validateName(val, "Father's last name", isRequired: true, maxLength: 50) : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextFormField(
                    controller: _fatherPlaceOfBirthController,
                    label: 'Place of Origin',
                    isRequired: false,
                    enabled: !_fatherNotIndicated,
                    maxLength: 100,
                    validator: (val) => !_fatherNotIndicated ? SacramentalValidators.validatePlace(val, "Father's place of origin", isRequired: false, maxLength: 100) : null,
                  ),
                ),
              ],
            ),
          ],

          const Divider(height: 26),

          Text("Mother's Information", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: ParishColors.marianBlue)),
          const SizedBox(height: 10),

          if (isWide) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: _buildTextFormField(
                    controller: _motherFirstNameController,
                    label: 'Mother First Name',
                    isRequired: true,
                    maxLength: 50,
                    validator: (val) => SacramentalValidators.validateName(val, "Mother's first name", isRequired: true, maxLength: 50),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _buildTextFormField(
                    controller: _motherMiddleNameController,
                    label: 'Middle Name',
                    isRequired: false,
                    maxLength: 50,
                    validator: (val) => SacramentalValidators.validateName(val, "Mother's middle name", isRequired: false, maxLength: 50),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: _buildTextFormField(
                    controller: _motherMaidenLastNameController,
                    label: 'Maiden Last Name',
                    isRequired: true,
                    maxLength: 50,
                    validator: (val) => SacramentalValidators.validateName(val, "Mother's maiden last name", isRequired: true, maxLength: 50),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: _buildTextFormField(
                    controller: _motherPlaceOfBirthController,
                    label: 'Place of Origin',
                    isRequired: false,
                    maxLength: 100,
                    validator: (val) => SacramentalValidators.validatePlace(val, "Mother's place of origin", isRequired: false, maxLength: 100),
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildTextFormField(
                    controller: _motherFirstNameController,
                    label: 'Mother First Name',
                    isRequired: true,
                    maxLength: 50,
                    validator: (val) => SacramentalValidators.validateName(val, "Mother's first name", isRequired: true, maxLength: 50),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextFormField(
                    controller: _motherMiddleNameController,
                    label: 'Middle Name',
                    isRequired: false,
                    maxLength: 50,
                    validator: (val) => SacramentalValidators.validateName(val, "Mother's middle name", isRequired: false, maxLength: 50),
                  ),
                ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildTextFormField(
                    controller: _motherMaidenLastNameController,
                    label: 'Maiden Last Name',
                    isRequired: true,
                    maxLength: 50,
                    validator: (val) => SacramentalValidators.validateName(val, "Mother's maiden last name", isRequired: true, maxLength: 50),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextFormField(
                    controller: _motherPlaceOfBirthController,
                    label: 'Place of Origin',
                    isRequired: false,
                    maxLength: 100,
                    validator: (val) => SacramentalValidators.validatePlace(val, "Mother's place of origin", isRequired: false, maxLength: 100),
                  ),
                ),
              ],
            ),
          ],

          const Divider(height: 26),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: isWide ? 4 : 1,
                child: _buildTextFormField(
                  controller: _parentsContactNumberController,
                  label: 'Parents Contact No. (11-digits)',
                  isRequired: false,
                  keyboardType: TextInputType.phone,
                  maxLength: 11,
                  validator: SacramentalValidators.validatePhoneNumber,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: isWide ? 6 : 1,
                child: _buildTextFormField(
                  controller: _parentsResidenceController,
                  label: 'Parents Residence Address',
                  isRequired: false,
                  maxLength: 150,
                  validator: (val) => SacramentalValidators.validatePlace(val, 'Parents residence', isRequired: false, maxLength: 150),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 4: Godparents & Sponsors Card (Unified)
  // ===========================================================================

  Widget _buildSection4Godparents({required bool isWide}) {
    return _buildSectionCard(
      title: '4. Godparents / Canonical Sponsors',
      icon: Icons.people_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Primary Sponsors (Canonically Required)',
            style: TextStyle(fontSize: 13, color: ParishColors.marianBlue, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          Text('Sponsor 1 (Ninong / Ninang)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: ParishColors.textDark)),
          const SizedBox(height: 6),
          if (isWide) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: _buildTextFormField(
                    controller: _sponsor1FirstNameController,
                    label: 'First Name',
                    isRequired: true,
                    maxLength: 50,
                    validator: (val) => SacramentalValidators.validateName(val, 'Sponsor 1 first name', isRequired: true, maxLength: 50),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _buildTextFormField(
                    controller: _sponsor1MiddleNameController,
                    label: 'Middle Name',
                    isRequired: false,
                    maxLength: 50,
                    validator: (val) => SacramentalValidators.validateName(val, 'Sponsor 1 middle name', isRequired: false, maxLength: 50),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: _buildTextFormField(
                    controller: _sponsor1LastNameController,
                    label: 'Last Name',
                    isRequired: true,
                    maxLength: 50,
                    validator: (val) => SacramentalValidators.validateName(val, 'Sponsor 1 last name', isRequired: true, maxLength: 50),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: _buildTextFormField(
                    controller: _sponsor1ResidenceController,
                    label: 'Residence / Address',
                    isRequired: false,
                    maxLength: 150,
                    validator: (val) => SacramentalValidators.validatePlace(val, 'Sponsor 1 residence', isRequired: false, maxLength: 150),
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildTextFormField(
                    controller: _sponsor1FirstNameController,
                    label: 'First Name',
                    isRequired: true,
                    maxLength: 50,
                    validator: (val) => SacramentalValidators.validateName(val, 'Sponsor 1 first name', isRequired: true, maxLength: 50),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextFormField(
                    controller: _sponsor1MiddleNameController,
                    label: 'Middle Name',
                    isRequired: false,
                    maxLength: 50,
                    validator: (val) => SacramentalValidators.validateName(val, 'Sponsor 1 middle name', isRequired: false, maxLength: 50),
                  ),
                ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildTextFormField(
                    controller: _sponsor1LastNameController,
                    label: 'Last Name',
                    isRequired: true,
                    maxLength: 50,
                    validator: (val) => SacramentalValidators.validateName(val, 'Sponsor 1 last name', isRequired: true, maxLength: 50),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextFormField(
                    controller: _sponsor1ResidenceController,
                    label: 'Residence',
                    isRequired: false,
                    maxLength: 150,
                    validator: (val) => SacramentalValidators.validatePlace(val, 'Sponsor 1 residence', isRequired: false, maxLength: 150),
                  ),
                ),
              ],
            ),
          ],

          const Divider(height: 22),

          Text('Sponsor 2 (Ninong / Ninang)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: ParishColors.textDark)),
          const SizedBox(height: 6),
          if (isWide) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: _buildTextFormField(
                    controller: _sponsor2FirstNameController,
                    label: 'First Name',
                    isRequired: true,
                    maxLength: 50,
                    validator: (val) => SacramentalValidators.validateName(val, 'Sponsor 2 first name', isRequired: true, maxLength: 50),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _buildTextFormField(
                    controller: _sponsor2MiddleNameController,
                    label: 'Middle Name',
                    isRequired: false,
                    maxLength: 50,
                    validator: (val) => SacramentalValidators.validateName(val, 'Sponsor 2 middle name', isRequired: false, maxLength: 50),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: _buildTextFormField(
                    controller: _sponsor2LastNameController,
                    label: 'Last Name',
                    isRequired: true,
                    maxLength: 50,
                    validator: (val) => SacramentalValidators.validateName(val, 'Sponsor 2 last name', isRequired: true, maxLength: 50),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: _buildTextFormField(
                    controller: _sponsor2ResidenceController,
                    label: 'Residence / Address',
                    isRequired: false,
                    maxLength: 150,
                    validator: (val) => SacramentalValidators.validatePlace(val, 'Sponsor 2 residence', isRequired: false, maxLength: 150),
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildTextFormField(
                    controller: _sponsor2FirstNameController,
                    label: 'First Name',
                    isRequired: true,
                    maxLength: 50,
                    validator: (val) => SacramentalValidators.validateName(val, 'Sponsor 2 first name', isRequired: true, maxLength: 50),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextFormField(
                    controller: _sponsor2MiddleNameController,
                    label: 'Middle Name',
                    isRequired: false,
                    maxLength: 50,
                    validator: (val) => SacramentalValidators.validateName(val, 'Sponsor 2 middle name', isRequired: false, maxLength: 50),
                  ),
                ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildTextFormField(
                    controller: _sponsor2LastNameController,
                    label: 'Last Name',
                    isRequired: true,
                    maxLength: 50,
                    validator: (val) => SacramentalValidators.validateName(val, 'Sponsor 2 last name', isRequired: true, maxLength: 50),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextFormField(
                    controller: _sponsor2ResidenceController,
                    label: 'Residence',
                    isRequired: false,
                    maxLength: 150,
                    validator: (val) => SacramentalValidators.validatePlace(val, 'Sponsor 2 residence', isRequired: false, maxLength: 150),
                  ),
                ),
              ],
            ),
          ],

          const Divider(height: 26),

          Text('Additional Secondary Godparents (Witnesses)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: ParishColors.textDark)),
          const SizedBox(height: 4),
          Text(
            'Click "[+] Add Godparent" to add additional secondary sponsor names individually.',
            style: TextStyle(fontSize: 13, color: ParishColors.textMuted),
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
                      maxLength: 60,
                      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                      style: const TextStyle(fontSize: 14.5),
                      decoration: InputDecoration(
                        labelText: 'Godparent / Witness #${idx + 1} Full Name',
                        filled: true,
                        fillColor: ParishColors.backgroundLight,
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      validator: (val) => SacramentalValidators.validateName(val, 'Godparent #${idx + 1}', isRequired: false, maxLength: 60),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.remove_circle_outline, color: ParishColors.mercyRed),
                    onPressed: () => _removeOtherGodparentField(idx),
                    tooltip: 'Remove Godparent',
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 4),
          SizedBox(
            width: isWide ? 220 : double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: ParishColors.marianBlue, width: 1.5),
                foregroundColor: ParishColors.marianBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _addOtherGodparentField,
              icon: const Icon(Icons.add_circle_outline, size: 20),
              label: const Text('Add Godparent', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Section 5: Administration & Clergy Details Card
  // ===========================================================================

  Widget _buildSection5Administration({required bool isWide}) {
    return _buildSectionCard(
      title: '5. Baptism Administration & Clergy Details',
      icon: Icons.church,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextFormField(
            controller: _parishChurchController,
            label: 'Parish / Church of Baptism',
            isRequired: true,
            maxLength: 150,
            validator: (val) => SacramentalValidators.validatePlace(val, 'Parish / Church of baptism', isRequired: true, maxLength: 150),
          ),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _buildTextFormField(
                  controller: _ministerFirstNameController,
                  label: 'Minister First Name',
                  isRequired: true,
                  maxLength: 50,
                  validator: (val) => SacramentalValidators.validateName(val, 'Minister first name', isRequired: true, maxLength: 50),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _buildTextFormField(
                  controller: _ministerMiddleNameController,
                  label: 'Middle Name',
                  isRequired: false,
                  maxLength: 50,
                  validator: (val) => SacramentalValidators.validateName(val, 'Minister middle name', isRequired: false, maxLength: 50),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: _buildTextFormField(
                  controller: _ministerLastNameController,
                  label: 'Minister Last Name',
                  isRequired: true,
                  maxLength: 50,
                  validator: (val) => SacramentalValidators.validateName(val, 'Minister last name', isRequired: true, maxLength: 50),
                ),
              ),
            ],
          ),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: isWide ? 4 : 1,
                child: _buildDatePickerField(
                  label: 'Date of Baptism',
                  isRequired: true,
                  value: _dateOfBaptism,
                  hasError: _dateOfBaptismHasError,
                  onTap: () => _selectDate(context, 2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: isWide ? 3 : 1,
                child: _buildTextFormField(
                  controller: _stipendController,
                  label: 'Stipend (₱)',
                  isRequired: false,
                  maxLength: 12,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: SacramentalValidators.validateStipend,
                ),
              ),
            ],
          ),

          _buildTextFormField(
            controller: _remarksController,
            label: 'Canonical Remarks / Marginal Notations',
            isRequired: false,
            maxLines: 2,
            maxLength: 255,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Bottom Submission Bar (With Explicit Back to Top)
  // ===========================================================================

  Widget _buildBottomSubmissionBar({required bool isWide}) {
    final borderGreyColor = ParishColors.borderGrey;
    final textMutedColor = ParishColors.textMuted;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderGreyColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(130, 50),
              side: BorderSide(color: borderGreyColor, width: 1.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _isSubmitting
                ? null
                : () async {
              final shouldExit = await showDiscardConfirmationDialog(
                context,
                accentColor: ParishColors.marianBlue,
              );
              if (shouldExit && mounted) {
                Navigator.pop(context);
              }
            },
            child: Text(
              'Discard & Exit',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textMutedColor),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Explicit Back to Top button in bottom bar
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(130, 50),
                  side: BorderSide(color: ParishColors.marianBlue, width: 1.4),
                  foregroundColor: ParishColors.marianBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _scrollToTop,
                icon: const Icon(Icons.arrow_upward, size: 18),
                label: const Text(
                  'Back to Top',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(isWide ? 260 : 180, 50),
                  backgroundColor: (_coordinateDuplicateError != null)
                      ? ParishColors.mercyRed
                      : ParishColors.oliveGreen,
                  foregroundColor: Colors.white,
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: (_isSubmitting || _coordinateDuplicateError != null) ? null : _submitForm,
                icon: const Icon(Icons.check_circle_outline, size: 22),
                label: Text(
                  isEditMode ? 'Update Baptism Record' : 'Save Baptism Record',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Reusable Form Field Component Builders
  // ===========================================================================

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
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
          Row(
            children: [
              Icon(icon, size: 22, color: ParishColors.marianBlue),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.bold,
                    color: ParishColors.marianBlue,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 22),
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
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: ParishColors.textDark,
          ),
          children: [
            TextSpan(text: label),
            if (isRequired)
              TextSpan(
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
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldLabel(label, isRequired: isRequired),
          TextFormField(
            controller: controller,
            enabled: enabled,
            keyboardType: keyboardType,
            maxLines: maxLines,
            maxLength: maxLength,
            buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
            validator: validator,
            style: TextStyle(fontSize: 14.5, color: enabled ? ParishColors.textDark : ParishColors.textMuted),
            decoration: InputDecoration(
              filled: true,
              fillColor: enabled ? ParishColors.backgroundLight : ParishColors.borderGrey.withOpacity(0.2),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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
                borderSide: BorderSide(color: ParishColors.marianBlue, width: 1.8),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: ParishColors.mercyRed, width: 1.2),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: ParishColors.mercyRed, width: 1.8),
              ),
              errorStyle: TextStyle(
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
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldLabel(label, isRequired: isRequired),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 50,
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
                      fontSize: 14.5,
                      color: value != null ? ParishColors.textDark : ParishColors.textMuted,
                    ),
                  ),
                  Icon(
                    Icons.calendar_month,
                    size: 22,
                    color: hasError ? ParishColors.mercyRed : ParishColors.marianBlue,
                  ),
                ],
              ),
            ),
          ),
          if (hasError)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 12),
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
      padding: const EdgeInsets.only(bottom: 14),
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
                  style: TextStyle(fontSize: 14, color: ParishColors.textDark),
                ),
              );
            }).toList(),
            onChanged: onChanged,
            style: TextStyle(fontSize: 14, color: ParishColors.textDark),
            decoration: InputDecoration(
              filled: true,
              fillColor: ParishColors.backgroundLight,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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
                borderSide: BorderSide(color: ParishColors.marianBlue, width: 1.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}