// =============================================================================
// FILE: lib/features/sacramental_records/validators/sacramental_validators.dart
// =============================================================================

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/database/local_database_service.dart';
import '../../../core/services/records_sync_service.dart';

/// Canonical & Demographic Validation Utilities for Sacramental Records (Liber Ordinarius)
/// Saint John Paul II Parish - Diocese of San Pablo
class SacramentalValidators {
  SacramentalValidators._(); // Private constructor to prevent instantiation

  // ===========================================================================
  // Regex Patterns
  // ===========================================================================

  /// Allows English alphabet, Latin/Spanish diacritics (À-ÿ, Ñ, ñ),
  /// hyphens, periods, single quotes, apostrophes, and spaces.
  static final RegExp nameRegExp = RegExp(r"^[a-zA-ZÀ-ÿÑñ\s\.\-\'’]+$");

  /// Standard Philippine mobile numbers strictly 11 digits starting with 09 (e.g. 09XXXXXXXXX)
  static final RegExp phoneRegExp = RegExp(r'^09\d{9}$');

  /// Form control numbers: FCM-YYYY-XXXX
  static final RegExp communionControlNoRegExp = RegExp(r'^FCM-\d{4}-\d{4}$');

  /// Common sequential keyboard mashing sequences to detect spam and gibberish input
  static const List<String> _keyboardSequences = [
    'asdf', 'sdfg', 'dfgh', 'fghj', 'ghjk', 'hjkl',
    'qwer', 'wert', 'erty', 'rtyu', 'tyui', 'yuio', 'uiop',
    'zxcv', 'xcvb', 'cvbn', 'vbnm',
    'fdsa', 'gfds', 'hgfd', 'jhgf', 'kjhg', 'lkjh',
    'poiuy', 'oiuyt', 'iuytr', 'uytre', 'ytrew', 'trewq',
    'mnbvc', 'nbvcx', 'bvcxz',
    '1234', '2345', '3456', '4567', '5678', '6789',
    'abcd', 'bcde', 'cdef', 'defg', 'efgh', 'fghi',
  ];

  // ===========================================================================
  // Automated Live Physical Coordinate Duplicate Checker (Book, Page, Line)
  // ===========================================================================

  /// Live automated asynchronous checker for Book, Page, and Line coordinate collisions.
  /// Checks local SQLite cache (instant, offline) and Supabase (online).
  /// Returns an error prompt message if the slot is already occupied, or `null` if clear.
  static Future<String?> checkCoordinateDuplicate({
    required String tableName,
    required String bookNumber,
    required String pageNumber,
    required String lineNumber,
    String? excludeRecordId,
  }) async {
    final cleanBook = int.tryParse(bookNumber.trim())?.toString();
    final cleanPage = int.tryParse(pageNumber.trim())?.toString();
    final cleanLine = int.tryParse(lineNumber.trim())?.toString();

    if (cleanBook == null || cleanPage == null || cleanLine == null) {
      return null;
    }

    // 1. Fast local SQLite duplicate lookup (Native)
    if (!kIsWeb) {
      try {
        final db = await LocalDatabaseService.instance.database;
        if (db != null) {
          String whereClause = 'book_number = ? AND page_number = ? AND line_number = ?';
          List<dynamic> whereArgs = [cleanBook, cleanPage, cleanLine];
          if (excludeRecordId != null && excludeRecordId.isNotEmpty) {
            whereClause += ' AND record_id != ?';
            whereArgs.add(excludeRecordId);
          }
          final results = await db.query(
            tableName,
            columns: ['record_id'],
            where: whereClause,
            whereArgs: whereArgs,
            limit: 1,
          );
          if (results.isNotEmpty) {
            final dupId = results.first['record_id']?.toString() ?? 'existing entry';
            return 'Book $cleanBook, Page $cleanPage, Line $cleanLine is already occupied in records ($dupId).';
          }
        }
      } catch (_) {}
    }

    // 2. Cloud Supabase duplicate verification (Web / Online)
    final isOnline = await RecordsSyncService.instance.checkConnectivity();
    if (isOnline || kIsWeb) {
      try {
        var query = Supabase.instance.client
            .from(tableName)
            .select('record_id')
            .eq('book_number', cleanBook)
            .eq('page_number', cleanPage)
            .eq('line_number', cleanLine);

        if (excludeRecordId != null && excludeRecordId.isNotEmpty) {
          query = query.neq('record_id', excludeRecordId);
        }

        final response = await query.maybeSingle();
        if (response != null) {
          final dupId = response['record_id']?.toString() ?? 'existing entry';
          return 'Book $cleanBook, Page $cleanPage, Line $cleanLine is already occupied in records ($dupId).';
        }
      } catch (_) {}
    }

    return null;
  }

