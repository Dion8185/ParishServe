import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';

void showNotificationModal(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.notifications_active, color: ParishColors.marianBlue, size: 28),
          SizedBox(width: 10),
          Text('Parish Alerts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildNotificationItem(
              icon: Icons.warning_amber_rounded,
              iconColor: ParishColors.mercyRed,
              title: 'Archive Humidity Alert (68%)',
              time: '15 mins ago',
              description: 'Vessel Storage node exceeded 60% relative humidity limit.',
            ),
            const Divider(),
            _buildNotificationItem(
              icon: Icons.assignment_late_outlined,
              iconColor: ParishColors.goldAccent,
              title: 'Priest Approval Required',
              time: '1 hour ago',
              description: 'Baptismal certificate for Juan Dela Cruz awaits review.',
            ),
            const Divider(),
            _buildNotificationItem(
              icon: Icons.calendar_today,
              iconColor: ParishColors.marianBlue,
              title: 'Upcoming Nuptial Mass',
              time: 'Tomorrow, 10:00 AM',
              description: 'Santos-Ramos Wedding scheduled at Main Altar.',
            ),
          ],
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ParishColors.marianBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Dismiss', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    ),
  );
}

Widget _buildNotificationItem({
  required IconData icon,
  required Color iconColor,
  required String title,
  required String time,
  required String description,
}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: iconColor, size: 26),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(time, style: const TextStyle(fontSize: 11, color: ParishColors.textMuted)),
              ],
            ),
            const SizedBox(height: 2),
            Text(description, style: const TextStyle(fontSize: 12, color: ParishColors.textMuted)),
          ],
        ),
      ),
    ],
  );
}