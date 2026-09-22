import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../auth/services/auth_service.dart';
import '../../models/mass_intention_model.dart';
import '../../services/mass_intention_service.dart';

void showRescheduleMassIntentionModal(
    BuildContext context, {
      required MassIntentionModel intention,
      VoidCallback? onRescheduled,
    }) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _RescheduleMassIntentionDialog(
      intention: intention,
      onRescheduled: onRescheduled,
    ),
  );
}

class _RescheduleMassIntentionDialog extends StatefulWidget {
  final MassIntentionModel intention;
  final VoidCallback? onRescheduled;

  const _RescheduleMassIntentionDialog({
    required this.intention,
    this.onRescheduled,
  });

  @override
  State<_RescheduleMassIntentionDialog> createState() => _RescheduleMassIntentionDialogState();
}

class _RescheduleMassIntentionDialogState extends State<_RescheduleMassIntentionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  late DateTime _newDate;
  late String _newMassTime;
  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _isParishioner =>
      AuthService.currentUser?.userRole.toLowerCase() == 'user';

  final List<String> _quickReasons = [
    'Requester / Family Request',
    'Mass Schedule Adjusted by Parish',
    'Liturgical Conflict / Fiesta',
    'Typo in Schedule Entry',
  ];

  @override
  void initState() {
    super.initState();
    final item = widget.intention;
    var target = item.scheduledDate.add(const Duration(days: 7));
    while (target.weekday != DateTime.wednesday &&
        target.weekday != DateTime.friday &&
        target.weekday != DateTime.sunday) {
      target = target.add(const Duration(days: 1));
    }
    _newDate = target;
    _updateMassTimeForDate(_newDate);
  }

  void _updateMassTimeForDate(DateTime date) {
    if (date.weekday == DateTime.sunday) {
      _newMassTime = '08:00:00';
    } else {
      _newMassTime = '17:30:00';
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstValidDate = _newDate.isBefore(today) ? _newDate : today;

    final picked = await showDatePicker(
      context: context,
      initialDate: _newDate,
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
        _newDate = picked;
        _updateMassTimeForDate(picked);
      });
    }
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

  Future<void> _confirmReschedule() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final dateStr =
          '${_newDate.year}-${_newDate.month.toString().padLeft(2, '0')}-${_newDate.day.toString().padLeft(2, '0')}';
      final item = widget.intention;

      await MassIntentionService.rescheduleMassIntention(
        intentionId: item.intentionId,
        newDate: dateStr,
        newMassTime: _newMassTime,
        reason: _reasonController.text.trim(),
        previousRemarks: item.remarks,
        previousDate: item.formattedDate,
        previousTime: item.formattedTime12Hour,
      );

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isParishioner
              ? 'Mass intention reschedule request submitted as PENDING.'
              : 'Mass intention schedule updated successfully.'),
          backgroundColor: ParishColors.oliveGreen,
        ),
      );

      widget.onRescheduled?.call();
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
    final item = widget.intention;
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final cardWhite = ParishColors.cardWhite;
    final borderGrey = ParishColors.borderGrey;
    final isSunday = _newDate.weekday == DateTime.sunday;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: cardWhite,
      child: Container(
        width: double.maxFinite,
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF3E8FF),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: borderGrey)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFF7C3AED),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.update, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reschedule Mass Intention',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark),
                        ),
                        Text(
                          '${item.intentionId} • ${item.requesterName}',
                          style: TextStyle(fontSize: 12, color: textMuted),
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
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: ParishColors.mercyRedSurface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: ParishColors.mercyRed),
                          ),
                          child: Text(_errorMessage!, style: const TextStyle(color: ParishColors.mercyRed, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],

                      // Current Schedule Box
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: ParishColors.backgroundLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderGrey),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('CURRENT MASS SCHEDULE:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textMuted)),
                            const SizedBox(height: 2),
                            Text('${item.formattedDate} • ${item.formattedTime12Hour}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
                            Text('Total Intentions: ${item.totalIntentionsCount} names', style: TextStyle(fontSize: 12, color: textMuted)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // New Date Selection (Wed, Fri, Sun only)
                      Text('Select New Date * (Wed, Fri, & Sun Only)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: ParishColors.backgroundLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: borderGrey),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${_newDate.year}-${_newDate.month.toString().padLeft(2, '0')}-${_newDate.day.toString().padLeft(2, '0')} (${_getDayName(_newDate.weekday)})',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textDark),
                              ),
                              const Icon(Icons.calendar_month, color: ParishColors.marianBlue, size: 20),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Mass Time
                      Text(isSunday ? 'Sunday Mass Time *' : 'Weekday Mass Time (Fixed at 5:30 PM)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
                      const SizedBox(height: 6),
                      if (isSunday)
                        DropdownButtonFormField<String>(
                          value: _newMassTime,
                          items: const [
                            DropdownMenuItem(value: '08:00:00', child: Text('8:00 AM (Sunday Morning Mass)', style: TextStyle(fontSize: 13.5))),
                            DropdownMenuItem(value: '16:00:00', child: Text('4:00 PM (Sunday Afternoon Mass)', style: TextStyle(fontSize: 13.5))),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _newMassTime = val);
                          },
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: ParishColors.backgroundLight,
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderGrey)),
                          ),
                        )
                      else
                        TextFormField(
                          initialValue: '5:30 PM (Wednesday / Friday Evening Mass)',
                          enabled: false,
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: textDark),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: ParishColors.borderGrey.withValues(alpha: 0.15),
                            isDense: true,
                            prefixIcon: const Icon(Icons.access_time, size: 18, color: ParishColors.marianBlue),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderGrey)),
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Reason
                      Text('Reason for Rescheduling *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _quickReasons.map((reason) {
                          return ActionChip(
                            label: Text(reason, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                            backgroundColor: ParishColors.marianBlueSurface,
                            onPressed: () => setState(() => _reasonController.text = reason),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),

                      TextFormField(
                        controller: _reasonController,
                        maxLines: 2,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Please specify a reason' : null,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Tap a chip above or type custom reason...',
                          filled: true,
                          fillColor: ParishColors.backgroundLight,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderGrey)),
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
                color: cardWhite,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                border: Border(top: BorderSide(color: borderGrey)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                    child: Text('Cancel', style: TextStyle(fontSize: 15, color: textMuted)),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 46,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                      ),
                      onPressed: _isSubmitting ? null : _confirmReschedule,
                      icon: _isSubmitting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.check, size: 18),
                      label: Text(
                        _isSubmitting ? 'Updating...' : 'Confirm Reschedule',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
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
}