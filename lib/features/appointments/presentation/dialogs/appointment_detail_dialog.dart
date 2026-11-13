// =============================================================================
// FILE: lib/features/appointments/presentation/dialogs/appointment_detail_dialog.dart
// =============================================================================

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
  String get _priest => _activeApt?.officiantName ?? widget.officiant ?? 'Rev. Fr. Roy';
  String? get _remarks => _activeApt?.appointmentRemarks;
  String? get _fee => widget.feeStatus;

  // Single Service Time with Estimated Runtime
  String get _timeDisplay {
    if (_activeApt != null) {
      final a = _activeApt!;
      final formattedTime = AppointmentService.formatTime12Hour(a.requestedTime);
      final duration = AppointmentService.getMinimumDurationMinutes(a.serviceType);
      return '${a.formattedDate} at $formattedTime (~${duration}m)';
    }
    return widget.scheduleTime ?? 'Scheduled Time';
  }

  String get _currentStatus {
    return (_activeApt?.appointmentStatus ?? widget.status ?? 'pending').toLowerCase();
  }

  bool get _hasIdAttachment =>
      _activeApt?.idDocumentUrl != null && _activeApt!.idDocumentUrl!.isNotEmpty;

  bool get _isOutsideVenue {
    final v = _venue.toLowerCase();
    return v.contains('outside') ||
        v.contains('off-site') ||
        v.contains('hospital') ||
        v.contains('residence') ||
        v.contains('home');
  }

  @override
  void initState() {
    super.initState();
    _isIdVerified = widget.appointment?.isIdVerified ?? false;

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
    // If cancelling, prompt for confirmation first
    if (newStatus == 'cancelled') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Cancel Appointment Booking?'),
          content: Text(
            'Are you sure you want to cancel the booking for $_service ($_reqName)? This will release the slot on the calendar.',
            style: const TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep Slot')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: ParishColors.mercyRed,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cancel Booking'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    setState(() => _isUpdating = true);
    try {
      await AppointmentService.updateStatus(_id, newStatus);
      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newStatus == 'confirmed'
              ? 'Appointment CONFIRMED and locked on the liturgical ledger.'
              : (newStatus == 'completed'
              ? 'Ceremony marked as COMPLETED and archived.'
              : 'Appointment marked as ${newStatus.toUpperCase()}.')),
          backgroundColor: newStatus == 'cancelled'
              ? ParishColors.mercyRed
              : (newStatus == 'completed'
              ? const Color(0xFF64748B)
              : ParishColors.oliveGreen),
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
          content: Text('Portal ID cleared.'),
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
      Navigator.pop(context);
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
                  child: InteractiveViewer(
                    panEnabled: true,
                    minScale: 0.8,
                    maxScale: 4.0,
                    child: Image.network(
                      signedUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(child: CircularProgressIndicator(color: ParishColors.marianBlue));
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.broken_image_outlined, size: 48, color: ParishColors.mercyRed),
                              SizedBox(height: 8),
                              Text('Image preview failed to load.'),
                            ],
                          ),
                        );
                      },
                    ),
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

    final callerRole = AuthService.currentUser?.userRole.toLowerCase() ?? '';
    final bool hasSchedulingAuthority = callerRole == 'parishpriest' ||
        callerRole == 'secretary' ||
        callerRole == 'admin' ||
        callerRole == 'superadmin';

    // Strict lock: Completed and Cancelled appointments cannot be edited, rescheduled, or cancelled
    final bool isCompleted = status == 'completed';
    final bool isCancelled = status == 'cancelled';
    final bool canModify = hasSchedulingAuthority && !isCompleted && !isCancelled;

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

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: ParishColors.cardWhite,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Appointment Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          Text(_id, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ParishColors.marianBlueAdaptive)),
        ],
      ),
      content: _isLoadingRecord
          ? const SizedBox(
        height: 160,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Loading appointment details...', style: TextStyle(fontSize: 12.5)),
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
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ParishColors.marianBlueSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ParishColors.borderGrey),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Service Requested', style: TextStyle(fontSize: 11.5, color: textMuted)),
                  Text(_service, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ParishColors.marianBlueAdaptive)),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Optional Valid ID Inspection Card (Only shows if an online parishioner submitted an ID)
            if (_hasIdAttachment) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _isIdVerified ? ParishColors.oliveGreenSurface : ParishColors.goldLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isIdVerified ? ParishColors.oliveGreen : ParishColors.goldAccent,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isIdVerified ? Icons.verified : Icons.badge_outlined,
                          size: 16,
                          color: _isIdVerified ? ParishColors.oliveGreen : ParishColors.goldAccent,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isIdVerified ? 'Portal ID Cleared' : 'Attached Portal ID',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _isIdVerified ? ParishColors.oliveGreen : textDark,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () => _openIdDocumentPreview(apt!.idDocumentUrl!),
                          child: const Text('Inspect Image', style: TextStyle(fontSize: 10.5)),
                        ),
                        if (!_isIdVerified && hasSchedulingAuthority && canModify) ...[
                          const SizedBox(width: 6),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ParishColors.oliveGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: _isUpdating ? null : _verifyIdDocument,
                            child: const Text('Clear ID', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],

            _buildDetailRow(Icons.person_outline, 'Requester', _reqName),
            _buildDetailRow(Icons.phone_outlined, 'Contact', _contactNo),
            if (_email != null && _email!.isNotEmpty) _buildDetailRow(Icons.email_outlined, 'Email', _email!),
            _buildDetailRow(Icons.access_time, 'Estimated Schedule', _timeDisplay),

            // Venue with clean Grounds vs. Outside indicator
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(_isOutsideVenue ? Icons.pin_drop_outlined : Icons.church_outlined, size: 17, color: ParishColors.marianBlueAdaptive),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 13, color: ParishColors.textDark),
                        children: [
                          TextSpan(text: 'Venue: ', style: TextStyle(fontWeight: FontWeight.bold, color: ParishColors.textMuted)),
                          TextSpan(text: '$_venue ', style: const TextStyle(fontWeight: FontWeight.w600)),
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: _isOutsideVenue ? ParishColors.goldLight : ParishColors.marianBlueSurface,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _isOutsideVenue ? 'OUTSIDE PARISH' : 'PARISH GROUNDS',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  color: _isOutsideVenue ? ParishColors.goldAccent : ParishColors.marianBlue,
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

            _buildDetailRow(Icons.church_outlined, 'Presiding Clergy', _priest),
            if (_fee != null) _buildDetailRow(Icons.payments_outlined, 'Fee Status', _fee!),

            if (_remarks != null && _remarks!.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ParishColors.backgroundLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ParishColors.borderGrey),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Remarks / History:', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: textMuted)),
                    const SizedBox(height: 2),
                    Text(_remarks!, style: TextStyle(fontSize: 11.5, color: textDark)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),

            // Status Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusSurface,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                isCompleted ? 'STATUS: CONCLUDED (READ-ONLY)' : 'STATUS: ${status.toUpperCase()}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: statusColor),
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (_isUpdating)
          const Center(child: Padding(padding: EdgeInsets.all(6.0), child: CircularProgressIndicator()))
        else ...[
          // Action Buttons: Strictly available ONLY if appointment is NOT completed and NOT cancelled
          if (canModify) ...[
            // 1. Reschedule Action
            if (_activeApt != null)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF7C3AED)),
                  foregroundColor: const Color(0xFF7C3AED),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () {
                  showRescheduleAppointmentModal(
                    context,
                    appointment: _activeApt!,
                    onRescheduled: widget.onStatusUpdated,
                  );
                },
                icon: const Icon(Icons.edit_calendar, size: 15),
                label: const Text('Reschedule', style: TextStyle(fontSize: 12)),
              ),

            // 2. Cancel Action
            TextButton(
              onPressed: () => _updateStatus('cancelled'),
              child: const Text('Cancel Booking',
                  style: TextStyle(color: ParishColors.mercyRed, fontWeight: FontWeight.bold, fontSize: 12)),
            ),

            // 3. Confirm Slot Action
            if (status == 'pending' || status == 'rescheduled')
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => _updateStatus('confirmed'),
                icon: const Icon(Icons.check_circle, size: 15),
                label: const Text('Confirm Slot', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),

            // 4. Mark Completed Action
            if (status == 'confirmed')
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ParishColors.marianBlue,
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => _updateStatus('completed'),
                child: const Text('Mark Completed', style: TextStyle(fontSize: 12)),
              ),
          ],

          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: textMuted, fontSize: 13)),
          ),
        ],
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: ParishColors.marianBlueAdaptive),
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