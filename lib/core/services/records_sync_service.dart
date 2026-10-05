// =============================================================================
// FILE: lib/core/services/records_sync_service.dart
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/local_database_service.dart';

enum RecordsSyncStatus {
  online,
  offline,
  syncing,
  synced,
  error,
}

class RecordsSyncProgress {
  final int totalTables;
  final int currentTableIndex;
  final String currentTableName;
  final int recordsDownloaded;

  const RecordsSyncProgress({
    this.totalTables = 0,
    this.currentTableIndex = 0,
    this.currentTableName = '',
    this.recordsDownloaded = 0,
  });

  double get progressFraction =>
      totalTables > 0 ? (currentTableIndex / totalTables).clamp(0.0, 1.0) : 0.0;
}

class RecordsSyncService {
  RecordsSyncService._();
  static final RecordsSyncService instance = RecordsSyncService._();

  static final ValueNotifier<RecordsSyncStatus> syncStatusNotifier =
  ValueNotifier<RecordsSyncStatus>(RecordsSyncStatus.online);

  static final ValueNotifier<int> pendingSyncCountNotifier =
  ValueNotifier<int>(0);

  static final ValueNotifier<String?> lastSyncErrorNotifier =
  ValueNotifier<String?>(null);

  static final ValueNotifier<DateTime?> lastSyncedAtNotifier =
  ValueNotifier<DateTime?>(null);

  static final ValueNotifier<RecordsSyncProgress?> downloadProgressNotifier =
  ValueNotifier<RecordsSyncProgress?>(null);

  Timer? _connectivityPollTimer;
  bool _isSyncRunning = false;
  bool _isOnline = true;

  bool get isOnline => _isOnline;
  bool get isSyncInProgress => _isSyncRunning;

  Future<void> initialize() async {
    await updatePendingCount();
    await _loadLastSyncTimestamp();
    await checkConnectivity();

    _connectivityPollTimer?.cancel();
    _connectivityPollTimer =
        Timer.periodic(const Duration(seconds: 15), (_) async {
          final wasOnline = _isOnline;
          await checkConnectivity();

          // If connectivity returned or pending changes exist, sync automatically
          if (_isOnline &&
              (!wasOnline || pendingSyncCountNotifier.value > 0) &&
              !_isSyncRunning) {
            await syncPendingChanges();
          }
        });
  }

  void dispose() {
    _connectivityPollTimer?.cancel();
  }

  /// CORS-Safe and resilient connectivity checker.
  Future<bool> checkConnectivity() async {
    try {
      if (kIsWeb) {
        await Supabase.instance.client
            .from('parish_certificate_settings')
            .select('id')
            .limit(1)
            .timeout(const Duration(seconds: 3));
        _isOnline = true;
      } else {
        final response = await http
            .get(Uri.parse('https://www.gstatic.com/generate_204'))
            .timeout(const Duration(seconds: 3));
        _isOnline = (response.statusCode == 204 || response.statusCode == 200);
      }
    } catch (_) {
      // Secondary check: verify if Supabase itself is reachable
      try {
        await Supabase.instance.client
            .from('parish_certificate_settings')
            .select('id')
            .limit(1)
            .timeout(const Duration(seconds: 3));
        _isOnline = true;
      } catch (_) {
        _isOnline = false;
      }
    }

    if (!_isOnline) {
      if (syncStatusNotifier.value != RecordsSyncStatus.offline &&
          syncStatusNotifier.value != RecordsSyncStatus.syncing) {
        syncStatusNotifier.value = RecordsSyncStatus.offline;
      }
    } else {
      if (syncStatusNotifier.value == RecordsSyncStatus.offline) {
        syncStatusNotifier.value = pendingSyncCountNotifier.value > 0
            ? RecordsSyncStatus.online
            : RecordsSyncStatus.synced;
      }
    }

    return _isOnline;
  }

  // ===========================================================================
  // 1. Download Offline Pack (All 6 Registers, User Templates & Assets)
  // ===========================================================================

