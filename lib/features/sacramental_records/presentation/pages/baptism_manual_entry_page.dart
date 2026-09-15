import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../services/baptism_service.dart';

class BaptismManualEntryPage extends StatefulWidget {
  final VoidCallback? onRecordSaved;

  const BaptismManualEntryPage({super.key, this.onRecordSaved});

  @override
  State<BaptismManualEntryPage> createState() => _BaptismManualEntryPageState();
}

class _BaptismManualEntryPageState extends State<BaptismManualEntryPage> {
  final _formKey = GlobalKey<FormState>();

  // Canonical options for Legitimacy
  static const List<String> _canonicalStatusOptions = [
    'Natural (Nat.)',
    'Catholic (Cath.)',
    'Aglipay (Agl.)',
    'Protestant (Prot.)',
    'Civil (Civ.)',
    'Others (Specify)',
  ];

  // 1. Record Reference
  final _bookNumberController = TextEditingController();
  final _pageNumberController = TextEditingController();
  final _lineNumberController = TextEditingController();

  // 2. Child Information
  final _childFirstNameController = TextEditingController();
  final _childMiddleNameController = TextEditingController();
  final _childLastNameController = TextEditingController();
  final _childSuffixController = TextEditingController();
  DateTime? _dateOfBirth;
  final _ageController = TextEditingController();
  final _placeOfBirthController = TextEditingController();
  final _legitimacyOtherController = TextEditingController();

  // 3. Father Information
  final _fatherFirstNameController = TextEditingController();
  final _fatherMiddleNameController = TextEditingController();
  final _fatherLastNameController = TextEditingController();
  final _fatherPlaceOfBirthController = TextEditingController();

  // 4. Mother Information
  final _motherFirstNameController = TextEditingController();
  final _motherMiddleNameController = TextEditingController();
  final _motherMaidenLastNameController = TextEditingController();
  final _motherPlaceOfBirthController = TextEditingController();

  // 5. Parents Information
  final _parentsContactNumberController = TextEditingController();
  final _parentsResidenceController = TextEditingController();

  // 6. Sponsors Information
  final _sponsor1FirstNameController = TextEditingController();
  final _sponsor1MiddleNameController = TextEditingController();
  final _sponsor1LastNameController = TextEditingController();
  final _sponsor1ResidenceController = TextEditingController();

  final _sponsor2FirstNameController = TextEditingController();
  final _sponsor2MiddleNameController = TextEditingController();
  final _sponsor2LastNameController = TextEditingController();
  final _sponsor2ResidenceController = TextEditingController();

  final _otherGodparentsController = TextEditingController();

  // 7. Baptism Information
  final _parishNameController = TextEditingController(text: 'St. John Paul II Parish');
  final _ministerFirstNameController = TextEditingController(text: 'Joseph');
  final _ministerMiddleNameController = TextEditingController();
  final _ministerLastNameController = TextEditingController(text: 'Santos');
  DateTime? _dateOfBaptism = DateTime.now();
  final _placeOfBaptismController = TextEditingController(text: 'St. John Paul II Parish');
  String _gender = 'Male';
  String _legitimacy = 'Natural (Nat.)';
  final _stipendController = TextEditingController();
  final _remarksController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;
  bool _dateOfBirthHasError = false;
  bool _dateOfBaptismHasError = false;

