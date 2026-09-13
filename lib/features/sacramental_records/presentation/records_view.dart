import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import 'pages/sacrament_registry_page.dart';

class SacramentalRecordsView extends StatelessWidget {
  const SacramentalRecordsView({super.key});

  @override
  Widget build(BuildContext context) {
    final cardWhiteColor = ParishColors.cardWhite;
    final textDarkColor = ParishColors.textDark;
    final textMutedColor = ParishColors.textMuted;
    final marianBlueColor = ParishColors.marianBlue;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sacramental Records',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textDarkColor),
          ),
          Text(
            'Select a sacramental register to search, scan, or enter entries',
            style: TextStyle(color: textMutedColor),
          ),
          const SizedBox(height: 18),

          // Search Bar
          Container(
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: cardWhiteColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: marianBlueColor, width: 1.8),
            ),
            child: Row(
              children: [
                Icon(Icons.search, size: 28, color: marianBlueColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Search by Name, Year, or Reference across all books...',
                    style: TextStyle(fontSize: 15, color: textMutedColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'Canonical Register Ledgers',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDarkColor),
          ),
          const SizedBox(height: 14),

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
        ],
      ),
    );
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

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: InkWell(
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
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: textDarkColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 13, color: textMutedColor),
                    ),
                  ],
                ),
              ),

              Icon(Icons.arrow_forward_ios, size: 18, color: themeColor),
            ],
          ),
        ),
      ),
    );
  }
}