import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../services/first_communion_service.dart';

class FirstCommunionManualEntryPage extends StatefulWidget {
  final VoidCallback? onRecordSaved;

  const FirstCommunionManualEntryPage({super.key, this.onRecordSaved});

  @override
  State<FirstCommunionManualEntryPage> createState() => _FirstCommunionManualEntryPageState();
}

class _FirstCommunionManualEntryPageState extends State<FirstCommunionManualEntryPage> {
  final _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();

  // Eucharistic Gold Accent Colors
  static const Color _eucharisticGold = Color(0xFFD49B18);
  static const Color _goldSurface = Color(0xFFFFF7E6);

  // Pagination State (4 Google Forms-Style Sections)
  int _currentStep = 0;
  static const int _totalSteps = 4;

  static const List<String> _stepTitles = [
    'Record Tracking & Reference',
    'Communicant Identity & Baptism',
    "Parents' Information",
    'Officiating Clergy & Remarks',
  ];

  static const List<String> _stepDescriptions = [
    'Archival reception year, auto-generated control register number, and date of communion.',
    'Official identity of the first communicant and proof of valid Catholic baptism.',
    'Parental names (optional in batch school/parish first communion registries).',
    'Presiding minister, celebration parish, and official canonical annotations.',
  ];

  // 1. Record Tracking & Reference (Page 1)
  final _yearController = TextEditingController(text: '${DateTime.now().year}');
  final _controlNumberController = TextEditingController(text: 'Loading...');
  DateTime? _dateOfCommunion = DateTime.now();

  // 2. Communicant Identity & Baptism (Page 2)
  final _communicantFirstNameController = TextEditingController();
  final _communicantMiddleNameController = TextEditingController();
  final _communicantLastNameController = TextEditingController();
  final _baptismParishController = TextEditingController(text: 'St. John Paul II Parish Church');
  DateTime? _baptismDate;

  // 3. Parents' Information (Page 3 - Batch Optional)
  final _fatherFirstNameController = TextEditingController();
  final _fatherMiddleNameController = TextEditingController();
  final _fatherLastNameController = TextEditingController();

  final _motherFirstNameController = TextEditingController();
  final _motherMiddleNameController = TextEditingController();
  final _motherMaidenLastNameController = TextEditingController();

  // 4. Officiating Clergy & Remarks (Page 4)
  final _ministerFirstNameController = TextEditingController(text: 'Joseph');
  final _ministerMiddleNameController = TextEditingController();
  final _ministerLastNameController = TextEditingController(text: 'Santos');
  final _remarksController = TextEditingController();

  bool _isSubmitting = false;
  bool _isLoadingControlNo = true;
  String? _errorMessage;
  bool _dateOfCommunionHasError = false;

