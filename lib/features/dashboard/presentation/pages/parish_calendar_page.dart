import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../appointments/presentation/dialogs/appointment_detail_dialog.dart';
import '../../../appointments/presentation/dialogs/schedule_appointment_dialog.dart';

enum CalendarViewMode { month, week, day }

class ParishCalendarPage extends StatefulWidget {
  const ParishCalendarPage({super.key});

  @override
  State<ParishCalendarPage> createState() => _ParishCalendarPageState();
}

class _ParishCalendarPageState extends State<ParishCalendarPage> {
  CalendarViewMode _currentView = CalendarViewMode.month;
  DateTime _selectedDate = DateTime(2026, 9, 12); // Simulated active date
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Sacraments',
    'Mass Intentions',
    'Pastoral Care',
    'Diocesan / Admin',
  ];

  // Rich Parish-Specific Event Data
  final List<Map<String, dynamic>> _allEvents = [
    {
      'id': 'APT-2026-0042',
      'title': 'Nuptial Mass (Santos-Ramos Wedding)',
      'date': DateTime(2026, 9, 12),
      'startTime': '10:00 AM',
      'endTime': '11:30 AM',
      'category': 'Sacraments',
      'venue': 'Main Church Altar',
      'officiant': 'Rev. Fr. Joseph Santos',
      'requester': 'Carlos Santos',
      'contact': '0917-882-9912',
      'status': 'CONFIRMED',
      'feeStatus': 'Paid (REC-2026-00870)',
      'color': ParishColors.marianBlue,
    },
    {
      'id': 'APT-2026-0046',
      'title': 'Pre-Cana Canonical Interview',
      'date': DateTime(2026, 9, 12),
      'startTime': '02:00 PM',
      'endTime': '03:30 PM',
      'category': 'Sacraments',
      'venue': 'Parish Secretariat Office',
      'officiant': 'Rev. Fr. Joseph Santos',
      'requester': 'Reyes-Mercado Couple',
      'contact': '0919-445-1288',
      'status': 'CONFIRMED',
      'feeStatus': 'Non-Financial',
      'color': ParishColors.marianBlue,
    },
    {
      'id': 'APT-2026-0043',
      'title': 'Community Baptism (Batch A - 12 Infants)',
      'date': DateTime(2026, 9, 14),
      'startTime': '09:00 AM',
      'endTime': '10:30 AM',
      'category': 'Sacraments',
      'venue': 'Baptistery & Main Altar',
      'officiant': 'Rev. Fr. Parochial Vicar',
      'requester': 'Dela Cruz Family & Others',
      'contact': '0922-451-2290',
      'status': 'CONFIRMED',
      'feeStatus': 'Paid (REC-2026-00892)',
      'color': ParishColors.marianBlue,
    },
    {
      'id': 'APT-2026-0047',
      'title': 'Diocesan Financial & Property Inspection',
      'date': DateTime(2026, 9, 15),
      'startTime': '09:00 AM',
      'endTime': '04:00 PM',
      'category': 'Diocesan / Admin',
      'venue': 'Parish Conference Room',
      'officiant': 'Diocesan Auditing Commission',
      'requester': 'Diocese of San Pablo',
      'contact': 'Office of the Bishop',
      'status': 'CONFIRMED',
      'feeStatus': 'Official Diocesan Visit',
      'color': ParishColors.mercyRed,
    },
    {
      'id': 'APT-2026-0044',
      'title': 'Pastoral Sick Call & Viaticum',
      'date': DateTime(2026, 9, 16),
      'startTime': '02:00 PM',
      'endTime': '03:00 PM',
      'category': 'Pastoral Care',
      'venue': 'Barangay Labuin Home Visit',
      'officiant': 'Rev. Fr. Joseph Santos',
      'requester': 'Remedios Bautista',
      'contact': '0918-334-5511',
      'status': 'PENDING',
      'feeStatus': 'Non-Financial (Pastoral Duty)',
      'color': ParishColors.oliveGreen,
    },
    {
      'id': 'APT-2026-0045',
      'title': 'Thanksgiving Dawn Mass Intention',
      'date': DateTime(2026, 9, 18),
      'startTime': '06:00 AM',
      'endTime': '07:00 AM',
      'category': 'Mass Intentions',
      'venue': 'Main Church Altar',
      'officiant': 'Rev. Fr. Joseph Santos',
      'requester': 'Pedro Alvarez',
      'contact': '0908-112-9943',
      'status': 'CONFIRMED',
      'feeStatus': 'Paid (REC-2026-00891)',
      'color': ParishColors.goldAccent,
    },
    {
      'id': 'APT-2026-0048',
      'title': 'Parish Confirmation Rites',
      'date': DateTime(2026, 9, 20),
      'startTime': '09:00 AM',
      'endTime': '11:30 AM',
      'category': 'Sacraments',
      'venue': 'Main Church Altar',
      'officiant': 'Most Rev. Bishop / Delegate',
      'requester': 'Parish Catechetical Ministry',
      'contact': 'Secretariat Desk',
      'status': 'CONFIRMED',
      'feeStatus': 'Parish Sponsored',
      'color': ParishColors.marianBlue,
    },
  ];

  List<Map<String, dynamic>> get _filteredEvents {
    return _allEvents.where((e) {
      final matchesCategory = _selectedCategory == 'All' || e['category'] == _selectedCategory;
      return matchesCategory;
    }).toList();
  }

  List<Map<String, dynamic>> _eventsForDate(DateTime date) {
    return _filteredEvents.where((e) {
      final eventDate = e['date'] as DateTime;
      return eventDate.year == date.year &&
          eventDate.month == date.month &&
          eventDate.day == date.day;
    }).toList();
  }

  void _navigateDate(int delta) {
    setState(() {
      if (_currentView == CalendarViewMode.month) {
        _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + delta, _selectedDate.day);
      } else if (_currentView == CalendarViewMode.week) {
        _selectedDate = _selectedDate.add(Duration(days: delta * 7));
      } else {
        _selectedDate = _selectedDate.add(Duration(days: delta));
      }
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
              'Liturgical & Service Schedule',
              style: TextStyle(fontSize: 12, color: textColorMuted),
            ),
          ],
        ),
        actions: [
          // "Today" Quick Jump Button
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: TextButton.icon(
              style: TextButton.styleFrom(
                backgroundColor: ParishColors.marianBlueSurface,
                foregroundColor: ParishColors.marianBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => setState(() => _selectedDate = DateTime(2026, 9, 12)),
              icon: const Icon(Icons.today, size: 18),
              label: const Text('Today', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildControlHeader(),
          _buildCategoryFilterRow(),
          Divider(height: 1, color: borderColor),
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
        onPressed: () => showScheduleAppointmentModal(context),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Top Controls: Month / Week / Day Toggle & Date Stepper
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
          // View Switcher Tabs (Month / Week / Day)
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

          // Date Navigator with Arrow Steppers
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

  // ---------------------------------------------------------------------------
  // Category Filter Chips
  // ---------------------------------------------------------------------------
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
  // 1. MONTH VIEW (Grid + Selected Day Event Drawer)
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Days of Week Header
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

          // 35-Day Calendar Grid
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
              itemCount: 35,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 0.95,
              ),
              itemBuilder: (context, index) {
                // Fixed offset: Sept 2026 starts on Tuesday (offset = 2)
                const offset = 2;
                final dayNum = index - offset + 1;
                if (dayNum < 1 || dayNum > 30) {
                  return const SizedBox.shrink();
                }

                final thisDate = DateTime(_selectedDate.year, _selectedDate.month, dayNum);
                final dayEvents = _eventsForDate(thisDate);
                final isSelected = dayNum == _selectedDate.day;
                final hasEvents = dayEvents.isNotEmpty;

                return InkWell(
                  onTap: () => setState(() => _selectedDate = thisDate),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? ParishColors.marianBlue
                          : (hasEvents ? goldLightColor : Colors.transparent),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? ParishColors.marianBlue
                            : (hasEvents ? ParishColors.goldAccent : borderGreyColor.withValues(alpha: 0.5)),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$dayNum',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: (hasEvents || isSelected) ? FontWeight.bold : FontWeight.normal,
                            color: isSelected
                                ? Colors.white
                                : (hasEvents ? textDarkColor : textMutedColor),
                          ),
                        ),
                        if (hasEvents) ...[
                          const SizedBox(height: 3),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: dayEvents.take(3).map((e) {
                              return Container(
                                width: 5,
                                height: 5,
                                margin: const EdgeInsets.symmetric(horizontal: 1),
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.white : (e['color'] as Color),
                                  shape: BoxShape.circle,
                                ),
                              );
                            }).toList(),
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

          // Events on the Selected Day
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Events on ${_selectedDate.month}/${_selectedDate.day}/${_selectedDate.year}',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDarkColor),
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
            _buildEmptyDayCard()
          else
            ...selectedDayEvents.map((e) => _buildEventCard(e)),
        ],
      ),
    );
  }

  // ===========================================================================
  // 2. WEEK VIEW (Day Strips with Scheduled Event Cards)
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
              // Day Header Row
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
                      ],
                    ),
                    Text(
                      '${dayEvents.length} services',
                      style: TextStyle(fontSize: 12, color: textMutedColor),
                    ),
                  ],
                ),
              ),

              if (dayEvents.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Text('No liturgical services scheduled.', style: TextStyle(fontSize: 13, color: textMutedColor)),
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
  // 3. DAY VIEW (Hourly Time-Block Timeline)
  // ===========================================================================
  Widget _buildDayView() {
    final dayEvents = _eventsForDate(_selectedDate);
    final hours = [6, 8, 10, 12, 14, 16, 18];
    final cardWhiteColor = ParishColors.cardWhite;
    final borderGreyColor = ParishColors.borderGrey;
    final marianBlueSurfaceColor = ParishColors.marianBlueSurface;
    final textMutedColor = ParishColors.textMuted;
    final backgroundLightColor = ParishColors.backgroundLight;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary Header
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
                    Text('Presiding: Rev. Fr. Joseph Santos', style: TextStyle(fontSize: 13, color: textMutedColor)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Hourly Timeline
        ...hours.map((hour) {
          final timeLabel = hour < 12
              ? '${hour.toString().padLeft(2, '0')}:00 AM'
              : (hour == 12 ? '12:00 PM' : '${(hour - 12).toString().padLeft(2, '0')}:00 PM');

          // Match simulated events roughly near this hour
          final slotEvents = dayEvents.where((e) {
            final start = e['startTime'] as String;
            if (hour == 6 && start.contains('06:00')) return true;
            if (hour == 8 && (start.contains('08:') || start.contains('09:'))) return true;
            if (hour == 10 && start.contains('10:')) return true;
            if (hour == 14 && start.contains('02:')) return true;
            if (hour == 16 && start.contains('04:')) return true;
            return false;
          }).toList();

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Time Label
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
              // Right Timeline Block
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: slotEvents.isNotEmpty ? cardWhiteColor : backgroundLightColor.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: slotEvents.isNotEmpty ? borderGreyColor : borderGreyColor.withValues(alpha: 0.4),
                    ),
                  ),
                  child: slotEvents.isEmpty
                      ? InkWell(
                    onTap: () => showScheduleAppointmentModal(context),
                    child: Row(
                      children: [
                        Icon(Icons.add_circle_outline, size: 18, color: textMutedColor),
                        const SizedBox(width: 8),
                        Text('Slot Available (Tap to book service)', style: TextStyle(fontSize: 12, color: textMutedColor)),
                      ],
                    ),
                  )
                      : Column(
                    children: slotEvents.map((e) => _buildEventCard(e)).toList(),
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
  // Reusable Event & Empty State Cards
  // ===========================================================================
  Widget _buildEventCard(Map<String, dynamic> event) {
    final Color categoryColor = event['color'] as Color;
    final cardWhiteColor = ParishColors.cardWhite;
    final borderGreyColor = ParishColors.borderGrey;
    final textMutedColor = ParishColors.textMuted;
    final textDarkColor = ParishColors.textDark;

    return InkWell(
      onTap: () => showAppointmentDetailModal(
        context,
        refNo: event['id'],
        serviceName: event['title'],
        requester: event['requester'],
        contact: event['contact'],
        scheduleTime: '${event['startTime']} – ${event['endTime']}',
        officiant: event['officiant'],
        status: event['status'],
        feeStatus: event['feeStatus'],
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
                          color: categoryColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          event['category'],
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: categoryColor),
                        ),
                      ),
                      Text(
                        '${event['startTime']} – ${event['endTime']}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textMutedColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    event['title'],
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textDarkColor),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 14, color: textMutedColor),
                      const SizedBox(width: 4),
                      Text(event['venue'], style: TextStyle(fontSize: 12, color: textMutedColor)),
                      const SizedBox(width: 12),
                      Icon(Icons.person_outline, size: 14, color: textMutedColor),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          event['officiant'],
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

  Widget _buildEmptyDayCard() {
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
          const Icon(Icons.event_available, size: 40, color: ParishColors.marianBlue),
          const SizedBox(height: 10),
          const Text('No Scheduled Services', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('This date is open for new Mass intentions or sacraments.', style: TextStyle(fontSize: 13, color: textMutedColor)),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: ParishColors.marianBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => showScheduleAppointmentModal(context),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Book This Day'),
          ),
        ],
      ),
    );
  }
}