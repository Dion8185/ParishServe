// =============================================================================
// FILE: lib/features/dashboard/presentation/dialogs/calendar_event_dialog.dart
// =============================================================================

import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';

void showCalendarEventModal(
    BuildContext context, {
      required String date,
      required String eventTitle,
      String? venue,
      String? officiant,
      String? time,
      String? gradeName,
      bool isLiturgical = false,
    }) {
  final textColorMuted = ParishColors.textMuted;
  final textColorDark = ParishColors.textDark;
  final resolvedVenue = venue ?? 'Parish Grounds (Main Church Altar)';
  final resolvedOfficiant = officiant ?? 'Rev. Fr. Roy (Parish Priest)';
  final bool isOutside = resolvedVenue.toLowerCase().contains('outside') ||
      resolvedVenue.toLowerCase().contains('off-site') ||
      resolvedVenue.toLowerCase().contains('home') ||
      resolvedVenue.toLowerCase().contains('hospital');

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: ParishColors.cardWhite,
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: isLiturgical ? ParishColors.goldLight : ParishColors.marianBlueSurface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isLiturgical ? Icons.church : Icons.event,
              color: isLiturgical ? ParishColors.goldAccent : ParishColors.marianBlue,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.5, color: textColorDark),
                ),
                Text(
                  isLiturgical ? 'Catholic Liturgical Celebration' : 'Parish Liturgy Schedule',
                  style: TextStyle(fontSize: 11.5, color: textColorMuted),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event / Rite Summary Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isLiturgical ? ParishColors.goldLight : ParishColors.marianBlueSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isLiturgical
                      ? ParishColors.goldAccent.withOpacity(0.4)
                      : ParishColors.marianBlue.withOpacity(0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isLiturgical ? 'LITURGICAL CALENDAR' : 'SCHEDULED CEREMONY',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isLiturgical ? ParishColors.goldAccent : ParishColors.marianBlue,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (gradeName != null && gradeName.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: ParishColors.cardWhite,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            gradeName.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: isLiturgical ? ParishColors.goldAccent : ParishColors.marianBlue,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    eventTitle,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isLiturgical ? const Color(0xFF92400E) : ParishColors.marianBlue,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Time Row (if available)
            if (time != null && time.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: ParishColors.marianBlueAdaptive),
                    const SizedBox(width: 8),
                    RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 12.5, color: textColorDark),
                        children: [
                          TextSpan(text: 'Time: ', style: TextStyle(fontWeight: FontWeight.bold, color: textColorMuted)),
                          TextSpan(text: time, style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Venue Row with Location Badge
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isOutside ? Icons.pin_drop_outlined : Icons.location_on_outlined,
                    size: 16,
                    color: ParishColors.marianBlueAdaptive,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 12.5, color: textColorDark),
                        children: [
                          TextSpan(text: 'Venue: ', style: TextStyle(fontWeight: FontWeight.bold, color: textColorMuted)),
                          TextSpan(text: '$resolvedVenue ', style: const TextStyle(fontWeight: FontWeight.w600)),
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: isOutside ? ParishColors.goldLight : ParishColors.marianBlueSurface,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isOutside ? 'OUTSIDE' : 'PARISH GROUNDS',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  color: isOutside ? ParishColors.goldAccent : ParishColors.marianBlue,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Officiant Row
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Icon(Icons.person_outline, size: 16, color: ParishColors.marianBlueAdaptive),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 12.5, color: textColorDark),
                        children: [
                          TextSpan(text: 'Presider: ', style: TextStyle(fontWeight: FontWeight.bold, color: textColorMuted)),
                          TextSpan(text: resolvedOfficiant, style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: ParishColors.marianBlue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Close', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}