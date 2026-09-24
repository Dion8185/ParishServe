import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../../../core/constants/colors.dart';
import '../../models/certificate_template_model.dart';
import '../../services/certificate_pdf_generator.dart';
import '../../services/certificate_service.dart';
import '../../utils/placeholder_registry.dart';

/// Launches the interactive Official Certificate Generation Workflow
Future<void> showGenerateCertificateModal(
    BuildContext context, {
      required String sacramentType,
      required String recordId,
      required String recipientName,
      required Map<String, dynamic> rawRecordData,
      required String bookRef,
      VoidCallback? onCertificateIssued,
    }) async {
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => GenerateCertificateDialog(
      sacramentType: sacramentType,
      recordId: recordId,
      recipientName: recipientName,
      rawRecordData: rawRecordData,
      bookRef: bookRef,
      onCertificateIssued: onCertificateIssued,
    ),
  );
}

class GenerateCertificateDialog extends StatefulWidget {
  final String sacramentType;
  final String recordId;
  final String recipientName;
  final Map<String, dynamic> rawRecordData;
  final String bookRef;
  final VoidCallback? onCertificateIssued;

  const GenerateCertificateDialog({
    super.key,
    required this.sacramentType,
    required this.recordId,
    required this.recipientName,
    required this.rawRecordData,
    required this.bookRef,
    this.onCertificateIssued,
  });

  @override
  State<GenerateCertificateDialog> createState() => _GenerateCertificateDialogState();
}

class _GenerateCertificateDialogState extends State<GenerateCertificateDialog> {
  bool _isLoadingTemplates = true;
  bool _isGenerating = false;
  String? _errorMessage;

  List<CertificateTemplateModel> _availableTemplates = [];
  CertificateTemplateModel? _selectedTemplate;

  String _selectedPurposePreset = 'For Personal Records';
  final TextEditingController _customPurposeController = TextEditingController();

  String get _effectivePurpose {
    if (_selectedPurposePreset == 'Other / Custom Purpose') {
      final custom = _customPurposeController.text.trim();
      return custom.isEmpty ? 'General Legal / Personal Records' : custom;
    }
    return _selectedPurposePreset;
  }

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  @override
  void dispose() {
    _customPurposeController.dispose();
    super.dispose();
  }

  Future<void> _loadTemplates() async {
    setState(() {
      _isLoadingTemplates = true;
      _errorMessage = null;
    });

    try {
      final templates = await CertificateService.getTemplatesForSacrament(widget.sacramentType);
      if (!mounted) return;

      setState(() {
        _availableTemplates = templates;
        if (templates.isNotEmpty) {
          _selectedTemplate = templates.firstWhere(
                (t) => t.isDefault,
            orElse: () => templates.first,
          );
          if (_selectedTemplate?.defaultPurpose != null &&
              _selectedTemplate!.defaultPurpose.isNotEmpty) {
            if (PlaceholderRegistry.standardPurposes.contains(_selectedTemplate!.defaultPurpose)) {
              _selectedPurposePreset = _selectedTemplate!.defaultPurpose;
            } else {
              _selectedPurposePreset = 'Other / Custom Purpose';
              _customPurposeController.text = _selectedTemplate!.defaultPurpose;
            }
          }
        }
        _isLoadingTemplates = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load templates: $e';
        _isLoadingTemplates = false;
      });
    }
  }

  String _buildRenderedPreviewText() {
    if (_selectedTemplate == null) return '';
    final placeholderValues = PlaceholderRegistry.extractPlaceholderValues(
      sacramentType: widget.sacramentType,
      recordData: widget.rawRecordData,
      purpose: _effectivePurpose,
    );
    return PlaceholderRegistry.renderTemplate(
      _selectedTemplate!.bodyWording,
      placeholderValues,
    );
  }

