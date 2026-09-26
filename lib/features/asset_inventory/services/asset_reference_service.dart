import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/asset_reference_models.dart';

class AssetReferenceService {
  static final SupabaseClient _client = Supabase.instance.client;

  // In-memory caches to reduce redundant queries during registration and editing
  static List<AssetLocationModel>? _cachedLocations;
  static List<AssetClassificationModel>? _cachedClassifications;

  // ===========================================================================
  // Standard Rigid Defaults (Matches Specification Exactly)
  // ===========================================================================

  static const List<AssetLocationModel> defaultLocations = [
    AssetLocationModel(
      locationId: 'LOC-C',
      acronym: 'C',
      locationName: 'Church',
      description: 'Main church building and its designated areas.',
    ),
    AssetLocationModel(
      locationId: 'LOC-S',
      acronym: 'S',
      locationName: 'Sacristy',
      description: 'Sacristy and designated storage areas for liturgical items.',
    ),
    AssetLocationModel(
      locationId: 'LOC-O',
      acronym: 'O',
      locationName: 'Office',
      description: 'Parish administrative offices.',
    ),
    AssetLocationModel(
      locationId: 'LOC-PO',
      acronym: 'PO',
      locationName: 'Pastoral Office',
      description:
      'Pastoral offices, including KoC, MBG, PFC, PPC, and other parish organizations.',
    ),
    AssetLocationModel(
      locationId: 'LOC-PEAC',
      acronym: 'PEAC',
      locationName: 'Parish Eucharistic Adoration Chapel',
      description: 'Parish Eucharistic Adoration Chapel.',
    ),
    AssetLocationModel(
      locationId: 'LOC-MH',
      acronym: 'MH',
      locationName: 'Multi-Purpose Hall',
      description: 'Parish multi-purpose hall and designated areas.',
    ),
    AssetLocationModel(
      locationId: 'LOC-OTH',
      acronym: 'OTH',
      locationName: 'Others',
      description: 'Additional locations that may be defined by authorized users.',
    ),
  ];

  static const List<AssetClassificationModel> defaultClassifications = [
    AssetClassificationModel(
      classificationId: 'CLS-SI',
      acronym: 'SI',
      classificationName: 'Sacred Image',
      description:
      'Religious images, statues, and other sacred representations.',
    ),
    AssetClassificationModel(
      classificationId: 'CLS-SV',
      acronym: 'SV',
      classificationName: 'Sacred Vessel',
      description: 'Sacred vessels used in liturgical celebrations.',
    ),
    AssetClassificationModel(
      classificationId: 'CLS-MI',
      acronym: 'MI',
      classificationName: 'Musical Instrument',
      description:
      'Musical instruments used for liturgical celebrations and parish activities.',
    ),
    AssetClassificationModel(
      classificationId: 'CLS-LB',
      acronym: 'LB',
      classificationName: 'Liturgical Book',
      description:
      'Liturgical books and other designated liturgical publications.',
    ),
    AssetClassificationModel(
      classificationId: 'CLS-FF',
      acronym: 'FF',
      classificationName: 'Furniture and Fixtures',
      description: 'Furniture, fixtures, and related parish furnishings.',
    ),
    AssetClassificationModel(
      classificationId: 'CLS-OE',
      acronym: 'OE',
      classificationName: 'Office Equipment',
      description: 'Equipment used for parish administrative operations.',
    ),
    AssetClassificationModel(
      classificationId: 'CLS-EE',
      acronym: 'EE',
      classificationName: 'Electrical Equipment',
      description: 'Electrical equipment and related devices.',
    ),
    AssetClassificationModel(
      classificationId: 'CLS-HT',
      acronym: 'HT',
      classificationName: 'Hand Tools',
      description: 'Tools used for maintenance and other parish activities.',
    ),
    AssetClassificationModel(
      classificationId: 'CLS-OTH',
      acronym: 'OTH',
      classificationName: 'Others',
      description:
      'Additional classifications that may be defined by authorized users.',
    ),
  ];

  // ===========================================================================
  // 1. Diocesan Location Management
  // ===========================================================================

