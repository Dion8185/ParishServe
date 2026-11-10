// =============================================================================
// FILE: lib/features/asset_inventory/services/asset_draft_service.dart
// =============================================================================

import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/services/auth_service.dart';
import '../models/asset_draft_model.dart';

class AssetDraftService {
  AssetDraftService._();

  static final SupabaseClient _client = Supabase.instance.client;

  /// Reactive notifier to track pending drafts count across dashboard navigation
  static final ValueNotifier<int> draftCountNotifier = ValueNotifier<int>(0);

  /// Initializes draft count from Supabase on launch
  static Future<void> initialize() async {
    try {
      final response = await _client
          .from('asset_drafts')
          .select('draft_id');
      draftCountNotifier.value = (response as List).length;
    } catch (e) {
      debugPrint('Notice initializing cloud asset drafts: $e');
    }
  }

  /// Uploads a draft's photograph to Supabase Storage and returns its public URL
  static Future<String?> uploadDraftPhoto({
    required String draftId,
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    try {
      final cleanExt = fileName.contains('.')
          ? fileName.split('.').last.toLowerCase()
          : 'jpg';
      final storagePath =
          'asset_photos/drafts/$draftId/photo_${DateTime.now().millisecondsSinceEpoch}.$cleanExt';

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
      debugPrint('Error uploading draft photo to Supabase storage: $e');
      return null;
    }
  }

  /// Fetches all asset registration drafts from Supabase, sorted latest first
  static Future<List<AssetDraftModel>> getAllDrafts() async {
    try {
      final response = await _client
          .from('asset_drafts')
          .select()
          .order('updated_at', ascending: false);

      final List<dynamic> rows = response as List;
      final drafts = rows
          .map((r) => AssetDraftModel.fromMap(r as Map<String, dynamic>))
          .toList();

      draftCountNotifier.value = drafts.length;
      return drafts;
    } catch (e) {
      debugPrint('Error querying cloud asset drafts: $e');
      return [];
    }
  }

  /// Saves or updates a draft in the Supabase `asset_drafts` table
  static Future<void> saveDraft(AssetDraftModel draft) async {
    try {
      final currentUserId = AuthService.currentUser?.userId;
      final now = DateTime.now();

      final payload = draft.toMap();
      payload['created_by'] = currentUserId ?? draft.createdBy;
      payload['updated_at'] = now.toIso8601String();

      await _client.from('asset_drafts').upsert(payload);
      await initialize();
    } catch (e) {
      debugPrint('Error saving draft to Supabase cloud: $e');
      rethrow;
    }
  }

  /// Deletes a specific draft from Supabase
  static Future<void> deleteDraft(String draftId) async {
    try {
      await _client
          .from('asset_drafts')
          .delete()
          .eq('draft_id', draftId);

      await initialize();
    } catch (e) {
      debugPrint('Error deleting draft from Supabase: $e');
      rethrow;
    }
  }

  /// Discards all drafts from Supabase
  static Future<void> clearAllDrafts() async {
    try {
      await _client
          .from('asset_drafts')
          .delete()
          .neq('draft_id', '');

      draftCountNotifier.value = 0;
    } catch (e) {
      debugPrint('Error clearing cloud drafts: $e');
      rethrow;
    }
  }
}