// =============================================================================
// FILE: lib/features/sacramental_records/presentation/pages/certificate_template_management_page.dart
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/database/local_database_service.dart';
import '../../../../core/services/records_sync_service.dart';
import '../../../sacramental_records/models/certificate_canvas_element.dart';
import '../../../sacramental_records/services/certificate_service.dart';
import '../../models/certificate_style_config.dart';
import '../../models/certificate_template_model.dart';
import '../../services/certificate_pdf_generator.dart';
import '../../utils/placeholder_registry.dart';
import 'certificate_canvas_designer_page.dart';
import 'certificate_template_editor_page.dart';

enum TemplateViewDisplayMode { cards, table }

class CertificateTemplateManagementPage extends StatefulWidget {
  const CertificateTemplateManagementPage({super.key});

  @override
  State<CertificateTemplateManagementPage> createState() =>
      _CertificateTemplateManagementPageState();
}

class _CertificateTemplateManagementPageState
    extends State<CertificateTemplateManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _sacramentTabs = [
    'All',
    'Baptism',
    'Confirmation',
    'First Communion',
    'Matrimony',
    'Death',
    'Conversion',
  ];

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounceTimer;

  List<CertificateTemplateModel> _allTemplates = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isLoadedFromSqlite = false;
  String _searchQuery = '';

  TemplateViewDisplayMode _viewMode = TemplateViewDisplayMode.table;

  // Pagination State
  int _currentPage = 0;
  int _rowsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _sacramentTabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _currentPage = 0;
        });
      }
    });
    _loadTemplates();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() {
          _searchQuery = query.trim().toLowerCase();
          _currentPage = 0;
        });
      }
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
  // Data Loading & SQLite Fallback
  // ===========================================================================

  Future<void> _loadTemplates() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final isOnline = await RecordsSyncService.instance.checkConnectivity();
    List<CertificateTemplateModel> templates = [];

    if (isOnline) {
      try {
        templates = await CertificateService.getAllTemplates();
        _isLoadedFromSqlite = false;
      } catch (_) {}
    }

    if (templates.isEmpty) {
      templates = await _loadTemplatesFromSqlite();
      _isLoadedFromSqlite = true;
    }

    if (!mounted) return;
    setState(() {
      _allTemplates = templates;
      _isLoading = false;
    });
  }

  Future<List<CertificateTemplateModel>> _loadTemplatesFromSqlite() async {
    final db = await LocalDatabaseService.instance.database;
    if (db == null) {
      return _generateDefaultCanonicalTemplates();
    }

    try {
      final rows = await db.query(
        'certificate_templates',
        orderBy: 'sacrament_type ASC, is_default DESC, created_at DESC',
      );

      if (rows.isNotEmpty) {
        return rows.map((r) => _parseTemplateFromSqlite(r)).toList();
      }

      final defaults = _generateDefaultCanonicalTemplates();
      final batch = db.batch();
      for (final t in defaults) {
        final map = t.toMap();
        map['sync_status'] = 'synced';
        map['last_modified_at'] = DateTime.now().toIso8601String();
        map.forEach((k, v) {
          if (v is bool) map[k] = v ? 1 : 0;
          if (v is Map) map[k] = jsonEncode(v);
        });
        batch.insert('certificate_templates', map,
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
      return defaults;
    } catch (e) {
      debugPrint('[CertificateTemplateManagementPage] SQLite load error: $e');
      return _generateDefaultCanonicalTemplates();
    }
  }

  CertificateTemplateModel _parseTemplateFromSqlite(Map<String, dynamic> raw) {
    final map = Map<String, dynamic>.from(raw);

    for (final key in [
      'show_diocese_logo',
      'show_parish_seal',
      'enable_qr_verification',
      'is_active',
      'is_default'
    ]) {
      if (map.containsKey(key)) {
        final val = map[key];
        map[key] = (val == 1 || val == true || val == '1' || val == 'true');
      }
    }

    if (map['style_config'] is String) {
      try {
        map['style_config'] = jsonDecode(map['style_config'] as String);
      } catch (_) {}
    }

    return CertificateTemplateModel.fromMap(map);
  }

  List<CertificateTemplateModel> _generateDefaultCanonicalTemplates() {
    return [
      CertificateTemplateModel(
        templateId: 'TPL-BAP-DEFAULT',
        sacramentType: 'Baptism',
        templateName: 'Canonical Certificate of Baptism',
        certificateTitle: 'CERTIFICATE OF BAPTISM',
        headerText:
        'Diocese of San Pablo\nSaint John Paul II Parish\nSanta Cruz, Laguna',
        bodyWording:
        'This is to Certify that {Full Name}, child of {Father Name} and {Mother Name}, born in {Place of Birth} on {Date of Birth}, was solemnly Baptized according to the Rites of the Roman Catholic Church on {Date of Baptism} by {Minister Name}.\n\nSponsors were {Sponsor 1} and {Sponsor 2}.\n\nIssued upon request for {Purpose}.',
        isDefault: true,
        paperSize: 'A4',
        orientation: 'Portrait',
      ),
      CertificateTemplateModel(
        templateId: 'TPL-CNF-DEFAULT',
        sacramentType: 'Confirmation',
        templateName: 'Canonical Certificate of Confirmation',
        certificateTitle: 'CERTIFICATE OF CONFIRMATION',
        headerText:
        'Diocese of San Pablo\nSaint John Paul II Parish\nSanta Cruz, Laguna',
        bodyWording:
        'This is to Certify that {Full Name}, child of {Father Name} and {Mother Name}, baptized at {Church of Baptism} on {Date of Baptism}, was solemnly Confirmed in the Catholic Faith on {Date of Confirmation} by {Minister Name}.\n\nSponsor was {Sponsor 1}.\n\nIssued upon request for {Purpose}.',
        isDefault: true,
        paperSize: 'A4',
        orientation: 'Portrait',
      ),
      CertificateTemplateModel(
        templateId: 'TPL-FCM-DEFAULT',
        sacramentType: 'First Communion',
        templateName: 'Canonical Certificate of First Holy Communion',
        certificateTitle: 'CERTIFICATE OF FIRST HOLY COMMUNION',
        headerText:
        'Diocese of San Pablo\nSaint John Paul II Parish\nSanta Cruz, Laguna',
        bodyWording:
        'This is to Certify that {Full Name} has received for the first time the Most Holy Body and Blood of our Lord Jesus Christ on {Date of Communion} at Saint John Paul II Parish, officiated by {Minister Name}.\n\nIssued upon request for {Purpose}.',
        isDefault: true,
        paperSize: 'A4',
        orientation: 'Portrait',
      ),
      CertificateTemplateModel(
        templateId: 'TPL-MAT-DEFAULT',
        sacramentType: 'Matrimony',
        templateName: 'Canonical Certificate of Matrimony',
        certificateTitle: 'CERTIFICATE OF MATRIMONY',
        headerText:
        'Diocese of San Pablo\nSaint John Paul II Parish\nSanta Cruz, Laguna',
        bodyWording:
        'This is to Certify that {Groom Name} and {Bride Name} were united in Holy Matrimony according to the Rites of the Holy Roman Catholic Church on {Date of Marriage} by {Solemnizer Name}.\n\nWitnesses were {Sponsor 1} and {Sponsor 2}.\n\nIssued upon request for {Purpose}.',
        isDefault: true,
        paperSize: 'A4',
        orientation: 'Portrait',
      ),
      CertificateTemplateModel(
        templateId: 'TPL-DTH-DEFAULT',
        sacramentType: 'Death',
        templateName: 'Canonical Certificate of Christian Burial',
        certificateTitle: 'CERTIFICATE OF CHRISTIAN BURIAL',
        headerText:
        'Diocese of San Pablo\nSaint John Paul II Parish\nSanta Cruz, Laguna',
        bodyWording:
        'This is to Certify that {Full Name}, aged {Age}, died on {Date of Death} and was granted Christian Burial on {Date of Burial} at {Place of Burial}, with funeral rites officiated by {Minister Name}.\n\nIssued upon request for {Purpose}.',
        isDefault: true,
        paperSize: 'A4',
        orientation: 'Portrait',
      ),
      CertificateTemplateModel(
        templateId: 'TPL-CNV-DEFAULT',
        sacramentType: 'Conversion',
        templateName: 'Canonical Certificate of Reception into Full Communion',
        certificateTitle: 'CERTIFICATE OF RECEPTION INTO FULL COMMUNION',
        headerText:
        'Diocese of San Pablo\nSaint John Paul II Parish\nSanta Cruz, Laguna',
        bodyWording:
        'This is to Certify that {Full Name}, born on {Date of Birth} in {Place of Birth}, was solemnly received into Full Communion with the Catholic Church on {Date of Reception} by {Minister Name}.\n\nWitnesses were {Witness 1} and {Witness 2}.\n\nIssued upon request for {Purpose}.',
        isDefault: true,
        paperSize: 'A4',
        orientation: 'Portrait',
      ),
    ];
  }

  // ===========================================================================
  // Live State Handlers (Real-time updates)
  // ===========================================================================

  void _onTemplateStatusChanged(String templateId, bool isActive) {
    setState(() {
      final index = _allTemplates.indexWhere((t) => t.templateId == templateId);
      if (index != -1) {
        _allTemplates[index] = _allTemplates[index].copyWith(isActive: isActive);
      }
    });
  }

  void _onTemplateDeleted(String templateId) {
    setState(() {
      _allTemplates.removeWhere((t) => t.templateId == templateId);
    });
  }

  void _onTrashEmptied() {
    setState(() {
      _allTemplates.removeWhere((t) => !t.isActive);
    });
  }

  List<CertificateTemplateModel> _getFilteredTemplates(String sacramentFilter) {
    var activeTemplates = _allTemplates.where((t) => t.isActive).toList();

    if (sacramentFilter != 'All') {
      activeTemplates = activeTemplates
          .where((t) => t.sacramentType.toLowerCase() == sacramentFilter.toLowerCase())
          .toList();
    }

    if (_searchQuery.isNotEmpty) {
      activeTemplates = activeTemplates.where((t) {
        final nameMatch = t.templateName.toLowerCase().contains(_searchQuery);
        final titleMatch = t.certificateTitle.toLowerCase().contains(_searchQuery);
        final sacramentMatch = t.sacramentType.toLowerCase().contains(_searchQuery);
        final signatoryMatch = t.signatoryName.toLowerCase().contains(_searchQuery);
        return nameMatch || titleMatch || sacramentMatch || signatoryMatch;
      }).toList();
    }

    return activeTemplates;
  }

  List<CertificateTemplateModel> _paginateList(List<CertificateTemplateModel> list) {
    final startIndex = _currentPage * _rowsPerPage;
    if (startIndex >= list.length) return [];
    final endIndex = min(startIndex + _rowsPerPage, list.length);
    return list.sublist(startIndex, endIndex);
  }

  Color _getSacramentColor(String sacrament) {
    switch (sacrament) {
      case 'Baptism':
        return const Color(0xFF164E87);
      case 'Confirmation':
        return const Color(0xFFB91C1C);
      case 'First Communion':
        return const Color(0xFFD49B18);
      case 'Matrimony':
        return const Color(0xFF9D174D);
      case 'Death':
        return const Color(0xFF6B21A8);
      case 'Conversion':
        return const Color(0xFF2D6A4F);
      default:
        return ParishColors.marianBlue;
    }
  }

  Color _getSacramentSurfaceColor(String sacrament) {
    switch (sacrament) {
      case 'Baptism':
        return const Color(0xFFEDF4FB);
      case 'Confirmation':
        return const Color(0xFFFDF2F2);
      case 'First Communion':
        return const Color(0xFFFFF7E6);
      case 'Matrimony':
        return const Color(0xFFFCE7F3);
      case 'Death':
        return const Color(0xFFF3E8FF);
      case 'Conversion':
        return const Color(0xFFEDF7F2);
      default:
        return ParishColors.marianBlueSurface;
    }
  }

  IconData _getSacramentIcon(String sacrament) {
    switch (sacrament) {
      case 'Baptism':
        return Icons.water_drop_outlined;
      case 'Confirmation':
        return Icons.local_fire_department_outlined;
      case 'First Communion':
        return Icons.restaurant;
      case 'Matrimony':
        return Icons.favorite_border;
      case 'Death':
        return Icons.church_outlined;
      case 'Conversion':
        return Icons.eco_outlined;
      default:
        return Icons.description_outlined;
    }
  }

  // ===========================================================================
  // Action Handlers
  // ===========================================================================

  Future<void> _archiveTemplate(CertificateTemplateModel template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ParishColors.mercyRedSurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.archive_outlined,
                  color: ParishColors.mercyRed, size: 22),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Archive Template',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.5),
              ),
            ),
          ],
        ),
        content: Text(
          'Move "${template.templateName}" to the Trash Bin? It will be safely archived and hidden from live certificate issuances.',
          style: TextStyle(
              fontSize: 13.5,
              color: ParishColors.textDark.withOpacity(0.85),
              height: 1.4),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: ParishColors.mercyRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.archive, size: 17),
            label: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _onTemplateStatusChanged(template.templateId, false);

      try {
        await CertificateService.toggleTemplateStatus(template.templateId, false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${template.templateName}" moved to Trash Bin.'),
            backgroundColor: ParishColors.oliveGreen,
            action: SnackBarAction(
              label: 'Undo',
              textColor: Colors.white,
              onPressed: () async {
                _onTemplateStatusChanged(template.templateId, true);
                await CertificateService.toggleTemplateStatus(
                    template.templateId, true);
              },
            ),
          ),
        );
      } catch (e) {
        _onTemplateStatusChanged(template.templateId, true);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Archiving error: $e')),
        );
      }
    }
  }

  Future<void> _openTrashBinDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _TrashBinDialog(
        initialArchivedTemplates:
        _allTemplates.where((t) => !t.isActive).toList(),
        onTemplateRestored: (restored) {
          _onTemplateStatusChanged(restored.templateId, true);
        },
        onTemplateDeleted: (deletedId) {
          _onTemplateDeleted(deletedId);
        },
        onTrashEmptied: _onTrashEmptied,
        onRefreshNeeded: _loadTemplates,
      ),
    );
  }

  Future<void> _openGlobalEmblemsDialog() async {
    final settings = await CertificateService.getGlobalEmblemSettings();
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _GlobalEmblemsDialog(
        initialSettings: settings,
        onSaved: _loadTemplates,
      ),
    );
  }

  Future<void> _duplicateTemplate(CertificateTemplateModel template) async {
    final controller =
    TextEditingController(text: '${template.templateName} (Copy)');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Duplicate Certificate Template',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'New Template Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          OutlinedButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: ParishColors.marianBlue,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Duplicate'),
          ),
        ],
      ),
    );

    if (confirmed == true && controller.text.trim().isNotEmpty) {
      try {
        await CertificateService.duplicateTemplate(
            template.templateId, controller.text.trim());
        await _loadTemplates();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Duplication error: $e')));
      }
    }
  }

  Future<void> _previewTemplate(CertificateTemplateModel template) async {
    final sampleData = {
      'child_first_name': 'Juan',
      'child_last_name': 'Dela Cruz',
      'confirmand_first_name': 'Juan',
      'confirmand_last_name': 'Dela Cruz',
      'communicant_first_name': 'Juan',
      'communicant_last_name': 'Dela Cruz',
      'groom_first_name': 'Juan',
      'groom_last_name': 'Dela Cruz',
      'groom_age': 28,
      'groom_civil_status': 'Single',
      'bride_first_name': 'Maria',
      'bride_last_name': 'Santos',
      'bride_age': 26,
      'bride_civil_status': 'Single',
      'deceased_first_name': 'Juan',
      'deceased_last_name': 'Dela Cruz',
      'deceased_age': '74',
      'deceased_civil_status': 'Married',
      'deceased_residence': 'Santa Cruz, Laguna',
      'convert_first_name': 'Juan',
      'convert_last_name': 'Dela Cruz',
      'date_of_birth': '1998-05-15',
      'place_of_birth': 'Santa Cruz, Laguna',
      'father_first_name': 'Roberto',
      'father_last_name': 'Dela Cruz',
      'mother_first_name': 'Teresa',
      'mother_maiden_last_name': 'Mendoza',
      'sponsor_1_first_name': 'Pedro',
      'sponsor_1_last_name': 'Reyes',
      'sponsor_2_first_name': 'Elena',
      'sponsor_2_last_name': 'Ramos',
      'date_of_baptism': '1998-06-20',
      'place_of_baptism': 'St. John Paul II Parish Church',
      'date_of_confirmation': '2010-10-12',
      'date_of_communion': '2007-04-18',
      'date_of_marriage': '2024-02-14',
      'date_of_death': '2026-03-01',
      'date_of_burial': '2026-03-04',
      'place_of_burial': 'Sta. Cruz Catholic Cemetery',
      'date_of_reception': '2025-08-15',
      'book_number': '14',
      'page_number': '82',
      'line_number': '03',
      'control_number': 'FCM-2026-0001',
      'minister_first_name': 'Joseph',
      'minister_last_name': 'Santos',
      'solemnizer_first_name': 'Joseph',
      'solemnizer_last_name': 'Santos',
      'parish_name': 'St. John Paul II Parish',
    };

    showDialog(
      context: context,
      builder: (ctx) {
        final screenHeight = MediaQuery.of(context).size.height;
        return AlertDialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titlePadding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Preview: ${template.templateName}',
                  style: const TextStyle(
                      fontSize: 16.5, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 22),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          content: SizedBox(
            width: 720,
            height: screenHeight * 0.78,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: PdfPreview(
                build: (format) => CertificatePdfGenerator.generatePdf(
                  template: template,
                  sacramentType: template.sacramentType,
                  recordData: sampleData,
                  purpose: template.defaultPurpose,
                  verificationId: 'PREVIEW-SAMPLE-TOKEN',
                  qrVerificationUrl:
                  '${CertificateService.verificationBaseUrl}?v=PREVIEW-SAMPLE-TOKEN',
                ),
                useActions: false,
                allowPrinting: false,
                allowSharing: false,
                canChangePageFormat: false,
                canChangeOrientation: false,
                canDebug: false,
                loadingWidget: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: ParishColors.marianBlue),
                      SizedBox(height: 12),
                      Text('Rendering certificate document...',
                          style: TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          actionsPadding:
          const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: ParishColors.marianBlue,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final pdfBytes = await CertificatePdfGenerator.generatePdf(
                  template: template,
                  sacramentType: template.sacramentType,
                  recordData: sampleData,
                  purpose: template.defaultPurpose,
                  verificationId: 'PREVIEW-SAMPLE-TOKEN',
                  qrVerificationUrl:
                  '${CertificateService.verificationBaseUrl}?v=PREVIEW-SAMPLE-TOKEN',
                );
                await CertificatePdfGenerator.printCertificate(
                  pdfBytes: pdfBytes,
                  documentTitle: 'Preview_${template.templateName}',
                );
              },
              icon: const Icon(Icons.print, size: 18),
              label: const Text('Print Preview',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
            ),
          ],
        );
      },
    );
  }

  // Opens the dedicated full page editor instead of an inline modal dialog
  Future<void> _openTemplateEditor([CertificateTemplateModel? template]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CertificateTemplateEditorPage(
          initialTemplate: template,
          onSaved: _loadTemplates,
        ),
      ),
    );

    if (result == true) {
      _loadTemplates();
    }
  }

  // ===========================================================================
  // Build Main Screen
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final cardWhite = ParishColors.cardWhite;
    final borderGrey = ParishColors.borderGrey;
    final archivedCount = _allTemplates.where((t) => !t.isActive).length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth >= 900;
        final bool isMobile = constraints.maxWidth < 650;

        final currentTab = _sacramentTabs[_tabController.index];
        final totalFilteredList = _getFilteredTemplates(currentTab);
        final totalCount = totalFilteredList.length;

        final int totalPages =
        (totalCount / _rowsPerPage).ceil() > 0 ? (totalCount / _rowsPerPage).ceil() : 1;
        if (_currentPage >= totalPages) _currentPage = totalPages > 0 ? totalPages - 1 : 0;

        final pagedTemplates = _paginateList(totalFilteredList);

        return Scaffold(
          backgroundColor: ParishColors.backgroundLight,
          appBar: AppBar(
            backgroundColor: cardWhite,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back,
                  color: ParishColors.marianBlue, size: 26),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Certificate Templates Studio',
                  style: TextStyle(
                    fontSize: isMobile ? 17 : 19,
                    fontWeight: FontWeight.bold,
                    color: textDark,
                  ),
                ),
                Text(
                  'Diocesan Canonical Certificate Formatting & Signatures',
                  style: TextStyle(fontSize: 12, color: textMuted),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.shield_outlined,
                    color: ParishColors.marianBlue),
                tooltip: 'Diocese & Parish Emblems',
                onPressed: _openGlobalEmblemsDialog,
              ),
              Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: archivedCount > 0
                          ? ParishColors.mercyRed
                          : ParishColors.marianBlue,
                    ),
                    tooltip: 'Trash Bin ($archivedCount archived)',
                    onPressed: _openTrashBinDialog,
                  ),
                  if (archivedCount > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: ParishColors.mercyRed,
                          shape: BoxShape.circle,
                        ),
                        constraints:
                        const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          '$archivedCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: ParishColors.marianBlue),
                tooltip: 'Reload Templates',
                onPressed: _loadTemplates,
              ),
              if (isMobile)
                IconButton(
                  icon: const Icon(Icons.add_circle,
                      color: ParishColors.marianBlue, size: 26),
                  tooltip: 'Create Template',
                  onPressed: () => _openTemplateEditor(),
                )
              else
                Padding(
                  padding:
                  const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ParishColors.marianBlue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(40, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _openTemplateEditor(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text(
                      'Create Template',
                      style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _loadTemplates,
            color: ParishColors.marianBlue,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : 28,
                vertical: isMobile ? 14 : 20,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1400),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Sync Status Banner
                      _buildSyncStatusPill(isMobile),
                      const SizedBox(height: 16),

                      // 2. Search & View Mode Toolbar
                      _buildSearchAndToolbar(isMobile),
                      const SizedBox(height: 14),

                      // 3. Sacrament Filter Tabs
                      Container(
                        decoration: BoxDecoration(
                          color: cardWhite,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderGrey),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          isScrollable: true,
                          labelColor: ParishColors.marianBlue,
                          unselectedLabelColor: textMuted,
                          indicatorColor: ParishColors.marianBlue,
                          indicatorWeight: 3,
                          tabs: _sacramentTabs.map((t) {
                            final count = _getFilteredTemplates(t).length;
                            return Tab(
                              text: t == 'All' ? 'All ($count)' : '$t ($count)',
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // 4. Section Count Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _searchQuery.isNotEmpty
                                  ? '$totalCount matches found'
                                  : '$currentTab Templates ($totalCount)',
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.bold,
                                color: textDark,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: ParishColors.marianBlueSurface,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${_allTemplates.where((t) => t.isActive).length} Active',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: ParishColors.marianBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // 5. Template Cards / Full-Width Table View
                      if (_isLoading)
                        _buildSkeletonLoading()
                      else if (_errorMessage != null && _allTemplates.isEmpty)
                        _buildErrorCard(_errorMessage!)
                      else if (totalCount == 0)
                          _buildEmptyState()
                        else if (_viewMode == TemplateViewDisplayMode.cards)
                            _buildCardsGrid(pagedTemplates, isDesktop)
                          else
                            _buildFullWidthTableView(pagedTemplates),

                      const SizedBox(height: 16),

                      // 6. Pagination Footer
                      if (!_isLoading && totalCount > 0)
                        _buildPaginationFooter(totalCount, totalPages, isMobile),

                      const SizedBox(height: 40),
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

  // ===========================================================================
  // UI Component Builders
  // ===========================================================================

  Widget _buildSyncStatusPill(bool isMobile) {
    final bgColor =
    _isLoadedFromSqlite ? Colors.amber.shade50 : const Color(0xFFE8F5E9);
    final borderColor =
    _isLoadedFromSqlite ? Colors.amber.shade300 : const Color(0xFF81C784);
    final textColor =
    _isLoadedFromSqlite ? Colors.amber.shade900 : const Color(0xFF2E7D32);
    final iconData =
    _isLoadedFromSqlite ? Icons.cloud_off : Icons.cloud_done_outlined;
    final statusText = _isLoadedFromSqlite
        ? 'Offline Mode • Working from local SQLite cache (${_allTemplates.length} templates available)'
        : 'Online Connected • All official and custom templates synchronized with Supabase';

    return Container(
      width: double.infinity,
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(iconData, size: 18, color: textColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              statusText,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(Icons.refresh, size: 16, color: textColor),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Sync now',
            onPressed: _loadTemplates,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndToolbar(bool isMobile) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: ParishColors.cardWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ParishColors.borderGrey),
            ),
            child: Row(
              children: [
                const Icon(Icons.search,
                    size: 20, color: ParishColors.marianBlue),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: _onSearchChanged,
                    style:
                    TextStyle(fontSize: 13.5, color: ParishColors.textDark),
                    decoration: InputDecoration(
                      hintText: isMobile
                          ? 'Search templates by name, title...'
                          : 'Search templates by name, sacrament, or signatory...',
                      hintStyle:
                      TextStyle(fontSize: 12.5, color: ParishColors.textMuted),
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
                    tooltip: 'Clear search',
                    onPressed: _clearSearch,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          height: 38,
          decoration: BoxDecoration(
            color: ParishColors.cardWhite,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ParishColors.borderGrey),
          ),
          child: ToggleButtons(
            isSelected: [
              _viewMode == TemplateViewDisplayMode.cards,
              _viewMode == TemplateViewDisplayMode.table,
            ],
            onPressed: (idx) => setState(() {
              _viewMode = idx == 0
                  ? TemplateViewDisplayMode.cards
                  : TemplateViewDisplayMode.table;
            }),
            borderRadius: BorderRadius.circular(7),
            selectedColor: Colors.white,
            fillColor: ParishColors.marianBlue,
            color: ParishColors.textMuted,
            constraints: const BoxConstraints(minHeight: 36, minWidth: 40),
            children: const [
              Tooltip(
                  message: 'Card View', child: Icon(Icons.grid_view, size: 16)),
              Tooltip(
                  message: 'Table View',
                  child: Icon(Icons.table_chart, size: 16)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCardsGrid(
      List<CertificateTemplateModel> templates, bool isDesktop) {
    if (isDesktop) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 2.15,
        ),
        itemCount: templates.length,
        itemBuilder: (ctx, idx) => _buildTemplateCard(templates[idx]),
      );
    }

    return Column(
      children: templates
          .map((t) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: _buildTemplateCard(t),
      ))
          .toList(),
    );
  }

  Widget _buildTemplateCard(CertificateTemplateModel item) {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final accent = _getSacramentColor(item.sacramentType);
    final surface = _getSacramentSurfaceColor(item.sacramentType);
    final icon = _getSacramentIcon(item.sacramentType);
    final isCanvaMode = item.styleConfig.useVisualCanvas;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.04),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accent.withOpacity(0.3)),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item.templateName,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.bold,
                              color: textDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (item.isDefault) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: ParishColors.goldLight,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: ParishColors.goldAccent, width: 0.8),
                            ),
                            child: Text(
                              'DEFAULT',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: ParishColors.textDark,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.certificateTitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: accent,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: isCanvaMode
                        ? const Color(0xFF0F172A)
                        : ParishColors.marianBlueSurface,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    isCanvaMode ? 'VISUAL CANVA' : 'SIMPLE MODE',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: isCanvaMode
                          ? Colors.cyanAccent
                          : ParishColors.marianBlue,
                    ),
                  ),
                ),
                Text(
                  '${item.paperSize} (${item.orientation}) • v${item.version}',
                  style: TextStyle(fontSize: 12, color: textMuted),
                ),
                Text(
                  '• Signatory: ${item.signatoryName}',
                  style: TextStyle(
                      fontSize: 11.5,
                      color: textDark.withOpacity(0.85),
                      fontStyle: FontStyle.italic),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: ParishColors.borderGrey)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('Active',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: textMuted)),
                    const SizedBox(width: 4),
                    Transform.scale(
                      scale: 0.75,
                      child: Switch(
                        value: item.isActive,
                        activeColor: ParishColors.oliveGreen,
                        onChanged: (val) async {
                          _onTemplateStatusChanged(item.templateId, val);
                          await CertificateService.toggleTemplateStatus(
                              item.templateId, val);
                        },
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: ParishColors.marianBlue,
                      ),
                      onPressed: () => _previewTemplate(item),
                      icon: const Icon(Icons.picture_as_pdf, size: 16),
                      label: const Text('Preview',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      tooltip: 'Duplicate',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32),
                      onPressed: () => _duplicateTemplate(item),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: 'Edit Template',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32),
                      onPressed: () => _openTemplateEditor(item),
                    ),
                    IconButton(
                      icon: const Icon(Icons.archive_outlined,
                          size: 18, color: ParishColors.mercyRed),
                      tooltip: 'Archive Template',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32),
                      onPressed: () => _archiveTemplate(item),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Full-Width Responsive Table View (Zero Trailing Whitespace)
  // ===========================================================================

  Widget _buildFullWidthTableView(List<CertificateTemplateModel> templates) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double containerWidth = constraints.maxWidth;
        // Dynamically compute spacing across available width to prevent right-edge blank space
        const double estimatedContentWidth = 720.0;
        double dynamicSpacing = (containerWidth - estimatedContentWidth) / 6;
        if (dynamicSpacing < 18.0) dynamicSpacing = 18.0;

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
                constraints: BoxConstraints(minWidth: containerWidth),
                child: DataTable(
                  columnSpacing: dynamicSpacing,
                  horizontalMargin: 22,
                  headingRowColor:
                  WidgetStateProperty.all(ParishColors.marianBlueSurface),
                  headingTextStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: ParishColors.marianBlue,
                    fontSize: 12.5,
                  ),
                  dataTextStyle:
                  TextStyle(fontSize: 12.5, color: ParishColors.textDark),
                  columns: const [
                    DataColumn(label: Text('Sacrament')),
                    DataColumn(label: Text('Template Name')),
                    DataColumn(label: Text('Mode')),
                    DataColumn(label: Text('Paper Size')),
                    DataColumn(label: Text('Signatory')),
                    DataColumn(label: Text('Default')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: templates.map((t) {
                    final accent = _getSacramentColor(t.sacramentType);
                    final surface = _getSacramentSurfaceColor(t.sacramentType);

                    return DataRow(
                      cells: [
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: surface,
                              borderRadius: BorderRadius.circular(5),
                              border:
                              Border.all(color: accent.withOpacity(0.35)),
                            ),
                            child: Text(
                              t.sacramentType.toUpperCase(),
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: accent),
                            ),
                          ),
                        ),
                        DataCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 220),
                            child: Text(
                              t.templateName,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: t.styleConfig.useVisualCanvas
                                  ? const Color(0xFF0F172A)
                                  : ParishColors.marianBlueSurface,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              t.styleConfig.useVisualCanvas
                                  ? 'Visual Canva'
                                  : 'Simple',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: t.styleConfig.useVisualCanvas
                                    ? Colors.cyanAccent
                                    : ParishColors.marianBlue,
                              ),
                            ),
                          ),
                        ),
                        DataCell(Text('${t.paperSize} (${t.orientation})')),
                        DataCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 180),
                            child: Text(t.signatoryName,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ),
                        DataCell(
                          Text(
                            t.isDefault ? 'YES' : '—',
                            style: TextStyle(
                              fontWeight: t.isDefault
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: t.isDefault
                                  ? ParishColors.goldAccent
                                  : ParishColors.textMuted,
                            ),
                          ),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.picture_as_pdf,
                                    size: 17, color: ParishColors.marianBlue),
                                tooltip: 'Preview PDF',
                                onPressed: () => _previewTemplate(t),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy, size: 17),
                                tooltip: 'Duplicate',
                                onPressed: () => _duplicateTemplate(t),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 17),
                                tooltip: 'Edit Template',
                                onPressed: () => _openTemplateEditor(t),
                              ),
                              IconButton(
                                icon: const Icon(Icons.archive_outlined,
                                    size: 17, color: ParishColors.mercyRed),
                                tooltip: 'Archive',
                                onPressed: () => _archiveTemplate(t),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // Pagination Toolbar Footer
  // ===========================================================================

  Widget _buildPaginationFooter(int totalCount, int totalPages, bool isMobile) {
    final cardWhiteColor = ParishColors.cardWhite;
    final borderGreyColor = ParishColors.borderGrey;
    final textDarkColor = ParishColors.textDark;
    final textMutedColor = ParishColors.textMuted;

    final startItem = _currentPage * _rowsPerPage + 1;
    final endItem = min((_currentPage + 1) * _rowsPerPage, totalCount);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: cardWhiteColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderGreyColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                'Showing $startItem–$endItem of $totalCount',
                style: TextStyle(fontSize: 12.5, color: textMutedColor),
              ),
              const SizedBox(width: 14),
              if (!isMobile) ...[
                Text('Rows per page:',
                    style: TextStyle(fontSize: 12, color: textMutedColor)),
                const SizedBox(width: 6),
                DropdownButton<int>(
                  value: _rowsPerPage,
                  isDense: true,
                  underline: const SizedBox.shrink(),
                  items: [10, 25, 50].map((val) {
                    return DropdownMenuItem<int>(
                      value: val,
                      child: Text(
                        '$val',
                        style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: ParishColors.marianBlue),
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
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.first_page, size: 20),
                tooltip: 'First page',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: _currentPage > 0
                    ? () => setState(() => _currentPage = 0)
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 20),
                tooltip: 'Previous page',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: _currentPage > 0
                    ? () => setState(() => _currentPage--)
                    : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '${_currentPage + 1} / $totalPages',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: textDarkColor),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 20),
                tooltip: 'Next page',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: _currentPage < totalPages - 1
                    ? () => setState(() => _currentPage++)
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.last_page, size: 20),
                tooltip: 'Last page',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: _currentPage < totalPages - 1
                    ? () => setState(() => _currentPage = totalPages - 1)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
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
          Icon(Icons.description_outlined,
              size: 44, color: ParishColors.textMuted),
          const SizedBox(height: 10),
          Text(
            'No certificate templates match your criteria.',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: ParishColors.textDark),
          ),
          const SizedBox(height: 4),
          Text(
            'Click "Create Template" above to add an official template or adjust your search filter.',
            style: TextStyle(fontSize: 12.5, color: ParishColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    return Container(
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
              error,
              style:
              const TextStyle(fontSize: 13, color: ParishColors.mercyRed),
            ),
          ),
          TextButton(
            onPressed: _loadTemplates,
            child: const Text('Retry',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoading() {
    return Column(
      children: List.generate(4, (index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 90,
          decoration: BoxDecoration(
            color: ParishColors.cardWhite,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ParishColors.borderGrey.withOpacity(0.4)),
          ),
        );
      }),
    );
  }
}

