// =============================================================================
// FILE: lib/features/appointments/presentation/appointments_view.dart
// =============================================================================

import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/colors.dart';
import '../../../core/database/local_database_service.dart';
import '../../../core/services/records_sync_service.dart';
import '../../auth/services/auth_service.dart';
import '../../receipts/presentation/dialogs/receipt_detail_dialog.dart';
import '../models/appointment_model.dart';
import '../models/liturgical_event_model.dart';
import '../models/mass_intention_model.dart';
import '../services/appointment_service.dart';
import '../services/liturgical_calendar_service.dart';
import '../services/mass_intention_pdf_service.dart';
import '../services/mass_intention_service.dart';
import 'dialogs/appointment_detail_dialog.dart';
import 'dialogs/manage_payment_references_dialog.dart';
import 'dialogs/review_mass_intention_payment_dialog.dart';
import 'pages/book_mass_intention_page.dart';
import 'pages/schedule_service_page.dart';

enum LedgerMode { timetable, monthOverview, searchRegister, massIntentions }

/// Uniform Status Color Scheme
class AppointmentStatusColors {
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'approved':
        return const Color(0xFF16A34A); // Green: Approved / Confirmed
      case 'pending':
      case 'rescheduled':
        return const Color(0xFFD97706); // Yellow / Amber: Pending
      case 'completed':
        return const Color(0xFF64748B); // Gray: Concluded / Completed
      case 'cancelled':
      case 'rejected':
      default:
        return const Color(0xFFDC2626); // Red: Cancelled / Rejected
    }
  }

  static Color getStatusSurface(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'approved':
        return const Color(0xFFF0FDF4); // Green Surface
      case 'pending':
      case 'rescheduled':
        return const Color(0xFFFFFBEB); // Yellow Surface
      case 'completed':
        return const Color(0xFFF1F5F9); // Gray Surface
      case 'cancelled':
      case 'rejected':
      default:
        return const Color(0xFFFEF2F2); // Red Surface
    }
  }
}

class _ContinuousTimeBand {
  final String label;
  final int startMinutes;
  final int endMinutes;
  final String sublabel;

  const _ContinuousTimeBand({
    required this.label,
    required this.startMinutes,
    required this.endMinutes,
    this.sublabel = '',
  });

  TimeOfDay get timeOfDay =>
      TimeOfDay(hour: startMinutes ~/ 60, minute: startMinutes % 60);
}

class AppointmentsView extends StatefulWidget {
  const AppointmentsView({super.key});

  @override
  State<AppointmentsView> createState() => _AppointmentsViewState();
}

class _AppointmentsViewState extends State<AppointmentsView> {
  LedgerMode _activeMode = LedgerMode.monthOverview;
  DateTime _selectedDate = DateTime.now();

  // Core Ledger Data
  List<AppointmentModel> _appointments = [];
  List<MassIntentionModel> _massIntentions = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Search Register & Filtering State
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedStatusFilter = 'All';
  String _selectedDateRangeFilter = 'All Dates';
  DateTimeRange? _customDateRange;
  String _selectedServiceFilter = 'All';
  String _sortBy = 'Date: Earliest First';
  bool _sortAscending = true;
  int _registerCurrentPage = 1;
  int _registerItemsPerPage = 10;

  // Slide-Over Desk Drawer State
  bool _isPanelOpen = false;
  bool _isPanelPlottingMode = false;
  String? _editingAppointmentId;
  DateTime? _panelDate;
  TimeOfDay? _panelTime;
  String _plotService = 'Nuptial Mass (Wedding)';
  bool _plotIsOnParishGrounds = true;
  final TextEditingController _plotOutsideLocationController = TextEditingController();
  final TextEditingController _plotNameController = TextEditingController();
  final TextEditingController _plotContactController = TextEditingController();
  final TextEditingController _plotRemarksController = TextEditingController();
  int _plotDurationMinutes = 60;
  bool _isSavingPlot = false;
  String? _plotError;
  String? _plotDuplicateWarning;

  // Anti-Gibberish Keyboard Sequence List
  static const List<String> _keyboardWalks = [
    'asdf', 'sdfg', 'dfgh', 'fghj', 'ghjk', 'hjkl',
    'qwer', 'wert', 'erty', 'rtyu', 'tyui', 'yuio', 'uiop',
    'zxcv', 'xcvb', 'cvbn', 'vbnm',
    'fdsa', 'gfds', 'hgfd', 'jhgf', 'kjhg', 'lkjh',
    'rewq', 'trew', 'ytre', 'uytr', 'iuyt', 'poiuy',
    'vcxz', 'bvcx', 'nbvc', 'mnbv',
  ];

  // Continuous Time Bands (08:00 AM through 06:30 PM+)
  static const List<_ContinuousTimeBand> _continuousTimeBands = [
    _ContinuousTimeBand(label: '08:00 AM', startMinutes: 480, endMinutes: 540, sublabel: 'Early Rites / Mass'),
    _ContinuousTimeBand(label: '09:00 AM', startMinutes: 540, endMinutes: 600, sublabel: 'Morning Window'),
    _ContinuousTimeBand(label: '10:00 AM', startMinutes: 600, endMinutes: 660, sublabel: 'Morning Window'),
    _ContinuousTimeBand(label: '11:00 AM', startMinutes: 660, endMinutes: 720, sublabel: 'Community Baptism (11 AM)'),
    _ContinuousTimeBand(label: '12:00 PM', startMinutes: 720, endMinutes: 810, sublabel: 'Midday Angelus / Desk Break'),
    _ContinuousTimeBand(label: '01:30 PM', startMinutes: 810, endMinutes: 870, sublabel: 'Afternoon Desk Reopen'),
    _ContinuousTimeBand(label: '02:30 PM', startMinutes: 870, endMinutes: 930, sublabel: 'Afternoon Rites Window'),
    _ContinuousTimeBand(label: '03:30 PM', startMinutes: 930, endMinutes: 990, sublabel: 'Afternoon Rites Window'),
    _ContinuousTimeBand(label: '04:30 PM', startMinutes: 990, endMinutes: 1050, sublabel: 'Late Afternoon Window'),
    _ContinuousTimeBand(label: '05:30 PM', startMinutes: 1050, endMinutes: 1110, sublabel: 'Weekday Mass Slot'),
    _ContinuousTimeBand(label: '06:30 PM+', startMinutes: 1110, endMinutes: 1440, sublabel: 'Sick Calls / Emergencies'),
  ];

  final List<String> _sacramentOptions = const [
    'Nuptial Mass (Wedding)',
    'Community Baptism',
    'Confirmation (Kumpil)',
    'Funeral Mass & Blessing',
    'Anointing of the Sick & Viaticum',
    'Confession & Spiritual Direction',
    'House / Business Blessing',
    'Canonical Interview / Pre-Cana',
    'Thanksgiving Mass Intention',
  ];

  final List<String> _statusOptions = const [
    'All',
    'Pending',
    'Confirmed',
    'Rescheduled',
    'Completed',
    'Cancelled',
  ];

  final List<String> _dateRangeOptions = const [
    'All Dates',
    'Today',
    'This Week',
    'This Month',
    'Upcoming Only',
    'Custom Date Range',
  ];

  final List<String> _sortOptions = const [
    'Date: Earliest First',
    'Date: Latest First',
    'Service / Sacrament',
    'Requester Name',
  ];

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  bool _isPastDate(DateTime date) {
    final target = DateTime(date.year, date.month, date.day);
    return target.isBefore(_today);
  }

  Map<String, List<MassIntentionModel>> get _groupedMassIntentions {
    final Map<String, List<MassIntentionModel>> groups = {};
    for (final item in _massIntentions) {
      if (item.isRejected) continue;
      final key = item.formattedScheduleDisplay;
      groups.putIfAbsent(key, () => []).add(item);
    }
    return groups;
  }

