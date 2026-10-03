// =============================================================================
// FILE: lib/features/dashboard/presentation/dialogs/pabuklat_request_dialog.dart (PART 1 OF 2)
// =============================================================================

import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/colors.dart';
import '../../../auth/services/auth_service.dart';
import '../../../sacramental_records/presentation/dialogs/discard_entry_dialog.dart';
import '../../../sacramental_records/services/pabuklat_service.dart';

void showPabuklatRequestModal(BuildContext context, {VoidCallback? onRequestSaved}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _PabuklatRequestDialog(onRequestSaved: onRequestSaved),
  );
}

/// Strict Philippine Phone Formatter (09XX-XXX-XXXX)
class _PhilippinePhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length > 11) return oldValue;

    final buffer = StringBuffer();
    for (int i = 0; i < digitsOnly.length; i++) {
      buffer.write(digitsOnly[i]);
      if ((i == 3 || i == 6) && i != digitsOnly.length - 1) {
        buffer.write('-');
      }
    }

    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}

/// Title Case Auto-Capitalizer
class _TitleCaseInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    final words = text.split(' ');
    final capitalized = words.map((w) {
      if (w.isEmpty) return '';
      return w[0].toUpperCase() + (w.length > 1 ? w.substring(1) : '');
    }).join(' ');

    return TextEditingValue(
      text: capitalized,
      selection: newValue.selection,
    );
  }
}

class _PabuklatRequestDialog extends StatefulWidget {
  final VoidCallback? onRequestSaved;

  const _PabuklatRequestDialog({this.onRequestSaved});

  @override
  State<_PabuklatRequestDialog> createState() => _PabuklatRequestDialogState();
}

