// =============================================================================
// FILE: lib/features/appointments/presentation/appointments_view.dart (PART 1 OF 2)
// =============================================================================

import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../auth/services/auth_service.dart';
import '../models/appointment_model.dart';
import '../models/mass_intention_model.dart';
import '../services/appointment_service.dart';
import '../services/mass_intention_service.dart';
import 'dialogs/appointment_detail_dialog.dart';
import 'dialogs/mass_intention_dialog.dart';
import 'dialogs/schedule_appointment_dialog.dart';
import 'widgets/appointment_card.dart';

enum AppointmentViewMode { cards, table }

class AppointmentsView extends StatefulWidget {
  const AppointmentsView({super.key});

  @override
  State<AppointmentsView> createState() => _AppointmentsViewState();
}

class _AppointmentsViewState extends State<AppointmentsView>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _mainTabController;
  late AnimationController _skeletonAnimController;
  late Animation<double> _skeletonOpacityAnimation;

  // Sacramental Appointments Data
  List<AppointmentModel> _appointments = [];
  bool _isLoadingAppointments = true;
  String? _appointmentsError;

  // Mass Intentions Data
  List<MassIntentionModel> _massIntentions = [];
  bool _isLoadingIntentions = true;
  String? _intentionsError;

  // View Mode: Cards vs Table
  AppointmentViewMode _viewMode = AppointmentViewMode.cards;

  // Unified Filtering & Sorting State (Matching Assets Module)
  String _selectedStatusFilter = 'All';
  String _selectedDateRangeFilter = 'All Dates';
  DateTimeRange? _customDateRange;
  String _selectedServiceFilter = 'All';
  String _sortBy = 'Date: Earliest First';
  bool _sortAscending = true;
  String _searchQuery = '';

  // Secretary Mass Intention View Mode (By Mass Slot vs By Requester)
  bool _groupByMassSchedule = true;

  // Pagination State
  int _currentPage = 1;
  int _itemsPerPage = 10;

  final List<String> _statusOptions = [
    'All',
    'Pending',
    'Confirmed',
    'Rescheduled',
  ];

  final List<String> _dateRangeOptions = [
    'All Dates',
    'Today',
    'This Week',
    'This Month',
    'Upcoming Only',
    'Custom Date Range',
  ];

  final List<String> _sortOptions = [
    'Date: Earliest First',
    'Date: Latest First',
    'Service / Mass Slot',
    'Requester Name',
  ];

  final List<String> _servicePresets = [
    'All',
    'Nuptial Mass (Wedding)',
    'Community Baptism',
    'Funeral Mass & Blessing',
    'Anointing of the Sick & Viaticum',
    'House / Business Blessing',
    'Thanksgiving Mass Intention',
    'Canonical Interview / Pre-Cana',
    'Confession & Spiritual Direction',
  ];

  @override
  void initState() {
    super.initState();
    // 4 Tabs: Sacraments & Services, Mass Intentions Registry, Completed Logs, Cancelled Archive
    _mainTabController = TabController(length: 4, vsync: this);
    _mainTabController.addListener(() {
      if (!_mainTabController.indexIsChanging) {
        setState(() {
          _currentPage = 1;
        });
      }
    });

    _skeletonAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _skeletonOpacityAnimation = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _skeletonAnimController, curve: Curves.easeInOut),
    );

    _loadAllData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mainTabController.dispose();
    _skeletonAnimController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadAppointments(),
      _loadMassIntentions(),
    ]);
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
  // Mass Intentions Grouping & Upcoming Slot Calculation
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
  // Data Filtering & Segregation
  // ===========================================================================

  // 1. Valid Active Sacraments (Excludes BOTH Cancelled and Completed by default)
  List<AppointmentModel> get _processedAppointments {
    var list = _appointments.where((a) {
      final status = a.appointmentStatus.toLowerCase();
      return status != 'cancelled' && status != 'completed';
    }).toList();

    if (_selectedStatusFilter != 'All') {
      list = list.where((a) => a.appointmentStatus.toLowerCase() == _selectedStatusFilter.toLowerCase()).toList();
    }

    if (_selectedServiceFilter != 'All') {
      list = list.where((a) => a.serviceType.toLowerCase().contains(_selectedServiceFilter.toLowerCase())).toList();
    }

    list = _applyDateRangeFilter(list, (a) => a.requestedDate);

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

    _applySorting(list, (a) => a.requestedDate, (a) => a.serviceType, (a) => a.requesterName);

    return list;
  }

  // 2. Valid Active Mass Intentions (Excludes Cancelled by default)
  List<MassIntentionModel> get _processedMassIntentions {
    var list = _massIntentions.where((m) => m.intentionStatus.toLowerCase() != 'cancelled').toList();

    if (_selectedStatusFilter != 'All') {
      list = list.where((m) => m.intentionStatus.toLowerCase() == _selectedStatusFilter.toLowerCase()).toList();
    }

    list = _applyDateRangeFilter(list, (m) => m.scheduledDate);

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      list = list.where((m) {
        final names = [
          ...m.thanksgivingList,
          ...m.reposeSoulsList,
          ...m.specialIntentionsList,
          m.otherIntentions ?? ''
        ].join(' ').toLowerCase();
        return m.requesterName.toLowerCase().contains(q) ||
            m.intentionId.toLowerCase().contains(q) ||
            m.contactNumber.toLowerCase().contains(q) ||
            (m.email ?? '').toLowerCase().contains(q) ||
            names.contains(q);
      }).toList();
    }

    _applySorting(list, (m) => m.scheduledDate, (m) => m.formattedTime12Hour, (m) => m.requesterName);

    return list;
  }

  // 3. Isolated Completed Sacraments (Logs after ceremonies have taken place)
  List<AppointmentModel> get _completedAppointments {
    var list = _appointments.where((a) => a.appointmentStatus.toLowerCase() == 'completed').toList();

    if (_selectedServiceFilter != 'All') {
      list = list.where((a) => a.serviceType.toLowerCase().contains(_selectedServiceFilter.toLowerCase())).toList();
    }

    list = _applyDateRangeFilter(list, (a) => a.requestedDate);

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      list = list.where((a) {
        return a.requesterName.toLowerCase().contains(q) ||
            a.serviceType.toLowerCase().contains(q) ||
            a.appointmentId.toLowerCase().contains(q) ||
            a.venue.toLowerCase().contains(q) ||
            (a.appointmentRemarks ?? '').toLowerCase().contains(q);
      }).toList();
    }

    _applySorting(list, (a) => a.requestedDate, (a) => a.serviceType, (a) => a.requesterName);
    return list;
  }

  // 4. Isolated Cancelled Records Archive (Contains Cancelled Appointments)
  List<AppointmentModel> get _cancelledAppointments {
    var list = _appointments.where((a) => a.appointmentStatus.toLowerCase() == 'cancelled').toList();

    if (_selectedServiceFilter != 'All') {
      list = list.where((a) => a.serviceType.toLowerCase().contains(_selectedServiceFilter.toLowerCase())).toList();
    }

    list = _applyDateRangeFilter(list, (a) => a.requestedDate);

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      list = list.where((a) {
        return a.requesterName.toLowerCase().contains(q) ||
            a.serviceType.toLowerCase().contains(q) ||
            a.appointmentId.toLowerCase().contains(q) ||
            a.venue.toLowerCase().contains(q) ||
            (a.appointmentRemarks ?? '').toLowerCase().contains(q);
      }).toList();
    }

    _applySorting(list, (a) => a.requestedDate, (a) => a.serviceType, (a) => a.requesterName);
    return list;
  }

  List<T> _applyDateRangeFilter<T>(List<T> list, DateTime Function(T item) getDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_selectedDateRangeFilter == 'Today') {
      return list.where((item) {
        final d = getDate(item);
        return d.year == today.year && d.month == today.month && d.day == today.day;
      }).toList();
    } else if (_selectedDateRangeFilter == 'This Week') {
      final startOfWeek = today.subtract(Duration(days: today.weekday % 7));
      final endOfWeek = startOfWeek.add(const Duration(days: 6, hours: 23, minutes: 59));
      return list.where((item) {
        final d = getDate(item);
        return !d.isBefore(startOfWeek) && !d.isAfter(endOfWeek);
      }).toList();
    } else if (_selectedDateRangeFilter == 'This Month') {
      return list.where((item) {
        final d = getDate(item);
        return d.year == today.year && d.month == today.month;
      }).toList();
    } else if (_selectedDateRangeFilter == 'Upcoming Only') {
      return list.where((item) {
        final d = getDate(item);
        return !d.isBefore(today);
      }).toList();
    } else if (_selectedDateRangeFilter == 'Custom Date Range' && _customDateRange != null) {
      final start = DateTime(_customDateRange!.start.year, _customDateRange!.start.month, _customDateRange!.start.day);
      final end = DateTime(_customDateRange!.end.year, _customDateRange!.end.month, _customDateRange!.end.day, 23, 59, 59);
      return list.where((item) {
        final d = getDate(item);
        return !d.isBefore(start) && !d.isAfter(end);
      }).toList();
    }
    return list;
  }

  void _applySorting<T>(
      List<T> list,
      DateTime Function(T item) getDate,
      String Function(T item) getService,
      String Function(T item) getRequester,
      ) {
    list.sort((a, b) {
      int comparison = 0;
      switch (_sortBy) {
        case 'Date: Earliest First':
          comparison = getDate(a).compareTo(getDate(b));
          break;
        case 'Date: Latest First':
          comparison = getDate(b).compareTo(getDate(a));
          break;
        case 'Service / Mass Slot':
          comparison = getService(a).compareTo(getService(b));
          break;
        case 'Requester Name':
        default:
          comparison = getRequester(a).toLowerCase().compareTo(getRequester(b).toLowerCase());
          break;
      }
      return _sortAscending ? comparison : -comparison;
    });
  }

  int get _totalPages {
    int total = 0;
    if (_mainTabController.index == 0) {
      total = _processedAppointments.length;
    } else if (_mainTabController.index == 1) {
      total = _processedMassIntentions.length;
    } else if (_mainTabController.index == 2) {
      total = _completedAppointments.length;
    } else {
      total = _cancelledAppointments.length;
    }
    if (total == 0) return 1;
    return (total / _itemsPerPage).ceil();
  }

  int get _activeFilterCount {
    int count = 0;
    if (_selectedStatusFilter != 'All') count++;
    if (_selectedDateRangeFilter != 'All Dates') count++;
    if (_selectedServiceFilter != 'All') count++;
    if (_sortBy != 'Date: Earliest First' || !_sortAscending) count++;
    return count;
  }

  bool get _hasActiveFilters => _activeFilterCount > 0;

  void _resetFilters() {
    setState(() {
      _selectedStatusFilter = 'All';
      _selectedDateRangeFilter = 'All Dates';
      _customDateRange = null;
      _selectedServiceFilter = 'All';
      _sortBy = 'Date: Earliest First';
      _sortAscending = true;
      _currentPage = 1;
    });
  }

  Future<void> _pickCustomDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _customDateRange ??
          DateTimeRange(start: now, end: now.add(const Duration(days: 7))),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: ParishColors.marianBlue,
              onPrimary: Colors.white,
              surface: ParishColors.cardWhite,
              onSurface: ParishColors.textDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _selectedDateRangeFilter = 'Custom Date Range';
        _currentPage = 1;
      });
    }
  }

  // ===========================================================================
  // Filter & Sort Bottom Sheet (All-in-One Engine matching Assets)
  // ===========================================================================
  void _openFilterAndSortBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ParishColors.cardWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 14,
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: ParishColors.borderGrey,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filter & Sort Appointments',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: ParishColors.textDark,
                        ),
                      ),
                      if (_hasActiveFilters)
                        TextButton(
                          onPressed: () {
                            _resetFilters();
                            setSheetState(() {});
                            Navigator.pop(ctx);
                          },
                          child: const Text(
                            'Reset All',
                            style: TextStyle(
                              color: ParishColors.mercyRed,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const Divider(height: 14),

                  // 1. Sort Sequence
                  Text(
                    'Sort Sequence',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: ParishColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _sortBy,
                          isExpanded: true,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          items: _sortOptions
                              .map((opt) => DropdownMenuItem(value: opt, child: Text(opt, style: const TextStyle(fontSize: 13))))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _sortBy = val);
                              setSheetState(() {});
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: ParishColors.marianBlueSurface,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: Icon(
                          _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                          size: 18,
                          color: ParishColors.marianBlue,
                        ),
                        onPressed: () {
                          setState(() => _sortAscending = !_sortAscending);
                          setSheetState(() {});
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 2. Date Range Filter
                  Text(
                    'Date Range Filter',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: ParishColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _selectedDateRangeFilter,
                    isExpanded: true,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: _dateRangeOptions.map((opt) {
                      String label = opt;
                      if (opt == 'Custom Date Range' && _customDateRange != null) {
                        label =
                        'Custom: ${_customDateRange!.start.month}/${_customDateRange!.start.day} - ${_customDateRange!.end.month}/${_customDateRange!.end.day}';
                      }
                      return DropdownMenuItem(value: opt, child: Text(label, style: const TextStyle(fontSize: 13)));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        if (val == 'Custom Date Range') {
                          _pickCustomDateRange().then((_) {
                            setSheetState(() {});
                          });
                        } else {
                          setState(() {
                            _selectedDateRangeFilter = val;
                            _customDateRange = null;
                            _currentPage = 1;
                          });
                          setSheetState(() {});
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  // 3. Status Filter (Only applicable for Active Schedule tab)
                  if (_mainTabController.index == 0) ...[
                    Text(
                      'Booking Status',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: ParishColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _statusOptions.map((st) {
                          final isSelected = _selectedStatusFilter == st;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: ChoiceChip(
                              label: Text(st),
                              selected: isSelected,
                              selectedColor: ParishColors.marianBlue,
                              backgroundColor: ParishColors.backgroundLight,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : ParishColors.textDark,
                                fontWeight: FontWeight.bold,
                                fontSize: 11.5,
                              ),
                              onSelected: (_) {
                                setState(() {
                                  _selectedStatusFilter = st;
                                  _currentPage = 1;
                                });
                                setSheetState(() {});
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // 4. Sacramental Service Filter
                  if (_mainTabController.index == 0 || _mainTabController.index == 2) ...[
                    Text(
                      'Sacrament / Service Type',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: ParishColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _selectedServiceFilter,
                      isExpanded: true,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: _servicePresets
                          .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13))))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedServiceFilter = val;
                            _currentPage = 1;
                          });
                          setSheetState(() {});
                        }
                      },
                    ),
                    const SizedBox(height: 18),
                  ],

                  // Apply & Close
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ParishColors.marianBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Apply & Close', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openRescheduleMassIntention(MassIntentionModel item) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _RescheduleMassIntentionModalDialog(
        intention: item,
        onRescheduled: _loadMassIntentions,
      ),
    );
  }

  // ===========================================================================
  // Build Method (Anchored to Top on Desktop)
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final textDarkColor = ParishColors.textDark;
    final cardWhiteColor = ParishColors.cardWhite;
    final borderGreyColor = ParishColors.borderGrey;

    final isAllDataLoading = _isLoadingAppointments && _isLoadingIntentions;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 650;
        final double viewportHeight = constraints.hasBoundedHeight ? constraints.maxHeight : 0.0;

        // Container explicitly claims available height on desktop and anchors child to topCenter
        return Container(
          width: double.infinity,
          height: constraints.hasBoundedHeight ? constraints.maxHeight : null,
          alignment: Alignment.topCenter,
          child: RefreshIndicator(
            onRefresh: _loadAllData,
            color: ParishColors.marianBlue,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 14 : 20,
                vertical: isMobile ? 12 : 18,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: max(0.0, viewportHeight - (isMobile ? 24 : 36)),
                  minWidth: double.infinity,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    // 1. Header (Subtext Removed completely per prompt instruction)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Parish Scheduling & Liturgy Desk',
                            style: TextStyle(
                              fontSize: isMobile ? 18 : 22,
                              fontWeight: FontWeight.bold,
                              color: textDarkColor,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.refresh, color: ParishColors.marianBlueAdaptive, size: 20),
                          onPressed: _loadAllData,
                          tooltip: 'Reload Database Records',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 2. Primary Action Buttons
                    _buildActionButtons(isMobile),
                    const SizedBox(height: 12),

                    // 3. Compact Stats Row (Matching Assets Module)
                    _buildCompactStatsRow(),
                    const SizedBox(height: 14),

                    // 4. Main Module Switcher (With Completed Logs & Cancelled Archive tabs)
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: cardWhiteColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderGreyColor),
                      ),
                      child: TabBar(
                        controller: _mainTabController,
                        labelColor: Colors.white,
                        unselectedLabelColor: ParishColors.textMuted,
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicator: BoxDecoration(
                          color: _mainTabController.index == 3
                              ? ParishColors.mercyRed
                              : (_mainTabController.index == 2
                              ? const Color(0xFF0F766E)
                              : ParishColors.marianBlue),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        tabs: [
                          Tab(
                            child: Text(
                              isMobile
                                  ? 'Sacraments (${_processedAppointments.length})'
                                  : 'Sacraments (${_processedAppointments.length})',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 10.5 : 11.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Tab(
                            child: Text(
                              isMobile
                                  ? 'Intentions (${_processedMassIntentions.length})'
                                  : 'Mass Intentions (${_processedMassIntentions.length})',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 10.5 : 11.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Tab(
                            child: Text(
                              isMobile
                                  ? 'Completed (${_completedAppointments.length})'
                                  : 'Completed Logs (${_completedAppointments.length})',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 10.5 : 11.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Tab(
                            child: Text(
                              isMobile
                                  ? 'Cancelled (${_cancelledAppointments.length})'
                                  : 'Cancelled Archive (${_cancelledAppointments.length})',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 10.5 : 11.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 5. Search Bar (Compact 44dp height)
                    Container(
                      width: double.infinity,
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: cardWhiteColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderGreyColor),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search, size: 20, color: ParishColors.marianBlueAdaptive),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: (val) {
                                setState(() {
                                  _searchQuery = val;
                                  _currentPage = 1;
                                });
                              },
                              style: TextStyle(fontSize: 13, color: textDarkColor),
                              decoration: InputDecoration(
                                hintText: 'Search by requester, sacrament, phone, ID...',
                                hintStyle: TextStyle(fontSize: 12, color: ParishColors.textMuted),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          if (_searchQuery.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                  _currentPage = 1;
                                });
                              },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 6. Filter & Sort Toolbar with Card / Table View Toggle
                    Row(
                      children: [
                        InkWell(
                          onTap: _openFilterAndSortBottomSheet,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            height: 36,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: _hasActiveFilters ? ParishColors.marianBlueSurface : cardWhiteColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _hasActiveFilters ? ParishColors.marianBlue : borderGreyColor,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.tune,
                                  size: 15,
                                  color: _hasActiveFilters ? ParishColors.marianBlue : ParishColors.textMuted,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _hasActiveFilters
                                      ? 'Filter & Sort ($_activeFilterCount)'
                                      : 'Filter & Sort',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: _hasActiveFilters ? ParishColors.marianBlue : textDarkColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_getCurrentTabItemsCount()} items',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: ParishColors.textMuted,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          height: 32,
                          decoration: BoxDecoration(
                            color: cardWhiteColor,
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(color: borderGreyColor),
                          ),
                          child: ToggleButtons(
                            isSelected: [
                              _viewMode == AppointmentViewMode.cards,
                              _viewMode == AppointmentViewMode.table,
                            ],
                            onPressed: (idx) => setState(() {
                              _viewMode = idx == 0 ? AppointmentViewMode.cards : AppointmentViewMode.table;
                            }),
                            borderRadius: BorderRadius.circular(6),
                            selectedColor: Colors.white,
                            fillColor: ParishColors.marianBlue,
                            color: ParishColors.textMuted,
                            constraints: const BoxConstraints(minHeight: 28, minWidth: 32),
                            children: const [
                              Tooltip(message: 'Card View', child: Icon(Icons.grid_view, size: 14)),
                              Tooltip(message: 'Table View', child: Icon(Icons.table_chart, size: 14)),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // 7. Active Filter Chips Row
                    if (_hasActiveFilters) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (_selectedDateRangeFilter != 'All Dates')
                            _buildActiveFilterChip('Range: $_selectedDateRangeFilter', () {
                              setState(() {
                                _selectedDateRangeFilter = 'All Dates';
                                _customDateRange = null;
                                _currentPage = 1;
                              });
                            }),
                          if (_selectedStatusFilter != 'All' && _mainTabController.index == 0)
                            _buildActiveFilterChip('Status: $_selectedStatusFilter', () {
                              setState(() {
                                _selectedStatusFilter = 'All';
                                _currentPage = 1;
                              });
                            }),
                          if (_selectedServiceFilter != 'All')
                            _buildActiveFilterChip('Service: $_selectedServiceFilter', () {
                              setState(() {
                                _selectedServiceFilter = 'All';
                                _currentPage = 1;
                              });
                            }),
                          if (_sortBy != 'Date: Earliest First' || !_sortAscending)
                            _buildActiveFilterChip('Sorted: $_sortBy', () {
                              setState(() {
                                _sortBy = 'Date: Earliest First';
                                _sortAscending = true;
                              });
                            }),
                          ActionChip(
                            label: const Text(
                              'Clear',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: ParishColors.mercyRed,
                              ),
                            ),
                            backgroundColor: ParishColors.mercyRedSurface,
                            side: BorderSide(color: ParishColors.mercyRed.withOpacity(0.3)),
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            visualDensity: VisualDensity.compact,
                            onPressed: _resetFilters,
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),

                    // 8. Tab Content / Anti-Shift Skeleton Loader
                    if (isAllDataLoading)
                      _buildSkeletonLoading(constraints.maxWidth)
                    else if (_mainTabController.index == 0)
                      _buildSacramentalAppointmentsTab(constraints.maxWidth)
                    else if (_mainTabController.index == 1)
                        _buildMassIntentionsTab(constraints.maxWidth)
                      else if (_mainTabController.index == 2)
                          _buildCompletedLogsTab(constraints.maxWidth)
                        else
                          _buildCancelledArchiveTab(constraints.maxWidth),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  int _getCurrentTabItemsCount() {
    if (_mainTabController.index == 0) return _processedAppointments.length;
    if (_mainTabController.index == 1) return _processedMassIntentions.length;
    if (_mainTabController.index == 2) return _completedAppointments.length;
    return _cancelledAppointments.length;
  }

  // ===========================================================================
  // Top Action Buttons
  // ===========================================================================
  Widget _buildActionButtons(bool isMobile) {
    return isMobile
        ? Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: ParishColors.marianBlue,
              foregroundColor: Colors.white,
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => showScheduleAppointmentModal(context, onAppointmentSaved: _loadAppointments),
            icon: const Icon(Icons.add_task, size: 18),
            label: const Text('+ Book Sacrament / Service', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: ParishColors.goldAccent, width: 1.5),
              foregroundColor: ParishColors.goldAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => showMassIntentionModal(context, onIntentionSaved: _loadMassIntentions),
            icon: const Icon(Icons.volunteer_activism, size: 18),
            label: const Text('+ Book Mass Intention (Walk-In)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    )
        : Row(
      children: [
        Expanded(
          flex: 5,
          child: SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: ParishColors.marianBlue,
                foregroundColor: Colors.white,
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => showScheduleAppointmentModal(context, onAppointmentSaved: _loadAppointments),
              icon: const Icon(Icons.add_task, size: 18),
              label: const Text('+ Book Sacrament / Service', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 5,
          child: SizedBox(
            height: 44,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: ParishColors.goldAccent, width: 1.5),
                foregroundColor: ParishColors.goldAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => showMassIntentionModal(context, onIntentionSaved: _loadMassIntentions),
              icon: const Icon(Icons.volunteer_activism, size: 18),
              label: const Text('+ Book Mass Intention (Walk-In)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // Compact Stats Row (Matching Assets Module)
  // ===========================================================================
  Widget _buildCompactStatsRow() {
    final activeApts = _appointments.where((a) {
      final s = a.appointmentStatus.toLowerCase();
      return s != 'cancelled' && s != 'completed';
    }).length;
    final pendingCount = _appointments.where((a) => a.appointmentStatus.toLowerCase() == 'pending').length;
    final confirmedCount = _appointments.where((a) => a.appointmentStatus.toLowerCase() == 'confirmed').length;
    final completedCount = _appointments.where((a) => a.appointmentStatus.toLowerCase() == 'completed').length;
    final cancelledTotal = _appointments.where((a) => a.appointmentStatus.toLowerCase() == 'cancelled').length +
        _massIntentions.where((m) => m.intentionStatus.toLowerCase() == 'cancelled').length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ParishColors.borderGrey),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildCompactStatItem(
              'Active',
              '$activeApts',
              ParishColors.marianBlue,
            ),
          ),
          Container(width: 1, height: 20, color: ParishColors.borderGrey),
          Expanded(
            child: _buildCompactStatItem(
              'Pending',
              '$pendingCount',
              ParishColors.goldAccent,
            ),
          ),
          Container(width: 1, height: 20, color: ParishColors.borderGrey),
          Expanded(
            child: _buildCompactStatItem(
              'Confirmed',
              '$confirmedCount',
              ParishColors.oliveGreen,
            ),
          ),
          Container(width: 1, height: 20, color: ParishColors.borderGrey),
          Expanded(
            child: _buildCompactStatItem(
              'Completed',
              '$completedCount',
              const Color(0xFF0F766E),
            ),
          ),
          Container(width: 1, height: 20, color: ParishColors.borderGrey),
          Expanded(
            child: _buildCompactStatItem(
              'Cancelled',
              '$cancelledTotal',
              ParishColors.mercyRed,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStatItem(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: ParishColors.textMuted),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildActiveFilterChip(String label, VoidCallback onDeleted) {
    return Chip(
      label: Text(label, style: TextStyle(fontSize: 10, color: ParishColors.textDark)),
      backgroundColor: ParishColors.marianBlueSurface,
      deleteIcon: const Icon(Icons.close, size: 12),
      onDeleted: onDeleted,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

// --- END OF PART 1 ---

// =============================================================================
// FILE: lib/features/appointments/presentation/appointments_view.dart (PART 2 OF 2)
// =============================================================================

  // ===========================================================================
  // Anti-Layout-Shift Skeleton Loader
  // ===========================================================================
  Widget _buildSkeletonLoading(double availableWidth) {
    return AnimatedBuilder(
      animation: _skeletonOpacityAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _skeletonOpacityAnimation.value,
          child: Column(
            children: List.generate(4, (index) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                height: 100,
                decoration: BoxDecoration(
                  color: ParishColors.cardWhite,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ParishColors.borderGrey.withOpacity(0.4)),
                ),
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: ParishColors.borderGrey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            height: 14,
                            width: 140,
                            decoration: BoxDecoration(
                              color: ParishColors.borderGrey.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 16,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: ParishColors.borderGrey.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 12,
                            width: 180,
                            decoration: BoxDecoration(
                              color: ParishColors.borderGrey.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // TAB 1: SACRAMENTAL APPOINTMENTS VIEW (Cards vs Responsive Table)
  // ===========================================================================
  Widget _buildSacramentalAppointmentsTab(double availableWidth) {
    final processed = _processedAppointments;
    final totalItems = processed.length;
    final start = (_currentPage - 1) * _itemsPerPage;
    final end = min(start + _itemsPerPage, totalItems);
    final paged = (start >= totalItems) ? <AppointmentModel>[] : processed.sublist(start, end);

    if (_appointmentsError != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: ParishColors.mercyRedSurface, borderRadius: BorderRadius.circular(12)),
        child: Text('Error: $_appointmentsError', style: const TextStyle(color: ParishColors.mercyRed)),
      );
    }

    if (processed.isEmpty) {
      return _buildEmptyState('No active sacramental appointments found under this filter.');
    }

    return Column(
      children: [
        if (_viewMode == AppointmentViewMode.cards)
          ...paged.map((apt) => AppointmentCard(appointment: apt, onRefresh: _loadAppointments))
        else
          _buildAppointmentsTableView(paged, availableWidth),
        const SizedBox(height: 14),
        _buildPaginationToolbar(totalItems),
      ],
    );
  }

  Widget _buildAppointmentsTableView(List<AppointmentModel> items, double availableWidth) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ParishColors.borderGrey),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: max(availableWidth, 980)),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(ParishColors.marianBlueSurface),
              headingTextStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                color: ParishColors.marianBlue,
                fontSize: 12.5,
              ),
              dataTextStyle: TextStyle(fontSize: 12.5, color: ParishColors.textDark),
              columnSpacing: 16,
              horizontalMargin: 14,
              columns: const [
                DataColumn(label: Text('Ref ID')),
                DataColumn(label: Text('Service / Sacrament')),
                DataColumn(label: Text('Requester')),
                DataColumn(label: Text('Contact')),
                DataColumn(label: Text('Scheduled Date & Time')),
                DataColumn(label: Text('Venue')),
                DataColumn(label: Text('Presider')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('ID Clearance')),
                DataColumn(label: Text('Action')),
              ],
              rows: items.map((a) {
                final status = a.appointmentStatus.toLowerCase();
                Color statusColor = ParishColors.goldAccent;
                Color statusSurface = ParishColors.goldLight;
                if (status == 'confirmed') {
                  statusColor = ParishColors.oliveGreen;
                  statusSurface = ParishColors.oliveGreenSurface;
                } else if (status == 'rescheduled') {
                  statusColor = const Color(0xFF7C3AED);
                  statusSurface = const Color(0xFFF3E8FF);
                }

                return DataRow(cells: [
                  DataCell(Text(a.appointmentId, style: const TextStyle(fontWeight: FontWeight.bold, color: ParishColors.marianBlue))),
                  DataCell(Text(a.serviceType, style: const TextStyle(fontWeight: FontWeight.bold))),
                  DataCell(Text(a.requesterName)),
                  DataCell(Text(a.contactNumber)),
                  DataCell(Text('${a.formattedDate} • ${a.formattedTimeRange}')),
                  DataCell(Text(a.venue)),
                  DataCell(Text(a.officiantName)),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: statusSurface, borderRadius: BorderRadius.circular(4)),
                      child: Text(a.appointmentStatus.toUpperCase(), style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10)),
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: a.isIdVerified ? ParishColors.oliveGreenSurface : ParishColors.goldLight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        a.isIdVerified ? 'VERIFIED' : 'PENDING',
                        style: TextStyle(
                          color: a.isIdVerified ? ParishColors.oliveGreen : ParishColors.goldAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 9.5,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    TextButton.icon(
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      onPressed: () => showAppointmentDetailModal(context, appointment: a, onStatusUpdated: _loadAppointments),
                      icon: const Icon(Icons.visibility, size: 14),
                      label: const Text('View', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ]);
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 2: MASS INTENTIONS REGISTRY VIEW (Cards vs Responsive Table)
  // ===========================================================================
  Widget _buildMassIntentionsTab(double availableWidth) {
    final processed = _processedMassIntentions;
    final totalItems = processed.length;
    final nearest = _nearestUpcomingMassSlot;

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
        if (nearest != null) ...[
          _buildNearestMassBanner(nearest),
          const SizedBox(height: 14),
        ],

        // Organization Layout Choice Chips
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: ParishColors.cardWhite,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ParishColors.borderGrey),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Organization Mode:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('Group by Slot', style: TextStyle(fontSize: 11)),
                    selected: _groupByMassSchedule,
                    selectedColor: ParishColors.marianBlueSurface,
                    labelStyle: TextStyle(color: _groupByMassSchedule ? ParishColors.marianBlue : ParishColors.textMuted, fontWeight: FontWeight.bold),
                    onSelected: (val) => setState(() => _groupByMassSchedule = true),
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: const Text('Per Requester', style: TextStyle(fontSize: 11)),
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
        const SizedBox(height: 12),

        if (processed.isEmpty)
          _buildEmptyState('No active mass intentions registered under this filter.')
        else if (_viewMode == AppointmentViewMode.table)
          ...[
            _buildMassIntentionsTableView(processed, availableWidth),
            const SizedBox(height: 14),
            _buildPaginationToolbar(totalItems),
          ]
        else if (_groupByMassSchedule)
            ..._buildGroupedMassSlotsView()
          else
            ..._buildPerRequesterIntentionsView(totalItems),
      ],
    );
  }

  Widget _buildMassIntentionsTableView(List<MassIntentionModel> allItems, double availableWidth) {
    final start = (_currentPage - 1) * _itemsPerPage;
    final end = min(start + _itemsPerPage, allItems.length);
    final paged = (start >= allItems.length) ? <MassIntentionModel>[] : allItems.sublist(start, end);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ParishColors.borderGrey),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: max(availableWidth, 900)),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(ParishColors.marianBlueSurface),
              headingTextStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                color: ParishColors.marianBlue,
                fontSize: 12.5,
              ),
              dataTextStyle: TextStyle(fontSize: 12.5, color: ParishColors.textDark),
              columnSpacing: 16,
              horizontalMargin: 14,
              columns: const [
                DataColumn(label: Text('Intention ID')),
                DataColumn(label: Text('Scheduled Mass Slot')),
                DataColumn(label: Text('Requester')),
                DataColumn(label: Text('Contact')),
                DataColumn(label: Text('Names / Petitions')),
                DataColumn(label: Text('Stipend')),
                DataColumn(label: Text('Payment')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Action')),
              ],
              rows: paged.map((m) {
                final status = m.intentionStatus.toLowerCase();
                Color statusColor = status == 'confirmed' ? ParishColors.oliveGreen : ParishColors.goldAccent;

                return DataRow(cells: [
                  DataCell(Text(m.intentionId, style: const TextStyle(fontWeight: FontWeight.bold, color: ParishColors.marianBlue))),
                  DataCell(Text('${m.formattedDate} • ${m.formattedTime12Hour}', style: const TextStyle(fontWeight: FontWeight.bold))),
                  DataCell(Text(m.requesterName)),
                  DataCell(Text(m.contactNumber)),
                  DataCell(Text('${m.totalIntentionsCount} names')),
                  DataCell(Text('₱ ${m.stipendAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: ParishColors.oliveGreen))),
                  DataCell(Text(m.paymentMethod)),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                      child: Text(m.intentionStatus.toUpperCase(), style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10)),
                    ),
                  ),
                  DataCell(
                    TextButton.icon(
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      onPressed: () => _openRescheduleMassIntention(m),
                      icon: const Icon(Icons.update, size: 14, color: Color(0xFF7C3AED)),
                      label: const Text('Reschedule', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED))),
                    ),
                  ),
                ]);
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 3: COMPLETED LOGS TAB (Ceremonies Concluded - Kept for Audit)
  // ===========================================================================
  Widget _buildCompletedLogsTab(double availableWidth) {
    final list = _completedAppointments;
    final totalItems = list.length;
    final start = (_currentPage - 1) * _itemsPerPage;
    final end = min(start + _itemsPerPage, totalItems);
    final paged = (start >= totalItems) ? <AppointmentModel>[] : list.sublist(start, end);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Information Banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDFA),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF0F766E).withOpacity(0.4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.task_alt, color: Color(0xFF0F766E), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CONCLUDED SACRAMENTAL CEREMONIES & LOGS',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                    ),
                    Text(
                      'Completed liturgies and fulfilled pastoral services are preserved here for historical reference without crowding the active schedule.',
                      style: TextStyle(fontSize: 11, color: ParishColors.textDark),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        if (list.isEmpty)
          _buildEmptyState('No completed sacramental services found under this filter.')
        else if (_viewMode == AppointmentViewMode.table)
          ...[
            _buildCompletedTableView(paged, availableWidth),
            const SizedBox(height: 14),
            _buildPaginationToolbar(totalItems),
          ]
        else
          ...[
            ...paged.map((a) => AppointmentCard(appointment: a, onRefresh: _loadAppointments)),
            const SizedBox(height: 14),
            _buildPaginationToolbar(totalItems),
          ],
      ],
    );
  }

  Widget _buildCompletedTableView(List<AppointmentModel> items, double availableWidth) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ParishColors.borderGrey),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: max(availableWidth, 900)),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFCCFBF1)),
              headingTextStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F766E),
                fontSize: 12.5,
              ),
              dataTextStyle: TextStyle(fontSize: 12.5, color: ParishColors.textDark),
              columnSpacing: 16,
              horizontalMargin: 14,
              columns: const [
                DataColumn(label: Text('Ref ID')),
                DataColumn(label: Text('Sacrament / Service')),
                DataColumn(label: Text('Requester')),
                DataColumn(label: Text('Concluded Date & Time')),
                DataColumn(label: Text('Venue')),
                DataColumn(label: Text('Presiding Minister')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Action')),
              ],
              rows: items.map((a) {
                return DataRow(cells: [
                  DataCell(Text(a.appointmentId, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F766E)))),
                  DataCell(Text(a.serviceType, style: const TextStyle(fontWeight: FontWeight.bold))),
                  DataCell(Text(a.requesterName)),
                  DataCell(Text('${a.formattedDate} • ${a.formattedTimeRange}')),
                  DataCell(Text(a.venue)),
                  DataCell(Text(a.officiantName)),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: ParishColors.marianBlueSurface,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('COMPLETED', style: TextStyle(color: ParishColors.marianBlue, fontWeight: FontWeight.bold, fontSize: 10)),
                    ),
                  ),
                  DataCell(
                    TextButton.icon(
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      onPressed: () => showAppointmentDetailModal(context, appointment: a, onStatusUpdated: _loadAppointments),
                      icon: const Icon(Icons.visibility, size: 14),
                      label: const Text('View', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ]);
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 4: CANCELLED ARCHIVE TAB (Cleanly Isolated from Main Schedule)
  // ===========================================================================
  Widget _buildCancelledArchiveTab(double availableWidth) {
    final list = _cancelledAppointments;
    final totalItems = list.length;
    final start = (_currentPage - 1) * _itemsPerPage;
    final end = min(start + _itemsPerPage, totalItems);
    final paged = (start >= totalItems) ? <AppointmentModel>[] : list.sublist(start, end);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Isolation Info Banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ParishColors.mercyRedSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ParishColors.mercyRed.withOpacity(0.4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.archive_outlined, color: ParishColors.mercyRed, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ISOLATED CANCELLED BOOKINGS ARCHIVE',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ParishColors.mercyRed),
                    ),
                    Text(
                      'Cancelled appointments and rejected slots are archived here to protect the master liturgical schedule from clutter.',
                      style: TextStyle(fontSize: 11, color: ParishColors.textDark),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        if (list.isEmpty)
          _buildEmptyState('No cancelled bookings recorded in archive.')
        else if (_viewMode == AppointmentViewMode.table)
          ...[
            _buildCancelledTableView(paged, availableWidth),
            const SizedBox(height: 14),
            _buildPaginationToolbar(totalItems),
          ]
        else
          ...[
            ...paged.map((a) => AppointmentCard(appointment: a, onRefresh: _loadAppointments)),
            const SizedBox(height: 14),
            _buildPaginationToolbar(totalItems),
          ],
      ],
    );
  }

  Widget _buildCancelledTableView(List<AppointmentModel> items, double availableWidth) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ParishColors.borderGrey),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: max(availableWidth, 900)),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(ParishColors.mercyRedSurface),
              headingTextStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                color: ParishColors.mercyRed,
                fontSize: 12.5,
              ),
              dataTextStyle: TextStyle(fontSize: 12.5, color: ParishColors.textDark),
              columnSpacing: 16,
              horizontalMargin: 14,
              columns: const [
                DataColumn(label: Text('Ref ID')),
                DataColumn(label: Text('Sacrament')),
                DataColumn(label: Text('Requester')),
                DataColumn(label: Text('Originally Requested')),
                DataColumn(label: Text('Venue')),
                DataColumn(label: Text('Cancellation Reason')),
                DataColumn(label: Text('Action')),
              ],
              rows: items.map((a) {
                return DataRow(cells: [
                  DataCell(Text(a.appointmentId, style: const TextStyle(fontWeight: FontWeight.bold, color: ParishColors.mercyRed))),
                  DataCell(Text(a.serviceType)),
                  DataCell(Text(a.requesterName)),
                  DataCell(Text('${a.formattedDate} • ${a.formattedTimeRange}')),
                  DataCell(Text(a.venue)),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 240),
                      child: Text(
                        a.appointmentRemarks ?? 'Cancelled by secretariat or requester',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, color: ParishColors.textMuted),
                      ),
                    ),
                  ),
                  DataCell(
                    TextButton.icon(
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      onPressed: () => showAppointmentDetailModal(context, appointment: a, onStatusUpdated: _loadAppointments),
                      icon: const Icon(Icons.visibility, size: 14),
                      label: const Text('View', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ]);
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // Upcoming Mass Banner & Mass Intention Helpers
  // ===========================================================================

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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ParishColors.goldLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ParishColors.goldAccent, width: 1.4),
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
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(color: ParishColors.goldAccent, shape: BoxShape.circle),
                    child: const Icon(Icons.church, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Text('Next Scheduled Holy Mass', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ParishColors.goldAccent)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: ParishColors.goldAccent, borderRadius: BorderRadius.circular(10)),
                child: Text('${items.length} Intention Slips', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),
          const Divider(height: 16),
          Text(slotTitle, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildIntentionCounterChip('🕊️ Thanksgiving', totalThanksgiving, ParishColors.marianBlueAdaptive),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text('$label: $count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
    );
  }

  List<Widget> _buildGroupedMassSlotsView() {
    final groups = _groupedMassIntentions;

    return groups.entries.map((entry) {
      final slotKey = entry.key;
      final intentions = entry.value;

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: ParishColors.cardWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ParishColors.borderGrey),
        ),
        child: ExpansionTile(
          initiallyExpanded: true,
          shape: Border.all(color: Colors.transparent),
          title: Row(
            children: [
              Icon(Icons.event, size: 18, color: ParishColors.marianBlueAdaptive),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  slotKey,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: ParishColors.textDark),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: ParishColors.goldLight, borderRadius: BorderRadius.circular(6)),
                child: Text('${intentions.length} Slips', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: ParishColors.goldAccent)),
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
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ParishColors.backgroundLight,
        borderRadius: BorderRadius.circular(10),
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
                  Text(item.intentionId, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: ParishColors.marianBlueAdaptive)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                    child: Text(item.intentionStatus.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: statusColor)),
                  ),
                ],
              ),
              Text('₱ ${item.stipendAmount.toStringAsFixed(2)} (${item.paymentMethod})', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: ParishColors.oliveGreen)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Requester: ${item.requesterName} (${item.contactNumber})', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
          const SizedBox(height: 6),

          if (item.thanksgivingList.isNotEmpty) _buildCategoryRow('🕊️ Thanksgiving:', item.thanksgivingList.join(', ')),
          if (item.reposeSoulsList.isNotEmpty) _buildCategoryRow('✝️ Repose of Souls:', item.reposeSoulsList.join(', ')),
          if (item.specialIntentionsList.isNotEmpty) _buildCategoryRow('🙏 Special Intentions:', item.specialIntentionsList.join(', ')),
          if (item.otherIntentions != null && item.otherIntentions!.isNotEmpty) _buildCategoryRow('📝 Others:', item.otherIntentions!),

          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF7C3AED)),
                  foregroundColor: const Color(0xFF7C3AED),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
                onPressed: () => _openRescheduleMassIntention(item),
                icon: const Icon(Icons.update, size: 13),
                label: const Text('Reschedule Slot', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryRow(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3.0),
      child: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 11.5, color: ParishColors.textDark),
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
          Text(message, textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
        ],
      ),
    );
  }

  // ===========================================================================
  // Pagination Toolbar (Kept as is)
  // ===========================================================================
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
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ParishColors.marianBlueAdaptive),
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
                color: _currentPage > 1 ? ParishColors.marianBlueAdaptive : ParishColors.borderGrey,
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
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: ParishColors.marianBlueAdaptive,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 22),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: _currentPage < totalPages ? ParishColors.marianBlueAdaptive : ParishColors.borderGrey,
                onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Self-Contained Mass Intention Reschedule Modal Dialog (Preserved Completely)
// =============================================================================

class _RescheduleMassIntentionModalDialog extends StatefulWidget {
  final MassIntentionModel intention;
  final VoidCallback? onRescheduled;

  const _RescheduleMassIntentionModalDialog({
    required this.intention,
    this.onRescheduled,
  });

  @override
  State<_RescheduleMassIntentionModalDialog> createState() => _RescheduleMassIntentionModalDialogState();
}

class _RescheduleMassIntentionModalDialogState extends State<_RescheduleMassIntentionModalDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  late DateTime _newDate;
  late String _newMassTime;
  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _isParishioner =>
      AuthService.currentUser?.userRole.toLowerCase() == 'user';

  final List<String> _quickReasons = [
    'Requester / Family Request',
    'Mass Schedule Adjusted by Parish',
    'Liturgical Conflict / Fiesta',
    'Typo in Schedule Entry',
  ];

  @override
  void initState() {
    super.initState();
    final item = widget.intention;
    var target = item.scheduledDate.add(const Duration(days: 7));
    while (target.weekday != DateTime.wednesday &&
        target.weekday != DateTime.friday &&
        target.weekday != DateTime.sunday) {
      target = target.add(const Duration(days: 1));
    }
    _newDate = target;
    _updateMassTimeForDate(_newDate);
  }

  void _updateMassTimeForDate(DateTime date) {
    if (date.weekday == DateTime.sunday) {
      _newMassTime = '08:00:00';
    } else {
      _newMassTime = '17:30:00';
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstValidDate = _newDate.isBefore(today) ? _newDate : today;

    final picked = await showDatePicker(
      context: context,
      initialDate: _newDate,
      firstDate: firstValidDate,
      lastDate: today.add(const Duration(days: 365)),
      selectableDayPredicate: (DateTime day) {
        return day.weekday == DateTime.wednesday ||
            day.weekday == DateTime.friday ||
            day.weekday == DateTime.sunday;
      },
    );

    if (picked != null) {
      setState(() {
        _newDate = picked;
        _updateMassTimeForDate(picked);
      });
    }
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case DateTime.wednesday:
        return 'Wednesday';
      case DateTime.friday:
        return 'Friday';
      case DateTime.sunday:
        return 'Sunday';
      default:
        return '';
    }
  }

  Future<void> _confirmReschedule() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final dateStr =
          '${_newDate.year}-${_newDate.month.toString().padLeft(2, '0')}-${_newDate.day.toString().padLeft(2, '0')}';
      final item = widget.intention;

      await MassIntentionService.rescheduleMassIntention(
        intentionId: item.intentionId,
        newDate: dateStr,
        newMassTime: _newMassTime,
        reason: _reasonController.text.trim(),
        previousRemarks: item.remarks,
        previousDate: item.formattedDate,
        previousTime: item.formattedTime12Hour,
      );

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isParishioner
              ? 'Mass intention reschedule request submitted as PENDING.'
              : 'Mass intention schedule updated successfully.'),
          backgroundColor: ParishColors.oliveGreen,
        ),
      );

      widget.onRescheduled?.call();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.intention;
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final cardWhite = ParishColors.cardWhite;
    final borderGrey = ParishColors.borderGrey;
    final isSunday = _newDate.weekday == DateTime.sunday;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: cardWhite,
      child: Container(
        width: double.maxFinite,
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF3E8FF),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: borderGrey)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFF7C3AED),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.update, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reschedule Mass Intention',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark),
                        ),
                        Text(
                          '${item.intentionId} • ${item.requesterName}',
                          style: TextStyle(fontSize: 12, color: textMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Form Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_errorMessage != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: ParishColors.mercyRedSurface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: ParishColors.mercyRed),
                          ),
                          child: Text(_errorMessage!, style: const TextStyle(color: ParishColors.mercyRed, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],

                      // Current Schedule Box
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: ParishColors.backgroundLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderGrey),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('CURRENT MASS SCHEDULE:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textMuted)),
                            const SizedBox(height: 2),
                            Text('${item.formattedDate} • ${item.formattedTime12Hour}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
                            Text('Total Intentions: ${item.totalIntentionsCount} names', style: TextStyle(fontSize: 12, color: textMuted)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // New Date Selection
                      Text('Select New Date * (Wed, Fri, & Sun Only)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: ParishColors.backgroundLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: borderGrey),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${_newDate.year}-${_newDate.month.toString().padLeft(2, '0')}-${_newDate.day.toString().padLeft(2, '0')} (${_getDayName(_newDate.weekday)})',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textDark),
                              ),
                              Icon(Icons.calendar_month, color: ParishColors.marianBlueAdaptive, size: 20),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Mass Time
                      Text(isSunday ? 'Sunday Mass Time *' : 'Weekday Mass Time (Fixed at 5:30 PM)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
                      const SizedBox(height: 6),
                      if (isSunday)
                        DropdownButtonFormField<String>(
                          value: _newMassTime,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: '08:00:00', child: Text('8:00 AM (Sunday Morning Mass)', style: TextStyle(fontSize: 13.5), overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: '16:00:00', child: Text('4:00 PM (Sunday Afternoon Mass)', style: TextStyle(fontSize: 13.5), overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _newMassTime = val);
                          },
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: ParishColors.backgroundLight,
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderGrey)),
                          ),
                        )
                      else
                        TextFormField(
                          initialValue: '5:30 PM (Wednesday / Friday Evening Mass)',
                          enabled: false,
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: textDark),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: ParishColors.borderGrey.withOpacity(0.15),
                            isDense: true,
                            prefixIcon: Icon(Icons.access_time, size: 18, color: ParishColors.marianBlueAdaptive),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderGrey)),
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Reason
                      Text('Reason for Rescheduling *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _quickReasons.map((reason) {
                          return ActionChip(
                            label: Text(reason, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                            backgroundColor: ParishColors.marianBlueSurface,
                            onPressed: () => setState(() => _reasonController.text = reason),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),

                      TextFormField(
                        controller: _reasonController,
                        maxLines: 2,
                        maxLength: 250,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Please specify a reason' : null,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Tap a chip above or type custom reason...',
                          filled: true,
                          fillColor: ParishColors.backgroundLight,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderGrey)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: cardWhite,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                border: Border(top: BorderSide(color: borderGrey)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                    child: Text('Cancel', style: TextStyle(fontSize: 15, color: textMuted)),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 46,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                      ),
                      onPressed: _isSubmitting ? null : _confirmReschedule,
                      icon: _isSubmitting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.check, size: 18),
                      label: Text(
                        _isSubmitting ? 'Updating...' : 'Confirm Reschedule',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}