import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../models/appointment_model.dart';
import '../../services/appointment_service.dart';
import 'reschedule_appointment_dialog.dart';

void showAppointmentDetailModal(
    BuildContext context, {
      AppointmentModel? appointment,
      String? refNo,
      String? serviceName,
      String? requester,
      String? contact,
      String? scheduleTime,
      String? officiant,
      String? status,
      String? feeStatus,
      VoidCallback? onStatusUpdated,
    }) {
  showDialog(
    context: context,
    builder: (ctx) => _AppointmentDetailDialog(
      appointment: appointment,
      refNo: refNo,
      serviceName: serviceName,
      requester: requester,
      contact: contact,
      scheduleTime: scheduleTime,
      officiant: officiant,
      status: status,
      feeStatus: feeStatus,
      onStatusUpdated: onStatusUpdated,
    ),
  );
}

class _AppointmentDetailDialog extends StatefulWidget {
  final AppointmentModel? appointment;
  final String? refNo;
  final String? serviceName;
  final String? requester;
  final String? contact;
  final String? scheduleTime;
  final String? officiant;
  final String? status;
  final String? feeStatus;
  final VoidCallback? onStatusUpdated;

  const _AppointmentDetailDialog({
    this.appointment,
    this.refNo,
    this.serviceName,
    this.requester,
    this.contact,
    this.scheduleTime,
    this.officiant,
    this.status,
    this.feeStatus,
    this.onStatusUpdated,
  });

  @override
  State<_AppointmentDetailDialog> createState() => _AppointmentDetailDialogState();
}

class _AppointmentDetailDialogState extends State<_AppointmentDetailDialog> {
  bool _isUpdating = false;

  String get _id => widget.appointment?.appointmentId ?? widget.refNo ?? 'APT-RECORD';
  String get _service => widget.appointment?.serviceType ?? widget.serviceName ?? 'Parish Service';
  String get _reqName => widget.appointment?.requesterName ?? widget.requester ?? 'Parishioner';
  String get _contactNo => widget.appointment?.contactNumber ?? widget.contact ?? 'N/A';
  String? get _email => widget.appointment?.email;
  String get _venue => widget.appointment?.venue ?? 'Main Church Altar';
  String get _priest => widget.appointment?.officiantName ?? widget.officiant ?? 'Rev. Fr. Joseph Santos';
  String? get _remarks => widget.appointment?.appointmentRemarks;
  String? get _fee => widget.feeStatus;

  String get _timeDisplay {
    if (widget.appointment != null) {
      return '${widget.appointment!.formattedDate} • ${widget.appointment!.formattedTimeRange}';
    }
    return widget.scheduleTime ?? 'Scheduled Time';
  }

  String get _currentStatus {
    return (widget.appointment?.appointmentStatus ?? widget.status ?? 'pending').toLowerCase();
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isUpdating = true);
    try {
      await AppointmentService.updateStatus(_id, newStatus);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Appointment marked as ${newStatus.toUpperCase()}.'),
          backgroundColor: ParishColors.oliveGreen,
        ),
      );
      widget.onStatusUpdated?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating status: $e'),
          backgroundColor: ParishColors.mercyRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final status = _currentStatus;

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

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: ParishColors.cardWhite,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Booking Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          Text(_id, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ParishColors.marianBlue)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                  Text('Service Requested', style: TextStyle(fontSize: 12, color: textMuted)),
                  Text(_service, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: ParishColors.marianBlue)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _buildDetailRow(Icons.person_outline, 'Requester', _reqName),
            _buildDetailRow(Icons.phone_outlined, 'Contact', _contactNo),
            if (_email != null) _buildDetailRow(Icons.email_outlined, 'Email', _email!),
            _buildDetailRow(Icons.access_time, 'Schedule', _timeDisplay),
            _buildDetailRow(Icons.location_on_outlined, 'Parish Venue', _venue),
            _buildDetailRow(Icons.church_outlined, 'Presiding Clergy', _priest),
            if (_fee != null) _buildDetailRow(Icons.payments_outlined, 'Fee Status', _fee!),
            if (_remarks != null) ...[
              const SizedBox(height: 6),
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
                    Text('Remarks / Reschedule History:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textMuted)),
                    const SizedBox(height: 4),
                    Text(_remarks!, style: TextStyle(fontSize: 12, color: textDark)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusSurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'STATUS: ${status.toUpperCase()}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: statusColor),
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (_isUpdating)
          const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
        else ...[
          if (status != 'cancelled' && status != 'completed') ...[
            // Dedicated Reschedule Action
            if (widget.appointment != null)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF7C3AED)),
                  foregroundColor: const Color(0xFF7C3AED),
                ),
                onPressed: () => showRescheduleAppointmentModal(
                  context,
                  appointment: widget.appointment!,
                  onRescheduled: widget.onStatusUpdated,
                ),
                icon: const Icon(Icons.update, size: 16),
                label: const Text('Reschedule'),
              ),
            TextButton(
              onPressed: () => _updateStatus('cancelled'),
              child: const Text('Cancel Booking', style: TextStyle(color: ParishColors.mercyRed, fontWeight: FontWeight.bold)),
            ),
            if (status == 'pending' || status == 'rescheduled')
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: ParishColors.oliveGreen, foregroundColor: Colors.white),
                onPressed: () => _updateStatus('confirmed'),
                child: const Text('Confirm'),
              ),
            if (status == 'confirmed')
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: ParishColors.marianBlue, foregroundColor: Colors.white),
                onPressed: () => _updateStatus('completed'),
                child: const Text('Mark Completed'),
              ),
          ],
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: textMuted)),
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
                  TextSpan(text: '$label: ', style: TextStyle(fontWeight: FontWeight.bold, color: ParishColors.textMuted)),
                  TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}