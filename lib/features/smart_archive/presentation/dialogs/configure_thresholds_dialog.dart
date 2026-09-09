import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/widgets/dialog_text_field.dart';

void showConfigureThresholdsModal(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Configure Safe Limits', style: TextStyle(fontWeight: FontWeight.bold)),
      content: const SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Set safe environmental thresholds for document preservation:', style: TextStyle(fontSize: 13, color: ParishColors.textMuted)),
            SizedBox(height: 14),
            ParishDialogTextField(label: 'Max Relative Humidity (%)', hint: '60 % (Standard Canonical Archive)'),
            ParishDialogTextField(label: 'Max Ambient Temperature (°C)', hint: '26 °C'),
            ParishDialogTextField(label: 'Telemetry Polling Interval (Sec)', hint: '60 seconds'),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: ParishColors.marianBlue,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Save Parameters'),
        ),
      ],
    ),
  );
}