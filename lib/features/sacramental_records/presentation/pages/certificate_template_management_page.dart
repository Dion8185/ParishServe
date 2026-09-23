import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../../../core/constants/colors.dart';
import '../../models/certificate_canvas_element.dart';
import '../../models/certificate_style_config.dart';
import '../../models/certificate_template_model.dart';
import '../../services/certificate_pdf_generator.dart';
import '../../services/certificate_service.dart';
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
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Preview: ${template.templateName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
          ],
        ),
        content: SizedBox(
          width: 650,
          height: 600,
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
      ),
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
            Text('Certificate Template Management', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark)),
            Text('Customize designs, typography, borders, and canonical headers', style: TextStyle(fontSize: 12, color: textMuted)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: ParishColors.marianBlue),
            tooltip: 'Reload Templates',
            onPressed: _loadTemplates,
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: ParishColors.marianBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _openTemplateEditor(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Create New Template', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
      body: _isLoading
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
            padding: const EdgeInsets.all(20),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final item = list[index];
              final accent = _getSacramentColor(item.sacramentType);
              final isCanvaMode = item.styleConfig.useVisualCanvas;

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
                              Text(
                                item.templateName,
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDark),
                              ),
                              const SizedBox(width: 8),
                              if (item.isDefault)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: ParishColors.goldLight,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: ParishColors.goldAccent),
                                  ),
                                  child: Text(
                                    'DEFAULT',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ParishColors.textDark),
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
                                  isCanvaMode ? 'CANVA CANVAS' : 'SIMPLE MODE',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: isCanvaMode ? Colors.cyanAccent : ParishColors.marianBlue,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${item.sacramentType} • ${item.paperSize} (${item.orientation}) • Font: ${item.styleConfig.fontFamily.toUpperCase()} • Body: ${item.styleConfig.bodyFontSize.toInt()}pt • Version ${item.version}',
                            style: TextStyle(fontSize: 12.5, color: textMuted),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Signatory: ${item.signatoryName} (${item.signatoryTitle}) • Anchor: ${item.styleConfig.signatoryPosition}',
                            style: TextStyle(fontSize: 12, color: textDark, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.picture_as_pdf, color: ParishColors.marianBlue),
                          tooltip: 'Preview PDF Layout',
                          onPressed: () => _previewTemplate(item),
                        ),
                        IconButton(
                          icon: Icon(Icons.copy, color: ParishColors.textDark),
                          tooltip: 'Duplicate Template',
                          onPressed: () => _duplicateTemplate(item),
                        ),
                        IconButton(
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
    );
  }
}

