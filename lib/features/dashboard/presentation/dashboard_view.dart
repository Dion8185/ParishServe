import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../auth/models/user_model.dart';
import '../../sacramental_records/presentation/dialogs/ocr_scan_dialog.dart';
import '../../appointments/presentation/dialogs/schedule_appointment_dialog.dart';
import '../../receipts/presentation/dialogs/new_transaction_dialog.dart';
import '../../smart_archive/presentation/dialogs/sensor_detail_dialog.dart';
import 'pages/parish_calendar_page.dart';

class DashboardView extends StatelessWidget {
  final UserModel? currentUser;

  const DashboardView({super.key, this.currentUser});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Card
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

          // ESP32 Smart Archive Telemetry Banner
          _buildArchiveTelemetryCard(context),
          const SizedBox(height: 22),

          // Master Calendar Preview Card
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Parish Master Calendar', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: ParishColors.goldLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'September 2026',
                  style: TextStyle(fontWeight: FontWeight.bold, color: ParishColors.goldAccent, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Tap below to view full Month, Week, and Day schedules.',
            style: TextStyle(fontSize: 13, color: ParishColors.textMuted),
          ),
          const SizedBox(height: 12),
          _buildCalendarSummaryCard(context),

          const SizedBox(height: 24),

          // Operational Actions
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

  Widget _buildCalendarSummaryCard(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ParishCalendarPage()),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: ParishColors.cardWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ParishColors.borderGrey, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ParishColors.marianBlueSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.calendar_month, color: ParishColors.marianBlue, size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Open Master Calendar',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Month • Week • Day timeline views',
                        style: TextStyle(fontSize: 13, color: ParishColors.textMuted),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 18, color: ParishColors.textMuted),
              ],
            ),
            const Divider(height: 24),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _CalendarQuickMetric(label: 'Today', value: '2 Services', color: ParishColors.marianBlue),
                _CalendarQuickMetric(label: 'This Week', value: '7 Bookings', color: ParishColors.goldAccent),
                _CalendarQuickMetric(label: 'Status', value: '1 Alert', color: ParishColors.mercyRed),
              ],
            ),
          ],
        ),
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

class _CalendarQuickMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _CalendarQuickMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: ParishColors.textMuted)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}