  /// Live automated duplicate checker for First Communion Control Numbers.
  static Future<String?> checkCommunionControlDuplicate({
    required int year,
    required String controlNumber,
    String? excludeRecordId,
  }) async {
    final cleanControl = controlNumber.trim();
    if (cleanControl.isEmpty) return null;

    if (!kIsWeb) {
      try {
        final db = await LocalDatabaseService.instance.database;
        if (db != null) {
          String whereClause = 'year = ? AND control_number = ?';
          List<dynamic> whereArgs = [year, cleanControl];
          if (excludeRecordId != null && excludeRecordId.isNotEmpty) {
            whereClause += ' AND record_id != ?';
            whereArgs.add(excludeRecordId);
          }
          final results = await db.query(
            'first_communion_records',
            columns: ['record_id'],
            where: whereClause,
            whereArgs: whereArgs,
            limit: 1,
          );
          if (results.isNotEmpty) {
            return 'Control Number "$cleanControl" is already assigned in Year $year.';
          }
        }
      } catch (_) {}
    }

    final isOnline = await RecordsSyncService.instance.checkConnectivity();
    if (isOnline || kIsWeb) {
      try {
        var query = Supabase.instance.client
            .from('first_communion_records')
            .select('record_id')
            .eq('year', year)
            .eq('control_number', cleanControl);

        if (excludeRecordId != null && excludeRecordId.isNotEmpty) {
          query = query.neq('record_id', excludeRecordId);
        }

        final response = await query.maybeSingle();
        if (response != null) {
          return 'Control Number "$cleanControl" is already assigned in Year $year.';
        }
      } catch (_) {}
    }

    return null;
  }

  // ===========================================================================
  // Anti-Gibberish & Pattern Detection Engine
  // ===========================================================================

  /// Inspects a string for repeating characters, pure symbols (e.g. '----------'),
  /// keyboard mash sequences, and lack of valid letters.
  static String? checkGibberishAndRepeating(String text, String fieldName, {bool allowNumericOnly = false}) {
    final clean = text.trim();
    if (clean.isEmpty) return null;

    // 1. Check for 4 or more consecutive identical characters (e.g. '----', '.....', 'aaaa')
    if (RegExp(r'(.)\1{3,}', caseSensitive: false).hasMatch(clean)) {
      return '$fieldName contains an invalid repeating character sequence.';
    }

    // 2. Reject inputs composed solely of non-alphanumeric symbols or punctuation (e.g. '---', '...', '___', '===')
    if (!RegExp(r'[a-zA-Z0-9À-ÿÑñ]').hasMatch(clean)) {
      return '$fieldName cannot consist only of symbols or punctuation.';
    }

    // 3. For alphabetic text fields (names, origins), verify that at least one letter exists
    if (!allowNumericOnly && !RegExp(r'[a-zA-ZÀ-ÿÑñ]').hasMatch(clean)) {
      return '$fieldName must contain valid letters.';
    }

    // 4. Check for keyboard mash sequence patterns
    final lower = clean.toLowerCase();
    for (final seq in _keyboardSequences) {
      if (lower.contains(seq)) {
        return '$fieldName contains an invalid sequential pattern ("$seq").';
      }
    }

    // 5. For alphabetic words with 5+ characters, ensure there is at least one vowel (rejects consonant mashing like 'bcdfghjk')
    if (!allowNumericOnly) {
      final words = clean.split(RegExp(r'[\s\-\.]+')).where((w) => w.length >= 5);
      for (final word in words) {
        if (!RegExp(r'[aeiouyAEIOUYÀ-ÿ]').hasMatch(word)) {
          return '$fieldName contains an invalid or unpronounceable word ("$word").';
        }
      }
    }

    return null;
  }

