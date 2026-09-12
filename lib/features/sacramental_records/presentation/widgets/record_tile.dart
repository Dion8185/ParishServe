import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../dialogs/certificate_preview_dialog.dart';

class RecordTile extends StatelessWidget {
  final String name;
  final String sacrament;
  final String bookRef;
  final String date;

  const RecordTile({
    super.key,
    required this.name,
    required this.sacrament,
    required this.bookRef,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ParishColors.borderGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: ParishColors.marianBlueSurface,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  sacrament,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: ParishColors.marianBlue,
                  ),
                ),
              ),
              Icon(Icons.qr_code_2, size: 26, color: ParishColors.textMuted),
            ],
          ),
          const SizedBox(height: 8),
          Text(name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
          const SizedBox(height: 2),
          Text(bookRef, style: TextStyle(fontSize: 14, color: ParishColors.textMuted)),
          Text(date, style: TextStyle(fontSize: 14, color: ParishColors.textMuted)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: ParishColors.goldLight,
                foregroundColor: ParishColors.textDark,
                elevation: 0,
                side: const BorderSide(color: ParishColors.goldAccent, width: 1.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => showCertificatePreviewModal(
                context,
                name: name,
                sacrament: sacrament,
                bookRef: bookRef,
              ),
              icon: Icon(Icons.print, size: 20, color: ParishColors.textDark),
              label: const Text('Generate Official Certificate', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}