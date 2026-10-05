// =============================================================================
// FILE: lib/features/sacramental_records/services/certificate_service.dart
// =============================================================================

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/database/local_database_service.dart';
import '../../../core/services/records_sync_service.dart';
import '../../auth/services/auth_service.dart';
import '../models/certificate_issuance_model.dart';
import '../models/certificate_template_model.dart';

class CertificateService {
  static final SupabaseClient _client = Supabase.instance.client;

  // Fallback domain for native mobile runs. When running on Flutter Web,
  // the system dynamically detects your live Firebase Hosting origin.
  static const String _defaultProductionDomain = 'https://parishserve.web.app';

  /// Dynamically resolves the base verification endpoint from the hosting environment.
  static String get verificationBaseUrl {
    if (kIsWeb) {
      final origin = Uri.base.origin;
      return '$origin/verify';
    }
    return '$_defaultProductionDomain/verify';
  }

  /// Builds the public dynamic verification URL embedded into the QR code
  static String buildVerificationUrl(String verificationId) {
    return '$verificationBaseUrl?v=$verificationId';
  }

  // ===========================================================================
  // 1. Global Parish & Diocesan Emblem Settings (Applies to ALL Certificates)
  // ===========================================================================

  /// Fetches the centralized Diocese Logo and Parish Seal configuration.
  /// On Web or Online: Queries Supabase and caches settings locally in SQLite.
  /// Offline: Reads from local SQLite without failing.
  static Future<Map<String, dynamic>> getGlobalEmblemSettings() async {
    final isOnline = await RecordsSyncService.instance.checkConnectivity();

    if (isOnline || kIsWeb) {
      try {
        final response = await _client
            .from('parish_certificate_settings')
            .select()
            .eq('id', 'global')
            .maybeSingle();

        if (response != null) {
          final resMap = Map<String, dynamic>.from(response);
          if (!kIsWeb) {
            RecordsSyncService.instance.cacheRemoteRecordsLocally(
              'parish_certificate_settings',
              [resMap],
            );
          }
          return resMap;
        }
      } catch (_) {}
    }

    final db = await LocalDatabaseService.instance.database;
    if (db != null) {
      try {
        final rows = await db.query(
          'parish_certificate_settings',
          where: 'id = ?',
          whereArgs: ['global'],
          limit: 1,
        );
        if (rows.isNotEmpty) return rows.first;
      } catch (_) {}
    }

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

    final data = {
      'id': 'global',
      'diocese_logo_url': dioceseLogoUrl,
      'parish_seal_url': parishSealUrl,
      'show_diocese_logo': showDioceseLogo,
      'show_parish_seal': showParishSeal,
      'updated_at': now,
    };

    final isOnline = await RecordsSyncService.instance.checkConnectivity();
    if (isOnline || kIsWeb) {
      try {
        // 1. Update the centralized settings table
        await _client.from('parish_certificate_settings').upsert(data);

        // 2. Cascade update to all existing certificate templates in Supabase
        final Map<String, dynamic> templateUpdate = {
          'show_diocese_logo': showDioceseLogo,
          'show_parish_seal': showParishSeal,
          'updated_at': now,
        };
        if (dioceseLogoUrl != null) templateUpdate['diocese_logo_url'] = dioceseLogoUrl;
        if (parishSealUrl != null) templateUpdate['parish_seal_url'] = parishSealUrl;

        await _client
            .from('certificate_templates')
            .update(templateUpdate)
            .neq('template_id', '');

        if (!kIsWeb) {
          RecordsSyncService.instance.cacheRemoteRecordsLocally(
            'parish_certificate_settings',
            [data],
          );
        }
        return;
      } catch (_) {
        if (kIsWeb) rethrow;
      }
    }

    // Offline fallback for Native
    await RecordsSyncService.instance.queueOfflineChange(
      tableName: 'parish_certificate_settings',
      recordId: 'global',
      operation: 'UPDATE',
      data: data,
    );
  }

  // ===========================================================================
  // 2. Template Management CRUD (Default & User-Created Custom Templates)
  // ===========================================================================

