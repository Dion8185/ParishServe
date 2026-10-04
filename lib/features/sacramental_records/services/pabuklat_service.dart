// =============================================================================
// FILE: lib/features/sacramental_records/services/pabuklat_service.dart
// =============================================================================

import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/notification_service.dart';
import '../../auth/services/auth_service.dart';

class SacramentMatchResult {
  final String recordId;
  final String sacramentType;
  final String recipientName;
  final String dateOfSacrament;
  final int matchScore;
  final Map<String, dynamic> rawData;

  const SacramentMatchResult({
    required this.recordId,
    required this.sacramentType,
    required this.recipientName,
    required this.dateOfSacrament,
    required this.matchScore,
    required this.rawData,
  });
}

/// In-memory rate limiter to prevent dictionary attacks and automated enumeration of canonical books.
class PabuklatRateLimiter {
  static final Map<String, List<DateTime>> _searchAttempts = {};
  static const int maxAttemptsPerMinute = 5;
  static const Duration windowDuration = Duration(minutes: 1);
  static const Duration cooldownDuration = Duration(seconds: 45);

  static int getRemainingCooldownSeconds(String identifier) {
    final now = DateTime.now();
    final attempts = _searchAttempts[identifier] ?? [];
    if (attempts.isEmpty) return 0;

    final recent = attempts.where((t) => now.difference(t) < windowDuration).toList();
    _searchAttempts[identifier] = recent;

    if (recent.length >= maxAttemptsPerMinute) {
      final oldestInWindow = recent.first;
      final elapsed = now.difference(oldestInWindow);
      final remaining = windowDuration.inSeconds - elapsed.inSeconds;
      return remaining > 0 ? remaining : 0;
    }
    return 0;
  }

  static void recordSearchAttempt(String identifier) {
    final cooldown = getRemainingCooldownSeconds(identifier);
    if (cooldown > 0) {
      throw 'Search rate limit exceeded. Please wait $cooldown second(s) before attempting another record search.';
    }

    final history = _searchAttempts.putIfAbsent(identifier, () => []);
    history.add(DateTime.now());
  }

  static void reset(String identifier) {
    _searchAttempts.remove(identifier);
  }
}

class PabuklatService {
  static final SupabaseClient _client = Supabase.instance.client;

  static const List<String> _keyboardSequences = [
    'asdf', 'sdfg', 'dfgh', 'fghj', 'ghjk', 'hjkl',
    'qwer', 'wert', 'erty', 'rtyu', 'tyui', 'yuio', 'uiop',
    'zxcv', 'xcvb', 'cvbn', 'vbnm',
    'fdsa', 'gfds', 'hgfd', 'jhgf', 'kjhg', 'lkjh',
  ];

  /// Validates search input strings against enumeration scripts, SQL patterns, and spam.
  static String? validateSearchString(String? text, String label, {int min = 2, int max = 60, bool isRequired = false}) {
    if (text == null || text.trim().isEmpty) {
      if (isRequired) return '$label is required.';
      return null;
    }

    final clean = text.trim();

    if (clean.length < min) {
      return '$label must be at least $min characters.';
    }
    if (clean.length > max) {
      return '$label cannot exceed $max characters.';
    }

    // Reject SQL/Script special characters
    if (RegExp(r'''[<>{};'"%\\]''').hasMatch(clean)) {
      return '$label contains invalid special characters.';
    }

    // Reject 3+ repetitive characters (e.g. aaaaa, bbb)
    if (RegExp(r'(.)\1{2,}', caseSensitive: false).hasMatch(clean)) {
      return '$label contains an invalid repetitive character sequence.';
    }

    final lower = clean.toLowerCase();
    for (final seq in _keyboardSequences) {
      if (lower.contains(seq)) {
        return '$label cannot contain keyboard sequence "$seq".';
      }
    }

    return null;
  }

  // ===========================================================================
  // 1. Accurate Database Record Matching (Strictly >= 2 Criteria Match)
  // ===========================================================================

