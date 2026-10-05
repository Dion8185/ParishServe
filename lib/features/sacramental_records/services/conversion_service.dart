// =============================================================================
// FILE: lib/features/sacramental_records/services/conversion_service.dart
// =============================================================================

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/database/local_database_service.dart';
import '../../../core/services/records_sync_service.dart';
import '../../auth/services/auth_service.dart';
import '../models/conversion_record_model.dart';
import '../validators/sacramental_validators.dart';

class ConversionService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Fetch all conversion records ordered by date of reception descending.
  /// On Web or Online: Queries Supabase directly and transparently caches to SQLite on native platforms.
  /// On Native Offline: Reads directly from local SQLite storage without network delay or errors.
  static Future<List<ConversionRecordModel>> getConversionRecords() async {
    final isOnline = await RecordsSyncService.instance.checkConnectivity();

    if (isOnline || kIsWeb) {
      try {
        final response = await _client
            .from('conversion_records')
            .select()
            .order('date_of_reception', ascending: false)
            .order('created_at', ascending: false);

        final list = (response as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();

        if (!kIsWeb) {
          await RecordsSyncService.instance.cacheRemoteRecordsLocally(
            'conversion_records',
            list,
          );
        }

        return list.map((row) => ConversionRecordModel.fromMap(row)).toList();
      } catch (_) {
        if (kIsWeb) return [];
      }
    }

    final db = await LocalDatabaseService.instance.database;
    if (db != null) {
      final rows = await db.query(
        'conversion_records',
        orderBy: 'date_of_reception DESC, created_at DESC',
      );
      return rows.map((row) => ConversionRecordModel.fromMap(row)).toList();
    }

    return [];
  }

  /// Validates and inserts a manual Conversion record into public.conversion_records.
  /// On Web or Online: Persists directly to Supabase.
  /// On Native Offline: Saves to SQLite with pending status and queues for auto-sync.
  static Future<ConversionRecordModel> insertManualConversionRecord(
      Map<String, dynamic> data,
      ) async {
    // 1. Required fields validation
    final requiredFields = {
      'book_number': 'Book Number',
      'page_number': 'Page Number',
      'line_number': 'Line Number',
      'date_of_reception': 'Date of Reception into Full Communion',
      'convert_first_name': 'Convert First Name',
      'convert_last_name': 'Convert Last Name',
      'date_of_birth': 'Date of Birth',
      'place_of_birth': 'Place of Birth',
      'witness_1_first_name': 'Witness 1 First Name',
      'witness_1_last_name': 'Witness 1 Last Name',
      'minister_first_name': 'Minister First Name',
      'minister_last_name': 'Minister Last Name',
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

    // 3. Chronological consistency checks
    final dob = DateTime.tryParse(data['date_of_birth']?.toString() ?? '');
    final dobError = SacramentalValidators.validateDateOfBirth(dob);
    if (dobError != null) throw dobError;

    final receptionDate =
    DateTime.tryParse(data['date_of_reception']?.toString() ?? '');
    final receptionError = SacramentalValidators.validateReceptionDate(
      receptionDate,
      dob,
    );
    if (receptionError != null) throw receptionError;

    final priorBaptismDate = data['prior_baptism_date'] != null
        ? DateTime.tryParse(data['prior_baptism_date'].toString())
        : null;
    final priorBaptismError = SacramentalValidators.validatePriorBaptismDate(
      priorBaptismDate,
      dob,
    );
    if (priorBaptismError != null) throw priorBaptismError;

    // 4. Check duplicate physical reference in local SQLite first (Native)
    if (!kIsWeb) {
      final db = await LocalDatabaseService.instance.database;
      if (db != null) {
        final localDup = await db.query(
          'conversion_records',
          where: 'book_number = ? AND page_number = ? AND line_number = ?',
          whereArgs: [cleanBook, cleanPage, cleanLine],
          limit: 1,
        );

        if (localDup.isNotEmpty) {
          throw 'This Book, Page, and Line reference is already registered in the Conversion Register.';
        }
      }
    }

    // Duplicate check in Supabase (Online / Web)
    final isOnline = await RecordsSyncService.instance.checkConnectivity();
    if (isOnline || kIsWeb) {
      try {
        final remoteDup = await _client
            .from('conversion_records')
            .select('record_id')
            .eq('book_number', cleanBook)
            .eq('page_number', cleanPage)
            .eq('line_number', cleanLine)
            .maybeSingle();

        if (remoteDup != null) {
          throw 'This Book, Page, and Line reference is already registered in the Conversion Register.';
        }
      } catch (e) {
        if (e is String) rethrow;
      }
    }

    // 5. Generate unique record ID: CNV-YY-XXXX
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
    data['parish_name'] = data['parish_name'] ?? 'St. John Paul II Parish';
    data['is_gratis'] = data['is_gratis'] ?? true;
    data['stipend'] = data['stipend'] ?? 0.00;

    // 7. Execute Insert
    if (isOnline || kIsWeb) {
      try {
        final response = await _client
            .from('conversion_records')
            .insert(data)
            .select()
            .single();

        if (!kIsWeb) {
          await RecordsSyncService.instance.cacheRemoteRecordsLocally(
            'conversion_records',
            [response],
          );
        }

        return ConversionRecordModel.fromMap(response);
      } catch (e) {
        if (kIsWeb) rethrow;
      }
    }

    await RecordsSyncService.instance.queueOfflineChange(
      tableName: 'conversion_records',
      recordId: data['record_id'],
      operation: 'INSERT',
      data: data,
    );

    return ConversionRecordModel.fromMap(data);
  }

  /// Updates an existing manual Conversion record in public.conversion_records.
  /// Locks canonical coordinates from being modified.
  static Future<ConversionRecordModel> updateConversionRecord(
      String recordId,
      Map<String, dynamic> data,
      ) async {
    final requiredFields = {
      'date_of_reception': 'Date of Reception into Full Communion',
      'convert_first_name': 'Convert First Name',
      'convert_last_name': 'Convert Last Name',
      'date_of_birth': 'Date of Birth',
      'place_of_birth': 'Place of Birth',
      'witness_1_first_name': 'Witness 1 First Name',
      'witness_1_last_name': 'Witness 1 Last Name',
      'minister_first_name': 'Minister First Name',
      'minister_last_name': 'Minister Last Name',
    };

    for (final entry in requiredFields.entries) {
      final val = data[entry.key];
      if (val == null || (val is String && val.trim().isEmpty)) {
        throw '${entry.value} is required.';
      }
    }

    final dob = DateTime.tryParse(data['date_of_birth']?.toString() ?? '');
    final receptionDate =
    DateTime.tryParse(data['date_of_reception']?.toString() ?? '');
    final receptionError = SacramentalValidators.validateReceptionDate(
      receptionDate,
      dob,
    );
    if (receptionError != null) throw receptionError;

    final priorBaptismDate = data['prior_baptism_date'] != null
        ? DateTime.tryParse(data['prior_baptism_date'].toString())
        : null;
    final priorBaptismError = SacramentalValidators.validatePriorBaptismDate(
      priorBaptismDate,
      dob,
    );
    if (priorBaptismError != null) throw priorBaptismError;

    // Protect immutable physical coordinates from being altered
    data.remove('record_id');
    data.remove('book_number');
    data.remove('page_number');
    data.remove('line_number');

    final isOnline = await RecordsSyncService.instance.checkConnectivity();
    if (isOnline || kIsWeb) {
      try {
        final response = await _client
            .from('conversion_records')
            .update(data)
            .eq('record_id', recordId)
            .select()
            .single();

        if (!kIsWeb) {
          await RecordsSyncService.instance.cacheRemoteRecordsLocally(
            'conversion_records',
            [response],
          );
        }

        return ConversionRecordModel.fromMap(response);
      } catch (e) {
        if (kIsWeb) rethrow;
      }
    }

    await RecordsSyncService.instance.queueOfflineChange(
      tableName: 'conversion_records',
      recordId: recordId,
      operation: 'UPDATE',
      data: data,
    );

    final db = await LocalDatabaseService.instance.database;
    if (db != null) {
      final rows = await db.query(
        'conversion_records',
        where: 'record_id = ?',
        whereArgs: [recordId],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        return ConversionRecordModel.fromMap(rows.first);
      }
    }

    return ConversionRecordModel.fromMap(data);
  }

  /// Generates sequential record ID: CNV-YY-XXXX.
  /// Checks Supabase directly on Web/Online and cross-checks SQLite on native platforms.
  static Future<String> _generateRecordId() async {
    final now = DateTime.now();
    final yearSuffix = (now.year % 100).toString().padLeft(2, '0');
    int highest = 0;

    final isOnline = await RecordsSyncService.instance.checkConnectivity();
    if (isOnline || kIsWeb) {
      try {
        final remoteRecords = await _client
            .from('conversion_records')
            .select('record_id')
            .like('record_id', 'CNV-$yearSuffix-%');

        for (final item in remoteRecords) {
          final id = item['record_id']?.toString() ?? '';
          final parts = id.split('-');
          if (parts.length >= 3) {
            final seq = int.tryParse(parts[2]);
            if (seq != null && seq > highest) highest = seq;
          }
        }
        final nextSeq = (highest + 1).toString().padLeft(4, '0');
        return 'CNV-$yearSuffix-$nextSeq';
      } catch (_) {
        if (kIsWeb) {
          final timestampSeq =
          (now.millisecondsSinceEpoch % 10000).toString().padLeft(4, '0');
          return 'CNV-$yearSuffix-$timestampSeq';
        }
      }
    }

    final db = await LocalDatabaseService.instance.database;
    if (db != null) {
      final localRows = await db.rawQuery(
        "SELECT record_id FROM conversion_records WHERE record_id LIKE 'CNV-$yearSuffix-%'",
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
    return 'CNV-$yearSuffix-$nextSeq';
  }
}