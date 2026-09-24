import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/pos_item_model.dart';

class ParticularsService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Fetches all particulars/offerings from public.parish_particulars.
  /// Automatically seeds defaults into database if table is empty.
  static Future<List<PosItemModel>> getParticulars({bool activeOnly = true}) async {
    try {
      var query = _client.from('parish_particulars').select();

      if (activeOnly) {
        query = query.eq('is_active', true);
      }

      final response = await query
          .order('category', ascending: true)
          .order('title', ascending: true);

      final list = (response as List)
          .map((row) => PosItemModel.fromMap(row as Map<String, dynamic>))
          .toList();

      if (list.isEmpty) {
        // Auto-seed initial catalog defaults into database
        await seedDefaultParticulars();
        return getParticulars(activeOnly: activeOnly);
      }

      return list;
    } catch (_) {
      // Fallback to local defaults if offline or table is being created
      if (activeOnly) {
        return PosItemModel.initialDefaults.where((p) => p.isActive).toList();
      }
      return PosItemModel.initialDefaults;
    }
  }

  /// Creates a new particular/offering item
  static Future<PosItemModel> createParticular({
    required String title,
    required String category,
    required double defaultPrice,
    required String description,
    String iconName = 'church',
    bool allowsCustomPrice = false,
  }) async {
    final particularId = 'PRT-${DateTime.now().millisecondsSinceEpoch}';

    final data = {
      'particular_id': particularId,
      'title': title.trim(),
      'category': category.trim(),
      'default_price': defaultPrice,
      'description': description.trim(),
      'icon_name': iconName,
      'allows_custom_price': allowsCustomPrice,
      'is_active': true,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    final response = await _client
        .from('parish_particulars')
        .insert(data)
        .select()
        .single();

    return PosItemModel.fromMap(response);
  }

  /// Updates an existing particular/offering item
  static Future<PosItemModel> updateParticular(PosItemModel item) async {
    final data = item.toMap();
    data['updated_at'] = DateTime.now().toIso8601String();
    data.remove('created_at');

    final response = await _client
        .from('parish_particulars')
        .update(data)
        .eq('particular_id', item.id)
        .select()
        .single();

    return PosItemModel.fromMap(response);
  }

  /// Toggles active status (Soft delete / deactivate)
  static Future<void> toggleStatus(String particularId, bool isActive) async {
    await _client.from('parish_particulars').update({
      'is_active': isActive,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('particular_id', particularId);
  }

  /// Hard deletes an offering from the catalog
  static Future<void> deleteParticular(String particularId) async {
    await _client
        .from('parish_particulars')
        .delete()
        .eq('particular_id', particularId);
  }

  /// Seeds default catalog items into the database
  static Future<void> seedDefaultParticulars() async {
    try {
      final rows = PosItemModel.initialDefaults.map((p) => p.toMap()).toList();
      await _client.from('parish_particulars').upsert(rows);
    } catch (_) {}
  }
}