  static Future<SacramentMatchResult?> findMatchingRecord({
    required String sacramentType,
    String? recipientFullName,
    String? motherFirstName,
    String? motherMiddleName,
    String? motherLastName,
    String? fatherFirstName,
    String? fatherMiddleName,
    String? fatherLastName,
    DateTime? birthDate,
    DateTime? sacramentDate,
    String? brideFullName,
    DateTime? brideBirthDate,
    String? brideMotherFirstName,
    String? brideMotherMiddleName,
    String? brideMotherLastName,
    String? brideFatherFirstName,
    String? brideFatherMiddleName,
    String? brideFatherLastName,
    String? groomFullName,
    DateTime? groomBirthDate,
    String? groomMotherFirstName,
    String? groomMotherMiddleName,
    String? groomMotherLastName,
    String? groomFatherFirstName,
    String? groomFatherMiddleName,
    String? groomFatherLastName,
    DateTime? marriageDate,
  }) async {
    final userKey = AuthService.currentUser?.userId ?? 'anonymous_client';
    PabuklatRateLimiter.recordSearchAttempt(userKey);

    final err1 = validateSearchString(recipientFullName, 'Recipient Name', min: 2, max: 80);
    if (err1 != null) throw err1;

    final err2 = validateSearchString(groomFullName, 'Groom Name', min: 2, max: 80);
    if (err2 != null) throw err2;

    final err3 = validateSearchString(brideFullName, 'Bride Name', min: 2, max: 80);
    if (err3 != null) throw err3;

    purgeExpiredRequestIds();

    try {
      if (sacramentType == 'Baptism') {
        return await _matchBaptismRecord(
          recipientFullName: recipientFullName,
          motherFirstName: motherFirstName,
          motherMiddleName: motherMiddleName,
          motherLastName: motherLastName,
          fatherFirstName: fatherFirstName,
          fatherMiddleName: fatherMiddleName,
          fatherLastName: fatherLastName,
          birthDate: birthDate,
          sacramentDate: sacramentDate,
        );
      } else if (sacramentType == 'Confirmation') {
        return await _matchConfirmationRecord(
          recipientFullName: recipientFullName,
          motherFirstName: motherFirstName,
          motherMiddleName: motherMiddleName,
          motherLastName: motherLastName,
          fatherFirstName: fatherFirstName,
          fatherMiddleName: fatherMiddleName,
          fatherLastName: fatherLastName,
          birthDate: birthDate,
          sacramentDate: sacramentDate,
        );
      } else if (sacramentType == 'Matrimony') {
        return await _matchMatrimonyRecord(
          brideFullName: brideFullName,
          brideBirthDate: brideBirthDate,
          brideMotherFirstName: brideMotherFirstName,
          brideMotherMiddleName: brideMotherMiddleName,
          brideMotherLastName: brideMotherLastName,
          brideFatherFirstName: brideFatherFirstName,
          brideFatherMiddleName: brideFatherMiddleName,
          brideFatherLastName: brideFatherLastName,
          groomFullName: groomFullName,
          groomBirthDate: groomBirthDate,
          groomMotherFirstName: groomMotherFirstName,
          groomMotherMiddleName: groomMotherMiddleName,
          groomMotherLastName: groomMotherLastName,
          groomFatherFirstName: groomFatherFirstName,
          groomFatherMiddleName: groomFatherMiddleName,
          groomFatherLastName: groomFatherLastName,
          marriageDate: marriageDate ?? sacramentDate,
        );
      } else if (sacramentType == 'Death') {
        return await _matchDeathRecord(
          deceasedFullName: recipientFullName,
          motherFirstName: motherFirstName,
          motherLastName: motherLastName,
          fatherFirstName: fatherFirstName,
          fatherLastName: fatherLastName,
          burialOrDeathDate: sacramentDate,
        );
      } else if (sacramentType == 'First Communion') {
        return await _matchFirstCommunionRecord(
          communicantFullName: recipientFullName,
          motherFirstName: motherFirstName,
          motherLastName: motherLastName,
          fatherFirstName: fatherFirstName,
          fatherLastName: fatherLastName,
          communionDate: sacramentDate,
        );
      } else if (sacramentType == 'Conversion') {
        return await _matchConversionRecord(
          convertFullName: recipientFullName,
          motherFirstName: motherFirstName,
          motherLastName: motherLastName,
          fatherFirstName: fatherFirstName,
          fatherLastName: fatherLastName,
          birthDate: birthDate,
          receptionDate: sacramentDate,
        );
      }
    } catch (e) {
      debugPrint('[PabuklatService] Record matching query notice: $e');
    }

    return null;
  }

