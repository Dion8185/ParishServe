// =============================================================================
// FILE: lib/features/sacramental_records/services/sacrament_csv_service.dart
// =============================================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:printing/printing.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/database/local_database_service.dart';
import '../../../core/services/records_sync_service.dart';
import '../../auth/services/auth_service.dart';

class CsvValidationResult {
  final bool isValid;
  final String? errorMessage;
  final List<String> headers;
  final List<Map<String, dynamic>> parsedRows;
  final int totalCount;

  const CsvValidationResult({
    required this.isValid,
    this.errorMessage,
    this.headers = const [],
    this.parsedRows = const [],
    this.totalCount = 0,
  });
}

class SacramentCsvService {
  SacramentCsvService._();

  static final SupabaseClient _client = Supabase.instance.client;

  // ===========================================================================
  // 1. Exact Canonical Column Schema Definitions
  // ===========================================================================

  /// Exact 47 columns for Baptism Records matching the database schema
  static const List<String> baptismColumns = [
    'record_id',
    'book_number',
    'page_number',
    'line_number',
    'child_first_name',
    'child_middle_name',
    'child_last_name',
    'child_suffix',
    'date_of_birth',
    'age',
    'place_of_birth',
    'gender',
    'legitimacy',
    'father_first_name',
    'father_middle_name',
    'father_last_name',
    'father_place_of_birth',
    'mother_first_name',
    'mother_middle_name',
    'mother_maiden_last_name',
    'mother_place_of_birth',
    'parents_contact_number',
    'parents_residence',
    'sponsor_1_first_name',
    'sponsor_1_middle_name',
    'sponsor_1_last_name',
    'sponsor_1_residence',
    'sponsor_2_first_name',
    'sponsor_2_middle_name',
    'sponsor_2_last_name',
    'sponsor_2_residence',
    'other_godparents',
    'parish_name',
    'minister_first_name',
    'minister_middle_name',
    'minister_last_name',
    'date_of_baptism',
    'place_of_baptism',
    'stipend',
    'remarks',
    'is_verified',
    'encoded_by',
    'date_encoded',
    'created_at',
    'approved_by_priest',
    'registry_date',
    'entry_status',
  ];

  /// Canonical columns for Confirmation Records
  static const List<String> confirmationColumns = [
    'record_id',
    'book_number',
    'page_number',
    'line_number',
    'registry_date',
    'entry_status',
    'confirmand_first_name',
    'confirmand_middle_name',
    'confirmand_last_name',
    'confirmand_suffix',
    'date_of_birth',
    'age',
    'date_of_baptism',
    'church_baptized',
    'address',
    'father_first_name',
    'father_middle_name',
    'father_last_name',
    'father_origin',
    'mother_first_name',
    'mother_middle_name',
    'mother_maiden_last_name',
    'mother_origin',
    'sponsor_1_first_name',
    'sponsor_1_middle_name',
    'sponsor_1_last_name',
    'sponsor_1_origin_address',
    'sponsor_2_first_name',
    'sponsor_2_middle_name',
    'sponsor_2_last_name',
    'sponsor_2_origin_address',
    'date_of_confirmation',
    'stipend',
    'minister_first_name',
    'minister_middle_name',
    'minister_last_name',
    'parish_name',
    'remarks',
    'is_verified',
    'encoded_by',
    'date_encoded',
    'created_at',
  ];

  /// Canonical columns for First Communion Records
  static const List<String> firstCommunionColumns = [
    'record_id',
    'year',
    'control_number',
    'communicant_first_name',
    'communicant_middle_name',
    'communicant_last_name',
    'date_of_communion',
    'baptism_parish',
    'baptism_date',
    'father_first_name',
    'father_middle_name',
    'father_last_name',
    'mother_first_name',
    'mother_middle_name',
    'mother_maiden_last_name',
    'minister_first_name',
    'minister_middle_name',
    'minister_last_name',
    'remarks',
    'is_verified',
    'encoded_by',
    'created_at',
  ];

