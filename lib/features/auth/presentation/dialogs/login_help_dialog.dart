import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';

void showLoginHelpDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Row(
        children: [
          Icon(Icons.support_agent, color: ParishColors.marianBlue, size: 28),
          SizedBox(width: 8),
          Text('Staff Assistance', style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'If you forgot your password or require role access:',
            style: TextStyle(fontSize: 14, color: ParishColors.textDark),
          ),
          SizedBox(height: 12),
          Text(
            '• Approach the Parish Priest or Parish Technical Staff.\n• Passwords can be reset directly at the Parish Secretariat terminal.',
            style: TextStyle(fontSize: 13, color: ParishColors.textMuted),
          ),
        ],
      ),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: ParishColors.marianBlue,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Understood'),
        ),
      ],
    ),
  );
}