  static Future<SacramentMatchResult?> _matchBaptismRecord({
    String? recipientFullName,
    String? motherFirstName,
    String? motherMiddleName,
    String? motherLastName,
    String? fatherFirstName,
    String? fatherMiddleName,
    String? fatherLastName,
    DateTime? birthDate,
    DateTime? sacramentDate,
  }) async {
    final response = await _client.from('baptism_records').select().limit(100);
    final rows = response as List;

    SacramentMatchResult? bestMatch;
    int highestScore = 0;

    for (final r in rows) {
      int score = 0;

      final storedFirst = (r['child_first_name'] ?? '').toString().trim().toLowerCase();
      final storedLast = (r['child_last_name'] ?? '').toString().trim().toLowerCase();
      final storedFull = '$storedFirst $storedLast'.trim();

      final storedFatFirst = (r['father_first_name'] ?? '').toString().trim().toLowerCase();
      final storedFatLast = (r['father_last_name'] ?? '').toString().trim().toLowerCase();

      final storedMotFirst = (r['mother_first_name'] ?? '').toString().trim().toLowerCase();
      final storedMotLast = (r['mother_maiden_last_name'] ?? '').toString().trim().toLowerCase();

      final storedDob = r['date_of_birth']?.toString();
      final storedDap = r['date_of_baptism']?.toString();

      if (recipientFullName != null && recipientFullName.trim().isNotEmpty) {
        final queryFull = recipientFullName.trim().toLowerCase();
        if (storedFull == queryFull ||
            (storedFirst.isNotEmpty && queryFull.contains(storedFirst)) &&
                (storedLast.isNotEmpty && queryFull.contains(storedLast))) {
          score++;
        }
      }

      if (birthDate != null && storedDob != null) {
        final dobStr = birthDate.toIso8601String().substring(0, 10);
        if (storedDob.startsWith(dobStr)) score++;
      }

      if (sacramentDate != null && storedDap != null) {
        final dapStr = sacramentDate.toIso8601String().substring(0, 10);
        if (storedDap.startsWith(dapStr)) score++;
      }

      if (fatherLastName != null && fatherLastName.trim().isNotEmpty) {
        final fLast = fatherLastName.trim().toLowerCase();
        if (storedFatLast.isNotEmpty && storedFatLast == fLast) {
          score++;
        } else if (fatherFirstName != null &&
            fatherFirstName.trim().isNotEmpty &&
            storedFatFirst.isNotEmpty &&
            storedFatFirst == fatherFirstName.trim().toLowerCase()) {
          score++;
        }
      }

      if (motherLastName != null && motherLastName.trim().isNotEmpty) {
        final mLast = motherLastName.trim().toLowerCase();
        if (storedMotLast.isNotEmpty && storedMotLast == mLast) {
          score++;
        } else if (motherFirstName != null &&
            motherFirstName.trim().isNotEmpty &&
            storedMotFirst.isNotEmpty &&
            storedMotFirst == motherFirstName.trim().toLowerCase()) {
          score++;
        }
      }

      if (score >= 2 && score > highestScore) {
        highestScore = score;
        bestMatch = SacramentMatchResult(
          recordId: r['record_id'] ?? '',
          sacramentType: 'Baptism',
          recipientName: '${r['child_first_name'] ?? ''} ${r['child_last_name'] ?? ''}'.trim(),
          dateOfSacrament: r['date_of_baptism']?.toString() ?? '',
          matchScore: score,
          rawData: Map<String, dynamic>.from(r),
        );
      }
    }

    return bestMatch;
  }

  static Future<SacramentMatchResult?> _matchConfirmationRecord({
    String? recipientFullName,
    String? motherFirstName,
    String? motherMiddleName,
    String? motherLastName,
    String? fatherFirstName,
    String? fatherMiddleName,
    String? fatherLastName,
    DateTime? birthDate,
    DateTime? sacramentDate,
  }) async {
    final response = await _client.from('confirmation_records').select().limit(100);
    final rows = response as List;

    SacramentMatchResult? bestMatch;
    int highestScore = 0;

    for (final r in rows) {
      int score = 0;

      final storedFirst = (r['confirmand_first_name'] ?? '').toString().trim().toLowerCase();
      final storedLast = (r['confirmand_last_name'] ?? '').toString().trim().toLowerCase();
      final storedFull = '$storedFirst $storedLast'.trim();

      final storedFatLast = (r['father_last_name'] ?? '').toString().trim().toLowerCase();
      final storedMotLast = (r['mother_maiden_last_name'] ?? '').toString().trim().toLowerCase();
      final storedDob = r['date_of_birth']?.toString();
      final storedDoc = r['date_of_confirmation']?.toString();

      if (recipientFullName != null && recipientFullName.trim().isNotEmpty) {
        final queryFull = recipientFullName.trim().toLowerCase();
        if (storedFull == queryFull ||
            (storedFirst.isNotEmpty && queryFull.contains(storedFirst)) &&
                (storedLast.isNotEmpty && queryFull.contains(storedLast))) {
          score++;
        }
      }

      if (birthDate != null && storedDob != null) {
        final dobStr = birthDate.toIso8601String().substring(0, 10);
        if (storedDob.startsWith(dobStr)) score++;
      }

      if (sacramentDate != null && storedDoc != null) {
        final docStr = sacramentDate.toIso8601String().substring(0, 10);
        if (storedDoc.startsWith(docStr)) score++;
      }

      if (fatherLastName != null && fatherLastName.trim().isNotEmpty && storedFatLast.isNotEmpty) {
        if (storedFatLast == fatherLastName.trim().toLowerCase()) score++;
      }

      if (motherLastName != null && motherLastName.trim().isNotEmpty && storedMotLast.isNotEmpty) {
        if (storedMotLast == motherLastName.trim().toLowerCase()) score++;
      }

      if (score >= 2 && score > highestScore) {
        highestScore = score;
        bestMatch = SacramentMatchResult(
          recordId: r['record_id'] ?? '',
          sacramentType: 'Confirmation',
          recipientName: '${r['confirmand_first_name'] ?? ''} ${r['confirmand_last_name'] ?? ''}'.trim(),
          dateOfSacrament: r['date_of_confirmation']?.toString() ?? '',
          matchScore: score,
          rawData: Map<String, dynamic>.from(r),
        );
      }
    }

    return bestMatch;
  }

