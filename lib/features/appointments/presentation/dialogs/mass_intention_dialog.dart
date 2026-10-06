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
import 'schedule_appointment_dialog.dart';

void showMassIntentionModal(
    BuildContext context, {
      VoidCallback? onIntentionSaved,
    }) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _MassIntentionDialog(onIntentionSaved: onIntentionSaved),
  );
}

class _MassIntentionDialog extends StatefulWidget {
  final VoidCallback? onIntentionSaved;

  const _MassIntentionDialog({this.onIntentionSaved});

  @override
  State<_MassIntentionDialog> createState() => _MassIntentionDialogState();
}

class _MassIntentionDialogState extends State<_MassIntentionDialog> {
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

  // GCash Semi-Manual QR & Receipt Upload State
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
      _paymentMethod = 'GCash'; // Locked to GCash for parishioners
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

  // ===========================================================================
  // Draft Persistence Lifecycle (Auto-save / Restore via SharedPreferences)
  // ===========================================================================

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
            if (map['stipendAmount'] != null && (map['stipendAmount'] as String).isNotEmpty) {
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
      setState(() {
        list.add(TextEditingController());
      });
      _recalculateDefaultStipend();
      _saveDraft();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum of 10 items reached for this intention category.'),
          backgroundColor: ParishColors.goldAccent,
          duration: Duration(seconds: 2),
        ),
      );
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
    return list
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }

  void _recalculateDefaultStipend() {
    // If OCR already extracted an amount from a valid receipt screenshot, preserve it
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

  // ===========================================================================
  // Google ML Kit GCash Receipt Image Selection & Auto-Extraction
  // ===========================================================================

  Future<void> _pickReceiptScreenshot() async {
    try {
      final PlatformFile? file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      );

      if (file == null) return;

      final fileSize = (await file.length()) ?? 0;
      if (fileSize > 6 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receipt image exceeds 6MB. Please upload a compressed image.'),
            backgroundColor: ParishColors.mercyRed,
          ),
        );
        return;
      }

      final bytes = await file.readAsBytes();

      setState(() {
        _receiptBytes = bytes;
        _receiptFileName = file.name;
        _receiptFilePath = file.path;
        _isExtractingOcr = true;
        _errorMessage = null;
      });

      // Execute Google ML Kit OCR and multi-line GCash parsing
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ocrRes.referenceNumber != null
              ? 'GCash Receipt scanned! Ref #${ocrRes.referenceNumber} auto-extracted.'
              : 'Screenshot attached. Please confirm Reference Number.'),
          backgroundColor: ParishColors.oliveGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isExtractingOcr = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error reading receipt: $e'), backgroundColor: ParishColors.mercyRed),
      );
    }
  }

  void _clearReceipt() {
    setState(() {
      _receiptBytes = null;
      _receiptFileName = null;
      _receiptFilePath = null;
      _ocrResult = null;
    });
  }

  // ===========================================================================
  // Submission
  // ===========================================================================

  Future<void> _submitMassIntention() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) return;

    final thanksgiving = _extractCleanList(_thanksgivingControllers);
    final repose = _extractCleanList(_reposeSoulsControllers);
    final special = _extractCleanList(_specialIntentionsControllers);
    final other = _otherIntentionsController.text.trim();

    if (thanksgiving.isEmpty && repose.isEmpty && special.isEmpty && other.isEmpty) {
      setState(() {
        _errorMessage = 'Please provide at least one intention entry.';
      });
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

      // Clear draft on confirmed commit
      await _clearDraft();

      if (!mounted) return;
      Navigator.pop(context);

      _showSuccessDialog(result);
      widget.onIntentionSaved?.call();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessDialog(MassIntentionModel item) {
    final bool isStaff = !_isParishioner;
    final bool isCashDesk = isStaff && item.paymentMethod.toLowerCase().contains('cash');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: ParishColors.cardWhite,
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: ParishColors.oliveGreen, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isCashDesk ? 'Walk-In Intention & Receipt Issued!' : 'Mass Intention Submitted!',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isCashDesk
                  ? 'The walk-in Mass intention (${item.intentionId}) has been confirmed and official receipt issued in the parish ledger.'
                  : 'Your Mass intention request (${item.intentionId}) has been queued for verification by the Parish Secretariat.',
              style: TextStyle(fontSize: 13.5, color: ParishColors.textDark, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ParishColors.marianBlueSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ParishColors.borderGrey),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mass Schedule: ${item.formattedScheduleDisplay}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 3),
                  Text('Total Intentions: ${item.totalIntentionsCount} names',
                      style: const TextStyle(fontSize: 12)),
                  Text('Stipend: ₱ ${item.stipendAmount.toStringAsFixed(2)} (${item.paymentMethod})',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ParishColors.oliveGreen)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ParishColors.marianBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textDarkColor = ParishColors.textDark;
    final textMutedColor = ParishColors.textMuted;
    final cardWhiteColor = ParishColors.cardWhite;
    final borderGreyColor = ParishColors.borderGrey;
    final isSunday = _selectedDate.weekday == DateTime.sunday;
    final bool isStaff = !_isParishioner;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 600;

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: cardWhiteColor,
          child: Container(
            width: double.maxFinite,
            constraints: const BoxConstraints(maxWidth: 640, maxHeight: 780),
            child: Column(
              children: [
                // Modal Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: ParishColors.marianBlueSurface,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    border: Border(bottom: BorderSide(color: borderGreyColor)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: ParishColors.marianBlueAdaptive,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.volunteer_activism, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isStaff ? 'Encode Walk-In Mass Intention' : 'Mass Intention Request',
                              style: TextStyle(fontSize: isCompact ? 16 : 18, fontWeight: FontWeight.bold, color: textDarkColor),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Wed & Fri (5:30 PM) • Sun (8:00 AM & 4:00 PM)',
                              style: TextStyle(fontSize: 11.5, color: textMutedColor),
                              overflow: TextOverflow.ellipsis,
                            ),
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

                // Form Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isCompact ? 14 : 20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_errorMessage != null) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 14),
                              decoration: BoxDecoration(
                                color: ParishColors.mercyRedSurface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: ParishColors.mercyRed),
                              ),
                              child: Text(_errorMessage!,
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: ParishColors.mercyRed)),
                            ),
                          ],

                          // Prominent Mass Schedule Banner
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: ParishColors.marianBlueSurface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: ParishColors.marianBlue.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.event_available, color: ParishColors.marianBlue, size: 26),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('SELECTED MASS SCHEDULE',
                                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: ParishColors.marianBlue, letterSpacing: 0.5)),
                                      const SizedBox(height: 2),
                                      Text(
                                        _currentScheduleFullDisplay,
                                        style: TextStyle(fontSize: isCompact ? 13.5 : 14.5, fontWeight: FontWeight.bold, color: textDarkColor),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: _pickDate,
                                  child: const Text('Change', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Requester Full Name
                          _buildFieldLabel(_isParishioner
                              ? 'Requester Full Name (Account Linked)'
                              : 'Requester Full Name (Walk-In) *'),
                          TextFormField(
                            controller: _requesterNameController,
                            enabled: !_isParishioner,
                            maxLength: 100,
                            buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                            inputFormatters: [TitleCaseInputFormatter()],
                            validator: (v) => SacramentalValidators.validateName(v, 'Requester name', isRequired: true),
                            onChanged: (_) => _saveDraft(),
                            style: TextStyle(fontSize: 14, color: _isParishioner ? textMutedColor : textDarkColor),
                            decoration: _inputDecoration(
                              hint: 'First Name and Last Name',
                              prefixIcon: _isParishioner
                                  ? Icon(Icons.lock_outline, size: 18, color: ParishColors.marianBlueAdaptive)
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Contact & Email Responsive Row
                          if (isCompact) ...[
                            _buildFieldLabel('Contact Number *'),
                            TextFormField(
                              controller: _contactNumberController,
                              keyboardType: TextInputType.phone,
                              maxLength: 13,
                              buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                PhilippinePhoneInputFormatter(),
                              ],
                              validator: SacramentalValidators.validatePhoneNumber,
                              onChanged: (_) => _saveDraft(),
                              style: const TextStyle(fontSize: 14),
                              decoration: _inputDecoration(hint: '09XX-XXX-XXXX'),
                            ),
                            const SizedBox(height: 14),
                            _buildFieldLabel(_isParishioner ? 'Email Address *' : 'Email (Optional)'),
                            TextFormField(
                              controller: _emailController,
                              enabled: !_isParishioner,
                              maxLength: 100,
                              buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                              keyboardType: TextInputType.emailAddress,
                              onChanged: (_) => _saveDraft(),
                              validator: (v) {
                                final text = (v ?? '').trim();
                                if (_isParishioner && text.isEmpty) return 'Required';
                                if (text.isNotEmpty && !text.contains('@')) return 'Invalid email';
                                return null;
                              },
                              style: TextStyle(fontSize: 14, color: _isParishioner ? textMutedColor : textDarkColor),
                              decoration: _inputDecoration(hint: 'name@email.com'),
                            ),
                          ] else ...[
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
                                        maxLength: 13,
                                        buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly,
                                          PhilippinePhoneInputFormatter(),
                                        ],
                                        validator: SacramentalValidators.validatePhoneNumber,
                                        onChanged: (_) => _saveDraft(),
                                        style: const TextStyle(fontSize: 14),
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
                                      _buildFieldLabel(_isParishioner ? 'Email Address *' : 'Email (Optional)'),
                                      TextFormField(
                                        controller: _emailController,
                                        enabled: !_isParishioner,
                                        maxLength: 100,
                                        buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                                        keyboardType: TextInputType.emailAddress,
                                        onChanged: (_) => _saveDraft(),
                                        validator: (v) {
                                          final text = (v ?? '').trim();
                                          if (_isParishioner && text.isEmpty) return 'Required';
                                          if (text.isNotEmpty && !text.contains('@')) return 'Invalid email';
                                          return null;
                                        },
                                        style: TextStyle(fontSize: 14, color: _isParishioner ? textMutedColor : textDarkColor),
                                        decoration: _inputDecoration(hint: 'name@email.com'),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 16),

                          // Time Slot Options (For Sunday Masses)
                          if (isSunday) ...[
                            _buildFieldLabel('Sunday Mass Time Slot *'),
                            DropdownButtonFormField<String>(
                              value: _selectedMassTime,
                              isExpanded: true,
                              items: const [
                                DropdownMenuItem(
                                    value: '08:00:00',
                                    child: Text('8:00 AM (Sunday Morning Mass)',
                                        style: TextStyle(fontSize: 13.5), overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(
                                    value: '16:00:00',
                                    child: Text('4:00 PM (Sunday Afternoon Mass)',
                                        style: TextStyle(fontSize: 13.5), overflow: TextOverflow.ellipsis)),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedMassTime = val);
                                  _saveDraft();
                                }
                              },
                              decoration: _inputDecoration(),
                            ),
                            const SizedBox(height: 16),
                          ],

                          const Divider(height: 24),

                          // Categorized Petitions
                          Text('Mass Intention Names & Petitions',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDarkColor)),
                          Text('Enter names for altar mention (up to 10 entries per category).',
                              style: TextStyle(fontSize: 12, color: textMutedColor)),
                          const SizedBox(height: 14),

                          _buildDynamicCategorySection(
                            title: '1. Thanksgiving (Pasasalamat)',
                            subtitle: 'Birthdays, anniversaries, recoveries, blessings received',
                            icon: Icons.celebration,
                            color: ParishColors.marianBlueAdaptive,
                            controllers: _thanksgivingControllers,
                            hintText: 'e.g. For the gift of life of Maria Santos',
                          ),
                          const SizedBox(height: 14),

                          _buildDynamicCategorySection(
                            title: '2. Repose of the Soul (Para sa Kaluluwa)',
                            subtitle: 'Deceased loved ones, death anniversaries, All Souls',
                            icon: Icons.church,
                            color: const Color(0xFF7C3AED),
                            controllers: _reposeSoulsControllers,
                            hintText: 'e.g. + Juan Dela Cruz (40th Day)',
                          ),
                          const SizedBox(height: 14),

                          _buildDynamicCategorySection(
                            title: '3. Special Intentions (Natatanging Kahilingan)',
                            subtitle: 'Healing, board exams, safe travel, peace of mind',
                            icon: Icons.favorite_border,
                            color: ParishColors.oliveGreen,
                            controllers: _specialIntentionsControllers,
                            hintText: 'e.g. For good health of Dela Cruz Family',
                          ),
                          const SizedBox(height: 14),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildFieldLabel('4. Other Intentions / Petitions'),
                              Text(
                                '${_otherIntentionsController.text.length}/150',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _otherIntentionsController.text.length > 150
                                      ? ParishColors.mercyRed
                                      : textMutedColor,
                                ),
                              ),
                            ],
                          ),
                          TextFormField(
                            controller: _otherIntentionsController,
                            maxLength: 150,
                            maxLines: 2,
                            buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                            onChanged: (_) {
                              setState(() {});
                              _recalculateDefaultStipend();
                              _saveDraft();
                            },
                            style: const TextStyle(fontSize: 13),
                            decoration: _inputDecoration(hint: 'Other specific intentions (Max 150 characters)'),
                          ),
                          const SizedBox(height: 20),

                          const Divider(height: 24),

                          // Payment Method & Semi-Manual GCash QR Upload Section
                          Text(isStaff ? 'Offering Mode & Stipend' : 'GCash Offering & Receipt Upload',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDarkColor)),
                          const SizedBox(height: 12),

                          if (isStaff) ...[
                            _buildFieldLabel('Payment Method (Desk Intake) *'),
                            DropdownButtonFormField<String>(
                              value: _paymentMethod,
                              isExpanded: true,
                              items: const [
                                DropdownMenuItem(
                                    value: 'Cash (Walk-In Desk)',
                                    child: Text('Cash (Walk-In at Secretariat Desk)',
                                        style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(
                                    value: 'GCash',
                                    child: Text('GCash Direct Transfer',
                                        style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _paymentMethod = val);
                                  _saveDraft();
                                }
                              },
                              decoration: _inputDecoration(),
                            ),
                            const SizedBox(height: 14),
                          ],

                          if (_isParishioner || _paymentMethod == 'GCash') ...[
                            _buildGcashPaymentBox(),
                            const SizedBox(height: 14),
                          ],

                          // Stipend Amount & Ref Number Layout
                          if (isCompact) ...[
                            _buildFieldLabel('Stipend Offering Amount (PHP) *'),
                            TextFormField(
                              controller: _stipendAmountController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textDarkColor),
                              decoration: _inputDecoration(
                                prefixIcon: const Icon(Icons.attach_money, size: 18, color: ParishColors.oliveGreen),
                              ),
                              onChanged: (_) => _saveDraft(),
                            ),
                            if (_paymentMethod == 'GCash' || _isParishioner) ...[
                              const SizedBox(height: 12),
                              _buildFieldLabel('GCash Ref Number *'),
                              TextFormField(
                                controller: _gcashRefController,
                                maxLength: 50,
                                buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textDarkColor),
                                decoration: _inputDecoration(
                                  hint: '1002 9847 1120',
                                  prefixIcon: const Icon(Icons.receipt_long, size: 18, color: ParishColors.marianBlue),
                                ),
                                onChanged: (_) => _saveDraft(),
                              ),
                            ],
                          ] else ...[
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildFieldLabel('Stipend Offering Amount (PHP) *'),
                                      TextFormField(
                                        controller: _stipendAmountController,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textDarkColor),
                                        decoration: _inputDecoration(
                                          prefixIcon: const Icon(Icons.attach_money, size: 18, color: ParishColors.oliveGreen),
                                        ),
                                        onChanged: (_) => _saveDraft(),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_paymentMethod == 'GCash' || _isParishioner) ...[
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _buildFieldLabel('GCash Ref Number *'),
                                        TextFormField(
                                          controller: _gcashRefController,
                                          maxLength: 50,
                                          buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textDarkColor),
                                          decoration: _inputDecoration(
                                            hint: '1002 9847 1120',
                                            prefixIcon: const Icon(Icons.receipt_long, size: 18, color: ParishColors.marianBlue),
                                          ),
                                          onChanged: (_) => _saveDraft(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                // Modal Action Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: cardWhiteColor,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                    border: Border(top: BorderSide(color: borderGreyColor)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                        child: Text('Cancel', style: TextStyle(fontSize: 14, color: textMutedColor)),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ParishColors.marianBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                        ),
                        onPressed: _isSubmitting ? null : _submitMassIntention,
                        icon: _isSubmitting
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.check, size: 18),
                        label: Text(
                          _isSubmitting
                              ? 'Submitting...'
                              : (isStaff && _paymentMethod.toLowerCase().contains('cash')
                              ? 'Save & Issue Receipt'
                              : 'Confirm & Submit Intention'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGcashPaymentBox() {
    final borderGrey = ParishColors.borderGrey;
    final textDark = ParishColors.textDark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF005CEE).withOpacity(0.35), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.qr_code_2, color: Color(0xFF005CEE), size: 22),
                  const SizedBox(width: 8),
                  Text('Parish Official GCash QR',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: textDark)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF005CEE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('GCash Only',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 9.5)),
              ),
            ],
          ),
          const Divider(height: 18),

          Center(
            child: Column(
              children: [
                Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderGrey),
                  ),
                  child: _paymentSettings.gcashQrCodeUrl != null &&
                      _paymentSettings.gcashQrCodeUrl!.isNotEmpty
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      _paymentSettings.gcashQrCodeUrl!,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => _buildFallbackQr(),
                    ),
                  )
                      : _buildFallbackQr(),
                ),
                const SizedBox(height: 6),
                Text('Account: ${_paymentSettings.gcashAccountName}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                Text('GCash No: ${_paymentSettings.gcashAccountNumber}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF005CEE))),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _paymentSettings.paymentInstructions,
            style: TextStyle(fontSize: 11, color: ParishColors.textMuted, height: 1.3),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderGrey),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Upload GCash Receipt Screenshot *',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textDark)),
                    if (_receiptBytes != null)
                      IconButton(
                        icon: const Icon(Icons.close, size: 16, color: ParishColors.mercyRed),
                        onPressed: _clearReceipt,
                        tooltip: 'Remove Screenshot',
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                if (_receiptBytes == null) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF005CEE), width: 1.2),
                        foregroundColor: const Color(0xFF005CEE),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _isExtractingOcr ? null : _pickReceiptScreenshot,
                      icon: _isExtractingOcr
                          ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF005CEE)))
                          : const Icon(Icons.document_scanner_outlined, size: 16),
                      label: Text(
                        _isExtractingOcr ? 'Scanning with Google ML Kit...' : 'Select Screenshot & Auto-Extract',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      const Icon(Icons.image, size: 18, color: ParishColors.oliveGreen),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _receiptFileName ?? 'receipt.jpg',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: ParishColors.oliveGreen),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: ParishColors.oliveGreenSurface,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('SCANNED',
                            style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: ParishColors.oliveGreen)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackQr() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.qr_code, size: 75, color: Color(0xFF005CEE)),
        Text('SCAN TO PAY GCASH',
            style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF005CEE))),
      ],
    );
  }

  Widget _buildDynamicCategorySection({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<TextEditingController> controllers,
    required String hintText,
  }) {
    return Container(
      width: double.infinity,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ParishColors.textDark)),
                    Text(subtitle, style: TextStyle(fontSize: 10.5, color: ParishColors.textMuted)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                child: Text('${controllers.length}/10', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: color)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...controllers.asMap().entries.map((entry) {
            final idx = entry.key;
            final ctrl = entry.value;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: ctrl,
                      maxLength: 100,
                      buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                      onChanged: (_) {
                        setState(() {});
                        _recalculateDefaultStipend();
                        _saveDraft();
                      },
                      style: const TextStyle(fontSize: 13),
                      decoration: _inputDecoration(hint: '$hintText #${idx + 1}'),
                    ),
                  ),
                  if (controllers.length > 1) ...[
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, size: 18, color: ParishColors.mercyRed),
                      onPressed: () => _removeListItem(controllers, idx),
                      tooltip: 'Remove',
                    ),
                  ],
                ],
              ),
            );
          }),
          if (controllers.length < 10)
            SizedBox(
              height: 34,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: color, width: 1.2),
                  foregroundColor: color,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _addListItem(controllers),
                icon: const Icon(Icons.add, size: 15),
                label: Text('Add Another Entry (${controllers.length}/10)',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
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
      padding: const EdgeInsets.only(bottom: 5.0),
      child: Text(
        label,
        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: ParishColors.textDark),
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint, Widget? prefixIcon}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: ParishColors.backgroundLight,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ParishColors.borderGrey)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ParishColors.borderGrey)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ParishColors.marianBlueAdaptive, width: 1.8)),
    );
  }
}