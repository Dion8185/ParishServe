// =============================================================================
// FILE: lib/features/sacramental_records/services/confirmation_service.dart
// =============================================================================

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/database/local_database_service.dart';
import '../../../core/services/records_sync_service.dart';
import '../../auth/services/auth_service.dart';
import '../models/confirmation_record_model.dart';
import '../validators/sacramental_validators.dart';

class ConfirmationService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Fetch all confirmation records ordered by creation date descending.
  /// On Web or Online: Queries Supabase directly and transparently caches to SQLite on native platforms.
  /// On Native Offline: Queries the local SQLite table directly without network delay or errors.
  static Future<List<ConfirmationRecordModel>> getConfirmationRecords() async {
    final isOnline = await RecordsSyncService.instance.checkConnectivity();

    if (isOnline || kIsWeb) {
      try {
        final response = await _client
            .from('confirmation_records')
            .select()
            .order('created_at', ascending: false);

        final list = (response as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();

        if (!kIsWeb) {
          await RecordsSyncService.instance.cacheRemoteRecordsLocally(
            'confirmation_records',
            list,
          );
        }

        return list.map((row) => ConfirmationRecordModel.fromMap(row)).toList();
      } catch (_) {
        if (kIsWeb) return [];
      }
    }

    final db = await LocalDatabaseService.instance.database;
    if (db != null) {
      final rows = await db.query(
        'confirmation_records',
        orderBy: 'created_at DESC, date_of_confirmation DESC',
      );
      return rows.map((row) => ConfirmationRecordModel.fromMap(row)).toList();
    }

    return [];
  }

  /// Validates and inserts a manual Confirmation Record into public.confirmation_records.
  /// On Web or Online: Persists directly to Supabase.
  /// On Native Offline: Saves to SQLite with pending status and queues for auto-sync.
  static Future<ConfirmationRecordModel> insertManualConfirmationRecord(
      Map<String, dynamic> data,
      ) async {
    final requiredFields = {
      'book_number': 'Book Number',
      'page_number': 'Page Number',
      'line_number': 'Line Number',
      'confirmand_first_name': 'Confirmand First Name',
      'confirmand_last_name': 'Confirmand Last Name',
      'date_of_baptism': 'Date of Baptism',
      'church_baptized': 'Church of Baptism',
      'father_first_name': 'Father First Name',
      'father_last_name': 'Father Last Name',
      'mother_first_name': 'Mother First Name',
      'mother_maiden_last_name': 'Mother Maiden Last Name',
      'sponsor_1_first_name': 'Sponsor 1 First Name',
      'sponsor_1_last_name': 'Sponsor 1 Last Name',
      'date_of_confirmation': 'Date of Confirmation',
      'minister_first_name': 'Minister First Name',
      'minister_last_name': 'Minister Last Name',
      'parish_name': 'Parish Name',
    };

    for (final entry in requiredFields.entries) {
      final val = data[entry.key];
      if (val == null || (val is String && val.trim().isEmpty)) {
        throw '${entry.value} is required.';
      }
    }

    final bookError = SacramentalValidators.validateBookNumber(
      data['book_number']?.toString(),
    );
    if (bookError != null) throw bookError;

    final pageError = SacramentalValidators.validatePageNumber(
      data['page_number']?.toString(),
    );
    if (pageError != null) throw pageError;

    final lineError = SacramentalValidators.validateLineNumber(
      data['line_number']?.toString(),
    );
    if (lineError != null) throw lineError;

    final cleanBook = int.parse(data['book_number'].toString().trim()).toString();
    final cleanPage = int.parse(data['page_number'].toString().trim()).toString();
    final cleanLine = int.parse(data['line_number'].toString().trim()).toString();

    data['book_number'] = cleanBook;
    data['page_number'] = cleanPage;
    data['line_number'] = cleanLine;

    // Chronological validation
    final baptismDate = DateTime.tryParse(data['date_of_baptism']?.toString() ?? '');
    final confirmationDate =
    DateTime.tryParse(data['date_of_confirmation']?.toString() ?? '');
    final confDateError = SacramentalValidators.validateConfirmationDate(
      confirmationDate,
      baptismDate,
    );
    if (confDateError != null) throw confDateError;

    // 1. Check duplicate physical reference in local SQLite first (Native)
    if (!kIsWeb) {
      final db = await LocalDatabaseService.instance.database;
      if (db != null) {
        final localDup = await db.query(
          'confirmation_records',
          where: 'book_number = ? AND page_number = ? AND line_number = ?',
          whereArgs: [cleanBook, cleanPage, cleanLine],
          limit: 1,
        );

        if (localDup.isNotEmpty) {
          throw 'This Book, Page, and Line reference is already registered in the Confirmation Register.';
        }
      }
    }

    // 2. Duplicate check in Supabase (Online / Web)
    final isOnline = await RecordsSyncService.instance.checkConnectivity();
    if (isOnline || kIsWeb) {
      try {
        final remoteDup = await _client
            .from('confirmation_records')
            .select('record_id')
            .eq('book_number', cleanBook)
            .eq('page_number', cleanPage)
            .eq('line_number', cleanLine)
            .maybeSingle();

        if (remoteDup != null) {
          throw 'This Book, Page, and Line reference is already registered in the Confirmation Register.';
        }
      } catch (e) {
        if (e is String) rethrow;
      }
    }

    if (data['record_id'] == null || data['record_id'].toString().trim().isEmpty) {
      data['record_id'] = await _generateRecordId();
    }

    String? encoderId = AuthService.currentUser?.userId;
    data['encoded_by'] = encoderId ?? 'S26-0003';

    data['is_verified'] = false;
    data['scanned_image_url'] = null;
    data['ocr_raw_text'] = null;
    data['entry_status'] = data['entry_status'] ?? 'ORIGINAL';
    data['stipend'] = data['stipend'] ?? 0.00;
    data['created_at'] = DateTime.now().toIso8601String();
    data['date_encoded'] = DateTime.now().toIso8601String();
    data['registry_date'] =
        data['registry_date'] ?? DateTime.now().toIso8601String().substring(0, 10);

    // 3. Execute Insert
    if (isOnline || kIsWeb) {
      try {
        final response = await _client
            .from('confirmation_records')
            .insert(data)
            .select()
            .single();

        if (!kIsWeb) {
          await RecordsSyncService.instance.cacheRemoteRecordsLocally(
            'confirmation_records',
            [response],
          );
        }

        return ConfirmationRecordModel.fromMap(response);
      } catch (e) {
        if (kIsWeb) rethrow;
      }
    }

    await RecordsSyncService.instance.queueOfflineChange(
      tableName: 'confirmation_records',
      recordId: data['record_id'],
      operation: 'INSERT',
      data: data,
    );

    return ConfirmationRecordModel.fromMap(data);
  }

  /// Updates an existing manual Confirmation Record.
  /// Locks canonical coordinates from being modified.
  static Future<ConfirmationRecordModel> updateConfirmationRecord(
      String recordId,
      Map<String, dynamic> data,
      ) async {
    final requiredFields = {
      'confirmand_first_name': 'Confirmand First Name',
      'confirmand_last_name': 'Confirmand Last Name',
      'date_of_baptism': 'Date of Baptism',
      'church_baptized': 'Church of Baptism',
      'father_first_name': 'Father First Name',
      'father_last_name': 'Father Last Name',
      'mother_first_name': 'Mother First Name',
      'mother_maiden_last_name': 'Mother Maiden Last Name',
      'sponsor_1_first_name': 'Sponsor 1 First Name',
      'sponsor_1_last_name': 'Sponsor 1 Last Name',
      'date_of_confirmation': 'Date of Confirmation',
      'minister_first_name': 'Minister First Name',
      'minister_last_name': 'Minister Last Name',
      'parish_name': 'Parish Name',
    };

    for (final entry in requiredFields.entries) {
      final val = data[entry.key];
      if (val == null || (val is String && val.trim().isEmpty)) {
        throw '${entry.value} is required.';
      }
    }

    final baptismDate = DateTime.tryParse(data['date_of_baptism']?.toString() ?? '');
    final confirmationDate =
    DateTime.tryParse(data['date_of_confirmation']?.toString() ?? '');
    final confDateError = SacramentalValidators.validateConfirmationDate(
      confirmationDate,
      baptismDate,
    );
    if (confDateError != null) throw confDateError;

    // Protect physical coordinates from being altered
    data.remove('record_id');
    data.remove('book_number');
    data.remove('page_number');
    data.remove('line_number');

    final isOnline = await RecordsSyncService.instance.checkConnectivity();
    if (isOnline || kIsWeb) {
      try {
        final response = await _client
            .from('confirmation_records')
            .update(data)
            .eq('record_id', recordId)
            .select()
            .single();

        if (!kIsWeb) {
          await RecordsSyncService.instance.cacheRemoteRecordsLocally(
            'confirmation_records',
            [response],
          );
        }

        return ConfirmationRecordModel.fromMap(response);
      } catch (e) {
        if (kIsWeb) rethrow;
      }
    }

    await RecordsSyncService.instance.queueOfflineChange(
      tableName: 'confirmation_records',
      recordId: recordId,
      operation: 'UPDATE',
      data: data,
    );

    final db = await LocalDatabaseService.instance.database;
    if (db != null) {
      final rows = await db.query(
        'confirmation_records',
        where: 'record_id = ?',
        whereArgs: [recordId],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        return ConfirmationRecordModel.fromMap(rows.first);
      }
    }

    return ConfirmationRecordModel.fromMap(data);
  }

  /// Generates a sequential record ID: CNF-YY-XXXX.
  /// Checks Supabase directly on Web/Online, and cross-checks SQLite on native platforms.
  static Future<String> _generateRecordId() async {
    final now = DateTime.now();
    final yearSuffix = (now.year % 100).toString().padLeft(2, '0');
    int highest = 0;

    final isOnline = await RecordsSyncService.instance.checkConnectivity();
    if (isOnline || kIsWeb) {
      try {
        final remoteRecords = await _client
            .from('confirmation_records')
            .select('record_id')
            .like('record_id', 'CNF-$yearSuffix-%');

        for (final item in remoteRecords) {
          final id = item['record_id']?.toString() ?? '';
          final parts = id.split('-');
          if (parts.length >= 3) {
            final seq = int.tryParse(parts[2]);
            if (seq != null && seq > highest) highest = seq;
          }
        }
        final nextSeq = (highest + 1).toString().padLeft(4, '0');
        return 'CNF-$yearSuffix-$nextSeq';
      } catch (_) {
        if (kIsWeb) {
          final timestampSeq =
          (now.millisecondsSinceEpoch % 10000).toString().padLeft(4, '0');
          return 'CNF-$yearSuffix-$timestampSeq';
        }
      }
    }

    final db = await LocalDatabaseService.instance.database;
    if (db != null) {
      final localRows = await db.rawQuery(
        "SELECT record_id FROM confirmation_records WHERE record_id LIKE 'CNF-$yearSuffix-%'",
      );
      for (final item in localRows) {
        final id = item['record_id']?.toString() ?? '';
        final parts = id.split('-');
        if (parts.length >= 3) {
          final seq = int.tryParse(parts[2]);
          if (seq != null && seq > highest) highest = seq;
        }
      }
    }

    final nextSeq = (highest + 1).toString().padLeft(4, '0');
    return 'CNF-$yearSuffix-$nextSeq';
  }
}