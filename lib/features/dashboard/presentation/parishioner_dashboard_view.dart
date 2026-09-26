import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../auth/models/user_model.dart';
import '../../appointments/models/appointment_model.dart';
import '../../appointments/presentation/dialogs/schedule_appointment_dialog.dart';
import '../../appointments/presentation/dialogs/mass_intention_dialog.dart';
import '../../appointments/presentation/dialogs/parishioner_appointment_detail_dialog.dart';
import '../../auth/services/user_service.dart';
import '../../appointments/services/liturgical_calendar_service.dart';
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
      ]);
      if (!mounted) return;
      setState(() {
        _myBookings = results[0];
        _myReceipts = results[1];
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth >= 900;

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
                const SizedBox(height: 28),

                if (isDesktop)
                // DESKTOP LAYOUT (2 Columns)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // LEFT COLUMN: Self-Service Actions & Bookings/Receipts Tabs
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
                      // RIGHT COLUMN: Calendar, Daily Scripture Readings, & Office Hours
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
                // MOBILE LAYOUT (Single Stack)
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
            'Welcome to the St. John Paul II Parish Client Portal. Book sacraments, request mass intentions, and track your parish contributions directly from this portal.',
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
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: isDesktop ? 2.3 : 3.8,
          children: [
            _buildActionCard(
              title: 'Schedule Sacrament',
              subtitle: 'Baptisms, Weddings & Blessings',
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
              title: 'Request Record (Pabuklat)',
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
        padding: const EdgeInsets.all(16),
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
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: ParishColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: ParishColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: ParishColors.borderGrey),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentsAndTransactionsTabs() {
    return DefaultTabController(
      length: 2,
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
                  tabs: const [
                    Tab(text: 'My Appointments'),
                    Tab(text: 'Transaction History'),
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
            height: 420,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
              children: [
                _buildAppointmentsList(),
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
        final statusColor = isConfirmed ? ParishColors.oliveGreen : ParishColors.goldAccent;

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
                          Text(
                            appointment.serviceType,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: ParishColors.textDark,
                            ),
                          ),
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
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Venue: ${appointment.venue}',
                        style: TextStyle(fontSize: 11.5, color: ParishColors.textMuted),
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
        final amount = t['transaction_amount'] ?? 0.00;
        final service = t['related_service'] ?? t['transaction_type'] ?? 'Parish Transaction';
        final date = (t['transaction_date'] ?? t['created_at'] ?? '').toString();
        final dateDisplay = date.length >= 10 ? date.substring(0, 10) : date;

        return Container(
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
                  color: ParishColors.oliveGreenSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.receipt, color: ParishColors.oliveGreen),
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
                          t['receipt_number'] ?? 'REC-XXXX',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: ParishColors.marianBlue),
                        ),
                        Text(
                          '₱ $amount',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ParishColors.oliveGreen),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      service.toString(),
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                    ),
                    Text(
                      'Issued: $dateDisplay',
                      style: TextStyle(fontSize: 11.5, color: ParishColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
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