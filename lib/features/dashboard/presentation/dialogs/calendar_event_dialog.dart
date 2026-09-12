import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';

void showCalendarEventModal(BuildContext context, {required String date, required String eventTitle}) {
  final textColorMuted = ParishColors.textMuted;
  final textColorDark = ParishColors.textDark;

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.event, color: ParishColors.goldAccent, size: 28),
          const SizedBox(width: 10),
          Expanded(child: Text(date, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
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
                Text('Scheduled Activity', style: TextStyle(fontSize: 12, color: textColorMuted)),
                Text(eventTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ParishColors.marianBlue)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 18, color: textColorMuted),
              const SizedBox(width: 6),
              Text('Venue: Main Church Altar', style: TextStyle(fontSize: 14, color: textColorDark)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.person_outline, size: 18, color: textColorMuted),
              const SizedBox(width: 6),
              Text('Officiant: Rev. Fr. Parish Priest', style: TextStyle(fontSize: 14, color: textColorDark)),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Close', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ParishColors.marianBlue)),
        ),
      ],
    ),
  );
}