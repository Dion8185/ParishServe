// =============================================================================
// FILE: lib/core/database/local_database_service.dart
// =============================================================================

import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint, Uint8List;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'database_factory_helper.dart';

/// Platform-Aware SQLite Local Database Manager for Offline Sacramental Records,
/// Certificate Studio, Appointments, and Mass Intentions.
/// Native (Android, Windows, iOS, Linux, macOS): Uses native/FFI SQLite.
/// Web: Attempts SQLite via WebAssembly/IndexedDB; gracefully degrades if WASM is unavailable.
class LocalDatabaseService {
  LocalDatabaseService._();
  static final LocalDatabaseService instance = LocalDatabaseService._();

  static const String _dbName = 'parishserve_records_offline.db';
  static const int _dbVersion = 5; // Bumped to v5 to ensure clean schema rebuild & data parity

  Database? _db;
  bool _isFactoryInitialized = false;
  bool _webInitFailed = false;

  /// Returns true if SQLite local database is available and initialized.
  bool get isSupported => _db != null || !kIsWeb;

  Future<Database?> get database async {
    if (_db != null && _db!.isOpen) {
      return _db!;
    }
    if (kIsWeb && _webInitFailed) {
      return null;
    }
    _db = await _initDatabase();
    return _db;
  }

  Future<Database?> _initDatabase() async {
    try {
      if (!_isFactoryInitialized) {
        initCrossPlatformDatabaseFactory();
        _isFactoryInitialized = true;
      }

      String path;
      if (kIsWeb) {
        path = _dbName;
      } else {
        final dbPath = await getDatabasesPath();
        path = p.join(dbPath, _dbName);
      }

      return await openDatabase(
        path,
        version: _dbVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    } catch (e) {
      if (kIsWeb) {
        _webInitFailed = true;
        debugPrint(
          '[LocalDatabaseService] SQLite WASM not initialized on Web ($e). '
              'Web will operate directly against Supabase.',
        );
      } else {
        debugPrint('[LocalDatabaseService] Error initializing SQLite database: $e');
      }
      return null;
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    // 1. Baptism Records (Liber Baptismorum)
    batch.execute('''
      CREATE TABLE IF NOT EXISTS baptism_records (
        record_id TEXT PRIMARY KEY,
        book_number TEXT,
        page_number TEXT,
        line_number TEXT,
        child_first_name TEXT,
        child_middle_name TEXT,
        child_last_name TEXT,
        child_suffix TEXT,
        date_of_birth TEXT,
        age TEXT,
        place_of_birth TEXT,
        gender TEXT,
        legitimacy TEXT,
        father_first_name TEXT,
        father_middle_name TEXT,
        father_last_name TEXT,
        father_place_of_birth TEXT,
        mother_first_name TEXT,
        mother_middle_name TEXT,
        mother_maiden_last_name TEXT,
        mother_place_of_birth TEXT,
        parents_contact_number TEXT,
        parents_residence TEXT,
        parents_marriage_type TEXT,
        sponsor_1_first_name TEXT,
        sponsor_1_middle_name TEXT,
        sponsor_1_last_name TEXT,
        sponsor_1_residence TEXT,
        sponsor_2_first_name TEXT,
        sponsor_2_middle_name TEXT,
        sponsor_2_last_name TEXT,
        sponsor_2_residence TEXT,
        other_godparents TEXT,
        parish_name TEXT,
        minister_first_name TEXT,
        minister_middle_name TEXT,
        minister_last_name TEXT,
        date_of_baptism TEXT,
        place_of_baptism TEXT,
        stipend REAL,
        remarks TEXT,
        scanned_image_url TEXT,
        ocr_raw_text TEXT,
        is_verified INTEGER DEFAULT 0,
        encoded_by TEXT,
        date_encoded TEXT,
        created_at TEXT,
        approved_by_priest INTEGER DEFAULT 0,
        priest_signed_at TEXT,
        canonical_notes TEXT,
        registry_date TEXT,
        entry_status TEXT DEFAULT 'ORIGINAL',
        sync_status TEXT DEFAULT 'synced',
        last_modified_at TEXT
      )
    ''');

    // 2. Confirmation Records (Liber Confirmatorum)
    batch.execute('''
      CREATE TABLE IF NOT EXISTS confirmation_records (
        record_id TEXT PRIMARY KEY,
        book_number TEXT,
        page_number TEXT,
        line_number TEXT,
        registry_date TEXT,
        entry_status TEXT DEFAULT 'ORIGINAL',
        confirmand_first_name TEXT,
        confirmand_middle_name TEXT,
        confirmand_last_name TEXT,
        confirmand_suffix TEXT,
        date_of_birth TEXT,
        age INTEGER DEFAULT 0,
        date_of_baptism TEXT,
        church_baptized TEXT,
        address TEXT,
        father_first_name TEXT,
        father_middle_name TEXT,
        father_last_name TEXT,
        father_origin TEXT,
        mother_first_name TEXT,
        mother_middle_name TEXT,
        mother_maiden_last_name TEXT,
        mother_origin TEXT,
        sponsor_1_first_name TEXT,
        sponsor_1_middle_name TEXT,
        sponsor_1_last_name TEXT,
        sponsor_1_origin_address TEXT,
        sponsor_2_first_name TEXT,
        sponsor_2_middle_name TEXT,
        sponsor_2_last_name TEXT,
        sponsor_2_origin_address TEXT,
        date_of_confirmation TEXT,
        stipend REAL DEFAULT 0.00,
        minister_first_name TEXT,
        minister_middle_name TEXT,
        minister_last_name TEXT,
        parish_name TEXT DEFAULT 'St. John Paul II Parish',
        remarks TEXT,
        scanned_image_url TEXT,
        ocr_raw_text TEXT,
        is_verified INTEGER DEFAULT 0,
        encoded_by TEXT,
        date_encoded TEXT,
        created_at TEXT,
        sync_status TEXT DEFAULT 'synced',
        last_modified_at TEXT
      )
    ''');

    // 3. First Communion Records (Liber Primae Communionis)
    batch.execute('''
      CREATE TABLE IF NOT EXISTS first_communion_records (
        record_id TEXT PRIMARY KEY,
        year INTEGER,
        control_number TEXT,
        communicant_first_name TEXT,
        communicant_middle_name TEXT,
        communicant_last_name TEXT,
        date_of_communion TEXT,
        baptism_parish TEXT,
        baptism_date TEXT,
        father_first_name TEXT,
        father_middle_name TEXT,
        father_last_name TEXT,
        mother_first_name TEXT,
        mother_middle_name TEXT,
        mother_maiden_last_name TEXT,
        minister_first_name TEXT,
        minister_middle_name TEXT,
        minister_last_name TEXT,
        remarks TEXT,
        scanned_image_url TEXT,
        is_verified INTEGER DEFAULT 0,
        encoded_by TEXT,
        created_at TEXT,
        sync_status TEXT DEFAULT 'synced',
        last_modified_at TEXT
      )
    ''');

    // 4. Matrimony Records (Liber Matrimoniorum)
    batch.execute('''
      CREATE TABLE IF NOT EXISTS matrimony_records (
        record_id TEXT PRIMARY KEY,
        book_number TEXT,
        page_number TEXT,
        line_number TEXT,
        registry_date TEXT,
        entry_status TEXT DEFAULT 'ORIGINAL',
        groom_first_name TEXT,
        groom_middle_name TEXT,
        groom_last_name TEXT,
        groom_suffix TEXT,
        groom_civil_status TEXT DEFAULT 'Single',
        groom_age INTEGER,
        groom_date_of_birth TEXT,
        groom_place_of_birth TEXT,
        groom_address TEXT,
        groom_father_first_name TEXT,
        groom_father_middle_name TEXT,
        groom_father_last_name TEXT,
        groom_mother_first_name TEXT,
        groom_mother_middle_name TEXT,
        groom_mother_maiden_last TEXT,
        bride_first_name TEXT,
        bride_middle_name TEXT,
        bride_last_name TEXT,
        bride_suffix TEXT,
        bride_civil_status TEXT DEFAULT 'Single',
        bride_age INTEGER,
        bride_date_of_birth TEXT,
        bride_place_of_birth TEXT,
        bride_address TEXT,
        bride_father_first_name TEXT,
        bride_father_middle_name TEXT,
        bride_father_last_name TEXT,
        bride_mother_first_name TEXT,
        bride_mother_middle_name TEXT,
        bride_mother_maiden_last TEXT,
        sponsor_1_first_name TEXT,
        sponsor_1_middle_name TEXT,
        sponsor_1_last_name TEXT,
        sponsor_1_origin_address TEXT,
        sponsor_2_first_name TEXT,
        sponsor_2_middle_name TEXT,
        sponsor_2_last_name TEXT,
        sponsor_2_origin_address TEXT,
        other_sponsors TEXT,
        date_of_marriage TEXT,
        marriage_type TEXT DEFAULT 'Between Catholics',
        is_filipino_foreigner INTEGER DEFAULT 0,
        marriage_license_no TEXT,
        license_date_registered TEXT,
        license_place_issued TEXT,
        solemnizer_first_name TEXT,
        solemnizer_middle_name TEXT,
        solemnizer_last_name TEXT,
        crasm_number TEXT,
        crasm_validity_date TEXT,
        stipend REAL DEFAULT 0.00,
        remarks TEXT,
        parish_name TEXT DEFAULT 'St. John Paul II Parish',
        scanned_image_url TEXT,
        ocr_raw_text TEXT,
        is_verified INTEGER DEFAULT 0,
        encoded_by TEXT,
        date_encoded TEXT,
        created_at TEXT,
        sync_status TEXT DEFAULT 'synced',
        last_modified_at TEXT
      )
    ''');

    // 5. Death Records (Liber Defunctorum)
    batch.execute('''
      CREATE TABLE IF NOT EXISTS death_records (
        record_id TEXT PRIMARY KEY,
        book_number TEXT,
        page_number TEXT,
        line_number TEXT,
        deceased_first_name TEXT,
        deceased_middle_name TEXT,
        deceased_last_name TEXT,
        deceased_suffix TEXT,
        gender TEXT,
        age TEXT,
        civil_status TEXT,
        residence TEXT,
        spouse_first_name TEXT,
        spouse_middle_name TEXT,
        spouse_last_name TEXT,
        father_first_name TEXT,
        father_middle_name TEXT,
        father_last_name TEXT,
        mother_first_name TEXT,
        mother_middle_name TEXT,
        mother_maiden_last_name TEXT,
        date_of_death TEXT,
        date_of_burial TEXT,
        place_of_burial TEXT,
        cause_of_death TEXT,
        sacraments_received INTEGER DEFAULT 1,
        sacraments_notes TEXT,
        liturgical_service TEXT DEFAULT 'Funeral Mass',
        stipend REAL DEFAULT 0.00,
        minister_first_name TEXT,
        minister_middle_name TEXT,
        minister_last_name TEXT,
        remarks TEXT,
        parish_name TEXT DEFAULT 'St. John Paul II Parish',
        scanned_image_url TEXT,
        ocr_raw_text TEXT,
        is_verified INTEGER DEFAULT 0,
        encoded_by TEXT,
        date_encoded TEXT,
        created_at TEXT,
        sync_status TEXT DEFAULT 'synced',
        last_modified_at TEXT
      )
    ''');

    // 6. Conversion Records (Liber Conversorum)
    batch.execute('''
      CREATE TABLE IF NOT EXISTS conversion_records (
        record_id TEXT PRIMARY KEY,
        book_number TEXT,
        page_number TEXT,
        line_number TEXT,
        date_of_reception TEXT,
        convert_first_name TEXT,
        convert_middle_name TEXT,
        convert_last_name TEXT,
        convert_suffix TEXT,
        date_of_birth TEXT,
        place_of_birth TEXT,
        prior_baptism_date TEXT,
        prior_baptism_church TEXT,
        prior_baptism_place TEXT,
        father_first_name TEXT,
        father_middle_name TEXT,
        father_last_name TEXT,
        father_religion TEXT,
        mother_first_name TEXT,
        mother_middle_name TEXT,
        mother_maiden_last_name TEXT,
        mother_religion TEXT,
        witness_1_first_name TEXT,
        witness_1_middle_name TEXT,
        witness_1_last_name TEXT,
        witness_2_first_name TEXT,
        witness_2_middle_name TEXT,
        witness_2_last_name TEXT,
        is_gratis INTEGER DEFAULT 1,
        stipend REAL DEFAULT 0.00,
        minister_first_name TEXT,
        minister_middle_name TEXT,
        minister_last_name TEXT,
        remarks TEXT,
        parish_name TEXT DEFAULT 'St. John Paul II Parish',
        scanned_image_url TEXT,
        ocr_raw_text TEXT,
        is_verified INTEGER DEFAULT 0,
        encoded_by TEXT,
        date_encoded TEXT,
        created_at TEXT,
        sync_status TEXT DEFAULT 'synced',
        last_modified_at TEXT
      )
    ''');

    // 7. Appointments (Parish Booking Schedule & Liturgy Desk)
    batch.execute('''
      CREATE TABLE IF NOT EXISTS appointments (
        appointment_id TEXT PRIMARY KEY,
        schedule_id TEXT,
        service_request_id TEXT,
        created_by TEXT,
        requester_name TEXT,
        contact_number TEXT,
        email TEXT,
        service_type TEXT,
        requested_date TEXT,
        requested_time TEXT,
        end_time TEXT,
        venue TEXT DEFAULT 'Main Church Altar',
        officiant_name TEXT DEFAULT 'Rev. Fr. Roy G. Reyes',
        appointment_status TEXT DEFAULT 'pending',
        appointment_remarks TEXT,
        id_type TEXT,
        id_number TEXT,
        id_document_url TEXT,
        is_id_verified INTEGER DEFAULT 0,
        id_verified_by TEXT,
        id_verified_at TEXT,
        id_verification_notes TEXT,
        reminder_24h_sent INTEGER DEFAULT 0,
        reminder_12h_sent INTEGER DEFAULT 0,
        created_at TEXT,
        updated_at TEXT,
        sync_status TEXT DEFAULT 'synced',
        last_modified_at TEXT
      )
    ''');

    // 8. Mass Intentions Registry
    batch.execute('''
      CREATE TABLE IF NOT EXISTS mass_intentions (
        intention_id TEXT PRIMARY KEY,
        created_by TEXT,
        requester_name TEXT,
        contact_number TEXT,
        email TEXT,
        scheduled_date TEXT,
        mass_time TEXT,
        thanksgiving_list TEXT,
        repose_souls_list TEXT,
        special_intentions_list TEXT,
        other_intentions TEXT,
        stipend_amount REAL DEFAULT 0.0,
        payment_method TEXT DEFAULT 'GCash',
        payment_status TEXT DEFAULT 'pending',
        gcash_reference_no TEXT,
        intention_status TEXT DEFAULT 'pending',
        remarks TEXT,
        created_at TEXT,
        updated_at TEXT,
        sync_status TEXT DEFAULT 'synced',
        last_modified_at TEXT
      )
    ''');

    // 9. Certificate Templates
    batch.execute('''
      CREATE TABLE IF NOT EXISTS certificate_templates (
        template_id TEXT PRIMARY KEY,
        sacrament_type TEXT,
        template_name TEXT,
        certificate_title TEXT DEFAULT 'CERTIFICATE OF SACRAMENT',
        header_text TEXT,
        body_wording TEXT,
        default_purpose TEXT DEFAULT 'For Legal / Personal Records',
        paper_size TEXT DEFAULT 'A4',
        orientation TEXT DEFAULT 'Portrait',
        background_image_url TEXT,
        background_mode TEXT DEFAULT 'Border',
        signatory_name TEXT,
        signatory_title TEXT,
        signature_image_url TEXT,
        show_parish_seal INTEGER DEFAULT 1,
        show_diocese_logo INTEGER DEFAULT 1,
        diocese_logo_url TEXT,
        parish_seal_url TEXT,
        enable_qr_verification INTEGER DEFAULT 1,
        is_active INTEGER DEFAULT 1,
        is_default INTEGER DEFAULT 0,
        version INTEGER DEFAULT 1,
        created_by TEXT,
        created_at TEXT,
        updated_at TEXT,
        style_config TEXT,
        sync_status TEXT DEFAULT 'synced',
        last_modified_at TEXT
      )
    ''');

    // 10. Certificate Issuances
    batch.execute('''
      CREATE TABLE IF NOT EXISTS certificate_issuances (
        issuance_id TEXT PRIMARY KEY,
        verification_id TEXT,
        record_id TEXT,
        sacrament_type TEXT,
        recipient_name TEXT,
        purpose TEXT,
        template_id TEXT,
        template_version INTEGER DEFAULT 1,
        rendered_wording TEXT,
        signatory_name TEXT,
        signatory_title TEXT,
        book_number TEXT,
        page_number TEXT,
        line_number TEXT,
        registry_reference TEXT,
        qr_verification_url TEXT,
        pdf_storage_path TEXT,
        certificate_status TEXT DEFAULT 'Valid',
        revocation_reason TEXT,
        revoked_at TEXT,
        revoked_by TEXT,
        issued_by TEXT,
        issued_at TEXT,
        created_at TEXT,
        transaction_id TEXT,
        receipt_number TEXT,
        sync_status TEXT DEFAULT 'synced',
        last_modified_at TEXT
      )
    ''');

    // 11. Global Parish Certificate Settings
    batch.execute('''
      CREATE TABLE IF NOT EXISTS parish_certificate_settings (
        id TEXT PRIMARY KEY DEFAULT 'global',
        diocese_name TEXT DEFAULT 'Diocese of San Pablo',
        parish_name TEXT DEFAULT 'Saint John Paul II Parish',
        location_text TEXT DEFAULT 'Santa Cruz, Laguna',
        diocese_logo_url TEXT,
        parish_seal_url TEXT,
        show_diocese_logo INTEGER DEFAULT 1,
        show_parish_seal INTEGER DEFAULT 1,
        updated_at TEXT,
        sync_status TEXT DEFAULT 'synced',
        last_modified_at TEXT
      )
    ''');

    // 12. Sync Queue
    batch.execute('''
      CREATE TABLE IF NOT EXISTS sync_queue (
        queue_id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT,
        record_id TEXT,
        operation TEXT,
        payload TEXT,
        queued_at TEXT,
        attempts INTEGER DEFAULT 0,
        last_error TEXT,
        status TEXT DEFAULT 'pending'
      )
    ''');

    // 13. Sync Metadata
    batch.execute('''
      CREATE TABLE IF NOT EXISTS app_sync_metadata (
        key TEXT PRIMARY KEY,
        value TEXT,
        updated_at TEXT
      )
    ''');

    // 14. Offline Binary Asset Cache
    batch.execute('''
      CREATE TABLE IF NOT EXISTS offline_asset_cache (
        asset_key TEXT PRIMARY KEY,
        asset_type TEXT,
        file_bytes BLOB,
        mime_type TEXT,
        updated_at TEXT
      )
    ''');

    await batch.commit();
    debugPrint('[LocalDatabaseService] SQLite offline schema v$version created.');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('[LocalDatabaseService] Migrating database from v$oldVersion to v$newVersion');
    if (oldVersion < 5) {
      final tables = [
        'baptism_records',
        'confirmation_records',
        'first_communion_records',
        'matrimony_records',
        'death_records',
        'conversion_records',
        'appointments',
        'mass_intentions',
        'certificate_templates',
        'certificate_issuances',
        'parish_certificate_settings',
        'sync_queue',
        'app_sync_metadata',
        'offline_asset_cache',
      ];
      final batch = db.batch();
      for (final t in tables) {
        batch.execute('DROP TABLE IF EXISTS $t');
      }
      await batch.commit();
    }
    await _onCreate(db, newVersion);
  }

  Future<void> cacheAsset(
      String key,
      String type,
      Uint8List bytes, {
        String? mimeType,
      }) async {
    try {
      final db = await database;
      if (db == null) return;
      await db.insert(
        'offline_asset_cache',
        {
          'asset_key': key.trim(),
          'asset_type': type,
          'file_bytes': bytes,
          'mime_type': mimeType,
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('[LocalDatabaseService] Error caching asset ($key): $e');
    }
  }

  Future<Uint8List?> getCachedAsset(String key) async {
    try {
      final db = await database;
      if (db == null) return null;
      final rows = await db.query(
        'offline_asset_cache',
        columns: ['file_bytes'],
        where: 'asset_key = ?',
        whereArgs: [key.trim()],
        limit: 1,
      );

      if (rows.isNotEmpty) {
        return rows.first['file_bytes'] as Uint8List?;
      }
    } catch (e) {
      debugPrint('[LocalDatabaseService] Error retrieving cached asset ($key): $e');
    }
    return null;
  }

  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }

  Future<void> clearAllData() async {
    final db = await database;
    if (db == null) return;
    final tables = [
      'baptism_records',
      'confirmation_records',
      'first_communion_records',
      'matrimony_records',
      'death_records',
      'conversion_records',
      'appointments',
      'mass_intentions',
      'certificate_templates',
      'certificate_issuances',
      'parish_certificate_settings',
      'sync_queue',
      'app_sync_metadata',
      'offline_asset_cache',
    ];

    final batch = db.batch();
    for (final table in tables) {
      batch.delete(table);
    }
    await batch.commit();
  }
}