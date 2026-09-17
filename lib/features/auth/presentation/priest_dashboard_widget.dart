import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../dashboard/presentation/widgets/dashboard_calendar_section.dart';
import '../services/priest_service.dart';

class PriestDashboardWidget extends StatefulWidget {
  const PriestDashboardWidget({super.key});

  @override
  State<PriestDashboardWidget> createState() => _PriestDashboardWidgetState();
}

class _PriestDashboardWidgetState extends State<PriestDashboardWidget> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _pendingCerts = [];

  @override
  void initState() {
    super.initState();
    _loadPriestQueue();
  }

  Future<void> _loadPriestQueue() async {
    setState(() => _isLoading = true);
    try {
      final certs = await PriestService.getPendingCertificates();
      if (!mounted) return;
      setState(() {
        _pendingCerts = certs;
      });
    } catch (e) {
      debugPrint('Error loading priest queue: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signCertificate(String recordId, String childName) async {
    try {
      await PriestService.approveCertificate(recordId);
      _loadPriestQueue();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Certificate for $childName digitally signed and approved.'),
          backgroundColor: ParishColors.oliveGreen,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Approval failed: $e'), backgroundColor: ParishColors.mercyRed),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Executive Parish Priest Header Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: ParishColors.marianBlueSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ParishColors.goldAccent, width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ParishColors.marianBlue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.verified, size: 32, color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Parish Priest Executive Desk',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Canonical Oversight, Certificate Sign-offs & Archive Custody',
                        style: TextStyle(fontSize: 13, color: ParishColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // INTEGRATED CALENDAR SECTION WITH MAIN CALENDAR BUTTON
          const DashboardCalendarSection(),
          const SizedBox(height: 24),

          // Pending Certificate Approvals Queue
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Pending Certificate Approvals', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: ParishColors.goldLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('${_pendingCerts.length} Awaiting', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ParishColors.goldAccent)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          _isLoading
              ? const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
              : _pendingCerts.isEmpty
              ? Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: ParishColors.cardWhite,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ParishColors.borderGrey),
            ),
            child: Column(
              children: [
                const Icon(Icons.check_circle_outline, size: 40, color: ParishColors.oliveGreen),
                const SizedBox(height: 8),
                Text('All sacramental certificates have been signed.', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
                Text('No pending clearances in the queue.', style: TextStyle(fontSize: 13, color: ParishColors.textMuted)),
              ],
            ),
          )
              : Column(
            children: _pendingCerts.map((cert) {
              final childName = '${cert['child_first_name']} ${cert['child_last_name']}';
              final recordId = cert['record_id'];
              final ref = 'Book ${cert['book_number']}, Page ${cert['page_number']}, Line ${cert['line_number']}';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ParishColors.cardWhite,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ParishColors.borderGrey),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(recordId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: ParishColors.marianBlue)),
                        Text('BAPTISM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ParishColors.textMuted)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(childName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
                    Text(ref, style: TextStyle(fontSize: 13, color: ParishColors.textMuted)),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom( // Corrected from styleFor to styleFrom
                          backgroundColor: ParishColors.marianBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _signCertificate(recordId, childName),
                        icon: const Icon(Icons.draw, size: 18),
                        label: const Text('Affix Digital Signature & Approve', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}