  /// Fetches active templates for a given sacrament, prioritizing the default template.
  /// Works 100% offline from SQLite, returning all custom user templates.
  static Future<List<CertificateTemplateModel>> getTemplatesForSacrament(
      String sacramentType,
      ) async {
    final isOnline = await RecordsSyncService.instance.checkConnectivity();

    if (isOnline || kIsWeb) {
      try {
        final response = await _client
            .from('certificate_templates')
            .select()
            .eq('sacrament_type', sacramentType)
            .eq('is_active', true)
            .order('is_default', ascending: false)
            .order('created_at', ascending: false);

        final list = (response as List)
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();

        if (!kIsWeb) {
          await RecordsSyncService.instance.cacheRemoteRecordsLocally(
            'certificate_templates',
            list,
          );
        }

        return list.map((row) => CertificateTemplateModel.fromMap(row)).toList();
      } catch (_) {
        if (kIsWeb) return [];
      }
    }

    // Direct SQLite Query
    final db = await LocalDatabaseService.instance.database;
    if (db != null) {
      try {
        final rows = await db.query(
          'certificate_templates',
          where: 'sacrament_type = ? AND (is_active = 1 OR is_active = "true")',
          orderBy: 'is_default DESC, created_at DESC',
        );
        return rows.map((r) => CertificateTemplateModel.fromMap(r)).toList();
      } catch (_) {}
    }

    return [];
  }

  /// Fetches all templates across all sacraments for administrative management.
  /// Supports both online live sync and offline SQLite cache retrieval.
  static Future<List<CertificateTemplateModel>> getAllTemplates() async {
    final isOnline = await RecordsSyncService.instance.checkConnectivity();

    if (isOnline || kIsWeb) {
      try {
        final response = await _client
            .from('certificate_templates')
            .select()
            .order('sacrament_type', ascending: true)
            .order('is_default', ascending: false)
            .order('created_at', ascending: false);

        final list = (response as List)
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();

        if (!kIsWeb) {
          await RecordsSyncService.instance.cacheRemoteRecordsLocally(
            'certificate_templates',
            list,
          );
        }

        return list.map((row) => CertificateTemplateModel.fromMap(row)).toList();
      } catch (_) {
        if (kIsWeb) return [];
      }
    }

    final db = await LocalDatabaseService.instance.database;
    if (db != null) {
      try {
        final rows = await db.query(
          'certificate_templates',
          orderBy: 'sacrament_type ASC, is_default DESC, created_at DESC',
        );
        return rows.map((r) => CertificateTemplateModel.fromMap(r)).toList();
      } catch (_) {}
    }

    return [];
  }

  /// Retrieves the default template for a specific sacrament.
  static Future<CertificateTemplateModel?> getDefaultTemplate(
      String sacramentType,
      ) async {
    final templates = await getTemplatesForSacrament(sacramentType);
    if (templates.isEmpty) return null;

    try {
      return templates.firstWhere((t) => t.isDefault);
    } catch (_) {
      return templates.first;
    }
  }

  /// Saves a new certificate template, inheriting global emblems if not explicitly set.
  static Future<CertificateTemplateModel> createTemplate(
      CertificateTemplateModel template,
      ) async {
    final currentUserId = AuthService.currentUser?.userId ?? 'S26-0003';
    final globalEmblems = await getGlobalEmblemSettings();

    final map = template.toMap();
    map['created_by'] = currentUserId;
    map['created_at'] = DateTime.now().toIso8601String();
    map['updated_at'] = DateTime.now().toIso8601String();

    map['diocese_logo_url'] ??= globalEmblems['diocese_logo_url'];
    map['parish_seal_url'] ??= globalEmblems['parish_seal_url'];
    map['show_diocese_logo'] = globalEmblems['show_diocese_logo'] ?? true;
    map['show_parish_seal'] = globalEmblems['show_parish_seal'] ?? true;

    if (template.isDefault) {
      await _unsetDefaultTemplates(template.sacramentType);
    }

    final isOnline = await RecordsSyncService.instance.checkConnectivity();
    if (isOnline || kIsWeb) {
      try {
        final response = await _client
            .from('certificate_templates')
            .insert(map)
            .select()
            .single();

        if (!kIsWeb) {
          await RecordsSyncService.instance.cacheRemoteRecordsLocally(
            'certificate_templates',
            [response],
          );
        }

        return CertificateTemplateModel.fromMap(response);
      } catch (_) {
        if (kIsWeb) rethrow;
      }
    }

    await RecordsSyncService.instance.queueOfflineChange(
      tableName: 'certificate_templates',
      recordId: template.templateId,
      operation: 'INSERT',
      data: map,
    );

    return CertificateTemplateModel.fromMap(map);
  }

