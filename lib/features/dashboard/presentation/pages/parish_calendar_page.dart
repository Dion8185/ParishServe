// =============================================================================
// FILE: lib/features/dashboard/presentation/pages/parish_calendar_page.dart
// =============================================================================

import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../appointments/models/appointment_model.dart';
import '../../../appointments/models/liturgical_event_model.dart';
import '../../../appointments/presentation/dialogs/appointment_detail_dialog.dart';
import '../../../appointments/presentation/dialogs/parishioner_appointment_detail_dialog.dart';
import '../../../appointments/presentation/dialogs/schedule_appointment_dialog.dart';
import '../../../appointments/services/appointment_service.dart';
import '../../../appointments/services/liturgical_calendar_service.dart';
import '../../../auth/services/auth_service.dart';
import '../../../auth/services/user_service.dart';

enum CalendarViewMode { month, week, day }

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

class _TimetableSlot {
  final String label;
  final int hour;
  final int minute;
  final String slotNote;

  const _TimetableSlot({
    required this.label,
    required this.hour,
    required this.minute,
    this.slotNote = '',
  });

  int get totalMinutes => hour * 60 + minute;
  TimeOfDay get timeOfDay => TimeOfDay(hour: hour, minute: minute);
}

class ParishCalendarPage extends StatefulWidget {
  const ParishCalendarPage({super.key});

  @override
  State<ParishCalendarPage> createState() => _ParishCalendarPageState();
}

class _ParishCalendarPageState extends State<ParishCalendarPage> {
  CalendarViewMode _currentView = CalendarViewMode.week;
  DateTime _selectedDate = DateTime.now();
  String _selectedCategory = 'All';

  List<AppointmentModel> _appointments = [];
  List<Map<String, dynamic>> _serviceRequests = [];
  bool _isLoading = false;
  String? _errorMessage;

  static const Color colorGlobalLiturgical = Color(0xFFDC2626);   // Red
  static const Color colorPhilippineSpecific = Color(0xFF2563EB); // Blue
  static const Color colorAppointments = Color(0xFFD97706);       // Amber
  static const Color colorCertificatePickup = Color(0xFF059669);  // Emerald

  static const List<_TimetableSlot> _timetableSlots = [
    _TimetableSlot(label: '08:00 AM', hour: 8, minute: 0, slotNote: 'Morning Mass / Early Rite'),
    _TimetableSlot(label: '09:00 AM', hour: 9, minute: 0, slotNote: 'Office Opens'),
    _TimetableSlot(label: '10:00 AM', hour: 10, minute: 0, slotNote: 'Morning Service Window'),
    _TimetableSlot(label: '11:00 AM', hour: 11, minute: 0, slotNote: 'Community Baptism (Weekends)'),
    _TimetableSlot(label: '12:00 PM', hour: 12, minute: 0, slotNote: 'Midday Angelus / Desk Break'),
    _TimetableSlot(label: '01:30 PM', hour: 13, minute: 30, slotNote: 'Afternoon Desk Reopens'),
    _TimetableSlot(label: '02:30 PM', hour: 14, minute: 30, slotNote: 'Afternoon Rite Window'),
    _TimetableSlot(label: '03:30 PM', hour: 15, minute: 30, slotNote: 'Afternoon Rite Window'),
    _TimetableSlot(label: '04:30 PM', hour: 16, minute: 30, slotNote: 'Late Afternoon / Anticipated'),
    _TimetableSlot(label: '05:30 PM', hour: 17, minute: 30, slotNote: 'Weekday Mass Slot'),
    _TimetableSlot(label: '06:30 PM+', hour: 18, minute: 30, slotNote: 'Sick Calls / Emergencies'),
  ];

  bool get _isParishioner =>
      AuthService.currentUser?.userRole.toLowerCase() == 'user';

