import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/widgets/dialog_text_field.dart';

void showScheduleAppointmentModal(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Schedule Parish Service', style: TextStyle(fontWeight: FontWeight.bold)),
      content: const SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ParishDialogTextField(label: 'Service Requested', hint: 'Baptism, Wedding, Sick Call'),
            ParishDialogTextField(label: 'Requester Name', hint: 'Full Name'),
            ParishDialogTextField(label: 'Contact Number', hint: '09XX-XXX-XXXX'),
            ParishDialogTextField(label: 'Preferred Date & Time', hint: 'e.g., Sep 18, 2026 - 10:00 AM'),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: ParishColors.goldAccent,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Confirm Schedule'),
        ),
      ],
    ),
  );
}