// =============================================================================
// FILE: lib/features/sacramental_records/presentation/pages/confirmation_manual_entry_page.dart
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/colors.dart';
import '../../../auth/services/auth_service.dart';
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

  // Floating Back to Top state & micro-interactions
  bool _showBackToTop = false;
  bool _isBackToTopHovered = false;

  bool get isEditMode => widget.initialData != null;

  // Pentecost Theme Accent for Confirmation
  static const Color _pentecostRed = Color(0xFFB91C1C);

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

  // 2. Confirmand's Personal Information
  final _confirmandFirstNameController = TextEditingController();
  final _confirmandMiddleNameController = TextEditingController();
  final _confirmandLastNameController = TextEditingController();
  final _confirmandSuffixController = TextEditingController();
  DateTime? _dateOfBirth;
  final _ageController = TextEditingController();
  DateTime? _dateOfBaptism;
  final _churchBaptizedController = TextEditingController(text: 'St. John Paul II Parish');
  final _addressController = TextEditingController();

  // 3. Father Information
  bool _fatherNotIndicated = false;
  final _fatherFirstNameController = TextEditingController();
  final _fatherMiddleNameController = TextEditingController();
  final _fatherLastNameController = TextEditingController();
  final _fatherOriginController = TextEditingController();

  // 4. Mother Information
  final _motherFirstNameController = TextEditingController();
  final _motherMiddleNameController = TextEditingController();
  final _motherMaidenLastNameController = TextEditingController();
  final _motherOriginController = TextEditingController();

  // 5. Sponsors
  final _sponsor1FirstNameController = TextEditingController();
  final _sponsor1MiddleNameController = TextEditingController();
  final _sponsor1LastNameController = TextEditingController();
  final _sponsor1OriginAddressController = TextEditingController();

  final _sponsor2FirstNameController = TextEditingController();
  final _sponsor2MiddleNameController = TextEditingController();
  final _sponsor2LastNameController = TextEditingController();
  final _sponsor2OriginAddressController = TextEditingController();

  // 6. Administration Details
  DateTime? _dateOfConfirmation = DateTime.now();
  final _stipendController = TextEditingController();
  final _ministerFirstNameController = TextEditingController(text: 'Roy');
  final _ministerMiddleNameController = TextEditingController();
  final _ministerLastNameController = TextEditingController(text: 'Reyes');
  final _parishNameController = TextEditingController(text: 'St. John Paul II Parish');
  final _remarksController = TextEditingController();
  String? _existingCanonicalNotes;

  bool _isSubmitting = false;
  String? _errorMessage;
  bool _dateOfBaptismHasError = false;
  bool _dateOfConfirmationHasError = false;

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

    if (_dateOfBirth != null) {
      _recomputeAge();
    }
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
      tableName: 'confirmation_records',
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

  void _recomputeAge() {
    if (_dateOfBirth != null && _dateOfConfirmation != null) {
      final years = SacramentalValidators.calculateAgeInYears(
        _dateOfBirth!,
        _dateOfConfirmation!,
      );
      _ageController.text = '$years';
    }
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
      lastDate: now,
    );

    if (picked != null) {
      setState(() {
        if (dateType == 0) {
          _registryDate = picked;
        } else if (dateType == 1) {
          _dateOfBirth = picked;
          _recomputeAge();
        } else if (dateType == 2) {
          _dateOfBaptism = picked;
          _dateOfBaptismHasError = false;
        } else {
          _dateOfConfirmation = picked;
          _dateOfConfirmationHasError = false;
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
        _fatherOriginController.clear();
      } else {
        _fatherFirstNameController.clear();
        _fatherMiddleNameController.clear();
        _fatherLastNameController.clear();
        _fatherOriginController.clear();
      }
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

    final dobError = SacramentalValidators.validateDateOfBirth(_dateOfBirth, isRequired: false);
    if (dobError != null) {
      setState(() => _errorMessage = dobError);
      _scrollToTop();
      return false;
    }

    if (_dateOfBaptism == null) {
      setState(() {
        _dateOfBaptismHasError = true;
        _errorMessage = 'Date of Baptism is required.';
      });
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

    final confError = SacramentalValidators.validateConfirmationDate(_dateOfConfirmation, _dateOfBaptism);
    if (confError != null) {
      setState(() {
        _dateOfConfirmationHasError = true;
        _errorMessage = confError;
      });
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
      'confirmand_first_name': 'Confirmand First Name',
      'confirmand_middle_name': 'Confirmand Middle Name',
      'confirmand_last_name': 'Confirmand Last Name',
      'confirmand_suffix': 'Confirmand Suffix',
      'date_of_birth': 'Date of Birth',
      'age': 'Age',
      'date_of_baptism': 'Date of Baptism',
      'church_baptized': 'Church where Baptized',
      'address': 'Address / Residence',
      'father_first_name': 'Father First Name',
      'father_middle_name': 'Father Middle Name',
      'father_last_name': 'Father Last Name',
      'father_origin': 'Father Birthplace',
      'mother_first_name': 'Mother First Name',
      'mother_middle_name': 'Mother Middle Name',
      'mother_maiden_last_name': 'Mother Maiden Last Name',
      'mother_origin': 'Mother Birthplace',
      'sponsor_1_first_name': 'Sponsor 1 First Name',
      'sponsor_1_middle_name': 'Sponsor 1 Middle Name',
      'sponsor_1_last_name': 'Sponsor 1 Last Name',
      'sponsor_1_origin_address': 'Sponsor 1 Address',
      'sponsor_2_first_name': 'Sponsor 2 First Name',
      'sponsor_2_middle_name': 'Sponsor 2 Middle Name',
      'sponsor_2_last_name': 'Sponsor 2 Last Name',
      'sponsor_2_origin_address': 'Sponsor 2 Address',
      'date_of_confirmation': 'Date of Confirmation',
      'stipend': 'Stipend',
      'minister_first_name': 'Priest / Bishop First Name',
      'minister_middle_name': 'Priest / Bishop Middle Name',
      'minister_last_name': 'Priest / Bishop Last Name',
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

  /// Verification & Review confirmation dialog before saving a new Confirmation record
  Future<void> _promptSaveConfirmation() async {
    if (!_validateAllFields()) return;

    final confirmandName = [
      _confirmandFirstNameController.text.trim(),
      _confirmandMiddleNameController.text.trim(),
      _confirmandLastNameController.text.trim(),
      _confirmandSuffixController.text.trim(),
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
                color: _pentecostRed.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.fact_check_outlined, color: _pentecostRed, size: 24),
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
                    'Verify all fields before saving into Liber Confirmatorum.',
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
                _buildReviewSection("2. Confirmand's Information", [
                  _buildReviewRow('Full Name:', confirmandName),
                  _buildReviewRow('Date of Birth:', _dateOfBirth?.toIso8601String().substring(0, 10) ?? 'Not Specified'),
                  _buildReviewRow('Age at Confirmation:', _ageController.text.trim().isNotEmpty ? _ageController.text.trim() : '—'),
                  _buildReviewRow('Date of Baptism:', _dateOfBaptism?.toIso8601String().substring(0, 10) ?? '—'),
                  _buildReviewRow('Church where Baptized:', _churchBaptizedController.text.trim()),
                  if (_addressController.text.trim().isNotEmpty)
                    _buildReviewRow('Address / Residence:', _addressController.text.trim()),
                ]),
                const SizedBox(height: 12),
                _buildReviewSection('3. Parents & Lineage', [
                  _buildReviewRow('Father:', fatherName),
                  if (!_fatherNotIndicated && _fatherOriginController.text.trim().isNotEmpty)
                    _buildReviewRow('Father Birthplace:', _fatherOriginController.text.trim()),
                  _buildReviewRow('Mother Maiden Name:', motherName),
                  if (_motherOriginController.text.trim().isNotEmpty)
                    _buildReviewRow('Mother Birthplace:', _motherOriginController.text.trim()),
                ]),
                const SizedBox(height: 12),
                _buildReviewSection('4. Confirmation Sponsors', [
                  _buildReviewRow('Sponsor 1 (Required):', sponsor1Name),
                  if (_sponsor1OriginAddressController.text.trim().isNotEmpty)
                    _buildReviewRow('Sponsor 1 Address:', _sponsor1OriginAddressController.text.trim()),
                  if (sponsor2Name.isNotEmpty)
                    _buildReviewRow('Sponsor 2 (Optional):', sponsor2Name),
                  if (_sponsor2OriginAddressController.text.trim().isNotEmpty)
                    _buildReviewRow('Sponsor 2 Address:', _sponsor2OriginAddressController.text.trim()),
                ]),
                const SizedBox(height: 12),
                _buildReviewSection('5. Confirmation Details & Clergy', [
                  _buildReviewRow('Parish Name:', _parishNameController.text.trim()),
                  _buildReviewRow('Officiating Bishop/Priest:', priestName),
                  _buildReviewRow('Date of Confirmation:', _dateOfConfirmation?.toIso8601String().substring(0, 10) ?? '—'),
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
              color: _pentecostRed,
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
                color: _pentecostRed.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.security_update_good, color: _pentecostRed, size: 24),
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
                'You are modifying canonical entry ${widget.initialData!['record_id']} (${_confirmandFirstNameController.text.trim()} ${_confirmandLastNameController.text.trim()}).',
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
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _pentecostRed),
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
                  hintText: 'e.g. Typographical error correction on confirmand name',
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
      final int parsedAge = int.tryParse(_ageController.text.trim()) ?? 0;
      final double parsedStipend = _stipendController.text.trim().isNotEmpty
          ? (double.tryParse(_stipendController.text.trim()) ?? 0.00)
          : 0.00;

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
        final recordId = widget.initialData!['record_id'].toString();

        final changesJson = _computeChangesSummaryJson(widget.initialData!, recordMap);

        await ConfirmationService.updateConfirmationRecord(recordId, recordMap);

        if (changesJson.isNotEmpty) {
          try {
            await Supabase.instance.client.from('sacramental_record_audit_logs').insert({
              'log_id': 'LOG-${now.millisecondsSinceEpoch}',
              'record_id': recordId,
              'sacrament_type': 'Confirmation',
              'action_type': 'UPDATED',
              'recipient_name': '${_confirmandFirstNameController.text.trim()} ${_confirmandLastNameController.text.trim()}',
              'book_number': _bookNumberController.text.trim(),
              'page_number': _pageNumberController.text.trim(),
              'line_number': _lineNumberController.text.trim(),
              'performed_by_id': currentUserId,
              'performed_by_name': currentUserName,
              'performed_by_role': currentUser?.userRole ?? 'Secretary',
              'justification': reasonForCorrection ?? 'Correction of confirmation details',
              'changes_summary': changesJson,
              'created_at': now.toIso8601String(),
            });
          } catch (auditErr) {
            debugPrint('[ConfirmationManualEntryPage] Audit log insertion notice: $auditErr');
          }
        }
      } else {
        final insertedRecord = await ConfirmationService.insertManualConfirmationRecord(recordMap);

        try {
          await Supabase.instance.client.from('sacramental_record_audit_logs').insert({
            'log_id': 'LOG-${now.millisecondsSinceEpoch}',
            'record_id': insertedRecord.recordId,
            'sacrament_type': 'Confirmation',
            'action_type': 'CREATED',
            'recipient_name': insertedRecord.confirmandFullName,
            'book_number': insertedRecord.bookNumber,
            'page_number': insertedRecord.pageNumber,
            'line_number': insertedRecord.lineNumber,
            'performed_by_id': currentUserId,
            'performed_by_name': currentUserName,
            'performed_by_role': currentUser?.userRole ?? 'Secretary',
            'justification': 'Initial confirmation registry entry',
            'changes_summary': '',
            'created_at': now.toIso8601String(),
          });
        } catch (auditErr) {
          debugPrint('[ConfirmationManualEntryPage] Audit log insertion notice: $auditErr');
        }
      }

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditMode
              ? 'Confirmation record updated and logged successfully.'
              : 'Confirmation record registered successfully.'),
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
                    ? 'Editing Record: ${widget.initialData!['record_id']}'
                    : 'Parish Confirmation Register (Liber Confirmatorum)',
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
                      backgroundColor: _pentecostRed,
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
                              _buildSection2Confirmand(isWide: isWide),
                              const SizedBox(height: 16),
                              _buildSection3Parents(isWide: isWide),
                              const SizedBox(height: 16),
                              _buildSection4Sponsors(isWide: isWide),
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
            decoration: const BoxDecoration(
              color: _pentecostRed,
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
                      'CONFIRMATION REGISTER',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _pentecostRed,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _pentecostRed.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Canonical Step',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _pentecostRed,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Confirmation Record Entry',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: ParishColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Enter all confirmation credentials accurately according to the church registry book.',
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
                color: _pentecostRed.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _pentecostRed.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock, size: 16, color: _pentecostRed),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Book, Page, and Line coordinates are permanent physical coordinates and cannot be altered.',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _pentecostRed),
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
                  const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.8, color: _pentecostRed)),
                  const SizedBox(width: 8),
                  Text('Checking physical confirmation register...', style: TextStyle(fontSize: 11, color: ParishColors.textMuted)),
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

  Widget _buildSection2Confirmand({required bool isWide}) {
    final bool hasBirthIndicated = _dateOfBirth != null;

    return _buildSectionCard(
      title: "2. Confirmand's Information",
      icon: Icons.local_fire_department,
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
                    controller: _confirmandFirstNameController,
                    label: 'First Name',
                    isRequired: true,
                    maxLength: 50,
                    validator: (val) => SacramentalValidators.validateName(val, 'Confirmand first name', isRequired: true, maxLength: 50),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _buildTextFormField(
                    controller: _confirmandMiddleNameController,
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
                    controller: _confirmandLastNameController,
                    label: 'Last Name',
                    isRequired: true,
                    maxLength: 50,
                    validator: (val) => SacramentalValidators.validateName(val, 'Confirmand last name', isRequired: true, maxLength: 50),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: _buildTextFormField(
                    controller: _confirmandSuffixController,
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
                    controller: _confirmandFirstNameController,
                    label: 'First Name',
                    isRequired: true,
                    maxLength: 50,
                    validator: (val) => SacramentalValidators.validateName(val, 'Confirmand first name', isRequired: true, maxLength: 50),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: _buildTextFormField(
                    controller: _confirmandMiddleNameController,
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
                    controller: _confirmandLastNameController,
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
                    controller: _confirmandSuffixController,
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
                  label: 'Date of Birth (Optional)',
                  isRequired: false,
                  value: _dateOfBirth,
                  hasError: false,
                  onTap: () => _selectDate(context, 1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: isWide ? 2 : 1,
                child: _buildTextFormField(
                  controller: _ageController,
                  label: hasBirthIndicated ? 'Age (Calculated)' : 'Age (Enter in Years)',
                  isRequired: !hasBirthIndicated,
                  enabled: !hasBirthIndicated,
                  keyboardType: TextInputType.number,
                  maxLength: 3,
                  validator: (val) => SacramentalValidators.validateWholeNumberAge(val, isRequired: !hasBirthIndicated),
                ),
              ),
              if (isWide) ...[
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
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
                  flex: 4,
                  child: _buildTextFormField(
                    controller: _churchBaptizedController,
                    label: 'Church where Baptized',
                    isRequired: true,
                    maxLength: 150,
                    validator: (val) => SacramentalValidators.validatePlace(val, 'Church where baptized', isRequired: true, maxLength: 150),
                  ),
                ),
              ],
            ],
          ),

          if (!isWide) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
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
                  child: _buildTextFormField(
                    controller: _churchBaptizedController,
                    label: 'Church where Baptized',
                    isRequired: true,
                    maxLength: 150,
                    validator: (val) => SacramentalValidators.validatePlace(val, 'Church where baptized', isRequired: true, maxLength: 150),
                  ),
                ),
              ],
            ),
          ],

          _buildTextFormField(
            controller: _addressController,
            label: 'Address / Residence',
            isRequired: false,
            maxLength: 150,
            validator: (val) => SacramentalValidators.validatePlace(val, 'Address / Residence', isRequired: false, maxLength: 150),
          ),
        ],
      ),
    );
  }

  Widget _buildSection3Parents({required bool isWide}) {
    return _buildSectionCard(
      title: "3. Parents & Lineage",
      icon: Icons.people,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Father's Information", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: _pentecostRed)),
          const SizedBox(height: 8),

          Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: _fatherNotIndicated ? _pentecostRed.withOpacity(0.12) : ParishColors.backgroundLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _fatherNotIndicated ? _pentecostRed : ParishColors.borderGrey,
                width: _fatherNotIndicated ? 1.6 : 1.0,
              ),
            ),
            child: CheckboxListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              activeColor: _pentecostRed,
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
                    controller: _fatherOriginController,
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
                    controller: _fatherOriginController,
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

          const Text("Mother's Information", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: _pentecostRed)),
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
                    controller: _motherOriginController,
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
                    controller: _motherOriginController,
                    label: 'Birthplace / Hometown',
                    isRequired: false,
                    maxLength: 100,
                    validator: (val) => SacramentalValidators.validatePlace(val, "Mother's birthplace", isRequired: false, maxLength: 100),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSection4Sponsors({required bool isWide}) {
    return _buildSectionCard(
      title: '4. Confirmation Sponsors',
      icon: Icons.people_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Confirmation registers limit sponsors to Sponsor 1 (Required) and Sponsor 2 (Optional).',
            style: TextStyle(fontSize: 13, color: _pentecostRed, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          Text('Sponsor 1 (Ninong / Ninang - Required)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: ParishColors.textDark)),
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
                    controller: _sponsor1OriginAddressController,
                    label: 'Residence / Address',
                    isRequired: false,
                    maxLength: 150,
                    validator: (val) => SacramentalValidators.validatePlace(val, 'Sponsor 1 address', isRequired: false, maxLength: 150),
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
                    controller: _sponsor1OriginAddressController,
                    label: 'Residence',
                    isRequired: false,
                    maxLength: 150,
                    validator: (val) => SacramentalValidators.validatePlace(val, 'Sponsor 1 address', isRequired: false, maxLength: 150),
                  ),
                ),
              ],
            ),
          ],

          const Divider(height: 22),

          Text('Sponsor 2 (Ninong / Ninang - Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: ParishColors.textDark)),
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
                    isRequired: false,
                    maxLength: 50,
                    validator: (val) => SacramentalValidators.validateName(val, 'Sponsor 2 first name', isRequired: false, maxLength: 50),
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
                    isRequired: false,
                    maxLength: 50,
                    validator: (val) => SacramentalValidators.validateName(val, 'Sponsor 2 last name', isRequired: false, maxLength: 50),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: _buildTextFormField(
                    controller: _sponsor2OriginAddressController,
                    label: 'Residence / Address',
                    isRequired: false,
                    maxLength: 150,
                    validator: (val) => SacramentalValidators.validatePlace(val, 'Sponsor 2 address', isRequired: false, maxLength: 150),
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
                    isRequired: false,
                    maxLength: 50,
                    validator: (val) => SacramentalValidators.validateName(val, 'Sponsor 2 first name', isRequired: false, maxLength: 50),
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
                    isRequired: false,
                    maxLength: 50,
                    validator: (val) => SacramentalValidators.validateName(val, 'Sponsor 2 last name', isRequired: false, maxLength: 50),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextFormField(
                    controller: _sponsor2OriginAddressController,
                    label: 'Residence',
                    isRequired: false,
                    maxLength: 150,
                    validator: (val) => SacramentalValidators.validatePlace(val, 'Sponsor 2 address', isRequired: false, maxLength: 150),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSection5Administration({required bool isWide}) {
    return _buildSectionCard(
      title: '5. Confirmation Details & Officiating Clergy',
      icon: Icons.church,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextFormField(
            controller: _parishNameController,
            label: 'Parish Name',
            isRequired: true,
            maxLength: 150,
            validator: (val) => SacramentalValidators.validatePlace(val, 'Parish name', isRequired: true, maxLength: 150),
          ),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _buildTextFormField(
                  controller: _ministerFirstNameController,
                  label: 'Priest / Bishop First Name',
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
                  label: 'Priest / Bishop Last Name',
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
                  label: 'Date of Confirmation',
                  isRequired: true,
                  value: _dateOfConfirmation,
                  hasError: _dateOfConfirmationHasError,
                  onTap: () => _selectDate(context, 3),
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
                  accentColor: _pentecostRed,
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
                    : (isEditMode ? _pentecostRed : ParishColors.oliveGreen),
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
                isEditMode ? 'Update Confirmation' : 'Save Confirmation',
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
              Icon(icon, size: 22, color: _pentecostRed),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.bold,
                    color: _pentecostRed,
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
                borderSide: BorderSide(color: _pentecostRed, width: 1.8),
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
                    color: _pentecostRed,
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
                borderSide: BorderSide(color: _pentecostRed, width: 1.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