  /// Updates an existing template and increments its version number to preserve snapshot history.
  static Future<CertificateTemplateModel> updateTemplate(
      CertificateTemplateModel template,
      ) async {
    final map = template.toMap();
    map['version'] = template.version + 1;
    map['updated_at'] = DateTime.now().toIso8601String();
    map.remove('created_at');

    if (template.isDefault) {
      await _unsetDefaultTemplates(template.sacramentType, excludeId: template.templateId);
    }

    final isOnline = await RecordsSyncService.instance.checkConnectivity();
    if (isOnline || kIsWeb) {
      try {
        final response = await _client
            .from('certificate_templates')
            .update(map)
            .eq('template_id', template.templateId)
            .select()
            .single();

        if (!kIsWeb) {
          await RecordsSyncService.instance.cacheRemoteRecordsLocally(
            'certificate_templates',
            [response],
          );
        }

        return CertificateTemplateModel.fromMap(response);
      } catch (_) {
        if (kIsWeb) rethrow;
      }
    }

    await RecordsSyncService.instance.queueOfflineChange(
      tableName: 'certificate_templates',
      recordId: template.templateId,
      operation: 'UPDATE',
      data: map,
    );

    return CertificateTemplateModel.fromMap(map);
  }

  /// Clones an existing template with a new name.
  static Future<CertificateTemplateModel> duplicateTemplate(
      String sourceTemplateId,
      String newTemplateName,
      ) async {
    final templates = await getAllTemplates();
    CertificateTemplateModel? model;
    try {
      model = templates.firstWhere((t) => t.templateId == sourceTemplateId);
    } catch (_) {}

    if (model == null) {
      final source = await _client
          .from('certificate_templates')
          .select()
          .eq('template_id', sourceTemplateId)
          .single();
      model = CertificateTemplateModel.fromMap(source);
    }

    final newId =
        'TPL-${model.sacramentType.substring(0, 3).toUpperCase()}-${DateTime.now().millisecondsSinceEpoch % 100000}';

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
  static Future<void> setDefaultTemplate(
      String templateId,
      String sacramentType,
      ) async {
    await _unsetDefaultTemplates(sacramentType);

    final updateData = {
      'is_default': true,
      'updated_at': DateTime.now().toIso8601String(),
    };

    final isOnline = await RecordsSyncService.instance.checkConnectivity();
    if (isOnline || kIsWeb) {
      try {
        await _client
            .from('certificate_templates')
            .update(updateData)
            .eq('template_id', templateId);
        return;
      } catch (_) {
        if (kIsWeb) rethrow;
      }
    }

    await RecordsSyncService.instance.queueOfflineChange(
      tableName: 'certificate_templates',
      recordId: templateId,
      operation: 'UPDATE',
      data: updateData,
    );
  }

  /// Activates or deactivates a template.
  static Future<void> toggleTemplateStatus(
      String templateId,
      bool isActive,
      ) async {
    final updateData = {
      'is_active': isActive,
      'updated_at': DateTime.now().toIso8601String(),
    };

    final isOnline = await RecordsSyncService.instance.checkConnectivity();
    if (isOnline || kIsWeb) {
      try {
        await _client
            .from('certificate_templates')
            .update(updateData)
            .eq('template_id', templateId);
        return;
      } catch (_) {
        if (kIsWeb) rethrow;
      }
    }

    await RecordsSyncService.instance.queueOfflineChange(
      tableName: 'certificate_templates',
      recordId: templateId,
      operation: 'UPDATE',
      data: updateData,
    );
  }

  static Future<void> _unsetDefaultTemplates(
      String sacramentType, {
        String? excludeId,
      }) async {
    final isOnline = await RecordsSyncService.instance.checkConnectivity();
    if (isOnline || kIsWeb) {
      try {
        var query = _client
            .from('certificate_templates')
            .update({'is_default': false})
            .eq('sacrament_type', sacramentType);

        if (excludeId != null) {
          query = query.neq('template_id', excludeId);
        }
        await query;
      } catch (_) {}
    }

    final db = await LocalDatabaseService.instance.database;
    if (db != null) {
      try {
        if (excludeId != null) {
          await db.update(
            'certificate_templates',
            {'is_default': 0},
            where: 'sacrament_type = ? AND template_id != ?',
            whereArgs: [sacramentType, excludeId],
          );
        } else {
          await db.update(
            'certificate_templates',
            {'is_default': 0},
            where: 'sacrament_type = ?',
            whereArgs: [sacramentType],
          );
        }
      } catch (_) {}
    }
  }

  // ===========================================================================
  // 3. Uploadable Certificate Assets (Borders, Backgrounds & Logos)
  // ===========================================================================

  /// Uploads a decorative border, background image, or seal to the Supabase storage bucket
  /// and immediately caches the raw binary bytes in local SQLite for offline PDF printing.
  static Future<String> uploadCertificateAsset({
    required Uint8List fileBytes,
    required String fileExtension,
    required String assetCategory,
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

    final publicUrl =
    _client.storage.from('certificate-assets').getPublicUrl(fileName);

    if (!kIsWeb) {
      await LocalDatabaseService.instance.cacheAsset(
        publicUrl,
        assetCategory,
        fileBytes,
        mimeType: 'image/$cleanExt',
      );
    }

    return publicUrl;
  }

  // ===========================================================================
  // 4. Official Issuance Generation & Verification Tokenization (Offline Ready)
  // ===========================================================================

  /// Issues an official certificate, creating a permanent issuance snapshot.
  /// Operates seamlessly offline by writing to SQLite and queuing for auto-sync.
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
    String? verificationId,
    String? qrVerificationUrl,
    String? transactionId,
    String? receiptNumber,
  }) async {
    final effectiveVerificationId =
        verificationId ?? generateSecureVerificationId();
    final effectiveQrUrl =
        qrVerificationUrl ?? buildVerificationUrl(effectiveVerificationId);
    final issuanceId = await _generateIssuanceId();

    final currentUserId = AuthService.currentUser?.userId ?? 'S26-0003';
    final now = DateTime.now();

    String? pdfPath;
    final isOnline = await RecordsSyncService.instance.checkConnectivity();

    if ((isOnline || kIsWeb) && generatedPdfBytes != null) {
      try {
        final pdfFileName =
            'issued_pdfs/$sacramentType/${issuanceId}_$effectiveVerificationId.pdf';
        await _client.storage.from('certificate-assets').uploadBinary(
          pdfFileName,
          generatedPdfBytes,
          fileOptions: const FileOptions(
            contentType: 'application/pdf',
            upsert: true,
          ),
        );
        pdfPath = pdfFileName;
      } catch (_) {}
    }

    final issuance = CertificateIssuanceModel(
      issuanceId: issuanceId,
      verificationId: effectiveVerificationId,
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
      qrVerificationUrl: effectiveQrUrl,
      pdfStoragePath: pdfPath,
      certificateStatus: 'Valid',
      transactionId: transactionId,
      receiptNumber: receiptNumber,
      issuedBy: currentUserId,
      issuedAt: now,
      createdAt: now,
    );

    if (isOnline || kIsWeb) {
      try {
        final response = await _client
            .from('certificate_issuances')
            .insert(issuance.toMap())
            .select()
            .single();

        if (transactionId != null && transactionId.isNotEmpty) {
          try {
            await _client.from('parish_transactions').update({
              'related_issuance_id': issuanceId,
            }).eq('transaction_id', transactionId);
          } catch (_) {}
        }

        try {
          await _client.from('pastoral_audit_logs').insert({
            'log_id': 'LOG-${now.millisecondsSinceEpoch}',
            'priest_id': currentUserId,
            'action_type': 'CERTIFICATE_ISSUED',
            'target_reference_id': recordId,
            'justification':
            'Issued $sacramentType Certificate for $recipientName. Purpose: $purpose. Receipt: ${receiptNumber ?? "None/Exempt"}. Verification ID: $effectiveVerificationId',
          });
        } catch (_) {}

        if (!kIsWeb) {
          await RecordsSyncService.instance.cacheRemoteRecordsLocally(
            'certificate_issuances',
            [response],
          );
        }

        return CertificateIssuanceModel.fromMap(response);
      } catch (e) {
        if (kIsWeb) rethrow;
      }
    }

    // Offline write on Native (Saves to SQLite table & sync queue)
    await RecordsSyncService.instance.queueOfflineChange(
      tableName: 'certificate_issuances',
      recordId: issuanceId,
      operation: 'INSERT',
      data: issuance.toMap(),
    );

    return issuance;
  }