  static Future<SacramentMatchResult?> _matchMatrimonyRecord({
    String? brideFullName,
    DateTime? brideBirthDate,
    String? brideMotherFirstName,
    String? brideMotherMiddleName,
    String? brideMotherLastName,
    String? brideFatherFirstName,
    String? brideFatherMiddleName,
    String? brideFatherLastName,
    String? groomFullName,
    DateTime? groomBirthDate,
    String? groomMotherFirstName,
    String? groomMotherMiddleName,
    String? groomMotherLastName,
    String? groomFatherFirstName,
    String? groomFatherMiddleName,
    String? groomFatherLastName,
    DateTime? marriageDate,
  }) async {
    final response = await _client.from('matrimony_records').select().limit(100);
    final rows = response as List;

    SacramentMatchResult? bestMatch;
    int highestScore = 0;

    for (final r in rows) {
      int score = 0;

      final storedGroomFirst = (r['groom_first_name'] ?? '').toString().trim().toLowerCase();
      final storedGroomLast = (r['groom_last_name'] ?? '').toString().trim().toLowerCase();
      final storedGroomFull = '$storedGroomFirst $storedGroomLast'.trim();

      final storedBrideFirst = (r['bride_first_name'] ?? '').toString().trim().toLowerCase();
      final storedBrideLast = (r['bride_last_name'] ?? '').toString().trim().toLowerCase();
      final storedBrideFull = '$storedBrideFirst $storedBrideLast'.trim();

      final storedGroomDob = r['groom_date_of_birth']?.toString();
      final storedBrideDob = r['bride_date_of_birth']?.toString();
      final storedDom = r['date_of_marriage']?.toString();

      final storedGroomFatherLast = (r['groom_father_last_name'] ?? '').toString().trim().toLowerCase();
      final storedBrideFatherLast = (r['bride_father_last_name'] ?? '').toString().trim().toLowerCase();

      if (groomFullName != null && groomFullName.trim().isNotEmpty) {
        final gQuery = groomFullName.trim().toLowerCase();
        if (storedGroomFull == gQuery ||
            (storedGroomFirst.isNotEmpty && gQuery.contains(storedGroomFirst) &&
                storedGroomLast.isNotEmpty && gQuery.contains(storedGroomLast))) {
          score++;
        }
      }

      if (brideFullName != null && brideFullName.trim().isNotEmpty) {
        final bQuery = brideFullName.trim().toLowerCase();
        if (storedBrideFull == bQuery ||
            (storedBrideFirst.isNotEmpty && bQuery.contains(storedBrideFirst) &&
                storedBrideLast.isNotEmpty && bQuery.contains(storedBrideLast))) {
          score++;
        }
      }

      if (marriageDate != null && storedDom != null) {
        final domStr = marriageDate.toIso8601String().substring(0, 10);
        if (storedDom.startsWith(domStr)) score++;
      }

      if (groomBirthDate != null && storedGroomDob != null) {
        if (storedGroomDob.startsWith(groomBirthDate.toIso8601String().substring(0, 10))) score++;
      }

      if (brideBirthDate != null && storedBrideDob != null) {
        if (storedBrideDob.startsWith(brideBirthDate.toIso8601String().substring(0, 10))) score++;
      }

      if (groomFatherLastName != null && groomFatherLastName.trim().isNotEmpty && storedGroomFatherLast.isNotEmpty) {
        if (storedGroomFatherLast == groomFatherLastName.trim().toLowerCase()) score++;
      }

      if (brideFatherLastName != null && brideFatherLastName.trim().isNotEmpty && storedBrideFatherLast.isNotEmpty) {
        if (storedBrideFatherLast == brideFatherLastName.trim().toLowerCase()) score++;
      }

      if (score >= 2 && score > highestScore) {
        highestScore = score;
        final coupleNames = '${r['groom_first_name'] ?? ''} ${r['groom_last_name'] ?? ''} & ${r['bride_first_name'] ?? ''} ${r['bride_last_name'] ?? ''}'.trim();
        bestMatch = SacramentMatchResult(
          recordId: r['record_id'] ?? '',
          sacramentType: 'Matrimony',
          recipientName: coupleNames,
          dateOfSacrament: r['date_of_marriage']?.toString() ?? '',
          matchScore: score,
          rawData: Map<String, dynamic>.from(r),
        );
      }
    }

    return bestMatch;
  }

