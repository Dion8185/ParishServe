import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../auth/models/user_model.dart';
import '../../appointments/services/liturgical_calendar_service.dart';
import '../../smart_archive/presentation/dialogs/sensor_detail_dialog.dart';
import 'dialogs/calendar_event_dialog.dart';
import 'pages/parish_calendar_page.dart';
import 'widgets/daily_readings_card.dart';

class DashboardView extends StatefulWidget {
  final UserModel? currentUser;

  const DashboardView({super.key, this.currentUser});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  @override
  void initState() {
    super.initState();
    LiturgicalCalendarService.getCalendarForYear(DateTime.now().year).then((_) {
      if (mounted) setState(() {});
    });
  }

  String _getTimeBasedGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return 'Good morning';
    } else if (hour >= 12 && hour < 18) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }

  String _formatTodayDate() {
    final now = DateTime.now();
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    final dayName = days[now.weekday - 1];
    final monthName = months[now.month - 1];
    return '$dayName, $monthName ${now.day}, ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    final textDarkColor = ParishColors.textDark;
    final textMutedColor = ParishColors.textMuted;
    final cardWhiteColor = ParishColors.cardWhite;
    final borderGreyColor = ParishColors.borderGrey;

    final greeting = _getTimeBasedGreeting();
    final displayName = widget.currentUser?.firstName ?? 'Parish Staff';
    final roleDisplay = widget.currentUser?.roleDisplay ?? 'Parish Operations Desk';

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth >= 900;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isDesktop ? 32 : 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Staff Greeting & Identification Banner
              _buildGreetingBanner(greeting, displayName, roleDisplay, isDesktop),
              const SizedBox(height: 24),

              // 2. Continuous 2-Column Balanced Architecture on Desktop
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // LEFT COLUMN (50%): Calendar + Smart Archive Telemetry
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCalendarHeader(context),
                          const SizedBox(height: 12),
                          _buildInteractiveCalendar(context, isDesktop: true),
                          const SizedBox(height: 24),
                          _buildArchiveTelemetryCard(context),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    // RIGHT COLUMN (50%): Daily Readings + Liturgical Schedule + Office Hours
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const DailyReadingsCard(),
                          const SizedBox(height: 24),
                          _buildLiturgicalScheduleCard(textDarkColor, borderGreyColor, cardWhiteColor),
                          const SizedBox(height: 24),
                          _buildOfficeHoursNotice(textDarkColor, textMutedColor, borderGreyColor),
                        ],
                      ),
                    ),
                  ],
                )
              else
              // Mobile View: Single Clean Vertical Stack
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const DailyReadingsCard(),
                    const SizedBox(height: 24),
                    _buildCalendarHeader(context),
                    const SizedBox(height: 12),
                    _buildInteractiveCalendar(context, isDesktop: false),
                    const SizedBox(height: 24),
                    _buildArchiveTelemetryCard(context),
                    const SizedBox(height: 20),
                    _buildLiturgicalScheduleCard(textDarkColor, borderGreyColor, cardWhiteColor),
                    const SizedBox(height: 20),
                    _buildOfficeHoursNotice(textDarkColor, textMutedColor, borderGreyColor),
                  ],
                ),
              const SizedBox(height: 28),

              // 3. Totus Tuus Parish Footer Motto
              Center(
                child: Column(
                  children: [
                    const Text(
                      'TOTUS TUUS',
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        fontStyle: FontStyle.italic,
                        color: ParishColors.goldAccent,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'St. John Paul II Parish • Diocese of San Pablo',
                      style: TextStyle(fontSize: 11, color: textMutedColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Greeting Banner
  // ---------------------------------------------------------------------------
  Widget _buildGreetingBanner(String greeting, String displayName, String roleDisplay, bool isDesktop) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isDesktop ? 24 : 18),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ParishColors.borderGrey, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: isDesktop ? 28 : 24,
            backgroundColor: ParishColors.marianBlueSurface,
            child: Text(
              displayName.isNotEmpty ? displayName[0].toUpperCase() : 'S',
              style: TextStyle(
                fontSize: isDesktop ? 22 : 18,
                fontWeight: FontWeight.bold,
                color: ParishColors.marianBlue,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting, $displayName!',
                  style: TextStyle(
                    fontSize: isDesktop ? 20 : 17,
                    fontWeight: FontWeight.bold,
                    color: ParishColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: ParishColors.goldLight,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: ParishColors.goldAccent.withOpacity(0.5)),
                  ),
                  child: Text(
                    roleDisplay,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: ParishColors.goldAccent,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 12, color: ParishColors.textMuted),
                    const SizedBox(width: 5),
                    Text(
                      _formatTodayDate(),
                      style: TextStyle(fontSize: 12, color: ParishColors.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Calendar Header
  // ---------------------------------------------------------------------------
  Widget _buildCalendarHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Parish Event Calendar',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: ParishColors.textDark),
            ),
            Text(
              'Liturgical feasts & parish schedules',
              style: TextStyle(fontSize: 12, color: ParishColors.textMuted),
            ),
          ],
        ),
        InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ParishCalendarPage()),
            );
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: ParishColors.marianBlueSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ParishColors.marianBlue.withOpacity(0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_month, size: 14, color: ParishColors.marianBlue),
                SizedBox(width: 6),
                Text(
                  'Full Calendar',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: ParishColors.marianBlue,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Compact Interactive Mini-Calendar Grid
  // ---------------------------------------------------------------------------
  Widget _buildInteractiveCalendar(BuildContext context, {required bool isDesktop}) {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
    final totalDays = lastDayOfMonth.day;
    final offset = firstDayOfMonth.weekday % 7;
    final totalGridCells = ((totalDays + offset) / 7).ceil() * 7;
    final daysOfWeek = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ParishColors.borderGrey, width: 1.2),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: daysOfWeek
                .map((d) => SizedBox(
              width: 32,
              child: Text(
                d,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: ParishColors.marianBlue,
                  fontSize: 13,
                ),
              ),
            ))
                .toList(),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: totalGridCells,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              // Sleek, compact 1.25:1 aspect ratio on desktop to prevent excessive height
              childAspectRatio: isDesktop ? 1.25 : 1.0,
            ),
            itemBuilder: (context, index) {
              final dayNumber = index - offset + 1;
              if (dayNumber < 1 || dayNumber > totalDays) {
                return const SizedBox.shrink();
              }

              final cellDate = DateTime(now.year, now.month, dayNumber);
              final feasts = LiturgicalCalendarService.getCelebrationsForDateSync(cellDate);
              final hasFeast = feasts.isNotEmpty;
              final isToday = dayNumber == now.day;

              return InkWell(
                onTap: () {
                  if (hasFeast) {
                    showCalendarEventModal(
                      context,
                      date: '${cellDate.month}/${cellDate.day}/${cellDate.year}',
                      eventTitle: feasts.first.name,
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ParishCalendarPage()),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: BoxDecoration(
                    color: isToday
                        ? ParishColors.marianBlue
                        : (hasFeast ? feasts.first.liturgicalColor.withOpacity(0.15) : Colors.transparent),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isToday
                          ? ParishColors.marianBlue
                          : (hasFeast ? feasts.first.liturgicalColor : Colors.transparent),
                      width: 1.5,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        '$dayNumber',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: (hasFeast || isToday) ? FontWeight.bold : FontWeight.normal,
                          color: isToday
                              ? Colors.white
                              : (hasFeast ? ParishColors.textDark : ParishColors.textMuted),
                        ),
                      ),
                      if (hasFeast && !isToday)
                        Positioned(
                          bottom: 3,
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: feasts.first.liturgicalColor,
                              shape: BoxShape.circle,
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

  // ---------------------------------------------------------------------------
  // Smart Archive Telemetry (ESP32 IoT)
  // ---------------------------------------------------------------------------
  Widget _buildArchiveTelemetryCard(BuildContext context) {
    return InkWell(
      onTap: () => showSensorDetailModal(
        context,
        roomTitle: 'Sacramental Archive Room',
        nodeId: 'ESP32-NODE-01',
        temperature: '24.2 °C',
        humidity: '54 %',
        isWarning: false,
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: ParishColors.cardWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ParishColors.borderGrey, width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.sensors, color: ParishColors.marianBlue, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Archive Telemetry',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: ParishColors.oliveGreenSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: ParishColors.oliveGreen.withOpacity(0.5)),
                  ),
                  child: const Text(
                    'SAFE (ESP32)',
                    style: TextStyle(
                      color: ParishColors.oliveGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 10.5,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.thermostat, size: 22, color: ParishColors.marianBlue),
                      const SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Temperature', style: TextStyle(fontSize: 11, color: ParishColors.textMuted)),
                          Text('24.2 °C', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(height: 28, width: 1, color: ParishColors.borderGrey),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.water_drop_outlined, size: 22, color: ParishColors.marianBlue),
                      const SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Humidity', style: TextStyle(fontSize: 11, color: ParishColors.textMuted)),
                          Text('54 %', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Liturgical Schedule
  // ---------------------------------------------------------------------------
  Widget _buildLiturgicalScheduleCard(Color textDark, Color borderGrey, Color cardWhite) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderGrey, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.church, color: ParishColors.marianBlue, size: 22),
              const SizedBox(width: 10),
              Text(
                'Regular Liturgical Schedule',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textDark),
              ),
            ],
          ),
          const Divider(height: 20),
          _buildScheduleRow('Sunday Masses', '6:00 AM • 8:00 AM • 5:00 PM', Icons.wb_sunny_outlined),
          const SizedBox(height: 10),
          _buildScheduleRow('Daily Masses (Tue – Sat)', '6:30 AM (Main Altar)', Icons.schedule),
          const SizedBox(height: 10),
          _buildScheduleRow('Confessions & Anointing', 'By appointment or Saturday 4:00 PM', Icons.favorite_border),
        ],
      ),
    );
  }

  Widget _buildScheduleRow(String title, String timing, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: ParishColors.marianBlue),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: ParishColors.textDark),
              ),
              Text(
                timing,
                style: TextStyle(fontSize: 11.5, color: ParishColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Secretariat Office Hours
  // ---------------------------------------------------------------------------
  Widget _buildOfficeHoursNotice(Color textDark, Color textMuted, Color borderGrey) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ParishColors.backgroundLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderGrey),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: ParishColors.marianBlue, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Parish Office & Administration Hours',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: textDark),
                ),
                const SizedBox(height: 4),
                Text(
                  '• Tuesday to Sunday: 8:00 AM – 12:00 PM | 1:30 PM – 5:00 PM\n'
                      '• Monday: Closed (Canonical Clergy Rest Day & Sanctification)',
                  style: TextStyle(fontSize: 12, color: textMuted, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}