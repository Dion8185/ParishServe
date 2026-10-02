import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../../../core/constants/colors.dart';
import '../../../sacramental_records/models/certificate_canvas_element.dart';
import '../../../sacramental_records/services/certificate_service.dart';
import '../../models/certificate_style_config.dart';
import '../../models/certificate_template_model.dart';
import '../../services/certificate_pdf_generator.dart';
import '../../utils/placeholder_registry.dart';
import 'certificate_canvas_designer_page.dart';

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

  List<CertificateTemplateModel> _allTemplates = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _sacramentTabs.length, vsync: this);
    _loadTemplates();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTemplates() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final templates = await CertificateService.getAllTemplates();
      if (!mounted) return;
      setState(() {
        _allTemplates = templates;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  List<CertificateTemplateModel> _getFilteredTemplates(String filter) {
    if (filter == 'All') return _allTemplates;
    return _allTemplates.where((t) => t.sacramentType == filter).toList();
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

  Future<void> _openGlobalEmblemsDialog() async {
    final settings = await CertificateService.getGlobalEmblemSettings();
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _GlobalEmblemsDialog(
        initialSettings: settings,
        onSaved: () {
          _loadTemplates();
        },
      ),
    );
  }

  Future<void> _duplicateTemplate(CertificateTemplateModel template) async {
    final controller = TextEditingController(text: '${template.templateName} (Copy)');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Duplicate Certificate Template'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'New Template Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ParishColors.marianBlue, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Duplicate'),
          ),
        ],
      ),
    );

    if (confirmed == true && controller.text.trim().isNotEmpty) {
      try {
        await CertificateService.duplicateTemplate(template.templateId, controller.text.trim());
        _loadTemplates();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Duplication error: $e')));
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Preview: ${template.templateName}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
            ],
          ),
          content: SizedBox(
            width: 720,
            height: screenHeight * 0.75,
            child: PdfPreview(
              build: (format) => CertificatePdfGenerator.generatePdf(
                template: template,
                sacramentType: template.sacramentType,
                recordData: sampleData,
                purpose: template.defaultPurpose,
                verificationId: 'PREVIEW-SAMPLE-TOKEN',
                qrVerificationUrl: '${CertificateService.verificationBaseUrl}?v=PREVIEW-SAMPLE-TOKEN',
              ),
              allowPrinting: true,
              allowSharing: false,
              canChangePageFormat: false,
            ),
          ),
        );
      },
    );
  }

  void _openTemplateEditor([CertificateTemplateModel? template]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _TemplateEditorDialog(
        initialTemplate: template,
        onSaved: () {
          _loadTemplates();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final cardWhite = ParishColors.cardWhite;
    final borderGrey = ParishColors.borderGrey;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 650;

        return Scaffold(
          backgroundColor: ParishColors.backgroundLight,
          appBar: AppBar(
            backgroundColor: cardWhite,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: ParishColors.marianBlue, size: 26),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Certificate Templates',
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.bold,
                    color: textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!isMobile)
                  Text(
                    'Customize designs, typography, borders, and canonical headers',
                    style: TextStyle(fontSize: 12, color: textMuted),
                  ),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.shield_outlined, color: ParishColors.marianBlue),
                tooltip: 'Official Emblems (Global Parish Settings)',
                onPressed: _openGlobalEmblemsDialog,
              ),
              IconButton(
                icon: Icon(Icons.refresh, color: ParishColors.marianBlue),
                tooltip: 'Reload Templates',
                onPressed: _loadTemplates,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ParishColors.marianBlue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(40, 40),
                    padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _openTemplateEditor(),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(
                    isMobile ? 'New' : 'Create Template',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: ParishColors.marianBlue,
              unselectedLabelColor: textMuted,
              indicatorColor: ParishColors.marianBlue,
              tabs: _sacramentTabs.map((t) => Tab(text: t)).toList(),
            ),
          ),
          body: SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(child: Text(_errorMessage!, style: TextStyle(color: ParishColors.mercyRed)))
                : TabBarView(
              controller: _tabController,
              children: _sacramentTabs.map((tab) {
                final list = _getFilteredTemplates(tab);
                if (list.isEmpty) {
                  return Center(
                    child: Text('No certificate templates found for $tab.', style: TextStyle(color: textMuted)),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.all(isMobile ? 12 : 20),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final item = list[index];
                    final accent = _getSacramentColor(item.sacramentType);
                    final isCanvaMode = item.styleConfig.useVisualCanvas;

                    // RESPONSIVE MOBILE CARD: Stacks action buttons cleanly at the bottom
                    if (isMobile) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cardWhite,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderGrey),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: accent.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(Icons.description, color: accent, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.templateName,
                                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textDark),
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          if (item.isDefault)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: ParishColors.goldLight,
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: ParishColors.goldAccent),
                                              ),
                                              child: Text(
                                                'DEFAULT',
                                                style: TextStyle(fontSize: 9.0, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                                              ),
                                            ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isCanvaMode ? const Color(0xFF0F172A) : ParishColors.marianBlueSurface,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              isCanvaMode ? 'VISUAL CANVA' : 'SIMPLE MODE',
                                              style: TextStyle(
                                                fontSize: 9.0,
                                                fontWeight: FontWeight.bold,
                                                color: isCanvaMode ? Colors.cyanAccent : ParishColors.marianBlue,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '${item.sacramentType} • ${item.paperSize} (${item.orientation}) • Version ${item.version}',
                                        style: TextStyle(fontSize: 12.0, color: textMuted),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Signatory: ${item.signatoryName} (${item.signatoryTitle})',
                                        style: TextStyle(fontSize: 11.5, color: textDark, fontStyle: FontStyle.italic),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Text('Active:', style: TextStyle(fontSize: 12, color: textMuted)),
                                    const SizedBox(width: 4),
                                    Switch(
                                      value: item.isActive,
                                      activeColor: ParishColors.oliveGreen,
                                      onChanged: (val) async {
                                        await CertificateService.toggleTemplateStatus(item.templateId, val);
                                        _loadTemplates();
                                      },
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                                      icon: Icon(Icons.picture_as_pdf, color: ParishColors.marianBlue, size: 20),
                                      tooltip: 'Preview PDF',
                                      onPressed: () => _previewTemplate(item),
                                    ),
                                    IconButton(
                                      constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                                      icon: Icon(Icons.copy, color: textDark, size: 20),
                                      tooltip: 'Duplicate',
                                      onPressed: () => _duplicateTemplate(item),
                                    ),
                                    IconButton(
                                      constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                                      icon: Icon(Icons.edit, color: textDark, size: 20),
                                      tooltip: 'Edit Template',
                                      onPressed: () => _openTemplateEditor(item),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }

                    // DESKTOP CARD VIEW: Horizontal row with actions aligned to right edge
                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: cardWhite,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderGrey),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: accent.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.description, color: accent, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.templateName,
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDark),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (item.isDefault)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: ParishColors.goldLight,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: ParishColors.goldAccent),
                                        ),
                                        child: Text(
                                          'DEFAULT',
                                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                                        ),
                                      ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isCanvaMode ? const Color(0xFF0F172A) : ParishColors.marianBlueSurface,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        isCanvaMode ? 'VISUAL MODE' : 'SIMPLE MODE',
                                        style: TextStyle(
                                          fontSize: 9.0,
                                          fontWeight: FontWeight.bold,
                                          color: isCanvaMode ? Colors.cyanAccent : ParishColors.marianBlue,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${item.sacramentType} • ${item.paperSize} (${item.orientation}) • Font: ${item.styleConfig.fontFamily.toUpperCase()} • Version ${item.version}',
                                  style: TextStyle(fontSize: 12.0, color: textMuted),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Signatory: ${item.signatoryName} (${item.signatoryTitle})',
                                  style: TextStyle(fontSize: 11.5, color: textDark, fontStyle: FontStyle.italic),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                                icon: Icon(Icons.picture_as_pdf, color: ParishColors.marianBlue),
                                tooltip: 'Preview PDF Layout',
                                onPressed: () => _previewTemplate(item),
                              ),
                              IconButton(
                                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                                icon: Icon(Icons.copy, color: ParishColors.textDark),
                                tooltip: 'Duplicate Template',
                                onPressed: () => _duplicateTemplate(item),
                              ),
                              IconButton(
                                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                                icon: Icon(Icons.edit, color: ParishColors.textDark),
                                tooltip: 'Edit Template',
                                onPressed: () => _openTemplateEditor(item),
                              ),
                              Switch(
                                value: item.isActive,
                                activeColor: ParishColors.oliveGreen,
                                onChanged: (val) async {
                                  await CertificateService.toggleTemplateStatus(item.templateId, val);
                                  _loadTemplates();
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}

/// Global Emblem Management Dialog (Applies to all certificates)
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
                if (name != null && name.contains('.')) ext = name.split('.').last;
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
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
          content: Text('Official Diocese Logo & Parish Seal updated across ALL certificates!'),
          backgroundColor: ParishColors.oliveGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: ParishColors.cardWhite,
      title: const Row(
        children: [
          Icon(Icons.shield, color: ParishColors.marianBlue, size: 24),
          SizedBox(width: 10),
          Expanded(
            child: Text('Official Emblems', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                style: TextStyle(fontSize: 12.5, color: ParishColors.textMuted, height: 1.3),
              ),
              const Divider(height: 20),

              // 1. Diocese Crest
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
                      title: const Text('Display Diocese Logo (Left)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      value: _showDioceseLogo,
                      onChanged: (val) => setState(() => _showDioceseLogo = val),
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
                            border: Border.all(color: ParishColors.borderGrey),
                          ),
                          child: _dioceseLogoUrl != null && _dioceseLogoUrl!.isNotEmpty
                              ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(_dioceseLogoUrl!, fit: BoxFit.contain))
                              : const Center(child: Text('DSP', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ParishColors.marianBlue))),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(minimumSize: const Size(40, 40)),
                            onPressed: _isUploading ? null : () => _pickAndUploadEmblem(true),
                            icon: const Icon(Icons.upload_file, size: 16),
                            label: Text(_dioceseLogoUrl != null ? 'Replace Logo' : 'Upload Logo', style: const TextStyle(fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 2. Parish Seal
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
                      title: const Text('Display Parish Seal (Right)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      value: _showParishSeal,
                      onChanged: (val) => setState(() => _showParishSeal = val),
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
                            border: Border.all(color: ParishColors.borderGrey),
                          ),
                          child: _parishSealUrl != null && _parishSealUrl!.isNotEmpty
                              ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(_parishSealUrl!, fit: BoxFit.contain))
                              : const Center(child: Text('SJP2', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ParishColors.marianBlue))),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(minimumSize: const Size(40, 40)),
                            onPressed: _isUploading ? null : () => _pickAndUploadEmblem(false),
                            icon: const Icon(Icons.upload_file, size: 16),
                            label: Text(_parishSealUrl != null ? 'Replace Seal' : 'Upload Seal', style: const TextStyle(fontSize: 12)),
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
      actionsPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: ParishColors.marianBlue,
            foregroundColor: Colors.white,
            minimumSize: const Size(44, 44),
          ),
          onPressed: _isSaving ? null : _saveGlobalEmblems,
          icon: _isSaving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.done_all, size: 18),
          label: const Text('Apply Emblems', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

/// Dynamic Full-Scale Certificate Template Editor Modal (Responsive on phones)
class _TemplateEditorDialog extends StatefulWidget {
  final CertificateTemplateModel? initialTemplate;
  final VoidCallback onSaved;

  const _TemplateEditorDialog({this.initialTemplate, required this.onSaved});

  @override
  State<_TemplateEditorDialog> createState() => _TemplateEditorDialogState();
}

class _TemplateEditorDialogState extends State<_TemplateEditorDialog> {
  final _formKey = GlobalKey<FormState>();

  bool get isEditMode => widget.initialTemplate != null;

  late TextEditingController _nameController;
  late TextEditingController _titleController;
  late TextEditingController _headerController;
  late TextEditingController _bodyController;
  late TextEditingController _purposeController;
  late TextEditingController _signatoryNameController;
  late TextEditingController _signatoryTitleController;

  String _sacramentType = 'Baptism';
  String _paperSize = 'A4';
  String _orientation = 'Portrait';
  String _backgroundMode = 'Border';
  String? _backgroundImageUrl;
  String? _dioceseLogoUrl;
  String? _parishSealUrl;
  String? _signatureImageUrl;

  bool _showDioceseLogo = true;
  bool _showParishSeal = true;
  bool _enableQr = true;
  bool _isDefault = false;

  String _fontFamily = 'serif';
  double _titleFontSize = 16.0;
  String _titleFontWeight = 'bold';
  double _bodyFontSize = 11.5;
  String _bodyFontWeight = 'normal';
  double _bodyLineSpacing = 5.0;
  String _textAlignment = 'center';

  String _qrPosition = 'bottom-left';
  String _signatoryPosition = 'bottom-right';
  List<String> _sectionOrder = ['header', 'title', 'body', 'footer'];

  bool _useVisualCanvas = false;
  List<CertificateCanvasElement> _canvasElements = [];

  final Map<String, String> _sectionLabels = {
    'header': '1. Ecclesiastical Header (Diocese, Parish & Seals)',
    'title': '2. Certificate Title Banner (e.g. CERTIFICATE OF BAPTISM)',
    'body': '3. Canonical Narrative Body Text (with dynamic data)',
    'footer': '4. Signatory Block & QR Verification Code',
  };

  bool _isSaving = false;
  bool _isUploadingImage = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final t = widget.initialTemplate;
    _sacramentType = t?.sacramentType ?? 'Baptism';
    _nameController = TextEditingController(text: t?.templateName ?? 'Official Certificate');
    _titleController = TextEditingController(text: t?.certificateTitle ?? 'CERTIFICATE OF $_sacramentType'.toUpperCase());
    _headerController = TextEditingController(
      text: t?.headerText ?? 'Diocese of San Pablo\nSaint John Paul II Parish\nSanta Cruz, Laguna',
    );
    _bodyController = TextEditingController(text: t?.bodyWording ?? _getDefaultWordingFor(_sacramentType));
    _purposeController = TextEditingController(text: t?.defaultPurpose ?? 'For Legal / Personal Records');
    _signatoryNameController = TextEditingController(text: t?.signatoryName ?? 'Rev. Fr. Joseph Santos');
    _signatoryTitleController = TextEditingController(text: t?.signatoryTitle ?? 'Parish Priest');

    _paperSize = t?.paperSize ?? 'A4';
    _orientation = t?.orientation ?? 'Portrait';
    _backgroundMode = t?.backgroundMode ?? 'Border';
    _backgroundImageUrl = t?.backgroundImageUrl;
    _dioceseLogoUrl = t?.dioceseLogoUrl;
    _parishSealUrl = t?.parishSealUrl;
    _signatureImageUrl = t?.signatureImageUrl;

    _showDioceseLogo = t?.showDioceseLogo ?? true;
    _showParishSeal = t?.showParishSeal ?? true;
    _enableQr = t?.enableQrVerification ?? true;
    _isDefault = t?.isDefault ?? false;

    final style = t?.styleConfig ?? CertificateStyleConfig.defaultConfig;
    _fontFamily = style.fontFamily;
    _titleFontSize = style.titleFontSize;
    _titleFontWeight = style.titleFontWeight;
    _bodyFontSize = style.bodyFontSize;
    _bodyFontWeight = style.bodyFontWeight;
    _bodyLineSpacing = style.bodyLineSpacing;
    _textAlignment = style.textAlignment;
    _qrPosition = style.qrPosition;
    _signatoryPosition = style.signatoryPosition;
    _sectionOrder = List.from(style.sectionOrder);

    _useVisualCanvas = style.useVisualCanvas;
    _canvasElements = List.from(style.canvasElements);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _titleController.dispose();
    _headerController.dispose();
    _bodyController.dispose();
    _purposeController.dispose();
    _signatoryNameController.dispose();
    _signatoryTitleController.dispose();
    super.dispose();
  }

  String _getDefaultWordingFor(String sacrament) {
    return 'This is to Certify that {Full Name} received the Holy Sacrament of $sacrament on {Date Issued}.\n\nIssued upon request for {Purpose}.';
  }

  Future<void> _launchVisualDesigner() async {
    final currentModel = CertificateTemplateModel(
      templateId: widget.initialTemplate?.templateId ?? 'TPL_TEMP',
      sacramentType: _sacramentType,
      templateName: _nameController.text.trim(),
      certificateTitle: _titleController.text.trim(),
      headerText: _headerController.text.trim(),
      dioceseLogoUrl: _dioceseLogoUrl,
      parishSealUrl: _parishSealUrl,
      showDioceseLogo: _showDioceseLogo,
      showParishSeal: _showParishSeal,
      bodyWording: _bodyController.text.trim(),
      defaultPurpose: _purposeController.text.trim(),
      paperSize: _paperSize,
      orientation: _orientation,
      backgroundImageUrl: _backgroundImageUrl,
      backgroundMode: _backgroundMode,
      signatoryName: _signatoryNameController.text.trim(),
      signatoryTitle: _signatoryTitleController.text.trim(),
      signatureImageUrl: _signatureImageUrl,
      styleConfig: CertificateStyleConfig(
        fontFamily: _fontFamily,
        titleFontSize: _titleFontSize,
        titleFontWeight: _titleFontWeight,
        bodyFontSize: _bodyFontSize,
        bodyFontWeight: _bodyFontWeight,
        bodyLineSpacing: _bodyLineSpacing,
        textAlignment: _textAlignment,
        qrPosition: _qrPosition,
        signatoryPosition: _signatoryPosition,
        sectionOrder: _sectionOrder,
        useVisualCanvas: _useVisualCanvas,
        canvasElements: _canvasElements,
      ),
      enableQrVerification: _enableQr,
      isDefault: _isDefault,
    );

    final updatedElements = await Navigator.push<List<CertificateCanvasElement>>(
      context,
      MaterialPageRoute(
        builder: (_) => CertificateCanvasDesignerPage(template: currentModel),
      ),
    );

    if (updatedElements != null) {
      setState(() {
        _canvasElements = updatedElements;
        _useVisualCanvas = true;
      });
    }
  }

  void _resetToDefaultStyles() {
    setState(() {
      _fontFamily = 'serif';
      _titleFontSize = 16.0;
      _titleFontWeight = 'bold';
      _bodyFontSize = 11.5;
      _bodyFontWeight = 'normal';
      _bodyLineSpacing = 5.0;
      _textAlignment = 'center';
      _qrPosition = 'bottom-left';
      _signatoryPosition = 'bottom-right';
      _sectionOrder = ['header', 'title', 'body', 'footer'];
      _useVisualCanvas = false;
      _canvasElements = [];
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Restored standard Diocesan Simple Mode settings.')),
    );
  }

  void _insertPlaceholder(String tag) {
    final text = _bodyController.text;
    final selection = _bodyController.selection;
    if (selection.start >= 0 && selection.end >= 0) {
      final newText = text.replaceRange(selection.start, selection.end, tag);
      _bodyController.text = newText;
      _bodyController.selection = TextSelection.collapsed(offset: selection.start + tag.length);
    } else {
      _bodyController.text = '$text $tag';
    }
    setState(() {});
  }

  Future<void> _pickAndUploadAsset(String category) async {
    setState(() => _isUploadingImage = true);
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
                if (name != null && name.contains('.')) ext = name.split('.').last;
              } catch (_) {}
            }

            final url = await CertificateService.uploadCertificateAsset(
              fileBytes: bytes,
              fileExtension: ext,
              assetCategory: category,
            );

            setState(() {
              if (category == 'borders') _backgroundImageUrl = url;
              if (category == 'logos') _parishSealUrl = url;
              if (category == 'signatures') _signatureImageUrl = url;
            });
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _saveTemplate() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_useVisualCanvas) {
      final invalidPlaceholders = PlaceholderRegistry.findInvalidPlaceholders(
        _bodyController.text,
        _sacramentType,
      );

      if (invalidPlaceholders.isNotEmpty) {
        setState(() {
          _errorMessage = 'Unrecognized placeholders: ${invalidPlaceholders.join(', ')}';
        });
        return;
      }
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final tplId = widget.initialTemplate?.templateId ??
          'TPL-${_sacramentType.substring(0, 3).toUpperCase()}-${DateTime.now().millisecondsSinceEpoch % 100000}';

      final styleConfig = CertificateStyleConfig(
        fontFamily: _fontFamily,
        titleFontSize: _titleFontSize,
        titleFontWeight: _titleFontWeight,
        bodyFontSize: _bodyFontSize,
        bodyFontWeight: _bodyFontWeight,
        bodyLineSpacing: _bodyLineSpacing,
        textAlignment: _textAlignment,
        qrPosition: _qrPosition,
        signatoryPosition: _signatoryPosition,
        sectionOrder: _sectionOrder,
        useVisualCanvas: _useVisualCanvas,
        canvasElements: _canvasElements,
      );

      final model = CertificateTemplateModel(
        templateId: tplId,
        sacramentType: _sacramentType,
        templateName: _nameController.text.trim(),
        certificateTitle: _titleController.text.trim(),
        headerText: _headerController.text.trim(),
        dioceseLogoUrl: _dioceseLogoUrl,
        parishSealUrl: _parishSealUrl,
        showDioceseLogo: _showDioceseLogo,
        showParishSeal: _showParishSeal,
        bodyWording: _bodyController.text.trim(),
        defaultPurpose: _purposeController.text.trim(),
        paperSize: _paperSize,
        orientation: _orientation,
        backgroundImageUrl: _backgroundImageUrl,
        backgroundMode: _backgroundMode,
        signatoryName: _signatoryNameController.text.trim(),
        signatoryTitle: _signatoryTitleController.text.trim(),
        signatureImageUrl: _signatureImageUrl,
        styleConfig: styleConfig,
        enableQrVerification: _enableQr,
        isDefault: _isDefault,
        version: widget.initialTemplate?.version ?? 1,
      );

      if (isEditMode) {
        await CertificateService.updateTemplate(model);
      } else {
        await CertificateService.createTemplate(model);
      }

      if (!mounted) return;
      Navigator.pop(context);
      widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final cardWhite = ParishColors.cardWhite;
    final availableTags = PlaceholderRegistry.getPlaceholdersFor(_sacramentType);

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 650;
        final double dialogMaxHeight = MediaQuery.of(context).size.height * 0.85;

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: cardWhite,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  isEditMode ? 'Edit Template' : 'Create Template',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textDark),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            constraints: BoxConstraints(maxWidth: 780, maxHeight: dialogMaxHeight),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(color: ParishColors.mercyRedSurface, borderRadius: BorderRadius.circular(10), border: Border.all(color: ParishColors.mercyRed)),
                        child: Text(_errorMessage!, style: TextStyle(color: ParishColors.mercyRed, fontWeight: FontWeight.bold, fontSize: 12.5)),
                      ),
                    ],

                    // 1. Basic Metadata (Adaptive Stack on Mobile)
                    if (isMobile) ...[
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Template Name *', border: OutlineInputBorder()),
                        validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _sacramentType,
                        decoration: const InputDecoration(labelText: 'Sacrament *', border: OutlineInputBorder()),
                        items: ['Baptism', 'Confirmation', 'First Communion', 'Matrimony', 'Death', 'Conversion']
                            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: isEditMode
                            ? null
                            : (val) {
                          if (val != null) {
                            setState(() {
                              _sacramentType = val;
                              _titleController.text = 'CERTIFICATE OF $val'.toUpperCase();
                            });
                          }
                        },
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(labelText: 'Template Name *', border: OutlineInputBorder()),
                              validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              value: _sacramentType,
                              decoration: const InputDecoration(labelText: 'Sacrament *', border: OutlineInputBorder()),
                              items: ['Baptism', 'Confirmation', 'First Communion', 'Matrimony', 'Death', 'Conversion']
                                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                                  .toList(),
                              onChanged: isEditMode
                                  ? null
                                  : (val) {
                                if (val != null) {
                                  setState(() {
                                    _sacramentType = val;
                                    _titleController.text = 'CERTIFICATE OF $val'.toUpperCase();
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: 'Certificate Title * (e.g., CERTIFICATE OF BAPTISM)', border: OutlineInputBorder()),
                      validator: (v) => v!.trim().isEmpty ? 'Title is required' : null,
                    ),
                    const SizedBox(height: 16),

                    // 2. TOGGLE: SIMPLE MODE VS. CANVA VISUAL DESIGNER MODE
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _useVisualCanvas ? const Color(0xFF0F172A) : ParishColors.marianBlueSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _useVisualCanvas ? const Color(0xFF0284C7) : ParishColors.marianBlue.withOpacity(0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _useVisualCanvas ? Icons.palette_outlined : Icons.edit_note,
                            color: _useVisualCanvas ? Colors.cyanAccent : ParishColors.marianBlue,
                            size: 26,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _useVisualCanvas ? 'Visual Designer Mode (Active)' : 'Simple Mode (Recommended)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                    color: _useVisualCanvas ? Colors.white : ParishColors.marianBlue,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _useVisualCanvas
                                      ? 'Visual canvas is active (${_canvasElements.length} elements placed).'
                                      : 'Standard word-processor flow with safe canonical margins.',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: _useVisualCanvas ? Colors.white70 : textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _useVisualCanvas,
                            activeColor: Colors.cyanAccent,
                            onChanged: (val) {
                              setState(() {
                                _useVisualCanvas = val;
                              });
                              if (val && _canvasElements.isEmpty) {
                                _launchVisualDesigner();
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 3. CANVA MODE ACTIVE
                    if (_useVisualCanvas) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF0284C7)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.layers, color: Colors.cyanAccent, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Visual Canvas Mode Active',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Typography, sizes, alignments, and element coordinates are managed on the canvas.',
                              style: TextStyle(color: Colors.white70, fontSize: 11.5),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0284C7),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: _launchVisualDesigner,
                                icon: const Icon(Icons.open_in_new, size: 18),
                                label: Text(
                                  _canvasElements.isEmpty
                                      ? 'Open Canva Designer Studio'
                                      : 'Open Canva Designer (${_canvasElements.length} Elements)',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ] else ...[
                      // 4. SIMPLE MODE ACTIVE
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: ParishColors.backgroundLight,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: ParishColors.goldAccent.withOpacity(0.5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.text_format, color: ParishColors.marianBlue, size: 20),
                                    SizedBox(width: 8),
                                    Text('Formatting Toolbar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: ParishColors.marianBlue)),
                                  ],
                                ),
                                TextButton.icon(
                                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                  onPressed: _resetToDefaultStyles,
                                  icon: const Icon(Icons.restart_alt, size: 16),
                                  label: const Text('Reset', style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            DropdownButtonFormField<String>(
                              value: _fontFamily,
                              isDense: true,
                              decoration: const InputDecoration(labelText: 'Font Set', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), border: OutlineInputBorder()),
                              items: const [
                                DropdownMenuItem(value: 'serif', child: Text('Times / Classical Serif')),
                                DropdownMenuItem(value: 'sans', child: Text('Helvetica / Modern Sans')),
                                DropdownMenuItem(value: 'courier', child: Text('Courier / Typewriter')),
                                DropdownMenuItem(value: 'georgia', child: Text('Georgia / Editorial')),
                                DropdownMenuItem(value: 'garamond', child: Text('Garamond / Traditional')),
                                DropdownMenuItem(value: 'cinzel', child: Text('Roman Inscription (Cinzel)')),
                                DropdownMenuItem(value: 'script', child: Text('Chancery Script (Cursive)')),
                                DropdownMenuItem(value: 'trebuchet', child: Text('Trebuchet / Display Sans')),
                              ],
                              onChanged: (v) => setState(() => _fontFamily = v ?? 'serif'),
                            ),
                            const SizedBox(height: 12),

                            Wrap(
                              spacing: 12,
                              runSpacing: 10,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('Body: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    IconButton(
                                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                      icon: const Icon(Icons.remove_circle_outline, size: 18),
                                      onPressed: _bodyFontSize > 9.0 ? () => setState(() => _bodyFontSize -= 0.5) : null,
                                    ),
                                    Text('${_bodyFontSize.toStringAsFixed(1)} pt', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    IconButton(
                                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                      icon: const Icon(Icons.add_circle_outline, size: 18),
                                      onPressed: _bodyFontSize < 16.0 ? () => setState(() => _bodyFontSize += 0.5) : null,
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('Title: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    IconButton(
                                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                      icon: const Icon(Icons.remove_circle_outline, size: 18),
                                      onPressed: _titleFontSize > 14.0 ? () => setState(() => _titleFontSize -= 1.0) : null,
                                    ),
                                    Text('${_titleFontSize.toStringAsFixed(0)} pt', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    IconButton(
                                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                      icon: const Icon(Icons.add_circle_outline, size: 18),
                                      onPressed: _titleFontSize < 24.0 ? () => setState(() => _titleFontSize += 1.0) : null,
                                    ),
                                  ],
                                ),
                                FilterChip(
                                  label: const Text('Bold Body', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  selected: _bodyFontWeight == 'bold',
                                  onSelected: (val) => setState(() => _bodyFontWeight = val ? 'bold' : 'normal'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Floating Element Placement
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: ParishColors.backgroundLight,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: ParishColors.borderGrey),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Floating Element Anchors', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: ParishColors.marianBlue)),
                            const SizedBox(height: 10),
                            if (isMobile) ...[
                              DropdownButtonFormField<String>(
                                value: _signatoryPosition,
                                decoration: const InputDecoration(labelText: 'Signatory Block Placement', border: OutlineInputBorder()),
                                items: const [
                                  DropdownMenuItem(value: 'bottom-right', child: Text('Bottom Right (Standard)')),
                                  DropdownMenuItem(value: 'bottom-center', child: Text('Bottom Center')),
                                  DropdownMenuItem(value: 'bottom-left', child: Text('Bottom Left')),
                                ],
                                onChanged: (v) => setState(() => _signatoryPosition = v ?? 'bottom-right'),
                              ),
                              const SizedBox(height: 10),
                              DropdownButtonFormField<String>(
                                value: _qrPosition,
                                decoration: const InputDecoration(labelText: 'QR Verification Placement', border: OutlineInputBorder()),
                                items: const [
                                  DropdownMenuItem(value: 'bottom-left', child: Text('Bottom Left (Standard)')),
                                  DropdownMenuItem(value: 'bottom-center', child: Text('Bottom Center')),
                                  DropdownMenuItem(value: 'bottom-right', child: Text('Bottom Right')),
                                  DropdownMenuItem(value: 'none', child: Text('Disabled')),
                                ],
                                onChanged: (v) => setState(() => _qrPosition = v ?? 'bottom-left'),
                              ),
                            ] else ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      value: _signatoryPosition,
                                      decoration: const InputDecoration(labelText: 'Signatory Block Placement', border: OutlineInputBorder()),
                                      items: const [
                                        DropdownMenuItem(value: 'bottom-right', child: Text('Bottom Right (Standard)')),
                                        DropdownMenuItem(value: 'bottom-center', child: Text('Bottom Center')),
                                        DropdownMenuItem(value: 'bottom-left', child: Text('Bottom Left')),
                                      ],
                                      onChanged: (v) => setState(() => _signatoryPosition = v ?? 'bottom-right'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      value: _qrPosition,
                                      decoration: const InputDecoration(labelText: 'QR Verification Placement', border: OutlineInputBorder()),
                                      items: const [
                                        DropdownMenuItem(value: 'bottom-left', child: Text('Bottom Left (Standard)')),
                                        DropdownMenuItem(value: 'bottom-center', child: Text('Bottom Center')),
                                        DropdownMenuItem(value: 'bottom-right', child: Text('Bottom Right')),
                                        DropdownMenuItem(value: 'none', child: Text('Disabled')),
                                      ],
                                      onChanged: (v) => setState(() => _qrPosition = v ?? 'bottom-left'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      const Text('Certificate Wording & Dynamic Placeholders', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: ParishColors.marianBlue)),
                      const SizedBox(height: 4),
                      Text('Tap any tag below to insert it at the cursor position:', style: TextStyle(fontSize: 11.5, color: textMuted)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: availableTags.map((tag) {
                          return ActionChip(
                            label: Text(tag, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                            backgroundColor: ParishColors.goldLight,
                            side: BorderSide(color: ParishColors.goldAccent, width: 0.8),
                            onPressed: () => _insertPlaceholder(tag),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _bodyController,
                        maxLines: 6,
                        style: TextStyle(fontSize: _bodyFontSize, height: 1.4),
                        decoration: const InputDecoration(
                          labelText: 'Body Text with Dynamic Placeholders *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (!_useVisualCanvas && v!.trim().isEmpty) ? 'Body wording required in Simple Mode' : null,
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 5. Header & Seals Configuration
                    const Text('Header & Canonical Seals', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: ParishColors.marianBlue)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _headerController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Header Text (One line per row)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),

                    if (isMobile) ...[
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Diocese Logo (Left)', style: TextStyle(fontSize: 13)),
                        value: _showDioceseLogo,
                        onChanged: (v) => setState(() => _showDioceseLogo = v ?? true),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Parish Seal (Right)', style: TextStyle(fontSize: 13)),
                        value: _showParishSeal,
                        onChanged: (v) => setState(() => _showParishSeal = v ?? true),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Diocese Logo (Left)', style: TextStyle(fontSize: 13)),
                              value: _showDioceseLogo,
                              onChanged: (v) => setState(() => _showDioceseLogo = v ?? true),
                            ),
                          ),
                          Expanded(
                            child: CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Parish Seal (Right)', style: TextStyle(fontSize: 13)),
                              value: _showParishSeal,
                              onChanged: (v) => setState(() => _showParishSeal = v ?? true),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const Divider(height: 24),

                    // 6. Border & Background Customization (Wrap on phones)
                    const Text('Border / Background Frame', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: ParishColors.marianBlue)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ParishColors.backgroundLight,
                            foregroundColor: textDark,
                            minimumSize: const Size(40, 40),
                          ),
                          onPressed: _isUploadingImage ? null : () => _pickAndUploadAsset('borders'),
                          icon: const Icon(Icons.cloud_upload, size: 18),
                          label: Text(_backgroundImageUrl != null ? 'Replace Border' : 'Upload Border', style: const TextStyle(fontSize: 12.5)),
                        ),
                        const SizedBox(width: 10),
                        if (_backgroundImageUrl != null) ...[
                          const Icon(Icons.check_circle, color: ParishColors.oliveGreen, size: 18),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Row(
                              children: [
                                const Text('Attached', style: TextStyle(fontSize: 12)),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: ParishColors.mercyRed, size: 18),
                                  onPressed: () => setState(() => _backgroundImageUrl = null),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text('Mode: ', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Radio<String>(value: 'Border', groupValue: _backgroundMode, onChanged: (v) => setState(() => _backgroundMode = v!)),
                            const Text('Frame', style: TextStyle(fontSize: 12.5)),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Radio<String>(value: 'Full-Page', groupValue: _backgroundMode, onChanged: (v) => setState(() => _backgroundMode = v!)),
                            const Text('Full-Page', style: TextStyle(fontSize: 12.5)),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Radio<String>(value: 'None', groupValue: _backgroundMode, onChanged: (v) => setState(() => _backgroundMode = v!)),
                            const Text('Plain', style: TextStyle(fontSize: 12.5)),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // 7. Paper & Formatting (Adaptive Stack on Mobile)
                    if (isMobile) ...[
                      DropdownButtonFormField<String>(
                        value: _paperSize,
                        decoration: const InputDecoration(labelText: 'Paper Size', border: OutlineInputBorder()),
                        items: ['A4', 'Letter', 'Legal'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (v) => setState(() => _paperSize = v!),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: _orientation,
                        decoration: const InputDecoration(labelText: 'Orientation', border: OutlineInputBorder()),
                        items: ['Portrait', 'Landscape'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (v) => setState(() => _orientation = v!),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _paperSize,
                              decoration: const InputDecoration(labelText: 'Paper Size', border: OutlineInputBorder()),
                              items: ['A4', 'Letter', 'Legal'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                              onChanged: (v) => setState(() => _paperSize = v!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _orientation,
                              decoration: const InputDecoration(labelText: 'Orientation', border: OutlineInputBorder()),
                              items: ['Portrait', 'Landscape'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                              onChanged: (v) => setState(() => _orientation = v!),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const Divider(height: 24),

                    // 8. Signatory Configuration (Adaptive Stack on Mobile)
                    const Text('Signatory & Authority', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: ParishColors.marianBlue)),
                    const SizedBox(height: 8),
                    if (isMobile) ...[
                      TextFormField(
                        controller: _signatoryNameController,
                        decoration: const InputDecoration(labelText: 'Signatory Name *', border: OutlineInputBorder()),
                        validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _signatoryTitleController,
                        decoration: const InputDecoration(labelText: 'Signatory Title *', border: OutlineInputBorder()),
                        validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _signatoryNameController,
                              decoration: const InputDecoration(labelText: 'Signatory Name *', border: OutlineInputBorder()),
                              validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _signatoryTitleController,
                              decoration: const InputDecoration(labelText: 'Signatory Title *', border: OutlineInputBorder()),
                              validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),

                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _enableQr,
                      title: const Text('Enable QR Verification Token', style: TextStyle(fontSize: 13)),
                      onChanged: (v) => setState(() => _enableQr = v ?? true),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _isDefault,
                      title: const Text('Make Default Template for this Sacrament', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      onChanged: (v) => setState(() => _isDefault = v ?? false),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: ParishColors.marianBlue,
                foregroundColor: Colors.white,
                minimumSize: const Size(110, 44),
              ),
              onPressed: _isSaving ? null : _saveTemplate,
              icon: _isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save),
              label: Text(_isSaving ? 'Saving...' : 'Save Template'),
            ),
          ],
        );
      },
    );
  }
}