class _PabuklatRequestDialogState extends State<_PabuklatRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  static const String _draftStorageKey = 'parishserve_draft_pabuklat_request';

  // Step 0 = Request Information, Step 1 = Record Found Confirmation, Step 2 = Requestor Info & Submission
  int _currentStep = 0;

  String _selectedSacrament = 'Baptism';
  final List<String> _sacramentOptions = [
    'Baptism',
    'Confirmation',
    'First Communion',
    'Matrimony',
    'Death',
    'Conversion',
  ];

  // 1. Single Recipient / Subject Information
  final _recipientFullNameController = TextEditingController();
  final _fatherFirstNameController = TextEditingController();
  final _fatherMiddleNameController = TextEditingController();
  final _fatherLastNameController = TextEditingController();
  final _motherFirstNameController = TextEditingController();
  final _motherMiddleNameController = TextEditingController();
  final _motherLastNameController = TextEditingController();
  DateTime? _birthDate;
  DateTime? _possibleSacramentDate;

  // 2. Marriage Specific Information (Bride & Groom)
  final _groomFullNameController = TextEditingController();
  DateTime? _groomBirthDate;
  final _groomFatherFirstNameController = TextEditingController();
  final _groomFatherMiddleNameController = TextEditingController();
  final _groomFatherLastNameController = TextEditingController();
  final _groomMotherFirstNameController = TextEditingController();
  final _groomMotherMiddleNameController = TextEditingController();
  final _groomMotherLastNameController = TextEditingController();

  final _brideFullNameController = TextEditingController();
  DateTime? _brideBirthDate;
  final _brideFatherFirstNameController = TextEditingController();
  final _brideFatherMiddleNameController = TextEditingController();
  final _brideFatherLastNameController = TextEditingController();
  final _brideMotherFirstNameController = TextEditingController();
  final _brideMotherMiddleNameController = TextEditingController();
  final _brideMotherLastNameController = TextEditingController();
  DateTime? _marriageDate;

  // 3. Requestor Information
  final _requestorFullNameController = TextEditingController();
  String _relationshipToRecipient = 'Self';
  final List<String> _relationshipOptions = [
    'Self',
    'Parent / Guardian',
    'Child',
    'Spouse',
    'Sibling',
    'Authorized Representative',
  ];
  final _contactNumberController = TextEditingController();
  final _purposeController = TextEditingController();

  // Temporary Valid ID Document
  Uint8List? _attachedIdBytes;
  String? _attachedIdFileName;
  int? _attachedIdFileSize;

  // Matched Record
  SacramentMatchResult? _matchedRecord;

  bool _isSearching = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final user = AuthService.currentUser;
    if (user != null) {
      _requestorFullNameController.text = user.fullName;
    }
    _restoreDraftState();
  }

  @override
  void dispose() {
    _recipientFullNameController.dispose();
    _fatherFirstNameController.dispose();
    _fatherMiddleNameController.dispose();
    _fatherLastNameController.dispose();
    _motherFirstNameController.dispose();
    _motherMiddleNameController.dispose();
    _motherLastNameController.dispose();

    _groomFullNameController.dispose();
    _groomFatherFirstNameController.dispose();
    _groomFatherMiddleNameController.dispose();
    _groomFatherLastNameController.dispose();
    _groomMotherFirstNameController.dispose();
    _groomMotherMiddleNameController.dispose();
    _groomMotherLastNameController.dispose();

    _brideFullNameController.dispose();
    _brideFatherFirstNameController.dispose();
    _brideFatherMiddleNameController.dispose();
    _brideFatherLastNameController.dispose();
    _brideMotherFirstNameController.dispose();
    _brideMotherMiddleNameController.dispose();
    _brideMotherLastNameController.dispose();

    _requestorFullNameController.dispose();
    _contactNumberController.dispose();
    _purposeController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // Draft Persistence Lifecycle (SharedPreferences)
  // ===========================================================================

  Future<void> _saveDraftState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draft = {
        'step': _currentStep,
        'sacrament': _selectedSacrament,
        'recipientFullName': _recipientFullNameController.text,
        'fatherFirstName': _fatherFirstNameController.text,
        'fatherMiddleName': _fatherMiddleNameController.text,
        'fatherLastName': _fatherLastNameController.text,
        'motherFirstName': _motherFirstNameController.text,
        'motherMiddleName': _motherMiddleNameController.text,
        'motherLastName': _motherLastNameController.text,
        'birthDate': _birthDate?.toIso8601String(),
        'possibleSacramentDate': _possibleSacramentDate?.toIso8601String(),
        'groomFullName': _groomFullNameController.text,
        'groomBirthDate': _groomBirthDate?.toIso8601String(),
        'groomFatherFirstName': _groomFatherFirstNameController.text,
        'groomFatherMiddleName': _groomFatherMiddleNameController.text,
        'groomFatherLastName': _groomFatherLastNameController.text,
        'groomMotherFirstName': _groomMotherFirstNameController.text,
        'groomMotherMiddleName': _groomMotherMiddleNameController.text,
        'groomMotherLastName': _groomMotherLastNameController.text,
        'brideFullName': _brideFullNameController.text,
        'brideBirthDate': _brideBirthDate?.toIso8601String(),
        'brideFatherFirstName': _brideFatherFirstNameController.text,
        'brideFatherMiddleName': _brideFatherMiddleNameController.text,
        'brideFatherLastName': _brideFatherLastNameController.text,
        'brideMotherFirstName': _brideMotherFirstNameController.text,
        'brideMotherMiddleName': _brideMotherMiddleNameController.text,
        'brideMotherLastName': _brideMotherLastNameController.text,
        'marriageDate': _marriageDate?.toIso8601String(),
        'requestorFullName': _requestorFullNameController.text,
        'relationship': _relationshipToRecipient,
        'contact': _contactNumberController.text,
        'purpose': _purposeController.text,
        'hasMatch': _matchedRecord != null,
        'matchedRecordId': _matchedRecord?.recordId,
        'matchedSacrament': _matchedRecord?.sacramentType,
        'matchedRecipient': _matchedRecord?.recipientName,
        'matchedDate': _matchedRecord?.dateOfSacrament,
      };
      await prefs.setString(_draftStorageKey, jsonEncode(draft));
    } catch (_) {}
  }

  Future<void> _restoreDraftState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_draftStorageKey);
      if (raw != null && raw.isNotEmpty) {
        final d = jsonDecode(raw) as Map<String, dynamic>;
        if (!mounted) return;
        setState(() {
          _currentStep = d['step'] ?? 0;
          _selectedSacrament = d['sacrament'] ?? 'Baptism';
          _recipientFullNameController.text = d['recipientFullName'] ?? '';
          _fatherFirstNameController.text = d['fatherFirstName'] ?? '';
          _fatherMiddleNameController.text = d['fatherMiddleName'] ?? '';
          _fatherLastNameController.text = d['fatherLastName'] ?? '';
          _motherFirstNameController.text = d['motherFirstName'] ?? '';
          _motherMiddleNameController.text = d['motherMiddleName'] ?? '';
          _motherLastNameController.text = d['motherLastName'] ?? '';
          if (d['birthDate'] != null) _birthDate = DateTime.tryParse(d['birthDate']);
          if (d['possibleSacramentDate'] != null) _possibleSacramentDate = DateTime.tryParse(d['possibleSacramentDate']);

          _groomFullNameController.text = d['groomFullName'] ?? '';
          if (d['groomBirthDate'] != null) _groomBirthDate = DateTime.tryParse(d['groomBirthDate']);
          _groomFatherFirstNameController.text = d['groomFatherFirstName'] ?? '';
          _groomFatherMiddleNameController.text = d['groomFatherMiddleName'] ?? '';
          _groomFatherLastNameController.text = d['groomFatherLastName'] ?? '';
          _groomMotherFirstNameController.text = d['groomMotherFirstName'] ?? '';
          _groomMotherMiddleNameController.text = d['groomMotherMiddleName'] ?? '';
          _groomMotherLastNameController.text = d['groomMotherLastName'] ?? '';

          _brideFullNameController.text = d['brideFullName'] ?? '';
          if (d['brideBirthDate'] != null) _brideBirthDate = DateTime.tryParse(d['brideBirthDate']);
          _brideFatherFirstNameController.text = d['brideFatherFirstName'] ?? '';
          _brideFatherMiddleNameController.text = d['brideFatherMiddleName'] ?? '';
          _brideFatherLastNameController.text = d['brideFatherLastName'] ?? '';
          _brideMotherFirstNameController.text = d['brideMotherFirstName'] ?? '';
          _brideMotherMiddleNameController.text = d['brideMotherMiddleName'] ?? '';
          _brideMotherLastNameController.text = d['brideMotherLastName'] ?? '';
          if (d['marriageDate'] != null) _marriageDate = DateTime.tryParse(d['marriageDate']);

          if (d['requestorFullName'] != null && (d['requestorFullName'] as String).isNotEmpty) {
            _requestorFullNameController.text = d['requestorFullName'];
          }
          if (d['relationship'] != null) _relationshipToRecipient = d['relationship'];
          _contactNumberController.text = d['contact'] ?? '';
          _purposeController.text = d['purpose'] ?? '';

          if (d['hasMatch'] == true && d['matchedRecordId'] != null) {
            _matchedRecord = SacramentMatchResult(
              recordId: d['matchedRecordId'],
              sacramentType: d['matchedSacrament'] ?? _selectedSacrament,
              recipientName: d['matchedRecipient'] ?? '',
              dateOfSacrament: d['matchedDate'] ?? '',
              matchScore: 2,
              rawData: {},
            );
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _clearDraftState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftStorageKey);
    } catch (_) {}
  }

  // ===========================================================================
  // Strict Anti-Bruteforce & Input Sanitation Validation
  // ===========================================================================

  static const List<String> _keyboardSequences = [
    'asdf', 'sdfg', 'dfgh', 'fghj', 'ghjk', 'hjkl',
    'qwer', 'wert', 'erty', 'rtyu', 'tyui', 'yuio', 'uiop',
    'zxcv', 'xcvb', 'cvbn', 'vbnm',
    'fdsa', 'gfds', 'hgfd', 'jhgf', 'kjhg', 'lkjh',
  ];

  String? _validateNameField(String? value, String label, {bool isRequired = true, int min = 2, int max = 60}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      if (isRequired) return '$label is required.';
      return null;
    }

    if (text.length < min) return '$label must be at least $min characters.';
    if (text.length > max) return '$label cannot exceed $max characters.';

    if (RegExp(r'''[<>{};'"%\\=]''').hasMatch(text)) {
      return '$label contains invalid special characters.';
    }

    if (RegExp(r'(.)\1{2,}', caseSensitive: false).hasMatch(text)) {
      return '$label contains an invalid repetitive sequence.';
    }

    final lower = text.toLowerCase();
    for (final seq in _keyboardSequences) {
      if (lower.contains(seq)) {
        return '$label cannot contain keyboard sequence "$seq".';
      }
    }

    return null;
  }

  // ===========================================================================
  // Search & Match Action
  // ===========================================================================

  Future<void> _handleSearchRecord() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) return;

    final isMarriage = _selectedSacrament == 'Matrimony';

    // Birthdate is strictly required for matching
    if (!isMarriage && _birthDate == null) {
      setState(() => _errorMessage = 'Birthdate is required for record matching.');
      return;
    }

    if (isMarriage) {
      if (_groomBirthDate == null) {
        setState(() => _errorMessage = "Groom's birthdate is required for record matching.");
        return;
      }
      if (_brideBirthDate == null) {
        setState(() => _errorMessage = "Bride's birthdate is required for record matching.");
        return;
      }
    }

    setState(() => _isSearching = true);

    try {
      final match = await PabuklatService.findMatchingRecord(
        sacramentType: _selectedSacrament,
        recipientFullName: _recipientFullNameController.text.trim(),
        motherFirstName: _motherFirstNameController.text.trim(),
        motherMiddleName: _motherMiddleNameController.text.trim(),
        motherLastName: _motherLastNameController.text.trim(),
        fatherFirstName: _fatherFirstNameController.text.trim(),
        fatherMiddleName: _fatherMiddleNameController.text.trim(),
        fatherLastName: _fatherLastNameController.text.trim(),
        birthDate: _birthDate,
        sacramentDate: _possibleSacramentDate,
        brideFullName: _brideFullNameController.text.trim(),
        brideBirthDate: _brideBirthDate,
        brideMotherFirstName: _brideMotherFirstNameController.text.trim(),
        brideMotherMiddleName: _brideMotherMiddleNameController.text.trim(),
        brideMotherLastName: _brideMotherLastNameController.text.trim(),
        brideFatherFirstName: _brideFatherFirstNameController.text.trim(),
        brideFatherMiddleName: _brideFatherMiddleNameController.text.trim(),
        brideFatherLastName: _brideFatherLastNameController.text.trim(),
        groomFullName: _groomFullNameController.text.trim(),
        groomBirthDate: _groomBirthDate,
        groomMotherFirstName: _groomMotherFirstNameController.text.trim(),
        groomMotherMiddleName: _groomMotherMiddleNameController.text.trim(),
        groomMotherLastName: _groomMotherLastNameController.text.trim(),
        groomFatherFirstName: _groomFatherFirstNameController.text.trim(),
        groomFatherMiddleName: _groomFatherMiddleNameController.text.trim(),
        groomFatherLastName: _groomFatherLastNameController.text.trim(),
        marriageDate: _marriageDate,
      );

      if (!mounted) return;

      if (match != null) {
        setState(() {
          _matchedRecord = match;
          _isSearching = false;
          _currentStep = 1; // Transition directly to "Record Found State"
        });
        _saveDraftState();
      } else {
        setState(() {
          _isSearching = false;
          _errorMessage = 'No matching sacramental record found matching at least 2 pieces of your submitted information. Please verify spelling of names and dates.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isSearching = false;
      });
    }
  }

  // ===========================================================================
  // Valid ID Attachment
  // ===========================================================================

  Future<void> _pickIdDocument() async {
    try {
      final PlatformFile? file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      );

      if (file != null) {
        final int fileSize = (await file.length()) ?? 0;
        if (fileSize > 5 * 1024 * 1024) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File size exceeds 5MB limit. Please upload a smaller document.'),
              backgroundColor: ParishColors.mercyRed,
            ),
          );
          return;
        }

        final Uint8List bytes = await file.readAsBytes();

        setState(() {
          _attachedIdBytes = bytes;
          _attachedIdFileName = file.name;
          _attachedIdFileSize = fileSize;
        });
      }
    } catch (e) {
      debugPrint('[PabuklatRequestDialog] Error picking file: $e');
    }
  }

  void _clearAttachedId() {
    setState(() {
      _attachedIdBytes = null;
      _attachedIdFileName = null;
      _attachedIdFileSize = null;
    });
  }

  // ===========================================================================
  // Final Request Submission
  // ===========================================================================

  Future<void> _handleSubmitRequest() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) return;

    if (_attachedIdBytes == null || _attachedIdFileName == null) {
      setState(() => _errorMessage = 'Please upload a valid government or official ID for verification.');
      return;
    }

    if (_matchedRecord == null) {
      setState(() => _errorMessage = 'No verified record attached. Please re-run search.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final tempReqId = 'REQ-${DateTime.now().millisecondsSinceEpoch}';

      // 1. Upload temporary valid ID strictly to private bucket
      final idPath = await PabuklatService.uploadRequestorIdDocument(
        requestId: tempReqId,
        fileBytes: _attachedIdBytes!,
        fileName: _attachedIdFileName!,
      );

      // 2. Submit to service_requests and notify Secretary
      await PabuklatService.submitPabuklatRequest(
        sacramentType: _matchedRecord!.sacramentType,
        recordId: _matchedRecord!.recordId,
        requesterFullName: _requestorFullNameController.text.trim(),
        relationshipToRecipient: _relationshipToRecipient,
        contactNumber: _contactNumberController.text.trim(),
        purpose: _purposeController.text.trim(),
        idDocumentUrl: idPath,
      );

      // 3. Clear draft upon successful submission
      await _clearDraftState();

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sacramental certificate request submitted! Pending Secretary review.'),
          backgroundColor: ParishColors.oliveGreen,
          duration: Duration(seconds: 4),
        ),
      );

      widget.onRequestSaved?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isSubmitting = false;
      });
    }
  }

