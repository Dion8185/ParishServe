import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/widgets/dialog_text_field.dart';

void showNewTransactionModal(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Record Ecclesiastical Receipt', style: TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ParishDialogTextField(label: 'Payer / Requester', hint: 'e.g., Maria Santos'),
            const ParishDialogTextField(label: 'Transaction Purpose', hint: 'Mass Intention / Certificate / Donation'),
            const ParishDialogTextField(label: 'Amount Received (PHP)', hint: '₱ 0.00'),
            const ParishDialogTextField(label: 'Auto Generated Receipt #', hint: 'REC-2026-00893', enabled: false),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: ParishColors.oliveGreen,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Issue Receipt'),
        ),
      ],
    ),
  );
}