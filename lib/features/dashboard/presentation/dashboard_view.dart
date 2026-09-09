import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../auth/models/user_model.dart';
import '../../auth/presentation/login_view.dart';
import '../../sacramental_records/presentation/dialogs/ocr_scan_dialog.dart';
import '../../appointments/presentation/dialogs/schedule_appointment_dialog.dart';
import '../../receipts/presentation/dialogs/new_transaction_dialog.dart';
import '../../smart_archive/presentation/dialogs/sensor_detail_dialog.dart';
import 'widgets/parish_calendar.dart';
import 'dialogs/notification_dialog.dart';

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
          // Header with Dynamic User Greet & Role
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: ParishColors.marianBlueSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ParishColors.goldAccent, width: 2),
                ),
                child: const Icon(Icons.church, size: 32, color: ParishColors.marianBlue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentUser != null ? currentUser!.fullName : 'St. John Paul II Parish',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: ParishColors.marianBlue,
                      ),
                    ),
                    Text(
                      currentUser != null
                          ? '${currentUser!.roleDisplay} • ${currentUser!.userId}'
                          : 'ParishServe Portal',
                      style: const TextStyle(fontSize: 12, color: ParishColors.textMuted),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () => showNotificationModal(context),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: ParishColors.cardWhite,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ParishColors.borderGrey, width: 1.5),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(Icons.notifications_outlined, size: 26, color: ParishColors.marianBlue),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: ParishColors.mercyRed,
                            shape: BoxShape.circle,
                          ),
                          child: const Text(
                            '3',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginView()),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: ParishColors.cardWhite,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ParishColors.borderGrey, width: 1.5),
                  ),
                  child: const Icon(Icons.logout, size: 24, color: ParishColors.mercyRed),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          _buildArchiveTelemetryCard(context),
          const SizedBox(height: 22),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Parish Event Calendar', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
          const Text('Tap any highlighted date to view scheduled church events.', style: TextStyle(fontSize: 13, color: ParishColors.textMuted)),
          const SizedBox(height: 12),
          const ParishCalendar(),
          const SizedBox(height: 24),
          const Text('Quick Operational Actions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
            const Row(
              children: [
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.thermostat, size: 26, color: ParishColors.marianBlue),
                      SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Temperature', style: TextStyle(fontSize: 12, color: ParishColors.textMuted)),
                          Text('24.2 °C', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
                VerticalDivider(width: 20),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.water_drop_outlined, size: 26, color: ParishColors.marianBlue),
                      SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Humidity', style: TextStyle(fontSize: 12, color: ParishColors.textMuted)),
                          Text('54 %', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
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
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 13, color: ParishColors.textMuted)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 18, color: ParishColors.textMuted),
          ],
        ),
      ),
    );
  }
}