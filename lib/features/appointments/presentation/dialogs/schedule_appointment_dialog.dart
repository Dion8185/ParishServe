import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/colors.dart';
import '../../services/appointment_service.dart';
import '../../services/liturgical_calendar_service.dart';

void showScheduleAppointmentModal(
    BuildContext context, {
      DateTime? initialDate,
      VoidCallback? onAppointmentSaved,
    }) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _ScheduleAppointmentDialog(
      initialDate: initialDate,
      onAppointmentSaved: onAppointmentSaved,
    ),
  );
}

/// Custom Auto-Masking Formatter for Philippine Mobile Numbers (09XX-XXX-XXXX)
class PhilippinePhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length > 11) {
      return oldValue;
    }

    final buffer = StringBuffer();
    for (int i = 0; i < digitsOnly.length; i++) {
      buffer.write(digitsOnly[i]);
      if ((i == 3 || i == 6) && i != digitsOnly.length - 1) {
        buffer.write('-');
      }
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Auto-Capitalization (Title Case) Formatter for Names
class TitleCaseInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    final words = text.split(' ');
    final capitalized = words.map((w) {
      if (w.isEmpty) return '';
      return w[0].toUpperCase() + (w.length > 1 ? w.substring(1) : '');
    }).join(' ');

    return TextEditingValue(
      text: capitalized,
      selection: newValue.selection,
    );
  }
}

class _ServicePreset {
  final int durationMinutes;
  final String defaultVenue;
  final String defaultOfficiant;
  final String durationLabel;
  final bool isCommunityBaptism;

  const _ServicePreset({
    required this.durationMinutes,
    required this.defaultVenue,
    required this.defaultOfficiant,
    required this.durationLabel,
    this.isCommunityBaptism = false,
  });
}

class _ScheduleAppointmentDialog extends StatefulWidget {
  final DateTime? initialDate;
  final VoidCallback? onAppointmentSaved;

  const _ScheduleAppointmentDialog({
    this.initialDate,
    this.onAppointmentSaved,
  });

  @override
  State<_ScheduleAppointmentDialog> createState() => _ScheduleAppointmentDialogState();
}

class _ScheduleAppointmentDialogState extends State<_ScheduleAppointmentDialog> {
  final _formKey = GlobalKey<FormState>();

  final _requesterNameController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _emailController = TextEditingController();
  final _remarksController = TextEditingController();

  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _contactFocusNode = FocusNode();
  final FocusNode _emailFocusNode = FocusNode();

  String _selectedService = 'Nuptial Mass (Wedding)';
  String _selectedVenue = 'Main Church Altar';
  String _selectedOfficiant = 'Rev. Fr. Joseph Santos';

  late DateTime _selectedDate;
  TimeOfDay _startTime = const TimeOfDay(hour: 10, minute: 0);
  late TimeOfDay _endTime;

  bool _isSubmitting = false;
  String? _errorMessage;

  // Live Validation & Smart Conflict State
  bool _isLiveChecking = false;
  String? _liveConflictWarning;
  String? _duplicateRequesterWarning;
  Map<String, TimeOfDay>? _suggestedSlot;
  Timer? _debounceTimer;

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
      isCommunityBaptism: true, // Restricted to Weekends & 11 AM - 1 PM
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
    if (widget.initialDate != null) {
      var target = DateTime(
        widget.initialDate!.year,
        widget.initialDate!.month,
        widget.initialDate!.day,
      );
      if (_presets[_selectedService]?.isCommunityBaptism == true &&
          target.weekday != DateTime.saturday &&
          target.weekday != DateTime.sunday) {
        target = _getInitialValidDate();
      }
      _selectedDate = target;
    } else {
      _selectedDate = _getInitialValidDate();
    }

    _applyPresetInitialTimes();
    LiturgicalCalendarService.getCalendarForYear(_selectedDate.year);

    _nameFocusNode.addListener(() => setState(() {}));
    _contactFocusNode.addListener(() => setState(() {}));
    _emailFocusNode.addListener(() => setState(() {}));

