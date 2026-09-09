import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../dialogs/calendar_event_dialog.dart';

class ParishCalendar extends StatelessWidget {
  const ParishCalendar({super.key});

  @override
  Widget build(BuildContext context) {
    final daysOfWeek = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    final eventsMap = {
      6: 'Sunday Mass & Community Baptism',
      12: 'Nuptial Mass (Santos-Ramos Wedding)',
      15: 'Diocesan Asset Audit Inspection',
      20: 'Parish Confirmation Rites',
      27: 'Feast Day Preparation Meeting',
    };

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
              width: 36,
              child: Text(
                d,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, color: ParishColors.marianBlue, fontSize: 14),
              ),
            ))
                .toList(),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 35,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemBuilder: (context, index) {
              const offset = 2; // September 2026 starts on Tuesday
              final dayNumber = index - offset + 1;

              if (dayNumber < 1 || dayNumber > 30) {
                return const SizedBox.shrink();
              }

              final hasEvent = eventsMap.containsKey(dayNumber);

              return InkWell(
                onTap: hasEvent
                    ? () => showCalendarEventModal(
                  context,
                  date: 'September $dayNumber, 2026',
                  eventTitle: eventsMap[dayNumber]!,
                )
                    : null,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  decoration: BoxDecoration(
                    color: hasEvent ? ParishColors.goldLight : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: hasEvent ? ParishColors.goldAccent : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        '$dayNumber',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: hasEvent ? FontWeight.bold : FontWeight.normal,
                          color: hasEvent ? ParishColors.textDark : ParishColors.textMuted,
                        ),
                      ),
                      if (hasEvent)
                        Positioned(
                          bottom: 4,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: ParishColors.marianBlue,
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
}