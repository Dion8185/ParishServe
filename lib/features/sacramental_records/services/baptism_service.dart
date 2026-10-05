// =============================================================================
// FILE: lib/features/sacramental_records/services/baptism_service.dart
// =============================================================================

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/database/local_database_service.dart';
import '../../../core/services/records_sync_service.dart';
import '../../auth/services/auth_service.dart';
import '../models/baptism_record_model.dart';
import '../validators/sacramental_validators.dart';

class BaptismService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Fetch all baptism records ordered by date descending.
  /// On Web or Online: Queries Supabase directly and transparently caches to SQLite on native platforms.
  /// On Native Offline: Queries the local SQLite table directly without network latency or errors.
  static Future<List<BaptismRecordModel>> getBaptismRecords() async {
    final isOnline = await RecordsSyncService.instance.checkConnectivity();

    if (isOnline || kIsWeb) {
      try {
        final response = await _client
            .from('baptism_records')
            .select()
            .order('created_at', ascending: false);

        final list = (response as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();

        if (!kIsWeb) {
          await RecordsSyncService.instance.cacheRemoteRecordsLocally(
            'baptism_records',
            list,
          );
        }

        return list.map((row) => BaptismRecordModel.fromMap(row)).toList();
      } catch (_) {
        if (kIsWeb) return [];
      }
    }

    final db = await LocalDatabaseService.instance.database;
    if (db != null) {
      final rows = await db.query(
        'baptism_records',
        orderBy: 'created_at DESC, date_of_baptism DESC',
      );
      return rows.map((row) => BaptismRecordModel.fromMap(row)).toList();
    }

    return [];
  }

  /// Validates and inserts a new manual Baptism Record into public.baptism_records.
  /// On Web or Online: Persists directly to Supabase.
  /// On Native Offline: Persists to SQLite with sync_status = 'pending' and queues for auto-sync.
  static Future<BaptismRecordModel> insertManualBaptismRecord(
      Map<String, dynamic> data,
      ) async {
    // 1. Required fields validation
    final requiredFields = {
      'book_number': 'Book Number',
      'page_number': 'Page Number',
      'line_number': 'Line Number',
      'child_first_name': 'Child First Name',
      'child_last_name': 'Child Last Name',
      'date_of_birth': 'Date of Birth',
      'place_of_birth': 'Place of Birth',
      'father_first_name': 'Father First Name',
      'father_last_name': 'Father Last Name',
      'mother_first_name': 'Mother First Name',
      'mother_maiden_last_name': 'Mother Maiden Last Name',
      'sponsor_1_first_name': 'Sponsor 1 First Name',
      'sponsor_1_last_name': 'Sponsor 1 Last Name',
      'sponsor_2_first_name': 'Sponsor 2 First Name',
      'sponsor_2_last_name': 'Sponsor 2 Last Name',
      'parish_name': 'Parish Name',
      'minister_first_name': 'Minister First Name',
      'minister_last_name': 'Minister Last Name',
      'date_of_baptism': 'Date of Baptism',
      'place_of_baptism': 'Place of Baptism',
    };

    for (final entry in requiredFields.entries) {
      final val = data[entry.key];
      if (val == null || (val is String && val.trim().isEmpty)) {
        throw '${entry.value} is required.';
      }
    }

    // 2. Physical reference numerical and limit validations using SacramentalValidators
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

    // 3. Chronological sanity checks
    final dob = DateTime.tryParse(data['date_of_birth']?.toString() ?? '');
    final dobError = SacramentalValidators.validateDateOfBirth(dob);
    if (dobError != null) throw dobError;

    final baptismDate = DateTime.tryParse(data['date_of_baptism']?.toString() ?? '');
    final baptismDateError = SacramentalValidators.validateBaptismDate(baptismDate, dob);
    if (baptismDateError != null) throw baptismDateError;

    // 4. Duplicate physical reference check in local SQLite first (Native)
    if (!kIsWeb) {
      final db = await LocalDatabaseService.instance.database;
      if (db != null) {
        final localDup = await db.query(
          'baptism_records',
          where: 'book_number = ? AND page_number = ? AND line_number = ?',
          whereArgs: [cleanBook, cleanPage, cleanLine],
          limit: 1,
        );

        if (localDup.isNotEmpty) {
          throw 'This Book, Page, and Line reference is already registered in Liber Baptismorum.';
        }
      }
    }

    // Duplicate check in Supabase (Online / Web)
    final isOnline = await RecordsSyncService.instance.checkConnectivity();
    if (isOnline || kIsWeb) {
      try {
        final remoteDup = await _client
            .from('baptism_records')
            .select('record_id')
            .eq('book_number', cleanBook)
            .eq('page_number', cleanPage)
            .eq('line_number', cleanLine)
            .maybeSingle();

        if (remoteDup != null) {
          throw 'This Book, Page, and Line reference is already registered in Liber Baptismorum.';
        }
      } catch (e) {
        if (e is String) rethrow;
      }
    }

    // 5. Generate unique record_id
    if (data['record_id'] == null || data['record_id'].toString().trim().isEmpty) {
      data['record_id'] = await _generateRecordId();
    }

    // 6. Automatic encoded_by mapping
    String? encoderId = AuthService.currentUser?.userId;
    if (encoderId == null || encoderId.isEmpty) {
      encoderId = 'S26-0003';
    }
    data['encoded_by'] = encoderId;

    // 7. Managed system defaults & audit timestamps
    data['is_verified'] = false;
    data['scanned_image_url'] = null;
    data['ocr_raw_text'] = null;
    data['created_at'] = DateTime.now().toIso8601String();
    data['date_encoded'] = DateTime.now().toIso8601String();
    data['registry_date'] =
        data['registry_date'] ?? DateTime.now().toIso8601String().substring(0, 10);
    data['entry_status'] = data['entry_status'] ?? 'ORIGINAL';

    // 8. Execute insert
    if (isOnline || kIsWeb) {
      try {
        final response = await _client
            .from('baptism_records')
            .insert(data)
            .select()
            .single();

        if (!kIsWeb) {
          await RecordsSyncService.instance.cacheRemoteRecordsLocally(
            'baptism_records',
            [response],
          );
        }

        return BaptismRecordModel.fromMap(response);
      } catch (e) {
        if (kIsWeb) rethrow;
      }
    }

    // Native offline queue
    await RecordsSyncService.instance.queueOfflineChange(
      tableName: 'baptism_records',
      recordId: data['record_id'],
      operation: 'INSERT',
      data: data,
    );

    return BaptismRecordModel.fromMap(data);
  }

  /// Updates an existing manual Baptism Record in public.baptism_records.
  /// Locks canonical coordinates from accidental modification.
  static Future<BaptismRecordModel> updateBaptismRecord(
      String recordId,
      Map<String, dynamic> data,
      ) async {
    // 1. Required fields validation
    final requiredFields = {
      'child_first_name': 'Child First Name',
      'child_last_name': 'Child Last Name',
      'date_of_birth': 'Date of Birth',
      'place_of_birth': 'Place of Birth',
      'father_first_name': 'Father First Name',
      'father_last_name': 'Father Last Name',
      'mother_first_name': 'Mother First Name',
      'mother_maiden_last_name': 'Mother Maiden Last Name',
      'sponsor_1_first_name': 'Sponsor 1 First Name',
      'sponsor_1_last_name': 'Sponsor 1 Last Name',
      'sponsor_2_first_name': 'Sponsor 2 First Name',
      'sponsor_2_last_name': 'Sponsor 2 Last Name',
      'parish_name': 'Parish Name',
      'minister_first_name': 'Minister First Name',
      'minister_last_name': 'Minister Last Name',
      'date_of_baptism': 'Date of Baptism',
      'place_of_baptism': 'Place of Baptism',
    };

    for (final entry in requiredFields.entries) {
      final val = data[entry.key];
      if (val == null || (val is String && val.trim().isEmpty)) {
        throw '${entry.value} is required.';
      }
    }

    // 2. Chronological check
    final dob = DateTime.tryParse(data['date_of_birth']?.toString() ?? '');
    final baptismDate = DateTime.tryParse(data['date_of_baptism']?.toString() ?? '');
    final baptismDateError = SacramentalValidators.validateBaptismDate(baptismDate, dob);
    if (baptismDateError != null) throw baptismDateError;

    // 3. Lock and protect physical canonical coordinates from being modified
    data.remove('record_id');
    data.remove('book_number');
    data.remove('page_number');
    data.remove('line_number');

    final isOnline = await RecordsSyncService.instance.checkConnectivity();
    if (isOnline || kIsWeb) {
      try {
        final response = await _client
            .from('baptism_records')
            .update(data)
            .eq('record_id', recordId)
            .select()
            .single();

        if (!kIsWeb) {
          await RecordsSyncService.instance.cacheRemoteRecordsLocally(
            'baptism_records',
            [response],
          );
        }

        return BaptismRecordModel.fromMap(response);
      } catch (e) {
        if (kIsWeb) rethrow;
      }
    }

    await RecordsSyncService.instance.queueOfflineChange(
      tableName: 'baptism_records',
      recordId: recordId,
      operation: 'UPDATE',
      data: data,
    );

    final db = await LocalDatabaseService.instance.database;
    if (db != null) {
      final rows = await db.query(
        'baptism_records',
        where: 'record_id = ?',
        whereArgs: [recordId],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        return BaptismRecordModel.fromMap(rows.first);
      }
    }

    return BaptismRecordModel.fromMap(data);
  }

  /// Generates a sequential, canonical record ID: BAP-YY-XXXX.
  /// Checks Supabase directly on Web/Online, and cross-checks SQLite on native platforms.
  static Future<String> _generateRecordId() async {
    final now = DateTime.now();
    final yearSuffix = (now.year % 100).toString().padLeft(2, '0');
    int highest = 0;

    final isOnline = await RecordsSyncService.instance.checkConnectivity();
    if (isOnline || kIsWeb) {
      try {
        final remoteRecords = await _client
            .from('baptism_records')
            .select('record_id')
            .like('record_id', 'BAP-$yearSuffix-%');

        for (final item in remoteRecords) {
          final id = item['record_id']?.toString() ?? '';
          final parts = id.split('-');
          if (parts.length >= 3) {
            final seq = int.tryParse(parts[2]);
            if (seq != null && seq > highest) highest = seq;
          }
        }
        final nextSeq = (highest + 1).toString().padLeft(4, '0');
        return 'BAP-$yearSuffix-$nextSeq';
      } catch (_) {
        if (kIsWeb) {
          final timestampSeq =
          (now.millisecondsSinceEpoch % 10000).toString().padLeft(4, '0');
          return 'BAP-$yearSuffix-$timestampSeq';
        }
      }
    }

    final db = await LocalDatabaseService.instance.database;
    if (db != null) {
      final localRows = await db.rawQuery(
        "SELECT record_id FROM baptism_records WHERE record_id LIKE 'BAP-$yearSuffix-%'",
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
    return 'BAP-$yearSuffix-$nextSeq';
  }
}