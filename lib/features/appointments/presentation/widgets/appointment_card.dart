// =============================================================================
// FILE: lib/features/appointments/presentation/widgets/appointment_card.dart
// =============================================================================

import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../models/appointment_model.dart';
import '../../services/appointment_service.dart';
import '../dialogs/appointment_detail_dialog.dart';

class AppointmentCard extends StatelessWidget {
  final AppointmentModel appointment;
  final VoidCallback? onRefresh;

  const AppointmentCard({
    super.key,
    required this.appointment,
    this.onRefresh,
  });

  IconData _getServiceIcon(String serviceType) {
    final s = serviceType.toLowerCase();
    if (s.contains('wedding') || s.contains('nuptial')) return Icons.favorite;
    if (s.contains('confirmation') || s.contains('kumpil')) return Icons.local_fire_department;
    if (s.contains('baptism')) return Icons.water_drop;
    if (s.contains('funeral')) return Icons.church;
    if (s.contains('anointing') || s.contains('sick') || s.contains('viaticum')) return Icons.medical_services_outlined;
    if (s.contains('confession')) return Icons.lock_open;
    if (s.contains('blessing')) return Icons.wb_sunny_outlined;
    return Icons.event_available;
  }

  bool _isOutsideVenue(String venue) {
    final v = venue.toLowerCase();
    return v.contains('outside') ||
        v.contains('off-site') ||
        v.contains('hospital') ||
        v.contains('residence') ||
        v.contains('home');
  }

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final status = a.appointmentStatus.toLowerCase();
    final bool hasUploadedIdPending =
        a.idDocumentUrl != null && a.idDocumentUrl!.isNotEmpty && !a.isIdVerified;
    final bool isOutside = _isOutsideVenue(a.venue);

    Color statusColor = const Color(0xFFD97706); // Amber
    Color statusSurface = const Color(0xFFFFFBEB);
    if (status == 'confirmed') {
      statusColor = const Color(0xFF16A34A); // Green
      statusSurface = const Color(0xFFF0FDF4);
    } else if (status == 'completed') {
      statusColor = const Color(0xFF64748B); // Gray
      statusSurface = const Color(0xFFF1F5F9);
    } else if (status == 'cancelled') {
      statusColor = const Color(0xFFDC2626); // Red
      statusSurface = const Color(0xFFFEF2F2);
    }

    final formattedTime = AppointmentService.formatTime12Hour(a.requestedTime);
    final duration = AppointmentService.getMinimumDurationMinutes(a.serviceType);

    return InkWell(
      onTap: () => showAppointmentDetailModal(
        context,
        appointment: a,
        onStatusUpdated: onRefresh,
      ),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ParishColors.cardWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ParishColors.borderGrey),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Liturgical Rite Icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: statusSurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _getServiceIcon(a.serviceType),
                color: statusColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),

            // Appointment Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        a.appointmentId,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: ParishColors.marianBlue),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusSurface,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          a.appointmentStatus.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    a.serviceType,
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                  ),
                  Text(
                    'Requester: ${a.requesterName} (${a.contactNumber})',
                    style: TextStyle(fontSize: 12, color: ParishColors.textMuted),
                  ),
                  const SizedBox(height: 6),

                  // Single Service Time with Runtime Duration
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 13, color: ParishColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        '${a.formattedDate} at $formattedTime (~${duration}m)',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ParishColors.textDark),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Venue Badge (Parish Grounds vs Outside)
                  Row(
                    children: [
                      Icon(
                        isOutside ? Icons.pin_drop_outlined : Icons.church_outlined,
                        size: 13,
                        color: isOutside ? ParishColors.goldAccent : ParishColors.marianBlue,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: isOutside ? ParishColors.goldLight : ParishColors.marianBlueSurface,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isOutside ? 'OUTSIDE PARISH' : 'PARISH GROUNDS',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  color: isOutside ? ParishColors.goldAccent : ParishColors.marianBlue,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                a.venue,
                                style: TextStyle(fontSize: 11.5, color: ParishColors.textMuted),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Optional ID Pill: Only shows if an online portal user submitted an ID awaiting review
                  if (hasUploadedIdPending) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: ParishColors.goldLight,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: ParishColors.goldAccent.withOpacity(0.4)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.badge_outlined, size: 11, color: ParishColors.goldAccent),
                          SizedBox(width: 4),
                          Text(
                            'Portal ID Pending Review',
                            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: ParishColors.goldAccent),
                          ),
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
}