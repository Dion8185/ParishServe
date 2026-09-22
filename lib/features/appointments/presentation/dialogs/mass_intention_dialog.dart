import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/colors.dart';
import '../../../auth/services/auth_service.dart';
import '../../models/mass_intention_model.dart';
import '../../services/mass_intention_service.dart';
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

  final List<TextEditingController> _thanksgivingControllers = [];
  final List<TextEditingController> _reposeSoulsControllers = [];
  final List<TextEditingController> _specialIntentionsControllers = [];

  late DateTime _selectedDate;
  String _selectedMassTime = '17:30:00';
  String _paymentMethod = 'GCash';
  bool _isSubmitting = false;
  String? _errorMessage;

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
      // Staff default is in-person walk-in cash transaction
      _paymentMethod = 'Cash (Walk-In Desk)';
    }

    _selectedDate = _getNextValidMassDate();
    _updateMassTimeForDate(_selectedDate);

    _thanksgivingControllers.add(TextEditingController());
    _reposeSoulsControllers.add(TextEditingController());
    _specialIntentionsControllers.add(TextEditingController());
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

  @override
  void dispose() {
    _requesterNameController.dispose();
    _contactNumberController.dispose();
    _emailController.dispose();
    _otherIntentionsController.dispose();
    _gcashRefController.dispose();
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
  }

  List<String> _extractCleanList(List<TextEditingController> list) {
    return list
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();
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
    }
  }

  int get _calculatedStipend {
    final count = _extractCleanList(_thanksgivingControllers).length +
        _extractCleanList(_reposeSoulsControllers).length +
        _extractCleanList(_specialIntentionsControllers).length +
        (_otherIntentionsController.text.trim().isNotEmpty ? 1 : 0);
    return count * 100;
  }

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

    setState(() => _isSubmitting = true);

    try {
      final dateStr =
          '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

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
        stipendAmount: _calculatedStipend.toDouble(),
        paymentMethod: _paymentMethod,
        gcashReferenceNo: _paymentMethod == 'GCash' ? _gcashRefController.text.trim() : 'WALK-IN-CASH-STIPEND',
      );

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

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: ParishColors.oliveGreen, size: 26),
            SizedBox(width: 10),
            Text(isStaff ? 'Walk-In Intention Encoded!' : 'Mass Intention Filed!',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isStaff
                  ? 'The walk-in Mass intention (${item.intentionId}) has been registered and linked to cash receipting:'
                  : 'Your mass intention request (${item.intentionId}) has been submitted for liturgical celebration on:',
              style: TextStyle(fontSize: 13.5, color: ParishColors.textDark),
            ),
            const SizedBox(height: 10),
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
                  Text('Date: ${item.formattedDate}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('Time: ${item.formattedTime12Hour}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ParishColors.marianBlue)),
                  Text('Total Intentions: ${item.totalIntentionsCount} names', style: const TextStyle(fontSize: 12)),
                  if (isStaff) ...[
                    const SizedBox(height: 4),
                    const Text('Transaction: Linked to #REC-2026-00894 (Cash Walk-in)',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: ParishColors.oliveGreen)),
                  ],
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

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: cardWhiteColor,
      child: Container(
        width: double.maxFinite,
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 760),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: ParishColors.marianBlueSurface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: borderGreyColor)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: ParishColors.marianBlue,
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
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDarkColor),
                        ),
                        Text(
                          'Wed & Fri (5:30 PM) • Sun (8:00 AM & 4:00 PM)',
                          style: TextStyle(fontSize: 11.5, color: textMutedColor),
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

            // Form
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
                          child: Text(_errorMessage!, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: ParishColors.mercyRed)),
                        ),
                      ],

                      // Service Type (Locked on Mass Intention)
                      _buildFieldLabel('Service Type (Locked)'),
                      TextFormField(
                        initialValue: 'Mass Intention',
                        enabled: false,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textDarkColor),
                        decoration: _inputDecoration().copyWith(
                          prefixIcon: const Icon(Icons.lock_outline, size: 18, color: ParishColors.marianBlue),
                          fillColor: ParishColors.borderGrey.withValues(alpha: 0.15),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Requester Name
                      _buildFieldLabel(_isParishioner ? 'Requester Full Name (Account Linked)' : 'Requester Full Name (Walk-In) *'),
                      TextFormField(
                        controller: _requesterNameController,
                        enabled: !_isParishioner,
                        inputFormatters: [TitleCaseInputFormatter()],
                        validator: (v) => (v?.trim().isEmpty ?? true) ? 'Requester name is required' : null,
                        style: TextStyle(fontSize: 14, color: _isParishioner ? textMutedColor : textDarkColor),
                        decoration: _inputDecoration(
                          hint: 'First Name and Last Name',
                          prefixIcon: _isParishioner ? const Icon(Icons.lock_outline, size: 18, color: ParishColors.marianBlue) : null,
                        ),
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
                                  validator: (v) {
                                    final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                                    if (digits.length != 11 || !digits.startsWith('09')) {
                                      return 'Format: 09XX-XXX-XXXX';
                                    }
                                    return null;
                                  },
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
                                  keyboardType: TextInputType.emailAddress,
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
                      const SizedBox(height: 16),

                      // Date Selection
                      _buildFieldLabel('Scheduled Mass Date * (Wed, Fri, & Sun Only)'),
                      InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                          decoration: BoxDecoration(
                            color: ParishColors.backgroundLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: borderGreyColor),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')} (${_getDayName(_selectedDate.weekday)})',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textDarkColor),
                              ),
                              const Icon(Icons.calendar_month, color: ParishColors.marianBlue, size: 20),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Time Selection
                      _buildFieldLabel(isSunday ? 'Sunday Mass Time * (Choose Slot)' : 'Weekday Mass Time (Fixed at 5:30 PM)'),
                      if (isSunday)
                        DropdownButtonFormField<String>(
                          value: _selectedMassTime,
                          items: const [
                            DropdownMenuItem(value: '08:00:00', child: Text('8:00 AM (Sunday Morning Mass)', style: TextStyle(fontSize: 13.5))),
                            DropdownMenuItem(value: '16:00:00', child: Text('4:00 PM (Sunday Afternoon Mass)', style: TextStyle(fontSize: 13.5))),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedMassTime = val);
                          },
                          decoration: _inputDecoration(),
                        )
                      else
                        TextFormField(
                          initialValue: '5:30 PM (Wednesday / Friday Evening Mass)',
                          enabled: false,
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: textDarkColor),
                          decoration: _inputDecoration().copyWith(
                            prefixIcon: const Icon(Icons.access_time, size: 18, color: ParishColors.marianBlue),
                            fillColor: ParishColors.borderGrey.withValues(alpha: 0.15),
                          ),
                        ),
                      const SizedBox(height: 20),

                      const Divider(height: 24),

                      // 4 Intention Categories
                      Text('Mass Intention Names & Petitions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDarkColor)),
                      Text('Add up to 10 entries per category using the [+] button.', style: TextStyle(fontSize: 12, color: textMutedColor)),
                      const SizedBox(height: 14),

                      _buildDynamicCategorySection(
                        title: '1. Thanksgiving (Pasasalamat)',
                        subtitle: 'Birthdays, anniversaries, blessings received, recoveries',
                        icon: Icons.celebration,
                        color: ParishColors.marianBlue,
                        controllers: _thanksgivingControllers,
                        hintText: 'e.g. For the gift of life of Maria Santos',
                      ),
                      const SizedBox(height: 16),

                      _buildDynamicCategorySection(
                        title: '2. Repose of the Soul (Para sa Kaluluwa)',
                        subtitle: 'Deceased loved ones, death anniversaries, All Souls',
                        icon: Icons.church,
                        color: const Color(0xFF7C3AED),
                        controllers: _reposeSoulsControllers,
                        hintText: 'e.g. + Juan Dela Cruz (40th Day)',
                      ),
                      const SizedBox(height: 16),

                      _buildDynamicCategorySection(
                        title: '3. Special Intentions (Natatanging Kahilingan)',
                        subtitle: 'Healing, board exams, safe travel, peace of mind',
                        icon: Icons.favorite_border,
                        color: ParishColors.oliveGreen,
                        controllers: _specialIntentionsControllers,
                        hintText: 'e.g. For good health of Dela Cruz Family',
                      ),
                      const SizedBox(height: 16),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildFieldLabel('4. Other Intentions / Petitions'),
                          Text(
                            '${_otherIntentionsController.text.length}/150',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _otherIntentionsController.text.length > 150 ? ParishColors.mercyRed : textMutedColor,
                            ),
                          ),
                        ],
                      ),
                      TextFormField(
                        controller: _otherIntentionsController,
                        maxLength: 150,
                        maxLines: 2,
                        buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(fontSize: 13),
                        decoration: _inputDecoration(hint: 'Other specific intentions (Max 150 characters)'),
                      ),
                      const SizedBox(height: 20),

                      const Divider(height: 24),

                      // Payment & Receipt Module Linkage
                      Text(isStaff ? 'Cashiering & Receipt Linkage' : 'Mass Offering & Payment',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDarkColor)),
                      const SizedBox(height: 12),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: ParishColors.oliveGreen.withValues(alpha: 0.4), width: 1.2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(isStaff ? Icons.point_of_sale : Icons.qr_code_2,
                                        color: ParishColors.oliveGreen, size: 26),
                                    const SizedBox(width: 8),
                                    Text(isStaff ? 'Desk Cash Intake' : 'Parish Official GCash QR',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: ParishColors.oliveGreen)),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: ParishColors.oliveGreen,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text('Stipend: ₱ $_calculatedStipend.00',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ],
                            ),
                            const Divider(height: 20),

                            if (isStaff) ...[
                              Text('Payment Mode:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textDarkColor)),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                value: _paymentMethod,
                                items: const [
                                  DropdownMenuItem(value: 'Cash (Walk-In Desk)', child: Text('Cash (Walk-In at Secretariat Desk)', style: TextStyle(fontSize: 13))),
                                  DropdownMenuItem(value: 'GCash', child: Text('GCash Direct Transfer', style: TextStyle(fontSize: 13))),
                                ],
                                onChanged: (val) {
                                  if (val != null) setState(() => _paymentMethod = val);
                                },
                                decoration: _inputDecoration(),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: ParishColors.marianBlueSurface,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.receipt_long, size: 18, color: ParishColors.marianBlue),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Auto-Receipt: This walk-in intention will be recorded under Receipt #REC-2026-00894 in Receipt Management.',
                                        style: TextStyle(fontSize: 11.5, color: ParishColors.marianBlue, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              Center(
                                child: Column(
                                  children: [
                                    Container(
                                      width: 130,
                                      height: 130,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: ParishColors.borderGrey),
                                      ),
                                      child: const Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.qr_code, size: 85, color: Color(0xFF005CEE)),
                                          Text('SCAN TO PAY GCASH', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF005CEE))),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text('Account: ST. JOHN PAUL II PARISH', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    const Text('GCash No: 0917-882-9912', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF005CEE))),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildFieldLabel('GCash Reference Number (Optional for now)'),
                              TextFormField(
                                controller: _gcashRefController,
                                style: const TextStyle(fontSize: 13),
                                decoration: _inputDecoration(
                                  hint: 'e.g. 1002 9847 1120',
                                  prefixIcon: const Icon(Icons.receipt_long, size: 18, color: ParishColors.oliveGreen),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
                    child: Text('Cancel', style: TextStyle(fontSize: 15, color: textMutedColor)),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ParishColors.marianBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                      ),
                      onPressed: _isSubmitting ? null : _submitMassIntention,
                      icon: _isSubmitting
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.check, size: 20),
                      label: Text(
                        _isSubmitting ? 'Saving...' : (isStaff ? 'Save Walk-In Intention' : 'Confirm & Submit Intention'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
      padding: const EdgeInsets.all(14),
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
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: ParishColors.textDark)),
                    Text(subtitle, style: TextStyle(fontSize: 11, color: ParishColors.textMuted)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                child: Text('${controllers.length}/10', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
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
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(fontSize: 13),
                      decoration: _inputDecoration(hint: '$hintText #${idx + 1}'),
                    ),
                  ),
                  if (controllers.length > 1) ...[
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, size: 20, color: ParishColors.mercyRed),
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
              height: 36,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: color, width: 1.2),
                  foregroundColor: color,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _addListItem(controllers),
                icon: const Icon(Icons.add, size: 16),
                label: Text('Add Another Entry (${controllers.length}/10)', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
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
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ParishColors.textDark),
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint, Widget? prefixIcon}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ParishColors.borderGrey)),
    );
  }
}