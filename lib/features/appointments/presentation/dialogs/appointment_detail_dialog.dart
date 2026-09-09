import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';

void showAppointmentDetailModal(
    BuildContext context, {
      required String refNo,
      required String serviceName,
      required String requester,
      required String contact,
      required String scheduleTime,
      required String officiant,
      required String status,
      required String feeStatus,
    }) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Appointment Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          Text(refNo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ParishColors.marianBlue)),
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
                  const Text('Service Requested', style: TextStyle(fontSize: 12, color: ParishColors.textMuted)),
                  Text(serviceName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ParishColors.marianBlue)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _buildDetailRow(Icons.person, 'Requester', requester),
            _buildDetailRow(Icons.phone, 'Contact', contact),
            _buildDetailRow(Icons.event, 'Scheduled Date', scheduleTime),
            _buildDetailRow(Icons.church, 'Officiating Clergy', officiant),
            _buildDetailRow(Icons.payments_outlined, 'Ecclesiastical Fee', feeStatus),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: status == 'CONFIRMED' ? ParishColors.oliveGreenSurface : ParishColors.goldLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'STATUS: $status',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: status == 'CONFIRMED' ? ParishColors.oliveGreen : ParishColors.goldAccent,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Close', style: TextStyle(fontSize: 15, color: ParishColors.textMuted)),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: ParishColors.marianBlue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => Navigator.pop(ctx),
          icon: const Icon(Icons.edit_calendar, size: 18),
          label: const Text('Reschedule'),
        ),
      ],
    ),
  );
}

Widget _buildDetailRow(IconData icon, String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: ParishColors.marianBlue),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 14, color: ParishColors.textDark),
              children: [
                TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.bold, color: ParishColors.textMuted)),
                TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}