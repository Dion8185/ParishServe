// =============================================================================
// FILE: lib/features/sacramental_records/services/matrimony_service.dart
// =============================================================================

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/database/local_database_service.dart';
import '../../../core/services/records_sync_service.dart';
import '../../auth/services/auth_service.dart';
import '../models/matrimony_record_model.dart';
import '../validators/sacramental_validators.dart';

class MatrimonyService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Fetch all matrimony records ordered by marriage date descending.
  /// On Web or Online: Queries Supabase directly and transparently caches to SQLite on native platforms.
  /// On Native Offline: Reads directly from local SQLite storage without network delay or errors.
  static Future<List<MatrimonyRecordModel>> getMatrimonyRecords() async {
    final isOnline = await RecordsSyncService.instance.checkConnectivity();

    if (isOnline || kIsWeb) {
      try {
        final response = await _client
            .from('matrimony_records')
            .select()
            .order('date_of_marriage', ascending: false)
            .order('created_at', ascending: false);

        final list = (response as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();

        if (!kIsWeb) {
          await RecordsSyncService.instance.cacheRemoteRecordsLocally(
            'matrimony_records',
            list,
          );
        }

        return list.map((row) => MatrimonyRecordModel.fromMap(row)).toList();
      } catch (_) {
        if (kIsWeb) return [];
      }
    }

    final db = await LocalDatabaseService.instance.database;
    if (db != null) {
      final rows = await db.query(
        'matrimony_records',
        orderBy: 'date_of_marriage DESC, created_at DESC',
      );
      return rows.map((row) => MatrimonyRecordModel.fromMap(row)).toList();
    }

    return [];
  }

  /// Validates and inserts a manual Matrimony record into public.matrimony_records.
  /// On Web or Online: Persists directly to Supabase.
  /// On Native Offline: Saves to SQLite with pending status and queues for auto-sync.
  static Future<MatrimonyRecordModel> insertManualMatrimonyRecord(
      Map<String, dynamic> data,
      ) async {
    // 1. Validate required fields
    final requiredFields = {
      'book_number': 'Book Number',
      'page_number': 'Page Number',
      'line_number': 'Line Number',
      'groom_first_name': 'Groom First Name',
      'groom_last_name': 'Groom Last Name',
      'groom_address': 'Groom Address',
      'bride_first_name': 'Bride First Name',
      'bride_last_name': 'Bride Last Name',
      'bride_address': 'Bride Address',
      'sponsor_1_first_name': 'Primary Sponsor 1 First Name',
      'sponsor_1_last_name': 'Primary Sponsor 1 Last Name',
      'sponsor_2_first_name': 'Primary Sponsor 2 First Name',
      'sponsor_2_last_name': 'Primary Sponsor 2 Last Name',
      'date_of_marriage': 'Date of Marriage',
      'solemnizer_first_name': 'Solemnizing Minister First Name',
      'solemnizer_last_name': 'Solemnizing Minister Last Name',
    };

    for (final entry in requiredFields.entries) {
      final val = data[entry.key];
      if (val == null || (val is String && val.trim().isEmpty)) {
        throw '${entry.value} is required.';
      }
    }

    // 2. Physical reference limits (Canon 535) using SacramentalValidators
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

    // 3. Demographic age checks
    final groomAgeError = SacramentalValidators.validateWholeNumberAge(
      data['groom_age']?.toString(),
    );
    if (groomAgeError != null) throw 'Groom: $groomAgeError';

    final brideAgeError = SacramentalValidators.validateWholeNumberAge(
      data['bride_age']?.toString(),
    );
    if (brideAgeError != null) throw 'Bride: $brideAgeError';

    // 4. Check duplicate physical reference in local SQLite first (Native)
    if (!kIsWeb) {
      final db = await LocalDatabaseService.instance.database;
      if (db != null) {
        final localDup = await db.query(
          'matrimony_records',
          where: 'book_number = ? AND page_number = ? AND line_number = ?',
          whereArgs: [cleanBook, cleanPage, cleanLine],
          limit: 1,
        );

        if (localDup.isNotEmpty) {
          throw 'This Book, Page, and Line reference is already registered in the Matrimony Register.';
        }
      }
    }

    // Duplicate check in Supabase (Online / Web)
    final isOnline = await RecordsSyncService.instance.checkConnectivity();
    if (isOnline || kIsWeb) {
      try {
        final remoteDup = await _client
            .from('matrimony_records')
            .select('record_id')
            .eq('book_number', cleanBook)
            .eq('page_number', cleanPage)
            .eq('line_number', cleanLine)
            .maybeSingle();

        if (remoteDup != null) {
          throw 'This Book, Page, and Line reference is already registered in the Matrimony Register.';
        }
      } catch (e) {
        if (e is String) rethrow;
      }
    }

    // 5. Generate unique record ID: MAT-YY-XXXX
    if (data['record_id'] == null || data['record_id'].toString().trim().isEmpty) {
      data['record_id'] = await _generateRecordId();
    }

    // 6. Automatic encoded_by mapping
    String? encoderId = AuthService.currentUser?.userId;
    data['encoded_by'] = encoderId ?? 'S26-0003';

    data['is_verified'] = false;
    data['scanned_image_url'] = null;
    data['ocr_raw_text'] = null;
    data['created_at'] = DateTime.now().toIso8601String();
    data['date_encoded'] = DateTime.now().toIso8601String();
    data['registry_date'] =
        data['registry_date'] ?? DateTime.now().toIso8601String().substring(0, 10);
    data['entry_status'] = data['entry_status'] ?? 'ORIGINAL';

    // Format other_sponsors if passed as a List
    if (data['other_sponsors'] is List) {
      data['other_sponsors'] = (data['other_sponsors'] as List).join('\n');
    }

    // 7. Execute Insert
    if (isOnline || kIsWeb) {
      try {
        final response = await _client
            .from('matrimony_records')
            .insert(data)
            .select()
            .single();

        if (!kIsWeb) {
          await RecordsSyncService.instance.cacheRemoteRecordsLocally(
            'matrimony_records',
            [response],
          );
        }

        return MatrimonyRecordModel.fromMap(response);
      } catch (e) {
        if (kIsWeb) rethrow;
      }
    }

    await RecordsSyncService.instance.queueOfflineChange(
      tableName: 'matrimony_records',
      recordId: data['record_id'],
      operation: 'INSERT',
      data: data,
    );

    return MatrimonyRecordModel.fromMap(data);
  }

  /// Updates an existing manual Matrimony record in public.matrimony_records.
  /// Locks canonical coordinates from being modified.
  static Future<MatrimonyRecordModel> updateMatrimonyRecord(
      String recordId,
      Map<String, dynamic> data,
      ) async {
    final requiredFields = {
      'groom_first_name': 'Groom First Name',
      'groom_last_name': 'Groom Last Name',
      'groom_address': 'Groom Address',
      'bride_first_name': 'Bride First Name',
      'bride_last_name': 'Bride Last Name',
      'bride_address': 'Bride Address',
      'sponsor_1_first_name': 'Primary Sponsor 1 First Name',
      'sponsor_1_last_name': 'Primary Sponsor 1 Last Name',
      'sponsor_2_first_name': 'Primary Sponsor 2 First Name',
      'sponsor_2_last_name': 'Primary Sponsor 2 Last Name',
      'date_of_marriage': 'Date of Marriage',
      'solemnizer_first_name': 'Solemnizing Minister First Name',
      'solemnizer_last_name': 'Solemnizing Minister Last Name',
    };

    for (final entry in requiredFields.entries) {
      final val = data[entry.key];
      if (val == null || (val is String && val.trim().isEmpty)) {
        throw '${entry.value} is required.';
      }
    }

    // Protect immutable physical coordinates from being altered
    data.remove('record_id');
    data.remove('book_number');
    data.remove('page_number');
    data.remove('line_number');

    if (data['other_sponsors'] is List) {
      data['other_sponsors'] = (data['other_sponsors'] as List).join('\n');
    }

    final isOnline = await RecordsSyncService.instance.checkConnectivity();
    if (isOnline || kIsWeb) {
      try {
        final response = await _client
            .from('matrimony_records')
            .update(data)
            .eq('record_id', recordId)
            .select()
            .single();

        if (!kIsWeb) {
          await RecordsSyncService.instance.cacheRemoteRecordsLocally(
            'matrimony_records',
            [response],
          );
        }

        return MatrimonyRecordModel.fromMap(response);
      } catch (e) {
        if (kIsWeb) rethrow;
      }
    }

    await RecordsSyncService.instance.queueOfflineChange(
      tableName: 'matrimony_records',
      recordId: recordId,
      operation: 'UPDATE',
      data: data,
    );

    final db = await LocalDatabaseService.instance.database;
    if (db != null) {
      final rows = await db.query(
        'matrimony_records',
        where: 'record_id = ?',
        whereArgs: [recordId],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        return MatrimonyRecordModel.fromMap(rows.first);
      }
    }

    return MatrimonyRecordModel.fromMap(data);
  }

  /// Generates sequential record ID: MAT-YY-XXXX.
  /// Checks Supabase directly on Web/Online and cross-checks SQLite on native platforms.
  static Future<String> _generateRecordId() async {
    final now = DateTime.now();
    final yearSuffix = (now.year % 100).toString().padLeft(2, '0');
    int highest = 0;

    final isOnline = await RecordsSyncService.instance.checkConnectivity();
    if (isOnline || kIsWeb) {
      try {
        final remoteRecords = await _client
            .from('matrimony_records')
            .select('record_id')
            .like('record_id', 'MAT-$yearSuffix-%');

        for (final item in remoteRecords) {
          final id = item['record_id']?.toString() ?? '';
          final parts = id.split('-');
          if (parts.length >= 3) {
            final seq = int.tryParse(parts[2]);
            if (seq != null && seq > highest) highest = seq;
          }
        }
        final nextSeq = (highest + 1).toString().padLeft(4, '0');
        return 'MAT-$yearSuffix-$nextSeq';
      } catch (_) {
        if (kIsWeb) {
          final timestampSeq =
          (now.millisecondsSinceEpoch % 10000).toString().padLeft(4, '0');
          return 'MAT-$yearSuffix-$timestampSeq';
        }
      }
    }

    final db = await LocalDatabaseService.instance.database;
    if (db != null) {
      final localRows = await db.rawQuery(
        "SELECT record_id FROM matrimony_records WHERE record_id LIKE 'MAT-$yearSuffix-%'",
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
    return 'MAT-$yearSuffix-$nextSeq';
  }
}