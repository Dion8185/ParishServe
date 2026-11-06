// =============================================================================
// FILE: lib/features/sacramental_records/presentation/pages/first_communion_manual_entry_page.dart
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/colors.dart';
import '../../../auth/services/auth_service.dart';
import '../../services/first_communion_service.dart';
import '../../validators/sacramental_validators.dart';
import '../dialogs/discard_entry_dialog.dart';

class FirstCommunionManualEntryPage extends StatefulWidget {
  final VoidCallback? onRecordSaved;
  final Map<String, dynamic>? initialData; // Enables Edit Record Mode

  const FirstCommunionManualEntryPage({
    super.key,
    this.onRecordSaved,
    this.initialData,
  });

  @override
  State<FirstCommunionManualEntryPage> createState() => _FirstCommunionManualEntryPageState();
}

class _FirstCommunionManualEntryPageState extends State<FirstCommunionManualEntryPage> {
  final _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();

  // Floating Back to Top state & micro-interactions
  bool _showBackToTop = false;
  bool _isBackToTopHovered = false;

  bool get isEditMode => widget.initialData != null;

  // Eucharistic Gold Accent Colors
  static const Color _eucharisticGold = Color(0xFFD49B18);

  // 1. Record Tracking & Reference
  final _yearController = TextEditingController(text: '${DateTime.now().year}');
  final _controlNumberController = TextEditingController(text: 'Loading...');
  DateTime? _dateOfCommunion = DateTime.now();

  // Live Duplicate Checker State
  Timer? _controlDebounce;
  bool _isCheckingControlDuplicate = false;
  String? _controlDuplicateError;

  // 2. Communicant Identity & Baptism
  final _communicantFirstNameController = TextEditingController();
  final _communicantMiddleNameController = TextEditingController();
  final _communicantLastNameController = TextEditingController();
  final _baptismParishController = TextEditingController(text: 'St. John Paul II Parish');
  DateTime? _baptismDate;

  // 3. Parents' Information
  final _fatherFirstNameController = TextEditingController();
  final _fatherMiddleNameController = TextEditingController();
  final _fatherLastNameController = TextEditingController();

  final _motherFirstNameController = TextEditingController();
  final _motherMiddleNameController = TextEditingController();
  final _motherMaidenLastNameController = TextEditingController();

  // 4. Officiating Clergy & Remarks
  final _ministerFirstNameController = TextEditingController(text: 'Roy');
  final _ministerMiddleNameController = TextEditingController();
  final _ministerLastNameController = TextEditingController(text: 'Reyes');
  final _remarksController = TextEditingController();

  bool _isSubmitting = false;
  bool _isLoadingControlNo = true;
  String? _errorMessage;
  bool _dateOfCommunionHasError = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    if (isEditMode) {
      _populateExistingData(widget.initialData!);
    } else {
      _loadAutoControlNumber();
      _yearController.addListener(_onControlParametersChanged);
      _controlNumberController.addListener(_onControlParametersChanged);
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
    _yearController.text = data['year']?.toString() ?? '${DateTime.now().year}';
    _controlNumberController.text = data['control_number']?.toString() ?? '';
    _dateOfCommunion = DateTime.tryParse(data['date_of_communion']?.toString() ?? '');
    _communicantFirstNameController.text = data['communicant_first_name']?.toString() ?? '';
    _communicantMiddleNameController.text = data['communicant_middle_name']?.toString() ?? '';
    _communicantLastNameController.text = data['communicant_last_name']?.toString() ?? '';
    _baptismParishController.text = data['baptism_parish']?.toString() ?? '';
    _baptismDate = DateTime.tryParse(data['baptism_date']?.toString() ?? '');

    _fatherFirstNameController.text = data['father_first_name']?.toString() ?? '';
    _fatherMiddleNameController.text = data['father_middle_name']?.toString() ?? '';
    _fatherLastNameController.text = data['father_last_name']?.toString() ?? '';

    _motherFirstNameController.text = data['mother_first_name']?.toString() ?? '';
    _motherMiddleNameController.text = data['mother_middle_name']?.toString() ?? '';
    _motherMaidenLastNameController.text = data['mother_maiden_last_name']?.toString() ?? '';

    _ministerFirstNameController.text = data['minister_first_name']?.toString() ?? '';
    _ministerMiddleNameController.text = data['minister_middle_name']?.toString() ?? '';
    _ministerLastNameController.text = data['minister_last_name']?.toString() ?? '';
    _remarksController.text = data['remarks']?.toString() ?? '';

    _isLoadingControlNo = false;
  }

