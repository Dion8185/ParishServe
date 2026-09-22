import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../auth/services/auth_service.dart';
import '../../models/appointment_model.dart';
import '../../services/appointment_service.dart';
import '../../services/liturgical_calendar_service.dart';

void showRescheduleAppointmentModal(
    BuildContext context, {
      required AppointmentModel appointment,
      VoidCallback? onRescheduled,
    }) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _RescheduleAppointmentDialog(
      appointment: appointment,
      onRescheduled: onRescheduled,
    ),
  );
}

class _RescheduleAppointmentDialog extends StatefulWidget {
  final AppointmentModel appointment;
  final VoidCallback? onRescheduled;

  const _RescheduleAppointmentDialog({
    required this.appointment,
    this.onRescheduled,
  });

  @override
  State<_RescheduleAppointmentDialog> createState() =>
      _RescheduleAppointmentDialogState();
}

class _RescheduleAppointmentDialogState
    extends State<_RescheduleAppointmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  late DateTime _newDate;
  late TimeOfDay _newStartTime;
  late TimeOfDay _newEndTime;
  late String _venue;
  late String _officiant;

  bool _isSubmitting = false;
  String? _errorMessage;

  // Live validation state
  bool _isLiveChecking = false;
  String? _liveConflictWarning;
  Map<String, TimeOfDay>? _suggestedSlot;

  bool get _isParishioner =>
      AuthService.currentUser?.userRole.toLowerCase() == 'user';

  final List<String> _quickReasons = [
    'Parishioner Request',
    'Inclement Weather / Typhoon',
    'Late Document Submissions',
    'Family Emergency / Medical',
    'Work / Travel Conflict',
  ];

  final List<String> _venues = [
    'Main Church Altar',
    'Baptistery & Main Altar',
    'Parish Hall',
    'Mortuary Chapel',
    'Sanctuary / Sacristy',
    'Off-site / Home Visit',
  ];

  final List<String> _officiants = [
    'Rev. Fr. Joseph Santos',
    'Rev. Fr. Parochial Vicar',
    'Guest Priest / Visiting Clergy',
  ];

  @override
  void initState() {
    super.initState();
    final a = widget.appointment;
    var target = a.requestedDate.add(const Duration(days: 7));
    while (target.weekday == DateTime.monday ||
        LiturgicalCalendarService.isDateBlockedSync(target)) {
      target = target.add(const Duration(days: 1));
    }
    _newDate = target;
    _newStartTime = _parseTimeOfDay(a.requestedTime);
    _newEndTime = _parseTimeOfDay(a.endTime);
    _venue = a.venue;
    _officiant = a.officiantName;

    LiturgicalCalendarService.getCalendarForYear(_newDate.year);
    _runLiveConflictCheck();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  TimeOfDay _parseTimeOfDay(String timeStr) {
    try {
      final parts = timeStr.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (_) {
      return const TimeOfDay(hour: 10, minute: 0);
    }
  }

  TimeOfDay _addMinutes(TimeOfDay time, int minutesToAdd) {
    final totalMinutes = (time.hour * 60) + time.minute + minutesToAdd;
    final newHour = (totalMinutes ~/ 60) % 24;
    final newMinute = totalMinutes % 60;
    return TimeOfDay(hour: newHour, minute: newMinute);
  }

  int _getDurationMinutes(TimeOfDay start, TimeOfDay end) {
    final startTotal = start.hour * 60 + start.minute;
    final endTotal = end.hour * 60 + end.minute;
    return endTotal - startTotal;
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m:00';
  }

  String _formatTime12Hour(TimeOfDay time) {
    final hour = time.hour == 0 ? 12 : (time.hour > 12 ? time.hour - 12 : time.hour);
    final period = time.hour >= 12 ? 'PM' : 'AM';
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  /// Live checking and next-slot suggestion for rescheduling
  Future<void> _runLiveConflictCheck() async {
    if (!mounted) return;
    setState(() {
      _isLiveChecking = true;
      _liveConflictWarning = null;
      _suggestedSlot = null;
    });

    final dateStr =
        '${_newDate.year}-${_newDate.month.toString().padLeft(2, '0')}-${_newDate.day.toString().padLeft(2, '0')}';
    final startStr = _formatTimeOfDay(_newStartTime);
    final endStr = _formatTimeOfDay(_newEndTime);

    final warning = await AppointmentService.checkScheduleConflictSilent(
      date: dateStr,
      startTime: startStr,
      endTime: endStr,
      venue: _venue,
      officiant: _officiant,
      excludeAppointmentId: widget.appointment.appointmentId,
    );

    if (!mounted) return;

    if (warning != null) {
      final duration = _getDurationMinutes(_newStartTime, _newEndTime);

      final nextSlot = await AppointmentService.findNextAvailableSlot(
        date: dateStr,
        durationMinutes: duration > 0 ? duration : 60,
        venue: _venue,
        officiant: _officiant,
        preferredStartTime: _newStartTime,
        excludeAppointmentId: widget.appointment.appointmentId,
      );

      setState(() {
        _isLiveChecking = false;
        _liveConflictWarning = warning;
        _suggestedSlot = nextSlot;
      });
    } else {
      setState(() {
        _isLiveChecking = false;
        _liveConflictWarning = null;
        _suggestedSlot = null;
      });
    }
  }

  void _applySuggestedSlot() {
    if (_suggestedSlot != null) {
      setState(() {
        _newStartTime = _suggestedSlot!['start']!;
        _newEndTime = _suggestedSlot!['end']!;
      });
      _runLiveConflictCheck();
    }
  }

  Future<void> _pickDate() async {
    await LiturgicalCalendarService.getCalendarForYear(_newDate.year);

    final picked = await showDatePicker(
      context: context,
      initialDate: _newDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      selectableDayPredicate: (DateTime day) {
        if (day.weekday == DateTime.monday) return false;
        if (LiturgicalCalendarService.isDateBlockedSync(day)) return false;
        return true;
      },
    );
    if (picked != null) {
      setState(() => _newDate = picked);
      _runLiveConflictCheck();
    }
  }

  Future<void> _pickTime(bool isStart) async {
    final initial = isStart ? _newStartTime : _newEndTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _newStartTime = picked;
          final durationMinutes =
          _getDurationMinutes(_newStartTime, _newEndTime);
          _newEndTime = _addMinutes(
              picked, durationMinutes > 0 ? durationMinutes : 60);
        } else {
          _newEndTime = picked;
        }
      });
      _runLiveConflictCheck();
    }
  }

  void _showConflictPromptDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: ParishColors.mercyRed, size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Schedule Conflict Detected',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: ParishColors.mercyRed),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(fontSize: 13.5, color: ParishColors.textDark, height: 1.4),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ParishColors.marianBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Adjust Schedule'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmReschedule() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) return;

    final startStr = _formatTimeOfDay(_newStartTime);
    final endStr = _formatTimeOfDay(_newEndTime);

    if (startStr.compareTo(endStr) >= 0) {
      setState(() => _errorMessage = 'End Time must be later than Start Time.');
      _showConflictPromptDialog('End Time must be later than Start Time.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final dateStr =
          '${_newDate.year}-${_newDate.month.toString().padLeft(2, '0')}-${_newDate.day.toString().padLeft(2, '0')}';
      final a = widget.appointment;

      await AppointmentService.rescheduleAppointment(
        appointmentId: a.appointmentId,
        newDate: dateStr,
        newStartTime: startStr,
        newEndTime: endStr,
        venue: _venue,
        officiant: _officiant,
        reason: _reasonController.text.trim(),
        previousRemarks: a.appointmentRemarks,
        previousDate: a.formattedDate,
        previousTimeRange: a.formattedTimeRange,
      );

      if (!mounted) return;

      Navigator.pop(context); // Close reschedule dialog
      Navigator.pop(context); // Close parent detail dialog

      final isTuesday = _newDate.weekday == DateTime.tuesday;
      final isParishioner = _isParishioner;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isParishioner
              ? 'Reschedule request submitted! Marked as PENDING for Parish Office re-approval.'
              : (isTuesday
              ? 'Appointment rescheduled to Tuesday! Marked as PENDING for Priest approval.'
              : 'Appointment successfully rescheduled!')),
          backgroundColor: (isParishioner || isTuesday)
              ? ParishColors.goldAccent
              : ParishColors.oliveGreen,
          duration: const Duration(seconds: 4),
        ),
      );

      widget.onRescheduled?.call();
    } catch (e) {
      final cleanError = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _errorMessage = cleanError;
      });
      _showConflictPromptDialog(cleanError);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.appointment;
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final cardWhite = ParishColors.cardWhite;
    final borderGrey = ParishColors.borderGrey;
    final isTuesday = _newDate.weekday == DateTime.tuesday;
    final hasConflict = _liveConflictWarning != null;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: cardWhite,
      child: Container(
        width: double.maxFinite,
        constraints: const BoxConstraints(maxHeight: 740),
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
                          _isParishioner ? 'Request Reschedule' : 'Reschedule Service',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark),
                        ),
                        Text(
                          '${a.appointmentId} • ${a.serviceType}',
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
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: ParishColors.mercyRed, size: 22),
                              const SizedBox(width: 10),
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

                      // Current Schedule Summary
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: ParishColors.backgroundLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderGrey),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('CURRENT SCHEDULE:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textMuted)),
                            const SizedBox(height: 2),
                            Text('${a.formattedDate} • ${a.formattedTimeRange}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
                            Text('Venue: ${a.venue} • Presider: ${a.officiantName}', style: TextStyle(fontSize: 12, color: textMuted)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // New Date
                      Text('Select New Date * (Mondays & Solemnities Restricted)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
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
                                '${_newDate.year}-${_newDate.month.toString().padLeft(2, '0')}-${_newDate.day.toString().padLeft(2, '0')}',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textDark),
                              ),
                              const Icon(Icons.calendar_month, color: ParishColors.marianBlue, size: 20),
                            ],
                          ),
                        ),
                      ),

                      if (isTuesday || _isParishioner) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: ParishColors.goldLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: ParishColors.goldAccent),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.info_outline, color: ParishColors.goldAccent, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _isParishioner
                                      ? 'Reschedule Notice: Submitting a new schedule will change this appointment to PENDING status until verified and re-approved by Parish Staff.'
                                      : 'Tuesday Notice: Rescheduling to a Tuesday requires approval from the Parish Priest before finalization. The status will update to PENDING.',
                                  style: TextStyle(fontSize: 11.5, color: textDark, height: 1.3),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),

                      // New Times
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('New Start Time *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () => _pickTime(true),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: ParishColors.backgroundLight,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: hasConflict ? ParishColors.mercyRed : borderGrey),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(_formatTime12Hour(_newStartTime), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
                                        const Icon(Icons.access_time, size: 18, color: ParishColors.marianBlue),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('New End Time *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () => _pickTime(false),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: ParishColors.backgroundLight,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: hasConflict ? ParishColors.mercyRed : borderGrey),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(_formatTime12Hour(_newEndTime), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
                                        const Icon(Icons.access_time, size: 18, color: ParishColors.marianBlue),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Live Conflict Checker
                      const SizedBox(height: 10),
                      if (_isLiveChecking)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            children: [
                              const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                              const SizedBox(width: 8),
                              Text('Checking slot availability...', style: TextStyle(fontSize: 12, color: textMuted)),
                            ],
                          ),
                        )
                      else if (_liveConflictWarning != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: ParishColors.mercyRedSurface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: ParishColors.mercyRed),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.warning_amber_rounded, color: ParishColors.mercyRed, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _liveConflictWarning!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: ParishColors.mercyRed,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (_suggestedSlot != null) ...[
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF7C3AED),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: _applySuggestedSlot,
                                    icon: const Icon(Icons.bolt, size: 18),
                                    label: Text(
                                      'Auto-Set Next Open Slot: ${_formatTime12Hour(_suggestedSlot!['start']!)} – ${_formatTime12Hour(_suggestedSlot!['end']!)}',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: ParishColors.oliveGreenSurface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: ParishColors.oliveGreen.withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle, color: ParishColors.oliveGreen, size: 16),
                              SizedBox(width: 6),
                              Text(
                                'Reschedule slot is open and available.',
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: ParishColors.oliveGreen),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),

                      // Venue Selector (Locked for parishioners, staff-assigned)
                      Text(_isParishioner ? 'Parish Venue (Staff Assigned)' : 'Parish Venue *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _venue,
                        items: _venues.map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 13)))).toList(),
                        onChanged: _isParishioner ? null : (val) {
                          if (val != null) {
                            setState(() => _venue = val);
                            _runLiveConflictCheck();
                          }
                        },
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: _isParishioner ? ParishColors.borderGrey.withValues(alpha: 0.15) : ParishColors.backgroundLight,
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderGrey)),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Presider Selector (Locked for parishioners, parish priest assigned)
                      Text(_isParishioner ? 'Presiding Clergy (Parish Assigned)' : 'Presiding Clergy *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _officiant,
                        items: _officiants.map((o) => DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(fontSize: 13)))).toList(),
                        onChanged: _isParishioner ? null : (val) {
                          if (val != null) {
                            setState(() => _officiant = val);
                            _runLiveConflictCheck();
                          }
                        },
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: _isParishioner ? ParishColors.borderGrey.withValues(alpha: 0.15) : ParishColors.backgroundLight,
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderGrey)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text('Reason for Rescheduling *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _quickReasons.map((reason) {
                          return ActionChip(
                            label: Text(reason, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                            backgroundColor: ParishColors.marianBlueSurface,
                            onPressed: () {
                              setState(() {
                                _reasonController.text = reason;
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),

                      TextFormField(
                        controller: _reasonController,
                        maxLines: 2,
                        validator: (v) => v == null || v.trim().isEmpty ? 'Please specify a reason' : null,
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
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hasConflict
                            ? ParishColors.borderGrey
                            : const Color(0xFF7C3AED), // Royal Violet
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                      ),
                      onPressed: _isSubmitting ? null : _confirmReschedule,
                      icon: _isSubmitting
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.check, size: 20),
                      label: Text(
                        _isSubmitting
                            ? 'Checking Conflicts...'
                            : (_isParishioner ? 'Submit Reschedule Request' : 'Confirm Reschedule'),
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
}