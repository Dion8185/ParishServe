import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../dialogs/certificate_preview_dialog.dart';
import '../dialogs/manual_entry_dialog.dart';
import '../dialogs/ocr_scan_dialog.dart';

class SacramentRegistryPage extends StatelessWidget {
  final String sacramentName;
  final String ledgerSubtitle;
  final IconData icon;
  final Color themeColor;
  final Color surfaceColor;

  const SacramentRegistryPage({
    super.key,
    required this.sacramentName,
    required this.ledgerSubtitle,
    required this.icon,
    required this.themeColor,
    required this.surfaceColor,
  });

  @override
  Widget build(BuildContext context) {
    final cardWhiteColor = ParishColors.cardWhite;
    final borderGreyColor = ParishColors.borderGrey;
    final textDarkColor = ParishColors.textDark;
    final textMutedColor = ParishColors.textMuted;

    return Scaffold(
      backgroundColor: ParishColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: cardWhiteColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: themeColor, size: 26),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$sacramentName Registry',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDarkColor),
            ),
            Text(
              ledgerSubtitle,
              style: TextStyle(fontSize: 12, color: textMutedColor),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ledger Volume Status Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: themeColor.withValues(alpha: 0.4), width: 1.5),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: themeColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$sacramentName Canonical Books',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: themeColor),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Digitized registry companion • St. John Paul II Parish',
                          style: TextStyle(fontSize: 12, color: textMutedColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // MOVED HERE: AI OCR Scan & Manual Entry Action Buttons
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeColor,
                        foregroundColor: Colors.white,
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => showOcrScanModal(context),
                      icon: const Icon(Icons.document_scanner, size: 22),
                      label: const Text('AI OCR Scan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: themeColor, width: 1.8),
                        foregroundColor: themeColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => showManualEntryModal(context),
                      icon: const Icon(Icons.add, size: 22),
                      label: const Text('Manual Entry', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Specific Ledger Search Bar
            Container(
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: cardWhiteColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderGreyColor),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, size: 24, color: themeColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Search in $sacramentName books (Name, Year, Entry #)...',
                      style: TextStyle(fontSize: 14, color: textMutedColor),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Records List Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent $sacramentName Records',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDarkColor),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Canon 535',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: themeColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Sample Records with Canonical Marginal Notations
            _buildSacramentRecordCard(
              context: context,
              name: 'Juan Miguel Dela Cruz',
              bookRef: 'Book 12, Page 143, Entry #04',
              dateString: 'Administered: October 14, 2021',
              parentage: 'Parents: Roberto Dela Cruz & Teresa Mendoza',
              sponsors: 'Sponsors: Carlos Ramos (S1) & Elena Santos (S2)',
              marginalNotation: sacramentName == 'Baptism'
                  ? 'Marginal Note: Confirmed at St. John Paul II Parish on Dec 08, 2022 (Book 04, Page 88).'
                  : null,
            ),
            _buildSacramentRecordCard(
              context: context,
              name: 'Angelica Sofia Bautista',
              bookRef: 'Book 12, Page 144, Entry #08',
              dateString: 'Administered: November 22, 2021',
              parentage: 'Parents: Manuel Bautista & Cristina Reyes',
              sponsors: 'Sponsors: Rodrigo Gomez (S1) & Maricel Lim (S2)',
              marginalNotation: null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSacramentRecordCard({
    required BuildContext context,
    required String name,
    required String bookRef,
    required String dateString,
    required String parentage,
    required String sponsors,
    String? marginalNotation,
  }) {
    final cardWhiteColor = ParishColors.cardWhite;
    final borderGreyColor = ParishColors.borderGrey;
    final textDarkColor = ParishColors.textDark;
    final textMutedColor = ParishColors.textMuted;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardWhiteColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderGreyColor),
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
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  sacramentName.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: themeColor,
                  ),
                ),
              ),
              Icon(Icons.qr_code_2, size: 26, color: textMutedColor),
            ],
          ),
          const SizedBox(height: 8),
          Text(name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDarkColor)),
          const SizedBox(height: 2),
          Text(bookRef, style: TextStyle(fontSize: 13, color: textMutedColor)),
          Text(dateString, style: TextStyle(fontSize: 13, color: textMutedColor)),
          const SizedBox(height: 6),
          Text(parentage, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textDarkColor)),
          Text(sponsors, style: TextStyle(fontSize: 12, color: textMutedColor)),

          // Marginal Notation Display (Canonical Requirement)
          if (marginalNotation != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: themeColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.edit_note, size: 18, color: themeColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      marginalNotation,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: themeColor),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: surfaceColor,
                foregroundColor: textDarkColor,
                elevation: 0,
                side: BorderSide(color: themeColor, width: 1.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => showCertificatePreviewModal(
                context,
                name: name,
                sacrament: sacramentName.toUpperCase(),
                bookRef: bookRef,
              ),
              icon: Icon(Icons.print, size: 18, color: themeColor),
              label: Text(
                'Generate Official $sacramentName Certificate',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDarkColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}