  /// Canonical columns for Matrimony Records
  static const List<String> matrimonyColumns = [
    'record_id',
    'book_number',
    'page_number',
    'line_number',
    'registry_date',
    'entry_status',
    'groom_first_name',
    'groom_middle_name',
    'groom_last_name',
    'groom_suffix',
    'groom_civil_status',
    'groom_age',
    'groom_date_of_birth',
    'groom_place_of_birth',
    'groom_address',
    'groom_father_first_name',
    'groom_father_middle_name',
    'groom_father_last_name',
    'groom_mother_first_name',
    'groom_mother_middle_name',
    'groom_mother_maiden_last',
    'bride_first_name',
    'bride_middle_name',
    'bride_last_name',
    'bride_suffix',
    'bride_civil_status',
    'bride_age',
    'bride_date_of_birth',
    'bride_place_of_birth',
    'bride_address',
    'bride_father_first_name',
    'bride_father_middle_name',
    'bride_father_last_name',
    'bride_mother_first_name',
    'bride_mother_middle_name',
    'bride_mother_maiden_last',
    'sponsor_1_first_name',
    'sponsor_1_middle_name',
    'sponsor_1_last_name',
    'sponsor_1_origin_address',
    'sponsor_2_first_name',
    'sponsor_2_middle_name',
    'sponsor_2_last_name',
    'sponsor_2_origin_address',
    'other_sponsors',
    'date_of_marriage',
    'marriage_type',
    'is_filipino_foreigner',
    'marriage_license_no',
    'license_date_registered',
    'license_place_issued',
    'solemnizer_first_name',
    'solemnizer_middle_name',
    'solemnizer_last_name',
    'crasm_number',
    'crasm_validity_date',
    'stipend',
    'remarks',
    'parish_name',
    'is_verified',
    'encoded_by',
    'date_encoded',
    'created_at',
  ];

  /// Canonical columns for Death Records
  static const List<String> deathColumns = [
    'record_id',
    'book_number',
    'page_number',
    'line_number',
    'deceased_first_name',
    'deceased_middle_name',
    'deceased_last_name',
    'deceased_suffix',
    'gender',
    'age',
    'civil_status',
    'residence',
    'spouse_first_name',
    'spouse_middle_name',
    'spouse_last_name',
    'father_first_name',
    'father_middle_name',
    'father_last_name',
    'mother_first_name',
    'mother_middle_name',
    'mother_maiden_last_name',
    'date_of_death',
    'date_of_burial',
    'place_of_burial',
    'cause_of_death',
    'sacraments_received',
    'sacraments_notes',
    'liturgical_service',
    'stipend',
    'minister_first_name',
    'minister_middle_name',
    'minister_last_name',
    'remarks',
    'parish_name',
    'is_verified',
    'encoded_by',
    'date_encoded',
    'created_at',
  ];

  /// Canonical columns for Conversion Records
  static const List<String> conversionColumns = [
    'record_id',
    'book_number',
    'page_number',
    'line_number',
    'date_of_reception',
    'convert_first_name',
    'convert_middle_name',
    'convert_last_name',
    'convert_suffix',
    'date_of_birth',
    'place_of_birth',
    'prior_baptism_date',
    'prior_baptism_church',
    'prior_baptism_place',
    'father_first_name',
    'father_middle_name',
    'father_last_name',
    'father_religion',
    'mother_first_name',
    'mother_middle_name',
    'mother_maiden_last_name',
    'mother_religion',
    'witness_1_first_name',
    'witness_1_middle_name',
    'witness_1_last_name',
    'witness_2_first_name',
    'witness_2_middle_name',
    'witness_2_last_name',
    'is_gratis',
    'stipend',
    'minister_first_name',
    'minister_middle_name',
    'minister_last_name',
    'remarks',
    'parish_name',
    'is_verified',
    'encoded_by',
    'date_encoded',
    'created_at',
  ];

  static List<String> getColumnsForSacrament(String sacramentName) {
    switch (sacramentName) {
      case 'Baptism':
        return baptismColumns;
      case 'Confirmation':
        return confirmationColumns;
      case 'First Communion':
        return firstCommunionColumns;
      case 'Matrimony':
        return matrimonyColumns;
      case 'Death':
        return deathColumns;
      case 'Conversion':
        return conversionColumns;
      default:
        return baptismColumns;
    }
  }

  static String getTableName(String sacramentName) {
    switch (sacramentName) {
      case 'Baptism':
        return 'baptism_records';
      case 'Confirmation':
        return 'confirmation_records';
      case 'First Communion':
        return 'first_communion_records';
      case 'Matrimony':
        return 'matrimony_records';
      case 'Death':
        return 'death_records';
      case 'Conversion':
        return 'conversion_records';
      default:
        return 'baptism_records';
    }
  }

