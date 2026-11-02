// =============================================================================
// FILE: lib/core/services/records_sync_service.dart
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
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

class RecordsSyncService with WidgetsBindingObserver {
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
  Timer? _autoPeriodicSyncTimer;
  bool _isSyncRunning = false;
  bool _isOnline = true;
  bool _isObserverRegistered = false;

  DateTime? _lastAutoDownloadAttempt;

  bool get isOnline => _isOnline;
  bool get isSyncInProgress => _isSyncRunning;

  /// Global list of tables replicated for offline operation
  static const List<String> _syncTables = [
    'parish_certificate_settings',
    'certificate_templates',
    'baptism_records',
    'confirmation_records',
    'first_communion_records',
    'matrimony_records',
    'death_records',
    'conversion_records',
    'appointments',
    'mass_intentions',
    'certificate_issuances',
  ];

  // ===========================================================================
  // Initialization & Automated Background Lifecycle
  // ===========================================================================

  Future<void> initialize() async {
    if (!_isObserverRegistered) {
      WidgetsBinding.instance.addObserver(this);
      _isObserverRegistered = true;
    }

    await updatePendingCount();
    await _loadLastSyncTimestamp();
    await checkConnectivity();

    // 1. Initial background auto-sync & resource pull on launch
    if (_isOnline) {
      unawaited(autoSyncAndDownloadResources(silent: true));
    }

    // 2. Continuous connectivity polling (every 10 seconds)
    _connectivityPollTimer?.cancel();
    _connectivityPollTimer =
        Timer.periodic(const Duration(seconds: 10), (_) async {
          final wasOnline = _isOnline;
          final isNowOnline = await checkConnectivity();

          // Trigger automatic sync immediately when network is restored or pending local edits exist
          if (isNowOnline) {
            if (!wasOnline || pendingSyncCountNotifier.value > 0) {
              unawaited(autoSyncAndDownloadResources(silent: true));
            }
          }
        });

    // 3. Automated periodic background delta-sync (every 4 minutes while connected)
    _autoPeriodicSyncTimer?.cancel();
    _autoPeriodicSyncTimer =
        Timer.periodic(const Duration(minutes: 4), (_) async {
          if (_isOnline && !_isSyncRunning) {
            unawaited(autoSyncAndDownloadResources(silent: true));
          }
        });
  }

  void dispose() {
    if (_isObserverRegistered) {
      WidgetsBinding.instance.removeObserver(this);
      _isObserverRegistered = false;
    }
    _connectivityPollTimer?.cancel();
    _autoPeriodicSyncTimer?.cancel();
  }

