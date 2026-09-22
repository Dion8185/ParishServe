import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../models/appointment_model.dart';
import '../dialogs/appointment_detail_dialog.dart';

class AppointmentCard extends StatelessWidget {
  final AppointmentModel appointment;
  final VoidCallback? onRefresh;

  const AppointmentCard({
    super.key,
    required this.appointment,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final status = a.appointmentStatus.toLowerCase();
    final bool hasId = a.idType != null || a.idDocumentUrl != null;

    Color statusColor = ParishColors.goldAccent;
    Color statusSurface = ParishColors.goldLight;
    if (status == 'confirmed') {
      statusColor = ParishColors.oliveGreen;
      statusSurface = ParishColors.oliveGreenSurface;
    } else if (status == 'completed') {
      statusColor = ParishColors.marianBlue;
      statusSurface = ParishColors.marianBlueSurface;
    } else if (status == 'cancelled') {
      statusColor = ParishColors.mercyRed;
      statusSurface = ParishColors.mercyRedSurface;
    } else if (status == 'rescheduled') {
      statusColor = const Color(0xFF7C3AED); // Royal Violet
      statusSurface = const Color(0xFFF3E8FF);
    }

    return InkWell(
      onTap: () => showAppointmentDetailModal(
        context,
        appointment: a,
        onStatusUpdated: onRefresh,
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
                color: statusSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.calendar_month,
                color: statusColor,
                size: 26,
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
                        a.appointmentId,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: ParishColors.marianBlue),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusSurface,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          a.appointmentStatus.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    a.serviceType,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                  ),
                  Text(
                    'Requester: ${a.requesterName} (${a.contactNumber})',
                    style: TextStyle(fontSize: 12.5, color: ParishColors.textMuted),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 14, color: ParishColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        '${a.formattedDate} • ${a.formattedTimeRange}',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: ParishColors.textDark),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 14, color: ParishColors.textMuted),
                      const SizedBox(width: 4),
                      Text(a.venue, style: TextStyle(fontSize: 12, color: ParishColors.textMuted)),
                    ],
                  ),

                  // ID Clearance Indicator Pill for Staff Triage
                  if (hasId) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: a.isIdVerified
                                ? ParishColors.oliveGreenSurface
                                : ParishColors.goldLight,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: a.isIdVerified
                                  ? ParishColors.oliveGreen.withValues(alpha: 0.5)
                                  : ParishColors.goldAccent.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                a.isIdVerified ? Icons.verified : Icons.badge_outlined,
                                size: 12,
                                color: a.isIdVerified ? ParishColors.oliveGreen : ParishColors.goldAccent,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                a.isIdVerified ? 'ID Verified' : 'ID Clearance Needed',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: a.isIdVerified ? ParishColors.oliveGreen : ParishColors.goldAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
}