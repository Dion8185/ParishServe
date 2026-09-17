import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../dashboard/presentation/widgets/dashboard_calendar_section.dart';
import '../services/secretary_service.dart';

class SecretaryDashboardWidget extends StatefulWidget {
  const SecretaryDashboardWidget({super.key});

  @override
  State<SecretaryDashboardWidget> createState() => _SecretaryDashboardWidgetState();
}

class _SecretaryDashboardWidgetState extends State<SecretaryDashboardWidget> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _appointments = [];
  double _totalCollections = 0.0;

  @override
  void initState() {
    super.initState();
    _loadSecretaryData();
  }

  Future<void> _loadSecretaryData() async {
    setState(() => _isLoading = true);
    try {
      final txns = await SecretaryService.getTransactions();
      final appts = await SecretaryService.getAppointments();

      double sum = 0.0;
      for (var t in txns) {
        sum += double.tryParse(t['amount_received'].toString()) ?? 0.0;
      }

      if (!mounted) return;
      setState(() {
        _transactions = txns;
        _appointments = appts;
        _totalCollections = sum;
      });
    } catch (e) {
      debugPrint('Error loading secretary data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Secretary Operational Header Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: ParishColors.marianBlueSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ParishColors.marianBlue.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.point_of_sale, size: 36, color: ParishColors.marianBlue),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Secretary Operational Desk',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Cashiering, Remittances & Parish Service Intake',
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
          const SizedBox(height: 20),

          // End-of-Day Remittance Summary Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: ParishColors.cardWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ParishColors.borderGrey),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Daily Cash Remittance (Talaan)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: ParishColors.oliveGreenSurface,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('Balanced', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ParishColors.oliveGreen)),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Registered Intake:', style: TextStyle(fontSize: 14, color: ParishColors.textMuted)),
                    Text('₱ ${_totalCollections.toStringAsFixed(2)}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: ParishColors.oliveGreen)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Transactions Issued:', style: TextStyle(fontSize: 13, color: ParishColors.textMuted)),
                    Text('${_transactions.length} Receipts', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Upcoming Appointments Quick View
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Today\'s Parish Appointments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
              Text('${_appointments.length} Booked', style: TextStyle(fontSize: 13, color: ParishColors.textMuted)),
            ],
          ),
          const SizedBox(height: 10),

          _isLoading
              ? const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
              : _appointments.isEmpty
              ? Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: ParishColors.cardWhite, borderRadius: BorderRadius.circular(12)),
            child: const Text('No appointments scheduled for today.'),
          )
              : Column(
            children: _appointments.take(3).map((apt) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: ParishColors.cardWhite,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ParishColors.borderGrey),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.event_available, color: ParishColors.marianBlue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(apt['service_name'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: ParishColors.textDark)),
                          Text('Requester: ${apt['requester_name']}', style: TextStyle(fontSize: 12, color: ParishColors.textMuted)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: ParishColors.goldLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(apt['appointment_status'] ?? 'CONFIRMED', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ParishColors.goldAccent)),
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