  /// Fetches issuance history for a specific sacramental record.
  static Future<List<CertificateIssuanceModel>> getIssuancesForRecord(
      String recordId,
      ) async {
    final isOnline = await RecordsSyncService.instance.checkConnectivity();

    if (isOnline || kIsWeb) {
      try {
        final response = await _client
            .from('certificate_issuances')
            .select()
            .eq('record_id', recordId)
            .order('issued_at', ascending: false);

        final list = (response as List)
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();

        if (!kIsWeb) {
          await RecordsSyncService.instance.cacheRemoteRecordsLocally(
            'certificate_issuances',
            list,
          );
        }

        return list.map((r) => CertificateIssuanceModel.fromMap(r)).toList();
      } catch (_) {
        if (kIsWeb) return [];
      }
    }

    final db = await LocalDatabaseService.instance.database;
    if (db != null) {
      try {
        final rows = await db.query(
          'certificate_issuances',
          where: 'record_id = ?',
          whereArgs: [recordId],
          orderBy: 'issued_at DESC',
        );
        return rows.map((r) => CertificateIssuanceModel.fromMap(r)).toList();
      } catch (_) {}
    }

    return [];
  }

  /// Revokes an existing issued certificate.
  static Future<void> revokeCertificate({
    required String issuanceId,
    required String reason,
  }) async {
    final currentUserId = AuthService.currentUser?.userId ?? 'S26-0003';
    final now = DateTime.now();

    final updateData = {
      'certificate_status': 'Revoked',
      'revocation_reason': reason,
      'revoked_at': now.toIso8601String(),
      'revoked_by': currentUserId,
    };

    final isOnline = await RecordsSyncService.instance.checkConnectivity();
    if (isOnline || kIsWeb) {
      try {
        await _client
            .from('certificate_issuances')
            .update(updateData)
            .eq('issuance_id', issuanceId);

        try {
          await _client.from('pastoral_audit_logs').insert({
            'log_id': 'LOG-${now.millisecondsSinceEpoch}',
            'priest_id': currentUserId,
            'action_type': 'CERTIFICATE_REVOKED',
            'target_reference_id': issuanceId,
            'justification': 'Revoked Certificate $issuanceId. Reason: $reason',
          });
        } catch (_) {}
        return;
      } catch (_) {
        if (kIsWeb) rethrow;
      }
    }

    await RecordsSyncService.instance.queueOfflineChange(
      tableName: 'certificate_issuances',
      recordId: issuanceId,
      operation: 'UPDATE',
      data: updateData,
    );
  }

