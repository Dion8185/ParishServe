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

  final List<String> _categories = [
    'All',
    'Sacraments',
    'Mass Intentions',
    'Pastoral Care',
    'Diocesan / Admin',
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
      // Concurrently load database appointments and the Philippine Liturgical Calendar
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

  String _getCategoryForService(String serviceType) {
    final s = serviceType.toLowerCase();
    if (s.contains('mass intention') || s.contains('thanksgiving') || s.contains('dawn mass')) {
      return 'Mass Intentions';
    } else if (s.contains('sick call') ||
        s.contains('anointing') ||
        s.contains('viaticum') ||
        s.contains('blessing') ||
        s.contains('confession') ||
        s.contains('counseling')) {
      return 'Pastoral Care';
    } else if (s.contains('diocesan') ||
        s.contains('admin') ||
        s.contains('meeting') ||
        s.contains('inspection') ||
        s.contains('audit')) {
      return 'Diocesan / Admin';
    } else {
      return 'Sacraments';
    }
  }

  Color _getColorForCategory(String category) {
    switch (category) {
      case 'Mass Intentions':
        return ParishColors.goldAccent;
      case 'Pastoral Care':
        return ParishColors.oliveGreen;
      case 'Diocesan / Admin':
        return ParishColors.mercyRed;
      case 'Sacraments':
      default:
        return ParishColors.marianBlue;
    }
  }

  List<AppointmentModel> get _filteredAppointments {
    return _appointments.where((a) {
      if (_selectedCategory == 'All') return true;
      return _getCategoryForService(a.serviceType) == _selectedCategory;
    }).toList();
  }

  List<AppointmentModel> _eventsForDate(DateTime date) {
    return _filteredAppointments.where((a) {
      return a.requestedDate.year == date.year &&
          a.requestedDate.month == date.month &&
          a.requestedDate.day == date.day;
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
    // Ensure liturgical cache is ready for the new target year
    LiturgicalCalendarService.getCalendarForYear(_selectedDate.year);
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
              'Catholic Liturgical & Parish Schedule (Philippines)',
              style: TextStyle(fontSize: 12, color: textColorMuted),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: ParishColors.marianBlue),
            onPressed: _loadData,
            tooltip: 'Sync Calendar & Liturgy',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: TextButton.icon(
              style: TextButton.styleFrom(
                backgroundColor: ParishColors.marianBlueSurface,
                foregroundColor: ParishColors.marianBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => setState(() => _selectedDate = DateTime.now()),
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
              color: ParishColors.goldAccent,
            ),
          _buildControlHeader(),
          _buildCategoryFilterRow(),
          Divider(height: 1, color: borderColor),
          if (_errorMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: ParishColors.mercyRedSurface,
              child: Text(
                'Database Sync Error: $_errorMessage',
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
        onPressed: () => showScheduleAppointmentModal(context, onAppointmentSaved: _loadData),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Top Navigation Controls: Month / Week / Day Toggle & Date Stepper
  // ---------------------------------------------------------------------------
  Widget _buildControlHeader() {
    final cardWhiteColor = ParishColors.cardWhite;
    final backgroundLightColor = ParishColors.backgroundLight;
    final borderGreyColor = ParishColors.borderGrey;

    return Container(
      color: cardWhiteColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: backgroundLightColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderGreyColor),
            ),
            child: Row(
              children: [
                _buildViewTab(CalendarViewMode.month, 'Month View', Icons.calendar_view_month),
                _buildViewTab(CalendarViewMode.week, 'Week View', Icons.calendar_view_week),
                _buildViewTab(CalendarViewMode.day, 'Day View', Icons.calendar_view_day),
              ],
            ),
          ),
          const SizedBox(height: 12),
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
    final textMutedColor = ParishColors.textMuted;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentView = mode),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isSelected ? ParishColors.marianBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? Colors.white : textMutedColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : textMutedColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getDateHeaderTitle() {
    final months = [
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

  Widget _buildCategoryFilterRow() {
    final cardWhiteColor = ParishColors.cardWhite;
    final goldLightColor = ParishColors.goldLight;
    final backgroundLightColor = ParishColors.backgroundLight;
    final textMutedColor = ParishColors.textMuted;
    final borderGreyColor = ParishColors.borderGrey;

    return Container(
      color: cardWhiteColor,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
                selectedColor: goldLightColor,
                backgroundColor: backgroundLightColor,
                checkmarkColor: ParishColors.goldAccent,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? ParishColors.goldAccent : textMutedColor,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected ? ParishColors.goldAccent : borderGreyColor,
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
  // 1. MONTH VIEW (Dynamic Days + Liturgical Feast Indicators)
  // ===========================================================================
  Widget _buildMonthView() {
    final daysOfWeek = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final selectedDayEvents = _eventsForDate(_selectedDate);
    final cardWhiteColor = ParishColors.cardWhite;
    final borderGreyColor = ParishColors.borderGrey;
    final goldLightColor = ParishColors.goldLight;
    final textDarkColor = ParishColors.textDark;
    final textMutedColor = ParishColors.textMuted;
    final marianBlueSurfaceColor = ParishColors.marianBlueSurface;

    final firstDayOfMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final lastDayOfMonth = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
    final totalDays = lastDayOfMonth.day;
    final offset = firstDayOfMonth.weekday % 7;
    final totalGridCells = ((totalDays + offset) / 7).ceil() * 7;

    final isSelectedDateBlocked = LiturgicalCalendarService.isDateBlockedSync(_selectedDate);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: cardWhiteColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              border: Border.all(color: borderGreyColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: daysOfWeek.map((d) {
                final isSunday = d == 'Sun';
                return SizedBox(
                  width: 40,
                  child: Text(
                    d,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isSunday ? ParishColors.mercyRed : ParishColors.marianBlue,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cardWhiteColor,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
              border: Border(
                left: BorderSide(color: borderGreyColor),
                right: BorderSide(color: borderGreyColor),
                bottom: BorderSide(color: borderGreyColor),
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
                final dayEvents = _eventsForDate(thisDate);
                final liturgicalFeasts = LiturgicalCalendarService.getCelebrationsForDateSync(thisDate);
                final isSelected = dayNum == _selectedDate.day;
                final hasEvents = dayEvents.isNotEmpty;
                final hasLiturgicalFeast = liturgicalFeasts.isNotEmpty;

                return InkWell(
                  onTap: () => setState(() => _selectedDate = thisDate),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? ParishColors.marianBlue
                          : (hasLiturgicalFeast
                          ? liturgicalFeasts.first.liturgicalColor.withValues(alpha: 0.15)
                          : (hasEvents ? goldLightColor : Colors.transparent)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? ParishColors.marianBlue
                            : (hasLiturgicalFeast
                            ? liturgicalFeasts.first.liturgicalColor
                            : (hasEvents ? ParishColors.goldAccent : borderGreyColor.withValues(alpha: 0.4))),
                        width: isSelected || hasLiturgicalFeast ? 1.8 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$dayNum',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: (hasEvents || isSelected || hasLiturgicalFeast) ? FontWeight.bold : FontWeight.normal,
                            color: isSelected
                                ? Colors.white
                                : (hasLiturgicalFeast ? textDarkColor : (hasEvents ? textDarkColor : textMutedColor)),
                          ),
                        ),
                        if (hasLiturgicalFeast || hasEvents) ...[
                          const SizedBox(height: 3),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Liturgical Feast indicator dot
                              if (hasLiturgicalFeast)
                                Container(
                                  width: 5,
                                  height: 5,
                                  margin: const EdgeInsets.symmetric(horizontal: 1),
                                  decoration: BoxDecoration(
                                    color: isSelected ? Colors.white : liturgicalFeasts.first.liturgicalColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              // Appointment dots
                              ...dayEvents.take(2).map((apt) {
                                final cat = _getCategoryForService(apt.serviceType);
                                final color = _getColorForCategory(cat);
                                return Container(
                                  width: 5,
                                  height: 5,
                                  margin: const EdgeInsets.symmetric(horizontal: 1),
                                  decoration: BoxDecoration(
                                    color: isSelected ? Colors.white : color,
                                    shape: BoxShape.circle,
                                  ),
                                );
                              }),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          // Catholic Liturgical Observance Banner for Selected Day
          _buildLiturgicalBannerForDate(_selectedDate),

          // Events on the Selected Day
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Services on ${_selectedDate.month}/${_selectedDate.day}/${_selectedDate.year}',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textDarkColor),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: marianBlueSurfaceColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${selectedDayEvents.length} Scheduled',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ParishColors.marianBlue),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (selectedDayEvents.isEmpty)
            _buildEmptyDayCard(isBlocked: isSelectedDateBlocked)
          else
            ...selectedDayEvents.map((e) => _buildEventCard(e)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Liturgical Banner Widget
  // ---------------------------------------------------------------------------
  Widget _buildLiturgicalBannerForDate(DateTime date) {
    final celebrations = LiturgicalCalendarService.getCelebrationsForDateSync(date);
    if (celebrations.isEmpty) return const SizedBox.shrink();

    return Column(
      children: celebrations.map((feast) {
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: feast.liturgicalColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: feast.liturgicalColor, width: 1.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: feast.liturgicalColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.church, color: Colors.white, size: 20),
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
                          feast.gradeName.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: feast.liturgicalColor,
                          ),
                        ),
                        if (feast.blocksAppointments)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: ParishColors.mercyRed,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'APPOINTMENTS RESTRICTED',
                              style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      feast.name,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: ParishColors.textDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ===========================================================================
  // 2. WEEK VIEW (Day Strips with Liturgical Feasts & Live Bookings)
  // ===========================================================================
  Widget _buildWeekView() {
    final startOfWeek = _selectedDate.subtract(Duration(days: _selectedDate.weekday % 7));
    final weekDays = List.generate(7, (i) => startOfWeek.add(Duration(days: i)));
    final cardWhiteColor = ParishColors.cardWhite;
    final borderGreyColor = ParishColors.borderGrey;
    final marianBlueSurfaceColor = ParishColors.marianBlueSurface;
    final backgroundLightColor = ParishColors.backgroundLight;
    final textDarkColor = ParishColors.textDark;
    final textMutedColor = ParishColors.textMuted;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 7,
      itemBuilder: (context, index) {
        final day = weekDays[index];
        final dayEvents = _eventsForDate(day);
        final liturgicalFeasts = LiturgicalCalendarService.getCelebrationsForDateSync(day);
        final dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
        final isSelected = day.day == _selectedDate.day && day.month == _selectedDate.month;

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: cardWhiteColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? ParishColors.marianBlue : borderGreyColor,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? marianBlueSurfaceColor : backgroundLightColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
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
                            fontSize: 14,
                            color: index == 0 ? ParishColors.mercyRed : ParishColors.marianBlue,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${day.month}/${day.day}',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textDarkColor),
                        ),
                        if (liturgicalFeasts.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: liturgicalFeasts.first.liturgicalColor.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              liturgicalFeasts.first.gradeName,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: liturgicalFeasts.first.liturgicalColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      '${dayEvents.length} services',
                      style: TextStyle(fontSize: 12, color: textMutedColor),
                    ),
                  ],
                ),
              ),
              if (liturgicalFeasts.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                  child: Text(
                    '✝ ${liturgicalFeasts.first.name}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: liturgicalFeasts.first.liturgicalColor),
                  ),
                ),
              if (dayEvents.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Text('No liturgical appointments booked.', style: TextStyle(fontSize: 13, color: textMutedColor)),
                )
              else
                ...dayEvents.map((e) => Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: _buildEventCard(e),
                )),
            ],
          ),
        );
      },
    );
  }

  // ===========================================================================
  // 3. DAY VIEW (Hourly Time-Block Timeline from Database)
  // ===========================================================================
  Widget _buildDayView() {
    final dayEvents = _eventsForDate(_selectedDate);
    final hours = [6, 8, 10, 12, 14, 16, 18];
    final cardWhiteColor = ParishColors.cardWhite;
    final borderGreyColor = ParishColors.borderGrey;
    final marianBlueSurfaceColor = ParishColors.marianBlueSurface;
    final textMutedColor = ParishColors.textMuted;
    final backgroundLightColor = ParishColors.backgroundLight;

    final isBlocked = LiturgicalCalendarService.isDateBlockedSync(_selectedDate);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildLiturgicalBannerForDate(_selectedDate),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardWhiteColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderGreyColor),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: marianBlueSurfaceColor,
                child: const Icon(Icons.church, color: ParishColors.marianBlue, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${dayEvents.length} Service(s) Scheduled',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      isBlocked ? 'Liturgical Solemnity / Appointments Restricted' : 'Active Venue & Clergy Allocation',
                      style: TextStyle(fontSize: 13, color: textMutedColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...hours.map((hour) {
          final timeLabel = hour < 12
              ? '${hour.toString().padLeft(2, '0')}:00 AM'
              : (hour == 12 ? '12:00 PM' : '${(hour - 12).toString().padLeft(2, '0')}:00 PM');

          final slotEvents = dayEvents.where((a) {
            try {
              final parts = a.requestedTime.split(':');
              final startH = int.parse(parts[0]);
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
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textMutedColor),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: slotEvents.isNotEmpty ? cardWhiteColor : backgroundLightColor.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: slotEvents.isNotEmpty ? borderGreyColor : borderGreyColor.withValues(alpha: 0.4),
                    ),
                  ),
                  child: slotEvents.isEmpty
                      ? InkWell(
                    onTap: isBlocked
                        ? null
                        : () => showScheduleAppointmentModal(context, onAppointmentSaved: _loadData),
                    child: Row(
                      children: [
                        Icon(
                          isBlocked ? Icons.block : Icons.add_circle_outline,
                          size: 18,
                          color: isBlocked ? ParishColors.mercyRed : textMutedColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isBlocked ? 'Day Reserved for Solemn Liturgy' : 'Slot Available (Tap to book)',
                          style: TextStyle(fontSize: 12, color: isBlocked ? ParishColors.mercyRed : textMutedColor),
                        ),
                      ],
                    ),
                  )
                      : Column(
                    children: slotEvents.map((a) => _buildEventCard(a)).toList(),
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  // ===========================================================================
  // Event Card Widget Bound to Live Database Appointment
  // ===========================================================================
  Widget _buildEventCard(AppointmentModel apt) {
    final cat = _getCategoryForService(apt.serviceType);
    final categoryColor = _getColorForCategory(cat);
    final cardWhiteColor = ParishColors.cardWhite;
    final borderGreyColor = ParishColors.borderGrey;
    final textMutedColor = ParishColors.textMuted;
    final textDarkColor = ParishColors.textDark;

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
          color: cardWhiteColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderGreyColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 5,
              height: 52,
              decoration: BoxDecoration(
                color: categoryColor,
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
                          color: categoryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          cat,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: categoryColor),
                        ),
                      ),
                      Text(
                        apt.formattedTimeRange,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textMutedColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    apt.serviceType,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textDarkColor),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 14, color: textMutedColor),
                      const SizedBox(width: 4),
                      Text(apt.venue, style: TextStyle(fontSize: 12, color: textMutedColor)),
                      const SizedBox(width: 12),
                      Icon(Icons.person_outline, size: 14, color: textMutedColor),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          apt.officiantName,
                          style: TextStyle(fontSize: 12, color: textMutedColor),
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

  Widget _buildEmptyDayCard({bool isBlocked = false}) {
    final cardWhiteColor = ParishColors.cardWhite;
    final borderGreyColor = ParishColors.borderGrey;
    final textMutedColor = ParishColors.textMuted;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardWhiteColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderGreyColor),
      ),
      child: Column(
        children: [
          Icon(
            isBlocked ? Icons.church_outlined : Icons.event_available,
            size: 40,
            color: isBlocked ? ParishColors.goldAccent : ParishColors.marianBlue,
          ),
          const SizedBox(height: 10),
          Text(
            isBlocked ? 'Reserved for Catholic Liturgy' : 'No Scheduled Services',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            isBlocked
                ? 'Routine ritual appointments are restricted due to this Catholic celebration.'
                : 'This date is open for new Mass intentions or sacraments.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: textMutedColor),
          ),
          if (!isBlocked) ...[
            const SizedBox(height: 14),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: ParishColors.marianBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => showScheduleAppointmentModal(context, onAppointmentSaved: _loadData),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Book This Day'),
            ),
          ],
        ],
      ),
    );
  }
}