  static String getExpectedFileName(String sacramentName) {
    switch (sacramentName) {
      case 'Baptism':
        return 'baptism.csv';
      case 'Confirmation':
        return 'confirmation.csv';
      case 'First Communion':
        return 'first_communion.csv';
      case 'Matrimony':
        return 'matrimony.csv';
      case 'Death':
        return 'death.csv';
      case 'Conversion':
        return 'conversion.csv';
      default:
        return '${sacramentName.toLowerCase().replaceAll(' ', '_')}.csv';
    }
  }

  // ===========================================================================
  // 2. Strict File Name & Sacrament Validation
  // ===========================================================================

  /// Enforces that only sacrament-specific CSV files can be imported
  /// e.g. "Only baptism.csv can be imported inside baptism registry and so on"
  static bool validateFileName(String fileName, String sacramentName) {
    final clean = fileName.trim().toLowerCase();
    if (!clean.endsWith('.csv')) return false;

    final expected = getExpectedFileName(sacramentName).toLowerCase();
    final expectedBase = expected.replaceAll('.csv', '');

    // Strict matching: file name must exactly be "[sacrament].csv"
    // or start with "[sacrament]" (e.g. "baptism.csv", "baptism_records.csv")
    if (clean == expected) return true;

    final nameWithoutExt = clean.substring(0, clean.length - 4);
    if (nameWithoutExt == expectedBase ||
        nameWithoutExt == '${expectedBase}_records' ||
        nameWithoutExt.startsWith('${expectedBase}_') ||
        nameWithoutExt.startsWith('$expectedBase-')) {
      return true;
    }

    return false;
  }

  // ===========================================================================
  // 3. RFC-4180 Compliant CSV Serializer & Parser
  // ===========================================================================

  static String escapeCsvCell(dynamic value) {
    if (value == null) return '';
    String str = value.toString().trim();
    if (str.isEmpty || str.toLowerCase() == 'null') return '';

    // Enclose cell in double quotes if it contains commas, newlines, or quotes
    if (str.contains(',') || str.contains('"') || str.contains('\n') || str.contains('\r')) {
      str = str.replaceAll('"', '""');
      return '"$str"';
    }
    return str;
  }

  /// Builds a complete CSV string using the strict columns order
  static String generateCsv({
    required String sacramentName,
    required List<Map<String, dynamic>> records,
  }) {
    final columns = getColumnsForSacrament(sacramentName);
    final buffer = StringBuffer();

    // 1. Header row
    buffer.writeln(columns.join(','));

    // 2. Data rows
    for (final row in records) {
      final lineCells = <String>[];
      for (final col in columns) {
        lineCells.add(escapeCsvCell(row[col]));
      }
      buffer.writeln(lineCells.join(','));
    }

    return buffer.toString();
  }

  /// Generates a blank CSV template containing only the column headers
  static String generateEmptyTemplate(String sacramentName) {
    final columns = getColumnsForSacrament(sacramentName);
    return '${columns.join(',')}\n';
  }

  /// Robust RFC-4180 CSV parser handling multi-line quoted cells, commas, and escaped quotes
  static List<List<String>> parseCsvString(String rawCsv) {
    final List<List<String>> rows = [];
    final List<String> currentRow = [];
    final StringBuffer currentCell = StringBuffer();

    bool inQuotes = false;
    final int len = rawCsv.length;

    for (int i = 0; i < len; i++) {
      final char = rawCsv[i];

      if (inQuotes) {
        if (char == '"') {
          // Check for escaped double quotes ("")
          if (i + 1 < len && rawCsv[i + 1] == '"') {
            currentCell.write('"');
            i++; // skip next quote
          } else {
            inQuotes = false;
          }
        } else {
          currentCell.write(char);
        }
      } else {
        if (char == '"') {
          inQuotes = true;
        } else if (char == ',') {
          currentRow.add(currentCell.toString().trim());
          currentCell.clear();
        } else if (char == '\r') {
          // Ignore \r if followed by \n
          if (i + 1 < len && rawCsv[i + 1] == '\n') {
            i++;
          }
          currentRow.add(currentCell.toString().trim());
          currentCell.clear();
          if (currentRow.any((c) => c.isNotEmpty)) {
            rows.add(List.from(currentRow));
          }
          currentRow.clear();
        } else if (char == '\n') {
          currentRow.add(currentCell.toString().trim());
          currentCell.clear();
          if (currentRow.any((c) => c.isNotEmpty)) {
            rows.add(List.from(currentRow));
          }
          currentRow.clear();
        } else {
          currentCell.write(char);
        }
      }
    }

    // Flush remaining buffer
    currentRow.add(currentCell.toString().trim());
    if (currentRow.any((c) => c.isNotEmpty)) {
      rows.add(currentRow);
    }

    return rows;
  }