  static Future<SacramentMatchResult?> _matchDeathRecord({
    String? deceasedFullName,
    String? motherFirstName,
    String? motherLastName,
    String? fatherFirstName,
    String? fatherLastName,
    DateTime? burialOrDeathDate,
  }) async {
    final response = await _client.from('death_records').select().limit(100);
    final rows = response as List;

    SacramentMatchResult? bestMatch;
    int highestScore = 0;

    for (final r in rows) {
      int score = 0;
      final storedFirst = (r['deceased_first_name'] ?? '').toString().trim().toLowerCase();
      final storedLast = (r['deceased_last_name'] ?? '').toString().trim().toLowerCase();
      final storedFull = '$storedFirst $storedLast'.trim();
      final storedDod = r['date_of_death']?.toString();
      final storedDoburial = r['date_of_burial']?.toString();

      if (deceasedFullName != null && deceasedFullName.trim().isNotEmpty) {
        final queryFull = deceasedFullName.trim().toLowerCase();
        if (storedFull == queryFull ||
            (storedFirst.isNotEmpty && queryFull.contains(storedFirst)) &&
                (storedLast.isNotEmpty && queryFull.contains(storedLast))) {
          score++;
        }
      }

      if (burialOrDeathDate != null) {
        final dStr = burialOrDeathDate.toIso8601String().substring(0, 10);
        if ((storedDod != null && storedDod.startsWith(dStr)) ||
            (storedDoburial != null && storedDoburial.startsWith(dStr))) {
          score++;
        }
      }

      if (fatherLastName != null && fatherLastName.trim().isNotEmpty) {
        final sFatLast = (r['father_last_name'] ?? '').toString().trim().toLowerCase();
        if (sFatLast == fatherLastName.trim().toLowerCase()) score++;
      }

      if (motherLastName != null && motherLastName.trim().isNotEmpty) {
        final sMotLast = (r['mother_maiden_last_name'] ?? '').toString().trim().toLowerCase();
        if (sMotLast == motherLastName.trim().toLowerCase()) score++;
      }

      if (score >= 2 && score > highestScore) {
        highestScore = score;
        bestMatch = SacramentMatchResult(
          recordId: r['record_id'] ?? '',
          sacramentType: 'Death',
          recipientName: '${r['deceased_first_name'] ?? ''} ${r['deceased_last_name'] ?? ''}'.trim(),
          dateOfSacrament: r['date_of_death']?.toString() ?? r['date_of_burial']?.toString() ?? '',
          matchScore: score,
          rawData: Map<String, dynamic>.from(r),
        );
      }
    }

    return bestMatch;
  }

  static Future<SacramentMatchResult?> _matchFirstCommunionRecord({
    String? communicantFullName,
    String? motherFirstName,
    String? motherLastName,
    String? fatherFirstName,
    String? fatherLastName,
    DateTime? communionDate,
  }) async {
    final response = await _client.from('first_communion_records').select().limit(100);
    final rows = response as List;

    SacramentMatchResult? bestMatch;
    int highestScore = 0;

    for (final r in rows) {
      int score = 0;
      final storedFirst = (r['communicant_first_name'] ?? '').toString().trim().toLowerCase();
      final storedLast = (r['communicant_last_name'] ?? '').toString().trim().toLowerCase();
      final storedFull = '$storedFirst $storedLast'.trim();
      final storedDoc = r['date_of_communion']?.toString();

      if (communicantFullName != null && communicantFullName.trim().isNotEmpty) {
        final queryFull = communicantFullName.trim().toLowerCase();
        if (storedFull == queryFull ||
            (storedFirst.isNotEmpty && queryFull.contains(storedFirst)) &&
                (storedLast.isNotEmpty && queryFull.contains(storedLast))) {
          score++;
        }
      }

      if (communionDate != null && storedDoc != null) {
        if (storedDoc.startsWith(communionDate.toIso8601String().substring(0, 10))) score++;
      }

      if (fatherLastName != null && fatherLastName.trim().isNotEmpty) {
        final sFatLast = (r['father_last_name'] ?? '').toString().trim().toLowerCase();
        if (sFatLast == fatherLastName.trim().toLowerCase()) score++;
      }

      if (motherLastName != null && motherLastName.trim().isNotEmpty) {
        final sMotLast = (r['mother_maiden_last_name'] ?? '').toString().trim().toLowerCase();
        if (sMotLast == motherLastName.trim().toLowerCase()) score++;
      }

      if (score >= 2 && score > highestScore) {
        highestScore = score;
        bestMatch = SacramentMatchResult(
          recordId: r['record_id'] ?? '',
          sacramentType: 'First Communion',
          recipientName: '${r['communicant_first_name'] ?? ''} ${r['communicant_last_name'] ?? ''}'.trim(),
          dateOfSacrament: r['date_of_communion']?.toString() ?? '',
          matchScore: score,
          rawData: Map<String, dynamic>.from(r),
        );
      }
    }

    return bestMatch;
  }

  static Future<SacramentMatchResult?> _matchConversionRecord({
    String? convertFullName,
    String? motherFirstName,
    String? motherLastName,
    String? fatherFirstName,
    String? fatherLastName,
    DateTime? birthDate,
    DateTime? receptionDate,
  }) async {
    final response = await _client.from('conversion_records').select().limit(100);
    final rows = response as List;

    SacramentMatchResult? bestMatch;
    int highestScore = 0;

    for (final r in rows) {
      int score = 0;
      final storedFirst = (r['convert_first_name'] ?? '').toString().trim().toLowerCase();
      final storedLast = (r['convert_last_name'] ?? '').toString().trim().toLowerCase();
      final storedFull = '$storedFirst $storedLast'.trim();
      final storedDob = r['date_of_birth']?.toString();
      final storedDor = r['date_of_reception']?.toString();

      if (convertFullName != null && convertFullName.trim().isNotEmpty) {
        final queryFull = convertFullName.trim().toLowerCase();
        if (storedFull == queryFull ||
            (storedFirst.isNotEmpty && queryFull.contains(storedFirst)) &&
                (storedLast.isNotEmpty && queryFull.contains(storedLast))) {
          score++;
        }
      }

      if (birthDate != null && storedDob != null) {
        if (storedDob.startsWith(birthDate.toIso8601String().substring(0, 10))) score++;
      }

      if (receptionDate != null && storedDor != null) {
        if (storedDor.startsWith(receptionDate.toIso8601String().substring(0, 10))) score++;
      }

      if (score >= 2 && score > highestScore) {
        highestScore = score;
        bestMatch = SacramentMatchResult(
          recordId: r['record_id'] ?? '',
          sacramentType: 'Conversion',
          recipientName: '${r['convert_first_name'] ?? ''} ${r['convert_last_name'] ?? ''}'.trim(),
          dateOfSacrament: r['date_of_reception']?.toString() ?? '',
          matchScore: score,
          rawData: Map<String, dynamic>.from(r),
        );
      }
    }

    return bestMatch;
  }

