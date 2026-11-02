// =============================================================================
// FILE: lib/features/sacramental_records/presentation/pages/conversion_manual_entry_page.dart
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/colors.dart';
import '../../../auth/services/auth_service.dart';
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

  // Floating Back to Top state & micro-interactions
  bool _showBackToTop = false;
  bool _isBackToTopHovered = false;

  bool get isEditMode => widget.initialData != null;

  // Olive Green Theme Accent for Conversion & Reception records
  static const Color _conversionOlive = Color(0xFF2D6A4F);

  // Options for Prior Non-Catholic Baptism
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

  // 1. Canonical Coordinates & Date
  final _bookNumberController = TextEditingController();
  final _pageNumberController = TextEditingController();
  final _lineNumberController = TextEditingController();
  DateTime? _dateOfReception = DateTime.now();

  // Live Duplicate Checker State
  Timer? _coordinateDebounce;
  bool _isCheckingCoordinateDuplicate = false;
  String? _coordinateDuplicateError;

  // 2. Convert Identity & Prior Baptism
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

  // 3. Parents & Religious Affiliation
  final _fatherFirstNameController = TextEditingController();
  final _fatherMiddleNameController = TextEditingController();
  final _fatherLastNameController = TextEditingController();
  final _fatherReligionController = TextEditingController();

  final _motherFirstNameController = TextEditingController();
  final _motherMiddleNameController = TextEditingController();
  final _motherMaidenLastNameController = TextEditingController();
  final _motherReligionController = TextEditingController();

  // 4. Witnesses, Offering & Minister
  final _witness1FirstNameController = TextEditingController();
  final _witness1MiddleNameController = TextEditingController();
  final _witness1LastNameController = TextEditingController();

  final _witness2FirstNameController = TextEditingController();
  final _witness2MiddleNameController = TextEditingController();
  final _witness2LastNameController = TextEditingController();

  final _stipendController = TextEditingController();
  final _ministerFirstNameController = TextEditingController(text: 'Roy');
  final _ministerMiddleNameController = TextEditingController();
  final _ministerLastNameController = TextEditingController(text: 'Reyes');
  final _parishNameController = TextEditingController(text: 'St. John Paul II Parish');
  final _remarksController = TextEditingController();
  String? _existingCanonicalNotes;

  bool _isSubmitting = false;
  String? _errorMessage;
  bool _dateOfReceptionHasError = false;
  bool _dateOfBirthHasError = false;

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
    _dateOfReception = DateTime.tryParse(data['date_of_reception']?.toString() ?? '');
    _existingCanonicalNotes = data['canonical_notes']?.toString();

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
      tableName: 'conversion_records',
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
      initialDate: initialDate.isAfter(now) ? now : initialDate,
      firstDate: DateTime(1900),
      lastDate: now,
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
    if (_dateOfReception == null) {
      setState(() {
        _dateOfReceptionHasError = true;
        _errorMessage = 'Date of Reception into Full Communion is required.';
      });
      _scrollToTop();
      return false;
    }
    final notFutureDate = SacramentalValidators.validateNotFutureDate(_dateOfReception, 'Date of Reception');
    if (notFutureDate != null) {
      setState(() => _errorMessage = notFutureDate);
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

    final receptionError = SacramentalValidators.validateReceptionDate(_dateOfReception, _dateOfBirth);
    if (receptionError != null) {
      setState(() => _errorMessage = receptionError);
      _scrollToTop();
      return false;
    }

    final priorBaptismError = SacramentalValidators.validatePriorBaptismDate(_priorBaptismDate, _dateOfBirth);
    if (priorBaptismError != null) {
      setState(() => _errorMessage = priorBaptismError);
      _scrollToTop();
      return false;
    }

    if (_priorBaptismChurch == 'Others (Specify)' && _priorBaptismChurchOtherController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please specify the prior church / denomination.');
      _scrollToTop();
      return false;
    }

    return true;
  }

  /// Computes strict dynamic diff, excluding unchanged fields and audit metadata
  String _computeChangesSummaryJson(Map<String, dynamic> oldData, Map<String, dynamic> newData) {
    final diffs = <String, Map<String, dynamic>>{};

    final Map<String, String> fieldLabels = {
      'book_number': 'Book No.',
      'page_number': 'Page No.',
      'line_number': 'Line No.',
      'date_of_reception': 'Date of Reception',
      'convert_first_name': 'Candidate First Name',
      'convert_middle_name': 'Candidate Middle Name',
      'convert_last_name': 'Candidate Last Name',
      'convert_suffix': 'Candidate Suffix',
      'date_of_birth': 'Date of Birth',
      'place_of_birth': 'Place of Birth',
      'prior_baptism_date': 'Prior Baptism Date',
      'prior_baptism_church': 'Prior Church / Denomination',
      'prior_baptism_place': 'Prior Congregation Place',
      'father_first_name': 'Father First Name',
      'father_middle_name': 'Father Middle Name',
      'father_last_name': 'Father Last Name',
      'father_religion': 'Father Religion',
      'mother_first_name': 'Mother First Name',
      'mother_middle_name': 'Mother Middle Name',
      'mother_maiden_last_name': 'Mother Maiden Last Name',
      'mother_religion': 'Mother Religion',
      'witness_1_first_name': 'Witness 1 First Name',
      'witness_1_middle_name': 'Witness 1 Middle Name',
      'witness_1_last_name': 'Witness 1 Last Name',
      'witness_2_first_name': 'Witness 2 First Name',
      'witness_2_middle_name': 'Witness 2 Middle Name',
      'witness_2_last_name': 'Witness 2 Last Name',
      'stipend': 'Stipend / Offering',
      'minister_first_name': 'Priest First Name',
      'minister_middle_name': 'Priest Middle Name',
      'minister_last_name': 'Priest Last Name',
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

  /// Verification & Review confirmation dialog before saving a new Conversion record
  Future<void> _promptSaveConfirmation() async {
    if (!_validateAllFields()) return;

    final candidateName = [
      _convertFirstNameController.text.trim(),
      _convertMiddleNameController.text.trim(),
      _convertLastNameController.text.trim(),
      _convertSuffixController.text.trim(),
    ].where((s) => s.isNotEmpty).join(' ');

    final fatherName = [
      _fatherFirstNameController.text.trim(),
      _fatherMiddleNameController.text.trim(),
      _fatherLastNameController.text.trim(),
    ].where((s) => s.isNotEmpty).join(' ');

    final motherName = [
      _motherFirstNameController.text.trim(),
      _motherMiddleNameController.text.trim(),
      _motherMaidenLastNameController.text.trim(),
    ].where((s) => s.isNotEmpty).join(' ');

    final witness1Name = [
      _witness1FirstNameController.text.trim(),
      _witness1MiddleNameController.text.trim(),
      _witness1LastNameController.text.trim(),
    ].where((s) => s.isNotEmpty).join(' ');

    final witness2Name = [
      _witness2FirstNameController.text.trim(),
      _witness2MiddleNameController.text.trim(),
      _witness2LastNameController.text.trim(),
    ].where((s) => s.isNotEmpty).join(' ');

    final priestName = [
      'Rev. Fr.',
      _ministerFirstNameController.text.trim(),
      _ministerMiddleNameController.text.trim(),
      _ministerLastNameController.text.trim(),
    ].where((s) => s.isNotEmpty).join(' ');

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
                color: _conversionOlive.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.fact_check_outlined, color: _conversionOlive, size: 24),
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
                    'Verify all fields before saving into Liber Conversorum.',
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
                  _buildReviewRow('Date of Reception:', _dateOfReception?.toIso8601String().substring(0, 10) ?? '—'),
                ]),
                const SizedBox(height: 12),
                _buildReviewSection('2. Person Received into Full Communion', [
                  _buildReviewRow('Full Name:', candidateName),
                  _buildReviewRow('Date of Birth:', _dateOfBirth?.toIso8601String().substring(0, 10) ?? '—'),
                  _buildReviewRow('Place of Birth:', _placeOfBirthController.text.trim()),
                  _buildReviewRow('Prior Church:', _priorBaptismChurch == 'Others (Specify)' ? _priorBaptismChurchOtherController.text.trim() : _priorBaptismChurch),
                  if (_priorBaptismDate != null)
                    _buildReviewRow('Prior Baptism Date:', _priorBaptismDate!.toIso8601String().substring(0, 10)),
                  if (_priorBaptismPlaceController.text.trim().isNotEmpty)
                    _buildReviewRow('Prior Congregation:', _priorBaptismPlaceController.text.trim()),
                ]),
                const SizedBox(height: 12),
                _buildReviewSection('3. Parents & Religious Background (Optional)', [
                  _buildReviewRow('Father:', fatherName.isNotEmpty ? fatherName : 'Not Specified'),
                  if (_fatherReligionController.text.trim().isNotEmpty)
                    _buildReviewRow('Father Religion:', _fatherReligionController.text.trim()),
                  _buildReviewRow('Mother Maiden Name:', motherName.isNotEmpty ? motherName : 'Not Specified'),
                  if (_motherReligionController.text.trim().isNotEmpty)
                    _buildReviewRow('Mother Religion:', _motherReligionController.text.trim()),
                ]),
                const SizedBox(height: 12),
                _buildReviewSection('4. Witnesses, Offering & Priest', [
                  _buildReviewRow('Witness 1 (Required):', witness1Name),
                  if (witness2Name.isNotEmpty)
                    _buildReviewRow('Witness 2 (Optional):', witness2Name),
                  _buildReviewRow('Officiating Priest:', priestName),
                  _buildReviewRow('Parish Name:', _parishNameController.text.trim()),
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
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: _conversionOlive,
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
            width: 150,
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

    final reasonController = TextEditingController(text: 'Correction of reception details');

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
                color: _conversionOlive.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.security_update_good, color: _conversionOlive, size: 24),
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
                'You are modifying canonical entry ${widget.initialData!['record_id']} (${_convertFirstNameController.text.trim()} ${_convertLastNameController.text.trim()}).',
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
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _conversionOlive),
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
                  hintText: 'e.g. Typographical error correction on candidate name or denomination',
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
        final recordId = widget.initialData!['record_id'].toString();

        final changesJson = _computeChangesSummaryJson(widget.initialData!, recordMap);

        await ConversionService.updateConversionRecord(recordId, recordMap);

        if (changesJson.isNotEmpty) {
          try {
            await Supabase.instance.client.from('sacramental_record_audit_logs').insert({
              'log_id': 'LOG-${now.millisecondsSinceEpoch}',
              'record_id': recordId,
              'sacrament_type': 'Conversion',
              'action_type': 'UPDATED',
              'recipient_name': '${_convertFirstNameController.text.trim()} ${_convertLastNameController.text.trim()}',
              'book_number': _bookNumberController.text.trim(),
              'page_number': _pageNumberController.text.trim(),
              'line_number': _lineNumberController.text.trim(),
              'performed_by_id': currentUserId,
              'performed_by_name': currentUserName,
              'performed_by_role': currentUser?.userRole ?? 'Secretary',
              'justification': reasonForCorrection ?? 'Correction of reception details',
              'changes_summary': changesJson,
              'created_at': now.toIso8601String(),
            });
          } catch (auditErr) {
            debugPrint('[ConversionManualEntryPage] Audit log insertion notice: $auditErr');
          }
        }
      } else {
        final insertedRecord = await ConversionService.insertManualConversionRecord(recordMap);

        try {
          await Supabase.instance.client.from('sacramental_record_audit_logs').insert({
            'log_id': 'LOG-${now.millisecondsSinceEpoch}',
            'record_id': insertedRecord.recordId,
            'sacrament_type': 'Conversion',
            'action_type': 'CREATED',
            'recipient_name': insertedRecord.convertFullName,
            'book_number': insertedRecord.bookNumber,
            'page_number': insertedRecord.pageNumber,
            'line_number': insertedRecord.lineNumber,
            'performed_by_id': currentUserId,
            'performed_by_name': currentUserName,
            'performed_by_role': currentUser?.userRole ?? 'Secretary',
            'justification': 'Initial reception into full communion registry entry',
            'changes_summary': '',
            'created_at': now.toIso8601String(),
          });
        } catch (auditErr) {
          debugPrint('[ConversionManualEntryPage] Audit log insertion notice: $auditErr');
        }
      }

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditMode
              ? 'Conversion record updated and logged successfully in Liber Conversorum.'
              : 'Conversion record registered successfully in Liber Conversorum.'),
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
                    ? 'Editing Record: ${widget.initialData!['record_id']}'
                    : 'Canonical Registry Book (Liber Conversorum)',
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
                      backgroundColor: _conversionOlive,
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
                              _buildSection2Convert(isWide: isWide),
                              const SizedBox(height: 16),
                              _buildSection3Parents(isWide: isWide),
                              const SizedBox(height: 16),
                              _buildSection4Witnesses(isWide: isWide),
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
              color: _conversionOlive,
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
                      'CONVERSION REGISTER',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _conversionOlive,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _conversionOlive.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Canonical Step',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _conversionOlive,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Full Communion Reception Entry',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: ParishColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Record candidate particulars, prior Christian baptism credentials, and official witnesses.',
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
                color: _conversionOlive.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _conversionOlive.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock, size: 16, color: _conversionOlive),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Book, Page, and Line coordinates are permanent physical coordinates and cannot be altered.',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _conversionOlive),
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
                  const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.8, color: _conversionOlive)),
                  const SizedBox(width: 8),
                  Text('Checking physical conversion register...', style: TextStyle(fontSize: 11, color: ParishColors.textMuted)),
                ],
              ),
            ),

          _buildDatePickerField(
            label: 'Date of Reception into Full Communion',
            isRequired: true,
            value: _dateOfReception,
            hasError: _dateOfReceptionHasError,
            onTap: () => _selectDate(context, 0),
          ),
        ],
      ),
    );
  }

  Widget _buildSection2Convert({required bool isWide}) {
    return _buildSectionCard(
      title: '2. Person Received & Prior Baptism Credentials',
      icon: Icons.person,
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
                    controller: _convertFirstNameController,
                    label: 'First Name',
                    isRequired: true,
                    maxLength: 50,
                    validator: (v) => SacramentalValidators.validateName(v, 'First name', isRequired: true, maxLength: 50),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _buildTextFormField(
                    controller: _convertMiddleNameController,
                    label: 'Middle Name',
                    isRequired: false,
                    maxLength: 50,
                    validator: (v) => SacramentalValidators.validateName(v, 'Middle name', isRequired: false, maxLength: 50),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: _buildTextFormField(
                    controller: _convertLastNameController,
                    label: 'Last Name',
                    isRequired: true,
                    maxLength: 50,
                    validator: (v) => SacramentalValidators.validateName(v, 'Last name', isRequired: true, maxLength: 50),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: _buildTextFormField(
                    controller: _convertSuffixController,
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
                    controller: _convertFirstNameController,
                    label: 'First Name',
                    isRequired: true,
                    maxLength: 50,
                    validator: (v) => SacramentalValidators.validateName(v, 'First name', isRequired: true, maxLength: 50),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: _buildTextFormField(
                    controller: _convertMiddleNameController,
                    label: 'Middle Name',
                    isRequired: false,
                    maxLength: 50,
                    validator: (v) => SacramentalValidators.validateName(v, 'Middle name', isRequired: false, maxLength: 50),
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
                    controller: _convertLastNameController,
                    label: 'Last Name',
                    isRequired: true,
                    maxLength: 50,
                    validator: (v) => SacramentalValidators.validateName(v, 'Last name', isRequired: true, maxLength: 50),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: _buildTextFormField(
                    controller: _convertSuffixController,
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
                flex: isWide ? 4 : 1,
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
                flex: isWide ? 6 : 1,
                child: _buildTextFormField(
                  controller: _placeOfBirthController,
                  label: 'Place of Birth',
                  isRequired: true,
                  maxLength: 100,
                  validator: (v) => SacramentalValidators.validatePlace(v, 'Place of birth', isRequired: true, maxLength: 100),
                ),
              ),
            ],
          ),

          const Divider(height: 24),
          const Text('Prior Non-Catholic Baptism Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _conversionOlive)),
          const SizedBox(height: 8),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: isWide ? 4 : 1,
                child: _buildDatePickerField(
                  label: 'Prior Baptism Date (Optional)',
                  isRequired: false,
                  value: _priorBaptismDate,
                  hasError: false,
                  onTap: () => _selectDate(context, 2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: isWide ? 6 : 1,
                child: _buildDropdownField(
                  label: 'Prior Christian Church / Denomination',
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
              ),
            ],
          ),

          if (_priorBaptismChurch == 'Others (Specify)') ...[
            _buildTextFormField(
              controller: _priorBaptismChurchOtherController,
              label: 'Specify Prior Church / Denomination',
              isRequired: true,
              maxLength: 100,
              validator: (v) {
                if (_priorBaptismChurch == 'Others (Specify)' && (v == null || v.trim().isEmpty)) {
                  return 'Please specify the prior church / denomination.';
                }
                return SacramentalValidators.validatePlace(v, 'Prior church / denomination', isRequired: true, maxLength: 100);
              },
            ),
          ],

          _buildTextFormField(
            controller: _priorBaptismPlaceController,
            label: 'Prior Congregation Municipality / Address',
            isRequired: false,
            maxLength: 150,
            validator: (v) => SacramentalValidators.validatePlace(v, 'Congregation location', isRequired: false, maxLength: 150),
          ),
        ],
      ),
    );
  }

  Widget _buildSection3Parents({required bool isWide}) {
    return _buildSectionCard(
      title: "3. Parents & Religious Affiliation (Optional)",
      icon: Icons.people_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Father's Particulars", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _conversionOlive)),
          const SizedBox(height: 8),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildTextFormField(
                  controller: _fatherFirstNameController,
                  label: "Father's First Name",
                  isRequired: false,
                  maxLength: 50,
                  validator: (v) => SacramentalValidators.validateName(v, "Father's first name", isRequired: false, maxLength: 50),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextFormField(
                  controller: _fatherMiddleNameController,
                  label: "Middle Name",
                  isRequired: false,
                  maxLength: 50,
                  validator: (v) => SacramentalValidators.validateName(v, "Father's middle name", isRequired: false, maxLength: 50),
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
                  label: "Father's Last Name",
                  isRequired: false,
                  maxLength: 50,
                  validator: (v) => SacramentalValidators.validateName(v, "Father's last name", isRequired: false, maxLength: 50),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextFormField(
                  controller: _fatherReligionController,
                  label: "Father's Religion (e.g. Catholic, Methodist)",
                  isRequired: false,
                  maxLength: 50,
                  validator: (v) => SacramentalValidators.validatePlace(v, "Father's religion", isRequired: false, maxLength: 50),
                ),
              ),
            ],
          ),

          const Divider(height: 24),
          const Text("Mother's Particulars", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _conversionOlive)),
          const SizedBox(height: 8),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildTextFormField(
                  controller: _motherFirstNameController,
                  label: "Mother's First Name",
                  isRequired: false,
                  maxLength: 50,
                  validator: (v) => SacramentalValidators.validateName(v, "Mother's first name", isRequired: false, maxLength: 50),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextFormField(
                  controller: _motherMiddleNameController,
                  label: "Middle Name",
                  isRequired: false,
                  maxLength: 50,
                  validator: (v) => SacramentalValidators.validateName(v, "Mother's middle name", isRequired: false, maxLength: 50),
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
                  label: "Mother's Maiden Last Name",
                  isRequired: false,
                  maxLength: 50,
                  validator: (v) => SacramentalValidators.validateName(v, "Mother's maiden last name", isRequired: false, maxLength: 50),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextFormField(
                  controller: _motherReligionController,
                  label: "Mother's Religion",
                  isRequired: false,
                  maxLength: 50,
                  validator: (v) => SacramentalValidators.validatePlace(v, "Mother's religion", isRequired: false, maxLength: 50),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection4Witnesses({required bool isWide}) {
    return _buildSectionCard(
      title: '4. Witnesses, Officiating Priest & Offering',
      icon: Icons.church,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Primary Witness (Required)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: _conversionOlive)),
          const SizedBox(height: 8),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildTextFormField(
                  controller: _witness1FirstNameController,
                  label: 'Witness 1 First Name',
                  isRequired: true,
                  maxLength: 50,
                  validator: (v) => SacramentalValidators.validateName(v, 'Witness 1 first name', isRequired: true, maxLength: 50),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextFormField(
                  controller: _witness1MiddleNameController,
                  label: 'Middle Name',
                  isRequired: false,
                  maxLength: 50,
                  validator: (v) => SacramentalValidators.validateName(v, 'Witness 1 middle name', isRequired: false, maxLength: 50),
                ),
              ),
            ],
          ),
          _buildTextFormField(
            controller: _witness1LastNameController,
            label: 'Witness 1 Last Name',
            isRequired: true,
            maxLength: 50,
            validator: (v) => SacramentalValidators.validateName(v, 'Witness 1 last name', isRequired: true, maxLength: 50),
          ),

          const Divider(height: 24),
          const Text('Secondary Witness (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: _conversionOlive)),
          const SizedBox(height: 8),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildTextFormField(
                  controller: _witness2FirstNameController,
                  label: 'Witness 2 First Name',
                  isRequired: false,
                  maxLength: 50,
                  validator: (v) => SacramentalValidators.validateName(v, 'Witness 2 first name', isRequired: false, maxLength: 50),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextFormField(
                  controller: _witness2MiddleNameController,
                  label: 'Middle Name',
                  isRequired: false,
                  maxLength: 50,
                  validator: (v) => SacramentalValidators.validateName(v, 'Witness 2 middle name', isRequired: false, maxLength: 50),
                ),
              ),
            ],
          ),
          _buildTextFormField(
            controller: _witness2LastNameController,
            label: 'Witness 2 Last Name',
            isRequired: false,
            maxLength: 50,
            validator: (v) => SacramentalValidators.validateName(v, 'Witness 2 last name', isRequired: false, maxLength: 50),
          ),

          const Divider(height: 24),
          _buildTextFormField(
            controller: _stipendController,
            label: 'Stipend (₱)',
            isRequired: false,
            maxLength: 12,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: SacramentalValidators.validateStipend,
          ),

          const Divider(height: 24),
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
                  validator: (v) => SacramentalValidators.validateName(v, 'Minister first name', isRequired: true, maxLength: 50),
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
                  validator: (v) => SacramentalValidators.validateName(v, 'Minister middle name', isRequired: false, maxLength: 50),
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
                  validator: (v) => SacramentalValidators.validateName(v, 'Minister last name', isRequired: true, maxLength: 50),
                ),
              ),
            ],
          ),

          _buildTextFormField(
            controller: _parishNameController,
            label: 'Parish Name',
            isRequired: true,
            maxLength: 150,
            validator: (v) => SacramentalValidators.validatePlace(v, 'Parish name', isRequired: true, maxLength: 150),
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
                  accentColor: _conversionOlive,
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
                    : (isEditMode ? _conversionOlive : ParishColors.oliveGreen),
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
                isEditMode ? 'Update Conversion' : 'Save Conversion',
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
              Icon(icon, size: 22, color: _conversionOlive),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.bold,
                    color: _conversionOlive,
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
                borderSide: BorderSide(color: _conversionOlive, width: 1.8),
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
                    color: _conversionOlive,
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
            isExpanded: true,
            items: items.map((item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(
                  item,
                  style: TextStyle(fontSize: 14, color: ParishColors.textDark),
                  overflow: TextOverflow.ellipsis,
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
                borderSide: BorderSide(color: _conversionOlive, width: 1.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}