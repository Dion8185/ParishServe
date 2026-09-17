import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../appointments/models/appointment_model.dart';
import '../../../appointments/models/liturgical_event_model.dart';
import '../../../appointments/presentation/dialogs/appointment_detail_dialog.dart';
import '../../../appointments/presentation/dialogs/schedule_appointment_dialog.dart';
import '../../../appointments/services/appointment_service.dart';
import '../../../appointments/services/liturgical_calendar_service.dart';

enum CalendarViewMode { month, week, day }

class ParishCalendarPage extends StatefulWidget {
  const ParishCalendarPage({super.key});

  @override
  State<ParishCalendarPage> createState() => _ParishCalendarPageState();
}

class _ParishCalendarPageState extends State<ParishCalendarPage> {
  CalendarViewMode _currentView = CalendarViewMode.month;
  DateTime _selectedDate = DateTime.now();
  String _selectedCategory = 'All';

  List<AppointmentModel> _appointments = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Strict Color-Code Scheme
  static const Color colorGlobalLiturgical = Color(0xFFDC2626);   // RED: Universal Roman Rite
  static const Color colorPhilippineSpecific = Color(0xFF2563EB); // BLUE: Philippine Proper Feasts
  static const Color colorAppointments = Color(0xFFF59E0B);       // YELLOW / AMBER: Appointments

  final List<String> _categories = [
    'All',
    'Global Liturgical',
    'Philippine Proper',
    'Appointments',
  ];

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
      // Concurrently query database appointments and liturgical calendar cache
      final appointmentsData = await AppointmentService.getAppointments();
      await LiturgicalCalendarService.getCalendarForYear(_selectedDate.year);

