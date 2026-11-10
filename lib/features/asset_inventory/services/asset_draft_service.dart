// =============================================================================
// FILE: lib/features/asset_inventory/services/asset_draft_service.dart
// =============================================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/asset_draft_model.dart';

class AssetDraftService {
  AssetDraftService._();

  static const String _storageKey = 'parish_asset_registration_drafts_v1';

  /// ValueNotifier to allow UI components (like badges) to reactively track draft counts
  static final ValueNotifier<int> draftCountNotifier = ValueNotifier<int>(0);

  /// Initializes draft count on app launch
  static Future<void> initialize() async {
    final drafts = await getAllDrafts();
    draftCountNotifier.value = drafts.length;
  }

  /// Retrieves all saved registration drafts, sorted latest updated first
  static Future<List<AssetDraftModel>> getAllDrafts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? rawJson = prefs.getString(_storageKey);
      if (rawJson == null || rawJson.trim().isEmpty) {
        draftCountNotifier.value = 0;
        return [];
      }

      final List<dynamic> list = jsonDecode(rawJson) as List<dynamic>;
      final drafts = list
          .map((item) => AssetDraftModel.fromMap(item as Map<String, dynamic>))
          .toList();

      drafts.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      draftCountNotifier.value = drafts.length;
      return drafts;
    } catch (e) {
      debugPrint('Error retrieving asset drafts: $e');
      return [];
    }
  }

  /// Saves or updates a draft
  static Future<void> saveDraft(AssetDraftModel draft) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final drafts = await getAllDrafts();

      final existingIndex = drafts.indexWhere((d) => d.draftId == draft.draftId);
      if (existingIndex >= 0) {
        drafts[existingIndex] = draft;
      } else {
        drafts.insert(0, draft);
      }

      final encoded = jsonEncode(drafts.map((d) => d.toMap()).toList());
      await prefs.setString(_storageKey, encoded);
      draftCountNotifier.value = drafts.length;
    } catch (e) {
      debugPrint('Error saving asset draft: $e');
      rethrow;
    }
  }

  /// Deletes a specific draft
  static Future<void> deleteDraft(String draftId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final drafts = await getAllDrafts();

      drafts.removeWhere((d) => d.draftId == draftId);

      final encoded = jsonEncode(drafts.map((d) => d.toMap()).toList());
      await prefs.setString(_storageKey, encoded);
      draftCountNotifier.value = drafts.length;
    } catch (e) {
      debugPrint('Error deleting asset draft: $e');
      rethrow;
    }
  }

  /// Clears all stored drafts
  static Future<void> clearAllDrafts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
      draftCountNotifier.value = 0;
    } catch (e) {
      debugPrint('Error clearing asset drafts: $e');
    }
  }
}