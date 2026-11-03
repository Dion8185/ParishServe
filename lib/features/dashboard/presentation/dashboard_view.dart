// =============================================================================
// FILE: lib/features/dashboard/presentation/dashboard_view.dart
// =============================================================================

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../appointments/presentation/pages/book_mass_intention_page.dart';
import '../../appointments/presentation/pages/schedule_service_page.dart';
import '../../appointments/services/liturgical_calendar_service.dart';
import '../../asset_inventory/presentation/pages/asset_audit_scanner_page.dart';
import '../../asset_inventory/presentation/pages/asset_batch_print_page.dart';
import '../../auth/models/user_model.dart';
import '../../receipts/presentation/pages/particulars_catalog_page.dart';
import '../../receipts/presentation/pages/pos_cashier_page.dart';
import '../../receipts/presentation/pages/remittance_report_page.dart';
import '../../sacramental_records/presentation/dialogs/ocr_scan_dialog.dart';
import '../../sacramental_records/presentation/dialogs/pabuklat_requests_modal.dart';
import '../../sacramental_records/presentation/pages/baptism_manual_entry_page.dart';
import '../../sacramental_records/presentation/pages/certificate_template_management_page.dart';
import '../../sacramental_records/presentation/pages/confirmation_manual_entry_page.dart';
import '../../sacramental_records/presentation/pages/conversion_manual_entry_page.dart';
import '../../sacramental_records/presentation/pages/death_manual_entry_page.dart';
import '../../sacramental_records/presentation/pages/first_communion_manual_entry_page.dart';
import '../../sacramental_records/presentation/pages/matrimony_manual_entry_page.dart';
import '../../smart_archive/presentation/dialogs/sensor_detail_dialog.dart';
import 'pages/parish_calendar_page.dart';
import 'widgets/daily_readings_card.dart';

class DashboardView extends StatefulWidget {
  final UserModel? currentUser;

  const DashboardView({super.key, this.currentUser});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  DateTime _selectedCalendarDate = DateTime.now();
  final DatabaseReference _rtdbRef = FirebaseDatabase.instance.ref('storage_nodes');

  @override
  void initState() {
    super.initState();
    LiturgicalCalendarService.getCalendarForYear(DateTime.now().year).then((_) {
      if (mounted) setState(() {});
    });
  }

