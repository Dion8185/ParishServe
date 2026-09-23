import 'dart:math';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/services/auth_service.dart';
import '../models/certificate_issuance_model.dart';
import '../models/certificate_template_model.dart';

class CertificateService {
  static final SupabaseClient _client = Supabase.instance.client;

  // Base portal URL for scanning QR verification tokens
  static const String verificationBaseUrl = 'https://parishserve.sjp2parish.ph/verify';

  // ===========================================================================
  // 1. Global Parish & Diocesan Emblem Settings (Applies to ALL Certificates)
  // ===========================================================================

  /// Fetches the centralized Diocese Logo and Parish Seal configuration.
  static Future<Map<String, dynamic>> getGlobalEmblemSettings() async {
    try {
      final response = await _client
          .from('parish_certificate_settings')
          .select()
          .eq('id', 'global')
          .maybeSingle();

      if (response != null) {
        return response;
      }
    } catch (_) {}

    return {
      'diocese_logo_url': null,
      'parish_seal_url': null,
      'show_diocese_logo': true,
      'show_parish_seal': true,
    };
  }

  /// Updates the global emblems and cascades the changes across all certificate templates.
  static Future<void> updateGlobalEmblems({
    String? dioceseLogoUrl,
    String? parishSealUrl,
    required bool showDioceseLogo,
    required bool showParishSeal,
  }) async {
    final now = DateTime.now().toIso8601String();

    // 1. Update the centralized settings table
    await _client.from('parish_certificate_settings').upsert({
      'id': 'global',
      'diocese_logo_url': dioceseLogoUrl,
      'parish_seal_url': parishSealUrl,
      'show_diocese_logo': showDioceseLogo,
      'show_parish_seal': showParishSeal,
      'updated_at': now,
    });

    // 2. Cascade update to all existing certificate templates in the database
    final Map<String, dynamic> templateUpdate = {
      'show_diocese_logo': showDioceseLogo,
      'show_parish_seal': showParishSeal,
      'updated_at': now,
    };
    if (dioceseLogoUrl != null) templateUpdate['diocese_logo_url'] = dioceseLogoUrl;
    if (parishSealUrl != null) templateUpdate['parish_seal_url'] = parishSealUrl;

    await _client.from('certificate_templates').update(templateUpdate).neq('template_id', '');
  }

  // ===========================================================================
  // 2. Template Management CRUD
  // ===========================================================================

