// =============================================================================
// FILE: lib/features/appointments/presentation/dialogs/reschedule_appointment_dialog.dart
// =============================================================================

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
  final _outsideLocationController = TextEditingController();

  late DateTime _newDate;
  late TimeOfDay _newServiceTime;
  late int _durationMinutes;
  late String _officiant;
  bool _isOnParishGrounds = true;
  bool _allowMondayException = false;

  bool _isSubmitting = false;
  String? _errorMessage;

  // Live validation state
  bool _isLiveChecking = false;
  String? _liveConflictWarning;
  Map<String, TimeOfDay>? _suggestedSlot;

  bool get _isParishioner =>
      AuthService.currentUser?.userRole.toLowerCase() == 'user';

  bool get _isCommunityBaptism =>
      widget.appointment.serviceType.toLowerCase().contains('community baptism');

  bool get _isAnytimeService =>
      AppointmentService.isAnytimeService(widget.appointment.serviceType);

  final List<String> _quickReasons = [
    'Parishioner Request',
    'Inclement Weather / Typhoon',
    'Document Processing Delay',
    'Family Emergency / Medical',
    'Work / Travel Conflict',
    'Priest Liturgical Reassignment',
  ];

  final List<String> _officiants = [
    'Rev. Fr. Roy',
    'Guest Priest / Visiting Clergy',
  ];

  @override
  void initState() {
    super.initState();
    final a = widget.appointment;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    _durationMinutes = AppointmentService.getMinimumDurationMinutes(a.serviceType);

    // Initial venue extraction
    final currentVenue = a.venue.trim();
    if (currentVenue.toLowerCase().contains('outside')) {
      _isOnParishGrounds = false;
      _outsideLocationController.text = currentVenue
          .replaceAll(RegExp(r'^Outside Parish\s*(\((.*)\))?', caseSensitive: false), r'$2')
          .trim();
    } else {
      _isOnParishGrounds = true;
      _outsideLocationController.clear();
    }

    var target = a.requestedDate.add(const Duration(days: 7));
    if (target.isBefore(today)) {
      target = today.add(const Duration(days: 1));
    }

    while (target.isBefore(today) ||
        (!_isAnytimeService && target.weekday == DateTime.monday && _isParishioner) ||
        LiturgicalCalendarService.isDateBlockedSync(target) ||
        (_isCommunityBaptism &&
            target.weekday != DateTime.saturday &&
            target.weekday != DateTime.sunday)) {
      target = target.add(const Duration(days: 1));
    }
    _newDate = target;

    if (_isCommunityBaptism) {
      _newServiceTime = const TimeOfDay(hour: 11, minute: 0);
    } else {
      _newServiceTime = _parseTimeOfDay(a.requestedTime);
    }

    final rawOfficiant = a.officiantName.trim();
    if (_officiants.contains(rawOfficiant)) {
      _officiant = rawOfficiant;
    } else {
      _officiant = 'Rev. Fr. Roy';
    }

    if (_isParishioner) {
      _officiant = 'Rev. Fr. Roy';
    }

    LiturgicalCalendarService.getCalendarForYear(_newDate.year);
    _runLiveConflictCheck();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _outsideLocationController.dispose();
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

  TimeOfDay _calculateEndTime(TimeOfDay start, int durationMinutes) {
    final totalMinutes = (start.hour * 60) + start.minute + durationMinutes;
    final newHour = (totalMinutes ~/ 60) % 24;
    final newMinute = totalMinutes % 60;
    return TimeOfDay(hour: newHour, minute: newMinute);
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

  Future<void> _runLiveConflictCheck() async {
    if (!mounted) return;
    setState(() {
      _isLiveChecking = true;
      _liveConflictWarning = null;
      _suggestedSlot = null;
    });

    if (_isAnytimeService) {
      setState(() => _isLiveChecking = false);
      return;
    }

    final dateStr =
        '${_newDate.year}-${_newDate.month.toString().padLeft(2, '0')}-${_newDate.day.toString().padLeft(2, '0')}';
    final startStr = _formatTimeOfDay(_newServiceTime);
    final computedEnd = _calculateEndTime(_newServiceTime, _durationMinutes);
    final endStr = _formatTimeOfDay(computedEnd);
    final venueStr = _isOnParishGrounds
        ? 'Parish Grounds'
        : 'Outside Parish (${_outsideLocationController.text.trim()})';

    final warning = await AppointmentService.checkScheduleConflictSilent(
      date: dateStr,
      startTime: startStr,
      endTime: endStr,
      venue: venueStr,
      officiant: _officiant,
      serviceType: widget.appointment.serviceType,
      excludeAppointmentId: widget.appointment.appointmentId,
      allowMondayException: _allowMondayException,
    );

    if (!mounted) return;

    if (warning != null) {
      final nextSlot = await AppointmentService.findNextAvailableSlot(
        date: dateStr,
        durationMinutes: _durationMinutes,
        venue: venueStr,
        officiant: _officiant,
        preferredStartTime: _newServiceTime,
        serviceType: widget.appointment.serviceType,
        excludeAppointmentId: widget.appointment.appointmentId,
        allowMondayException: _allowMondayException,
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
        _newServiceTime = _suggestedSlot!['start']!;
      });
      _runLiveConflictCheck();
    }
  }

  Future<void> _pickDate() async {
    await LiturgicalCalendarService.getCalendarForYear(_newDate.year);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: _newDate.isBefore(today) ? today : _newDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: 730)),
      selectableDayPredicate: (DateTime day) {
        if (day.isBefore(today)) return false;
        if (!_isAnytimeService && day.weekday == DateTime.monday && _isParishioner) return false;
        if (LiturgicalCalendarService.isDateBlockedSync(day)) return false;
        if (_isCommunityBaptism &&
            day.weekday != DateTime.saturday &&
            day.weekday != DateTime.sunday) {
          return false;
        }
        return true;
      },
    );

    if (picked != null) {
      if (picked.weekday == DateTime.monday && !_isAnytimeService) {
        final allowed = await _confirmMondayExceptionDialog(picked);
        if (!allowed) return;
        _allowMondayException = true;
      } else {
        _allowMondayException = false;
      }

      setState(() => _newDate = picked);
      _runLiveConflictCheck();
    }
  }

  Future<bool> _confirmMondayExceptionDialog(DateTime date) async {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: ParishColors.goldAccent, size: 24),
            SizedBox(width: 8),
            Text('Monday Schedule Exception', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          'Mondays ($dateStr) are designated Clergy Rest Days and the parish office is closed.\n\n'
              'Do you want to reschedule this appointment to Monday as an administrative exception?',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ParishColors.marianBlue,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Allow Monday Exception'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<void> _pickServiceTime() async {
    if (_isCommunityBaptism) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Community Baptism ceremony strictly takes place at 11:00 AM on Weekends.'),
          backgroundColor: ParishColors.goldAccent,
        ),
      );
      return;
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: _newServiceTime,
    );

    if (picked != null) {
      setState(() {
        _newServiceTime = picked;
      });
      _runLiveConflictCheck();
    }
  }

  void _showConflictPromptDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: ParishColors.cardWhite,
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: ParishColors.mercyRed, size: 24),
            SizedBox(width: 8),
            Text('Schedule Collision Notice', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(fontSize: 13, color: ParishColors.textDark, height: 1.4),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ParishColors.marianBlue,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Adjust Slot'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmReschedule() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDay = DateTime(_newDate.year, _newDate.month, _newDate.day);

    if (targetDay.isBefore(today)) {
      const msg = 'Cannot reschedule appointments to past dates.';
      setState(() => _errorMessage = msg);
      _showConflictPromptDialog(msg);
      return;
    }

    // Resolve Venue cleanly
    String resolvedVenue;
    if (_isOnParishGrounds) {
      resolvedVenue = 'Parish Grounds';
    } else {
      final loc = _outsideLocationController.text.trim();
      if (loc.isEmpty) {
        setState(() => _errorMessage = 'Please specify the location outside the parish.');
        return;
      }
      resolvedVenue = 'Outside Parish ($loc)';
    }

    final startStr = _formatTimeOfDay(_newServiceTime);
    final computedEnd = _calculateEndTime(_newServiceTime, _durationMinutes);
    final endStr = _formatTimeOfDay(computedEnd);
    final dateStr =
        '${_newDate.year}-${_newDate.month.toString().padLeft(2, '0')}-${_newDate.day.toString().padLeft(2, '0')}';

    final a = widget.appointment;
    final isStaff = !_isParishioner;
    final existingStatus = a.appointmentStatus.toLowerCase();

    // Staff edits strictly preserve confirmed status
    final String targetStatus = (isStaff && existingStatus == 'confirmed')
        ? 'confirmed'
        : (isStaff ? existingStatus : 'pending');

    setState(() => _isSubmitting = true);

    try {
      await AppointmentService.rescheduleAppointment(
        appointmentId: a.appointmentId,
        newDate: dateStr,
        newStartTime: startStr,
        newEndTime: endStr,
        venue: resolvedVenue,
        officiant: _isParishioner ? 'Rev. Fr. Roy' : _officiant,
        reason: _reasonController.text.trim(),
        serviceType: a.serviceType,
        previousRemarks: a.appointmentRemarks,
        previousDate: a.formattedDate,
        previousTimeRange: a.formattedTimeRange,
        targetStatus: targetStatus,
        allowMondayException: _allowMondayException,
      );

      if (!mounted) return;

      Navigator.pop(context); // Close reschedule modal

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isStaff
                ? 'Appointment rescheduled to $dateStr at ${_formatTime12Hour(_newServiceTime)}.'
                : 'Reschedule request submitted for parish review.',
          ),
          backgroundColor: targetStatus == 'confirmed'
              ? ParishColors.oliveGreen
              : ParishColors.goldAccent,
          duration: const Duration(seconds: 4),
        ),
      );

      widget.onRescheduled?.call();
    } catch (e) {
      final cleanError = e.toString().replaceFirst('Exception: ', '');
      setState(() => _errorMessage = cleanError);
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
    final isMonday = _newDate.weekday == DateTime.monday;
    final hasConflict = _liveConflictWarning != null;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: cardWhite,
      child: Container(
        width: double.maxFinite,
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
        child: Column(
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF3E8FF),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                border: Border(bottom: BorderSide(color: borderGrey)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: const BoxDecoration(
                      color: Color(0xFF7C3AED),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit_calendar, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isParishioner ? 'Request Reschedule' : 'Reschedule Ceremony Slot',
                          style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: textDark),
                        ),
                        Text(
                          '${a.appointmentId} • ${a.serviceType}',
                          style: TextStyle(fontSize: 11.5, color: textMuted),
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
                padding: const EdgeInsets.all(18),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_errorMessage != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: ParishColors.mercyRedSurface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: ParishColors.mercyRed),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: ParishColors.mercyRed, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ParishColors.mercyRed),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Current Schedule Summary Box
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
                            Text('CURRENT SCHEDULE ON RECORD:', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: textMuted)),
                            const SizedBox(height: 2),
                            Text('${a.formattedDate} at ${AppointmentService.formatTime12Hour(a.requestedTime)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
                            Text('Venue: ${a.venue}', style: TextStyle(fontSize: 11.5, color: textMuted)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // New Date & Single Service Time
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('New Date *'),
                                InkWell(
                                  onTap: _pickDate,
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    height: 46,
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
                                          '${_newDate.year}-${_newDate.month.toString().padLeft(2, '0')}-${_newDate.day.toString().padLeft(2, '0')}',
                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark),
                                        ),
                                        const Icon(Icons.calendar_month, size: 18, color: ParishColors.marianBlue),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('New Service Time *'),
                                InkWell(
                                  onTap: _pickServiceTime,
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    height: 46,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: _isCommunityBaptism ? ParishColors.borderGrey.withOpacity(0.15) : ParishColors.backgroundLight,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: borderGrey),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _formatTime12Hour(_newServiceTime),
                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark),
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: ParishColors.marianBlueSurface,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text('~${_durationMinutes}m', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: ParishColors.marianBlue)),
                                            ),
                                            const SizedBox(width: 4),
                                            const Icon(Icons.access_time, size: 16, color: ParishColors.marianBlue),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      if (isMonday && !_isAnytimeService) ...[
                        const SizedBox(height: 6),
                        Text(
                          _allowMondayException
                              ? 'Monday Exception Granted: Will be scheduled on Monday.'
                              : 'Monday Notice: Secretariat is closed for Clergy Rest Day. Slot filed as Pending.',
                          style: TextStyle(fontSize: 11, color: _allowMondayException ? ParishColors.oliveGreen : textMuted),
                        ),
                      ],
                      if (isTuesday) ...[
                        const SizedBox(height: 6),
                        Text('Tuesday Notice: Requires Rev. Fr. Roy confirmation before finalization.', style: TextStyle(fontSize: 11, color: textMuted)),
                      ],
                      const SizedBox(height: 14),

                      // Venue: Parish Grounds (As Is) vs. Outside Parish (Custom Free-Text)
                      _buildFieldLabel('Venue Location *'),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: ParishColors.backgroundLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderGrey),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: ChoiceChip(
                                    label: const Center(child: Text('Parish Grounds', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                                    selected: _isOnParishGrounds,
                                    onSelected: (_) {
                                      setState(() {
                                        _isOnParishGrounds = true;
                                        _outsideLocationController.clear();
                                      });
                                      _runLiveConflictCheck();
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ChoiceChip(
                                    label: const Center(child: Text('Outside Parish', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                                    selected: !_isOnParishGrounds,
                                    onSelected: (_) {
                                      setState(() => _isOnParishGrounds = false);
                                      _runLiveConflictCheck();
                                    },
                                  ),
                                ),
                              ],
                            ),

                            // If Outside Parish: presents empty text field for custom entry
                            if (!_isOnParishGrounds) ...[
                              const SizedBox(height: 8),
                              TextField(
                                controller: _outsideLocationController,
                                style: const TextStyle(fontSize: 12.5),
                                onChanged: (_) => _runLiveConflictCheck(),
                                decoration: InputDecoration(
                                  hintText: 'Type location (e.g. Sitio Ilaya, Brgy. Labuin / San Pedro Hospital)',
                                  filled: true,
                                  fillColor: Colors.white,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Presider (if staff)
                      if (!_isParishioner) ...[
                        _buildFieldLabel('Presiding Clergy *'),
                        DropdownButtonFormField<String>(
                          value: _officiants.contains(_officiant) ? _officiant : 'Rev. Fr. Roy',
                          isExpanded: true,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: ParishColors.backgroundLight,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          items: _officiants.map((o) => DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(fontSize: 13)))).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _officiant = val);
                              _runLiveConflictCheck();
                            }
                          },
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Reason for Rescheduling
                      _buildFieldLabel('Reason for Rescheduling *'),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: _quickReasons.map((reason) {
                          return ActionChip(
                            label: Text(reason, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600)),
                            backgroundColor: ParishColors.marianBlueSurface,
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
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
                        maxLength: 200,
                        validator: (v) => v == null || v.trim().isEmpty ? 'Please provide a reason' : null,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Tap a reason above or type specific explanation...',
                          filled: true,
                          fillColor: ParishColors.backgroundLight,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),

                      if (_liveConflictWarning != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: ParishColors.mercyRedSurface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: ParishColors.mercyRed),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.warning_amber_rounded, color: ParishColors.mercyRed, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(_liveConflictWarning!, style: const TextStyle(fontSize: 11.5, color: ParishColors.mercyRed, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              if (_suggestedSlot != null) ...[
                                const SizedBox(height: 6),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED), foregroundColor: Colors.white),
                                    onPressed: _applySuggestedSlot,
                                    icon: const Icon(Icons.bolt, size: 16),
                                    label: Text('Auto-Set Open Slot: ${_formatTime12Hour(_suggestedSlot!['start']!)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Modal Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: cardWhite,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                border: Border(top: BorderSide(color: borderGrey)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                    child: Text('Cancel', style: TextStyle(color: textMuted, fontSize: 13.5)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasConflict ? ParishColors.borderGrey : const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onPressed: _isSubmitting ? null : _confirmReschedule,
                    icon: _isSubmitting
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.check, size: 16),
                    label: Text(
                      _isSubmitting
                          ? 'Checking...'
                          : (_isParishioner ? 'Submit Reschedule Request' : 'Confirm Reschedule'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5.0),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ParishColors.textDark),
      ),
    );
  }
}