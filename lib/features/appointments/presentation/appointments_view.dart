import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import 'dialogs/schedule_appointment_dialog.dart';
import 'widgets/appointment_card.dart';

class AppointmentsView extends StatelessWidget {
  const AppointmentsView({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Parish Appointments', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
          Text('Schedule weddings, baptisms, mass intentions & pastoral duties', style: TextStyle(color: ParishColors.textMuted)),
          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: ParishColors.goldAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => showScheduleAppointmentModal(context),
              icon: const Icon(Icons.add_task, size: 26),
              label: const Text('+ Book New Appointment', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              _buildFilterChip('All (4)', isSelected: true),
              const SizedBox(width: 8),
              _buildFilterChip('Confirmed (3)'),
              const SizedBox(width: 8),
              _buildFilterChip('Pending (1)'),
            ],
          ),
          const SizedBox(height: 16),

          Text('Scheduled Parish Services', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
          const SizedBox(height: 12),

          AppointmentCard(
            refNo: 'APT-2026-0042',
            serviceName: 'Nuptial Mass (Santos & Ramos Wedding)',
            requester: 'Carlos Santos',
            contact: '0917-882-9912',
            scheduleTime: 'Saturday, Sep 12, 2026 • 10:00 AM',
            officiant: 'Rev. Fr. Parish Priest',
            status: 'CONFIRMED',
            feeStatus: 'Paid (REC-2026-00870)',
          ),
          AppointmentCard(
            refNo: 'APT-2026-0043',
            serviceName: 'Community Baptism (Batch A)',
            requester: 'Dela Cruz Family',
            contact: '0922-451-2290',
            scheduleTime: 'Monday, Sep 14, 2026 • 09:00 AM',
            officiant: 'Rev. Fr. Parochial Vicar',
            status: 'CONFIRMED',
            feeStatus: 'Paid (REC-2026-00892)',
          ),
          AppointmentCard(
            refNo: 'APT-2026-0044',
            serviceName: 'Pastoral Sick Call & Anointing of the Sick',
            requester: 'Remedios Bautista',
            contact: '0918-334-5511',
            scheduleTime: 'Wednesday, Sep 16, 2026 • 02:00 PM',
            officiant: 'Rev. Fr. Parish Priest',
            status: 'PENDING',
            feeStatus: 'Non-Financial (Pastoral Care)',
          ),
          AppointmentCard(
            refNo: 'APT-2026-0045',
            serviceName: 'Thanksgiving Mass Intention',
            requester: 'Pedro Alvarez',
            contact: '0908-112-9943',
            scheduleTime: 'Friday, Sep 18, 2026 • 06:00 AM',
            officiant: 'Rev. Fr. Parish Priest',
            status: 'CONFIRMED',
            feeStatus: 'Paid (REC-2026-00891)',
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, {bool isSelected = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? ParishColors.marianBlue : ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isSelected ? ParishColors.marianBlue : ParishColors.borderGrey),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : ParishColors.textMuted,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }
}