  Future<void> _loadAutoControlNumber() async {
    setState(() => _isLoadingControlNo = true);
    try {
      final year = int.tryParse(_yearController.text.trim()) ?? DateTime.now().year;
      final nextControlNo = await FirstCommunionService.generateNextControlNumber(year);
      if (!mounted) return;
      setState(() {
        _controlNumberController.text = nextControlNo;
        _isLoadingControlNo = false;
      });
      _checkControlNumberLive();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _controlNumberController.text = 'FCM-${DateTime.now().year}-0001';
        _isLoadingControlNo = false;
      });
    }
  }

  void _onControlParametersChanged() {
    _controlDebounce?.cancel();
    _controlDebounce = Timer(const Duration(milliseconds: 350), _checkControlNumberLive);
  }

  Future<void> _checkControlNumberLive() async {
    final year = int.tryParse(_yearController.text.trim());
    final ctrl = _controlNumberController.text.trim();

    if (year == null || ctrl.isEmpty || ctrl == 'Loading...') {
      if (mounted && _controlDuplicateError != null) {
        setState(() => _controlDuplicateError = null);
      }
      return;
    }

    if (mounted) setState(() => _isCheckingControlDuplicate = true);

    final dupError = await SacramentalValidators.checkCommunionControlDuplicate(
      year: year,
      controlNumber: ctrl,
      excludeRecordId: isEditMode ? widget.initialData!['record_id']?.toString() : null,
    );

    if (mounted) {
      setState(() {
        _controlDuplicateError = dupError;
        _isCheckingControlDuplicate = false;
      });
    }
  }

  @override
  void dispose() {
    _controlDebounce?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _yearController.removeListener(_onControlParametersChanged);
    _controlNumberController.removeListener(_onControlParametersChanged);
    _yearController.dispose();
    _controlNumberController.dispose();
    _communicantFirstNameController.dispose();
    _communicantMiddleNameController.dispose();
    _communicantLastNameController.dispose();
    _baptismParishController.dispose();
    _fatherFirstNameController.dispose();
    _fatherMiddleNameController.dispose();
    _fatherLastNameController.dispose();
    _motherFirstNameController.dispose();
    _motherMiddleNameController.dispose();
    _motherMaidenLastNameController.dispose();
    _ministerFirstNameController.dispose();
    _ministerMiddleNameController.dispose();
    _ministerLastNameController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, int dateType) async {
    final now = DateTime.now();
    DateTime initialDate;
    final upperDateBound = (dateType == 0) ? DateTime(2100) : now;

    if (dateType == 0) {
      initialDate = _dateOfCommunion ?? now;
    } else {
      initialDate = _baptismDate ?? DateTime(now.year - 8, 1, 1);
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
          _dateOfCommunion = picked;
          _dateOfCommunionHasError = false;
        } else {
          _baptismDate = picked;
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

    if (_controlDuplicateError != null) {
      setState(() => _errorMessage = _controlDuplicateError);
      _scrollToTop();
      return false;
    }

    final yearError = SacramentalValidators.validateCommunionYear(_yearController.text);
    if (yearError != null) {
      setState(() => _errorMessage = yearError);
      _scrollToTop();
      return false;
    }

    final controlError = SacramentalValidators.validateCommunionControlNumber(_controlNumberController.text);
    if (controlError != null && !isEditMode) {
      setState(() => _errorMessage = controlError);
      _scrollToTop();
      return false;
    }

    if (_dateOfCommunion == null) {
      setState(() {
        _dateOfCommunionHasError = true;
        _errorMessage = 'Date of First Holy Communion is required.';
      });
      _scrollToTop();
      return false;
    }

    final communionError = SacramentalValidators.validateCommunionDate(_dateOfCommunion, _baptismDate);
    if (communionError != null) {
      setState(() => _errorMessage = communionError);
      _scrollToTop();
      return false;
    }

    return true;
  }

  /// Computes strict dynamic diff, excluding unchanged fields and coordinates
  String _computeChangesSummaryJson(Map<String, dynamic> oldData, Map<String, dynamic> newData) {
    final diffs = <String, Map<String, dynamic>>{};

    final Map<String, String> fieldLabels = {
      'communicant_first_name': 'Communicant First Name',
      'communicant_middle_name': 'Communicant Middle Name',
      'communicant_last_name': 'Communicant Last Name',
      'date_of_communion': 'Date of Communion',
      'baptism_parish': 'Church where Baptized',
      'baptism_date': 'Date of Baptism',
      'father_first_name': 'Father First Name',
      'father_middle_name': 'Father Middle Name',
      'father_last_name': 'Father Last Name',
      'mother_first_name': 'Mother First Name',
      'mother_middle_name': 'Mother Middle Name',
      'mother_maiden_last_name': 'Mother Maiden Last Name',
      'minister_first_name': 'Priest First Name',
      'minister_middle_name': 'Priest Middle Name',
      'minister_last_name': 'Priest Last Name',
      'remarks': 'Remarks',
    };

    newData.forEach((key, newVal) {
      if (key == 'created_at' ||
          key == 'year' ||
          key == 'control_number' ||
          key == 'record_id') {
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

  /// Verification & Review confirmation dialog before saving a new First Communion record
  Future<void> _promptSaveConfirmation() async {
    if (!_validateAllFields()) return;

    final communicantName = [
      _communicantFirstNameController.text.trim(),
      _communicantMiddleNameController.text.trim(),
      _communicantLastNameController.text.trim(),
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
                color: _eucharisticGold.withOpacity(0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.fact_check_outlined, color: _eucharisticGold, size: 24),
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
                    'Verify all fields before saving into Liber Primae Communionis.',
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
                _buildReviewSection('1. Registry Reference', [
                  _buildReviewRow('Archival Year:', _yearController.text.trim()),
                  _buildReviewRow('Control Number:', _controlNumberController.text.trim()),
                  _buildReviewRow('Communion Date:', _dateOfCommunion?.toIso8601String().substring(0, 10) ?? '—'),
                ]),
                const SizedBox(height: 12),
                _buildReviewSection("2. Communicant Information", [
                  _buildReviewRow('Full Name:', communicantName),
                  _buildReviewRow('Church where Baptized:', _baptismParishController.text.trim()),
                  _buildReviewRow('Date of Baptism:', _baptismDate?.toIso8601String().substring(0, 10) ?? 'Not Specified'),
                ]),
                const SizedBox(height: 12),
                _buildReviewSection('3. Parents (Optional in Batch Registers)', [
                  _buildReviewRow('Father:', fatherName.isNotEmpty ? fatherName : 'Not Specified'),
                  _buildReviewRow('Mother Maiden Name:', motherName.isNotEmpty ? motherName : 'Not Specified'),
                ]),
                const SizedBox(height: 12),
                _buildReviewSection('4. Presiding Priest & Remarks', [
                  _buildReviewRow('Officiating Priest:', priestName),
                  if (_remarksController.text.trim().isNotEmpty)
                    _buildReviewRow('Batch / Mass Notes:', _remarksController.text.trim()),
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
              color: _eucharisticGold,
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

    final reasonController = TextEditingController(text: 'Correction of communion record details');

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
                color: _eucharisticGold.withOpacity(0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.security_update_good, color: _eucharisticGold, size: 24),
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
                'You are modifying canonical entry ${widget.initialData!['record_id']} (${_communicantFirstNameController.text.trim()} ${_communicantLastNameController.text.trim()}).',
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
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _eucharisticGold),
                    ),
                    Text(
                      'Year ${_yearController.text.trim()} • Control No. ${_controlNumberController.text.trim()}',
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
                  hintText: 'e.g. Typographical error correction on communicant name',
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
      final int year = int.parse(_yearController.text.trim());
      final currentUser = AuthService.currentUser;
      final currentUserId = currentUser?.userId ?? 'STAFF';
      final currentUserName = currentUser != null
          ? '${currentUser.firstName} ${currentUser.lastName}'.trim()
          : 'Authorized Parish Personnel';
      final now = DateTime.now();

      final recordMap = {
        'year': isEditMode ? widget.initialData!['year'] : year,
        'control_number': isEditMode ? widget.initialData!['control_number'] : _controlNumberController.text.trim(),
        'date_of_communion': _dateOfCommunion!.toIso8601String().substring(0, 10),

        'communicant_first_name': _communicantFirstNameController.text.trim(),
        'communicant_middle_name': _communicantMiddleNameController.text.trim().isEmpty ? null : _communicantMiddleNameController.text.trim(),
        'communicant_last_name': _communicantLastNameController.text.trim(),

        'baptism_parish': _baptismParishController.text.trim(),
        'baptism_date': _baptismDate?.toIso8601String().substring(0, 10),

        'father_first_name': _fatherFirstNameController.text.trim().isEmpty ? null : _fatherFirstNameController.text.trim(),
        'father_middle_name': _fatherMiddleNameController.text.trim().isEmpty ? null : _fatherMiddleNameController.text.trim(),
        'father_last_name': _fatherLastNameController.text.trim().isEmpty ? null : _fatherLastNameController.text.trim(),

        'mother_first_name': _motherFirstNameController.text.trim().isEmpty ? null : _motherFirstNameController.text.trim(),
        'mother_middle_name': _motherMiddleNameController.text.trim().isEmpty ? null : _motherMiddleNameController.text.trim(),
        'mother_maiden_last_name': _motherMaidenLastNameController.text.trim().isEmpty ? null : _motherMaidenLastNameController.text.trim(),

        'minister_first_name': _ministerFirstNameController.text.trim(),
        'minister_middle_name': _ministerMiddleNameController.text.trim().isEmpty ? null : _ministerMiddleNameController.text.trim(),
        'minister_last_name': _ministerLastNameController.text.trim(),

        'remarks': _remarksController.text.trim().isEmpty ? null : _remarksController.text.trim(),
      };

      if (isEditMode) {
        final recordId = widget.initialData!['record_id'].toString();

        final changesJson = _computeChangesSummaryJson(widget.initialData!, recordMap);

        await FirstCommunionService.updateFirstCommunionRecord(recordId, recordMap);

        if (changesJson.isNotEmpty) {
          try {
            await Supabase.instance.client.from('sacramental_record_audit_logs').insert({
              'log_id': 'LOG-${now.millisecondsSinceEpoch}',
              'record_id': recordId,
              'sacrament_type': 'First Communion',
              'action_type': 'UPDATED',
              'recipient_name': '${_communicantFirstNameController.text.trim()} ${_communicantLastNameController.text.trim()}',
              'book_number': null,
              'page_number': null,
              'line_number': null,
              'performed_by_id': currentUserId,
              'performed_by_name': currentUserName,
              'performed_by_role': currentUser?.userRole ?? 'Secretary',
              'justification': reasonForCorrection ?? 'Correction of communion record details',
              'changes_summary': changesJson,
              'created_at': now.toIso8601String(),
            });
          } catch (auditErr) {
            debugPrint('[FirstCommunionManualEntryPage] Audit log insertion notice: $auditErr');
          }
        }
      } else {
        final insertedRecord = await FirstCommunionService.insertManualFirstCommunionRecord(recordMap);

        try {
          await Supabase.instance.client.from('sacramental_record_audit_logs').insert({
            'log_id': 'LOG-${now.millisecondsSinceEpoch}',
            'record_id': insertedRecord.recordId,
            'sacrament_type': 'First Communion',
            'action_type': 'CREATED',
            'recipient_name': insertedRecord.communicantFullName,
            'book_number': null,
            'page_number': null,
            'line_number': null,
            'performed_by_id': currentUserId,
            'performed_by_name': currentUserName,
            'performed_by_role': currentUser?.userRole ?? 'Secretary',
            'justification': 'Initial First Communion registry entry',
            'changes_summary': '',
            'created_at': now.toIso8601String(),
          });
        } catch (auditErr) {
          debugPrint('[FirstCommunionManualEntryPage] Audit log insertion notice: $auditErr');
        }
      }

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditMode
              ? 'First Communion record updated and logged successfully.'
              : 'First Communion record saved in Liber Primae Communionis.'),
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
          accentColor: _eucharisticGold,
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
            icon: const Icon(Icons.arrow_back, color: _eucharisticGold, size: 26),
            onPressed: _isSubmitting
                ? null
                : () async {
              final shouldExit = await showDiscardConfirmationDialog(
                context,
                accentColor: _eucharisticGold,
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
                isEditMode ? 'Edit First Communion Record' : 'First Communion Manual Entry',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDarkColor),
              ),
              Text(
                isEditMode
                    ? 'Editing Record: ${widget.initialData!['record_id']}'
                    : 'Canonical Registry Book (Liber Primae Communionis)',
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
                      backgroundColor: _eucharisticGold,
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

                              _buildSection1TrackingAndReference(isWide: isWide),
                              const SizedBox(height: 16),
                              _buildSection2CommunicantIdentity(isWide: isWide),
                              const SizedBox(height: 16),
                              _buildSection3Parents(isWide: isWide),
                              const SizedBox(height: 16),
                              _buildSection4ClergyAndRemarks(isWide: isWide),
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
              color: _eucharisticGold,
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
                      'FIRST COMMUNION REGISTER',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _eucharisticGold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _eucharisticGold.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Canonical Step',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _eucharisticGold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'First Holy Communion Entry',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: ParishColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Enter all communion credentials according to the parish registry book.',
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

  Widget _buildSection1TrackingAndReference({required bool isWide}) {
    final bool hasDup = _controlDuplicateError != null;

    return _buildSectionCard(
      title: isEditMode
          ? '1. Parish Registry Control Reference (Coordinates Locked)'
          : '1. Parish Registry Control Reference',
      icon: Icons.bookmark_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isEditMode) ...[
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: _eucharisticGold.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _eucharisticGold.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock, size: 16, color: _eucharisticGold),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Archival Year and Control Number are permanent canonical identifiers and cannot be altered.',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _eucharisticGold),
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
                      _controlDuplicateError!,
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
                  controller: _yearController,
                  label: 'Archival Year',
                  isRequired: true,
                  enabled: !isEditMode,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  onChanged: (_) => _loadAutoControlNumber(),
                  validator: SacramentalValidators.validateCommunionYear,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextFormField(
                      controller: _controlNumberController,
                      label: 'Control Number',
                      isRequired: true,
                      enabled: false,
                      maxLength: 20,
                      validator: SacramentalValidators.validateCommunionControlNumber,
                    ),
                    if (_isCheckingControlDuplicate)
                      Padding(
                        padding: const EdgeInsets.only(top: 2, left: 4),
                        child: Row(
                          children: [
                            const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: _eucharisticGold)),
                            const SizedBox(width: 6),
                            Text('Checking control assignment...', style: TextStyle(fontSize: 10.5, color: ParishColors.textMuted)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildDatePickerField(
            label: 'Date of First Holy Communion',
            isRequired: true,
            value: _dateOfCommunion,
            hasError: _dateOfCommunionHasError,
            onTap: () => _selectDate(context, 0),
          ),
        ],
      ),
    );
  }

  Widget _buildSection2CommunicantIdentity({required bool isWide}) {
    return _buildSectionCard(
      title: "2. Communicant's Information",
      icon: Icons.person_outline,
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
                    controller: _communicantFirstNameController,
                    label: 'First Name',
                    isRequired: true,
                    maxLength: 50,
                    validator: (val) => SacramentalValidators.validateName(val, 'Communicant first name', isRequired: true, maxLength: 50),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _buildTextFormField(
                    controller: _communicantMiddleNameController,
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
                    controller: _communicantLastNameController,
                    label: 'Last Name',
                    isRequired: true,
                    maxLength: 50,
                    validator: (val) => SacramentalValidators.validateName(val, 'Communicant last name', isRequired: true, maxLength: 50),
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
                    controller: _communicantFirstNameController,
                    label: 'First Name',
                    isRequired: true,
                    maxLength: 50,
                    validator: (val) => SacramentalValidators.validateName(val, 'Communicant first name', isRequired: true, maxLength: 50),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: _buildTextFormField(
                    controller: _communicantMiddleNameController,
                    label: 'Middle Name',
                    isRequired: false,
                    maxLength: 50,
                    validator: (val) => SacramentalValidators.validateName(val, 'Middle name', isRequired: false, maxLength: 50),
                  ),
                ),
              ],
            ),
            _buildTextFormField(
              controller: _communicantLastNameController,
              label: 'Last Name',
              isRequired: true,
              maxLength: 50,
              validator: (val) => SacramentalValidators.validateName(val, 'Communicant last name', isRequired: true, maxLength: 50),
            ),
          ],
          const Divider(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: isWide ? 6 : 1,
                child: _buildTextFormField(
                  controller: _baptismParishController,
                  label: 'Church where Baptized',
                  isRequired: true,
                  maxLength: 150,
                  validator: (val) => SacramentalValidators.validatePlace(val, 'Church where baptized', isRequired: true, maxLength: 150),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: isWide ? 4 : 1,
                child: _buildDatePickerField(
                  label: 'Date of Baptism',
                  isRequired: false,
                  value: _baptismDate,
                  hasError: false,
                  onTap: () => _selectDate(context, 1),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection3Parents({required bool isWide}) {
    return _buildSectionCard(
      title: "3. Parents' Names (Optional in Batch Registers)",
      icon: Icons.people,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Father's Information", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: _eucharisticGold)),
          const SizedBox(height: 8),

          if (isWide) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: _buildTextFormField(
                    controller: _fatherFirstNameController,
                    label: 'Father First Name',
                    isRequired: false,
                    maxLength: 50,
                    validator: (val) => SacramentalValidators.validateName(val, "Father's first name", isRequired: false, maxLength: 50),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _buildTextFormField(
                    controller: _fatherMiddleNameController,
                    label: 'Middle Name',
                    isRequired: false,
                    maxLength: 50,
                    validator: (val) => SacramentalValidators.validateName(val, "Father's middle name", isRequired: false, maxLength: 50),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: _buildTextFormField(
                    controller: _fatherLastNameController,
                    label: 'Father Last Name',
                    isRequired: false,
                    maxLength: 50,
                    validator: (val) => SacramentalValidators.validateName(val, "Father's last name", isRequired: false, maxLength: 50),
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
                    isRequired: false,
                    maxLength: 50,
                    validator: (val) => SacramentalValidators.validateName(val, "Father's first name", isRequired: false, maxLength: 50),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextFormField(
                    controller: _fatherMiddleNameController,
                    label: 'Middle Name',
                    isRequired: false,
                    maxLength: 50,
                    validator: (val) => SacramentalValidators.validateName(val, "Father's middle name", isRequired: false, maxLength: 50),
                  ),
                ),
              ],
            ),
            _buildTextFormField(
              controller: _fatherLastNameController,
              label: 'Father Last Name',
              isRequired: false,
              maxLength: 50,
              validator: (val) => SacramentalValidators.validateName(val, "Father's last name", isRequired: false, maxLength: 50),
            ),
          ],

          const Divider(height: 24),

          const Text("Mother's Information", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: _eucharisticGold)),
          const SizedBox(height: 8),

          if (isWide) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: _buildTextFormField(
                    controller: _motherFirstNameController,
                    label: 'Mother First Name',
                    isRequired: false,
                    maxLength: 50,
                    validator: (val) => SacramentalValidators.validateName(val, "Mother's first name", isRequired: false, maxLength: 50),
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
                    isRequired: false,
                    maxLength: 50,
                    validator: (val) => SacramentalValidators.validateName(val, "Mother's maiden last name", isRequired: false, maxLength: 50),
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
                    isRequired: false,
                    maxLength: 50,
                    validator: (val) => SacramentalValidators.validateName(val, "Mother's first name", isRequired: false, maxLength: 50),
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
            _buildTextFormField(
              controller: _motherMaidenLastNameController,
              label: 'Maiden Last Name',
              isRequired: false,
              maxLength: 50,
              validator: (val) => SacramentalValidators.validateName(val, "Mother's maiden last name", isRequired: false, maxLength: 50),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSection4ClergyAndRemarks({required bool isWide}) {
    return _buildSectionCard(
      title: '4. Officiating Priest & Remarks',
      icon: Icons.church,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
            ],
          ),
          _buildTextFormField(
            controller: _ministerLastNameController,
            label: 'Priest Last Name',
            isRequired: true,
            maxLength: 50,
            validator: (val) => SacramentalValidators.validateName(val, 'Priest last name', isRequired: true, maxLength: 50),
          ),
          _buildTextFormField(
            controller: _remarksController,
            label: 'Remarks / Batch Details',
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
                  accentColor: _eucharisticGold,
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
                backgroundColor: (_controlDuplicateError != null)
                    ? ParishColors.mercyRed
                    : (isEditMode ? _eucharisticGold : ParishColors.oliveGreen),
                foregroundColor: Colors.white,
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: (_isSubmitting || _isLoadingControlNo || _controlDuplicateError != null)
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
                isEditMode ? 'Update Communion' : 'Save Communion',
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
              Icon(icon, size: 22, color: _eucharisticGold),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.bold,
                    color: _eucharisticGold,
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
    void Function(String)? onChanged,
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
            onChanged: onChanged,
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
                borderSide: BorderSide(color: _eucharisticGold, width: 1.8),
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
                    color: _eucharisticGold,
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
}