  /// Fetches all diocesan locations. Automatically seeds defaults into database if table is empty.
  static Future<List<AssetLocationModel>> getLocations({bool activeOnly = true}) async {
    try {
      var query = _client.from('asset_locations').select();

      if (activeOnly) {
        query = query.eq('is_active', true);
      }

      final response = await query
          .order('acronym', ascending: true)
          .order('location_name', ascending: true);

      var list = (response as List)
          .map((row) => AssetLocationModel.fromMap(row as Map<String, dynamic>))
          .toList();

      // If database table is empty, auto-seed and return defaults
      if (list.isEmpty) {
        await seedDefaultLocations();
        return getLocations(activeOnly: activeOnly);
      }

      if (activeOnly) {
        _cachedLocations = list;
      }
      return list;
    } catch (e) {
      debugPrint('Error fetching asset locations: $e');
      if (activeOnly) {
        return defaultLocations.where((l) => l.isActive).toList();
      }
      return defaultLocations;
    }
  }

  /// Auto-seeds initial rigid locations into the database
  static Future<void> seedDefaultLocations() async {
    try {
      final rows = defaultLocations.map((l) => l.toMap()).toList();
      await _client.from('asset_locations').upsert(rows);
    } catch (e) {
      debugPrint('Error seeding default locations: $e');
    }
  }

