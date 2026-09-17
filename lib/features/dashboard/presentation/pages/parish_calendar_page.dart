import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../auth/services/auth_service.dart';
import '../../../appointments/presentation/dialogs/schedule_appointment_dialog.dart';

enum CalendarViewMode { month, week, day }

class ParishCalendarPage extends StatefulWidget {
  const ParishCalendarPage({super.key});

  @override
  State<ParishCalendarPage> createState() => _ParishCalendarPageState();
}

class _ParishCalendarPageState extends State<ParishCalendarPage> {
  CalendarViewMode _currentView = CalendarViewMode.month;
  DateTime _selectedDate = DateTime(2026, 9, 12);
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Sacraments',
    'Mass Intentions',
    'Pastoral Care',
    'Diocesan / Admin',
  ];

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

  void _showEventDetailsModal(Map<String, dynamic> event) {
    final role = AuthService.currentUser?.userRole.toLowerCase() ?? 'secretary';
    final isPriest = role == 'parishpriest';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Celebration Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text(event['id'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ParishColors.marianBlue)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ParishColors.marianBlueSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Service / Celebration', style: TextStyle(fontSize: 12, color: ParishColors.textMuted)),
                  Text(event['title'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ParishColors.marianBlue)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text('Date: ${event['date'].toIso8601String().substring(0, 10)} (${event['startTime']} - ${event['endTime']})', style: TextStyle(fontWeight: FontWeight.w600, color: ParishColors.textDark)),
            const SizedBox(height: 4),
            Text('Venue: ${event['venue']}', style: TextStyle(color: ParishColors.textMuted)),
            Text('Officiant: ${event['officiant']}', style: TextStyle(color: ParishColors.textMuted)),
            Text('Requester: ${event['requester']} (${event['contact']})', style: TextStyle(color: ParishColors.textMuted)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: ParishColors.oliveGreenSurface,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('Status: ${event['status']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: ParishColors.oliveGreen)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          // Parish Priest gets Cancel/Revoke authority; Secretary gets Appointment booking tools
          if (isPriest)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: ParishColors.mercyRed, foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _allEvents.removeWhere((e) => e['id'] == event['id']);
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Celebration/Appointment cancelled by Parish Priest.'), backgroundColor: ParishColors.mercyRed),
                );
              },
              icon: const Icon(Icons.cancel_outlined, size: 18),
              label: const Text('Cancel Celebration'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = AuthService.currentUser?.userRole.toLowerCase() ?? 'secretary';
    final bool canAppoint = role != 'parishpriest'; // Priest views/cancels; Secretary/others can appoint

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
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ParishColors.textDark),
            ),
            Text(
              canAppoint ? 'Secretary Mode: View & Appoint' : 'Parish Priest Mode: View & Cancel',
              style: TextStyle(fontSize: 12, color: ParishColors.textMuted),
            ),
          ],
        ),
        actions: [
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
          Divider(height: 1, color: ParishColors.borderGrey),
          Expanded(
            child: _buildCurrentCalendarView(),
          ),
        ],
      ),
      // Only Secretaries and non-Priest roles can book new appointments here
      floatingActionButton: canAppoint
          ? FloatingActionButton.extended(
        backgroundColor: ParishColors.marianBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Appoint Service', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => showScheduleAppointmentModal(context),
      )
          : null,
    );
  }

  Widget _buildControlHeader() {
    return Container(
      color: ParishColors.cardWhite,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: ParishColors.backgroundLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ParishColors.borderGrey),
            ),
            child: Row(
              children: [
                _buildViewTab(CalendarViewMode.month, 'Month', Icons.calendar_view_month),
                _buildViewTab(CalendarViewMode.week, 'Week', Icons.calendar_view_week),
                _buildViewTab(CalendarViewMode.day, 'Day', Icons.calendar_view_day),
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
              Icon(icon, size: 16, color: isSelected ? Colors.white : ParishColors.textMuted),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
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
    return Container(
      color: ParishColors.cardWhite,
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
                selectedColor: ParishColors.goldLight,
                backgroundColor: ParishColors.backgroundLight,
                checkmarkColor: ParishColors.goldAccent,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? ParishColors.goldAccent : ParishColors.textMuted,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected ? ParishColors.goldAccent : ParishColors.borderGrey,
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

  Widget _buildMonthView() {
    final daysOfWeek = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final selectedDayEvents = _eventsForDate(_selectedDate);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
              itemCount: 35,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 0.95,
              ),
              itemBuilder: (context, index) {
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
                          : (hasEvents ? ParishColors.goldLight : Colors.transparent),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? ParishColors.marianBlue
                            : (hasEvents ? ParishColors.goldAccent : ParishColors.borderGrey.withOpacity(0.5)),
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
                                : (hasEvents ? ParishColors.textDark : ParishColors.textMuted),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Celebrations on ${_selectedDate.month}/${_selectedDate.day}/${_selectedDate.year}',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ParishColors.textDark),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: ParishColors.marianBlueSurface,
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

  Widget _buildWeekView() {
    final startOfWeek = _selectedDate.subtract(Duration(days: _selectedDate.weekday % 7));
    final weekDays = List.generate(7, (i) => startOfWeek.add(Duration(days: i)));

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
            color: ParishColors.cardWhite,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? ParishColors.marianBlue : ParishColors.borderGrey,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? ParishColors.marianBlueSurface : ParishColors.backgroundLight,
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
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                        ),
                      ],
                    ),
                    Text('${dayEvents.length} services', style: TextStyle(fontSize: 12, color: ParishColors.textMuted)),
                  ],
                ),
              ),
              if (dayEvents.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Text('No liturgical services scheduled.', style: TextStyle(fontSize: 13, color: ParishColors.textMuted)),
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

  Widget _buildDayView() {
    final dayEvents = _eventsForDate(_selectedDate);
    final hours = [6, 8, 10, 12, 14, 16, 18];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ParishColors.cardWhite,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ParishColors.borderGrey),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: ParishColors.marianBlueSurface,
                child: const Icon(Icons.church, color: ParishColors.marianBlue, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${dayEvents.length} Celebration(s) Scheduled', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
                    Text('Active Liturgical Master Schedule', style: TextStyle(fontSize: 13, color: ParishColors.textMuted)),
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

          final slotEvents = dayEvents.where((e) {
            final start = e['startTime'] as String;
            if (hour == 6 && start.contains('06:00')) return true;
            if (hour == 8 && (start.contains('08:') || start.contains('09:'))) return true;
            if (hour == 10 && start.contains('10:')) return true;
            if (hour == 14 && start.contains('02:')) return true;
            if (hour == 16 && start.contains('04:')) return true;
            return false;
          }).toList();

          final role = AuthService.currentUser?.userRole.toLowerCase() ?? 'secretary';
          final canAppoint = role != 'parishpriest';

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 70,
                child: Padding(
                  padding: const EdgeInsets.only(top: 14.0),
                  child: Text(timeLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ParishColors.textMuted)),
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: slotEvents.isNotEmpty ? ParishColors.cardWhite : ParishColors.backgroundLight.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: slotEvents.isNotEmpty ? ParishColors.borderGrey : ParishColors.borderGrey.withOpacity(0.4)),
                  ),
                  child: slotEvents.isEmpty
                      ? (canAppoint
                      ? InkWell(
                    onTap: () => showScheduleAppointmentModal(context),
                    child: Row(
                      children: [
                        Icon(Icons.add_circle_outline, size: 18, color: ParishColors.textMuted),
                        const SizedBox(width: 8),
                        Text('Slot Available (Tap to appoint)', style: TextStyle(fontSize: 12, color: ParishColors.textMuted)),
                      ],
                    ),
                  )
                      : Text('No celebration scheduled', style: TextStyle(fontSize: 12, color: ParishColors.textMuted)))
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

  Widget _buildEventCard(Map<String, dynamic> event) {
    final Color categoryColor = event['color'] as Color;

    return InkWell(
      onTap: () => _showEventDetailsModal(event),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ParishColors.cardWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ParishColors.borderGrey),
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
                      Text('${event['startTime']} – ${event['endTime']}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ParishColors.textMuted)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(event['title'], style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 14, color: ParishColors.textMuted),
                      const SizedBox(width: 4),
                      Text(event['venue'], style: TextStyle(fontSize: 12, color: ParishColors.textMuted)),
                      const SizedBox(width: 12),
                      Icon(Icons.person_outline, size: 14, color: ParishColors.textMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(event['officiant'], style: TextStyle(fontSize: 12, color: ParishColors.textMuted), overflow: TextOverflow.ellipsis),
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
    final role = AuthService.currentUser?.userRole.toLowerCase() ?? 'secretary';
    final canAppoint = role != 'parishpriest';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ParishColors.borderGrey),
      ),
      child: Column(
        children: [
          const Icon(Icons.event_available, size: 40, color: ParishColors.marianBlue),
          const SizedBox(height: 10),
          Text('No Celebrations Scheduled', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
          Text('This date is open for new liturgical services.', style: TextStyle(fontSize: 13, color: ParishColors.textMuted)),
          if (canAppoint) ...[
            const SizedBox(height: 14),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: ParishColors.marianBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => showScheduleAppointmentModal(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Appoint Service'),
            ),
          ],
        ],
      ),
    );
  }
}