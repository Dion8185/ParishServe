import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/colors.dart';
import '../../../auth/services/auth_service.dart';
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
  late bool _isIdVerified;
  AppointmentModel? _loadedAppointment;
  bool _isLoadingRecord = false;

  AppointmentModel? get _activeApt => widget.appointment ?? _loadedAppointment;

  String get _id => _activeApt?.appointmentId ?? widget.refNo ?? 'APT-RECORD';
  String get _service => _activeApt?.serviceType ?? widget.serviceName ?? 'Parish Service';
  String get _reqName => _activeApt?.requesterName ?? widget.requester ?? 'Parishioner';
  String get _contactNo => _activeApt?.contactNumber ?? widget.contact ?? 'N/A';
  String? get _email => _activeApt?.email;
  String get _venue => _activeApt?.venue ?? 'Main Church Altar';
  String get _priest => _activeApt?.officiantName ?? widget.officiant ?? 'Rev. Fr. Joseph Santos';
  String? get _remarks => _activeApt?.appointmentRemarks;
  String? get _fee => widget.feeStatus;

  String get _timeDisplay {
    if (_activeApt != null) {
      return '${_activeApt!.formattedDate} • ${_activeApt!.formattedTimeRange}';
    }
    return widget.scheduleTime ?? 'Scheduled Time';
  }

  String get _currentStatus {
    return (_activeApt?.appointmentStatus ?? widget.status ?? 'pending').toLowerCase();
  }

  bool get _hasIdAttachment =>
      _activeApt?.idType != null || _activeApt?.idDocumentUrl != null;

  @override
  void initState() {
    super.initState();
    _isIdVerified = widget.appointment?.isIdVerified ?? false;

    // If opened from a notification click with only refNo, load full appointment from Supabase
    if (widget.appointment == null && widget.refNo != null && widget.refNo!.isNotEmpty) {
      _fetchAppointmentRecord(widget.refNo!);
    }
  }

  Future<void> _fetchAppointmentRecord(String refId) async {
    setState(() => _isLoadingRecord = true);
    try {
      final res = await Supabase.instance.client
          .from('appointments')
          .select()
          .eq('appointment_id', refId)
          .maybeSingle();

      if (res != null && mounted) {
        setState(() {
          _loadedAppointment = AppointmentModel.fromMap(res);
          _isIdVerified = _loadedAppointment?.isIdVerified ?? false;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingRecord = false);
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isUpdating = true);
    try {
      await AppointmentService.updateStatus(_id, newStatus);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newStatus == 'confirmed'
              ? 'Appointment APPROVED & CONFIRMED. Notification email dispatched.'
              : 'Appointment marked as ${newStatus.toUpperCase()}.'),
          backgroundColor: newStatus == 'cancelled' ? ParishColors.mercyRed : ParishColors.oliveGreen,
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
        notes: 'Verified and approved across secretariat desk.',
      );

      if (!mounted) return;

      setState(() {
        _isIdVerified = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Valid ID approved! You may now confirm the appointment.'),
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator(color: ParishColors.marianBlue)),
    );

    final signedUrl = await AppointmentService.getSignedIdDocumentUrl(filePath);

    if (mounted) {
      Navigator.pop(context); // Close loading indicator
    }

    if (!mounted || signedUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not load ID document image. Please verify file format.'),
          backgroundColor: ParishColors.mercyRed,
        ),
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
                  const Text('Identification Document Inspection',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    signedUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(child: CircularProgressIndicator(color: ParishColors.marianBlue));
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.broken_image_outlined, size: 48, color: ParishColors.mercyRed),
                            const SizedBox(height: 8),
                            const Text('Image preview failed to render.'),
                            Text('URL: $signedUrl', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                      );
                    },
                  ),
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
    final apt = _activeApt;

    // RBAC: Only Parish Priest, Secretary, and System Admins have booking mutation authority
    final callerRole = AuthService.currentUser?.userRole.toLowerCase() ?? '';
    final bool hasSchedulingAuthority = callerRole == 'parishpriest' ||
        callerRole == 'secretary' ||
        callerRole == 'admin' ||
        callerRole == 'superadmin';

    final bool canModify = hasSchedulingAuthority && status != 'cancelled' && status != 'completed';

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
      statusColor = const Color(0xFF7C3AED);
      statusSurface = const Color(0xFFF3E8FF);
    }

    final bool canApproveAppointment = !_hasIdAttachment || _isIdVerified;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: ParishColors.cardWhite,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Booking Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          Text(_id, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ParishColors.marianBlueAdaptive)),
        ],
      ),
      content: _isLoadingRecord
          ? const SizedBox(
        height: 180,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Loading canonical schedule details...', style: TextStyle(fontSize: 12.5)),
            ],
          ),
        ),
      )
          : SingleChildScrollView(
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
                  Text('Service Requested', style: TextStyle(fontSize: 12, color: textMuted)),
                  Text(_service, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: ParishColors.marianBlueAdaptive)),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Valid ID Clearance Card
            if (_hasIdAttachment) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isIdVerified ? ParishColors.oliveGreenSurface : ParishColors.goldLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _isIdVerified ? ParishColors.oliveGreen : ParishColors.goldAccent,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Valid ID Clearance:',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: textDark),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _isIdVerified ? ParishColors.oliveGreen : ParishColors.goldAccent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _isIdVerified ? 'VERIFIED' : 'NEEDS CLEARANCE',
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Type: ${apt?.idType ?? 'Government ID'}', style: TextStyle(fontSize: 12, color: textDark)),
                    if (apt?.idNumber != null && apt!.idNumber!.isNotEmpty)
                      Text('Serial #: ${apt.idNumber}', style: TextStyle(fontSize: 12, color: textDark)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (apt?.idDocumentUrl != null)
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: ParishColors.marianBlueAdaptive),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                            onPressed: () => _openIdDocumentPreview(apt!.idDocumentUrl!),
                            icon: const Icon(Icons.remove_red_eye, size: 14),
                            label: const Text('Inspect ID Photo',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        const SizedBox(width: 8),
                        // Only staff with authority can approve IDs
                        if (!_isIdVerified && hasSchedulingAuthority)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ParishColors.oliveGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                            onPressed: _isUpdating ? null : _verifyIdDocument,
                            icon: const Icon(Icons.check, size: 14),
                            label: const Text('Approve ID',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            _buildDetailRow(Icons.person_outline, 'Requester', _reqName),
            _buildDetailRow(Icons.phone_outlined, 'Contact', _contactNo),
            if (_email != null) _buildDetailRow(Icons.email_outlined, 'Email', _email!),
            _buildDetailRow(Icons.access_time, 'Schedule', _timeDisplay),
            _buildDetailRow(Icons.location_on_outlined, 'Parish Venue', _venue),
            _buildDetailRow(Icons.church_outlined, 'Presiding Clergy', _priest),
            if (_fee != null) _buildDetailRow(Icons.payments_outlined, 'Fee Status', _fee!),

            if (_remarks != null && _remarks!.trim().isNotEmpty) ...[
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
                    Text('Remarks / History:',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textMuted)),
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

            // Informational notice for PFC and Encoders
            if (!hasSchedulingAuthority) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ParishColors.backgroundLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ParishColors.borderGrey),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: ParishColors.marianBlueAdaptive),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Informational View: Schedule modifications and booking approvals are reserved for Secretariat and Clergy.',
                        style: TextStyle(fontSize: 11, color: textMuted),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (_isUpdating)
          const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
        else ...[
          // Mutation actions strictly hidden for PFC and Encoders
          if (canModify) ...[
            // 1. Reschedule Action
            if (_activeApt != null)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF7C3AED)),
                  foregroundColor: const Color(0xFF7C3AED),
                ),
                onPressed: () {
                  showRescheduleAppointmentModal(
                    context,
                    appointment: _activeApt!,
                    onRescheduled: widget.onStatusUpdated,
                  );
                },
                icon: const Icon(Icons.update, size: 16),
                label: const Text('Reschedule'),
              ),

            // 2. Cancel Booking Action
            TextButton(
              onPressed: () => _updateStatus('cancelled'),
              child: const Text('Cancel Booking',
                  style: TextStyle(color: ParishColors.mercyRed, fontWeight: FontWeight.bold)),
            ),

            // 3. Confirm / Approve Action (Requires ID Approval First)
            if (status == 'pending' || status == 'rescheduled')
              Tooltip(
                message: canApproveAppointment
                    ? 'Confirm schedule and send email confirmation'
                    : 'Approve the Valid ID above first to unlock confirmation',
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canApproveAppointment ? ParishColors.oliveGreen : ParishColors.borderGrey,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: canApproveAppointment
                      ? () => _updateStatus('confirmed')
                      : () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please inspect and click "Approve ID" first before confirming this appointment.'),
                        backgroundColor: ParishColors.goldAccent,
                      ),
                    );
                  },
                  icon: Icon(canApproveAppointment ? Icons.check_circle : Icons.lock, size: 16),
                  label: const Text('Confirm Booking'),
                ),
              ),

            // 4. Mark Completed Action
            if (status == 'confirmed')
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: ParishColors.marianBlue, foregroundColor: Colors.white),
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
          Icon(icon, size: 18, color: ParishColors.marianBlueAdaptive),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 13, color: ParishColors.textDark),
                children: [
                  TextSpan(
                      text: '$label: ',
                      style: TextStyle(fontWeight: FontWeight.bold, color: ParishColors.textMuted)),
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