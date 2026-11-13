// =============================================================================
// FILE: lib/features/dashboard/presentation/widgets/dashboard_calendar_section.dart
// =============================================================================

import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../appointments/services/liturgical_calendar_service.dart';
import '../../../auth/services/auth_service.dart';
import '../pages/parish_calendar_page.dart';

class DashboardCalendarSection extends StatelessWidget {
  const DashboardCalendarSection({super.key});

  static const List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final role = AuthService.currentUser?.userRole.toLowerCase() ?? 'secretary';
    final isPriest = role == 'parishpriest';
    final monthTitle = '${_monthNames[now.month - 1]} ${now.year}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Parish Event Calendar',
              style: TextStyle(
                fontSize: 17.5,
                fontWeight: FontWeight.bold,
                color: ParishColors.textDark,
              ),
            ),
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: ParishColors.marianBlue,
                backgroundColor: ParishColors.marianBlueSurface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ParishCalendarPage()),
                );
              },
              icon: const Icon(Icons.table_chart_outlined, size: 14),
              label: const Text(
                'Open Timetable Ledger',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          isPriest
              ? 'Review liturgical celebrations, Solemnities, and scheduled ceremonies.'
              : 'Track upcoming sacraments, blessings, and altar celebrations.',
          style: TextStyle(fontSize: 12.5, color: ParishColors.textMuted),
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ParishCalendarPage()),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ParishColors.cardWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ParishColors.borderGrey, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      monthTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: ParishColors.marianBlue,
                        fontSize: 14,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: ParishColors.marianBlueSurface,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Live Liturgy Ledger',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: ParishColors.marianBlue,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildLiveMiniCalendarGrid(now),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLiveMiniCalendarGrid(DateTime now) {
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
    final totalDays = lastDayOfMonth.day;
    final offset = firstDayOfMonth.weekday % 7;
    final totalCells = ((totalDays + offset) / 7).ceil() * 7;
    final daysOfWeek = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: daysOfWeek.map((d) {
            final isMon = d == 'M';
            return SizedBox(
              width: 28,
              child: Text(
                d,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isMon ? const Color(0xFF94A3B8) : ParishColors.marianBlue,
                  fontSize: 12,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: totalCells,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: 1.25,
          ),
          itemBuilder: (context, index) {
            final dayNumber = index - offset + 1;
            if (dayNumber < 1 || dayNumber > totalDays) {
              return const SizedBox.shrink();
            }

            final cellDate = DateTime(now.year, now.month, dayNumber);
            final isToday = dayNumber == now.day;
            final isMonday = cellDate.weekday == DateTime.monday;
            final feasts = LiturgicalCalendarService.getCelebrationsForDateSync(cellDate);
            final hasFeast = feasts.isNotEmpty;

            Color bgColor = Colors.transparent;
            Color borderColor = ParishColors.borderGrey.withOpacity(0.3);

            if (isToday) {
              bgColor = ParishColors.marianBlueSurface;
              borderColor = ParishColors.marianBlue;
            } else if (hasFeast) {
              bgColor = feasts.first.categorySurfaceColor;
              borderColor = feasts.first.categoryBadgeColor.withOpacity(0.35);
            } else if (isMonday) {
              bgColor = const Color(0xFFF8FAFC);
            }

            return Container(
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: borderColor, width: isToday ? 1.4 : 1.0),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    '$dayNumber',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: (isToday || hasFeast) ? FontWeight.bold : FontWeight.normal,
                      color: isToday
                          ? ParishColors.marianBlue
                          : (isMonday ? const Color(0xFF94A3B8) : ParishColors.textDark),
                    ),
                  ),
                  if (hasFeast)
                    Positioned(
                      bottom: 2,
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: feasts.first.categoryBadgeColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}