  @override
  void dispose() {
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
    _otherGodparentsController.dispose();
    _parishNameController.dispose();
    _ministerFirstNameController.dispose();
    _ministerMiddleNameController.dispose();
    _ministerLastNameController.dispose();
    _placeOfBaptismController.dispose();
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
      if (isRequired) {
        return '$fieldName is required.';
      }
      return null;
    }
    if (text.length < 2) {
      return '$fieldName must be at least 2 characters.';
    }
    final nameRegExp = RegExp(r"^[a-zA-ZÀ-ÿÑñ\s\.\-\'’]+$");
    if (!nameRegExp.hasMatch(text)) {
      return 'Enter a valid name (letters only).';
    }
    return null;
  }

  String? _validateRequiredText(String? value, String fieldName) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return '$fieldName is required.';
    }
    if (text.length < 2) {
      return '$fieldName must be at least 2 characters.';
    }
    return null;
  }

  String? _validatePhoneNumber(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null; // Optional field

    final clean = text.replaceAll(RegExp(r'[\s\-]'), '');
    final phoneRegExp = RegExp(r'^(09\d{9}|\+639\d{9}|\d{7,10})$');
    if (!phoneRegExp.hasMatch(clean)) {
      return 'Enter a valid phone number (e.g., 09171234567).';
    }
    return null;
  }

  String? _validateStipend(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null; // Optional field

    final amount = double.tryParse(text);
    if (amount == null || amount < 0) {
      return 'Enter a valid amount (e.g., 150.00).';
    }
    return null;
  }

  Future<void> _selectDate(BuildContext context, bool isBirthDate) async {
    final now = DateTime.now();
    final initialDate = isBirthDate ? (_dateOfBirth ?? DateTime(now.year, 1, 1)) : (_dateOfBaptism ?? now);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(now) ? now : initialDate,
      firstDate: DateTime(1900),
      lastDate: isBirthDate ? now : now.add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        if (isBirthDate) {
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

  Future<void> _submitForm() async {
    setState(() {
      _errorMessage = null;
      _dateOfBirthHasError = _dateOfBirth == null;
      _dateOfBaptismHasError = _dateOfBaptism == null;
    });

    final isFormValid = _formKey.currentState!.validate();

    if (!isFormValid || _dateOfBirthHasError || _dateOfBaptismHasError) {
      setState(() {
        _errorMessage = 'Please check and complete all required fields.';
      });
      return;
    }

    if (_dateOfBirth != null && _dateOfBirth!.isAfter(DateTime.now())) {
      setState(() {
        _dateOfBirthHasError = true;
        _errorMessage = 'Date of Birth cannot be in the future.';
      });
      return;
    }

    if (_dateOfBirth != null && _dateOfBaptism != null && _dateOfBaptism!.isBefore(_dateOfBirth!)) {
      setState(() {
        _dateOfBaptismHasError = true;
        _errorMessage = 'Date of Baptism cannot be earlier than Date of Birth.';
      });
      return;
    }

    final String finalLegitimacy = _legitimacy == 'Others (Specify)'
        ? (_legitimacyOtherController.text.trim().isNotEmpty
        ? 'Others (${_legitimacyOtherController.text.trim()})'
        : 'Others')
        : _legitimacy;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final recordMap = {
        'book_number': _bookNumberController.text.trim(),
        'page_number': _pageNumberController.text.trim(),
        'line_number': _lineNumberController.text.trim(),

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

        'other_godparents': _otherGodparentsController.text.trim().isEmpty ? null : _otherGodparentsController.text.trim(),

        'parish_name': _parishNameController.text.trim(),

        'minister_first_name': _ministerFirstNameController.text.trim(),
        'minister_middle_name': _ministerMiddleNameController.text.trim().isEmpty ? null : _ministerMiddleNameController.text.trim(),
        'minister_last_name': _ministerLastNameController.text.trim(),

        'date_of_baptism': _dateOfBaptism!.toIso8601String().substring(0, 10),
        'place_of_baptism': _placeOfBaptismController.text.trim(),
        'stipend': _stipendController.text.trim().isNotEmpty ? double.tryParse(_stipendController.text.trim()) : null,
        'remarks': _remarksController.text.trim().isEmpty ? null : _remarksController.text.trim(),
      };

      await BaptismService.insertManualBaptismRecord(recordMap);

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Baptism record registered successfully.'),
          backgroundColor: ParishColors.oliveGreen,
          duration: Duration(seconds: 3),
        ),
      );

      if (widget.onRecordSaved != null) {
        widget.onRecordSaved!();
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textDarkColor = ParishColors.textDark;
    final textMutedColor = ParishColors.textMuted;
    final cardWhiteColor = ParishColors.cardWhite;
    final borderGreyColor = ParishColors.borderGrey;

    return Scaffold(
      backgroundColor: ParishColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: cardWhiteColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: ParishColors.marianBlue, size: 26),
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Baptism Manual Entry',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDarkColor),
            ),
            Text(
              'Canonical Registry Book (Liber Baptismorum)',
              style: TextStyle(fontSize: 12, color: textMutedColor),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
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

                      // 1. Record Reference
                      _buildSectionCard(
                        title: '1. Canonical Record Reference',
                        icon: Icons.menu_book,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildTextFormField(
                                controller: _bookNumberController,
                                label: 'Book No.',
                                isRequired: true,
                                keyboardType: TextInputType.number,
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) return 'Required';
                                  final num = int.tryParse(val.trim());
                                  if (num == null) return 'Must be a number';
                                  if (num < 1 || num > 200) return '1 to 200 only';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildTextFormField(
                                controller: _pageNumberController,
                                label: 'Page No.',
                                isRequired: true,
                                keyboardType: TextInputType.number,
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) return 'Required';
                                  final num = int.tryParse(val.trim());
                                  if (num == null) return 'Must be a number';
                                  if (num < 1 || num > 100) return '1 to 100 only';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildTextFormField(
                                controller: _lineNumberController,
                                label: 'Line No.',
                                isRequired: true,
                                keyboardType: TextInputType.number,
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) return 'Required';
                                  final num = int.tryParse(val.trim());
                                  if (num == null) return 'Must be a number';
                                  if (num < 1 || num > 10) return '1 to 10 only';
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 2. Child's Information
                      _buildSectionCard(
                        title: "2. Child's Information",
                        icon: Icons.child_care,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: _buildTextFormField(
                                    controller: _childFirstNameController,
                                    label: 'First Name',
                                    isRequired: true,
                                    validator: (val) => _validateName(val, 'First name', isRequired: true),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildTextFormField(
                                    controller: _childMiddleNameController,
                                    label: 'Middle Name',
                                    isRequired: false,
                                    validator: (val) => _validateName(val, 'Middle name', isRequired: false),
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
                                    validator: (val) => _validateName(val, 'Last name', isRequired: true),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildTextFormField(
                                    controller: _childSuffixController,
                                    label: 'Suffix',
                                    isRequired: false,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _buildDatePickerField(
                                    label: 'Date of Birth',
                                    isRequired: true,
                                    value: _dateOfBirth,
                                    hasError: _dateOfBirthHasError,
                                    onTap: () => _selectDate(context, true),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildTextFormField(
                                    controller: _ageController,
                                    label: 'Age',
                                    isRequired: false,
                                  ),
                                ),
                              ],
                            ),
                            _buildTextFormField(
                              controller: _placeOfBirthController,
                              label: 'Place of Birth',
                              isRequired: true,
                              validator: (val) => _validateRequiredText(val, 'Place of birth'),
                            ),
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
                                const SizedBox(width: 8),
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
                      ),
                      const SizedBox(height: 16),

                      // 3. Father Information
                      _buildSectionCard(
                        title: "3. Father's Information",
                        icon: Icons.person,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _buildTextFormField(
                                    controller: _fatherFirstNameController,
                                    label: 'First Name',
                                    isRequired: true,
                                    validator: (val) => _validateName(val, "Father's first name", isRequired: true),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildTextFormField(
                                    controller: _fatherMiddleNameController,
                                    label: 'Middle Name',
                                    isRequired: false,
                                    validator: (val) => _validateName(val, "Father's middle name", isRequired: false),
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
                                    label: 'Last Name',
                                    isRequired: true,
                                    validator: (val) => _validateName(val, "Father's last name", isRequired: true),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildTextFormField(
                                    controller: _fatherPlaceOfBirthController,
                                    label: 'Place of Origin',
                                    isRequired: false,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 4. Mother Information
                      _buildSectionCard(
                        title: "4. Mother's Information",
                        icon: Icons.person_outline,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _buildTextFormField(
                                    controller: _motherFirstNameController,
                                    label: 'First Name',
                                    isRequired: true,
                                    validator: (val) => _validateName(val, "Mother's first name", isRequired: true),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildTextFormField(
                                    controller: _motherMiddleNameController,
                                    label: 'Middle Name',
                                    isRequired: false,
                                    validator: (val) => _validateName(val, "Mother's middle name", isRequired: false),
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
                                    validator: (val) => _validateName(val, "Mother's maiden last name", isRequired: true),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildTextFormField(
                                    controller: _motherPlaceOfBirthController,
                                    label: 'Place of Origin',
                                    isRequired: false,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 5. Parents Contact & Residence
                      _buildSectionCard(
                        title: "5. Parents' Contact & Residence",
                        icon: Icons.home_outlined,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTextFormField(
                              controller: _parentsContactNumberController,
                              label: 'Contact Number',
                              isRequired: false,
                              keyboardType: TextInputType.phone,
                              validator: _validatePhoneNumber,
                            ),
                            _buildTextFormField(
                              controller: _parentsResidenceController,
                              label: 'Parents Residence / Address',
                              isRequired: false,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 6. Sponsors / Godparents
                      _buildSectionCard(
                        title: '6. Godparents / Sponsors',
                        icon: Icons.people_outline,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Canonical entries require Sponsor 1 and Sponsor 2.',
                              style: TextStyle(fontSize: 12, color: ParishColors.marianBlue, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _buildTextFormField(
                                    controller: _sponsor1FirstNameController,
                                    label: 'Sponsor 1 First Name',
                                    isRequired: true,
                                    validator: (val) => _validateName(val, 'Sponsor 1 first name', isRequired: true),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildTextFormField(
                                    controller: _sponsor1MiddleNameController,
                                    label: 'Sponsor 1 Middle Name',
                                    isRequired: false,
                                    validator: (val) => _validateName(val, 'Sponsor 1 middle name', isRequired: false),
                                  ),
                                ),
                              ],
                            ),
                            _buildTextFormField(
                              controller: _sponsor1LastNameController,
                              label: 'Sponsor 1 Last Name',
                              isRequired: true,
                              validator: (val) => _validateName(val, 'Sponsor 1 last name', isRequired: true),
                            ),
                            _buildTextFormField(
                              controller: _sponsor1ResidenceController,
                              label: 'Sponsor 1 Residence',
                              isRequired: false,
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
                                    validator: (val) => _validateName(val, 'Sponsor 2 first name', isRequired: true),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildTextFormField(
                                    controller: _sponsor2MiddleNameController,
                                    label: 'Sponsor 2 Middle Name',
                                    isRequired: false,
                                    validator: (val) => _validateName(val, 'Sponsor 2 middle name', isRequired: false),
                                  ),
                                ),
                              ],
                            ),
                            _buildTextFormField(
                              controller: _sponsor2LastNameController,
                              label: 'Sponsor 2 Last Name',
                              isRequired: true,
                              validator: (val) => _validateName(val, 'Sponsor 2 last name', isRequired: true),
                            ),
                            _buildTextFormField(
                              controller: _sponsor2ResidenceController,
                              label: 'Sponsor 2 Residence',
                              isRequired: false,
                            ),
                            const Divider(height: 24),
                            _buildTextFormField(
                              controller: _otherGodparentsController,
                              label: 'Other Godparents',
                              isRequired: false,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 7. Baptism & Minister Details
                      _buildSectionCard(
                        title: '7. Baptism & Minister Details',
                        icon: Icons.church,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _buildTextFormField(
                                    controller: _ministerFirstNameController,
                                    label: 'Minister First Name',
                                    isRequired: true,
                                    validator: (val) => _validateName(val, 'Minister first name', isRequired: true),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildTextFormField(
                                    controller: _ministerMiddleNameController,
                                    label: 'Minister Middle Name',
                                    isRequired: false,
                                    validator: (val) => _validateName(val, 'Minister middle name', isRequired: false),
                                  ),
                                ),
                              ],
                            ),
                            _buildTextFormField(
                              controller: _ministerLastNameController,
                              label: 'Minister Last Name',
                              isRequired: true,
                              validator: (val) => _validateName(val, 'Minister last name', isRequired: true),
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _buildDatePickerField(
                                    label: 'Date of Baptism',
                                    isRequired: true,
                                    value: _dateOfBaptism,
                                    hasError: _dateOfBaptismHasError,
                                    onTap: () => _selectDate(context, false),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildTextFormField(
                                    controller: _stipendController,
                                    label: 'Stipend (₱)',
                                    isRequired: false,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    validator: _validateStipend,
                                  ),
                                ),
                              ],
                            ),
                            _buildTextFormField(
                              controller: _placeOfBaptismController,
                              label: 'Place of Baptism',
                              isRequired: true,
                              validator: (val) => _validateRequiredText(val, 'Place of baptism'),
                            ),
                            _buildTextFormField(
                              controller: _remarksController,
                              label: 'Canonical Remarks / Marginal Notations',
                              isRequired: false,
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),

            // Sticky Bottom Action Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: cardWhiteColor,
                border: Border(top: BorderSide(color: borderGreyColor)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: borderGreyColor, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                      child: Text('Discard / Back', style: TextStyle(fontSize: 15, color: textMutedColor)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ParishColors.marianBlue,
                          foregroundColor: Colors.white,
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isSubmitting ? null : _submitForm,
                        icon: _isSubmitting
                            ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                            : const Icon(Icons.check, size: 20),
                        label: Text(
                          _isSubmitting ? 'Registering...' : 'Save Baptism Record',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
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

  // ===========================================================================
  // Section & Field Building Blocks
  // ===========================================================================

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
          const Divider(height: 18),
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
            keyboardType: keyboardType,
            maxLines: maxLines,
            validator: validator,
            style: TextStyle(fontSize: 14, color: ParishColors.textDark),
            decoration: InputDecoration(
              hintText: null, // Input area remains blank without redundant hint
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
                    value != null ? value.toIso8601String().substring(0, 10) : '',
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