  // ===========================================================================
  // 4. File Validation & Data Preview Parsing
  // ===========================================================================

  static CsvValidationResult validateAndParseCsv({
    required String fileName,
    required String rawContent,
    required String sacramentName,
  }) {
    // 1. Strict File Name Verification
    final expectedFileName = getExpectedFileName(sacramentName);
    if (!validateFileName(fileName, sacramentName)) {
      return CsvValidationResult(
        isValid: false,
        errorMessage: 'Invalid file name. Only "$expectedFileName" can be imported into the $sacramentName Registry.',
      );
    }

    final parsedRows = parseCsvString(rawContent);
    if (parsedRows.isEmpty) {
      return const CsvValidationResult(
        isValid: false,
        errorMessage: 'The selected CSV file is empty. Please select a valid CSV with canonical record rows.',
      );
    }

    final headers = parsedRows.first.map((h) => h.trim().toLowerCase()).toList();
    final expectedColumns = getColumnsForSacrament(sacramentName);

    // 2. Header Structure Validation: Check for essential primary columns
    final List<String> missingEssential = [];
    if (sacramentName == 'Baptism') {
      for (final col in ['book_number', 'page_number', 'line_number', 'child_first_name', 'child_last_name', 'date_of_baptism']) {
        if (!headers.contains(col)) missingEssential.add(col);
      }
    } else if (sacramentName == 'Confirmation') {
      for (final col in ['book_number', 'page_number', 'line_number', 'confirmand_first_name', 'confirmand_last_name', 'date_of_confirmation']) {
        if (!headers.contains(col)) missingEssential.add(col);
      }
    } else if (sacramentName == 'First Communion') {
      for (final col in ['year', 'control_number', 'communicant_first_name', 'communicant_last_name', 'date_of_communion']) {
        if (!headers.contains(col)) missingEssential.add(col);
      }
    } else if (sacramentName == 'Matrimony') {
      for (final col in ['book_number', 'page_number', 'line_number', 'groom_first_name', 'bride_first_name', 'date_of_marriage']) {
        if (!headers.contains(col)) missingEssential.add(col);
      }
    } else if (sacramentName == 'Death') {
      for (final col in ['book_number', 'page_number', 'line_number', 'deceased_first_name', 'deceased_last_name', 'date_of_death']) {
        if (!headers.contains(col)) missingEssential.add(col);
      }
    } else if (sacramentName == 'Conversion') {
      for (final col in ['book_number', 'page_number', 'line_number', 'convert_first_name', 'convert_last_name', 'date_of_reception']) {
        if (!headers.contains(col)) missingEssential.add(col);
      }
    }

    if (missingEssential.isNotEmpty) {
      return CsvValidationResult(
        isValid: false,
        errorMessage: 'The CSV headers do not match $sacramentName records. Missing required columns: ${missingEssential.join(", ")}.',
      );
    }

    // 3. Map Data Rows
    final List<Map<String, dynamic>> recordsList = [];
    final currentUserId = AuthService.currentUser?.userId ?? 'STAFF';
    final nowIso = DateTime.now().toIso8601String();

    for (int r = 1; r < parsedRows.length; r++) {
      final rowCells = parsedRows[r];
      // Skip empty blank lines
      if (rowCells.every((cell) => cell.trim().isEmpty)) continue;

      final Map<String, dynamic> recordMap = {};

      for (int c = 0; c < headers.length; c++) {
        final colName = headers[c];
        final cellVal = c < rowCells.length ? rowCells[c].trim() : '';

        if (cellVal.isEmpty || cellVal.toLowerCase() == 'null') {
          recordMap[colName] = null;
        } else if (colName == 'is_verified' || colName == 'approved_by_priest' || colName == 'is_filipino_foreigner' || colName == 'is_gratis' || colName == 'sacraments_received') {
          recordMap[colName] = cellVal.toLowerCase() == 'true' || cellVal == '1' || cellVal.toLowerCase() == 'yes';
        } else if (colName == 'stipend') {
          recordMap[colName] = double.tryParse(cellVal);
        } else if (colName == 'year' || (colName == 'age' && sacramentName == 'Confirmation')) {
          recordMap[colName] = int.tryParse(cellVal);
        } else {
          recordMap[colName] = cellVal;
        }
      }

      // Fill system audit defaults if omitted in CSV
      if (recordMap['encoded_by'] == null || recordMap['encoded_by'].toString().isEmpty) {
        recordMap['encoded_by'] = currentUserId;
      }
      if (recordMap['created_at'] == null) {
        recordMap['created_at'] = nowIso;
      }
      if (recordMap['date_encoded'] == null) {
        recordMap['date_encoded'] = nowIso;
      }

      recordsList.add(recordMap);
    }

    if (recordsList.isEmpty) {
      return const CsvValidationResult(
        isValid: false,
        errorMessage: 'The CSV file contains header columns but has no data rows to import.',
      );
    }

    return CsvValidationResult(
      isValid: true,
      headers: expectedColumns,
      parsedRows: recordsList,
      totalCount: recordsList.length,
    );
  }

