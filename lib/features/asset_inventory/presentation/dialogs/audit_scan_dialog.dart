import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';

void showAuditScanModal(BuildContext context) {
  final textColorMuted = ParishColors.textMuted;

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Asset Audit Scanner', style: TextStyle(fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 140,
            width: double.infinity,
            decoration: BoxDecoration(
              color: ParishColors.marianBlueSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ParishColors.marianBlue, width: 2),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.nfc, size: 50, color: ParishColors.marianBlue),
                SizedBox(height: 8),
                Text('Scan Property QR or Wave NFC Tag', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text('Hold device within 4 cm of asset label.', style: TextStyle(fontSize: 12, color: textColorMuted)),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: ParishColors.marianBlue, foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Simulate Scan Result'),
        ),
      ],
    ),
  );
}