// =============================================================================
// FILE: lib/features/sacramental_records/presentation/dialogs/certificate_preview_dialog.dart
// =============================================================================

import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';

void showCertificatePreviewModal(
    BuildContext context, {
      required String name,
      required String sacrament,
      required String bookRef,
    }) {
  final textColorMuted = ParishColors.textMuted;
  final textColorDark = ParishColors.textDark;
  final marianBlue = ParishColors.marianBlue;
  final goldAccent = ParishColors.goldAccent;
  final cardWhite = ParishColors.cardWhite;
  final borderGrey = ParishColors.borderGrey;

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: cardWhite,
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 14, 10),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.visibility_outlined, color: marianBlue, size: 24),
              const SizedBox(width: 10),
              Text(
                'Certificate Preview',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: textColorDark,
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: () => Navigator.pop(ctx),
            icon: const Icon(Icons.close, size: 24),
            tooltip: 'Close Preview',
          ),
        ],
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      content: Container(
        width: double.maxFinite,
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: ParishColors.backgroundLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: goldAccent, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_outlined, size: 44, color: marianBlue),
            const SizedBox(height: 8),
            Text(
              'PAROCHIA SANCTI IOANNIS PAULI II',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 0.8,
                color: textColorDark,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Diocese of San Pablo',
              style: TextStyle(fontSize: 13, color: textColorMuted, fontWeight: FontWeight.w500),
            ),
            const Divider(height: 22),
            Text(
              'CERTIFICATE OF ${sacrament.toUpperCase()}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 0.5,
                color: textColorDark,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 19,
                color: marianBlue,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: cardWhite,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: borderGrey),
              ),
              child: Text(
                bookRef,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColorDark),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: cardWhite,
                border: Border.all(color: borderGrey, width: 1.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.qr_code_2, size: 76, color: textColorDark),
            ),
            const SizedBox(height: 8),
            Text(
              'QR Code for Parish Verification',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColorMuted),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      actions: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: borderGrey, width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Close',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColorMuted),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: goldAccent,
                    foregroundColor: Colors.white,
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.print, size: 20),
                  label: const Text(
                    'Print Certificate',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}