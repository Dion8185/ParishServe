import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/services/auth_service.dart';
import '../models/asset_audit_log_model.dart';
import '../models/asset_model.dart';

class AssetService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Fetches registered parish assets with optional filtering (active vs archived)
  static Future<List<AssetModel>> getAssets({
    bool includeArchived = false,
    String? categoryFilter,
    String? locationFilter,
    String? conditionFilter,
  }) async {
    try {
      var query = _client.from('parish_assets').select('''
        *,
        asset_classifications (
          classification_id,
          acronym,
          classification_name
        ),
        asset_locations (
          location_id,
          acronym,
          location_name
        )
      ''');

      if (!includeArchived) {
        query = query.eq('is_archived', false);
      }

      if (categoryFilter != null && categoryFilter != 'All') {
        query = query.eq('classification_acronym', categoryFilter.toUpperCase());
      }

      if (locationFilter != null && locationFilter != 'All') {
        query = query.eq('location_acronym', locationFilter.toUpperCase());
      }

      if (conditionFilter != null && conditionFilter != 'All') {
        query = query.eq('condition_status', conditionFilter);
      }

      final response = await query
          .order('registration_date', ascending: false)
          .order('created_at', ascending: false);

      return (response as List)
          .map((row) => AssetModel.fromMap(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching parish assets: $e');
      rethrow;
    }
  }

  /// Looks up a single asset record by its Control Number, Asset ID, or QR Code Token
  static Future<AssetModel?> findAssetByIdentifier(String identifier) async {
    final clean = identifier.trim();
    if (clean.isEmpty) return null;

    try {
      // Direct match by control_number, asset_id, or qr_code_token
      final response = await _client
          .from('parish_assets')
          .select('''
            *,
            asset_classifications (
              classification_id,
              acronym,
              classification_name
            ),
            asset_locations (
              location_id,
              acronym,
              location_name
            )
          ''')
          .or('control_number.eq.$clean,asset_id.eq.$clean,qr_code_token.eq.$clean,rfid_tag.eq.$clean')
          .maybeSingle();

      if (response != null) {
        return AssetModel.fromMap(response);
      }
    } catch (e) {
      debugPrint('Error querying asset identifier: $e');
    }
    return null;
  }

  /// Uploads asset photographic documentation to Supabase Storage
  static Future<String?> uploadAssetPhoto({
    required String assetId,
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    try {
      final cleanExt = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : 'jpg';
      final storagePath = 'asset_photos/$assetId/photo_${DateTime.now().millisecondsSinceEpoch}.$cleanExt';

      await _client.storage.from('certificate-assets').uploadBinary(
        storagePath,
        fileBytes,
        fileOptions: FileOptions(
          contentType: 'image/$cleanExt',
          upsert: true,
        ),
      );

      return _client.storage.from('certificate-assets').getPublicUrl(storagePath);
    } catch (e) {
      debugPrint('Error uploading asset photo: $e');
      return null;
    }
  }

  /// Atomically invokes the Postgres stored procedure to generate a Diocesan Control Number
  /// Format: LOCATION-CLASSIFICATION-YEAR-SEQUENCE (e.g. C-SI-2008-001)
  static Future<String> generateControlNumber({
    required String locationAcronym,
    required String classificationAcronym,
    required int acquisitionYear,
  }) async {
    try {
      final result = await _client.rpc(
        'generate_diocesan_asset_control_number',
        params: {
          'p_location_acronym': locationAcronym.trim().toUpperCase(),
          'p_classification_acronym': classificationAcronym.trim().toUpperCase(),
          'p_acquisition_year': acquisitionYear,
        },
      );

      if (result != null && result.toString().trim().isNotEmpty) {
        return result.toString().trim();
      }
    } catch (e) {
      debugPrint('RPC error generating control number: $e. Falling back to local sequence generation.');
    }

    // Fallback: Query highest sequence locally if procedure is unavailable
    final prefix = '${locationAcronym.trim().toUpperCase()}-${classificationAcronym.trim().toUpperCase()}-$acquisitionYear-';
    final records = await _client
        .from('parish_assets')
        .select('control_number')
        .like('control_number', '$prefix%');

    int highestSeq = 0;
    for (final r in records) {
      final cNo = r['control_number']?.toString() ?? '';
      if (cNo.startsWith(prefix)) {
        final seqPart = cNo.substring(prefix.length);
        final parsed = int.tryParse(seqPart);
        if (parsed != null && parsed > highestSeq) {
          highestSeq = parsed;
        }
      }
    }

    return '$prefix${(highestSeq + 1).toString().padLeft(3, '0')}';
  }

  /// Generates a permanent canonical UUID v4 for the Asset ID and QR Code Token
  static String generatePermanentIdentifier(String prefix) {
    final rand = Random.secure();
    final values = List<int>.generate(8, (_) => rand.nextInt(256));
    final token = values.map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
    return '$prefix-$token';
  }

  /// Helper to safely resolve a valid user ID for foreign keys
  static Future<String?> _resolveValidUserId() async {
    String? currentUserId = AuthService.currentUser?.userId;
    if (currentUserId != null && currentUserId.isNotEmpty) {
      return currentUserId;
    }

    try {
      final defaultUser = await _client
          .from('users')
          .select('user_id')
          .eq('account_status', true)
          .limit(1)
          .maybeSingle();
      return defaultUser?['user_id'];
    } catch (_) {
      return null;
    }
  }

  /// Registers a new parish asset with automatic identifiers and audit trail
  static Future<AssetModel> registerAsset({
    required String itemName,
    required String classificationId,
    required String classificationAcronym,
    String? classificationName,
    required String locationId,
    required String locationAcronym,
    String? locationName,
    String? dimensions,
    String? color,
    String? model,
    String? others,
    String? remarks,
    String? photoUrl,
    required DateTime dateOfAcquisition,
    String modeOfAcquisition = 'Purchase',
    double cost = 0.0,
    String? rfidTag,
    String conditionStatus = 'VERIFIED / GOOD',
    String operationalStatus = 'Active',
  }) async {
    final cleanItemName = itemName.trim();
    if (cleanItemName.isEmpty) throw 'Asset designation / item name is required.';

    final validUserId = await _resolveValidUserId();
    final int acquisitionYear = dateOfAcquisition.year;

    // 1. Generate unique identifiers
    final assetId = generatePermanentIdentifier('AST');
    final qrCodeToken = generatePermanentIdentifier('QR');

    // 2. Generate Diocesan Control Number: LOCATION-CLASSIFICATION-YEAR-SEQUENCE
    final controlNumber = await generateControlNumber(
      locationAcronym: locationAcronym,
      classificationAcronym: classificationAcronym,
      acquisitionYear: acquisitionYear,
    );

    final now = DateTime.now();

    final payload = {
      'asset_id': assetId,
      'control_number': controlNumber,
      'item_name': cleanItemName,
      'classification_id': classificationId,
      'classification_acronym': classificationAcronym.trim().toUpperCase(),
      'location_id': locationId,
      'location_acronym': locationAcronym.trim().toUpperCase(),
      'dimensions': dimensions?.trim().isEmpty ?? true ? null : dimensions!.trim(),
      'color': color?.trim().isEmpty ?? true ? null : color!.trim(),
      'model': model?.trim().isEmpty ?? true ? null : model!.trim(),
      'others': others?.trim().isEmpty ?? true ? null : others!.trim(),
      'remarks': remarks?.trim().isEmpty ?? true ? null : remarks!.trim(),
      'photo_url': photoUrl?.trim().isEmpty ?? true ? null : photoUrl!.trim(),
      'date_of_acquisition': '${dateOfAcquisition.year}-${dateOfAcquisition.month.toString().padLeft(2, '0')}-${dateOfAcquisition.day.toString().padLeft(2, '0')}',
      'acquisition_year': acquisitionYear,
      'mode_of_acquisition': modeOfAcquisition,
      'cost': cost,
      'rfid_tag': rfidTag?.trim().isEmpty ?? true ? null : rfidTag!.trim(),
      'qr_code_token': qrCodeToken,
      'condition_status': conditionStatus,
      'operational_status': operationalStatus,
      'is_archived': false,
      'registration_date': now.toIso8601String(),
      'created_by': validUserId,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
      // Legacy compatibility
      'category': classificationName ?? classificationAcronym,
      'storage_location': locationName ?? locationAcronym,
      'acquisition_date': '${dateOfAcquisition.year}-${dateOfAcquisition.month.toString().padLeft(2, '0')}-${dateOfAcquisition.day.toString().padLeft(2, '0')}',
      'acquisition_mode': modeOfAcquisition,
      'description': remarks ?? others ?? cleanItemName,
    };

    final response = await _client
        .from('parish_assets')
        .insert(payload)
        .select()
        .single();

    // 3. Create initial registration audit log entry
    try {
      await _client.from('asset_audit_logs').insert({
        'audit_id': 'AUD-${now.millisecondsSinceEpoch}',
        'asset_id': assetId,
        'control_number': controlNumber,
        'audited_by': validUserId,
        'previous_condition': null,
        'new_condition': conditionStatus,
        'previous_location': null,
        'new_location': locationName ?? locationAcronym,
        'audit_method': 'MANUAL',
        'audit_notes': 'Initial registration in parish inventory.',
        'audited_at': now.toIso8601String(),
      });
    } catch (e) {
      debugPrint('Non-blocking initial audit log note: $e');
    }

    return AssetModel.fromMap(response);
  }

  /// Updates an existing asset while strictly preserving its original Control Number
  static Future<AssetModel> updateAsset({
    required String assetId,
    required String itemName,
    String? classificationId,
    required String classificationAcronym,
    String? locationId,
    required String locationAcronym,
    String? locationName,
    String? dimensions,
    String? color,
    String? model,
    String? others,
    String? remarks,
    String? photoUrl,
    required DateTime dateOfAcquisition,
    required String modeOfAcquisition,
    required double cost,
    String? rfidTag,
    required String conditionStatus,
    required String operationalStatus,
  }) async {
    final cleanItemName = itemName.trim();
    if (cleanItemName.isEmpty) throw 'Asset designation / item name is required.';

    final now = DateTime.now();

    final updatePayload = {
      'item_name': cleanItemName,
      'classification_id': classificationId,
      'classification_acronym': classificationAcronym.trim().toUpperCase(),
      'location_id': locationId,
      'location_acronym': locationAcronym.trim().toUpperCase(),
      'dimensions': dimensions?.trim().isEmpty ?? true ? null : dimensions!.trim(),
      'color': color?.trim().isEmpty ?? true ? null : color!.trim(),
      'model': model?.trim().isEmpty ?? true ? null : model!.trim(),
      'others': others?.trim().isEmpty ?? true ? null : others!.trim(),
      'remarks': remarks?.trim().isEmpty ?? true ? null : remarks!.trim(),
      if (photoUrl != null) 'photo_url': photoUrl.trim(),
      'date_of_acquisition': '${dateOfAcquisition.year}-${dateOfAcquisition.month.toString().padLeft(2, '0')}-${dateOfAcquisition.day.toString().padLeft(2, '0')}',
      'acquisition_year': dateOfAcquisition.year,
      'mode_of_acquisition': modeOfAcquisition,
      'cost': cost,
      'rfid_tag': rfidTag?.trim().isEmpty ?? true ? null : rfidTag!.trim(),
      'condition_status': conditionStatus,
      'operational_status': operationalStatus,
      'updated_at': now.toIso8601String(),
      // Legacy columns
      'storage_location': locationName ?? locationAcronym,
      'acquisition_date': '${dateOfAcquisition.year}-${dateOfAcquisition.month.toString().padLeft(2, '0')}-${dateOfAcquisition.day.toString().padLeft(2, '0')}',
      'acquisition_mode': modeOfAcquisition,
      'description': remarks ?? others ?? cleanItemName,
    };

    final response = await _client
        .from('parish_assets')
        .update(updatePayload)
        .eq('asset_id', assetId)
        .select()
        .single();

    return AssetModel.fromMap(response);
  }

  /// Records an audit inspection and updates condition and location
  static Future<void> recordAuditScan({
    required String assetId,
    required String controlNumber,
    required String newCondition,
    String? previousCondition,
    String? previousLocation,
    String? newLocation,
    String auditMethod = 'QR_SCAN', // 'QR_SCAN', 'RFID_NFC', 'MANUAL'
    String? auditNotes,
  }) async {
    final validUserId = await _resolveValidUserId();
    final now = DateTime.now();

    // 1. Log the audit verification entry
    await _client.from('asset_audit_logs').insert({
      'audit_id': 'AUD-${now.millisecondsSinceEpoch}',
      'asset_id': assetId,
      'control_number': controlNumber,
      'audited_by': validUserId,
      'previous_condition': previousCondition,
      'new_condition': newCondition,
      'previous_location': previousLocation,
      'new_location': newLocation,
      'audit_method': auditMethod,
      'audit_notes': auditNotes?.trim().isEmpty ?? true ? null : auditNotes!.trim(),
      'audited_at': now.toIso8601String(),
    });

    // 2. Update the master asset record's audit timestamp and condition
    await _client.from('parish_assets').update({
      'condition_status': newCondition,
      'last_audited_at': now.toIso8601String(),
      'audited_by': validUserId,
      if (newLocation != null && newLocation.isNotEmpty) 'storage_location': newLocation,
      'updated_at': now.toIso8601String(),
    }).eq('asset_id', assetId);
  }

  /// Fetches historical audit logs for a specific asset
  static Future<List<AssetAuditLogModel>> getAssetAuditHistory(String assetId) async {
    try {
      final response = await _client
          .from('asset_audit_logs')
          .select('''
            *,
            users (
              first_name,
              last_name
            )
          ''')
          .eq('asset_id', assetId)
          .order('audited_at', ascending: false);

      return (response as List)
          .map((row) => AssetAuditLogModel.fromMap(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching audit history: $e');
      return [];
    }
  }

  /// Soft-archives an asset (quarantines record while strictly preserving history)
  static Future<void> archiveAsset({
    required String assetId,
    required String reason,
  }) async {
    final validUserId = await _resolveValidUserId();
    final now = DateTime.now();

    await _client.from('parish_assets').update({
      'is_archived': true,
      'archived_at': now.toIso8601String(),
      'archived_by': validUserId,
      'archive_reason': reason.trim(),
      'operational_status': 'Decommissioned',
      'updated_at': now.toIso8601String(),
    }).eq('asset_id', assetId);
  }

  /// Restores an archived asset back to active inventory
  static Future<void> restoreAsset(String assetId) async {
    final now = DateTime.now();

    await _client.from('parish_assets').update({
      'is_archived': false,
      'archived_at': null,
      'archived_by': null,
      'archive_reason': null,
      'operational_status': 'Active',
      'updated_at': now.toIso8601String(),
    }).eq('asset_id', assetId);
  }
}