  /// Verification lookup supporting both live Supabase lookup and local offline cache verification.
  static Future<CertificateIssuanceModel?> verifyCertificate(
      String verificationId,
      ) async {
    final cleanToken = verificationId.trim().toUpperCase();

    final isOnline = await RecordsSyncService.instance.checkConnectivity();
    if (isOnline || kIsWeb) {
      try {
        final response = await _client
            .from('certificate_issuances')
            .select()
            .eq('verification_id', cleanToken)
            .maybeSingle();

        if (response != null) {
          final model = CertificateIssuanceModel.fromMap(response);

          try {
            await _client.from('certificate_issuances').update({
              'last_scanned_at': DateTime.now().toIso8601String(),
            }).eq('verification_id', cleanToken);
          } catch (_) {}

          return model;
        }
      } catch (_) {
        if (kIsWeb) return null;
      }
    }

    final db = await LocalDatabaseService.instance.database;
    if (db != null) {
      try {
        final rows = await db.query(
          'certificate_issuances',
          where: 'verification_id = ?',
          whereArgs: [cleanToken],
          limit: 1,
        );
        if (rows.isNotEmpty) {
          return CertificateIssuanceModel.fromMap(rows.first);
        }
      } catch (_) {}
    }

    return null;
  }

  // ===========================================================================
  // Security & Token Helpers
  // ===========================================================================

  /// Generates a cryptographically random, non-sequential UUID v4 token.
  static String generateSecureVerificationId() {
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
    int highest = 0;

    final isOnline = await RecordsSyncService.instance.checkConnectivity();
    if (isOnline || kIsWeb) {
      try {
        final records = await _client
            .from('certificate_issuances')
            .select('issuance_id')
            .like('issuance_id', 'ISS-$year-%');

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
        if (kIsWeb) {
          final fallback = (DateTime.now().millisecondsSinceEpoch % 10000)
              .toString()
              .padLeft(4, '0');
          return 'ISS-$year-$fallback';
        }
      }
    }

    final db = await LocalDatabaseService.instance.database;
    if (db != null) {
      try {
        final rows = await db.rawQuery(
          "SELECT issuance_id FROM certificate_issuances WHERE issuance_id LIKE 'ISS-$year-%'",
        );
        for (final r in rows) {
          final id = r['issuance_id']?.toString() ?? '';
          final parts = id.split('-');
          if (parts.length >= 3) {
            final num = int.tryParse(parts[2]);
            if (num != null && num > highest) highest = num;
          }
        }
      } catch (_) {}
    }

    final nextSeq = (highest + 1).toString().padLeft(4, '0');
    return 'ISS-$year-$nextSeq';
  }
}