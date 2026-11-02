// =============================================================================
// FILE: lib/features/sacramental_records/presentation/pages/matrimony_manual_entry_page.dart
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/colors.dart';
import '../../../auth/services/auth_service.dart';
import '../../services/matrimony_service.dart';
import '../../validators/sacramental_validators.dart';
import '../dialogs/discard_entry_dialog.dart';

class MatrimonyManualEntryPage extends StatefulWidget {
  final VoidCallback? onRecordSaved;
  final Map<String, dynamic>? initialData; // Enables Edit Record Mode

  const MatrimonyManualEntryPage({
    super.key,
    this.onRecordSaved,
    this.initialData,
  });

  @override
  State<MatrimonyManualEntryPage> createState() => _MatrimonyManualEntryPageState();
}

class _MatrimonyManualEntryPageState extends State<MatrimonyManualEntryPage> {
  final _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();

  // Floating Back to Top state & micro-interactions
  bool _showBackToTop = false;
  bool _isBackToTopHovered = false;

  bool get isEditMode => widget.initialData != null;

  // Royal Amethyst / Burgundy Theme Accent for Matrimony
  static const Color _matrimonyBurgundy = Color(0xFF9D174D);

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

  // 2. Groom Information
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

  // 3. Bride Information
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

  // 4. Sponsors
  final _sponsor1FirstNameController = TextEditingController();
  final _sponsor1MiddleNameController = TextEditingController();
  final _sponsor1LastNameController = TextEditingController();
  final _sponsor1OriginAddressController = TextEditingController();

  final _sponsor2FirstNameController = TextEditingController();
  final _sponsor2MiddleNameController = TextEditingController();
  final _sponsor2LastNameController = TextEditingController();
  final _sponsor2OriginAddressController = TextEditingController();

  // Dynamic Other Sponsors List
  final List<TextEditingController> _otherSponsorControllers = [];

  // 5. Ceremony & Legal Details
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
  String? _existingCanonicalNotes;

  bool _isSubmitting = false;
  String? _errorMessage;
  bool _dateOfMarriageHasError = false;

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

    // Groom
    _groomFirstNameController.text = data['groom_first_name']?.toString() ?? '';
    _groomMiddleNameController.text = data['groom_middle_name']?.toString() ?? '';
    _groomLastNameController.text = data['groom_last_name']?.toString() ?? '';
    _groomSuffixController.text = data['groom_suffix']?.toString() ?? '';
    _groomCivilStatus = data['groom_civil_status']?.toString() ?? 'Single';
    _groomAgeController.text = data['groom_age']?.toString() ?? '';
    _groomDateOfBirth = DateTime.tryParse(data['groom_date_of_birth']?.toString() ?? '');
    _groomPlaceOfBirthController.text = data['groom_place_of_birth']?.toString() ?? '';
    _groomAddressController.text = data['groom_address']?.toString() ?? '';
    _groomFatherFirstNameController.text = data['groom_father_first_name']?.toString() ?? '';
    _groomFatherMiddleNameController.text = data['groom_father_middle_name']?.toString() ?? '';
    _groomFatherLastNameController.text = data['groom_father_last_name']?.toString() ?? '';
    _groomMotherFirstNameController.text = data['groom_mother_first_name']?.toString() ?? '';
    _groomMotherMiddleNameController.text = data['groom_mother_middle_name']?.toString() ?? '';
    _groomMotherMaidenLastController.text = data['groom_mother_maiden_last']?.toString() ?? '';

    // Bride
    _brideFirstNameController.text = data['bride_first_name']?.toString() ?? '';
    _brideMiddleNameController.text = data['bride_middle_name']?.toString() ?? '';
    _brideLastNameController.text = data['bride_last_name']?.toString() ?? '';
    _brideSuffixController.text = data['bride_suffix']?.toString() ?? '';
    _brideCivilStatus = data['bride_civil_status']?.toString() ?? 'Single';
    _brideAgeController.text = data['bride_age']?.toString() ?? '';
    _brideDateOfBirth = DateTime.tryParse(data['bride_date_of_birth']?.toString() ?? '');
    _bridePlaceOfBirthController.text = data['bride_place_of_birth']?.toString() ?? '';
    _brideAddressController.text = data['bride_address']?.toString() ?? '';
    _brideFatherFirstNameController.text = data['bride_father_first_name']?.toString() ?? '';
    _brideFatherMiddleNameController.text = data['bride_father_middle_name']?.toString() ?? '';
    _brideFatherLastNameController.text = data['bride_father_last_name']?.toString() ?? '';
    _brideMotherFirstNameController.text = data['bride_mother_first_name']?.toString() ?? '';
    _brideMotherMiddleNameController.text = data['bride_mother_middle_name']?.toString() ?? '';
    _brideMotherMaidenLastController.text = data['bride_mother_maiden_last']?.toString() ?? '';

    // Sponsors
    _sponsor1FirstNameController.text = data['sponsor_1_first_name']?.toString() ?? '';
    _sponsor1MiddleNameController.text = data['sponsor_1_middle_name']?.toString() ?? '';
    _sponsor1LastNameController.text = data['sponsor_1_last_name']?.toString() ?? '';
    _sponsor1OriginAddressController.text = data['sponsor_1_origin_address']?.toString() ?? '';