  /// App lifecycle listener: triggers auto-sync when the app wakes up or resumes from background
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('[RecordsSyncService] App resumed from background. Checking connectivity & triggering auto-sync.');
      checkConnectivity().then((online) {
        if (online && !_isSyncRunning) {
          autoSyncAndDownloadResources(silent: true);
        }
      });
    }
  }

  // ===========================================================================
  // Connectivity Verification
  // ===========================================================================

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
  // Automated Background Two-Way Sync (Push + Incremental Delta Pull)
  // ===========================================================================

  /// Automatically synchronizes pending local edits and downloads new/updated resources.
  /// Runs completely in the background without blocking the UI thread or throwing intrusive errors.
  Future<void> autoSyncAndDownloadResources({bool silent = true}) async {
    if (_isSyncRunning) return;
    if (!await checkConnectivity()) {
      syncStatusNotifier.value = RecordsSyncStatus.offline;
      return;
    }

    // Rate-limit automated delta checks to prevent network flooding (minimum 15s between runs)
    final now = DateTime.now();
    if (_lastAutoDownloadAttempt != null &&
        now.difference(_lastAutoDownloadAttempt!) < const Duration(seconds: 15)) {
      return;
    }
    _lastAutoDownloadAttempt = now;

    _isSyncRunning = true;
    syncStatusNotifier.value = RecordsSyncStatus.syncing;
    if (!silent) lastSyncErrorNotifier.value = null;

    final db = await LocalDatabaseService.instance.database;
    if (db == null) {
      _isSyncRunning = false;
      return;
    }

    try {
      // Step 1: Push all pending local offline changes to Cloud first
      await _executePushQueue(db);

      // Step 2: Incremental Delta Pull from Cloud to Local SQLite
      final lastSyncTime = lastSyncedAtNotifier.value;
      await _executeIncrementalPull(db, lastSyncTime);

      // Step 3: Auto-warm typography & cache new template assets
      await _cacheMissingTemplateAssets(db);

      final finishTime = DateTime.now();
      await _saveLastSyncTimestamp(finishTime);
      await updatePendingCount();

      syncStatusNotifier.value = pendingSyncCountNotifier.value > 0
          ? RecordsSyncStatus.online
          : RecordsSyncStatus.synced;
      lastSyncedAtNotifier.value = finishTime;
      lastSyncErrorNotifier.value = null;
      debugPrint('[RecordsSyncService] Background auto-sync and delta-download completed successfully.');
    } catch (e) {
      debugPrint('[RecordsSyncService] Background auto-sync notice: $e');
      syncStatusNotifier.value = RecordsSyncStatus.error;
      lastSyncErrorNotifier.value = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isSyncRunning = false;
    }
  }

  // ===========================================================================
  // Internal Push & Incremental Pull Engines
  // ===========================================================================

  Future<void> _executePushQueue(Database db) async {
    final client = Supabase.instance.client;

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
      final payload = jsonDecode(item['payload'] as String) as Map<String, dynamic>;

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
        debugPrint('[RecordsSyncService] Push item failed ($recordId): $itemError');
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
  }

  Future<void> _executeIncrementalPull(Database db, DateTime? lastSyncTime) async {
    final client = Supabase.instance.client;
    final nowIso = DateTime.now().toIso8601String();

    for (final table in _syncTables) {
      try {
        var query = client.from(table).select();

        // If a previous sync exists, pull only newer or modified records
        if (lastSyncTime != null) {
          final lastSyncIso = lastSyncTime.toUtc().toIso8601String();
          if (table == 'certificate_templates' ||
              table == 'parish_certificate_settings' ||
              table == 'appointments' ||
              table == 'mass_intentions') {
            query = query.gte('updated_at', lastSyncIso);
          } else {
            query = query.gte('created_at', lastSyncIso);
          }
        }

        final response = await query;
        final List rows = response as List;

        if (rows.isNotEmpty) {
          final tableInfo = await db.rawQuery('PRAGMA table_info($table)');
          final validColumns = tableInfo.map((col) => col['name'] as String).toSet();

          final batch = db.batch();
          for (final row in rows) {
            final map = Map<String, dynamic>.from(row as Map);
            final sanitized = _sanitizeRowForSqlite(table, map, validColumns);
            sanitized['sync_status'] = 'synced';
            sanitized['last_modified_at'] = nowIso;

            batch.insert(
              table,
              sanitized,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
          await batch.commit(noResult: true);
          debugPrint('[RecordsSyncService] Delta-pulled ${rows.length} updated rows into $table');
        }
      } catch (tableErr) {
        debugPrint('[RecordsSyncService] Delta pull notice for $table: $tableErr');
      }
    }
  }

  Future<void> _cacheMissingTemplateAssets(Database db) async {
    try {
      final rows = await db.rawQuery('''
        SELECT background_image_url, diocese_logo_url, parish_seal_url, signature_image_url 
        FROM certificate_templates
        UNION
        SELECT '' as background_image_url, diocese_logo_url, parish_seal_url, '' as signature_image_url
        FROM parish_certificate_settings
      ''');

      final Set<String> urlsToCache = {};
      for (final r in rows) {
        for (final val in r.values) {
          if (val != null && val is String && val.trim().startsWith('http')) {
            urlsToCache.add(val.trim());
          }
        }
      }

      for (final url in urlsToCache) {
        final existing = await LocalDatabaseService.instance.getCachedAsset(url);
        if (existing == null || existing.isEmpty) {
          try {
            final uri = Uri.tryParse(url);
            if (uri == null || !uri.hasScheme) continue;

            final res = await http.get(uri).timeout(const Duration(seconds: 6));
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
              debugPrint('[RecordsSyncService] Auto-cached template asset: $url');
            }
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  // ===========================================================================
  // Manual Full Offline Pack Download (Clean Rebuild)
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

    int totalDownloaded = 0;
    final Set<String> imageUrlsToDownload = {};

    try {
      if (forceWipe) {
        await LocalDatabaseService.instance.clearAllData();
      }

      for (int i = 0; i < _syncTables.length; i++) {
        final table = _syncTables[i];
        downloadProgressNotifier.value = RecordsSyncProgress(
          totalTables: _syncTables.length + 2,
          currentTableIndex: i,
          currentTableName: 'Downloading $table...',
          recordsDownloaded: totalDownloaded,
        );

        try {
          final response = await client.from(table).select();
          final List rows = response as List;

          if (rows.isNotEmpty) {
            final tableInfo = await db.rawQuery('PRAGMA table_info($table)');
            final validColumns =
            tableInfo.map((col) => col['name'] as String).toSet();

            final batch = db.batch();
            for (final row in rows) {
              final map = Map<String, dynamic>.from(row as Map);

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
          }
        } catch (tableError) {
          debugPrint('[RecordsSyncService] Error syncing table $table: $tableError');
        }
      }

      downloadProgressNotifier.value = RecordsSyncProgress(
        totalTables: _syncTables.length + 2,
        currentTableIndex: _syncTables.length,
        currentTableName: 'Caching ${imageUrlsToDownload.length} Certificate Assets & Borders...',
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

      downloadProgressNotifier.value = RecordsSyncProgress(
        totalTables: _syncTables.length + 2,
        currentTableIndex: _syncTables.length + 1,
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
      lastSyncErrorNotifier.value = e.toString().replaceFirst('Exception: ', '');
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
  // Local Change Queueing
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

    // If connected, automatically push this queued change right away
    if (_isOnline && !_isSyncRunning) {
      unawaited(syncPendingChanges());
    }
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
  // Manual & Push-Only Trigger
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

    try {
      await _executePushQueue(db);
      final now = DateTime.now();
      await _saveLastSyncTimestamp(now);
      await updatePendingCount();

      syncStatusNotifier.value = pendingSyncCountNotifier.value > 0
          ? RecordsSyncStatus.online
          : RecordsSyncStatus.synced;
      lastSyncedAtNotifier.value = now;
      lastSyncErrorNotifier.value = null;
    } catch (e) {
      debugPrint('[RecordsSyncService] Push loop error: $e');
      syncStatusNotifier.value = RecordsSyncStatus.error;
      lastSyncErrorNotifier.value = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isSyncRunning = false;
    }
  }

  // ===========================================================================
  // Utility & Serialization Helpers
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
      case 'appointments':
        return 'appointment_id';
      case 'mass_intentions':
        return 'intention_id';
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

    clean.remove('sync_status');
    clean.remove('last_modified_at');

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
      'is_id_verified',
      'reminder_24h_sent',
      'reminder_12h_sent',
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

    if (table == 'mass_intentions') {
      final listFields = ['thanksgiving_list', 'repose_souls_list', 'special_intentions_list'];
      for (final lf in listFields) {
        if (clean[lf] is String) {
          try {
            final decoded = jsonDecode(clean[lf] as String);
            if (decoded is List) {
              clean[lf] = decoded.map((e) => e.toString().trim()).toList();
            }
          } catch (_) {
            clean[lf] = <String>[];
          }
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