/// Dynamic Full-Scale Certificate Template Editor Modal with Guardrailed Typography & Drag-and-Drop
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

  // Typography & Layout State (Simple Mode)
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

  // Canva-Style Advanced Mode State
  bool _useVisualCanvas = false;
  List<CertificateCanvasElement> _canvasElements = [];

  final Map<String, String> _sectionLabels = {
    'header': '1. Ecclesiastical Header (Diocese, Parish & Logos)',
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

    // Load custom style configurations
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

  /// Launches the Canva Visual Designer in a completely separate page to save RAM
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
            if (files != null && files.isNotEmpty) {
              file = files.first;
            }
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
    final availableTags = PlaceholderRegistry.getPlaceholdersFor(_sacramentType);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: ParishColors.cardWhite,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(isEditMode ? 'Edit Certificate Template' : 'Create Certificate Template', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textDark)),
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
        ],
      ),
      content: SizedBox(
        width: 800,
        height: 700,
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

                // 1. Basic Metadata
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Template Name *', border: OutlineInputBorder()),
                        validator: (v) => v!.trim().isEmpty ? 'Template name is required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
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
                              _useVisualCanvas ? 'Canva-Style Visual Designer Mode (Active)' : 'Simple Mode (Recommended for Beginners)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                                color: _useVisualCanvas ? Colors.white : ParishColors.marianBlue,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _useVisualCanvas
                                  ? 'Custom drag & drop canvas is active (${_canvasElements.length} elements placed).'
                                  : 'Standard word-processor flow with safe margins. No coordinates or complex dragging.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: _useVisualCanvas ? Colors.white70 : ParishColors.textMuted,
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

                if (_useVisualCanvas) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _launchVisualDesigner,
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: Text(
                        _canvasElements.isEmpty
                            ? 'Open Canva Visual Designer (Separate Page to Save RAM)'
                            : 'Open Canva Designer (${_canvasElements.length} Custom Elements Placed)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 3. TYPOGRAPHY & FORMATTING TOOLBAR (Always Available / Simple Mode Baseline)
                Container(
                  padding: const EdgeInsets.all(16),
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
                              Text('Typography & Formatting Toolbar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: ParishColors.marianBlue)),
                            ],
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                            onPressed: _resetToDefaultStyles,
                            icon: const Icon(Icons.restart_alt, size: 16),
                            label: const Text('Reset Defaults', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Font Family Selector
                      Row(
                        children: [
                          const SizedBox(width: 90, child: Text('Font Set:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _fontFamily,
                              isDense: true,
                              decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), border: OutlineInputBorder()),
                              items: const [
                                DropdownMenuItem(value: 'serif', child: Text('Classical Roman (Times / Serif) - Canonical Default')),
                                DropdownMenuItem(value: 'sans', child: Text('Modern Clean (Helvetica / Sans-Serif)')),
                                DropdownMenuItem(value: 'courier', child: Text('Official Typewriter (Courier / Monospace)')),
                              ],
                              onChanged: (v) => setState(() => _fontFamily = v ?? 'serif'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Sizing & Alignment Controls
                      Wrap(
                        spacing: 16,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          // Body Size Stepper
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Body Size: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, size: 20),
                                onPressed: _bodyFontSize > 9.0 ? () => setState(() => _bodyFontSize -= 0.5) : null,
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: ParishColors.borderGrey)),
                                child: Text('${_bodyFontSize.toStringAsFixed(1)} pt', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, size: 20),
                                onPressed: _bodyFontSize < 16.0 ? () => setState(() => _bodyFontSize += 0.5) : null,
                              ),
                            ],
                          ),

                          // Title Size Stepper
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Title: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, size: 20),
                                onPressed: _titleFontSize > 14.0 ? () => setState(() => _titleFontSize -= 1.0) : null,
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: ParishColors.borderGrey)),
                                child: Text('${_titleFontSize.toStringAsFixed(0)} pt', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, size: 20),
                                onPressed: _titleFontSize < 24.0 ? () => setState(() => _titleFontSize += 1.0) : null,
                              ),
                            ],
                          ),

                          // Bold Weight Toggle
                          FilterChip(
                            label: const Text('Bold Body Text', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            selected: _bodyFontWeight == 'bold',
                            onSelected: (val) => setState(() => _bodyFontWeight = val ? 'bold' : 'normal'),
                          ),

                          // Text Alignment Selector
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Align: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              ToggleButtons(
                                isSelected: [
                                  _textAlignment == 'left',
                                  _textAlignment == 'center',
                                  _textAlignment == 'justify',
                                ],
                                onPressed: (index) {
                                  setState(() {
                                    if (index == 0) _textAlignment = 'left';
                                    if (index == 1) _textAlignment = 'center';
                                    if (index == 2) _textAlignment = 'justify';
                                  });
                                },
                                constraints: const BoxConstraints(minHeight: 32, minWidth: 36),
                                borderRadius: BorderRadius.circular(8),
                                children: const [
                                  Tooltip(message: 'Left Align', child: Icon(Icons.format_align_left, size: 16)),
                                  Tooltip(message: 'Center Align (Recommended)', child: Icon(Icons.format_align_center, size: 16)),
                                  Tooltip(message: 'Justify Text', child: Icon(Icons.format_align_justify, size: 16)),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // 4. SECTION REORDERING (Active in Simple Mode)
                if (!_useVisualCanvas) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: ParishColors.cardWhite,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: ParishColors.borderGrey),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.swap_vert, color: ParishColors.marianBlue, size: 20),
                            SizedBox(width: 8),
                            Text('Section Sequence (Simple Drag Reorder)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: ParishColors.marianBlue)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('Drag handles to adjust section order without risking margin overlap:', style: TextStyle(fontSize: 12, color: textMuted)),
                        const SizedBox(height: 10),
                        ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _sectionOrder.length,
                          onReorder: (oldIndex, newIndex) {
                            setState(() {
                              if (oldIndex < newIndex) newIndex -= 1;
                              final item = _sectionOrder.removeAt(oldIndex);
                              _sectionOrder.insert(newIndex, item);
                            });
                          },
                          itemBuilder: (context, index) {
                            final key = _sectionOrder[index];
                            return Container(
                              key: ValueKey(key),
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: ParishColors.backgroundLight,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: ParishColors.borderGrey),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.layers, size: 18, color: ParishColors.marianBlue.withOpacity(0.7)),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text(_sectionLabels[key] ?? key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5))),
                                  const Icon(Icons.drag_handle, color: Colors.grey),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                ],

                // 5. ANCHOR POSITIONING FOR FLOATING ELEMENTS
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ParishColors.backgroundLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: ParishColors.borderGrey),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.anchor, color: ParishColors.marianBlue, size: 20),
                          SizedBox(width: 8),
                          Text('Floating Element Placement & Anchors', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: ParishColors.marianBlue)),
                        ],
                      ),
                      const SizedBox(height: 10),
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
                              decoration: const InputDecoration(labelText: 'QR Code Verification Placement', border: OutlineInputBorder()),
                              items: const [
                                DropdownMenuItem(value: 'bottom-left', child: Text('Bottom Left (Standard)')),
                                DropdownMenuItem(value: 'bottom-center', child: Text('Bottom Center')),
                                DropdownMenuItem(value: 'bottom-right', child: Text('Bottom Right')),
                                DropdownMenuItem(value: 'none', child: Text('Hidden / Disabled')),
                              ],
                              onChanged: (v) => setState(() => _qrPosition = v ?? 'bottom-left'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 28),

                // 6. Header & Logos
                const Text('Header & Ecclesiastical Identification', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: ParishColors.marianBlue)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _headerController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Header Text (One line per row)',
                    helperText: 'Default: Diocese of San Pablo / Saint John Paul II Parish / Santa Cruz, Laguna',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
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
                const Divider(height: 28),

                // 7. Border & Background Customization
                const Text('Certificate Border / Background Design', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: ParishColors.marianBlue)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: ParishColors.backgroundLight, foregroundColor: textDark),
                      onPressed: _isUploadingImage ? null : () => _pickAndUploadAsset('borders'),
                      icon: const Icon(Icons.cloud_upload),
                      label: Text(_backgroundImageUrl != null ? 'Replace Border Image' : 'Upload Border Image'),
                    ),
                    const SizedBox(width: 12),
                    if (_backgroundImageUrl != null) ...[
                      const Icon(Icons.check_circle, color: ParishColors.oliveGreen, size: 20),
                      const SizedBox(width: 6),
                      Text('Image Uploaded', style: TextStyle(color: textDark, fontSize: 13)),
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: ParishColors.mercyRed),
                        tooltip: 'Remove Custom Image',
                        onPressed: () => setState(() => _backgroundImageUrl = null),
                      ),
                    ] else
                      Text('Using Classical Double-Line Vector Border', style: TextStyle(fontSize: 12, color: textMuted)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Display Mode: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    Radio<String>(value: 'Border', groupValue: _backgroundMode, onChanged: (v) => setState(() => _backgroundMode = v!)),
                    const Text('Border Frame'),
                    Radio<String>(value: 'Full-Page', groupValue: _backgroundMode, onChanged: (v) => setState(() => _backgroundMode = v!)),
                    const Text('Full-Page Background'),
                  ],
                ),
                const Divider(height: 28),

                // 8. Paper & Formatting
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
                const Divider(height: 28),

                // 9. Narrative Wording & Dynamic Placeholders
                const Text('Certificate Wording & Dynamic Placeholders', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: ParishColors.marianBlue)),
                const SizedBox(height: 4),
                Text('Tap any tag below to insert it at the cursor position:', style: TextStyle(fontSize: 12, color: textMuted)),
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
                  maxLines: 7,
                  style: TextStyle(
                    fontSize: _bodyFontSize,
                    fontWeight: _bodyFontWeight == 'bold' ? FontWeight.bold : FontWeight.normal,
                    fontFamily: _fontFamily == 'courier' ? 'monospace' : null,
                    height: 1.4,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Body Text with Dynamic Placeholders *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v!.trim().isEmpty ? 'Body wording is required' : null,
                ),
                const Divider(height: 28),

                // 10. Signatory Configuration
                const Text('Signatory & Authority', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: ParishColors.marianBlue)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _signatoryNameController,
                        decoration: const InputDecoration(labelText: 'Signatory Name *', border: OutlineInputBorder()),
                        validator: (v) => v!.trim().isEmpty ? 'Signatory name required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _signatoryTitleController,
                        decoration: const InputDecoration(labelText: 'Signatory Title *', border: OutlineInputBorder()),
                        validator: (v) => v!.trim().isEmpty ? 'Signatory title required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Checkbox(value: _enableQr, onChanged: (v) => setState(() => _enableQr = v ?? true)),
                    const Text('Enable Cryptographic QR Verification Token', style: TextStyle(fontSize: 13)),
                  ],
                ),
                Row(
                  children: [
                    Checkbox(value: _isDefault, onChanged: (v) => setState(() => _isDefault = v ?? false)),
                    const Text('Make this the default template for this sacrament', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: ParishColors.marianBlue, foregroundColor: Colors.white),
          onPressed: _isSaving ? null : _saveTemplate,
          icon: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save),
          label: Text(_isSaving ? 'Saving Template...' : 'Save Template'),
        ),
      ],
    );
  }
}