  // ===========================================================================
  // 1. Physical Ledger Coordinates (Canon 535 Bounds)
  // ===========================================================================

  /// Validates physical ledger Book Number: Integer between 1 and 200.
  static String? validateBookNumber(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Book number is required.';
    final num = int.tryParse(text);
    if (num == null) return 'Book number must be a valid number.';
    if (num < 1 || num > 200) return 'Book number must be between 1 and 200.';
    return null;
  }

  /// Validates physical ledger Page Number: Integer between 1 and 100.
  static String? validatePageNumber(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Page number is required.';
    final num = int.tryParse(text);
    if (num == null) return 'Page number must be a valid number.';
    if (num < 1 || num > 100) return 'Page number must be between 1 and 100.';
    return null;
  }

  /// Validates physical ledger Line Number: Integer between 1 and 10.
  static String? validateLineNumber(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Line number is required.';
    final num = int.tryParse(text);
    if (num == null) return 'Line number must be a valid number.';
    if (num < 1 || num > 10) return 'Line number must be between 1 and 10.';
    return null;
  }

  // ===========================================================================
  // 2. Personal & Lineage Names
  // ===========================================================================

  /// Validates personal names (First, Middle, Last names, Minister, Sponsors).
  /// Enforces alphabet + diacritics check, anti-gibberish checks, and max 50 chars.
  static String? validateName(
      String? value,
      String fieldName, {
        bool isRequired = true,
        int minLength = 2,
        int maxLength = 50,
      }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      if (isRequired) return '$fieldName is required.';
      return null;
    }

    if (text.length < minLength) {
      return '$fieldName must be at least $minLength characters.';
    }

    if (text.length > maxLength) {
      return '$fieldName cannot exceed $maxLength characters.';
    }

    if (!nameRegExp.hasMatch(text)) {
      return 'Enter a valid name (letters, hyphens, and spaces only).';
    }

    final gibberishErr = checkGibberishAndRepeating(text, fieldName);
    if (gibberishErr != null) return gibberishErr;