  MapEntry<String, List<MassIntentionModel>>? get _nearestUpcomingMassSlot {
    final today = _today;
    final futureEntries = _groupedMassIntentions.entries.where((entry) {
      final item = entry.value.first;
      return !item.scheduledDate.isBefore(today);
    }).toList();

    if (futureEntries.isEmpty) return null;
    return futureEntries.first;
  }

  @override
  void initState() {
    super.initState();
    RecordsSyncService.instance.checkConnectivity();
    RecordsSyncService.instance.updatePendingCount();
    _loadAllLedgerData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _plotOutsideLocationController.dispose();
    _plotNameController.dispose();
    _plotContactController.dispose();
    _plotRemarksController.dispose();
    super.dispose();
  }

  Future<void> _loadAllLedgerData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        AppointmentService.getAppointments(),
        MassIntentionService.getMassIntentions(),
        LiturgicalCalendarService.getCalendarForYear(_selectedDate.year),
      ]);

      if (!mounted) return;
      setState(() {
        _appointments = results[0] as List<AppointmentModel>;
        _massIntentions = results[1] as List<MassIntentionModel>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _navigateDate(int delta) {
    setState(() {
      if (_activeMode == LedgerMode.monthOverview) {
        _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + delta, 1);
      } else {
        _selectedDate = _selectedDate.add(Duration(days: delta * 7));
      }
    });

    LiturgicalCalendarService.getCalendarForYear(_selectedDate.year).then((_) {
      if (mounted) setState(() {});
    });
  }

  List<AppointmentModel> _getAppointmentsForDate(DateTime date) {
    return _appointments.where((a) {
      final st = a.appointmentStatus.toLowerCase();
      if (st == 'cancelled') return false; // Excluded from calendar
      return a.requestedDate.year == date.year &&
          a.requestedDate.month == date.month &&
          a.requestedDate.day == date.day;
    }).toList();
  }

  List<LiturgicalEvent> _getLiturgicalFeastsForDate(DateTime date) {
    return LiturgicalCalendarService.getCelebrationsForDateSync(date);
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
      return 'Name contains invalid characters (letters and spaces only).';
    }

    final lower = trimmed.toLowerCase();
    if (RegExp(r'(.)\1{2,}', caseSensitive: false).hasMatch(trimmed)) {
      return 'Name cannot contain 3 or more identical letters consecutively.';
    }
    if (RegExp(r'(.{2,4})\1{2,}', caseSensitive: false).hasMatch(lower)) {
      return 'Please enter a genuine name (repetitive text pattern detected).';
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

  // ---------------------------------------------------------------------------
  // Monday Exception Confirmation
  // ---------------------------------------------------------------------------
  Future<bool> _confirmMondayException(DateTime date) async {
    if (date.weekday != DateTime.monday) return true;

    final dateStr = '${_getMonthName(date.month)} ${date.day}, ${date.year}';
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
          'Mondays ($dateStr) are designated Clergy Rest Days and the parish office is routinely closed.\n\n'
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

  // ---------------------------------------------------------------------------
  // CRUD Actions Engine
  // ---------------------------------------------------------------------------
  void _openDayInspector(DateTime date) async {
    if (date.weekday == DateTime.monday) {
      final allowed = await _confirmMondayException(date);
      if (!allowed) return;
    }

    setState(() {
      _panelDate = date;
      _panelTime = const TimeOfDay(hour: 10, minute: 0);
      _isPanelOpen = true;
      _isPanelPlottingMode = false;
      _editingAppointmentId = null;
      _isSavingPlot = false;
      _plotError = null;
      _plotDuplicateWarning = null;
    });
  }

  void _openQuickPlotForSlot(DateTime date, _ContinuousTimeBand band) async {
    if (date.weekday == DateTime.monday) {
      final allowed = await _confirmMondayException(date);
      if (!allowed) return;
    }

    setState(() {
      _panelDate = date;
      _panelTime = band.timeOfDay;
      _isPanelOpen = true;
      _isPanelPlottingMode = true;
      _editingAppointmentId = null;
      _isSavingPlot = false;
      _plotError = null;
      _plotDuplicateWarning = null;
      _plotService = band.label.contains('11:00')
          ? 'Community Baptism'
          : 'Nuptial Mass (Wedding)';
      _plotDurationMinutes = AppointmentService.getMinimumDurationMinutes(_plotService);
      _plotIsOnParishGrounds = true;
      _plotOutsideLocationController.clear();
      _plotNameController.clear();
      _plotContactController.clear();
      _plotRemarksController.clear();
    });
  }

  /// Unified Edit & Reschedule Action in Drawer
  void _openEditInDrawer(AppointmentModel a) {
    final bool isOutside = a.venue.toLowerCase().contains('outside');

    setState(() {
      _panelDate = a.requestedDate;
      try {
        final parts = a.requestedTime.split(':');
        _panelTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      } catch (_) {
        _panelTime = const TimeOfDay(hour: 10, minute: 0);
      }
      _editingAppointmentId = a.appointmentId;
      _isPanelOpen = true;
      _isPanelPlottingMode = true;
      _isSavingPlot = false;
      _plotError = null;
      _plotDuplicateWarning = null;
      _plotService = a.serviceType;
      _plotDurationMinutes = AppointmentService.getMinimumDurationMinutes(a.serviceType);
      _plotIsOnParishGrounds = !isOutside;
      _plotOutsideLocationController.text = isOutside
          ? a.venue.replaceAll(RegExp(r'^Outside Parish\s*\((.*)\)$', caseSensitive: false), r'$1').trim()
          : '';
      _plotNameController.text = a.requesterName;
      _plotContactController.text = a.contactNumber == 'N/A' ? '' : a.contactNumber;
      _plotRemarksController.text = a.appointmentRemarks ?? '';
    });
  }

  void _closePanel() {
    setState(() {
      _isPanelOpen = false;
      _isPanelPlottingMode = false;
      _editingAppointmentId = null;
      _isSavingPlot = false;
      _plotError = null;
      _plotDuplicateWarning = null;
    });
  }

  Future<void> _checkDuplicateOnTyping(String name) async {
    if (name.trim().length < 3 || _editingAppointmentId != null) {
      if (_plotDuplicateWarning != null) {
        setState(() => _plotDuplicateWarning = null);
      }
      return;
    }

    final date = _panelDate ?? _selectedDate;
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    final warning = await AppointmentService.checkDuplicateRequester(
      requesterName: name.trim(),
      date: dateStr,
      serviceType: _plotService,
      excludeAppointmentId: _editingAppointmentId,
    );

    if (mounted) {
      setState(() => _plotDuplicateWarning = warning);
    }
  }

  /// Interactive Date Picker within the Drawer Form
  Future<void> _pickDrawerDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initial = _panelDate ?? _selectedDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(today) ? today : initial,
      firstDate: today,
      lastDate: today.add(const Duration(days: 730)),
    );

    if (picked != null) {
      if (picked.weekday == DateTime.monday) {
        final allowed = await _confirmMondayException(picked);
        if (!allowed) return;
      }
      setState(() {
        _panelDate = picked;
      });
      _checkDuplicateOnTyping(_plotNameController.text);
    }
  }

  Future<void> _saveQuickPlot() async {
    setState(() {
      _plotError = null;
      _isSavingPlot = true;
    });

    try {
      final rawName = _plotNameController.text;
      final nameError = _validateFullName(rawName);
      if (nameError != null) {
        setState(() => _plotError = nameError);
        return;
      }

      final name = rawName.trim();
      final rawContact = _plotContactController.text.trim();
      final contact = rawContact.isNotEmpty ? rawContact : 'N/A';

      // Clean Venue Resolution
      String resolvedVenue;
      if (_plotIsOnParishGrounds) {
        resolvedVenue = 'Parish Grounds';
      } else {
        final specificOutside = _plotOutsideLocationController.text.trim();
        if (specificOutside.isEmpty) {
          setState(() => _plotError = 'Please specify the location outside the parish.');
          return;
        }
        resolvedVenue = 'Outside Parish ($specificOutside)';
      }

      final date = _panelDate ?? _selectedDate;
      final time = _panelTime ?? const TimeOfDay(hour: 10, minute: 0);

      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final startTimeStr =
          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';
      final computedEndMinutes = time.hour * 60 + time.minute + _plotDurationMinutes;
      final endTimeStr =
          '${(computedEndMinutes ~/ 60 % 24).toString().padLeft(2, '0')}:${(computedEndMinutes % 60).toString().padLeft(2, '0')}:00';

      if (_editingAppointmentId != null) {
        // UPDATE: Preserves confirmed status for staff CRUD operations
        final existingApt = _appointments.firstWhere((item) => item.appointmentId == _editingAppointmentId);
        final existingStatus = existingApt.appointmentStatus.toLowerCase();
        // If already confirmed, it STAYS confirmed!
        final targetStatus = existingStatus == 'confirmed' ? 'confirmed' : 'pending';

        final updatePayload = {
          'requested_date': dateStr,
          'requested_time': startTimeStr,
          'end_time': endTimeStr,
          'venue': resolvedVenue,
          'requester_name': name,
          'contact_number': contact,
          'appointment_status': targetStatus,
          'appointment_remarks': _plotRemarksController.text.trim(),
          'updated_at': DateTime.now().toIso8601String(),
        };

        final isOnline = await RecordsSyncService.instance.checkConnectivity();
        if (isOnline) {
          await Supabase.instance.client
              .from('appointments')
              .update(updatePayload)
              .eq('appointment_id', _editingAppointmentId!);
        }

        final db = await LocalDatabaseService.instance.database;
        if (db != null) {
          await db.update('appointments', updatePayload, where: 'appointment_id = ?', whereArgs: [_editingAppointmentId!]);
        }
      } else {
        // CREATE
        final conflictWarning = await AppointmentService.checkScheduleConflictSilent(
          date: dateStr,
          startTime: startTimeStr,
          endTime: endTimeStr,
          venue: resolvedVenue,
          officiant: 'Rev. Fr. Roy',
          serviceType: _plotService,
        );

        if (conflictWarning != null) {
          setState(() => _plotError = conflictWarning);
          return;
        }

        await AppointmentService.createAppointment(
          serviceType: _plotService,
          requesterName: name,
          contactNumber: contact,
          date: dateStr,
          startTime: startTimeStr,
          endTime: endTimeStr,
          venue: resolvedVenue,
          officiant: 'Rev. Fr. Roy',
          remarks: _plotRemarksController.text.trim(),
        );
      }

      _closePanel();
      await _loadAllLedgerData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _editingAppointmentId != null
                        ? 'Appointment updated on the parish ledger.'
                        : 'Appointment plotted: $_plotService for $name on $dateStr.',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: ParishColors.oliveGreen,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _plotError = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingPlot = false);
      }
    }
  }

  Future<void> _cancelBookingAction(AppointmentModel a) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Appointment Booking?'),
        content: Text(
          'Cancel booking for ${a.serviceType} (${a.requesterName})? This will immediately free up the slot on the calendar.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep Slot')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ParishColors.mercyRed, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Booking'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await AppointmentService.updateStatus(a.appointmentId, 'cancelled');
        await _loadAllLedgerData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Appointment cancelled and slot released.'), backgroundColor: ParishColors.mercyRed),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: ParishColors.mercyRed),
          );
        }
      }
    }
  }

  Future<void> _permanentDeleteAppointment(AppointmentModel a) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: ParishColors.mercyRed, size: 24),
            SizedBox(width: 8),
            Text('Permanently Delete Record?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently purge ${a.serviceType} (${a.requesterName}) from the parish database? This action cannot be undone.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ParishColors.mercyRed, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Permanently Purge'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final isOnline = await RecordsSyncService.instance.checkConnectivity();
        if (isOnline) {
          await Supabase.instance.client
              .from('appointments')
              .delete()
              .eq('appointment_id', a.appointmentId);
        }

        final db = await LocalDatabaseService.instance.database;
        if (db != null) {
          await db.delete('appointments', where: 'appointment_id = ?', whereArgs: [a.appointmentId]);
          await RecordsSyncService.instance.queueOfflineChange(
            tableName: 'appointments',
            recordId: a.appointmentId,
            operation: 'DELETE',
            data: {},
          );
        }

        await _loadAllLedgerData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cancelled appointment permanently deleted.'), backgroundColor: ParishColors.mercyRed),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: ParishColors.mercyRed),
          );
        }
      }
    }
  }

  Future<void> _purgeAllCancelledRecords() async {
    final cancelledList = _appointments.where((a) => a.appointmentStatus.toLowerCase() == 'cancelled').toList();
    if (cancelledList.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_sweep, color: ParishColors.mercyRed, size: 24),
            SizedBox(width: 8),
            Text('Clean Cancelled Records?'),
          ],
        ),
        content: Text(
          'Permanently purge all ${cancelledList.length} cancelled appointment records from the parish database? This will clean up the ledger history and cannot be undone.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ParishColors.mercyRed, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Purge All Cancelled'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final client = Supabase.instance.client;
        final db = await LocalDatabaseService.instance.database;

        for (final a in cancelledList) {
          try {
            await client.from('appointments').delete().eq('appointment_id', a.appointmentId);
          } catch (_) {}
          if (db != null) {
            await db.delete('appointments', where: 'appointment_id = ?', whereArgs: [a.appointmentId]);
          }
        }

        await _loadAllLedgerData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Purged ${cancelledList.length} cancelled records from the database.'), backgroundColor: ParishColors.mercyRed),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: ParishColors.mercyRed),
          );
        }
      }
    }
  }

  Future<void> _quickStatusTransition(AppointmentModel a, String newStatus) async {
    try {
      await AppointmentService.updateStatus(a.appointmentId, newStatus);
      await _loadAllLedgerData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status marked as ${newStatus.toUpperCase()}.'),
            backgroundColor: AppointmentStatusColors.getStatusColor(newStatus),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $e'), backgroundColor: ParishColors.mercyRed),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Mass Intentions Handlers
  // ---------------------------------------------------------------------------
  void _printLiturgicalSlipForSlot(String slotKey, List<MassIntentionModel> intentions) {
    if (intentions.isEmpty) return;
    final first = intentions.first;

    MassIntentionPdfService.printMassIntentionSlip(
      massDayOfWeek: first.dayOfWeekName,
      massDate: first.formattedDate,
      massTime: first.formattedTime12Hour,
      intentions: intentions,
    );
  }

  void _viewOfficialReceiptForVerifiedIntention(MassIntentionModel item) {
    final serviceTitle =
        'Mass Intention (${item.dayOfWeekName}, ${item.formattedDate} at ${item.formattedTime12Hour})';
    final lines = <String>[];
    if (item.thanksgivingList.isNotEmpty) lines.add('• Thanksgiving: ${item.thanksgivingList.join(", ")}');
    if (item.reposeSoulsList.isNotEmpty) lines.add('• Repose of Souls: ${item.reposeSoulsList.join(", ")}');
    if (item.specialIntentionsList.isNotEmpty) lines.add('• Special Petitions: ${item.specialIntentionsList.join(", ")}');
    if (item.otherIntentions != null && item.otherIntentions!.isNotEmpty) lines.add('• Others: ${item.otherIntentions}');

    final refNote = (item.gcashReferenceNo != null && item.gcashReferenceNo!.isNotEmpty)
        ? '\nGCash Ref: ${item.gcashReferenceNo}'
        : '';
    final details = '• $serviceTitle\n${lines.join("\n")}$refNote\nIntention ID: ${item.intentionId}';

    showReceiptDetailModal(
      context,
      receiptNo: 'REC-VERIFIED',
      payer: item.requesterName,
      purpose: serviceTitle,
      amount: '₱ ${item.stipendAmount.toStringAsFixed(2)}',
      date: item.formattedDate,
      payorContact: item.contactNumber,
      transactionDetails: details,
      paymentMode: item.paymentMethod,
      status: 'PAID',
    );
  }

  // ===========================================================================
  // Top Hero Banner
  // ===========================================================================
  Widget _buildHeroHeader(bool isMobile) {
    final fade = ParishColors.cardWhite;
    final totalActive = _appointments.where((a) {
      final s = a.appointmentStatus.toLowerCase();
      return s != 'cancelled' && s != 'completed';
    }).length + _massIntentions.where((m) => !m.isRejected).length;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'images/jp2-bg.png',
              fit: BoxFit.cover,
              alignment: const Alignment(0.35, -0.55),
              errorBuilder: (_, __, ___) => Container(color: ParishColors.marianBlueSurface),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    fade.withOpacity(0.96),
                    fade.withOpacity(isMobile ? 0.88 : 0.80),
                    fade.withOpacity(isMobile ? 0.25 : 0.0),
                  ],
                  stops: [0.0, isMobile ? 0.62 : 0.45, isMobile ? 1.0 : 0.85],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, fade.withOpacity(0.55)],
                  stops: const [0.55, 1.0],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(isMobile ? 16 : 24, isMobile ? 16 : 22, isMobile ? 12 : 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 56,
                            height: 3,
                            decoration: BoxDecoration(
                              color: ParishColors.goldAccent,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Schedules & Liturgy Desk',
                            style: TextStyle(
                              fontFamily: 'Georgia',
                              fontFamilyFallback: const ['Times New Roman', 'serif'],
                              fontSize: isMobile ? 26 : 38,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                              color: ParishColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$totalActive active booking(s) across sacraments and mass intentions',
                            style: TextStyle(
                              fontSize: isMobile ? 12.5 : 14,
                              fontStyle: FontStyle.italic,
                              color: ParishColors.textDark.withOpacity(0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildOverflowMenu(),
                  ],
                ),
                SizedBox(height: isMobile ? 36 : 56),
                _buildSyncStatusBar(isMobile),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverflowMenu() {
    return Container(
      decoration: BoxDecoration(
        color: ParishColors.cardWhite.withOpacity(0.9),
        shape: BoxShape.circle,
        border: Border.all(color: ParishColors.borderGrey),
      ),
      child: PopupMenuButton<String>(
        icon: Icon(Icons.more_vert, color: ParishColors.textMuted, size: 22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: ParishColors.cardWhite,
        onSelected: (val) {
          if (val == 'gcash_settings') {
            showManagePaymentReferencesModal(context, onReferencesUpdated: _loadAllLedgerData);
          } else if (val == 'refresh') {
            _loadAllLedgerData();
            RecordsSyncService.instance.checkConnectivity();
          }
        },
        itemBuilder: (ctx) => [
          const PopupMenuItem(
            value: 'gcash_settings',
            child: Row(
              children: [
                Icon(Icons.qr_code_2, size: 18),
                SizedBox(width: 10),
                Text('GCash QR & Bank Ledger', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'refresh',
            child: Row(
              children: [
                Icon(Icons.refresh, size: 18),
                SizedBox(width: 10),
                Text('Reload Liturgy Ledger', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncStatusBar(bool isMobile) {
    return ValueListenableBuilder<RecordsSyncStatus>(
      valueListenable: RecordsSyncService.syncStatusNotifier,
      builder: (context, status, _) {
        return ValueListenableBuilder<int>(
          valueListenable: RecordsSyncService.pendingSyncCountNotifier,
          builder: (context, pendingCount, _) {
            Color pillColor;
            Color textColor;
            IconData statusIcon;
            String statusLabel;

            if (status == RecordsSyncStatus.offline) {
              pillColor = Colors.amber.shade50;
              textColor = Colors.amber.shade900;
              statusIcon = Icons.cloud_off;
              statusLabel = pendingCount > 0
                  ? 'Offline • Working Locally ($pendingCount booking(s) queued)'
                  : 'Offline • Working Locally on SQLite Ledger';
            } else if (status == RecordsSyncStatus.syncing) {
              pillColor = Colors.blue.shade50;
              textColor = Colors.blue.shade900;
              statusIcon = Icons.sync;
              statusLabel = 'Synchronizing parish schedule with Supabase cloud...';
            } else if (pendingCount > 0) {
              pillColor = Colors.orange.shade50;
              textColor = Colors.orange.shade900;
              statusIcon = Icons.upload_file;
              statusLabel = 'Online • $pendingCount local edit(s) pending (Tap to Sync)';
            } else {
              pillColor = const Color(0xFFE8F5E9);
              textColor = const Color(0xFF2E7D32);
              statusIcon = Icons.check_circle;
              statusLabel = 'Online • All liturgical records & appointments synchronized';
            }

            final canSync = pendingCount > 0 && status != RecordsSyncStatus.syncing;

            return InkWell(
              onTap: canSync ? () => RecordsSyncService.instance.syncPendingChanges() : null,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: pillColor.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: textColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(statusIcon, size: 17, color: textColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        statusLabel,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!isMobile)
                      ValueListenableBuilder<DateTime?>(
                        valueListenable: RecordsSyncService.lastSyncedAtNotifier,
                        builder: (context, lastSync, _) {
                          final text = lastSync != null
                              ? lastSync.toLocal().toString().substring(0, 16)
                              : 'Just now';
                          return Text(
                            'Last cloud sync: $text',
                            style: TextStyle(fontSize: 11, color: textColor.withOpacity(0.85)),
                          );
                        },
                      ),
                    const SizedBox(width: 8),
                    Icon(Icons.refresh, size: 16, color: textColor),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // Main Build Layout
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth >= 980;

        return RefreshIndicator(
          onRefresh: _loadAllLedgerData,
          color: ParishColors.marianBlue,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 32 : 16,
              vertical: isDesktop ? 24 : 14,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1380),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeroHeader(!isDesktop),
                    const SizedBox(height: 16),
                    _buildLedgerHeaderBar(isDesktop),
                    const SizedBox(height: 16),

                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: ParishColors.mercyRedSurface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: ParishColors.mercyRed),
                        ),
                        child: Text(
                          'Notice: $_errorMessage',
                          style: const TextStyle(color: ParishColors.mercyRed, fontWeight: FontWeight.bold, fontSize: 12.5),
                        ),
                      ),
                    ],

                    Stack(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                          padding: EdgeInsets.only(right: (_isPanelOpen && isDesktop) ? 385 : 0),
                          child: _buildActiveWorkspaceContent(isDesktop),
                        ),

                        if (_isPanelOpen)
                          Positioned(
                            top: 0,
                            bottom: 0,
                            right: 0,
                            width: isDesktop ? 370 : MediaQuery.of(context).size.width * 0.92,
                            child: _buildSlideOverDrawer(isDesktop),
                          ),
                      ],
                    ),
                    const SizedBox(height: 36),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Clean Toolbar & Mode Switcher
  // ---------------------------------------------------------------------------
  Widget _buildLedgerHeaderBar(bool isDesktop) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ParishColors.borderGrey),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Date Navigation
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 28, color: ParishColors.marianBlue),
                    onPressed: () => _navigateDate(-1),
                    tooltip: 'Previous',
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _activeMode == LedgerMode.monthOverview
                        ? '${_getMonthName(_selectedDate.month)} ${_selectedDate.year}'
                        : 'Week of ${_getMonthName(_selectedDate.month).substring(0, 3)} ${_selectedDate.day}, ${_selectedDate.year}',
                    style: TextStyle(
                      fontSize: isDesktop ? 16 : 14,
                      fontWeight: FontWeight.bold,
                      color: ParishColors.marianBlue,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 26, color: ParishColors.marianBlue),
                    onPressed: () => _navigateDate(1),
                    tooltip: 'Next',
                  ),
                  const SizedBox(width: 6),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      backgroundColor: ParishColors.marianBlueSurface,
                      foregroundColor: ParishColors.marianBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => setState(() => _selectedDate = DateTime.now()),
                    icon: const Icon(Icons.today, size: 16),
                    label: const Text('Today', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 18),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildModePill(LedgerMode.monthOverview, 'Month Overview', Icons.calendar_view_month),
                const SizedBox(width: 8),
                _buildModePill(LedgerMode.timetable, 'Week Timetable', Icons.table_chart_outlined),
                const SizedBox(width: 8),
                _buildModePill(LedgerMode.searchRegister, 'Search Records Register', Icons.search),
                const SizedBox(width: 8),
                _buildModePill(LedgerMode.massIntentions, 'Mass Intentions Desk', Icons.volunteer_activism),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModePill(LedgerMode mode, String label, IconData icon) {
    final isSelected = _activeMode == mode;
    return InkWell(
      onTap: () {
        setState(() {
          _activeMode = mode;
          _closePanel();
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? ParishColors.marianBlue : ParishColors.backgroundLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? ParishColors.marianBlue : ParishColors.borderGrey,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : ParishColors.marianBlue),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : ParishColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Active Workspace Content Router
  // ===========================================================================
  Widget _buildActiveWorkspaceContent(bool isDesktop) {
    switch (_activeMode) {
      case LedgerMode.monthOverview:
        return _buildUnclutteredMonthView(isDesktop);
      case LedgerMode.timetable:
        return _buildNaturalWeekTimetable(isDesktop);
      case LedgerMode.searchRegister:
        return _buildSearchRegisterView(isDesktop);
      case LedgerMode.massIntentions:
        return _buildMassIntentionsDesk();
    }
  }

  // ===========================================================================
  // 1. MONTH OVERVIEW
  // ===========================================================================
  Widget _buildUnclutteredMonthView(bool isDesktop) {
    final firstDayOfMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final lastDayOfMonth = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
    final totalDays = lastDayOfMonth.day;
    final offset = firstDayOfMonth.weekday % 7;
    final totalGridCells = ((totalDays + offset) / 7).ceil() * 7;
    final daysOfWeek = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];

    return Container(
      padding: EdgeInsets.all(isDesktop ? 22 : 12),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ParishColors.borderGrey),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: daysOfWeek.map((d) {
              final isMon = d == 'MON';
              return Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isMon ? const Color(0xFF94A3B8) : ParishColors.marianBlue,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const Divider(height: 16),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: totalGridCells,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: isDesktop ? 8 : 4,
              crossAxisSpacing: isDesktop ? 8 : 4,
              childAspectRatio: isDesktop ? 1.25 : 0.82,
            ),
            itemBuilder: (context, index) {
              final dayNum = index - offset + 1;
              if (dayNum < 1 || dayNum > totalDays) return const SizedBox.shrink();

              final cellDate = DateTime(_selectedDate.year, _selectedDate.month, dayNum);
              final isToday = cellDate.day == _today.day && cellDate.month == _today.month && cellDate.year == _today.year;
              final isMonday = cellDate.weekday == DateTime.monday;
              final isSelected = _panelDate != null &&
                  _panelDate!.day == cellDate.day &&
                  _panelDate!.month == cellDate.month &&
                  _isPanelOpen;

              final appointments = _getAppointmentsForDate(cellDate);
              final feasts = _getLiturgicalFeastsForDate(cellDate);

              return InkWell(
                onTap: () => _openDayInspector(cellDate),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? ParishColors.marianBlueSurface
                        : (isToday
                        ? const Color(0xFFEFF6FF)
                        : (isMonday ? const Color(0xFFF8FAFC) : ParishColors.cardWhite)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? ParishColors.marianBlue
                          : (isToday ? ParishColors.marianBlue : ParishColors.borderGrey),
                      width: isSelected || isToday ? 1.6 : 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$dayNum',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.w600,
                              color: isMonday ? const Color(0xFF94A3B8) : ParishColors.textDark,
                            ),
                          ),
                          if (isMonday)
                            const Text('REST', style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                        ],
                      ),
                      const SizedBox(height: 2),

                      if (feasts.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                          margin: const EdgeInsets.only(bottom: 2),
                          decoration: BoxDecoration(
                            color: feasts.first.categorySurfaceColor,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            feasts.first.name,
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: feasts.first.categoryBadgeColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                      Expanded(
                        child: SingleChildScrollView(
                          physics: const NeverScrollableScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _buildExplicitSacramentBadges(appointments),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _buildExplicitSacramentBadges(List<AppointmentModel> appointments) {
    if (appointments.isEmpty) return const [];

    return appointments.map((a) {
      final statusCol = AppointmentStatusColors.getStatusColor(a.appointmentStatus);
      final surfaceCol = AppointmentStatusColors.getStatusSurface(a.appointmentStatus);

      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
        decoration: BoxDecoration(
          color: surfaceCol,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: statusCol.withOpacity(0.4), width: 0.8),
        ),
        child: Row(
          children: [
            Container(width: 4, height: 4, decoration: BoxDecoration(color: statusCol, shape: BoxShape.circle)),
            const SizedBox(width: 3),
            Expanded(
              child: Text(
                a.serviceType,
                style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: statusCol),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  // ===========================================================================
  // 2. CONTINUOUS WEEK TIMETABLE
  // ===========================================================================
  Widget _buildNaturalWeekTimetable(bool isDesktop) {
    final startOfWeek = _selectedDate.subtract(Duration(days: _selectedDate.weekday % 7));
    final weekDays = List.generate(7, (i) => startOfWeek.add(Duration(days: i)));
    final dayNames = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];

    return Container(
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ParishColors.borderGrey),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 1160,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: ParishColors.marianBlueSurface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 86, child: Center(child: Text('SLOT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)))),
                    ...List.generate(7, (idx) {
                      final day = weekDays[idx];
                      final isMon = day.weekday == DateTime.monday;
                      final feasts = _getLiturgicalFeastsForDate(day);

                      return Expanded(
                        child: Column(
                          children: [
                            Text(
                              '${dayNames[idx]} ${day.day}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                                color: isMon ? const Color(0xFF94A3B8) : ParishColors.marianBlue,
                              ),
                            ),
                            if (feasts.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                child: Text(
                                  feasts.first.name,
                                  style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: feasts.first.categoryBadgeColor),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),

              ..._continuousTimeBands.map((band) {
                return Container(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: ParishColors.borderGrey.withOpacity(0.4))),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 86,
                        height: 76,
                        child: Center(
                          child: Text(
                            band.label,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: ParishColors.marianBlue),
                          ),
                        ),
                      ),
                      ...List.generate(7, (dIdx) {
                        final day = weekDays[dIdx];
                        final isMon = day.weekday == DateTime.monday;
                        final appointments = _getAppointmentsInSlotBand(day, band);

                        return Expanded(
                          child: Container(
                            height: 76,
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: isMon ? const Color(0xFFF8FAFC) : ParishColors.cardWhite,
                              border: Border(left: BorderSide(color: ParishColors.borderGrey.withOpacity(0.4))),
                            ),
                            child: appointments.isNotEmpty
                                ? _buildTimetableAppointmentCard(appointments.first)
                                : _buildTimetableOpenSlot(day, band, isMon),
                          ),
                        );
                      }),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  List<AppointmentModel> _getAppointmentsInSlotBand(DateTime date, _ContinuousTimeBand band) {
    return _getAppointmentsForDate(date).where((a) {
      try {
        final parts = a.requestedTime.split(':');
        final h = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        final totalMin = h * 60 + m;
        return totalMin >= band.startMinutes && totalMin < band.endMinutes;
      } catch (_) {
        return false;
      }
    }).toList();
  }

  Widget _buildTimetableAppointmentCard(AppointmentModel apt) {
    final bool isOutside = apt.venue.toLowerCase().contains('outside');
    final statusColor = AppointmentStatusColors.getStatusColor(apt.appointmentStatus);
    final statusSurface = AppointmentStatusColors.getStatusSurface(apt.appointmentStatus);

    return InkWell(
      onTap: () => showAppointmentDetailModal(context, appointment: apt, onStatusUpdated: _loadAllLedgerData),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: statusSurface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: statusColor.withOpacity(0.6), width: 1.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(width: 5, height: 5, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    apt.serviceType,
                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: statusColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Text(
              apt.requesterName,
              style: TextStyle(fontSize: 9, color: ParishColors.textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              isOutside ? 'Outside' : 'Church Altar',
              style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: isOutside ? const Color(0xFFD97706) : ParishColors.marianBlue),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimetableOpenSlot(DateTime day, _ContinuousTimeBand band, bool isMon) {
    if (isMon) {
      return InkWell(
        onTap: () => _openQuickPlotForSlot(day, band),
        child: Center(
          child: Text('Rest', style: TextStyle(fontSize: 9, color: const Color(0xFF94A3B8).withOpacity(0.8))),
        ),
      );
    }
    return InkWell(
      onTap: () => _openQuickPlotForSlot(day, band),
      borderRadius: BorderRadius.circular(6),
      child: Center(
        child: Text('+ Open', style: TextStyle(fontSize: 10, color: ParishColors.marianBlue.withOpacity(0.4), fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ===========================================================================
  // 3. SLIDE-OVER DESK DRAWER (SIMPLIFIED CARD & INTERACTIVE DATE RESCHEDULE)
  // ===========================================================================
  Widget _buildSlideOverDrawer(bool isDesktop) {
    final date = _panelDate ?? _selectedDate;
    final dateStr = '${_getMonthName(date.month)} ${date.day}, ${date.year}';
    final feasts = _getLiturgicalFeastsForDate(date);
    final appointments = _getAppointmentsForDate(date);

    return Container(
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ParishColors.borderGrey),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(-2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: ParishColors.marianBlueSurface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
              border: Border(bottom: BorderSide(color: ParishColors.borderGrey)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      _isPanelPlottingMode ? (_editingAppointmentId != null ? Icons.edit_calendar : Icons.add_task) : Icons.event,
                      size: 18,
                      color: ParishColors.marianBlue,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isPanelPlottingMode
                          ? (_editingAppointmentId != null ? 'Edit / Reschedule' : 'Plot New Appointment')
                          : 'Day Inspector',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: _closePanel,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _isPanelPlottingMode
                  ? _buildPlottingFormBody()
                  : _buildDayInspectorBody(dateStr, feasts, appointments, date),
            ),
          ),
        ],
      ),
    );
  }

  /// Simplified Card: Shows only Sacrament, Requester, Time, and unified Edit/Reschedule action
  Widget _buildDayInspectorBody(
      String dateStr,
      List<LiturgicalEvent> feasts,
      List<AppointmentModel> appointments,
      DateTime date,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(dateStr, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('${appointments.length} appointment(s) booked on this date', style: TextStyle(fontSize: 12, color: ParishColors.textMuted)),
        const Divider(height: 18),

        if (feasts.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: feasts.first.categorySurfaceColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${feasts.first.name} (${feasts.first.gradeName})',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: feasts.first.categoryBadgeColor),
            ),
          ),
          const SizedBox(height: 12),
        ],

        if (appointments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('No ceremonies booked on this date.', style: TextStyle(fontSize: 12, color: ParishColors.textMuted)),
            ),
          )
        else
          ...appointments.map((a) {
            final status = a.appointmentStatus.toLowerCase();
            final statusColor = AppointmentStatusColors.getStatusColor(status);
            final statusSurface = AppointmentStatusColors.getStatusSurface(status);
            final bool isCompleted = status == 'completed';
            final bool isCancelled = status == 'cancelled';

            return InkWell(
              onTap: () => showAppointmentDetailModal(context, appointment: a, onStatusUpdated: _loadAllLedgerData),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ParishColors.backgroundLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ParishColors.borderGrey),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Badge + Sacrament Type + Cancel icon
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: statusSurface, borderRadius: BorderRadius.circular(4)),
                              child: Text(
                                a.appointmentStatus.toUpperCase(),
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: statusColor),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              a.serviceType,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                        if (!isCompleted && !isCancelled)
                          IconButton(
                            icon: const Icon(Icons.cancel_outlined, size: 16, color: ParishColors.mercyRed),
                            tooltip: 'Cancel Booking',
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(2),
                            onPressed: () => _cancelBookingAction(a),
                          )
                        else if (isCompleted)
                          const Text('CONCLUDED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Requester Name & Time
                    Text('Requester: ${a.requesterName}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('Time: ${AppointmentService.formatTime12Hour(a.requestedTime)}', style: TextStyle(fontSize: 12, color: ParishColors.textMuted)),

                    // Unified Edit / Reschedule Button
                    if (!isCompleted && !isCancelled) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 32,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: ParishColors.marianBlue.withOpacity(0.5)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: () => _openEditInDrawer(a),
                          icon: const Icon(Icons.edit_calendar, size: 14, color: ParishColors.marianBlue),
                          label: const Text('Edit / Reschedule', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ParishColors.marianBlue)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),

        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: ParishColors.marianBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => setState(() {
              _isPanelPlottingMode = true;
              _editingAppointmentId = null;
              _isSavingPlot = false;
              _plotNameController.clear();
              _plotContactController.clear();
              _plotRemarksController.clear();
              _plotOutsideLocationController.clear();
              _plotIsOnParishGrounds = true;
            }),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Plot Walk-In on this Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ),
      ],
    );
  }

  /// Interactive Drawer Form with Date Picker & Simplified Venue (Parish Grounds vs Outside)
  Widget _buildPlottingFormBody() {
    final activeDate = _panelDate ?? _selectedDate;
    final dateDisplay = '${_getMonthName(activeDate.month)} ${activeDate.day}, ${activeDate.year}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_plotError != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: ParishColors.mercyRedSurface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_plotError!, style: const TextStyle(color: ParishColors.mercyRed, fontSize: 11.5, fontWeight: FontWeight.bold)),
          ),
        ],

        // 1. Interactive Ceremony Date Picker (Enables full Rescheduling!)
        const Text('Ceremony Date *', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        InkWell(
          onTap: _pickDrawerDate,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: ParishColors.backgroundLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ParishColors.borderGrey),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dateDisplay,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const Icon(Icons.calendar_month, size: 18, color: ParishColors.marianBlue),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 2. Sacrament Dropdown
        const Text('Sacrament / Service *', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: _plotService,
          isExpanded: true,
          decoration: _panelInputDeco(),
          items: _sacramentOptions.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)))).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _plotService = val;
                _plotDurationMinutes = AppointmentService.getMinimumDurationMinutes(val);
              });
            }
          },
        ),
        const SizedBox(height: 12),

        // 3. Single Service Time
        const Text('Estimated Service Time *', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        InkWell(
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: _panelTime ?? const TimeOfDay(hour: 10, minute: 0),
            );
            if (picked != null) setState(() => _panelTime = picked);
          },
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: ParishColors.backgroundLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ParishColors.borderGrey),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _panelTime != null ? AppointmentService.formatTime12Hour('${_panelTime!.hour}:${_panelTime!.minute}:00') : '10:00 AM',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                Text('~${_plotDurationMinutes}m', style: TextStyle(fontSize: 11, color: ParishColors.textMuted)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 4. Venue: Parish Grounds (As Is) vs Outside Parish (Custom Free-Text)
        const Text('Venue Location *', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: const Center(child: Text('Parish Grounds', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                selected: _plotIsOnParishGrounds,
                onSelected: (_) => setState(() => _plotIsOnParishGrounds = true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ChoiceChip(
                label: const Center(child: Text('Outside Parish', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                selected: !_plotIsOnParishGrounds,
                onSelected: (_) => setState(() => _plotIsOnParishGrounds = false),
              ),
            ),
          ],
        ),

        // If outside parish: presents an empty text field for Sister to freely log the location
        if (!_plotIsOnParishGrounds) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _plotOutsideLocationController,
            style: const TextStyle(fontSize: 12.5),
            decoration: _panelInputDeco(
              hint: 'Type location (e.g. Sitio Ilaya, Brgy. Labuin / San Pedro Hospital)',
            ),
          ),
        ],

        const SizedBox(height: 12),

        // 5. Requester Name with Full Anti-Gibberish Validation
        const Text('Requester Full Name *', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        TextField(
          controller: _plotNameController,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r"[a-zA-ZÀ-ÿ\u0100-\u024FÑñ\s.\-’']")),
          ],
          onChanged: (val) => _checkDuplicateOnTyping(val),
          style: const TextStyle(fontSize: 12.5),
          decoration: _panelInputDeco(hint: 'First and Last Name'),
        ),
        if (_plotDuplicateWarning != null) ...[
          const SizedBox(height: 4),
          Text(_plotDuplicateWarning!, style: const TextStyle(fontSize: 10.5, color: Color(0xFFD97706), fontWeight: FontWeight.bold)),
        ],
        const SizedBox(height: 12),

        // 6. Contact Mobile (Optional for Staff Walk-Ins)
        const Text('Contact Mobile (Optional)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        TextField(
          controller: _plotContactController,
          keyboardType: TextInputType.phone,
          maxLength: 13,
          buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(11),
          ],
          style: const TextStyle(fontSize: 12.5),
          decoration: _panelInputDeco(hint: '09XX-XXX-XXXX (Optional)'),
        ),
        const SizedBox(height: 18),

        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _editingAppointmentId != null ? const Color(0xFF7C3AED) : ParishColors.oliveGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _isSavingPlot ? null : _saveQuickPlot,
            child: _isSavingPlot
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(
              _editingAppointmentId != null ? 'Save & Update Appointment' : 'Save & Plot on Schedule',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _panelInputDeco({String? hint}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: ParishColors.backgroundLight,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      isDense: true,
    );
  }

  // ===========================================================================
  // 4. SEARCH RECORDS REGISTER (FULL DATA TABLE & CLICKABLE ROWS)
  // ===========================================================================
  Widget _buildSearchRegisterView(bool isDesktop) {
    var filtered = _appointments;

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      filtered = filtered.where((a) {
        return a.requesterName.toLowerCase().contains(q) ||
            a.serviceType.toLowerCase().contains(q) ||
            a.contactNumber.contains(q) ||
            a.appointmentId.toLowerCase().contains(q) ||
            a.venue.toLowerCase().contains(q);
      }).toList();
    }

    if (_selectedStatusFilter != 'All') {
      filtered = filtered.where((a) => a.appointmentStatus.toLowerCase() == _selectedStatusFilter.toLowerCase()).toList();
    }

    if (_selectedServiceFilter != 'All') {
      filtered = filtered.where((a) => a.serviceType.toLowerCase().contains(_selectedServiceFilter.toLowerCase())).toList();
    }

    final today = _today;
    if (_selectedDateRangeFilter == 'Today') {
      filtered = filtered.where((a) => a.requestedDate.year == today.year && a.requestedDate.month == today.month && a.requestedDate.day == today.day).toList();
    } else if (_selectedDateRangeFilter == 'This Week') {
      final startOfWeek = today.subtract(Duration(days: today.weekday % 7));
      final endOfWeek = startOfWeek.add(const Duration(days: 6, hours: 23, minutes: 59));
      filtered = filtered.where((a) => !a.requestedDate.isBefore(startOfWeek) && !a.requestedDate.isAfter(endOfWeek)).toList();
    } else if (_selectedDateRangeFilter == 'This Month') {
      filtered = filtered.where((a) => a.requestedDate.year == today.year && a.requestedDate.month == today.month).toList();
    } else if (_selectedDateRangeFilter == 'Upcoming Only') {
      filtered = filtered.where((a) => !a.requestedDate.isBefore(today)).toList();
    } else if (_selectedDateRangeFilter == 'Custom Date Range' && _customDateRange != null) {
      filtered = filtered.where((a) => !a.requestedDate.isBefore(_customDateRange!.start) && !a.requestedDate.isAfter(_customDateRange!.end.add(const Duration(hours: 23, minutes: 59)))).toList();
    }

    filtered.sort((a, b) {
      int cmp = 0;
      switch (_sortBy) {
        case 'Date: Latest First':
          cmp = b.requestedDate.compareTo(a.requestedDate);
          break;
        case 'Service / Sacrament':
          cmp = a.serviceType.compareTo(b.serviceType);
          break;
        case 'Requester Name':
          cmp = a.requesterName.toLowerCase().compareTo(b.requesterName.toLowerCase());
          break;
        case 'Date: Earliest First':
        default:
          cmp = a.requestedDate.compareTo(b.requestedDate);
          break;
      }
      return _sortAscending ? cmp : -cmp;
    });

    final totalItems = filtered.length;
    final totalPages = max(1, (totalItems / _registerItemsPerPage).ceil());
    final startIdx = (_registerCurrentPage - 1) * _registerItemsPerPage;
    final endIdx = min(startIdx + _registerItemsPerPage, totalItems);
    final paged = (startIdx >= totalItems) ? <AppointmentModel>[] : filtered.sublist(startIdx, endIdx);
    final bool isCancelledFiltered = _selectedStatusFilter == 'Cancelled';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ParishColors.borderGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              SizedBox(
                width: 280,
                height: 40,
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() {
                    _searchQuery = val;
                    _registerCurrentPage = 1;
                  }),
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search requester, ref, or venue...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    filled: true,
                    fillColor: ParishColors.backgroundLight,
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),

              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<String>(
                    value: _selectedStatusFilter,
                    underline: const SizedBox.shrink(),
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                    items: _statusOptions.map((s) => DropdownMenuItem(value: s, child: Text('Status: $s'))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedStatusFilter = val;
                          _registerCurrentPage = 1;
                        });
                      }
                    },
                  ),
                  const SizedBox(width: 10),
                  DropdownButton<String>(
                    value: _selectedDateRangeFilter,
                    underline: const SizedBox.shrink(),
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                    items: _dateRangeOptions.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                    onChanged: (val) async {
                      if (val != null) {
                        if (val == 'Custom Date Range') {
                          final picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(const Duration(days: 730)),
                          );
                          if (picked != null) {
                            setState(() {
                              _customDateRange = picked;
                              _selectedDateRangeFilter = val;
                              _registerCurrentPage = 1;
                            });
                          }
                        } else {
                          setState(() {
                            _selectedDateRangeFilter = val;
                            _customDateRange = null;
                            _registerCurrentPage = 1;
                          });
                        }
                      }
                    },
                  ),
                  const SizedBox(width: 10),
                  DropdownButton<String>(
                    value: _sortBy,
                    underline: const SizedBox.shrink(),
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                    items: _sortOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _sortBy = val;
                          _registerCurrentPage = 1;
                        });
                      }
                    },
                  ),
                  IconButton(
                    icon: Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward, size: 18),
                    onPressed: () => setState(() => _sortAscending = !_sortAscending),
                  ),

                  if (isCancelledFiltered && filtered.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: ParishColors.mercyRed, foregroundColor: Colors.white, visualDensity: VisualDensity.compact),
                      onPressed: _purgeAllCancelledRecords,
                      icon: const Icon(Icons.delete_sweep, size: 16),
                      label: const Text('Clean All Cancelled', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const Divider(height: 20),

          // Clickable Rows DataTable
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 1100),
              child: DataTable(
                showCheckboxColumn: false,
                headingRowColor: WidgetStateProperty.all(ParishColors.marianBlueSurface),
                headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: ParishColors.marianBlue, fontSize: 12),
                dataTextStyle: TextStyle(fontSize: 12, color: ParishColors.textDark),
                columnSpacing: 16,
                columns: const [
                  DataColumn(label: Text('Ref ID')),
                  DataColumn(label: Text('Sacrament / Service')),
                  DataColumn(label: Text('Requester')),
                  DataColumn(label: Text('Contact')),
                  DataColumn(label: Text('Estimated Schedule')),
                  DataColumn(label: Text('Venue')),
                  DataColumn(label: Text('Presider')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Actions (CRUD)')),
                ],
                rows: paged.map((a) {
                  final status = a.appointmentStatus.toLowerCase();
                  final statusColor = AppointmentStatusColors.getStatusColor(status);
                  final statusSurface = AppointmentStatusColors.getStatusSurface(status);
                  final formattedTime = AppointmentService.formatTime12Hour(a.requestedTime);
                  final duration = AppointmentService.getMinimumDurationMinutes(a.serviceType);
                  final bool isCompleted = status == 'completed';
                  final bool isCancelled = status == 'cancelled';

                  void openDetails() {
                    showAppointmentDetailModal(context, appointment: a, onStatusUpdated: _loadAllLedgerData);
                  }

                  return DataRow(
                    onSelectChanged: (_) => openDetails(),
                    cells: [
                      DataCell(Text(a.appointmentId, style: const TextStyle(fontWeight: FontWeight.bold, color: ParishColors.marianBlue)), onTap: openDetails),
                      DataCell(Text(a.serviceType, style: const TextStyle(fontWeight: FontWeight.bold)), onTap: openDetails),
                      DataCell(Text(a.requesterName)),
                      DataCell(Text(a.contactNumber)),
                      DataCell(Text('${a.formattedDate} at $formattedTime (~${duration}m)'), onTap: openDetails),
                      DataCell(Text(a.venue), onTap: openDetails),
                      DataCell(Text(a.officiantName), onTap: openDetails),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: statusSurface, borderRadius: BorderRadius.circular(4)),
                          child: Text(a.appointmentStatus.toUpperCase(), style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 9.5)),
                        ),
                        onTap: openDetails,
                      ),
                      // Actions (Unified Edit/Reschedule)
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.visibility_outlined, size: 16, color: ParishColors.marianBlue),
                              tooltip: 'View Booking Details',
                              onPressed: openDetails,
                            ),
                            // Unified Edit & Reschedule Action
                            if (!isCompleted && !isCancelled)
                              IconButton(
                                icon: const Icon(Icons.edit_calendar, size: 16, color: Color(0xFF7C3AED)),
                                tooltip: 'Edit / Reschedule',
                                onPressed: () => _openEditInDrawer(a),
                              ),
                            // Quick Approve (if pending)
                            if (status == 'pending' || status == 'rescheduled')
                              IconButton(
                                icon: const Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF16A34A)),
                                tooltip: 'Confirm Booking',
                                onPressed: () => _quickStatusTransition(a, 'confirmed'),
                              ),
                            // Quick Complete (if confirmed)
                            if (status == 'confirmed')
                              IconButton(
                                icon: const Icon(Icons.task_alt, size: 16, color: ParishColors.marianBlue),
                                tooltip: 'Mark Completed',
                                onPressed: () => _quickStatusTransition(a, 'completed'),
                              ),
                            // Cancel: Only available if active
                            if (!isCompleted && !isCancelled)
                              IconButton(
                                icon: const Icon(Icons.cancel_outlined, size: 16, color: ParishColors.mercyRed),
                                tooltip: 'Cancel Booking',
                                onPressed: () => _cancelBookingAction(a),
                              ),
                            // Permanent Purge Delete (Cancelled records only)
                            if (isCancelled)
                              IconButton(
                                icon: const Icon(Icons.delete_forever, size: 18, color: ParishColors.mercyRed),
                                tooltip: 'Permanently Purge Record',
                                onPressed: () => _permanentDeleteAppointment(a),
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Pagination Toolbar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text('Show: ', style: TextStyle(fontSize: 12, color: ParishColors.textMuted)),
                  DropdownButton<int>(
                    value: _registerItemsPerPage,
                    underline: const SizedBox.shrink(),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ParishColors.marianBlue),
                    items: const [
                      DropdownMenuItem(value: 10, child: Text('10')),
                      DropdownMenuItem(value: 25, child: Text('25')),
                      DropdownMenuItem(value: 50, child: Text('50')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _registerItemsPerPage = val;
                          _registerCurrentPage = 1;
                        });
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  Text('entries (Total $totalItems)', style: TextStyle(fontSize: 12, color: ParishColors.textMuted)),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 20),
                    onPressed: _registerCurrentPage > 1 ? () => setState(() => _registerCurrentPage--) : null,
                  ),
                  Text('Page $_registerCurrentPage of $totalPages', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 20),
                    onPressed: _registerCurrentPage < totalPages ? () => setState(() => _registerCurrentPage++) : null,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 5. MASS INTENTIONS DESK
  // ===========================================================================
  Widget _buildMassIntentionsDesk() {
    final groups = _groupedMassIntentions;
    final nearest = _nearestUpcomingMassSlot;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ParishColors.borderGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (nearest != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ParishColors.goldLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ParishColors.goldAccent.withOpacity(0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('NEXT HOLY MASS ALTAR INTENTIONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ParishColors.goldAccent, letterSpacing: 0.5)),
                      const SizedBox(height: 2),
                      Text(nearest.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text('${nearest.value.length} intentions registered for this Mass', style: TextStyle(fontSize: 11.5, color: ParishColors.textMuted)),
                    ],
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: ParishColors.marianBlue, foregroundColor: Colors.white),
                    onPressed: () => _printLiturgicalSlipForSlot(nearest.key, nearest.value),
                    icon: const Icon(Icons.print, size: 16),
                    label: const Text('Print Mass Slip', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF005CEE)),
                  foregroundColor: const Color(0xFF005CEE),
                ),
                onPressed: () => showManagePaymentReferencesModal(context, onReferencesUpdated: _loadAllLedgerData),
                icon: const Icon(Icons.qr_code_2, size: 16),
                label: const Text('GCash Stipend QR & References'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: ParishColors.marianBlue, foregroundColor: Colors.white),
                onPressed: () => navigateToBookMassIntentionPage(context, onIntentionSaved: _loadAllLedgerData),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Encode Walk-In Intention'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          ...groups.entries.map((entry) {
            final slotKey = entry.key;
            final items = entry.value;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: ParishColors.backgroundLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ParishColors.borderGrey),
              ),
              child: ExpansionTile(
                initiallyExpanded: true,
                title: Text(slotKey, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(color: ParishColors.goldLight, borderRadius: BorderRadius.circular(6)),
                      child: Text('${items.length} Slips', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ParishColors.goldAccent)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.print, size: 18, color: ParishColors.marianBlue),
                      tooltip: 'Print Altar Slip',
                      onPressed: () => _printLiturgicalSlipForSlot(slotKey, items),
                    ),
                  ],
                ),
                children: items.map((m) {
                  final isVerified = m.verificationStatus.toLowerCase() == 'verified';

                  return Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: ParishColors.borderGrey.withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${m.requesterName} (${m.totalIntentionsCount} names)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                            Text('₱ ${m.stipendAmount.toStringAsFixed(2)} • ${m.paymentMethod}${m.gcashReferenceNo != null ? " • Ref: ${m.gcashReferenceNo}" : ""}', style: TextStyle(fontSize: 11, color: ParishColors.textMuted)),
                          ],
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isVerified ? ParishColors.oliveGreen : ParishColors.marianBlue,
                            foregroundColor: Colors.white,
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () {
                            if (isVerified) {
                              _viewOfficialReceiptForVerifiedIntention(m);
                            } else {
                              showReviewMassIntentionPaymentModal(context, intention: m, onVerified: _loadAllLedgerData);
                            }
                          },
                          icon: Icon(isVerified ? Icons.receipt_long : Icons.verified_user, size: 13),
                          label: Text(isVerified ? 'View Voucher' : 'Review & Verify', style: const TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            );
          }),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }
}