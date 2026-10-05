// =============================================================================
// FILE: lib/features/sacramental_records/services/first_communion_service.dart
// =============================================================================

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/database/local_database_service.dart';
import '../../../core/services/records_sync_service.dart';
import '../../auth/services/auth_service.dart';
import '../models/first_communion_record_model.dart';
import '../validators/sacramental_validators.dart';

class FirstCommunionService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Fetch all first communion records ordered by communion date descending.
  /// On Web or Online: Queries Supabase directly and transparently caches to SQLite on native platforms.
  /// On Native Offline: Reads directly from local SQLite storage without blocking or throwing errors.
  static Future<List<FirstCommunionRecordModel>> getFirstCommunionRecords() async {
    final isOnline = await RecordsSyncService.instance.checkConnectivity();

    if (isOnline || kIsWeb) {
      try {
        final response = await _client
            .from('first_communion_records')
            .select()
            .order('date_of_communion', ascending: false)
            .order('created_at', ascending: false);

        final list = (response as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();

        if (!kIsWeb) {
          await RecordsSyncService.instance.cacheRemoteRecordsLocally(
            'first_communion_records',
            list,
          );
        }

        return list.map((row) => FirstCommunionRecordModel.fromMap(row)).toList();
      } catch (_) {
        if (kIsWeb) return [];
      }
    }

    final db = await LocalDatabaseService.instance.database;
    if (db != null) {
      final rows = await db.query(
        'first_communion_records',
        orderBy: 'date_of_communion DESC, created_at DESC',
      );
      return rows.map((row) => FirstCommunionRecordModel.fromMap(row)).toList();
    }

    return [];
  }

  /// Automatically generates the next sequential control number: FCM-Year-Number (e.g. FCM-2026-0001).
  /// Checks Supabase directly on Web/Online and cross-checks SQLite on native platforms.
  static Future<String> generateNextControlNumber(int year) async {
    int highest = 0;

    final isOnline = await RecordsSyncService.instance.checkConnectivity();
    if (isOnline || kIsWeb) {
      try {
        final remoteRecords = await _client
            .from('first_communion_records')
            .select('control_number')
            .eq('year', year);

        for (final item in remoteRecords) {
          final cNo = item['control_number']?.toString() ?? '';
          final parts = cNo.split('-');
          if (parts.length >= 3) {
            final seq = int.tryParse(parts.last);
            if (seq != null && seq > highest) {
              highest = seq;
            }
          }
        }
        final nextSeq = (highest + 1).toString().padLeft(4, '0');
        return 'FCM-$year-$nextSeq';
      } catch (_) {
        if (kIsWeb) {
          final fallbackSeq =
          (DateTime.now().millisecondsSinceEpoch % 10000).toString().padLeft(4, '0');
          return 'FCM-$year-$fallbackSeq';
        }
      }
    }

    final db = await LocalDatabaseService.instance.database;
    if (db != null) {
      final localRows = await db.query(
        'first_communion_records',
        columns: ['control_number'],
        where: 'year = ?',
        whereArgs: [year],
      );

      for (final item in localRows) {
        final cNo = item['control_number']?.toString() ?? '';
        final parts = cNo.split('-');
        if (parts.length >= 3) {
          final seq = int.tryParse(parts.last);
          if (seq != null && seq > highest) {
            highest = seq;
          }
        }
      }
    }

    final nextSeq = (highest + 1).toString().padLeft(4, '0');
    return 'FCM-$year-$nextSeq';
  }

  /// Validates and inserts a manual First Communion record into public.first_communion_records.
  /// On Web or Online: Inserts directly into Supabase.
  /// On Native Offline: Inserts into SQLite with pending status and queues for auto-sync.
  static Future<FirstCommunionRecordModel> insertManualFirstCommunionRecord(
      Map<String, dynamic> data,
      ) async {
    final requiredFields = {
      'year': 'Communion Year',
      'control_number': 'Control Number',
      'communicant_first_name': 'Communicant First Name',
      'communicant_last_name': 'Communicant Last Name',
      'date_of_communion': 'Date of First Holy Communion',
      'baptism_parish': 'Church of Baptism',
      'minister_first_name': 'Minister First Name',
      'minister_last_name': 'Minister Last Name',
    };

    for (final entry in requiredFields.entries) {
      final val = data[entry.key];
      if (val == null || (val is String && val.trim().isEmpty)) {
        throw '${entry.value} is required.';
      }
    }

    final yearError = SacramentalValidators.validateCommunionYear(
      data['year']?.toString(),
    );
    if (yearError != null) throw yearError;
    final yearNum = int.parse(data['year'].toString().trim());
    data['year'] = yearNum;

    final controlNum = data['control_number'].toString().trim();
    final controlError = SacramentalValidators.validateCommunionControlNumber(controlNum);
    if (controlError != null) throw controlError;
    data['control_number'] = controlNum;

    final communionDate =
    DateTime.tryParse(data['date_of_communion']?.toString() ?? '');
    final baptismDate =
    DateTime.tryParse(data['baptism_date']?.toString() ?? '');
    final communionDateError = SacramentalValidators.validateCommunionDate(
      communionDate,
      baptismDate,
    );
    if (communionDateError != null) throw communionDateError;

    // 1. Check duplicate control number in local SQLite first (Native)
    if (!kIsWeb) {
      final db = await LocalDatabaseService.instance.database;
      if (db != null) {
        final localDup = await db.query(
          'first_communion_records',
          where: 'year = ? AND control_number = ?',
          whereArgs: [yearNum, controlNum],
          limit: 1,
        );

        if (localDup.isNotEmpty) {
          throw 'Control Number "$controlNum" is already registered for the year $yearNum.';
        }
      }
    }

    // 2. Duplicate check in Supabase (Online / Web)
    final isOnline = await RecordsSyncService.instance.checkConnectivity();
    if (isOnline || kIsWeb) {
      try {
        final remoteDup = await _client
            .from('first_communion_records')
            .select('record_id')
            .eq('year', yearNum)
            .eq('control_number', controlNum)
            .maybeSingle();

        if (remoteDup != null) {
          throw 'Control Number "$controlNum" is already registered for the year $yearNum.';
        }
      } catch (e) {
        if (e is String) rethrow;
      }
    }

    if (data['record_id'] == null || data['record_id'].toString().trim().isEmpty) {
      data['record_id'] = controlNum;
    }

    String? encoderId = AuthService.currentUser?.userId;
    data['encoded_by'] = encoderId ?? 'S26-0003';

    data['is_verified'] = false;
    data['scanned_image_url'] = null;
    data['created_at'] = DateTime.now().toIso8601String();

    // 3. Execute Insert
    if (isOnline || kIsWeb) {
      try {
        final response = await _client
            .from('first_communion_records')
            .insert(data)
            .select()
            .single();

        if (!kIsWeb) {
          await RecordsSyncService.instance.cacheRemoteRecordsLocally(
            'first_communion_records',
            [response],
          );
        }

        return FirstCommunionRecordModel.fromMap(response);
      } catch (e) {
        if (kIsWeb) rethrow;
      }
    }

    await RecordsSyncService.instance.queueOfflineChange(
      tableName: 'first_communion_records',
      recordId: data['record_id'],
      operation: 'INSERT',
      data: data,
    );

    return FirstCommunionRecordModel.fromMap(data);
  }

  /// Updates an existing manual First Communion record in public.first_communion_records.
  /// Protects immutable control coordinates from alteration.
  static Future<FirstCommunionRecordModel> updateFirstCommunionRecord(
      String recordId,
      Map<String, dynamic> data,
      ) async {
    final requiredFields = {
      'communicant_first_name': 'Communicant First Name',
      'communicant_last_name': 'Communicant Last Name',
      'date_of_communion': 'Date of First Holy Communion',
      'baptism_parish': 'Church of Baptism',
      'minister_first_name': 'Minister First Name',
      'minister_last_name': 'Minister Last Name',
    };

    for (final entry in requiredFields.entries) {
      final val = data[entry.key];
      if (val == null || (val is String && val.trim().isEmpty)) {
        throw '${entry.value} is required.';
      }
    }

    final communionDate =
    DateTime.tryParse(data['date_of_communion']?.toString() ?? '');
    final baptismDate =
    DateTime.tryParse(data['baptism_date']?.toString() ?? '');
    final communionDateError = SacramentalValidators.validateCommunionDate(
      communionDate,
      baptismDate,
    );
    if (communionDateError != null) throw communionDateError;

    // Protect control number and year coordinates from being altered
    data.remove('record_id');
    data.remove('year');
    data.remove('control_number');

    final isOnline = await RecordsSyncService.instance.checkConnectivity();
    if (isOnline || kIsWeb) {
      try {
        final response = await _client
            .from('first_communion_records')
            .update(data)
            .eq('record_id', recordId)
            .select()
            .single();

        if (!kIsWeb) {
          await RecordsSyncService.instance.cacheRemoteRecordsLocally(
            'first_communion_records',
            [response],
          );
        }

        return FirstCommunionRecordModel.fromMap(response);
      } catch (e) {
        if (kIsWeb) rethrow;
      }
    }

    await RecordsSyncService.instance.queueOfflineChange(
      tableName: 'first_communion_records',
      recordId: recordId,
      operation: 'UPDATE',
      data: data,
    );

    final db = await LocalDatabaseService.instance.database;
    if (db != null) {
      final rows = await db.query(
        'first_communion_records',
        where: 'record_id = ?',
        whereArgs: [recordId],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        return FirstCommunionRecordModel.fromMap(rows.first);
      }
    }

    return FirstCommunionRecordModel.fromMap(data);
  }
}