    return null;
  }

  /// Validates personal suffix (e.g., Jr., Sr., III). Max length 15 characters.
  static String? validateSuffix(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;

    if (text.length > 15) {
      return 'Suffix cannot exceed 15 characters.';
    }

    if (!nameRegExp.hasMatch(text)) {
      return 'Enter a valid suffix (letters, periods, and roman numerals only).';
    }

    final gibberishErr = checkGibberishAndRepeating(text, 'Suffix');
    if (gibberishErr != null) return gibberishErr;

    return null;
  }

  /// Validates generic required text fields (Addresses, Parishes, Places).
  static String? validateRequiredText(
      String? value,
      String fieldName, {
        int minLength = 2,
        int maxLength = 255,
      }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '$fieldName is required.';
    if (text.length < minLength) {
      return '$fieldName must be at least $minLength characters.';
    }
    if (text.length > maxLength) {
      return '$fieldName cannot exceed $maxLength characters.';
    }

    final gibberishErr = checkGibberishAndRepeating(text, fieldName);
    if (gibberishErr != null) return gibberishErr;

    return null;
  }

  /// Validates place fields (Place of Birth, Origins, Residences, Cemeteries, Parishes)
  /// with strict length constraints and anti-gibberish filtering.
  static String? validatePlace(
      String? value,
      String fieldName, {
        bool isRequired = true,
        int minLength = 2,
        int maxLength = 100,
      }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      if (isRequired) return '$fieldName is required.';
      return null;
    }
    if (text.length < minLength) {
      return '$fieldName must be at least $minLength characters.';
    }
    if (text.length > maxLength) {
      return '$fieldName cannot exceed $maxLength characters.';
    }

    final gibberishErr = checkGibberishAndRepeating(text, fieldName);
    if (gibberishErr != null) return gibberishErr;

    return null;
  }

  // ===========================================================================
  // 3. Contact, Demographics & Stipends
  // ===========================================================================

  /// Validates Philippine mobile contact numbers:
  /// - Must be strictly 11 digits starting with 09
  /// - Rejects all identical digits (e.g. 09999999999, 09000000000)
  /// - Allows up to 4 consecutive identical numbers (e.g. 09999087875), but rejects 5 or more (e.g. 099999XXXXX)
  static String? validatePhoneNumber(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null; // Optional unless required by caller

    final clean = text.replaceAll(RegExp(r'[\s\-]'), '');
    if (!phoneRegExp.hasMatch(clean)) {
      return 'Enter a valid 11-digit mobile number starting with 09 (e.g., 09171234567).';
    }

    // Reject 5 or more consecutive identical digits (e.g. 09999999999, 09111110000)
    if (RegExp(r'(\d)\1{4,}').hasMatch(clean)) {
      return 'Invalid mobile number: contains 5 or more consecutive identical digits.';
    }

    // Reject repeating 2-digit patterns like 09121212121
    final body = clean.substring(2); // 9 digits after 09
    if (RegExp(r'^(\d{2})\1{3,}').hasMatch(body)) {
      return 'Invalid repetitive number pattern.';
    }

    return null;
  }

  /// Validates monetary stipend / church offering (Non-negative decimal).
  static String? validateStipend(String? value, {bool allowZero = true}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null; // Blank indicates ₱0.00 / Gratis

    final amount = double.tryParse(text);
    if (amount == null) {
      return 'Enter a valid monetary amount (e.g. 150.00).';
    }

    if (!allowZero && amount <= 0) {
      return 'Stipend must be greater than 0.00.';
    }

    if (amount < 0) {
      return 'Stipend cannot be negative.';
    }

    return null;
  }

  /// Validates whole-number age (Canonically restricted between 0 and 150).
  static String? validateWholeNumberAge(String? value, {bool isRequired = true}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      if (isRequired) return 'Age is required.';
      return null;
    }

    final number = int.tryParse(text);
    if (number == null || number < 0) {
      return 'Please enter a valid whole number (e.g. 24).';
    }

    if (number > 150) {
      return 'Please enter a realistic age between 0 and 150.';
    }

    return null;
  }

  /// Validates First Communion archival reception year.
  static String? validateCommunionYear(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Communion year is required.';
    final year = int.tryParse(text);
    final currentYear = DateTime.now().year;

    if (year == null || year < 1900 || year > currentYear) {
      return 'Please enter a valid year between 1900 and $currentYear.';
    }

    return null;
  }

  /// Validates Control Number format (e.g. FCM-2026-0001).
  static String? validateCommunionControlNumber(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Control number is required.';
    if (!communionControlNoRegExp.hasMatch(text)) {
      return 'Invalid format. Expected: FCM-YYYY-XXXX (e.g. FCM-2026-0001).';
    }
    return null;
  }

  // ===========================================================================
  // 4. Chronological, Canonical Integrity & Age Computation Engine
  // ===========================================================================

  /// Validates that a date is not in the future (not past today).
  static String? validateNotFutureDate(DateTime? date, String fieldName, {bool isRequired = true}) {
    if (date == null) {
      if (isRequired) return '$fieldName is required.';
      return null;
    }

    final now = DateTime.now();
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    if (date.isAfter(todayEnd)) {
      return '$fieldName cannot be a future date.';
    }

    return null;
  }

  /// Validates Date of Birth with realism bounds (not in the future, and not older than 125 years).
  static String? validateDateOfBirth(
      DateTime? dob, {
        bool isRequired = true,
        int maxAgeYears = 125,
      }) {
    if (dob == null) {
      if (isRequired) return 'Date of Birth is required.';
      return null;
    }

    final now = DateTime.now();
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    if (dob.isAfter(todayEnd)) {
      return 'Date of Birth cannot be a future date.';
    }

    final earliestRealisticDate = DateTime(now.year - maxAgeYears, now.month, now.day);
    if (dob.isBefore(earliestRealisticDate)) {
      return 'Please enter a realistic Date of Birth (within the last $maxAgeYears years).';
    }

    return null;
  }

  /// Computes whole number age at the time of the administered sacrament:
  /// (Date of Sacrament - Date of Birth).
  static int calculateAgeInYears(DateTime birthDate, DateTime sacramentDate) {
    if (sacramentDate.isBefore(birthDate)) return 0;

    int age = sacramentDate.year - birthDate.year;
    if (sacramentDate.month < birthDate.month ||
        (sacramentDate.month == birthDate.month && sacramentDate.day < birthDate.day)) {
      age--;
    }
    return age < 0 ? 0 : age;
  }

  /// Computes a descriptive age representation (years, months, or days)
  /// specifically tailored for infant and adult Baptism records:
  /// (Date of Sacrament - Date of Birth).
  static String calculateFormattedAge(DateTime birthDate, DateTime sacramentDate) {
    if (sacramentDate.isBefore(birthDate)) return '0 days old';

    final totalDays = sacramentDate.difference(birthDate).inDays;
    final years = calculateAgeInYears(birthDate, sacramentDate);

    if (years >= 1) {
      return '$years yr(s) old';
    }

    final months = (totalDays / 30.44).floor();
    if (months >= 1) {
      return '$months mo(s) old';
    }

    return '$totalDays day(s) old';
  }

  /// Validates Date of Baptism relative to Date of Birth and today.
  static String? validateBaptismDate(DateTime? baptismDate, DateTime? dob) {
    if (baptismDate == null) return 'Date of Baptism is required.';
    final notFutureErr = validateNotFutureDate(baptismDate, 'Date of Baptism', isRequired: true);
    if (notFutureErr != null) return notFutureErr;

    if (dob != null && baptismDate.isBefore(dob)) {
      return 'Date of Baptism cannot be earlier than Date of Birth.';
    }
    return null;
  }

  /// Validates Confirmation Date relative to required prior Baptism Date and today.
  static String? validateConfirmationDate(DateTime? confirmationDate, DateTime? baptismDate) {
    if (confirmationDate == null) return 'Date of Confirmation is required.';
    final notFutureErr = validateNotFutureDate(confirmationDate, 'Date of Confirmation', isRequired: true);
    if (notFutureErr != null) return notFutureErr;

    if (baptismDate != null && confirmationDate.isBefore(baptismDate)) {
      return 'Date of Confirmation cannot be earlier than Date of Baptism.';
    }
    return null;
  }

  /// Validates First Holy Communion date relative to prior Baptism Date and today.
  static String? validateCommunionDate(DateTime? communionDate, DateTime? baptismDate) {
    if (communionDate == null) return 'Date of First Holy Communion is required.';
    final notFutureErr = validateNotFutureDate(communionDate, 'Date of First Holy Communion', isRequired: true);
    if (notFutureErr != null) return notFutureErr;

    if (baptismDate != null && communionDate.isBefore(baptismDate)) {
      return 'Date of First Communion cannot be earlier than Date of Baptism.';
    }
    return null;
  }

  /// Validates Death and Burial dates consistency and non-future bounds.
  static String? validateBurialDate(DateTime? burialDate, DateTime? deathDate) {
    if (deathDate == null) return 'Date of Death is required.';
    final notFutureDeath = validateNotFutureDate(deathDate, 'Date of Death', isRequired: true);
    if (notFutureDeath != null) return notFutureDeath;

    if (burialDate == null) return 'Date of Burial is required.';
    final notFutureBurial = validateNotFutureDate(burialDate, 'Date of Burial', isRequired: true);
    if (notFutureBurial != null) return notFutureBurial;

    if (burialDate.isBefore(deathDate)) {
      return 'Date of Burial cannot be earlier than Date of Death.';
    }
    return null;
  }

  /// Validates Reception into Full Communion (Conversion) date relative to birth date.
  static String? validateReceptionDate(DateTime? receptionDate, DateTime? dob) {
    if (receptionDate == null) return 'Date of Reception into Full Communion is required.';
    final notFutureErr = validateNotFutureDate(receptionDate, 'Date of Reception', isRequired: true);
    if (notFutureErr != null) return notFutureErr;

    if (dob != null && receptionDate.isBefore(dob)) {
      return 'Date of Reception cannot be earlier than Date of Birth.';
    }
    return null;
  }

  /// Validates prior non-Catholic baptism date relative to birth date.
  static String? validatePriorBaptismDate(DateTime? priorBaptismDate, DateTime? dob) {
    if (priorBaptismDate == null) return null; // Optional
    final notFutureErr = validateNotFutureDate(priorBaptismDate, 'Prior Baptism Date', isRequired: false);
    if (notFutureErr != null) return notFutureErr;

    if (dob != null && priorBaptismDate.isBefore(dob)) {
      return 'Prior Baptism Date cannot be earlier than Date of Birth.';
    }
    return null;
  }
}