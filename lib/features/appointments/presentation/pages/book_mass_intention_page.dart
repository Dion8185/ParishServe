// =============================================================================
// FILE: lib/features/appointments/presentation/pages/book_mass_intention_page.dart
// =============================================================================

import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/colors.dart';
import '../../../auth/services/auth_service.dart';
import '../../../sacramental_records/validators/sacramental_validators.dart';
import '../../models/mass_intention_model.dart';
import '../../services/gcash_ocr_service.dart';
import '../../services/mass_intention_service.dart';
import '../../services/parish_payment_settings_service.dart';
import 'schedule_service_page.dart';

Future<void> navigateToBookMassIntentionPage(
    BuildContext context, {
      VoidCallback? onIntentionSaved,
    }) {
  return Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => BookMassIntentionPage(onIntentionSaved: onIntentionSaved),
    ),
  );
}

class BookMassIntentionPage extends StatefulWidget {
  final VoidCallback? onIntentionSaved;

  const BookMassIntentionPage({super.key, this.onIntentionSaved});

  @override
  State<BookMassIntentionPage> createState() => _BookMassIntentionPageState();
}

class _BookMassIntentionPageState extends State<BookMassIntentionPage> {
  final _formKey = GlobalKey<FormState>();

  final _requesterNameController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _emailController = TextEditingController();
  final _otherIntentionsController = TextEditingController();
  final _gcashRefController = TextEditingController();
  final _stipendAmountController = TextEditingController();

  final List<TextEditingController> _thanksgivingControllers = [];
  final List<TextEditingController> _reposeSoulsControllers = [];
  final List<TextEditingController> _specialIntentionsControllers = [];

  late DateTime _selectedDate;
  String _selectedMassTime = '17:30:00';
  String _paymentMethod = 'GCash';
  bool _isSubmitting = false;
  String? _errorMessage;

  ParishPaymentSettings _paymentSettings = const ParishPaymentSettings();
  bool _isLoadingPaymentSettings = true;
  Uint8List? _receiptBytes;
  String? _receiptFileName;
  String? _receiptFilePath;
  bool _isExtractingOcr = false;
  GcashOcrResult? _ocrResult;

  static const String _draftStorageKey = 'parishserve_draft_mass_intention';

  bool get _isParishioner =>
      AuthService.currentUser?.userRole.toLowerCase() == 'user';

  @override
  void initState() {
    super.initState();

    final user = AuthService.currentUser;
    if (user != null && _isParishioner) {
      _requesterNameController.text = user.fullName;
      _emailController.text = user.email;
      _paymentMethod = 'GCash';
    } else {
      _paymentMethod = 'Cash (Walk-In Desk)';
    }

    _selectedDate = _getNextValidMassDate();
    _updateMassTimeForDate(_selectedDate);

    _thanksgivingControllers.add(TextEditingController());
    _reposeSoulsControllers.add(TextEditingController());
    _specialIntentionsControllers.add(TextEditingController());

    _stipendAmountController.text = '100.00';

    _loadPaymentSettings();
    _restoreDraft();
  }

