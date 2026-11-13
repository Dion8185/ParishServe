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
      TimeOfDay? initialTime,
      VoidCallback? onAppointmentSaved,
    }) {
  return Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ScheduleServicePage(
        initialDate: initialDate,
        initialTime: initialTime,
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
  final bool isAnytimeAllowed;

  const _ServicePreset({
    required this.durationMinutes,
    required this.defaultVenue,
    required this.defaultOfficiant,
    required this.durationLabel,
    this.isCommunityBaptism = false,
    this.isAnytimeAllowed = false,
  });
}

class ScheduleServicePage extends StatefulWidget {
  final DateTime? initialDate;
  final TimeOfDay? initialTime;
  final VoidCallback? onAppointmentSaved;

  const ScheduleServicePage({
    super.key,
    this.initialDate,
    this.initialTime,
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
  final _remarksController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _outsideLocationController = TextEditingController();

  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _contactFocusNode = FocusNode();

  String _selectedService = 'Nuptial Mass (Wedding)';
  String _selectedOfficiant = 'Rev. Fr. Roy';
  String _selectedIdType = 'Philippine National ID (PhilID / ePhilID)';

  // Venue state
  bool _isOnParishGrounds = true;

  // Single service time state
  late DateTime _selectedDate;
  TimeOfDay _estimatedServiceTime = const TimeOfDay(hour: 10, minute: 0);
  int _estimatedDurationMinutes = 60;
  bool _allowMondayException = false;

  // Preserved Parishioner Valid ID attachment
  Uint8List? _attachedIdFileBytes;
  String? _attachedIdFileName;
  int? _attachedIdFileSize;
  bool _idFileHasError = false;

  DateTime? _lastFilePickAttemptTime;
  final List<DateTime> _recentAttachmentAttempts = [];
  static const int _maxAttachmentAttemptsPerWindow = 5;
  static const Duration _rateLimitWindow = Duration(minutes: 5);
  static const Duration _pickCooldown = Duration(seconds: 3);

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

  bool get _isImageAttachment {
    if (_attachedIdFileName == null) return false;
    final lower = _attachedIdFileName!.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp');
  }

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
      defaultVenue: 'Parish Grounds',
      defaultOfficiant: 'Rev. Fr. Roy',
      durationLabel: '1 hr 30 mins',
    ),
    'Community Baptism': _ServicePreset(
      durationMinutes: 60,
      defaultVenue: 'Parish Grounds',
      defaultOfficiant: 'Rev. Fr. Roy',
      durationLabel: '1 hour (11:00 AM Batch)',
      isCommunityBaptism: true,
    ),
    'Confirmation (Kumpil)': _ServicePreset(
      durationMinutes: 60,
      defaultVenue: 'Parish Grounds',
      defaultOfficiant: 'Rev. Fr. Roy',
      durationLabel: '1 hour',
    ),
    'Funeral Mass & Blessing': _ServicePreset(
      durationMinutes: 60,
      defaultVenue: 'Parish Grounds',
      defaultOfficiant: 'Rev. Fr. Roy',
      durationLabel: '1 hour',
    ),
    'Anointing of the Sick & Viaticum': _ServicePreset(
      durationMinutes: 45,
      defaultVenue: 'Outside Parish',
      defaultOfficiant: 'Rev. Fr. Roy',
      durationLabel: '45 mins (Emergency / Anytime)',
      isAnytimeAllowed: true,
    ),
    'Confession & Spiritual Direction': _ServicePreset(
      durationMinutes: 30,
      defaultVenue: 'Parish Grounds',
      defaultOfficiant: 'Rev. Fr. Roy',
      durationLabel: '30 mins (Flexible / Anytime)',
      isAnytimeAllowed: true,
    ),
    'House / Business Blessing': _ServicePreset(
      durationMinutes: 45,
      defaultVenue: 'Outside Parish',
      defaultOfficiant: 'Rev. Fr. Roy',
      durationLabel: '45 mins',
    ),
    'Canonical Interview / Pre-Cana': _ServicePreset(
      durationMinutes: 45,
      defaultVenue: 'Parish Grounds',
      defaultOfficiant: 'Rev. Fr. Roy',
      durationLabel: '45 mins',
    ),
    'Thanksgiving Mass Intention': _ServicePreset(
      durationMinutes: 60,
      defaultVenue: 'Parish Grounds',
      defaultOfficiant: 'Rev. Fr. Roy',
      durationLabel: '1 hour',
    ),
  };

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

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (widget.initialDate != null) {
      final target = DateTime(
        widget.initialDate!.year,
        widget.initialDate!.month,
        widget.initialDate!.day,
      );
      _selectedDate = target.isBefore(today) ? _getInitialValidDate() : target;
    } else {
      _selectedDate = _getInitialValidDate();
    }

    if (widget.initialTime != null) {
      _estimatedServiceTime = widget.initialTime!;
    }

    _applyServicePreset(_selectedService, retainCustomTime: widget.initialTime != null);
    LiturgicalCalendarService.getCalendarForYear(_selectedDate.year);

    _nameFocusNode.addListener(() => setState(() {}));
    _contactFocusNode.addListener(() => setState(() {}));

    _restoreDraft();
    _runLiveConflictCheck();
  }

  void _applyServicePreset(String service, {bool retainCustomTime = false}) {
    final preset = _presets[service];
    if (preset == null) return;

    _estimatedDurationMinutes = preset.durationMinutes;

    if (preset.defaultVenue.toLowerCase().contains('outside')) {
      _isOnParishGrounds = false;
    } else {
      _isOnParishGrounds = true;
      _outsideLocationController.clear();
    }

    if (!retainCustomTime) {
      if (preset.isCommunityBaptism) {
        _estimatedServiceTime = const TimeOfDay(hour: 11, minute: 0);
      } else if (!preset.isAnytimeAllowed) {
        if (_estimatedServiceTime.hour < 9 || _estimatedServiceTime.hour >= 17) {
          _estimatedServiceTime = const TimeOfDay(hour: 10, minute: 0);
        }
      }
    }
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

  DateTime _getInitialValidDate() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var date = today.add(const Duration(days: 1));
    final preset = _presets[_selectedService];
    final isCommunity = preset?.isCommunityBaptism ?? false;
    final isAnytime = preset?.isAnytimeAllowed ?? false;

    while (date.isBefore(today) ||
        (!isAnytime && date.weekday == DateTime.monday && _isParishioner) ||
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
    _remarksController.dispose();
    _idNumberController.dispose();
    _outsideLocationController.dispose();
    _nameFocusNode.dispose();
    _contactFocusNode.dispose();
    super.dispose();
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

  TimeOfDay _calculateEndTime(TimeOfDay start, int durationMinutes) {
    final totalMinutes = (start.hour * 60) + start.minute + durationMinutes;
    final newHour = (totalMinutes ~/ 60) % 24;
    final newMinute = totalMinutes % 60;
    return TimeOfDay(hour: newHour, minute: newMinute);
  }

  Future<void> _pickServiceTime() async {
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

    final picked = await showTimePicker(
      context: context,
      initialTime: _estimatedServiceTime,
    );

    if (picked != null) {
      setState(() {
        _estimatedServiceTime = picked;
      });
      _saveDraft();
      _runLiveConflictCheck();
    }
  }

  Future<void> _pickDate() async {
    await LiturgicalCalendarService.getCalendarForYear(_selectedDate.year);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final preset = _presets[_selectedService];
    final isCommunity = preset?.isCommunityBaptism ?? false;
    final isAnytime = preset?.isAnytimeAllowed ?? false;

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(today) ? today : _selectedDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: 730)),
      selectableDayPredicate: (DateTime day) {
        if (day.isBefore(today)) return false;
        if (!isAnytime && day.weekday == DateTime.monday && _isParishioner) return false;
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
      if (picked.weekday == DateTime.monday && !isAnytime && !_isParishioner) {
        final allowed = await _confirmMondayExceptionDialog(picked);
        if (!allowed) return;
        _allowMondayException = true;
      } else {
        _allowMondayException = false;
      }

      setState(() => _selectedDate = picked);
      _saveDraft();
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
              'Do you want to schedule this appointment on Monday as an administrative exception?',
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

  void _openImagePreviewDialog(Uint8List bytes, String fileName) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: ParishColors.cardWhite,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 640, maxHeight: 680),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.verified_user_outlined, color: ParishColors.marianBlue, size: 22),
                      SizedBox(width: 8),
                      Text('Attached ID Inspection', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 16),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: InteractiveViewer(
                    panEnabled: true,
                    minScale: 0.8,
                    maxScale: 4.0,
                    child: Center(
                      child: Image.memory(bytes, fit: BoxFit.contain),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ParishColors.marianBlue,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Looks Good'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _triggerDebouncedValidation() {
    _saveDraft();
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
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

    final preset = _presets[_selectedService];
    if (preset?.isAnytimeAllowed == true) {
      setState(() => _isLiveChecking = false);
      return;
    }

    final dateStr =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    final startStr = _formatTimeOfDay(_estimatedServiceTime);
    final computedEnd = _calculateEndTime(_estimatedServiceTime, _estimatedDurationMinutes);
    final endStr = _formatTimeOfDay(computedEnd);
    final venueStr = _isOnParishGrounds
        ? 'Parish Grounds'
        : 'Outside Parish (${_outsideLocationController.text.trim()})';

    final warning = await AppointmentService.checkScheduleConflictSilent(
      date: dateStr,
      startTime: startStr,
      endTime: endStr,
      venue: venueStr,
      officiant: _selectedOfficiant,
      serviceType: _selectedService,
      allowMondayException: _allowMondayException,
    );

    if (!mounted) return;

    if (warning != null) {
      final nextSlot = await AppointmentService.findNextAvailableSlot(
        date: dateStr,
        durationMinutes: _estimatedDurationMinutes,
        venue: venueStr,
        officiant: _selectedOfficiant,
        preferredStartTime: _estimatedServiceTime,
        serviceType: _selectedService,
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
        _estimatedServiceTime = _suggestedSlot!['start']!;
      });
      _runLiveConflictCheck();
    }
  }

  Future<void> _saveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftMap = {
        'service': _selectedService,
        'requesterName': _requesterNameController.text.trim(),
        'contact': _contactNumberController.text.trim(),
        'email': _emailController.text.trim(),
        'remarks': _remarksController.text.trim(),
        'outsideLocation': _outsideLocationController.text.trim(),
        'isOnParishGrounds': _isOnParishGrounds,
        'date': _selectedDate.toIso8601String(),
        'startHour': _estimatedServiceTime.hour,
        'startMinute': _estimatedServiceTime.minute,
        'duration': _estimatedDurationMinutes,
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
            if (!_isParishioner && map['requesterName'] != null) {
              _requesterNameController.text = map['requesterName'];
            }
            if (_contactNumberController.text.isEmpty && map['contact'] != null) {
              _contactNumberController.text = map['contact'];
            }
            if (!_isParishioner && map['email'] != null) {
              _emailController.text = map['email'];
            }
            if (map['remarks'] != null) _remarksController.text = map['remarks'];
            if (map['outsideLocation'] != null) _outsideLocationController.text = map['outsideLocation'];
            if (map['isOnParishGrounds'] != null) _isOnParishGrounds = map['isOnParishGrounds'];
            if (map['service'] != null && _presets.containsKey(map['service'])) {
              _selectedService = map['service'];
            }
            if (map['duration'] != null) _estimatedDurationMinutes = map['duration'];
            if (map['date'] != null) {
              final draftDate = DateTime.tryParse(map['date']);
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              if (draftDate != null && !draftDate.isBefore(today)) {
                _selectedDate = draftDate;
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

  Future<void> _submitAppointment() async {
    setState(() {
      _errorMessage = null;
      _idFileHasError = _isParishioner && _attachedIdFileBytes == null;
    });

    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);

    if (targetDay.isBefore(today)) {
      setState(() => _errorMessage = 'Cannot schedule appointments for past dates.');
      return;
    }

    if (_isParishioner && _attachedIdFileBytes == null) {
      setState(() => _errorMessage = 'Please attach a photo or copy of your valid ID card.');
      return;
    }

    // Venue resolution
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

    final startStr = _formatTimeOfDay(_estimatedServiceTime);
    final computedEnd = _calculateEndTime(_estimatedServiceTime, _estimatedDurationMinutes);
    final endStr = _formatTimeOfDay(computedEnd);
    final dateStr =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

    final preset = _presets[_selectedService];
    final isAnytime = preset?.isAnytimeAllowed ?? false;

    final rawContact = _contactNumberController.text.trim();
    final contact = rawContact.isNotEmpty ? rawContact : 'N/A';

    setState(() => _isSubmitting = true);

    try {
      if (!isAnytime) {
        final conflictWarning = await AppointmentService.checkScheduleConflictSilent(
          date: dateStr,
          startTime: startStr,
          endTime: endStr,
          venue: resolvedVenue,
          officiant: _isParishioner ? 'Rev. Fr. Roy' : _selectedOfficiant,
          serviceType: _selectedService,
          allowMondayException: _allowMondayException,
        );

        if (conflictWarning != null) {
          setState(() {
            _errorMessage = conflictWarning;
          });
          return;
        }
      }

      String? uploadedDocumentPath;
      final tempId = 'APT-${DateTime.now().millisecondsSinceEpoch % 1000000}';

      if (_isParishioner && _attachedIdFileBytes != null && _attachedIdFileName != null) {
        uploadedDocumentPath = await AppointmentService.uploadIdDocument(
          appointmentId: tempId,
          fileBytes: _attachedIdFileBytes!,
          fileName: _attachedIdFileName!,
        );
      }

      final created = await AppointmentService.createAppointment(
        serviceType: _selectedService,
        requesterName: _requesterNameController.text.trim(),
        contactNumber: contact,
        email: _emailController.text.trim(),
        date: dateStr,
        startTime: startStr,
        endTime: endStr,
        venue: resolvedVenue,
        officiant: _isParishioner ? 'Rev. Fr. Roy' : _selectedOfficiant,
        idType: _isParishioner ? _selectedIdType : null,
        idNumber: _isParishioner ? _idNumberController.text.trim() : null,
        idDocumentUrl: uploadedDocumentPath,
        remarks: _remarksController.text.trim(),
        allowMondayException: _allowMondayException,
      );

      await _clearDraft();

      if (!mounted) return;
      Navigator.pop(context);

      // Staff confirmation: Quick toast banner without patronizing checklist
      if (!_isParishioner) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Appointment plotted: ${created.serviceType} for ${created.requesterName} ($dateStr at ${_formatTime12Hour(_estimatedServiceTime)}).',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: ParishColors.oliveGreen,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        showAppointmentSubmissionSuccessModal(
          context,
          appointment: created,
          userEmail: _emailController.text.trim(),
        );
      }

      widget.onAppointmentSaved?.call();
    } catch (e) {
      if (!mounted) return;
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
              'St. John Paul II Parish • Pastoral Liturgy Desk',
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
              if (val != null) {
                setState(() {
                  _selectedService = val;
                  _applyServicePreset(val);
                });
                _triggerDebouncedValidation();
              }
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
                    _buildFieldLabel(_isParishioner ? 'Contact Number *' : 'Contact Number (Optional)'),
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
                      decoration: _inputDecoration(
                        hint: '09XX-XXX-XXXX',
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

          // Venue Architecture: Parish Grounds vs. Outside Parish (Custom Free-Text)
          _buildFieldLabel('Venue / Location *'),
          Container(
            padding: const EdgeInsets.all(12),
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
                          _triggerDebouncedValidation();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Outside Parish', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                        selected: !_isOnParishGrounds,
                        onSelected: (_) {
                          setState(() {
                            _isOnParishGrounds = false;
                          });
                          _triggerDebouncedValidation();
                        },
                      ),
                    ),
                  ],
                ),

                // If outside parish: presents an empty text field for Sister to freely type
                if (!_isOnParishGrounds) ...[
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _outsideLocationController,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    onChanged: (_) => _triggerDebouncedValidation(),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Please specify the exact venue or address' : null,
                    decoration: _inputDecoration(
                      hint: 'Type location (e.g. Sitio Ilaya, Brgy. Labuin / San Pedro Hospital)',
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Portal-Only ID Upload (Completely Hidden for Staff)
          if (_isParishioner) ...[
            _buildFieldLabel('Valid Identification Document * (Required)'),
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

            // Attachment Box
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _attachedIdFileBytes != null ? Icons.check_circle : Icons.attach_file,
                            color: _attachedIdFileBytes != null ? ParishColors.oliveGreen : ParishColors.marianBlue,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _attachedIdFileBytes != null
                                ? 'Valid ID Document Attached'
                                : 'Attach valid ID photo (JPG, PNG, PDF up to 5MB)',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: _attachedIdFileBytes != null ? ParishColors.oliveGreen : textDark,
                            ),
                          ),
                        ],
                      ),
                      if (_attachedIdFileBytes != null)
                        IconButton(
                          icon: const Icon(Icons.close, size: 18, color: ParishColors.mercyRed),
                          onPressed: _removeAttachedIdDocument,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_attachedIdFileBytes == null) ...[
                    Text('Stored securely and verified during secretariat review.', style: TextStyle(fontSize: 11.5, color: textMuted)),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _pickIdDocument,
                      icon: const Icon(Icons.upload_file, size: 16),
                      label: const Text('Choose File'),
                    ),
                  ] else ...[
                    InkWell(
                      onTap: () => _openImagePreviewDialog(_attachedIdFileBytes!, _attachedIdFileName ?? 'valid_id.jpg'),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.memory(_attachedIdFileBytes!, width: 44, height: 44, fit: BoxFit.cover),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_attachedIdFileName ?? 'valid_id.jpg', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                Text('Tap to inspect image', style: TextStyle(fontSize: 11, color: textMuted)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          _buildFieldLabel('Remarks / Intentions / Special Instructions (Optional)'),
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
    return Column(
      children: [
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

              // Single Estimated Service Time Picker
              _buildFieldLabel('Service Time *'),
              InkWell(
                onTap: _pickServiceTime,
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
                        _formatTime12Hour(_estimatedServiceTime),
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textDark),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: ParishColors.marianBlueSurface,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '~${_estimatedDurationMinutes}m',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ParishColors.marianBlue),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.access_time, size: 16),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Duration selector pills
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [30, 45, 60, 90, 120].map((dur) {
                  final isSelected = _estimatedDurationMinutes == dur;
                  final label = dur < 60 ? '${dur}m' : '${dur ~/ 60}${dur % 60 != 0 ? ".5" : ""}h';
                  return ChoiceChip(
                    label: Text(label, style: const TextStyle(fontSize: 11)),
                    selected: isSelected,
                    selectedColor: ParishColors.marianBlueSurface,
                    onSelected: (_) {
                      setState(() => _estimatedDurationMinutes = dur);
                      _triggerDebouncedValidation();
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

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
                              'Auto-Set: ${_formatTime12Hour(_suggestedSlot!['start']!)}',
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
                          'Requested slot is open on the parish ledger.',
                          style: TextStyle(color: ParishColors.oliveGreen, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),

              if (!_isParishioner) ...[
                _buildFieldLabel('Presiding Clergy *'),
                DropdownButtonFormField<String>(
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
                  onPressed: _isSubmitting ? null : _submitAppointment,
                  icon: _isSubmitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.check, size: 20),
                  label: Text(
                    _isSubmitting
                        ? 'Validating & Submitting...'
                        : (_isParishioner
                        ? 'Submit for Office Approval'
                        : 'Plot on Calendar'),
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
      focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)), borderSide: BorderSide(color: ParishColors.marianBlue, width: 1.8)),
    );
  }
}