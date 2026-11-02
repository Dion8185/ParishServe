// =============================================================================
// FILE: lib/features/sacramental_records/presentation/records_view.dart
// =============================================================================

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/database/local_database_service.dart';
import '../../../../core/services/records_sync_service.dart';
import '../models/baptism_record_model.dart';
import '../models/confirmation_record_model.dart';
import '../models/conversion_record_model.dart';
import '../models/death_record_model.dart';
import '../models/first_communion_record_model.dart';
import '../models/matrimony_record_model.dart';
import 'dialogs/pabuklat_requests_modal.dart';
import 'pages/baptism_manual_entry_page.dart';
import 'pages/certificate_template_management_page.dart';
import 'pages/certificate_verification_page.dart';
import 'pages/confirmation_manual_entry_page.dart';
import 'pages/conversion_manual_entry_page.dart';
import 'pages/death_manual_entry_page.dart';
import 'pages/first_communion_manual_entry_page.dart';
import 'pages/matrimony_manual_entry_page.dart';
import 'pages/sacrament_record_detail_page.dart';
import 'pages/sacrament_registry_page.dart';
import 'package:sqflite/sqflite.dart';

enum RecordsViewDisplayMode { cards, table }

class UniversalRecordResult {
        final String sacramentName;
        final String recordId;
        final String name;
        final String bookRef;
        final String dateString;
        final String parentage;
        final String sponsors;
        final String? marginalNotation;
        final Color themeColor;
        final Color surfaceColor;
        final IconData icon;
        final Map<String, dynamic> rawRecordData;
        final DateTime? sortDate;

        const UniversalRecordResult({
                required this.sacramentName,
                required this.recordId,
                required this.name,
                required this.bookRef,
                required this.dateString,
                required this.parentage,
                required this.sponsors,
                this.marginalNotation,
                required this.themeColor,
                required this.surfaceColor,
                required this.icon,
                required this.rawRecordData,
                this.sortDate,
        });
}

class SacramentalRecordsView extends StatefulWidget {
        const SacramentalRecordsView({super.key});

        @override
        State<SacramentalRecordsView> createState() => _SacramentalRecordsViewState();
}