  Future<void> downloadAllOfflineResources({bool forceWipe = false}) async {
    if (!await checkConnectivity()) {
      throw 'Internet connection is required to download the offline records pack.';
    }

    _isSyncRunning = true;
    syncStatusNotifier.value = RecordsSyncStatus.syncing;
    lastSyncErrorNotifier.value = null;

    final client = Supabase.instance.client;
    final db = await LocalDatabaseService.instance.database;
    if (db == null) {
      _isSyncRunning = false;
      throw 'Local SQLite database could not be initialized.';
    }

    final tablesToDownload = [
      'parish_certificate_settings',
      'certificate_templates',
      'baptism_records',
      'confirmation_records',
      'first_communion_records',
      'matrimony_records',
      'death_records',
      'conversion_records',
      'certificate_issuances',
    ];

    int totalDownloaded = 0;
    final Set<String> imageUrlsToDownload = {};

    try {
      if (forceWipe) {
        await LocalDatabaseService.instance.clearAllData();
      }

      for (int i = 0; i < tablesToDownload.length; i++) {
        final table = tablesToDownload[i];
        downloadProgressNotifier.value = RecordsSyncProgress(
          totalTables: tablesToDownload.length + 2,
          currentTableIndex: i,
          currentTableName: 'Downloading $table...',
          recordsDownloaded: totalDownloaded,
        );

        try {
          final response = await client.from(table).select();
          final List rows = response as List;

          if (rows.isNotEmpty) {
            // Retrieve valid local columns to avoid SQLite schema mismatch crashes
            final tableInfo = await db.rawQuery('PRAGMA table_info($table)');
            final validColumns =
            tableInfo.map((col) => col['name'] as String).toSet();

            final batch = db.batch();
            for (final row in rows) {
              final map = Map<String, dynamic>.from(row as Map);

              // Extract images from both global settings and user-customized templates
              if (table == 'certificate_templates' ||
                  table == 'parish_certificate_settings') {
                for (final field in [
                  'background_image_url',
                  'diocese_logo_url',
                  'parish_seal_url',
                  'signature_image_url'
                ]) {
                  final val = map[field]?.toString();
                  if (val != null &&
                      val.trim().isNotEmpty &&
                      val.startsWith('http')) {
                    imageUrlsToDownload.add(val.trim());
                  }
                }

                // Parse nested style_config and canvas elements for user-customized image URLs
                final rawStyle = map['style_config'];
                if (rawStyle != null) {
                  final styleStr =
                  rawStyle is String ? rawStyle : jsonEncode(rawStyle);
                  final urlMatches = RegExp(
                    r'https?://[^\s",\\]+\.(png|jpg|jpeg|webp|gif|svg)(\?[^\s",\\]*)?',
                    caseSensitive: false,
                  ).allMatches(styleStr);
                  for (final m in urlMatches) {
                    final matchedUrl = m.group(0);
                    if (matchedUrl != null && matchedUrl.isNotEmpty) {
                      imageUrlsToDownload.add(matchedUrl.trim());
                    }
                  }
                }
              }

              final sanitized =
              _sanitizeRowForSqlite(table, map, validColumns);
              sanitized['sync_status'] = 'synced';
              sanitized['last_modified_at'] = DateTime.now().toIso8601String();

              batch.insert(
                table,
                sanitized,
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
            await batch.commit(noResult: true);
            totalDownloaded += rows.length;
            debugPrint(
                '[RecordsSyncService] Successfully synchronized ${rows.length} rows into $table');
          }
        } catch (tableError) {
          debugPrint(
              '[RecordsSyncService] Error syncing table $table: $tableError');
        }
      }

      // Download and cache all extracted borders, crests, logos, and signatures into SQLite
      downloadProgressNotifier.value = RecordsSyncProgress(
        totalTables: tablesToDownload.length + 2,
        currentTableIndex: tablesToDownload.length,
        currentTableName:
        'Caching ${imageUrlsToDownload.length} Certificate Assets & Borders...',
        recordsDownloaded: totalDownloaded,
      );

      for (final url in imageUrlsToDownload) {
        try {
          final uri = Uri.tryParse(url);
          if (uri == null || !uri.hasScheme) continue;

          final res = await http.get(uri).timeout(const Duration(seconds: 8));
          if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
            String type = 'image';
            final lower = url.toLowerCase();
            if (lower.contains('border')) type = 'border';
            if (lower.contains('signature')) type = 'signature';
            if (lower.contains('logo') || lower.contains('seal')) type = 'logo';

            await LocalDatabaseService.instance.cacheAsset(
              url,
              type,
              res.bodyBytes,
              mimeType: res.headers['content-type'],
            );
          }
        } catch (e) {
          debugPrint('[RecordsSyncService] Failed to cache asset ($url): $e');
        }
      }

      // Pre-warm Google Fonts for offline PDF compilation
      downloadProgressNotifier.value = RecordsSyncProgress(
        totalTables: tablesToDownload.length + 2,
        currentTableIndex: tablesToDownload.length + 1,
        currentTableName: 'Pre-warming Google Typography & Fonts...',
        recordsDownloaded: totalDownloaded,
      );

      await _preWarmCertificateFonts();

      final now = DateTime.now();
      await _saveLastSyncTimestamp(now);
      await updatePendingCount();

      syncStatusNotifier.value = RecordsSyncStatus.synced;
      lastSyncedAtNotifier.value = now;
      downloadProgressNotifier.value = null;
    } catch (e) {
      debugPrint('[RecordsSyncService] Download error: $e');
      syncStatusNotifier.value = RecordsSyncStatus.error;
      lastSyncErrorNotifier.value =
          e.toString().replaceFirst('Exception: ', '');
      downloadProgressNotifier.value = null;
      rethrow;
    } finally {
      _isSyncRunning = false;
    }
  }

  Future<void> _preWarmCertificateFonts() async {
    try {
      await Future.wait([
        PdfGoogleFonts.arimoRegular(),
        PdfGoogleFonts.arimoBold(),
        PdfGoogleFonts.arimoItalic(),
        PdfGoogleFonts.arimoBoldItalic(),
        PdfGoogleFonts.tinosRegular(),
        PdfGoogleFonts.tinosBold(),
        PdfGoogleFonts.tinosItalic(),
        PdfGoogleFonts.tinosBoldItalic(),
        PdfGoogleFonts.cousineRegular(),
        PdfGoogleFonts.cousineBold(),
        PdfGoogleFonts.cousineItalic(),
        PdfGoogleFonts.cousineBoldItalic(),
        PdfGoogleFonts.cinzelRegular(),
        PdfGoogleFonts.cinzelBold(),
        PdfGoogleFonts.eBGaramondRegular(),
        PdfGoogleFonts.eBGaramondBold(),
        PdfGoogleFonts.eBGaramondItalic(),
        PdfGoogleFonts.eBGaramondBoldItalic(),
        PdfGoogleFonts.caveatRegular(),
        PdfGoogleFonts.caveatBold(),
      ]);
    } catch (_) {}
  }

  // ===========================================================================
  // 2. Queue Offline Changes
  // ===========================================================================

  Future<void> queueOfflineChange({
    required String tableName,
    required String recordId,
    required String operation,
    required Map<String, dynamic> data,
  }) async {
    final db = await LocalDatabaseService.instance.database;
    if (db == null) return;
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      if (operation == 'DELETE') {
        await txn.delete(
          tableName,
          where: '${_getPrimaryKey(tableName)} = ?',
          whereArgs: [recordId],
        );
      } else {
        final tableInfo = await txn.rawQuery('PRAGMA table_info($tableName)');
        final validColumns =
        tableInfo.map((col) => col['name'] as String).toSet();

        final sanitized = _sanitizeRowForSqlite(tableName, data, validColumns);
        sanitized['sync_status'] = 'pending';
        sanitized['last_modified_at'] = now;

        await txn.insert(
          tableName,
          sanitized,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await txn.delete(
        'sync_queue',
        where: 'table_name = ? AND record_id = ?',
        whereArgs: [tableName, recordId],
      );

      await txn.insert('sync_queue', {
        'table_name': tableName,
        'record_id': recordId,
        'operation': operation,
        'payload': jsonEncode(data),
        'queued_at': now,
        'attempts': 0,
        'last_error': null,
        'status': 'pending',
      });
    });

    await updatePendingCount();
  }

  Future<void> cacheRemoteRecordsLocally(
      String tableName,
      List<Map<String, dynamic>> records,
      ) async {
    if (records.isEmpty) return;
    try {
      final db = await LocalDatabaseService.instance.database;
      if (db == null) return;

      final tableInfo = await db.rawQuery('PRAGMA table_info($tableName)');
      final validColumns =
      tableInfo.map((col) => col['name'] as String).toSet();

      final batch = db.batch();
      final now = DateTime.now().toIso8601String();

      for (final r in records) {
        final sanitized = _sanitizeRowForSqlite(tableName, r, validColumns);
        sanitized['sync_status'] = 'synced';
        sanitized['last_modified_at'] = now;

        batch.insert(
          tableName,
          sanitized,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit(noResult: true);
    } catch (e) {
      debugPrint('[RecordsSyncService] Cache error on $tableName: $e');
    }
  }

  // ===========================================================================
  // 3. Bi-Directional Synchronization Loop
  // ===========================================================================

  Future<void> syncPendingChanges() async {
    if (_isSyncRunning) return;
    if (!await checkConnectivity()) {
      syncStatusNotifier.value = RecordsSyncStatus.offline;
      return;
    }

    _isSyncRunning = true;
    syncStatusNotifier.value = RecordsSyncStatus.syncing;
    lastSyncErrorNotifier.value = null;

    final db = await LocalDatabaseService.instance.database;
    if (db == null) {
      _isSyncRunning = false;
      return;
    }

    final client = Supabase.instance.client;

    try {
      final pendingQueue = await db.query(
        'sync_queue',
        where: 'status = ?',
        whereArgs: ['pending'],
        orderBy: 'queue_id ASC',
      );

      for (final item in pendingQueue) {
        final queueId = item['queue_id'] as int;
        final tableName = item['table_name'] as String;
        final recordId = item['record_id'] as String;
        final operation = item['operation'] as String;
        final payload =
        jsonDecode(item['payload'] as String) as Map<String, dynamic>;

        try {
          final supabasePayload = _prepareRowForSupabase(tableName, payload);

          if (operation == 'INSERT') {
            await client.from(tableName).upsert(supabasePayload);
          } else if (operation == 'UPDATE') {
            await client
                .from(tableName)
                .update(supabasePayload)
                .eq(_getPrimaryKey(tableName), recordId);
          } else if (operation == 'DELETE') {
            await client
                .from(tableName)
                .delete()
                .eq(_getPrimaryKey(tableName), recordId);
          }

          await db.transaction((txn) async {
            await txn.delete(
              'sync_queue',
              where: 'queue_id = ?',
              whereArgs: [queueId],
            );

            if (operation != 'DELETE') {
              await txn.update(
                tableName,
                {'sync_status': 'synced'},
                where: '${_getPrimaryKey(tableName)} = ?',
                whereArgs: [recordId],
              );
            }
          });
        } catch (itemError) {
          debugPrint(
              '[RecordsSyncService] Push failed ($recordId): $itemError');
          await db.update(
            'sync_queue',
            {
              'attempts': ((item['attempts'] as int? ?? 0) + 1),
              'last_error': itemError.toString(),
              'status': 'pending',
            },
            where: 'queue_id = ?',
            whereArgs: [queueId],
          );
        }
      }

      final now = DateTime.now();
      await _saveLastSyncTimestamp(now);
      await updatePendingCount();

      syncStatusNotifier.value = pendingSyncCountNotifier.value > 0
          ? RecordsSyncStatus.online
          : RecordsSyncStatus.synced;
      lastSyncedAtNotifier.value = now;
      lastSyncErrorNotifier.value = null;
    } catch (e) {
      debugPrint('[RecordsSyncService] Sync loop error: $e');
      syncStatusNotifier.value = RecordsSyncStatus.error;
      lastSyncErrorNotifier.value =
          e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isSyncRunning = false;
    }
  }

  // ===========================================================================
  // 4. Utility & Metadata Helpers
  // ===========================================================================

  Future<int> updatePendingCount() async {
    try {
      final db = await LocalDatabaseService.instance.database;
      if (db == null) return 0;
      final result = Sqflite.firstIntValue(
        await db.rawQuery(
          'SELECT COUNT(*) FROM sync_queue WHERE status = ?',
          ['pending'],
        ),
      );
      final count = result ?? 0;
      pendingSyncCountNotifier.value = count;
      return count;
    } catch (_) {
      return 0;
    }
  }

  String _getPrimaryKey(String table) {
    switch (table) {
      case 'baptism_records':
      case 'confirmation_records':
      case 'first_communion_records':
      case 'matrimony_records':
      case 'death_records':
      case 'conversion_records':
        return 'record_id';
      case 'certificate_templates':
        return 'template_id';
      case 'certificate_issuances':
        return 'issuance_id';
      case 'parish_certificate_settings':
        return 'id';
      default:
        return 'id';
    }
  }

  Map<String, dynamic> _sanitizeRowForSqlite(
      String table,
      Map<String, dynamic> row, [
        Set<String>? validColumns,
      ]) {
    final clean = Map<String, dynamic>.from(row);

    // Normalize any camelCase keys from memory before SQLite insertion
    if (clean.containsKey('bodyWording')) {
      clean['body_wording'] = clean['bodyWording'];
      clean.remove('bodyWording');
    }

    clean.forEach((key, value) {
      if (value is bool) {
        clean[key] = value ? 1 : 0;
      } else if (value is Map ||
          (value is List &&
              key != 'other_sponsors' &&
              key != 'other_godparents')) {
        clean[key] = jsonEncode(value);
      }
    });

    if (validColumns != null && validColumns.isNotEmpty) {
      clean.removeWhere((key, _) => !validColumns.contains(key));
    }

    return clean;
  }

  Map<String, dynamic> _prepareRowForSupabase(
      String table,
      Map<String, dynamic> row,
      ) {
    final clean = Map<String, dynamic>.from(row);

    // Remove SQLite-specific local metadata columns
    clean.remove('sync_status');
    clean.remove('last_modified_at');

    // Strip legacy camelCase keys that cause PGRST204 errors
    if (clean.containsKey('bodyWording')) {
      if (!clean.containsKey('body_wording') || clean['body_wording'] == null) {
        clean['body_wording'] = clean['bodyWording'];
      }
      clean.remove('bodyWording');
    }

    final booleanFields = [
      'is_verified',
      'approved_by_priest',
      'is_filipino_foreigner',
      'sacraments_received',
      'is_gratis',
      'show_parish_seal',
      'show_diocese_logo',
      'enable_qr_verification',
      'is_active',
      'is_default',
    ];

    for (final b in booleanFields) {
      if (clean.containsKey(b)) {
        final val = clean[b];
        if (val is int) {
          clean[b] = val == 1;
        } else if (val is String) {
          clean[b] = val == '1' || val.toLowerCase() == 'true';
        }
      }
    }

    if (clean['style_config'] is String) {
      try {
        clean['style_config'] = jsonDecode(clean['style_config'] as String);
      } catch (_) {}
    }

    return clean;
  }

  Future<void> _saveLastSyncTimestamp(DateTime time) async {
    try {
      final db = await LocalDatabaseService.instance.database;
      if (db == null) return;
      await db.insert(
        'app_sync_metadata',
        {
          'key': 'last_successful_records_sync',
          'value': time.toIso8601String(),
          'updated_at': time.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  Future<DateTime?> _getLastSyncTimestamp() async {
    try {
      final db = await LocalDatabaseService.instance.database;
      if (db == null) return null;
      final rows = await db.query(
        'app_sync_metadata',
        where: 'key = ?',
        whereArgs: ['last_successful_records_sync'],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        return DateTime.tryParse(rows.first['value'] as String);
      }
    } catch (_) {}
    return null;
  }

  Future<void> _loadLastSyncTimestamp() async {
    final timestamp = await _getLastSyncTimestamp();
    lastSyncedAtNotifier.value = timestamp;
  }
}