import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../models/appointment_model.dart';

void showAppointmentSubmissionSuccessModal(
    BuildContext context, {
      required AppointmentModel appointment,
      required String userEmail,
    }) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _AppointmentSubmissionSuccessDialog(
      appointment: appointment,
      userEmail: userEmail,
    ),
  );
}

class _AppointmentSubmissionSuccessDialog extends StatelessWidget {
  final AppointmentModel appointment;
  final String userEmail;

  const _AppointmentSubmissionSuccessDialog({
    required this.appointment,
    required this.userEmail,
  });

  /// Canonical & Civil requirements matrix per sacrament/service
  List<String> _getCanonicalRequirements(String serviceType) {
    final s = serviceType.toLowerCase();

    if (s.contains('wedding') || s.contains('nuptial')) {
      return [
        'PSA Authenticated Birth Certificate (Groom & Bride)',
        'PSA Certificate of No Marriage (CENOMAR) (Issued within 6 months)',
        'Newly Issued Baptismal Certificate with "FOR MARRIAGE PURPOSES" annotation (valid 6 months)',
        'Newly Issued Confirmation Certificate with "FOR MARRIAGE PURPOSES" annotation',
        'Pre-Cana Seminar Certificate of Attendance',
        'Canonical Interview with Parish Priest / Parochial Vicar',
        'Marriage License (LCR) or PSA Marriage Contract (if civilly married)',
        'Parish Marriage Banns (Tawag sa Simbahan) certificate from respective home parishes',
        'Official List of Principal Sponsors (Ninong & Ninang) and 2x2 ID Photos',
      ];
    } else if (s.contains('baptism')) {
      return [
        'PSA Authenticated Birth Certificate / Certified True Copy of Live Birth (Child)',
        'Parents\' PSA Catholic Marriage Contract (or Certificate of No Marriage/COLB Acknowledgement under Canon 877 if unmarried)',
        'Baptismal & Confirmation Certificates of Catholic Godparents (Ninong & Ninang)',
        'Pre-Baptismal Seminar Attendance Certificate (Parents & Sponsors)',
        'Photocopy of Valid Government ID of Parents',
      ];
    } else if (s.contains('funeral')) {
      return [
        'Certified True Copy of Death Certificate',
        'Burial / Transfer / Cremation Permit (from LCR or Municipal Health Office)',
        'Parish Sacramental Record / Reference (if deceased is a registered parishioner)',
        'Photocopy of Valid Government ID of the requesting next of kin',
      ];
    } else if (s.contains('anointing') || s.contains('sick call') || s.contains('blessing')) {
      return [
        'Exact residential address and landmark directions for the pastoral home visit',
        'Photocopy of Valid Government ID of the requesting family member',
      ];
    } else if (s.contains('thanksgiving') || s.contains('mass intention')) {
      return [
        'Printed or digital copy of booking confirmation reference',
        'Mass stipend / offering settlement receipt at the parish secretariat desk',
      ];
    } else if (s.contains('canonical interview') || s.contains('pre-cana')) {
      return [
        'PSA Birth Certificates of both parties',
        'Newly issued Baptismal and Confirmation certificates',
        'Valid Government IDs of the couple',
      ];
    } else {
      return [
        'Valid Government-Issued Identification Document of the requester',
        'Supporting pastoral or canonical documents requested by the Parish Office',
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final requirements = _getCanonicalRequirements(appointment.serviceType);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      backgroundColor: ParishColors.cardWhite,
      child: Container(
        width: double.maxFinite,
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
        child: Column(
          children: [
            // Top Header Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: BoxDecoration(
                color: ParishColors.marianBlueSurface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                border: Border(bottom: BorderSide(color: ParishColors.borderGrey)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: ParishColors.oliveGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Appointment Request Sent!',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textDark,
                          ),
                        ),
                        Text(
                          'Reference: ${appointment.appointmentId}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: ParishColors.marianBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Email Notification Advisory Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: ParishColors.goldLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: ParishColors.goldAccent.withValues(alpha: 0.6)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.mark_email_read_outlined,
                              color: ParishColors.goldAccent, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: 13,
                                  color: textDark,
                                  height: 1.4,
                                ),
                                children: [
                                  const TextSpan(
                                    text: 'Your appointment request has been submitted to the secretariat. We will notify you via your registered email at ',
                                  ),
                                  TextSpan(
                                    text: userEmail.isNotEmpty ? userEmail : 'your account email',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: ParishColors.marianBlue,
                                    ),
                                  ),
                                  const TextSpan(
                                    text: ' once the Parish Priest and staff review and approve your schedule.',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Service & Schedule Overview
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: ParishColors.backgroundLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: ParishColors.borderGrey),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                appointment.serviceType,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: ParishColors.marianBlue,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: ParishColors.goldLight,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'PENDING REVIEW',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: ParishColors.goldAccent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.calendar_today_outlined, size: 14, color: textMuted),
                              const SizedBox(width: 6),
                              Text(
                                '${appointment.formattedDate} • ${appointment.formattedTimeRange}',
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textDark),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined, size: 14, color: textMuted),
                              const SizedBox(width: 6),
                              Text(
                                'Venue: ${appointment.venue}',
                                style: TextStyle(fontSize: 12, color: textMuted),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Required Documents Checklist
                    Row(
                      children: [
                        const Icon(Icons.assignment_outlined, color: ParishColors.marianBlue, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Required Physical Documents to Submit',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: textDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Kindly bring clear physical copies of the following documents to the Parish Secretariat as soon as possible for canonical verification and final booking clearance:',
                      style: TextStyle(fontSize: 12, color: textMuted, height: 1.35),
                    ),
                    const SizedBox(height: 10),

                    ...requirements.map((req) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 4.0),
                              child: Icon(Icons.check_box_outlined,
                                  size: 16, color: ParishColors.marianBlue),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                req,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: textDark,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 18),

                    // Parish Office Schedule & Submission Guidelines
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: ParishColors.marianBlueSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: ParishColors.marianBlue.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.access_time_filled, size: 18, color: ParishColors.marianBlue),
                              const SizedBox(width: 8),
                              Text(
                                'Parish Office Schedule for Submissions',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: textDark,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '• Tuesday to Sunday: 8:00 AM – 12:00 PM | 1:30 PM – 5:00 PM\n'
                                '• Monday: Closed (Clergy Rest Day & Office Sanitation)\n'
                                '• Location: Parish Secretariat, St. John Paul II Parish, Brgy. Labuin, Sta. Cruz, Laguna',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: textMuted,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Modal Action Button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              decoration: BoxDecoration(
                color: ParishColors.cardWhite,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
                border: Border(top: BorderSide(color: ParishColors.borderGrey)),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ParishColors.marianBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'I Understand (Return to Portal)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}