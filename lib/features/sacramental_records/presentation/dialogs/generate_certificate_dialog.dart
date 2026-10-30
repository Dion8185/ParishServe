// =============================================================================
// FILE: lib/features/sacramental_records/presentation/dialogs/generate_certificate_dialog.dart
// =============================================================================

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/database/local_database_service.dart';
import '../../../receipts/models/pos_item_model.dart';
import '../../../receipts/services/particulars_service.dart';
import '../../../receipts/services/receipt_pdf_generator.dart';
import '../../../receipts/services/secretary_service.dart';
import '../../models/certificate_template_model.dart';
import '../../services/certificate_pdf_generator.dart';
import '../../services/certificate_service.dart';
import '../../utils/placeholder_registry.dart';

/// Launches the interactive Official Certificate Generation & Receipt Workflow
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
  State<GenerateCertificateDialog> createState() =>
      _GenerateCertificateDialogState();
}

class _GenerateCertificateDialogState
    extends State<GenerateCertificateDialog> {
  final _formKey = GlobalKey<FormState>();

  bool _isLoadingTemplates = true;
  bool _isGenerating = false;
  String? _errorMessage;

  List<CertificateTemplateModel> _availableTemplates = [];
  CertificateTemplateModel? _selectedTemplate;

  String _selectedPurposePreset = 'For Personal Records';
  final TextEditingController _customPurposeController =
  TextEditingController();

  // Dynamic Receipt System Particulars Integration
  List<PosItemModel> _availableCertificateParticulars = [];
  PosItemModel? _selectedParticular;
  double _resolvedFee = 150.00;
  String _resolvedServiceTitle = 'Certificate (Pabuklat)';

  bool _issueReceipt = true;
  final TextEditingController _payorNameController = TextEditingController();

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
    _payorNameController.text = widget.recipientName;
    _resolvedServiceTitle = '${widget.sacramentType} Certificate (Pabuklat)';
    _loadTemplatesAndParticulars();
  }

  @override
  void dispose() {
    _customPurposeController.dispose();
    _payorNameController.dispose();
    super.dispose();
  }

  /// Intelligent semantic matcher between sacrament type and receipt particular titles
  bool _matchesSacrament(String title, String desc, String sacramentType) {
    final t = title.toLowerCase();
    final d = desc.toLowerCase();
    final s = sacramentType.toLowerCase();

    if (t.contains(s) || d.contains(s)) return true;

    if (s.contains('bapt') || s.contains('binyag')) {
      if (t.contains('bapt') ||
          t.contains('binyag') ||
          t.contains('pabuklat') ||
          d.contains('bapt')) {
        return true;
      }
    }

    if (s.contains('confirm') || s.contains('kumpil')) {
      if (t.contains('confirm') ||
          t.contains('kumpil') ||
          d.contains('confirm')) {
        return true;
      }
    }

    if (s.contains('commun') ||
        s.contains('eucharist') ||
        s.contains('komunyon')) {
      if (t.contains('commun') ||
          t.contains('komunyon') ||
          d.contains('commun')) {
        return true;
      }
    }

    if (s.contains('matrimon') ||
        s.contains('marr') ||
        s.contains('kasal') ||
        s.contains('nuptial')) {
      if (t.contains('marr') ||
          t.contains('matrimon') ||
          t.contains('kasal') ||
          t.contains('nuptial') ||
          d.contains('marr') ||
          d.contains('matrimon')) {
        return true;
      }
    }

    if (s.contains('death') ||
        s.contains('burial') ||
        s.contains('funeral') ||
        s.contains('libing')) {
      if (t.contains('death') ||
          t.contains('burial') ||
          t.contains('funeral') ||
          t.contains('libing') ||
          d.contains('death')) {
        return true;
      }
    }

    if (s.contains('convert') || s.contains('conversion')) {
      if (t.contains('convert') ||
          t.contains('conversion') ||
          d.contains('convert')) {
        return true;
      }
    }

    return false;
  }

  Future<void> _loadTemplatesAndParticulars() async {
    setState(() {
      _isLoadingTemplates = true;
      _errorMessage = null;
    });

    List<CertificateTemplateModel> templates = [];
    List<PosItemModel> particulars = [];

    try {
      templates = await CertificateService.getTemplatesForSacrament(
        widget.sacramentType,
      );
    } catch (_) {}

    if (templates.isEmpty) {
      final db = await LocalDatabaseService.instance.database;
      if (db != null) {
        try {
          final rows = await db.query(
            'certificate_templates',
            where:
            'sacrament_type = ? AND (is_active = 1 OR is_active = "true")',
            orderBy: 'is_default DESC, created_at DESC',
          );
          if (rows.isNotEmpty) {
            templates =
                rows.map((r) => CertificateTemplateModel.fromMap(r)).toList();
          }
        } catch (_) {}
      }
    }

    if (templates.isEmpty) {
      templates = [_generateFallbackTemplate(widget.sacramentType)];
    }

    try {
      particulars =
      await ParticularsService.getParticulars(activeOnly: true);
    } catch (_) {
      particulars = [];
    }

    if (!mounted) return;

    final List<PosItemModel> certParticulars = particulars.where((p) {
      final cat = p.category.toLowerCase();
      return cat.contains('cert') ||
          _matchesSacrament(p.title, p.description, widget.sacramentType);
    }).toList();

    final candidateList =
    certParticulars.isNotEmpty ? certParticulars : particulars;

    PosItemModel? bestMatch;
    for (final p in candidateList) {
      if (_matchesSacrament(p.title, p.description, widget.sacramentType)) {
        bestMatch = p;
        break;
      }
    }

    bestMatch ??= candidateList.isNotEmpty ? candidateList.first : null;

    double dynamicFee;
    String dynamicTitle;

    if (bestMatch != null) {
      dynamicFee = bestMatch.defaultPrice;
      dynamicTitle = bestMatch.title;
    } else {
      final sacramentLower = widget.sacramentType.toLowerCase();
      dynamicFee = (sacramentLower.contains('matrimony') ||
          sacramentLower.contains('marriage'))
          ? 200.00
          : 150.00;
      dynamicTitle = '${widget.sacramentType} Certificate (Pabuklat)';
    }

    setState(() {
      _availableCertificateParticulars = candidateList;
      _selectedParticular = bestMatch;
      _resolvedFee = dynamicFee;
      _resolvedServiceTitle = dynamicTitle;
      _availableTemplates = templates;
      if (templates.isNotEmpty) {
        _selectedTemplate = templates.firstWhere(
              (t) => t.isDefault,
          orElse: () => templates.first,
        );
        if (_selectedTemplate?.defaultPurpose != null &&
            _selectedTemplate!.defaultPurpose.isNotEmpty) {
          if (PlaceholderRegistry.standardPurposes
              .contains(_selectedTemplate!.defaultPurpose)) {
            _selectedPurposePreset = _selectedTemplate!.defaultPurpose;
          } else {
            _selectedPurposePreset = 'Other / Custom Purpose';
            _customPurposeController.text = _selectedTemplate!.defaultPurpose;
          }
        }
      }
      _isLoadingTemplates = false;
    });
  }

  CertificateTemplateModel _generateFallbackTemplate(String sacrament) {
    String wording = '';
    switch (sacrament) {
      case 'Baptism':
        wording =
        'This is to Certify that {Full Name}, child of {Father Name} and {Mother Name}, born in {Place of Birth} on {Date of Birth}, was solemnly Baptized according to the Rites of the Roman Catholic Church on {Date of Baptism} by {Minister Name}.\n\nSponsors were {Sponsor 1} and {Sponsor 2}.\n\nIssued upon request for {Purpose}.';
        break;
      case 'Confirmation':
        wording =
        'This is to Certify that {Full Name}, child of {Father Name} and {Mother Name}, baptized at {Church of Baptism} on {Date of Baptism}, was solemnly Confirmed in the Catholic Faith on {Date of Confirmation} by {Minister Name}.\n\nSponsor was {Sponsor 1}.\n\nIssued upon request for {Purpose}.';
        break;
      case 'First Communion':
        wording =
        'This is to Certify that {Full Name} has received for the first time the Most Holy Body and Blood of our Lord Jesus Christ on {Date of Communion} at Saint John Paul II Parish, officiated by {Minister Name}.\n\nIssued upon request for {Purpose}.';
        break;
      case 'Matrimony':
        wording =
        'This is to Certify that {Groom Name} and {Bride Name} were united in Holy Matrimony according to the Rites of the Holy Roman Catholic Church on {Date of Marriage} by {Solemnizer Name}.\n\nWitnesses were {Sponsor 1} and {Sponsor 2}.\n\nIssued upon request for {Purpose}.';
        break;
      case 'Death':
        wording =
        'This is to Certify that {Full Name}, aged {Age}, died on {Date of Death} and was granted Christian Burial on {Date of Burial} at {Place of Burial}, with funeral rites officiated by {Minister Name}.\n\nIssued upon request for {Purpose}.';
        break;
      case 'Conversion':
        wording =
        'This is to Certify that {Full Name}, born on {Date of Birth} in {Place of Birth}, was solemnly received into Full Communion with the Catholic Church on {Date of Reception} by {Minister Name}.\n\nWitnesses were {Witness 1} and {Witness 2}.\n\nIssued upon request for {Purpose}.';
        break;
      default:
        wording =
        'This is to Certify that {Full Name} received the Sacrament of $sacrament.\n\nIssued upon request for {Purpose}.';
    }

    return CertificateTemplateModel(
      templateId: 'TPL-${sacrament.substring(0, 3).toUpperCase()}-DEFAULT',
      sacramentType: sacrament,
      templateName: '$sacrament Canonical Certificate',
      certificateTitle: 'CERTIFICATE OF ${sacrament.toUpperCase()}',
      headerText:
      'Diocese of San Pablo\nSaint John Paul II Parish\nSanta Cruz, Laguna',
      bodyWording: wording,
      defaultPurpose: 'For Legal / Personal Records',
      isDefault: true,
      paperSize: 'A4',
      orientation: 'Portrait',
      signatoryName: 'Rev. Fr. Joseph Santos',
      signatoryTitle: 'Parish Priest',
    );
  }

  void _onParticularChanged(PosItemModel? item) {
    if (item == null) return;
    setState(() {
      _selectedParticular = item;
      _resolvedFee = item.defaultPrice;
      _resolvedServiceTitle = item.title;
    });
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

  /// Clean preview dialog without distracting bottom navigation or page controls
  Future<void> _openFullPdfPreview() async {
    if (_selectedTemplate == null) return;

    final previewVerificationId =
        'PREVIEW-${DateTime.now().millisecondsSinceEpoch % 10000}';
    final previewQrUrl =
    CertificateService.buildVerificationUrl(previewVerificationId);

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
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf, color: ParishColors.marianBlue, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${widget.sacramentType} Certificate Preview',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close, size: 24),
                tooltip: 'Close Preview',
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
                  template: _selectedTemplate!,
                  sacramentType: widget.sacramentType,
                  recordData: widget.rawRecordData,
                  purpose: _effectivePurpose,
                  verificationId: previewVerificationId,
                  qrVerificationUrl: previewQrUrl,
                ),
                // UX Overhaul: Disable useless default bottom actions & toolbar controls
                useActions: false,
                allowPrinting: false,
                allowSharing: false,
                canChangePageFormat: false,
                canChangeOrientation: false,
                canDebug: false,
                loadingWidget: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: ParishColors.marianBlue),
                      const SizedBox(height: 12),
                      const Text('Rendering certificate document...', style: TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ParishColors.marianBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Looks Good / Back', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _issueAndPrintCertificate() async {
    if (_selectedTemplate == null) return;
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) return;

    // Focused loading mode: Disables all other functions entirely
    setState(() {
      _isGenerating = true;
    });

    try {
      final renderedWording = _buildRenderedPreviewText();
      final verificationId =
      CertificateService.generateSecureVerificationId();
      final qrVerificationUrl =
      CertificateService.buildVerificationUrl(verificationId);

      // 1. Compile print-ready Certificate PDF binary
      final certPdfBytes = await CertificatePdfGenerator.generatePdf(
        template: _selectedTemplate!,
        sacramentType: widget.sacramentType,
        recordData: widget.rawRecordData,
        purpose: _effectivePurpose,
        verificationId: verificationId,
        qrVerificationUrl: qrVerificationUrl,
      );

      String? linkedTransactionId;
      String? linkedReceiptNumber;
      Map<String, dynamic>? createdTxnRecord;

      // 2. Record transaction in Receipt System if requested
      if (_issueReceipt) {
        final payorName = _payorNameController.text.trim().isNotEmpty
            ? _payorNameController.text.trim()
            : widget.recipientName;

        final serviceTitle = _resolvedServiceTitle;
        final lineDetails =
            '- $serviceTitle x1\n  @ P ${_resolvedFee.toStringAsFixed(2)} = P ${_resolvedFee.toStringAsFixed(2)}';
        final remarksText =
            'Recipient: ${widget.recipientName} | Ref: ${widget.bookRef} | Purpose: $_effectivePurpose | Token: $verificationId';
        final fullDetails = '$lineDetails\nRemarks: $remarksText';

        try {
          createdTxnRecord = await SecretaryService.createTransaction(
            payorName: payorName,
            relatedService: serviceTitle,
            transactionDetails: fullDetails,
            transactionAmount: _resolvedFee,
            transactionType: 'certificate',
          );

          linkedTransactionId =
              createdTxnRecord['transaction_id']?.toString();
          linkedReceiptNumber =
              createdTxnRecord['receipt_number']?.toString();
        } catch (_) {
          linkedReceiptNumber =
          'REC-OFFLINE-${DateTime.now().millisecondsSinceEpoch % 100000}';
        }
      }

      // 3. Save Certificate Issuance Record
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
        generatedPdfBytes: certPdfBytes,
        verificationId: verificationId,
        qrVerificationUrl: qrVerificationUrl,
        transactionId: linkedTransactionId,
        receiptNumber: linkedReceiptNumber,
      );

      if (!mounted) return;

      Navigator.pop(context);
      widget.onCertificateIssued?.call();

      _showIssuanceSuccessModal(
        context: context,
        issuance: issuance,
        certPdfBytes: certPdfBytes,
        receiptRecord: createdTxnRecord,
        receiptNumber: linkedReceiptNumber,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isGenerating = false;
      });
    }
  }

  void _showIssuanceSuccessModal({
    required BuildContext context,
    required dynamic issuance,
    required Uint8List certPdfBytes,
    Map<String, dynamic>? receiptRecord,
    String? receiptNumber,
  }) {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: ParishColors.cardWhite,
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Color(0xFFDCFCE7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle,
                  color: ParishColors.oliveGreen, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Certificate Successfully Issued',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: textDark,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The official ${widget.sacramentType} certificate for "${widget.recipientName}" is recorded in parish archives.',
                style: TextStyle(
                  fontSize: 14,
                  color: textDark,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: ParishColors.backgroundLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ParishColors.borderGrey),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Issuance ID:',
                          style: TextStyle(
                            fontSize: 13,
                            color: textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          issuance.issuanceId,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: ParishColors.marianBlue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Verification Token:',
                          style: TextStyle(
                            fontSize: 13,
                            color: textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          issuance.verificationId.length > 20
                              ? '${issuance.verificationId.substring(0, 18)}...'
                              : issuance.verificationId,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: textDark,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Official Receipt No.:',
                          style: TextStyle(
                            fontSize: 13,
                            color: textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          receiptNumber != null && receiptNumber.isNotEmpty
                              ? receiptNumber
                              : 'None / Exempt',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: receiptNumber != null
                                ? ParishColors.oliveGreen
                                : ParishColors.goldAccent,
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
        actionsPadding:
        const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        actions: [
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(90, 48),
                  side: BorderSide(color: ParishColors.borderGrey, width: 1.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: Text('Done / Close',
                    style: TextStyle(color: textMuted, fontSize: 14, fontWeight: FontWeight.bold)),
              ),
              if (receiptRecord != null)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(130, 48),
                    side: const BorderSide(
                        color: ParishColors.oliveGreen, width: 1.4),
                    foregroundColor: ParishColors.oliveGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                  onPressed: () {
                    final rawAmt = receiptRecord['transaction_amount'];
                    final double parsedAmt = (rawAmt is num)
                        ? rawAmt.toDouble()
                        : (double.tryParse(rawAmt?.toString() ?? '0') ??
                        _resolvedFee);

                    ReceiptPdfGenerator.printReceipt(
                      receiptNumber: receiptRecord['receipt_number'],
                      payorName: receiptRecord['payor_name'],
                      payorContact: receiptRecord['payor_contact'],
                      relatedService: receiptRecord['related_service'],
                      transactionDetails:
                      receiptRecord['transaction_details'],
                      amount: parsedAmt,
                      paymentMode: 'Cash',
                    );
                  },
                  icon: const Icon(Icons.receipt, size: 18),
                  label: const Text('Print Receipt',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(160, 48),
                  backgroundColor: ParishColors.marianBlue,
                  foregroundColor: Colors.white,
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: () async {
                  await CertificatePdfGenerator.printCertificate(
                    pdfBytes: certPdfBytes,
                    documentTitle:
                    '${widget.sacramentType}_Certificate_${widget.recipientName.replaceAll(" ", "_")}',
                  );
                },
                icon: const Icon(Icons.print, size: 20),
                label: const Text('Print Certificate',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final cardWhite = ParishColors.cardWhite;
    final borderGrey = ParishColors.borderGrey;
    final screenHeight = MediaQuery.of(context).size.height;

    return PopScope(
      canPop: !_isGenerating,
      child: Stack(
        children: [
          AlertDialog(
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: cardWhite,
            insetPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            titlePadding: const EdgeInsets.fromLTRB(20, 18, 14, 12),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ParishColors.marianBlueSurface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.verified,
                      color: ParishColors.marianBlue, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Generate ${widget.sacramentType} Certificate',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            color: textDark),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Record: ${widget.recordId} • ${widget.bookRef}',
                        style: TextStyle(fontSize: 12.5, color: textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _isGenerating ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 24),
                  tooltip: 'Cancel',
                ),
              ],
            ),
            content: Container(
              width: double.maxFinite,
              constraints:
              BoxConstraints(maxWidth: 620, maxHeight: screenHeight * 0.78),
              child: _isLoadingTemplates
                  ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 50),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: ParishColors.marianBlue),
                      const SizedBox(height: 14),
                      Text('Loading canonical certificate templates...',
                          style: TextStyle(fontSize: 13.5, color: textDark)),
                    ],
                  ),
                ),
              )
                  : SingleChildScrollView(
                child: Form(
                  key: _formKey,
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
                              const Icon(Icons.error_outline,
                                  color: ParishColors.mercyRed, size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: ParishColors.mercyRed,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Recipient summary banner with clear high contrast
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: ParishColors.backgroundLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderGrey),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.person,
                                color: ParishColors.marianBlue, size: 22),
                            const SizedBox(width: 10),
                            Text('Recipient: ',
                                style: TextStyle(
                                    fontSize: 13.5, color: textMuted, fontWeight: FontWeight.w600)),
                            Expanded(
                              child: Text(
                                widget.recipientName,
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: textDark),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 1. Template Selection
                      Text('1. Certificate Template',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: textDark)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<CertificateTemplateModel>(
                        value: _selectedTemplate,
                        isExpanded: true,
                        decoration: _inputDecoration(),
                        items: _availableTemplates.map((t) {
                          return DropdownMenuItem(
                            value: t,
                            child: Text(
                              t.isDefault
                                  ? '${t.templateName} (Default)'
                                  : t.templateName,
                              style: TextStyle(
                                  fontSize: 13.5,
                                  color: textDark,
                                  fontWeight: t.isDefault
                                      ? FontWeight.bold
                                      : FontWeight.normal),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedTemplate = val);
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // 2. Purpose Selection
                      Text('2. Purpose of Certificate',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: textDark)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _selectedPurposePreset,
                        isExpanded: true,
                        decoration: _inputDecoration(),
                        items: PlaceholderRegistry.standardPurposes.map((p) {
                          return DropdownMenuItem(
                            value: p,
                            child: Text(p,
                                style: TextStyle(
                                    fontSize: 13.5, color: textDark),
                                overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedPurposePreset = val);
                          }
                        },
                      ),

                      if (_selectedPurposePreset ==
                          'Other / Custom Purpose') ...[
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _customPurposeController,
                          style: const TextStyle(fontSize: 14),
                          onChanged: (_) => setState(() {}),
                          decoration: _inputDecoration(
                            labelText: 'Custom Purpose Description',
                            hint: 'Enter specific purpose (e.g. Scholarship Application)',
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // 3. Dynamic Receipt System Linkage
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: ParishColors.backgroundLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: ParishColors.oliveGreen.withOpacity(0.4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.receipt_long,
                                    size: 22, color: ParishColors.oliveGreen),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '3. Record in Receipt Ledger',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: textDark),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Switch(
                                  value: _issueReceipt,
                                  activeColor: ParishColors.oliveGreen,
                                  onChanged: (val) =>
                                      setState(() => _issueReceipt = val),
                                ),
                              ],
                            ),
                            if (_issueReceipt) ...[
                              const Divider(height: 18),
                              if (_availableCertificateParticulars.length >
                                  1) ...[
                                Text(
                                  'Offering Particular Item *',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: textDark),
                                ),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<PosItemModel>(
                                  value: _selectedParticular,
                                  isExpanded: true,
                                  decoration: _inputDecoration(),
                                  items: _availableCertificateParticulars
                                      .map((p) {
                                    return DropdownMenuItem(
                                      value: p,
                                      child: Text(
                                        '${p.title} — P ${p.defaultPrice.toStringAsFixed(2)}',
                                        style: TextStyle(
                                            fontSize: 13.5, color: textDark),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: _onParticularChanged,
                                ),
                                const SizedBox(height: 12),
                              ],
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: ParishColors.oliveGreenSurface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: ParishColors.oliveGreen
                                          .withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Current Stipend Fee:',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: textDark),
                                    ),
                                    Text(
                                      'P ${_resolvedFee.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: ParishColors.oliveGreen),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                "Receipt's Payor Name *",
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: textDark),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _payorNameController,
                                style: const TextStyle(fontSize: 14),
                                decoration: _inputDecoration(
                                  hint: 'Payor / Requester Full Name',
                                ),
                                validator: (v) => _issueReceipt &&
                                    (v?.trim().isEmpty ?? true)
                                    ? 'Payor name required'
                                    : null,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 4. Live Canonical Wording Preview Box
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '4. Rendered Canonical Text',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: textDark),
                            overflow: TextOverflow.ellipsis,
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: ParishColors.marianBlue,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                            onPressed: _openFullPdfPreview,
                            icon: const Icon(Icons.picture_as_pdf, size: 18),
                            label: const Text('Inspect PDF',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold)),
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
                          border: Border.all(
                              color: ParishColors.goldAccent.withOpacity(0.5),
                              width: 1.2),
                        ),
                        child: Text(
                          _buildRenderedPreviewText(),
                          style: TextStyle(
                              fontSize: 13, color: textDark, height: 1.45),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Signatory summary
                      Row(
                        children: [
                          Icon(Icons.draw,
                              size: 17, color: textMuted),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Signatory: ${_selectedTemplate?.signatoryName ?? "—"} (${_selectedTemplate?.signatoryTitle ?? "—"})',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: textMuted,
                                  fontStyle: FontStyle.italic),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actionsPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            actions: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(100, 48),
                  side: BorderSide(color: borderGrey, width: 1.2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isGenerating ? null : () => Navigator.pop(context),
                child: Text('Cancel',
                    style: TextStyle(
                        color: textMuted, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(190, 48),
                  backgroundColor: ParishColors.goldAccent,
                  foregroundColor: Colors.white,
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                onPressed: (_isLoadingTemplates ||
                    _availableTemplates.isEmpty ||
                    _isGenerating)
                    ? null
                    : _issueAndPrintCertificate,
                icon: const Icon(Icons.print, size: 20),
                label: const Text(
                  'Issue & Print Certificate',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),

          // Non-Dismissible Focused Loading Barrier with translucent shadow background
          if (_isGenerating)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: CircularProgressIndicator(
                    color: ParishColors.goldAccent,
                    strokeWidth: 4.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint, String? labelText}) {
    return InputDecoration(
      hintText: hint,
      labelText: labelText,
      filled: true,
      fillColor: ParishColors.backgroundLight,
      isDense: true,
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
        borderSide: BorderSide(color: ParishColors.marianBlue, width: 1.8),
      ),
    );
  }
}