class _SacramentalRecordsViewState extends State<SacramentalRecordsView>
    with TickerProviderStateMixin {
        final TextEditingController _searchController = TextEditingController();
        final FocusNode _searchFocusNode = FocusNode();
        late AnimationController _skeletonAnimController;
        late Animation<double> _skeletonOpacityAnimation;
        Timer? _debounceTimer;

        bool _isSearching = false;
        List<UniversalRecordResult> _searchResults = [];
        String _selectedSacramentFilter = 'All';

        // Counts for Stats & Badges
        int _baptismCount = 0;
        int _confirmationCount = 0;
        int _communionCount = 0;
        int _matrimonyCount = 0;
        int _deathCount = 0;
        int _conversionCount = 0;

        // View Mode: Cards vs Table
        RecordsViewDisplayMode _viewMode = RecordsViewDisplayMode.cards;

        // Sort & Filter State
        String _sortBy = 'Date: Latest First';
        bool _sortAscending = false;

        // Pagination State
        int _currentPage = 1;
        int _itemsPerPage = 10;

        final List<String> _sacramentFilterOptions = [
                'All',
                'Baptism',
                'Confirmation',
                'First Communion',
                'Matrimony',
                'Death',
                'Conversion',
        ];

        final List<String> _sortOptions = [
                'Date: Latest First',
                'Date: Earliest First',
                'Name (A-Z)',
                'Name (Z-A)',
                'Book Coordinates',
        ];

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

                RecordsSyncService.instance.checkConnectivity();
                RecordsSyncService.instance.updatePendingCount();
                _loadSummaryStats();
        }

        @override
        void dispose() {
                _debounceTimer?.cancel();
                _searchController.dispose();
                _searchFocusNode.dispose();
                _skeletonAnimController.dispose();
                super.dispose();
        }

        Future<void> _loadSummaryStats() async {
                int bCount = 0;
                int cCount = 0;
                int fcCount = 0;
                int mCount = 0;
                int dCount = 0;
                int cvCount = 0;

                final isOnline = await RecordsSyncService.instance.checkConnectivity();

                if (isOnline || kIsWeb) {
                        try {
                                final client = Supabase.instance.client;
                                final res = await Future.wait([
                                        client.from('baptism_records').select('record_id'),
                                        client.from('confirmation_records').select('record_id'),
                                        client.from('first_communion_records').select('record_id'),
                                        client.from('matrimony_records').select('record_id'),
                                        client.from('death_records').select('record_id'),
                                        client.from('conversion_records').select('record_id'),
                                ]);

                                bCount = (res[0] as List).length;
                                cCount = (res[1] as List).length;
                                fcCount = (res[2] as List).length;
                                mCount = (res[3] as List).length;
                                dCount = (res[4] as List).length;
                                cvCount = (res[5] as List).length;
                        } catch (_) {}
                }

                if (bCount == 0 && cCount == 0 && fcCount == 0 && !kIsWeb) {
                        final db = await LocalDatabaseService.instance.database;
                        if (db != null) {
                                try {
                                        bCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM baptism_records')) ?? 0;
                                        cCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM confirmation_records')) ?? 0;
                                        fcCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM first_communion_records')) ?? 0;
                                        mCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM matrimony_records')) ?? 0;
                                        dCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM death_records')) ?? 0;
                                        cvCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM conversion_records')) ?? 0;
                                } catch (_) {}
                        }
                }

                if (!mounted) return;
                setState(() {
                        _baptismCount = bCount;
                        _confirmationCount = cCount;
                        _communionCount = fcCount;
                        _matrimonyCount = mCount;
                        _deathCount = dCount;
                        _conversionCount = cvCount;
                });
        }

        int get _totalRecordsCount =>
            _baptismCount +
                _confirmationCount +
                _communionCount +
                _matrimonyCount +
                _deathCount +
                _conversionCount;

        void _onSearchChanged(String query) {
                _debounceTimer?.cancel();

                if (query.trim().isEmpty) {
                        setState(() {
                                _searchResults = [];
                                _isSearching = false;
                                _currentPage = 1;
                        });
                        return;
                }

                _debounceTimer = Timer(const Duration(milliseconds: 250), () {
                        _performUniversalSearch(query.trim());
                });
        }

        Future<void> _performUniversalSearch(String query) async {
                if (query.isEmpty) return;

                setState(() => _isSearching = true);

                try {
                        final results = await Future.wait([
                                _searchBaptisms(query),
                                _searchConfirmations(query),
                                _searchCommunions(query),
                                _searchMatrimonies(query),
                                _searchDeaths(query),
                                _searchConversions(query),
                        ]);

                        if (!mounted) return;

                        final List<UniversalRecordResult> combined = [];
                        for (final list in results) {
                                combined.addAll(list);
                        }

                        _applySorting(combined);

                        setState(() {
                                _searchResults = combined;
                                _isSearching = false;
                                _currentPage = 1;
                        });
                } catch (_) {
                        if (mounted) setState(() => _isSearching = false);
                }
        }

        // ===========================================================================
        // Search Database Fetchers
        // ===========================================================================

        Future<List<UniversalRecordResult>> _searchBaptisms(String q) async {
                final isOnline = await RecordsSyncService.instance.checkConnectivity();

                if (isOnline || kIsWeb) {
                        try {
                                final response = await Supabase.instance.client
                                    .from('baptism_records')
                                    .select()
                                    .or('child_first_name.ilike.%$q%,child_last_name.ilike.%$q%,father_first_name.ilike.%$q%,father_last_name.ilike.%$q%,mother_first_name.ilike.%$q%,mother_maiden_last_name.ilike.%$q%,record_id.ilike.%$q%,book_number.ilike.%$q%')
                                    .order('date_of_baptism', ascending: false)
                                    .limit(15);

                                return (response as List).map((row) {
                                        final model = BaptismRecordModel.fromMap(row as Map<String, dynamic>);
                                        return _mapBaptismResult(model);
                                }).toList();
                        } catch (_) {
                                if (kIsWeb) return [];
                        }
                }

                final db = await LocalDatabaseService.instance.database;
                if (db != null) {
                        final rows = await db.rawQuery(
                                '''
        SELECT * FROM baptism_records
        WHERE child_first_name LIKE ? OR child_last_name LIKE ? OR father_first_name LIKE ?
           OR father_last_name LIKE ? OR mother_first_name LIKE ? OR mother_maiden_last_name LIKE ?
           OR record_id LIKE ? OR book_number LIKE ?
        ORDER BY date_of_baptism DESC
        LIMIT 15
        ''',
                                ['%$q%', '%$q%', '%$q%', '%$q%', '%$q%', '%$q%', '%$q%', '%$q%'],
                        );
                        return rows.map((r) => _mapBaptismResult(BaptismRecordModel.fromMap(r))).toList();
                }

                return [];
        }

        UniversalRecordResult _mapBaptismResult(BaptismRecordModel model) {
                return UniversalRecordResult(
                        sacramentName: 'Baptism',
                        recordId: model.recordId,
                        name: model.childFullName,
                        bookRef: model.bookReference,
                        dateString: 'Baptism: ${model.dateOfBaptism.toIso8601String().substring(0, 10)}',
                        parentage: 'Parents: ${model.fatherFullName} & ${model.motherFullName}',
                        sponsors: 'Sponsors: ${model.sponsor1FullName} & ${model.sponsor2FullName}',
                        marginalNotation: model.remarks,
                        themeColor: const Color(0xFF164E87),
                        surfaceColor: const Color(0xFFEDF4FB),
                        icon: Icons.water_drop_outlined,
                        rawRecordData: model.toMap(),
                        sortDate: model.dateOfBaptism,
                );
        }

        Future<List<UniversalRecordResult>> _searchConfirmations(String q) async {
                final isOnline = await RecordsSyncService.instance.checkConnectivity();

                if (isOnline || kIsWeb) {
                        try {
                                final response = await Supabase.instance.client
                                    .from('confirmation_records')
                                    .select()
                                    .or('confirmand_first_name.ilike.%$q%,confirmand_last_name.ilike.%$q%,father_first_name.ilike.%$q%,father_last_name.ilike.%$q%,mother_first_name.ilike.%$q%,mother_maiden_last_name.ilike.%$q%,record_id.ilike.%$q%,church_baptized.ilike.%$q%')
                                    .order('date_of_confirmation', ascending: false)
                                    .limit(15);

                                return (response as List).map((row) {
                                        final model = ConfirmationRecordModel.fromMap(row as Map<String, dynamic>);
                                        return _mapConfirmationResult(model);
                                }).toList();
                        } catch (_) {
                                if (kIsWeb) return [];
                        }
                }

                final db = await LocalDatabaseService.instance.database;
                if (db != null) {
                        final rows = await db.rawQuery(
                                '''
        SELECT * FROM confirmation_records
        WHERE confirmand_first_name LIKE ? OR confirmand_last_name LIKE ? OR father_first_name LIKE ?
           OR father_last_name LIKE ? OR mother_first_name LIKE ? OR mother_maiden_last_name LIKE ?
           OR record_id LIKE ? OR church_baptized LIKE ?
        ORDER BY date_of_confirmation DESC
        LIMIT 15
        ''',
                                ['%$q%', '%$q%', '%$q%', '%$q%', '%$q%', '%$q%', '%$q%', '%$q%'],
                        );
                        return rows.map((r) => _mapConfirmationResult(ConfirmationRecordModel.fromMap(r))).toList();
                }

                return [];
        }

        UniversalRecordResult _mapConfirmationResult(ConfirmationRecordModel model) {
                final s2Text = model.sponsor2FullName != null ? ' & ${model.sponsor2FullName} (S2)' : '';
                return UniversalRecordResult(
                        sacramentName: 'Confirmation',
                        recordId: model.recordId,
                        name: model.confirmandFullName,
                        bookRef: model.bookReference,
                        dateString: 'Confirmation: ${model.dateOfConfirmation.toIso8601String().substring(0, 10)}',
                        parentage: 'Parents: ${model.fatherFullName} & ${model.motherFullName}',
                        sponsors: 'Sponsors: ${model.sponsor1FullName} (S1)$s2Text',
                        marginalNotation: model.remarks,
                        themeColor: const Color(0xFFB91C1C),
                        surfaceColor: const Color(0xFFFDF2F2),
                        icon: Icons.local_fire_department_outlined,
                        rawRecordData: model.toMap(),
                        sortDate: model.dateOfConfirmation,
                );
        }

        Future<List<UniversalRecordResult>> _searchCommunions(String q) async {
                final isOnline = await RecordsSyncService.instance.checkConnectivity();

                if (isOnline || kIsWeb) {
                        try {
                                final response = await Supabase.instance.client
                                    .from('first_communion_records')
                                    .select()
                                    .or('communicant_first_name.ilike.%$q%,communicant_last_name.ilike.%$q%,control_number.ilike.%$q%,record_id.ilike.%$q%,baptism_parish.ilike.%$q%')
                                    .order('date_of_communion', ascending: false)
                                    .limit(15);

                                return (response as List).map((row) {
                                        final model = FirstCommunionRecordModel.fromMap(row as Map<String, dynamic>);
                                        return _mapCommunionResult(model);
                                }).toList();
                        } catch (_) {
                                if (kIsWeb) return [];
                        }
                }

                final db = await LocalDatabaseService.instance.database;
                if (db != null) {
                        final rows = await db.rawQuery(
                                '''
        SELECT * FROM first_communion_records
        WHERE communicant_first_name LIKE ? OR communicant_last_name LIKE ?
           OR control_number LIKE ? OR record_id LIKE ? OR baptism_parish LIKE ?
        ORDER BY date_of_communion DESC
        LIMIT 15
        ''',
                                ['%$q%', '%$q%', '%$q%'],
                        );
                        return rows.map((r) => _mapCommunionResult(FirstCommunionRecordModel.fromMap(r))).toList();
                }

                return [];
        }

        UniversalRecordResult _mapCommunionResult(FirstCommunionRecordModel model) {
                final parents = (model.fatherFullName != '—' || model.motherFullName != '—')
                    ? 'Parents: ${model.fatherFullName} & ${model.motherFullName}'
                    : 'Parents: Not Specified in Batch Register';
                return UniversalRecordResult(
                        sacramentName: 'First Communion',
                        recordId: model.recordId,
                        name: model.communicantFullName,
                        bookRef: model.referenceDisplay,
                        dateString: 'Communion: ${model.dateOfCommunion.toIso8601String().substring(0, 10)}',
                        parentage: parents,
                        sponsors: 'Baptism Parish: ${model.baptismParish}',
                        marginalNotation: model.remarks,
                        themeColor: const Color(0xFFD49B18),
                        surfaceColor: const Color(0xFFFFF7E6),
                        icon: Icons.restaurant,
                        rawRecordData: model.toMap(),
                        sortDate: model.dateOfCommunion,
                );
        }

        Future<List<UniversalRecordResult>> _searchMatrimonies(String q) async {
                final isOnline = await RecordsSyncService.instance.checkConnectivity();

                if (isOnline || kIsWeb) {
                        try {
                                final response = await Supabase.instance.client
                                    .from('matrimony_records')
                                    .select()
                                    .or('groom_first_name.ilike.%$q%,groom_last_name.ilike.%$q%,bride_first_name.ilike.%$q%,bride_last_name.ilike.%$q%,record_id.ilike.%$q%,marriage_license_no.ilike.%$q%')
                                    .order('date_of_marriage', ascending: false)
                                    .limit(15);

                                return (response as List).map((row) {
                                        final model = MatrimonyRecordModel.fromMap(row as Map<String, dynamic>);
                                        return _mapMatrimonyResult(model);
                                }).toList();
                        } catch (_) {
                                if (kIsWeb) return [];
                        }
                }

                final db = await LocalDatabaseService.instance.database;
                if (db != null) {
                        final rows = await db.rawQuery(
                                '''
        SELECT * FROM matrimony_records
        WHERE groom_first_name LIKE ? OR groom_last_name LIKE ? OR bride_first_name LIKE ?
           OR bride_last_name LIKE ? OR record_id LIKE ? OR marriage_license_no LIKE ?
        ORDER BY date_of_marriage DESC
        LIMIT 15
        ''',
                                ['%$q%', '%$q%', '%$q%', '%$q%', '%$q%', '%$q%'],
                        );
                        return rows.map((r) => _mapMatrimonyResult(MatrimonyRecordModel.fromMap(r))).toList();
                }

                return [];
        }

        UniversalRecordResult _mapMatrimonyResult(MatrimonyRecordModel model) {
                return UniversalRecordResult(
                        sacramentName: 'Matrimony',
                        recordId: model.recordId,
                        name: '${model.groomFullName}  &  ${model.brideFullName}',
                        bookRef: model.bookReference,
                        dateString: 'Marriage: ${model.dateOfMarriage.toIso8601String().substring(0, 10)}',
                        parentage: 'Groom (${model.groomFatherLastName}) & Bride (${model.brideFatherLastName})',
                        sponsors: 'Primary Sponsors: ${model.sponsor1FirstName} ${model.sponsor1LastName} & ${model.sponsor2FirstName} ${model.sponsor2LastName}',
                        marginalNotation: model.remarks,
                        themeColor: const Color(0xFF9D174D),
                        surfaceColor: const Color(0xFFFCE7F3),
                        icon: Icons.favorite_border,
                        rawRecordData: model.toMap(),
                        sortDate: model.dateOfMarriage,
                );
        }

        Future<List<UniversalRecordResult>> _searchDeaths(String q) async {
                final isOnline = await RecordsSyncService.instance.checkConnectivity();

                if (isOnline || kIsWeb) {
                        try {
                                final response = await Supabase.instance.client
                                    .from('death_records')
                                    .select()
                                    .or('deceased_first_name.ilike.%$q%,deceased_last_name.ilike.%$q%,place_of_burial.ilike.%$q%,record_id.ilike.%$q%,cause_of_death.ilike.%$q%')
                                    .order('date_of_burial', ascending: false)
                                    .limit(15);

                                return (response as List).map((row) {
                                        final model = DeathRecordModel.fromMap(row as Map<String, dynamic>);
                                        return _mapDeathResult(model);
                                }).toList();
                        } catch (_) {
                                if (kIsWeb) return [];
                        }
                }

                final db = await LocalDatabaseService.instance.database;
                if (db != null) {
                        final rows = await db.rawQuery(
                                '''
        SELECT * FROM death_records
        WHERE deceased_first_name LIKE ? OR deceased_last_name LIKE ? OR place_of_burial LIKE ?
           OR record_id LIKE ? OR cause_of_death LIKE ?
        ORDER BY date_of_burial DESC
        LIMIT 15
        ''',
                                ['%$q%', '%$q%', '%$q%', '%$q%', '%$q%'],
                        );
                        return rows.map((r) => _mapDeathResult(DeathRecordModel.fromMap(r))).toList();
                }

                return [];
        }

        UniversalRecordResult _mapDeathResult(DeathRecordModel model) {
                final spouseOrParents = model.spouseFullName != '—'
                    ? 'Spouse: ${model.spouseFullName}'
                    : 'Parents: ${model.parentsFullName}';
                return UniversalRecordResult(
                        sacramentName: 'Death',
                        recordId: model.recordId,
                        name: model.deceasedFullName,
                        bookRef: model.bookReference,
                        dateString: 'Burial: ${model.dateOfBurial.toIso8601String().substring(0, 10)}',
                        parentage: spouseOrParents,
                        sponsors: 'Cemetery: ${model.placeOfBurial} • Service: ${model.liturgicalService}',
                        marginalNotation: model.remarks,
                        themeColor: const Color(0xFF6B21A8),
                        surfaceColor: const Color(0xFFF3E8FF),
                        icon: Icons.church_outlined,
                        rawRecordData: model.toMap(),
                        sortDate: model.dateOfBurial,
                );
        }

        Future<List<UniversalRecordResult>> _searchConversions(String q) async {
                final isOnline = await RecordsSyncService.instance.checkConnectivity();

                if (isOnline || kIsWeb) {
                        try {
                                final response = await Supabase.instance.client
                                    .from('conversion_records')
                                    .select()
                                    .or('convert_first_name.ilike.%$q%,convert_last_name.ilike.%$q%,record_id.ilike.%$q%,prior_baptism_church.ilike.%$q%')
                                    .order('date_of_reception', ascending: false)
                                    .limit(15);

                                return (response as List).map((row) {
                                        final model = ConversionRecordModel.fromMap(row as Map<String, dynamic>);
                                        return _mapConversionResult(model);
                                }).toList();
                        } catch (_) {
                                if (kIsWeb) return [];
                        }
                }

                final db = await LocalDatabaseService.instance.database;
                if (db != null) {
                        final rows = await db.rawQuery(
                                '''
        SELECT * FROM conversion_records
        WHERE convert_first_name LIKE ? OR convert_last_name LIKE ?
           OR record_id LIKE ? OR prior_baptism_church LIKE ?
        ORDER BY date_of_reception DESC
        LIMIT 15
        ''',
                                ['%$q%', '%$q%', '%$q%'],
                        );
                        return rows.map((r) => _mapConversionResult(ConversionRecordModel.fromMap(r))).toList();
                }

                return [];
        }

        UniversalRecordResult _mapConversionResult(ConversionRecordModel model) {
                return UniversalRecordResult(
                        sacramentName: 'Conversion',
                        recordId: model.recordId,
                        name: model.convertFullName,
                        bookRef: model.bookReference,
                        dateString: 'Reception: ${model.dateOfReception.toIso8601String().substring(0, 10)}',
                        parentage: 'Parents: ${model.fatherFullName} & ${model.motherFullName}',
                        sponsors: 'Witness: ${model.witness1FullName}',
                        marginalNotation: model.remarks,
                        themeColor: const Color(0xFF2D6A4F),
                        surfaceColor: const Color(0xFFEDF7F2),
                        icon: Icons.eco_outlined,
                        rawRecordData: model.toMap(),
                        sortDate: model.dateOfReception,
                );
        }

        // ===========================================================================
        // Filtering & Sorting Operations
        // ===========================================================================

        List<UniversalRecordResult> get _filteredSearchResults {
                var list = List<UniversalRecordResult>.from(_searchResults);

                if (_selectedSacramentFilter != 'All') {
                        list = list.where((s) => s.sacramentName.toLowerCase() == _selectedSacramentFilter.toLowerCase()).toList();
                }

                _applySorting(list);
                return list;
        }

        void _applySorting(List<UniversalRecordResult> list) {
                list.sort((a, b) {
                        int comparison = 0;
                        switch (_sortBy) {
                                case 'Date: Latest First':
                                        final da = a.sortDate ?? DateTime(1970);
                                        final db = b.sortDate ?? DateTime(1970);
                                        comparison = db.compareTo(da);
                                        break;
                                case 'Date: Earliest First':
                                        final da = a.sortDate ?? DateTime(1970);
                                        final db = b.sortDate ?? DateTime(1970);
                                        comparison = da.compareTo(db);
                                        break;
                                case 'Name (A-Z)':
                                        comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
                                        break;
                                case 'Name (Z-A)':
                                        comparison = b.name.toLowerCase().compareTo(a.name.toLowerCase());
                                        break;
                                case 'Book Coordinates':
                                default:
                                        comparison = a.bookRef.compareTo(b.bookRef);
                                        break;
                        }
                        return _sortAscending ? -comparison : comparison;
                });
        }

        int get _totalPages {
                final total = _filteredSearchResults.length;
                if (total == 0) return 1;
                return (total / _itemsPerPage).ceil();
        }

        int get _activeFilterCount {
                int count = 0;
                if (_selectedSacramentFilter != 'All') count++;
                if (_sortBy != 'Date: Latest First' || _sortAscending) count++;
                return count;
        }

        bool get _hasActiveFilters => _activeFilterCount > 0;

        void _resetFilters() {
                setState(() {
                        _selectedSacramentFilter = 'All';
                        _sortBy = 'Date: Latest First';
                        _sortAscending = false;
                        _currentPage = 1;
                });
        }

        void _navigateToDetail(UniversalRecordResult result) {
                Navigator.push(
                        context,
                        MaterialPageRoute(
                                builder: (_) => SacramentRecordDetailPage(
                                        sacramentName: result.sacramentName,
                                        recordId: result.recordId,
                                        name: result.name,
                                        bookRef: result.bookRef,
                                        dateString: result.dateString,
                                        parentage: result.parentage,
                                        sponsors: result.sponsors,
                                        marginalNotation: result.marginalNotation,
                                        themeColor: result.themeColor,
                                        surfaceColor: result.surfaceColor,
                                        rawRecordData: result.rawRecordData,
                                        onRecordUpdated: () {
                                                _loadSummaryStats();
                                                if (_searchController.text.trim().isNotEmpty) {
                                                        _performUniversalSearch(_searchController.text.trim());
                                                }
                                        },
                                ),
                        ),
                );
        }

        void _openCertificateVerificationPortal() {
                Navigator.push(
                        context,
                        MaterialPageRoute(
                                builder: (_) => const CertificateVerificationPage(),
                        ),
                );
        }

        // ===========================================================================
        // Filter & Sort Bottom Sheet
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
                                                                                                'Filter & Sort Registers',
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

                                                                        Text(
                                                                                'Sacrament Register Filter',
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
                                                                                        children: _sacramentFilterOptions.map((sacrament) {
                                                                                                final isSelected = _selectedSacramentFilter == sacrament;
                                                                                                return Padding(
                                                                                                        padding: const EdgeInsets.only(right: 6.0),
                                                                                                        child: ChoiceChip(
                                                                                                                label: Text(sacrament),
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
                                                                                                                                _selectedSacramentFilter = sacrament;
                                                                                                                                _currentPage = 1;
                                                                                                                        });
                                                                                                                        setSheetState(() {});
                                                                                                                },
                                                                                                        ),
                                                                                                );
                                                                                        }).toList(),
                                                                                ),
                                                                        ),
                                                                        const SizedBox(height: 18),

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

        // ===========================================================================
        // Offline Resource Pack Modal
        // ===========================================================================

        void _showOfflinePackModal(BuildContext context) {
                bool forceWipe = false;

                showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (ctx) => StatefulBuilder(
                                builder: (context, setModalState) {
                                        final isSyncing = RecordsSyncService.instance.isSyncInProgress;

                                        return AlertDialog(
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                                backgroundColor: ParishColors.cardWhite,
                                                title: Row(
                                                        children: [
                                                                Container(
                                                                        padding: const EdgeInsets.all(8),
                                                                        decoration: const BoxDecoration(
                                                                                color: ParishColors.marianBlue,
                                                                                shape: BoxShape.circle,
                                                                        ),
                                                                        child: const Icon(Icons.cloud_download, color: Colors.white, size: 20),
                                                                ),
                                                                const SizedBox(width: 12),
                                                                Expanded(
                                                                        child: Column(
                                                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                                                children: [
                                                                                        Text(
                                                                                                'Offline Records Pack',
                                                                                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                                                                                        ),
                                                                                        Text(
                                                                                                'Cache all 6 registers, templates & seals locally',
                                                                                                style: TextStyle(fontSize: 11.5, color: ParishColors.textMuted),
                                                                                        ),
                                                                                ],
                                                                        ),
                                                                ),
                                                        ],
                                                ),
                                                content: SizedBox(
                                                        width: 480,
                                                        child: ValueListenableBuilder<RecordsSyncProgress?>(
                                                                valueListenable: RecordsSyncService.downloadProgressNotifier,
                                                                builder: (context, progress, _) {
                                                                        return Column(
                                                                                mainAxisSize: MainAxisSize.min,
                                                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                                                children: [
                                                                                        ValueListenableBuilder<DateTime?>(
                                                                                                valueListenable: RecordsSyncService.lastSyncedAtNotifier,
                                                                                                builder: (context, lastSync, _) {
                                                                                                        final lastSyncText = lastSync != null
                                                                                                            ? '${lastSync.toLocal().toString().substring(0, 16)}'
                                                                                                            : 'Never downloaded';
                                                                                                        return Container(
                                                                                                                padding: const EdgeInsets.all(12),
                                                                                                                decoration: BoxDecoration(
                                                                                                                        color: ParishColors.marianBlue.withOpacity(0.06),
                                                                                                                        borderRadius: BorderRadius.circular(10),
                                                                                                                        border: Border.all(color: ParishColors.marianBlue.withOpacity(0.2)),
                                                                                                                ),
                                                                                                                child: Row(
                                                                                                                        children: [
                                                                                                                                const Icon(Icons.info_outline, size: 18, color: ParishColors.marianBlue),
                                                                                                                                const SizedBox(width: 10),
                                                                                                                                Expanded(
                                                                                                                                        child: Text(
                                                                                                                                                'Last offline pack update: $lastSyncText',
                                                                                                                                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ParishColors.textDark),
                                                                                                                                        ),
                                                                                                                                ),
                                                                                                                        ],
                                                                                                                ),
                                                                                                        );
                                                                                                },
                                                                                        ),
                                                                                        const SizedBox(height: 14),

                                                                                        Text(
                                                                                                'Downloading the offline pack pulls all canonical registers, active/custom certificate templates, background frames, seals, and typography into your device\'s SQLite database. You can operate freely in archives and vaults without internet.',
                                                                                                style: TextStyle(fontSize: 12.5, color: ParishColors.textDark.withOpacity(0.85), height: 1.4),
                                                                                        ),
                                                                                        const SizedBox(height: 14),

                                                                                        if (progress != null) ...[
                                                                                                ClipRRect(
                                                                                                        borderRadius: BorderRadius.circular(6),
                                                                                                        child: LinearProgressIndicator(
                                                                                                                value: progress.progressFraction > 0 ? progress.progressFraction : null,
                                                                                                                minHeight: 8,
                                                                                                                backgroundColor: Colors.grey.shade200,
                                                                                                                valueColor: const AlwaysStoppedAnimation<Color>(ParishColors.marianBlue),
                                                                                                        ),
                                                                                                ),
                                                                                                const SizedBox(height: 8),
                                                                                                Row(
                                                                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                                        children: [
                                                                                                                Expanded(
                                                                                                                        child: Text(
                                                                                                                                progress.currentTableName,
                                                                                                                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: ParishColors.marianBlue),
                                                                                                                                overflow: TextOverflow.ellipsis,
                                                                                                                        ),
                                                                                                                ),
                                                                                                                Text(
                                                                                                                        '${(progress.progressFraction * 100).toInt()}%',
                                                                                                                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: ParishColors.textMuted),
                                                                                                                ),
                                                                                                        ],
                                                                                                ),
                                                                                        ] else ...[
                                                                                                CheckboxListTile(
                                                                                                        contentPadding: EdgeInsets.zero,
                                                                                                        dense: true,
                                                                                                        title: const Text('Force clean wipe and full re-download', style: TextStyle(fontSize: 12.5)),
                                                                                                        value: forceWipe,
                                                                                                        onChanged: isSyncing
                                                                                                            ? null
                                                                                                            : (val) => setModalState(() => forceWipe = val ?? false),
                                                                                                        controlAffinity: ListTileControlAffinity.leading,
                                                                                                ),
                                                                                        ],
                                                                                ],
                                                                        );
                                                                },
                                                        ),
                                                ),
                                                actions: [
                                                        TextButton(
                                                                onPressed: isSyncing ? null : () => Navigator.pop(ctx),
                                                                child: Text('Close', style: TextStyle(color: ParishColors.textMuted)),
                                                        ),
                                                        ElevatedButton.icon(
                                                                style: ElevatedButton.styleFrom(
                                                                        backgroundColor: ParishColors.marianBlue,
                                                                        foregroundColor: Colors.white,
                                                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                                ),
                                                                onPressed: isSyncing
                                                                    ? null
                                                                    : () async {
                                                                        setModalState(() {});
                                                                        try {
                                                                                await RecordsSyncService.instance.downloadAllOfflineResources(
                                                                                        forceWipe: forceWipe,
                                                                                );
                                                                                _loadSummaryStats();
                                                                                if (context.mounted) {
                                                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                                                                const SnackBar(
                                                                                                        content: Text('Offline pack successfully synchronized to local SQLite!'),
                                                                                                        backgroundColor: ParishColors.oliveGreen,
                                                                                                ),
                                                                                        );
                                                                                        Navigator.pop(ctx);
                                                                                }
                                                                        } catch (e) {
                                                                                if (context.mounted) {
                                                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                                                                SnackBar(
                                                                                                        content: Text('Download failed: $e'),
                                                                                                        backgroundColor: ParishColors.mercyRed,
                                                                                                ),
                                                                                        );
                                                                                }
                                                                        }
                                                                },
                                                                icon: const Icon(Icons.download, size: 16),
                                                                label: const Text('Download Offline Pack', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                                        ),
                                                ],
                                        );
                                },
                        ),
                );
        }

        // ===========================================================================
        // Slide-Up Bottom Sheet Modal for "Encode a new record" (Image 1)
        // ===========================================================================

        void _showNewRecordSelector(BuildContext context) {
                showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: false,
                        backgroundColor: Colors.transparent,
                        builder: (ctx) => Align(
                                alignment: Alignment.bottomCenter,
                                child: ConstrainedBox(
                                        constraints: const BoxConstraints(maxWidth: 560),
                                        child: Container(
                                                decoration: BoxDecoration(
                                                        color: ParishColors.cardWhite,
                                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                                ),
                                                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                                                child: Column(
                                                        mainAxisSize: MainAxisSize.min,
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                                Center(
                                                                        child: Container(
                                                                                width: 36,
                                                                                height: 4,
                                                                                margin: const EdgeInsets.only(bottom: 14),
                                                                                decoration: BoxDecoration(
                                                                                        color: Colors.grey.shade300,
                                                                                        borderRadius: BorderRadius.circular(2),
                                                                                ),
                                                                        ),
                                                                ),
                                                                Row(
                                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                                        children: [
                                                                                Expanded(
                                                                                        child: Column(
                                                                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                                                                children: [
                                                                                                        Text(
                                                                                                                'Encode a new record',
                                                                                                                style: TextStyle(
                                                                                                                        fontSize: 18,
                                                                                                                        fontWeight: FontWeight.bold,
                                                                                                                        color: ParishColors.textDark,
                                                                                                                ),
                                                                                                        ),
                                                                                                        const SizedBox(height: 4),
                                                                                                        Text(
                                                                                                                'Which register does this entry belong to?',
                                                                                                                style: TextStyle(
                                                                                                                        fontSize: 13,
                                                                                                                        color: ParishColors.textMuted,
                                                                                                                ),
                                                                                                        ),
                                                                                                ],
                                                                                        ),
                                                                                ),
                                                                                IconButton(
                                                                                        icon: Icon(Icons.close, color: ParishColors.textMuted, size: 22),
                                                                                        padding: EdgeInsets.zero,
                                                                                        constraints: const BoxConstraints(),
                                                                                        tooltip: 'Close',
                                                                                        onPressed: () => Navigator.pop(ctx),
                                                                                ),
                                                                        ],
                                                                ),
                                                                const SizedBox(height: 16),
                                                                _buildSacramentPickerTile(
                                                                        ctx: ctx,
                                                                        title: 'Baptism Register',
                                                                        subtitle: 'Liber Baptismorum • Baptisms, lineage & godparents',
                                                                        icon: Icons.water_drop_outlined,
                                                                        color: const Color(0xFF164E87),
                                                                        onTap: () {
                                                                                Navigator.pop(ctx);
                                                                                Navigator.push(context, MaterialPageRoute(builder: (_) => BaptismManualEntryPage(onRecordSaved: _loadSummaryStats)));
                                                                        },
                                                                ),
                                                                _buildSacramentPickerTile(
                                                                        ctx: ctx,
                                                                        title: 'Confirmation Register',
                                                                        subtitle: 'Liber Confirmatorum • Confirmands & sponsors',
                                                                        icon: Icons.local_fire_department_outlined,
                                                                        color: const Color(0xFFB91C1C),
                                                                        onTap: () {
                                                                                Navigator.pop(ctx);
                                                                                Navigator.push(context, MaterialPageRoute(builder: (_) => ConfirmationManualEntryPage(onRecordSaved: _loadSummaryStats)));
                                                                        },
                                                                ),
                                                                _buildSacramentPickerTile(
                                                                        ctx: ctx,
                                                                        title: 'First Communion Register',
                                                                        subtitle: 'Liber Primae Communionis • Annual batch registries',
                                                                        icon: Icons.restaurant,
                                                                        color: const Color(0xFFD49B18),
                                                                        onTap: () {
                                                                                Navigator.pop(ctx);
                                                                                Navigator.push(context, MaterialPageRoute(builder: (_) => FirstCommunionManualEntryPage(onRecordSaved: _loadSummaryStats)));
                                                                        },
                                                                ),
                                                                _buildSacramentPickerTile(
                                                                        ctx: ctx,
                                                                        title: 'Matrimony Register',
                                                                        subtitle: 'Liber Matrimoniorum • Spouses, license & banns',
                                                                        icon: Icons.favorite_border,
                                                                        color: const Color(0xFF9D174D),
                                                                        onTap: () {
                                                                                Navigator.pop(ctx);
                                                                                Navigator.push(context, MaterialPageRoute(builder: (_) => MatrimonyManualEntryPage(onRecordSaved: _loadSummaryStats)));
                                                                        },
                                                                ),
                                                                _buildSacramentPickerTile(
                                                                        ctx: ctx,
                                                                        title: 'Death & Burial Register',
                                                                        subtitle: 'Liber Defunctorum • Deceased, burial & rites',
                                                                        icon: Icons.church_outlined,
                                                                        color: const Color(0xFF6B21A8),
                                                                        onTap: () {
                                                                                Navigator.pop(ctx);
                                                                                Navigator.push(context, MaterialPageRoute(builder: (_) => DeathManualEntryPage(onRecordSaved: _loadSummaryStats)));
                                                                        },
                                                                ),
                                                                _buildSacramentPickerTile(
                                                                        ctx: ctx,
                                                                        title: 'Conversion Register',
                                                                        subtitle: 'Liber Conversorum • Reception into full communion',
                                                                        icon: Icons.eco_outlined,
                                                                        color: const Color(0xFF2D6A4F),
                                                                        onTap: () {
                                                                                Navigator.pop(ctx);
                                                                                Navigator.push(context, MaterialPageRoute(builder: (_) => ConversionManualEntryPage(onRecordSaved: _loadSummaryStats)));
                                                                        },
                                                                ),
                                                        ],
                                                ),
                                        ),
                                ),
                        ),
                );
        }

        Widget _buildSacramentPickerTile({
                required BuildContext ctx,
                required String title,
                required String subtitle,
                required IconData icon,
                required Color color,
                required VoidCallback onTap,
        }) {
                return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                        onTap: onTap,
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                                decoration: BoxDecoration(
                                                        color: color.withOpacity(0.04),
                                                        borderRadius: BorderRadius.circular(12),
                                                        border: Border.all(color: color.withOpacity(0.35), width: 1.2),
                                                ),
                                                child: Row(
                                                        children: [
                                                                Container(
                                                                        padding: const EdgeInsets.all(8),
                                                                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                                                                        child: Icon(icon, color: Colors.white, size: 18),
                                                                ),
                                                                const SizedBox(width: 14),
                                                                Expanded(
                                                                        child: Column(
                                                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                                                children: [
                                                                                        Text(
                                                                                                title,
                                                                                                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                                                                                        ),
                                                                                        const SizedBox(height: 2),
                                                                                        Text(
                                                                                                subtitle,
                                                                                                style: TextStyle(fontSize: 11.5, color: ParishColors.textMuted),
                                                                                        ),
                                                                                ],
                                                                        ),
                                                                ),
                                                                Icon(Icons.chevron_right, size: 20, color: color),
                                                        ],
                                                ),
                                        ),
                                ),
                        ),
                );
        }

        // ===========================================================================
        // Responsive Action Cards Bar
        // ===========================================================================

        Widget _buildActionCardsRow(bool isDesktop) {
                final encodeCard = _buildDashboardActionCard(
                        title: 'Encode Record',
                        subtitle: 'Add a new register entry',
                        icon: Icons.post_add,
                        isSolidBlue: true,
                        onTap: () => _showNewRecordSelector(context),
                );

                final verifyCard = _buildDashboardActionCard(
                        title: 'Verify Certificate',
                        subtitle: 'Scan a QR to confirm authenticity',
                        icon: Icons.qr_code_scanner,
                        isSolidBlue: false,
                        borderColor: ParishColors.borderGrey,
                        iconColor: ParishColors.marianBlue,
                        onTap: _openCertificateVerificationPortal,
                );

                final studioCard = _buildDashboardActionCard(
                        title: 'Certificate Studio',
                        subtitle: 'Design & manage templates',
                        icon: Icons.design_services_outlined,
                        isSolidBlue: false,
                        borderColor: ParishColors.goldAccent,
                        iconColor: ParishColors.goldAccent,
                        titleColor: ParishColors.goldAccent,
                        onTap: () {
                                Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => const CertificateTemplateManagementPage()),
                                );
                        },
                );

                if (isDesktop) {
                        return Row(
                                children: [
                                        Expanded(child: encodeCard),
                                        const SizedBox(width: 16),
                                        Expanded(child: verifyCard),
                                        const SizedBox(width: 16),
                                        Expanded(child: studioCard),
                                ],
                        );
                }

                return Column(
                        children: [
                                encodeCard,
                                const SizedBox(height: 10),
                                Row(
                                        children: [
                                                Expanded(child: verifyCard),
                                                const SizedBox(width: 10),
                                                Expanded(child: studioCard),
                                        ],
                                ),
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
                                height: 72,
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
                                                        width: 44,
                                                        height: 44,
                                                        decoration: BoxDecoration(
                                                                color: isSolidBlue ? Colors.white.withOpacity(0.18) : (iconColor?.withOpacity(0.12) ?? ParishColors.marianBlueSurface),
                                                                borderRadius: BorderRadius.circular(10),
                                                        ),
                                                        child: Icon(icon, color: resolvedIconColor, size: 22),
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
        // Anti-Layout-Shift Skeleton Loader
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
                                                                                                                width: 150,
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
                                                                                                                width: 170,
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
        // Build Main Dashboard Shell
        // ===========================================================================

        @override
        Widget build(BuildContext context) {
                final textDarkColor = ParishColors.textDark;
                final cardWhiteColor = ParishColors.cardWhite;
                final borderGreyColor = ParishColors.borderGrey;

                return LayoutBuilder(
                        builder: (context, constraints) {
                                final double screenWidth = constraints.maxWidth;
                                final bool isDesktop = screenWidth >= 1080;
                                final bool isTablet = screenWidth >= 650 && screenWidth < 1080;
                                final bool isMobile = screenWidth < 650;
                                final isSearchActive = _searchController.text.trim().isNotEmpty;

                                return RefreshIndicator(
                                        onRefresh: () async {
                                                await RecordsSyncService.instance.checkConnectivity();
                                                await RecordsSyncService.instance.updatePendingCount();
                                                await _loadSummaryStats();
                                                if (isSearchActive) {
                                                        _performUniversalSearch(_searchController.text.trim());
                                                }
                                        },
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
                                                                                // 1. Header with title, record tally & overflow popup menu
                                                                                Row(
                                                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                                                        children: [
                                                                                                Expanded(
                                                                                                        child: Column(
                                                                                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                                                                                children: [
                                                                                                                        Text(
                                                                                                                                'Sacramental Registers',
                                                                                                                                style: TextStyle(
                                                                                                                                        fontSize: isMobile ? 20 : 25,
                                                                                                                                        fontWeight: FontWeight.bold,
                                                                                                                                        color: textDarkColor,
                                                                                                                                ),
                                                                                                                        ),
                                                                                                                        const SizedBox(height: 4),
                                                                                                                        Text(
                                                                                                                                '$_totalRecordsCount records across 6 canonical books',
                                                                                                                                style: TextStyle(
                                                                                                                                        fontSize: 13,
                                                                                                                                        color: ParishColors.textMuted,
                                                                                                                                ),
                                                                                                                        ),
                                                                                                                ],
                                                                                                        ),
                                                                                                ),
                                                                                                PopupMenuButton<String>(
                                                                                                        icon: Icon(Icons.more_vert, color: ParishColors.textMuted, size: 22),
                                                                                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                                                                        color: cardWhiteColor,
                                                                                                        onSelected: (val) {
                                                                                                                if (val == 'download_pack') {
                                                                                                                        _showOfflinePackModal(context);
                                                                                                                } else if (val == 'pabuklat') {
                                                                                                                        showPabuklatRequestsModal(context);
                                                                                                                } else if (val == 'refresh') {
                                                                                                                        _loadSummaryStats();
                                                                                                                        RecordsSyncService.instance.checkConnectivity();
                                                                                                                }
                                                                                                        },
                                                                                                        itemBuilder: (ctx) => [
                                                                                                                const PopupMenuItem(
                                                                                                                        value: 'download_pack',
                                                                                                                        child: Row(
                                                                                                                                children: [
                                                                                                                                        Icon(Icons.cloud_download_outlined, size: 18, color: ParishColors.marianBlue),
                                                                                                                                        SizedBox(width: 10),
                                                                                                                                        Text('Download Offline Pack', style: TextStyle(fontSize: 13)),
                                                                                                                                ],
                                                                                                                        ),
                                                                                                                ),
                                                                                                                const PopupMenuItem(
                                                                                                                        value: 'pabuklat',
                                                                                                                        child: Row(
                                                                                                                                children: [
                                                                                                                                        Icon(Icons.folder_shared_outlined, size: 18, color: ParishColors.oliveGreen),
                                                                                                                                        SizedBox(width: 10),
                                                                                                                                        Text('Pabuklat Search Requests', style: TextStyle(fontSize: 13)),
                                                                                                                                ],
                                                                                                                        ),
                                                                                                                ),
                                                                                                                const PopupMenuItem(
                                                                                                                        value: 'refresh',
                                                                                                                        child: Row(
                                                                                                                                children: [
                                                                                                                                        Icon(Icons.refresh, size: 18),
                                                                                                                                        SizedBox(width: 10),
                                                                                                                                        Text('Refresh Registers', style: TextStyle(fontSize: 13)),
                                                                                                                                ],
                                                                                                                        ),
                                                                                                                ),
                                                                                                        ],
                                                                                                ),
                                                                                        ],
                                                                                ),
                                                                                const SizedBox(height: 12),

                                                                                // 2. Connectivity & Sync Status Bar
                                                                                ValueListenableBuilder<RecordsSyncStatus>(
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
                                                                                                                            ? 'Offline Mode • Working Locally ($pendingCount pending changes)'
                                                                                                                            : 'Offline Mode • Working Locally';
                                                                                                                } else if (status == RecordsSyncStatus.syncing) {
                                                                                                                        pillColor = Colors.blue.shade50;
                                                                                                                        textColor = Colors.blue.shade900;
                                                                                                                        statusIcon = Icons.sync;
                                                                                                                        statusLabel = 'Syncing records with Supabase cloud...';
                                                                                                                } else if (pendingCount > 0) {
                                                                                                                        pillColor = Colors.orange.shade50;
                                                                                                                        textColor = Colors.orange.shade900;
                                                                                                                        statusIcon = Icons.upload_file;
                                                                                                                        statusLabel = 'Online • $pendingCount record(s) queued for upload (Tap to Sync Now)';
                                                                                                                } else {
                                                                                                                        pillColor = const Color(0xFFE8F5E9);
                                                                                                                        textColor = const Color(0xFF2E7D32);
                                                                                                                        statusIcon = Icons.cloud_done;
                                                                                                                        statusLabel = 'Online • all records synchronized';
                                                                                                                }

                                                                                                                return InkWell(
                                                                                                                        onTap: pendingCount > 0 && status != RecordsSyncStatus.syncing
                                                                                                                            ? () => RecordsSyncService.instance.syncPendingChanges()
                                                                                                                            : null,
                                                                                                                        borderRadius: BorderRadius.circular(8),
                                                                                                                        child: Container(
                                                                                                                                width: double.infinity,
                                                                                                                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                                                                                                                decoration: BoxDecoration(
                                                                                                                                        color: pillColor,
                                                                                                                                        borderRadius: BorderRadius.circular(8),
                                                                                                                                        border: Border.all(color: textColor.withOpacity(0.3)),
                                                                                                                                ),
                                                                                                                                child: Row(
                                                                                                                                        children: [
                                                                                                                                                Icon(statusIcon, size: 16, color: textColor),
                                                                                                                                                const SizedBox(width: 8),
                                                                                                                                                Expanded(
                                                                                                                                                        child: Text(
                                                                                                                                                                statusLabel,
                                                                                                                                                                style: TextStyle(
                                                                                                                                                                        fontSize: 12,
                                                                                                                                                                        fontWeight: FontWeight.w600,
                                                                                                                                                                        color: textColor,
                                                                                                                                                                ),
                                                                                                                                                                overflow: TextOverflow.ellipsis,
                                                                                                                                                        ),
                                                                                                                                                ),
                                                                                                                                                if (pendingCount > 0 && status != RecordsSyncStatus.syncing) ...[
                                                                                                                                                        const SizedBox(width: 8),
                                                                                                                                                        Icon(Icons.refresh, size: 15, color: textColor),
                                                                                                                                                ],
                                                                                                                                        ],
                                                                                                                                ),
                                                                                                                        ),
                                                                                                                );
                                                                                                        },
                                                                                                );
                                                                                        },
                                                                                ),
                                                                                const SizedBox(height: 16),

                                                                                // 3. Action Cards Row (Aligned with Register Grid Columns)
                                                                                _buildActionCardsRow(isDesktop),
                                                                                const SizedBox(height: 16),

                                                                                // 4. Search Bar (Exact Reference UI: Height 48, Marian Blue Icon, Rounded Border 12)
                                                                                Container(
                                                                                        width: double.infinity,
                                                                                        height: 48,
                                                                                        padding: const EdgeInsets.symmetric(horizontal: 14),
                                                                                        decoration: BoxDecoration(
                                                                                                color: cardWhiteColor,
                                                                                                borderRadius: BorderRadius.circular(12),
                                                                                                border: Border.all(
                                                                                                        color: borderGreyColor,
                                                                                                        width: 1,
                                                                                                ),
                                                                                        ),
                                                                                        child: Row(
                                                                                                children: [
                                                                                                        const Icon(
                                                                                                                Icons.search,
                                                                                                                size: 21,
                                                                                                                color: ParishColors.marianBlue,
                                                                                                        ),
                                                                                                        const SizedBox(width: 10),
                                                                                                        Expanded(
                                                                                                                child: TextField(
                                                                                                                        controller: _searchController,
                                                                                                                        focusNode: _searchFocusNode,
                                                                                                                        onChanged: _onSearchChanged,
                                                                                                                        style: TextStyle(
                                                                                                                                fontSize: 14,
                                                                                                                                color: textDarkColor,
                                                                                                                        ),
                                                                                                                        decoration: InputDecoration(
                                                                                                                                hintText: 'Search every register by name, parent, book or ID...',
                                                                                                                                hintStyle: TextStyle(
                                                                                                                                        fontSize: 13,
                                                                                                                                        color: ParishColors.textMuted,
                                                                                                                                ),
                                                                                                                                border: InputBorder.none,
                                                                                                                                isDense: true,
                                                                                                                        ),
                                                                                                                ),
                                                                                                        ),
                                                                                                        if (_isSearching)
                                                                                                                const Padding(
                                                                                                                        padding: EdgeInsets.symmetric(horizontal: 4),
                                                                                                                        child: SizedBox(
                                                                                                                                width: 16,
                                                                                                                                height: 16,
                                                                                                                                child: CircularProgressIndicator(
                                                                                                                                        strokeWidth: 2,
                                                                                                                                        color: ParishColors.marianBlue,
                                                                                                                                ),
                                                                                                                        ),
                                                                                                                )
                                                                                                        else if (isSearchActive)
                                                                                                                IconButton(
                                                                                                                        icon: const Icon(Icons.clear, size: 17),
                                                                                                                        padding: EdgeInsets.zero,
                                                                                                                        constraints: const BoxConstraints(),
                                                                                                                        onPressed: () {
                                                                                                                                _searchController.clear();
                                                                                                                                setState(() {
                                                                                                                                        _searchResults = [];
                                                                                                                                        _isSearching = false;
                                                                                                                                        _currentPage = 1;
                                                                                                                                });
                                                                                                                        },
                                                                                                                ),
                                                                                                ],
                                                                                        ),
                                                                                ),
                                                                                const SizedBox(height: 24),

                                                                                // 5. Dynamic Section Switcher: Search Results vs Canonical Registers Grid
                                                                                if (_isSearching)
                                                                                        _buildSkeletonLoading()
                                                                                else if (isSearchActive) ...[
                                                                                        // Search Results Header & Filter Bar
                                                                                        Row(
                                                                                                children: [
                                                                                                        InkWell(
                                                                                                                onTap: _openFilterAndSortBottomSheet,
                                                                                                                borderRadius: BorderRadius.circular(8),
                                                                                                                child: Container(
                                                                                                                        height: 36,
                                                                                                                        padding: const EdgeInsets.symmetric(horizontal: 12),
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
                                                                                                                                                size: 16,
                                                                                                                                                color: _hasActiveFilters ? ParishColors.marianBlue : ParishColors.textMuted,
                                                                                                                                        ),
                                                                                                                                        const SizedBox(width: 6),
                                                                                                                                        Text(
                                                                                                                                                _hasActiveFilters
                                                                                                                                                    ? 'Filter & Sort ($_activeFilterCount)'
                                                                                                                                                    : 'Filter & Sort',
                                                                                                                                                style: TextStyle(
                                                                                                                                                        fontSize: 12,
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
                                                                                                                '${_filteredSearchResults.length} matches found',
                                                                                                                style: TextStyle(
                                                                                                                        fontSize: 12,
                                                                                                                        fontWeight: FontWeight.w600,
                                                                                                                        color: ParishColors.textMuted,
                                                                                                                ),
                                                                                                        ),
                                                                                                        const SizedBox(width: 12),
                                                                                                        Container(
                                                                                                                height: 32,
                                                                                                                decoration: BoxDecoration(
                                                                                                                        color: cardWhiteColor,
                                                                                                                        borderRadius: BorderRadius.circular(8),
                                                                                                                        border: Border.all(color: borderGreyColor),
                                                                                                                ),
                                                                                                                child: ToggleButtons(
                                                                                                                        isSelected: [
                                                                                                                                _viewMode == RecordsViewDisplayMode.cards,
                                                                                                                                _viewMode == RecordsViewDisplayMode.table,
                                                                                                                        ],
                                                                                                                        onPressed: (idx) => setState(() {
                                                                                                                                _viewMode = idx == 0 ? RecordsViewDisplayMode.cards : RecordsViewDisplayMode.table;
                                                                                                                        }),
                                                                                                                        borderRadius: BorderRadius.circular(7),
                                                                                                                        selectedColor: Colors.white,
                                                                                                                        fillColor: ParishColors.marianBlue,
                                                                                                                        color: ParishColors.textMuted,
                                                                                                                        constraints: const BoxConstraints(minHeight: 30, minWidth: 36),
                                                                                                                        children: const [
                                                                                                                                Tooltip(message: 'Card View', child: Icon(Icons.grid_view, size: 16)),
                                                                                                                                Tooltip(message: 'Table View', child: Icon(Icons.table_chart, size: 16)),
                                                                                                                        ],
                                                                                                                ),
                                                                                                        ),
                                                                                                ],
                                                                                        ),
                                                                                        const SizedBox(height: 14),
                                                                                        _buildUniversalSearchResultsView(constraints.maxWidth),
                                                                                ] else ...[
                                                                                        // Standard Canonical Registers Section Title
                                                                                        Text(
                                                                                                'Canonical Registers',
                                                                                                style: TextStyle(
                                                                                                        fontSize: 18,
                                                                                                        fontWeight: FontWeight.bold,
                                                                                                        color: textDarkColor,
                                                                                                ),
                                                                                        ),
                                                                                        const SizedBox(height: 3),
                                                                                        Text(
                                                                                                'Open a book to browse, filter, and issue certificates.',
                                                                                                style: TextStyle(
                                                                                                        fontSize: 13,
                                                                                                        color: ParishColors.textMuted,
                                                                                                ),
                                                                                        ),
                                                                                        const SizedBox(height: 16),

                                                                                        // Responsive Grid of 6 Canonical Registers
                                                                                        _buildCanonicalRegistersGrid(isDesktop, isTablet),
                                                                                ],

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
        // Canonical Registers 6-Card Grid
        // ===========================================================================

        Widget _buildCanonicalRegistersGrid(bool isDesktop, bool isTablet) {
                final int crossAxisCount = isDesktop ? 3 : (isTablet ? 2 : 1);

                final registerCards = [
                        _buildRegisterCard(
                                title: 'Baptism',
                                latinTitle: 'Liber Baptismorum',
                                description: 'Baptisms, lineage & godparents',
                                count: _baptismCount,
                                icon: Icons.water_drop_outlined,
                                themeColor: const Color(0xFF164E87),
                                surfaceColor: const Color(0xFFEDF4FB),
                                sacramentName: 'Baptism',
                                onQuickAdd: () {
                                        Navigator.push(
                                                context,
                                                MaterialPageRoute(builder: (_) => BaptismManualEntryPage(onRecordSaved: _loadSummaryStats)),
                                        );
                                },
                        ),
                        _buildRegisterCard(
                                title: 'Confirmation',
                                latinTitle: 'Liber Confirmatorum',
                                description: 'Confirmands & sponsors',
                                count: _confirmationCount,
                                icon: Icons.local_fire_department_outlined,
                                themeColor: const Color(0xFFB91C1C),
                                surfaceColor: const Color(0xFFFDF2F2),
                                sacramentName: 'Confirmation',
                                onQuickAdd: () {
                                        Navigator.push(
                                                context,
                                                MaterialPageRoute(builder: (_) => ConfirmationManualEntryPage(onRecordSaved: _loadSummaryStats)),
                                        );
                                },
                        ),
                        _buildRegisterCard(
                                title: 'First Communion',
                                latinTitle: 'Liber Primae Communionis',
                                description: 'Annual batch registries',
                                count: _communionCount,
                                icon: Icons.restaurant,
                                themeColor: const Color(0xFFD49B18),
                                surfaceColor: const Color(0xFFFFF7E6),
                                sacramentName: 'First Communion',
                                onQuickAdd: () {
                                        Navigator.push(
                                                context,
                                                MaterialPageRoute(builder: (_) => FirstCommunionManualEntryPage(onRecordSaved: _loadSummaryStats)),
                                        );
                                },
                        ),
                        _buildRegisterCard(
                                title: 'Matrimony',
                                latinTitle: 'Liber Matrimoniorum',
                                description: 'Spouses, license & banns',
                                count: _matrimonyCount,
                                icon: Icons.favorite_border,
                                themeColor: const Color(0xFF9D174D),
                                surfaceColor: const Color(0xFFFCE7F3),
                                sacramentName: 'Matrimony',
                                onQuickAdd: () {
                                        Navigator.push(
                                                context,
                                                MaterialPageRoute(builder: (_) => MatrimonyManualEntryPage(onRecordSaved: _loadSummaryStats)),
                                        );
                                },
                        ),
                        _buildRegisterCard(
                                title: 'Death & Burial',
                                latinTitle: 'Liber Defunctorum',
                                description: 'Deceased, burial & rites',
                                count: _deathCount,
                                icon: Icons.church_outlined,
                                themeColor: const Color(0xFF6B21A8),
                                surfaceColor: const Color(0xFFF3E8FF),
                                sacramentName: 'Death',
                                onQuickAdd: () {
                                        Navigator.push(
                                                context,
                                                MaterialPageRoute(builder: (_) => DeathManualEntryPage(onRecordSaved: _loadSummaryStats)),
                                        );
                                },
                        ),
                        _buildRegisterCard(
                                title: 'Conversion',
                                latinTitle: 'Liber Conversorum',
                                description: 'Reception into full communion',
                                count: _conversionCount,
                                icon: Icons.eco_outlined,
                                themeColor: const Color(0xFF2D6A4F),
                                surfaceColor: const Color(0xFFEDF7F2),
                                sacramentName: 'Conversion',
                                onQuickAdd: () {
                                        Navigator.push(
                                                context,
                                                MaterialPageRoute(builder: (_) => ConversionManualEntryPage(onRecordSaved: _loadSummaryStats)),
                                        );
                                },
                        ),
                ];

                if (crossAxisCount == 1) {
                        return Column(
                                children: registerCards.map((c) => Padding(padding: const EdgeInsets.only(bottom: 12), child: c)).toList(),
                        );
                }

                return LayoutBuilder(
                        builder: (context, gridConstraints) {
                                final double itemWidth = (gridConstraints.maxWidth - ((crossAxisCount - 1) * 16)) / crossAxisCount;

                                return Wrap(
                                        spacing: 16,
                                        runSpacing: 16,
                                        children: registerCards.map((card) {
                                                return SizedBox(
                                                        width: itemWidth,
                                                        child: card,
                                                );
                                        }).toList(),
                                );
                        },
                );
        }

        Widget _buildRegisterCard({
                required String title,
                required String latinTitle,
                required String description,
                required int count,
                required IconData icon,
                required Color themeColor,
                required Color surfaceColor,
                required String sacramentName,
                required VoidCallback onQuickAdd,
        }) {
                final textDark = ParishColors.textDark;
                final textMuted = ParishColors.textMuted;

                return Container(
                        decoration: BoxDecoration(
                                color: ParishColors.cardWhite,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: themeColor.withOpacity(0.35), width: 1.2),
                                boxShadow: [
                                        BoxShadow(
                                                color: themeColor.withOpacity(0.04),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                        ),
                                ],
                        ),
                        child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                        borderRadius: BorderRadius.circular(16),
                                        onTap: () {
                                                Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                                builder: (_) => SacramentRegistryPage(
                                                                        sacramentName: sacramentName,
                                                                        ledgerSubtitle: '$latinTitle • Canonical Books',
                                                                        icon: icon,
                                                                        themeColor: themeColor,
                                                                        surfaceColor: surfaceColor,
                                                                ),
                                                        ),
                                                ).then((_) => _loadSummaryStats());
                                        },
                                        child: Padding(
                                                padding: const EdgeInsets.all(18),
                                                child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                                // Top Row: Sacrament Icon & Count Tally
                                                                Row(
                                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                                        children: [
                                                                                Container(
                                                                                        width: 44,
                                                                                        height: 44,
                                                                                        decoration: BoxDecoration(
                                                                                                color: surfaceColor,
                                                                                                borderRadius: BorderRadius.circular(12),
                                                                                                border: Border.all(color: themeColor.withOpacity(0.25), width: 1.0),
                                                                                        ),
                                                                                        child: Icon(icon, color: themeColor, size: 22),
                                                                                ),
                                                                                Column(
                                                                                        crossAxisAlignment: CrossAxisAlignment.end,
                                                                                        children: [
                                                                                                Text(
                                                                                                        '$count',
                                                                                                        style: TextStyle(
                                                                                                                fontSize: 22,
                                                                                                                fontWeight: FontWeight.bold,
                                                                                                                color: themeColor,
                                                                                                                height: 1.1,
                                                                                                        ),
                                                                                                ),
                                                                                                Text(
                                                                                                        'records',
                                                                                                        style: TextStyle(fontSize: 11, color: textMuted),
                                                                                                ),
                                                                                        ],
                                                                                ),
                                                                        ],
                                                                ),
                                                                const SizedBox(height: 14),

                                                                // Title & Subtitle Nomenclature
                                                                Text(
                                                                        title,
                                                                        style: TextStyle(
                                                                                fontSize: 16.5,
                                                                                fontWeight: FontWeight.bold,
                                                                                color: textDark,
                                                                        ),
                                                                ),
                                                                const SizedBox(height: 2),
                                                                Text(
                                                                        latinTitle,
                                                                        style: TextStyle(
                                                                                fontSize: 12,
                                                                                fontStyle: FontStyle.italic,
                                                                                color: textMuted,
                                                                        ),
                                                                ),
                                                                const SizedBox(height: 4),
                                                                Text(
                                                                        description,
                                                                        style: TextStyle(
                                                                                fontSize: 12,
                                                                                color: textDark.withOpacity(0.8),
                                                                        ),
                                                                        maxLines: 1,
                                                                        overflow: TextOverflow.ellipsis,
                                                                ),
                                                                const SizedBox(height: 16),

                                                                // Bottom Row: "Open register ->" and Quick Add (+) Button
                                                                Row(
                                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                        children: [
                                                                                Row(
                                                                                        children: [
                                                                                                Text(
                                                                                                        'Open register',
                                                                                                        style: TextStyle(
                                                                                                                fontSize: 12.5,
                                                                                                                fontWeight: FontWeight.bold,
                                                                                                                color: themeColor,
                                                                                                        ),
                                                                                                ),
                                                                                                const SizedBox(width: 4),
                                                                                                Icon(Icons.arrow_forward, size: 14, color: themeColor),
                                                                                        ],
                                                                                ),
                                                                                IconButton(
                                                                                        icon: Icon(Icons.add_circle_outline, color: themeColor, size: 22),
                                                                                        padding: EdgeInsets.zero,
                                                                                        constraints: const BoxConstraints(),
                                                                                        tooltip: 'Encode $title Record',
                                                                                        onPressed: onQuickAdd,
                                                                                ),
                                                                        ],
                                                                ),
                                                        ],
                                                ),
                                        ),
                                ),
                        ),
                );
        }

        // ===========================================================================
        // Search Results Display (Cards vs Table)
        // ===========================================================================

        Widget _buildUniversalSearchResultsView(double availableWidth) {
                final list = _filteredSearchResults;
                final totalItems = list.length;
                final start = (_currentPage - 1) * _itemsPerPage;
                final end = min(start + _itemsPerPage, totalItems);
                final paged = (start >= totalItems) ? <UniversalRecordResult>[] : list.sublist(start, end);

                if (list.isEmpty) {
                        return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(36),
                                decoration: BoxDecoration(
                                        color: ParishColors.cardWhite,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: ParishColors.borderGrey),
                                ),
                                child: Column(
                                        children: [
                                                Icon(Icons.search_off_outlined, size: 44, color: ParishColors.textMuted),
                                                const SizedBox(height: 10),
                                                Text(
                                                        'No canonical records match your search criteria.',
                                                        textAlign: TextAlign.center,
                                                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                        'Try adjusting your search query, clearing filters, or opening a specific register above.',
                                                        textAlign: TextAlign.center,
                                                        style: TextStyle(fontSize: 12, color: ParishColors.textMuted),
                                                ),
                                        ],
                                ),
                        );
                }

                return Column(
                        children: [
                                if (_viewMode == RecordsViewDisplayMode.cards)
                                        ...paged.map((r) => _buildUniversalRecordCard(r))
                                else
                                        _buildUniversalRecordsTableView(paged, availableWidth),
                                const SizedBox(height: 14),
                                _buildPaginationToolbar(totalItems),
                        ],
                );
        }

        Widget _buildUniversalRecordCard(UniversalRecordResult item) {
                return InkWell(
                        onTap: () => _navigateToDetail(item),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                        color: ParishColors.cardWhite,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: item.themeColor.withOpacity(0.35), width: 1.2),
                                        boxShadow: [
                                                BoxShadow(
                                                        color: item.themeColor.withOpacity(0.04),
                                                        blurRadius: 6,
                                                        offset: const Offset(0, 2),
                                                ),
                                        ],
                                ),
                                child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                                Container(
                                                        padding: const EdgeInsets.all(10),
                                                        decoration: BoxDecoration(
                                                                color: item.surfaceColor,
                                                                borderRadius: BorderRadius.circular(10),
                                                        ),
                                                        child: Icon(item.icon, color: item.themeColor, size: 22),
                                                ),
                                                const SizedBox(width: 12),

                                                Expanded(
                                                        child: Column(
                                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                                children: [
                                                                        Row(
                                                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                children: [
                                                                                        Container(
                                                                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                                                                decoration: BoxDecoration(
                                                                                                        color: item.surfaceColor,
                                                                                                        borderRadius: BorderRadius.circular(5),
                                                                                                        border: Border.all(color: item.themeColor.withOpacity(0.4)),
                                                                                                ),
                                                                                                child: Text(
                                                                                                        item.sacramentName.toUpperCase(),
                                                                                                        style: TextStyle(
                                                                                                                fontSize: 9.5,
                                                                                                                fontWeight: FontWeight.bold,
                                                                                                                color: item.themeColor,
                                                                                                                letterSpacing: 0.5,
                                                                                                        ),
                                                                                                ),
                                                                                        ),
                                                                                        Text(
                                                                                                item.bookRef,
                                                                                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ParishColors.textMuted),
                                                                                        ),
                                                                                ],
                                                                        ),
                                                                        const SizedBox(height: 5),

                                                                        Text(
                                                                                item.name,
                                                                                style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                                                                        ),
                                                                        const SizedBox(height: 2),

                                                                        Text(
                                                                                item.parentage,
                                                                                style: TextStyle(fontSize: 12, color: ParishColors.textDark.withOpacity(0.85)),
                                                                                maxLines: 1,
                                                                                overflow: TextOverflow.ellipsis,
                                                                        ),
                                                                        const SizedBox(height: 4),

                                                                        Row(
                                                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                children: [
                                                                                        Text(
                                                                                                item.dateString,
                                                                                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: item.themeColor),
                                                                                        ),
                                                                                        Row(
                                                                                                children: [
                                                                                                        Text('Inspect', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: item.themeColor)),
                                                                                                        const SizedBox(width: 2),
                                                                                                        Icon(Icons.arrow_forward, size: 13, color: item.themeColor),
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
        }

        Widget _buildUniversalRecordsTableView(List<UniversalRecordResult> items, double availableWidth) {
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
                                                        headingTextStyle: TextStyle(
                                                                fontWeight: FontWeight.bold,
                                                                color: ParishColors.marianBlue,
                                                                fontSize: 12.5,
                                                        ),
                                                        dataTextStyle: TextStyle(fontSize: 12.5, color: ParishColors.textDark),
                                                        columnSpacing: 16,
                                                        horizontalMargin: 14,
                                                        columns: const [
                                                                DataColumn(label: Text('Sacrament')),
                                                                DataColumn(label: Text('Record ID')),
                                                                DataColumn(label: Text('Primary Name')),
                                                                DataColumn(label: Text('Canonical Reference')),
                                                                DataColumn(label: Text('Date / Timeline')),
                                                                DataColumn(label: Text('Parentage / Lineage')),
                                                                DataColumn(label: Text('Action')),
                                                        ],
                                                        rows: items.map((r) {
                                                                return DataRow(cells: [
                                                                        DataCell(Container(
                                                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                                                decoration: BoxDecoration(
                                                                                        color: r.surfaceColor,
                                                                                        borderRadius: BorderRadius.circular(4),
                                                                                        border: Border.all(color: r.themeColor.withOpacity(0.4)),
                                                                                ),
                                                                                child: Text(
                                                                                        r.sacramentName.toUpperCase(),
                                                                                        style: TextStyle(
                                                                                                fontSize: 9.5,
                                                                                                fontWeight: FontWeight.bold,
                                                                                                color: r.themeColor,
                                                                                        ),
                                                                                ),
                                                                        )),
                                                                        DataCell(Text(r.recordId, style: const TextStyle(fontWeight: FontWeight.bold))),
                                                                        DataCell(Text(r.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                                                                        DataCell(Text(r.bookRef)),
                                                                        DataCell(Text(r.dateString)),
                                                                        DataCell(ConstrainedBox(
                                                                                constraints: const BoxConstraints(maxWidth: 220),
                                                                                child: Text(r.parentage, maxLines: 1, overflow: TextOverflow.ellipsis),
                                                                        )),
                                                                        DataCell(
                                                                                TextButton.icon(
                                                                                        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                                                                        onPressed: () => _navigateToDetail(r),
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
        // Pagination Toolbar
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