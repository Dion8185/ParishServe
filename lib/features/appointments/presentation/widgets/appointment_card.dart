import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../dialogs/appointment_detail_dialog.dart';

class AppointmentCard extends StatelessWidget {
  final String refNo;
  final String serviceName;
  final String requester;
  final String contact;
  final String scheduleTime;
  final String officiant;
  final String status;
  final String feeStatus;

  const AppointmentCard({
    super.key,
    required this.refNo,
    required this.serviceName,
    required this.requester,
    required this.contact,
    required this.scheduleTime,
    required this.officiant,
    required this.status,
    required this.feeStatus,
  });

  @override
  Widget build(BuildContext context) {
    final bool isConfirmed = status == 'CONFIRMED';

    return InkWell(
      onTap: () => showAppointmentDetailModal(
        context,
        refNo: refNo,
        serviceName: serviceName,
        requester: requester,
        contact: contact,
        scheduleTime: scheduleTime,
        officiant: officiant,
        status: status,
        feeStatus: feeStatus,
      ),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ParishColors.cardWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ParishColors.borderGrey),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isConfirmed ? ParishColors.marianBlueSurface : ParishColors.goldLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.calendar_today,
                color: isConfirmed ? ParishColors.marianBlue : ParishColors.goldAccent,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        refNo,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: ParishColors.marianBlue),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isConfirmed ? ParishColors.oliveGreenSurface : ParishColors.goldLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isConfirmed ? ParishColors.oliveGreen : ParishColors.goldAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(serviceName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('Requester: $requester', style: const TextStyle(fontSize: 13, color: ParishColors.textMuted)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 14, color: ParishColors.textMuted),
                      const SizedBox(width: 4),
                      Text(scheduleTime, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ParishColors.textDark)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}