  List<String> get _categories => [
    'All',
    'Global Liturgical',
    'Philippine Proper',
    _isParishioner ? 'My Bookings' : 'Appointments',
    if (_isParishioner) 'Certificate Pickups',
  ];

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  bool _isPastDate(DateTime date) {
    final target = DateTime(date.year, date.month, date.day);
    return target.isBefore(_today);
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      List<AppointmentModel> appointmentsData = [];
      List<Map<String, dynamic>> requestsData = [];

      if (_isParishioner) {
        final results = await Future.wait([
          AppointmentService.getMyAppointments(),
          UserService.getMyServiceRequests(),
        ]);
        appointmentsData = results[0] as List<AppointmentModel>;
        requestsData = results[1] as List<Map<String, dynamic>>;
      } else {
        appointmentsData = await AppointmentService.getAppointments();
      }

      await LiturgicalCalendarService.getCalendarForYear(_selectedDate.year);

      if (!mounted) return;
      setState(() {
        _appointments = appointmentsData;
        _serviceRequests = requestsData;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Strictly filters out cancelled appointments from calendar views
  List<AppointmentModel> _appointmentsForDate(DateTime date) {
    if (_selectedCategory == 'Global Liturgical' ||
        _selectedCategory == 'Philippine Proper' ||
        _selectedCategory == 'Certificate Pickups') {
      return [];
    }
    return _appointments.where((a) {
      final st = a.appointmentStatus.toLowerCase();
      if (st == 'cancelled') return false; // Strictly filtered
      return a.requestedDate.year == date.year &&
          a.requestedDate.month == date.month &&
          a.requestedDate.day == date.day;
    }).toList();
  }

  List<LiturgicalEvent> _liturgicalFeastsForDate(DateTime date) {
    final allFeasts = LiturgicalCalendarService.getCelebrationsForDateSync(date);
    if (_selectedCategory == 'Appointments' ||
        _selectedCategory == 'My Bookings' ||
        _selectedCategory == 'Certificate Pickups') {
      return [];
    }
    if (_selectedCategory == 'Global Liturgical') {
      return allFeasts.where((f) => !f.isPhilippineSpecific).toList();
    }
    if (_selectedCategory == 'Philippine Proper') {
      return allFeasts.where((f) => f.isPhilippineSpecific).toList();
    }
    return allFeasts;
  }

  List<Map<String, dynamic>> _certificatePickupsForDate(DateTime date) {
    if (!_isParishioner) return [];
    if (_selectedCategory == 'Global Liturgical' ||
        _selectedCategory == 'Philippine Proper' ||
        _selectedCategory == 'Appointments' ||
        _selectedCategory == 'My Bookings') {
      return [];
    }

    final targetDateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    return _serviceRequests.where((req) {
      final pickup = req['pickup_date']?.toString();
      final status = (req['request_status'] ?? '').toString().toLowerCase();
      return pickup != null &&
          pickup == targetDateStr &&
          (status == 'approved' || status == 'ready_for_pickup' || status == 'signature_completed');
    }).toList();
  }

  void _navigateDate(int delta) {
    setState(() {
      if (_currentView == CalendarViewMode.month) {
        _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + delta, 1);
      } else if (_currentView == CalendarViewMode.week) {
        _selectedDate = _selectedDate.add(Duration(days: delta * 7));
      } else {
        _selectedDate = _selectedDate.add(Duration(days: delta));
      }
    });

    LiturgicalCalendarService.getCalendarForYear(_selectedDate.year).then((_) {
      if (mounted) setState(() {});
    });
  }

  void _openAppointmentDetail(AppointmentModel apt) {
    if (_isParishioner) {
      showParishionerAppointmentDetailModal(
        context,
        appointment: apt,
        onStatusUpdated: _loadData,
      );
    } else {
      showAppointmentDetailModal(
        context,
        appointment: apt,
        onStatusUpdated: _loadData,
      );
    }
  }

  void _showPickupDetailsDialog(Map<String, dynamic> request) {
    final sacrament = request['sacrament_type'] ?? 'Sacrament';
    final pickupDate = request['pickup_date']?.toString() ?? 'Scheduled Date';
    final status = (request['request_status'] ?? '').toString().toLowerCase();
    final bool isReady = status == 'ready_for_pickup';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: ParishColors.cardWhite,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isReady ? ParishColors.oliveGreenSurface : ParishColors.goldLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isReady ? Icons.verified : Icons.event_available,
                color: isReady ? ParishColors.oliveGreen : ParishColors.goldAccent,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isReady ? 'Certificate Ready for Pickup!' : 'Certificate Pickup Scheduled',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your official $sacrament Certificate has been approved.',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Scheduled Pickup Date: $pickupDate',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ParishColors.oliveGreen),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ParishColors.backgroundLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ParishColors.borderGrey),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Parish Office Claiming Instructions:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '• Claim location: Parish Secretariat, St. John Paul II Parish (Brgy. Labuin, Sta. Cruz, Laguna).\n'
                        '• Office Hours: Tuesday to Sunday: 8:00 AM – 12:00 PM | 1:30 PM – 5:00 PM\n'
                        '• Monday: Closed (Clergy Rest Day)',
                    style: TextStyle(fontSize: 11.5, color: ParishColors.textMuted, height: 1.35),
                  ),
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
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  void _openBookingForDate(DateTime date, {TimeOfDay? initialTime}) {
    if (_isPastDate(date)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot book or request services for past dates.'),
          backgroundColor: ParishColors.mercyRed,
        ),
      );
      return;
    }

    // Monday Guidance: Allow sick calls & emergency confessions with confirmation
    if (date.weekday == DateTime.monday && !_isParishioner) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: ParishColors.goldAccent, size: 22),
              SizedBox(width: 8),
              Text('Monday Schedule Exception', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          content: const Text(
            'Mondays are designated Clergy Rest Days and the secretariat is closed.\n\n'
                'Emergency Sick Calls (Anointing/Viaticum), confessions, and administrative exceptions may proceed.',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: ParishColors.marianBlue,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                showScheduleAppointmentModal(
                  context,
                  initialDate: date,
                  initialTime: initialTime,
                  onAppointmentSaved: _loadData,
                );
              },
              child: const Text('Allow Exception & Plot'),
            ),
          ],
        ),
      );
      return;
    }

    if (date.weekday == DateTime.monday && _isParishioner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The Parish Office is closed on Mondays (Clergy Rest Day).'),
          backgroundColor: ParishColors.goldAccent,
        ),
      );
      return;
    }

    if (LiturgicalCalendarService.isDateBlockedSync(date)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notice: A major solemn liturgical celebration is scheduled for this day.'),
          backgroundColor: ParishColors.goldAccent,
        ),
      );
    }

    showScheduleAppointmentModal(
      context,
      initialDate: date,
      initialTime: initialTime,
      onAppointmentSaved: _loadData,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textColorDark = ParishColors.textDark;
    final textColorMuted = ParishColors.textMuted;
    final borderColor = ParishColors.borderGrey;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth >= 960;

        return Scaffold(
          backgroundColor: ParishColors.backgroundLight,
          appBar: AppBar(
            backgroundColor: ParishColors.cardWhite,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: ParishColors.marianBlueAdaptive, size: 24),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isParishioner ? 'My Parish Schedule' : 'Parish Liturgy & Booking Ledger',
                  style: TextStyle(fontSize: 17.5, fontWeight: FontWeight.bold, color: textColorDark),
                ),
                Text(
                  _isParishioner
                      ? 'Live tracking of your sacrament requests & celebrations'
                      : 'Interactive Weekly Timetable • Click any slot to plot bookings',
                  style: TextStyle(fontSize: 11.5, color: textColorMuted),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.refresh, color: ParishColors.marianBlueAdaptive, size: 20),
                onPressed: _loadData,
                tooltip: 'Synchronize Schedule',
              ),
              Padding(
                padding: const EdgeInsets.only(right: 14.0),
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    backgroundColor: ParishColors.marianBlueSurface,
                    foregroundColor: ParishColors.marianBlueAdaptive,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    setState(() => _selectedDate = DateTime.now());
                    LiturgicalCalendarService.getCalendarForYear(_selectedDate.year).then((_) {
                      if (mounted) setState(() {});
                    });
                  },
                  icon: const Icon(Icons.today, size: 16),
                  label: const Text('Today', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              if (_isLoading)
                const LinearProgressIndicator(
                  minHeight: 2.5,
                  backgroundColor: Colors.transparent,
                  color: colorAppointments,
                ),
              _buildControlHeader(isDesktop),
              _buildFilterAndLegendBar(isDesktop),
              Divider(height: 1, color: borderColor),
              if (_errorMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  color: ParishColors.mercyRedSurface,
                  child: Text(
                    'Sync Notice: $_errorMessage',
                    style: const TextStyle(fontSize: 12, color: ParishColors.mercyRed, fontWeight: FontWeight.bold),
                  ),
                ),
              Expanded(
                child: _buildCurrentCalendarView(isDesktop),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Top Control Header
  // ---------------------------------------------------------------------------
  Widget _buildControlHeader(bool isDesktop) {
    return Container(
      color: ParishColors.cardWhite,
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 20 : 14, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: ParishColors.backgroundLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ParishColors.borderGrey),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildViewTab(CalendarViewMode.week, 'Week Ledger', Icons.table_chart_outlined),
                _buildViewTab(CalendarViewMode.month, 'Month', Icons.calendar_view_month),
                _buildViewTab(CalendarViewMode.day, 'Day', Icons.calendar_view_day),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.chevron_left, size: 26, color: ParishColors.marianBlueAdaptive),
                onPressed: () => _navigateDate(-1),
                tooltip: 'Previous',
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(6),
              ),
              const SizedBox(width: 8),
              Text(
                _getDateHeaderTitle(),
                style: TextStyle(
                  fontSize: isDesktop ? 16 : 14.5,
                  fontWeight: FontWeight.bold,
                  color: ParishColors.marianBlueAdaptive,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.chevron_right, size: 26, color: ParishColors.marianBlueAdaptive),
                onPressed: () => _navigateDate(1),
                tooltip: 'Next',
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(6),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildViewTab(CalendarViewMode mode, String label, IconData icon) {
    final isSelected = _currentView == mode;
    return InkWell(
      onTap: () => setState(() => _currentView = mode),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected ? ParishColors.marianBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : ParishColors.textMuted),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : ParishColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getDateHeaderTitle() {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    if (_currentView == CalendarViewMode.month) {
      return '${months[_selectedDate.month - 1]} ${_selectedDate.year}';
    } else if (_currentView == CalendarViewMode.week) {
      final startOfWeek = _selectedDate.subtract(Duration(days: _selectedDate.weekday % 7));
      final endOfWeek = startOfWeek.add(const Duration(days: 6));
      return '${months[startOfWeek.month - 1].substring(0, 3)} ${startOfWeek.day} – ${endOfWeek.day}, ${endOfWeek.year}';
    } else {
      return '${months[_selectedDate.month - 1]} ${_selectedDate.day}, ${_selectedDate.year}';
    }
  }

  // ---------------------------------------------------------------------------
  // Filters & Legend Combined Row
  // ---------------------------------------------------------------------------
  Widget _buildFilterAndLegendBar(bool isDesktop) {
    return Container(
      color: ParishColors.cardWhite,
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 20 : 12, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _categories.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: ChoiceChip(
                      label: Text(cat),
                      selected: isSelected,
                      selectedColor: ParishColors.marianBlueSurface,
                      backgroundColor: ParishColors.backgroundLight,
                      labelStyle: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? ParishColors.marianBlueAdaptive : ParishColors.textMuted,
                      ),
                      onSelected: (_) => setState(() => _selectedCategory = cat),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (isDesktop)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildLegendPill(colorGlobalLiturgical, 'Global Feasts'),
                const SizedBox(width: 8),
                _buildLegendPill(colorPhilippineSpecific, 'Philippine Feasts'),
                const SizedBox(width: 8),
                _buildLegendPill(colorAppointments, _isParishioner ? 'My Bookings' : 'Booked Rites'),
                const SizedBox(width: 8),
                _buildLegendPill(const Color(0xFF94A3B8), 'Monday Rest'),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildLegendPill(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600)),
      ],
    );
  }

  // ===========================================================================
  // Master View Switcher
  // ===========================================================================
  Widget _buildCurrentCalendarView(bool isDesktop) {
    switch (_currentView) {
      case CalendarViewMode.week:
        return isDesktop ? _buildDesktopTimetableGrid() : _buildMobileTimetableGrid();
      case CalendarViewMode.month:
        return _buildDesktopSplitMonthView();
      case CalendarViewMode.day:
        return _buildDayView(isDesktop);
    }
  }

  // ===========================================================================
  // 1. DESKTOP TIMETABLE GRID (WEEK VIEW)
  // ===========================================================================
  Widget _buildDesktopTimetableGrid() {
    final startOfWeek = _selectedDate.subtract(Duration(days: _selectedDate.weekday % 7));
    final weekDays = List.generate(7, (i) => startOfWeek.add(Duration(days: i)));
    final dayNames = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];

    return Container(
      color: ParishColors.backgroundLight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const double timeColumnWidth = 86.0;
          final double availableWidth = constraints.maxWidth - timeColumnWidth;
          final double dayColumnWidth = (availableWidth / 7).clamp(160.0, 320.0);

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: timeColumnWidth + (dayColumnWidth * 7),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: ParishColors.cardWhite,
                      border: Border(bottom: BorderSide(color: ParishColors.borderGrey, width: 1.2)),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: timeColumnWidth,
                          height: 72,
                          child: Center(
                            child: Text(
                              'TIME / SLOT',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: ParishColors.textMuted,
                              ),
                            ),
                          ),
                        ),
                        ...List.generate(7, (index) {
                          final day = weekDays[index];
                          final isToday = day.year == _today.year && day.month == _today.month && day.day == _today.day;
                          final isMonday = day.weekday == DateTime.monday;
                          final feasts = _liturgicalFeastsForDate(day);
                          final pickups = _certificatePickupsForDate(day);

                          return Container(
                            width: dayColumnWidth,
                            height: 72,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: isToday
                                  ? ParishColors.marianBlueSurface
                                  : (isMonday ? const Color(0xFFF1F5F9) : ParishColors.cardWhite),
                              border: Border(
                                left: BorderSide(color: ParishColors.borderGrey.withOpacity(0.5)),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      dayNames[index],
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isMonday ? const Color(0xFF64748B) : ParishColors.marianBlueAdaptive,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: isToday ? ParishColors.marianBlue : Colors.transparent,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${day.day}',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.bold,
                                          color: isToday ? Colors.white : ParishColors.textDark,
                                        ),
                                      ),
                                    ),
                                    if (isMonday) ...[
                                      const Spacer(),
                                      const Text(
                                        'REST DAY',
                                        style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 3),
                                if (feasts.isNotEmpty)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: feasts.first.categorySurfaceColor,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: feasts.first.categoryBadgeColor.withOpacity(0.3)),
                                    ),
                                    child: Text(
                                      feasts.first.name,
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: feasts.first.categoryBadgeColor,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  )
                                else if (pickups.isNotEmpty)
                                  Text(
                                    '${pickups.length} Certificate Pickup',
                                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: colorCertificatePickup),
                                  )
                                else
                                  Text(
                                    isMonday ? 'Secretariat Closed' : 'Available for plotting',
                                    style: TextStyle(fontSize: 9.5, color: ParishColors.textMuted),
                                    maxLines: 1,
                                  ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: _timetableSlots.map((slot) {
                          return Container(
                            decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: ParishColors.borderGrey.withOpacity(0.4))),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: timeColumnWidth,
                                  height: 84,
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                  alignment: Alignment.topCenter,
                                  child: Column(
                                    children: [
                                      Text(
                                        slot.label,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: ParishColors.marianBlueAdaptive,
                                        ),
                                      ),
                                      if (slot.label.contains('11:00')) ...[
                                        const SizedBox(height: 2),
                                        const Text(
                                          'Baptism',
                                          style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: ParishColors.goldAccent),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),

                                ...List.generate(7, (dayIdx) {
                                  final day = weekDays[dayIdx];
                                  final isMonday = day.weekday == DateTime.monday;
                                  final isPast = _isPastDate(day);
                                  final cellAppointments = _getAppointmentsInSlot(day, slot);

                                  return Container(
                                    width: dayColumnWidth,
                                    height: 84,
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      color: isMonday ? const Color(0xFFF8FAFC) : ParishColors.cardWhite,
                                      border: Border(
                                        left: BorderSide(color: ParishColors.borderGrey.withOpacity(0.4)),
                                      ),
                                    ),
                                    child: cellAppointments.isNotEmpty
                                        ? _buildCellBookedAppointments(cellAppointments)
                                        : _buildCellEmptySlot(day, slot, isMonday, isPast),
                                  );
                                }),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // 2. MOBILE TIMETABLE VIEW
  // ===========================================================================
  Widget _buildMobileTimetableGrid() {
    final startOfWeek = _selectedDate.subtract(Duration(days: _selectedDate.weekday % 7));
    final weekDays = List.generate(7, (i) => startOfWeek.add(Duration(days: i)));
    final dayNames = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];

    final isMonday = _selectedDate.weekday == DateTime.monday;
    final isPast = _isPastDate(_selectedDate);
    final dayFeasts = _liturgicalFeastsForDate(_selectedDate);
    final dayPickups = _certificatePickupsForDate(_selectedDate);

    return Column(
      children: [
        Container(
          color: ParishColors.cardWhite,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: ParishColors.borderGrey)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (idx) {
              final day = weekDays[idx];
              final isSelected = day.day == _selectedDate.day && day.month == _selectedDate.month;
              final hasBookings = _appointmentsForDate(day).isNotEmpty;

              return InkWell(
                onTap: () => setState(() => _selectedDate = day),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? ParishColors.marianBlue : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        dayNames[idx],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : ParishColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : ParishColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: hasBookings ? colorAppointments : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),

        if (dayFeasts.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: dayFeasts.first.categorySurfaceColor,
            child: Row(
              children: [
                Icon(Icons.church, size: 16, color: dayFeasts.first.categoryBadgeColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${dayFeasts.first.name} (${dayFeasts.first.gradeName})',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: dayFeasts.first.categoryBadgeColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

        if (dayPickups.isNotEmpty) ...[
          ...dayPickups.map((p) => Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: _buildCertificatePickupCard(p),
          )),
        ],

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: _timetableSlots.length,
            itemBuilder: (context, idx) {
              final slot = _timetableSlots[idx];
              final cellAppointments = _getAppointmentsInSlot(_selectedDate, slot);

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isMonday ? const Color(0xFFF8FAFC) : ParishColors.cardWhite,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ParishColors.borderGrey.withOpacity(0.6)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 78,
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            slot.label,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: ParishColors.marianBlue),
                          ),
                          Text(
                            slot.hour >= 12 ? 'PM' : 'AM',
                            style: TextStyle(fontSize: 10, color: ParishColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: cellAppointments.isNotEmpty
                            ? _buildCellBookedAppointments(cellAppointments)
                            : _buildCellEmptySlot(_selectedDate, slot, isMonday, isPast),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  List<AppointmentModel> _getAppointmentsInSlot(DateTime date, _TimetableSlot slot) {
    final dayAppointments = _appointmentsForDate(date);

    return dayAppointments.where((a) {
      try {
        final parts = a.requestedTime.split(':');
        final aptHour = int.parse(parts[0]);
        final aptMin = int.parse(parts[1]);
        final aptTotalMin = aptHour * 60 + aptMin;

        final slotStart = slot.totalMinutes;
        final slotEnd = slotStart + 60;

        return aptTotalMin >= slotStart && aptTotalMin < slotEnd;
      } catch (_) {
        return false;
      }
    }).toList();
  }

  Widget _buildCellBookedAppointments(List<AppointmentModel> appointments) {
    return Column(
      children: appointments.map((apt) {
        final bool isOutside = apt.venue.toLowerCase().contains('outside');
        final bool isBatch = apt.serviceType.toLowerCase().contains('community baptism');
        final statusColor = AppointmentStatusColors.getStatusColor(apt.appointmentStatus);
        final statusSurface = AppointmentStatusColors.getStatusSurface(apt.appointmentStatus);

        return InkWell(
          onTap: () => _openAppointmentDetail(apt),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 2),
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: statusSurface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: statusColor.withOpacity(0.6),
                width: 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        apt.serviceType,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: isBatch ? ParishColors.marianBlue : statusColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      AppointmentService.formatTime12Hour(apt.requestedTime),
                      style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: ParishColors.marianBlue),
                    ),
                  ],
                ),
                Text(
                  apt.requesterName,
                  style: TextStyle(fontSize: 10, color: ParishColors.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  isOutside ? 'Outside' : 'Church Altar',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    color: isOutside ? const Color(0xFFD97706) : ParishColors.marianBlue,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCellEmptySlot(DateTime day, _TimetableSlot slot, bool isMonday, bool isPast) {
    if (isPast) {
      return Container(
        alignment: Alignment.center,
        child: Text('—', style: TextStyle(color: ParishColors.borderGrey, fontSize: 13)),
      );
    }

    if (isMonday) {
      return InkWell(
        onTap: () => _openBookingForDate(day, initialTime: slot.timeOfDay),
        child: Container(
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_clock, size: 14, color: const Color(0xFF94A3B8).withOpacity(0.7)),
              const Text(
                'Rest Day',
                style: TextStyle(fontSize: 8.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      onTap: () => _openBookingForDate(day, initialTime: slot.timeOfDay),
      borderRadius: BorderRadius.circular(6),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 14, color: ParishColors.marianBlue.withOpacity(0.35)),
            const SizedBox(width: 2),
            Text(
              'Open',
              style: TextStyle(fontSize: 10, color: ParishColors.marianBlue.withOpacity(0.55), fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 3. FULL DESKTOP SPLIT MONTH VIEW (100% PRESERVED)
  // ===========================================================================
  Widget _buildDesktopSplitMonthView() {
    final selectedDayEvents = _appointmentsForDate(_selectedDate);
    final selectedDayFeasts = _liturgicalFeastsForDate(_selectedDate);
    final selectedDayPickups = _certificatePickupsForDate(_selectedDate);
    final isSelectedMonday = _selectedDate.weekday == DateTime.monday;
    final isSelectedTuesday = _selectedDate.weekday == DateTime.tuesday;
    final isPast = _isPastDate(_selectedDate);
    final isBlocked = LiturgicalCalendarService.isDateBlockedSync(_selectedDate);
    final bool canSchedule = !isPast && !isBlocked;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Month Grid (58%)
          Expanded(
            flex: 58,
            child: Container(
              decoration: BoxDecoration(
                color: ParishColors.cardWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ParishColors.borderGrey),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildWeekdayHeader(),
                  _buildMonthGrid(isDesktop: true),
                ],
              ),
            ),
          ),
          const SizedBox(width: 24),

          // Right Day Details Panel (42%)
          Expanded(
            flex: 42,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ParishColors.cardWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ParishColors.borderGrey),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_getMonthName(_selectedDate.month)} ${_selectedDate.day}, ${_selectedDate.year}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: ParishColors.textDark,
                              ),
                            ),
                            Text(
                              _getDayName(_selectedDate.weekday),
                              style: TextStyle(fontSize: 12.5, color: ParishColors.textMuted),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            if (selectedDayPickups.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: colorCertificatePickup.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${selectedDayPickups.length} Pickup',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colorCertificatePickup),
                                ),
                              ),
                            ],
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: colorAppointments.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${selectedDayEvents.length} Booked',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colorAppointments),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    if (isPast) ...[
                      _buildPastDateNotice(),
                      const SizedBox(height: 12),
                    ],
                    if (isSelectedMonday) ...[
                      _buildMondayBanner(),
                      const SizedBox(height: 12),
                    ],
                    if (isSelectedTuesday && !isPast) ...[
                      _buildTuesdayBanner(),
                      const SizedBox(height: 12),
                    ],

                    if (selectedDayPickups.isNotEmpty) ...[
                      Text(
                        'Certificate Pickups for Today',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                      ),
                      const SizedBox(height: 8),
                      ...selectedDayPickups.map((req) => _buildCertificatePickupCard(req)),
                      const SizedBox(height: 14),
                    ],

                    ...selectedDayFeasts.map((f) => _buildLiturgicalEventCard(f)),

                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _isParishioner ? 'My Scheduled Appointments' : 'Pastoral Ceremonies & Appointments',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                        ),
                        if (canSchedule && selectedDayEvents.isNotEmpty)
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            ),
                            onPressed: () => _openBookingForDate(_selectedDate),
                            icon: const Icon(Icons.add, size: 15),
                            label: Text(_isParishioner ? 'Request' : 'Schedule', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (selectedDayEvents.isEmpty && selectedDayPickups.isEmpty)
                      _buildEmptyDayCard(
                        isMonday: isSelectedMonday,
                        isPast: isPast,
                        isBlocked: isBlocked,
                      )
                    else ...[
                      ...selectedDayEvents.map((a) => _buildAppointmentCard(a)),
                      if (canSchedule) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 40,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: ParishColors.marianBlue.withOpacity(0.5)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => _openBookingForDate(_selectedDate),
                            icon: const Icon(Icons.add_task, size: 16),
                            label: Text(
                              _isParishioner
                                  ? '+ Request Another Service on This Date'
                                  : '+ Schedule Another Service on This Date',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 4. MOBILE STACKED MONTH VIEW
  // ===========================================================================
  Widget _buildMobileMonthView() {
    final selectedDayEvents = _appointmentsForDate(_selectedDate);
    final selectedDayFeasts = _liturgicalFeastsForDate(_selectedDate);
    final selectedDayPickups = _certificatePickupsForDate(_selectedDate);
    final isSelectedMonday = _selectedDate.weekday == DateTime.monday;
    final isSelectedTuesday = _selectedDate.weekday == DateTime.tuesday;
    final isPast = _isPastDate(_selectedDate);
    final isBlocked = LiturgicalCalendarService.isDateBlockedSync(_selectedDate);
    final bool canSchedule = !isPast && !isBlocked;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: ParishColors.cardWhite,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ParishColors.borderGrey),
            ),
            child: Column(
              children: [
                _buildWeekdayHeader(),
                _buildMonthGrid(isDesktop: false),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (isPast) ...[
            _buildPastDateNotice(),
            const SizedBox(height: 12),
          ],
          if (isSelectedMonday) ...[
            _buildMondayBanner(),
            const SizedBox(height: 12),
          ],
          if (isSelectedTuesday && !isPast) ...[
            _buildTuesdayBanner(),
            const SizedBox(height: 12),
          ],

          if (selectedDayPickups.isNotEmpty) ...[
            Text(
              'Certificate Pickups on ${_selectedDate.month}/${_selectedDate.day}/${_selectedDate.year}',
              style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: ParishColors.textDark),
            ),
            const SizedBox(height: 8),
            ...selectedDayPickups.map((req) => _buildCertificatePickupCard(req)),
            const SizedBox(height: 14),
          ],

          ...selectedDayFeasts.map((f) => _buildLiturgicalEventCard(f)),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isParishioner
                    ? 'My Bookings (${_selectedDate.month}/${_selectedDate.day})'
                    : 'Appointments (${_selectedDate.month}/${_selectedDate.day})',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ParishColors.textDark),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colorAppointments.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${selectedDayEvents.length} Booked',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colorAppointments),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (selectedDayEvents.isEmpty && selectedDayPickups.isEmpty)
            _buildEmptyDayCard(
              isMonday: isSelectedMonday,
              isPast: isPast,
              isBlocked: isBlocked,
            )
          else ...[
            ...selectedDayEvents.map((a) => _buildAppointmentCard(a)),
            if (canSchedule) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 42,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: ParishColors.marianBlue.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _openBookingForDate(_selectedDate),
                  icon: const Icon(Icons.add_task, size: 16),
                  label: Text(
                    _isParishioner
                        ? '+ Request Another Service on This Date'
                        : '+ Schedule Another Service on This Date',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildWeekdayHeader() {
    final daysOfWeek = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: ParishColors.marianBlueSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: daysOfWeek.map((d) {
          final isMonday = d == 'Mon';
          return SizedBox(
            width: 40,
            child: Text(
              d,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
                color: isMonday ? const Color(0xFF94A3B8) : ParishColors.marianBlueAdaptive,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMonthGrid({required bool isDesktop}) {
    final firstDayOfMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final lastDayOfMonth = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
    final totalDays = lastDayOfMonth.day;
    final offset = firstDayOfMonth.weekday % 7;
    final totalGridCells = ((totalDays + offset) / 7).ceil() * 7;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: totalGridCells,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: isDesktop ? 1.25 : 0.95,
        ),
        itemBuilder: (context, index) {
          final dayNum = index - offset + 1;
          if (dayNum < 1 || dayNum > totalDays) {
            return const SizedBox.shrink();
          }

          final thisDate = DateTime(_selectedDate.year, _selectedDate.month, dayNum);
          final isMonday = thisDate.weekday == DateTime.monday;
          final isSelected = dayNum == _selectedDate.day;
          final isPast = _isPastDate(thisDate);

          final dayAppointments = _appointmentsForDate(thisDate);
          final dayFeasts = _liturgicalFeastsForDate(thisDate);
          final dayPickups = _certificatePickupsForDate(thisDate);

          final hasGlobal = dayFeasts.any((f) => !f.isPhilippineSpecific);
          final hasPh = dayFeasts.any((f) => f.isPhilippineSpecific);
          final hasAppointments = dayAppointments.isNotEmpty;
          final hasPickup = dayPickups.isNotEmpty;

          Color cellBackground = Colors.transparent;
          Color borderColor = ParishColors.borderGrey.withOpacity(0.4);

          if (isMonday) {
            cellBackground = ParishColors.backgroundLight;
          } else if (isSelected) {
            cellBackground = ParishColors.marianBlue;
            borderColor = ParishColors.marianBlue;
          }

          return InkWell(
            onTap: () => setState(() => _selectedDate = thisDate),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              decoration: BoxDecoration(
                color: cellBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? ParishColors.marianBlue : borderColor,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$dayNum',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: (isSelected || hasGlobal || hasPh || hasAppointments || hasPickup)
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected
                              ? Colors.white
                              : (isPast
                              ? ParishColors.textMuted.withOpacity(0.5)
                              : (isMonday ? const Color(0xFF94A3B8) : ParishColors.textDark)),
                        ),
                      ),
                      if (isMonday) ...[
                        const SizedBox(width: 2),
                        const Icon(Icons.lock_clock, size: 10, color: Color(0xFF94A3B8)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (hasGlobal) _buildIndicatorDot(isSelected ? Colors.white : colorGlobalLiturgical),
                      if (hasPh) _buildIndicatorDot(isSelected ? Colors.white : colorPhilippineSpecific),
                      if (hasAppointments) _buildIndicatorDot(isSelected ? Colors.white : colorAppointments),
                      if (hasPickup) _buildIndicatorDot(isSelected ? Colors.white : colorCertificatePickup),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // 5. DAY VIEW
  // ===========================================================================
  Widget _buildDayView(bool isDesktop) {
    final isMonday = _selectedDate.weekday == DateTime.monday;
    final isTuesday = _selectedDate.weekday == DateTime.tuesday;
    final isPast = _isPastDate(_selectedDate);
    final dayAppointments = _appointmentsForDate(_selectedDate);
    final dayFeasts = _liturgicalFeastsForDate(_selectedDate);
    final dayPickups = _certificatePickupsForDate(_selectedDate);
    final hours = [9, 11, 13, 15, 17];

    if (isDesktop) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_getMonthName(_selectedDate.month)} ${_selectedDate.day}, ${_selectedDate.year}',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                    ),
                    Text(
                      _getDayName(_selectedDate.weekday),
                      style: TextStyle(fontSize: 13, color: ParishColors.textMuted),
                    ),
                    const SizedBox(height: 14),

                    if (isPast) _buildPastDateNotice(),
                    if (isMonday) _buildMondayBanner(),
                    if (isTuesday && !isPast) _buildTuesdayBanner(),

                    if (dayPickups.isNotEmpty) ...[
                      Text('Certificate Pickups Scheduled Today', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
                      const SizedBox(height: 8),
                      ...dayPickups.map((p) => _buildCertificatePickupCard(p)),
                      const SizedBox(height: 14),
                    ],

                    ...dayFeasts.map((f) => _buildLiturgicalEventCard(f)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              flex: 6,
              child: ListView(
                children: hours.map((hour) => _buildHourSlot(hour, dayAppointments, isMonday, isPast)).toList(),
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (isPast) _buildPastDateNotice(),
        if (isMonday) _buildMondayBanner(),
        if (isTuesday && !isPast) _buildTuesdayBanner(),
        if (dayPickups.isNotEmpty) ...[
          Text('Certificate Pickups Scheduled Today', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
          const SizedBox(height: 8),
          ...dayPickups.map((p) => _buildCertificatePickupCard(p)),
          const SizedBox(height: 14),
        ],
        ...dayFeasts.map((f) => _buildLiturgicalEventCard(f)),
        const SizedBox(height: 10),
        ...hours.map((hour) => _buildHourSlot(hour, dayAppointments, isMonday, isPast)),
      ],
    );
  }

  Widget _buildHourSlot(int hour, List<AppointmentModel> dayAppointments, bool isMonday, bool isPast) {
    final timeLabel = hour < 12
        ? '${hour.toString().padLeft(2, '0')}:00 AM'
        : (hour == 12 ? '12:00 PM' : '${(hour - 12).toString().padLeft(2, '0')}:00 PM');

    final slotAppointments = dayAppointments.where((a) {
      try {
        final startH = int.parse(a.requestedTime.split(':')[0]);
        return startH >= hour && startH < hour + 2;
      } catch (_) {
        return false;
      }
    }).toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Padding(
            padding: const EdgeInsets.only(top: 14.0),
            child: Text(
              timeLabel,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ParishColors.textMuted),
            ),
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (isMonday || isPast) ? const Color(0xFFF8FAFC) : ParishColors.cardWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: (isMonday || isPast) ? const Color(0xFFE2E8F0) : ParishColors.borderGrey),
            ),
            child: slotAppointments.isEmpty
                ? InkWell(
              onTap: isPast ? null : () => _openBookingForDate(_selectedDate),
              child: Row(
                children: [
                  Icon(
                    isMonday ? Icons.lock_clock : (isPast ? Icons.block : Icons.add_circle_outline),
                    size: 16,
                    color: isPast ? const Color(0xFF94A3B8) : colorAppointments,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isPast
                        ? 'Past Slot (Archived)'
                        : (isMonday ? 'Monday (Tap to allow exception)' : 'Available (Tap to book)'),
                    style: TextStyle(
                      fontSize: 12,
                      color: isPast ? const Color(0xFF94A3B8) : ParishColors.textMuted,
                    ),
                  ),
                ],
              ),
            )
                : Column(
              children: slotAppointments.map((a) => _buildAppointmentCard(a)).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCertificatePickupCard(Map<String, dynamic> req) {
    final sacrament = req['sacrament_type'] ?? 'Sacrament';
    final status = (req['request_status'] ?? '').toString().toLowerCase();
    final bool isReady = status == 'ready_for_pickup';

    return InkWell(
      onTap: () => _showPickupDetailsDialog(req),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isReady ? ParishColors.oliveGreenSurface : ParishColors.goldLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isReady ? ParishColors.oliveGreen : ParishColors.goldAccent,
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isReady ? ParishColors.oliveGreen : ParishColors.goldAccent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isReady ? Icons.verified : Icons.event_available,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isReady ? 'Certificate Ready for Pickup!' : 'Certificate Pickup Scheduled',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isReady ? ParishColors.oliveGreen : ParishColors.goldAccent,
                    ),
                  ),
                  Text(
                    '$sacrament Certificate • Claim at Parish Secretariat Office',
                    style: TextStyle(fontSize: 11, color: ParishColors.textDark),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 12, color: ParishColors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildPastDateNotice() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: const Row(
        children: [
          Icon(Icons.history, color: Color(0xFF64748B), size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Past Date (Historical Ledger)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF334155)),
                ),
                Text(
                  'This date has passed. Bookings are only accepted for today and future calendar dates.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMondayBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF94A3B8)),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_clock, color: Color(0xFF64748B), size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Monday Pastoral Rest Day (Office Closed)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155)),
                ),
                SizedBox(height: 2),
                Text(
                  'Parish secretariat is closed. Emergency Sick Calls (Viaticum) and Confessions may proceed by exception.',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTuesdayBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ParishColors.goldLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ParishColors.goldAccent),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: ParishColors.goldAccent, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tuesday Parish Priest Approval Required',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ParishColors.goldAccent),
                ),
                const SizedBox(height: 2),
                Text(
                  'Appointments booked on Tuesdays are recorded as PENDING until approved by Rev. Fr. Roy.',
                  style: TextStyle(fontSize: 11.5, color: ParishColors.textDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiturgicalEventCard(LiturgicalEvent event) {
    final Color badgeColor = event.isPhilippineSpecific ? colorPhilippineSpecific : colorGlobalLiturgical;
    final Color surfaceColor = event.isPhilippineSpecific ? const Color(0xFFEFF6FF) : const Color(0xFFFEF2F2);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withOpacity(0.4), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.church, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      event.isPhilippineSpecific ? 'PHILIPPINE PROPER' : 'GLOBAL LITURGICAL',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: badgeColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (event.blocksAppointments)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorGlobalLiturgical,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'RESTRICTED',
                          style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  event.name,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                ),
                Text(
                  'Grade: ${event.gradeName}',
                  style: TextStyle(fontSize: 11.5, color: ParishColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentCard(AppointmentModel apt) {
    return InkWell(
      onTap: () => _openAppointmentDetail(apt),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ParishColors.cardWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorAppointments.withOpacity(0.5), width: 1.2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: 54,
              decoration: BoxDecoration(
                color: colorAppointments,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorAppointments.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          apt.appointmentStatus.toUpperCase(),
                          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: colorAppointments),
                        ),
                      ),
                      Text(
                        AppointmentService.formatTime12Hour(apt.requestedTime),
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: ParishColors.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    apt.serviceType,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                  ),
                  Text(
                    'Requester: ${apt.requesterName} (${apt.contactNumber})',
                    style: TextStyle(fontSize: 12, color: ParishColors.textMuted),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 13, color: ParishColors.textMuted),
                      const SizedBox(width: 4),
                      Text(apt.venue, style: TextStyle(fontSize: 11.5, color: ParishColors.textMuted)),
                      const SizedBox(width: 10),
                      Icon(Icons.person_outline, size: 13, color: ParishColors.textMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          apt.officiantName,
                          style: TextStyle(fontSize: 11.5, color: ParishColors.textMuted),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyDayCard({
    bool isMonday = false,
    bool isPast = false,
    bool isBlocked = false,
  }) {
    IconData icon = Icons.event_available;
    String title = _isParishioner ? 'No Personal Bookings' : 'No Appointments Booked';
    String message = 'This day is open for bookings.';

    if (isPast) {
      icon = Icons.history;
      title = 'Past Date (Archived)';
      message = 'This date has passed. Bookings are only accepted for today and future calendar dates.';
    } else if (isMonday) {
      icon = Icons.lock_clock;
      title = 'Pastoral Rest Day';
      message = 'The Parish Office is closed on Mondays for Clergy Rest (Exceptions permitted).';
    } else if (isBlocked) {
      icon = Icons.church;
      title = 'Liturgical Solemnity';
      message = 'Pastoral bookings are restricted today due to a major Catholic solemnity.';
    }

    final bool canBook = !isPast && !isBlocked;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: (isMonday || isPast) ? const Color(0xFFF1F5F9) : ParishColors.backgroundLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: (isMonday || isPast) ? const Color(0xFFCBD5E1) : ParishColors.borderGrey),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 36,
            color: (isMonday || isPast) ? const Color(0xFF64748B) : ParishColors.marianBlueAdaptive,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: ParishColors.textMuted),
          ),
          if (canBook) ...[
            const SizedBox(height: 14),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: ParishColors.marianBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: () => _openBookingForDate(_selectedDate),
              icon: const Icon(Icons.add, size: 16),
              label: Text(_isParishioner ? 'Request This Date' : 'Book This Day'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIndicatorDot(Color color) {
    return Container(
      width: 4.5,
      height: 4.5,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  String _getDayName(int weekday) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[weekday - 1];
  }
}