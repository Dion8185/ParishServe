// =============================================================================
// FILE: lib/features/sacramental_records/presentation/pages/sacrament_registry_page.dart
// =============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/database/local_database_service.dart';
import '../../../../core/services/records_sync_service.dart';
import '../../models/baptism_record_model.dart';
import '../../models/confirmation_record_model.dart';
import '../../models/first_communion_record_model.dart';
import '../../models/matrimony_record_model.dart';
import '../../models/death_record_model.dart';
import '../../models/conversion_record_model.dart';
import '../../services/baptism_service.dart';
import '../../services/confirmation_service.dart';
import '../../services/first_communion_service.dart';
import '../../services/matrimony_service.dart';
import '../../services/death_service.dart';
import '../../services/conversion_service.dart';
import '../../services/sacrament_csv_service.dart';
import '../dialogs/manual_entry_dialog.dart';
import 'baptism_manual_entry_page.dart';
import 'certificate_template_management_page.dart';
import 'certificate_verification_page.dart';
import 'confirmation_manual_entry_page.dart';
import 'first_communion_manual_entry_page.dart';
import 'matrimony_manual_entry_page.dart';
import 'death_manual_entry_page.dart';
import 'conversion_manual_entry_page.dart';
import 'sacrament_csv_import_page.dart';
import 'sacrament_record_detail_page.dart';

enum RegistryViewMode { cards, table }

class SacramentRegistryPage extends StatefulWidget {
  final String sacramentName;
  final String ledgerSubtitle;
  final IconData icon;
  final Color themeColor;
  final Color surfaceColor;

  const SacramentRegistryPage({
    super.key,
    required this.sacramentName,
    required this.ledgerSubtitle,
    required this.icon,
    required this.themeColor,
    required this.surfaceColor,
  });

  @override
  State<SacramentRegistryPage> createState() => _SacramentRegistryPageState();
}

