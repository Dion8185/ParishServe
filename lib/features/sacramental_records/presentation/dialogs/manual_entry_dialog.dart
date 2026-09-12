import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/widgets/dialog_text_field.dart';

void showManualEntryModal(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('New Sacramental Entry', style: TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ParishDialogTextField(label: 'Sacrament Type', hint: 'Baptism / Matrimony / Confirmation'),
            const ParishDialogTextField(label: 'Full Name of Subject', hint: 'First, Middle, Last Name'),
            const ParishDialogTextField(label: 'Book & Page Reference', hint: 'e.g., Book 12, Page 45, Entry 02'),
            const ParishDialogTextField(label: 'Parents / Witnesses', hint: 'Names separated by comma'),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Discard')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: ParishColors.marianBlue,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Save Record'),
        ),
      ],
    ),
  );
}