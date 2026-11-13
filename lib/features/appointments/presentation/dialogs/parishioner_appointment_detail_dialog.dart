// =============================================================================
// FILE: lib/features/appointments/presentation/dialogs/parishioner_appointment_detail_dialog.dart
// =============================================================================

import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../models/appointment_model.dart';
import '../../services/appointment_service.dart';
import 'reschedule_appointment_dialog.dart';

void showParishionerAppointmentDetailModal(
    BuildContext context, {
      required AppointmentModel appointment,
      VoidCallback? onStatusUpdated,
    }) {
  showDialog(
    context: context,
    builder: (ctx) => _ParishionerAppointmentDetailDialog(
      appointment: appointment,
      onStatusUpdated: onStatusUpdated,
    ),
  );
}

class _ParishionerAppointmentDetailDialog extends StatefulWidget {
  final AppointmentModel appointment;
  final VoidCallback? onStatusUpdated;

  const _ParishionerAppointmentDetailDialog({
    required this.appointment,
    this.onStatusUpdated,
  });

  @override
  State<_ParishionerAppointmentDetailDialog> createState() =>
      _ParishionerAppointmentDetailDialogState();
}

class _ParishionerAppointmentDetailDialogState
    extends State<_ParishionerAppointmentDetailDialog> {
  bool _isCancelling = false;

  bool _isOutsideVenue(String venue) {
    final v = venue.toLowerCase();
    return v.contains('outside') ||
        v.contains('off-site') ||
        v.contains('hospital') ||
        v.contains('residence') ||
        v.contains('home');
  }

  Future<void> _cancelBooking() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Appointment Request?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'Are you sure you want to cancel this booking request? This will immediately release the time slot on the parish calendar.',
          style: TextStyle(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Appointment'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ParishColors.mercyRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Request'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isCancelling = true);

    try {
      await AppointmentService.updateStatus(
        widget.appointment.appointmentId,
        'cancelled',
      );

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your appointment request has been cancelled.'),
          backgroundColor: ParishColors.mercyRed,
        ),
      );

      widget.onStatusUpdated?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cancelling booking: $e'),
          backgroundColor: ParishColors.mercyRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.appointment;
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final status = a.appointmentStatus.toLowerCase();

    // Strict lock: Concluded/Completed or Cancelled appointments are read-only
    final bool isCompleted = status == 'completed';
    final bool isCancelled = status == 'cancelled';
    final bool canModify = !isCompleted && !isCancelled;
    final bool isOutside = _isOutsideVenue(a.venue);

    Color statusColor = const Color(0xFFD97706); // Amber: Pending
    Color statusSurface = const Color(0xFFFFFBEB);
    String statusExplanation =
        'Your request has been submitted and is currently being reviewed by the Parish Office staff.';

    if (status == 'confirmed') {
      statusColor = const Color(0xFF16A34A); // Green: Confirmed
      statusSurface = const Color(0xFFF0FDF4);
      statusExplanation =
      'Your schedule has been confirmed and locked on the Parish Master Calendar.';
    } else if (status == 'completed') {
      statusColor = const Color(0xFF64748B); // Gray: Concluded
      statusSurface = const Color(0xFFF1F5F9);
      statusExplanation = 'This liturgical ceremony has been concluded.';
    } else if (status == 'cancelled') {
      statusColor = const Color(0xFFDC2626); // Red: Cancelled
      statusSurface = const Color(0xFFFEF2F2);
      statusExplanation = 'This appointment request was cancelled.';
    } else if (status == 'rescheduled') {
      statusColor = const Color(0xFFD97706); // Amber: Rescheduled / Pending check
      statusSurface = const Color(0xFFFFFBEB);
      statusExplanation =
      'This service has been moved to a new schedule. Please verify the date and time.';
    }

    final formattedTime = AppointmentService.formatTime12Hour(a.requestedTime);
    final duration = AppointmentService.getMinimumDurationMinutes(a.serviceType);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: ParishColors.cardWhite,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Booking Details',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          Text(
            a.appointmentId,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: ParishColors.marianBlue),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Service Requested Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ParishColors.marianBlueSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ParishColors.borderGrey),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Service Requested',
                      style: TextStyle(fontSize: 12, color: textMuted)),
                  Text(
                    a.serviceType,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: ParishColors.marianBlue,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            _buildDetailRow(Icons.person_outline, 'Requester', a.requesterName),
            _buildDetailRow(Icons.phone_outlined, 'Contact', a.contactNumber),
            if (a.email != null && a.email!.isNotEmpty)
              _buildDetailRow(Icons.email_outlined, 'Email', a.email!),

            // Estimated Schedule
            _buildDetailRow(Icons.access_time, 'Estimated Schedule',
                '${a.formattedDate} at $formattedTime (~${duration}m)'),

            // Venue with Grounds vs Outside Badge
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isOutside ? Icons.pin_drop_outlined : Icons.church_outlined,
                    size: 18,
                    color: ParishColors.marianBlue,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 13, color: textDark),
                        children: [
                          TextSpan(
                            text: 'Venue: ',
                            style: TextStyle(fontWeight: FontWeight.bold, color: textMuted),
                          ),
                          TextSpan(text: '${a.venue} ', style: const TextStyle(fontWeight: FontWeight.w600)),
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
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
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            _buildDetailRow(Icons.church_outlined, 'Presiding Clergy', a.officiantName),

            if (a.appointmentRemarks != null &&
                a.appointmentRemarks!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ParishColors.backgroundLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ParishColors.borderGrey),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Parish Office Notes / Remarks:',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: textMuted)),
                    const SizedBox(height: 3),
                    Text(a.appointmentRemarks!,
                        style: TextStyle(fontSize: 12, color: textDark)),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Status Badge & Context
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusSurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isCompleted ? 'STATUS: CONCLUDED' : 'STATUS: ${a.appointmentStatus.toUpperCase()}',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: statusColor),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    statusExplanation,
                    style: TextStyle(fontSize: 11.5, color: textDark, height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (_isCancelling)
          const Center(
              child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator()))
        else ...[
          // Actions: Strictly locked if completed or cancelled
          if (canModify) ...[
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF7C3AED)),
                foregroundColor: const Color(0xFF7C3AED),
              ),
              onPressed: () {
                showRescheduleAppointmentModal(
                  context,
                  appointment: widget.appointment,
                  onRescheduled: widget.onStatusUpdated,
                );
              },
              icon: const Icon(Icons.edit_calendar, size: 16),
              label: const Text('Request Reschedule'),
            ),
            TextButton(
              onPressed: _cancelBooking,
              child: const Text('Cancel Request',
                  style: TextStyle(
                      color: ParishColors.mercyRed,
                      fontWeight: FontWeight.bold)),
            ),
          ],
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ParishColors.marianBlue,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: ParishColors.marianBlue),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 13, color: ParishColors.textDark),
                children: [
                  TextSpan(
                      text: '$label: ',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: ParishColors.textMuted)),
                  TextSpan(
                      text: value,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}