class _SacramentRegistryPageState extends State<SacramentRegistryPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounceTimer;

  late AnimationController _skeletonAnimController;
  late Animation<double> _skeletonOpacityAnimation;

  List<BaptismRecordModel> _baptismRecords = [];
  List<ConfirmationRecordModel> _confirmationRecords = [];
  List<FirstCommunionRecordModel> _firstCommunionRecords = [];
  List<MatrimonyRecordModel> _matrimonyRecords = [];
  List<DeathRecordModel> _deathRecords = [];
  List<ConversionRecordModel> _conversionRecords = [];

  bool _isLoading = false;
  bool _isExporting = false;
  String? _fetchError;
  String _searchQuery = '';
  bool _isLoadedFromSqlite = false;

  // View & Pagination State
  RegistryViewMode _viewMode = RegistryViewMode.cards;
  int _currentPage = 0;
  int _rowsPerPage = 10;

  // Sorting State ('canonical', 'book', 'page', 'line', 'date', 'name')
  // For First Communion: ('year', 'control_number', 'date', 'name')
  String _sortBy = 'canonical';
  bool _sortAscending = true;

  // Advanced Filters State
  DateTimeRange? _selectedDateRange;
  String _selectedEntryStatusFilter = 'All';

  // Exact Locator State (Book No. + Page No. + Line No. applied together).
  String _selectedBookFilter = 'All';
  String _selectedPageFilter = 'All';
  String _selectedLineFilter = 'All';
  bool _showLocator = false;

  bool get _isCommunionRegistry => widget.sacramentName == 'First Communion';

  @override
  void initState() {
    super.initState();
    _skeletonAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _skeletonOpacityAnimation = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _skeletonAnimController, curve: Curves.easeInOut),
    );
    _loadRecords();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _skeletonAnimController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // Data Loading (cloud first, SQLite fallback)
  // ===========================================================================

  Future<List<T>> _loadWithFallback<T>({
    required bool isOnline,
    required Future<List<T>> Function() cloud,
    required Future<List<T>> Function() local,
  }) async {
    List<T> records = [];
    if (isOnline) {
      try {
        records = await cloud();
      } catch (_) {}
    }
    if (records.isEmpty) {
      records = await local();
      _isLoadedFromSqlite = true;
    } else {
      _isLoadedFromSqlite = false;
    }
    return records;
  }

  Future<List<T>> _queryLocal<T>(
      String table,
      String dateColumn,
      T Function(Map<String, dynamic>) fromMap,
      ) async {
    final db = await LocalDatabaseService.instance.database;
    if (db == null) return [];
    try {
      final rows = await db.query(
        table,
        orderBy: '$dateColumn DESC, created_at DESC',
      );
      return rows.map((r) => fromMap(r)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _loadRecords() async {
    setState(() {
      _isLoading = true;
      _fetchError = null;
    });

    final isOnline = await RecordsSyncService.instance.checkConnectivity();

    try {
      if (widget.sacramentName == 'Baptism') {
        final records = await _loadWithFallback<BaptismRecordModel>(
          isOnline: isOnline,
          cloud: () => BaptismService.getBaptismRecords(),
          local: () => _queryLocal<BaptismRecordModel>(
              'baptism_records', 'date_of_baptism', BaptismRecordModel.fromMap),
        );
        if (!mounted) return;
        setState(() {
          _baptismRecords = records;
          _fetchError = null;
        });
      } else if (widget.sacramentName == 'Confirmation') {
        final records = await _loadWithFallback<ConfirmationRecordModel>(
          isOnline: isOnline,
          cloud: () => ConfirmationService.getConfirmationRecords(),
          local: () => _queryLocal<ConfirmationRecordModel>('confirmation_records',
              'date_of_confirmation', ConfirmationRecordModel.fromMap),
        );
        if (!mounted) return;
        setState(() {
          _confirmationRecords = records;
          _fetchError = null;
        });
      } else if (widget.sacramentName == 'First Communion') {
        final records = await _loadWithFallback<FirstCommunionRecordModel>(
          isOnline: isOnline,
          cloud: () => FirstCommunionService.getFirstCommunionRecords(),
          local: () => _queryLocal<FirstCommunionRecordModel>(
              'first_communion_records',
              'date_of_communion',
              FirstCommunionRecordModel.fromMap),
        );
        if (!mounted) return;
        setState(() {
          _firstCommunionRecords = records;
          _fetchError = null;
        });
      } else if (widget.sacramentName == 'Matrimony') {
        final records = await _loadWithFallback<MatrimonyRecordModel>(
          isOnline: isOnline,
          cloud: () => MatrimonyService.getMatrimonyRecords(),
          local: () => _queryLocal<MatrimonyRecordModel>(
              'matrimony_records', 'date_of_marriage', MatrimonyRecordModel.fromMap),
        );
        if (!mounted) return;
        setState(() {
          _matrimonyRecords = records;
          _fetchError = null;
        });
      } else if (widget.sacramentName == 'Death') {
        final records = await _loadWithFallback<DeathRecordModel>(
          isOnline: isOnline,
          cloud: () => DeathService.getDeathRecords(),
          local: () => _queryLocal<DeathRecordModel>(
              'death_records', 'date_of_death', DeathRecordModel.fromMap),
        );
        if (!mounted) return;
        setState(() {
          _deathRecords = records;
          _fetchError = null;
        });
      } else if (widget.sacramentName == 'Conversion') {
        final records = await _loadWithFallback<ConversionRecordModel>(
          isOnline: isOnline,
          cloud: () => ConversionService.getConversionRecords(),
          local: () => _queryLocal<ConversionRecordModel>('conversion_records',
              'date_of_reception', ConversionRecordModel.fromMap),
        );
        if (!mounted) return;
        setState(() {
          _conversionRecords = records;
          _fetchError = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _fetchError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ===========================================================================
  // Search
  // ===========================================================================

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() {
        _searchQuery = value.trim();
        _currentPage = 0;
      });
    });
  }

  void _clearSearch() {
    _debounceTimer?.cancel();
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _currentPage = 0;
    });
  }

  // ===========================================================================
  // Sorting Engine (Book, Page, Line, Canonical, Date, Name)
  // ===========================================================================

  int _compareNumericalStrings(String a, String b) {
    final ai = int.tryParse(a.trim());
    final bi = int.tryParse(b.trim());
    if (ai != null && bi != null) return ai.compareTo(bi);
    if (ai != null) return -1;
    if (bi != null) return 1;
    return a.trim().toLowerCase().compareTo(b.trim().toLowerCase());
  }

  String get _sortLabel {
    if (_isCommunionRegistry) {
      switch (_sortBy) {
        case 'year':
        case 'book':
          return 'Year';
        case 'control_number':
        case 'page':
        case 'canonical':
          return 'Control No.';
        case 'date':
          return 'Date';
        case 'name':
          return 'Name';
        default:
          return 'Year';
      }
    }

    switch (_sortBy) {
      case 'book':
        return 'Book';
      case 'page':
        return 'Page';
      case 'line':
        return 'Line';
      case 'canonical':
        return 'Book, Page, Line';
      case 'date':
        return 'Date';
      case 'name':
        return 'Name';
      default:
        return 'Book, Page, Line';
    }
  }

  void _onColumnSort(String field) {
    setState(() {
      if (_sortBy == field) {
        _sortAscending = !_sortAscending;
      } else {
        _sortBy = field;
        _sortAscending = true;
      }
      _currentPage = 0;
    });
  }

  int? _getSortColumnIndex() {
    if (_isCommunionRegistry) {
      switch (_sortBy) {
        case 'year':
        case 'book':
          return 0;
        case 'control_number':
        case 'page':
        case 'canonical':
          return 1;
        case 'name':
          return 2;
        case 'date':
          return 3;
        default:
          return null;
      }
    }

    switch (_sortBy) {
      case 'book':
        return 0;
      case 'page':
        return 1;
      case 'line':
        return 2;
      case 'canonical':
        return 0;
      case 'name':
        return 3;
      case 'date':
        if (widget.sacramentName == 'Matrimony') return 4;
        if (widget.sacramentName == 'Death') return 6;
        return 5;
      default:
        return null;
    }
  }

  int _compareBaptism(BaptismRecordModel a, BaptismRecordModel b) {
    int res = 0;
    switch (_sortBy) {
      case 'book':
        res = _compareNumericalStrings(a.bookNumber, b.bookNumber);
        if (res == 0) res = _compareNumericalStrings(a.pageNumber, b.pageNumber);
        if (res == 0) res = _compareNumericalStrings(a.lineNumber, b.lineNumber);
        break;
      case 'page':
        res = _compareNumericalStrings(a.pageNumber, b.pageNumber);
        if (res == 0) res = _compareNumericalStrings(a.bookNumber, b.bookNumber);
        if (res == 0) res = _compareNumericalStrings(a.lineNumber, b.lineNumber);
        break;
      case 'line':
        res = _compareNumericalStrings(a.lineNumber, b.lineNumber);
        if (res == 0) res = _compareNumericalStrings(a.bookNumber, b.bookNumber);
        if (res == 0) res = _compareNumericalStrings(a.pageNumber, b.pageNumber);
        break;
      case 'canonical':
        res = _compareNumericalStrings(a.bookNumber, b.bookNumber);
        if (res == 0) res = _compareNumericalStrings(a.pageNumber, b.pageNumber);
        if (res == 0) res = _compareNumericalStrings(a.lineNumber, b.lineNumber);
        break;
      case 'date':
        res = a.dateOfBaptism.compareTo(b.dateOfBaptism);
        break;
      case 'name':
        res = a.childFullName.toLowerCase().compareTo(b.childFullName.toLowerCase());
        break;
      default:
        res = _compareNumericalStrings(a.bookNumber, b.bookNumber);
    }
    return _sortAscending ? res : -res;
  }

  int _compareConfirmation(ConfirmationRecordModel a, ConfirmationRecordModel b) {
    int res = 0;
    switch (_sortBy) {
      case 'book':
        res = _compareNumericalStrings(a.bookNumber, b.bookNumber);
        if (res == 0) res = _compareNumericalStrings(a.pageNumber, b.pageNumber);
        if (res == 0) res = _compareNumericalStrings(a.lineNumber, b.lineNumber);
        break;
      case 'page':
        res = _compareNumericalStrings(a.pageNumber, b.pageNumber);
        if (res == 0) res = _compareNumericalStrings(a.bookNumber, b.bookNumber);
        if (res == 0) res = _compareNumericalStrings(a.lineNumber, b.lineNumber);
        break;
      case 'line':
        res = _compareNumericalStrings(a.lineNumber, b.lineNumber);
        if (res == 0) res = _compareNumericalStrings(a.bookNumber, b.bookNumber);
        if (res == 0) res = _compareNumericalStrings(a.pageNumber, b.pageNumber);
        break;
      case 'canonical':
        res = _compareNumericalStrings(a.bookNumber, b.bookNumber);
        if (res == 0) res = _compareNumericalStrings(a.pageNumber, b.pageNumber);
        if (res == 0) res = _compareNumericalStrings(a.lineNumber, b.lineNumber);
        break;
      case 'date':
        res = a.dateOfConfirmation.compareTo(b.dateOfConfirmation);
        break;
      case 'name':
        res = a.confirmandFullName.toLowerCase().compareTo(b.confirmandFullName.toLowerCase());
        break;
      default:
        res = _compareNumericalStrings(a.bookNumber, b.bookNumber);
    }
    return _sortAscending ? res : -res;
  }

  int _compareCommunion(FirstCommunionRecordModel a, FirstCommunionRecordModel b) {
    int res = 0;
    switch (_sortBy) {
      case 'year':
      case 'book':
        res = a.year.compareTo(b.year);
        if (res == 0) res = _compareNumericalStrings(a.controlNumber, b.controlNumber);
        break;
      case 'control_number':
      case 'page':
      case 'canonical':
        res = _compareNumericalStrings(a.controlNumber, b.controlNumber);
        if (res == 0) res = a.year.compareTo(b.year);
        break;
      case 'date':
        res = a.dateOfCommunion.compareTo(b.dateOfCommunion);
        break;
      case 'name':
        res = a.communicantFullName.toLowerCase().compareTo(b.communicantFullName.toLowerCase());
        break;
      default:
        res = a.year.compareTo(b.year);
        if (res == 0) res = _compareNumericalStrings(a.controlNumber, b.controlNumber);
    }
    return _sortAscending ? res : -res;
  }

  int _compareMatrimony(MatrimonyRecordModel a, MatrimonyRecordModel b) {
    int res = 0;
    switch (_sortBy) {
      case 'book':
        res = _compareNumericalStrings(a.bookNumber, b.bookNumber);
        if (res == 0) res = _compareNumericalStrings(a.pageNumber, b.pageNumber);
        if (res == 0) res = _compareNumericalStrings(a.lineNumber, b.lineNumber);
        break;
      case 'page':
        res = _compareNumericalStrings(a.pageNumber, b.pageNumber);
        if (res == 0) res = _compareNumericalStrings(a.bookNumber, b.bookNumber);
        if (res == 0) res = _compareNumericalStrings(a.lineNumber, b.lineNumber);
        break;
      case 'line':
        res = _compareNumericalStrings(a.lineNumber, b.lineNumber);
        if (res == 0) res = _compareNumericalStrings(a.bookNumber, b.bookNumber);
        if (res == 0) res = _compareNumericalStrings(a.pageNumber, b.pageNumber);
        break;
      case 'canonical':
        res = _compareNumericalStrings(a.bookNumber, b.bookNumber);
        if (res == 0) res = _compareNumericalStrings(a.pageNumber, b.pageNumber);
        if (res == 0) res = _compareNumericalStrings(a.lineNumber, b.lineNumber);
        break;
      case 'date':
        res = a.dateOfMarriage.compareTo(b.dateOfMarriage);
        break;
      case 'name':
        res = a.groomFullName.toLowerCase().compareTo(b.groomFullName.toLowerCase());
        break;
      default:
        res = _compareNumericalStrings(a.bookNumber, b.bookNumber);
    }
    return _sortAscending ? res : -res;
  }

  int _compareDeath(DeathRecordModel a, DeathRecordModel b) {
    int res = 0;
    switch (_sortBy) {
      case 'book':
        res = _compareNumericalStrings(a.bookNumber, b.bookNumber);
        if (res == 0) res = _compareNumericalStrings(a.pageNumber, b.pageNumber);
        if (res == 0) res = _compareNumericalStrings(a.lineNumber, b.lineNumber);
        break;
      case 'page':
        res = _compareNumericalStrings(a.pageNumber, b.pageNumber);
        if (res == 0) res = _compareNumericalStrings(a.bookNumber, b.bookNumber);
        if (res == 0) res = _compareNumericalStrings(a.lineNumber, b.lineNumber);
        break;
      case 'line':
        res = _compareNumericalStrings(a.lineNumber, b.lineNumber);
        if (res == 0) res = _compareNumericalStrings(a.bookNumber, b.bookNumber);
        if (res == 0) res = _compareNumericalStrings(a.pageNumber, b.pageNumber);
        break;
      case 'canonical':
        res = _compareNumericalStrings(a.bookNumber, b.bookNumber);
        if (res == 0) res = _compareNumericalStrings(a.pageNumber, b.pageNumber);
        if (res == 0) res = _compareNumericalStrings(a.lineNumber, b.lineNumber);
        break;
      case 'date':
        res = a.dateOfBurial.compareTo(b.dateOfBurial);
        break;
      case 'name':
        res = a.deceasedFullName.toLowerCase().compareTo(b.deceasedFullName.toLowerCase());
        break;
      default:
        res = _compareNumericalStrings(a.bookNumber, b.bookNumber);
    }
    return _sortAscending ? res : -res;
  }

  int _compareConversion(ConversionRecordModel a, ConversionRecordModel b) {
    int res = 0;
    switch (_sortBy) {
      case 'book':
        res = _compareNumericalStrings(a.bookNumber, b.bookNumber);
        if (res == 0) res = _compareNumericalStrings(a.pageNumber, b.pageNumber);
        if (res == 0) res = _compareNumericalStrings(a.lineNumber, b.lineNumber);
        break;
      case 'page':
        res = _compareNumericalStrings(a.pageNumber, b.pageNumber);
        if (res == 0) res = _compareNumericalStrings(a.bookNumber, b.bookNumber);
        if (res == 0) res = _compareNumericalStrings(a.lineNumber, b.lineNumber);
        break;
      case 'line':
        res = _compareNumericalStrings(a.lineNumber, b.lineNumber);
        if (res == 0) res = _compareNumericalStrings(a.bookNumber, b.bookNumber);
        if (res == 0) res = _compareNumericalStrings(a.pageNumber, b.pageNumber);
        break;
      case 'canonical':
        res = _compareNumericalStrings(a.bookNumber, b.bookNumber);
        if (res == 0) res = _compareNumericalStrings(a.pageNumber, b.pageNumber);
        if (res == 0) res = _compareNumericalStrings(a.lineNumber, b.lineNumber);
        break;
      case 'date':
        res = a.dateOfReception.compareTo(b.dateOfReception);
        break;
      case 'name':
        res = a.convertFullName.toLowerCase().compareTo(b.convertFullName.toLowerCase());
        break;
      default:
        res = _compareNumericalStrings(a.bookNumber, b.bookNumber);
    }
    return _sortAscending ? res : -res;
  }

  // ===========================================================================
  // Exact Locator: Book No. + Page No. + Line No.
  // ===========================================================================

  List<List<String>> get _locatorRows {
    switch (widget.sacramentName) {
      case 'Baptism':
        return _baptismRecords
            .map((r) => ['${r.bookNumber}'.trim(), '${r.pageNumber}'.trim(), '${r.lineNumber}'.trim()])
            .toList();
      case 'Confirmation':
        return _confirmationRecords
            .map((r) => ['${r.bookNumber}'.trim(), '${r.pageNumber}'.trim(), '${r.lineNumber}'.trim()])
            .toList();
      case 'Matrimony':
        return _matrimonyRecords
            .map((r) => ['${r.bookNumber}'.trim(), '${r.pageNumber}'.trim(), '${r.lineNumber}'.trim()])
            .toList();
      case 'Death':
        return _deathRecords
            .map((r) => ['${r.bookNumber}'.trim(), '${r.pageNumber}'.trim(), '${r.lineNumber}'.trim()])
            .toList();
      case 'Conversion':
        return _conversionRecords
            .map((r) => ['${r.bookNumber}'.trim(), '${r.pageNumber}'.trim(), '${r.lineNumber}'.trim()])
            .toList();
      case 'First Communion':
        return _firstCommunionRecords
            .map((r) => ['${r.year}'.trim(), '${r.controlNumber}'.trim(), ''])
            .toList();
    }
    return [];
  }

  List<String> get _locatorLabels => _isCommunionRegistry
      ? ['Archival Year', 'Control No.']
      : ['Book No.', 'Page No.', 'Line No.'];

  List<String> get _locatorSelection =>
      [_selectedBookFilter, _selectedPageFilter, _selectedLineFilter];

  bool get _hasLocatorSelection =>
      _selectedBookFilter != 'All' ||
          _selectedPageFilter != 'All' ||
          _selectedLineFilter != 'All';

  String get _locatorSummary {
    final labels = _isCommunionRegistry
        ? ['Year', 'Control']
        : ['Book', 'Page', 'Line'];
    final sel = _locatorSelection;
    final parts = <String>[];
    for (int i = 0; i < labels.length; i++) {
      if (sel[i] != 'All') parts.add('${labels[i]} ${sel[i]}');
    }
    return parts.join(' • ');
  }

  bool _valueMatches(String recordValue, String selected) {
    if (selected == 'All') return true;
    final a = recordValue.trim();
    final b = selected.trim();
    final ai = int.tryParse(a);
    final bi = int.tryParse(b);
    if (ai != null && bi != null) return ai == bi;
    return a.toLowerCase() == b.toLowerCase();
  }

  bool _matchesLocator(String book, String page, String line) {
    return _valueMatches(book, _selectedBookFilter) &&
        _valueMatches(page, _selectedPageFilter) &&
        _valueMatches(line, _selectedLineFilter);
  }

  List<String> _locatorOptions(int index) {
    final sel = _locatorSelection;
    final values = <String>{};
    for (final row in _locatorRows) {
      bool ok = true;
      for (int i = 0; i < index; i++) {
        if (!_valueMatches(row[i], sel[i])) {
          ok = false;
          break;
        }
      }
      if (ok && row[index].isNotEmpty) values.add(row[index]);
    }
    final sorted = values.toList()..sort(_compareNumericalStrings);
    return ['All', ...sorted];
  }

  List<String> get _availableBookNumbers => _locatorOptions(0);

  void _onBookChanged(String v) {
    setState(() {
      _selectedBookFilter = v;
      _selectedPageFilter = 'All';
      _selectedLineFilter = 'All';
      _currentPage = 0;
    });
  }

  void _onPageChanged(String v) {
    setState(() {
      _selectedPageFilter = v;
      _selectedLineFilter = 'All';
      _currentPage = 0;
    });
  }

  void _onLineChanged(String v) {
    setState(() {
      _selectedLineFilter = v;
      _currentPage = 0;
    });
  }

  void _clearLocator() {
    setState(() {
      _selectedBookFilter = 'All';
      _selectedPageFilter = 'All';
      _selectedLineFilter = 'All';
      _currentPage = 0;
    });
  }

  // ===========================================================================
  // Filter Computation & List Getters
  // ===========================================================================

  bool _matchesDateRange(DateTime date) {
    if (_selectedDateRange == null) return true;
    final start = DateTime(_selectedDateRange!.start.year, _selectedDateRange!.start.month, _selectedDateRange!.start.day);
    final end = DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day, 23, 59, 59);
    return (date.isAfter(start) || date.isAtSameMomentAs(start)) &&
        (date.isBefore(end) || date.isAtSameMomentAs(end));
  }

  bool _matchesStatus(String status) {
    if (_selectedEntryStatusFilter == 'All') return true;
    return status.trim().toUpperCase() == _selectedEntryStatusFilter.trim().toUpperCase();
  }

  bool get _hasActiveAdvancedFilters {
    return _selectedDateRange != null ||
        _hasLocatorSelection ||
        _selectedEntryStatusFilter != 'All';
  }

  int get _activeAdvancedFilterCount {
    int count = 0;
    if (_selectedDateRange != null) count++;
    if (_hasLocatorSelection) count++;
    if (_selectedEntryStatusFilter != 'All') count++;
    return count;
  }

  void _resetAdvancedFilters() {
    setState(() {
      _selectedDateRange = null;
      _selectedBookFilter = 'All';
      _selectedPageFilter = 'All';
      _selectedLineFilter = 'All';
      _selectedEntryStatusFilter = 'All';
      _currentPage = 0;
    });
  }

  void _resetEverything() {
    _debounceTimer?.cancel();
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _selectedDateRange = null;
      _selectedBookFilter = 'All';
      _selectedPageFilter = 'All';
      _selectedLineFilter = 'All';
      _selectedEntryStatusFilter = 'All';
      _sortBy = 'canonical';
      _sortAscending = true;
      _currentPage = 0;
    });
  }

  List<BaptismRecordModel> get _filteredBaptismRecords {
    var list = _baptismRecords.where((r) {
      if (!_matchesLocator(r.bookNumber, r.pageNumber, r.lineNumber)) return false;
      if (!_matchesDateRange(r.dateOfBaptism)) return false;
      return true;
    }).toList();

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((r) {
        final nameMatch = r.childFullName.toLowerCase().contains(q);
        final bookMatch = 'book ${r.bookNumber}'.toLowerCase().contains(q) ||
            'page ${r.pageNumber}'.toLowerCase().contains(q) ||
            'line ${r.lineNumber}'.toLowerCase().contains(q);
        final parentMatch = r.fatherFullName.toLowerCase().contains(q) ||
            r.motherFullName.toLowerCase().contains(q);
        final idMatch = r.recordId.toLowerCase().contains(q);
        return nameMatch || bookMatch || parentMatch || idMatch;
      }).toList();
    }

    list.sort(_compareBaptism);
    return list;
  }

  List<ConfirmationRecordModel> get _filteredConfirmationRecords {
    var list = _confirmationRecords.where((c) {
      if (!_matchesLocator(c.bookNumber, c.pageNumber, c.lineNumber)) return false;
      if (!_matchesDateRange(c.dateOfConfirmation)) return false;
      if (!_matchesStatus(c.entryStatus)) return false;
      return true;
    }).toList();

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((c) {
        final nameMatch = c.confirmandFullName.toLowerCase().contains(q);
        final bookMatch = 'book ${c.bookNumber}'.toLowerCase().contains(q) ||
            'page ${c.pageNumber}'.toLowerCase().contains(q) ||
            'line ${c.lineNumber}'.toLowerCase().contains(q);
        final parentMatch = c.fatherFullName.toLowerCase().contains(q) ||
            c.motherFullName.toLowerCase().contains(q);
        final churchMatch = c.churchBaptized.toLowerCase().contains(q);
        final idMatch = c.recordId.toLowerCase().contains(q);
        return nameMatch || bookMatch || parentMatch || churchMatch || idMatch;
      }).toList();
    }

    list.sort(_compareConfirmation);
    return list;
  }

  List<FirstCommunionRecordModel> get _filteredFirstCommunionRecords {
    var list = _firstCommunionRecords.where((fcm) {
      if (!_matchesDateRange(fcm.dateOfCommunion)) return false;
      if (!_matchesLocator('${fcm.year}', fcm.controlNumber, '')) return false;
      return true;
    }).toList();

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((r) {
        final nameMatch = r.communicantFullName.toLowerCase().contains(q);
        final controlMatch = r.controlNumber.toLowerCase().contains(q);
        final yearMatch = r.year.toString().contains(q);
        final parishMatch = r.baptismParish.toLowerCase().contains(q);
        final idMatch = r.recordId.toLowerCase().contains(q);
        return nameMatch || controlMatch || yearMatch || parishMatch || idMatch;
      }).toList();
    }

    list.sort(_compareCommunion);
    return list;
  }

  List<MatrimonyRecordModel> get _filteredMatrimonyRecords {
    var list = _matrimonyRecords.where((m) {
      if (!_matchesLocator(m.bookNumber, m.pageNumber, m.lineNumber)) return false;
      if (!_matchesDateRange(m.dateOfMarriage)) return false;
      if (!_matchesStatus(m.entryStatus)) return false;
      return true;
    }).toList();

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((r) {
        final nameMatch = r.groomFullName.toLowerCase().contains(q) ||
            r.brideFullName.toLowerCase().contains(q);
        final bookMatch = 'book ${r.bookNumber}'.toLowerCase().contains(q) ||
            'page ${r.pageNumber}'.toLowerCase().contains(q) ||
            'line ${r.lineNumber}'.toLowerCase().contains(q);
        final idMatch = r.recordId.toLowerCase().contains(q);
        return nameMatch || bookMatch || idMatch;
      }).toList();
    }

    list.sort(_compareMatrimony);
    return list;
  }

  List<DeathRecordModel> get _filteredDeathRecords {
    var list = _deathRecords.where((d) {
      if (!_matchesLocator(d.bookNumber, d.pageNumber, d.lineNumber)) return false;
      if (!_matchesDateRange(d.dateOfBurial)) return false;
      return true;
    }).toList();

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((d) {
        final nameMatch = d.deceasedFullName.toLowerCase().contains(q);
        final bookMatch = 'book ${d.bookNumber}'.toLowerCase().contains(q) ||
            'page ${d.pageNumber}'.toLowerCase().contains(q) ||
            'line ${d.lineNumber}'.toLowerCase().contains(q);
        final placeMatch = d.placeOfBurial.toLowerCase().contains(q);
        final idMatch = d.recordId.toLowerCase().contains(q);
        return nameMatch || bookMatch || placeMatch || idMatch;
      }).toList();
    }

    list.sort(_compareDeath);
    return list;
  }

  List<ConversionRecordModel> get _filteredConversionRecords {
    var list = _conversionRecords.where((cnv) {
      if (!_matchesLocator(cnv.bookNumber, cnv.pageNumber, cnv.lineNumber)) return false;
      if (!_matchesDateRange(cnv.dateOfReception)) return false;
      return true;
    }).toList();

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((c) {
        final nameMatch = c.convertFullName.toLowerCase().contains(q);
        final bookMatch = 'book ${c.bookNumber}'.toLowerCase().contains(q) ||
            'page ${c.pageNumber}'.toLowerCase().contains(q) ||
            'line ${c.lineNumber}'.toLowerCase().contains(q);
        final parentMatch = c.fatherFullName.toLowerCase().contains(q) ||
            c.motherFullName.toLowerCase().contains(q);
        final idMatch = c.recordId.toLowerCase().contains(q);
        return nameMatch || bookMatch || parentMatch || idMatch;
      }).toList();
    }

    list.sort(_compareConversion);
    return list;
  }

  // ===========================================================================
  // CSV Export & Import Handlers
  // ===========================================================================

  Future<void> _exportCsv() async {
    setState(() => _isExporting = true);

    try {
      List<Map<String, dynamic>> rawRecords = [];

      switch (widget.sacramentName) {
        case 'Baptism':
          rawRecords = _filteredBaptismRecords.map((r) => r.toMap()).toList();
          break;
        case 'Confirmation':
          rawRecords = _filteredConfirmationRecords.map((r) => r.toMap()).toList();
          break;
        case 'First Communion':
          rawRecords = _filteredFirstCommunionRecords.map((r) => r.toMap()).toList();
          break;
        case 'Matrimony':
          rawRecords = _filteredMatrimonyRecords.map((r) => r.toMap()).toList();
          break;
        case 'Death':
          rawRecords = _filteredDeathRecords.map((r) => r.toMap()).toList();
          break;
        case 'Conversion':
          rawRecords = _filteredConversionRecords.map((r) => r.toMap()).toList();
          break;
      }

      if (rawRecords.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No ${widget.sacramentName} records found to export.'),
            backgroundColor: widget.themeColor,
          ),
        );
        setState(() => _isExporting = false);
        return;
      }

      await SacramentCsvService.exportAndDownloadCsv(
        sacramentName: widget.sacramentName,
        records: rawRecords,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported ${rawRecords.length} ${widget.sacramentName.toLowerCase()} records to ${SacramentCsvService.getExpectedFileName(widget.sacramentName)}.'),
          backgroundColor: ParishColors.oliveGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export error: $e'),
          backgroundColor: ParishColors.mercyRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _openImportPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SacramentCsvImportPage(
          sacramentName: widget.sacramentName,
          themeColor: widget.themeColor,
          surfaceColor: widget.surfaceColor,
        ),
      ),
    ).then((result) {
      if (result == true) {
        _loadRecords();
      }
    });
  }

  // ===========================================================================
  // Navigation
  // ===========================================================================

  void _openManualEntry() {
    if (widget.sacramentName == 'Baptism') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => BaptismManualEntryPage(onRecordSaved: _loadRecords)));
    } else if (widget.sacramentName == 'Confirmation') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ConfirmationManualEntryPage(onRecordSaved: _loadRecords)));
    } else if (widget.sacramentName == 'First Communion') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => FirstCommunionManualEntryPage(onRecordSaved: _loadRecords)));
    } else if (widget.sacramentName == 'Matrimony') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => MatrimonyManualEntryPage(onRecordSaved: _loadRecords)));
    } else if (widget.sacramentName == 'Death') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => DeathManualEntryPage(onRecordSaved: _loadRecords)));
    } else if (widget.sacramentName == 'Conversion') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ConversionManualEntryPage(onRecordSaved: _loadRecords)));
    } else {
      showManualEntryModal(context);
    }
  }

  void _openCertificateTemplates() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CertificateTemplateManagementPage()),
    );
  }

  void _openCertificateVerificationPortal() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CertificateVerificationPage()),
    );
  }

  void _navigateToDetail(BuildContext context, {
    required String recordId,
    required String name,
    required String bookRef,
    required String dateString,
    required String parentage,
    required String sponsors,
    String? marginalNotation,
    required Map<String, dynamic> rawRecordData,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SacramentRecordDetailPage(
          sacramentName: widget.sacramentName,
          recordId: recordId,
          name: name,
          bookRef: bookRef,
          dateString: dateString,
          parentage: parentage,
          sponsors: sponsors,
          marginalNotation: marginalNotation,
          themeColor: widget.themeColor,
          surfaceColor: widget.surfaceColor,
          rawRecordData: rawRecordData,
          onRecordUpdated: _loadRecords,
        ),
      ),
    );
  }

  // ===========================================================================
  // Quick Sort Bottom Sheet Modal
  // ===========================================================================

  void _openSortBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: ParishColors.cardWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final isCommunion = _isCommunionRegistry;

          final sortOptions = isCommunion
              ? [
            {'field': 'year', 'label': 'Archival Year', 'icon': Icons.calendar_today},
            {'field': 'control_number', 'label': 'Control Number', 'icon': Icons.tag},
            {'field': 'date', 'label': 'Communion Date', 'icon': Icons.event},
            {'field': 'name', 'label': 'Communicant Name', 'icon': Icons.sort_by_alpha},
          ]
              : [
            {'field': 'canonical', 'label': 'Canonical (Book → Page → Line)', 'icon': Icons.menu_book},
            {'field': 'book', 'label': 'Book Number', 'icon': Icons.bookmark_outline},
            {'field': 'page', 'label': 'Page Number', 'icon': Icons.find_in_page_outlined},
            {'field': 'line', 'label': 'Line Number', 'icon': Icons.format_list_numbered},
            {'field': 'date', 'label': 'Sacrament Date', 'icon': Icons.event},
            {'field': 'name', 'label': 'Primary Name', 'icon': Icons.sort_by_alpha},
          ];

          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
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
                        Row(
                          children: [
                            Icon(Icons.sort, color: widget.themeColor, size: 22),
                            const SizedBox(width: 8),
                            Text(
                              'Sort Records',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: ParishColors.textDark,
                              ),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: () {
                            setState(() => _sortAscending = !_sortAscending);
                            setSheetState(() {});
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: widget.surfaceColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: widget.themeColor.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _sortAscending ? 'Ascending (1-9)' : 'Descending (9-1)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: widget.themeColor,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                                  size: 16,
                                  color: widget.themeColor,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Text(
                      'Choose primary sort field:',
                      style: TextStyle(fontSize: 12, color: ParishColors.textMuted),
                    ),
                    const SizedBox(height: 10),
                    ...sortOptions.map((opt) {
                      final field = opt['field'] as String;
                      final label = opt['label'] as String;
                      final icon = opt['icon'] as IconData;
                      final isSelected = _sortBy == field;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? widget.surfaceColor : ParishColors.backgroundLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? widget.themeColor : ParishColors.borderGrey,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: ListTile(
                          dense: true,
                          leading: Icon(icon, color: isSelected ? widget.themeColor : ParishColors.textMuted, size: 20),
                          title: Text(
                            label,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? widget.themeColor : ParishColors.textDark,
                            ),
                          ),
                          trailing: isSelected
                              ? Icon(
                            _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                            size: 18,
                            color: widget.themeColor,
                          )
                              : null,
                          onTap: () {
                            setState(() {
                              if (_sortBy == field) {
                                _sortAscending = !_sortAscending;
                              } else {
                                _sortBy = field;
                              }
                              _currentPage = 0;
                            });
                            Navigator.pop(ctx);
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // Advanced Filter Modal Bottom Sheet
  // ===========================================================================

  void _openAdvancedFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ParishColors.cardWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final isCommunion = _isCommunionRegistry;
          final hasStatusField = widget.sacramentName == 'Confirmation' || widget.sacramentName == 'Matrimony';
          final bookOptions = _availableBookNumbers;
          final bookValue = bookOptions.contains(_selectedBookFilter) ? _selectedBookFilter : 'All';

          return Padding(
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
                        Row(
                          children: [
                            Icon(Icons.tune, color: widget.themeColor, size: 22),
                            const SizedBox(width: 8),
                            Text(
                              'Advanced Filters & Sorting',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: ParishColors.textDark,
                              ),
                            ),
                          ],
                        ),
                        if (_hasActiveAdvancedFilters || _sortBy != 'canonical' || !_sortAscending)
                          TextButton(
                            onPressed: () {
                              _resetAdvancedFilters();
                              setState(() {
                                _sortBy = 'canonical';
                                _sortAscending = true;
                              });
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

                    // Sort Order Section
                    Text(
                      'Sort Order',
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
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            items: (isCommunion
                                ? [
                              {'value': 'year', 'label': 'Year'},
                              {'value': 'control_number', 'label': 'Control Number'},
                              {'value': 'date', 'label': 'Date'},
                              {'value': 'name', 'label': 'Name'},
                            ]
                                : [
                              {'value': 'canonical', 'label': 'Canonical (Book → Page → Line)'},
                              {'value': 'book', 'label': 'Book Number'},
                              {'value': 'page', 'label': 'Page Number'},
                              {'value': 'line', 'label': 'Line Number'},
                              {'value': 'date', 'label': 'Sacrament Date'},
                              {'value': 'name', 'label': 'Name'},
                            ])
                                .map((m) => DropdownMenuItem(
                              value: m['value']!,
                              child: Text(m['label']!, style: const TextStyle(fontSize: 13)),
                            ))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _sortBy = val;
                                  _currentPage = 0;
                                });
                                setSheetState(() {});
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: widget.surfaceColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: Icon(
                            _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                            color: widget.themeColor,
                            size: 20,
                          ),
                          tooltip: _sortAscending ? 'Ascending' : 'Descending',
                          onPressed: () {
                            setState(() => _sortAscending = !_sortAscending);
                            setSheetState(() {});
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // 1. Physical Book Number / Year Filter
                    Text(
                      isCommunion ? 'Filter by Archival Year' : 'Filter by Physical Book Number',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      key: ValueKey('sheet-book-$bookValue-${bookOptions.length}'),
                      value: bookValue,
                      isExpanded: true,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: bookOptions.map((b) {
                        return DropdownMenuItem(
                          value: b,
                          child: Text(
                            b == 'All' ? 'All Books / Volumes' : (isCommunion ? 'Year $b' : 'Book $b'),
                            style: TextStyle(fontSize: 13, color: ParishColors.textDark),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          _onBookChanged(val);
                          setSheetState(() {});
                        }
                      },
                    ),
                    if (!isCommunion) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Need an exact entry? Use "Locate Entry" on the registry screen to pick Book, Page and Line together.',
                        style: TextStyle(fontSize: 11.5, color: ParishColors.textMuted),
                      ),
                    ],
                    const SizedBox(height: 14),

                    // 2. Date Range Picker
                    Text(
                      'Sacrament Event Date Range',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(1900),
                          lastDate: DateTime.now(),
                          initialDateRange: _selectedDateRange,
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: Theme.of(context).colorScheme.copyWith(
                                  primary: widget.themeColor,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setState(() {
                            _selectedDateRange = picked;
                            _currentPage = 0;
                          });
                          setSheetState(() {});
                        }
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: ParishColors.backgroundLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: ParishColors.borderGrey),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _selectedDateRange != null
                                  ? '${_selectedDateRange!.start.toIso8601String().substring(0, 10)}  to  ${_selectedDateRange!.end.toIso8601String().substring(0, 10)}'
                                  : 'Select Date Range (From - To)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: _selectedDateRange != null ? FontWeight.bold : FontWeight.normal,
                                color: _selectedDateRange != null ? ParishColors.textDark : ParishColors.textMuted,
                              ),
                            ),
                            Icon(Icons.date_range, size: 18, color: widget.themeColor),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 3. Entry Status Filter
                    if (hasStatusField) ...[
                      Text(
                        'Canonical Entry Status',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: ['All', 'ORIGINAL', 'CORRECTED', 'INCOMPLETE'].map((st) {
                          final isSelected = _selectedEntryStatusFilter == st;
                          return ChoiceChip(
                            label: Text(st),
                            selected: isSelected,
                            selectedColor: widget.themeColor,
                            backgroundColor: ParishColors.backgroundLight,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : ParishColors.textDark,
                              fontWeight: FontWeight.bold,
                              fontSize: 11.5,
                            ),
                            onSelected: (_) {
                              setState(() {
                                _selectedEntryStatusFilter = st;
                                _currentPage = 0;
                              });
                              setSheetState(() {});
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                    ],

                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.themeColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Apply Filters', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // Search Bar
  // ===========================================================================

  Widget _buildSearchBar() {
    return Container(
      width: double.infinity,
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ParishColors.borderGrey, width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 21, color: ParishColors.marianBlue),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              style: TextStyle(fontSize: 14, color: ParishColors.textDark),
              decoration: InputDecoration(
                hintText: 'Search by name, parent, book, page or ID...',
                hintStyle: TextStyle(fontSize: 13, color: ParishColors.textMuted),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _searchController,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.clear, size: 17),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Clear search',
                onPressed: _clearSearch,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToolbarButton({
    required String label,
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: active ? widget.surfaceColor : ParishColors.cardWhite,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? widget.themeColor : ParishColors.borderGrey,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: active ? widget.themeColor : ParishColors.textMuted),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: active ? widget.themeColor : ParishColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchToolbar() {
    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildToolbarButton(
                label: _hasLocatorSelection ? 'Locate Entry (set)' : 'Locate Entry',
                icon: Icons.pin_drop_outlined,
                active: _showLocator || _hasLocatorSelection,
                onTap: () => setState(() => _showLocator = !_showLocator),
              ),
              _buildToolbarButton(
                label: _hasActiveAdvancedFilters
                    ? 'Filter ($_activeAdvancedFilterCount)'
                    : 'Filter',
                icon: Icons.tune,
                active: _hasActiveAdvancedFilters,
                onTap: _openAdvancedFilterBottomSheet,
              ),
              _buildToolbarButton(
                label: 'Sort: $_sortLabel',
                icon: _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                active: _sortBy != 'canonical' || !_sortAscending,
                onTap: _openSortBottomSheet,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          height: 32,
          decoration: BoxDecoration(
            color: ParishColors.cardWhite,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ParishColors.borderGrey),
          ),
          child: ToggleButtons(
            isSelected: [
              _viewMode == RegistryViewMode.cards,
              _viewMode == RegistryViewMode.table,
            ],
            onPressed: (index) {
              setState(() {
                _viewMode = index == 0 ? RegistryViewMode.cards : RegistryViewMode.table;
              });
            },
            borderRadius: BorderRadius.circular(7),
            selectedColor: Colors.white,
            fillColor: widget.themeColor,
            color: ParishColors.textMuted,
            constraints: const BoxConstraints(minHeight: 30, minWidth: 36),
            children: const [
              Tooltip(message: 'Card View', child: Icon(Icons.grid_view, size: 16)),
              Tooltip(message: 'Table View', child: Icon(Icons.table_chart, size: 16)),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // Locate Entry Panel
  // ===========================================================================

  Widget _buildLocatorDropdown({
    required String label,
    required List<String> options,
    required String selected,
    required ValueChanged<String> onChanged,
  }) {
    final safeValue = options.contains(selected) ? selected : 'All';
    return DropdownButtonFormField<String>(
      key: ValueKey('$label|$safeValue|${options.length}'),
      value: safeValue,
      isExpanded: true,
      menuMaxHeight: 320,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 12.5, color: ParishColors.textMuted),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: widget.themeColor, width: 1.6),
        ),
      ),
      items: options.map((o) {
        return DropdownMenuItem<String>(
          value: o,
          child: Text(
            o == 'All' ? 'Any' : o,
            style: TextStyle(
              fontSize: 13,
              fontWeight: o == 'All' ? FontWeight.normal : FontWeight.bold,
              color: ParishColors.textDark,
            ),
          ),
        );
      }).toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }

  Widget _buildLocatorPanel() {
    final labels = _locatorLabels;
    final fields = <Widget>[
      Expanded(
        child: _buildLocatorDropdown(
          label: labels[0],
          options: _locatorOptions(0),
          selected: _selectedBookFilter,
          onChanged: _onBookChanged,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _buildLocatorDropdown(
          label: labels[1],
          options: _locatorOptions(1),
          selected: _selectedPageFilter,
          onChanged: _onPageChanged,
        ),
      ),
      if (labels.length > 2) ...[
        const SizedBox(width: 8),
        Expanded(
          child: _buildLocatorDropdown(
            label: labels[2],
            options: _locatorOptions(2),
            selected: _selectedLineFilter,
            onChanged: _onLineChanged,
          ),
        ),
      ],
    ];

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.themeColor.withOpacity(0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: widget.themeColor.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: widget.surfaceColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.pin_drop_outlined, size: 18, color: widget.themeColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Locate exact entry',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                    ),
                    Text(
                      _isCommunionRegistry
                          ? 'Pick the Year and Control No. together.'
                          : 'Pick Book, Page and Line together to jump straight to one ledger entry.',
                      style: TextStyle(fontSize: 11.5, color: ParishColors.textMuted),
                    ),
                  ],
                ),
              ),
              if (_hasLocatorSelection)
                TextButton(
                  onPressed: _clearLocator,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Clear',
                    style: TextStyle(
                      color: ParishColors.mercyRed,
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: fields),
          const SizedBox(height: 8),
          Text(
            _isCommunionRegistry
                ? 'Tip: choose a Year first to narrow the Control No. list.'
                : 'Tip: choose a Book first to narrow the Page list, then pick a Line.',
            style: TextStyle(fontSize: 11, color: ParishColors.textMuted),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Skeleton Loader
  // ===========================================================================

  Widget _buildSkeletonLoading() {
    return AnimatedBuilder(
      animation: _skeletonOpacityAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _skeletonOpacityAnimation.value,
          child: Column(
            children: List.generate(4, (index) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                height: 110,
                decoration: BoxDecoration(
                  color: ParishColors.cardWhite,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ParishColors.borderGrey.withOpacity(0.4)),
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      height: 14,
                      width: 90,
                      decoration: BoxDecoration(
                        color: ParishColors.borderGrey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 16,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: ParishColors.borderGrey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 12,
                      width: 170,
                      decoration: BoxDecoration(
                        color: ParishColors.borderGrey.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
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
  // Build Main Screen
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final cardWhiteColor = ParishColors.cardWhite;
    final borderGreyColor = ParishColors.borderGrey;
    final textDarkColor = ParishColors.textDark;
    final textMutedColor = ParishColors.textMuted;

    final isBaptism = widget.sacramentName == 'Baptism';
    final isConfirmation = widget.sacramentName == 'Confirmation';
    final isCommunion = widget.sacramentName == 'First Communion';
    final isMatrimony = widget.sacramentName == 'Matrimony';
    final isDeath = widget.sacramentName == 'Death';
    final isConversion = widget.sacramentName == 'Conversion';

    int totalCount = 0;
    List paginatedBaptism = [];
    List paginatedConfirmation = [];
    List paginatedCommunion = [];
    List paginatedMatrimony = [];
    List paginatedDeath = [];
    List paginatedConversion = [];

    List activeList = [];
    if (isBaptism) {
      activeList = _filteredBaptismRecords;
    } else if (isConfirmation) {
      activeList = _filteredConfirmationRecords;
    } else if (isCommunion) {
      activeList = _filteredFirstCommunionRecords;
    } else if (isMatrimony) {
      activeList = _filteredMatrimonyRecords;
    } else if (isDeath) {
      activeList = _filteredDeathRecords;
    } else if (isConversion) {
      activeList = _filteredConversionRecords;
    }
    totalCount = activeList.length;

    final int totalPages = (totalCount / _rowsPerPage).ceil() > 0 ? (totalCount / _rowsPerPage).ceil() : 1;
    if (_currentPage >= totalPages) _currentPage = totalPages > 0 ? totalPages - 1 : 0;

    final pageSlice = _paginate(activeList);
    if (isBaptism) paginatedBaptism = pageSlice;
    if (isConfirmation) paginatedConfirmation = pageSlice;
    if (isCommunion) paginatedCommunion = pageSlice;
    if (isMatrimony) paginatedMatrimony = pageSlice;
    if (isDeath) paginatedDeath = pageSlice;
    if (isConversion) paginatedConversion = pageSlice;

    final bool isSearchOrFilterActive = _searchQuery.isNotEmpty || _hasActiveAdvancedFilters || _sortBy != 'canonical' || !_sortAscending;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth >= 900;

        return Scaffold(
          backgroundColor: ParishColors.backgroundLight,
          appBar: AppBar(
            backgroundColor: cardWhiteColor,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: widget.themeColor, size: 26),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.sacramentName} Registry',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDarkColor),
                ),
                Text(
                  widget.ledgerSubtitle,
                  style: TextStyle(fontSize: 12, color: textMutedColor),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.file_upload_outlined, color: widget.themeColor),
                tooltip: 'Import ${widget.sacramentName} CSV',
                onPressed: _openImportPage,
              ),
              IconButton(
                icon: Icon(Icons.file_download_outlined, color: widget.themeColor),
                tooltip: 'Export ${widget.sacramentName} CSV',
                onPressed: _isExporting ? null : _exportCsv,
              ),
              IconButton(
                icon: Icon(Icons.design_services_outlined, color: widget.themeColor),
                tooltip: 'Certificate Templates Studio',
                onPressed: _openCertificateTemplates,
              ),
              IconButton(
                icon: Icon(Icons.refresh, color: widget.themeColor),
                onPressed: _loadRecords,
                tooltip: 'Refresh Records',
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _loadRecords,
            color: widget.themeColor,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.all(isDesktop ? 26 : 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1400),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Ledger Status Banner
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: widget.surfaceColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: widget.themeColor.withOpacity(0.4), width: 1.5),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: widget.themeColor,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(widget.icon, color: Colors.white, size: 26),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      Text(
                                        '${widget.sacramentName} Canonical Books',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: widget.themeColor,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: _isLoadedFromSqlite
                                              ? Colors.amber.shade100
                                              : Colors.green.shade100,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: _isLoadedFromSqlite
                                                ? Colors.amber.shade800
                                                : Colors.green.shade800,
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Text(
                                          _isLoadedFromSqlite ? 'OFFLINE MODE' : 'ONLINE MODE',
                                          style: TextStyle(
                                            fontSize: 9.0,
                                            fontWeight: FontWeight.bold,
                                            color: _isLoadedFromSqlite
                                                ? Colors.amber.shade900
                                                : Colors.green.shade900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _isLoadedFromSqlite
                                        ? 'Offline Local Cache: $totalCount registered (Working without internet)'
                                        : 'Live Database Records: $totalCount registered',
                                    style: TextStyle(fontSize: 12, color: textMutedColor),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Action Buttons Toolbar
                      isDesktop
                          ? Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: SizedBox(
                              height: 52,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: widget.themeColor,
                                  foregroundColor: Colors.white,
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: _openCertificateVerificationPortal,
                                icon: const Icon(Icons.qr_code_scanner, size: 20),
                                label: const Text('Verify Certificate (QR)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 4,
                            child: SizedBox(
                              height: 52,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: widget.themeColor, width: 1.5),
                                  foregroundColor: widget.themeColor,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: _openManualEntry,
                                icon: const Icon(Icons.add, size: 20),
                                label: const Text('Manual Entry', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 3,
                            child: SizedBox(
                              height: 52,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: ParishColors.goldAccent, width: 1.5),
                                  foregroundColor: ParishColors.goldAccent,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: _openCertificateTemplates,
                                icon: const Icon(Icons.design_services_outlined, size: 18),
                                label: const Text('Templates Studio', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                        ],
                      )
                          : Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 48,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: widget.themeColor,
                                      foregroundColor: Colors.white,
                                      elevation: 1,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    onPressed: _openCertificateVerificationPortal,
                                    icon: const Icon(Icons.qr_code_scanner, size: 20),
                                    label: const Text('Verify Cert (QR)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: SizedBox(
                                  height: 48,
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(color: widget.themeColor, width: 1.5),
                                      foregroundColor: widget.themeColor,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    onPressed: _openManualEntry,
                                    icon: const Icon(Icons.add, size: 20),
                                    label: const Text('Manual Entry', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ),
                            ],
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
                              onPressed: _openCertificateTemplates,
                              icon: const Icon(Icons.design_services_outlined, size: 18),
                              label: const Text('Certificate Templates Studio', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Search bar
                      _buildSearchBar(),
                      const SizedBox(height: 10),

                      // Locate Entry + Filter + Sort + Import/Export + View toggle
                      _buildSearchToolbar(),

                      // Book • Page • Line locator panel
                      if (_showLocator) _buildLocatorPanel(),

                      // Active Filter & Sort Chips Display
                      if (_hasActiveAdvancedFilters || _sortBy != 'canonical' || !_sortAscending) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (_sortBy != 'canonical' || !_sortAscending)
                              Chip(
                                avatar: Icon(
                                  _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                                  size: 14,
                                  color: widget.themeColor,
                                ),
                                label: Text(
                                  'Sort: $_sortLabel (${_sortAscending ? "Asc" : "Desc"})',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textDarkColor),
                                ),
                                backgroundColor: widget.surfaceColor,
                                deleteIcon: const Icon(Icons.close, size: 14),
                                onDeleted: () => setState(() {
                                  _sortBy = 'canonical';
                                  _sortAscending = true;
                                  _currentPage = 0;
                                }),
                              ),
                            if (_hasLocatorSelection)
                              Chip(
                                avatar: Icon(Icons.pin_drop_outlined, size: 14, color: widget.themeColor),
                                label: Text(
                                  _locatorSummary,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textDarkColor),
                                ),
                                backgroundColor: widget.surfaceColor,
                                deleteIcon: const Icon(Icons.close, size: 14),
                                onDeleted: _clearLocator,
                              ),
                            if (_selectedDateRange != null)
                              Chip(
                                label: Text(
                                  '${_selectedDateRange!.start.toIso8601String().substring(0, 10)} - ${_selectedDateRange!.end.toIso8601String().substring(0, 10)}',
                                  style: TextStyle(fontSize: 11, color: textDarkColor),
                                ),
                                backgroundColor: widget.surfaceColor,
                                deleteIcon: const Icon(Icons.close, size: 14),
                                onDeleted: () => setState(() {
                                  _selectedDateRange = null;
                                  _currentPage = 0;
                                }),
                              ),
                            if (_selectedEntryStatusFilter != 'All')
                              Chip(
                                label: Text(
                                  'Status: $_selectedEntryStatusFilter',
                                  style: TextStyle(fontSize: 11, color: textDarkColor),
                                ),
                                backgroundColor: widget.surfaceColor,
                                deleteIcon: const Icon(Icons.close, size: 14),
                                onDeleted: () => setState(() {
                                  _selectedEntryStatusFilter = 'All';
                                  _currentPage = 0;
                                }),
                              ),
                            ActionChip(
                              label: const Text(
                                'Clear All',
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: ParishColors.mercyRed),
                              ),
                              backgroundColor: ParishColors.mercyRedSurface,
                              side: BorderSide(color: ParishColors.mercyRed.withOpacity(0.3)),
                              onPressed: _resetEverything,
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 18),

                      // Header info & count
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              isSearchOrFilterActive
                                  ? '$totalCount ${totalCount == 1 ? 'match' : 'matches'} found (Sorted by $_sortLabel)'
                                  : '${widget.sacramentName} Entries ($totalCount)',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textDarkColor),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: widget.surfaceColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Page ${_currentPage + 1} of $totalPages',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: widget.themeColor),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Main Records Display Area
                      if (_isLoading)
                        _buildSkeletonLoading()
                      else if (_fetchError != null && totalCount == 0)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: ParishColors.mercyRedSurface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: ParishColors.mercyRed),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: ParishColors.mercyRed),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Database error: $_fetchError',
                                  style: const TextStyle(fontSize: 13, color: ParishColors.mercyRed),
                                ),
                              ),
                              TextButton(
                                onPressed: _loadRecords,
                                child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        )
                      else if (totalCount == 0)
                          _buildEmptyState(
                            title: isSearchOrFilterActive
                                ? 'No records match your search or filters.'
                                : 'No registered ${widget.sacramentName.toLowerCase()} records yet.',
                            subtitle: isSearchOrFilterActive
                                ? 'Try a shorter search, or clear the filters to see every entry again.'
                                : 'Tap "Manual Entry" above to encode a canonical record.',
                            actionLabel: isSearchOrFilterActive ? 'Clear search & filters' : null,
                            onAction: isSearchOrFilterActive ? _resetEverything : null,
                          )
                        else if (_viewMode == RegistryViewMode.cards)
                            isDesktop
                                ? GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: 2,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                              childAspectRatio: 2.1,
                              children: _buildCardsList(
                                paginatedBaptism,
                                paginatedConfirmation,
                                paginatedCommunion,
                                paginatedMatrimony,
                                paginatedDeath,
                                paginatedConversion,
                                isBaptism,
                                isConfirmation,
                                isCommunion,
                                isMatrimony,
                                isDeath,
                                isConversion,
                              ),
                            )
                                : Column(
                              children: _buildCardsList(
                                paginatedBaptism,
                                paginatedConfirmation,
                                paginatedCommunion,
                                paginatedMatrimony,
                                paginatedDeath,
                                paginatedConversion,
                                isBaptism,
                                isConfirmation,
                                isCommunion,
                                isMatrimony,
                                isDeath,
                                isConversion,
                              ),
                            )
                          else
                            _buildTableView(
                              paginatedBaptism,
                              paginatedConfirmation,
                              paginatedCommunion,
                              paginatedMatrimony,
                              paginatedDeath,
                              paginatedConversion,
                              isBaptism,
                              isConfirmation,
                              isCommunion,
                              isMatrimony,
                              isDeath,
                              isConversion,
                            ),

                      const SizedBox(height: 16),

                      // Pagination Controls Footer
                      if (!_isLoading && totalCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: cardWhiteColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderGreyColor),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Showing ${_currentPage * _rowsPerPage + 1}–${((_currentPage + 1) * _rowsPerPage) > totalCount ? totalCount : ((_currentPage + 1) * _rowsPerPage)} of $totalCount',
                                      style: TextStyle(fontSize: 12, color: textMutedColor),
                                    ),
                                  ),
                                  Text('Rows:', style: TextStyle(fontSize: 12, color: textMutedColor)),
                                  const SizedBox(width: 8),
                                  DropdownButton<int>(
                                    value: _rowsPerPage,
                                    isDense: true,
                                    underline: const SizedBox.shrink(),
                                    items: [10, 25, 50].map((val) {
                                      return DropdownMenuItem<int>(
                                        value: val,
                                        child: Text(
                                          '$val',
                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: widget.themeColor),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() {
                                          _rowsPerPage = val;
                                          _currentPage = 0;
                                        });
                                      }
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.first_page, size: 20),
                                    tooltip: 'First page',
                                    onPressed: _currentPage > 0 ? () => setState(() => _currentPage = 0) : null,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.chevron_left, size: 20),
                                    tooltip: 'Previous page',
                                    onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                                  ),
                                  Text(
                                    '${_currentPage + 1} / $totalPages',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDarkColor),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.chevron_right, size: 20),
                                    tooltip: 'Next page',
                                    onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.last_page, size: 20),
                                    tooltip: 'Last page',
                                    onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage = totalPages - 1) : null,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List _paginate(List list) {
    final startIndex = _currentPage * _rowsPerPage;
    if (startIndex >= list.length) return [];
    final endIndex = (startIndex + _rowsPerPage) > list.length ? list.length : (startIndex + _rowsPerPage);
    return list.sublist(startIndex, endIndex);
  }

  List<Widget> _buildCardsList(
      List bList, List cList, List fList, List mList, List dList, List cnList,
      bool isBaptism, bool isConfirmation, bool isCommunion, bool isMatrimony, bool isDeath, bool isConversion) {
    if (isBaptism) {
      return bList.map((r) => _buildConciseSacramentCard(
        context: context,
        name: r.childFullName,
        parents: 'Parents: ${r.fatherFullName} & ${r.motherFullName}',
        dob: 'DOB: ${r.dateOfBirth.toIso8601String().substring(0, 10)}',
        sacramentDate: 'Baptism Date: ${r.dateOfBaptism.toIso8601String().substring(0, 10)}',
        bookRef: r.bookReference,
        recordId: r.recordId,
        parentage: 'Parents: ${r.fatherFullName} & ${r.motherFullName}',
        sponsors: 'Sponsors: ${r.sponsor1FullName} (S1) & ${r.sponsor2FullName} (S2)',
        marginalNotation: r.remarks,
        rawRecordData: r.toMap(),
      )).toList();
    }
    if (isConfirmation) {
      return cList.map((c) {
        final s2Text = c.sponsor2FullName != null ? ' & ${c.sponsor2FullName} (S2)' : '';
        return _buildConciseSacramentCard(
          context: context,
          name: c.confirmandFullName,
          parents: 'Parents: ${c.fatherFullName} & ${c.motherFullName}',
          dob: c.dateOfBirth != null ? 'DOB: ${c.dateOfBirth!.toIso8601String().substring(0, 10)}' : 'DOB: Not Specified',
          sacramentDate: 'Confirmation Date: ${c.dateOfConfirmation.toIso8601String().substring(0, 10)}',
          bookRef: c.bookReference,
          recordId: c.recordId,
          parentage: 'Parents: ${c.fatherFullName} & ${c.motherFullName}',
          sponsors: 'Sponsors: ${c.sponsor1FullName} (S1)$s2Text',
          marginalNotation: c.remarks,
          rawRecordData: c.toMap(),
        );
      }).toList();
    }
    if (isCommunion) {
      return fList.map((fcm) {
        final parents = (fcm.fatherFullName != '—' || fcm.motherFullName != '—')
            ? 'Parents: ${fcm.fatherFullName} & ${fcm.motherFullName}'
            : 'Parents: Not Specified in Batch Register';
        return _buildConciseSacramentCard(
          context: context,
          name: fcm.communicantFullName,
          parents: parents,
          dob: 'Baptism Parish: ${fcm.baptismParish}',
          sacramentDate: 'Communion Date: ${fcm.dateOfCommunion.toIso8601String().substring(0, 10)}',
          bookRef: fcm.referenceDisplay,
          recordId: fcm.recordId,
          parentage: parents,
          sponsors: 'Baptism Parish: ${fcm.baptismParish}',
          marginalNotation: fcm.remarks,
          rawRecordData: fcm.toMap(),
        );
      }).toList();
    }
    if (isMatrimony) {
      return mList.map((m) {
        final coupleName = '${m.groomFullName}  &  ${m.brideFullName}';
        return _buildConciseSacramentCard(
          context: context,
          name: coupleName,
          parents: 'Groom DOB: ${m.groomDateOfBirth?.toIso8601String().substring(0, 10) ?? "N/A"} | Bride DOB: ${m.brideDateOfBirth?.toIso8601String().substring(0, 10) ?? "N/A"}',
          dob: 'Marriage Type: ${m.marriageType}',
          sacramentDate: 'Marriage Date: ${m.dateOfMarriage.toIso8601String().substring(0, 10)}',
          bookRef: m.bookReference,
          recordId: m.recordId,
          parentage: 'Parents: Groom (${m.groomFatherLastName}) & Bride (${m.brideFatherLastName})',
          sponsors: 'Primary Sponsors: ${m.sponsor1FirstName} ${m.sponsor1LastName} & ${m.sponsor2FirstName} ${m.sponsor2LastName}',
          marginalNotation: m.remarks,
          rawRecordData: m.toMap(),
        );
      }).toList();
    }
    if (isDeath) {
      return dList.map((d) {
        final spouseOrParents = d.spouseFullName != '—' ? 'Spouse: ${d.spouseFullName}' : 'Parents: ${d.parentsFullName}';
        return _buildConciseSacramentCard(
          context: context,
          name: d.deceasedFullName,
          parents: spouseOrParents,
          dob: 'Civil Status: ${d.civilStatus} (Age: ${d.age})',
          sacramentDate: 'Burial Date: ${d.dateOfBurial.toIso8601String().substring(0, 10)}',
          bookRef: d.bookReference,
          recordId: d.recordId,
          parentage: spouseOrParents,
          sponsors: 'Cemetery: ${d.placeOfBurial} • Liturgical Service: ${d.liturgicalService}',
          marginalNotation: d.remarks,
          rawRecordData: d.toMap(),
        );
      }).toList();
    }
    if (isConversion) {
      return cnList.map((cnv) {
        return _buildConciseSacramentCard(
          context: context,
          name: cnv.convertFullName,
          parents: 'Parents: ${cnv.fatherFullName} & ${cnv.motherFullName}',
          dob: 'DOB: ${cnv.dateOfBirth.toIso8601String().substring(0, 10)}',
          sacramentDate: 'Reception Date: ${cnv.dateOfReception.toIso8601String().substring(0, 10)}',
          bookRef: cnv.bookReference,
          recordId: cnv.recordId,
          parentage: 'Parents: ${cnv.fatherFullName} & ${cnv.motherFullName}',
          sponsors: 'Witness 1: ${cnv.witness1FullName}',
          marginalNotation: cnv.remarks,
          rawRecordData: cnv.toMap(),
        );
      }).toList();
    }
    return [];
  }

  Widget _buildTableView(
      List bList, List cList, List fList, List mList, List dList, List cnList,
      bool isBaptism, bool isConfirmation, bool isCommunion, bool isMatrimony, bool isDeath, bool isConversion) {
    List<DataColumn> columns = [];
    List<DataRow> rows = [];

    if (isBaptism) {
      columns = [
        DataColumn(
          label: const Text('Book'),
          onSort: (col, asc) => _onColumnSort('book'),
        ),
        DataColumn(
          label: const Text('Page'),
          onSort: (col, asc) => _onColumnSort('page'),
        ),
        DataColumn(
          label: const Text('Line'),
          onSort: (col, asc) => _onColumnSort('line'),
        ),
        DataColumn(
          label: const Text('Child Full Name'),
          onSort: (col, asc) => _onColumnSort('name'),
        ),
        const DataColumn(label: Text('Date of Birth')),
        DataColumn(
          label: const Text('Date of Baptism'),
          onSort: (col, asc) => _onColumnSort('date'),
        ),
        const DataColumn(label: Text('Parents')),
        const DataColumn(label: Text('Action')),
      ];
      rows = bList.map((r) {
        return DataRow(cells: [
          DataCell(Text(r.bookNumber, style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text(r.pageNumber, style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text(r.lineNumber, style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text(r.childFullName, style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text(r.dateOfBirth.toIso8601String().substring(0, 10))),
          DataCell(Text(r.dateOfBaptism.toIso8601String().substring(0, 10))),
          DataCell(Text('${r.fatherFullName} & ${r.motherFullName}')),
          DataCell(_buildTableDetailBtn(
            context: context,
            recordId: r.recordId,
            name: r.childFullName,
            bookRef: r.bookReference,
            dateString: 'Baptized: ${r.dateOfBaptism.toIso8601String().substring(0, 10)}',
            parentage: 'Parents: ${r.fatherFullName} & ${r.motherFullName}',
            sponsors: 'Sponsors: ${r.sponsor1FullName} (S1) & ${r.sponsor2FullName} (S2)',
            marginalNotation: r.remarks,
            rawData: r.toMap(),
          )),
        ]);
      }).toList();
    } else if (isConfirmation) {
      columns = [
        DataColumn(
          label: const Text('Book'),
          onSort: (col, asc) => _onColumnSort('book'),
        ),
        DataColumn(
          label: const Text('Page'),
          onSort: (col, asc) => _onColumnSort('page'),
        ),
        DataColumn(
          label: const Text('Line'),
          onSort: (col, asc) => _onColumnSort('line'),
        ),
        DataColumn(
          label: const Text('Confirmand Full Name'),
          onSort: (col, asc) => _onColumnSort('name'),
        ),
        const DataColumn(label: Text('Date of Birth')),
        DataColumn(
          label: const Text('Date of Confirmation'),
          onSort: (col, asc) => _onColumnSort('date'),
        ),
        const DataColumn(label: Text('Parents')),
        const DataColumn(label: Text('Action')),
      ];
      rows = cList.map((c) {
        final s2Text = c.sponsor2FullName != null ? ' & ${c.sponsor2FullName} (S2)' : '';
        return DataRow(cells: [
          DataCell(Text(c.bookNumber, style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text(c.pageNumber, style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text(c.lineNumber, style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text(c.confirmandFullName, style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text(c.dateOfBirth != null ? c.dateOfBirth!.toIso8601String().substring(0, 10) : '—')),
          DataCell(Text(c.dateOfConfirmation.toIso8601String().substring(0, 10))),
          DataCell(Text('${c.fatherFullName} & ${c.motherFullName}')),
          DataCell(_buildTableDetailBtn(
            context: context,
            recordId: c.recordId,
            name: c.confirmandFullName,
            bookRef: c.bookReference,
            dateString: 'Confirmed: ${c.dateOfConfirmation.toIso8601String().substring(0, 10)}',
            parentage: 'Parents: ${c.fatherFullName} & ${c.motherFullName}',
            sponsors: 'Sponsors: ${c.sponsor1FullName} (S1)$s2Text',
            marginalNotation: c.remarks,
            rawData: c.toMap(),
          )),
        ]);
      }).toList();
    } else if (isCommunion) {
      columns = [
        DataColumn(
          label: const Text('Year'),
          onSort: (col, asc) => _onColumnSort('year'),
        ),
        DataColumn(
          label: const Text('Control #'),
          onSort: (col, asc) => _onColumnSort('control_number'),
        ),
        DataColumn(
          label: const Text('Communicant Name'),
          onSort: (col, asc) => _onColumnSort('name'),
        ),
        DataColumn(
          label: const Text('Date of Communion'),
          onSort: (col, asc) => _onColumnSort('date'),
        ),
        const DataColumn(label: Text('Baptism Parish')),
        const DataColumn(label: Text('Action')),
      ];
      rows = fList.map((fcm) {
        final parents = (fcm.fatherFullName != '—' || fcm.motherFullName != '—')
            ? 'Parents: ${fcm.fatherFullName} & ${fcm.motherFullName}'
            : 'Parents: Not Specified';
        return DataRow(cells: [
          DataCell(Text('${fcm.year}', style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text(fcm.controlNumber, style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text(fcm.communicantFullName, style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text(fcm.dateOfCommunion.toIso8601String().substring(0, 10))),
          DataCell(Text(fcm.baptismParish)),
          DataCell(_buildTableDetailBtn(
            context: context,
            recordId: fcm.recordId,
            name: fcm.communicantFullName,
            bookRef: fcm.referenceDisplay,
            dateString: 'Received Holy Communion: ${fcm.dateOfCommunion.toIso8601String().substring(0, 10)}',
            parentage: parents,
            sponsors: 'Baptism Parish: ${fcm.baptismParish}',
            marginalNotation: fcm.remarks,
            rawData: fcm.toMap(),
          )),
        ]);
      }).toList();
    } else if (isMatrimony) {
      columns = [
        DataColumn(
          label: const Text('Book'),
          onSort: (col, asc) => _onColumnSort('book'),
        ),
        DataColumn(
          label: const Text('Page'),
          onSort: (col, asc) => _onColumnSort('page'),
        ),
        DataColumn(
          label: const Text('Line'),
          onSort: (col, asc) => _onColumnSort('line'),
        ),
        DataColumn(
          label: const Text('Groom & Bride'),
          onSort: (col, asc) => _onColumnSort('name'),
        ),
        DataColumn(
          label: const Text('Date of Marriage'),
          onSort: (col, asc) => _onColumnSort('date'),
        ),
        const DataColumn(label: Text('Marriage Type')),
        const DataColumn(label: Text('Action')),
      ];
      rows = mList.map((m) {
        final couple = '${m.groomFullName} & ${m.brideFullName}';
        return DataRow(cells: [
          DataCell(Text(m.bookNumber, style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text(m.pageNumber, style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text(m.lineNumber, style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text(couple, style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text(m.dateOfMarriage.toIso8601String().substring(0, 10))),
          DataCell(Text(m.marriageType)),
          DataCell(_buildTableDetailBtn(
            context: context,
            recordId: m.recordId,
            name: couple,
            bookRef: m.bookReference,
            dateString: 'Married: ${m.dateOfMarriage.toIso8601String().substring(0, 10)} (${m.marriageType})',
            parentage: 'Primary Sponsors: ${m.sponsor1FirstName} ${m.sponsor1LastName} & ${m.sponsor2FirstName} ${m.sponsor2LastName}',
            sponsors: 'Solemnized by: Rev. Fr. ${m.solemnizerFirstName} ${m.solemnizerLastName}',
            marginalNotation: m.remarks,
            rawData: m.toMap(),
          )),
        ]);
      }).toList();
    } else if (isDeath) {
      columns = [
        DataColumn(
          label: const Text('Book'),
          onSort: (col, asc) => _onColumnSort('book'),
        ),
        DataColumn(
          label: const Text('Page'),
          onSort: (col, asc) => _onColumnSort('page'),
        ),
        DataColumn(
          label: const Text('Line'),
          onSort: (col, asc) => _onColumnSort('line'),
        ),
        DataColumn(
          label: const Text('Deceased Name'),
          onSort: (col, asc) => _onColumnSort('name'),
        ),
        const DataColumn(label: Text('Age')),
        const DataColumn(label: Text('Date of Death')),
        DataColumn(
          label: const Text('Date of Burial'),
          onSort: (col, asc) => _onColumnSort('date'),
        ),
        const DataColumn(label: Text('Action')),
      ];
      rows = dList.map((d) {
        final spouseOrParents = d.spouseFullName != '—' ? 'Spouse: ${d.spouseFullName}' : 'Parents: ${d.parentsFullName}';
        return DataRow(cells: [
          DataCell(Text(d.bookNumber, style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text(d.pageNumber, style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text(d.lineNumber, style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text(d.deceasedFullName, style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text(d.age)),
          DataCell(Text(d.dateOfDeath.toIso8601String().substring(0, 10))),
          DataCell(Text(d.dateOfBurial.toIso8601String().substring(0, 10))),
          DataCell(_buildTableDetailBtn(
            context: context,
            recordId: d.recordId,
            name: d.deceasedFullName,
            bookRef: d.bookReference,
            dateString: 'Buried: ${d.dateOfBurial.toIso8601String().substring(0, 10)}',
            parentage: spouseOrParents,
            sponsors: 'Cemetery: ${d.placeOfBurial}',
            marginalNotation: d.remarks,
            rawData: d.toMap(),
          )),
        ]);
      }).toList();
    } else if (isConversion) {
      columns = [
        DataColumn(
          label: const Text('Book'),
          onSort: (col, asc) => _onColumnSort('book'),
        ),
        DataColumn(
          label: const Text('Page'),
          onSort: (col, asc) => _onColumnSort('page'),
        ),
        DataColumn(
          label: const Text('Line'),
          onSort: (col, asc) => _onColumnSort('line'),
        ),
        DataColumn(
          label: const Text('Convert Name'),
          onSort: (col, asc) => _onColumnSort('name'),
        ),
        const DataColumn(label: Text('Date of Birth')),
        DataColumn(
          label: const Text('Date of Reception'),
          onSort: (col, asc) => _onColumnSort('date'),
        ),
        const DataColumn(label: Text('Prior Church')),
        const DataColumn(label: Text('Action')),
      ];
      rows = cnList.map((cnv) {
        return DataRow(cells: [
          DataCell(Text(cnv.bookNumber, style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text(cnv.pageNumber, style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text(cnv.lineNumber, style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text(cnv.convertFullName, style: const TextStyle(fontWeight: FontWeight.bold))),
          DataCell(Text(cnv.dateOfBirth.toIso8601String().substring(0, 10))),
          DataCell(Text(cnv.dateOfReception.toIso8601String().substring(0, 10))),
          DataCell(Text(cnv.priorBaptismChurch ?? 'None')),
          DataCell(_buildTableDetailBtn(
            context: context,
            recordId: cnv.recordId,
            name: cnv.convertFullName,
            bookRef: cnv.bookReference,
            dateString: 'Received into Communion: ${cnv.dateOfReception.toIso8601String().substring(0, 10)}',
            parentage: 'Parents: ${cnv.fatherFullName} & ${cnv.motherFullName}',
            sponsors: 'Witness 1: ${cnv.witness1FullName}',
            marginalNotation: cnv.remarks,
            rawData: cnv.toMap(),
          )),
        ]);
      }).toList();
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ParishColors.borderGrey),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                sortColumnIndex: _getSortColumnIndex(),
                sortAscending: _sortAscending,
                columns: columns,
                rows: rows,
                headingRowColor: WidgetStateProperty.all(widget.surfaceColor),
                headingTextStyle: TextStyle(fontWeight: FontWeight.bold, color: widget.themeColor, fontSize: 13),
                dataTextStyle: TextStyle(fontSize: 13, color: ParishColors.textDark),
                columnSpacing: 24,
                horizontalMargin: 20,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTableDetailBtn({
    required BuildContext context,
    required String recordId,
    required String name,
    required String bookRef,
    required String dateString,
    required String parentage,
    required String sponsors,
    String? marginalNotation,
    required Map<String, dynamic> rawData,
  }) {
    return TextButton.icon(
      style: TextButton.styleFrom(
        foregroundColor: widget.themeColor,
        backgroundColor: widget.surfaceColor,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: () => _navigateToDetail(
        context,
        recordId: recordId,
        name: name,
        bookRef: bookRef,
        dateString: dateString,
        parentage: parentage,
        sponsors: sponsors,
        marginalNotation: marginalNotation,
        rawRecordData: rawData,
      ),
      icon: const Icon(Icons.visibility, size: 15),
      label: const Text('View / Print', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildEmptyState({
    required String title,
    required String subtitle,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ParishColors.borderGrey),
      ),
      child: Column(
        children: [
          Icon(
            actionLabel != null ? Icons.search_off_outlined : Icons.inbox_outlined,
            size: 40,
            color: ParishColors.textMuted,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ParishColors.textDark),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: ParishColors.textMuted),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: widget.themeColor, width: 1.3),
                foregroundColor: widget.themeColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: onAction,
              icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
              label: Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConciseSacramentCard({
    required BuildContext context,
    required String name,
    required String parents,
    required String dob,
    required String sacramentDate,
    required String bookRef,
    required String recordId,
    required String parentage,
    required String sponsors,
    String? marginalNotation,
    required Map<String, dynamic> rawRecordData,
  }) {
    final cardWhiteColor = ParishColors.cardWhite;
    final textDarkColor = ParishColors.textDark;
    final textMutedColor = ParishColors.textMuted;

    return InkWell(
      onTap: () => _navigateToDetail(
        context,
        recordId: recordId,
        name: name,
        bookRef: bookRef,
        dateString: sacramentDate,
        parentage: parentage,
        sponsors: sponsors,
        marginalNotation: marginalNotation,
        rawRecordData: rawRecordData,
      ),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardWhiteColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: widget.themeColor.withOpacity(0.35), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: widget.themeColor.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.surfaceColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    widget.sacramentName.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: widget.themeColor,
                    ),
                  ),
                ),
                Flexible(
                  child: Text(
                    bookRef,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textMutedColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              name,
              style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: textDarkColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              parents,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textDarkColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              dob,
              style: TextStyle(fontSize: 12, color: textMutedColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              sacramentDate,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: widget.themeColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 38,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  backgroundColor: widget.surfaceColor,
                  foregroundColor: textDarkColor,
                  elevation: 0,
                  side: BorderSide(color: widget.themeColor, width: 1.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                onPressed: () => _navigateToDetail(
                  context,
                  recordId: recordId,
                  name: name,
                  bookRef: bookRef,
                  dateString: sacramentDate,
                  parentage: parentage,
                  sponsors: sponsors,
                  marginalNotation: marginalNotation,
                  rawRecordData: rawRecordData,
                ),
                icon: Icon(Icons.visibility, size: 16, color: widget.themeColor),
                label: Text(
                  'View & Manage Record Details',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: textDarkColor),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

