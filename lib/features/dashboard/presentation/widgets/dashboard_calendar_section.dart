import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../auth/services/auth_service.dart';
import '../pages/parish_calendar_page.dart';

class DashboardCalendarSection extends StatelessWidget {
  const DashboardCalendarSection({super.key});

  @override
  Widget build(BuildContext context) {
    final role = AuthService.currentUser?.userRole.toLowerCase() ?? 'secretary';
    final isPriest = role == 'parishpriest';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Parish Event Calendar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
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
              icon: const Icon(Icons.open_in_new, size: 14),
              label: const Text('Open Main Calendar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          isPriest
              ? 'Tap below to review celebrations or cancel appointments.'
              : 'Tap below to view celebrations or schedule new appointments.',
          style: TextStyle(fontSize: 13, color: ParishColors.textMuted),
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
                  color: Colors.black.withValues(alpha: 0.03),
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
                    Text('September 2026', style: TextStyle(fontWeight: FontWeight.bold, color: ParishColors.marianBlue, fontSize: 14)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: ParishColors.goldLight, borderRadius: BorderRadius.circular(6)),
                      child: const Text('Active Schedule', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ParishColors.goldAccent)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildMiniCalendarGrid(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniCalendarGrid() {
    final daysOfWeek = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    final eventsMap = {
      6: 'Sunday Mass & Community Baptism',
      12: 'Nuptial Mass (Santos-Ramos Wedding)',
      15: 'Diocesan Asset Audit Inspection',
      20: 'Parish Confirmation Rites',
      27: 'Feast Day Preparation Meeting',
    };

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: daysOfWeek
              .map((d) => SizedBox(
            width: 28,
            child: Text(
              d,
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, color: ParishColors.marianBlue, fontSize: 12),
            ),
          ))
              .toList(),
        ),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 35,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: 1.2,
          ),
          itemBuilder: (context, index) {
            const offset = 2; // Sept 2026 starts on Tuesday
            final dayNumber = index - offset + 1;
            if (dayNumber < 1 || dayNumber > 30) {
              return const SizedBox.shrink();
            }
            final hasEvent = eventsMap.containsKey(dayNumber);

            return Container(
              decoration: BoxDecoration(
                color: hasEvent ? ParishColors.goldLight : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: hasEvent ? ParishColors.goldAccent : ParishColors.borderGrey.withValues(alpha: 0.3),
                  width: 1.2,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    '$dayNumber',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: hasEvent ? FontWeight.bold : FontWeight.normal,
                      color: hasEvent ? ParishColors.textDark : ParishColors.textMuted,
                    ),
                  ),
                  if (hasEvent)
                    Positioned(
                      bottom: 2,
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: ParishColors.marianBlue,
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