import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../services/appointment_service.dart';
import '../../services/liturgical_calendar_service.dart';

void showScheduleAppointmentModal(BuildContext context, {VoidCallback? onAppointmentSaved}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _ScheduleAppointmentDialog(onAppointmentSaved: onAppointmentSaved),
  );
}

class _ServicePreset {
  final int durationMinutes;
  final String defaultVenue;
  final String defaultOfficiant;
  final String durationLabel;

  const _ServicePreset({
    required this.durationMinutes,
    required this.defaultVenue,
    required this.defaultOfficiant,
    required this.durationLabel,
  });
}

class _ScheduleAppointmentDialog extends StatefulWidget {
  final VoidCallback? onAppointmentSaved;

  const _ScheduleAppointmentDialog({this.onAppointmentSaved});

  @override
  State<_ScheduleAppointmentDialog> createState() => _ScheduleAppointmentDialogState();
}

class _ScheduleAppointmentDialogState extends State<_ScheduleAppointmentDialog> {
  final _formKey = GlobalKey<FormState>();

  final _requesterNameController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _emailController = TextEditingController();
  final _remarksController = TextEditingController();

  String _selectedService = 'Nuptial Mass (Wedding)';
  String _selectedVenue = 'Main Church Altar';
  String _selectedOfficiant = 'Rev. Fr. Joseph Santos';

  late DateTime _selectedDate;
  TimeOfDay _startTime = const TimeOfDay(hour: 10, minute: 0);
  late TimeOfDay _endTime;

  bool _isSubmitting = false;
  String? _errorMessage;

  final Map<String, _ServicePreset> _presets = const {
    'Nuptial Mass (Wedding)': _ServicePreset(
      durationMinutes: 90,
      defaultVenue: 'Main Church Altar',
      defaultOfficiant: 'Rev. Fr. Joseph Santos',
      durationLabel: '1 hr 30 mins',
    ),
    'Community Baptism': _ServicePreset(
      durationMinutes: 60,
      defaultVenue: 'Baptistery & Main Altar',
      defaultOfficiant: 'Rev. Fr. Parochial Vicar',
      durationLabel: '1 hour',
    ),
    'Private Baptism': _ServicePreset(
      durationMinutes: 45,
      defaultVenue: 'Baptistery & Main Altar',
      defaultOfficiant: 'Rev. Fr. Joseph Santos',
      durationLabel: '45 mins',
    ),
    'Funeral Mass & Blessing': _ServicePreset(
      durationMinutes: 60,
      defaultVenue: 'Main Church Altar',
      defaultOfficiant: 'Rev. Fr. Joseph Santos',
      durationLabel: '1 hour',
    ),
    'Anointing of the Sick & Viaticum': _ServicePreset(
      durationMinutes: 45,
      defaultVenue: 'Off-site / Home Visit',
      defaultOfficiant: 'Rev. Fr. Joseph Santos',
      durationLabel: '45 mins',
    ),
    'House / Business Blessing': _ServicePreset(
      durationMinutes: 45,
      defaultVenue: 'Off-site / Home Visit',
      defaultOfficiant: 'Rev. Fr. Joseph Santos',
      durationLabel: '45 mins',
    ),
    'Thanksgiving Mass Intention': _ServicePreset(
      durationMinutes: 60,
      defaultVenue: 'Main Church Altar',
      defaultOfficiant: 'Rev. Fr. Joseph Santos',
      durationLabel: '1 hour',
    ),
    'Canonical Interview / Pre-Cana': _ServicePreset(
      durationMinutes: 45,
      defaultVenue: 'Sanctuary / Sacristy',
      defaultOfficiant: 'Rev. Fr. Joseph Santos',
      durationLabel: '45 mins',
    ),
    'Confession & Spiritual Direction': _ServicePreset(
      durationMinutes: 30,
      defaultVenue: 'Sanctuary / Sacristy',
      defaultOfficiant: 'Rev. Fr. Joseph Santos',
      durationLabel: '30 mins',
    ),
  };

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
    _selectedDate = _getInitialValidDate();
    _endTime = _addMinutes(_startTime, _presets[_selectedService]!.durationMinutes);