  // ===========================================================================
  // 5. Database Batch Importer (Supabase & SQLite Upsert)
  // ===========================================================================

  /// Executes batch import into Supabase and local SQLite storage
  static Future<int> executeImport({
    required String sacramentName,
    required List<Map<String, dynamic>> records,
    void Function(double progress, String status)? onProgress,
  }) async {
    final tableName = getTableName(sacramentName);
    final total = records.length;
    int importedCount = 0;

    final isOnline = await RecordsSyncService.instance.checkConnectivity();
    final db = await LocalDatabaseService.instance.database;

    // Process in batches of 50 to avoid timeout or payload limit
    const batchSize = 50;

    for (int i = 0; i < total; i += batchSize) {
      final end = (i + batchSize) > total ? total : (i + batchSize);
      final batchChunk = records.sublist(i, end);

      onProgress?.call(
        i / total,
        'Importing records ${i + 1} to $end of $total...',
      );

      // 1. Supabase Cloud Upsert
      if (isOnline || kIsWeb) {
        try {
          await _client
              .from(tableName)
              .upsert(batchChunk, onConflict: 'record_id');
        } catch (e) {
          debugPrint('[SacramentCsvService] Supabase upsert error on batch: $e');
          if (kIsWeb) rethrow;
        }
      }

      // 2. Local SQLite Cache Upsert (Native)
      if (db != null && !kIsWeb) {
        try {
          final sqLiteBatch = db.batch();
          for (final record in batchChunk) {
            final sqliteMap = Map<String, dynamic>.from(record);
            sqliteMap['sync_status'] = 'synced';
            sqliteMap['last_modified_at'] = DateTime.now().toIso8601String();

            sqliteMap.forEach((key, value) {
              if (value is bool) {
                sqliteMap[key] = value ? 1 : 0;
              } else if (value is Map || value is List) {
                sqliteMap[key] = jsonEncode(value);
              }
            });

            sqLiteBatch.insert(
              tableName,
              sqliteMap,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
          await sqLiteBatch.commit(noResult: true);
        } catch (e) {
          debugPrint('[SacramentCsvService] SQLite cache error on batch: $e');
        }
      }

      importedCount += batchChunk.length;
    }

    onProgress?.call(1.0, 'Import completed successfully!');
    return importedCount;
  }

  // ===========================================================================
  // 6. CSV File Downloader / Share Integration
  // ===========================================================================

  /// Prompts browser download on Web, or standard system share/save on mobile/desktop
  static Future<void> exportAndDownloadCsv({
    required String sacramentName,
    required List<Map<String, dynamic>> records,
  }) async {
    final csvContent = generateCsv(
      sacramentName: sacramentName,
      records: records,
    );

    final fileName = getExpectedFileName(sacramentName);
    final bytes = Uint8List.fromList(utf8.encode(csvContent));

    await Printing.sharePdf(
      bytes: bytes,
      filename: fileName,
    );
  }

  /// Downloads empty template CSV
  static Future<void> downloadSampleTemplate(String sacramentName) async {
    final templateContent = generateEmptyTemplate(sacramentName);
    final fileName = getExpectedFileName(sacramentName);
    final bytes = Uint8List.fromList(utf8.encode(templateContent));

    await Printing.sharePdf(
      bytes: bytes,
      filename: fileName,
    );
  }
}