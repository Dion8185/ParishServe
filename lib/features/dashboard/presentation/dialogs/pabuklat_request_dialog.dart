// =============================================================================
// FILE: lib/features/dashboard/presentation/dialogs/pabuklat_request_dialog.dart
// =============================================================================

import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../auth/services/auth_service.dart';
import '../../../sacramental_records/services/pabuklat_service.dart';

void showPabuklatRequestModal(BuildContext context, {VoidCallback? onRequestSaved}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _PabuklatRequestDialog(onRequestSaved: onRequestSaved),
  );
}

class _PabuklatRequestDialog extends StatefulWidget {
  final VoidCallback? onRequestSaved;

  const _PabuklatRequestDialog({this.onRequestSaved});

  @override
  State<_PabuklatRequestDialog> createState() => _PabuklatRequestDialogState();
}

class _PabuklatRequestDialogState extends State<_PabuklatRequestDialog> {
  final _formKey = GlobalKey<FormState>();

  // Wizard Step: 0 = Search Criteria Input, 1 = Matching Results Selection, 2 = Final Purpose & Contact Confirmation
  int _wizardStep = 0;

  String _selectedSacrament = 'Baptism';
  final List<String> _sacramentOptions = [
    'Baptism',
    'Confirmation',
    'Matrimony',
    'Death',
  ];

  // Search Fields (Standard Baptized / Confirmand / Deceased / Convert)
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();

  // Matrimony Specific Search Fields
  final _groomFirstNameController = TextEditingController();
  final _groomMiddleNameController = TextEditingController();
  final _groomLastNameController = TextEditingController();
  final _brideFirstNameController = TextEditingController();
  final _brideMiddleNameController = TextEditingController();
  final _brideLastNameController = TextEditingController();

  // Parents Search Fields
  final _fatherNameController = TextEditingController();
  final _motherNameController = TextEditingController();

  DateTime? _searchBirthDate;
  DateTime? _searchSacramentDate;

  // Final Confirmation Fields
  final _contactNumberController = TextEditingController();
  final _purposeController = TextEditingController();

  bool _isSearching = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  List<SacramentMatchResult> _searchResults = [];
  SacramentMatchResult? _selectedMatch;

