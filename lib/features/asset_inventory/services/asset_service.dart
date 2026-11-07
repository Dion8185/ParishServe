// =============================================================================
// FILE: lib/features/asset_inventory/services/asset_service.dart
// =============================================================================

import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/services/auth_service.dart';
import '../models/asset_audit_log_model.dart';
import '../models/asset_model.dart';

class AssetService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Fetches registered parish assets directly from parish_assets
  static Future<List<AssetModel>> getAssets({
    bool includeArchived = false,
    String? categoryFilter,
    String? locationFilter,
    String? conditionFilter,
    String? sectionFilter,
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
        query = query
            .eq('is_archived', false)
            .neq('operational_status', 'Decommissioned');
      }

      if (categoryFilter != null && categoryFilter != 'All') {
        query =
            query.eq('classification_acronym', categoryFilter.toUpperCase());
      }

      if (locationFilter != null && locationFilter != 'All') {
        query = query.eq('location_acronym', locationFilter.toUpperCase());
      }

      if (conditionFilter != null && conditionFilter != 'All') {
        query = query.eq('condition_status', conditionFilter);
      }

      if (sectionFilter != null && sectionFilter != 'All') {
        if (sectionFilter.contains('Section 1') ||
            sectionFilter.contains('10,000.00 and Above')) {
          query = query.gte('unit_price', 10000.0);
        } else if (sectionFilter.contains('Section 2') ||
            sectionFilter.contains('Below 10,000.00')) {
          query = query.lt('unit_price', 10000.0);
        }
      }

      final response = await query
          .order('registration_date', ascending: false)
          .order('created_at', ascending: false);

      final List<dynamic> rows = response as List;
      return rows
          .map((r) => AssetModel.fromMap(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching parish assets: $e');
      rethrow;
    }
  }

  /// Looks up a single asset by Control Number, Asset ID, QR Token, or RFID tag
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

  /// Real-time autocomplete suggestions for search-as-you-type lookup
  static Future<List<AssetModel>> searchAssetSuggestions(
      String query, {
        int limit = 6,
      }) async {
    final clean = query.trim();
    if (clean.isEmpty) return [];

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
          .or('control_number.ilike.%$clean%,item_name.ilike.%$clean%,rfid_tag.ilike.%$clean%,model.ilike.%$clean%')
          .order('control_number', ascending: true)
          .limit(limit);

      return (response as List)
          .map((row) => AssetModel.fromMap(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error searching asset suggestions: $e');
      return [];
    }
  }

  static Future<String?> uploadAssetPhoto({
    required String assetId,
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    try {
      final cleanExt = fileName.contains('.')
          ? fileName.split('.').last.toLowerCase()
          : 'jpg';
      final storagePath =
          'asset_photos/$assetId/photo_${DateTime.now().millisecondsSinceEpoch}.$cleanExt';

      await _client.storage.from('certificate-assets').uploadBinary(
        storagePath,
        fileBytes,
        fileOptions: FileOptions(
          contentType: 'image/$cleanExt',
          upsert: true,
        ),
      );

      return _client.storage
          .from('certificate-assets')
          .getPublicUrl(storagePath);
    } catch (e) {
      debugPrint('Error uploading asset photo: $e');
      return null;
    }
  }

  /// Calculates the next sequential number based on the last registered entry for
  /// the given location, classification, and acquisition year.
  static Future<int> getNextControlNumberSequence({
    required String locationAcronym,
    required String classificationAcronym,
    required int acquisitionYear,
  }) async {
    final locClean = locationAcronym.trim().toUpperCase();
    final clsClean = classificationAcronym.trim().toUpperCase();
    final prefix = '$locClean-$clsClean $acquisitionYear-';

    try {
      final List<dynamic> result = await _client.rpc(
        'generate_diocesan_asset_control_number_batch',
        params: {
          'p_location_acronym': locClean,
          'p_classification_acronym': clsClean,
          'p_acquisition_year': acquisitionYear,
          'p_count': 1,
        },
      );

      if (result.isNotEmpty) {
        final cNo =
            result.first['control_number']?.toString().trim() ?? '';
        final dashIdx = cNo.lastIndexOf('-');
        if (dashIdx != -1 && dashIdx < cNo.length - 1) {
          final parsed = int.tryParse(cNo.substring(dashIdx + 1));
          if (parsed != null && parsed > 0) return parsed;
        }
      }
    } catch (e) {
      debugPrint('RPC sequence lookup notice: $e. Falling back to table scan.');
    }

    try {
      final records = await _client
          .from('parish_assets')
          .select('control_number')
          .ilike('control_number', '$prefix%');

      int highestSeq = 0;
      for (final r in records) {
        final cNo = r['control_number']?.toString().trim() ?? '';
        final dashIndex = cNo.lastIndexOf('-');
        if (dashIndex != -1 && dashIndex < cNo.length - 1) {
          final parsed = int.tryParse(cNo.substring(dashIndex + 1));
          if (parsed != null && parsed > highestSeq) {
            highestSeq = parsed;
          }
        }
      }
      return highestSeq + 1;
    } catch (e) {
      debugPrint('Error getting next control sequence: $e');
      return 1;
    }
  }

  /// Verifies if a specific control number is already present in the ledger.
  static Future<bool> checkControlNumberExists(String controlNumber) async {
    final clean = controlNumber.trim();
    if (clean.isEmpty) return false;

    try {
      final response = await _client
          .from('parish_assets')
          .select('control_number')
          .ilike('control_number', clean)
          .maybeSingle();

      return response != null;
    } catch (_) {
      return false;
    }
  }

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
        return result
            .map((r) => r['control_number'].toString().trim())
            .toList();
      }
    } catch (e) {
      debugPrint('Batch RPC notice: $e. Falling back to sequence scanner.');
    }

    final records = await _client
        .from('parish_assets')
        .select('control_number');

    int highestSeq = 0;
    for (final r in records) {
      final cNo = r['control_number']?.toString() ?? '';
      final dashIndex = cNo.lastIndexOf('-');
      if (dashIndex != -1 && dashIndex < cNo.length - 1) {
        final parsed = int.tryParse(cNo.substring(dashIndex + 1));
        if (parsed != null && parsed > highestSeq) {
          highestSeq = parsed;
        }
      }
    }

    final prefix = '$locClean-$clsClean $acquisitionYear-';
    final List<String> list = [];
    for (int i = 1; i <= safeCount; i++) {
      list.add('$prefix${(highestSeq + i).toString().padLeft(3, '0')}');
    }
    return list;
  }

  static String generatePermanentIdentifier(String prefix) {
    final rand = Random.secure();
    final values = List<int>.generate(8, (_) => rand.nextInt(256));
    final token = values
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
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

  /// Registers a parish asset with an assigned Control Number (custom modified or auto-generated)
  /// and specified quantity count.
  static Future<AssetModel> registerAsset({
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
    String? customControlNumber,
  }) async {
    final cleanItemName = itemName.trim();
    if (cleanItemName.isEmpty) throw 'Item name is required.';
    if (quantity <= 0) throw 'Quantity must be at least 1.';

    final validUserId = await _resolveValidUserId();
    final int acquisitionYear = dateOfAcquisition.year;
    final now = DateTime.now();
    final bool isDecommissioned =
        operationalStatus.trim().toLowerCase() == 'decommissioned';

    String assignedControlNumber;
    if (customControlNumber != null && customControlNumber.trim().isNotEmpty) {
      final cleanCustom = customControlNumber.trim().toUpperCase();
      final exists = await checkControlNumberExists(cleanCustom);
      if (exists) {
        throw 'Control Number "$cleanCustom" is already registered to another item. Please choose a different sequence number.';
      }
      assignedControlNumber = cleanCustom;
    } else {
      final controlNumbers = await generateControlNumberBatch(
        locationAcronym: locationAcronym,
        classificationAcronym: classificationAcronym,
        acquisitionYear: acquisitionYear,
        count: 1,
      );
      assignedControlNumber = controlNumbers.first;
    }

    final double safeUnitPrice = unitPrice >= 0.0 ? unitPrice : 0.0;
    final double calculatedTotalCost = quantity * safeUnitPrice;
    final String dateString =
        '${dateOfAcquisition.year}-${dateOfAcquisition.month.toString().padLeft(2, '0')}-${dateOfAcquisition.day.toString().padLeft(2, '0')}';

    final String assetId = generatePermanentIdentifier('AST');
    final String qrCodeToken = generatePermanentIdentifier('QR');

    final payload = {
      'asset_id': assetId,
      'control_number': assignedControlNumber,
      'item_name': cleanItemName,
      'classification_id': classificationId,
      'classification_acronym': classificationAcronym.trim().toUpperCase(),
      'location_id': locationId,
      'location_acronym': locationAcronym.trim().toUpperCase(),
      'dimensions':
      dimensions?.trim().isEmpty ?? true ? null : dimensions!.trim(),
      'color': color?.trim().isEmpty ?? true ? null : color!.trim(),
      'model': model?.trim().isEmpty ?? true ? null : model!.trim(),
      'others': others?.trim().isEmpty ?? true ? null : others!.trim(),
      'remarks': remarks?.trim().isEmpty ?? true ? null : remarks!.trim(),
      'photo_url': photoUrl?.trim().isEmpty ?? true ? null : photoUrl!.trim(),
      'date_of_acquisition': dateString,
      'acquisition_year': acquisitionYear,
      'mode_of_acquisition': modeOfAcquisition,
      'quantity': quantity,
      'unit_price': safeUnitPrice,
      'total_cost': calculatedTotalCost,
      'cost': calculatedTotalCost,
      'rfid_tag': (rfidTag != null && rfidTag.trim().isNotEmpty)
          ? rfidTag.trim()
          : null,
      'qr_code_token': qrCodeToken,
      'condition_status': conditionStatus,
      'operational_status': operationalStatus,
      'is_archived': isDecommissioned,
      'archived_at': isDecommissioned ? now.toIso8601String() : null,
      'archived_by': isDecommissioned ? validUserId : null,
      'archive_reason': isDecommissioned
          ? 'Registered with Decommissioned status.'
          : null,
      'bulk_batch_id': null,
      'item_sequence_in_batch': null,
      'registration_date': now.toIso8601String(),
      'created_by': validUserId,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
      'category': classificationName ?? classificationAcronym,
      'storage_location': locationName ?? locationAcronym,
      'acquisition_date': dateString,
      'acquisition_mode': modeOfAcquisition,
      'description': remarks ?? others ?? cleanItemName,
    };

    final response = await _client
        .from('parish_assets')
        .insert(payload)
        .select()
        .single();

    try {
      await _client.from('asset_audit_logs').insert({
        'audit_id': 'AUD-${now.millisecondsSinceEpoch}',
        'asset_id': assetId,
        'control_number': assignedControlNumber,
        'audited_by': validUserId,
        'previous_condition': null,
        'new_condition': conditionStatus,
        'previous_status': null,
        'new_status': operationalStatus,
        'previous_location': null,
        'new_location': locationName ?? locationAcronym,
        'audit_method': 'MANUAL',
        'audit_notes':
        'Initial registration in parish inventory ($quantity unit(s)).',
        'audited_at': now.toIso8601String(),
      });
    } catch (e) {
      debugPrint('Initial audit log notice: $e');
    }

    return AssetModel.fromMap(response);
  }

  /// Backward-compatible alias for single-record registration
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
    String? customControlNumber,
  }) async {
    final asset = await registerAsset(
      itemName: itemName,
      quantity: quantity,
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
      customControlNumber: customControlNumber,
    );
    return [asset];
  }

  /// Updates an asset record. Control Number remains strictly locked and preserved.
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
    if (cleanItemName.isEmpty) throw 'Item name is required.';

    final validUserId = await _resolveValidUserId();
    final now = DateTime.now();
    final bool isDecommissioned =
        operationalStatus.trim().toLowerCase() == 'decommissioned';
    final double safeUnitPrice = unitPrice >= 0.0 ? unitPrice : 0.0;
    final double safeTotalCost = quantity * safeUnitPrice;

    final updatePayload = {
      'item_name': cleanItemName,
      'classification_id': classificationId,
      'classification_acronym': classificationAcronym.trim().toUpperCase(),
      'location_id': locationId,
      'location_acronym': locationAcronym.trim().toUpperCase(),
      'dimensions':
      dimensions?.trim().isEmpty ?? true ? null : dimensions!.trim(),
      'color': color?.trim().isEmpty ?? true ? null : color!.trim(),
      'model': model?.trim().isEmpty ?? true ? null : model!.trim(),
      'others': others?.trim().isEmpty ?? true ? null : others!.trim(),
      'remarks': remarks?.trim().isEmpty ?? true ? null : remarks!.trim(),
      if (photoUrl != null) 'photo_url': photoUrl.trim(),
      'date_of_acquisition':
      '${dateOfAcquisition.year}-${dateOfAcquisition.month.toString().padLeft(2, '0')}-${dateOfAcquisition.day.toString().padLeft(2, '0')}',
      'acquisition_year': dateOfAcquisition.year,
      'mode_of_acquisition': modeOfAcquisition,
      'quantity': quantity > 0 ? quantity : 1,
      'unit_price': safeUnitPrice,
      'total_cost': safeTotalCost,
      'cost': safeTotalCost,
      'rfid_tag':
      rfidTag?.trim().isEmpty ?? true ? null : rfidTag!.trim(),
      'condition_status': conditionStatus,
      'operational_status': operationalStatus,
      'is_archived': isDecommissioned,
      'updated_at': now.toIso8601String(),
    };

    final response = await _client
        .from('parish_assets')
        .update(updatePayload)
        .eq('asset_id', assetId)
        .select()
        .single();

    return AssetModel.fromMap(response);
  }

  /// Records an audit inspection with quantity adjustment tracking and accountability reasons
  static Future<void> recordAuditScan({
    required String assetId,
    required String controlNumber,
    required String newCondition,
    String? previousCondition,
    required String newStatus,
    String? previousStatus,
    String? previousLocation,
    String? newLocation,
    String auditMethod = 'QR_SCAN',
    String? auditNotes,
    int? previousQuantity,
    int? newQuantity,
    String? quantityChangeReason,
    bool auditEntireGroup = false,
    List<String> groupAssetIds = const [],
  }) async {
    final validUserId = await _resolveValidUserId();
    final now = DateTime.now();

    final bool hasQtyChange = previousQuantity != null &&
        newQuantity != null &&
        previousQuantity != newQuantity;

    String combinedNotes = '';

    if (hasQtyChange) {
      final change = newQuantity - previousQuantity;
      final sign = change > 0 ? '+$change' : '$change';
      final reason = (quantityChangeReason != null &&
          quantityChangeReason.trim().isNotEmpty)
          ? quantityChangeReason.trim()
          : 'Quantity updated during inspection';

      combinedNotes +=
      '[QTY_ADJUST: from $previousQuantity to $newQuantity ($sign) | REASON: $reason]\n';
    }

    if (auditNotes != null && auditNotes.trim().isNotEmpty) {
      combinedNotes += auditNotes.trim();
    }

    final finalNotes =
    combinedNotes.trim().isEmpty ? null : combinedNotes.trim();

    await _client.from('asset_audit_logs').insert({
      'audit_id': 'AUD-${now.millisecondsSinceEpoch}',
      'asset_id': assetId,
      'control_number': controlNumber,
      'audited_by': validUserId,
      'previous_condition': previousCondition,
      'new_condition': newCondition,
      'previous_status': previousStatus,
      'new_status': newStatus,
      'previous_location': previousLocation,
      'new_location': newLocation,
      'audit_method': auditMethod,
      'audit_notes': finalNotes,
      'audited_at': now.toIso8601String(),
    });

    final Map<String, dynamic> assetUpdates = {
      'condition_status': newCondition,
      'operational_status': newStatus,
      'last_audited_at': now.toIso8601String(),
      'audited_by': validUserId,
      'updated_at': now.toIso8601String(),
    };

    if (hasQtyChange && newQuantity > 0) {
      assetUpdates['quantity'] = newQuantity;

      try {
        final current = await _client
            .from('parish_assets')
            .select('unit_price')
            .eq('asset_id', assetId)
            .maybeSingle();

        if (current != null && current['unit_price'] != null) {
          final double uPrice =
              double.tryParse(current['unit_price'].toString()) ?? 0.0;
          assetUpdates['total_cost'] = newQuantity * uPrice;
          assetUpdates['cost'] = newQuantity * uPrice;
        }
      } catch (_) {}
    }

    await _client
        .from('parish_assets')
        .update(assetUpdates)
        .eq('asset_id', assetId);
  }

  static Future<List<AssetAuditLogModel>> getAssetAuditHistory(
      String assetId) async {
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

  static Future<void> restoreAsset(String assetId) async {
    await _client.from('parish_assets').update({
      'is_archived': false,
      'archived_at': null,
      'archived_by': null,
      'archive_reason': null,
      'operational_status': 'Active',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('asset_id', assetId);
  }
}