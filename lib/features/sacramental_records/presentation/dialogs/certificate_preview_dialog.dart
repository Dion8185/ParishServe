import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';

void showCertificatePreviewModal(
    BuildContext context, {
      required String name,
      required String sacrament,
      required String bookRef,
    }) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Certificate Preview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
        ],
      ),
      content: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ParishColors.cardWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ParishColors.goldAccent, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shield_outlined, size: 40, color: ParishColors.marianBlue),
            const SizedBox(height: 6),
            const Text(
              'PAROCHIA SANCTI IOANNIS PAULI II',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.8),
            ),
            const Text('Diocese of San Pablo', style: TextStyle(fontSize: 11, color: ParishColors.textMuted)),
            const Divider(height: 20),
            Text('CERTIFICATE OF $sacrament', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: ParishColors.marianBlue)),
            const SizedBox(height: 4),
            Text(bookRef, style: const TextStyle(fontSize: 12, color: ParishColors.textMuted)),
            const SizedBox(height: 14),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                border: Border.all(color: ParishColors.borderGrey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.qr_code_2, size: 70, color: ParishColors.textDark),
            ),
            const SizedBox(height: 6),
            const Text('QR Code for Parish Verification', style: TextStyle(fontSize: 10, color: ParishColors.textMuted)),
          ],
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: ParishColors.goldAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            icon: const Icon(Icons.print),
            label: const Text('Print Official Certificate', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    ),
  );
}