  /// Fetches active templates for a given sacrament, prioritizing the default template.
  static Future<List<CertificateTemplateModel>> getTemplatesForSacrament(String sacramentType) async {
    final response = await _client
        .from('certificate_templates')
        .select()
        .eq('sacrament_type', sacramentType)
        .eq('is_active', true)
        .order('is_default', ascending: false)
        .order('created_at', ascending: false);

    return (response as List)
        .map((row) => CertificateTemplateModel.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Fetches all templates across all sacraments (including inactive) for administrative management.
  static Future<List<CertificateTemplateModel>> getAllTemplates() async {
    final response = await _client
        .from('certificate_templates')
        .select()
        .order('sacrament_type', ascending: true)
        .order('is_default', ascending: false)
        .order('created_at', ascending: false);

    return (response as List)
        .map((row) => CertificateTemplateModel.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Retrieves the default template for a specific sacrament.
  static Future<CertificateTemplateModel?> getDefaultTemplate(String sacramentType) async {
    final response = await _client
        .from('certificate_templates')
        .select()
        .eq('sacrament_type', sacramentType)
        .eq('is_active', true)
        .eq('is_default', true)
        .maybeSingle();

    if (response != null) {
      return CertificateTemplateModel.fromMap(response);
    }

    final fallback = await _client
        .from('certificate_templates')
        .select()
        .eq('sacrament_type', sacramentType)
        .eq('is_active', true)
        .limit(1)
        .maybeSingle();

    if (fallback != null) {
      return CertificateTemplateModel.fromMap(fallback);
    }
    return null;
  }

  /// Saves a new certificate template, inheriting the global emblems if not explicitly set.
  static Future<CertificateTemplateModel> createTemplate(CertificateTemplateModel template) async {
    final currentUserId = AuthService.currentUser?.userId ?? 'S26-0003';
    final globalEmblems = await getGlobalEmblemSettings();

    final map = template.toMap();
    map['created_by'] = currentUserId;
    map['created_at'] = DateTime.now().toIso8601String();
    map['updated_at'] = DateTime.now().toIso8601String();

    // Inherit global emblems
    map['diocese_logo_url'] ??= globalEmblems['diocese_logo_url'];
    map['parish_seal_url'] ??= globalEmblems['parish_seal_url'];
    map['show_diocese_logo'] = globalEmblems['show_diocese_logo'] ?? true;
    map['show_parish_seal'] = globalEmblems['show_parish_seal'] ?? true;

    if (template.isDefault) {
      await _unsetDefaultTemplates(template.sacramentType);
    }

    final response = await _client
        .from('certificate_templates')
        .insert(map)
        .select()
        .single();

    return CertificateTemplateModel.fromMap(response);
  }

  /// Updates an existing template and increments its version number to preserve snapshot history.
  static Future<CertificateTemplateModel> updateTemplate(CertificateTemplateModel template) async {
    final map = template.toMap();
    map['version'] = template.version + 1;
    map['updated_at'] = DateTime.now().toIso8601String();
    map.remove('created_at');

    if (template.isDefault) {
      await _unsetDefaultTemplates(template.sacramentType, excludeId: template.templateId);
    }

    final response = await _client
        .from('certificate_templates')
        .update(map)
        .eq('template_id', template.templateId)
        .select()
        .single();

    return CertificateTemplateModel.fromMap(response);
  }

  /// Clones an existing template with a new name.
  static Future<CertificateTemplateModel> duplicateTemplate(
      String sourceTemplateId,
      String newTemplateName,
      ) async {
    final source = await _client
        .from('certificate_templates')
        .select()
        .eq('template_id', sourceTemplateId)
        .single();

    final model = CertificateTemplateModel.fromMap(source);
    final newId = 'TPL-${model.sacramentType.substring(0, 3).toUpperCase()}-${DateTime.now().millisecondsSinceEpoch % 100000}';

    final clone = model.copyWith(
      templateId: newId,
      templateName: newTemplateName,
      isDefault: false,
      version: 1,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    return createTemplate(clone);
  }

  /// Sets a specific template as default for its sacrament.
  static Future<void> setDefaultTemplate(String templateId, String sacramentType) async {
    await _unsetDefaultTemplates(sacramentType);
    await _client
        .from('certificate_templates')
        .update({'is_default': true, 'updated_at': DateTime.now().toIso8601String()})
        .eq('template_id', templateId);
  }

  /// Activates or deactivates a template.
  static Future<void> toggleTemplateStatus(String templateId, bool isActive) async {
    await _client
        .from('certificate_templates')
        .update({'is_active': isActive, 'updated_at': DateTime.now().toIso8601String()})
        .eq('template_id', templateId);
  }

  static Future<void> _unsetDefaultTemplates(String sacramentType, {String? excludeId}) async {
    var query = _client
        .from('certificate_templates')
        .update({'is_default': false})
        .eq('sacrament_type', sacramentType);

    if (excludeId != null) {
      query = query.neq('template_id', excludeId);
    }
    await query;
  }

  // ===========================================================================
  // 3. Uploadable Certificate Assets (Borders, Backgrounds & Logos)
  // ===========================================================================

  /// Uploads a decorative border, background image, or seal to the Supabase storage bucket.
  static Future<String> uploadCertificateAsset({
    required Uint8List fileBytes,
    required String fileExtension,
    required String assetCategory, // 'borders', 'backgrounds', 'logos', 'signatures'
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final cleanExt = fileExtension.replaceAll('.', '').toLowerCase();
    final fileName = '$assetCategory/$timestamp.$cleanExt';

    await _client.storage.from('certificate-assets').uploadBinary(
      fileName,
      fileBytes,
      fileOptions: FileOptions(
        contentType: 'image/$cleanExt',
        upsert: true,
      ),
    );

    return _client.storage.from('certificate-assets').getPublicUrl(fileName);
  }

  // ===========================================================================
  // 4. Official Issuance Generation & Verification Tokenization
  // ===========================================================================

  /// Issues an official certificate, creating a permanent issuance snapshot,
  /// generating a cryptographically secure verification token, and recording audit entries.
  static Future<CertificateIssuanceModel> issueCertificate({
    required String recordId,
    required String sacramentType,
    required String recipientName,
    required String purpose,
    required CertificateTemplateModel template,
    required String renderedWording,
    String? bookNumber,
    String? pageNumber,
    String? lineNumber,
    String? registryReference,
    Uint8List? generatedPdfBytes,
  }) async {
    final verificationId = _generateSecureVerificationId();
    final issuanceId = await _generateIssuanceId();
    final qrUrl = '$verificationBaseUrl?v=$verificationId';

    String? pdfPath;
    if (generatedPdfBytes != null) {
      try {
        final pdfFileName = 'issued_pdfs/$sacramentType/${issuanceId}_$verificationId.pdf';
        await _client.storage.from('certificate-assets').uploadBinary(
          pdfFileName,
          generatedPdfBytes,
          fileOptions: const FileOptions(contentType: 'application/pdf', upsert: true),
        );
        pdfPath = pdfFileName;
      } catch (_) {}
    }

    final currentUserId = AuthService.currentUser?.userId ?? 'S26-0003';
    final now = DateTime.now();

    final issuance = CertificateIssuanceModel(
      issuanceId: issuanceId,
      verificationId: verificationId,
      recordId: recordId,
      sacramentType: sacramentType,
      recipientName: recipientName,
      purpose: purpose,
      templateId: template.templateId,
      templateVersion: template.version,
      renderedWording: renderedWording,
      signatoryName: template.signatoryName,
      signatoryTitle: template.signatoryTitle,
      bookNumber: bookNumber,
      pageNumber: pageNumber,
      lineNumber: lineNumber,
      registryReference: registryReference,
      qrVerificationUrl: qrUrl,
      pdfStoragePath: pdfPath,
      certificateStatus: 'Valid',
      issuedBy: currentUserId,
      issuedAt: now,
      createdAt: now,
    );

    final response = await _client
        .from('certificate_issuances')
        .insert(issuance.toMap())
        .select()
        .single();

    try {
      await _client.from('pastoral_audit_logs').insert({
        'log_id': 'LOG-${now.millisecondsSinceEpoch}',
        'priest_id': currentUserId,
        'action_type': 'CERTIFICATE_ISSUED',
        'target_reference_id': recordId,
        'justification': 'Issued $sacramentType Certificate for $recipientName. Purpose: $purpose. Verification ID: $verificationId',
      });
    } catch (_) {}

    return CertificateIssuanceModel.fromMap(response);
  }

  /// Fetches issuance history for a specific sacramental record.
  static Future<List<CertificateIssuanceModel>> getIssuancesForRecord(String recordId) async {
    final response = await _client
        .from('certificate_issuances')
        .select()
        .eq('record_id', recordId)
        .order('issued_at', ascending: false);

    return (response as List)
        .map((row) => CertificateIssuanceModel.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Revokes an existing issued certificate.
  static Future<void> revokeCertificate({
    required String issuanceId,
    required String reason,
  }) async {
    final currentUserId = AuthService.currentUser?.userId ?? 'S26-0003';
    final now = DateTime.now();

    await _client.from('certificate_issuances').update({
      'certificate_status': 'Revoked',
      'revocation_reason': reason,
      'revoked_at': now.toIso8601String(),
      'revoked_by': currentUserId,
    }).eq('issuance_id', issuanceId);

    try {
      await _client.from('pastoral_audit_logs').insert({
        'log_id': 'LOG-${now.millisecondsSinceEpoch}',
        'priest_id': currentUserId,
        'action_type': 'CERTIFICATE_REVOKED',
        'target_reference_id': issuanceId,
        'justification': 'Revoked Certificate $issuanceId. Reason: $reason',
      });
    } catch (_) {}
  }

  /// Online Verification Lookup.
  static Future<CertificateIssuanceModel?> verifyCertificate(String verificationId) async {
    final response = await _client
        .from('certificate_issuances')
        .select()
        .eq('verification_id', verificationId.trim().toUpperCase())
        .maybeSingle();

    if (response != null) {
      return CertificateIssuanceModel.fromMap(response);
    }
    return null;
  }

  // ===========================================================================
  // Security & Token Helpers
  // ===========================================================================

  static String _generateSecureVerificationId() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));

    values[6] = (values[6] & 0x0f) | 0x40;
    values[8] = (values[8] & 0x3f) | 0x80;

    final buffer = StringBuffer();
    for (int i = 0; i < 16; i++) {
      if (i == 4 || i == 6 || i == 8 || i == 10) buffer.write('-');
      buffer.write(values[i].toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString().toUpperCase();
  }

  static Future<String> _generateIssuanceId() async {
    final year = DateTime.now().year;
    try {
      final records = await _client
          .from('certificate_issuances')
          .select('issuance_id')
          .like('issuance_id', 'ISS-$year-%');

      int highest = 0;
      for (final r in records) {
        final id = r['issuance_id']?.toString() ?? '';
        final parts = id.split('-');
        if (parts.length >= 3) {
          final num = int.tryParse(parts[2]);
          if (num != null && num > highest) highest = num;
        }
      }
      final nextSeq = (highest + 1).toString().padLeft(4, '0');
      return 'ISS-$year-$nextSeq';
    } catch (_) {
      final fallback = (DateTime.now().millisecondsSinceEpoch % 10000).toString().padLeft(4, '0');
      return 'ISS-$year-$fallback';
    }
  }
}