    _runLiveConflictCheck();
  }

  DateTime _getInitialValidDate() {
    var date = DateTime.now().add(const Duration(days: 1));
    final isCommunity = _presets[_selectedService]?.isCommunityBaptism ?? false;

    while (date.weekday == DateTime.monday ||
        LiturgicalCalendarService.isDateBlockedSync(date) ||
        (isCommunity && date.weekday != DateTime.saturday && date.weekday != DateTime.sunday)) {
      date = date.add(const Duration(days: 1));
    }
    return DateTime(date.year, date.month, date.day);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _requesterNameController.dispose();
    _contactNumberController.dispose();
    _emailController.dispose();
    _remarksController.dispose();
    _nameFocusNode.dispose();
    _contactFocusNode.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  // ===========================================================================
  // Validation Helpers (Positive Green Reinforcement)
  // ===========================================================================
  bool get _isNameValid {
    final text = _requesterNameController.text.trim();
    if (text.isEmpty) return false;
    final parts = text.split(RegExp(r'\s+'));
    return parts.length >= 2 && RegExp(r'^[a-zA-Z\s\.\-]+$').hasMatch(text);
  }

  bool get _isPhoneValid {
    final digits = _contactNumberController.text.replaceAll(RegExp(r'\D'), '');
    return digits.length == 11 && digits.startsWith('09');
  }

  bool get _isEmailValid {
    final text = _emailController.text.trim();
    if (text.isEmpty) return true;
    return RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[\w\-]{2,4}$').hasMatch(text);
  }

  TimeOfDay _addMinutes(TimeOfDay time, int minutesToAdd) {
    final totalMinutes = (time.hour * 60) + time.minute + minutesToAdd;
    final newHour = (totalMinutes ~/ 60) % 24;
    final newMinute = totalMinutes % 60;
    return TimeOfDay(hour: newHour, minute: newMinute);
  }

  void _applyPresetInitialTimes() {
    final preset = _presets[_selectedService]!;
    if (preset.isCommunityBaptism) {
      _startTime = const TimeOfDay(hour: 11, minute: 0); // 11:00 AM mandatory start
    }
    _endTime = _addMinutes(_startTime, preset.durationMinutes);
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

  /// Live Conflict & Duplicate Requester Checker (Debounced)
  void _triggerDebouncedValidation() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _runLiveConflictCheck();
      _runDuplicateRequesterCheck();
    });
  }

  Future<void> _runDuplicateRequesterCheck() async {
    final name = _requesterNameController.text.trim();
    if (name.length < 4) {
      if (_duplicateRequesterWarning != null) {
        setState(() => _duplicateRequesterWarning = null);
      }
      return;
    }

    final dateStr = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    final warning = await AppointmentService.checkDuplicateRequester(
      requesterName: name,
      date: dateStr,
    );

    if (mounted) {
      setState(() => _duplicateRequesterWarning = warning);
    }
  }

  Future<void> _runLiveConflictCheck() async {
    if (!mounted) return;
    setState(() {
      _isLiveChecking = true;
      _liveConflictWarning = null;
      _suggestedSlot = null;
    });

    final dateStr = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    final startStr = _formatTimeOfDay(_startTime);
    final endStr = _formatTimeOfDay(_endTime);

    final warning = await AppointmentService.checkScheduleConflictSilent(
      date: dateStr,
      startTime: startStr,
      endTime: endStr,
      venue: _selectedVenue,
      officiant: _selectedOfficiant,
    );

    if (!mounted) return;

    if (warning != null) {
      final preset = _presets[_selectedService];
      final duration = preset?.durationMinutes ?? 60;

      final nextSlot = await AppointmentService.findNextAvailableSlot(
        date: dateStr,
        durationMinutes: duration,
        venue: _selectedVenue,
        officiant: _selectedOfficiant,
        preferredStartTime: _startTime,
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
        _startTime = _suggestedSlot!['start']!;
        _endTime = _suggestedSlot!['end']!;
      });
      _runLiveConflictCheck();
    }
  }

  void _onServiceSelected(String service) {
    setState(() {
      _selectedService = service;
      final preset = _presets[service];
      if (preset != null) {
        _selectedVenue = preset.defaultVenue;
        _selectedOfficiant = preset.defaultOfficiant;

        if (preset.isCommunityBaptism) {
          _startTime = const TimeOfDay(hour: 11, minute: 0);
          if (_selectedDate.weekday != DateTime.saturday && _selectedDate.weekday != DateTime.sunday) {
            _selectedDate = _getInitialValidDate();
          }
        }

        _endTime = _addMinutes(_startTime, preset.durationMinutes);
      }
    });
    _runLiveConflictCheck();
  }

  Future<void> _pickDate() async {
    await LiturgicalCalendarService.getCalendarForYear(_selectedDate.year);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstValidDate = _selectedDate.isBefore(today) ? _selectedDate : today;
    final preset = _presets[_selectedService];
    final isCommunity = preset?.isCommunityBaptism ?? false;

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: firstValidDate,
      lastDate: today.add(const Duration(days: 365)),
      selectableDayPredicate: (DateTime day) {
        if (day.weekday == DateTime.monday) return false;
        if (LiturgicalCalendarService.isDateBlockedSync(day)) return false;
        if (isCommunity && day.weekday != DateTime.saturday && day.weekday != DateTime.sunday) {
          return false;
        }
        return true;
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _runLiveConflictCheck();
    }
  }

  Future<void> _pickTime(bool isStart) async {
    final preset = _presets[_selectedService];

    if (preset?.isCommunityBaptism == true && isStart) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Community Baptism start time is strictly fixed at 11:00 AM.'),
          backgroundColor: ParishColors.goldAccent,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final initial = isStart ? _startTime : _endTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked != null) {
      if (preset?.isCommunityBaptism == true) {
        final totalMin = picked.hour * 60 + picked.minute;
        if (totalMin < 660 || totalMin > 780) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Community Baptism must be scheduled between 11:00 AM and 1:00 PM.'),
              backgroundColor: ParishColors.mercyRed,
            ),
          );
          return;
        }
      }

      setState(() {
        if (isStart) {
          _startTime = picked;
          final duration = preset?.durationMinutes ?? 60;
          _endTime = _addMinutes(picked, duration);
        } else {
          _endTime = picked;
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
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: ParishColors.mercyRed),
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

  Future<void> _submitAppointment() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) return;

    final preset = _presets[_selectedService];
    if (preset?.isCommunityBaptism == true) {
      if (_selectedDate.weekday != DateTime.saturday && _selectedDate.weekday != DateTime.sunday) {
        setState(() => _errorMessage = 'Community Baptism is strictly restricted to Weekends (Saturday & Sunday).');
        return;
      }
      final startMin = _startTime.hour * 60 + _startTime.minute;
      if (startMin < 660 || startMin > 780) {
        setState(() => _errorMessage = 'Community Baptism must take place between 11:00 AM and 1:00 PM.');
        return;
      }
    }

    final startStr = _formatTimeOfDay(_startTime);
    final endStr = _formatTimeOfDay(_endTime);

    if (startStr.compareTo(endStr) >= 0) {
      setState(() => _errorMessage = 'End Time must be later than Start Time.');
      _showConflictPromptDialog('End Time must be later than Start Time.');
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
      final cleanError = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _errorMessage = cleanError;
      });
      _showConflictPromptDialog(cleanError);
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
    final hasConflict = _liveConflictWarning != null;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: cardWhiteColor,
      child: Container(
        width: double.maxFinite,
        constraints: const BoxConstraints(maxHeight: 740),
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
                          currentPreset?.isCommunityBaptism == true
                              ? 'Community Baptism: Weekends Only (11:00 AM – 1:00 PM)'
                              : 'Operating Hours: 6:00 AM – 7:00 PM (Mondays Closed)',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: currentPreset?.isCommunityBaptism == true ? FontWeight.bold : FontWeight.normal,
                            color: currentPreset?.isCommunityBaptism == true ? ParishColors.marianBlue : textMutedColor,
                          ),
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
                      // Form Error Banner
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
                                  currentPreset.isCommunityBaptism
                                      ? 'Preset: Community Baptism (Weekends 11AM–1PM • Baptistery)'
                                      : 'Preset: ${currentPreset.durationLabel} • Venue & end time set.',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ParishColors.marianBlue),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),

                      // Requester Full Name (with Title Case & Gentle Validation)
                      _buildFieldLabel('Requester Full Name *'),
                      TextFormField(
                        controller: _requesterNameController,
                        focusNode: _nameFocusNode,
                        inputFormatters: [TitleCaseInputFormatter()],
                        onChanged: (_) {
                          setState(() {});
                          _triggerDebouncedValidation();
                        },
                        validator: (v) {
                          final text = v?.trim() ?? '';
                          if (text.isEmpty) return 'Please enter requester full name';
                          final words = text.split(RegExp(r'\s+'));
                          if (words.length < 2) {
                            return 'Please enter both First Name and Last Name';
                          }
                          if (!RegExp(r'^[a-zA-Z\s\.\-]+$').hasMatch(text)) {
                            return 'Name must contain letters only';
                          }
                          return null;
                        },
                        style: const TextStyle(fontSize: 14),
                        decoration: _inputDecoration(
                          hint: 'First Name and Last Name',
                          suffixIcon: _isNameValid
                              ? const Icon(Icons.check_circle, color: ParishColors.oliveGreen, size: 20)
                              : null,
                        ),
                      ),

                      // Duplicate Requester Same-Day Notice
                      if (_duplicateRequesterWarning != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: ParishColors.goldLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: ParishColors.goldAccent),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, color: ParishColors.goldAccent, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _duplicateRequesterWarning!,
                                  style: TextStyle(fontSize: 11.5, color: textDarkColor, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),

                      // Contact & Email
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Contact Number *'),
                                TextFormField(
                                  controller: _contactNumberController,
                                  focusNode: _contactFocusNode,
                                  keyboardType: TextInputType.phone,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    PhilippinePhoneInputFormatter(),
                                  ],
                                  onChanged: (_) => setState(() {}),
                                  validator: (v) {
                                    final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                                    if (digits.isEmpty) return 'Contact number is required';
                                    if (digits.length != 11 || !digits.startsWith('09')) {
                                      return 'Format: 09XX-XXX-XXXX';
                                    }
                                    return null;
                                  },
                                  style: const TextStyle(fontSize: 14),
                                  decoration: _inputDecoration(
                                    hint: '09XX-XXX-XXXX',
                                    suffixIcon: _isPhoneValid
                                        ? const Icon(Icons.check_circle, color: ParishColors.oliveGreen, size: 20)
                                        : null,
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
                                _buildFieldLabel('Email (Optional)'),
                                TextFormField(
                                  controller: _emailController,
                                  focusNode: _emailFocusNode,
                                  keyboardType: TextInputType.emailAddress,
                                  onChanged: (_) => setState(() {}),
                                  validator: (v) {
                                    final text = (v ?? '').trim();
                                    if (text.isEmpty) return null;
                                    if (!RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[\w\-]{2,4}$').hasMatch(text)) {
                                      return 'Invalid email address';
                                    }
                                    return null;
                                  },
                                  style: const TextStyle(fontSize: 14),
                                  decoration: _inputDecoration(
                                    hint: 'name@email.com',
                                    suffixIcon: _emailController.text.trim().isNotEmpty
                                        ? (_isEmailValid
                                        ? const Icon(Icons.check_circle, color: ParishColors.oliveGreen, size: 20)
                                        : const Icon(Icons.error_outline, color: ParishColors.mercyRed, size: 20))
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Scheduled Date
                      _buildFieldLabel(currentPreset?.isCommunityBaptism == true
                          ? 'Scheduled Date * (Weekends Only for Baptism)'
                          : 'Scheduled Date * (Mondays & Solemnities Restricted)'),
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

                      // Time Pickers
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
                                      border: Border.all(color: hasConflict ? ParishColors.mercyRed : borderGreyColor),
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
                                      border: Border.all(color: hasConflict ? ParishColors.mercyRed : borderGreyColor),
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

                      // Live Conflict Banner
                      const SizedBox(height: 10),
                      if (_isLiveChecking)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            children: [
                              const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                              const SizedBox(width: 8),
                              Text('Checking slot availability...', style: TextStyle(fontSize: 12, color: textMutedColor)),
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
                                      backgroundColor: ParishColors.goldAccent,
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
                                'Time slot is available on the parish schedule.',
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: ParishColors.oliveGreen),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),

                      _buildFieldLabel('Parish Venue *'),
                      DropdownButtonFormField<String>(
                        value: _selectedVenue,
                        items: _venues.map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 13)))).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedVenue = val);
                            _runLiveConflictCheck();
                          }
                        },
                        decoration: _inputDecoration(),
                      ),
                      const SizedBox(height: 14),

                      _buildFieldLabel('Presiding Clergy *'),
                      DropdownButtonFormField<String>(
                        value: _selectedOfficiant,
                        items: _officiants.map((o) => DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(fontSize: 13)))).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedOfficiant = val);
                            _runLiveConflictCheck();
                          }
                        },
                        decoration: _inputDecoration(),
                      ),
                      const SizedBox(height: 14),

                      // Remarks with Character Counter
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildFieldLabel('Remarks / Intentions (Optional)'),
                          Text(
                            '${_remarksController.text.length}/250',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: _remarksController.text.length > 250
                                  ? ParishColors.mercyRed
                                  : textMutedColor,
                            ),
                          ),
                        ],
                      ),
                      TextFormField(
                        controller: _remarksController,
                        maxLength: 250,
                        maxLines: 2,
                        buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                        onChanged: (_) => setState(() {}),
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
                        backgroundColor: hasConflict
                            ? ParishColors.borderGrey
                            : (isTuesday ? ParishColors.goldAccent : ParishColors.marianBlue),
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

  InputDecoration _inputDecoration({String? hint, Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: ParishColors.backgroundLight,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ParishColors.borderGrey)),
    );
  }
}