    // Warm up the Philippine Liturgical Calendar cache for the selected year
    LiturgicalCalendarService.getCalendarForYear(_selectedDate.year);
  }

  DateTime _getInitialValidDate() {
    var date = DateTime.now().add(const Duration(days: 1));
    while (date.weekday == DateTime.monday || LiturgicalCalendarService.isDateBlockedSync(date)) {
      date = date.add(const Duration(days: 1));
    }
    return date;
  }

  @override
  void dispose() {
    _requesterNameController.dispose();
    _contactNumberController.dispose();
    _emailController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  TimeOfDay _addMinutes(TimeOfDay time, int minutesToAdd) {
    final totalMinutes = (time.hour * 60) + time.minute + minutesToAdd;
    final newHour = (totalMinutes ~/ 60) % 24;
    final newMinute = totalMinutes % 60;
    return TimeOfDay(hour: newHour, minute: newMinute);
  }

  void _onServiceSelected(String service) {
    setState(() {
      _selectedService = service;
      final preset = _presets[service];
      if (preset != null) {
        _selectedVenue = preset.defaultVenue;
        _selectedOfficiant = preset.defaultOfficiant;
        _endTime = _addMinutes(_startTime, preset.durationMinutes);
      }
    });
  }

  Future<void> _pickDate() async {
    await LiturgicalCalendarService.getCalendarForYear(_selectedDate.year);

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      // Blocks Mondays (Clergy Rest Day) AND Catholic Liturgical Solemnities / Celebrations
      selectableDayPredicate: (DateTime day) {
        if (day.weekday == DateTime.monday) return false;
        if (LiturgicalCalendarService.isDateBlockedSync(day)) return false;
        return true;
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime(bool isStart) async {
    final initial = isStart ? _startTime : _endTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
          final preset = _presets[_selectedService];
          final duration = preset?.durationMinutes ?? 60;
          _endTime = _addMinutes(picked, duration);
        } else {
          _endTime = picked;
        }
      });
    }
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

  Future<void> _submitAppointment() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) return;

    final startStr = _formatTimeOfDay(_startTime);
    final endStr = _formatTimeOfDay(_endTime);

    if (startStr.compareTo(endStr) >= 0) {
      setState(() => _errorMessage = 'End Time must be later than Start Time.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final dateStr = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

      await AppointmentService.createAppointment(
        serviceType: _selectedService,
        requesterName: _requesterNameController.text.trim(),
        contactNumber: _contactNumberController.text.trim(),
        email: _emailController.text.trim(),
        date: dateStr,
        startTime: startStr,
        endTime: endStr,
        venue: _selectedVenue,
        officiant: _selectedOfficiant,
        remarks: _remarksController.text.trim(),
      );

      if (!mounted) return;

      Navigator.pop(context);

      final isTuesday = _selectedDate.weekday == DateTime.tuesday;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isTuesday
              ? 'Appointment submitted for Tuesday! Marked as PENDING for Priest approval.'
              : 'Appointment registered and confirmed successfully!'),
          backgroundColor: isTuesday ? ParishColors.goldAccent : ParishColors.oliveGreen,
          duration: const Duration(seconds: 4),
        ),
      );

      widget.onAppointmentSaved?.call();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textDarkColor = ParishColors.textDark;
    final textMutedColor = ParishColors.textMuted;
    final cardWhiteColor = ParishColors.cardWhite;
    final borderGreyColor = ParishColors.borderGrey;
    final currentPreset = _presets[_selectedService];
    final isTuesday = _selectedDate.weekday == DateTime.tuesday;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: cardWhiteColor,
      child: Container(
        width: double.maxFinite,
        constraints: const BoxConstraints(maxHeight: 720),
        child: Column(
          children: [
            // Modal Header
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
                    child: const Icon(Icons.edit_calendar, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Schedule Parish Service',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDarkColor),
                        ),
                        Text(
                          'Operating Hours: 6:00 AM – 7:00 PM (Mondays Closed)',
                          style: TextStyle(fontSize: 12, color: textMutedColor),
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
                      // Collision / Conflict Warning Banner
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
                              const Icon(Icons.warning_amber_rounded, color: ParishColors.mercyRed, size: 22),
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

                      // 1. Service Type Dropdown
                      _buildFieldLabel('Service Requested *'),
                      DropdownButtonFormField<String>(
                        value: _selectedService,
                        items: _presets.keys.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 14)))).toList(),
                        onChanged: (val) {
                          if (val != null) _onServiceSelected(val);
                        },
                        decoration: _inputDecoration(),
                      ),
                      const SizedBox(height: 8),

                      // Smart Preset Information Chip
                      if (currentPreset != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: ParishColors.marianBlueSurface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: ParishColors.marianBlue.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.auto_awesome, size: 16, color: ParishColors.marianBlue),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Preset: ${currentPreset.durationLabel} • Venue & end time set.',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ParishColors.marianBlue),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),

                      // 2. Requester Information
                      _buildFieldLabel('Requester Full Name *'),
                      TextFormField(
                        controller: _requesterNameController,
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                        style: const TextStyle(fontSize: 14),
                        decoration: _inputDecoration(hint: 'e.g. Maria Santos'),
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
                                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
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
                                _buildFieldLabel('Email (Optional)'),
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  style: const TextStyle(fontSize: 14),
                                  decoration: _inputDecoration(hint: 'name@email.com'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 3. Date Selection (Mondays & Liturgical Celebrations Blocked)
                      _buildFieldLabel('Scheduled Date * (Mondays & Solemnities Restricted)'),
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
                                '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textDarkColor),
                              ),
                              const Icon(Icons.calendar_month, color: ParishColors.marianBlue, size: 20),
                            ],
                          ),
                        ),
                      ),

                      // TUESDAY NOTICE
                      if (isTuesday) ...[
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
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Tuesday Parish Priest Approval Notice',
                                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: ParishColors.goldAccent),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Tuesdays may be scheduled, but the Parish Priest will approve the appointment first before it is finalized. This booking will be filed as PENDING.',
                                      style: TextStyle(fontSize: 11.5, color: textDarkColor, height: 1.3),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),

                      // 4. Time Pickers (6 AM to 7 PM limit)
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Start Time *'),
                                InkWell(
                                  onTap: () => _pickTime(true),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                                    decoration: BoxDecoration(
                                      color: ParishColors.backgroundLight,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: borderGreyColor),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(_formatTime12Hour(_startTime), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDarkColor)),
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
                                _buildFieldLabel('End Time (Auto) *'),
                                InkWell(
                                  onTap: () => _pickTime(false),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                                    decoration: BoxDecoration(
                                      color: ParishColors.backgroundLight,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: borderGreyColor),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(_formatTime12Hour(_endTime), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDarkColor)),
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
                      const SizedBox(height: 14),

                      // 5. Venue Selector
                      _buildFieldLabel('Parish Venue *'),
                      DropdownButtonFormField<String>(
                        value: _selectedVenue,
                        items: _venues.map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 13)))).toList(),
                        onChanged: (val) => setState(() => _selectedVenue = val!),
                        decoration: _inputDecoration(),
                      ),
                      const SizedBox(height: 14),

                      // 6. Officiant Selector
                      _buildFieldLabel('Presiding Clergy *'),
                      DropdownButtonFormField<String>(
                        value: _selectedOfficiant,
                        items: _officiants.map((o) => DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(fontSize: 13)))).toList(),
                        onChanged: (val) => setState(() => _selectedOfficiant = val!),
                        decoration: _inputDecoration(),
                      ),
                      const SizedBox(height: 14),

                      // 7. Remarks
                      _buildFieldLabel('Remarks / Special Intentions (Optional)'),
                      TextFormField(
                        controller: _remarksController,
                        maxLines: 2,
                        style: const TextStyle(fontSize: 13),
                        decoration: _inputDecoration(hint: 'Special requests, intentions, or notes'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Modal Actions
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
                        backgroundColor: isTuesday ? ParishColors.goldAccent : ParishColors.marianBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                      ),
                      onPressed: _isSubmitting ? null : _submitAppointment,
                      icon: _isSubmitting
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.check, size: 20),
                      label: Text(
                        _isSubmitting
                            ? 'Validating...'
                            : (isTuesday ? 'Submit for Priest Approval' : 'Confirm Schedule'),
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

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5.0),
      child: Text(
        label,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ParishColors.textDark),
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: ParishColors.backgroundLight,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ParishColors.borderGrey)),
    );
  }
}