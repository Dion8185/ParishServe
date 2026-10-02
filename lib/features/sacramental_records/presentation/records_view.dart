// =============================================================================
// FILE: lib/features/sacramental_records/presentation/records_view.dart
// =============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/colors.dart';
import '../models/baptism_record_model.dart';
import '../models/confirmation_record_model.dart';
import '../models/conversion_record_model.dart';
import '../models/death_record_model.dart';
import '../models/first_communion_record_model.dart';
import '../models/matrimony_record_model.dart';
import 'dialogs/ocr_scan_dialog.dart';
import 'dialogs/pabuklat_requests_modal.dart';
import 'pages/baptism_manual_entry_page.dart';
import 'pages/certificate_template_management_page.dart';
import 'pages/confirmation_manual_entry_page.dart';
import 'pages/conversion_manual_entry_page.dart';
import 'pages/death_manual_entry_page.dart';
import 'pages/first_communion_manual_entry_page.dart';
import 'pages/matrimony_manual_entry_page.dart';
import 'pages/sacrament_record_detail_page.dart';
import 'pages/sacrament_registry_page.dart';

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
  });
}

class SacramentalRecordsView extends StatefulWidget {
  const SacramentalRecordsView({super.key});

  @override
  State<SacramentalRecordsView> createState() => _SacramentalRecordsViewState();
}

