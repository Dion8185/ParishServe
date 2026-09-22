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

  Future<void> _cancelBooking() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Appointment Request?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'Are you sure you want to cancel this booking request? This will release the time slot on the parish calendar.',
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
    final bool canModify = status != 'cancelled' && status != 'completed';

    Color statusColor = ParishColors.goldAccent;
    Color statusSurface = ParishColors.goldLight;
    String statusExplanation =
        'Your request is currently being reviewed by the Parish Office staff.';

    if (status == 'confirmed') {
      statusColor = ParishColors.oliveGreen;
      statusSurface = ParishColors.oliveGreenSurface;
      statusExplanation =
      'Your schedule has been confirmed and locked on the Parish Master Calendar.';
    } else if (status == 'completed') {
      statusColor = ParishColors.marianBlue;
      statusSurface = ParishColors.marianBlueSurface;
      statusExplanation = 'This liturgical service has been concluded.';
    } else if (status == 'cancelled') {
      statusColor = ParishColors.mercyRed;
      statusSurface = ParishColors.mercyRedSurface;
      statusExplanation = 'This appointment request was cancelled.';
    } else if (status == 'rescheduled') {
      statusColor = const Color(0xFF7C3AED);
      statusSurface = const Color(0xFFF3E8FF);
      statusExplanation =
      'This service has been moved to a new schedule. Please check the date and time.';
    }

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
            if (a.email != null)
              _buildDetailRow(Icons.email_outlined, 'Email', a.email!),
            _buildDetailRow(Icons.access_time, 'Scheduled Date',
                '${a.formattedDate} • ${a.formattedTimeRange}'),
            _buildDetailRow(Icons.location_on_outlined, 'Venue', a.venue),
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
                    'STATUS: ${a.appointmentStatus.toUpperCase()}',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: statusColor),
                  ),
                  const SizedBox(height: 2),
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
          if (canModify) ...[
            // Parishioner Reschedule Request Action
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
              icon: const Icon(Icons.update, size: 16),
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