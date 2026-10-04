// =============================================================================
// FILE: lib/features/dashboard/presentation/parishioner_dashboard_view.dart (PART 1 OF 2)
// =============================================================================

import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../auth/models/user_model.dart';
import '../../appointments/models/appointment_model.dart';
import '../../appointments/presentation/dialogs/schedule_appointment_dialog.dart';
import '../../appointments/presentation/dialogs/mass_intention_dialog.dart';
import '../../appointments/presentation/dialogs/parishioner_appointment_detail_dialog.dart';
import '../../auth/services/user_service.dart';
import '../../appointments/services/liturgical_calendar_service.dart';
import '../../receipts/presentation/dialogs/receipt_detail_dialog.dart';
import 'dialogs/pabuklat_request_dialog.dart';
import 'pages/parish_calendar_page.dart';
import 'dialogs/calendar_event_dialog.dart';
import 'widgets/daily_readings_card.dart';

class ParishionerDashboardView extends StatefulWidget {
  final UserModel currentUser;

  const ParishionerDashboardView({super.key, required this.currentUser});

  @override
  State<ParishionerDashboardView> createState() => _ParishionerDashboardViewState();
}

class _ParishionerDashboardViewState extends State<ParishionerDashboardView> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _myBookings = [];
  List<Map<String, dynamic>> _myReceipts = [];
  List<Map<String, dynamic>> _myServiceRequests = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    LiturgicalCalendarService.getCalendarForYear(DateTime.now().year).then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        UserService.getMyBookings(),
        UserService.getMyReceipts(),
        UserService.getMyServiceRequests(),
      ]);
      if (!mounted) return;
      setState(() {
        _myBookings = results[0];
        _myReceipts = results[1];
        _myServiceRequests = results[2];
      });
    } catch (e) {
      debugPrint('Error fetching parishioner data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getTimeBasedGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Good morning';
    if (hour >= 12 && hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  /// Identifies certificate requests with an assigned pickup date
  List<Map<String, dynamic>> get _readyForPickupRequests {
    return _myServiceRequests.where((r) {
      final status = (r['request_status'] ?? '').toString().toLowerCase();
      final hasPickupDate = r['pickup_date'] != null && r['pickup_date'].toString().isNotEmpty;
      return hasPickupDate && (status == 'ready_for_pickup' || status == 'approved' || status == 'signature_completed');
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth >= 900;
        final pickupAlerts = _readyForPickupRequests;

        return RefreshIndicator(
          onRefresh: _loadDashboardData,
          color: ParishColors.marianBlue,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 32 : 18,
              vertical: isDesktop ? 32 : 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroBanner(isDesktop),
                const SizedBox(height: 20),

                // Real-Time Alert Banner for Scheduled Pickup
                if (pickupAlerts.isNotEmpty) ...[
                  ...pickupAlerts.map((req) => _buildCertificatePickupAlertBanner(req)),
                  const SizedBox(height: 16),
                ],

                if (isDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // LEFT COLUMN: Actions & Tabbed Ledger Lists
                      Expanded(
                        flex: 7,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildQuickActionsGrid(isDesktop: true),
                            const SizedBox(height: 32),
                            _buildAppointmentsAndTransactionsTabs(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 28),
                      // RIGHT COLUMN: Calendar, Daily Readings, & Office Hours
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const DailyReadingsCard(),
                            const SizedBox(height: 24),
                            _buildMiniCalendarWidget(),
                            const SizedBox(height: 24),
                            _buildOfficeHoursWidget(),
                          ],
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildQuickActionsGrid(isDesktop: false),
                      const SizedBox(height: 24),
                      const DailyReadingsCard(),
                      const SizedBox(height: 24),
                      _buildMiniCalendarWidget(),
                      const SizedBox(height: 28),
                      _buildAppointmentsAndTransactionsTabs(),
                      const SizedBox(height: 24),
                      _buildOfficeHoursWidget(),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeroBanner(bool isDesktop) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isDesktop ? 36 : 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [ParishColors.marianBlue, ParishColors.marianBlueLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: ParishColors.marianBlue.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_getTimeBasedGreeting()}, ${widget.currentUser.firstName}!',
            style: TextStyle(
              fontSize: isDesktop ? 30 : 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Welcome to the St. John Paul II Parish Client Portal. Book sacraments, request mass intentions, track record requests, and view your official transaction receipts.',
            style: TextStyle(
              fontSize: isDesktop ? 15 : 13.5,
              color: Colors.white.withOpacity(0.9),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCertificatePickupAlertBanner(Map<String, dynamic> request) {
    final sacramentType = request['sacrament_type'] ?? 'Sacrament';
    final pickupDate = request['pickup_date']?.toString() ?? 'the scheduled date';
    final status = (request['request_status'] ?? '').toString().toLowerCase();
    final bool isReadyNow = status == 'ready_for_pickup';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isReadyNow ? ParishColors.oliveGreenSurface : ParishColors.goldLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isReadyNow ? ParishColors.oliveGreen : ParishColors.goldAccent,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isReadyNow ? ParishColors.oliveGreen : ParishColors.goldAccent).withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isReadyNow ? ParishColors.oliveGreen : ParishColors.goldAccent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isReadyNow ? Icons.verified : Icons.event_available,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isReadyNow ? 'CERTIFICATE READY FOR PICKUP!' : 'CERTIFICATE PICKUP SCHEDULED',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: isReadyNow ? ParishColors.oliveGreen : ParishColors.goldAccent,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'Ref: ${request["service_request_id"] ?? ""}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ParishColors.marianBlue),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Your $sacramentType Certificate has been approved.',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                ),
                const SizedBox(height: 2),
                Text(
                  'Pickup Date: $pickupDate • Please claim your physical certificate at the Parish Secretariat Office during office hours (Tue–Sun: 8AM–12PM | 1:30PM–5PM).',
                  style: TextStyle(fontSize: 12, color: ParishColors.textDark.withOpacity(0.85), height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid({required bool isDesktop}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Self-Service Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: ParishColors.textDark,
          ),
        ),
        const SizedBox(height: 14),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isDesktop ? 3 : 1,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: isDesktop ? 1.65 : 3.2,
          children: [
            _buildActionCard(
              title: 'Schedule Sacrament',
              subtitle: 'Weddings, Baptisms & Blessings',
              icon: Icons.edit_calendar,
              color: ParishColors.marianBlue,
              onTap: () => showScheduleAppointmentModal(context, onAppointmentSaved: _loadDashboardData),
            ),
            _buildActionCard(
              title: 'Mass Intentions',
              subtitle: 'Wed/Fri (5:30PM) • Sun (8AM/4PM)',
              icon: Icons.volunteer_activism,
              color: ParishColors.goldAccent,
              onTap: () => showMassIntentionModal(context, onIntentionSaved: _loadDashboardData),
            ),
            _buildActionCard(
              title: 'Request Record',
              subtitle: 'Baptismal & Marriage Certificates',
              icon: Icons.folder_shared,
              color: ParishColors.oliveGreen,
              onTap: () => showPabuklatRequestModal(context, onRequestSaved: _loadDashboardData),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: ParishColors.cardWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ParishColors.borderGrey),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: ParishColors.textDark,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: ParishColors.textMuted,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 18, color: ParishColors.borderGrey),
          ],
        ),
      ),
    );
  }
// =============================================================================
// FILE: lib/features/dashboard/presentation/parishioner_dashboard_view.dart (PART 2 OF 2)
// =============================================================================

  Widget _buildAppointmentsAndTransactionsTabs() {
    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TabBar(
                  labelColor: ParishColors.marianBlue,
                  unselectedLabelColor: ParishColors.textMuted,
                  indicatorColor: ParishColors.marianBlue,
                  indicatorWeight: 3,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                    Tab(text: 'My Appointments (${_myBookings.length})'),
                    Tab(text: 'Certificate Requests (${_myServiceRequests.length})'),
                    Tab(text: 'Transaction History (${_myReceipts.length})'),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: ParishColors.marianBlue),
                tooltip: 'Refresh Records',
                onPressed: _loadDashboardData,
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 440,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
              children: [
                _buildAppointmentsList(),
                _buildServiceRequestsList(),
                _buildTransactionsList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentsList() {
    if (_myBookings.isEmpty) {
      return _buildEmptyState(
        icon: Icons.event_note,
        title: 'No Active Bookings',
        message: 'Your scheduled sacraments and mass intentions will appear here.',
      );
    }
    return ListView.builder(
      itemCount: _myBookings.length,
      itemBuilder: (context, index) {
        final rawMap = _myBookings[index];
        final appointment = AppointmentModel.fromMap(rawMap);
        final status = appointment.appointmentStatus.toLowerCase();
        final isConfirmed = status == 'confirmed' || status == 'completed';
        final isCancelled = status == 'cancelled';

        Color statusColor = ParishColors.goldAccent;
        if (isConfirmed) {
          statusColor = ParishColors.oliveGreen;
        } else if (isCancelled) {
          statusColor = ParishColors.mercyRed;
        }

        return InkWell(
          onTap: () => showParishionerAppointmentDetailModal(
            context,
            appointment: appointment,
            onStatusUpdated: _loadDashboardData,
          ),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ParishColors.cardWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ParishColors.borderGrey),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ParishColors.marianBlueSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.bookmark, color: ParishColors.marianBlue),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              appointment.serviceType,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: ParishColors.textDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              appointment.appointmentStatus.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Scheduled: ${appointment.formattedDate} • ${appointment.formattedTimeRange}',
                        style: TextStyle(fontSize: 12.5, color: ParishColors.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Venue: ${appointment.venue}',
                        style: TextStyle(fontSize: 11.5, color: ParishColors.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: ParishColors.borderGrey, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // Dedicated Pabuklat / Certificate Requests Status Tracking List
  // ===========================================================================

  Widget _buildServiceRequestsList() {
    if (_myServiceRequests.isEmpty) {
      return _buildEmptyState(
        icon: Icons.folder_shared_outlined,
        title: 'No Certificate Requests Found',
        message: 'Tap "Request Record (Pabuklat)" above to request official certificates.',
      );
    }

    return ListView.builder(
      itemCount: _myServiceRequests.length,
      itemBuilder: (context, index) {
        final req = _myServiceRequests[index];
        final status = (req['request_status'] ?? 'submitted').toString().toLowerCase();
        final serviceType = req['service_type'] ?? 'Certificate Request';
        final pickupDate = req['pickup_date']?.toString();
        final rejectionReason = req['rejection_reason']?.toString();

        Color statusColor = ParishColors.goldAccent;
        String statusLabel = status.toUpperCase();

        if (status == 'submitted') {
          statusLabel = 'SUBMITTED';
          statusColor = ParishColors.goldAccent;
        } else if (status == 'record_verification') {
          statusLabel = 'RECORD VERIFICATION';
          statusColor = ParishColors.marianBlue;
        } else if (status == 'pending_secretary_approval') {
          statusLabel = 'PENDING SECRETARY APPROVAL';
          statusColor = ParishColors.goldAccent;
        } else if (status == 'approved' || status == 'signature_completed') {
          statusLabel = 'APPROVED';
          statusColor = ParishColors.oliveGreen;
        } else if (status == 'ready_for_pickup') {
          statusLabel = 'READY FOR PICKUP';
          statusColor = ParishColors.oliveGreen;
        } else if (status == 'released') {
          statusLabel = 'RELEASED / CLAIMED';
          statusColor = ParishColors.marianBlue;
        } else if (status == 'rejected') {
          statusLabel = 'REJECTED';
          statusColor = ParishColors.mercyRed;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ParishColors.cardWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: status == 'ready_for_pickup'
                  ? ParishColors.oliveGreen
                  : ParishColors.borderGrey,
              width: status == 'ready_for_pickup' ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        req['service_request_id'] ?? 'REQ-XXXX',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ParishColors.marianBlue),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    req['sacrament_type'] ?? 'Certificate',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                serviceType.toString(),
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: ParishColors.textDark),
              ),
              if (req['matched_record_summary'] != null) ...[
                const SizedBox(height: 2),
                Text(
                  'Record: ${req["matched_record_summary"]}',
                  style: TextStyle(fontSize: 12, color: ParishColors.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),

              // Scheduled Pickup Notification
              if (pickupDate != null && status != 'rejected') ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: status == 'ready_for_pickup' ? ParishColors.oliveGreenSurface : ParishColors.goldLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: status == 'ready_for_pickup'
                          ? ParishColors.oliveGreen.withOpacity(0.4)
                          : ParishColors.goldAccent.withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        status == 'ready_for_pickup' ? Icons.verified : Icons.event_available,
                        size: 16,
                        color: status == 'ready_for_pickup' ? ParishColors.oliveGreen : ParishColors.goldAccent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          status == 'ready_for_pickup'
                              ? 'Certificate is ready! Claim at Parish Office (Pickup Date: $pickupDate).'
                              : 'Scheduled Pickup Date: $pickupDate at the Parish Office.',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: status == 'ready_for_pickup' ? ParishColors.oliveGreen : ParishColors.textDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (rejectionReason != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Rejection Notice: $rejectionReason',
                  style: const TextStyle(fontSize: 11.5, color: ParishColors.mercyRed, fontWeight: FontWeight.bold),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ===========================================================================
  // Interactive Transaction History with Official Receipt Detail Modal Launch
  // ===========================================================================

  Widget _buildTransactionsList() {
    if (_myReceipts.isEmpty) {
      return _buildEmptyState(
        icon: Icons.receipt_long,
        title: 'No Transactions Found',
        message: 'Official parish receipts and offerings will appear here.',
      );
    }

    return ListView.builder(
      itemCount: _myReceipts.length,
      itemBuilder: (context, index) {
        final t = _myReceipts[index];
        final rawAmount = t['transaction_amount'];
        final double amountVal = (rawAmount is num)
            ? rawAmount.toDouble()
            : (double.tryParse(rawAmount?.toString() ?? '0') ?? 0.0);
        final service = (t['related_service'] ?? t['transaction_type'] ?? 'Parish Offering').toString();
        final date = (t['transaction_date'] ?? t['created_at'] ?? '').toString();
        final dateDisplay = date.length >= 10 ? date.substring(0, 10) : date;
        final receiptNo = (t['receipt_number'] ?? 'REC-XXXX').toString();
        final status = (t['transaction_status'] ?? 'paid').toString().toUpperCase();

        // Determine payment tender mode
        final details = (t['transaction_details'] ?? '').toString().toLowerCase();
        final type = (t['transaction_type'] ?? '').toString().toLowerCase();
        String tenderMode = 'Cash';
        Color tenderColor = ParishColors.oliveGreen;

        if (details.contains('tender mode: gcash') || details.contains('gcash ref') || type == 'gcash') {
          tenderMode = 'GCash';
          tenderColor = const Color(0xFF005CEE);
        } else if (details.contains('tender mode: gratis') || type == 'gratis' || amountVal == 0.0) {
          tenderMode = 'Gratis';
          tenderColor = ParishColors.goldAccent;
        }

        final bool isVoided = status.contains('VOID') || status.contains('CANCEL') || details.contains('[VOIDED');

        return InkWell(
          onTap: () {
            showReceiptDetailModal(
              context,
              receiptNo: receiptNo,
              payer: t['payor_name'] ?? widget.currentUser.fullName,
              purpose: service,
              amount: '₱ ${amountVal.toStringAsFixed(2)}',
              date: dateDisplay,
              payorContact: t['payor_contact']?.toString(),
              transactionDetails: t['transaction_details']?.toString(),
              paymentMode: tenderMode,
              transactionId: t['transaction_id']?.toString(),
              status: status,
              onTransactionUpdated: _loadDashboardData,
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isVoided ? const Color(0xFFFEF2F2) : ParishColors.cardWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isVoided ? ParishColors.mercyRed.withOpacity(0.5) : ParishColors.borderGrey,
                width: isVoided ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isVoided
                        ? ParishColors.mercyRedSurface
                        : tenderColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isVoided ? Icons.block : Icons.receipt_long,
                    color: isVoided ? ParishColors.mercyRed : tenderColor,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                receiptNo,
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: ParishColors.marianBlue),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isVoided
                                      ? ParishColors.mercyRedSurface
                                      : tenderColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isVoided ? 'VOIDED' : tenderMode.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: isVoided ? ParishColors.mercyRed : tenderColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '₱ ${amountVal.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isVoided ? ParishColors.mercyRed : ParishColors.oliveGreen,
                              decoration: isVoided ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        service,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: ParishColors.textDark,
                          decoration: isVoided ? TextDecoration.lineThrough : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Date: $dateDisplay',
                            style: TextStyle(fontSize: 11.5, color: ParishColors.textMuted),
                          ),
                          Row(
                            children: [
                              Text(
                                'View Voucher',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: ParishColors.marianBlue,
                                ),
                              ),
                              const SizedBox(width: 3),
                              const Icon(Icons.arrow_forward_ios, size: 10, color: ParishColors.marianBlue),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ParishColors.borderGrey, width: 1.2),
      ),
      child: Column(
        children: [
          Icon(icon, size: 50, color: ParishColors.borderGrey),
          const SizedBox(height: 14),
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
          const SizedBox(height: 4),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: ParishColors.textMuted, fontSize: 12.5)),
        ],
      ),
    );
  }

  Widget _buildMiniCalendarWidget() {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
    final totalDays = lastDayOfMonth.day;
    final offset = firstDayOfMonth.weekday % 7;
    final totalGridCells = ((totalDays + offset) / 7).ceil() * 7;
    final daysOfWeek = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ParishColors.borderGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Parish Calendar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ParishColors.textDark),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ParishCalendarPage()),
                ),
                child: const Text('Open Full', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ParishColors.marianBlue)),
              )
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: daysOfWeek
                .map((d) => SizedBox(
              width: 28,
              child: Text(
                d,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, color: ParishColors.marianBlue, fontSize: 12),
              ),
            ))
                .toList(),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: totalGridCells,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 5,
              crossAxisSpacing: 5,
            ),
            itemBuilder: (context, index) {
              final dayNumber = index - offset + 1;
              if (dayNumber < 1 || dayNumber > totalDays) {
                return const SizedBox.shrink();
              }

              final cellDate = DateTime(now.year, now.month, dayNumber);
              final feasts = LiturgicalCalendarService.getCelebrationsForDateSync(cellDate);
              final hasFeast = feasts.isNotEmpty;
              final isToday = dayNumber == now.day;

              return InkWell(
                onTap: () {
                  if (hasFeast) {
                    showCalendarEventModal(
                      context,
                      date: '${cellDate.month}/${cellDate.day}/${cellDate.year}',
                      eventTitle: feasts.first.name,
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ParishCalendarPage()),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: BoxDecoration(
                    color: isToday
                        ? ParishColors.marianBlue
                        : (hasFeast ? feasts.first.liturgicalColor.withOpacity(0.15) : Colors.transparent),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isToday
                          ? ParishColors.marianBlue
                          : (hasFeast ? feasts.first.liturgicalColor : Colors.transparent),
                      width: 1.2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$dayNumber',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: (hasFeast || isToday) ? FontWeight.bold : FontWeight.normal,
                        color: isToday
                            ? Colors.white
                            : (hasFeast ? ParishColors.textDark : ParishColors.textMuted),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOfficeHoursWidget() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ParishColors.backgroundLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ParishColors.borderGrey),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: ParishColors.marianBlue, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Parish Secretariat Schedule',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: ParishColors.textDark),
                ),
                const SizedBox(height: 4),
                Text(
                  '• Tuesday – Sunday: 8:00 AM – 12:00 PM | 1:30 PM – 5:00 PM\n• Monday: Closed (Clergy Rest Day)',
                  style: TextStyle(fontSize: 12, color: ParishColors.textMuted, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}