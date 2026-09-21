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

  Future<void> _verifyIdDocument() async {
    setState(() => _isUpdating = true);
    try {
      await AppointmentService.updateIdVerification(
        appointmentId: _id,
        isVerified: true,
        notes: 'Verified and approved by Secretariat.',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Valid ID document approved and verified.'),
          backgroundColor: ParishColors.oliveGreen,
        ),
      );
      widget.onStatusUpdated?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error verifying ID: $e'), backgroundColor: ParishColors.mercyRed),
      );
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _openIdDocumentPreview(String filePath) async {
    final signedUrl = await AppointmentService.getSignedIdDocumentUrl(filePath);
    if (!mounted || signedUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load ID document image.'), backgroundColor: ParishColors.mercyRed),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 650),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Identification Inspection', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              Expanded(
                child: Center(
                  child: Image.network(signedUrl, fit: BoxFit.contain),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final status = _currentStatus;
    final apt = widget.appointment;

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
            // ID Clearance Card (Visible if uploaded)
            if (apt != null && (apt.idType != null || apt.idDocumentUrl != null)) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (apt.isIdVerified) ? ParishColors.oliveGreenSurface : ParishColors.goldLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: (apt.isIdVerified) ? ParishColors.oliveGreen : ParishColors.goldAccent),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Valid ID Clearance:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: textDark)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (apt.isIdVerified) ? ParishColors.oliveGreen : ParishColors.goldAccent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text((apt.isIdVerified) ? 'VERIFIED' : 'NEEDS CLEARANCE', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Type: ${apt.idType ?? 'Government ID'}', style: TextStyle(fontSize: 12, color: textDark)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (apt.idDocumentUrl != null)
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: ParishColors.marianBlue),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                            onPressed: () => _openIdDocumentPreview(apt.idDocumentUrl!),
                            icon: const Icon(Icons.remove_red_eye, size: 14),
                            label: const Text('View ID Photo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        const SizedBox(width: 8),
                        if (!apt.isIdVerified)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ParishColors.oliveGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                            onPressed: _verifyIdDocument,
                            icon: const Icon(Icons.check, size: 14),
                            label: const Text('Approve ID', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            _buildDetailRow(Icons.person_outline, 'Requester', _reqName),
            _buildDetailRow(Icons.phone_outlined, 'Contact', _contactNo),
            _buildDetailRow(Icons.access_time, 'Schedule', _timeDisplay),
            _buildDetailRow(Icons.location_on_outlined, 'Venue', _venue),
          ],
        ),
      ),
      actions: [
        if (_isUpdating)
          const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
        else ...[
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