// =============================================================================
// FILE: lib/features/dashboard/presentation/dialogs/pabuklat_request_dialog.dart (PART 2 OF 2)
// =============================================================================

  Future<void> _handleDiscardAndClose() async {
    final confirmed = await showDiscardConfirmationDialog(
      context,
      title: 'Discard Request Draft?',
      message: 'All entered details will be cleared and your draft will be discarded.',
      accentColor: ParishColors.marianBlue,
    );

    if (confirmed && mounted) {
      await _clearDraftState();
      Navigator.pop(context);
    }
  }

  Future<void> _saveDraftAndClose() async {
    await _saveDraftState();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final cardWhite = ParishColors.cardWhite;
    final borderGrey = ParishColors.borderGrey;
    final isMarriage = _selectedSacrament == 'Matrimony';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        // Closing via hardware back, ESC, or barrier click automatically preserves the draft!
        _saveDraftAndClose();
      },
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        backgroundColor: cardWhite,
        child: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxWidth: 640, maxHeight: 780),
          child: Column(
            children: [
              // Top Header Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                decoration: BoxDecoration(
                  color: ParishColors.marianBlueSurface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                  border: Border(bottom: BorderSide(color: borderGrey)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: ParishColors.marianBlue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.folder_shared, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Request Sacramental Record (Pabuklat)',
                            style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: textDark),
                          ),
                          Text(
                            _currentStep == 0
                                ? 'Step 1: Request Information'
                                : (_currentStep == 1
                                ? 'Step 2: Record Found Confirmation'
                                : 'Step 3: Requestor Information & Verification ID'),
                            style: TextStyle(fontSize: 11.5, color: textMuted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Save Draft & Close',
                      onPressed: _isSearching || _isSubmitting ? null : _saveDraftAndClose,
                    ),
                  ],
                ),
              ),

              // Scrollable Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(22),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_errorMessage != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: ParishColors.mercyRedSurface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: ParishColors.mercyRed),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.warning_amber_rounded, color: ParishColors.mercyRed, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: ParishColors.mercyRed),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // =======================================================
                        // STEP 0: REQUEST INFORMATION
                        // =======================================================
                        if (_currentStep == 0) ...[
                          _buildFieldLabel('Select Certificate / Sacrament Type', isRequired: true),
                          DropdownButtonFormField<String>(
                            value: _selectedSacrament,
                            isExpanded: true,
                            decoration: _inputDecoration(),
                            items: _sacramentOptions.map((s) {
                              return DropdownMenuItem(
                                value: s,
                                child: Text('$s Certificate', style: const TextStyle(fontSize: 13.5)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedSacrament = val;
                                  _matchedRecord = null;
                                });
                                _saveDraftState();
                              }
                            },
                          ),
                          const SizedBox(height: 18),

                          // Dynamic Layout: Marriage vs Single Recipient
                          if (isMarriage) ...[
                            _buildMarriageFormSection(),
                          ] else ...[
                            _buildSingleRecipientFormSection(),
                          ],
                        ]

                        // =======================================================
                        // STEP 1: RECORD FOUND STATE
                        // =======================================================
                        else if (_currentStep == 1) ...[
                          _buildRecordFoundState(),
                        ]

                        // =======================================================
                        // STEP 2: REQUESTOR INFORMATION
                        // =======================================================
                        else ...[
                            _buildRequestorInfoSection(),
                          ],
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom Action Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                decoration: BoxDecoration(
                  color: cardWhite,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
                  border: Border(top: BorderSide(color: borderGrey)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: _isSearching || _isSubmitting ? null : _handleDiscardAndClose,
                      child: const Text(
                        'Discard Draft',
                        style: TextStyle(color: ParishColors.mercyRed, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    Row(
                      children: [
                        if (_currentStep > 0)
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: borderGrey),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                            onPressed: _isSearching || _isSubmitting
                                ? null
                                : () {
                              setState(() {
                                _currentStep--;
                                _errorMessage = null;
                              });
                              _saveDraftState();
                            },
                            child: const Text('Back'),
                          ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _currentStep == 2 ? ParishColors.oliveGreen : ParishColors.marianBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                          ),
                          onPressed: _isSearching || _isSubmitting
                              ? null
                              : () {
                            if (_currentStep == 0) {
                              _handleSearchRecord();
                            } else if (_currentStep == 1) {
                              setState(() {
                                _currentStep = 2;
                                _errorMessage = null;
                              });
                              _saveDraftState();
                            } else {
                              _handleSubmitRequest();
                            }
                          },
                          icon: _isSearching || _isSubmitting
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Icon(_currentStep == 2 ? Icons.check_circle : Icons.arrow_forward, size: 18),
                          label: Text(
                            _isSearching
                                ? 'Matching...'
                                : (_isSubmitting
                                ? 'Submitting...'
                                : (_currentStep == 0
                                ? 'Match Record'
                                : (_currentStep == 1 ? 'Proceed to Requestor Details' : 'Submit Request'))),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // UI Builder: Single Recipient Form (Baptism, Confirmation, Death, etc.)
  // ===========================================================================
  Widget _buildSingleRecipientFormSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // One Single Full Name Field
        _buildFieldLabel('Recipient / Subject Full Name', isRequired: true),
        TextFormField(
          controller: _recipientFullNameController,
          maxLength: 80,
          buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r"[a-zA-ZÀ-ÿÑñ\s\.\-\'’]")),
            _TitleCaseInputFormatter(),
          ],
          validator: (v) => _validateNameField(v, 'Recipient full name', isRequired: true, min: 2, max: 80),
          onChanged: (_) => _saveDraftState(),
          style: const TextStyle(fontSize: 14),
          decoration: _inputDecoration(hint: 'e.g. Juan Mendoza Dela Cruz'),
        ),
        const SizedBox(height: 14),

        // Birthdate (Visually and strictly marked as Required)
        _buildFieldLabel('Birthdate', isRequired: true),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _birthDate ?? DateTime(2000, 1, 1),
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
            );
            if (picked != null) {
              setState(() => _birthDate = picked);
              _saveDraftState();
            }
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: ParishColors.backgroundLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ParishColors.borderGrey),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _birthDate != null ? _birthDate!.toIso8601String().substring(0, 10) : 'YYYY-MM-DD',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: _birthDate != null ? FontWeight.bold : FontWeight.normal,
                    color: _birthDate != null ? ParishColors.textDark : ParishColors.textMuted,
                  ),
                ),
                const Icon(Icons.calendar_month, size: 18, color: ParishColors.marianBlue),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Possible Date of Sacrament (Optional)
        _buildFieldLabel('Possible Date of Sacrament (Optional)', isRequired: false),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _possibleSacramentDate ?? DateTime.now(),
              firstDate: DateTime(1900),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) {
              setState(() => _possibleSacramentDate = picked);
              _saveDraftState();
            }
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: ParishColors.backgroundLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ParishColors.borderGrey),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _possibleSacramentDate != null
                      ? _possibleSacramentDate!.toIso8601String().substring(0, 10)
                      : 'Approximate celebration date (if known)',
                  style: TextStyle(
                    fontSize: 13,
                    color: _possibleSacramentDate != null ? ParishColors.textDark : ParishColors.textMuted,
                  ),
                ),
                const Icon(Icons.event_outlined, size: 18, color: ParishColors.marianBlue),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),

        // Mother: 3 Separate Fields
        const Text(
          "Mother's Information",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: ParishColors.marianBlue),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _motherFirstNameController,
                maxLength: 50,
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                inputFormatters: [_TitleCaseInputFormatter()],
                validator: (v) => _validateNameField(v, "Mother's first name", isRequired: false),
                onChanged: (_) => _saveDraftState(),
                decoration: _inputDecoration(labelText: "Mother's First Name"),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _motherMiddleNameController,
                maxLength: 50,
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                inputFormatters: [_TitleCaseInputFormatter()],
                onChanged: (_) => _saveDraftState(),
                decoration: _inputDecoration(labelText: 'Middle Name'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _motherLastNameController,
                maxLength: 50,
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                inputFormatters: [_TitleCaseInputFormatter()],
                validator: (v) => _validateNameField(v, "Mother's maiden last name", isRequired: false),
                onChanged: (_) => _saveDraftState(),
                decoration: _inputDecoration(labelText: 'Maiden Last Name'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Father: 3 Separate Fields
        const Text(
          "Father's Information",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: ParishColors.marianBlue),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _fatherFirstNameController,
                maxLength: 50,
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                inputFormatters: [_TitleCaseInputFormatter()],
                validator: (v) => _validateNameField(v, "Father's first name", isRequired: false),
                onChanged: (_) => _saveDraftState(),
                decoration: _inputDecoration(labelText: "Father's First Name"),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _fatherMiddleNameController,
                maxLength: 50,
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                inputFormatters: [_TitleCaseInputFormatter()],
                onChanged: (_) => _saveDraftState(),
                decoration: _inputDecoration(labelText: 'Middle Name'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _fatherLastNameController,
                maxLength: 50,
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                inputFormatters: [_TitleCaseInputFormatter()],
                validator: (v) => _validateNameField(v, "Father's last name", isRequired: false),
                onChanged: (_) => _saveDraftState(),
                decoration: _inputDecoration(labelText: "Father's Last Name"),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ===========================================================================
  // UI Builder: Clearly Separated Marriage Form (Bride vs Groom)
  // ===========================================================================
  Widget _buildMarriageFormSection() {
    final borderGrey = ParishColors.borderGrey;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Groom Container
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ParishColors.backgroundLight,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderGrey),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(color: Color(0xFF164E87), shape: BoxShape.circle),
                    child: const Icon(Icons.male, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 8),
                  const Text("Groom's Information", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF164E87))),
                ],
              ),
              const Divider(height: 20),
              _buildFieldLabel("Groom's Full Name", isRequired: true),
              TextFormField(
                controller: _groomFullNameController,
                maxLength: 80,
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                inputFormatters: [_TitleCaseInputFormatter()],
                validator: (v) => _selectedSacrament == 'Matrimony' ? _validateNameField(v, "Groom's full name", isRequired: true) : null,
                onChanged: (_) => _saveDraftState(),
                decoration: _inputDecoration(hint: 'First Name, Middle Name, Last Name'),
              ),
              const SizedBox(height: 12),
              _buildFieldLabel("Groom's Birthdate", isRequired: true),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _groomBirthDate ?? DateTime(1995, 1, 1),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() => _groomBirthDate = picked);
                    _saveDraftState();
                  }
                },
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderGrey),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _groomBirthDate != null ? _groomBirthDate!.toIso8601String().substring(0, 10) : 'YYYY-MM-DD',
                        style: TextStyle(fontSize: 13, color: _groomBirthDate != null ? ParishColors.textDark : ParishColors.textMuted),
                      ),
                      const Icon(Icons.calendar_today, size: 16, color: ParishColors.marianBlue),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text("Groom's Mother (3 Separate Fields)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(child: TextFormField(controller: _groomMotherFirstNameController, onChanged: (_) => _saveDraftState(), decoration: _inputDecoration(labelText: 'First Name'))),
                  const SizedBox(width: 6),
                  Expanded(child: TextFormField(controller: _groomMotherMiddleNameController, onChanged: (_) => _saveDraftState(), decoration: _inputDecoration(labelText: 'Middle Name'))),
                  const SizedBox(width: 6),
                  Expanded(child: TextFormField(controller: _groomMotherLastNameController, onChanged: (_) => _saveDraftState(), decoration: _inputDecoration(labelText: 'Maiden Last'))),
                ],
              ),
              const SizedBox(height: 12),
              const Text("Groom's Father (3 Separate Fields)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(child: TextFormField(controller: _groomFatherFirstNameController, onChanged: (_) => _saveDraftState(), decoration: _inputDecoration(labelText: 'First Name'))),
                  const SizedBox(width: 6),
                  Expanded(child: TextFormField(controller: _groomFatherMiddleNameController, onChanged: (_) => _saveDraftState(), decoration: _inputDecoration(labelText: 'Middle Name'))),
                  const SizedBox(width: 6),
                  Expanded(child: TextFormField(controller: _groomFatherLastNameController, onChanged: (_) => _saveDraftState(), decoration: _inputDecoration(labelText: 'Last Name'))),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Bride Container
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ParishColors.backgroundLight,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderGrey),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(color: Color(0xFF9D174D), shape: BoxShape.circle),
                    child: const Icon(Icons.female, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 8),
                  const Text("Bride's Information", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF9D174D))),
                ],
              ),
              const Divider(height: 20),
              _buildFieldLabel("Bride's Full Name", isRequired: true),
              TextFormField(
                controller: _brideFullNameController,
                maxLength: 80,
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                inputFormatters: [_TitleCaseInputFormatter()],
                validator: (v) => _selectedSacrament == 'Matrimony' ? _validateNameField(v, "Bride's full name", isRequired: true) : null,
                onChanged: (_) => _saveDraftState(),
                decoration: _inputDecoration(hint: 'First Name, Middle Name, Maiden Last Name'),
              ),
              const SizedBox(height: 12),
              _buildFieldLabel("Bride's Birthdate", isRequired: true),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _brideBirthDate ?? DateTime(1997, 1, 1),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() => _brideBirthDate = picked);
                    _saveDraftState();
                  }
                },
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderGrey),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _brideBirthDate != null ? _brideBirthDate!.toIso8601String().substring(0, 10) : 'YYYY-MM-DD',
                        style: TextStyle(fontSize: 13, color: _brideBirthDate != null ? ParishColors.textDark : ParishColors.textMuted),
                      ),
                      const Icon(Icons.calendar_today, size: 16, color: ParishColors.marianBlue),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text("Bride's Mother (3 Separate Fields)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(child: TextFormField(controller: _brideMotherFirstNameController, onChanged: (_) => _saveDraftState(), decoration: _inputDecoration(labelText: 'First Name'))),
                  const SizedBox(width: 6),
                  Expanded(child: TextFormField(controller: _brideMotherMiddleNameController, onChanged: (_) => _saveDraftState(), decoration: _inputDecoration(labelText: 'Middle Name'))),
                  const SizedBox(width: 6),
                  Expanded(child: TextFormField(controller: _brideMotherLastNameController, onChanged: (_) => _saveDraftState(), decoration: _inputDecoration(labelText: 'Maiden Last'))),
                ],
              ),
              const SizedBox(height: 12),
              const Text("Bride's Father (3 Separate Fields)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(child: TextFormField(controller: _brideFatherFirstNameController, onChanged: (_) => _saveDraftState(), decoration: _inputDecoration(labelText: 'First Name'))),
                  const SizedBox(width: 6),
                  Expanded(child: TextFormField(controller: _brideFatherMiddleNameController, onChanged: (_) => _saveDraftState(), decoration: _inputDecoration(labelText: 'Middle Name'))),
                  const SizedBox(width: 6),
                  Expanded(child: TextFormField(controller: _brideFatherLastNameController, onChanged: (_) => _saveDraftState(), decoration: _inputDecoration(labelText: 'Last Name'))),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Date of Marriage (Optional)
        _buildFieldLabel('Possible Date of Marriage (Optional)', isRequired: false),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _marriageDate ?? DateTime.now(),
              firstDate: DateTime(1900),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) {
              setState(() => _marriageDate = picked);
              _saveDraftState();
            }
          },
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: ParishColors.backgroundLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderGrey),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _marriageDate != null ? _marriageDate!.toIso8601String().substring(0, 10) : 'YYYY-MM-DD (if known)',
                  style: TextStyle(fontSize: 13, color: _marriageDate != null ? ParishColors.textDark : ParishColors.textMuted),
                ),
                const Icon(Icons.event, size: 18, color: ParishColors.marianBlue),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // UI Builder: Step 1 - Affirmative Record Found State
  // ===========================================================================
  Widget _buildRecordFoundState() {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ParishColors.oliveGreen, width: 2.0),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: ParishColors.oliveGreenSurface, shape: BoxShape.circle),
            child: const Icon(Icons.verified_outlined, size: 48, color: ParishColors.oliveGreen),
          ),
          const SizedBox(height: 16),
          Text(
            'Matching Sacramental Record Found!',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Your submitted details successfully match an official $_selectedSacrament entry in the parish registry.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: textMuted, height: 1.4),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ParishColors.backgroundLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ParishColors.borderGrey),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check, size: 16, color: ParishColors.oliveGreen),
                    const SizedBox(width: 6),
                    Text('Certificate: $_selectedSacrament Certificate', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Subject: ${_matchedRecord?.recipientName ?? _recipientFullNameController.text}',
                  style: TextStyle(fontSize: 12.5, color: textDark),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Click below to proceed to the Requestor Information and ID verification section.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: textMuted),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // UI Builder: Step 2 - Requestor Information & Valid ID Upload
  // ===========================================================================
  Widget _buildRequestorInfoSection() {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final borderGrey = ParishColors.borderGrey;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel("Requestor's Full Name", isRequired: true),
        TextFormField(
          controller: _requestorFullNameController,
          maxLength: 80,
          buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
          inputFormatters: [_TitleCaseInputFormatter()],
          validator: (v) => _validateNameField(v, "Requestor's full name", isRequired: true, min: 2, max: 80),
          onChanged: (_) => _saveDraftState(),
          style: const TextStyle(fontSize: 14),
          decoration: _inputDecoration(hint: 'First Name, Middle Name, Last Name'),
        ),
        const SizedBox(height: 14),

        _buildFieldLabel('Relationship to Recipient / Subject', isRequired: true),
        DropdownButtonFormField<String>(
          value: _relationshipToRecipient,
          isExpanded: true,
          decoration: _inputDecoration(),
          items: _relationshipOptions.map((rel) {
            return DropdownMenuItem(value: rel, child: Text(rel, style: const TextStyle(fontSize: 13.5)));
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() => _relationshipToRecipient = val);
              _saveDraftState();
            }
          },
        ),
        const SizedBox(height: 14),

        _buildFieldLabel('Contact Number for Office Updates', isRequired: true),
        TextFormField(
          controller: _contactNumberController,
          keyboardType: TextInputType.phone,
          maxLength: 13,
          buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            _PhilippinePhoneInputFormatter(),
          ],
          validator: (v) {
            final t = v?.replaceAll(RegExp(r'\D'), '') ?? '';
            if (t.isEmpty) return 'Contact number is required.';
            if (t.length != 11) return 'Must be a valid 11-digit mobile number (e.g. 0917-123-4567).';
            return null;
          },
          onChanged: (_) => _saveDraftState(),
          style: const TextStyle(fontSize: 14),
          decoration: _inputDecoration(hint: '09XX-XXX-XXXX'),
        ),
        const SizedBox(height: 14),

        _buildFieldLabel('Purpose of Request', isRequired: true),
        TextFormField(
          controller: _purposeController,
          maxLines: 2,
          maxLength: 200,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Please specify the purpose.' : null,
          onChanged: (_) => _saveDraftState(),
          style: const TextStyle(fontSize: 13),
          decoration: _inputDecoration(hint: 'e.g. Marriage banns, School enrollment, Passport, Legal records'),
        ),
        const SizedBox(height: 18),

        // Valid Government ID Upload Box
        _buildFieldLabel('Valid Government / Official ID', isRequired: true),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _attachedIdBytes != null ? ParishColors.oliveGreenSurface : ParishColors.backgroundLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _attachedIdBytes != null ? ParishColors.oliveGreen : borderGrey,
              width: _attachedIdBytes != null ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        _attachedIdBytes != null ? Icons.verified : Icons.badge_outlined,
                        color: _attachedIdBytes != null ? ParishColors.oliveGreen : ParishColors.marianBlue,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _attachedIdBytes != null ? 'Official ID Attached' : 'Attach Government / Official ID *',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _attachedIdBytes != null ? ParishColors.oliveGreen : textDark,
                        ),
                      ),
                    ],
                  ),
                  if (_attachedIdBytes != null)
                    IconButton(
                      icon: const Icon(Icons.close, size: 18, color: ParishColors.mercyRed),
                      onPressed: _clearAttachedId,
                      tooltip: 'Remove Attachment',
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                ],
              ),
              const SizedBox(height: 6),
              if (_attachedIdBytes == null) ...[
                Text(
                  'Upload a clear photo or copy of your valid government ID (Passport, UMID, PhilID, Driver\'s License). Max size: 5MB.',
                  style: TextStyle(fontSize: 11.5, color: textMuted, height: 1.35),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 40,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: ParishColors.marianBlue),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _pickIdDocument,
                    icon: const Icon(Icons.upload_file, size: 16),
                    label: const Text('Select ID Document / Image', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              ] else ...[
                Row(
                  children: [
                    const Icon(Icons.insert_drive_file, size: 16, color: ParishColors.oliveGreen),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${_attachedIdFileName ?? "valid_id.jpg"} (${((_attachedIdFileSize ?? 0) / 1024).toStringAsFixed(1)} KB)',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ParishColors.oliveGreen),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // Helpers
  // ===========================================================================

  Widget _buildFieldLabel(String label, {bool isRequired = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5.0),
      child: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ParishColors.textDark),
          children: [
            TextSpan(text: label),
            if (isRequired)
              const TextSpan(
                text: ' *',
                style: TextStyle(color: ParishColors.mercyRed, fontWeight: FontWeight.bold),
              ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint, String? labelText}) {
    return InputDecoration(
      hintText: hint,
      labelText: labelText,
      filled: true,
      fillColor: ParishColors.backgroundLight,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: ParishColors.borderGrey),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: ParishColors.borderGrey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: ParishColors.marianBlue, width: 1.8),
      ),
    );
  }
}