class _SacramentalRecordsViewState extends State<SacramentalRecordsView> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounceTimer;

  bool _isSearching = false;
  List<UniversalRecordResult> _suggestions = [];
  String _selectedFilter = 'All';

  final List<String> _sacramentFilters = [
    'All',
    'Baptism',
    'Confirmation',
    'First Communion',
    'Matrimony',
    'Death',
    'Conversion',
  ];

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();

    if (query.trim().isEmpty) {
      setState(() {
        _suggestions = [];
        _isSearching = false;
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

      setState(() {
        _suggestions = combined;
        _isSearching = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<List<UniversalRecordResult>> _searchBaptisms(String q) async {
    try {
      final response = await Supabase.instance.client
          .from('baptism_records')
          .select()
          .or('child_first_name.ilike.%$q%,child_last_name.ilike.%$q%,father_first_name.ilike.%$q%,father_last_name.ilike.%$q%,mother_first_name.ilike.%$q%,mother_maiden_last_name.ilike.%$q%,record_id.ilike.%$q%,book_number.ilike.%$q%')
          .order('date_of_baptism', ascending: false)
          .limit(6);

      return (response as List).map((row) {
        final model = BaptismRecordModel.fromMap(row as Map<String, dynamic>);
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
          icon: Icons.water_drop,
          rawRecordData: model.toMap(),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<UniversalRecordResult>> _searchConfirmations(String q) async {
    try {
      final response = await Supabase.instance.client
          .from('confirmation_records')
          .select()
          .or('confirmand_first_name.ilike.%$q%,confirmand_last_name.ilike.%$q%,father_first_name.ilike.%$q%,father_last_name.ilike.%$q%,mother_first_name.ilike.%$q%,mother_maiden_last_name.ilike.%$q%,record_id.ilike.%$q%,church_baptized.ilike.%$q%')
          .order('date_of_confirmation', ascending: false)
          .limit(6);

      return (response as List).map((row) {
        final model = ConfirmationRecordModel.fromMap(row as Map<String, dynamic>);
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
          icon: Icons.local_fire_department,
          rawRecordData: model.toMap(),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<UniversalRecordResult>> _searchCommunions(String q) async {
    try {
      final response = await Supabase.instance.client
          .from('first_communion_records')
          .select()
          .or('communicant_first_name.ilike.%$q%,communicant_last_name.ilike.%$q%,control_number.ilike.%$q%,record_id.ilike.%$q%,baptism_parish.ilike.%$q%')
          .order('date_of_communion', ascending: false)
          .limit(6);

      return (response as List).map((row) {
        final model = FirstCommunionRecordModel.fromMap(row as Map<String, dynamic>);
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
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<UniversalRecordResult>> _searchMatrimonies(String q) async {
    try {
      final response = await Supabase.instance.client
          .from('matrimony_records')
          .select()
          .or('groom_first_name.ilike.%$q%,groom_last_name.ilike.%$q%,bride_first_name.ilike.%$q%,bride_last_name.ilike.%$q%,record_id.ilike.%$q%,marriage_license_no.ilike.%$q%')
          .order('date_of_marriage', ascending: false)
          .limit(6);

      return (response as List).map((row) {
        final model = MatrimonyRecordModel.fromMap(row as Map<String, dynamic>);
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
          icon: Icons.favorite,
          rawRecordData: model.toMap(),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<UniversalRecordResult>> _searchDeaths(String q) async {
    try {
      final response = await Supabase.instance.client
          .from('death_records')
          .select()
          .or('deceased_first_name.ilike.%$q%,deceased_last_name.ilike.%$q%,place_of_burial.ilike.%$q%,record_id.ilike.%$q%,cause_of_death.ilike.%$q%')
          .order('date_of_burial', ascending: false)
          .limit(6);

      return (response as List).map((row) {
        final model = DeathRecordModel.fromMap(row as Map<String, dynamic>);
        final spouseOrParents = model.spouseFullName != '—' ? 'Spouse: ${model.spouseFullName}' : 'Parents: ${model.parentsFullName}';
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
          icon: Icons.church,
          rawRecordData: model.toMap(),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<UniversalRecordResult>> _searchConversions(String q) async {
    try {
      final response = await Supabase.instance.client
          .from('conversion_records')
          .select()
          .or('convert_first_name.ilike.%$q%,convert_last_name.ilike.%$q%,record_id.ilike.%$q%,prior_baptism_church.ilike.%$q%')
          .order('date_of_reception', ascending: false)
          .limit(6);

      return (response as List).map((row) {
        final model = ConversionRecordModel.fromMap(row as Map<String, dynamic>);
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
          icon: Icons.eco,
          rawRecordData: model.toMap(),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  List<UniversalRecordResult> get _filteredSuggestions {
    if (_selectedFilter == 'All') return _suggestions;
    return _suggestions.where((s) => s.sacramentName.toLowerCase() == _selectedFilter.toLowerCase()).toList();
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
            if (_searchController.text.trim().isNotEmpty) {
              _performUniversalSearch(_searchController.text.trim());
            }
          },
        ),
      ),
    );
  }

  void _showNewRecordSelector(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
              child: const Icon(Icons.post_add, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Canonical Register',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                  ),
                  Text(
                    'Choose the register to encode a new entry',
                    style: TextStyle(fontSize: 11.5, color: ParishColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSacramentPickerTile(
                  ctx: ctx,
                  title: 'Baptism Register (Liber Baptismorum)',
                  subtitle: 'Baptisms, lineages, and initial godparents',
                  icon: Icons.water_drop,
                  color: const Color(0xFF164E87),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const BaptismManualEntryPage()));
                  },
                ),
                _buildSacramentPickerTile(
                  ctx: ctx,
                  title: 'Confirmation Register (Liber Confirmatorum)',
                  subtitle: 'Confirmands, chrismation dates, and sponsors',
                  icon: Icons.local_fire_department,
                  color: const Color(0xFFB91C1C),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ConfirmationManualEntryPage()));
                  },
                ),
                _buildSacramentPickerTile(
                  ctx: ctx,
                  title: 'First Communion (Liber Primae Communionis)',
                  subtitle: 'Annual batch control registries and parishes',
                  icon: Icons.restaurant,
                  color: const Color(0xFFD49B18),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const FirstCommunionManualEntryPage()));
                  },
                ),
                _buildSacramentPickerTile(
                  ctx: ctx,
                  title: 'Matrimony Register (Liber Matrimoniorum)',
                  subtitle: 'Spouses, marriage license, and canonical banns',
                  icon: Icons.favorite,
                  color: const Color(0xFF9D174D),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const MatrimonyManualEntryPage()));
                  },
                ),
                _buildSacramentPickerTile(
                  ctx: ctx,
                  title: 'Death & Burial (Liber Defunctorum)',
                  subtitle: 'Deceased, cemetery locations, and funeral rites',
                  icon: Icons.church,
                  color: const Color(0xFF6B21A8),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const DeathManualEntryPage()));
                  },
                ),
                _buildSacramentPickerTile(
                  ctx: ctx,
                  title: 'Conversion (Liber Conversorum)',
                  subtitle: 'Reception into full Catholic communion & witnesses',
                  icon: Icons.eco,
                  color: const Color(0xFF2D6A4F),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ConversionManualEntryPage()));
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: ParishColors.textMuted)),
          ),
        ],
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
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
                    Text(subtitle, style: TextStyle(fontSize: 11.5, color: ParishColors.textMuted)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: color),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardWhiteColor = ParishColors.cardWhite;
    final textDarkColor = ParishColors.textDark;
    final textMutedColor = ParishColors.textMuted;
    final marianBlueColor = ParishColors.marianBlue;
    final isSearchActive = _searchController.text.trim().isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Page Title & Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sacramental Records',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textDarkColor),
                    ),
                    Text(
                      'Select a sacramental register or search canonical entries across all books',
                      style: TextStyle(color: textMutedColor),
                    ),
                  ],
                ),
              ),
              // Secretary Shortcut to Review Pabuklat Requests
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ParishColors.oliveGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => showPabuklatRequestsModal(context),
                icon: const Icon(Icons.folder_shared, size: 18),
                label: const Text('Pabuklat Requests', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // QUICK ACTION BUTTONS
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              return isWide
                  ? Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ParishColors.marianBlue,
                          foregroundColor: Colors.white,
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => _showNewRecordSelector(context),
                        icon: const Icon(Icons.post_add, size: 20),
                        label: const Text(
                          '+ Encode Canonical Record',
                          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                        ),
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
                          side: const BorderSide(color: ParishColors.marianBlue, width: 1.5),
                          foregroundColor: ParishColors.marianBlue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => showOcrScanModal(context),
                        icon: const Icon(Icons.document_scanner, size: 18),
                        label: const Text(
                          'AI OCR Ledger Scan',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                        ),
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
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const CertificateTemplateManagementPage()),
                          );
                        },
                        icon: const Icon(Icons.design_services_outlined, size: 18),
                        label: const Text(
                          'Certificate Studio',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                        ),
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
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _showNewRecordSelector(context),
                      icon: const Icon(Icons.post_add, size: 18),
                      label: const Text(
                        '+ Encode Canonical Record',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: ParishColors.marianBlue, width: 1.5),
                              foregroundColor: ParishColors.marianBlue,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => showOcrScanModal(context),
                            icon: const Icon(Icons.document_scanner, size: 16),
                            label: const Text('AI OCR Scan', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: ParishColors.goldAccent, width: 1.5),
                              foregroundColor: ParishColors.goldAccent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const CertificateTemplateManagementPage()),
                              );
                            },
                            icon: const Icon(Icons.design_services_outlined, size: 16),
                            label: const Text('Templates', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),

          // Universal Search Bar
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: cardWhiteColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSearchActive ? marianBlueColor : ParishColors.borderGrey,
                width: isSearchActive ? 2.0 : 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.search, size: 24, color: marianBlueColor),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: _onSearchChanged,
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: textDarkColor),
                    decoration: InputDecoration(
                      hintText: 'Search by Name, Year, Book, or Reference across all registers...',
                      hintStyle: TextStyle(fontSize: 13, color: textMutedColor),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                if (_isSearching)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: ParishColors.marianBlue),
                  )
                else if (isSearchActive)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    tooltip: 'Clear Search',
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _suggestions = [];
                        _isSearching = false;
                      });
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          if (isSearchActive) ...[
            _buildUniversalSearchResultsPanel(textDarkColor, textMutedColor, cardWhiteColor)
          ] else ...[
            _buildCanonicalLedgersGrid(context, textDarkColor, textMutedColor)
          ],
        ],
      ),
    );
  }

  Widget _buildUniversalSearchResultsPanel(Color textDark, Color textMuted, Color cardWhite) {
    final results = _filteredSuggestions;
    final totalCount = _suggestions.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _sacramentFilters.map((filter) {
              final isSelected = _selectedFilter == filter;
              int count;
              if (filter == 'All') {
                count = totalCount;
              } else {
                count = _suggestions.where((s) => s.sacramentName.toLowerCase() == filter.toLowerCase()).length;
              }

              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text('$filter ($count)'),
                  selected: isSelected,
                  selectedColor: ParishColors.marianBlue,
                  backgroundColor: cardWhite,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.white : textDark,
                  ),
                  onSelected: (_) => setState(() => _selectedFilter = filter),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Search Suggestions (${results.length})',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDark),
            ),
            if (results.isNotEmpty)
              Text(
                'Tap record to view details & certificate',
                style: TextStyle(fontSize: 11.5, color: textMuted),
              ),
          ],
        ),
        const SizedBox(height: 10),

        if (_isSearching)
          Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            child: const Column(
              children: [
                CircularProgressIndicator(strokeWidth: 2.5, color: ParishColors.marianBlue),
                SizedBox(height: 12),
                Text('Searching canonical registers in real-time...', style: TextStyle(fontSize: 13, color: Colors.grey)),
              ],
            ),
          )
        else if (results.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(36),
            decoration: BoxDecoration(
              color: cardWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ParishColors.borderGrey),
            ),
            child: Column(
              children: [
                Icon(Icons.search_off_outlined, size: 48, color: textMuted),
                const SizedBox(height: 10),
                Text(
                  'No matching canonical records found.',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textDark),
                ),
                const SizedBox(height: 4),
                Text(
                  'Check for spelling variations or browse specific ledger books below.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: textMuted),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: results.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = results[index];
              return _buildSuggestionTile(item, textDark, textMuted, cardWhite);
            },
          ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildSuggestionTile(UniversalRecordResult item, Color textDark, Color textMuted, Color cardWhite) {
    return InkWell(
      onTap: () => _navigateToDetail(item),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardWhite,
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
              child: Icon(item.icon, color: item.themeColor, size: 24),
            ),
            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: item.surfaceColor,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: item.themeColor.withOpacity(0.4)),
                        ),
                        child: Text(
                          item.sacramentName.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: item.themeColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Text(
                        item.bookRef,
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  Text(
                    item.name,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDark),
                  ),
                  const SizedBox(height: 2),

                  Text(
                    item.parentage,
                    style: TextStyle(fontSize: 12.5, color: textDark.withOpacity(0.85)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.dateString,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: item.themeColor),
                      ),
                      Row(
                        children: [
                          Text('Inspect', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: item.themeColor)),
                          const SizedBox(width: 2),
                          Icon(Icons.arrow_forward, size: 14, color: item.themeColor),
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

  Widget _buildCanonicalLedgersGrid(BuildContext context, Color textDarkColor, Color textMutedColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Canonical Register Ledgers',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDarkColor),
        ),
        const SizedBox(height: 14),

        _buildSacramentSelectionCard(
          context: context,
          title: 'Baptism Records',
          subtitle: 'Liber Baptismorum • Books 1 to 14',
          icon: Icons.water_drop,
          themeColor: const Color(0xFF164E87),
          surfaceColor: const Color(0xFFEDF4FB),
          sacramentName: 'Baptism',
          ledgerSubtitle: 'Liber Baptismorum • Canonical Books',
        ),
        _buildSacramentSelectionCard(
          context: context,
          title: 'Confirmation Records',
          subtitle: 'Liber Confirmatorum • Books 1 to 6',
          icon: Icons.local_fire_department,
          themeColor: const Color(0xFFB91C1C),
          surfaceColor: const Color(0xFFFDF2F2),
          sacramentName: 'Confirmation',
          ledgerSubtitle: 'Liber Confirmatorum • Canonical Books',
        ),
        _buildSacramentSelectionCard(
          context: context,
          title: 'First Communion Records',
          subtitle: 'Liber Primae Communionis • Annual Control Registries',
          icon: Icons.restaurant,
          themeColor: const Color(0xFFD49B18),
          surfaceColor: const Color(0xFFFFF7E6),
          sacramentName: 'First Communion',
          ledgerSubtitle: 'Liber Primae Communionis • Canonical Books',
        ),
        _buildSacramentSelectionCard(
          context: context,
          title: 'Matrimony Records',
          subtitle: 'Liber Matrimoniorum • Books 1 to 8',
          icon: Icons.favorite,
          themeColor: const Color(0xFF9D174D),
          surfaceColor: const Color(0xFFFCE7F3),
          sacramentName: 'Matrimony',
          ledgerSubtitle: 'Liber Matrimoniorum • Canonical Books',
        ),
        _buildSacramentSelectionCard(
          context: context,
          title: 'Death & Burial Records',
          subtitle: 'Liber Defunctorum • Books 1 to 7',
          icon: Icons.church,
          themeColor: const Color(0xFF6B21A8),
          surfaceColor: const Color(0xFFF3E8FF),
          sacramentName: 'Death',
          ledgerSubtitle: 'Liber Defunctorum • Canonical Books',
        ),
        _buildSacramentSelectionCard(
          context: context,
          title: 'Conversion Records',
          subtitle: 'Liber Conversorum • Reception into Full Communion',
          icon: Icons.eco,
          themeColor: const Color(0xFF2D6A4F),
          surfaceColor: const Color(0xFFEDF7F2),
          sacramentName: 'Conversion',
          ledgerSubtitle: 'Liber Conversorum • Reception into Full Communion',
        ),
      ],
    );
  }

  Widget _buildSacramentSelectionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color themeColor,
    required Color surfaceColor,
    required String sacramentName,
    required String ledgerSubtitle,
  }) {
    final cardWhiteColor = ParishColors.cardWhite;
    final textDarkColor = ParishColors.textDark;
    final textMutedColor = ParishColors.textMuted;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SacramentRegistryPage(
                sacramentName: sacramentName,
                ledgerSubtitle: ledgerSubtitle,
                icon: icon,
                themeColor: themeColor,
                surfaceColor: surfaceColor,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardWhiteColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: themeColor.withOpacity(0.35), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: themeColor.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: themeColor.withOpacity(0.5), width: 1.2),
                ),
                child: Icon(icon, color: themeColor, size: 28),
              ),
              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: textDarkColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 13, color: textMutedColor),
                    ),
                  ],
                ),
              ),

              Icon(Icons.arrow_forward_ios, size: 18, color: themeColor),
            ],
          ),
        ),
      ),
    );
  }
}