  /// Launches a full-fidelity print preview modal
  Future<void> _openFullPdfPreview() async {
    if (_selectedTemplate == null) return;

    final previewVerificationId = 'PREVIEW-${DateTime.now().millisecondsSinceEpoch % 10000}';
    final previewQrUrl = CertificateService.buildVerificationUrl(previewVerificationId);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${widget.sacramentType} Certificate Preview',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            IconButton(
              onPressed: () => Navigator.pop(ctx),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        content: SizedBox(
          width: 650,
          height: 600,
          child: PdfPreview(
            build: (format) => CertificatePdfGenerator.generatePdf(
              template: _selectedTemplate!,
              sacramentType: widget.sacramentType,
              recordData: widget.rawRecordData,
              purpose: _effectivePurpose,
              verificationId: previewVerificationId,
              qrVerificationUrl: previewQrUrl,
            ),
            allowPrinting: false,
            allowSharing: false,
            canChangePageFormat: false,
          ),
        ),
      ),
    );
  }

  /// Single-pass generation: creates permanent token upfront, compiles PDF, records issuance, and prints
  Future<void> _issueAndPrintCertificate() async {
    if (_selectedTemplate == null) return;

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    try {
      final renderedWording = _buildRenderedPreviewText();

      // 1. Generate the permanent cryptographic token upfront
      final verificationId = CertificateService.generateSecureVerificationId();
      final qrVerificationUrl = CertificateService.buildVerificationUrl(verificationId);

      // 2. Compile the official print-ready PDF containing the live dynamic verification QR code
      final pdfBytes = await CertificatePdfGenerator.generatePdf(
        template: _selectedTemplate!,
        sacramentType: widget.sacramentType,
        recordData: widget.rawRecordData,
        purpose: _effectivePurpose,
        verificationId: verificationId,
        qrVerificationUrl: qrVerificationUrl,
      );

      // 3. Save the permanent issuance record in public.certificate_issuances with matching token
      final issuance = await CertificateService.issueCertificate(
        recordId: widget.recordId,
        sacramentType: widget.sacramentType,
        recipientName: widget.recipientName,
        purpose: _effectivePurpose,
        template: _selectedTemplate!,
        renderedWording: renderedWording,
        bookNumber: widget.rawRecordData['book_number']?.toString(),
        pageNumber: widget.rawRecordData['page_number']?.toString(),
        lineNumber: widget.rawRecordData['line_number']?.toString(),
        registryReference: widget.bookRef,
        generatedPdfBytes: pdfBytes,
        verificationId: verificationId,
        qrVerificationUrl: qrVerificationUrl,
      );

      if (!mounted) return;

      // 4. Close dialog and launch print engine
      Navigator.pop(context);
      widget.onCertificateIssued?.call();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Certificate ${issuance.issuanceId} issued! Launching print engine...'),
          backgroundColor: ParishColors.oliveGreen,
          duration: const Duration(seconds: 4),
        ),
      );

      await CertificatePdfGenerator.printCertificate(
        pdfBytes: pdfBytes,
        documentTitle: '${widget.sacramentType}_Certificate_${widget.recipientName.replaceAll(' ', '_')}',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isGenerating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final cardWhite = ParishColors.cardWhite;
    final borderGrey = ParishColors.borderGrey;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: cardWhite,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ParishColors.marianBlueSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.verified, color: ParishColors.marianBlue, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Generate ${widget.sacramentType} Certificate',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: textDark),
                  ),
                  Text(
                    'Record: ${widget.recordId} • ${widget.bookRef}',
                    style: TextStyle(fontSize: 12, color: textMuted),
                  ),
                ],
              ),
            ],
          ),
          IconButton(
            onPressed: _isGenerating ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      content: SizedBox(
        width: 600,
        child: _isLoadingTemplates
            ? const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(child: CircularProgressIndicator()),
        )
            : SingleChildScrollView(
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
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: ParishColors.mercyRed, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(fontSize: 12.5, color: ParishColors.mercyRed, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Recipient summary banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ParishColors.backgroundLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderGrey),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person, color: ParishColors.marianBlue, size: 20),
                    const SizedBox(width: 10),
                    Text('Recipient: ', style: TextStyle(fontSize: 13, color: textMuted)),
                    Expanded(
                      child: Text(
                        widget.recipientName,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textDark),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 1. Template Selection Dropdown
              Text('1. Certificate Template', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textDark)),
              const SizedBox(height: 6),
              DropdownButtonFormField<CertificateTemplateModel>(
                value: _selectedTemplate,
                isExpanded: true,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: ParishColors.backgroundLight,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderGrey)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderGrey)),
                ),
                items: _availableTemplates.map((t) {
                  return DropdownMenuItem(
                    value: t,
                    child: Text(
                      t.isDefault ? '${t.templateName} (Default)' : t.templateName,
                      style: TextStyle(fontSize: 13, color: textDark, fontWeight: t.isDefault ? FontWeight.bold : FontWeight.normal),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedTemplate = val);
                },
              ),
              const SizedBox(height: 16),

              // 2. Purpose Selection
              Text('2. Purpose of Certificate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textDark)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedPurposePreset,
                isExpanded: true,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: ParishColors.backgroundLight,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderGrey)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderGrey)),
                ),
                items: PlaceholderRegistry.standardPurposes.map((p) {
                  return DropdownMenuItem(
                    value: p,
                    child: Text(p, style: TextStyle(fontSize: 13, color: textDark)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedPurposePreset = val);
                },
              ),

              if (_selectedPurposePreset == 'Other / Custom Purpose') ...[
                const SizedBox(height: 10),
                TextFormField(
                  controller: _customPurposeController,
                  style: const TextStyle(fontSize: 13),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Enter specific custom purpose (e.g., For Scholarship Application)',
                    filled: true,
                    fillColor: ParishColors.backgroundLight,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
              const SizedBox(height: 18),

              // 3. Live Canonical Wording Preview Box
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('3. Rendered Certificate Wording', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textDark)),
                  TextButton.icon(
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    onPressed: _openFullPdfPreview,
                    icon: const Icon(Icons.picture_as_pdf, size: 16),
                    label: const Text('View Full PDF Layout', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: ParishColors.backgroundLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ParishColors.goldAccent.withOpacity(0.5), width: 1.2),
                ),
                child: Text(
                  _buildRenderedPreviewText(),
                  style: TextStyle(fontSize: 12.5, color: textDark, height: 1.5),
                ),
              ),
              const SizedBox(height: 8),

              // Signatory summary
              Row(
                children: [
                  Icon(Icons.draw, size: 16, color: ParishColors.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    'Signatory: ${_selectedTemplate?.signatoryName ?? "—"} (${_selectedTemplate?.signatoryTitle ?? "—"})',
                    style: TextStyle(fontSize: 11.5, color: textMuted, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      actions: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: borderGrey, width: 1.2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _isGenerating ? null : () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: textMuted, fontWeight: FontWeight.w600)),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: ParishColors.goldAccent,
            foregroundColor: Colors.white,
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          onPressed: (_isLoadingTemplates || _availableTemplates.isEmpty || _isGenerating)
              ? null
              : _issueAndPrintCertificate,
          icon: _isGenerating
              ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
          )
              : const Icon(Icons.print, size: 18),
          label: Text(
            _isGenerating ? 'Generating & Recording...' : 'Issue & Print Certificate',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
          ),
        ),
      ],
    );
  }
}