      if (!mounted) return;
      setState(() {
        _appointments = appointmentsData;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<AppointmentModel> _appointmentsForDate(DateTime date) {
    if (_selectedCategory == 'Global Liturgical' || _selectedCategory == 'Philippine Proper') {
      return [];
    }
    return _appointments.where((a) {
      return a.requestedDate.year == date.year &&
          a.requestedDate.month == date.month &&
          a.requestedDate.day == date.day;
    }).toList();
  }

  List<LiturgicalEvent> _liturgicalFeastsForDate(DateTime date) {
    final allFeasts = LiturgicalCalendarService.getCelebrationsForDateSync(date);
    if (_selectedCategory == 'Appointments') {
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

  @override
  Widget build(BuildContext context) {
    final textColorDark = ParishColors.textDark;
    final textColorMuted = ParishColors.textMuted;
    final borderColor = ParishColors.borderGrey;

    return Scaffold(
      backgroundColor: ParishColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: ParishColors.cardWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: ParishColors.marianBlue, size: 26),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Parish Master Calendar',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColorDark),
            ),
            Text(
              'Diocese of San Pablo • Liturgical & Appointment Engine',
              style: TextStyle(fontSize: 12, color: textColorMuted),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: ParishColors.marianBlue),
            onPressed: _loadData,
            tooltip: 'Sync Liturgy & Appointments',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: TextButton.icon(
              style: TextButton.styleFrom(
                backgroundColor: ParishColors.marianBlueSurface,
                foregroundColor: ParishColors.marianBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                setState(() => _selectedDate = DateTime.now());
                LiturgicalCalendarService.getCalendarForYear(_selectedDate.year).then((_) {
                  if (mounted) setState(() {});
                });
              },
              icon: const Icon(Icons.today, size: 18),
              label: const Text('Today', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading)
            const LinearProgressIndicator(
              minHeight: 3,
              backgroundColor: Colors.transparent,
              color: colorAppointments,
            ),
          _buildControlHeader(),
          _buildColorLegendBar(),
          _buildCategoryFilterRow(),
          Divider(height: 1, color: borderColor),
          if (_errorMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: ParishColors.mercyRedSurface,
              child: Text(
                'Supabase Sync Error: $_errorMessage',
                style: const TextStyle(fontSize: 12, color: ParishColors.mercyRed, fontWeight: FontWeight.bold),
              ),
            ),
          Expanded(
            child: _buildCurrentCalendarView(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: ParishColors.marianBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Schedule Service', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => showScheduleAppointmentModal(
          context,
          initialDate: _selectedDate.weekday == DateTime.monday ? null : _selectedDate,
          onAppointmentSaved: _loadData,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Top Control Header: Month / Week / Day Switcher & Month Navigation
  // ---------------------------------------------------------------------------
  Widget _buildControlHeader() {
    return Container(
      color: ParishColors.cardWhite,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        children: [
          Container(
            height: 42,
            decoration: BoxDecoration(
              color: ParishColors.backgroundLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ParishColors.borderGrey),
            ),
            child: Row(
              children: [
                _buildViewTab(CalendarViewMode.month, 'Month View', Icons.calendar_view_month),
                _buildViewTab(CalendarViewMode.week, 'Week View', Icons.calendar_view_week),
                _buildViewTab(CalendarViewMode.day, 'Day View', Icons.calendar_view_day),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 28, color: ParishColors.marianBlue),
                onPressed: () => _navigateDate(-1),
              ),
              Text(
                _getDateHeaderTitle(),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: ParishColors.marianBlue),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 28, color: ParishColors.marianBlue),
                onPressed: () => _navigateDate(1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildViewTab(CalendarViewMode mode, String label, IconData icon) {
    final isSelected = _currentView == mode;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentView = mode),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isSelected ? ParishColors.marianBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: isSelected ? Colors.white : ParishColors.textMuted),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : ParishColors.textMuted,
                ),
              ),
            ],
          ),
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
  // Color-Coding Legend Bar (Red = Global, Blue = PH, Yellow = Appointments, Gray = Monday)
  // ---------------------------------------------------------------------------
  Widget _buildColorLegendBar() {
    return Container(
      color: ParishColors.cardWhite,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildLegendItem(colorGlobalLiturgical, 'Global / Universal'),
            const SizedBox(width: 12),
            _buildLegendItem(colorPhilippineSpecific, 'Philippine Proper'),
            const SizedBox(width: 12),
            _buildLegendItem(colorAppointments, 'Appointments'),
            const SizedBox(width: 12),
            _buildLegendItem(const Color(0xFF94A3B8), 'Monday Rest Day', isGray: true),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label, {bool isGray = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isGray ? ParishColors.textMuted : ParishColors.textDark,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryFilterRow() {
    return Container(
      color: ParishColors.cardWhite,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _categories.map((cat) {
            final isSelected = _selectedCategory == cat;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FilterChip(
                label: Text(cat),
                selected: isSelected,
                selectedColor: ParishColors.marianBlueSurface,
                backgroundColor: ParishColors.backgroundLight,
                checkmarkColor: ParishColors.marianBlue,
                labelStyle: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? ParishColors.marianBlue : ParishColors.textMuted,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isSelected ? ParishColors.marianBlue : ParishColors.borderGrey,
                  ),
                ),
                onSelected: (_) => setState(() => _selectedCategory = cat),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCurrentCalendarView() {
    switch (_currentView) {
      case CalendarViewMode.month:
        return _buildMonthView();
      case CalendarViewMode.week:
        return _buildWeekView();
      case CalendarViewMode.day:
        return _buildDayView();
    }
  }

  // ===========================================================================
  // 1. MONTH VIEW (With Monday Graying & Strict Red/Blue/Yellow Color Dots)
  // ===========================================================================
  Widget _buildMonthView() {
    final daysOfWeek = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final selectedDayEvents = _appointmentsForDate(_selectedDate);
    final selectedDayFeasts = _liturgicalFeastsForDate(_selectedDate);

    final firstDayOfMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final lastDayOfMonth = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
    final totalDays = lastDayOfMonth.day;
    final offset = firstDayOfMonth.weekday % 7;
    final totalGridCells = ((totalDays + offset) / 7).ceil() * 7;

    final isSelectedMonday = _selectedDate.weekday == DateTime.monday;
    final isSelectedTuesday = _selectedDate.weekday == DateTime.tuesday;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Weekday header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: ParishColors.cardWhite,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              border: Border.all(color: ParishColors.borderGrey),
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
                      color: isMonday ? const Color(0xFF94A3B8) : ParishColors.marianBlue,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Monthly Grid
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: ParishColors.cardWhite,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
              border: Border(
                left: BorderSide(color: ParishColors.borderGrey),
                right: BorderSide(color: ParishColors.borderGrey),
                bottom: BorderSide(color: ParishColors.borderGrey),
              ),
            ),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: totalGridCells,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 0.95,
              ),
              itemBuilder: (context, index) {
                final dayNum = index - offset + 1;
                if (dayNum < 1 || dayNum > totalDays) {
                  return const SizedBox.shrink();
                }

                final thisDate = DateTime(_selectedDate.year, _selectedDate.month, dayNum);
                final isMonday = thisDate.weekday == DateTime.monday;
                final isSelected = dayNum == _selectedDate.day;

                final dayAppointments = _appointmentsForDate(thisDate);
                final dayFeasts = _liturgicalFeastsForDate(thisDate);

                final hasGlobal = dayFeasts.any((f) => !f.isPhilippineSpecific);
                final hasPh = dayFeasts.any((f) => f.isPhilippineSpecific);
                final hasAppointments = dayAppointments.isNotEmpty;

                Color cellBackground = Colors.transparent;
                Color borderColor = ParishColors.borderGrey.withValues(alpha: 0.4);

                if (isMonday) {
                  cellBackground = const Color(0xFFF1F5F9); // Grayed out for Pastoral Rest Day
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
                                fontWeight: (isSelected || hasGlobal || hasPh || hasAppointments)
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? Colors.white
                                    : (isMonday ? const Color(0xFF94A3B8) : ParishColors.textDark),
                              ),
                            ),
                            if (isMonday) ...[
                              const SizedBox(width: 2),
                              const Icon(Icons.lock_clock, size: 10, color: Color(0xFF94A3B8)),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        // Indicator Dots: Red (Global), Blue (PH), Yellow (Appointments)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (hasGlobal)
                              _buildIndicatorDot(isSelected ? Colors.white : colorGlobalLiturgical),
                            if (hasPh)
                              _buildIndicatorDot(isSelected ? Colors.white : colorPhilippineSpecific),
                            if (hasAppointments)
                              _buildIndicatorDot(isSelected ? Colors.white : colorAppointments),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // MONDAY REST DAY BANNER
          if (isSelectedMonday) ...[
            Container(
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
                          'Parish secretariat is closed and routine appointments cannot be scheduled on Mondays.',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // TUESDAY PASTORAL APPROVAL NOTICE BANNER
          if (isSelectedTuesday) ...[
            Container(
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
                          'Appointments booked on Tuesdays are recorded as PENDING until approved by the Parish Priest.',
                          style: TextStyle(fontSize: 11.5, color: ParishColors.textDark),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Feast Observance Banners (Red = Global, Blue = PH)
          ...selectedDayFeasts.map((f) => _buildLiturgicalEventCard(f)),

          // Appointments Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Appointments on ${_selectedDate.month}/${_selectedDate.day}/${_selectedDate.year}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ParishColors.textDark),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colorAppointments.withValues(alpha: 0.15),
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

          if (selectedDayEvents.isEmpty)
            _buildEmptyDayCard(isMonday: isSelectedMonday)
          else
            ...selectedDayEvents.map((a) => _buildAppointmentCard(a)),
        ],
      ),
    );
  }

  Widget _buildIndicatorDot(Color color) {
    return Container(
      width: 4.5,
      height: 4.5,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Liturgical Event Card (Red for Global, Blue for Philippine-Specific)
  // ---------------------------------------------------------------------------
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
        border: Border.all(color: badgeColor.withValues(alpha: 0.4), width: 1.5),
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
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: ParishColors.textDark,
                  ),
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

  // ---------------------------------------------------------------------------
  // Appointment Card: Yellow / Amber Theme
  // ---------------------------------------------------------------------------
  Widget _buildAppointmentCard(AppointmentModel apt) {
    return InkWell(
      onTap: () => showAppointmentDetailModal(
        context,
        appointment: apt,
        onStatusUpdated: _loadData,
      ),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ParishColors.cardWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorAppointments.withValues(alpha: 0.5), width: 1.2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 5,
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
                          color: colorAppointments.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          apt.appointmentStatus.toUpperCase(),
                          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: colorAppointments),
                        ),
                      ),
                      Text(
                        apt.formattedTimeRange,
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: ParishColors.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    apt.serviceType,
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: ParishColors.textDark),
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

  // ===========================================================================
  // 2. WEEK VIEW (Monday Grayed Out, Feasts & Appointments Strips)
  // ===========================================================================
  Widget _buildWeekView() {
    final startOfWeek = _selectedDate.subtract(Duration(days: _selectedDate.weekday % 7));
    final weekDays = List.generate(7, (i) => startOfWeek.add(Duration(days: i)));
    final dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 7,
      itemBuilder: (context, index) {
        final day = weekDays[index];
        final isMonday = day.weekday == DateTime.monday;
        final isSelected = day.day == _selectedDate.day && day.month == _selectedDate.month;

        final dayAppointments = _appointmentsForDate(day);
        final dayFeasts = _liturgicalFeastsForDate(day);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isMonday ? const Color(0xFFF8FAFC) : ParishColors.cardWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? ParishColors.marianBlue : (isMonday ? const Color(0xFFCBD5E1) : ParishColors.borderGrey),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isMonday ? const Color(0xFFF1F5F9) : ParishColors.marianBlueSurface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          dayNames[index],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isMonday ? const Color(0xFF64748B) : ParishColors.marianBlue,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${day.month}/${day.day}',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                        ),
                        if (isMonday) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF64748B),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'CLERGY REST DAY',
                              style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text('${dayAppointments.length} bookings', style: TextStyle(fontSize: 11.5, color: ParishColors.textMuted)),
                  ],
                ),
              ),

              // Feasts
              ...dayFeasts.map((f) => Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: f.isPhilippineSpecific ? colorPhilippineSpecific : colorGlobalLiturgical,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        f.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: f.isPhilippineSpecific ? colorPhilippineSpecific : colorGlobalLiturgical,
                        ),
                      ),
                    ),
                  ],
                ),
              )),

              // Appointments
              if (dayAppointments.isEmpty && dayFeasts.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    isMonday ? 'Closed for Pastoral Rest Day.' : 'No events scheduled.',
                    style: TextStyle(fontSize: 12, color: ParishColors.textMuted),
                  ),
                )
              else
                ...dayAppointments.map((a) => Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                  child: _buildAppointmentCard(a),
                )),
            ],
          ),
        );
      },
    );
  }

  // ===========================================================================
  // 3. DAY VIEW (Hourly Timeline & Clear Day Restrictions)
  // ===========================================================================
  Widget _buildDayView() {
    final isMonday = _selectedDate.weekday == DateTime.monday;
    final isTuesday = _selectedDate.weekday == DateTime.tuesday;
    final dayAppointments = _appointmentsForDate(_selectedDate);
    final dayFeasts = _liturgicalFeastsForDate(_selectedDate);
    final hours = [6, 8, 10, 12, 14, 16, 18];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (isMonday) ...[
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF94A3B8)),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock, color: Color(0xFF64748B)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Monday Pastoral Rest Day: Services and appointments are locked.',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (isTuesday) ...[
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: ParishColors.goldLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ParishColors.goldAccent),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: ParishColors.goldAccent),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tuesday Notice: Requires Parish Priest approval before confirmation.',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: ParishColors.goldAccent),
                  ),
                ),
              ],
            ),
          ),
        ],

        ...dayFeasts.map((f) => _buildLiturgicalEventCard(f)),
        const SizedBox(height: 10),

        ...hours.map((hour) {
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
                    color: isMonday ? const Color(0xFFF8FAFC) : ParishColors.cardWhite,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isMonday ? const Color(0xFFE2E8F0) : ParishColors.borderGrey),
                  ),
                  child: slotAppointments.isEmpty
                      ? InkWell(
                    onTap: isMonday
                        ? null
                        : () => showScheduleAppointmentModal(
                      context,
                      initialDate: _selectedDate,
                      onAppointmentSaved: _loadData,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isMonday ? Icons.block : Icons.add_circle_outline,
                          size: 16,
                          color: isMonday ? const Color(0xFF94A3B8) : colorAppointments,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isMonday ? 'Monday Locked' : 'Available (Tap to book)',
                          style: TextStyle(
                            fontSize: 12,
                            color: isMonday ? const Color(0xFF94A3B8) : ParishColors.textMuted,
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
        }),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Empty Day Card with Date-Aware "Book This Day"
  // ---------------------------------------------------------------------------
  Widget _buildEmptyDayCard({bool isMonday = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isMonday ? const Color(0xFFF1F5F9) : ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isMonday ? const Color(0xFFCBD5E1) : ParishColors.borderGrey),
      ),
      child: Column(
        children: [
          Icon(
            isMonday ? Icons.lock_clock : Icons.event_available,
            size: 38,
            color: isMonday ? const Color(0xFF64748B) : ParishColors.marianBlue,
          ),
          const SizedBox(height: 8),
          Text(
            isMonday ? 'Pastoral Rest Day' : 'No Appointments Booked',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            isMonday
                ? 'The Parish Office is closed on Mondays.'
                : 'This time slot is open for new pastoral duties or liturgies.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: ParishColors.textMuted),
          ),
          if (!isMonday) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: ParishColors.marianBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => showScheduleAppointmentModal(
                context,
                initialDate: _selectedDate, // Defaults to currently selected calendar date
                onAppointmentSaved: _loadData,
              ),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Book This Day'),
            ),
          ],
        ],
      ),
    );
  }
}