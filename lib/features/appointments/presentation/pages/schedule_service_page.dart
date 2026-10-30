// =============================================================================
// FILE: lib/features/appointments/presentation/pages/schedule_service_page.dart
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/colors.dart';
import '../../../auth/services/auth_service.dart';
import '../../../sacramental_records/validators/sacramental_validators.dart';
import '../../models/appointment_model.dart';
import '../../services/appointment_service.dart';
import '../../services/liturgical_calendar_service.dart';
import '../dialogs/appointment_submission_success_dialog.dart';

Future<void> navigateToScheduleServicePage(
    BuildContext context, {
      DateTime? initialDate,
      VoidCallback? onAppointmentSaved,
    }) {
  return Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ScheduleServicePage(
        initialDate: initialDate,
        onAppointmentSaved: onAppointmentSaved,
      ),
    ),
  );
}

class PhilippinePhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length > 11) return oldValue;

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

class ScheduleServicePage extends StatefulWidget {
  final DateTime? initialDate;
  final VoidCallback? onAppointmentSaved;

  const ScheduleServicePage({
    super.key,
    this.initialDate,
    this.onAppointmentSaved,
  });

  @override
  State<ScheduleServicePage> createState() => _ScheduleServicePageState();
}

class _ScheduleServicePageState extends State<ScheduleServicePage> {
  final _formKey = GlobalKey<FormState>();

  final _requesterNameController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _emailController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _remarksController = TextEditingController();

  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _contactFocusNode = FocusNode();
  final FocusNode _emailFocusNode = FocusNode();

  String _selectedService = 'Nuptial Mass (Wedding)';
  String _selectedVenue = 'Main Church Altar';
  String _selectedOfficiant = 'Rev. Fr. Roy';
  String _selectedIdType = 'Philippine National ID (PhilID / ePhilID)';

  Uint8List? _attachedIdFileBytes;
  String? _attachedIdFileName;
  int? _attachedIdFileSize;
  bool _idFileHasError = false;

  DateTime? _lastFilePickAttemptTime;
  final List<DateTime> _recentAttachmentAttempts = [];
  static const int _maxAttachmentAttemptsPerWindow = 5;
  static const Duration _rateLimitWindow = Duration(minutes: 5);
  static const Duration _pickCooldown = Duration(seconds: 3);

  late DateTime _selectedDate;
  TimeOfDay _startTime = const TimeOfDay(hour: 10, minute: 0);
  late TimeOfDay _endTime;

  bool _isSubmitting = false;
  String? _errorMessage;

  bool _isLiveChecking = false;
  String? _liveConflictWarning;
  String? _duplicateRequesterWarning;
  Map<String, TimeOfDay>? _suggestedSlot;
  Timer? _debounceTimer;

  static const String _draftStorageKey = 'parishserve_draft_appointment_form';

  bool get _isParishioner =>
      AuthService.currentUser?.userRole.toLowerCase() == 'user';

  static const List<String> _keyboardWalks = [
    'asdf', 'sdfg', 'dfgh', 'fghj', 'ghjk', 'hjkl',
    'qwer', 'wert', 'erty', 'rtyu', 'tyui', 'yuio', 'uiop',
    'zxcv', 'xcvb', 'cvbn', 'vbnm',
    'fdsa', 'gfds', 'hgfd', 'jhgf', 'kjhg', 'lkjh',
    'rewq', 'trew', 'ytre', 'uytr', 'iuyt', 'poiuy',
    'vcxz', 'bvcx', 'nbvc', 'mnbv',
  ];

  final List<String> _philippineIdTypes = const [
    'Philippine National ID (PhilID / ePhilID)',
    'Driver\'s License (LTO)',
    'UMID (SSS / GSIS)',
    'Passport (DFA)',
    'Postal ID (PhilPost)',
    'Senior Citizen ID',
    'Voter\'s ID / Certification (COMELEC)',
    'Barangay ID / Certificate of Residency',
    'PRC Professional ID',
    'Solo Parent / PWD ID',
  ];