  Future<void> _loadPaymentSettings() async {
    try {
      final settings = await ParishPaymentSettingsService.getSettings();
      if (!mounted) return;
      setState(() {
        _paymentSettings = settings;
        _isLoadingPaymentSettings = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingPaymentSettings = false);
    }
  }

  Future<void> _saveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftMap = {
        'requesterName': _requesterNameController.text.trim(),
        'contact': _contactNumberController.text.trim(),
        'email': _emailController.text.trim(),
        'otherIntentions': _otherIntentionsController.text.trim(),
        'gcashRef': _gcashRefController.text.trim(),
        'stipendAmount': _stipendAmountController.text.trim(),
        'paymentMethod': _paymentMethod,
        'date': _selectedDate.toIso8601String(),
        'massTime': _selectedMassTime,
        'thanksgiving': _extractCleanList(_thanksgivingControllers),
        'repose': _extractCleanList(_reposeSoulsControllers),
        'special': _extractCleanList(_specialIntentionsControllers),
      };
      await prefs.setString(_draftStorageKey, jsonEncode(draftMap));
    } catch (_) {}
  }

  Future<void> _restoreDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_draftStorageKey);
      if (raw != null && raw.isNotEmpty) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            if (!_isParishioner &&
                map['requesterName'] != null &&
                (map['requesterName'] as String).isNotEmpty) {
              _requesterNameController.text = map['requesterName'];
            }
            if (_contactNumberController.text.isEmpty && map['contact'] != null) {
              _contactNumberController.text = map['contact'];
            }
            if (!_isParishioner &&
                map['email'] != null &&
                (map['email'] as String).isNotEmpty) {
              _emailController.text = map['email'];
            }
            if (map['otherIntentions'] != null) {
              _otherIntentionsController.text = map['otherIntentions'];
            }
            if (map['gcashRef'] != null) {
              _gcashRefController.text = map['gcashRef'];
            }
            if (map['stipendAmount'] != null &&
                (map['stipendAmount'] as String).isNotEmpty) {
              _stipendAmountController.text = map['stipendAmount'];
            }

            if (map['thanksgiving'] is List && (map['thanksgiving'] as List).isNotEmpty) {
              _thanksgivingControllers.clear();
              for (var name in (map['thanksgiving'] as List)) {
                _thanksgivingControllers.add(TextEditingController(text: name.toString()));
              }
            }

            if (map['repose'] is List && (map['repose'] as List).isNotEmpty) {
              _reposeSoulsControllers.clear();
              for (var name in (map['repose'] as List)) {
                _reposeSoulsControllers.add(TextEditingController(text: name.toString()));
              }
            }

            if (map['special'] is List && (map['special'] as List).isNotEmpty) {
              _specialIntentionsControllers.clear();
              for (var name in (map['special'] as List)) {
                _specialIntentionsControllers.add(TextEditingController(text: name.toString()));
              }
            }
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftStorageKey);
    } catch (_) {}
  }

  DateTime _getNextValidMassDate() {
    var date = DateTime.now().add(const Duration(days: 1));
    while (date.weekday != DateTime.wednesday &&
        date.weekday != DateTime.friday &&
        date.weekday != DateTime.sunday) {
      date = date.add(const Duration(days: 1));
    }
    return DateTime(date.year, date.month, date.day);
  }

  void _updateMassTimeForDate(DateTime date) {
    if (date.weekday == DateTime.sunday) {
      _selectedMassTime = '08:00:00';
    } else {
      _selectedMassTime = '17:30:00';
    }
  }

  String _formatTime12Hour(String timeStr) {
    try {
      final parts = timeStr.split(':');
      int hour = int.parse(parts[0]);
      int minute = int.parse(parts[1]);
      final period = hour >= 12 ? 'PM' : 'AM';
      final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      return '${hour12.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
    } catch (_) {
      return timeStr;
    }
  }

  String get _currentScheduleFullDisplay {
    final y = _selectedDate.year;
    final m = _selectedDate.month.toString().padLeft(2, '0');
    final d = _selectedDate.day.toString().padLeft(2, '0');
    final dayName = _getDayName(_selectedDate.weekday);
    final timeStr = _formatTime12Hour(_selectedMassTime);
    return '$dayName, $y-$m-$d at $timeStr';
  }

  @override
  void dispose() {
    _requesterNameController.dispose();
    _contactNumberController.dispose();
    _emailController.dispose();
    _otherIntentionsController.dispose();
    _gcashRefController.dispose();
    _stipendAmountController.dispose();
    for (var c in _thanksgivingControllers) {
      c.dispose();
    }
    for (var c in _reposeSoulsControllers) {
      c.dispose();
    }
    for (var c in _specialIntentionsControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addListItem(List<TextEditingController> list) {
    if (list.length < 10) {
      setState(() => list.add(TextEditingController()));
      _recalculateDefaultStipend();
      _saveDraft();
    }
  }

  void _removeListItem(List<TextEditingController> list, int index) {
    setState(() {
      list[index].dispose();
      list.removeAt(index);
    });
    _recalculateDefaultStipend();
    _saveDraft();
  }

  List<String> _extractCleanList(List<TextEditingController> list) {
    return list.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
  }

  void _recalculateDefaultStipend() {
    if (_ocrResult?.amount != null && _ocrResult!.amount! > 0) return;

    final count = _extractCleanList(_thanksgivingControllers).length +
        _extractCleanList(_reposeSoulsControllers).length +
        _extractCleanList(_specialIntentionsControllers).length +
        (_otherIntentionsController.text.trim().isNotEmpty ? 1 : 0);
    final calculated = count > 0 ? (count * 100.0) : 100.0;
    _stipendAmountController.text = calculated.toStringAsFixed(2);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstValidDate = _selectedDate.isBefore(today) ? _selectedDate : today;

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: firstValidDate,
      lastDate: today.add(const Duration(days: 365)),
      selectableDayPredicate: (DateTime day) {
        return day.weekday == DateTime.wednesday ||
            day.weekday == DateTime.friday ||
            day.weekday == DateTime.sunday;
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _updateMassTimeForDate(picked);
      });
      _saveDraft();
    }
  }

  Future<void> _pickReceiptScreenshot() async {
    try {
      final PlatformFile? file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      );

      if (file == null) return;
      final bytes = await file.readAsBytes();

      setState(() {
        _receiptBytes = bytes;
        _receiptFileName = file.name;
        _receiptFilePath = file.path;
        _isExtractingOcr = true;
        _errorMessage = null;
      });

      final ocrRes = await GcashOcrService.processReceiptImage(
        filePath: file.path,
        imageBytes: bytes,
        fileName: file.name,
      );

      if (!mounted) return;

      setState(() {
        _isExtractingOcr = false;
        _ocrResult = ocrRes;

        if (ocrRes.referenceNumber != null && ocrRes.referenceNumber!.isNotEmpty) {
          _gcashRefController.text = ocrRes.referenceNumber!;
        }
        if (ocrRes.amount != null && ocrRes.amount! > 0) {
          _stipendAmountController.text = ocrRes.amount!.toStringAsFixed(2);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isExtractingOcr = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error scanning receipt: $e')),
      );
    }
  }

  Future<void> _submitMassIntention() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) return;

    final thanksgiving = _extractCleanList(_thanksgivingControllers);
    final repose = _extractCleanList(_reposeSoulsControllers);
    final special = _extractCleanList(_specialIntentionsControllers);
    final other = _otherIntentionsController.text.trim();

    if (thanksgiving.isEmpty && repose.isEmpty && special.isEmpty && other.isEmpty) {
      setState(() => _errorMessage = 'Please provide at least one intention entry.');
      return;
    }

    final double enteredAmount = double.tryParse(_stipendAmountController.text.trim()) ?? 0.0;
    if (enteredAmount <= 0) {
      setState(() => _errorMessage = 'Please enter a valid stipend amount.');
      return;
    }

    if (_isParishioner) {
      if (_receiptBytes == null) {
        setState(() => _errorMessage = 'Please upload your GCash payment screenshot.');
        return;
      }
      if (_gcashRefController.text.trim().isEmpty) {
        setState(() => _errorMessage = 'Please provide the GCash Reference Number.');
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      final dateStr =
          '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

      String? uploadedImageUrl;
      final tempId = 'INT-${DateTime.now().millisecondsSinceEpoch % 1000000}';

      if (_receiptBytes != null && _receiptFileName != null) {
        uploadedImageUrl = await MassIntentionService.uploadReceiptImage(
          intentionId: tempId,
          fileBytes: _receiptBytes!,
          fileName: _receiptFileName!,
        );
      }

      final result = await MassIntentionService.createMassIntention(
        requesterName: _requesterNameController.text.trim(),
        contactNumber: _contactNumberController.text.trim(),
        email: _emailController.text.trim(),
        date: dateStr,
        massTime: _selectedMassTime,
        thanksgivingList: thanksgiving,
        reposeSoulsList: repose,
        specialIntentionsList: special,
        otherIntentions: other,
        stipendAmount: enteredAmount,
        paymentMethod: _isParishioner ? 'GCash' : _paymentMethod,
        gcashReferenceNo: _gcashRefController.text.trim().isNotEmpty
            ? _gcashRefController.text.trim()
            : (_isParishioner ? null : 'WALK-IN-CASH-STIPEND'),
        receiptImageUrl: uploadedImageUrl,
        ocrReferenceNumber: _ocrResult?.referenceNumber,
        ocrAmount: _ocrResult?.amount,
        ocrRawText: _ocrResult?.rawText,
      );

      await _clearDraft();

      if (!mounted) return;
      Navigator.pop(context);
      widget.onIntentionSaved?.call();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Mass Intention #${result.intentionId} successfully booked!'),
          backgroundColor: ParishColors.oliveGreen,
        ),
      );
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final cardWhite = ParishColors.cardWhite;
    final borderGrey = ParishColors.borderGrey;
    final isSunday = _selectedDate.weekday == DateTime.sunday;

    return Scaffold(
      backgroundColor: ParishColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: cardWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: ParishColors.marianBlue),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isParishioner ? 'Book Mass Intention' : 'Encode Mass Intention (Altar Desk)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark),
            ),
            Text(
              'Wed & Fri (5:30 PM) • Sun (8:00 AM & 4:00 PM)',
              style: TextStyle(fontSize: 12, color: textMuted),
            ),
          ],
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 960;

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 32 : 16,
              vertical: 24,
            ),
            child: Form(
              key: _formKey,
              child: isDesktop
                  ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 6,
                    child: _buildNamesAndScheduleCard(textDark, textMuted, cardWhite, borderGrey, isSunday),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 4,
                    child: _buildOfferingAndCheckoutSidebar(textDark, textMuted, cardWhite, borderGrey),
                  ),
                ],
              )
                  : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildNamesAndScheduleCard(textDark, textMuted, cardWhite, borderGrey, isSunday),
                  const SizedBox(height: 20),
                  _buildOfferingAndCheckoutSidebar(textDark, textMuted, cardWhite, borderGrey),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNamesAndScheduleCard(
      Color textDark,
      Color textMuted,
      Color cardWhite,
      Color borderGrey,
      bool isSunday,
      ) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: ParishColors.mercyRedSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ParishColors.mercyRed),
              ),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: ParishColors.mercyRed, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],

          // Mass Schedule Picker Banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ParishColors.marianBlueSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ParishColors.marianBlue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.event_available, color: ParishColors.marianBlue, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SELECTED MASS SCHEDULE',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ParishColors.marianBlue),
                      ),
                      Text(
                        _currentScheduleFullDisplay,
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: textDark),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _pickDate,
                  child: const Text('Change Date', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (isSunday) ...[
            _buildFieldLabel('Sunday Mass Time Slot *'),
            DropdownButtonFormField<String>(
              value: _selectedMassTime,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: '08:00:00', child: Text('8:00 AM (Sunday Morning Mass)')),
                DropdownMenuItem(value: '16:00:00', child: Text('4:00 PM (Sunday Afternoon Mass)')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedMassTime = val);
              },
              decoration: _inputDecoration(),
            ),
            const SizedBox(height: 16),
          ],

          // Requester Info
          _buildFieldLabel(_isParishioner ? 'Requester Name (Linked)' : 'Requester Name (Walk-In) *'),
          TextFormField(
            controller: _requesterNameController,
            enabled: !_isParishioner,
            inputFormatters: [TitleCaseInputFormatter()],
            validator: (v) => SacramentalValidators.validateName(v, 'Requester name', isRequired: true),
            decoration: _inputDecoration(hint: 'Full Name'),
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Contact Number *'),
                    TextFormField(
                      controller: _contactNumberController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        PhilippinePhoneInputFormatter(),
                      ],
                      validator: SacramentalValidators.validatePhoneNumber,
                      decoration: _inputDecoration(hint: '09XX-XXX-XXXX'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Email (Optional)'),
                    TextFormField(
                      controller: _emailController,
                      enabled: !_isParishioner,
                      decoration: _inputDecoration(hint: 'name@email.com'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 32),

          // Categorized Lists
          Text(
            'Altar Intentions & Names (Up to 10 per Category)',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textDark),
          ),
          const SizedBox(height: 12),

          _buildDynamicListSection(
            title: '1. Thanksgiving (Pasasalamat)',
            subtitle: 'Birthdays, anniversaries, blessings received',
            icon: Icons.celebration,
            color: ParishColors.marianBlue,
            controllers: _thanksgivingControllers,
          ),
          const SizedBox(height: 14),

          _buildDynamicListSection(
            title: '2. Repose of the Soul (Para sa Kaluluwa)',
            subtitle: 'Deceased loved ones, All Souls',
            icon: Icons.church,
            color: const Color(0xFF7C3AED),
            controllers: _reposeSoulsControllers,
          ),
          const SizedBox(height: 14),

          _buildDynamicListSection(
            title: '3. Special Intentions (Natatanging Kahilingan)',
            subtitle: 'Healing, board exams, safe travel',
            icon: Icons.favorite_border,
            color: ParishColors.oliveGreen,
            controllers: _specialIntentionsControllers,
          ),
          const SizedBox(height: 14),

          _buildFieldLabel('4. Other Intentions / Custom Text (Max 150 chars)'),
          TextFormField(
            controller: _otherIntentionsController,
            maxLength: 150,
            maxLines: 2,
            buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
            decoration: _inputDecoration(hint: 'Special private petitions'),
            onChanged: (_) => _recalculateDefaultStipend(),
          ),
        ],
      ),
    );
  }

  Widget _buildOfferingAndCheckoutSidebar(
      Color textDark,
      Color textMuted,
      Color cardWhite,
      Color borderGrey,
      ) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Offering Stipend & Checkout',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDark),
          ),
          const Divider(height: 20),

          if (!_isParishioner) ...[
            _buildFieldLabel('Intake Payment Method *'),
            DropdownButtonFormField<String>(
              value: _paymentMethod,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'Cash (Walk-In Desk)', child: Text('Cash (Walk-In Desk)')),
                DropdownMenuItem(value: 'GCash', child: Text('GCash Direct Transfer')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _paymentMethod = val);
              },
              decoration: _inputDecoration(),
            ),
            const SizedBox(height: 16),
          ],

          _buildFieldLabel('Offering Amount (PHP) *'),
          TextFormField(
            controller: _stipendAmountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark),
            decoration: _inputDecoration(
              prefixIcon: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Text('₱', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (_isParishioner || _paymentMethod == 'GCash') ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F7FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF005CEE).withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.qr_code, color: Color(0xFF005CEE)),
                      const SizedBox(width: 8),
                      Text(
                        'GCash: ${_paymentSettings.gcashAccountNumber}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF005CEE)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_receiptBytes == null)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF005CEE)),
                        foregroundColor: const Color(0xFF005CEE),
                      ),
                      onPressed: _isExtractingOcr ? null : _pickReceiptScreenshot,
                      icon: _isExtractingOcr
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.document_scanner),
                      label: Text(_isExtractingOcr ? 'Scanning with OCR...' : 'Upload Receipt Screenshot'),
                    )
                  else
                    Row(
                      children: [
                        const Icon(Icons.check_circle, color: ParishColors.oliveGreen, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _receiptFileName ?? 'receipt.jpg',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16, color: ParishColors.mercyRed),
                          onPressed: () => setState(() => _receiptBytes = null),
                        ),
                      ],
                    ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _gcashRefController,
                    decoration: _inputDecoration(hint: 'GCash Ref Number'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: ParishColors.marianBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isSubmitting ? null : _submitMassIntention,
              icon: _isSubmitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check, size: 20),
              label: Text(
                _isSubmitting
                    ? 'Recording...'
                    : (!_isParishioner && _paymentMethod.contains('Cash')
                    ? 'Confirm & Issue Receipt'
                    : 'Submit Mass Intention'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicListSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<TextEditingController> controllers,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ParishColors.backgroundLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ParishColors.borderGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              Text('${controllers.length}/10', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 8),
          ...controllers.asMap().entries.map((e) {
            final idx = e.key;
            final ctrl = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: ctrl,
                      maxLength: 100,
                      buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                      onChanged: (_) => _recalculateDefaultStipend(),
                      decoration: _inputDecoration(hint: 'Entry #${idx + 1} Name'),
                    ),
                  ),
                  if (controllers.length > 1)
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: ParishColors.mercyRed, size: 18),
                      onPressed: () => _removeListItem(controllers, idx),
                    ),
                ],
              ),
            );
          }),
          if (controllers.length < 10)
            TextButton.icon(
              onPressed: () => _addListItem(controllers),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Another Name'),
            ),
        ],
      ),
    );
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case DateTime.wednesday:
        return 'Wednesday';
      case DateTime.friday:
        return 'Friday';
      case DateTime.sunday:
        return 'Sunday';
      default:
        return '';
    }
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
    );
  }

  InputDecoration _inputDecoration({String? hint, Widget? prefixIcon}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: ParishColors.backgroundLight,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ParishColors.borderGrey)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ParishColors.borderGrey)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: ParishColors.marianBlue, width: 1.8)),
    );
  }
}