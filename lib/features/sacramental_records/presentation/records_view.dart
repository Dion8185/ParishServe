import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import 'dialogs/ocr_scan_dialog.dart';
import 'dialogs/manual_entry_dialog.dart';
import 'widgets/record_tile.dart';

class SacramentalRecordsView extends StatelessWidget {
  const SacramentalRecordsView({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sacramental Records', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
          Text('Search registry or digitize manual books', style: TextStyle(color: ParishColors.textMuted)),
          const SizedBox(height: 18),

          Container(
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: ParishColors.cardWhite,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ParishColors.marianBlue, width: 1.8),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, size: 28, color: ParishColors.marianBlue),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Search by Name, Year, or Book #...',
                    style: TextStyle(fontSize: 16, color: ParishColors.textMuted),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ParishColors.marianBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => showOcrScanModal(context),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('AI OCR Scan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: ParishColors.marianBlue, width: 1.8),
                      foregroundColor: ParishColors.marianBlue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => showManualEntryModal(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Manual Entry', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Text('Recent Sacramental Logs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
          const SizedBox(height: 12),

          RecordTile(
            name: 'Juan Miguel Dela Cruz',
            sacrament: 'BAPTISM',
            bookRef: 'Book 12, Page 143, Entry #04',
            date: 'Baptized: Oct 14, 2021',
          ),
          RecordTile(
            name: 'Carlos Santos & Maria Ramos',
            sacrament: 'MATRIMONY',
            bookRef: 'Book 06, Page 52, Entry #01',
            date: 'Married: Feb 18, 2023',
          ),
          RecordTile(
            name: 'Gabriel Morales',
            sacrament: 'CONFIRMATION',
            bookRef: 'Book 04, Page 88, Entry #19',
            date: 'Confirmed: Dec 08, 2022',
          ),
        ],
      ),
    );
  }
}