  String _getTimeBasedGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Good morning';
    if (hour >= 12 && hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  String _formatTodayDate() {
    final now = DateTime.now();
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    final dayName = days[now.weekday - 1];
    final monthName = months[now.month - 1];
    return '$dayName, $monthName ${now.day}, ${now.year}';
  }

  // ===========================================================================
  // Quick Record Encoder Modal
  // ===========================================================================
  void _showNewRecordSelector(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: ParishColors.cardWhite,
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 16, 10),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: const BoxDecoration(
                color: ParishColors.marianBlue,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.post_add, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Encode Canonical Record',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: ParishColors.textDark,
                    ),
                  ),
                  Text(
                    'Select parish register book (Canon 535)',
                    style: TextStyle(fontSize: 11, color: ParishColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSacramentPickerTile(
                  title: 'Baptism (Liber Baptismorum)',
                  subtitle: 'Baptisms, lineages, and godparents',
                  icon: Icons.water_drop,
                  color: const Color(0xFF164E87),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BaptismManualEntryPage()),
                    );
                  },
                ),
                _buildSacramentPickerTile(
                  title: 'Confirmation (Liber Confirmatorum)',
                  subtitle: 'Confirmands, chrismation dates & sponsors',
                  icon: Icons.local_fire_department,
                  color: const Color(0xFFB91C1C),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ConfirmationManualEntryPage()),
                    );
                  },
                ),
                _buildSacramentPickerTile(
                  title: 'First Communion (Liber Primae Communionis)',
                  subtitle: 'Eucharistic batch control records',
                  icon: Icons.restaurant,
                  color: const Color(0xFFD49B18),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const FirstCommunionManualEntryPage()),
                    );
                  },
                ),
                _buildSacramentPickerTile(
                  title: 'Matrimony (Liber Matrimoniorum)',
                  subtitle: 'Spouses, witnesses, and marriage license',
                  icon: Icons.favorite,
                  color: const Color(0xFF9D174D),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MatrimonyManualEntryPage()),
                    );
                  },
                ),
                _buildSacramentPickerTile(
                  title: 'Death & Burial (Liber Defunctorum)',
                  subtitle: 'Deceased, cemetery, and Christian burial rites',
                  icon: Icons.church,
                  color: const Color(0xFF6B21A8),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DeathManualEntryPage()),
                    );
                  },
                ),
                _buildSacramentPickerTile(
                  title: 'Conversion (Liber Conversorum)',
                  subtitle: 'Reception into full Catholic communion',
                  icon: Icons.eco,
                  color: const Color(0xFF2D6A4F),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ConversionManualEntryPage()),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: ParishColors.textMuted)),
          ),
        ],
      ),
    );
  }

  Widget _buildSacramentPickerTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: ParishColors.textDark,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11, color: ParishColors.textMuted),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 16, color: color),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // Build Main Screen
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    final textDarkColor = ParishColors.textDark;
    final textMutedColor = ParishColors.textMuted;
    final cardWhiteColor = ParishColors.cardWhite;
    final borderGreyColor = ParishColors.borderGrey;

    final greeting = _getTimeBasedGreeting();
    final displayName = widget.currentUser?.firstName ?? 'Parish Staff';
    final roleDisplay = widget.currentUser?.roleDisplay ?? 'Parish Operations Desk';

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth >= 900;
        final bool isMobile = constraints.maxWidth < 650;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isDesktop ? 26 : (isMobile ? 14 : 18)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Staff Greeting Card
              _buildGreetingBanner(greeting, displayName, roleDisplay, isDesktop),
              const SizedBox(height: 16),

              // 2. Quick Actions Tray (Responsive Action Cards)
              _buildCompactActionLaunchpad(context, isDesktop, isMobile),
              const SizedBox(height: 20),

              // 3. Parish dashboard overview
              Padding(
                padding: const EdgeInsets.only(left: 2, bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 19,
                      decoration: BoxDecoration(
                        color: ParishColors.goldAccent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Text(
                      'PARISH OVERVIEW',
                      style: TextStyle(
                        color: ParishColors.textDark,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.15,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Today at a glance',
                      style: TextStyle(fontSize: 11, color: textMutedColor),
                    ),
                  ],
                ),
              ),
              if (isDesktop) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 11,
                      child: _buildUnifiedCalendarCard(context, isDesktop: true),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      flex: 9,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const DailyReadingsCard(),
                          const SizedBox(height: 18),
                          _buildArchiveTelemetryCard(context),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 11,
                      child: _buildLiturgicalScheduleCard(textDarkColor, borderGreyColor, cardWhiteColor),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      flex: 9,
                      child: _buildOfficeHoursNotice(textDarkColor, textMutedColor, borderGreyColor),
                    ),
                  ],
                ),
              ] else ...[
                const DailyReadingsCard(),
                const SizedBox(height: 18),
                _buildUnifiedCalendarCard(context, isDesktop: false),
                const SizedBox(height: 18),
                _buildArchiveTelemetryCard(context),
                const SizedBox(height: 18),
                _buildLiturgicalScheduleCard(textDarkColor, borderGreyColor, cardWhiteColor),
                const SizedBox(height: 14),
                _buildOfficeHoursNotice(textDarkColor, textMutedColor, borderGreyColor),
              ],

              const SizedBox(height: 28),

              // 4. Institutional Footer
              Center(
                child: Column(
                  children: [
                    const Text(
                      'TOTUS TUUS',
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        fontStyle: FontStyle.italic,
                        color: ParishColors.goldAccent,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'St. John Paul II Parish • Diocese of San Pablo',
                      style: TextStyle(fontSize: 11, color: textMutedColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Greeting Banner
  // ---------------------------------------------------------------------------
  Widget _buildGreetingBanner(String greeting, String displayName, String roleDisplay, bool isDesktop) {
    final initials = displayName.trim().isEmpty
        ? 'S'
        : displayName.trim().split(RegExp(r'\s+')).take(2).map((part) => part[0]).join().toUpperCase();

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF102F52), Color(0xFF174D7A), Color(0xFF236A91)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -42,
              top: -76,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.08), width: 28),
                ),
              ),
            ),
            Positioned(
              right: 95,
              bottom: -100,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ParishColors.goldAccent.withOpacity(0.08),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 28 : 20,
                vertical: isDesktop ? 24 : 20,
              ),
              child: Row(
                children: [
                  Container(
                    width: isDesktop ? 58 : 50,
                    height: isDesktop ? 58 : 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.13),
                      shape: BoxShape.circle,
                      border: Border.all(color: ParishColors.goldAccent.withOpacity(0.8), width: 1.4),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initials,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: isDesktop ? 21 : 18,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFFE5BD63),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 7),
                            const Text(
                              'PARISHSERVE  •  PARISH OPERATIONS',
                              style: TextStyle(
                                color: Color(0xFFD8E7F2),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.25,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Text(
                          '$greeting, $displayName',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isDesktop ? 23 : 19,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.35,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: ParishColors.goldAccent.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: ParishColors.goldAccent.withOpacity(0.55)),
                              ),
                              child: Text(
                                roleDisplay,
                                style: const TextStyle(
                                  color: Color(0xFFFFE7AD),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              _formatTodayDate(),
                              style: const TextStyle(color: Color(0xFFD3E1EB), fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isDesktop) ...[
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: Colors.white.withOpacity(0.14)),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('TOTUS TUUS', style: TextStyle(
                            color: Color(0xFFFFE7AD), fontFamily: 'serif',
                            fontStyle: FontStyle.italic, fontWeight: FontWeight.bold,
                            letterSpacing: 1.2, fontSize: 11,
                          )),
                          SizedBox(height: 2),
                          Text('Serving the parish', style: TextStyle(
                            color: Color(0xFFD3E1EB), fontSize: 9.5,
                          )),
                        ],
                      ),
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

  // ===========================================================================
  // QUICK ACTIONS TRAY (Responsive Action Cards)
  // ===========================================================================
  Widget _buildCompactActionLaunchpad(BuildContext context, bool isDesktop, bool isMobile) {
    final role = widget.currentUser?.userRole.toLowerCase() ?? '';
    final isPriest = role == 'parishpriest';
    final isEncoder = role == 'encoder';
    final isPfc = role == 'pfc';

    final List<_QuickAction> items = [];

    if (isPriest) {
      items.addAll([
        _QuickAction(
          label: 'Pabuklat',
          icon: Icons.draw_outlined,
          color: ParishColors.goldAccent,
          onTap: () => showPabuklatRequestsModal(context),
        ),
        _QuickAction(
          label: 'Mass Slips',
          icon: Icons.volunteer_activism,
          color: ParishColors.marianBlue,
          onTap: () => navigateToBookMassIntentionPage(context),
        ),
        _QuickAction(
          label: 'Schedule',
          icon: Icons.edit_calendar,
          color: ParishColors.oliveGreen,
          onTap: () => navigateToScheduleServicePage(context),
        ),
        _QuickAction(
          label: 'Remittance',
          icon: Icons.assessment_outlined,
          color: const Color(0xFF0F766E),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RemittanceReportPage()),
          ),
        ),
        _QuickAction(
          label: 'Registers',
          icon: Icons.post_add,
          color: const Color(0xFF7C3AED),
          onTap: () => _showNewRecordSelector(context),
        ),
        _QuickAction(
          label: 'Calendar',
          icon: Icons.calendar_month,
          color: const Color(0xFF2563EB),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ParishCalendarPage()),
          ),
        ),
      ]);
    } else if (isEncoder) {
      items.addAll([
        _QuickAction(
          label: 'Encode',
          icon: Icons.post_add,
          color: ParishColors.marianBlue,
          onTap: () => _showNewRecordSelector(context),
        ),
        _QuickAction(
          label: 'AI Scan',
          icon: Icons.document_scanner_outlined,
          color: const Color(0xFF7C3AED),
          onTap: () => showOcrScanModal(context),
        ),
        _QuickAction(
          label: 'Audit Scan',
          icon: Icons.qr_code_scanner,
          color: ParishColors.oliveGreen,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AssetAuditScannerPage()),
          ),
        ),
        _QuickAction(
          label: 'Batch Print',
          icon: Icons.print_outlined,
          color: ParishColors.goldAccent,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AssetBatchPrintPage(availableAssets: []),
            ),
          ),
        ),
      ]);
    } else if (isPfc) {
      items.addAll([
        _QuickAction(
          label: 'Remittance',
          icon: Icons.assessment_outlined,
          color: ParishColors.oliveGreen,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RemittanceReportPage()),
          ),
        ),
        _QuickAction(
          label: 'POS Cashier',
          icon: Icons.point_of_sale,
          color: ParishColors.marianBlue,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PosCashierPage()),
          ),
        ),
        _QuickAction(
          label: 'Particulars',
          icon: Icons.tune,
          color: ParishColors.goldAccent,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ParticularsCatalogPage()),
          ),
        ),
        _QuickAction(
          label: 'Asset Ledger',
          icon: Icons.inventory_2_outlined,
          color: const Color(0xFF0F766E),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AssetAuditScannerPage()),
          ),
        ),
      ]);
    } else {
      // Secretary / Admin (Full Operations Suite)
      items.addAll([
        _QuickAction(
          label: 'POS Cashier',
          icon: Icons.point_of_sale,
          color: ParishColors.oliveGreen,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PosCashierPage()),
          ),
        ),
        _QuickAction(
          label: 'Pabuklat',
          icon: Icons.folder_shared_outlined,
          color: ParishColors.marianBlue,
          onTap: () => showPabuklatRequestsModal(context),
        ),
        _QuickAction(
          label: 'Schedule',
          icon: Icons.edit_calendar,
          color: const Color(0xFF2563EB),
          onTap: () => navigateToScheduleServicePage(context),
        ),
        _QuickAction(
          label: 'Mass Intention',
          icon: Icons.volunteer_activism,
          color: ParishColors.goldAccent,
          onTap: () => navigateToBookMassIntentionPage(context),
        ),
        _QuickAction(
          label: 'Encode',
          icon: Icons.post_add,
          color: const Color(0xFF7C3AED),
          onTap: () => _showNewRecordSelector(context),
        ),
        _QuickAction(
          label: 'Audit Scan',
          icon: Icons.qr_code_scanner,
          color: const Color(0xFF0F766E),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AssetAuditScannerPage()),
          ),
        ),
        _QuickAction(
          label: 'Remittance',
          icon: Icons.assessment_outlined,
          color: const Color(0xFFB91C1C),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RemittanceReportPage()),
          ),
        ),
        _QuickAction(
          label: 'Studio',
          icon: Icons.design_services_outlined,
          color: const Color(0xFF1E3A5F),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CertificateTemplateManagementPage()),
          ),
        ),
      ]);
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(isDesktop ? 18 : 14, 16, isDesktop ? 18 : 14, 16),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ParishColors.borderGrey),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: ParishColors.marianBlueSurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.bolt_rounded, size: 18, color: ParishColors.marianBlue),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: ParishColors.textDark,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: ParishColors.backgroundLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: ParishColors.borderGrey),
                ),
                child: Text(
                  'Tap to launch',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: ParishColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Responsive card grid
          LayoutBuilder(
            builder: (context, c) {
              const gap = 10.0;
              final w = c.maxWidth;

              int cols = w >= 760 ? 4 : (w >= 480 ? 3 : 2);
              // Avoid orphan rows (e.g. 4 items in 3 cols, 6 items in 4 cols)
              if (cols == 3 && items.length % 3 != 0) cols = 2;
              if (cols == 4 && items.length % 4 != 0 && items.length % 3 == 0) cols = 3;

              final tileWidth = ((w - gap * (cols - 1)) / cols).floorToDouble();

              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: items
                    .map((a) => SizedBox(
                  width: tileWidth,
                  child: _QuickActionTile(action: a, showArrow: isDesktop),
                ))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // UNIFIED CALENDAR CARD (Grid + Integrated Date Inspector Footer)
  // ===========================================================================
  Widget _buildUnifiedCalendarCard(BuildContext context, {required bool isDesktop}) {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
    final totalDays = lastDayOfMonth.day;
    final offset = firstDayOfMonth.weekday % 7;
    final totalGridCells = ((totalDays + offset) / 7).ceil() * 7;
    final daysOfWeek = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    final d = _selectedCalendarDate;
    final feasts = LiturgicalCalendarService.getCelebrationsForDateSync(d);
    final isMonday = d.weekday == DateTime.monday;
    final isTuesday = d.weekday == DateTime.tuesday;
    final dateStr = '${_getMonthName(d.month)} ${d.day}, ${d.year}';

    return Container(
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ParishColors.borderGrey),
        boxShadow: [
          BoxShadow(color: const Color(0xFF18334D).withOpacity(0.05), blurRadius: 18, offset: const Offset(0, 7)),
        ],
      ),
      child: Column(
        children: [
          // 1. Calendar Header Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Parish Event Calendar',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                        color: ParishColors.textDark,
                      ),
                    ),
                    Text(
                      'Liturgical feasts & parish activities',
                      style: TextStyle(fontSize: 11.5, color: ParishColors.textMuted),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ParishCalendarPage()),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: ParishColors.marianBlueSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: ParishColors.marianBlue.withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_month, size: 14, color: ParishColors.marianBlue),
                        SizedBox(width: 5),
                        Text(
                          'Full View',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: ParishColors.marianBlue,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // 2. Day of Week Header & Month Grid
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: daysOfWeek
                      .map((day) => SizedBox(
                    width: 32,
                    child: Text(
                      day,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: day == 'M' ? const Color(0xFF94A3B8) : ParishColors.marianBlue,
                        fontSize: 12.5,
                      ),
                    ),
                  ))
                      .toList(),
                ),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: totalGridCells,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 5,
                    crossAxisSpacing: 5,
                    childAspectRatio: isDesktop ? 1.35 : 1.05,
                  ),
                  itemBuilder: (context, index) {
                    final dayNumber = index - offset + 1;
                    if (dayNumber < 1 || dayNumber > totalDays) {
                      return const SizedBox.shrink();
                    }

                    final cellDate = DateTime(now.year, now.month, dayNumber);
                    final cellFeasts = LiturgicalCalendarService.getCelebrationsForDateSync(cellDate);
                    final hasFeast = cellFeasts.isNotEmpty;
                    final isToday = dayNumber == now.day;
                    final isSelected = cellDate.day == _selectedCalendarDate.day &&
                        cellDate.month == _selectedCalendarDate.month;
                    final isCellMonday = cellDate.weekday == DateTime.monday;

                    return InkWell(
                      onTap: () {
                        setState(() => _selectedCalendarDate = cellDate);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? ParishColors.marianBlue
                              : (isToday
                              ? ParishColors.marianBlueSurface
                              : (hasFeast ? cellFeasts.first.liturgicalColor.withOpacity(0.12) : Colors.transparent)),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? ParishColors.marianBlue
                                : (isToday
                                ? ParishColors.marianBlue
                                : (hasFeast ? cellFeasts.first.liturgicalColor : Colors.transparent)),
                            width: isSelected || isToday ? 1.6 : 1.0,
                          ),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Text(
                              '$dayNumber',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: (hasFeast || isToday || isSelected)
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? Colors.white
                                    : (isCellMonday
                                    ? const Color(0xFF94A3B8)
                                    : (hasFeast ? ParishColors.textDark : ParishColors.textMuted)),
                              ),
                            ),
                            if (hasFeast && !isSelected)
                              Positioned(
                                bottom: 3,
                                child: Container(
                                  width: 4.5,
                                  height: 4.5,
                                  decoration: BoxDecoration(
                                    color: cellFeasts.first.liturgicalColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // 3. Compact Date Inspector Footer (Seamlessly embedded)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: ParishColors.backgroundLight,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
              border: Border(top: BorderSide(color: ParishColors.borderGrey.withOpacity(0.6))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.event, size: 14, color: ParishColors.marianBlue),
                          const SizedBox(width: 5),
                          Text(
                            dateStr,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: ParishColors.textDark,
                            ),
                          ),
                          if (isMonday) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Text('REST DAY', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      if (feasts.isNotEmpty)
                        Text(
                          '${feasts.first.name} (${feasts.first.gradeName})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: feasts.first.liturgicalColor,
                          ),
                        )
                      else
                        Text(
                          isMonday
                              ? 'Office closed for Clergy Rest Day'
                              : (isTuesday ? 'Office open (Tuesday approval required)' : 'Office open (8:00 AM – 5:00 PM)'),
                          style: TextStyle(fontSize: 11, color: ParishColors.textMuted),
                        ),
                    ],
                  ),
                ),
                if (!isMonday)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ParishColors.marianBlue,
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => navigateToScheduleServicePage(
                      context,
                      initialDate: _selectedCalendarDate,
                    ),
                    icon: const Icon(Icons.add_task, size: 14),
                    label: const Text('Book', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Smart Archive Telemetry
  // ---------------------------------------------------------------------------
  Widget _buildArchiveTelemetryCard(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: _rtdbRef.onValue,
      builder: (context, snapshot) {
        double temp = 24.2;
        double hum = 54.0;
        bool isWarning = false;
        String nodeId = 'ESP32-NODE-01';

        if (snapshot.hasData && snapshot.data?.snapshot.value != null) {
          final raw = snapshot.data!.snapshot.value;
          if (raw is Map && raw.isNotEmpty) {
            final firstNode = raw.values.first;
            if (firstNode is Map) {
              temp = double.tryParse(firstNode['temperature']?.toString() ?? '24.2') ?? 24.2;
              hum = double.tryParse(firstNode['humidity']?.toString() ?? '54.0') ?? 54.0;
              nodeId = firstNode['node_id']?.toString() ?? 'ESP32-NODE-01';
              isWarning = hum > 60.0 || temp > 26.0;
            }
          }
        }

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => showSensorDetailModal(
              context,
              roomTitle: 'Sacramental Archive Room',
              nodeId: nodeId,
              temperature: '${temp.toStringAsFixed(1)} °C',
              humidity: '${hum.toStringAsFixed(1)} %',
              isWarning: isWarning,
            ),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: ParishColors.cardWhite,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isWarning ? ParishColors.mercyRed.withOpacity(0.55) : ParishColors.borderGrey,
                ),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF18334D).withOpacity(0.055), blurRadius: 18, offset: const Offset(0, 7)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: ParishColors.marianBlueSurface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.sensors_rounded, color: ParishColors.marianBlue, size: 20),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Environmental monitoring', style: TextStyle(fontSize: 10.5, color: ParishColors.textMuted)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                        decoration: BoxDecoration(
                          color: isWarning ? ParishColors.mercyRedSurface : ParishColors.oliveGreenSurface,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle, size: 6, color: isWarning ? ParishColors.mercyRed : ParishColors.oliveGreen),
                            const SizedBox(width: 5),
                            Text(
                              isWarning ? 'Attention' : 'Within range',
                              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: isWarning ? ParishColors.mercyRed : ParishColors.oliveGreen),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 17),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTelemetryMetric(
                          icon: Icons.thermostat_rounded,
                          label: 'Temperature',
                          value: '${temp.toStringAsFixed(1)}°',
                          unit: 'C',
                          color: ParishColors.goldAccent,
                          progress: (temp / 40).clamp(0.0, 1.0),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTelemetryMetric(
                          icon: Icons.water_drop_rounded,
                          label: 'Humidity',
                          value: hum.toStringAsFixed(1),
                          unit: '%',
                          color: isWarning ? ParishColors.mercyRed : ParishColors.marianBlue,
                          progress: (hum / 100).clamp(0.0, 1.0),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.only(top: 11),
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: ParishColors.borderGrey.withOpacity(0.8)))),
                    child: Row(
                      children: [
                        Icon(Icons.memory_rounded, size: 13, color: ParishColors.textMuted),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(nodeId, style: TextStyle(fontSize: 10, color: ParishColors.textMuted, fontWeight: FontWeight.w600)),
                        ),
                        Text('View sensor details', style: TextStyle(fontSize: 10, color: ParishColors.marianBlue, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 3),
                        const Icon(Icons.arrow_forward_rounded, size: 12, color: ParishColors.marianBlue),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTelemetryMetric({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    required Color color,
    required double progress,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ParishColors.backgroundLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
              Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: ParishColors.textMuted, fontWeight: FontWeight.w600))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [

              const SizedBox(width: 3),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(unit, style: TextStyle(fontSize: 10, color: ParishColors.textMuted, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: color.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Liturgical Schedule Card
  // ---------------------------------------------------------------------------
  Widget _buildLiturgicalScheduleCard(Color textDark, Color borderGrey, Color cardWhite) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderGrey),
        boxShadow: [
          BoxShadow(color: const Color(0xFF18334D).withOpacity(0.045), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: ParishColors.goldLight, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.church_rounded, color: ParishColors.goldAccent, size: 20),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Liturgical Schedule', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: textDark)),
                    Text('Regular parish services', style: TextStyle(fontSize: 10.5, color: ParishColors.textMuted)),
                  ],
                ),
              ),

            ],
          ),
          const SizedBox(height: 15),
          _buildScheduleRow('Sunday Holy Masses', '8:00 AM • 4:00 PM (Main Altar)', Icons.wb_sunny_outlined),
          _buildScheduleRow('Weekday Holy Masses', 'Wednesday & Friday 5:30 PM', Icons.schedule_rounded),
          _buildScheduleRow('Confessions & Anointing', 'By appointment or Saturday 4:00 PM', Icons.favorite_border_rounded),
        ],
      ),
    );
  }

  Widget _buildScheduleRow(String title, String timing, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: ParishColors.marianBlueSurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: ParishColors.marianBlue),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  const SizedBox(height: 3),
                  Text(timing, style: TextStyle(fontSize: 10.5, color: ParishColors.textMuted, height: 1.3)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Secretariat Office Hours Notice
  // ---------------------------------------------------------------------------
  Widget _buildOfficeHoursNotice(Color textDark, Color textMuted, Color borderGrey) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF4F7FA), Color(0xFFEAF1F7)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.business_outlined, color: ParishColors.marianBlue, size: 20),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Parish Office Hours', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: textDark)),
                    Text('Secretariat & administration', style: TextStyle(fontSize: 10.5, color: textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), borderRadius: BorderRadius.circular(13)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.schedule_rounded, size: 17, color: ParishColors.marianBlue),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Tuesday to Sunday\\n8:00 AM – 12:00 PM  |  1:30 PM – 5:00 PM',
                    style: TextStyle(fontSize: 11, color: textDark, height: 1.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, size: 15, color: ParishColors.goldAccent),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Monday: Closed for Canonical Clergy Rest Day & Sanctification',
                  style: TextStyle(fontSize: 10.5, color: textMuted, height: 1.35),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }
}