  @override
  void initState() {
    super.initState();
    final user = AuthService.currentUser;
    if (user != null) {
      // Pre-fill contact if stored or known
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _groomFirstNameController.dispose();
    _groomMiddleNameController.dispose();
    _groomLastNameController.dispose();
    _brideFirstNameController.dispose();
    _brideMiddleNameController.dispose();
    _brideLastNameController.dispose();
    _fatherNameController.dispose();
    _motherNameController.dispose();
    _contactNumberController.dispose();
    _purposeController.dispose();
    super.dispose();
  }

  Future<void> _performRecordSearch() async {
    setState(() {
      _errorMessage = null;
      _isSearching = true;
    });

    try {
      final results = await PabuklatService.searchRecordsForRequest(
        sacramentType: _selectedSacrament,
        firstName: _firstNameController.text.trim(),
        middleName: _middleNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        groomFirstName: _groomFirstNameController.text.trim(),
        groomMiddleName: _groomMiddleNameController.text.trim(),
        groomLastName: _groomLastNameController.text.trim(),
        brideFirstName: _brideFirstNameController.text.trim(),
        brideMiddleName: _brideMiddleNameController.text.trim(),
        brideLastName: _brideLastNameController.text.trim(),
        fatherName: _fatherNameController.text.trim(),
        motherName: _motherNameController.text.trim(),
        birthDate: _searchBirthDate,
        sacramentDate: _searchSacramentDate,
      );

      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _isSearching = false;
        _wizardStep = 1; // Move to Results Selection step
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isSearching = false;
      });
    }
  }

  Future<void> _submitRequest() async {
    setState(() => _errorMessage = null);

    if (_selectedMatch == null) {
      setState(() => _errorMessage = 'Please select your matching sacramental record.');
      return;
    }

    if (_purposeController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please specify the purpose of your request.');
      return;
    }

    if (_contactNumberController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Contact number is required for office updates.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final match = _selectedMatch!;
      final summary = 'Record: ${match.fullName} (${match.sacramentType}) • Ref: ${match.bookRef} • Date: ${match.dateOfSacrament}';

      final requesterFullName = AuthService.currentUser?.fullName ?? 'Parishioner Client';

      await PabuklatService.createPabuklatRequest(
        sacramentType: match.sacramentType,
        recordId: match.recordId,
        matchedRecordSummary: summary,
        requesterName: requesterFullName,
        contactNumber: _contactNumberController.text.trim(),
        purpose: _purposeController.text.trim(),
      );

      if (!mounted) return;

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pabuklat request submitted successfully! Pending Secretary review.'),
          backgroundColor: ParishColors.oliveGreen,
          duration: Duration(seconds: 4),
        ),
      );

      widget.onRequestSaved?.call();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _pickSearchDate(bool isBirthDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isBirthDate) {
          _searchBirthDate = picked;
        } else {
          _searchSacramentDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final cardWhite = ParishColors.cardWhite;
    final borderGrey = ParishColors.borderGrey;
    final bool isMarriage = _selectedSacrament == 'Matrimony';

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: cardWhite,
      child: Container(
        width: double.maxFinite,
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 740),
        child: Column(
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: ParishColors.marianBlueSurface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                        Text('Request Sacramental Record', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDark)),
                        Text('Pabuklat / Certificate Request Wizard (Step ${_wizardStep + 1} of 3)', style: TextStyle(fontSize: 12, color: textMuted)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Step Content Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: ParishColors.mercyRedSurface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: ParishColors.mercyRed),
                          ),
                          child: Text(_errorMessage!, style: const TextStyle(color: ParishColors.mercyRed, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],

                      if (_wizardStep == 0) ...[
                        // WIZARD STEP 1: Search Criteria Form
                        Text('Select Sacrament Type *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _selectedSacrament,
                          items: _sacramentOptions.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 14)))).toList(),
                          onChanged: (val) => setState(() => _selectedSacrament = val!),
                          decoration: _inputDecoration(),
                        ),
                        const SizedBox(height: 14),

                        if (isMarriage) ...[
                          // Dynamic Marriage Inputs: Groom & Bride separated into First, Middle, Last
                          const Text('Groom Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ParishColors.marianBlue)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(child: TextFormField(controller: _groomFirstNameController, decoration: _inputDecoration(labelText: "Groom's First Name"))),
                              const SizedBox(width: 8),
                              Expanded(child: TextFormField(controller: _groomMiddleNameController, decoration: _inputDecoration(labelText: "Groom's Middle Name"))),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextFormField(controller: _groomLastNameController, decoration: _inputDecoration(labelText: "Groom's Last Name")),
                          const SizedBox(height: 14),

                          const Text('Bride Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ParishColors.marianBlue)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(child: TextFormField(controller: _brideFirstNameController, decoration: _inputDecoration(labelText: "Bride's First Name"))),
                              const SizedBox(width: 8),
                              Expanded(child: TextFormField(controller: _brideMiddleNameController, decoration: _inputDecoration(labelText: "Bride's Middle Name"))),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextFormField(controller: _brideLastNameController, decoration: _inputDecoration(labelText: "Bride's Last Name / Maiden Name")),
                        ] else ...[
                          // Standard Sacrament Inputs: First Name, Middle Name, Last Name Separately
                          const Text('Name on Record', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ParishColors.marianBlue)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _firstNameController,
                                  validator: (v) => (v?.trim().isEmpty ?? true) ? 'First name required' : null,
                                  decoration: _inputDecoration(labelText: 'First Name *'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: _middleNameController,
                                  decoration: _inputDecoration(labelText: 'Middle Name'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _lastNameController,
                            validator: (v) => (v?.trim().isEmpty ?? true) ? 'Last name required' : null,
                            decoration: _inputDecoration(labelText: 'Last Name *'),
                          ),
                          const SizedBox(height: 14),

                          // Properly Labeled Parent Names
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _fatherNameController,
                                  decoration: _inputDecoration(labelText: "Father's Full Name"),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: _motherNameController,
                                  decoration: _inputDecoration(labelText: "Mother's Maiden Name"),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 14),

                        // Date Pickers for Birthdate and Possible Sacrament Date
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Birthdate (Optional)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: textDark)),
                                  const SizedBox(height: 6),
                                  InkWell(
                                    onTap: () => _pickSearchDate(true),
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: ParishColors.backgroundLight,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: borderGrey),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            _searchBirthDate != null ? _searchBirthDate!.toIso8601String().substring(0, 10) : 'Select Birthdate',
                                            style: TextStyle(fontSize: 13, color: _searchBirthDate != null ? textDark : textMuted),
                                          ),
                                          const Icon(Icons.calendar_today, size: 16, color: ParishColors.marianBlue),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Possible Sacrament Date', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: textDark)),
                                  const SizedBox(height: 6),
                                  InkWell(
                                    onTap: () => _pickSearchDate(false),
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: ParishColors.backgroundLight,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: borderGrey),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            _searchSacramentDate != null ? _searchSacramentDate!.toIso8601String().substring(0, 10) : 'Select Date',
                                            style: TextStyle(fontSize: 13, color: _searchSacramentDate != null ? textDark : textMuted),
                                          ),
                                          const Icon(Icons.calendar_today, size: 16, color: ParishColors.marianBlue),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ] else if (_wizardStep == 1) ...[
                        // WIZARD STEP 2: Matching Results Selection
                        Text('Matching Records Found (${_searchResults.length})', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textDark)),
                        const SizedBox(height: 4),
                        Text('Select the correct record matching your information from the parish archives:', style: TextStyle(fontSize: 12, color: textMuted)),
                        const SizedBox(height: 12),

                        if (_searchResults.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: ParishColors.backgroundLight,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: borderGrey),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.search_off, size: 36, color: ParishColors.mercyRed),
                                const SizedBox(height: 8),
                                const Text('No matching records found based on provided fields.', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text('Try adjusting your search names or clearing optional dates.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: textMuted)),
                              ],
                            ),
                          )
                        else
                          ..._searchResults.map((match) {
                            final isSelected = _selectedMatch?.recordId == match.recordId;
                            return InkWell(
                              onTap: () => setState(() => _selectedMatch = match),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isSelected ? ParishColors.marianBlueSurface : ParishColors.backgroundLight,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? ParishColors.marianBlue : borderGrey,
                                    width: isSelected ? 2.0 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Radio<SacramentMatchResult>(
                                      value: match,
                                      groupValue: _selectedMatch,
                                      activeColor: ParishColors.marianBlue,
                                      onChanged: (val) => setState(() => _selectedMatch = val),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(match.fullName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: textDark)),
                                          const SizedBox(height: 2),
                                          Text('${match.sacramentType} • Date: ${match.dateOfSacrament}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ParishColors.marianBlue)),
                                          Text(match.parentage, style: TextStyle(fontSize: 11.5, color: textMuted)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                      ] else ...[
                        // WIZARD STEP 3: Purpose & Contact Confirmation
                        Text('Confirm Request Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textDark)),
                        const SizedBox(height: 12),

                        if (_selectedMatch != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: ParishColors.oliveGreenSurface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: ParishColors.oliveGreen.withOpacity(0.4)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('SELECTED MATCHED RECORD:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ParishColors.oliveGreen)),
                                Text(_selectedMatch!.fullName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textDark)),
                                Text('${_selectedMatch!.sacramentType} • Date: ${_selectedMatch!.dateOfSacrament}', style: TextStyle(fontSize: 12, color: textMuted)),
                              ],
                            ),
                          ),
                        const SizedBox(height: 14),

                        Text('Contact Number for Office Updates *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _contactNumberController,
                          keyboardType: TextInputType.phone,
                          validator: (v) => (v?.trim().isEmpty ?? true) ? 'Contact number required' : null,
                          decoration: _inputDecoration(hint: '09XX-XXX-XXXX'),
                        ),
                        const SizedBox(height: 14),

                        Text('Purpose of Certificate Request *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _purposeController,
                          maxLines: 2,
                          validator: (v) => (v?.trim().isEmpty ?? true) ? 'Purpose required' : null,
                          decoration: _inputDecoration(hint: 'e.g. For Marriage Requirements, Employment, School'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Actions Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: cardWhite,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                border: Border(top: BorderSide(color: borderGrey)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_wizardStep > 0)
                    TextButton(
                      onPressed: () => setState(() => _wizardStep--),
                      child: const Text('Back'),
                    )
                  else
                    TextButton(
                      onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                      child: Text('Cancel', style: TextStyle(color: textMuted)),
                    ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ParishColors.marianBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isSearching || _isSubmitting
                          ? null
                          : () {
                        if (_wizardStep == 0) {
                          if (isMarriage) {
                            if (_groomLastNameController.text.trim().isEmpty && _brideLastNameController.text.trim().isEmpty) {
                              setState(() => _errorMessage = "Please enter Groom's or Bride's last name for marriage search.");
                              return;
                            }
                          } else {
                            if (_lastNameController.text.trim().isEmpty) {
                              setState(() => _errorMessage = 'Last name is required for search.');
                              return;
                            }
                          }
                          _performRecordSearch();
                        } else if (_wizardStep == 1) {
                          if (_selectedMatch == null) {
                            setState(() => _errorMessage = 'Please select a matching record.');
                            return;
                          }
                          setState(() {
                            _errorMessage = null;
                            _wizardStep = 2;
                          });
                        } else {
                          _submitRequest();
                        }
                      },
                      icon: _isSearching || _isSubmitting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Icon(_wizardStep == 2 ? Icons.send : Icons.arrow_forward, size: 18),
                      label: Text(
                        _isSearching
                            ? 'Searching...'
                            : (_isSubmitting
                            ? 'Submitting...'
                            : (_wizardStep == 2 ? 'Submit Request' : 'Next (View Matches)')),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
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
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ParishColors.borderGrey)),
    );
  }
}