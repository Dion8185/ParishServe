import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import 'pages/certificate_template_management_page.dart';
import 'pages/certificate_verification_page.dart';
import 'pages/sacrament_registry_page.dart';

class SacramentalRecordsView extends StatelessWidget {
  const SacramentalRecordsView({super.key});

  @override
  Widget build(BuildContext context) {
    final cardWhiteColor = ParishColors.cardWhite;
    final textDarkColor = ParishColors.textDark;
    final textMutedColor = ParishColors.textMuted;
    final marianBlueColor = ParishColors.marianBlue;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth >= 850;
        final bool isVeryWide = constraints.maxWidth >= 1200;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isDesktop ? 28 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Title Header & Subtitle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sacramental Records',
                          style: TextStyle(
                            fontSize: isDesktop ? 26 : 22,
                            fontWeight: FontWeight.bold,
                            color: textDarkColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Canonical Registers (Canon 535) • Search, scan, record entries & issue certificates',
                          style: TextStyle(color: textMutedColor, fontSize: 13.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Quick Action Shortcut Buttons Toolbar
              _buildQuickActionButtons(context, isDesktop),
              const SizedBox(height: 18),

              // Search Bar Across All Books
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: cardWhiteColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: marianBlueColor.withValues(alpha: 0.5), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, size: 26, color: marianBlueColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Search by Name, Year, or Reference across all canonical registers...',
                        style: TextStyle(fontSize: 14, color: textMutedColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Section Title Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Canonical Register Ledgers',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textDarkColor,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: ParishColors.marianBlueSurface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '6 Canonical Volumes',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: marianBlueColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Responsive Books View: Multi-column Grid on Desktop, Single-column List on Mobile
              if (isDesktop)
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: isVeryWide ? 3 : 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: isVeryWide ? 2.5 : 2.7,
                  children: _buildAllSacramentCards(context),
                )
              else
                Column(
                  children: _buildAllSacramentCards(context)
                      .map((card) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: card,
                  ))
                      .toList(),
                ),
            ],
          ),
        );
      },
    );
  }

  // ===========================================================================
  // Quick Action Shortcut Buttons Toolbar
  // ===========================================================================
  Widget _buildQuickActionButtons(BuildContext context, bool isDesktop) {
    final buttons = [
      Expanded(
        child: SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: ParishColors.marianBlue,
              foregroundColor: Colors.white,
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CertificateTemplateManagementPage()),
              );
            },
            icon: const Icon(Icons.design_services_outlined, size: 18),
            label: const Text(
              'Certificate Templates Studio',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: ParishColors.goldAccent, width: 1.5),
              foregroundColor: ParishColors.goldAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CertificateVerificationPage()),
              );
            },
            icon: const Icon(Icons.qr_code_scanner, size: 18),
            label: const Text(
              'QR Verification Portal',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    ];

    if (isDesktop) {
      return Row(children: buttons);
    }

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: ParishColors.marianBlue,
              foregroundColor: Colors.white,
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CertificateTemplateManagementPage()),
              );
            },
            icon: const Icon(Icons.design_services_outlined, size: 18),
            label: const Text(
              'Certificate Templates Studio',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: ParishColors.goldAccent, width: 1.5),
              foregroundColor: ParishColors.goldAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CertificateVerificationPage()),
              );
            },
            icon: const Icon(Icons.qr_code_scanner, size: 18),
            label: const Text(
              'QR Verification Portal',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // Ledger Card Collection
  // ===========================================================================
  List<Widget> _buildAllSacramentCards(BuildContext context) {
    return [
      // 1. Baptism Card (Water Blue)
      _buildSacramentSelectionCard(
        context: context,
        title: 'Baptism Records',
        subtitle: 'Books 1 to 14 • 3,420 Baptized Christians',
        icon: Icons.water_drop,
        themeColor: const Color(0xFF164E87),
        surfaceColor: const Color(0xFFEDF4FB),
        sacramentName: 'Baptism',
        ledgerSubtitle: 'Liber Baptismorum • Canonical Books',
      ),

      // 2. Confirmation Card (Pentecost Red)
      _buildSacramentSelectionCard(
        context: context,
        title: 'Confirmation Records',
        subtitle: 'Books 1 to 6 • 1,840 Confirmands',
        icon: Icons.local_fire_department,
        themeColor: const Color(0xFFB91C1C),
        surfaceColor: const Color(0xFFFDF2F2),
        sacramentName: 'Confirmation',
        ledgerSubtitle: 'Liber Confirmatorum • Canonical Books',
      ),

      // 3. First Communion Card (Eucharistic Gold)
      _buildSacramentSelectionCard(
        context: context,
        title: 'First Communion Records',
        subtitle: 'Books 1 to 5 • 2,110 Communicants',
        icon: Icons.restaurant,
        themeColor: const Color(0xFFD49B18),
        surfaceColor: const Color(0xFFFFF7E6),
        sacramentName: 'First Communion',
        ledgerSubtitle: 'Liber Primae Communionis • Canonical Books',
      ),

      // 4. Matrimony Card (Royal Burgundy / Amethyst)
      _buildSacramentSelectionCard(
        context: context,
        title: 'Matrimony Records',
        subtitle: 'Books 1 to 8 • 920 Contracted Marriages',
        icon: Icons.favorite,
        themeColor: const Color(0xFF9D174D),
        surfaceColor: const Color(0xFFFCE7F3),
        sacramentName: 'Matrimony',
        ledgerSubtitle: 'Liber Matrimoniorum • Canonical Books',
      ),

      // 5. Death / Burial Card (Solemn Violet)
      _buildSacramentSelectionCard(
        context: context,
        title: 'Death & Burial Records',
        subtitle: 'Books 1 to 7 • 1,450 Registered Deceased',
        icon: Icons.church,
        themeColor: const Color(0xFF6B21A8),
        surfaceColor: const Color(0xFFF3E8FF),
        sacramentName: 'Death',
        ledgerSubtitle: 'Liber Defunctorum • Canonical Books',
      ),

      // 6. Conversion Card (Olive Green)
      _buildSacramentSelectionCard(
        context: context,
        title: 'Conversion Records',
        subtitle: 'Book 1 • 84 Professions of Faith',
        icon: Icons.eco,
        themeColor: const Color(0xFF2D6A4F),
        surfaceColor: const Color(0xFFEDF7F2),
        sacramentName: 'Conversion',
        ledgerSubtitle: 'Liber Conversorum • Reception into Full Communion',
      ),
    ];
  }

  Widget _buildSacramentSelectionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color themeColor,
    required Color surfaceColor,
    required String sacramentName,
    required String ledgerSubtitle,
  }) {
    final cardWhiteColor = ParishColors.cardWhite;
    final textDarkColor = ParishColors.textDark;
    final textMutedColor = ParishColors.textMuted;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SacramentRegistryPage(
              sacramentName: sacramentName,
              ledgerSubtitle: ledgerSubtitle,
              icon: icon,
              themeColor: themeColor,
              surfaceColor: surfaceColor,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cardWhiteColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: themeColor.withValues(alpha: 0.35), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: themeColor.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Distinct Icon Badge
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: themeColor.withValues(alpha: 0.5), width: 1.2),
              ),
              child: Icon(icon, color: themeColor, size: 28),
            ),
            const SizedBox(width: 16),

            // Title & Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.bold,
                      color: textDarkColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12.5, color: textMutedColor),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            Icon(Icons.arrow_forward_ios, size: 16, color: themeColor),
          ],
        ),
      ),
    );
  }
}