import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';

void showTermsAndConditionsModal(BuildContext context, {bool isReadOnly = true, VoidCallback? onAccepted}) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _TermsAndConditionsDialog(
      isReadOnly: isReadOnly,
      onAccepted: onAccepted,
    ),
  );
}

class _TermsAndConditionsDialog extends StatelessWidget {
  final bool isReadOnly;
  final VoidCallback? onAccepted;

  const _TermsAndConditionsDialog({
    required this.isReadOnly,
    this.onAccepted,
  });

  @override
  Widget build(BuildContext context) {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final cardWhite = ParishColors.cardWhite;
    final borderGrey = ParishColors.borderGrey;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: cardWhite,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: double.maxFinite,
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
        child: Column(
          children: [
            // Header Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: BoxDecoration(
                color: ParishColors.marianBlueSurface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: borderGrey)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: ParishColors.marianBlue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.gavel_outlined, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Terms of Service & Data Privacy Policy',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textDark),
                        ),
                        Text(
                          'St. John Paul II Parish • Diocese of San Pablo',
                          style: TextStyle(fontSize: 12, color: textMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Scrollable Legal Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('1. Acceptance of Terms & Digital Companion Status'),
                    _buildParagraph(
                      'Welcome to ParishServe, the official digital administrative platform of St. John Paul II Parish (Labuin, Sta. Cruz, Laguna, Diocese of San Pablo). By creating an account or accessing this portal, you agree to comply with and be bound by these Terms and Conditions. In accordance with the Code of Canon Law (Can. 535), ParishServe operates strictly as an administrative, indexing, and pastoral retrieval companion. It does not replace physical, handwritten sacramental registry books or official Diocesan archives. All legal and canonical validity remains tied to physical volumes, ink signatures, and embossed parish dry seals.',
                    ),
                    const SizedBox(height: 16),

                    _buildSectionHeader('2. Data Privacy Act of 2012 (RA 10173) Compliance'),
                    _buildParagraph(
                      'We respect your fundamental right to privacy. In compliance with Republic Act No. 10173 (Data Privacy Act of 2012), personal data collected through ParishServe—including full legal names, contact numbers, email addresses, and valid government identification documents—is processed solely for legitimate ecclesiastical administration, sacrament scheduling, pastoral communication, and canonical record-keeping.',
                    ),
                    const SizedBox(height: 16),

                    _buildSectionHeader('3. Sacramental Records & Canonical Stewardship'),
                    _buildParagraph(
                      'Sacramental information entered into or retrieved through ParishServe (Baptism, Confirmation, Matrimony, Death, and Conversion registers) is governed by ecclesiastical secrecy and canonical record-keeping standards. Unauthorized extraction, duplication, or dissemination of sacramental register data is strictly prohibited and subject to canonical and civil penalties.',
                    ),
                    const SizedBox(height: 16),

                    _buildSectionHeader('4. User Account Governance & Security'),
                    _buildParagraph(
                      'Parishioner and staff accounts are safeguarded through Row-Level Security (RLS) and encrypted database tokens. You are responsible for maintaining the confidentiality of your password and account credentials. Open public registration is restricted; accounts must be verified via secure 6-digit email OTP. The parish administration reserves the right to deactivate accounts violating security protocols.',
                    ),
                    const SizedBox(height: 16),

                    _buildSectionHeader('5. Service Appointments & Financial Offerings'),
                    _buildParagraph(
                      'Service bookings and Mass intentions submitted through the portal are subject to pastoral review, operating hours (Tuesday–Sunday), and liturgical law restrictions (e.g., restricted Solemnities and Monday clerical rest days). Financial transactions recorded via cash or official GCash transfers represent voluntary offerings and service stipends; ParishServe does not process commercial online payments or charge gateway fees.',
                    ),
                    const SizedBox(height: 16),

                    _buildSectionHeader('6. Amendments & Jurisdiction'),
                    _buildParagraph(
                      'St. John Paul II Parish reserves the right to modify these terms at any time to align with updated Diocesan policies or civil statutes. Continued use of ParishServe constitutes your acceptance of such modifications. Any disputes arising from the use of this system shall be settled under the ecclesiastical jurisdiction of the Diocese of San Pablo.',
                    ),
                  ],
                ),
              ),
            ),

            // Modal Action Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: cardWhite,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                border: Border(top: BorderSide(color: borderGrey)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Close', style: TextStyle(fontSize: 14, color: textMuted, fontWeight: FontWeight.bold)),
                  ),
                  if (!isReadOnly) ...[
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ParishColors.marianBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        onAccepted?.call();
                      },
                      child: const Text('I Agree & Accept', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: ParishColors.marianBlue,
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          color: ParishColors.textDark,
          height: 1.45,
        ),
      ),
    );
  }
}