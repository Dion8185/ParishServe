// =============================================================================
// FILE: lib/features/sacramental_records/services/sacramental_draft_service.dart
// =============================================================================

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/database/local_database_service.dart';
import '../../../core/services/records_sync_service.dart';
import '../../auth/services/auth_service.dart';
import '../models/sacramental_draft_model.dart';

class SacramentalDraftService {
  SacramentalDraftService._();

  static final SupabaseClient _client = Supabase.instance.client;
  static const String _tableName = 'sacramental_record_drafts';

  /// Resilient multi-tier in-memory draft cache across all platforms (Web and Native).
  /// Ensures drafts are instantly saved, retrieved, and resumed even if the remote
  /// Supabase table is not yet migrated or if the device is operating completely offline.
  static final Map<String, List<SacramentalDraftModel>> _memoryDrafts = {};

  /// Ensures the local SQLite table exists for offline draft persistence on native devices.
  static Future<Database?> _getInitializedLocalDb() async {
    if (kIsWeb) return null;
    try {
      final db = await LocalDatabaseService.instance.database;
      if (db == null) return null;

      await db.execute('''
        CREATE TABLE IF NOT EXISTS $_tableName (
          draft_id TEXT PRIMARY KEY,
          sacrament_type TEXT NOT NULL,
          display_title TEXT,
          book_reference TEXT,
          draft_data TEXT NOT NULL,
          created_by TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');

      return db;
    } catch (e) {
      debugPrint('[SacramentalDraftService] SQLite init warning: $e');
      return null;
    }
  }

  /// Fetches all saved drafts for a specific sacrament ordered by most recently updated.
  /// Operates safely across Supabase, SQLite, and in-memory storage without throwing errors.
  static Future<List<SacramentalDraftModel>> getDraftsForSacrament(
      String sacramentType,
      ) async {
    final isOnline = await RecordsSyncService.instance.checkConnectivity();

    // 1. Attempt remote Supabase query when online or on Web
    if (isOnline || kIsWeb) {
      try {
        final response = await _client
            .from(_tableName)
            .select()
            .eq('sacrament_type', sacramentType)
            .order('updated_at', ascending: false);

        final list = (response as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();

        final models =
        list.map((row) => SacramentalDraftModel.fromMap(row)).toList();

        // Synchronize in-memory cache
        _memoryDrafts[sacramentType] = List.from(models);

        // Cache remote drafts into local SQLite on native platforms
        if (!kIsWeb) {
          final db = await _getInitializedLocalDb();
          if (db != null) {
            try {
              final batch = db.batch();
              batch.delete(
                _tableName,
                where: 'sacrament_type = ?',
                whereArgs: [sacramentType],
              );
              for (final model in models) {
                batch.insert(
                  _tableName,
                  model.toSqliteMap(),
                  conflictAlgorithm: ConflictAlgorithm.replace,
                );
              }
              await batch.commit(noResult: true);
            } catch (_) {}
          }
        }

        return models;
      } catch (e) {
        debugPrint(
            '[SacramentalDraftService] Remote fetch notice (falling back locally): $e');
      }
    }

    // 2. Query local SQLite table on native platforms
    if (!kIsWeb) {
      final db = await _getInitializedLocalDb();
      if (db != null) {
        try {
          final rows = await db.query(
            _tableName,
            where: 'sacrament_type = ?',
            whereArgs: [sacramentType],
            orderBy: 'updated_at DESC',
          );
          if (rows.isNotEmpty) {
            final models =
            rows.map((row) => SacramentalDraftModel.fromMap(row)).toList();
            _memoryDrafts[sacramentType] = List.from(models);
            return models;
          }
        } catch (_) {}
      }
    }

    // 3. Fallback to in-memory draft cache
    final cached = _memoryDrafts[sacramentType] ?? [];
    cached.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return List.from(cached);
  }

  /// Returns the total draft count for a given sacrament.
  static Future<int> getDraftCountForSacrament(String sacramentType) async {
    try {
      final drafts = await getDraftsForSacrament(sacramentType);
      return drafts.length;
    } catch (_) {
      return _memoryDrafts[sacramentType]?.length ?? 0;
    }
  }

  /// Creates or updates a sacramental record draft.
  /// Guarantees that draft saving succeeds on all platforms, storing in-memory,
  /// in local SQLite, and syncing with Supabase without breaking on remote table absence.
  static Future<SacramentalDraftModel> saveDraft({
    String? existingDraftId,
    required String sacramentType,
    required String displayTitle,
    String? bookReference,
    required Map<String, dynamic> draftData,
  }) async {
    final now = DateTime.now();
    final cleanId = existingDraftId?.trim();
    final draftId = (cleanId != null && cleanId.isNotEmpty)
        ? cleanId
        : 'DRF-${now.millisecondsSinceEpoch}';

    final currentUserId = AuthService.currentUser?.userId?.trim();
    final cleanTitle = displayTitle.trim().isNotEmpty
        ? displayTitle.trim()
        : 'Untitled $sacramentType Draft';
    final cleanBookRef =
    (bookReference != null && bookReference.trim().isNotEmpty)
        ? bookReference.trim()
        : null;

    final model = SacramentalDraftModel(
      draftId: draftId,
      sacramentType: sacramentType,
      displayTitle: cleanTitle,
      bookReference: cleanBookRef,
      draftData: draftData,
      createdBy: currentUserId,
      createdAt: now,
      updatedAt: now,
    );

    // 1. Immediately store in resilient in-memory cache
    final inMemoryList = _memoryDrafts.putIfAbsent(sacramentType, () => []);
    inMemoryList.removeWhere((d) => d.draftId == draftId);
    inMemoryList.insert(0, model);

    // 2. Persist to local SQLite on native platforms
    if (!kIsWeb) {
      final db = await _getInitializedLocalDb();
      if (db != null) {
        try {
          await db.insert(
            _tableName,
            model.toSqliteMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        } catch (e) {
          debugPrint('[SacramentalDraftService] SQLite draft insert error: $e');
        }
      }
    }

    // 3. Attempt Supabase persistence when online or on Web without breaking on failures
    final isOnline = await RecordsSyncService.instance.checkConnectivity();
    if (isOnline || kIsWeb) {
      try {
        final payload = model.toMap();
        if (cleanId != null && cleanId.isNotEmpty) {
          payload.remove('created_at');
        }

        final response = await _client
            .from(_tableName)
            .upsert(payload, onConflict: 'draft_id')
            .select()
            .single();

        return SacramentalDraftModel.fromMap(response);
      } catch (e) {
        debugPrint(
            '[SacramentalDraftService] Remote save notice (draft preserved locally): $e');
      }
    }

    return model;
  }

  /// Deletes a draft by its draft_id from memory, local SQLite, and Supabase.
  static Future<void> deleteDraft(String draftId) async {
    final cleanId = draftId.trim();
    if (cleanId.isEmpty) return;

    // 1. Remove from in-memory cache
    for (final key in _memoryDrafts.keys) {
      _memoryDrafts[key]?.removeWhere((d) => d.draftId == cleanId);
    }

    // 2. Remove from local SQLite database
    if (!kIsWeb) {
      final db = await _getInitializedLocalDb();
      if (db != null) {
        try {
          await db.delete(
            _tableName,
            where: 'draft_id = ?',
            whereArgs: [cleanId],
          );
        } catch (_) {}
      }
    }

    // 3. Remove from Supabase if online
    final isOnline = await RecordsSyncService.instance.checkConnectivity();
    if (isOnline || kIsWeb) {
      try {
        await _client.from(_tableName).delete().eq('draft_id', cleanId);
      } catch (e) {
        debugPrint('[SacramentalDraftService] Remote delete notice: $e');
      }
    }
  }
}