    _sponsor2FirstNameController.text = data['sponsor_2_first_name']?.toString() ?? '';
    _sponsor2MiddleNameController.text = data['sponsor_2_middle_name']?.toString() ?? '';
    _sponsor2LastNameController.text = data['sponsor_2_last_name']?.toString() ?? '';
    _sponsor2OriginAddressController.text = data['sponsor_2_origin_address']?.toString() ?? '';

    final rawOtherSponsors = data['other_sponsors']?.toString() ?? '';
    if (rawOtherSponsors.trim().isNotEmpty) {
      final list = rawOtherSponsors.contains('\n')
          ? rawOtherSponsors.split('\n')
          : rawOtherSponsors.split(',');
      for (var s in list) {
        if (s.trim().isNotEmpty) {
          _otherSponsorControllers.add(TextEditingController(text: s.trim()));
        }
      }
    }

    // Ceremony Details
    _dateOfMarriage = DateTime.tryParse(data['date_of_marriage']?.toString() ?? '');
    _marriageType = data['marriage_type']?.toString() ?? 'Between Catholics';
    _isFilipinoForeigner = data['is_filipino_foreigner'] == true;
    _marriageLicenseNoController.text = data['marriage_license_no']?.toString() ?? '';
    _licenseDateRegistered = DateTime.tryParse(data['license_date_registered']?.toString() ?? '');
    _licensePlaceIssuedController.text = data['license_place_issued']?.toString() ?? '';

    _solemnizerFirstNameController.text = data['solemnizer_first_name']?.toString() ?? '';
    _solemnizerMiddleNameController.text = data['solemnizer_middle_name']?.toString() ?? '';
    _solemnizerLastNameController.text = data['solemnizer_last_name']?.toString() ?? '';
    _crasmNumberController.text = data['crasm_number']?.toString() ?? '';
    _crasmValidityDate = DateTime.tryParse(data['crasm_validity_date']?.toString() ?? '');
    _stipendController.text = data['stipend']?.toString() ?? '';
    _parishNameController.text = data['parish_name']?.toString() ?? 'St. John Paul II Parish';
    _remarksController.text = data['remarks']?.toString() ?? '';

    if (_groomDateOfBirth != null) _recomputeGroomAge();
    if (_brideDateOfBirth != null) _recomputeBrideAge();
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
      tableName: 'matrimony_records',
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

  void _recomputeGroomAge() {
    if (_groomDateOfBirth != null && _dateOfMarriage != null) {
      final years = SacramentalValidators.calculateAgeInYears(
        _groomDateOfBirth!,
        _dateOfMarriage!,
      );
      _groomAgeController.text = '$years';
    }
  }

  void _recomputeBrideAge() {
    if (_brideDateOfBirth != null && _dateOfMarriage != null) {
      final years = SacramentalValidators.calculateAgeInYears(
        _brideDateOfBirth!,
        _dateOfMarriage!,
      );
      _brideAgeController.text = '$years';
    }
  }

  Future<void> _selectDate(BuildContext context, int dateType) async {
    final now = DateTime.now();
    DateTime initialDate = now;

    if (dateType == 0) initialDate = _registryDate;
    if (dateType == 1) initialDate = _groomDateOfBirth ?? DateTime(now.year - 25, 1, 1);
    if (dateType == 2) initialDate = _brideDateOfBirth ?? DateTime(now.year - 23, 1, 1);
    if (dateType == 3) initialDate = _dateOfMarriage ?? now;
    if (dateType == 4) initialDate = _licenseDateRegistered ?? now;
    if (dateType == 5) initialDate = _crasmValidityDate ?? now;

    final DateTime upperDateBound = (dateType == 5) ? now.add(const Duration(days: 3650)) : now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(upperDateBound) ? upperDateBound : initialDate,
      firstDate: DateTime(1900),
      lastDate: upperDateBound,
    );