// =============================================================================
// Quick Action model + tile
// =============================================================================
class _QuickAction {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class _QuickActionTile extends StatefulWidget {
  final _QuickAction action;
  final bool showArrow;

  const _QuickActionTile({required this.action, this.showArrow = false});

  @override
  State<_QuickActionTile> createState() => _QuickActionTileState();
}

class _QuickActionTileState extends State<_QuickActionTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.action;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
        decoration: BoxDecoration(
          color: _hovered ? a.color.withOpacity(0.07) : ParishColors.backgroundLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _hovered ? a.color.withOpacity(0.55) : ParishColors.borderGrey,
            width: 1.2,
          ),
          boxShadow: _hovered
              ? [
            BoxShadow(
              color: a.color.withOpacity(0.14),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ]
              : const [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: a.onTap,
            borderRadius: BorderRadius.circular(14),
            splashColor: a.color.withOpacity(0.12),
            highlightColor: a.color.withOpacity(0.06),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 60),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [a.color, a.color.withOpacity(0.78)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: a.color.withOpacity(0.28),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(a.icon, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        a.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: ParishColors.textDark,
                          height: 1.2,
                        ),
                      ),
                    ),
                    if (widget.showArrow)
                      AnimatedSlide(
                        duration: const Duration(milliseconds: 160),
                        offset: _hovered ? const Offset(0.25, 0) : Offset.zero,
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: _hovered ? a.color : ParishColors.textMuted.withOpacity(0.6),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}