  /// Creates a new location reference entry
  static Future<AssetLocationModel> createLocation({
    required String acronym,
    required String locationName,
    String? description,
  }) async {
    final cleanAcronym = acronym.trim().toUpperCase();
    final cleanName = locationName.trim();

    if (cleanAcronym.isEmpty) throw 'Location acronym is required.';
    if (cleanName.isEmpty) throw 'Location name is required.';

    final existing = await _client
        .from('asset_locations')
        .select('location_id')
        .ilike('acronym', cleanAcronym)
        .maybeSingle();

    if (existing != null) {
      throw 'A location with acronym "$cleanAcronym" already exists.';
    }

    final locationId = 'LOC-$cleanAcronym';
    final payload = {
      'location_id': locationId,
      'acronym': cleanAcronym,
      'location_name': cleanName,
      'description': description?.trim().isEmpty ?? true ? null : description!.trim(),
      'is_active': true,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    final response = await _client
        .from('asset_locations')
        .insert(payload)
        .select()
        .single();

    _cachedLocations = null;
    return AssetLocationModel.fromMap(response);
  }

  /// Updates an existing location's name and description. Acronym is preserved to prevent corrupting existing control numbers.
  static Future<AssetLocationModel> updateLocation({
    required String locationId,
    required String locationName,
    String? description,
    required bool isActive,
  }) async {
    final cleanName = locationName.trim();
    if (cleanName.isEmpty) throw 'Location name is required.';

    final response = await _client
        .from('asset_locations')
        .update({
      'location_name': cleanName,
      'description': description?.trim().isEmpty ?? true ? null : description!.trim(),
      'is_active': isActive,
      'updated_at': DateTime.now().toIso8601String(),
    })
        .eq('location_id', locationId)
        .select()
        .single();

    _cachedLocations = null;
    return AssetLocationModel.fromMap(response);
  }

  /// Safely checks whether any registered assets are currently associated with this location acronym before deletion
  static Future<bool> isLocationInUse(String acronym) async {
    try {
      final matches = await _client
          .from('parish_assets')
          .select('asset_id')
          .ilike('location_acronym', acronym.trim())
          .limit(1);

      return (matches as List).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Deletes a location entry only if no registered assets are currently assigned to it
  static Future<void> deleteLocation(String locationId, String acronym) async {
    final inUse = await isLocationInUse(acronym);
    if (inUse) {
      throw 'Cannot delete location "$acronym": Registered assets are currently assigned to this location. You may deactivate it instead.';
    }

    await _client.from('asset_locations').delete().eq('location_id', locationId);
    _cachedLocations = null;
  }

  // ===========================================================================
  // 2. Diocesan Asset Classification Management
  // ===========================================================================

  /// Fetches all asset classifications. Automatically seeds defaults into database if table is empty.
  static Future<List<AssetClassificationModel>> getClassifications({bool activeOnly = true}) async {
    try {
      var query = _client.from('asset_classifications').select();

      if (activeOnly) {
        query = query.eq('is_active', true);
      }

      final response = await query
          .order('acronym', ascending: true)
          .order('classification_name', ascending: true);

      var list = (response as List)
          .map((row) => AssetClassificationModel.fromMap(row as Map<String, dynamic>))
          .toList();

      // If database table is empty, auto-seed and return defaults
      if (list.isEmpty) {
        await seedDefaultClassifications();
        return getClassifications(activeOnly: activeOnly);
      }

      if (activeOnly) {
        _cachedClassifications = list;
      }
      return list;
    } catch (e) {
      debugPrint('Error fetching asset classifications: $e');
      if (activeOnly) {
        return defaultClassifications.where((c) => c.isActive).toList();
      }
      return defaultClassifications;
    }
  }

  /// Auto-seeds initial rigid classifications into the database
  static Future<void> seedDefaultClassifications() async {
    try {
      final rows = defaultClassifications.map((c) => c.toMap()).toList();
      await _client.from('asset_classifications').upsert(rows);
    } catch (e) {
      debugPrint('Error seeding default classifications: $e');
    }
  }

  /// Creates a new asset classification entry
  static Future<AssetClassificationModel> createClassification({
    required String acronym,
    required String classificationName,
    String? description,
  }) async {
    final cleanAcronym = acronym.trim().toUpperCase();
    final cleanName = classificationName.trim();

    if (cleanAcronym.isEmpty) throw 'Classification acronym is required.';
    if (cleanName.isEmpty) throw 'Classification name is required.';

    final existing = await _client
        .from('asset_classifications')
        .select('classification_id')
        .ilike('acronym', cleanAcronym)
        .maybeSingle();

    if (existing != null) {
      throw 'A classification with acronym "$cleanAcronym" already exists.';
    }

    final classificationId = 'CLS-$cleanAcronym';
    final payload = {
      'classification_id': classificationId,
      'acronym': cleanAcronym,
      'classification_name': cleanName,
      'description': description?.trim().isEmpty ?? true ? null : description!.trim(),
      'is_active': true,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    final response = await _client
        .from('asset_classifications')
        .insert(payload)
        .select()
        .single();

    _cachedClassifications = null;
    return AssetClassificationModel.fromMap(response);
  }

  /// Updates an existing classification's name and description. Acronym is preserved to safeguard control numbers.
  static Future<AssetClassificationModel> updateClassification({
    required String classificationId,
    required String classificationName,
    String? description,
    required bool isActive,
  }) async {
    final cleanName = classificationName.trim();
    if (cleanName.isEmpty) throw 'Classification name is required.';

    final response = await _client
        .from('asset_classifications')
        .update({
      'classification_name': cleanName,
      'description': description?.trim().isEmpty ?? true ? null : description!.trim(),
      'is_active': isActive,
      'updated_at': DateTime.now().toIso8601String(),
    })
        .eq('classification_id', classificationId)
        .select()
        .single();

    _cachedClassifications = null;
    return AssetClassificationModel.fromMap(response);
  }

  /// Safely checks whether any registered assets are currently associated with this classification acronym before deletion
  static Future<bool> isClassificationInUse(String acronym) async {
    try {
      final matches = await _client
          .from('parish_assets')
          .select('asset_id')
          .ilike('classification_acronym', acronym.trim())
          .limit(1);

      return (matches as List).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Deletes a classification entry only if no registered assets are currently assigned to it
  static Future<void> deleteClassification(String classificationId, String acronym) async {
    final inUse = await isClassificationInUse(acronym);
    if (inUse) {
      throw 'Cannot delete classification "$acronym": Registered assets are currently assigned to this classification. You may deactivate it instead.';
    }

    await _client.from('asset_classifications').delete().eq('classification_id', classificationId);
    _cachedClassifications = null;
  }
}