  @override
  void initState() {
    super.initState();
    _loadAutoControlNumber();
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
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _controlNumberController.text = 'FCM-${DateTime.now().year}-0001';
        _isLoadingControlNo = false;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
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

  Future<void> _selectDate(BuildContext context, int dateType) async {
    final now = DateTime.now();
    DateTime initialDate;

    if (dateType == 0) {
      initialDate = _dateOfCommunion ?? now;
    } else {
      initialDate = _baptismDate ?? DateTime(now.year - 8, 1, 1);
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(now) ? now : initialDate,
      firstDate: DateTime(1900),
      lastDate: now.add(const Duration(days: 365)),
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

  // ===========================================================================
  // Google Forms Step Validation
  // ===========================================================================

  bool _validateStep(int step) {
    setState(() => _errorMessage = null);

    if (step == 0) {
      // Step 1: Record Tracking
      final y = int.tryParse(_yearController.text.trim());
      if (y == null || y < 1900 || y > DateTime.now().year + 1) {
        setState(() => _errorMessage = 'Please specify a valid communion year.');
        return false;
      }
      final cnErr = _validateRequiredText(_controlNumberController.text, 'Control Number');
      if (cnErr != null) {
        setState(() => _errorMessage = cnErr);
        return false;
      }
      if (_dateOfCommunion == null) {
        setState(() {
          _dateOfCommunionHasError = true;
          _errorMessage = 'Date of First Holy Communion is required.';
        });
        return false;
      }
      return true;
    } else if (step == 1) {
      // Step 2: Communicant Identity & Baptism
      final fnErr = _validateName(_communicantFirstNameController.text, 'Communicant First Name', isRequired: true);
      if (fnErr != null) {
        setState(() => _errorMessage = fnErr);
        return false;
      }
      final lnErr = _validateName(_communicantLastNameController.text, 'Communicant Last Name', isRequired: true);
      if (lnErr != null) {
        setState(() => _errorMessage = lnErr);
        return false;
      }
      final bpErr = _validateRequiredText(_baptismParishController.text, 'Church of Baptism');
      if (bpErr != null) {
        setState(() => _errorMessage = bpErr);
        return false;
      }
      if (_baptismDate != null && _dateOfCommunion != null && _dateOfCommunion!.isBefore(_baptismDate!)) {
        setState(() => _errorMessage = 'Date of First Communion cannot be earlier than Date of Baptism.');
        return false;
      }
      return true;
    } else if (step == 2) {
      // Step 3: Parents' Information
      if (_fatherFirstNameController.text.trim().isNotEmpty) {
        final flnErr = _validateName(_fatherLastNameController.text, "Father's last name", isRequired: true);
        if (flnErr != null) {
          setState(() => _errorMessage = flnErr);
          return false;
        }
      }
      if (_motherFirstNameController.text.trim().isNotEmpty) {
        final mlnErr = _validateName(_motherMaidenLastNameController.text, "Mother's maiden last name", isRequired: true);
        if (mlnErr != null) {
          setState(() => _errorMessage = mlnErr);
          return false;
        }
      }
      return true;
    } else if (step == 3) {
      // Step 4: Clergy
      final mfnErr = _validateName(_ministerFirstNameController.text, 'Minister First Name', isRequired: true);
      if (mfnErr != null) {
        setState(() => _errorMessage = mfnErr);
        return false;
      }
      final mlnErr = _validateName(_ministerLastNameController.text, 'Minister Last Name', isRequired: true);
      if (mlnErr != null) {
        setState(() => _errorMessage = mlnErr);
        return false;
      }
      return true;
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

  void _goToPreviousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _errorMessage = null;
      });
      _scrollToTop();
    } else {
      Navigator.pop(context);
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

  Future<void> _submitForm() async {
    for (int s = 0; s < _totalSteps; s++) {
      if (!_validateStep(s)) {
        setState(() => _currentStep = s);
        _scrollToTop();
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      final int year = int.parse(_yearController.text.trim());

      final recordMap = {
        'year': year,
        'control_number': _controlNumberController.text.trim(),
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

      await FirstCommunionService.insertManualFirstCommunionRecord(recordMap);

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('First Communion record saved in Liber Primae Communionis.'),
          backgroundColor: ParishColors.oliveGreen,
          duration: Duration(seconds: 3),
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

    return Scaffold(
      backgroundColor: ParishColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: cardWhiteColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _eucharisticGold, size: 26),
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'First Communion Manual Entry',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDarkColor),
            ),
            Text(
              'Canonical Registry Book (Liber Primae Communionis)',
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
                // Google Forms Progress Banner
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
                                'Section ${_currentStep + 1} of $_totalSteps',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _eucharisticGold,
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
                              valueColor: const AlwaysStoppedAnimation<Color>(_eucharisticGold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Divider(height: 1, color: borderGreyColor),

                // Form Page Content
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 18),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 960),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Google Forms Header Card
                              _buildGoogleFormsSectionHeader(
                                title: _stepTitles[_currentStep],
                                description: _stepDescriptions[_currentStep],
                                stepIndex: _currentStep,
                              ),
                              const SizedBox(height: 16),

                              // Validation Banner
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

                              // Paginated Step View Switcher
                              _buildActiveStepContent(isMobile: isMobile),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Responsive Sticky Bottom Navigation Bar (Back, Next, Submit)
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
                                    : _eucharisticGold,
                                foregroundColor: Colors.white,
                                elevation: 1,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: _isSubmitting || _isLoadingControlNo ? null : _goToNextStep,
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
                                    ? 'Registering...'
                                    : (_currentStep == _totalSteps - 1 ? 'Save Communion Record' : 'Continue / Next'),
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
                            width: isMobile ? 190 : 260,
                            height: 48,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _currentStep == _totalSteps - 1
                                    ? ParishColors.oliveGreen
                                    : _eucharisticGold,
                                foregroundColor: Colors.white,
                                elevation: 1,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: _isSubmitting || _isLoadingControlNo ? null : _goToNextStep,
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
                                    ? 'Registering...'
                                    : (_currentStep == _totalSteps - 1 ? 'Save Communion Record' : 'Next Section'),
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
    );
  }

  // ===========================================================================
  // Step Views
  // ===========================================================================

  Widget _buildActiveStepContent({required bool isMobile}) {
    switch (_currentStep) {
      case 0:
        return _buildStep1TrackingAndReference(isMobile: isMobile);
      case 1:
        return _buildStep2CommunicantIdentity(isMobile: isMobile);
      case 2:
        return _buildStep3ParentsInformation(isMobile: isMobile);
      case 3:
        return _buildStep4ClergyAndRemarks(isMobile: isMobile);
      default:
        return const SizedBox.shrink();
    }
  }

  // STEP 1: Record Tracking & Reference (Auto-generated Read-only Control Number)
  Widget _buildStep1TrackingAndReference({required bool isMobile}) {
    return _buildSectionCard(
      title: 'Canonical Ledger & Control Reference',
      icon: Icons.bookmark_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAdaptivePair(
            isStacked: isMobile,
            first: _buildTextFormField(
              controller: _yearController,
              label: 'Archival Reception Year',
              isRequired: true,
              keyboardType: TextInputType.number,
              onChanged: (_) => _loadAutoControlNumber(),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Year is required';
                final y = int.tryParse(val.trim());
                if (y == null || y < 1900 || y > DateTime.now().year + 1) {
                  return 'Valid year required';
                }
                return null;
              },
            ),
            second: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTextFormField(
                  controller: _controlNumberController,
                  label: 'Control Number (Auto-Generated)',
                  isRequired: true,
                  enabled: false, // Cannot be edited by encoder
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 2, left: 4),
                  child: Text(
                    'Format: FCM-Year-Number (Incremented automatically per record)',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ParishColors.goldAccent),
                  ),
                ),
              ],
            ),
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

  // STEP 2: Communicant Identity & Baptism
  Widget _buildStep2CommunicantIdentity({required bool isMobile}) {
    return _buildSectionCard(
      title: 'Communicant Identity & Proof of Baptism',
      icon: Icons.person_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAdaptivePair(
            isStacked: isMobile,
            first: _buildTextFormField(
              controller: _communicantFirstNameController,
              label: 'Communicant First Name',
              isRequired: true,
              validator: (val) => _validateName(val, 'Communicant first name', isRequired: true),
            ),
            second: _buildTextFormField(
              controller: _communicantMiddleNameController,
              label: 'Middle Name (Optional)',
              isRequired: false,
              validator: (val) => _validateName(val, 'Middle name', isRequired: false),
            ),
          ),
          _buildTextFormField(
            controller: _communicantLastNameController,
            label: 'Communicant Last Name',
            isRequired: true,
            validator: (val) => _validateName(val, 'Communicant last name', isRequired: true),
          ),
          const Divider(height: 24),
          _buildTextFormField(
            controller: _baptismParishController,
            label: 'Church of Baptism',
            isRequired: true,
            validator: (val) => _validateRequiredText(val, 'Church of baptism'),
          ),
          _buildDatePickerField(
            label: 'Date of Baptism (Optional)',
            isRequired: false,
            value: _baptismDate,
            hasError: false,
            onTap: () => _selectDate(context, 1),
          ),
        ],
      ),
    );
  }

  // STEP 3: Parents' Information (Batch/Parish Optional)
  Widget _buildStep3ParentsInformation({required bool isMobile}) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: _goldSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _eucharisticGold.withOpacity(0.4)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: _eucharisticGold, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Parental lineage is optional in batch school and parish first communion registries.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ParishColors.marianBlue),
                ),
              ),
            ],
          ),
        ),
        _buildSectionCard(
          title: "Father's Information (Optional)",
          icon: Icons.person,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAdaptivePair(
                isStacked: isMobile,
                first: _buildTextFormField(
                  controller: _fatherFirstNameController,
                  label: 'Father First Name',
                  isRequired: false,
                  validator: (val) => _validateName(val, "Father's first name", isRequired: false),
                ),
                second: _buildTextFormField(
                  controller: _fatherMiddleNameController,
                  label: 'Middle Name',
                  isRequired: false,
                  validator: (val) => _validateName(val, "Father's middle name", isRequired: false),
                ),
              ),
              _buildTextFormField(
                controller: _fatherLastNameController,
                label: 'Father Last Name',
                isRequired: false,
                validator: (val) => _validateName(val, "Father's last name", isRequired: false),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          title: "Mother's Information (Optional)",
          icon: Icons.person_outline,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAdaptivePair(
                isStacked: isMobile,
                first: _buildTextFormField(
                  controller: _motherFirstNameController,
                  label: 'Mother First Name',
                  isRequired: false,
                  validator: (val) => _validateName(val, "Mother's first name", isRequired: false),
                ),
                second: _buildTextFormField(
                  controller: _motherMiddleNameController,
                  label: 'Middle Name',
                  isRequired: false,
                  validator: (val) => _validateName(val, "Mother's middle name", isRequired: false),
                ),
              ),
              _buildTextFormField(
                controller: _motherMaidenLastNameController,
                label: 'Mother Maiden Last Name',
                isRequired: false,
                validator: (val) => _validateName(val, "Mother's maiden last name", isRequired: false),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // STEP 4: Officiating Clergy & Canonical Remarks
  Widget _buildStep4ClergyAndRemarks({required bool isMobile}) {
    return _buildSectionCard(
      title: 'Officiating Clergy & Archival Annotations',
      icon: Icons.church,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
              label: 'Middle Name (Optional)',
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
          _buildTextFormField(
            controller: _remarksController,
            label: 'Remarks / Mass Batch Details',
            isRequired: false,
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Google Forms Header & UI Blocks
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
              color: _eucharisticGold,
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
                      'SECTION ${stepIndex + 1} OF $_totalSteps',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _eucharisticGold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _goldSurface,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Eucharistic Register',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _eucharisticGold,
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
              Icon(icon, size: 20, color: _eucharisticGold),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: _eucharisticGold,
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
    void Function(String)? onChanged,
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
            onChanged: onChanged,
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
                borderSide: const BorderSide(color: _eucharisticGold, width: 1.8),
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
                    color: hasError ? ParishColors.mercyRed : _eucharisticGold,
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
}