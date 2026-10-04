// =============================================================================
// FILE: lib/features/sacramental_records/presentation/dialogs/pabuklat_requests_modal.dart (PART 1 OF 2)
// =============================================================================

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/colors.dart';
import '../../../auth/services/auth_service.dart';
import '../../../receipts/models/pos_item_model.dart';
import '../../../receipts/presentation/dialogs/receipt_detail_dialog.dart';
import '../../../receipts/services/particulars_service.dart';
import '../../../receipts/services/secretary_service.dart';
import '../../models/certificate_template_model.dart';
import '../../services/certificate_pdf_generator.dart';
import '../../services/certificate_service.dart';
import '../../services/pabuklat_service.dart';

void showPabuklatRequestsModal(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => const PabuklatRequestsModal(),
  );
}

class PabuklatRequestsModal extends StatefulWidget {
  const PabuklatRequestsModal({super.key});

  @override
  State<PabuklatRequestsModal> createState() => _PabuklatRequestsModalState();
}

class _PabuklatRequestsModalState extends State<PabuklatRequestsModal> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _requests = [];
  String? _errorMessage;

  String? _priestStoredSignatureUrl;
  bool _isUploadingPriestSignature = false;

  bool get _isSecretary =>
      AuthService.currentUser?.userRole.toLowerCase() == 'secretary' ||
          AuthService.currentUser?.userRole.toLowerCase() == 'admin' ||
          AuthService.currentUser?.userRole.toLowerCase() == 'superadmin';

  bool get _isParishPriest =>
      AuthService.currentUser?.userRole.toLowerCase() == 'parishpriest';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Extracts exclusively the clean certificate purpose text, stripping out any
  /// legacy relationship labels or matched record IDs so they never appear on the certificate.
  static String _extractCleanPurpose(dynamic rawDetails) {
    if (rawDetails == null) return 'For Legal / Personal Records';
    final text = rawDetails.toString().trim();
    if (text.isEmpty) return 'For Legal / Personal Records';

    for (final line in text.split('\n')) {
      final clean = line.trim();
      if (clean.toLowerCase().startsWith('purpose:')) {
        final extracted = clean.substring(8).trim();
        if (extracted.isNotEmpty) return extracted;
      }
    }

    final filteredLines = text
        .split('\n')
        .where((l) =>
    !l.toLowerCase().startsWith('relationship:') &&
        !l.toLowerCase().startsWith('matched record id:'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (filteredLines.isNotEmpty) {
      return filteredLines.join('\n');
    }
    return 'For Legal / Personal Records';
  }

  /// Matches the requested sacrament with the managed particulars catalog item
  static bool _matchesSacrament(String title, String desc, String sacramentType) {
    final t = title.toLowerCase();
    final d = desc.toLowerCase();
    final s = sacramentType.toLowerCase();

    if (t.contains(s) || d.contains(s)) return true;

    if (s.contains('bapt') || s.contains('binyag')) {
      if (t.contains('bapt') || t.contains('binyag') || t.contains('pabuklat') || d.contains('bapt')) return true;
    }
    if (s.contains('confirm') || s.contains('kumpil')) {
      if (t.contains('confirm') || t.contains('kumpil') || d.contains('confirm')) return true;
    }
    if (s.contains('commun') || s.contains('eucharist') || s.contains('komunyon')) {
      if (t.contains('commun') || t.contains('komunyon') || d.contains('commun')) return true;
    }
    if (s.contains('matrimon') || s.contains('marr') || s.contains('kasal') || s.contains('nuptial')) {
      if (t.contains('marr') || t.contains('matrimon') || t.contains('kasal') || t.contains('nuptial') || d.contains('marr') || d.contains('matrimon')) return true;
    }
    if (s.contains('death') || s.contains('burial') || s.contains('funeral') || s.contains('libing')) {
      if (t.contains('death') || t.contains('burial') || t.contains('funeral') || t.contains('libing') || d.contains('death')) return true;
    }
    if (s.contains('convert') || s.contains('conversion')) {
      if (t.contains('convert') || t.contains('conversion') || d.contains('convert')) return true;
    }

    return false;
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final client = Supabase.instance.client;
      final response = await client
          .from('service_requests')
          .select()
          .order('created_at', ascending: false);

      final priestSig = await PabuklatService.getPriestReusableSignature();

      if (!mounted) return;
      setState(() {
        _requests = List<Map<String, dynamic>>.from(response)
            .where((r) => (r['service_type'] ?? '').toString().toLowerCase().contains('pabuklat') ||
            r['sacrament_type'] != null)
            .toList();
        _priestStoredSignatureUrl = priestSig;
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

  // ===========================================================================
  // 1. Certificate PDF Verification Preview (For Secretary & Parish Priest)
  // ===========================================================================

  Future<void> _previewCertificatePdf(Map<String, dynamic> request) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator(color: ParishColors.marianBlue)),
    );

    try {
      final client = Supabase.instance.client;
      final String sacramentType = (request['sacrament_type'] ?? 'Baptism').toString();
      final String recordId = (request['record_id'] ?? '').toString();

      String tableName = 'baptism_records';
      if (sacramentType == 'Confirmation') tableName = 'confirmation_records';
      if (sacramentType == 'First Communion') tableName = 'first_communion_records';
      if (sacramentType == 'Matrimony') tableName = 'matrimony_records';
      if (sacramentType == 'Death') tableName = 'death_records';
      if (sacramentType == 'Conversion') tableName = 'conversion_records';

      final recordResponse = await client
          .from(tableName)
          .select()
          .eq('record_id', recordId)
          .maybeSingle();

      final recordData = recordResponse != null
          ? Map<String, dynamic>.from(recordResponse)
          : <String, dynamic>{'record_id': recordId};

      final template = await CertificateService.getDefaultTemplate(sacramentType) ??
          CertificateTemplateModel(
            templateId: 'TPL-DEF',
            sacramentType: sacramentType,
            templateName: 'Standard Certificate',
            bodyWording: 'This is to certify that {Full Name} received the Holy Sacrament.',
          );

      final isRemote = (request['signature_method'] ?? 'physical').toString().toLowerCase() == 'remote_esignature';
      final priestSigUrl = request['priest_signature_url']?.toString() ?? _priestStoredSignatureUrl;

      final CertificateTemplateModel effectiveTemplate = template.copyWith(
        signatureImageUrl: isRemote ? priestSigUrl : null,
      );

      final verificationId = 'VERIFY-${request["service_request_id"]}';
      final qrUrl = CertificateService.buildVerificationUrl(verificationId);
      final cleanPurpose = _extractCleanPurpose(request['service_request_details']);

      if (mounted) Navigator.pop(context); // Dismiss loading dialog

      final screenHeight = MediaQuery.of(context).size.height;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Certificate PDF Inspection ($sacramentType)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Request: ${request["service_request_id"]} • Record ID: $recordId',
                      style: TextStyle(fontSize: 11.5, color: ParishColors.textMuted),
                    ),
                  ],
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
                template: effectiveTemplate,
                sacramentType: sacramentType,
                recordData: recordData,
                purpose: cleanPurpose,
                verificationId: verificationId,
                qrVerificationUrl: qrUrl,
              ),
              allowPrinting: false,
              allowSharing: false,
              canChangePageFormat: false,
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close Preview')),
          ],
        ),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Preview error: $e'), backgroundColor: ParishColors.mercyRed),
      );
    }
  }

  // ===========================================================================
  // 2. Inspect Uploaded Verification ID (Private Bucket Signed URL)
  // ===========================================================================

  Future<void> _inspectRequestorId(String? idPath, String requesterName) async {
    if (idPath == null || idPath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No verification ID was uploaded for this request.'),
          backgroundColor: ParishColors.goldAccent,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator(color: ParishColors.marianBlue)),
    );

    final signedUrl = await PabuklatService.getSignedIdUrl(idPath);
    if (mounted) Navigator.pop(context);

    if (!mounted || signedUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not access ID document. The 72-hour retention period may have expired.'),
          backgroundColor: ParishColors.mercyRed,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: ParishColors.cardWhite,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Verification ID Inspection', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('Requestor: $requesterName', style: TextStyle(fontSize: 12, color: ParishColors.textMuted)),
                ],
              ),
            ),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
          ],
        ),
        content: SizedBox(
          width: 580,
          height: 480,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              signedUrl,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const Center(child: CircularProgressIndicator(color: ParishColors.marianBlue));
              },
              errorBuilder: (_, __, ___) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.broken_image, size: 48, color: ParishColors.mercyRed),
                    const SizedBox(height: 8),
                    Text('Failed to render ID image preview.', style: TextStyle(color: ParishColors.textMuted)),
                  ],
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
        ],
      ),
    );
  }

  // ===========================================================================
  // 3. Secretary Approval & Signature Routing Dialog
  // ===========================================================================

  Future<void> _openSecretaryApprovalDialog(Map<String, dynamic> request) async {
    DateTime selectedPickupDate = DateTime.now().add(const Duration(days: 3));
    String selectedMethod = 'physical';

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isPhysical = selectedMethod == 'physical';

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: ParishColors.cardWhite,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: ParishColors.oliveGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.verified, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Secretary Approval & Routing', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.5)),
                ),
              ],
            ),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Request: ${request['service_request_id']} • ${request['service_type']}',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ParishColors.marianBlue),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Requestor: ${request['requester_name']} (${request['relationship_to_recipient'] ?? "Self"})',
                      style: TextStyle(fontSize: 12, color: ParishColors.textMuted),
                    ),
                    const Divider(height: 20),

                    Text('1. Set Certificate Pickup / Release Date *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ParishColors.textDark)),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedPickupDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 90)),
                        );
                        if (picked != null) {
                          setModalState(() => selectedPickupDate = picked);
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
                              selectedPickupDate.toIso8601String().substring(0, 10),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                            ),
                            const Icon(Icons.calendar_today, size: 18, color: ParishColors.marianBlue),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    Text('2. Signature Method', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ParishColors.textDark)),
                    const SizedBox(height: 4),
                    Text(
                      'Determine whether the Parish Priest is physically present or requires remote e-signature approval:',
                      style: TextStyle(fontSize: 11.5, color: ParishColors.textMuted, height: 1.35),
                    ),
                    const SizedBox(height: 10),

                    InkWell(
                      onTap: () => setModalState(() => selectedMethod = 'physical'),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isPhysical ? ParishColors.marianBlueSurface : ParishColors.backgroundLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isPhysical ? ParishColors.marianBlue : ParishColors.borderGrey,
                            width: isPhysical ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Radio<String>(
                              value: 'physical',
                              groupValue: selectedMethod,
                              activeColor: ParishColors.marianBlue,
                              onChanged: (v) => setModalState(() => selectedMethod = v!),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Physical Parish Priest Signature', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Parish Priest is physically present in the parish office. E-signature is not required; print certificate with blank signature line for manual ink sign.',
                                    style: TextStyle(fontSize: 11, color: ParishColors.textMuted, height: 1.3),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    InkWell(
                      onTap: () => setModalState(() => selectedMethod = 'remote_esignature'),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: !isPhysical ? ParishColors.goldLight : ParishColors.backgroundLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: !isPhysical ? ParishColors.goldAccent : ParishColors.borderGrey,
                            width: !isPhysical ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Radio<String>(
                              value: 'remote_esignature',
                              groupValue: selectedMethod,
                              activeColor: ParishColors.goldAccent,
                              onChanged: (v) => setModalState(() => selectedMethod = v!),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Remote Parish Priest E-Signature Workflow', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Parish Priest is not physically available. Forwards request to Priest for remote review and approval using their stored reusable e-signature.',
                                    style: TextStyle(fontSize: 11, color: ParishColors.textMuted, height: 1.3),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPhysical ? ParishColors.oliveGreen : ParishColors.goldAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                icon: Icon(isPhysical ? Icons.check : Icons.forward_to_inbox, size: 18),
                label: Text(
                  isPhysical ? 'Approve (Physical Signature)' : 'Approve & Forward to Priest',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed == true) {
      try {
        await PabuklatService.approveRequestBySecretary(
          serviceRequestId: request['service_request_id'],
          pickupDate: selectedPickupDate,
          signatureMethod: selectedMethod,
        );

        _loadAllData();
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(selectedMethod == 'physical'
                ? 'Request approved! Pickup date assigned. Ready for physical signature.'
                : 'Request approved & forwarded to Parish Priest for remote e-signature.'),
            backgroundColor: ParishColors.oliveGreen,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error approving request: $e'), backgroundColor: ParishColors.mercyRed),
        );
      }
    }
  }

  // ===========================================================================
  // 4. Parish Priest Remote Approval & E-Signature Signing
  // ===========================================================================

  Future<void> _handlePriestRemoteSign(Map<String, dynamic> request) async {
    if (_priestStoredSignatureUrl == null || _priestStoredSignatureUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload your reusable e-signature first before signing.'),
          backgroundColor: ParishColors.mercyRed,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Apply Reusable E-Signature?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Affix your stored electronic signature to certificate request ${request['service_request_id']} (${request['service_type']})?'),
            const SizedBox(height: 12),
            Container(
              height: 60,
              width: double.infinity,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ParishColors.borderGrey),
              ),
              child: Image.network(_priestStoredSignatureUrl!, fit: BoxFit.contain),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: ParishColors.oliveGreen, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.draw, size: 16),
            label: const Text('Sign & Approve'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await PabuklatService.signAndApproveByPriest(
          serviceRequestId: request['service_request_id'],
          priestSignatureUrl: _priestStoredSignatureUrl!,
        );

        _loadAllData();
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('E-Signature applied! Certificate is now cleared and ready for printing.'),
            backgroundColor: ParishColors.oliveGreen,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error applying signature: $e'), backgroundColor: ParishColors.mercyRed),
        );
      }
    }
  }

  // ===========================================================================
  // 5. Parish Priest Reusable E-Signature Upload & Management
  // ===========================================================================

  Future<void> _uploadPriestSignature() async {
    final priestId = AuthService.currentUser?.userId;
    if (priestId == null) return;

    setState(() => _isUploadingPriestSignature = true);

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

          String fileName = 'priest_sig.png';
          try {
            fileName = (file as dynamic).name ?? 'priest_sig.png';
          } catch (_) {}

          if (bytes != null) {
            final url = await PabuklatService.updatePriestReusableSignature(
              priestUserId: priestId,
              fileBytes: bytes,
              fileName: fileName,
            );

            setState(() {
              _priestStoredSignatureUrl = url;
            });

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Reusable Parish Priest E-Signature updated successfully!'),
                  backgroundColor: ParishColors.oliveGreen,
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading signature: $e'), backgroundColor: ParishColors.mercyRed),
      );
    } finally {
      if (mounted) setState(() => _isUploadingPriestSignature = false);
    }
  }

  // ===========================================================================
  // 6. Rejection Handler
  // ===========================================================================

  Future<void> _rejectRequest(Map<String, dynamic> request) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reject Certificate Request', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: reasonController,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Reason for Rejection *', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ParishColors.mercyRed, foregroundColor: Colors.white),
            onPressed: () {
              if (reasonController.text.trim().isNotEmpty) Navigator.pop(ctx, true);
            },
            child: const Text('Reject Request'),
          ),
        ],
      ),
    );

    if (confirmed == true && reasonController.text.trim().isNotEmpty) {
      try {
        await PabuklatService.rejectRequest(
          serviceRequestId: request['service_request_id'],
          reason: reasonController.text.trim(),
        );

        _loadAllData();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request marked as rejected.'),
            backgroundColor: ParishColors.mercyRed,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error rejecting request: $e'), backgroundColor: ParishColors.mercyRed),
        );
      }
    }
  }

