import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../auth/models/user_model.dart';
import '../../auth/presentation/priest_dashboard_widget.dart';
import '../../receipts/presentation/secretary_dashboard_widget.dart';
import '../../auth/presentation/encoder_dashboard_widget.dart';
import '../../auth/presentation/pfc_dashboard_widget.dart';
import '../../auth/presentation/admin_users_page.dart';
import '../../auth/presentation/user_dashboard_widget.dart';
import '../../sacramental_records/presentation/dialogs/ocr_scan_dialog.dart';
import '../../appointments/presentation/dialogs/schedule_appointment_dialog.dart';
import '../../receipts/presentation/dialogs/new_transaction_dialog.dart';
import '../../smart_archive/presentation/dialogs/sensor_detail_dialog.dart';
import 'dialogs/calendar_event_dialog.dart';
import 'pages/parish_calendar_page.dart';

class DashboardView extends StatelessWidget {
  final UserModel? currentUser;

  const DashboardView({super.key, this.currentUser});

  @override
  Widget build(BuildContext context) {
    final role = currentUser?.userRole.toLowerCase() ?? 'secretary';

    // Role-Based Dynamic Workspace Routing
    if (role == 'parishpriest') {
      return const PriestDashboardWidget();
    } else if (role == 'secretary') {
      return const SecretaryDashboardWidget();
    } else if (role == 'encoder') {
      return const EncoderDashboardWidget();
    } else if (role == 'pfc') {
      return const PfcDashboardWidget();
    } else if (role == 'admin' || role == 'superadmin') {
      return const AdminUsersPage();
    } else if (role == 'user') {
      return UserDashboardWidget(currentUser: currentUser);
    }

    // Default Fallback View
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: ParishColors.cardWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ParishColors.borderGrey),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: ParishColors.goldLight,
                  child: const Icon(Icons.person, color: ParishColors.goldAccent, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentUser != null ? 'Welcome, ${currentUser!.firstName}!' : 'Welcome, Parish Staff!',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: ParishColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Ready for today\'s sacramental & parish duties.',
                        style: TextStyle(fontSize: 13, color: ParishColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _buildArchiveTelemetryCard(context),
          const SizedBox(height: 22),

          // Parish Calendar Section with Interactive Grid Preview
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Parish Event Calendar', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ParishCalendarPage()),
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: ParishColors.goldLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'September 2026 (Open Full)',
                    style: TextStyle(fontWeight: FontWeight.bold, color: ParishColors.goldAccent, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Tap any date to view details or open the Master Calendar.',
            style: TextStyle(fontSize: 13, color: ParishColors.textMuted),
          ),
          const SizedBox(height: 12),

          // Clickable Mini-Calendar Grid Preview
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ParishCalendarPage()),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: _buildInteractiveCalendar(context),
          ),

          const SizedBox(height: 24),
          Text('Quick Operational Actions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
          const SizedBox(height: 12),
          _buildLargeActionCard(
            context: context,
            icon: Icons.document_scanner,
            title: 'Scan Sacramental Page (OCR)',
            subtitle: 'Digitize Baptism, Confirmation, or Marriage books',
            accentColor: ParishColors.marianBlue,
            onTap: () => showOcrScanModal(context),
          ),
          const SizedBox(height: 12),
          _buildLargeActionCard(
            context: context,
            icon: Icons.edit_calendar,
            title: 'Schedule Parish Appointment',
            subtitle: 'Book Mass intentions, weddings, or baptism dates',
            accentColor: ParishColors.goldAccent,
            onTap: () => showScheduleAppointmentModal(context),
          ),
          const SizedBox(height: 12),
          _buildLargeActionCard(
            context: context,
            icon: Icons.payments_outlined,
            title: 'Issue Ecclesiastical Receipt',
            subtitle: 'Record fees, certificate requests & donations',
            accentColor: ParishColors.oliveGreen,
            onTap: () => showNewTransactionModal(context),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveCalendar(BuildContext context) {
    final daysOfWeek = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    final eventsMap = {
      6: 'Sunday Mass & Community Baptism',
      12: 'Nuptial Mass (Santos-Ramos Wedding)',
      15: 'Diocesan Asset Audit Inspection',
      20: 'Parish Confirmation Rites',
      27: 'Feast Day Preparation Meeting',
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ParishColors.borderGrey, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: daysOfWeek
                .map((d) => SizedBox(
              width: 36,
              child: Text(
                d,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, color: ParishColors.marianBlue, fontSize: 14),
              ),
            ))
                .toList(),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 35,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemBuilder: (context, index) {
              const offset = 2; // September 2026 starts on Tuesday
              final dayNumber = index - offset + 1;

              if (dayNumber < 1 || dayNumber > 30) {
                return const SizedBox.shrink();
              }

              final hasEvent = eventsMap.containsKey(dayNumber);

              return InkWell(
                onTap: hasEvent
                    ? () => showCalendarEventModal(
                  context,
                  date: 'September $dayNumber, 2026',
                  eventTitle: eventsMap[dayNumber]!,
                )
                    : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ParishCalendarPage()),
                  );
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  decoration: BoxDecoration(
                    color: hasEvent ? ParishColors.goldLight : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: hasEvent ? ParishColors.goldAccent : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        '$dayNumber',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: hasEvent ? FontWeight.bold : FontWeight.normal,
                          color: hasEvent ? ParishColors.textDark : ParishColors.textMuted,
                        ),
                      ),
                      if (hasEvent)
                        Positioned(
                          bottom: 4,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: ParishColors.marianBlue,
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
    );
  }

  Widget _buildArchiveTelemetryCard(BuildContext context) {
    return InkWell(
      onTap: () => showSensorDetailModal(
        context,
        roomTitle: 'Sacramental Archive Room',
        nodeId: 'ESP32-NODE-01',
        temperature: '24.2 °C',
        humidity: '54 %',
        isWarning: false,
      ),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: ParishColors.cardWhite,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: ParishColors.borderGrey, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.sensors, color: ParishColors.marianBlue, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Archive Sensors (ESP32)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: ParishColors.oliveGreenSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: ParishColors.oliveGreen),
                  ),
                  child: const Text(
                    'SAFE STATUS',
                    style: TextStyle(
                      color: ParishColors.oliveGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 22),
            Row(
              children: [
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.thermostat, size: 26, color: ParishColors.marianBlue),
                      const SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Temperature', style: TextStyle(fontSize: 12, color: ParishColors.textMuted)),
                          Text('24.2 °C', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
                        ],
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 20),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.water_drop_outlined, size: 26, color: ParishColors.marianBlue),
                      const SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Humidity', style: TextStyle(fontSize: 12, color: ParishColors.textMuted)),
                          Text('54 %', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLargeActionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: ParishColors.cardWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ParishColors.borderGrey, width: 1.2),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: accentColor.withOpacity(0.12),
              child: Icon(icon, size: 28, color: accentColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 13, color: ParishColors.textMuted)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 18, color: ParishColors.textMuted),
          ],
        ),
      ),
    );
  }
}