// =============================================================================
// Live-Synchronized Trash Bin Dialog
// =============================================================================

class _TrashBinDialog extends StatefulWidget {
  final List<CertificateTemplateModel> initialArchivedTemplates;
  final void Function(CertificateTemplateModel template) onTemplateRestored;
  final void Function(String templateId) onTemplateDeleted;
  final VoidCallback onTrashEmptied;
  final Future<void> Function() onRefreshNeeded;

  const _TrashBinDialog({
    required this.initialArchivedTemplates,
    required this.onTemplateRestored,
    required this.onTemplateDeleted,
    required this.onTrashEmptied,
    required this.onRefreshNeeded,
  });

  @override
  State<_TrashBinDialog> createState() => _TrashBinDialogState();
}

class _TrashBinDialogState extends State<_TrashBinDialog> {
  late List<CertificateTemplateModel> _archivedTemplates;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _archivedTemplates = List.from(widget.initialArchivedTemplates);
  }

  Color _getSacramentColor(String sacrament) {
    switch (sacrament) {
      case 'Baptism':
        return const Color(0xFF164E87);
      case 'Confirmation':
        return const Color(0xFFB91C1C);
      case 'First Communion':
        return const Color(0xFFD49B18);
      case 'Matrimony':
        return const Color(0xFF9D174D);
      case 'Death':
        return const Color(0xFF6B21A8);
      case 'Conversion':
        return const Color(0xFF2D6A4F);
      default:
        return ParishColors.marianBlue;
    }
  }

  Future<void> _restoreTemplate(CertificateTemplateModel template) async {
    setState(() {
      _archivedTemplates.removeWhere((t) => t.templateId == template.templateId);
    });

    widget.onTemplateRestored(template);

    try {
      await CertificateService.toggleTemplateStatus(template.templateId, true);
      widget.onRefreshNeeded();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${template.templateName}" has been restored.'),
          backgroundColor: ParishColors.oliveGreen,
        ),
      );
    } catch (e) {
      setState(() {
        _archivedTemplates.add(template);
      });
      widget.onTemplateRestored(template.copyWith(isActive: false));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restore failed: $e')),
      );
    }
  }

  Future<void> _confirmPermanentlyDelete(
      CertificateTemplateModel template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ParishColors.mercyRedSurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_forever,
                  color: ParishColors.mercyRed, size: 22),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Permanently Delete Template',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
        content: Text(
          'Permanently remove "${template.templateName}"? This action cannot be undone and will permanently erase this template from parish archives.',
          style: TextStyle(
              fontSize: 13.5,
              color: ParishColors.textDark.withOpacity(0.85),
              height: 1.4),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: ParishColors.mercyRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_forever, size: 17),
            label: const Text('Permanently Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _archivedTemplates
            .removeWhere((t) => t.templateId == template.templateId);
      });
      widget.onTemplateDeleted(template.templateId);

      try {
        await CertificateService.deleteTemplatePermanently(template.templateId);
        widget.onRefreshNeeded();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${template.templateName}" was permanently deleted.'),
            backgroundColor: ParishColors.mercyRed,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deletion failed: $e')),
        );
      }
    }
  }

  Future<void> _confirmEmptyTrash() async {
    if (_archivedTemplates.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ParishColors.mercyRedSurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_sweep,
                  color: ParishColors.mercyRed, size: 24),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Empty Trash Bin',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
        content: Text(
          'Permanently delete all ${_archivedTemplates.length} archived template(s)? This action cannot be undone.',
          style: TextStyle(
              fontSize: 13.5,
              color: ParishColors.textDark.withOpacity(0.85),
              height: 1.4),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: ParishColors.mercyRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_sweep, size: 18),
            label: const Text('Empty Trash Bin'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final itemsToDelete = List<CertificateTemplateModel>.from(_archivedTemplates);
      setState(() {
        _archivedTemplates.clear();
      });
      widget.onTrashEmptied();

      try {
        for (final t in itemsToDelete) {
          await CertificateService.deleteTemplatePermanently(t.templateId);
        }
        widget.onRefreshNeeded();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trash bin emptied successfully.'),
            backgroundColor: ParishColors.mercyRed,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error emptying trash: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final cardWhite = ParishColors.cardWhite;
    final borderGrey = ParishColors.borderGrey;
    final double screenHeight = MediaQuery.of(context).size.height;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: cardWhite,
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.restore_from_trash,
                  color: ParishColors.mercyRed, size: 24),
              const SizedBox(width: 10),
              Text(
                'Trash Bin (${_archivedTemplates.length})',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 17, color: textDark),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      content: SizedBox(
        width: 650,
        height: screenHeight * 0.65,
        child: Column(
          children: [
            if (_archivedTemplates.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Archived templates are stored here. You can restore them anytime or permanently delete them.',
                        style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.red.shade900,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ParishColors.mercyRed,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(36, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      onPressed: _isProcessing ? null : _confirmEmptyTrash,
                      icon: const Icon(Icons.delete_sweep, size: 16),
                      label: const Text('Empty Trash',
                          style: TextStyle(
                              fontSize: 11.5, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
            Expanded(
              child: _archivedTemplates.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.delete_outline,
                        size: 52, color: textMuted.withOpacity(0.5)),
                    const SizedBox(height: 12),
                    Text(
                      'Trash Bin is empty',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: textDark),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Archived templates will appear here and can be restored or permanently removed.',
                      style: TextStyle(fontSize: 12, color: textMuted),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                itemCount: _archivedTemplates.length,
                itemBuilder: (context, index) {
                  final item = _archivedTemplates[index];
                  final accent = _getSacramentColor(item.sacramentType);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cardWhite,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderGrey),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child:
                          Icon(Icons.archive, color: accent, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.templateName,
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: textDark),
                              ),
                              Text(
                                '${item.sacramentType} • ${item.paperSize} (${item.orientation}) • v${item.version}',
                                style: TextStyle(
                                    fontSize: 11.5, color: textMuted),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: ParishColors.mercyRed,
                            side: const BorderSide(
                                color: ParishColors.mercyRed),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            minimumSize: const Size(36, 32),
                          ),
                          onPressed: () =>
                              _confirmPermanentlyDelete(item),
                          icon: const Icon(Icons.delete_forever, size: 14),
                          label: const Text('Delete',
                              style: TextStyle(fontSize: 11)),
                        ),
                        const SizedBox(width: 6),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ParishColors.marianBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            minimumSize: const Size(36, 32),
                          ),
                          onPressed: () => _restoreTemplate(item),
                          icon: const Icon(Icons.restore, size: 14),
                          label: const Text('Restore',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

// =============================================================================
// Global Emblems Configuration Dialog
// =============================================================================

class _GlobalEmblemsDialog extends StatefulWidget {
  final Map<String, dynamic> initialSettings;
  final VoidCallback onSaved;

  const _GlobalEmblemsDialog({
    required this.initialSettings,
    required this.onSaved,
  });

  @override
  State<_GlobalEmblemsDialog> createState() => _GlobalEmblemsDialogState();
}

class _GlobalEmblemsDialogState extends State<_GlobalEmblemsDialog> {
  String? _dioceseLogoUrl;
  String? _parishSealUrl;
  late bool _showDioceseLogo;
  late bool _showParishSeal;

  bool _isSaving = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _dioceseLogoUrl = widget.initialSettings['diocese_logo_url']?.toString();
    _parishSealUrl = widget.initialSettings['parish_seal_url']?.toString();
    _showDioceseLogo = widget.initialSettings['show_diocese_logo'] ?? true;
    _showParishSeal = widget.initialSettings['show_parish_seal'] ?? true;
  }

  Future<void> _pickAndUploadEmblem(bool isDiocese) async {
    setState(() => _isUploading = true);
    try {
      final dynamic result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
      );

      if (result != null) {
        dynamic file;
        if (result is List && result.isNotEmpty) {
          file = result.first;
        } else {
          try {
            final files = (result as dynamic).files;
            if (files != null && files.isNotEmpty) file = files.first;
          } catch (_) {
            file = result;
          }
        }

        if (file != null) {
          Uint8List? bytes;
          try {
            bytes = await (file as dynamic).readAsBytes();
          } catch (_) {
            try {
              bytes = (file as dynamic).bytes;
            } catch (_) {}
          }

          if (bytes != null) {
            String ext = 'png';
            try {
              ext = (file as dynamic).extension ?? 'png';
            } catch (_) {
              try {
                final String? name = (file as dynamic).name;
                if (name != null && name.contains('.')) {
                  ext = name.split('.').last;
                }
              } catch (_) {}
            }

            final url = await CertificateService.uploadCertificateAsset(
              fileBytes: bytes,
              fileExtension: ext,
              assetCategory: 'logos',
            );

            setState(() {
              if (isDiocese) {
                _dioceseLogoUrl = url;
              } else {
                _parishSealUrl = url;
              }
            });
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _saveGlobalEmblems() async {
    setState(() => _isSaving = true);
    try {
      await CertificateService.updateGlobalEmblems(
        dioceseLogoUrl: _dioceseLogoUrl,
        parishSealUrl: _parishSealUrl,
        showDioceseLogo: _showDioceseLogo,
        showParishSeal: _showParishSeal,
      );

      if (!mounted) return;
      Navigator.pop(context);
      widget.onSaved();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Official Diocese Logo & Parish Seal updated!'),
          backgroundColor: ParishColors.oliveGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AlertDialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          backgroundColor: ParishColors.cardWhite,
          title: const Row(
            children: [
              Icon(Icons.shield, color: ParishColors.marianBlue, size: 24),
              SizedBox(width: 10),
              Expanded(
                child: Text('Official Emblems',
                    style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Changes made here apply automatically to ALL issued certificates and templates.',
                    style: TextStyle(
                        fontSize: 12.5,
                        color: ParishColors.textMuted,
                        height: 1.3),
                  ),
                  const Divider(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ParishColors.backgroundLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ParishColors.borderGrey),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          activeColor: ParishColors.marianBlue,
                          title: const Text('Display Diocese Logo',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13)),
                          value: _showDioceseLogo,
                          onChanged: (val) =>
                              setState(() => _showDioceseLogo = val),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border:
                                Border.all(color: ParishColors.borderGrey),
                              ),
                              child: _dioceseLogoUrl != null &&
                                  _dioceseLogoUrl!.isNotEmpty
                                  ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(_dioceseLogoUrl!,
                                      fit: BoxFit.contain))
                                  : const Center(
                                  child: Text('DSP',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: ParishColors.marianBlue))),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(40, 40)),
                                onPressed: (_isUploading || _isSaving)
                                    ? null
                                    : () => _pickAndUploadEmblem(true),
                                icon: const Icon(Icons.upload_file, size: 16),
                                label: Text(
                                    _dioceseLogoUrl != null
                                        ? 'Replace Logo'
                                        : 'Upload Logo',
                                    style: const TextStyle(fontSize: 12)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ParishColors.backgroundLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ParishColors.borderGrey),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          activeColor: ParishColors.marianBlue,
                          title: const Text('Display Parish Seal',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13)),
                          value: _showParishSeal,
                          onChanged: (val) =>
                              setState(() => _showParishSeal = val),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border:
                                Border.all(color: ParishColors.borderGrey),
                              ),
                              child: _parishSealUrl != null &&
                                  _parishSealUrl!.isNotEmpty
                                  ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(_parishSealUrl!,
                                      fit: BoxFit.contain))
                                  : const Center(
                                  child: Text('SJP2',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: ParishColors.marianBlue))),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(40, 40)),
                                onPressed: (_isUploading || _isSaving)
                                    ? null
                                    : () => _pickAndUploadEmblem(false),
                                icon: const Icon(Icons.upload_file, size: 16),
                                label: Text(
                                    _parishSealUrl != null
                                        ? 'Replace Seal'
                                        : 'Upload Seal',
                                    style: const TextStyle(fontSize: 12)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actionsPadding:
          const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          actions: [
            OutlinedButton(
                onPressed: _isSaving ? null : () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: ParishColors.marianBlue,
                foregroundColor: Colors.white,
                minimumSize: const Size(44, 44),
              ),
              onPressed: (_isSaving || _isUploading) ? null : _saveGlobalEmblems,
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('Apply Emblems',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        if (_isSaving || _isUploading)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  color: ParishColors.goldAccent,
                  strokeWidth: 4,
                ),
              ),
            ),
          ),
      ],
    );
  }
}