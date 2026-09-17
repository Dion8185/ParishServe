import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../models/user_model.dart';
import '../../appointments/presentation/dialogs/schedule_appointment_dialog.dart';
import '../../dashboard/presentation/pages/parish_calendar_page.dart';
import '../services/user_service.dart';

class UserDashboardWidget extends StatefulWidget {
  final UserModel? currentUser;

  const UserDashboardWidget({super.key, this.currentUser});

  @override
  State<UserDashboardWidget> createState() => _UserDashboardWidgetState();
}

class _UserDashboardWidgetState extends State<UserDashboardWidget> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _myBookings = [];

  @override
  void initState() {
    super.initState();
    _loadUserBookings();
  }

  Future<void> _loadUserBookings() async {
    setState(() => _isLoading = true);
    try {
      final bookings = await UserService.getMyBookings();
      if (!mounted) return;
      setState(() {
        _myBookings = bookings;
      });
    } catch (e) {
      debugPrint('Error loading user bookings: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstName = widget.currentUser?.firstName ?? 'Parishioner';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Parishioner Welcome Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: ParishColors.marianBlueSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ParishColors.goldAccent, width: 1.5),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: ParishColors.goldLight,
                  child: const Icon(Icons.person, color: ParishColors.goldAccent, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back, $firstName!',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'St. John Paul II Parish Client Portal',
                        style: TextStyle(fontSize: 13, color: ParishColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Quick Actions for Parishioners
          Text('Self-Service Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
          const SizedBox(height: 12),

          _buildActionCard(
            context: context,
            icon: Icons.edit_calendar,
            title: 'Book Sacrament or Mass Intention',
            subtitle: 'Submit booking schedules directly to the parish office',
            accentColor: ParishColors.goldAccent,
            onTap: () => showScheduleAppointmentModal(context),
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            context: context,
            icon: Icons.calendar_month,
            title: 'View Parish Master Calendar',
            subtitle: 'Check liturgical services, Mass times, and parish events',
            accentColor: ParishColors.marianBlue,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ParishCalendarPage())),
          ),
          const SizedBox(height: 24),

          // My Appointment Requests Tracker
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('My Appointment Requests', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
              Text('${_myBookings.length} Submitted', style: TextStyle(fontSize: 13, color: ParishColors.textMuted)),
            ],
          ),
          const SizedBox(height: 10),

          _isLoading
              ? const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
              : _myBookings.isEmpty
              ? Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: ParishColors.cardWhite,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ParishColors.borderGrey),
            ),
            child: Column(
              children: [
                Icon(Icons.event_note, size: 40, color: ParishColors.textMuted),
                const SizedBox(height: 8),
                Text('No appointment requests found.', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
                Text('Tap "Book Sacrament" above to submit your first request.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: ParishColors.textMuted)),
              ],
            ),
          )
              : Column(
            children: _myBookings.map((b) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ParishColors.cardWhite,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ParishColors.borderGrey),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bookmark_added, color: ParishColors.marianBlue),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(b['service_name'] ?? '', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
                          const SizedBox(height: 2),
                          Text('Scheduled: ${b['scheduled_datetime'].toString().substring(0, 10)}', style: TextStyle(fontSize: 12, color: ParishColors.textMuted)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: ParishColors.oliveGreenSurface,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(b['appointment_status'] ?? 'CONFIRMED', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ParishColors.oliveGreen)),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ParishColors.cardWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ParishColors.borderGrey),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: accentColor.withOpacity(0.12),
              child: Icon(icon, color: accentColor, size: 26),
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