  final Map<String, _ServicePreset> _presets = const {
    'Nuptial Mass (Wedding)': _ServicePreset(
      durationMinutes: 90,
      defaultVenue: 'Main Church Altar',
      defaultOfficiant: 'Rev. Fr. Roy',
      durationLabel: '1 hr 30 mins',
    ),
    'Community Baptism': _ServicePreset(
      durationMinutes: 60,
      defaultVenue: 'Baptistery & Main Altar',
      defaultOfficiant: 'Rev. Fr. Roy',
      durationLabel: '1 hour (11:00 AM Batch)',
      isCommunityBaptism: true,
    ),
    'Funeral Mass & Blessing': _ServicePreset(
      durationMinutes: 60,
      defaultVenue: 'Main Church Altar',
      defaultOfficiant: 'Rev. Fr. Roy',
      durationLabel: '1 hour',
    ),
    'Anointing of the Sick & Viaticum': _ServicePreset(
      durationMinutes: 45,
      defaultVenue: 'Off-site / Home Visit',
      defaultOfficiant: 'Rev. Fr. Roy',
      durationLabel: '45 mins',
    ),
    'House / Business Blessing': _ServicePreset(
      durationMinutes: 45,
      defaultVenue: 'Off-site / Home Visit',
      defaultOfficiant: 'Rev. Fr. Roy',
      durationLabel: '45 mins',
    ),
    'Thanksgiving Mass Intention': _ServicePreset(
      durationMinutes: 60,
      defaultVenue: 'Main Church Altar',
      defaultOfficiant: 'Rev. Fr. Roy',
      durationLabel: '1 hour',
    ),
    'Canonical Interview / Pre-Cana': _ServicePreset(
      durationMinutes: 45,
      defaultVenue: 'Sanctuary / Sacristy',
      defaultOfficiant: 'Rev. Fr. Roy',
      durationLabel: '45 mins',
    ),
    'Confession & Spiritual Direction': _ServicePreset(
      durationMinutes: 30,
      defaultVenue: 'Sanctuary / Sacristy',
      defaultOfficiant: 'Rev. Fr. Roy',
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
    'Rev. Fr. Roy',
    'Guest Priest / Visiting Clergy',
  ];

  @override
  void initState() {
    super.initState();

    final user = AuthService.currentUser;
    if (user != null && _isParishioner) {
      _requesterNameController.text = user.fullName;
      _emailController.text = user.email;
    }

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

    _restoreDraft();
    _runLiveConflictCheck();
  }

  String? _validateFullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Requester full name is required.';
    }
    if (value.startsWith(' ') || value.endsWith(' ')) {
      return 'Name cannot start or end with a space.';
    }
    if (value.contains(RegExp(r'\s{2,}'))) {
      return 'Name cannot contain consecutive spaces.';
    }

    final trimmed = value.trim();
    if (trimmed.length < 2) return 'Name must be at least 2 characters.';
    if (trimmed.length > 70) return 'Name cannot exceed 70 characters.';

    final nameRegex = RegExp(r"^[a-zA-ZÀ-ÿ\u0100-\u024FÑñ\s.\-’']+$");
    if (!nameRegex.hasMatch(trimmed)) {
      return 'Name contains invalid characters (letters, hyphens, and spaces only).';
    }

    final lower = trimmed.toLowerCase();
    if (RegExp(r'(.)\1{2,}', caseSensitive: false).hasMatch(trimmed)) {
      return 'Name cannot contain 3 or more identical letters consecutively.';
    }
    if (RegExp(r'(.{2,4})\1{2,}', caseSensitive: false).hasMatch(lower)) {
      return 'Please enter a genuine name (repetitive pattern detected).';
    }
    for (final walk in _keyboardWalks) {
      if (lower.contains(walk)) {
        return 'Please enter a genuine name (keyboard sequence detected).';
      }
    }