// =============================================================================
// FILE: lib/features/sacramental_records/presentation/dialogs/pabuklat_requests_modal.dart (PART 2 OF 2)
// =============================================================================

  // ===========================================================================
  // 7. Certificate Printing & Verification Engine
  // ===========================================================================

  Future<void> _handlePrintCertificate(Map<String, dynamic> request) async {
    final isReady = PabuklatService.validatePrintReadiness(request);
    if (!isReady) {
      final method = (request['signature_method'] ?? 'physical').toString().toLowerCase();
      final status = (request['request_status'] ?? '').toString().toLowerCase();

      String warningMessage = 'Certificate is not cleared for printing.';
      if (status == 'submitted') {
        warningMessage = 'Secretary approval and pickup date are required before printing.';
      } else if (method == 'remote_esignature' && status == 'forwarded_to_priest') {
        warningMessage = 'Cannot print: Awaiting Parish Priest remote e-signature approval.';
      } else if (request['pickup_date'] == null) {
        warningMessage = 'Please assign a certificate pickup date before printing.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(warningMessage),
          backgroundColor: ParishColors.goldAccent,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator(color: ParishColors.marianBlue)),
    );

    try {
      final client = Supabase.instance.client;
      final String sacramentType = (request['sacrament_type'] ?? 'Baptism').toString();
      final String recordId = (request['record_id'] ?? '').toString();

      String tableName = 'baptism_records';
      if (sacramentType == 'Confirmation') tableName = 'confirmation_records';
      if (sacramentType == 'First Communion') tableName = 'first_communion_records';
      if (sacramentType == 'Matrimony') tableName = 'matrimony_records';
      if (sacramentType == 'Death') tableName = 'death_records';
      if (sacramentType == 'Conversion') tableName = 'conversion_records';

      final recordResponse = await client
          .from(tableName)
          .select()
          .eq('record_id', recordId)
          .maybeSingle();

      final recordData = recordResponse != null
          ? Map<String, dynamic>.from(recordResponse)
          : <String, dynamic>{'record_id': recordId};

      final template = await CertificateService.getDefaultTemplate(sacramentType) ??
          CertificateTemplateModel(
            templateId: 'TPL-DEF',
            sacramentType: sacramentType,
            templateName: 'Standard Certificate',
            bodyWording: 'This is to certify that {Full Name} received the Holy Sacrament.',
          );

      final isRemote = (request['signature_method'] ?? 'physical').toString().toLowerCase() == 'remote_esignature';
      final priestSigUrl = request['priest_signature_url']?.toString() ?? _priestStoredSignatureUrl;

      final CertificateTemplateModel effectiveTemplate = template.copyWith(
        signatureImageUrl: isRemote ? priestSigUrl : null,
      );

      final verificationId = CertificateService.generateSecureVerificationId();
      final qrUrl = CertificateService.buildVerificationUrl(verificationId);

      // Clean purpose without relationship and matched record ID strings
      final cleanPurpose = _extractCleanPurpose(request['service_request_details']);

      final pdfBytes = await CertificatePdfGenerator.generatePdf(
        template: effectiveTemplate,
        sacramentType: sacramentType,
        recordData: recordData,
        purpose: cleanPurpose,
        verificationId: verificationId,
        qrVerificationUrl: qrUrl,
      );

      if (mounted) Navigator.pop(context);

      await CertificatePdfGenerator.printCertificate(
        pdfBytes: pdfBytes,
        documentTitle: '${sacramentType}_Certificate_${request["requester_name"]}',
      );

      await PabuklatService.markCertificatePrinted(request['service_request_id']);
      _loadAllData();
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Print error: $e'), backgroundColor: ParishColors.mercyRed),
      );
    }
  }

  // ===========================================================================
  // 8. Mark Released: Auto-Links to Receipt System with Managed Particulars Price
  // ===========================================================================

  Future<void> _handleMarkReleased(Map<String, dynamic> request) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator(color: ParishColors.marianBlue)),
    );

    double resolvedPrice = 150.0;
    String serviceTitle = '${request["sacrament_type"] ?? "Sacrament"} Certificate';

    try {
      final String sacramentType = (request['sacrament_type'] ?? 'Baptism').toString();
      final particulars = await ParticularsService.getParticulars(activeOnly: true);

      PosItemModel? matchedParticular;
      for (final p in particulars) {
        if (_matchesSacrament(p.title, p.description, sacramentType)) {
          matchedParticular = p;
          break;
        }
      }

      if (matchedParticular != null) {
        resolvedPrice = matchedParticular.defaultPrice;
        serviceTitle = matchedParticular.title;
      } else {
        final sLower = sacramentType.toLowerCase();
        resolvedPrice = (sLower.contains('matrimony') || sLower.contains('marriage')) ? 200.0 : 150.0;
        serviceTitle = '$sacramentType Certificate (Pabuklat)';
      }
    } catch (_) {}

    if (mounted) Navigator.pop(context); // Dismiss loading

    String selectedPaymentMode = 'Cash';
    final gcashRefController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: ParishColors.cardWhite,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: ParishColors.oliveGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.receipt_long, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Release & Issue Receipt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.5)),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Releasing: ${request["service_type"]} (${request["service_request_id"]})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ParishColors.marianBlue),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Claimant: ${request["requester_name"]} (${request["relationship_to_recipient"] ?? "Self"})',
                    style: TextStyle(fontSize: 12, color: ParishColors.textMuted),
                  ),
                  const Divider(height: 20),

                  // Managed Particulars Auto-Price Callout
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: ParishColors.oliveGreen.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              serviceTitle,
                              style:  TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                            ),
                            const Text('Auto-priced from Managed Particulars catalog', style: TextStyle(fontSize: 10.5, color: ParishColors.oliveGreen)),
                          ],
                        ),
                        Text(
                          selectedPaymentMode == 'Gratis' ? '₱ 0.00' : '₱ ${resolvedPrice.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ParishColors.oliveGreen),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text('Payment Mode *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedPaymentMode,
                    decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                    items: const [
                      DropdownMenuItem(value: 'Cash', child: Text('Cash (Secretariat Desk)')),
                      DropdownMenuItem(value: 'GCash', child: Text('GCash (E-Wallet)')),
                      DropdownMenuItem(value: 'Gratis', child: Text('Gratis (Canonically Exempt)')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => selectedPaymentMode = val);
                      }
                    },
                  ),

                  if (selectedPaymentMode == 'GCash') ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: gcashRefController,
                      decoration: const InputDecoration(
                        labelText: 'GCash Reference Number *',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: ParishColors.oliveGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: () {
                if (selectedPaymentMode == 'GCash' && gcashRefController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Please enter GCash Reference Number')),
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              },
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Confirm Release & Issue Receipt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      try {
        final double finalAmount = selectedPaymentMode == 'Gratis' ? 0.0 : resolvedPrice;
        final cleanPurpose = _extractCleanPurpose(request['service_request_details']);
        final lineDetails = '• $serviceTitle x1\n  @ ₱${resolvedPrice.toStringAsFixed(2)} = ₱${finalAmount.toStringAsFixed(2)}';
        String fullDetails = '$lineDetails\nPurpose: $cleanPurpose\nClaimant: ${request["requester_name"]}';
        if (selectedPaymentMode == 'GCash' && gcashRefController.text.trim().isNotEmpty) {
          fullDetails += '\nGCash Ref: ${gcashRefController.text.trim()}';
        }

        // 1. Create Transaction in Receipt Management System
        final transactionRecord = await SecretaryService.createTransaction(
          payorName: request['requester_name'] ?? 'Parishioner',
          payorContact: request['contact_number'],
          relatedService: serviceTitle,
          transactionDetails: fullDetails,
          transactionAmount: finalAmount,
          transactionType: 'certificate',
          relatedRequestId: request['service_request_id'],
        );

        // 2. Mark Request as Released in Pabuklat Workflow (activates 72-hour purge timer)
        await PabuklatService.markCertificateReleased(request['service_request_id']);

        _loadAllData();
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Certificate released and Receipt #${transactionRecord["receipt_number"]} generated!'),
            backgroundColor: ParishColors.oliveGreen,
          ),
        );

        // 3. Launch official Receipt Detail Modal for immediate receipt printing/voucher handover
        showReceiptDetailModal(
          context,
          receiptNo: transactionRecord['receipt_number'] ?? 'REC-XXXX',
          payer: transactionRecord['payor_name'] ?? request['requester_name'],
          purpose: serviceTitle,
          amount: '₱ ${finalAmount.toStringAsFixed(2)}',
          date: DateTime.now().toIso8601String().substring(0, 10),
          payorContact: request['contact_number'],
          transactionDetails: transactionRecord['transaction_details'],
          paymentMode: selectedPaymentMode,
          transactionId: transactionRecord['transaction_id']?.toString(),
          status: 'PAID',
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error releasing certificate: $e'), backgroundColor: ParishColors.mercyRed),
        );
      }
    }
  }

  // ===========================================================================
  // Filtering Helpers
  // ===========================================================================

  List<Map<String, dynamic>> _filterRequests(int tabIndex) {
    switch (tabIndex) {
      case 1: // Pending Review
        return _requests.where((r) => (r['request_status'] ?? '').toString().toLowerCase() == 'submitted').toList();
      case 2: // Awaiting Priest Signature
        return _requests.where((r) => (r['request_status'] ?? '').toString().toLowerCase() == 'forwarded_to_priest').toList();
      case 3: // Ready for Printing / Pickup
        return _requests.where((r) {
          final s = (r['request_status'] ?? '').toString().toLowerCase();
          return s == 'approved' || s == 'signature_completed' || s == 'ready_for_pickup';
        }).toList();
      case 4: // Released / Rejected
        return _requests.where((r) {
          final s = (r['request_status'] ?? '').toString().toLowerCase();
          return s == 'released' || s == 'rejected' || s == 'cancelled';
        }).toList();
      case 0: // All
      default:
        return _requests;
    }
  }

  // ===========================================================================
  // Main Build Method
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final cardWhite = ParishColors.cardWhite;
    final borderGrey = ParishColors.borderGrey;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      backgroundColor: cardWhite,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        width: 860,
        constraints: const BoxConstraints(maxHeight: 780),
        child: Column(
          children: [
            // Modal Header Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              decoration: BoxDecoration(
                color: ParishColors.marianBlueSurface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                border: Border(bottom: BorderSide(color: borderGrey)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(color: ParishColors.marianBlue, shape: BoxShape.circle),
                    child: const Icon(Icons.folder_shared, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isParishPriest ? 'Parish Priest Review: Certificate Requests' : 'Secretariat: Request Record Desk (Pabuklat)',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textDark),
                        ),
                        Text(
                          _isParishPriest
                              ? 'Remote e-signature sign-off and canonical review portal'
                              : 'Verify requestor credentials, inspect PDF, assign pickup dates, and route signatures',
                          style: TextStyle(fontSize: 12, color: textMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Parish Priest E-Signature Ribbon (Visible for Parish Priest)
            if (_isParishPriest) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: ParishColors.goldLight,
                  border: Border(bottom: BorderSide(color: ParishColors.goldAccent.withOpacity(0.4))),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.draw, size: 20, color: ParishColors.goldAccent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Reusable Electronic Signature', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                          Text(
                            _priestStoredSignatureUrl != null
                                ? 'Active signature on file. Applied automatically when approving remote requests.'
                                : 'No signature on file. Upload your e-signature to enable remote approvals.',
                            style: TextStyle(fontSize: 11, color: textDark),
                          ),
                        ],
                      ),
                    ),
                    if (_priestStoredSignatureUrl != null) ...[
                      Container(
                        height: 32,
                        width: 80,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: borderGrey)),
                        child: Image.network(_priestStoredSignatureUrl!, fit: BoxFit.contain),
                      ),
                      const SizedBox(width: 8),
                    ],
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: ParishColors.goldAccent),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      onPressed: _isUploadingPriestSignature ? null : _uploadPriestSignature,
                      icon: const Icon(Icons.upload_file, size: 14, color: ParishColors.goldAccent),
                      label: Text(
                        _priestStoredSignatureUrl != null ? 'Replace' : 'Upload E-Signature',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: ParishColors.goldAccent),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Navigation Tabs
            Container(
              color: cardWhite,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: ParishColors.marianBlue,
                unselectedLabelColor: textMuted,
                indicatorColor: ParishColors.marianBlue,
                indicatorWeight: 3,
                tabs: [
                  Tab(text: 'All (${_requests.length})'),
                  Tab(text: 'Pending (${_filterRequests(1).length})'),
                  Tab(text: 'Priest Signature (${_filterRequests(2).length})'),
                  Tab(text: 'Ready to Print / Pickup (${_filterRequests(3).length})'),
                  Tab(text: 'Released / Concluded (${_filterRequests(4).length})'),
                ],
              ),
            ),
            const Divider(height: 1),

            // Tab Views Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                  ? Center(child: Text(_errorMessage!, style: const TextStyle(color: ParishColors.mercyRed)))
                  : TabBarView(
                controller: _tabController,
                children: List.generate(5, (tabIndex) {
                  final list = _filterRequests(tabIndex);
                  if (list.isEmpty) {
                    return Center(
                      child: Text('No requests in this category.', style: TextStyle(color: textMuted)),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(18),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final req = list[index];
                      return _buildRequestCard(req);
                    },
                  );
                }),
              ),
            ),

            // Modal Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              decoration: BoxDecoration(
                color: cardWhite,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
                border: Border(top: BorderSide(color: borderGrey)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Physical certificate released at the Parish Secretariat desk upon claiming.',
                    style: TextStyle(fontSize: 11.5, color: textMuted, fontStyle: FontStyle.italic),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Close', style: TextStyle(color: textMuted, fontWeight: FontWeight.bold)),
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
  // Request Card Builder (With Prominent "View PDF" for Secretary & Priest)
  // ===========================================================================

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final textDark = ParishColors.textDark;
    final textMuted = ParishColors.textMuted;
    final borderGrey = ParishColors.borderGrey;

    final status = (request['request_status'] ?? 'submitted').toString().toLowerCase();
    final method = (request['signature_method'] ?? 'physical').toString().toLowerCase();
    final isRemote = method == 'remote_esignature';
    final pickup = request['pickup_date']?.toString();
    final idPath = request['id_document_url']?.toString();
    final bool hasId = idPath != null && idPath.isNotEmpty;
    final bool canPrint = PabuklatService.validatePrintReadiness(request);

    // Extracted clean purpose without relationship or record ID strings
    final cleanPurpose = _extractCleanPurpose(request['service_request_details']);

    Color statusColor = ParishColors.goldAccent;
    String statusDisplay = status.toUpperCase();

    if (status == 'approved') {
      statusColor = ParishColors.oliveGreen;
      statusDisplay = isRemote ? 'APPROVED - REMOTE SIGNING' : 'APPROVED - PHYSICAL SIGNATURE';
    } else if (status == 'forwarded_to_priest') {
      statusColor = const Color(0xFF7C3AED);
      statusDisplay = 'AWAITING PRIEST E-SIGNATURE';
    } else if (status == 'signature_completed') {
      statusColor = ParishColors.oliveGreen;
      statusDisplay = 'SIGNATURE COMPLETED (READY TO PRINT)';
    } else if (status == 'ready_for_pickup') {
      statusColor = ParishColors.marianBlue;
      statusDisplay = 'PRINTED • READY FOR PICKUP';
    } else if (status == 'released') {
      statusColor = ParishColors.oliveGreen;
      statusDisplay = 'RELEASED / CLAIMED';
    } else if (status == 'rejected') {
      statusColor = ParishColors.mercyRed;
      statusDisplay = 'REJECTED';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Request ID & Dynamic Status Tag
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    request['service_request_id'] ?? 'REQ-XXXX',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ParishColors.marianBlue),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: statusColor.withOpacity(0.4)),
                    ),
                    child: Text(
                      statusDisplay,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                    ),
                  ),
                ],
              ),
              Text(
                'Type: ${request["sacrament_type"] ?? "Sacrament"}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textDark),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Requestor & Relationship Line
          Text(
            'Requestor: ${request["requester_name"]} (${request["relationship_to_recipient"] ?? "Self"})',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textDark),
          ),
          Text(
            'Contact: ${request["contact_number"]} • Email: ${request["email"] ?? "None"}',
            style: TextStyle(fontSize: 12, color: textMuted),
          ),
          const SizedBox(height: 6),

          // Matched Record Details Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ParishColors.backgroundLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderGrey),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MATCHED CANONICAL RECORD:',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textMuted),
                ),
                Text(
                  request['matched_record_summary'] ?? 'Canonical Entry Attached',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textDark),
                ),
                const SizedBox(height: 3),
                Text('Purpose: $cleanPurpose', style: TextStyle(fontSize: 11.5, color: textMuted, fontStyle: FontStyle.italic)),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Pickup Schedule Bar
          if (pickup != null)
            Row(
              children: [
                const Icon(Icons.event_available, size: 16, color: ParishColors.oliveGreen),
                const SizedBox(width: 6),
                Text(
                  'Scheduled Pickup Date: $pickup (at Parish Office)',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: ParishColors.oliveGreen),
                ),
              ],
            ),

          if (request['rejection_reason'] != null) ...[
            const SizedBox(height: 4),
            Text(
              'Rejection Reason: ${request["rejection_reason"]}',
              style: const TextStyle(fontSize: 12, color: ParishColors.mercyRed, fontWeight: FontWeight.bold),
            ),
          ],

          const Divider(height: 20),

          // Action Buttons Toolbar (With "View PDF" for both Secretary and Priest)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left Group: Inspection Tools (View PDF + Inspect ID)
              Wrap(
                spacing: 8,
                children: [
                  // View PDF Inspection Button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ParishColors.marianBlueSurface,
                      foregroundColor: ParishColors.marianBlue,
                      elevation: 0,
                      side: BorderSide(color: ParishColors.marianBlue.withOpacity(0.4)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    onPressed: () => _previewCertificatePdf(request),
                    icon: const Icon(Icons.picture_as_pdf, size: 15, color: ParishColors.marianBlue),
                    label: const Text(
                      'View PDF',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                  ),

                  // Inspect Valid ID Button
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: hasId ? ParishColors.marianBlue : borderGrey),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    onPressed: hasId ? () => _inspectRequestorId(idPath, request['requester_name']) : null,
                    icon: Icon(hasId ? Icons.verified_user : Icons.badge_outlined, size: 15, color: hasId ? ParishColors.marianBlue : textMuted),
                    label: Text(
                      hasId ? 'Inspect ID' : 'No ID',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: hasId ? ParishColors.marianBlue : textMuted),
                    ),
                  ),
                ],
              ),

              // Right Group: Role-Specific Action Triggers
              Wrap(
                spacing: 8,
                children: [
                  // Secretary Initial Review & Routing
                  if (_isSecretary && status == 'submitted') ...[
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: ParishColors.mercyRed),
                      onPressed: () => _rejectRequest(request),
                      child: const Text('Reject', style: TextStyle(fontSize: 12)),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: ParishColors.oliveGreen, foregroundColor: Colors.white),
                      onPressed: () => _openSecretaryApprovalDialog(request),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Review & Approve', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],

                  // Parish Priest Remote Signature Sign-Off
                  if (_isParishPriest && status == 'forwarded_to_priest') ...[
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: ParishColors.mercyRed),
                      onPressed: () => _rejectRequest(request),
                      child: const Text('Reject', style: TextStyle(fontSize: 12)),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: ParishColors.goldAccent, foregroundColor: Colors.white),
                      onPressed: () => _handlePriestRemoteSign(request),
                      icon: const Icon(Icons.draw, size: 16),
                      label: const Text('Sign with E-Signature', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],

                  // Certificate Print Action
                  if (_isSecretary && (status == 'approved' || status == 'signature_completed' || status == 'ready_for_pickup')) ...[
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: canPrint ? ParishColors.marianBlue : borderGrey,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _handlePrintCertificate(request),
                      icon: const Icon(Icons.print, size: 16),
                      label: Text(
                        status == 'ready_for_pickup' ? 'Re-Print Certificate' : 'Print Certificate',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],

                  // Mark Released Action (Auto-Links to Receipt System)
                  if (_isSecretary && status == 'ready_for_pickup') ...[
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: ParishColors.oliveGreen, foregroundColor: Colors.white),
                      onPressed: () => _handleMarkReleased(request),
                      icon: const Icon(Icons.done_all, size: 16),
                      label: const Text('Mark Released', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}