  // ===========================================================================
  // 2. Requestor ID Upload & Verification Storage
  // ===========================================================================

  static Future<String?> uploadRequestorIdDocument({
    required String requestId,
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    try {
      final cleanExt = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : 'jpg';
      final storagePath = 'pabuklat_verification_ids/$requestId/id_${DateTime.now().millisecondsSinceEpoch}.$cleanExt';

      await _client.storage.from('appointment-documents').uploadBinary(
        storagePath,
        fileBytes,
        fileOptions: FileOptions(
          contentType: cleanExt == 'pdf' ? 'application/pdf' : 'image/$cleanExt',
          upsert: true,
        ),
      );

      return storagePath;
    } catch (e) {
      debugPrint('[PabuklatService] Error uploading ID document: $e');
      return null;
    }
  }

  static Future<String?> getSignedIdUrl(String filePath) async {
    try {
      var cleanPath = filePath.trim();
      if (cleanPath.startsWith('http://') || cleanPath.startsWith('https://')) {
        return cleanPath;
      }
      if (cleanPath.startsWith('/')) cleanPath = cleanPath.substring(1);
      if (cleanPath.startsWith('appointment-documents/')) {
        cleanPath = cleanPath.replaceFirst('appointment-documents/', '');
      }

      return await _client.storage.from('appointment-documents').createSignedUrl(cleanPath, 60 * 30);
    } catch (e) {
      debugPrint('[PabuklatService] Signed ID URL error: $e');
      return null;
    }
  }

  // ===========================================================================
  // 3. Request Submission & Instant Secretary Push Notification
  // ===========================================================================

  static Future<void> submitPabuklatRequest({
    required String sacramentType,
    required String recordId,
    required String requesterFullName,
    required String relationshipToRecipient,
    required String contactNumber,
    required String purpose,
    String? idDocumentUrl,
  }) async {
    final user = AuthService.currentUser;
    final requestId = 'REQ-${DateTime.now().millisecondsSinceEpoch}';

    final payload = {
      'service_request_id': requestId,
      'requester_name': requesterFullName.trim(),
      'contact_number': contactNumber.trim(),
      'email': user?.email,
      'service_type': 'Pabuklat / $sacramentType Certificate',
      'sacrament_type': sacramentType,
      'record_id': recordId,
      'relationship_to_recipient': relationshipToRecipient.trim(),
      'id_document_url': idDocumentUrl,
      'service_request_details': purpose.trim(),
      'request_status': 'submitted',
      'signature_method': 'physical',
      'signature_status': 'pending',
      'created_by': user?.userId,
      'created_at': DateTime.now().toIso8601String(),
    };

    await _client.from('service_requests').insert(payload);

    final notificationTitle = 'New Pabuklat Request ($sacramentType)';
    final notificationMessage = '$requesterFullName requested an official $sacramentType certificate ($relationshipToRecipient). Secretary review required.';
    final notificationData = {
      'type': 'pabuklat_request',
      'notification_type': 'pabuklat_request',
      'reference_id': requestId,
      'service_request_id': requestId,
      'sacrament_type': sacramentType,
    };

    try {
      await _client.from('notifications').insert({
        'target_role': 'secretary',
        'title': notificationTitle,
        'message': notificationMessage,
        'notification_type': 'pabuklat_request',
        'reference_id': requestId,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}

    try {
      await NotificationService.sendRolePushNotification(
        targetRole: 'secretary',
        title: notificationTitle,
        message: notificationMessage,
        data: notificationData,
      );
    } catch (e) {
      debugPrint('[PabuklatService] Non-blocking push dispatch notice: $e');
    }
  }

  // ===========================================================================
  // 4. Secretary Review, Signature Workflow & Printing Validation
  // ===========================================================================

  static Future<void> approveRequestBySecretary({
    required String serviceRequestId,
    required DateTime pickupDate,
    required String signatureMethod, // 'physical' or 'remote_esignature'
  }) async {
    final secretaryId = AuthService.currentUser?.userId;

    final isRemote = signatureMethod == 'remote_esignature';
    final targetStatus = isRemote ? 'forwarded_to_priest' : 'approved';
    final signatureStatus = isRemote ? 'forwarded' : 'pending_physical';
    final String pickupDateStr = pickupDate.toIso8601String().substring(0, 10);

    final updateMap = <String, dynamic>{
      'request_status': targetStatus,
      'signature_method': signatureMethod,
      'signature_status': signatureStatus,
      'pickup_date': pickupDateStr,
      'reviewed_by': secretaryId,
      if (isRemote) 'forwarded_to_priest_at': DateTime.now().toIso8601String(),
    };

    await _client
        .from('service_requests')
        .update(updateMap)
        .eq('service_request_id', serviceRequestId);

    // 1. Notify Requester Account of Approved Request & Assigned Pickup Date
    try {
      final req = await _client
          .from('service_requests')
          .select('created_by, requester_name, sacrament_type')
          .eq('service_request_id', serviceRequestId)
          .maybeSingle();

      final requesterUserId = req?['created_by']?.toString();
      final sacramentType = req?['sacrament_type']?.toString() ?? 'Sacrament';

      if (requesterUserId != null && requesterUserId.isNotEmpty) {
        final title = 'Certificate Pickup Scheduled';
        final message = 'Your $sacramentType certificate request has been approved. Scheduled pickup date: $pickupDateStr at the Parish Office.';

        await _client.from('notifications').insert({
          'user_id': requesterUserId,
          'title': title,
          'message': message,
          'notification_type': 'pabuklat_ready',
          'reference_id': serviceRequestId,
          'created_at': DateTime.now().toIso8601String(),
        });

        await NotificationService.sendUserPushNotification(
          targetUserId: requesterUserId,
          title: title,
          message: message,
          data: {
            'type': 'pabuklat_ready',
            'service_request_id': serviceRequestId,
            'pickup_date': pickupDateStr,
          },
        );
      }
    } catch (e) {
      debugPrint('[PabuklatService] Non-blocking requester alert error: $e');
    }

    // 2. If remote signature workflow, notify Parish Priest
    if (isRemote) {
      try {
        final notifTitle = 'Certificate Approval Required';
        final notifMsg = 'A certificate request has been forwarded for your remote e-signature approval.';

        await _client.from('notifications').insert({
          'target_role': 'parishpriest',
          'title': notifTitle,
          'message': notifMsg,
          'notification_type': 'tuesday_approval',
          'reference_id': serviceRequestId,
          'created_at': DateTime.now().toIso8601String(),
        });

        await NotificationService.sendRolePushNotification(
          targetRole: 'parishpriest',
          title: notifTitle,
          message: notifMsg,
          data: {'type': 'tuesday_approval', 'reference_id': serviceRequestId},
        );
      } catch (_) {}
    }
  }

  static Future<void> signAndApproveByPriest({
    required String serviceRequestId,
    required String priestSignatureUrl,
  }) async {
    final now = DateTime.now();

    await _client.from('service_requests').update({
      'request_status': 'signature_completed',
      'signature_status': 'signed',
      'priest_signed_at': now.toIso8601String(),
      'priest_signature_url': priestSignatureUrl,
    }).eq('service_request_id', serviceRequestId);

    try {
      final title = 'Certificate Signed by Priest';
      final msg = 'The Parish Priest has signed request $serviceRequestId. Certificate is now ready for printing.';

      await _client.from('notifications').insert({
        'target_role': 'secretary',
        'title': title,
        'message': msg,
        'notification_type': 'pabuklat_ready',
        'reference_id': serviceRequestId,
        'created_at': now.toIso8601String(),
      });

      await NotificationService.sendRolePushNotification(
        targetRole: 'secretary',
        title: title,
        message: msg,
        data: {'type': 'pabuklat_ready', 'reference_id': serviceRequestId},
      );
    } catch (_) {}
  }

  static bool validatePrintReadiness(Map<String, dynamic> request) {
    final status = (request['request_status'] ?? '').toString().toLowerCase();
    final method = (request['signature_method'] ?? 'physical').toString().toLowerCase();
    final signatureStatus = (request['signature_status'] ?? '').toString().toLowerCase();
    final pickupDate = request['pickup_date']?.toString();

    if (pickupDate == null || pickupDate.isEmpty) return false;

    if (status == 'rejected' || status == 'submitted' || status == 'record_verification') {
      return false;
    }

    if (method == 'remote_esignature') {
      return status == 'signature_completed' ||
          status == 'ready_for_pickup' ||
          status == 'released' ||
          signatureStatus == 'signed';
    }

    return status == 'approved' ||
        status == 'ready_for_pickup' ||
        status == 'released' ||
        status == 'signature_completed';
  }

  static Future<void> markCertificatePrinted(String serviceRequestId) async {
    final currentUserId = AuthService.currentUser?.userId;
    final now = DateTime.now();

    await _client.from('service_requests').update({
      'request_status': 'ready_for_pickup',
      'printed_at': now.toIso8601String(),
      'printed_by': currentUserId,
    }).eq('service_request_id', serviceRequestId);

    // Alert the requester that their certificate is printed and ready for pickup
    try {
      final req = await _client
          .from('service_requests')
          .select('created_by, requester_name, sacrament_type, pickup_date')
          .eq('service_request_id', serviceRequestId)
          .maybeSingle();

      final requesterUserId = req?['created_by']?.toString();
      final sacramentType = req?['sacrament_type']?.toString() ?? 'Sacrament';
      final pickupDateStr = req?['pickup_date']?.toString() ?? 'the scheduled date';

      if (requesterUserId != null && requesterUserId.isNotEmpty) {
        final title = 'Certificate Ready for Pickup!';
        final message = 'Your official $sacramentType certificate is ready for pickup at the Parish Office (Pickup Date: $pickupDateStr).';

        await _client.from('notifications').insert({
          'user_id': requesterUserId,
          'title': title,
          'message': message,
          'notification_type': 'pabuklat_ready',
          'reference_id': serviceRequestId,
          'created_at': now.toIso8601String(),
        });

        await NotificationService.sendUserPushNotification(
          targetUserId: requesterUserId,
          title: title,
          message: message,
          data: {
            'type': 'pabuklat_ready',
            'service_request_id': serviceRequestId,
            'pickup_date': pickupDateStr,
          },
        );
      }
    } catch (e) {
      debugPrint('[PabuklatService] Non-blocking printed notification notice: $e');
    }
  }

  static Future<void> markCertificateReleased(String serviceRequestId) async {
    final now = DateTime.now();

    await _client.from('service_requests').update({
      'request_status': 'released',
      'finalized_at': now.toIso8601String(),
    }).eq('service_request_id', serviceRequestId);
  }

  static Future<void> rejectRequest({
    required String serviceRequestId,
    required String reason,
  }) async {
    final secretaryId = AuthService.currentUser?.userId;
    final now = DateTime.now();

    await _client.from('service_requests').update({
      'request_status': 'rejected',
      'rejection_reason': reason.trim(),
      'reviewed_by': secretaryId,
      'finalized_at': now.toIso8601String(),
    }).eq('service_request_id', serviceRequestId);

    // Notify requester account of rejection reason
    try {
      final req = await _client
          .from('service_requests')
          .select('created_by, sacrament_type')
          .eq('service_request_id', serviceRequestId)
          .maybeSingle();

      final requesterUserId = req?['created_by']?.toString();
      final sacramentType = req?['sacrament_type']?.toString() ?? 'Sacrament';

      if (requesterUserId != null && requesterUserId.isNotEmpty) {
        final title = 'Certificate Request Rejected';
        final message = 'Your $sacramentType certificate request could not be approved. Reason: $reason';

        await _client.from('notifications').insert({
          'user_id': requesterUserId,
          'title': title,
          'message': message,
          'notification_type': 'pabuklat_ready',
          'reference_id': serviceRequestId,
          'created_at': now.toIso8601String(),
        });

        await NotificationService.sendUserPushNotification(
          targetUserId: requesterUserId,
          title: title,
          message: message,
          data: {
            'type': 'pabuklat_ready',
            'service_request_id': serviceRequestId,
          },
        );
      }
    } catch (_) {}
  }

  // ===========================================================================
  // 5. Parish Priest Reusable E-Signature Management
  // ===========================================================================

  static Future<String?> getPriestReusableSignature() async {
    try {
      final res = await _client
          .from('users')
          .select('signature_image_url')
          .eq('user_role', 'parishpriest')
          .eq('account_status', true)
          .not('signature_image_url', 'is', null)
          .limit(1)
          .maybeSingle();

      return res?['signature_image_url']?.toString();
    } catch (_) {
      return null;
    }
  }

  static Future<String?> updatePriestReusableSignature({
    required String priestUserId,
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    try {
      final cleanExt = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : 'png';
      final storagePath = 'signatures/priest_esignature_$priestUserId.$cleanExt';

      await _client.storage.from('certificate-assets').uploadBinary(
        storagePath,
        fileBytes,
        fileOptions: FileOptions(contentType: 'image/$cleanExt', upsert: true),
      );

      final publicUrl = _client.storage.from('certificate-assets').getPublicUrl(storagePath);

      await _client
          .from('users')
          .update({'signature_image_url': publicUrl})
          .eq('user_id', priestUserId);

      return publicUrl;
    } catch (e) {
      debugPrint('[PabuklatService] Error saving priest e-signature: $e');
      return null;
    }
  }

  // ===========================================================================
  // 6. Backend 72-Hour Automatic ID Deletion Engine
  // ===========================================================================

  static Future<void> purgeExpiredRequestIds() async {
    try {
      final cutoff = DateTime.now().subtract(const Duration(hours: 72)).toIso8601String();

      final expired = await _client
          .from('service_requests')
          .select('service_request_id, id_document_url')
          .not('id_document_url', 'is', null)
          .eq('id_purged', false)
          .lte('finalized_at', cutoff);

      for (final row in expired as List) {
        final reqId = row['service_request_id']?.toString();
        final path = row['id_document_url']?.toString();

        if (path != null && path.isNotEmpty) {
          try {
            await _client.storage.from('appointment-documents').remove([path]);
          } catch (_) {}
        }

        if (reqId != null) {
          await _client.from('service_requests').update({
            'id_document_url': null,
            'id_purged': true,
          }).eq('service_request_id', reqId);
        }
      }
    } catch (_) {}
  }
}