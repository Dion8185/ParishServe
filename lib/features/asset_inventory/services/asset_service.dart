import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/services/auth_service.dart';
import '../models/asset_audit_log_model.dart';
import '../models/asset_model.dart';

class AssetService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Fetches registered parish assets with optional filtering (active vs archived, section, category, etc.)
  static Future<List<AssetModel>> getAssets({
    bool includeArchived = false,
    String? categoryFilter,
    String? locationFilter,
    String? conditionFilter,
    String? sectionFilter, // 'Section 1', 'Section 2', or null
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
        query = query.eq('is_archived', false).neq('operational_status', 'Decommissioned');
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

      if (sectionFilter != null && sectionFilter != 'All') {
        if (sectionFilter.contains('Section 1') || sectionFilter.contains('10,000.00 and Above')) {
          query = query.gte('unit_price', 10000.0);
        } else if (sectionFilter.contains('Section 2') || sectionFilter.contains('Below 10,000.00')) {
          query = query.lt('unit_price', 10000.0);
        }
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

  /// Atomically invokes Postgres stored procedure to generate a single Diocesan Control Number
  static Future<String> generateControlNumber({
    required String locationAcronym,
    required String classificationAcronym,
    required int acquisitionYear,
  }) async {
    final batch = await generateControlNumberBatch(
      locationAcronym: locationAcronym,
      classificationAcronym: classificationAcronym,
      acquisitionYear: acquisitionYear,
      count: 1,
    );
    return batch.first;
  }

  /// Atomically generates consecutive Diocesan Control Numbers for bulk registrations:
  /// LOCATION-CLASSIFICATION-YEAR-SEQUENCE (e.g. C-FF-2026-001, C-FF-2026-002, ...)
  static Future<List<String>> generateControlNumberBatch({
    required String locationAcronym,
    required String classificationAcronym,
    required int acquisitionYear,
    required int count,
  }) async {
    final safeCount = count > 0 ? count : 1;
    final locClean = locationAcronym.trim().toUpperCase();
    final clsClean = classificationAcronym.trim().toUpperCase();

    try {
      final List<dynamic> result = await _client.rpc(
        'generate_diocesan_asset_control_number_batch',
        params: {
          'p_location_acronym': locClean,
          'p_classification_acronym': clsClean,
          'p_acquisition_year': acquisitionYear,
          'p_count': safeCount,
        },
      );

      if (result.isNotEmpty) {
        return result.map((r) => r['control_number'].toString().trim()).toList();
      }
    } catch (e) {
      debugPrint('Batch RPC notice: $e. Falling back to sequential generator.');
    }

    // Fallback: Query highest sequence locally and generate consecutive strings
    final prefix = '$locClean-$clsClean-$acquisitionYear-';
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

    final List<String> list = [];
    for (int i = 1; i <= safeCount; i++) {
      list.add('$prefix${(highestSeq + i).toString().padLeft(3, '0')}');
    }
    return list;
  }

  /// Generates a permanent canonical UUID v4 for Asset ID and QR Code Token
  static String generatePermanentIdentifier(String prefix) {
    final rand = Random.secure();
    final values = List<int>.generate(8, (_) => rand.nextInt(256));
    final token = values.map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
    return '$prefix-$token';
  }

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

  /// Registers a single asset record (Quantity: 1)
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
    double unitPrice = 0.0,
    String? rfidTag,
    String conditionStatus = 'VERIFIED / GOOD',
    String operationalStatus = 'Active',
  }) async {
    final results = await registerBulkAssets(
      itemName: itemName,
      quantity: 1,
      unitPrice: unitPrice,
      classificationId: classificationId,
      classificationAcronym: classificationAcronym,
      classificationName: classificationName,
      locationId: locationId,
      locationAcronym: locationAcronym,
      locationName: locationName,
      dimensions: dimensions,
      color: color,
      model: model,
      others: others,
      remarks: remarks,
      photoUrl: photoUrl,
      dateOfAcquisition: dateOfAcquisition,
      modeOfAcquisition: modeOfAcquisition,
      rfidTag: rfidTag,
      conditionStatus: conditionStatus,
      operationalStatus: operationalStatus,
    );
    return results.first;
  }

  /// Bulk Asset Registration Workflow:
  /// Takes shared properties and a quantity count (e.g. 16 Church Pews @ ₱15,000.00).
  /// Generates 16 distinct consecutive Diocesan Control Numbers (C-FF-2026-001 ... 016),
  /// 16 unique Asset IDs, and 16 unique QR codes, inserting 16 individual records in database.
  static Future<List<AssetModel>> registerBulkAssets({
    required String itemName,
    required int quantity,
    required double unitPrice,
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
    String? rfidTag,
    String conditionStatus = 'VERIFIED / GOOD',
    String operationalStatus = 'Active',
  }) async {
    final cleanItemName = itemName.trim();
    if (cleanItemName.isEmpty) throw 'Asset designation / item name is required.';
    if (quantity <= 0) throw 'Quantity must be a positive whole number (at least 1).';

    final validUserId = await _resolveValidUserId();
    final int acquisitionYear = dateOfAcquisition.year;
    final now = DateTime.now();
    final bool isDecommissioned = operationalStatus.trim().toLowerCase() == 'decommissioned';

    // 1. Generate consecutive control numbers atomically
    final controlNumbers = await generateControlNumberBatch(
      locationAcronym: locationAcronym,
      classificationAcronym: classificationAcronym,
      acquisitionYear: acquisitionYear,
      count: quantity,
    );

    final String bulkBatchId = 'BATCH-${now.millisecondsSinceEpoch}-${Random().nextInt(9999)}';
    final double safeUnitPrice = unitPrice >= 0.0 ? unitPrice : 0.0;
    final String dateString = '${dateOfAcquisition.year}-${dateOfAcquisition.month.toString().padLeft(2, '0')}-${dateOfAcquisition.day.toString().padLeft(2, '0')}';

    final List<Map<String, dynamic>> payloads = [];
    final List<Map<String, dynamic>> auditLogs = [];

    for (int i = 0; i < quantity; i++) {
      final String assetId = generatePermanentIdentifier('AST');
      final String qrCodeToken = generatePermanentIdentifier('QR');
      final String controlNumber = controlNumbers[i];

      // Format individual name if multiple items exist (e.g. Church Pew 001)
      final String itemDesignation = quantity > 1
          ? '$cleanItemName ${(i + 1).toString().padLeft(3, '0')}'
          : cleanItemName;

      payloads.add({
        'asset_id': assetId,
        'control_number': controlNumber,
        'item_name': itemDesignation,
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
        'date_of_acquisition': dateString,
        'acquisition_year': acquisitionYear,
        'mode_of_acquisition': modeOfAcquisition,
        'quantity': 1, // Each individual physical asset record represents 1 unit
        'unit_price': safeUnitPrice,
        'total_cost': safeUnitPrice, // 1 * unitPrice
        'cost': safeUnitPrice, // Legacy column compatibility
        'rfid_tag': (quantity == 1 && rfidTag != null && rfidTag.trim().isNotEmpty) ? rfidTag.trim() : null,
        'qr_code_token': qrCodeToken,
        'condition_status': conditionStatus,
        'operational_status': operationalStatus,
        'is_archived': isDecommissioned,
        'archived_at': isDecommissioned ? now.toIso8601String() : null,
        'archived_by': isDecommissioned ? validUserId : null,
        'archive_reason': isDecommissioned ? 'Registered with Decommissioned status.' : null,
        'bulk_batch_id': quantity > 1 ? bulkBatchId : null,
        'item_sequence_in_batch': quantity > 1 ? (i + 1) : null,
        'registration_date': now.toIso8601String(),
        'created_by': validUserId,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        // Legacy column compatibility
        'category': classificationName ?? classificationAcronym,
        'storage_location': locationName ?? locationAcronym,
        'acquisition_date': dateString,
        'acquisition_mode': modeOfAcquisition,
        'description': remarks ?? others ?? itemDesignation,
      });

      auditLogs.add({
        'audit_id': 'AUD-${now.millisecondsSinceEpoch}-$i',
        'asset_id': assetId,
        'control_number': controlNumber,
        'audited_by': validUserId,
        'previous_condition': null,
        'new_condition': conditionStatus,
        'previous_location': null,
        'new_location': locationName ?? locationAcronym,
        'audit_method': 'MANUAL',
        'audit_notes': quantity > 1
            ? 'Registered as part of bulk registration (${i + 1} of $quantity).'
            : 'Initial registration in parish inventory.',
        'audited_at': now.toIso8601String(),
      });
    }

    // 2. Perform bulk insert in a single transaction
    final List<dynamic> response = await _client
        .from('parish_assets')
        .insert(payloads)
        .select();

    // 3. Log initial audit records
    try {
      await _client.from('asset_audit_logs').insert(auditLogs);
    } catch (e) {
      debugPrint('Non-blocking initial bulk audit log note: $e');
    }

    return response.map((row) => AssetModel.fromMap(row as Map<String, dynamic>)).toList();
  }

  /// Updates an individual asset record independently while strictly preserving its Control Number
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
    int quantity = 1,
    required double unitPrice,
    String? rfidTag,
    required String conditionStatus,
    required String operationalStatus,
  }) async {
    final cleanItemName = itemName.trim();
    if (cleanItemName.isEmpty) throw 'Asset designation / item name is required.';
    if (quantity <= 0) throw 'Quantity must be a positive whole number (at least 1).';

    final validUserId = await _resolveValidUserId();
    final now = DateTime.now();
    final bool isDecommissioned = operationalStatus.trim().toLowerCase() == 'decommissioned';
    final double safeUnitPrice = unitPrice >= 0.0 ? unitPrice : 0.0;
    final double safeTotalCost = quantity * safeUnitPrice;

    // Check RFID uniqueness if being modified or assigned
    if (rfidTag != null && rfidTag.trim().isNotEmpty) {
      final cleanRfid = rfidTag.trim();
      final duplicate = await _client
          .from('parish_assets')
          .select('asset_id, control_number')
          .eq('rfid_tag', cleanRfid)
          .neq('asset_id', assetId)
          .maybeSingle();

      if (duplicate != null) {
        throw 'RFID Tag "$cleanRfid" is already assigned to asset ${duplicate['control_number']}.';
      }
    }

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
      'quantity': quantity,
      'unit_price': safeUnitPrice,
      'total_cost': safeTotalCost,
      'cost': safeTotalCost, // Legacy column compatibility
      'rfid_tag': rfidTag?.trim().isEmpty ?? true ? null : rfidTag!.trim(),
      'condition_status': conditionStatus,
      'operational_status': operationalStatus,
      'is_archived': isDecommissioned,
      if (isDecommissioned) ...{
        'archived_at': now.toIso8601String(),
        'archived_by': validUserId,
        'archive_reason': 'Operational status set to Decommissioned.',
      } else ...{
        'archived_at': null,
        'archived_by': null,
        'archive_reason': null,
      },
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
    String auditMethod = 'QR_SCAN',
    String? auditNotes,
  }) async {
    final validUserId = await _resolveValidUserId();
    final now = DateTime.now();

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

  /// Soft-archives an asset
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