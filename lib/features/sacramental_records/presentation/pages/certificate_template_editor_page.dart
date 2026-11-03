// =============================================================================
// FILE: lib/features/sacramental_records/presentation/pages/certificate_template_editor_page.dart
// =============================================================================

import 'dart:math';
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
import '../dialogs/discard_entry_dialog.dart';
import 'certificate_canvas_designer_page.dart';

class CertificateTemplateEditorPage extends StatefulWidget {
  final CertificateTemplateModel? initialTemplate;
  final VoidCallback? onSaved;

  const CertificateTemplateEditorPage({
    super.key,
    this.initialTemplate,
    this.onSaved,
  });

  @override
  State<CertificateTemplateEditorPage> createState() =>
      _CertificateTemplateEditorPageState();
}

class _CertificateTemplateEditorPageState
    extends State<CertificateTemplateEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _bodyFocusNode = FocusNode();

  bool get isEditMode => widget.initialTemplate != null;

  late TextEditingController _nameController;
  late TextEditingController _titleController;
  late TextEditingController _headerController;
  late TextEditingController _bodyController;
  late TextEditingController _purposeController;
  late TextEditingController _signatoryNameController;
  late TextEditingController _signatoryTitleController;

  // Track cursor position accurately across focus loss
  TextSelection _lastBodySelection = const TextSelection.collapsed(offset: 0);

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

  // Simple Mode Styling
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

  // Visual Canva Designer Mode
  bool _useVisualCanvas = false;
  List<CertificateCanvasElement> _canvasElements = [];

  bool _isSaving = false;
  bool _isUploadingAsset = false;
  String? _errorMessage;

  // Placeholder category filter tab
  String _activeTagCategory = 'All';

  @override
  void initState() {
    super.initState();
    final t = widget.initialTemplate;
    _sacramentType = t?.sacramentType ?? 'Baptism';
    _nameController =
        TextEditingController(text: t?.templateName ?? 'Official Certificate');
    _titleController = TextEditingController(
        text: t?.certificateTitle ??
            'CERTIFICATE OF $_sacramentType'.toUpperCase());
    _headerController = TextEditingController(
      text: t?.headerText ??
          'Diocese of San Pablo\nSaint John Paul II Parish\nSanta Cruz, Laguna',
    );
    _bodyController = TextEditingController(
        text: t?.bodyWording ?? _getDefaultWordingFor(_sacramentType));
    _purposeController = TextEditingController(
        text: t?.defaultPurpose ?? 'For Legal / Personal Records');
    _signatoryNameController = TextEditingController(
        text: t?.signatoryName ?? 'Rev. Fr. Roy G. Reyes');
    _signatoryTitleController =
        TextEditingController(text: t?.signatoryTitle ?? 'Parish Priest');

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

    _bodyController.addListener(_updateCursorPosition);
  }

  void _updateCursorPosition() {
    if (_bodyController.selection.isValid) {
      _lastBodySelection = _bodyController.selection;
    }
  }

  @override
  void dispose() {
    _bodyController.removeListener(_updateCursorPosition);
    _scrollController.dispose();
    _bodyFocusNode.dispose();
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
    return 'This is to Certify that {Full Name} received the Holy Sacrament of $sacrament according to the Rites of the Holy Roman Catholic Church.\n\nIssued upon request for {Purpose}.';
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

  // ===========================================================================
  // Cursor-Preserving Tag Insertion (No Focus Stealing)
  // ===========================================================================

  void _insertPlaceholder(String tag) {
    final currentText = _bodyController.text;
    int insertPosition = _bodyController.selection.baseOffset;

    if (insertPosition < 0) {
      insertPosition = _lastBodySelection.baseOffset;
    }
    if (insertPosition < 0 || insertPosition > currentText.length) {
      insertPosition = currentText.length;
    }

    int endPosition = _bodyController.selection.extentOffset;
    if (endPosition < 0) {
      endPosition = _lastBodySelection.extentOffset;
    }
    if (endPosition < 0 || endPosition > currentText.length) {
      endPosition = insertPosition;
    }

    final start = min(insertPosition, endPosition);
    final end = max(insertPosition, endPosition);

    final insertion = '$tag ';
    final newText = currentText.replaceRange(start, end, insertion);
    final newCursorPos = start + insertion.length;

    _lastBodySelection = TextSelection.collapsed(offset: newCursorPos);

    _bodyController.value = TextEditingValue(
      text: newText,
      selection: _lastBodySelection,
    );

    setState(() {});

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _bodyFocusNode.requestFocus();
      }
    });
  }

  List<String> _getFilteredTags() {
    final allTags = PlaceholderRegistry.getPlaceholdersFor(_sacramentType);
    if (_activeTagCategory == 'All') return allTags;

    return allTags.where((tag) {
      final t = tag.toLowerCase();
      if (_activeTagCategory == 'Personal') {
        return t.contains('name') &&
            !t.contains('father') &&
            !t.contains('mother') &&
            !t.contains('sponsor') &&
            !t.contains('minister') &&
            !t.contains('spouse');
      }
      if (_activeTagCategory == 'Lineage') {
        return t.contains('father') ||
            t.contains('mother') ||
            t.contains('sponsor') ||
            t.contains('godfather') ||
            t.contains('godmother') ||
            t.contains('spouse');
      }
      if (_activeTagCategory == 'Liturgy') {
        return t.contains('date') ||
            t.contains('church') ||
            t.contains('minister') ||
            t.contains('place') ||
            t.contains('marriage');
      }
      if (_activeTagCategory == 'Registry') {
        return t.contains('book') ||
            t.contains('page') ||
            t.contains('line') ||
            t.contains('purpose') ||
            t.contains('reference') ||
            t.contains('issued') ||
            t.contains('record') ||
            t.contains('year');
      }
      return true;
    }).toList();
  }

  // ===========================================================================
  // Asset Uploads & Frame Preview Dialog
  // ===========================================================================

  void _showImagePreviewDialog({
    required BuildContext context,
    required String imageUrl,
    required String title,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: ParishColors.cardWhite,
        titlePadding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 22),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 620,
            maxHeight: MediaQuery.of(context).size.height * 0.70,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: ParishColors.backgroundLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ParishColors.borderGrey),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 3.5,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(color: ParishColors.marianBlue),
                    );
                  },
                  errorBuilder: (_, __, ___) => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image, size: 48, color: ParishColors.mercyRed),
                          SizedBox(height: 8),
                          Text('Failed to render image asset preview.'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close Preview'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadAsset(String category) async {
    setState(() => _isUploadingAsset = true);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isUploadingAsset = false);
    }
  }

  // ===========================================================================
  // Studio & Model Snapshots
  // ===========================================================================

  CertificateTemplateModel _buildModelSnapshot() {
    final tplId = widget.initialTemplate?.templateId ??
        'TPL-${_sacramentType.substring(0, min(3, _sacramentType.length)).toUpperCase()}-${DateTime.now().millisecondsSinceEpoch % 100000}';

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

    return CertificateTemplateModel(
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
  }

  Future<void> _launchVisualDesigner() async {
    final currentModel = _buildModelSnapshot();

    final updatedElements =
    await Navigator.push<List<CertificateCanvasElement>>(
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
      const SnackBar(
        content: Text('Restored classical Diocesan typographic defaults.'),
      ),
    );
  }

  // ===========================================================================
  // Live PDF Inspection Preview
  // ===========================================================================

  Future<void> _previewCurrentPdf() async {
    final currentModel = _buildModelSnapshot();

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
      'gender': 'Male',
      'legitimacy': 'Catholic (Cath.)',
      'father_first_name': 'Roberto',
      'father_last_name': 'Dela Cruz',
      'mother_first_name': 'Teresa',
      'mother_maiden_last_name': 'Mendoza',
      'sponsor_1_first_name': 'Pedro',
      'sponsor_1_last_name': 'Reyes',
      'sponsor_2_first_name': 'Elena',
      'sponsor_2_last_name': 'Ramos',
      'other_godparents': 'Mateo Gonzales, Sofia Ramirez',
      'date_of_baptism': '1998-06-20',
      'place_of_baptism': 'St. John Paul II Parish',
      'church_baptized': 'St. John Paul II Parish',
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
      'minister_first_name': 'Roy',
      'minister_last_name': 'Reyes',
      'solemnizer_first_name': 'Roy',
      'solemnizer_last_name': 'Reyes',
      'parish_name': 'St. John Paul II Parish',
    };

    final screenHeight = MediaQuery.of(context).size.height;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Live Inspection: ${_nameController.text.trim()}',
                style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold),
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
                template: currentModel,
                sacramentType: _sacramentType,
                recordData: sampleData,
                purpose: _purposeController.text.trim(),
                verificationId: 'PREVIEW-LIVE-TOKEN',
                qrVerificationUrl:
                '${CertificateService.verificationBaseUrl}?v=PREVIEW-LIVE-TOKEN',
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
                    Text('Rendering live certificate document...',
                        style: TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Back to Editor'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: ParishColors.marianBlue,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final pdfBytes = await CertificatePdfGenerator.generatePdf(
                template: currentModel,
                sacramentType: _sacramentType,
                recordData: sampleData,
                purpose: _purposeController.text.trim(),
                verificationId: 'PREVIEW-LIVE-TOKEN',
                qrVerificationUrl:
                '${CertificateService.verificationBaseUrl}?v=PREVIEW-LIVE-TOKEN',
              );
              await CertificatePdfGenerator.printCertificate(
                pdfBytes: pdfBytes,
                documentTitle: 'Preview_${_nameController.text.trim()}',
              );
            },
            icon: const Icon(Icons.print, size: 18),
            label: const Text('Print Preview',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Save Confirmation Dialog & Submission
  // ===========================================================================

  Future<void> _promptSaveConfirmation() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) {
      setState(() => _errorMessage = 'Please complete the highlighted required fields.');
      _scrollController.animateTo(0.0,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      return;
    }

    if (!_useVisualCanvas) {
      final invalidPlaceholders = PlaceholderRegistry.findInvalidPlaceholders(
        _bodyController.text,
        _sacramentType,
      );

      if (invalidPlaceholders.isNotEmpty) {
        setState(() {
          _errorMessage =
          'Unrecognized placeholder tags found: ${invalidPlaceholders.join(', ')}';
        });
        _scrollController.animateTo(0.0,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        return;
      }
    }

    final accentColor = _getSacramentColor(_sacramentType);

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: ParishColors.cardWhite,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.check_circle_outline, color: accentColor, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isEditMode ? 'Confirm Template Update' : 'Confirm Save Template',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.5),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEditMode
                  ? 'Update canonical certificate template "${_nameController.text.trim()}"?'
                  : 'Save new template "${_nameController.text.trim()}" to the parish library?',
              style: TextStyle(
                  fontSize: 13.5,
                  color: ParishColors.textDark.withOpacity(0.85),
                  height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ParishColors.backgroundLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ParishColors.borderGrey),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryRow('Sacrament:', _sacramentType),
                  _buildSummaryRow('Layout Mode:', _useVisualCanvas ? 'Visual Canva Designer' : 'Simple Word-Processor'),
                  _buildSummaryRow('Paper Size:', '$_paperSize ($_orientation)'),
                  _buildSummaryRow('Default Setting:', _isDefault ? 'YES (Default for $_sacramentType)' : 'No'),
                  _buildSummaryRow('QR Verification:', _enableQr ? 'Enabled' : 'Disabled'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Go Back'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.save, size: 17),
            label: Text(isEditMode ? 'Update Template' : 'Save Template'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _executeSave();
    }
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: ParishColors.textMuted)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _executeSave() async {
    setState(() => _isSaving = true);

    try {
      final model = _buildModelSnapshot();

      if (isEditMode) {
        await CertificateService.updateTemplate(model);
      } else {
        await CertificateService.createTemplate(model);
      }

      if (!mounted) return;
      widget.onSaved?.call();
      Navigator.pop(context, true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditMode
              ? 'Template "${model.templateName}" updated successfully.'
              : 'Template "${model.templateName}" registered successfully.'),
          backgroundColor: ParishColors.oliveGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isSaving = false;
      });
      _scrollController.animateTo(0.0,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
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
    final accentColor = _getSacramentColor(_sacramentType);

    return PopScope(
      canPop: !_isSaving,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_isSaving) return;
        final shouldExit = await showDiscardConfirmationDialog(
          context,
          accentColor: accentColor,
        );
        if (shouldExit && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: ParishColors.backgroundLight,
        appBar: AppBar(
          backgroundColor: cardWhite,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: accentColor, size: 26),
            onPressed: _isSaving
                ? null
                : () async {
              final shouldExit = await showDiscardConfirmationDialog(
                context,
                accentColor: accentColor,
              );
              if (shouldExit && context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEditMode
                    ? 'Edit Certificate Template'
                    : 'Create Certificate Template',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
              ),
              Text(
                isEditMode
                    ? 'Configuring Template: ${widget.initialTemplate!.templateId} • $_sacramentType'
                    : 'Diocese of San Pablo • New Canonical Template',
                style: TextStyle(fontSize: 12, color: textMuted),
              ),
            ],
          ),
          actions: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: accentColor,
                side: BorderSide(color: accentColor.withOpacity(0.5)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onPressed: _previewCurrentPdf,
              icon: const Icon(Icons.picture_as_pdf, size: 16),
              label: const Text('Live Preview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Stack(
          children: [
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final bool isDesktop = constraints.maxWidth >= 960;
                  final bool isMobile = constraints.maxWidth < 650;
                  final double horizontalPadding = isDesktop ? 32.0 : (isMobile ? 12.0 : 20.0);

                  return SingleChildScrollView(
                    controller: _scrollController,
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: 20,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: isDesktop ? 1160 : 780),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top Hero Banner
                              _buildHeaderCard(accentColor, cardWhite, borderGrey, textDark, textMuted),
                              const SizedBox(height: 16),

                              // Error Notification Banner
                              if (_errorMessage != null)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: ParishColors.mercyRedSurface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: ParishColors.mercyRed),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_outline,
                                          color: ParishColors.mercyRed, size: 22),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          _errorMessage!,
                                          style: const TextStyle(
                                            color: ParishColors.mercyRed,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              // Prominent Mode Selector
                              _buildModeSelectorSegmentedCard(accentColor, cardWhite, borderGrey, textDark, textMuted, isMobile),
                              const SizedBox(height: 16),

                              // Responsive Layout (Desktop 2-Column vs Mobile/Tablet 1-Column)
                              if (isDesktop)
                                _buildWideTwoColumnLayout(cardWhite, borderGrey, textDark, textMuted, accentColor)
                              else
                                _buildSingleColumnLayout(cardWhite, borderGrey, textDark, textMuted, accentColor, isMobile),

                              const SizedBox(height: 24),
                              _buildBottomSubmissionBar(cardWhite, borderGrey, textMuted, accentColor, isMobile),
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            if (_isSaving || _isUploadingAsset)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.55),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: ParishColors.goldAccent,
                      strokeWidth: 4.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Mode Selector Segmented Card
  // ===========================================================================

  Widget _buildModeSelectorSegmentedCard(Color accentColor, Color cardWhite,
      Color borderGrey, Color textDark, Color textMuted, bool isMobile) {
    final simpleTile = InkWell(
      onTap: () => setState(() => _useVisualCanvas = false),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: !_useVisualCanvas
              ? ParishColors.marianBlueSurface
              : ParishColors.backgroundLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: !_useVisualCanvas ? ParishColors.marianBlue : borderGrey,
            width: !_useVisualCanvas ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.edit_note,
              size: 24,
              color: !_useVisualCanvas ? ParishColors.marianBlue : textMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Simple Mode',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                      color: !_useVisualCanvas ? ParishColors.marianBlue : textDark,
                    ),
                  ),
                  Text(
                    'Standard text-editor with auto-wrapped margins.',
                    style: TextStyle(fontSize: 11, color: textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (!_useVisualCanvas)
              const Icon(Icons.check_circle, size: 18, color: ParishColors.marianBlue),
          ],
        ),
      ),
    );

    final canvaTile = InkWell(
      onTap: () {
        setState(() => _useVisualCanvas = true);
        if (_canvasElements.isEmpty) {
          _launchVisualDesigner();
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _useVisualCanvas
              ? const Color(0xFF0F172A)
              : ParishColors.backgroundLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _useVisualCanvas ? const Color(0xFF0284C7) : borderGrey,
            width: _useVisualCanvas ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.palette_outlined,
              size: 24,
              color: _useVisualCanvas ? Colors.cyanAccent : textMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Visual Canva Designer',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                      color: _useVisualCanvas ? Colors.white : textDark,
                    ),
                  ),
                  Text(
                    'Drag, resize, and position elements on a live canvas.',
                    style: TextStyle(
                      fontSize: 11,
                      color: _useVisualCanvas ? Colors.white70 : textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (_useVisualCanvas)
              const Icon(Icons.check_circle, size: 18, color: Colors.cyanAccent),
          ],
        ),
      ),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune, color: accentColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Design & Formatting Mode',
                style: TextStyle(
                    fontSize: 14.5, fontWeight: FontWeight.bold, color: textDark),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isMobile)
            Column(
              children: [
                simpleTile,
                const SizedBox(height: 10),
                canvaTile,
              ],
            )
          else
            Row(
              children: [
                Expanded(child: simpleTile),
                const SizedBox(width: 12),
                Expanded(child: canvaTile),
              ],
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Responsive Columns
  // ===========================================================================

  Widget _buildWideTwoColumnLayout(Color cardWhite, Color borderGrey,
      Color textDark, Color textMuted, Color accentColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Identification, Paper Geometry, Seals & Signatory
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGeneralIdentityCard(cardWhite, borderGrey, textDark, accentColor, false),
              const SizedBox(height: 16),
              _buildPageGeometryCard(cardWhite, borderGrey, textDark, accentColor, false),
              const SizedBox(height: 16),
              _buildHeaderAndLogosCard(cardWhite, borderGrey, textDark, textMuted, accentColor, false),
              const SizedBox(height: 16),
              _buildSignatoryCard(cardWhite, borderGrey, textDark, textMuted, accentColor, false),
            ],
          ),
        ),
        const SizedBox(width: 20),

        // Right Column: Canva Launcher OR Simple Mode Large Body Editor & Typography
        Expanded(
          flex: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_useVisualCanvas) ...[
                _buildCanvaStudioActionCard(accentColor, cardWhite, borderGrey, textDark),
              ] else ...[
                _buildLargeBodyWordingCard(cardWhite, borderGrey, textDark, textMuted, accentColor),
                const SizedBox(height: 16),
                _buildTypographyAndAnchorsCard(cardWhite, borderGrey, textDark, textMuted, accentColor, false),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSingleColumnLayout(Color cardWhite, Color borderGrey,
      Color textDark, Color textMuted, Color accentColor, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildGeneralIdentityCard(cardWhite, borderGrey, textDark, accentColor, isMobile),
        const SizedBox(height: 16),
        if (_useVisualCanvas) ...[
          _buildCanvaStudioActionCard(accentColor, cardWhite, borderGrey, textDark),
        ] else ...[
          _buildLargeBodyWordingCard(cardWhite, borderGrey, textDark, textMuted, accentColor),
          const SizedBox(height: 16),
          _buildTypographyAndAnchorsCard(cardWhite, borderGrey, textDark, textMuted, accentColor, isMobile),
        ],
        const SizedBox(height: 16),
        _buildPageGeometryCard(cardWhite, borderGrey, textDark, accentColor, isMobile),
        const SizedBox(height: 16),
        _buildHeaderAndLogosCard(cardWhite, borderGrey, textDark, textMuted, accentColor, isMobile),
        const SizedBox(height: 16),
        _buildSignatoryCard(cardWhite, borderGrey, textDark, textMuted, accentColor, isMobile),
      ],
    );
  }

  // ===========================================================================
  // Section Cards
  // ===========================================================================

  Widget _buildHeaderCard(Color accentColor, Color cardWhite, Color borderGrey,
      Color textDark, Color textMuted) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 6,
            width: double.infinity,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.design_services, color: accentColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEditMode
                            ? 'Editing: ${widget.initialTemplate!.templateName}'
                            : 'New Certificate Template',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold, color: textDark),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Customize canonical certificate wording, diocesan crests, typography, and layout settings.',
                        style: TextStyle(fontSize: 12.5, color: textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCanvaStudioActionCard(Color accentColor, Color cardWhite,
      Color borderGrey, Color textDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF0284C7), width: 1.6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withOpacity(0.25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.palette, color: Colors.cyanAccent, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Canva Designer Studio Active',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Visual drag-and-drop workspace is currently enabled.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStudioStat('Placed Elements', '${_canvasElements.length}'),
                _buildStudioStat('Paper Size', '$_paperSize ($_orientation)'),
                _buildStudioStat('Frame Border', _backgroundMode),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'In Visual Designer mode, text wording, specific font sizes, lines, and anchors are manipulated directly on the interactive visual canvas.',
            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 18),
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
              icon: const Icon(Icons.open_in_new, size: 20),
              label: Text(
                _canvasElements.isEmpty
                    ? 'Launch Canva Designer Studio'
                    : 'Open Canva Designer (${_canvasElements.length} Elements)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudioStat(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.cyanAccent,
                fontSize: 15,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10.5)),
      ],
    );
  }

  Widget _buildGeneralIdentityCard(Color cardWhite, Color borderGrey,
      Color textDark, Color accentColor, bool isMobile) {
    return _buildSectionCard(
      title: '1. Template Information',
      icon: Icons.badge_outlined,
      accentColor: accentColor,
      cardWhite: cardWhite,
      borderGrey: borderGrey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isMobile) ...[
            TextFormField(
              controller: _nameController,
              decoration: _inputDecoration(
                labelText: 'Template Name *',
                hintText: 'e.g. Official Certificate',
              ),
              validator: (v) => v!.trim().isEmpty ? 'Template name is required' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _sacramentType,
              decoration: _inputDecoration(labelText: 'Sacrament *'),
              items: [
                'Baptism',
                'Confirmation',
                'First Communion',
                'Matrimony',
                'Death',
                'Conversion'
              ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: isEditMode
                  ? null
                  : (val) {
                if (val != null) {
                  setState(() {
                    _sacramentType = val;
                    _titleController.text =
                        'CERTIFICATE OF $val'.toUpperCase();
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
                    decoration: _inputDecoration(
                      labelText: 'Template Name *',
                      hintText: 'e.g. Official Certificate',
                    ),
                    validator: (v) => v!.trim().isEmpty ? 'Template name is required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _sacramentType,
                    decoration: _inputDecoration(labelText: 'Sacrament *'),
                    items: [
                      'Baptism',
                      'Confirmation',
                      'First Communion',
                      'Matrimony',
                      'Death',
                      'Conversion'
                    ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: isEditMode
                        ? null
                        : (val) {
                      if (val != null) {
                        setState(() {
                          _sacramentType = val;
                          _titleController.text =
                              'CERTIFICATE OF $val'.toUpperCase();
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
            decoration: _inputDecoration(
              labelText: 'Certificate Title * (Shown prominently in uppercase)',
              hintText: 'e.g. CERTIFICATE OF BAPTISM',
            ),
            validator: (v) => v!.trim().isEmpty ? 'Title is required' : null,
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            activeColor: accentColor,
            value: _isDefault,
            title: const Text('Make Default Template for this Sacrament',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            subtitle: const Text(
                'Auto-selected when issuing certificates for this sacrament',
                style: TextStyle(fontSize: 11.5)),
            onChanged: (v) => setState(() => _isDefault = v ?? false),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            activeColor: accentColor,
            value: _enableQr,
            title: const Text('Enable QR Verification Token',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            subtitle: const Text(
                'Embeds verifiable digital cryptographic token matching parish database',
                style: TextStyle(fontSize: 11.5)),
            onChanged: (v) => setState(() => _enableQr = v ?? true),
          ),
        ],
      ),
    );
  }

  Widget _buildLargeBodyWordingCard(Color cardWhite, Color borderGrey,
      Color textDark, Color textMuted, Color accentColor) {
    final filteredTags = _getFilteredTags();

    return _buildSectionCard(
      title: '2. Certificate Body Wording',
      icon: Icons.text_snippet_outlined,
      accentColor: accentColor,
      cardWhite: cardWhite,
      borderGrey: borderGrey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Tap Tag to Insert at Cursor',
                style: TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.bold, color: textDark),
              ),
              Wrap(
                spacing: 4,
                children: ['All', 'Personal', 'Lineage', 'Liturgy', 'Registry'].map((cat) {
                  final isSelected = _activeTagCategory == cat;
                  return ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    selectedColor: accentColor,
                    labelStyle: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : textDark,
                    ),
                    backgroundColor: ParishColors.backgroundLight,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    visualDensity: VisualDensity.compact,
                    onSelected: (val) => setState(() => _activeTagCategory = cat),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Non-focus-stealing interactive chips container
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ParishColors.backgroundLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderGrey),
            ),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: filteredTags.map((tag) {
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _insertPlaceholder(tag),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: ParishColors.goldLight,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: ParishColors.goldAccent.withOpacity(0.8),
                            width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add, size: 12, color: ParishColors.goldAccent),
                          const SizedBox(width: 4),
                          Text(
                            tag,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF78350F),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),

          // Taller & Larger Text Field Area
          TextFormField(
            controller: _bodyController,
            focusNode: _bodyFocusNode,
            minLines: 8,
            maxLines: 18,
            onTap: () {
              if (_bodyController.selection.isValid) {
                _lastBodySelection = _bodyController.selection;
              }
            },
            onChanged: (_) {
              if (_bodyController.selection.isValid) {
                _lastBodySelection = _bodyController.selection;
              }
            },
            style: TextStyle(
              fontFamily: _fontFamily == 'cinzel' ? 'Cinzel' : null,
              fontSize: 15.0,
              height: 1.55,
              fontWeight: FontWeight.w500,
              color: ParishColors.textDark,
            ),
            decoration: _inputDecoration(
              labelText: 'Certificate Body Wording Text *',
              hintText: 'Type canonical certificate wording here...',
            ),
            validator: (v) => (!_useVisualCanvas && (v == null || v.trim().isEmpty))
                ? 'Body text is required in Simple Mode'
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildTypographyAndAnchorsCard(Color cardWhite, Color borderGrey,
      Color textDark, Color textMuted, Color accentColor, bool isMobile) {
    return _buildSectionCard(
      title: '3. Typography & Anchors',
      icon: Icons.format_shapes_outlined,
      accentColor: accentColor,
      cardWhite: cardWhite,
      borderGrey: borderGrey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isMobile) ...[
            DropdownButtonFormField<String>(
              value: _fontFamily,
              decoration: _inputDecoration(labelText: 'Font Family'),
              items: const [
                DropdownMenuItem(value: 'serif', child: Text('Classical Serif (Times)')),
                DropdownMenuItem(value: 'sans', child: Text('Modern Sans (Helvetica)')),
                DropdownMenuItem(value: 'courier', child: Text('Typewriter (Courier)')),
                DropdownMenuItem(value: 'georgia', child: Text('Georgia / Editorial')),
                DropdownMenuItem(value: 'garamond', child: Text('Garamond / Traditional')),
                DropdownMenuItem(value: 'cinzel', child: Text('Roman Inscription (Cinzel)')),
                DropdownMenuItem(value: 'script', child: Text('Chancery Script (Cursive)')),
              ],
              onChanged: (v) => setState(() => _fontFamily = v ?? 'serif'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Body Font Size: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                  onPressed: _bodyFontSize > 9.0
                      ? () => setState(() => _bodyFontSize -= 0.5)
                      : null,
                ),
                Text('${_bodyFontSize.toStringAsFixed(1)} pt',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  onPressed: _bodyFontSize < 16.0
                      ? () => setState(() => _bodyFontSize += 0.5)
                      : null,
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    value: _fontFamily,
                    decoration: _inputDecoration(labelText: 'Font Family'),
                    items: const [
                      DropdownMenuItem(value: 'serif', child: Text('Classical Serif (Times)')),
                      DropdownMenuItem(value: 'sans', child: Text('Modern Sans (Helvetica)')),
                      DropdownMenuItem(value: 'courier', child: Text('Typewriter (Courier)')),
                      DropdownMenuItem(value: 'georgia', child: Text('Georgia / Editorial')),
                      DropdownMenuItem(value: 'garamond', child: Text('Garamond / Traditional')),
                      DropdownMenuItem(value: 'cinzel', child: Text('Roman Inscription (Cinzel)')),
                      DropdownMenuItem(value: 'script', child: Text('Chancery Script (Cursive)')),
                    ],
                    onChanged: (v) => setState(() => _fontFamily = v ?? 'serif'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Row(
                    children: [
                      const Text('Body: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 18),
                        onPressed: _bodyFontSize > 9.0
                            ? () => setState(() => _bodyFontSize -= 0.5)
                            : null,
                      ),
                      Text('${_bodyFontSize.toStringAsFixed(1)} pt',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, size: 18),
                        onPressed: _bodyFontSize < 16.0
                            ? () => setState(() => _bodyFontSize += 0.5)
                            : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          if (isMobile) ...[
            DropdownButtonFormField<String>(
              value: _signatoryPosition,
              decoration: _inputDecoration(labelText: 'Signatory Block Placement'),
              items: const [
                DropdownMenuItem(value: 'bottom-right', child: Text('Bottom Right (Standard)')),
                DropdownMenuItem(value: 'bottom-center', child: Text('Bottom Center')),
                DropdownMenuItem(value: 'bottom-left', child: Text('Bottom Left')),
              ],
              onChanged: (v) => setState(() => _signatoryPosition = v ?? 'bottom-right'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _qrPosition,
              decoration: _inputDecoration(labelText: 'QR Token Placement'),
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
                    decoration: _inputDecoration(labelText: 'Signatory Block'),
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
                    decoration: _inputDecoration(labelText: 'QR Token Placement'),
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
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _resetToDefaultStyles,
              icon: const Icon(Icons.restart_alt, size: 16),
              label: const Text('Reset Typography', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageGeometryCard(Color cardWhite, Color borderGrey,
      Color textDark, Color accentColor, bool isMobile) {
    return _buildSectionCard(
      title: '4. Paper Geometry & Frame Border',
      icon: Icons.aspect_ratio_outlined,
      accentColor: accentColor,
      cardWhite: cardWhite,
      borderGrey: borderGrey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isMobile) ...[
            DropdownButtonFormField<String>(
              value: _paperSize,
              decoration: _inputDecoration(labelText: 'Paper Size'),
              items: ['A4', 'Letter', 'Legal']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _paperSize = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _orientation,
              decoration: _inputDecoration(labelText: 'Orientation'),
              items: ['Portrait', 'Landscape']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _orientation = v!),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _paperSize,
                    decoration: _inputDecoration(labelText: 'Paper Size'),
                    items: ['A4', 'Letter', 'Legal']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => setState(() => _paperSize = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _orientation,
                    decoration: _inputDecoration(labelText: 'Orientation'),
                    items: ['Portrait', 'Landscape']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => setState(() => _orientation = v!),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),

          // Uploaded frame thumbnail with instant image preview modal
          Row(
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ParishColors.backgroundLight,
                  foregroundColor: textDark,
                  minimumSize: const Size(40, 42),
                ),
                onPressed: (_isUploadingAsset || _isSaving)
                    ? null
                    : () => _pickAndUploadAsset('borders'),
                icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                label: Text(
                  _backgroundImageUrl != null ? 'Replace Frame' : 'Upload Frame',
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
              const SizedBox(width: 12),
              if (_backgroundImageUrl != null) ...[
                InkWell(
                  onTap: () => _showImagePreviewDialog(
                    context: context,
                    imageUrl: _backgroundImageUrl!,
                    title: 'Attached Certificate Frame Preview',
                  ),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: ParishColors.oliveGreen, width: 1.5),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        _backgroundImageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 20),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: ParishColors.marianBlue,
                  ),
                  onPressed: () => _showImagePreviewDialog(
                    context: context,
                    imageUrl: _backgroundImageUrl!,
                    title: 'Attached Certificate Frame Preview',
                  ),
                  icon: const Icon(Icons.visibility, size: 16),
                  label: const Text('Preview Frame', style: TextStyle(fontSize: 12)),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: ParishColors.mercyRed, size: 20),
                  tooltip: 'Remove Frame',
                  onPressed: () => setState(() => _backgroundImageUrl = null),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Non-overflowing Display Mode Radios
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              const Text('Display Mode: ', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Radio<String>(
                    value: 'Border',
                    groupValue: _backgroundMode,
                    activeColor: accentColor,
                    onChanged: (v) => setState(() => _backgroundMode = v!),
                  ),
                  const Text('Frame Border', style: TextStyle(fontSize: 12)),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Radio<String>(
                    value: 'Full-Page',
                    groupValue: _backgroundMode,
                    activeColor: accentColor,
                    onChanged: (v) => setState(() => _backgroundMode = v!),
                  ),
                  const Text('Full-Page', style: TextStyle(fontSize: 12)),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Radio<String>(
                    value: 'None',
                    groupValue: _backgroundMode,
                    activeColor: accentColor,
                    onChanged: (v) => setState(() => _backgroundMode = v!),
                  ),
                  const Text('Plain', style: TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderAndLogosCard(Color cardWhite, Color borderGrey,
      Color textDark, Color textMuted, Color accentColor, bool isMobile) {
    return _buildSectionCard(
      title: '5. Header & Ecclesial Seals',
      icon: Icons.shield_outlined,
      accentColor: accentColor,
      cardWhite: cardWhite,
      borderGrey: borderGrey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _headerController,
            maxLines: 3,
            decoration: _inputDecoration(
              labelText: 'Header Lines (One line per row)',
              hintText: 'Diocese of San Pablo\nSaint John Paul II Parish\nSanta Cruz, Laguna',
            ),
          ),
          const SizedBox(height: 12),
          if (isMobile) ...[
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              activeColor: accentColor,
              title: const Text('Show Diocese Logo', style: TextStyle(fontSize: 13)),
              value: _showDioceseLogo,
              onChanged: (v) => setState(() => _showDioceseLogo = v ?? true),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              activeColor: accentColor,
              title: const Text('Show Parish Seal', style: TextStyle(fontSize: 13)),
              value: _showParishSeal,
              onChanged: (v) => setState(() => _showParishSeal = v ?? true),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    activeColor: accentColor,
                    title: const Text('Show Diocese Logo', style: TextStyle(fontSize: 13)),
                    value: _showDioceseLogo,
                    onChanged: (v) => setState(() => _showDioceseLogo = v ?? true),
                  ),
                ),
                Expanded(
                  child: CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    activeColor: accentColor,
                    title: const Text('Show Parish Seal', style: TextStyle(fontSize: 13)),
                    value: _showParishSeal,
                    onChanged: (v) => setState(() => _showParishSeal = v ?? true),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSignatoryCard(Color cardWhite, Color borderGrey,
      Color textDark, Color textMuted, Color accentColor, bool isMobile) {
    return _buildSectionCard(
      title: '6. Signatory & Authority',
      icon: Icons.draw_outlined,
      accentColor: accentColor,
      cardWhite: cardWhite,
      borderGrey: borderGrey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isMobile) ...[
            TextFormField(
              controller: _signatoryNameController,
              decoration: _inputDecoration(
                labelText: 'Signatory Name *',
                hintText: 'Rev. Fr. Roy G. Reyes',
              ),
              validator: (v) => v!.trim().isEmpty ? 'Signatory name required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _signatoryTitleController,
              decoration: _inputDecoration(
                labelText: 'Signatory Title *',
                hintText: 'Parish Priest',
              ),
              validator: (v) => v!.trim().isEmpty ? 'Signatory title required' : null,
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _signatoryNameController,
                    decoration: _inputDecoration(
                      labelText: 'Signatory Name *',
                      hintText: 'Rev. Fr. Roy G. Reyes',
                    ),
                    validator: (v) => v!.trim().isEmpty ? 'Signatory name required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _signatoryTitleController,
                    decoration: _inputDecoration(
                      labelText: 'Signatory Title *',
                      hintText: 'Parish Priest',
                    ),
                    validator: (v) => v!.trim().isEmpty ? 'Signatory title required' : null,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          TextFormField(
            controller: _purposeController,
            decoration: _inputDecoration(
              labelText: 'Default Stated Purpose',
              hintText: 'For Legal / Personal Records',
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ParishColors.backgroundLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderGrey),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Signatory E-Signature File',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                      Text(
                        _signatureImageUrl != null
                            ? 'Electronic signature on file and rendered onto certificates.'
                            : 'No e-signature on file (Physical manual ink signing required).',
                        style: TextStyle(fontSize: 11, color: textMuted),
                      ),
                    ],
                  ),
                ),
                if (_signatureImageUrl != null) ...[
                  InkWell(
                    onTap: () => _showImagePreviewDialog(
                      context: context,
                      imageUrl: _signatureImageUrl!,
                      title: 'Signatory E-Signature Preview',
                    ),
                    child: Container(
                      height: 36,
                      width: 70,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: borderGrey),
                      ),
                      child: Image.network(_signatureImageUrl!, fit: BoxFit.contain),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(36, 36)),
                  onPressed: (_isUploadingAsset || _isSaving)
                      ? null
                      : () => _pickAndUploadAsset('signatures'),
                  icon: const Icon(Icons.upload, size: 15),
                  label: Text(_signatureImageUrl != null ? 'Replace' : 'Upload',
                      style: const TextStyle(fontSize: 11.5)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Overflow-Free Responsive Bottom Submission Bar
  // ===========================================================================

  Widget _buildBottomSubmissionBar(Color cardWhite, Color borderGrey,
      Color textMuted, Color accentColor, bool isMobile) {
    if (isMobile) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderGrey),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: borderGrey, width: 1.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isSaving
                          ? null
                          : () async {
                        final shouldExit = await showDiscardConfirmationDialog(
                          context,
                          accentColor: accentColor,
                        );
                        if (shouldExit && context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                      child: Text(
                        'Discard & Exit',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold, color: textMuted),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: accentColor,
                        side: BorderSide(color: accentColor, width: 1.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isSaving ? null : _previewCurrentPdf,
                      icon: const Icon(Icons.picture_as_pdf, size: 16),
                      label: const Text('Live Preview',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isSaving ? null : _promptSaveConfirmation,
                icon: const Icon(Icons.save, size: 19),
                label: Text(
                  isEditMode ? 'Update Template' : 'Save Template',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderGrey),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 140,
            height: 48,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: borderGrey, width: 1.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _isSaving
                  ? null
                  : () async {
                final shouldExit = await showDiscardConfirmationDialog(
                  context,
                  accentColor: accentColor,
                );
                if (shouldExit && context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: Text(
                'Discard & Exit',
                style: TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.bold, color: textMuted),
              ),
            ),
          ),
          Row(
            children: [
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: accentColor,
                    side: BorderSide(color: accentColor, width: 1.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onPressed: _isSaving ? null : _previewCurrentPdf,
                  icon: const Icon(Icons.picture_as_pdf, size: 18),
                  label: const Text('Live Preview',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 190,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isSaving ? null : _promptSaveConfirmation,
                  icon: const Icon(Icons.save, size: 19),
                  label: Text(
                    isEditMode ? 'Update Template' : 'Save Template',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color accentColor,
    required Color cardWhite,
    required Color borderGrey,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: accentColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 22),
          child,
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({String? labelText, String? hintText}) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      filled: true,
      fillColor: ParishColors.backgroundLight,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: ParishColors.borderGrey),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: ParishColors.borderGrey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _getSacramentColor(_sacramentType), width: 1.8),
      ),
    );
  }
}