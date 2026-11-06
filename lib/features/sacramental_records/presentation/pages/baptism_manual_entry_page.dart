// =============================================================================
// FILE: lib/features/sacramental_records/presentation/pages/baptism_manual_entry_page.dart
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/colors.dart';
import '../../../auth/services/auth_service.dart';
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

  // Floating Back to Top state & micro-interactions
  bool _showBackToTop = false;
  bool _isBackToTopHovered = false;

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

  // 1. Registry Coordinates
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

  // 5. Baptism & Priest Details
  final _parishChurchController = TextEditingController(text: 'St. John Paul II Parish');
  final _ministerFirstNameController = TextEditingController(text: 'Roy');
  final _ministerMiddleNameController = TextEditingController();
  final _ministerLastNameController = TextEditingController(text: 'Reyes');
  DateTime? _dateOfBaptism = DateTime.now();
  final _stipendController = TextEditingController();
  final _remarksController = TextEditingController();
  String? _existingCanonicalNotes;

  bool _isSubmitting = false;
  String? _errorMessage;
  bool _dateOfBirthHasError = false;
  bool _dateOfBaptismHasError = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    if (isEditMode) {
      _populateExistingData(widget.initialData!);
    } else {
      _bookNumberController.addListener(_onCoordinateChanged);
      _pageNumberController.addListener(_onCoordinateChanged);
      _lineNumberController.addListener(_onCoordinateChanged);
    }
  }

  void _onScroll() {
    final shouldShow = _scrollController.hasClients && _scrollController.offset >= 1000;
    if (shouldShow != _showBackToTop) {
      setState(() => _showBackToTop = shouldShow);
    }
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _populateExistingData(Map<String, dynamic> data) {
    _bookNumberController.text = data['book_number']?.toString() ?? '';
    _pageNumberController.text = data['page_number']?.toString() ?? '';
    _lineNumberController.text = data['line_number']?.toString() ?? '';
    _entryStatus = data['entry_status']?.toString() ?? 'ORIGINAL';
    _registryDate = DateTime.tryParse(data['registry_date']?.toString() ?? '') ?? DateTime.now();
    _existingCanonicalNotes = data['canonical_notes']?.toString();

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
    _scrollController.removeListener(_onScroll);
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
    final upperDateBound = (dateType == 2) ? DateTime(2100) : now;

    if (dateType == 0) {
      initialDate = _registryDate;
    } else if (dateType == 1) {
      initialDate = _dateOfBirth ?? DateTime(now.year, 1, 1);
    } else {
      initialDate = _dateOfBaptism ?? now;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(upperDateBound) ? upperDateBound : initialDate,
      firstDate: DateTime(1900),
      lastDate: upperDateBound,
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

  /// Computes strict dynamic field-by-field diff, explicitly excluding unchanged fields
  /// as well as uneditable canonical audit metadata (registry_date, entry_status, created_at, date_encoded)
  String _computeChangesSummaryJson(Map<String, dynamic> oldData, Map<String, dynamic> newData) {
    final diffs = <String, Map<String, dynamic>>{};

    final Map<String, String> fieldLabels = {
      'book_number': 'Book No.',
      'page_number': 'Page No.',
      'line_number': 'Line No.',
      'child_first_name': 'Child First Name',
      'child_middle_name': 'Child Middle Name',
      'child_last_name': 'Child Last Name',
      'child_suffix': 'Child Suffix',
      'date_of_birth': 'Date of Birth',
      'age': 'Age',
      'place_of_birth': 'Place of Birth',
      'gender': 'Gender',
      'legitimacy': 'Legitimacy',
      'father_first_name': 'Father First Name',
      'father_middle_name': 'Father Middle Name',
      'father_last_name': 'Father Last Name',
      'father_place_of_birth': 'Father Place of Birth',
      'mother_first_name': 'Mother First Name',
      'mother_middle_name': 'Mother Middle Name',
      'mother_maiden_last_name': 'Mother Maiden Last Name',
      'mother_place_of_birth': 'Mother Place of Birth',
      'parents_contact_number': 'Parents Contact Number',
      'parents_residence': 'Parents Residence',
      'sponsor_1_first_name': 'Sponsor 1 First Name',
      'sponsor_1_middle_name': 'Sponsor 1 Middle Name',
      'sponsor_1_last_name': 'Sponsor 1 Last Name',
      'sponsor_1_residence': 'Sponsor 1 Residence',
      'sponsor_2_first_name': 'Sponsor 2 First Name',
      'sponsor_2_middle_name': 'Sponsor 2 Middle Name',
      'sponsor_2_last_name': 'Sponsor 2 Last Name',
      'sponsor_2_residence': 'Sponsor 2 Residence',
      'other_godparents': 'Other Godparents',
      'parish_name': 'Parish Name',
      'minister_first_name': 'Priest First Name',
      'minister_middle_name': 'Priest Middle Name',
      'minister_last_name': 'Priest Last Name',
      'date_of_baptism': 'Date of Baptism',
      'place_of_baptism': 'Place of Baptism',
      'stipend': 'Stipend',
      'remarks': 'Remarks',
    };

    newData.forEach((key, newVal) {
      if (key == 'created_at' ||
          key == 'date_encoded' ||
          key == 'canonical_notes' ||
          key == 'registry_date' ||
          key == 'entry_status') {
        return;
      }

      final oldVal = oldData[key];
      final oldStr = (oldVal == null || oldVal.toString().trim().isEmpty || oldVal.toString().toLowerCase() == 'null') ? '' : oldVal.toString().trim();
      final newStr = (newVal == null || newVal.toString().trim().isEmpty || newVal.toString().toLowerCase() == 'null') ? '' : newVal.toString().trim();

      String normOld = oldStr;
      String normNew = newStr;
      if (oldStr.length >= 10 && DateTime.tryParse(oldStr) != null) {
        normOld = oldStr.substring(0, 10);
      }
      if (newStr.length >= 10 && DateTime.tryParse(newStr) != null) {
        normNew = newStr.substring(0, 10);
      }

      if (normOld != normNew) {
        final label = fieldLabels[key] ?? key;
        diffs[label] = {
          'old': oldStr.isEmpty ? '—' : oldStr,
          'new': newStr.isEmpty ? '—' : newStr,
        };
      }
    });

    return diffs.isNotEmpty ? jsonEncode(diffs) : '';
  }

  /// Verification & Review confirmation dialog before executing the Save function for a new record
  Future<void> _promptSaveConfirmation() async {
    if (!_validateAllFields()) return;

    final childName = [
      _childFirstNameController.text.trim(),
      _childMiddleNameController.text.trim(),
      _childLastNameController.text.trim(),
      _childSuffixController.text.trim(),
    ].where((s) => s.isNotEmpty).join(' ');

    final fatherName = _fatherNotIndicated
        ? 'Not Acknowledged in Birth Certificate'
        : [
      _fatherFirstNameController.text.trim(),
      _fatherMiddleNameController.text.trim(),
      _fatherLastNameController.text.trim(),
    ].where((s) => s.isNotEmpty).join(' ');

    final motherName = [
      _motherFirstNameController.text.trim(),
      _motherMiddleNameController.text.trim(),
      _motherMaidenLastNameController.text.trim(),
    ].where((s) => s.isNotEmpty).join(' ');

    final sponsor1Name = [
      _sponsor1FirstNameController.text.trim(),
      _sponsor1MiddleNameController.text.trim(),
      _sponsor1LastNameController.text.trim(),
    ].where((s) => s.isNotEmpty).join(' ');

    final sponsor2Name = [
      _sponsor2FirstNameController.text.trim(),
      _sponsor2MiddleNameController.text.trim(),
      _sponsor2LastNameController.text.trim(),
    ].where((s) => s.isNotEmpty).join(' ');

    final priestName = [
      'Rev. Fr.',
      _ministerFirstNameController.text.trim(),
      _ministerMiddleNameController.text.trim(),
      _ministerLastNameController.text.trim(),
    ].where((s) => s.isNotEmpty).join(' ');

    final otherGodparents = _otherGodparentControllers
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final screenHeight = MediaQuery.of(context).size.height;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: ParishColors.cardWhite,
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ParishColors.marianBlueSurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.fact_check_outlined, color: ParishColors.marianBlue, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Review & Verify Record',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: ParishColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Check all entered fields to ensure accurate registry archiving.',
                    style: TextStyle(fontSize: 12, color: ParishColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 580,
          height: screenHeight * 0.70,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildReviewSection('1. Registry Book Coordinates', [
                  _buildReviewRow('Book No.:', _bookNumberController.text.trim()),
                  _buildReviewRow('Page No.:', _pageNumberController.text.trim()),
                  _buildReviewRow('Line No.:', _lineNumberController.text.trim()),
                  _buildReviewRow('Registry Date:', _registryDate.toIso8601String().substring(0, 10)),
                  _buildReviewRow('Entry Status:', _entryStatus),
                ]),
                const SizedBox(height: 12),
                _buildReviewSection('2. Child Information', [
                  _buildReviewRow('Full Name:', childName),
                  _buildReviewRow('Date of Birth:', _dateOfBirth?.toIso8601String().substring(0, 10) ?? '—'),
                  _buildReviewRow('Age at Baptism:', _ageController.text.trim().isNotEmpty ? _ageController.text.trim() : '—'),
                  _buildReviewRow('Place of Birth:', _placeOfBirthController.text.trim()),
                  _buildReviewRow('Gender:', _gender),
                  _buildReviewRow('Legitimacy:', _legitimacy == 'Others (Specify)' ? _legitimacyOtherController.text.trim() : _legitimacy),
                ]),
                const SizedBox(height: 12),
                _buildReviewSection('3. Parents & Residence', [
                  _buildReviewRow('Father:', fatherName),
                  if (!_fatherNotIndicated && _fatherPlaceOfBirthController.text.trim().isNotEmpty)
                    _buildReviewRow('Father Birthplace:', _fatherPlaceOfBirthController.text.trim()),
                  _buildReviewRow('Mother Maiden Name:', motherName),
                  if (_motherPlaceOfBirthController.text.trim().isNotEmpty)
                    _buildReviewRow('Mother Birthplace:', _motherPlaceOfBirthController.text.trim()),
                  if (_parentsContactNumberController.text.trim().isNotEmpty)
                    _buildReviewRow('Contact No.:', _parentsContactNumberController.text.trim()),
                  if (_parentsResidenceController.text.trim().isNotEmpty)
                    _buildReviewRow('Residence:', _parentsResidenceController.text.trim()),
                ]),
                const SizedBox(height: 12),
                _buildReviewSection('4. Godparents & Sponsors', [
                  _buildReviewRow('Sponsor 1 (Ninong/Ninang):', sponsor1Name),
                  if (_sponsor1ResidenceController.text.trim().isNotEmpty)
                    _buildReviewRow('Sponsor 1 Residence:', _sponsor1ResidenceController.text.trim()),
                  _buildReviewRow('Sponsor 2 (Ninong/Ninang):', sponsor2Name),
                  if (_sponsor2ResidenceController.text.trim().isNotEmpty)
                    _buildReviewRow('Sponsor 2 Residence:', _sponsor2ResidenceController.text.trim()),
                  if (otherGodparents.isNotEmpty)
                    _buildReviewRow('Additional Godparents:', otherGodparents.join(', ')),
                ]),
                const SizedBox(height: 12),
                _buildReviewSection('5. Baptism Details & Priest', [
                  _buildReviewRow('Church where Baptized:', _parishChurchController.text.trim()),
                  _buildReviewRow('Officiating Priest:', priestName),
                  _buildReviewRow('Date of Baptism:', _dateOfBaptism?.toIso8601String().substring(0, 10) ?? '—'),
                  _buildReviewRow('Stipend / Offering:', _stipendController.text.trim().isNotEmpty ? '₱ ${_stipendController.text.trim()}' : '₱ 0.00 (Gratis)'),
                  if (_remarksController.text.trim().isNotEmpty)
                    _buildReviewRow('Remarks / Notes:', _remarksController.text.trim()),
                ]),
              ],
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(130, 46),
              side: BorderSide(color: ParishColors.borderGrey),
            ),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Go Back and Edit'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(160, 46),
              backgroundColor: ParishColors.oliveGreen,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.check_circle, size: 18),
            label: const Text('Confirm and Save', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _submitForm();
    }
  }

  Widget _buildReviewSection(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ParishColors.backgroundLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ParishColors.borderGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: ParishColors.marianBlue,
            ),
          ),
          const Divider(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: ParishColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: ParishColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Prompts for confirmation and audit annotation before updating canonical records
  Future<void> _promptUpdateConfirmation() async {
    if (!_validateAllFields()) return;

    final currentUser = AuthService.currentUser;
    final currentUserName = currentUser != null
        ? '${currentUser.firstName} ${currentUser.lastName}'.trim()
        : 'Authorized Parish Personnel';
    final userRole = currentUser?.userRole ?? 'Secretary';

    final reasonController = TextEditingController(text: 'Correction of record details');

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: ParishColors.cardWhite,
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ParishColors.marianBlueSurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.security_update_good, color: ParishColors.marianBlue, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Confirm Record Update',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: ParishColors.textDark,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You are modifying canonical entry ${widget.initialData!['record_id']} (${_childFirstNameController.text.trim()} ${_childLastNameController.text.trim()}).',
                style: TextStyle(fontSize: 14, color: ParishColors.textDark, height: 1.35),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ParishColors.backgroundLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ParishColors.borderGrey),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AUDIT LOG ATTRIBUTION',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ParishColors.textMuted),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Editor: $currentUserName ($userRole)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ParishColors.marianBlue),
                    ),
                    Text(
                      'Coordinates: Book ${_bookNumberController.text.trim()}, Page ${_pageNumberController.text.trim()}, Line ${_lineNumberController.text.trim()}',
                      style: TextStyle(fontSize: 12, color: ParishColors.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Reason for Correction *',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ParishColors.textDark),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: reasonController,
                maxLines: 2,
                style: const TextStyle(fontSize: 13.5),
                decoration: InputDecoration(
                  hintText: 'e.g. Typographical error correction on mother maiden name',
                  filled: true,
                  fillColor: ParishColors.backgroundLight,
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(130, 44),
              side: BorderSide(color: ParishColors.borderGrey),
            ),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Go Back and Edit'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(160, 44),
              backgroundColor: ParishColors.oliveGreen,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Confirm & Save Update', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _submitForm(reasonForCorrection: reasonController.text.trim());
    }
  }

  Future<void> _submitForm({String? reasonForCorrection}) async {
    if (!isEditMode && !_validateAllFields()) return;

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

      final currentUser = AuthService.currentUser;
      final currentUserId = currentUser?.userId ?? 'STAFF';
      final currentUserName = currentUser != null
          ? '${currentUser.firstName} ${currentUser.lastName}'.trim()
          : 'Authorized Parish Personnel';
      final now = DateTime.now();

      String? compiledCanonicalNotes = _existingCanonicalNotes;
      if (isEditMode) {
        final reason = reasonForCorrection?.isNotEmpty == true
            ? reasonForCorrection!
            : 'Amended canonical ledger entry';
        final editLogStamp =
            '[Amended on ${now.toIso8601String().substring(0, 10)} by $currentUserName (${currentUser?.userRole ?? "Staff"})]: $reason';

        if (compiledCanonicalNotes != null && compiledCanonicalNotes.trim().isNotEmpty) {
          compiledCanonicalNotes = '$compiledCanonicalNotes\n$editLogStamp';
        } else {
          compiledCanonicalNotes = editLogStamp;
        }
      }

      final recordMap = {
        'book_number': _bookNumberController.text.trim(),
        'page_number': _pageNumberController.text.trim(),
        'line_number': _lineNumberController.text.trim(),
        'registry_date': isEditMode
            ? (widget.initialData!['registry_date']?.toString().substring(0, 10) ??
            _registryDate.toIso8601String().substring(0, 10))
            : _registryDate.toIso8601String().substring(0, 10),
        'entry_status': isEditMode
            ? (widget.initialData!['entry_status']?.toString() ?? 'ORIGINAL')
            : 'CORRECTED',
        'canonical_notes': compiledCanonicalNotes,

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
        final recordId = widget.initialData!['record_id'].toString();

        final changesJson = _computeChangesSummaryJson(widget.initialData!, recordMap);

        await BaptismService.updateBaptismRecord(recordId, recordMap);

        if (changesJson.isNotEmpty) {
          try {
            await Supabase.instance.client.from('sacramental_record_audit_logs').insert({
              'log_id': 'LOG-${now.millisecondsSinceEpoch}',
              'record_id': recordId,
              'sacrament_type': 'Baptism',
              'action_type': 'UPDATED',
              'recipient_name': '${_childFirstNameController.text.trim()} ${_childLastNameController.text.trim()}',
              'book_number': _bookNumberController.text.trim(),
              'page_number': _pageNumberController.text.trim(),
              'line_number': _lineNumberController.text.trim(),
              'performed_by_id': currentUserId,
              'performed_by_name': currentUserName,
              'performed_by_role': currentUser?.userRole ?? 'Secretary',
              'justification': reasonForCorrection ?? 'Correction of entry details',
              'changes_summary': changesJson,
              'created_at': now.toIso8601String(),
            });
          } catch (auditErr) {
            debugPrint('[BaptismManualEntryPage] Audit log insertion notice: $auditErr');
          }
        }
      } else {
        final insertedRecord = await BaptismService.insertManualBaptismRecord(recordMap);

        try {
          await Supabase.instance.client.from('sacramental_record_audit_logs').insert({
            'log_id': 'LOG-${now.millisecondsSinceEpoch}',
            'record_id': insertedRecord.recordId,
            'sacrament_type': 'Baptism',
            'action_type': 'CREATED',
            'recipient_name': insertedRecord.childFullName,
            'book_number': insertedRecord.bookNumber,
            'page_number': insertedRecord.pageNumber,
            'line_number': insertedRecord.lineNumber,
            'performed_by_id': currentUserId,
            'performed_by_name': currentUserName,
            'performed_by_role': currentUser?.userRole ?? 'Secretary',
            'justification': 'Initial registry record creation',
            'changes_summary': '',
            'created_at': now.toIso8601String(),
          });
        } catch (auditErr) {
          debugPrint('[BaptismManualEntryPage] Audit log insertion notice: $auditErr');
        }
      }

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditMode
              ? 'Baptism record updated and logged successfully.'
              : 'Baptism record registered successfully.'),
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
                    ? 'Editing Record: ${widget.initialData!['record_id']}'
                    : 'Parish Baptismal Register (Liber Baptismorum)',
                style: TextStyle(fontSize: 12, color: textMutedColor),
              ),
            ],
          ),
        ),
        floatingActionButton: IgnorePointer(
          ignoring: !_showBackToTop,
          child: AnimatedOpacity(
            opacity: _showBackToTop ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 250),
            child: Semantics(
              button: true,
              label: 'Back to top, button',
              child: FocusableActionDetector(
                onShowHoverHighlight: (hovered) {
                  setState(() => _isBackToTopHovered = hovered);
                },
                actions: <Type, Action<Intent>>{
                  ActivateIntent: CallbackAction<ActivateIntent>(
                    onInvoke: (_) => _scrollToTop(),
                  ),
                },
                child: AnimatedScale(
                  scale: _isBackToTopHovered ? 1.05 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  child: SizedBox(
                    height: 48,
                    child: FloatingActionButton.extended(
                      backgroundColor: ParishColors.marianBlue,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      onPressed: _scrollToTop,
                      icon: const Icon(Icons.arrow_upward, size: 18),
                      label: const Text(
                        'Back to Top',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double availableWidth = constraints.maxWidth;
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
                              _buildFormHeaderCard(),
                              const SizedBox(height: 16),

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

                              _buildSection1Coordinates(isWide: isWide),
                              const SizedBox(height: 16),
                              _buildSection2Child(isWide: isWide),
                              const SizedBox(height: 16),
                              _buildSection3Parents(isWide: isWide),
                              const SizedBox(height: 16),
                              _buildSection4Godparents(isWide: isWide),
                              const SizedBox(height: 16),
                              _buildSection5Administration(isWide: isWide),
                              const SizedBox(height: 24),
                              _buildBottomSubmissionBar(isWide: isWide),
                              const SizedBox(height: 50),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

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

  Widget _buildFormHeaderCard() {
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
                      'BAPTISM REGISTER',
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
                        isEditMode ? 'Edit Mode' : 'New Entry',
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
                  'Baptism Record Entry',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: ParishColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Enter all record details accurately according to the church registry book.',
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
      title: '1. Registry Book, Page & Line Coordinates',
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

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: isEditMode
                    ? _buildTextFormField(
                  controller: TextEditingController(text: _entryStatus),
                  label: 'Entry Status (Locked)',
                  isRequired: false,
                  enabled: false,
                )
                    : _buildDropdownField(
                  label: 'Entry Status',
                  isRequired: true,
                  value: _entryStatus,
                  items: const ['ORIGINAL', 'CORRECTED', 'INCOMPLETE'],
                  onChanged: (val) => setState(() => _entryStatus = val!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: isEditMode
                    ? _buildTextFormField(
                  controller: TextEditingController(text: _registryDate.toIso8601String().substring(0, 10)),
                  label: 'Registry Date (Locked)',
                  isRequired: false,
                  enabled: false,
                )
                    : _buildDatePickerField(
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

  Widget _buildSection2Child({required bool isWide}) {
    final bool hasBirthIndicated = _dateOfBirth != null;

    return _buildSectionCard(
      title: "2. Child's Information",
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
                  label: hasBirthIndicated ? 'Age at Baptism (Calculated)' : 'Age at Baptism',
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

  Widget _buildSection3Parents({required bool isWide}) {
    return _buildSectionCard(
      title: "3. Parents & Residence",
      icon: Icons.people,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Father's Information", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: ParishColors.marianBlue)),
          const SizedBox(height: 8),

          Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: _fatherNotIndicated ? ParishColors.marianBlueSurface : ParishColors.backgroundLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _fatherNotIndicated ? ParishColors.marianBlue : ParishColors.borderGrey,
                width: _fatherNotIndicated ? 1.6 : 1.0,
              ),
            ),
            child: CheckboxListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              activeColor: ParishColors.marianBlue,
              title: const Text(
                'Father not acknowledged in the Birth Certificate',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Check this box if no father is listed on the child\'s birth certificate. Father fields will be handled automatically.',
                style: TextStyle(fontSize: 12),
              ),
              value: _fatherNotIndicated,
              onChanged: _onFatherNotIndicatedToggle,
            ),
          ),

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
                    label: 'Birthplace / Hometown',
                    isRequired: false,
                    enabled: !_fatherNotIndicated,
                    maxLength: 100,
                    validator: (val) => !_fatherNotIndicated ? SacramentalValidators.validatePlace(val, "Father's birthplace", isRequired: false, maxLength: 100) : null,
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
                    label: 'Birthplace / Hometown',
                    isRequired: false,
                    enabled: !_fatherNotIndicated,
                    maxLength: 100,
                    validator: (val) => !_fatherNotIndicated ? SacramentalValidators.validatePlace(val, "Father's birthplace", isRequired: false, maxLength: 100) : null,
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
                    label: 'Birthplace / Hometown',
                    isRequired: false,
                    maxLength: 100,
                    validator: (val) => SacramentalValidators.validatePlace(val, "Mother's birthplace", isRequired: false, maxLength: 100),
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
                    label: 'Birthplace / Hometown',
                    isRequired: false,
                    maxLength: 100,
                    validator: (val) => SacramentalValidators.validatePlace(val, "Mother's birthplace", isRequired: false, maxLength: 100),
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
                  label: 'Parents Contact No. (11 digits)',
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

  Widget _buildSection4Godparents({required bool isWide}) {
    return _buildSectionCard(
      title: '4. Godparents & Sponsors',
      icon: Icons.people_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Primary Sponsors (Required)',
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

          Text('Additional Godparents & Witnesses', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: ParishColors.textDark)),
          const SizedBox(height: 4),
          Text(
            'Click "[+] Add Godparent" to add additional sponsor names individually.',
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

  Widget _buildSection5Administration({required bool isWide}) {
    return _buildSectionCard(
      title: '5. Baptism Details & Officiating Priest',
      icon: Icons.church,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextFormField(
            controller: _parishChurchController,
            label: 'Church where Baptized',
            isRequired: true,
            maxLength: 150,
            validator: (val) => SacramentalValidators.validatePlace(val, 'Church where baptized', isRequired: true, maxLength: 150),
          ),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _buildTextFormField(
                  controller: _ministerFirstNameController,
                  label: 'Priest First Name',
                  isRequired: true,
                  maxLength: 50,
                  validator: (val) => SacramentalValidators.validateName(val, 'Priest first name', isRequired: true, maxLength: 50),
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
                  validator: (val) => SacramentalValidators.validateName(val, 'Priest middle name', isRequired: false, maxLength: 50),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: _buildTextFormField(
                  controller: _ministerLastNameController,
                  label: 'Priest Last Name',
                  isRequired: true,
                  maxLength: 50,
                  validator: (val) => SacramentalValidators.validateName(val, 'Priest last name', isRequired: true, maxLength: 50),
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
                  label: 'Stipend / Offering (₱)',
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
            label: 'Remarks / Marginal Notes (Optional)',
            isRequired: false,
            maxLines: 2,
            maxLength: 255,
          ),
        ],
      ),
    );
  }

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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: isWide ? 190 : 130,
            height: 50,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
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
                if (shouldExit && context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: Text(
                'Discard & Exit',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textMutedColor),
              ),
            ),
          ),
          SizedBox(
            width: isWide ? 290 : 180,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: (_coordinateDuplicateError != null)
                    ? ParishColors.mercyRed
                    : (isEditMode ? ParishColors.marianBlue : ParishColors.oliveGreen),
                foregroundColor: Colors.white,
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: (_isSubmitting || _coordinateDuplicateError != null)
                  ? null
                  : () {
                if (isEditMode) {
                  _promptUpdateConfirmation();
                } else {
                  _promptSaveConfirmation();
                }
              },
              icon: Icon(isEditMode ? Icons.security_update_good : Icons.check_circle_outline, size: 22),
              label: Text(
                isEditMode ? 'Update Baptism Record' : 'Save Baptism Record',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

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

