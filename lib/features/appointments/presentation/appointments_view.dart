import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../models/appointment_model.dart';
import '../models/mass_intention_model.dart';
import '../services/appointment_service.dart';
import '../services/mass_intention_service.dart';
import 'dialogs/schedule_appointment_dialog.dart';
import 'dialogs/mass_intention_dialog.dart';
import 'dialogs/reschedule_mass_intention_dialog.dart';
import 'widgets/appointment_card.dart';

class AppointmentsView extends StatefulWidget {
  const AppointmentsView({super.key});

  @override
  State<AppointmentsView> createState() => _AppointmentsViewState();
}

class _AppointmentsViewState extends State<AppointmentsView> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _mainTabController;

  // Sacramental Appointments Data
  List<AppointmentModel> _appointments = [];
  bool _isLoadingAppointments = false;
  String? _appointmentsError;

  // Mass Intentions Data
  List<MassIntentionModel> _massIntentions = [];
  bool _isLoadingIntentions = false;
  String? _intentionsError;

  // Filtering State
  String _selectedFilter = 'All';
  String _selectedDateRangeFilter = 'All Dates';
  String _sortBy = 'Date: Earliest First';
  String _searchQuery = '';

  // Secretary Mass Intention View Mode (By Mass Slot vs By Requester)
  bool _groupByMassSchedule = true;

  // Pagination State
  int _currentPage = 1;
  int _itemsPerPage = 10;

  final List<String> _filterTabs = [
    'All',
    'Pending',
    'Confirmed',
    'Rescheduled',
    'Completed',
    'Cancelled',
  ];

  final List<String> _dateRangeOptions = [
    'All Dates',
    'Today',
    'This Week',
    'This Month',
    'Upcoming Only',
  ];

  final List<String> _sortOptions = [
    'Date: Earliest First',
    'Date: Latest First',
    'Service / Mass Slot',
    'Requester Name',
  ];

  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(length: 2, vsync: this);
    _mainTabController.addListener(() {
      if (!_mainTabController.indexIsChanging) {
        setState(() {
          _currentPage = 1;
        });
      }
    });
    _loadAllData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mainTabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    _loadAppointments();
    _loadMassIntentions();
  }

  Future<void> _loadAppointments() async {
    setState(() {
      _isLoadingAppointments = true;
      _appointmentsError = null;
    });

    try {
      final data = await AppointmentService.getAppointments();
      if (!mounted) return;
      setState(() => _appointments = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _appointmentsError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoadingAppointments = false);
    }
  }

  Future<void> _loadMassIntentions() async {
    setState(() {
      _isLoadingIntentions = true;
      _intentionsError = null;
    });

    try {
      final data = await MassIntentionService.getMassIntentions();
      if (!mounted) return;
      setState(() => _massIntentions = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _intentionsError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoadingIntentions = false);
    }
  }

  // ===========================================================================
  // Mass Intentions Nearest Slot Calculator & Grouping
  // ===========================================================================

  Map<String, List<MassIntentionModel>> get _groupedMassIntentions {
    final Map<String, List<MassIntentionModel>> groups = {};
    for (final item in _processedMassIntentions) {
      final key = '${item.formattedDate} • ${item.formattedTime12Hour}';
      groups.putIfAbsent(key, () => []).add(item);
    }
    return groups;
  }

  MapEntry<String, List<MassIntentionModel>>? get _nearestUpcomingMassSlot {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final futureEntries = _groupedMassIntentions.entries.where((entry) {
      final item = entry.value.first;
      return !item.scheduledDate.isBefore(today);
    }).toList();

    if (futureEntries.isEmpty) return null;
    return futureEntries.first;
  }

  // ===========================================================================
  // Data Filtering & Sorting Logic
  // ===========================================================================

  List<AppointmentModel> get _processedAppointments {
    var list = List<AppointmentModel>.from(_appointments);

    if (_selectedFilter != 'All') {
      list = list.where((a) => a.appointmentStatus.toLowerCase() == _selectedFilter.toLowerCase()).toList();
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_selectedDateRangeFilter == 'Today') {
      list = list.where((a) => a.requestedDate.year == today.year && a.requestedDate.month == today.month && a.requestedDate.day == today.day).toList();
    } else if (_selectedDateRangeFilter == 'This Week') {
      final startOfWeek = today.subtract(Duration(days: today.weekday % 7));
      final endOfWeek = startOfWeek.add(const Duration(days: 6, hours: 23, minutes: 59));
      list = list.where((a) => !a.requestedDate.isBefore(startOfWeek) && !a.requestedDate.isAfter(endOfWeek)).toList();
    } else if (_selectedDateRangeFilter == 'This Month') {
      list = list.where((a) => a.requestedDate.year == today.year && a.requestedDate.month == today.month).toList();
    } else if (_selectedDateRangeFilter == 'Upcoming Only') {
      list = list.where((a) => !a.requestedDate.isBefore(today)).toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      list = list.where((a) {
        return a.requesterName.toLowerCase().contains(q) ||
            a.serviceType.toLowerCase().contains(q) ||
            a.appointmentId.toLowerCase().contains(q) ||
            a.venue.toLowerCase().contains(q) ||
            a.contactNumber.toLowerCase().contains(q) ||
            (a.email ?? '').toLowerCase().contains(q);
      }).toList();
    }

    if (_sortBy == 'Date: Earliest First') {
      list.sort((a, b) => a.requestedDate.compareTo(b.requestedDate));
    } else if (_sortBy == 'Date: Latest First') {
      list.sort((a, b) => b.requestedDate.compareTo(a.requestedDate));
    } else if (_sortBy == 'Service / Mass Slot') {
      list.sort((a, b) => a.serviceType.compareTo(b.serviceType));
    } else if (_sortBy == 'Requester Name') {
      list.sort((a, b) => a.requesterName.compareTo(b.requesterName));
    }

    return list;
  }

  List<MassIntentionModel> get _processedMassIntentions {
    var list = List<MassIntentionModel>.from(_massIntentions);

    if (_selectedFilter != 'All') {
      list = list.where((m) => m.intentionStatus.toLowerCase() == _selectedFilter.toLowerCase()).toList();
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_selectedDateRangeFilter == 'Today') {
      list = list.where((m) => m.scheduledDate.year == today.year && m.scheduledDate.month == today.month && m.scheduledDate.day == today.day).toList();
    } else if (_selectedDateRangeFilter == 'This Week') {
      final startOfWeek = today.subtract(Duration(days: today.weekday % 7));
      final endOfWeek = startOfWeek.add(const Duration(days: 6, hours: 23, minutes: 59));
      list = list.where((m) => !m.scheduledDate.isBefore(startOfWeek) && !m.scheduledDate.isAfter(endOfWeek)).toList();
    } else if (_selectedDateRangeFilter == 'This Month') {
      list = list.where((m) => m.scheduledDate.year == today.year && m.scheduledDate.month == today.month).toList();
    } else if (_selectedDateRangeFilter == 'Upcoming Only') {
      list = list.where((m) => !m.scheduledDate.isBefore(today)).toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      list = list.where((m) {
        final names = [...m.thanksgivingList, ...m.reposeSoulsList, ...m.specialIntentionsList, m.otherIntentions ?? ''].join(' ').toLowerCase();
        return m.requesterName.toLowerCase().contains(q) ||
            m.intentionId.toLowerCase().contains(q) ||
            m.contactNumber.toLowerCase().contains(q) ||
            (m.email ?? '').toLowerCase().contains(q) ||
            names.contains(q);
      }).toList();
    }

    if (_sortBy == 'Date: Earliest First') {
      list.sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
    } else if (_sortBy == 'Date: Latest First') {
      list.sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));
    } else if (_sortBy == 'Requester Name') {
      list.sort((a, b) => a.requesterName.compareTo(b.requesterName));
    }

    return list;
  }

  int get _totalPages {
    final total = _mainTabController.index == 0 ? _processedAppointments.length : _processedMassIntentions.length;
    if (total == 0) return 1;
    return (total / _itemsPerPage).ceil();
  }

  void _onFilterChanged() {
    setState(() => _currentPage = 1);
  }

  @override
  Widget build(BuildContext context) {
    final textDarkColor = ParishColors.textDark;
    final textMutedColor = ParishColors.textMuted;
    final cardWhiteColor = ParishColors.cardWhite;
    final borderGreyColor = ParishColors.borderGrey;

    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Title Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Parish Scheduling & Liturgy Desk',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textDarkColor),
                    ),
                    Text(
                      'Manage sacramental ceremonies, weddings, baptisms & Mass intention registries',
                      style: TextStyle(color: textMutedColor, fontSize: 13),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: ParishColors.marianBlue),
                  onPressed: _loadAllData,
                  tooltip: 'Reload Database Records',
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Top Primary Booking Action Buttons (Dual Buttons)
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 650;
                return isWide
                    ? Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ParishColors.marianBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => showScheduleAppointmentModal(context, onAppointmentSaved: _loadAppointments),
                          icon: const Icon(Icons.add_task, size: 20),
                          label: const Text('+ Book Sacrament / Service', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ParishColors.goldAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => showMassIntentionModal(context, onIntentionSaved: _loadMassIntentions),
                          icon: const Icon(Icons.volunteer_activism, size: 20),
                          label: const Text('+ Book Mass Intention (Walk-In)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ],
                )
                    : Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ParishColors.marianBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => showScheduleAppointmentModal(context, onAppointmentSaved: _loadAppointments),
                        icon: const Icon(Icons.add_task, size: 20),
                        label: const Text('+ Book Sacrament / Service', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ParishColors.goldAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => showMassIntentionModal(context, onIntentionSaved: _loadMassIntentions),
                        icon: const Icon(Icons.volunteer_activism, size: 20),
                        label: const Text('+ Book Mass Intention (Walk-In)', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),

            // Main Module Switcher (Tabs)
            Container(
              decoration: BoxDecoration(
                color: ParishColors.backgroundLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderGreyColor),
              ),
              child: TabBar(
                controller: _mainTabController,
                labelColor: Colors.white,
                unselectedLabelColor: textMutedColor,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: ParishColors.marianBlue,
                  borderRadius: BorderRadius.circular(10),
                ),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.church, size: 18),
                        const SizedBox(width: 8),
                        Text('Sacraments & Services (${_appointments.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.volunteer_activism, size: 18),
                        const SizedBox(width: 8),
                        Text('Mass Intentions Registry (${_massIntentions.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Search Bar
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: cardWhiteColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderGreyColor),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 22, color: ParishColors.marianBlue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) {
                        setState(() => _searchQuery = val);
                        _onFilterChanged();
                      },
                      style: TextStyle(fontSize: 13.5, color: textDarkColor),
                      decoration: InputDecoration(
                        hintText: 'Search by requester, intention name, phone, reference ID...',
                        hintStyle: TextStyle(fontSize: 12.5, color: textMutedColor),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                        _onFilterChanged();
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Filters & Sorters
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 650;
                return isWide
                    ? Row(
                  children: [
                    Expanded(child: _buildDateRangeDropdown()),
                    const SizedBox(width: 12),
                    Expanded(child: _buildSortDropdown()),
                  ],
                )
                    : Column(
                  children: [
                    _buildDateRangeDropdown(),
                    const SizedBox(height: 10),
                    _buildSortDropdown(),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),

            // Status Tabs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filterTabs.map((tab) {
                  final isSelected = _selectedFilter == tab;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: InkWell(
                      onTap: () {
                        setState(() => _selectedFilter = tab);
                        _onFilterChanged();
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: isSelected ? ParishColors.marianBlue : cardWhiteColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isSelected ? ParishColors.marianBlue : borderGreyColor),
                        ),
                        child: Text(
                          tab,
                          style: TextStyle(
                            color: isSelected ? Colors.white : textMutedColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 18),

            // Render Tab Content
            if (_mainTabController.index == 0)
              _buildSacramentalAppointmentsTab()
            else
              _buildMassIntentionsTab(),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 1: SACRAMENTAL APPOINTMENTS VIEW
  // ===========================================================================
  Widget _buildSacramentalAppointmentsTab() {
    final processed = _processedAppointments;
    final totalItems = processed.length;
    final start = (_currentPage - 1) * _itemsPerPage;
    final end = min(start + _itemsPerPage, totalItems);
    final paged = (start >= totalItems) ? <AppointmentModel>[] : processed.sublist(start, end);

    if (_isLoadingAppointments) {
      return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
    }

    if (_appointmentsError != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: ParishColors.mercyRedSurface, borderRadius: BorderRadius.circular(12)),
        child: Text('Error: $_appointmentsError', style: const TextStyle(color: ParishColors.mercyRed)),
      );
    }

    if (processed.isEmpty) {
      return _buildEmptyState('No matching sacramental appointments found.');
    }

    return Column(
      children: [
        ...paged.map((apt) => AppointmentCard(appointment: apt, onRefresh: _loadAppointments)),
        const SizedBox(height: 14),
        _buildPaginationToolbar(totalItems),
      ],
    );
  }

  // ===========================================================================
  // TAB 2: MASS INTENTIONS REGISTRY VIEW
  // ===========================================================================
  Widget _buildMassIntentionsTab() {
    final processed = _processedMassIntentions;
    final totalItems = processed.length;
    final nearest = _nearestUpcomingMassSlot;

    if (_isLoadingIntentions) {
      return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
    }

    if (_intentionsError != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: ParishColors.mercyRedSurface, borderRadius: BorderRadius.circular(12)),
        child: Text('Error: $_intentionsError', style: const TextStyle(color: ParishColors.mercyRed)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Highlight Card: Nearest Upcoming Mass Schedule Summary
        if (nearest != null) ...[
          _buildNearestMassBanner(nearest),
          const SizedBox(height: 18),
        ],

        // 2. Secretary View Mode Switcher
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ParishColors.cardWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ParishColors.borderGrey),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Organization Layout:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('Group by Mass Slot', style: TextStyle(fontSize: 11.5)),
                    selected: _groupByMassSchedule,
                    selectedColor: ParishColors.marianBlueSurface,
                    labelStyle: TextStyle(color: _groupByMassSchedule ? ParishColors.marianBlue : ParishColors.textMuted, fontWeight: FontWeight.bold),
                    onSelected: (val) => setState(() => _groupByMassSchedule = true),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Per Requester / Entry', style: TextStyle(fontSize: 11.5)),
                    selected: !_groupByMassSchedule,
                    selectedColor: ParishColors.marianBlueSurface,
                    labelStyle: TextStyle(color: !_groupByMassSchedule ? ParishColors.marianBlue : ParishColors.textMuted, fontWeight: FontWeight.bold),
                    onSelected: (val) => setState(() => _groupByMassSchedule = false),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 3. Render Intentions by Mode
        if (processed.isEmpty)
          _buildEmptyState('No mass intentions registered under this filter.')
        else if (_groupByMassSchedule)
          ..._buildGroupedMassSlotsView()
        else
          ..._buildPerRequesterIntentionsView(totalItems),
      ],
    );
  }

  Widget _buildNearestMassBanner(MapEntry<String, List<MassIntentionModel>> nearest) {
    final slotTitle = nearest.key;
    final items = nearest.value;

    int totalThanksgiving = 0;
    int totalSouls = 0;
    int totalSpecial = 0;
    int totalOthers = 0;

    for (var m in items) {
      totalThanksgiving += m.thanksgivingList.length;
      totalSouls += m.reposeSoulsList.length;
      totalSpecial += m.specialIntentionsList.length;
      if (m.otherIntentions != null && m.otherIntentions!.isNotEmpty) totalOthers++;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ParishColors.goldAccent, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(color: ParishColors.goldAccent, shape: BoxShape.circle),
                    child: const Icon(Icons.church, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text('Next Scheduled Holy Mass', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ParishColors.goldAccent)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: ParishColors.goldAccent, borderRadius: BorderRadius.circular(12)),
                child: Text('${items.length} Intention Slips', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),
          const Divider(height: 20),
          Text(slotTitle, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _buildIntentionCounterChip('🕊️ Thanksgiving', totalThanksgiving, ParishColors.marianBlue),
              _buildIntentionCounterChip('✝️ Repose of Souls', totalSouls, const Color(0xFF7C3AED)),
              _buildIntentionCounterChip('🙏 Special Intentions', totalSpecial, ParishColors.oliveGreen),
              if (totalOthers > 0) _buildIntentionCounterChip('📝 Others', totalOthers, ParishColors.goldAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIntentionCounterChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text('$label: $count', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
    );
  }

  List<Widget> _buildGroupedMassSlotsView() {
    final groups = _groupedMassIntentions;

    return groups.entries.map((entry) {
      final slotKey = entry.key;
      final intentions = entry.value;

      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: ParishColors.cardWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ParishColors.borderGrey),
        ),
        child: ExpansionTile(
          initiallyExpanded: true,
          shape: Border.all(color: Colors.transparent),
          title: Row(
            children: [
              const Icon(Icons.event, size: 20, color: ParishColors.marianBlue),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  slotKey,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: ParishColors.textDark),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: ParishColors.goldLight, borderRadius: BorderRadius.circular(6)),
                child: Text('${intentions.length} Slips', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ParishColors.goldAccent)),
              ),
            ],
          ),
          children: [
            const Divider(height: 1),
            ...intentions.map((item) => _buildMassIntentionListItem(item)),
          ],
        ),
      );
    }).toList();
  }

  List<Widget> _buildPerRequesterIntentionsView(int totalItems) {
    final start = (_currentPage - 1) * _itemsPerPage;
    final end = min(start + _itemsPerPage, totalItems);
    final paged = (start >= totalItems) ? <MassIntentionModel>[] : _processedMassIntentions.sublist(start, end);

    return [
      ...paged.map((item) => _buildMassIntentionListItem(item)),
      const SizedBox(height: 14),
      _buildPaginationToolbar(totalItems),
    ];
  }

  Widget _buildMassIntentionListItem(MassIntentionModel item) {
    final status = item.intentionStatus.toLowerCase();
    Color statusColor = status == 'confirmed' ? ParishColors.oliveGreen : ParishColors.goldAccent;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 10),
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
              Row(
                children: [
                  Text(item.intentionId, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ParishColors.marianBlue)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                    child: Text(item.intentionStatus.toUpperCase(), style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: statusColor)),
                  ),
                ],
              ),
              Text('₱ ${item.stipendAmount.toStringAsFixed(2)} (${item.paymentMethod})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ParishColors.oliveGreen)),
            ],
          ),
          const SizedBox(height: 6),
          Text('Requester: ${item.requesterName} (${item.contactNumber})', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
          const SizedBox(height: 8),

          // Categorized Intentions Listing
          if (item.thanksgivingList.isNotEmpty) ...[
            _buildCategoryRow('🕊️ Thanksgiving:', item.thanksgivingList.join(', ')),
          ],
          if (item.reposeSoulsList.isNotEmpty) ...[
            _buildCategoryRow('✝️ Repose of Souls:', item.reposeSoulsList.join(', ')),
          ],
          if (item.specialIntentionsList.isNotEmpty) ...[
            _buildCategoryRow('🙏 Special Intentions:', item.specialIntentionsList.join(', ')),
          ],
          if (item.otherIntentions != null && item.otherIntentions!.isNotEmpty) ...[
            _buildCategoryRow('📝 Others:', item.otherIntentions!),
          ],

          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF7C3AED)),
                  foregroundColor: const Color(0xFF7C3AED),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                onPressed: () {
                  showRescheduleMassIntentionModal(context, intention: item, onRescheduled: _loadMassIntentions);
                },
                icon: const Icon(Icons.update, size: 14),
                label: const Text('Reschedule Slot', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryRow(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 12, color: ParishColors.textDark),
          children: [
            TextSpan(text: '$title ', style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: content, style: TextStyle(color: ParishColors.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ParishColors.borderGrey),
      ),
      child: Column(
        children: [
          Icon(Icons.event_busy, size: 40, color: ParishColors.textMuted),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
        ],
      ),
    );
  }

  Widget _buildDateRangeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ParishColors.borderGrey),
      ),
      child: Row(
        children: [
          const Icon(Icons.date_range, size: 18, color: ParishColors.marianBlue),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedDateRangeFilter,
                isExpanded: true,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                items: _dateRangeOptions.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedDateRangeFilter = val);
                    _onFilterChanged();
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ParishColors.borderGrey),
      ),
      child: Row(
        children: [
          const Icon(Icons.sort, size: 18, color: ParishColors.marianBlue),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _sortBy,
                isExpanded: true,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                items: _sortOptions.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _sortBy = val);
                    _onFilterChanged();
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationToolbar(int totalItems) {
    final totalPages = _totalPages;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ParishColors.borderGrey),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text('Show: ', style: TextStyle(fontSize: 12, color: ParishColors.textMuted)),
              DropdownButton<int>(
                value: _itemsPerPage,
                isDense: true,
                underline: const SizedBox.shrink(),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ParishColors.marianBlue),
                items: const [
                  DropdownMenuItem(value: 10, child: Text('10')),
                  DropdownMenuItem(value: 25, child: Text('25')),
                  DropdownMenuItem(value: 50, child: Text('50')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _itemsPerPage = val;
                      _currentPage = 1;
                    });
                  }
                },
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 22),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: _currentPage > 1 ? ParishColors.marianBlue : ParishColors.borderGrey,
                onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: ParishColors.marianBlueSurface,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Page $_currentPage of $totalPages',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: ParishColors.marianBlue,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 22),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: _currentPage < totalPages ? ParishColors.marianBlue : ParishColors.borderGrey,
                onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}