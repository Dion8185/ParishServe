import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../../../core/constants/colors.dart';
import '../../../sacramental_records/models/certificate_canvas_element.dart';
import '../../../sacramental_records/services/certificate_service.dart';
import '../../models/receipt_template_model.dart';
import '../../services/receipt_pdf_generator.dart';
import '../../services/receipt_template_service.dart';
import 'receipt_canvas_designer_page.dart';

class ReceiptTemplateManagementPage extends StatefulWidget {
  const ReceiptTemplateManagementPage({super.key});

  @override
  State<ReceiptTemplateManagementPage> createState() =>
      _ReceiptTemplateManagementPageState();
}

class _ReceiptTemplateManagementPageState
    extends State<ReceiptTemplateManagementPage> {
  List<ReceiptTemplateModel> _allTemplates = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final templates = await ReceiptTemplateService.getAllTemplates();
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

  Future<void> _duplicateTemplate(ReceiptTemplateModel template) async {
    final controller = TextEditingController(text: '${template.templateName} (Copy)');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Duplicate Receipt Template'),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: ParishColors.marianBlue,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Duplicate'),
          ),
        ],
      ),
    );

    if (confirmed == true && controller.text.trim().isNotEmpty) {
      try {
        await ReceiptTemplateService.duplicateTemplate(
          template.templateId,
          controller.text.trim(),
        );
        _loadTemplates();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Duplication error: $e')),
        );
      }
    }
  }

  Future<void> _previewTemplate(ReceiptTemplateModel template) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Preview: ${template.templateName}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
          ],
        ),
        content: SizedBox(
          width: 720,
          height: 520,
          child: PdfPreview(
            build: (format) => ReceiptPdfGenerator.generateReceiptPdf(
              receiptNumber: 'REC-2026-00891',
              payorName: 'Justin Dion Salaveria',
              payorContact: '0917-882-9912',
              relatedService: 'Baptism Registration & Mass Intention',
              transactionDetails: '• Baptism Registration Stipend @ ₱300.00\n• Thanksgiving Mass Intention @ ₱100.00\n• Sanctuary Lamp Offering @ ₱150.00',
              amount: 550.00,
              paymentMode: 'Cash',
              template: template,
            ),
            allowPrinting: true,
            allowSharing: false,
            canChangePageFormat: false,
          ),
        ),
      ),
    );
  }

  void _openTemplateEditor([ReceiptTemplateModel? template]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ReceiptTemplateEditorDialog(
        initialTemplate: template,
        onSaved: _loadTemplates,
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
        final bool isMobile = constraints.maxWidth < 600;

        return Scaffold(
          backgroundColor: ParishColors.backgroundLight,
          appBar: AppBar(
            backgroundColor: cardWhite,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: ParishColors.marianBlue, size: 26),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Receipt Template & Canvas Management',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark),
                ),
                Text(
                  'Configure layouts for Ecclesiastical (8.5×4.125 in), A4, Letter, and Legal (8.5×13 in)',
                  style: TextStyle(fontSize: 12, color: textMuted),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: ParishColors.marianBlue),
                tooltip: 'Reload Templates',
                onPressed: _loadTemplates,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ParishColors.oliveGreen,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(44, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _openTemplateEditor(),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(
                    isMobile ? 'New' : 'New Receipt Template',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(child: Text(_errorMessage!, style: const TextStyle(color: ParishColors.mercyRed)))
                : _allTemplates.isEmpty
                ? Center(
              child: Text('No receipt templates configured.', style: TextStyle(color: textMuted)),
            )
                : ListView.builder(
              padding: EdgeInsets.all(isMobile ? 12 : 20),
              itemCount: _allTemplates.length,
              itemBuilder: (context, index) {
                final item = _allTemplates[index];
                final isCanvaMode = item.styleConfig.useVisualCanvas;
                final isPlain = item.backgroundMode == 'None';

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: EdgeInsets.all(isMobile ? 14 : 18),
                  decoration: BoxDecoration(
                    color: cardWhite,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderGrey),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: ParishColors.oliveGreenSurface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.receipt_long, color: ParishColors.oliveGreen, size: 24),
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
                                    style: TextStyle(
                                      fontSize: isMobile ? 14.5 : 16,
                                      fontWeight: FontWeight.bold,
                                      color: textDark,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
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
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: textDark,
                                      ),
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
                                    isCanvaMode ? 'Visual MODE' : 'SIMPLE MODE',
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
                              'Paper: ${item.paperSize} (${item.orientation}) • ${isPlain ? "Plain (No Border)" : item.backgroundMode} • Font: ${item.styleConfig.fontFamily.toUpperCase()} • Version ${item.version}',
                              style: TextStyle(fontSize: 12.0, color: textMuted),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Title: ${item.receiptTitle} • Cashier: ${item.cashierTitle}',
                              style: TextStyle(fontSize: 11.5, color: textDark, fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                            icon: const Icon(Icons.picture_as_pdf, color: ParishColors.marianBlue),
                            tooltip: 'Preview PDF Layout',
                            onPressed: () => _previewTemplate(item),
                          ),
                          IconButton(
                            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                            icon: Icon(Icons.copy, color: textDark),
                            tooltip: 'Duplicate Template',
                            onPressed: () => _duplicateTemplate(item),
                          ),
                          IconButton(
                            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                            icon: Icon(Icons.edit, color: textDark),
                            tooltip: 'Edit Template',
                            onPressed: () => _openTemplateEditor(item),
                          ),
                          Switch(
                            value: item.isActive,
                            activeColor: ParishColors.oliveGreen,
                            onChanged: (val) async {
                              await ReceiptTemplateService.toggleTemplateStatus(item.templateId, val);
                              _loadTemplates();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

// =============================================================================
// Receipt Template Creation & Configuration Modal
// =============================================================================
class _ReceiptTemplateEditorDialog extends StatefulWidget {
  final ReceiptTemplateModel? initialTemplate;
  final VoidCallback onSaved;

  const _ReceiptTemplateEditorDialog({this.initialTemplate, required this.onSaved});

  @override
  State<_ReceiptTemplateEditorDialog> createState() => _ReceiptTemplateEditorDialogState();
}

class _ReceiptTemplateEditorDialogState extends State<_ReceiptTemplateEditorDialog> {
  final _formKey = GlobalKey<FormState>();

  bool get isEditMode => widget.initialTemplate != null;

  late TextEditingController _nameController;
  late TextEditingController _titleController;
  late TextEditingController _headerController;
  late TextEditingController _cashierTitleController;
  late TextEditingController _parishPriestController;

  String _paperSize = 'Ecclesiastical';
  String _orientation = 'Landscape';
  String _backgroundMode = 'None'; // Plain by default (no border or design)
  String? _backgroundImageUrl;
  String? _dioceseLogoUrl;
  String? _parishSealUrl;

  bool _showDioceseLogo = true;
  bool _showParishSeal = true;
  bool _enableQr = true;
  bool _isDefault = false;

  String _fontFamily = 'serif';
  double _titleFontSize = 16.0;
  String _titleFontWeight = 'bold';
  double _bodyFontSize = 10.5;
  String _bodyFontWeight = 'normal';
  double _bodyLineSpacing = 4.0;
  String _textAlignment = 'left';

  String _qrPosition = 'bottom-left';
  String _signatoryPosition = 'bottom-right';

  bool _useVisualCanvas = false;
  List<CertificateCanvasElement> _canvasElements = [];

  bool _isSaving = false;
  bool _isUploading = false;
  String? _errorMessage;

  final List<String> _paperSizeOptions = [
    'Ecclesiastical',
    'A4',
    'Letter',
    'Legal',
  ];

  @override
  void initState() {
    super.initState();
    final t = widget.initialTemplate;
    _nameController = TextEditingController(text: t?.templateName ?? 'Official Receipt Template');
    _titleController = TextEditingController(text: t?.receiptTitle ?? 'OFFICIAL RECEIPT');
    _headerController = TextEditingController(
      text: t?.headerText ?? 'Diocese of San Pablo\nSaint John Paul II Parish\nSanta Cruz, Laguna',
    );
    _cashierTitleController = TextEditingController(text: t?.cashierTitle ?? 'Parish Cashier / Secretary');
    _parishPriestController = TextEditingController(text: t?.parishPriestName ?? 'Rev. Fr. Joseph Santos');

    _paperSize = t?.paperSize ?? 'Ecclesiastical';
    _orientation = t?.orientation ?? 'Landscape';
    _backgroundMode = t?.backgroundMode ?? 'None'; // Respects 'None' as plain
    _backgroundImageUrl = t?.backgroundImageUrl;
    _dioceseLogoUrl = t?.dioceseLogoUrl;
    _parishSealUrl = t?.parishSealUrl;

    _showDioceseLogo = t?.showDioceseLogo ?? true;
    _showParishSeal = t?.showParishSeal ?? true;
    _enableQr = t?.enableQrVerification ?? true;
    _isDefault = t?.isDefault ?? false;

    final style = t?.styleConfig ?? ReceiptStyleConfig.defaultConfig;
    _fontFamily = style.fontFamily;
    _titleFontSize = style.titleFontSize;
    _titleFontWeight = style.titleFontWeight;
    _bodyFontSize = style.bodyFontSize;
    _bodyFontWeight = style.bodyFontWeight;
    _bodyLineSpacing = style.bodyLineSpacing;
    _textAlignment = style.textAlignment;
    _qrPosition = style.qrPosition;
    _signatoryPosition = style.signatoryPosition;
    _useVisualCanvas = style.useVisualCanvas;
    _canvasElements = List.from(style.canvasElements);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _titleController.dispose();
    _headerController.dispose();
    _cashierTitleController.dispose();
    _parishPriestController.dispose();
    super.dispose();
  }

  Future<void> _launchVisualDesigner() async {
    final currentModel = ReceiptTemplateModel(
      templateId: widget.initialTemplate?.templateId ?? 'TPL_TEMP',
      templateName: _nameController.text.trim(),
      receiptTitle: _titleController.text.trim(),
      headerText: _headerController.text.trim(),
      paperSize: _paperSize,
      orientation: _orientation,
      backgroundImageUrl: _backgroundImageUrl,
      backgroundMode: _backgroundMode,
      dioceseLogoUrl: _dioceseLogoUrl,
      parishSealUrl: _parishSealUrl,
      showDioceseLogo: _showDioceseLogo,
      showParishSeal: _showParishSeal,
      cashierTitle: _cashierTitleController.text.trim(),
      parishPriestName: _parishPriestController.text.trim(),
      enableQrVerification: _enableQr,
      styleConfig: ReceiptStyleConfig(
        fontFamily: _fontFamily,
        titleFontSize: _titleFontSize,
        titleFontWeight: _titleFontWeight,
        bodyFontSize: _bodyFontSize,
        bodyFontWeight: _bodyFontWeight,
        bodyLineSpacing: _bodyLineSpacing,
        textAlignment: _textAlignment,
        qrPosition: _qrPosition,
        signatoryPosition: _signatoryPosition,
        useVisualCanvas: _useVisualCanvas,
        canvasElements: _canvasElements,
      ),
      isDefault: _isDefault,
    );

    final updatedElements = await Navigator.push<List<CertificateCanvasElement>>(
      context,
      MaterialPageRoute(
        builder: (_) => ReceiptCanvasDesignerPage(template: currentModel),
      ),
    );

    if (updatedElements != null) {
      setState(() {
        _canvasElements = updatedElements;
        _useVisualCanvas = true;
      });
    }
  }

  Future<void> _pickAndUploadAsset(String category) async {
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
              assetCategory: category,
            );

            setState(() {
              if (category == 'borders') _backgroundImageUrl = url;
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

  Future<void> _saveTemplate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final tplId = widget.initialTemplate?.templateId ??
          'TPL-REC-${DateTime.now().millisecondsSinceEpoch % 100000}';

      final model = ReceiptTemplateModel(
        templateId: tplId,
        templateName: _nameController.text.trim(),
        receiptTitle: _titleController.text.trim(),
        headerText: _headerController.text.trim(),
        paperSize: _paperSize,
        orientation: _orientation,
        backgroundImageUrl: _backgroundImageUrl,
        backgroundMode: _backgroundMode,
        dioceseLogoUrl: _dioceseLogoUrl,
        parishSealUrl: _parishSealUrl,
        showDioceseLogo: _showDioceseLogo,
        showParishSeal: _showParishSeal,
        cashierTitle: _cashierTitleController.text.trim(),
        parishPriestName: _parishPriestController.text.trim(),
        enableQrVerification: _enableQr,
        styleConfig: ReceiptStyleConfig(
          fontFamily: _fontFamily,
          titleFontSize: _titleFontSize,
          titleFontWeight: _titleFontWeight,
          bodyFontSize: _bodyFontSize,
          bodyFontWeight: _bodyFontWeight,
          bodyLineSpacing: _bodyLineSpacing,
          textAlignment: _textAlignment,
          qrPosition: _qrPosition,
          signatoryPosition: _signatoryPosition,
          useVisualCanvas: _useVisualCanvas,
          canvasElements: _canvasElements,
        ),
        isDefault: _isDefault,
        version: widget.initialTemplate?.version ?? 1,
      );

      if (isEditMode) {
        await ReceiptTemplateService.updateTemplate(model);
      } else {
        await ReceiptTemplateService.createTemplate(model);
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

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: cardWhite,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            isEditMode ? 'Edit Receipt Template' : 'Create Receipt Template',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textDark),
          ),
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
        ],
      ),
      content: SizedBox(
        width: 780,
        height: 680,
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
                    decoration: BoxDecoration(
                      color: ParishColors.mercyRedSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: ParishColors.mercyRed),
                    ),
                    child: Text(_errorMessage!, style: const TextStyle(color: ParishColors.mercyRed, fontWeight: FontWeight.bold, fontSize: 12.5)),
                  ),
                ],

                // Name & Title
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
                      child: TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(labelText: 'Receipt Title Banner *', border: OutlineInputBorder()),
                        validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Dimension & Paper Size Configuration (A4, Letter, Legal 8.5x13, Ecclesiastical)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: ParishColors.backgroundLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ParishColors.borderGrey),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Paper Size & Orientation Parameters',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: ParishColors.marianBlue),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _paperSize,
                              decoration: const InputDecoration(labelText: 'Paper Size *', border: OutlineInputBorder()),
                              items: _paperSizeOptions.map((s) {
                                String label = s;
                                if (s == 'Ecclesiastical') label = 'Ecclesiastical Receipt (8.5 × 4.125 in)';
                                if (s == 'Legal') label = 'Legal (8.5 × 13 in) Folio';
                                if (s == 'Letter') label = 'Letter (8.5 × 11 in)';
                                if (s == 'A4') label = 'A4 (210 × 297 mm)';

                                return DropdownMenuItem(value: s, child: Text(label, style: const TextStyle(fontSize: 13)));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _paperSize = val;
                                    if (val == 'Ecclesiastical') _orientation = 'Landscape';
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _orientation,
                              decoration: const InputDecoration(labelText: 'Orientation *', border: OutlineInputBorder()),
                              items: const [
                                DropdownMenuItem(value: 'Landscape', child: Text('Landscape (Horizontal)')),
                                DropdownMenuItem(value: 'Portrait', child: Text('Portrait (Vertical)')),
                              ],
                              onChanged: (val) => setState(() => _orientation = val ?? 'Landscape'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // VISUAL Mode Toggle
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _useVisualCanvas ? const Color(0xFF0F172A) : ParishColors.oliveGreenSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _useVisualCanvas ? const Color(0xFF0284C7) : ParishColors.oliveGreen.withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _useVisualCanvas ? Icons.palette_outlined : Icons.receipt_long,
                        color: _useVisualCanvas ? Colors.cyanAccent : ParishColors.oliveGreen,
                        size: 26,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _useVisualCanvas ? 'Visual Canvas Active' : 'Structured Canonical Flow (Standard Voucher)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                                color: _useVisualCanvas ? Colors.white : ParishColors.textDark,
                              ),
                            ),
                            Text(
                              _useVisualCanvas
                                  ? 'Custom visual canvas is enabled (${_canvasElements.length} elements placed).'
                                  : 'Auto-adapts to A4, Letter, Legal, and Ecclesiastical voucher dimensions.',
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
                          setState(() => _useVisualCanvas = val);
                          if (val && _canvasElements.isEmpty) {
                            _launchVisualDesigner();
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (_useVisualCanvas) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 46,
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
                            ? 'Open Receipt Visual Designer'
                            : 'Open Receipt Visual Designer (${_canvasElements.length} Elements Configured)',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Header Text
                TextFormField(
                  controller: _headerController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Header Text (One line per row)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Cashier and Clergy
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _cashierTitleController,
                        decoration: const InputDecoration(labelText: 'Cashier Title *', border: OutlineInputBorder()),
                        validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _parishPriestController,
                        decoration: const InputDecoration(labelText: 'Parish Priest Name *', border: OutlineInputBorder()),
                        validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Plain vs Border / Background Styling Selector
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: ParishColors.backgroundLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ParishColors.borderGrey),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Design & Border Styling',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: ParishColors.marianBlue),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Radio<String>(
                                value: 'None',
                                groupValue: _backgroundMode,
                                onChanged: (v) => setState(() => _backgroundMode = v!),
                              ),
                              const Text('Plain Paper (No Border)'),
                            ],
                          ),
                          const SizedBox(width: 14),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Radio<String>(
                                value: 'Border',
                                groupValue: _backgroundMode,
                                onChanged: (v) => setState(() => _backgroundMode = v!),
                              ),
                              const Text('Border Frame'),
                            ],
                          ),
                          const SizedBox(width: 14),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Radio<String>(
                                value: 'Full-Page',
                                groupValue: _backgroundMode,
                                onChanged: (v) => setState(() => _backgroundMode = v!),
                              ),
                              const Text('Full-Page Background'),
                            ],
                          ),
                        ],
                      ),
                      if (_backgroundMode != 'None') ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: cardWhite,
                                foregroundColor: textDark,
                                minimumSize: const Size(44, 44),
                              ),
                              onPressed: _isUploading ? null : () => _pickAndUploadAsset('borders'),
                              icon: const Icon(Icons.cloud_upload),
                              label: Text(_backgroundImageUrl != null ? 'Replace Graphic' : 'Upload Graphic / Border'),
                            ),
                            const SizedBox(width: 12),
                            if (_backgroundImageUrl != null) ...[
                              const Icon(Icons.check_circle, color: ParishColors.oliveGreen, size: 20),
                              const SizedBox(width: 6),
                              Text('Image Attached', style: TextStyle(color: textDark, fontSize: 13)),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: ParishColors.mercyRed),
                                onPressed: () => setState(() => _backgroundImageUrl = null),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Switches
                Row(
                  children: [
                    Checkbox(value: _enableQr, onChanged: (v) => setState(() => _enableQr = v ?? true)),
                    const Text('Enable QR Verification Token on Receipt', style: TextStyle(fontSize: 13)),
                  ],
                ),
                Row(
                  children: [
                    Checkbox(value: _isDefault, onChanged: (v) => setState(() => _isDefault = v ?? false)),
                    const Text('Make this the default receipt template', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: ParishColors.marianBlue,
            foregroundColor: Colors.white,
            minimumSize: const Size(120, 44),
          ),
          onPressed: _isSaving ? null : _saveTemplate,
          icon: _isSaving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.save),
          label: Text(_isSaving ? 'Saving...' : 'Save Template'),
        ),
      ],
    );
  }
}