import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';

void showOcrScanModal(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.document_scanner, color: ParishColors.marianBlue, size: 28),
          SizedBox(width: 10),
          Text('AI OCR Document Scan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              color: ParishColors.backgroundLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ParishColors.marianBlue, width: 1.5),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.camera_alt_outlined, size: 48, color: ParishColors.marianBlue),
                SizedBox(height: 8),
                Text('Align ledger record inside frame', style: TextStyle(color: ParishColors.textMuted, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ParishColors.oliveGreenSurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: ParishColors.oliveGreen, size: 22),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'AI Match Confidence: 98.4%\nAutomated book/page extraction ready.',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ParishColors.oliveGreen),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel', style: TextStyle(fontSize: 16, color: ParishColors.textMuted)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: ParishColors.marianBlue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Extract & Digitize', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}