    final onlyLetters = lower.replaceAll(RegExp(r'[^a-zà-ÿñ]'), '');
    if (onlyLetters.length >= 3) {
      if (!RegExp(r'[aeiouyà-ÿ]').hasMatch(onlyLetters)) {
        return 'Name must contain at least one vowel sound.';
      }
      if (RegExp(r'[bcdfghjklmnpqrstvwxz]{5,}').hasMatch(onlyLetters)) {
        return 'Name contains too many consecutive consonants.';
      }
    }
    return null;
  }

  bool get _isNameValid => _validateFullName(_requesterNameController.text) == null;
  bool get _isPhoneValid =>
      SacramentalValidators.validatePhoneNumber(_contactNumberController.text) == null &&
          _contactNumberController.text.trim().isNotEmpty;
  bool get _isEmailValid {
    final text = _emailController.text.trim();
    if (text.isEmpty) return !_isParishioner;
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(text);
  }

  Future<void> _saveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftMap = {
        'service': _selectedService,
        'requesterName': _requesterNameController.text.trim(),
        'contact': _contactNumberController.text.trim(),
        'email': _emailController.text.trim(),
        'idType': _selectedIdType,
        'idNumber': _idNumberController.text.trim(),
        'remarks': _remarksController.text.trim(),
        'venue': _selectedVenue,
        'officiant': _selectedOfficiant,
        'date': _selectedDate.toIso8601String(),
        'startHour': _startTime.hour,
        'startMinute': _startTime.minute,
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
            if (map['idNumber'] != null) _idNumberController.text = map['idNumber'];
            if (map['remarks'] != null) _remarksController.text = map['remarks'];
            if (map['service'] != null && _presets.containsKey(map['service'])) {
              _selectedService = map['service'];
            }
            if (map['venue'] != null && _venues.contains(map['venue'])) {
              _selectedVenue = map['venue'];
            }
            if (map['officiant'] != null && _officiants.contains(map['officiant'])) {
              _selectedOfficiant = _isParishioner ? 'Rev. Fr. Roy' : map['officiant'];
            }
            if (map['idType'] != null && _philippineIdTypes.contains(map['idType'])) {
              _selectedIdType = map['idType'];
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

  DateTime _getInitialValidDate() {
    var date = DateTime.now().add(const Duration(days: 1));
    final isCommunity = _presets[_selectedService]?.isCommunityBaptism ?? false;

    while (date.weekday == DateTime.monday ||
        LiturgicalCalendarService.isDateBlockedSync(date) ||
        (isCommunity &&
            date.weekday != DateTime.saturday &&
            date.weekday != DateTime.sunday)) {
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
    _idNumberController.dispose();
    _remarksController.dispose();
    _nameFocusNode.dispose();
    _contactFocusNode.dispose();
    _emailFocusNode.dispose();
    super.dispose();
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
      _startTime = const TimeOfDay(hour: 11, minute: 0);
    } else {
      if (_startTime.hour < 9 || _startTime.hour >= 17) {
        _startTime = const TimeOfDay(hour: 10, minute: 0);
      }
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

  Future<void> _pickIdDocument() async {
    final now = DateTime.now();
    if (_lastFilePickAttemptTime != null &&
        now.difference(_lastFilePickAttemptTime!) < _pickCooldown) {
      final waitSec =
          _pickCooldown.inSeconds - now.difference(_lastFilePickAttemptTime!).inSeconds;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please wait $waitSec second(s) before choosing another file.'),
          backgroundColor: ParishColors.goldAccent,
        ),
      );
      return;
    }

    _recentAttachmentAttempts.removeWhere((t) => now.difference(t) > _rateLimitWindow);
    if (_recentAttachmentAttempts.length >= _maxAttachmentAttemptsPerWindow) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rate limit: Max 5 file selections per 5 minutes. Please wait.'),
          backgroundColor: ParishColors.mercyRed,
        ),
      );
      return;
    }

    _lastFilePickAttemptTime = now;
    _recentAttachmentAttempts.add(now);

    try {
      final PlatformFile? file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      );

      if (file != null) {
        final int fileSize = (await file.length()) ?? 0;
        if (fileSize > 5 * 1024 * 1024) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File size exceeds 5MB limit. Please attach a smaller file.'),
              backgroundColor: ParishColors.mercyRed,
            ),
          );
          return;
        }

        final Uint8List bytes = await file.readAsBytes();
        setState(() {
          _attachedIdFileBytes = bytes;
          _attachedIdFileName = file.name;
          _attachedIdFileSize = fileSize;
          _idFileHasError = false;
        });
      }
    } catch (e) {
      debugPrint('Error picking ID file: $e');
    }
  }

  void _removeAttachedIdDocument() {
    setState(() {
      _attachedIdFileBytes = null;
      _attachedIdFileName = null;
      _attachedIdFileSize = null;
    });
  }

  void _triggerDebouncedValidation() {
    _saveDraft();
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _runLiveConflictCheck();
      _runDuplicateRequesterCheck();
    });
  }

  Future<void> _runDuplicateRequesterCheck() async {
    final name = _requesterNameController.text.trim();
    if (name.length < 3) {
      if (_duplicateRequesterWarning != null) {
        setState(() => _duplicateRequesterWarning = null);
      }
      return;
    }

    final dateStr =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    final warning = await AppointmentService.checkDuplicateRequester(
      requesterName: name,
      date: dateStr,
      serviceType: _selectedService,
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

    final dateStr =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    final startStr = _formatTimeOfDay(_startTime);
    final endStr = _formatTimeOfDay(_endTime);

    final warning = await AppointmentService.checkScheduleConflictSilent(
      date: dateStr,
      startTime: startStr,
      endTime: endStr,
      venue: _selectedVenue,
      officiant: _selectedOfficiant,
      serviceType: _selectedService,
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
        serviceType: _selectedService,
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
        _selectedOfficiant = 'Rev. Fr. Roy';

        if (preset.isCommunityBaptism) {
          _startTime = const TimeOfDay(hour: 11, minute: 0);
          if (_selectedDate.weekday != DateTime.saturday &&
              _selectedDate.weekday != DateTime.sunday) {
            _selectedDate = _getInitialValidDate();
          }
        } else {
          if (_startTime.hour < 9 || _startTime.hour >= 17) {
            _startTime = const TimeOfDay(hour: 10, minute: 0);
          }
        }
        _endTime = _addMinutes(_startTime, preset.durationMinutes);
      }
    });
    _saveDraft();
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
        if (isCommunity &&
            day.weekday != DateTime.saturday &&
            day.weekday != DateTime.sunday) {
          return false;
        }
        return true;
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _saveDraft();
      _runLiveConflictCheck();
    }
  }

  Future<void> _pickTime(bool isStart) async {
    final preset = _presets[_selectedService];

    if (preset?.isCommunityBaptism == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Community Baptism ceremony strictly begins at 11:00 AM on Weekends.'),
          backgroundColor: ParishColors.goldAccent,
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
      final totalMin = picked.hour * 60 + picked.minute;

      if (totalMin < AppointmentService.operatingDayStartMin ||
          totalMin > AppointmentService.operatingDayEndMin) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Parish appointments must be scheduled between 9:00 AM and 5:00 PM.'),
            backgroundColor: ParishColors.mercyRed,
          ),
        );
        return;
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
      _saveDraft();
      _runLiveConflictCheck();
    }
  }

  Future<void> _submitAppointment() async {
    setState(() {
      _errorMessage = null;
      _idFileHasError = _isParishioner && _attachedIdFileBytes == null;
    });

    if (!_formKey.currentState!.validate()) return;

    if (_isParishioner && _attachedIdFileBytes == null) {
      setState(() => _errorMessage = 'Please attach a photo or copy of your valid ID card.');
      return;
    }

    final preset = _presets[_selectedService];
    if (preset?.isCommunityBaptism == true) {
      if (_selectedDate.weekday != DateTime.saturday &&
          _selectedDate.weekday != DateTime.sunday) {
        setState(() => _errorMessage = 'Community Baptism is strictly restricted to Weekends.');
        return;
      }
    }

    final startStr = _formatTimeOfDay(_startTime);
    final endStr = _formatTimeOfDay(_endTime);

    if (startStr.compareTo(endStr) >= 0) {
      setState(() => _errorMessage = 'End Time must be later than Start Time.');
      return;
    }

    final dateStr =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    final emailValue = _emailController.text.trim();
    final requesterNameVal = _requesterNameController.text.trim();

    setState(() => _isSubmitting = true);

    try {
      final duplicateWarning = await AppointmentService.checkDuplicateRequester(
        requesterName: requesterNameVal,
        date: dateStr,
        serviceType: _selectedService,
      );
      if (duplicateWarning != null) {
        setState(() {
          _errorMessage = duplicateWarning;
          _isSubmitting = false;
        });
        return;
      }

      final conflictWarning = await AppointmentService.checkScheduleConflictSilent(
        date: dateStr,
        startTime: startStr,
        endTime: endStr,
        venue: _selectedVenue,
        officiant: _isParishioner ? 'Rev. Fr. Roy' : _selectedOfficiant,
        serviceType: _selectedService,
      );
      if (conflictWarning != null) {
        setState(() {
          _errorMessage = conflictWarning;
          _isSubmitting = false;
        });
        return;
      }
    } catch (preCheckError) {
      setState(() {
        _errorMessage = preCheckError.toString().replaceFirst('Exception: ', '');
        _isSubmitting = false;
      });
      return;
    }

    String? uploadedDocumentPath;
    final tempId = 'APT-${DateTime.now().millisecondsSinceEpoch % 1000000}';

    try {
      if (_attachedIdFileBytes != null && _attachedIdFileName != null) {
        uploadedDocumentPath = await AppointmentService.uploadIdDocument(
          appointmentId: tempId,
          fileBytes: _attachedIdFileBytes!,
          fileName: _attachedIdFileName!,
        );
      }

      final createdAppointment = await AppointmentService.createAppointment(
        serviceType: _selectedService,
        requesterName: requesterNameVal,
        contactNumber: _contactNumberController.text.trim(),
        email: emailValue,
        date: dateStr,
        startTime: startStr,
        endTime: endStr,
        venue: _selectedVenue,
        officiant: _isParishioner ? 'Rev. Fr. Roy' : _selectedOfficiant,
        idType: _selectedIdType,
        idNumber: _idNumberController.text.trim(),
        idDocumentUrl: uploadedDocumentPath,
        remarks: _remarksController.text.trim(),
      );

      await _clearDraft();

      if (!mounted) return;
      Navigator.pop(context);

      showAppointmentSubmissionSuccessModal(
        context,
        appointment: createdAppointment,
        userEmail: emailValue,
      );

      widget.onAppointmentSaved?.call();
    } catch (e) {
      if (uploadedDocumentPath != null) {
        try {
          await Supabase.instance.client.storage
              .from('appointment-documents')
              .remove([uploadedDocumentPath]);
        } catch (_) {}
      }

      final cleanError = e.toString().replaceFirst('Exception: ', '');
      setState(() => _errorMessage = cleanError);
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
              _isParishioner ? 'Book Pastoral Sacrament / Service' : 'Schedule Sacrament / Liturgical Service',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark),
            ),
            Text(
              'St. John Paul II Parish • Operational window: 9:00 AM – 5:00 PM (Closed on Mondays)',
              style: TextStyle(fontSize: 12, color: textMuted),
            ),
          ],
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 920;

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
                    child: _buildFormFieldsCard(textDark, textMuted, cardWhite, borderGrey),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 4,
                    child: _buildInspectionAndRulesSidebar(textDark, textMuted, cardWhite, borderGrey),
                  ),
                ],
              )
                  : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFormFieldsCard(textDark, textMuted, cardWhite, borderGrey),
                  const SizedBox(height: 20),
                  _buildInspectionAndRulesSidebar(textDark, textMuted, cardWhite, borderGrey),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFormFieldsCard(Color textDark, Color textMuted, Color cardWhite, Color borderGrey) {
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
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: ParishColors.mercyRed),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: ParishColors.mercyRed, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],

          _buildFieldLabel('Service Requested *'),
          DropdownButtonFormField<String>(
            value: _selectedService,
            isExpanded: true,
            items: _presets.keys
                .map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (val) {
              if (val != null) _onServiceSelected(val);
            },
            decoration: _inputDecoration(),
          ),
          const SizedBox(height: 16),

          _buildFieldLabel(_isParishioner ? 'Requester Full Name (Account Linked)' : 'Requester Full Name *'),
          TextFormField(
            controller: _requesterNameController,
            focusNode: _nameFocusNode,
            enabled: !_isParishioner,
            maxLength: 70,
            buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
            inputFormatters: [TitleCaseInputFormatter()],
            onChanged: (_) => _triggerDebouncedValidation(),
            validator: _validateFullName,
            style: TextStyle(fontSize: 14, color: _isParishioner ? textMuted : textDark),
            decoration: _inputDecoration(
              hint: 'First Name and Last Name',
              prefixIcon: _isParishioner ? const Icon(Icons.lock_outline, size: 18) : null,
              suffixIcon: _isNameValid ? const Icon(Icons.check_circle, color: ParishColors.oliveGreen, size: 18) : null,
            ),
          ),
          const SizedBox(height: 16),

          Row(
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
                      maxLength: 13,
                      buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        PhilippinePhoneInputFormatter(),
                      ],
                      onChanged: (_) => _triggerDebouncedValidation(),
                      validator: SacramentalValidators.validatePhoneNumber,
                      decoration: _inputDecoration(
                        hint: '09XX-XXX-XXXX',
                        suffixIcon: _isPhoneValid ? const Icon(Icons.check_circle, color: ParishColors.oliveGreen, size: 18) : null,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel(_isParishioner ? 'Email (Linked) *' : 'Email (Optional)'),
                    TextFormField(
                      controller: _emailController,
                      focusNode: _emailFocusNode,
                      enabled: !_isParishioner,
                      maxLength: 100,
                      buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (_) => _triggerDebouncedValidation(),
                      validator: (v) {
                        final text = (v ?? '').trim();
                        if (_isParishioner && text.isEmpty) return 'Required';
                        if (text.isNotEmpty && !RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(text)) {
                          return 'Invalid email';
                        }
                        return null;
                      },
                      decoration: _inputDecoration(hint: 'name@email.com'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildFieldLabel(_isParishioner ? 'Valid Identification Document * (Required)' : 'Valid ID Document (Optional)'),
          DropdownButtonFormField<String>(
            value: _selectedIdType,
            isExpanded: true,
            items: _philippineIdTypes
                .map((id) => DropdownMenuItem(value: id, child: Text(id, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedIdType = val);
            },
            decoration: _inputDecoration(),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _idNumberController,
            maxLength: 50,
            buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
            decoration: _inputDecoration(hint: 'ID Serial / Control Number (Optional)'),
          ),
          const SizedBox(height: 10),

          // File picker box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _attachedIdFileBytes != null
                  ? ParishColors.oliveGreenSurface
                  : (_idFileHasError ? ParishColors.mercyRedSurface : ParishColors.backgroundLight),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _attachedIdFileBytes != null
                    ? ParishColors.oliveGreen
                    : (_idFileHasError ? ParishColors.mercyRed : borderGrey),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _attachedIdFileBytes != null ? Icons.check_circle : Icons.attach_file,
                  color: _attachedIdFileBytes != null ? ParishColors.oliveGreen : ParishColors.marianBlue,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _attachedIdFileBytes != null
                            ? '${_attachedIdFileName!} (${((_attachedIdFileSize ?? 0) / 1024).toStringAsFixed(1)} KB)'
                            : 'Attach valid ID photo (JPG, PNG, PDF up to 5MB)',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: _attachedIdFileBytes != null ? ParishColors.oliveGreen : textDark,
                        ),
                      ),
                      Text(
                        'Stored securely and verified during secretariat review.',
                        style: TextStyle(fontSize: 11, color: textMuted),
                      ),
                    ],
                  ),
                ),
                if (_attachedIdFileBytes != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: ParishColors.mercyRed),
                    onPressed: _removeAttachedIdDocument,
                  )
                else
                  OutlinedButton(
                    onPressed: _pickIdDocument,
                    child: const Text('Choose File'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _buildFieldLabel('Remarks / Intentions / Special Instructions'),
          TextFormField(
            controller: _remarksController,
            maxLines: 3,
            maxLength: 250,
            buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
            decoration: _inputDecoration(hint: 'Optional notes, intentions, or requested arrangements'),
          ),
        ],
      ),
    );
  }

  Widget _buildInspectionAndRulesSidebar(Color textDark, Color textMuted, Color cardWhite, Color borderGrey) {
    final currentPreset = _presets[_selectedService];
    final isTuesday = _selectedDate.weekday == DateTime.tuesday;

    return Column(
      children: [
        // Live Date & Time Slot Inspector
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardWhite,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderGrey),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Schedule Parameters & Slot',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textDark),
              ),
              const Divider(height: 20),

              _buildFieldLabel('Requested Date *'),
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
                        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textDark),
                      ),
                      const Icon(Icons.calendar_month, color: ParishColors.marianBlue),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

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
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: currentPreset?.isCommunityBaptism == true
                                  ? ParishColors.borderGrey.withOpacity(0.2)
                                  : ParishColors.backgroundLight,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: borderGrey),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_formatTime12Hour(_startTime), style: TextStyle(fontWeight: FontWeight.bold, color: textDark)),
                                const Icon(Icons.access_time, size: 16),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('End Time (Auto) *'),
                        InkWell(
                          onTap: () => _pickTime(false),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: ParishColors.backgroundLight,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: borderGrey),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_formatTime12Hour(_endTime), style: TextStyle(fontWeight: FontWeight.bold, color: textDark)),
                                const Icon(Icons.access_time, size: 16),
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

              // Live Conflict Status
              if (_isLiveChecking)
                const LinearProgressIndicator(minHeight: 2)
              else if (_liveConflictWarning != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ParishColors.mercyRedSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: ParishColors.mercyRed),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.warning, color: ParishColors.mercyRed, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _liveConflictWarning!,
                              style: const TextStyle(color: ParishColors.mercyRed, fontWeight: FontWeight.bold, fontSize: 12),
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
                            ),
                            onPressed: _applySuggestedSlot,
                            icon: const Icon(Icons.bolt, size: 16),
                            label: Text(
                              'Auto-Set: ${_formatTime12Hour(_suggestedSlot!['start']!)} - ${_formatTime12Hour(_suggestedSlot!['end']!)}',
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
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ParishColors.oliveGreenSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: ParishColors.oliveGreen.withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, color: ParishColors.oliveGreen, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Requested slot is open on the parish calendar.',
                          style: TextStyle(color: ParishColors.oliveGreen, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),

              _buildFieldLabel('Venue *'),
              DropdownButtonFormField<String>(
                value: _selectedVenue,
                isExpanded: true,
                items: _venues.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedVenue = val);
                    _runLiveConflictCheck();
                  }
                },
                decoration: _inputDecoration(),
              ),
              const SizedBox(height: 14),

              _buildFieldLabel(_isParishioner ? 'Presiding Clergy (Parish Priest)' : 'Presiding Clergy *'),
              _isParishioner
                  ? TextFormField(
                initialValue: 'Rev. Fr. Roy (Parish Priest)',
                enabled: false,
                decoration: _inputDecoration(prefixIcon: const Icon(Icons.lock_outline, size: 18)),
              )
                  : DropdownButtonFormField<String>(
                value: _selectedOfficiant,
                isExpanded: true,
                items: _officiants.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedOfficiant = val);
                    _runLiveConflictCheck();
                  }
                },
                decoration: _inputDecoration(),
              ),
              const SizedBox(height: 20),

              // Action Submission Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ParishColors.marianBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isSubmitting ? null : _submitAppointment,
                  icon: _isSubmitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.check, size: 20),
                  label: Text(
                    _isSubmitting
                        ? 'Validating & Submitting...'
                        : (_isParishioner
                        ? 'Submit for Office Approval'
                        : (isTuesday ? 'Submit for Priest Approval' : 'Confirm & Schedule')),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
    );
  }

  InputDecoration _inputDecoration({String? hint, Widget? prefixIcon, Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
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