    if (picked != null) {
      setState(() {
        if (dateType == 0) _registryDate = picked;
        if (dateType == 1) {
          _groomDateOfBirth = picked;
          _recomputeGroomAge();
        }
        if (dateType == 2) {
          _brideDateOfBirth = picked;
          _recomputeBrideAge();
        }
        if (dateType == 3) {
          _dateOfMarriage = picked;
          _dateOfMarriageHasError = false;
          _recomputeGroomAge();
          _recomputeBrideAge();
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

    final groomDobError = SacramentalValidators.validateDateOfBirth(_groomDateOfBirth, isRequired: false);
    if (groomDobError != null) {
      setState(() => _errorMessage = 'Groom: $groomDobError');
      _scrollToTop();
      return false;
    }

    final brideDobError = SacramentalValidators.validateDateOfBirth(_brideDateOfBirth, isRequired: false);
    if (brideDobError != null) {
      setState(() => _errorMessage = 'Bride: $brideDobError');
      _scrollToTop();
      return false;
    }

    if (_dateOfMarriage == null) {
      setState(() {
        _dateOfMarriageHasError = true;
        _errorMessage = 'Date of Marriage is required.';
      });
      _scrollToTop();
      return false;
    }

    final marriageNotFuture = SacramentalValidators.validateNotFutureDate(_dateOfMarriage, 'Date of Marriage');
    if (marriageNotFuture != null) {
      setState(() => _errorMessage = marriageNotFuture);
      _scrollToTop();
      return false;
    }

    return true;
  }

  /// Computes strict dynamic diff, excluding unchanged fields and uneditable audit metadata
  String _computeChangesSummaryJson(Map<String, dynamic> oldData, Map<String, dynamic> newData) {
    final diffs = <String, Map<String, dynamic>>{};

    final Map<String, String> fieldLabels = {
      'book_number': 'Book No.',
      'page_number': 'Page No.',
      'line_number': 'Line No.',
      'groom_first_name': 'Groom First Name',
      'groom_middle_name': 'Groom Middle Name',
      'groom_last_name': 'Groom Last Name',
      'groom_suffix': 'Groom Suffix',
      'groom_civil_status': 'Groom Civil Status',
      'groom_age': 'Groom Age',
      'groom_date_of_birth': 'Groom Date of Birth',
      'groom_place_of_birth': 'Groom Birthplace',
      'groom_address': 'Groom Residence',
      'groom_father_first_name': 'Groom Father First Name',
      'groom_father_middle_name': 'Groom Father Middle Name',
      'groom_father_last_name': 'Groom Father Last Name',
      'groom_mother_first_name': 'Groom Mother First Name',
      'groom_mother_middle_name': 'Groom Mother Middle Name',
      'groom_mother_maiden_last': 'Groom Mother Maiden Last Name',
      'bride_first_name': 'Bride First Name',
      'bride_middle_name': 'Bride Middle Name',
      'bride_last_name': 'Bride Last Name',
      'bride_suffix': 'Bride Suffix',
      'bride_civil_status': 'Bride Civil Status',
      'bride_age': 'Bride Age',
      'bride_date_of_birth': 'Bride Date of Birth',
      'bride_place_of_birth': 'Bride Birthplace',
      'bride_address': 'Bride Residence',
      'bride_father_first_name': 'Bride Father First Name',
      'bride_father_middle_name': 'Bride Father Middle Name',
      'bride_father_last_name': 'Bride Father Last Name',
      'bride_mother_first_name': 'Bride Mother First Name',
      'bride_mother_middle_name': 'Bride Mother Middle Name',
      'bride_mother_maiden_last': 'Bride Mother Maiden Last Name',
      'sponsor_1_first_name': 'Sponsor 1 First Name',
      'sponsor_1_middle_name': 'Sponsor 1 Middle Name',
      'sponsor_1_last_name': 'Sponsor 1 Last Name',
      'sponsor_1_origin_address': 'Sponsor 1 Address',
      'sponsor_2_first_name': 'Sponsor 2 First Name',
      'sponsor_2_middle_name': 'Sponsor 2 Middle Name',
      'sponsor_2_last_name': 'Sponsor 2 Last Name',
      'sponsor_2_origin_address': 'Sponsor 2 Address',
      'other_sponsors': 'Other Witnesses',
      'date_of_marriage': 'Date of Marriage',
      'marriage_type': 'Marriage Type',
      'is_filipino_foreigner': 'Filipino / Foreigner Status',
      'marriage_license_no': 'Marriage License No.',
      'license_date_registered': 'License Date Registered',
      'license_place_issued': 'License Place Issued',
      'solemnizer_first_name': 'Priest First Name',
      'solemnizer_middle_name': 'Priest Middle Name',
      'solemnizer_last_name': 'Priest Last Name',
      'crasm_number': 'CRASM Number',
      'crasm_validity_date': 'CRASM Validity Date',
      'stipend': 'Stipend',
      'parish_name': 'Parish Name',
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

  /// Verification & Review confirmation dialog before saving a new Matrimony record
  Future<void> _promptSaveConfirmation() async {
    if (!_validateAllFields()) return;

    final groomName = [
      _groomFirstNameController.text.trim(),
      _groomMiddleNameController.text.trim(),
      _groomLastNameController.text.trim(),
      _groomSuffixController.text.trim(),
    ].where((s) => s.isNotEmpty).join(' ');

    final brideName = [
      _brideFirstNameController.text.trim(),
      _brideMiddleNameController.text.trim(),
      _brideLastNameController.text.trim(),
      _brideSuffixController.text.trim(),
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
      _solemnizerFirstNameController.text.trim(),
      _solemnizerMiddleNameController.text.trim(),
      _solemnizerLastNameController.text.trim(),
    ].where((s) => s.isNotEmpty).join(' ');

    final otherSponsors = _otherSponsorControllers
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
                color: _matrimonyBurgundy.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.fact_check_outlined, color: _matrimonyBurgundy, size: 24),
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
                    'Verify all fields before saving into Liber Matrimoniorum.',
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
                _buildReviewSection('1. Registry Coordinates', [
                  _buildReviewRow('Book No.:', _bookNumberController.text.trim()),
                  _buildReviewRow('Page No.:', _pageNumberController.text.trim()),
                  _buildReviewRow('Line No.:', _lineNumberController.text.trim()),
                  _buildReviewRow('Registry Date:', _registryDate.toIso8601String().substring(0, 10)),
                  _buildReviewRow('Entry Status:', _entryStatus),
                ]),
                const SizedBox(height: 12),
                _buildReviewSection("2. Groom's Information", [
                  _buildReviewRow('Full Name:', groomName),
                  _buildReviewRow('Age:', _groomAgeController.text.trim()),
                  _buildReviewRow('Civil Status:', _groomCivilStatus),
                  if (_groomDateOfBirth != null)
                    _buildReviewRow('Date of Birth:', _groomDateOfBirth!.toIso8601String().substring(0, 10)),
                  if (_groomPlaceOfBirthController.text.trim().isNotEmpty)
                    _buildReviewRow('Birthplace:', _groomPlaceOfBirthController.text.trim()),
                  _buildReviewRow('Residence:', _groomAddressController.text.trim()),
                  _buildReviewRow('Father:', '${_groomFatherFirstNameController.text.trim()} ${_groomFatherLastNameController.text.trim()}'),
                  _buildReviewRow('Mother Maiden Name:', '${_groomMotherFirstNameController.text.trim()} ${_groomMotherMaidenLastController.text.trim()}'),
                ]),
                const SizedBox(height: 12),
                _buildReviewSection("3. Bride's Information", [
                  _buildReviewRow('Full Name:', brideName),
                  _buildReviewRow('Age:', _brideAgeController.text.trim()),
                  _buildReviewRow('Civil Status:', _brideCivilStatus),
                  if (_brideDateOfBirth != null)
                    _buildReviewRow('Date of Birth:', _brideDateOfBirth!.toIso8601String().substring(0, 10)),
                  if (_bridePlaceOfBirthController.text.trim().isNotEmpty)
                    _buildReviewRow('Birthplace:', _bridePlaceOfBirthController.text.trim()),
                  _buildReviewRow('Residence:', _brideAddressController.text.trim()),
                  _buildReviewRow('Father:', '${_brideFatherFirstNameController.text.trim()} ${_brideFatherLastNameController.text.trim()}'),
                  _buildReviewRow('Mother Maiden Name:', '${_brideMotherFirstNameController.text.trim()} ${_brideMotherMaidenLastController.text.trim()}'),
                ]),
                const SizedBox(height: 12),
                _buildReviewSection('4. Primary & Secondary Witnesses', [
                  _buildReviewRow('Primary Sponsor 1:', sponsor1Name),
                  _buildReviewRow('Primary Sponsor 2:', sponsor2Name),
                  if (otherSponsors.isNotEmpty)
                    _buildReviewRow('Additional Witnesses:', otherSponsors.join(', ')),
                ]),
                const SizedBox(height: 12),
                _buildReviewSection('5. Ceremony & Legal Details', [
                  _buildReviewRow('Date of Marriage:', _dateOfMarriage?.toIso8601String().substring(0, 10) ?? '—'),
                  _buildReviewRow('Marriage Type:', _marriageType),
                  _buildReviewRow('Solemnizing Priest:', priestName),
                  if (_marriageLicenseNoController.text.trim().isNotEmpty)
                    _buildReviewRow('Marriage License No.:', _marriageLicenseNoController.text.trim()),
                  if (_crasmNumberController.text.trim().isNotEmpty)
                    _buildReviewRow('CRASM Number:', _crasmNumberController.text.trim()),
                  _buildReviewRow('Stipend / Offering:', _stipendController.text.trim().isNotEmpty ? '₱ ${_stipendController.text.trim()}' : '₱ 0.00'),
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
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: _matrimonyBurgundy,
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

    final reasonController = TextEditingController(text: 'Correction of marriage record details');

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
                color: _matrimonyBurgundy.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.security_update_good, color: _matrimonyBurgundy, size: 24),
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
                'You are modifying canonical entry ${widget.initialData!['record_id']} (${_groomLastNameController.text.trim()} & ${_brideLastNameController.text.trim()}).',
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
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _matrimonyBurgundy),
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
                  hintText: 'e.g. Typographical error correction on bride surname or license details',
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

    setState(() => _isSubmitting = true);

    try {
      List<String> collectedOtherSponsors = _otherSponsorControllers
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

      if (isEditMode) {
        final recordId = widget.initialData!['record_id'].toString();

        final changesJson = _computeChangesSummaryJson(widget.initialData!, recordMap);

        await MatrimonyService.updateMatrimonyRecord(recordId, recordMap);

        if (changesJson.isNotEmpty) {
          try {
            await Supabase.instance.client.from('sacramental_record_audit_logs').insert({
              'log_id': 'LOG-${now.millisecondsSinceEpoch}',
              'record_id': recordId,
              'sacrament_type': 'Matrimony',
              'action_type': 'UPDATED',
              'recipient_name': '${_groomLastNameController.text.trim()} & ${_brideLastNameController.text.trim()}',
              'book_number': _bookNumberController.text.trim(),
              'page_number': _pageNumberController.text.trim(),
              'line_number': _lineNumberController.text.trim(),
              'performed_by_id': currentUserId,
              'performed_by_name': currentUserName,
              'performed_by_role': currentUser?.userRole ?? 'Secretary',
              'justification': reasonForCorrection ?? 'Correction of marriage record details',
              'changes_summary': changesJson,
              'created_at': now.toIso8601String(),
            });
          } catch (auditErr) {
            debugPrint('[MatrimonyManualEntryPage] Audit log insertion notice: $auditErr');
          }
        }
      } else {
        final insertedRecord = await MatrimonyService.insertManualMatrimonyRecord(recordMap);

        try {
          await Supabase.instance.client.from('sacramental_record_audit_logs').insert({
            'log_id': 'LOG-${now.millisecondsSinceEpoch}',
            'record_id': insertedRecord.recordId,
            'sacrament_type': 'Matrimony',
            'action_type': 'CREATED',
            'recipient_name': '${insertedRecord.groomFullName} & ${insertedRecord.brideFullName}',
            'book_number': insertedRecord.bookNumber,
            'page_number': insertedRecord.pageNumber,
            'line_number': insertedRecord.lineNumber,
            'performed_by_id': currentUserId,
            'performed_by_name': currentUserName,
            'performed_by_role': currentUser?.userRole ?? 'Secretary',
            'justification': 'Initial marriage registry entry',
            'changes_summary': '',
            'created_at': now.toIso8601String(),
          });
        } catch (auditErr) {
          debugPrint('[MatrimonyManualEntryPage] Audit log insertion notice: $auditErr');
        }
      }

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditMode
              ? 'Matrimony record updated and logged successfully.'
              : 'Matrimony record registered successfully.'),
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
                isEditMode ? 'Edit Matrimony Record' : 'Matrimony Manual Entry',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDarkColor),
              ),
              Text(
                isEditMode
                    ? 'Editing Record: ${widget.initialData!['record_id']}'
                    : 'Canonical Registry Book (Liber Matrimoniorum)',
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
                      backgroundColor: _matrimonyBurgundy,
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
                              _buildSection2Groom(isWide: isWide),
                              const SizedBox(height: 16),
                              _buildSection3Bride(isWide: isWide),
                              const SizedBox(height: 16),
                              _buildSection4Sponsors(isWide: isWide),
                              const SizedBox(height: 16),
                              _buildSection5Ceremony(isWide: isWide),
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
            decoration: const BoxDecoration(
              color: _matrimonyBurgundy,
              borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
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
                    const Text(
                      'MATRIMONY REGISTER',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _matrimonyBurgundy,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _matrimonyBurgundy.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Canonical Step',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _matrimonyBurgundy,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Holy Matrimony Record Entry',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: ParishColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Record canonical marriage details, spouses, witnesses, and civil license information.',
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
                color: _matrimonyBurgundy.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _matrimonyBurgundy.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock, size: 16, color: _matrimonyBurgundy),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Book, Page, and Line coordinates are permanent physical coordinates and cannot be altered.',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _matrimonyBurgundy),
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
                  const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.8, color: _matrimonyBurgundy)),
                  const SizedBox(width: 8),
                  Text('Checking physical matrimony register...', style: TextStyle(fontSize: 11, color: ParishColors.textMuted)),
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

  Widget _buildSection2Groom({required bool isWide}) {
    final bool hasGroomDob = _groomDateOfBirth != null;

    return _buildSectionCard(
      title: "2. Groom's Information",
      icon: Icons.male,
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
                    controller: _groomFirstNameController,
                    label: "Groom's First Name",
                    isRequired: true,
                    maxLength: 50,
                    validator: (val) => SacramentalValidators.validateName(val, "Groom's first name", isRequired: true, maxLength: 50),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _buildTextFormField(
                    controller: _groomMiddleNameController,
                    label: 'Middle Name',
                    isRequired: false,
                    maxLength: 50,
                    validator: (val) => SacramentalValidators.validateName(val, "Groom's middle name", isRequired: false, maxLength: 50),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: _buildTextFormField(
                    controller: _groomLastNameController,
                    label: "Groom's Last Name",
                    isRequired: true,
                    maxLength: 50,
                    validator: (val) => SacramentalValidators.validateName(val, "Groom's last name", isRequired: true, maxLength: 50),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: _buildTextFormField(
                    controller: _groomSuffixController,
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
                    controller: _groomFirstNameController,
                    label: "Groom's First Name",
                    isRequired: true,
                    maxLength: 50,
                    validator: (val) => SacramentalValidators.validateName(val, "Groom's first name", isRequired: true, maxLength: 50),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: _buildTextFormField(
                    controller: _groomMiddleNameController,
                    label: 'Middle Name',
                    isRequired: false,
                    maxLength: 50,
                    validator: (val) => SacramentalValidators.validateName(val, "Groom's middle name", isRequired: false, maxLength: 50),
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
                    controller: _groomLastNameController,
                    label: "Groom's Last Name",
                    isRequired: true,
                    maxLength: 50,
                    validator: (val) => SacramentalValidators.validateName(val, "Groom's last name", isRequired: true, maxLength: 50),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: _buildTextFormField(
                    controller: _groomSuffixController,
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
                child: _buildDropdownField(
                  label: 'Civil Status',
                  isRequired: true,
                  value: _groomCivilStatus,
                  items: const ['Single', 'Widower', 'Annulled', 'Divorced'],
                  onChanged: (val) => setState(() => _groomCivilStatus = val!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextFormField(
                  controller: _groomAgeController,
                  label: hasGroomDob ? "Groom's Age (Calculated)" : "Groom's Age",
                  isRequired: true,
                  enabled: !hasGroomDob,
                  keyboardType: TextInputType.number,
                  maxLength: 3,
                  validator: (val) => SacramentalValidators.validateWholeNumberAge(val, isRequired: true),
                ),
              ),
            ],
          ),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildDatePickerField(
                  label: 'Date of Birth (Optional)',
                  isRequired: false,
                  value: _groomDateOfBirth,
                  hasError: false,
                  onTap: () => _selectDate(context, 1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextFormField(
                  controller: _groomPlaceOfBirthController,
                  label: 'Birthplace / Hometown',
                  isRequired: false,
                  maxLength: 100,
                  validator: (val) => SacramentalValidators.validatePlace(val, "Groom's birthplace", isRequired: false, maxLength: 100),
                ),
              ),
            ],
          ),

          _buildTextFormField(
            controller: _groomAddressController,
            label: "Groom's Residential Address",
            isRequired: true,
            maxLength: 150,
            validator: (val) => SacramentalValidators.validatePlace(val, "Groom's address", isRequired: true, maxLength: 150),
          ),

          const Divider(height: 24),
          const Text("Groom's Parents", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _matrimonyBurgundy)),
          const SizedBox(height: 8),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildTextFormField(
                  controller: _groomFatherFirstNameController,
                  label: "Father's First Name",
                  isRequired: true,
                  maxLength: 50,
                  validator: (val) => SacramentalValidators.validateName(val, "Father's first name", isRequired: true, maxLength: 50),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextFormField(
                  controller: _groomFatherMiddleNameController,
                  label: 'Middle Name',
                  isRequired: false,
                  maxLength: 50,
                  validator: (val) => SacramentalValidators.validateName(val, "Father's middle name", isRequired: false, maxLength: 50),
                ),
              ),
            ],
          ),
          _buildTextFormField(
            controller: _groomFatherLastNameController,
            label: "Father's Last Name",
            isRequired: true,
            maxLength: 50,
            validator: (val) => SacramentalValidators.validateName(val, "Father's last name", isRequired: true, maxLength: 50),
          ),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildTextFormField(
                  controller: _groomMotherFirstNameController,
                  label: "Mother's First Name",
                  isRequired: true,
                  maxLength: 50,
                  validator: (val) => SacramentalValidators.validateName(val, "Mother's first name", isRequired: true, maxLength: 50),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextFormField(
                  controller: _groomMotherMiddleNameController,
                  label: 'Middle Name',
                  isRequired: false,
                  maxLength: 50,
                  validator: (val) => SacramentalValidators.validateName(val, "Mother's middle name", isRequired: false, maxLength: 50),
                ),
              ),
            ],
          ),
          _buildTextFormField(
            controller: _groomMotherMaidenLastController,
            label: "Mother's Maiden Last Name",
            isRequired: true,
            maxLength: 50,
            validator: (val) => SacramentalValidators.validateName(val, "Mother's maiden last name", isRequired: true, maxLength: 50),
          ),
        ],
      ),
    );
  }

  Widget _buildSection3Bride({required bool isWide}) {
    final bool hasBrideDob = _brideDateOfBirth != null;

    return _buildSectionCard(
      title: "3. Bride's Information",
      icon: Icons.female,
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
                    controller: _brideFirstNameController,
                    label: "Bride's First Name",
                    isRequired: true,
                    maxLength: 50,
                    validator: (val) => SacramentalValidators.validateName(val, "Bride's first name", isRequired: true, maxLength: 50),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _buildTextFormField(
                    controller: _brideMiddleNameController,
                    label: 'Middle Name',
                    isRequired: false,
                    maxLength: 50,
                    validator: (val) => SacramentalValidators.validateName(val, "Bride's middle name", isRequired: false, maxLength: 50),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: _buildTextFormField(
                    controller: _brideLastNameController,
                    label: "Bride's Last Name",
                    isRequired: true,
                    maxLength: 50,
                    validator: (val) => SacramentalValidators.validateName(val, "Bride's last name", isRequired: true, maxLength: 50),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: _buildTextFormField(
                    controller: _brideSuffixController,
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
                    controller: _brideFirstNameController,
                    label: "Bride's First Name",
                    isRequired: true,
                    maxLength: 50,
                    validator: (val) => SacramentalValidators.validateName(val, "Bride's first name", isRequired: true, maxLength: 50),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: _buildTextFormField(
                    controller: _brideMiddleNameController,
                    label: 'Middle Name',
                    isRequired: false,
                    maxLength: 50,
                    validator: (val) => SacramentalValidators.validateName(val, "Bride's middle name", isRequired: false, maxLength: 50),
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
                    controller: _brideLastNameController,
                    label: "Bride's Last Name",
                    isRequired: true,
                    maxLength: 50,
                    validator: (val) => SacramentalValidators.validateName(val, "Bride's last name", isRequired: true, maxLength: 50),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: _buildTextFormField(
                    controller: _brideSuffixController,
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
                child: _buildDropdownField(
                  label: 'Civil Status',
                  isRequired: true,
                  value: _brideCivilStatus,
                  items: const ['Single', 'Widow', 'Annulled', 'Divorced'],
                  onChanged: (val) => setState(() => _brideCivilStatus = val!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextFormField(
                  controller: _brideAgeController,
                  label: hasBrideDob ? "Bride's Age (Calculated)" : "Bride's Age",
                  isRequired: true,
                  enabled: !hasBrideDob,
                  keyboardType: TextInputType.number,
                  maxLength: 3,
                  validator: (val) => SacramentalValidators.validateWholeNumberAge(val, isRequired: true),
                ),
              ),
            ],
          ),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildDatePickerField(
                  label: 'Date of Birth (Optional)',
                  isRequired: false,
                  value: _brideDateOfBirth,
                  hasError: false,
                  onTap: () => _selectDate(context, 2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextFormField(
                  controller: _bridePlaceOfBirthController,
                  label: 'Birthplace / Hometown',
                  isRequired: false,
                  maxLength: 100,
                  validator: (val) => SacramentalValidators.validatePlace(val, "Bride's birthplace", isRequired: false, maxLength: 100),
                ),
              ),
            ],
          ),

          _buildTextFormField(
            controller: _brideAddressController,
            label: "Bride's Residential Address",
            isRequired: true,
            maxLength: 150,
            validator: (val) => SacramentalValidators.validatePlace(val, "Bride's address", isRequired: true, maxLength: 150),
          ),

          const Divider(height: 24),
          const Text("Bride's Parents", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _matrimonyBurgundy)),
          const SizedBox(height: 8),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildTextFormField(
                  controller: _brideFatherFirstNameController,
                  label: "Father's First Name",
                  isRequired: true,
                  maxLength: 50,
                  validator: (val) => SacramentalValidators.validateName(val, "Father's first name", isRequired: true, maxLength: 50),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextFormField(
                  controller: _brideFatherMiddleNameController,
                  label: 'Middle Name',
                  isRequired: false,
                  maxLength: 50,
                  validator: (val) => SacramentalValidators.validateName(val, "Father's middle name", isRequired: false, maxLength: 50),
                ),
              ),
            ],
          ),
          _buildTextFormField(
            controller: _brideFatherLastNameController,
            label: "Father's Last Name",
            isRequired: true,
            maxLength: 50,
            validator: (val) => SacramentalValidators.validateName(val, "Father's last name", isRequired: true, maxLength: 50),
          ),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildTextFormField(
                  controller: _brideMotherFirstNameController,
                  label: "Mother's First Name",
                  isRequired: true,
                  maxLength: 50,
                  validator: (val) => SacramentalValidators.validateName(val, "Mother's first name", isRequired: true, maxLength: 50),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextFormField(
                  controller: _brideMotherMiddleNameController,
                  label: 'Middle Name',
                  isRequired: false,
                  maxLength: 50,
                  validator: (val) => SacramentalValidators.validateName(val, "Mother's middle name", isRequired: false, maxLength: 50),
                ),
              ),
            ],
          ),
          _buildTextFormField(
            controller: _brideMotherMaidenLastController,
            label: "Mother's Maiden Last Name",
            isRequired: true,
            maxLength: 50,
            validator: (val) => SacramentalValidators.validateName(val, "Mother's maiden last name", isRequired: true, maxLength: 50),
          ),
        ],
      ),
    );
  }

  Widget _buildSection4Sponsors({required bool isWide}) {
    return _buildSectionCard(
      title: '4. Witnesses & Sponsors',
      icon: Icons.people_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Primary Witnesses (Ninong & Ninang)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: _matrimonyBurgundy)),
          const SizedBox(height: 8),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildTextFormField(
                  controller: _sponsor1FirstNameController,
                  label: 'Sponsor 1 First Name',
                  isRequired: true,
                  maxLength: 50,
                  validator: (v) => SacramentalValidators.validateName(v, 'Sponsor 1 first name', isRequired: true, maxLength: 50),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextFormField(
                  controller: _sponsor1MiddleNameController,
                  label: 'Middle Name',
                  isRequired: false,
                  maxLength: 50,
                  validator: (v) => SacramentalValidators.validateName(v, 'Sponsor 1 middle name', isRequired: false, maxLength: 50),
                ),
              ),
            ],
          ),
          _buildTextFormField(
            controller: _sponsor1LastNameController,
            label: 'Sponsor 1 Last Name',
            isRequired: true,
            maxLength: 50,
            validator: (v) => SacramentalValidators.validateName(v, 'Sponsor 1 last name', isRequired: true, maxLength: 50),
          ),

          const Divider(height: 24),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildTextFormField(
                  controller: _sponsor2FirstNameController,
                  label: 'Sponsor 2 First Name',
                  isRequired: true,
                  maxLength: 50,
                  validator: (v) => SacramentalValidators.validateName(v, 'Sponsor 2 first name', isRequired: true, maxLength: 50),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextFormField(
                  controller: _sponsor2MiddleNameController,
                  label: 'Middle Name',
                  isRequired: false,
                  maxLength: 50,
                  validator: (v) => SacramentalValidators.validateName(v, 'Sponsor 2 middle name', isRequired: false, maxLength: 50),
                ),
              ),
            ],
          ),
          _buildTextFormField(
            controller: _sponsor2LastNameController,
            label: 'Sponsor 2 Last Name',
            isRequired: true,
            maxLength: 50,
            validator: (v) => SacramentalValidators.validateName(v, 'Sponsor 2 last name', isRequired: true, maxLength: 50),
          ),

          const Divider(height: 26),

          Text('Additional Secondary Sponsors / Witnesses', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: ParishColors.textDark)),
          SizedBox(height: 4),
          Text(
            'Click "[+] Add Witness" to add additional secondary sponsor names individually.',
            style: TextStyle(fontSize: 13, color: ParishColors.textMuted),
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
                      maxLength: 60,
                      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                      style: const TextStyle(fontSize: 14.5),
                      decoration: InputDecoration(
                        labelText: 'Witness #${idx + 1} Full Name',
                        filled: true,
                        fillColor: ParishColors.backgroundLight,
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      validator: (val) => SacramentalValidators.validateName(val, 'Witness #${idx + 1}', isRequired: false, maxLength: 60),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.remove_circle_outline, color: ParishColors.mercyRed),
                    onPressed: () => _removeOtherSponsorField(idx),
                    tooltip: 'Remove Witness',
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
                side: const BorderSide(color: _matrimonyBurgundy, width: 1.5),
                foregroundColor: _matrimonyBurgundy,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _addOtherSponsorField,
              icon: const Icon(Icons.add_circle_outline, size: 20),
              label: const Text('Add Witness', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection5Ceremony({required bool isWide}) {
    return _buildSectionCard(
      title: '5. Ceremony, Legal Details & Officiating Priest',
      icon: Icons.church,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildDatePickerField(
                  label: 'Date of Marriage',
                  isRequired: true,
                  value: _dateOfMarriage,
                  hasError: _dateOfMarriageHasError,
                  onTap: () => _selectDate(context, 3),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDropdownField(
                  label: 'Marriage Type',
                  isRequired: true,
                  value: _marriageType,
                  items: const ['Between Catholics', 'Mixed Marriage', 'Disparity of Cults'],
                  onChanged: (val) => setState(() => _marriageType = val!),
                ),
              ),
            ],
          ),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeColor: _matrimonyBurgundy,
            title: const Text('Filipino / Foreigner Status', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
            value: _isFilipinoForeigner,
            onChanged: (val) => setState(() => _isFilipinoForeigner = val),
          ),

          const Divider(height: 24),
          const Text('Civil Marriage License Compliance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _matrimonyBurgundy)),
          const SizedBox(height: 10),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildTextFormField(
                  controller: _marriageLicenseNoController,
                  label: 'Marriage License No. (Optional)',
                  isRequired: false,
                  maxLength: 50,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDatePickerField(
                  label: 'License Date Registered',
                  isRequired: false,
                  value: _licenseDateRegistered,
                  hasError: false,
                  onTap: () => _selectDate(context, 4),
                ),
              ),
            ],
          ),
          _buildTextFormField(
            controller: _licensePlaceIssuedController,
            label: 'Place Issued',
            isRequired: false,
            maxLength: 100,
            validator: (v) => SacramentalValidators.validatePlace(v, 'Place issued', isRequired: false, maxLength: 100),
          ),

          const Divider(height: 24),
          const Text('Solemnizing Priest & CRASM Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _matrimonyBurgundy)),
          const SizedBox(height: 10),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _buildTextFormField(
                  controller: _solemnizerFirstNameController,
                  label: 'Priest First Name',
                  isRequired: true,
                  maxLength: 50,
                  validator: (v) => SacramentalValidators.validateName(v, 'Priest first name', isRequired: true, maxLength: 50),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _buildTextFormField(
                  controller: _solemnizerMiddleNameController,
                  label: 'Middle Name',
                  isRequired: false,
                  maxLength: 50,
                  validator: (v) => SacramentalValidators.validateName(v, 'Priest middle name', isRequired: false, maxLength: 50),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: _buildTextFormField(
                  controller: _solemnizerLastNameController,
                  label: 'Priest Last Name',
                  isRequired: true,
                  maxLength: 50,
                  validator: (v) => SacramentalValidators.validateName(v, 'Priest last name', isRequired: true, maxLength: 50),
                ),
              ),
            ],
          ),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildTextFormField(
                  controller: _crasmNumberController,
                  label: 'CRASM Number (Optional)',
                  isRequired: false,
                  maxLength: 50,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDatePickerField(
                  label: 'CRASM Validity Date',
                  isRequired: false,
                  value: _crasmValidityDate,
                  hasError: false,
                  onTap: () => _selectDate(context, 5),
                ),
              ),
            ],
          ),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: isWide ? 4 : 1,
                child: _buildTextFormField(
                  controller: _parishNameController,
                  label: 'Parish Name',
                  isRequired: true,
                  maxLength: 150,
                  validator: (v) => SacramentalValidators.validatePlace(v, 'Parish name', isRequired: true, maxLength: 150),
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
                  accentColor: _matrimonyBurgundy,
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
                    : (isEditMode ? _matrimonyBurgundy : ParishColors.oliveGreen),
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
                isEditMode ? 'Update Matrimony' : 'Save Matrimony',
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
              Icon(icon, size: 22, color: _matrimonyBurgundy),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.bold,
                    color: _matrimonyBurgundy,
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
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
                borderSide: BorderSide(color: _matrimonyBurgundy, width: 1.8),
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
                  const Icon(
                    Icons.calendar_month,
                    size: 22,
                    color: _matrimonyBurgundy,
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
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
                borderSide: BorderSide(color: _matrimonyBurgundy, width: 1.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
