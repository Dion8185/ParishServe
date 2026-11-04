// =============================================================================
// FILE: lib/features/appointments/presentation/appointments_view.dart
// =============================================================================

import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../core/services/records_sync_service.dart';
import '../../receipts/presentation/dialogs/receipt_detail_dialog.dart';
import '../models/appointment_model.dart';
import '../models/mass_intention_model.dart';
import '../services/appointment_service.dart';
import '../services/mass_intention_pdf_service.dart';
import '../services/mass_intention_service.dart';
import 'dialogs/appointment_detail_dialog.dart';
import 'dialogs/manage_payment_references_dialog.dart';
import 'dialogs/review_mass_intention_payment_dialog.dart';
import 'pages/book_mass_intention_page.dart';
import 'pages/schedule_service_page.dart';
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
  final FocusNode _searchFocusNode = FocusNode();
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

  // Filtering & Sorting State
  String _selectedStatusFilter = 'All';
  String _selectedDateRangeFilter = 'All Dates';
  DateTimeRange? _customDateRange;
  String _selectedServiceFilter = 'All';
  String _sortBy = 'Date: Earliest First';
  bool _sortAscending = true;
  String _searchQuery = '';

  // Mass Intention View Mode
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

    RecordsSyncService.instance.checkConnectivity();
    RecordsSyncService.instance.updatePendingCount();
    _loadAllData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
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
      final key = item.formattedScheduleDisplay;
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

  List<MassIntentionModel> get _processedMassIntentions {
    var list = _massIntentions.where((m) {
      final st = m.intentionStatus.toLowerCase();
      return st != 'cancelled' && st != 'rejected';
    }).toList();

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
            (m.gcashReferenceNo ?? '').toLowerCase().contains(q) ||
            names.contains(q);
      }).toList();
    }

    _applySorting(list, (m) => m.scheduledDate, (m) => m.formattedTime12Hour, (m) => m.requesterName);
    return list;
  }

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

  List<MassIntentionModel> get _rejectedMassIntentions {
    return _massIntentions.where((m) {
      final st = m.intentionStatus.toLowerCase();
      return st == 'rejected' || st == 'cancelled';
    }).toList();
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
    int total = _getCurrentTabItemsCount();
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

  int _getCurrentTabItemsCount() {
    if (_mainTabController.index == 0) return _processedAppointments.length;
    if (_mainTabController.index == 1) return _processedMassIntentions.length;
    if (_mainTabController.index == 2) return _completedAppointments.length;
    return _cancelledAppointments.length + _rejectedMassIntentions.length;
  }

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
                        'Filter & Sort Liturgy Desk',
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

                  Text(
                    'Sort Sequence',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: ParishColors.textDark),
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

                  Text(
                    'Date Range Filter',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: ParishColors.textDark),
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

                  if (_mainTabController.index == 0) ...[
                    Text(
                      'Booking Status',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: ParishColors.textDark),
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

                  if (_mainTabController.index == 0 || _mainTabController.index == 2) ...[
                    Text(
                      'Sacrament / Service Type',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: ParishColors.textDark),
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

  void _openReviewPaymentModal(MassIntentionModel item) {
    showReviewMassIntentionPaymentModal(
      context,
      intention: item,
      onVerified: _loadMassIntentions,
    );
  }

  void _openManageReferencesModal() {
    showManagePaymentReferencesModal(
      context,
      onReferencesUpdated: _loadMassIntentions,
    );
  }

  void _printLiturgicalSlipForSlot(String slotKey, List<MassIntentionModel> intentions) {
    if (intentions.isEmpty) return;
    final first = intentions.first;

    MassIntentionPdfService.printMassIntentionSlip(
      massDayOfWeek: first.dayOfWeekName,
      massDate: first.formattedDate,
      massTime: first.formattedTime12Hour,
      intentions: intentions,
    );
  }

  void _viewOfficialReceiptForVerifiedIntention(MassIntentionModel item) {
    final serviceTitle = 'Mass Intention (${item.dayOfWeekName}, ${item.formattedDate} at ${item.formattedTime12Hour})';
    final lines = <String>[];
    if (item.thanksgivingList.isNotEmpty) lines.add('• Thanksgiving: ${item.thanksgivingList.join(", ")}');
    if (item.reposeSoulsList.isNotEmpty) lines.add('• Repose of Souls: ${item.reposeSoulsList.join(", ")}');
    if (item.specialIntentionsList.isNotEmpty) lines.add('• Special Petitions: ${item.specialIntentionsList.join(", ")}');
    if (item.otherIntentions != null && item.otherIntentions!.isNotEmpty) lines.add('• Others: ${item.otherIntentions}');

    final refNote = (item.gcashReferenceNo != null && item.gcashReferenceNo!.isNotEmpty)
        ? '\nGCash Ref: ${item.gcashReferenceNo}'
        : '';
    final details = '• $serviceTitle\n${lines.join("\n")}$refNote\nIntention ID: ${item.intentionId}';

    showReceiptDetailModal(
      context,
      receiptNo: 'REC-VERIFIED',
      payer: item.requesterName,
      purpose: serviceTitle,
      amount: '₱ ${item.stipendAmount.toStringAsFixed(2)}',
      date: item.formattedDate,
      payorContact: item.contactNumber,
      transactionDetails: details,
      paymentMode: item.paymentMethod,
      status: 'PAID',
    );
  }

  // ===========================================================================
  // Hero Header with Sync Ribbon
  // ===========================================================================

  Widget _buildHeroHeader(bool isMobile) {
    final fade = ParishColors.cardWhite;
    final totalActiveBookings = _processedAppointments.length + _processedMassIntentions.length;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'images/jp2-bg.png',
              fit: BoxFit.cover,
              alignment: const Alignment(0.35, -0.55),
              errorBuilder: (_, __, ___) => Container(color: ParishColors.marianBlueSurface),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    fade.withOpacity(0.96),
                    fade.withOpacity(isMobile ? 0.88 : 0.80),
                    fade.withOpacity(isMobile ? 0.25 : 0.0),
                  ],
                  stops: [0.0, isMobile ? 0.62 : 0.45, isMobile ? 1.0 : 0.85],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, fade.withOpacity(0.55)],
                  stops: const [0.55, 1.0],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(isMobile ? 16 : 24, isMobile ? 16 : 22, isMobile ? 12 : 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 56,
                            height: 3,
                            decoration: BoxDecoration(
                              color: ParishColors.goldAccent,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Schedules & Liturgy Desk',
                            style: TextStyle(
                              fontFamily: 'Georgia',
                              fontFamilyFallback: const ['Times New Roman', 'serif'],
                              fontSize: isMobile ? 26 : 38,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                              color: ParishColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$totalActiveBookings active booking(s) across sacraments and mass intentions',
                            style: TextStyle(
                              fontSize: isMobile ? 12.5 : 14,
                              fontStyle: FontStyle.italic,
                              color: ParishColors.textDark.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildOverflowMenu(),
                  ],
                ),
                SizedBox(height: isMobile ? 44 : 64),
                _buildSyncStatusBar(isMobile),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverflowMenu() {
    return Container(
      decoration: BoxDecoration(
        color: ParishColors.cardWhite.withOpacity(0.9),
        shape: BoxShape.circle,
        border: Border.all(color: ParishColors.borderGrey),
      ),
      child: PopupMenuButton<String>(
        icon: Icon(Icons.more_vert, color: ParishColors.textMuted, size: 22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: ParishColors.cardWhite,
        onSelected: (val) {
          if (val == 'gcash_settings') {
            _openManageReferencesModal();
          } else if (val == 'book_sacrament') {
            navigateToScheduleServicePage(context, onAppointmentSaved: _loadAppointments);
          } else if (val == 'book_intention') {
            navigateToBookMassIntentionPage(context, onIntentionSaved: _loadMassIntentions);
          } else if (val == 'refresh') {
            _loadAllData();
            RecordsSyncService.instance.checkConnectivity();
          }
        },
        itemBuilder: (ctx) => [
          const PopupMenuItem(
            value: 'refresh',
            child: Row(
              children: [
                Icon(Icons.refresh, size: 18),
                SizedBox(width: 10),
                Text('Reload Liturgy Ledger', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncStatusBar(bool isMobile) {
    return ValueListenableBuilder<RecordsSyncStatus>(
      valueListenable: RecordsSyncService.syncStatusNotifier,
      builder: (context, status, _) {
        return ValueListenableBuilder<int>(
          valueListenable: RecordsSyncService.pendingSyncCountNotifier,
          builder: (context, pendingCount, _) {
            Color pillColor;
            Color textColor;
            IconData statusIcon;
            String statusLabel;

            if (status == RecordsSyncStatus.offline) {
              pillColor = Colors.amber.shade50;
              textColor = Colors.amber.shade900;
              statusIcon = Icons.cloud_off;
              statusLabel = pendingCount > 0
                  ? 'Offline • Working Locally ($pendingCount pending)'
                  : 'Offline • Working Locally';
            } else if (status == RecordsSyncStatus.syncing) {
              pillColor = Colors.blue.shade50;
              textColor = Colors.blue.shade900;
              statusIcon = Icons.sync;
              statusLabel = 'Syncing schedule with Supabase cloud...';
            } else if (pendingCount > 0) {
              pillColor = Colors.orange.shade50;
              textColor = Colors.orange.shade900;
              statusIcon = Icons.upload_file;
              statusLabel = 'Online • $pendingCount booking(s) queued (Tap to Sync Now)';
            } else {
              pillColor = const Color(0xFFE8F5E9);
              textColor = const Color(0xFF2E7D32);
              statusIcon = Icons.check_circle;
              statusLabel = 'Online • Liturgical schedule & intentions synchronized';
            }

            final canSync = pendingCount > 0 && status != RecordsSyncStatus.syncing;

            return InkWell(
              onTap: canSync ? () => RecordsSyncService.instance.syncPendingChanges() : null,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: pillColor.withOpacity(0.94),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: textColor.withOpacity(0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(statusIcon, size: 18, color: textColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        statusLabel,
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: textColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!isMobile)
                      ValueListenableBuilder<DateTime?>(
                        valueListenable: RecordsSyncService.lastSyncedAtNotifier,
                        builder: (context, lastSync, _) {
                          final text = lastSync != null
                              ? lastSync.toLocal().toString().substring(0, 16)
                              : 'Never';
                          return Padding(
                            padding: const EdgeInsets.only(left: 10),
                            child: Text(
                              'Last sync: $text',
                              style: TextStyle(fontSize: 11.5, color: textColor.withOpacity(0.85)),
                            ),
                          );
                        },
                      ),
                    const SizedBox(width: 10),
                    Icon(Icons.refresh, size: 17, color: textColor),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // Action Cards (Streamlined 2-Card Row)
  // ===========================================================================

  Widget _buildActionCardsRow(bool isDesktop) {
    final bookSacramentCard = _buildDashboardActionCard(
      title: 'Book Sacrament / Service',
      subtitle: 'Schedule baptisms, weddings, and blessings',
      icon: Icons.add_task,
      isSolidBlue: true,
      onTap: () => navigateToScheduleServicePage(context, onAppointmentSaved: _loadAppointments),
    );

    final bookIntentionCard = _buildDashboardActionCard(
      title: 'Book Mass Intention',
      subtitle: 'Walk-in thanksgiving and repose offerings',
      icon: Icons.volunteer_activism,
      isSolidBlue: false,
      borderColor: ParishColors.goldAccent,
      iconColor: ParishColors.goldAccent,
      titleColor: ParishColors.goldAccent,
      onTap: () => navigateToBookMassIntentionPage(context, onIntentionSaved: _loadMassIntentions),
    );

    if (isDesktop) {
      return Row(
        children: [
          Expanded(child: bookSacramentCard),
          const SizedBox(width: 16),
          Expanded(child: bookIntentionCard),
        ],
      );
    }

    return Column(
      children: [
        bookSacramentCard,
        const SizedBox(height: 10),
        bookIntentionCard,
      ],
    );
  }

  Widget _buildDashboardActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    bool isSolidBlue = false,
    Color? borderColor,
    Color? iconColor,
    Color? titleColor,
    required VoidCallback onTap,
  }) {
    final bgColor = isSolidBlue ? ParishColors.marianBlue : ParishColors.cardWhite;
    final primaryTextColor = isSolidBlue ? Colors.white : (titleColor ?? ParishColors.textDark);
    final secondaryTextColor = isSolidBlue ? Colors.white70 : ParishColors.textMuted;
    final resolvedIconColor = isSolidBlue ? Colors.white : (iconColor ?? ParishColors.marianBlue);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSolidBlue ? Colors.transparent : (borderColor ?? ParishColors.borderGrey),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isSolidBlue ? 0.08 : 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isSolidBlue
                    ? Colors.white.withOpacity(0.18)
                    : (iconColor?.withOpacity(0.12) ?? ParishColors.marianBlueSurface),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: resolvedIconColor, size: 21),
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
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: primaryTextColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: secondaryTextColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Liturgical Status KPI Deck (Always Visible + Interactive Active States)
  // ===========================================================================

  Widget _buildLiturgicalOverviewDeck(bool isMobile) {
    final activeApts = _appointments.where((a) {
      final s = a.appointmentStatus.toLowerCase();
      return s != 'cancelled' && s != 'completed';
    }).length;
    final pendingCount = _appointments.where((a) => a.appointmentStatus.toLowerCase() == 'pending').length;
    final confirmedCount = _appointments.where((a) => a.appointmentStatus.toLowerCase() == 'confirmed').length;
    final completedCount = _appointments.where((a) => a.appointmentStatus.toLowerCase() == 'completed').length;
    final cancelledTotal = _appointments.where((a) => a.appointmentStatus.toLowerCase() == 'cancelled').length +
        _massIntentions.where((m) => m.intentionStatus.toLowerCase() == 'cancelled' || m.intentionStatus.toLowerCase() == 'rejected').length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final int crossAxisCount = width > 1050 ? 5 : (width > 600 ? 3 : 2);
        final double itemWidth = (width - ((crossAxisCount - 1) * 10)) / crossAxisCount;

        final items = [
          _buildKpiCard(
            label: 'Active Sacraments',
            value: '$activeApts',
            icon: Icons.event_available,
            color: ParishColors.marianBlue,
            surfaceColor: ParishColors.marianBlueSurface,
            isSelected: _mainTabController.index == 0 && _selectedStatusFilter == 'All',
            onTap: () => setState(() {
              _mainTabController.index = 0;
              _selectedStatusFilter = 'All';
              _currentPage = 1;
            }),
          ),
          _buildKpiCard(
            label: 'Pending Review',
            value: '$pendingCount',
            icon: Icons.pending_actions,
            color: ParishColors.goldAccent,
            surfaceColor: ParishColors.goldLight,
            isSelected: _mainTabController.index == 0 && _selectedStatusFilter == 'Pending',
            onTap: () => setState(() {
              if (_mainTabController.index == 0 && _selectedStatusFilter == 'Pending') {
                _selectedStatusFilter = 'All';
              } else {
                _mainTabController.index = 0;
                _selectedStatusFilter = 'Pending';
              }
              _currentPage = 1;
            }),
          ),
          _buildKpiCard(
            label: 'Confirmed',
            value: '$confirmedCount',
            icon: Icons.check_circle_outline,
            color: ParishColors.oliveGreen,
            surfaceColor: ParishColors.oliveGreenSurface,
            isSelected: _mainTabController.index == 0 && _selectedStatusFilter == 'Confirmed',
            onTap: () => setState(() {
              if (_mainTabController.index == 0 && _selectedStatusFilter == 'Confirmed') {
                _selectedStatusFilter = 'All';
              } else {
                _mainTabController.index = 0;
                _selectedStatusFilter = 'Confirmed';
              }
              _currentPage = 1;
            }),
          ),
          _buildKpiCard(
            label: 'Concluded',
            value: '$completedCount',
            icon: Icons.task_alt,
            color: const Color(0xFF0F766E),
            surfaceColor: const Color(0xFFF0FDFA),
            isSelected: _mainTabController.index == 2,
            onTap: () => setState(() {
              _mainTabController.index = 2;
              _currentPage = 1;
            }),
          ),
          _buildKpiCard(
            label: 'Cancelled Archive',
            value: '$cancelledTotal',
            icon: Icons.archive_outlined,
            color: ParishColors.mercyRed,
            surfaceColor: ParishColors.mercyRedSurface,
            isSelected: _mainTabController.index == 3,
            onTap: () => setState(() {
              _mainTabController.index = 3;
              _currentPage = 1;
            }),
          ),
        ];

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items.map((w) => SizedBox(width: itemWidth, child: w)).toList(),
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required Color surfaceColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? surfaceColor : ParishColors.cardWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : ParishColors.borderGrey,
            width: isSelected ? 1.6 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(isSelected ? 0.08 : 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : surfaceColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color, height: 1.1),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? ParishColors.textDark : ParishColors.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Search & Filter Bar
  // ===========================================================================

  Widget _buildSearchAndFilterRow(bool isMobile) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: ParishColors.cardWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ParishColors.borderGrey, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.search, size: 21, color: ParishColors.marianBlue),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: (val) => setState(() {
                      _searchQuery = val;
                      _currentPage = 1;
                    }),
                    style: TextStyle(fontSize: 14, color: ParishColors.textDark),
                    decoration: InputDecoration(
                      hintText: isMobile
                          ? 'Search requester, sacrament, or ID...'
                          : 'Search by requester name, service type, reference #, or petitions...',
                      hintStyle: TextStyle(fontSize: 13, color: ParishColors.textMuted),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 17),
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
        ),
        const SizedBox(width: 10),
        InkWell(
          onTap: _openFilterAndSortBottomSheet,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 46,
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16),
            decoration: BoxDecoration(
              color: _hasActiveFilters ? ParishColors.marianBlueSurface : ParishColors.cardWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _hasActiveFilters ? ParishColors.marianBlue : ParishColors.borderGrey,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.tune,
                  size: 18,
                  color: _hasActiveFilters ? ParishColors.marianBlue : ParishColors.textDark,
                ),
                if (!isMobile || _hasActiveFilters) ...[
                  const SizedBox(width: 8),
                  Text(
                    _hasActiveFilters ? 'Filter ($_activeFilterCount)' : 'Filter',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _hasActiveFilters ? ParishColors.marianBlue : ParishColors.textDark,
                    ),
                  ),
                ],
                const SizedBox(width: 4),
                Icon(
                  Icons.expand_more,
                  size: 18,
                  color: _hasActiveFilters ? ParishColors.marianBlue : ParishColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // Section Header with Tabs & View Toggle
  // ===========================================================================

  Widget _buildSectionHeader(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 4,
              height: 38,
              decoration: BoxDecoration(
                color: ParishColors.goldAccent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Liturgical & Sacramental Calendar',
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontFamilyFallback: const ['Times New Roman', 'serif'],
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: ParishColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Manage bookings, verify intention offerings, and print liturgical slips.',
                    style: TextStyle(fontSize: 13, color: ParishColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: ParishColors.cardWhite,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: ParishColors.borderGrey),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.event_note, size: 15, color: ParishColors.textDark),
                  const SizedBox(width: 5),
                  Text(
                    '${_getCurrentTabItemsCount()} items',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ParishColors.textDark),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Tabs + View Toggle Row
        Row(
          children: [
            Container(
              height: 38,
              decoration: BoxDecoration(
                color: ParishColors.cardWhite,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ParishColors.borderGrey),
              ),
              child: TabBar(
                controller: _mainTabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
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
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'Sacraments (${_processedAppointments.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ),
                  Tab(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'Mass Intentions (${_processedMassIntentions.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ),
                  Tab(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'Completed (${_completedAppointments.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ),
                  Tab(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'Cancelled (${_cancelledAppointments.length + _rejectedMassIntentions.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),

            Container(
              height: 36,
              decoration: BoxDecoration(
                color: ParishColors.cardWhite,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ParishColors.borderGrey),
              ),
              child: ToggleButtons(
                isSelected: [
                  _viewMode == AppointmentViewMode.cards,
                  _viewMode == AppointmentViewMode.table,
                ],
                onPressed: (idx) => setState(() {
                  _viewMode = idx == 0 ? AppointmentViewMode.cards : AppointmentViewMode.table;
                }),
                borderRadius: BorderRadius.circular(7),
                selectedColor: Colors.white,
                fillColor: ParishColors.marianBlue,
                color: ParishColors.textMuted,
                constraints: const BoxConstraints(minHeight: 32, minWidth: 36),
                children: const [
                  Tooltip(message: 'Card View', child: Icon(Icons.grid_view, size: 16)),
                  Tooltip(message: 'Table View', child: Icon(Icons.table_chart, size: 16)),
                ],
              ),
            ),
          ],
        ),

        // Active Filter Badges
        if (_hasActiveFilters) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
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
                label: const Text('Reset', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: ParishColors.mercyRed)),
                backgroundColor: ParishColors.mercyRedSurface,
                onPressed: _resetFilters,
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildActiveFilterChip(String label, VoidCallback onDeleted) {
    return Chip(
      label: Text(label, style: TextStyle(fontSize: 11, color: ParishColors.textDark)),
      backgroundColor: ParishColors.marianBlueSurface,
      deleteIcon: const Icon(Icons.close, size: 13),
      onDeleted: onDeleted,
      visualDensity: VisualDensity.compact,
    );
  }

  // ===========================================================================
  // Skeleton Loading
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
                height: 96,
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
  // Main Dashboard Shell
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final isAllDataLoading = _isLoadingAppointments && _isLoadingIntentions;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double screenWidth = constraints.maxWidth;
        final bool isDesktop = screenWidth >= 1080;
        final bool isMobile = screenWidth < 650;

        return RefreshIndicator(
          onRefresh: _loadAllData,
          color: ParishColors.marianBlue,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 28,
              vertical: isMobile ? 14 : 24,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1400),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Hero Header with Sync Ribbon
                    _buildHeroHeader(isMobile),
                    const SizedBox(height: 16),

                    // 2. Streamlined 2-Card Action Row
                    _buildActionCardsRow(isDesktop),
                    const SizedBox(height: 16),

                    // 3. Liturgical Status KPI Deck (Always Visible)
                    _buildLiturgicalOverviewDeck(isMobile),
                    const SizedBox(height: 18),

                    // 4. Search & Filter Bar
                    _buildSearchAndFilterRow(isMobile),
                    const SizedBox(height: 20),

                    // 5. Section Header + Tabs + View Toggle
                    _buildSectionHeader(isMobile),
                    const SizedBox(height: 14),

                    // 6. Tab Content
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

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // Tab 1: Sacramental Appointments
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
  // Tab 2: Mass Intentions Registry
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
          const SizedBox(height: 12),
        ],

        // Clean sub-toolbar for Mass Intentions
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: ParishColors.cardWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ParishColors.borderGrey),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF005CEE)),
                  foregroundColor: const Color(0xFF005CEE),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _openManageReferencesModal,
                icon: const Icon(Icons.qr_code_2, size: 16),
                label: const Text('GCash Stipend QR', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('Group by Slot'),
                    selected: _groupByMassSchedule,
                    selectedColor: ParishColors.marianBlueSurface,
                    labelStyle: TextStyle(
                      color: _groupByMassSchedule ? ParishColors.marianBlue : ParishColors.textMuted,
                      fontWeight: FontWeight.bold,
                      fontSize: 11.5,
                    ),
                    onSelected: (_) => setState(() => _groupByMassSchedule = true),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Per Requester'),
                    selected: !_groupByMassSchedule,
                    selectedColor: ParishColors.marianBlueSurface,
                    labelStyle: TextStyle(
                      color: !_groupByMassSchedule ? ParishColors.marianBlue : ParishColors.textMuted,
                      fontWeight: FontWeight.bold,
                      fontSize: 11.5,
                    ),
                    onSelected: (_) => setState(() => _groupByMassSchedule = false),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        if (processed.isEmpty)
          _buildEmptyState('No active mass intentions registered under this filter.')
        else if (_viewMode == AppointmentViewMode.table) ...[
          _buildMassIntentionsTableView(processed, availableWidth),
          const SizedBox(height: 14),
          _buildPaginationToolbar(totalItems),
        ] else if (_groupByMassSchedule) ...[
          ..._buildGroupedMassSlotsView(),
        ] else ...[
          ..._buildPerRequesterIntentionsView(totalItems),
        ],
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
                DataColumn(label: Text('Intention ID')),
                DataColumn(label: Text('Day, Date & Time')),
                DataColumn(label: Text('Requester')),
                DataColumn(label: Text('Names / Petitions')),
                DataColumn(label: Text('Stipend')),
                DataColumn(label: Text('Payment Method')),
                DataColumn(label: Text('Verification')),
                DataColumn(label: Text('Action')),
              ],
              rows: paged.map((m) {
                final isVerified = m.verificationStatus.toLowerCase() == 'verified';

                return DataRow(cells: [
                  DataCell(Text(m.intentionId, style: const TextStyle(fontWeight: FontWeight.bold, color: ParishColors.marianBlue))),
                  DataCell(Text(m.formattedScheduleDisplay, style: const TextStyle(fontWeight: FontWeight.bold))),
                  DataCell(Text(m.requesterName)),
                  DataCell(Text('${m.totalIntentionsCount} names')),
                  DataCell(Text('₱ ${m.stipendAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: ParishColors.oliveGreen))),
                  DataCell(Text(m.paymentMethod)),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isVerified ? ParishColors.oliveGreenSurface : ParishColors.goldLight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isVerified ? 'VERIFIED' : 'PENDING REVIEW',
                        style: TextStyle(
                          color: isVerified ? ParishColors.oliveGreen : ParishColors.goldAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 9.5,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isVerified ? ParishColors.oliveGreen : ParishColors.marianBlue,
                            foregroundColor: Colors.white,
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () {
                            if (isVerified) {
                              _viewOfficialReceiptForVerifiedIntention(m);
                            } else {
                              _openReviewPaymentModal(m);
                            }
                          },
                          icon: Icon(isVerified ? Icons.receipt_long : Icons.verified_user, size: 13),
                          label: Text(isVerified ? 'View Voucher' : 'Review & Verify', style: const TextStyle(fontSize: 11)),
                        ),
                      ],
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ParishColors.goldLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ParishColors.goldAccent.withOpacity(0.5), width: 1.2),
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
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(color: ParishColors.goldAccent, shape: BoxShape.circle),
                    child: const Icon(Icons.church, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 8),
                  const Text('Next Holy Mass Slot',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: ParishColors.goldAccent)),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ParishColors.marianBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => _printLiturgicalSlipForSlot(slotTitle, items),
                icon: const Icon(Icons.print, size: 14),
                label: const Text('Print Mass Slip', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(slotTitle, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _buildIntentionCounterChip('Thanksgiving', totalThanksgiving, ParishColors.marianBlueAdaptive),
              _buildIntentionCounterChip('Souls', totalSouls, const Color(0xFF7C3AED)),
              _buildIntentionCounterChip('Special Intentions', totalSpecial, ParishColors.oliveGreen),
              if (totalOthers > 0) _buildIntentionCounterChip('Others', totalOthers, ParishColors.goldAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIntentionCounterChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text('$label: $count', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: color)),
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
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: ParishColors.textDark),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(color: ParishColors.goldLight, borderRadius: BorderRadius.circular(6)),
                child: Text('${intentions.length} Slips',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ParishColors.goldAccent)),
              ),
              IconButton(
                icon: const Icon(Icons.print, size: 18, color: ParishColors.marianBlue),
                tooltip: 'Print Altar Mass Intention Slip',
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
                onPressed: () => _printLiturgicalSlipForSlot(slotKey, intentions),
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
    final isConfirmed = item.intentionStatus.toLowerCase() == 'confirmed';
    final isVerified = item.verificationStatus.toLowerCase() == 'verified';
    Color statusColor = isConfirmed ? ParishColors.oliveGreen : ParishColors.goldAccent;

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
              Text('₱ ${item.stipendAmount.toStringAsFixed(2)} (${item.paymentMethod})',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: ParishColors.oliveGreen)),
            ],
          ),
          const SizedBox(height: 4),
          Text(item.formattedScheduleDisplay, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ParishColors.marianBlue)),
          Text('Requester: ${item.requesterName} (${item.contactNumber})', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
          const SizedBox(height: 6),

          if (item.thanksgivingList.isNotEmpty) _buildCategoryRow('Thanksgiving:', item.thanksgivingList.join(', ')),
          if (item.reposeSoulsList.isNotEmpty) _buildCategoryRow('Repose of Souls:', item.reposeSoulsList.join(', ')),
          if (item.specialIntentionsList.isNotEmpty) _buildCategoryRow('Special Intentions:', item.specialIntentionsList.join(', ')),
          if (item.otherIntentions != null && item.otherIntentions!.isNotEmpty) _buildCategoryRow('Others:', item.otherIntentions!),

          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (item.gcashReferenceNo != null && item.gcashReferenceNo!.isNotEmpty)
                Text('Ref: ${item.gcashReferenceNo}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF005CEE)))
              else
                const SizedBox.shrink(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isVerified ? ParishColors.oliveGreen : ParishColors.marianBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () {
                  if (isVerified) {
                    _viewOfficialReceiptForVerifiedIntention(item);
                  } else {
                    _openReviewPaymentModal(item);
                  }
                },
                icon: Icon(isVerified ? Icons.receipt_long : Icons.verified_user, size: 14),
                label: Text(isVerified ? 'View Receipt Voucher' : 'Review & Verify Payment',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Tab 3: Completed Sacraments Log
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
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDFA),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF0F766E).withOpacity(0.4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.task_alt, color: Color(0xFF0F766E), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Concluded sacramental ceremonies are archived here for pastoral record.',
                  style: TextStyle(fontSize: 12, color: const Color(0xFF0F766E), fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),

        if (list.isEmpty)
          _buildEmptyState('No completed sacramental services found under this filter.')
        else
          ...[
            ...paged.map((a) => AppointmentCard(appointment: a, onRefresh: _loadAppointments)),
            const SizedBox(height: 14),
            _buildPaginationToolbar(totalItems),
          ],
      ],
    );
  }

  // ===========================================================================
  // Tab 4: Cancelled & Rejected Archive
  // ===========================================================================

  Widget _buildCancelledArchiveTab(double availableWidth) {
    final listApts = _cancelledAppointments;
    final listIntentions = _rejectedMassIntentions;
    final totalItems = listApts.length + listIntentions.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ParishColors.mercyRedSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ParishColors.mercyRed.withOpacity(0.4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.archive_outlined, color: ParishColors.mercyRed, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Cancelled bookings and rejected mass intentions are archived here for audit purposes.',
                  style: TextStyle(fontSize: 12, color: ParishColors.mercyRed, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),

        if (totalItems == 0)
          _buildEmptyState('No cancelled bookings or rejected mass intentions recorded.')
        else
          ...[
            ...listApts.map((a) => AppointmentCard(appointment: a, onRefresh: _loadAppointments)),
            ...listIntentions.map((m) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ParishColors.cardWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ParishColors.borderGrey),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Mass Intention: ${m.intentionId}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: ParishColors.mercyRed)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: ParishColors.mercyRedSurface,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('REJECTED',
                            style: TextStyle(color: ParishColors.mercyRed, fontSize: 9.5, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(m.formattedScheduleDisplay, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('Requester: ${m.requesterName} (${m.contactNumber})', style: const TextStyle(fontSize: 12)),
                  if (m.remarks != null && m.remarks!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('Reason: ${m.remarks}', style: const TextStyle(fontSize: 11.5, color: ParishColors.mercyRed)),
                  ],
                ],
              ),
            )),
          ],
      ],
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