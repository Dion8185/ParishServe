// =============================================================================
// FILE: lib/features/sacramental_records/services/pabuklat_service.dart
// =============================================================================

import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/services/auth_service.dart';

class SacramentMatchResult {
  final String recordId;
  final String sacramentType;
  final String fullName;
  final String bookRef;
  final String dateOfSacrament;
  final String parentage;
  final int matchScore;
  final Map<String, dynamic> rawData;

  const SacramentMatchResult({
    required this.recordId,
    required this.sacramentType,
    required this.fullName,
    required this.bookRef,
    required this.dateOfSacrament,
    required this.parentage,
    required this.matchScore,
    required this.rawData,
  });
}

class PabuklatService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Searches sacramental tables using separate First, Middle, Last names, Parents,
  /// Birthdate, and Sacrament date, requiring at least 2 matching information points.
  static Future<List<SacramentMatchResult>> searchRecordsForRequest({
    required String sacramentType,
    // General / Individual names
    String? firstName,
    String? middleName,
    String? lastName,
    // Marriage specific (Groom & Bride)
    String? groomFirstName,
    String? groomMiddleName,
    String? groomLastName,
    String? brideFirstName,
    String? brideMiddleName,
    String? brideLastName,
    // Parents
    String? fatherName,
    String? motherName,
    DateTime? birthDate,
    DateTime? sacramentDate,
  }) async {
    final List<SacramentMatchResult> matches = [];

    final fName = firstName?.trim().toLowerCase() ?? '';
    final mName = middleName?.trim().toLowerCase() ?? '';
    final lName = lastName?.trim().toLowerCase() ?? '';

    final gFirst = groomFirstName?.trim().toLowerCase() ?? '';
    final gLast = groomLastName?.trim().toLowerCase() ?? '';
    final bFirst = brideFirstName?.trim().toLowerCase() ?? '';
    final bLast = brideLastName?.trim().toLowerCase() ?? '';

    final fatName = fatherName?.trim().toLowerCase() ?? '';
    final motName = motherName?.trim().toLowerCase() ?? '';

    try {
      // 1. Baptism Records
      if (sacramentType == 'All' || sacramentType == 'Baptism') {
        final res = await _client.from('baptism_records').select().limit(50);
        for (final row in res as List) {
          int score = 0;
          final rFirst = (row['child_first_name'] ?? '').toString().toLowerCase();
          final rMiddle = (row['child_middle_name'] ?? '').toString().toLowerCase();
          final rLast = (row['child_last_name'] ?? '').toString().toLowerCase();
          final rDob = row['date_of_birth']?.toString();
          final rDap = row['date_of_baptism']?.toString();
          final rFat = '${row['father_first_name'] ?? ''} ${row['father_last_name'] ?? ''}'.toLowerCase();
          final rMot = '${row['mother_first_name'] ?? ''} ${row['mother_maiden_last_name'] ?? ''}'.toLowerCase();

          if (fName.isNotEmpty && rFirst.contains(fName)) score++;
          if (lName.isNotEmpty && rLast.contains(lName)) score++;
          if (mName.isNotEmpty && rMiddle.contains(mName)) score++;
          if (birthDate != null && rDob != null && rDob.startsWith(birthDate.toIso8601String().substring(0, 10))) score++;
          if (sacramentDate != null && rDap != null && rDap.startsWith(sacramentDate.toIso8601String().substring(0, 10))) score++;
          if (fatName.isNotEmpty && rFat.contains(fatName)) score++;
          if (motName.isNotEmpty && rMot.contains(motName)) score++;

          // Require 2 or more matches
          if (score >= 2) {
            final childFull = '${row['child_first_name'] ?? ''} ${row['child_last_name'] ?? ''}'.trim();
            matches.add(SacramentMatchResult(
              recordId: row['record_id'] ?? '',
              sacramentType: 'Baptism',
              fullName: childFull,
              bookRef: 'Book ${row['book_number']}, Page ${row['page_number']}, Line ${row['line_number']}',
              dateOfSacrament: row['date_of_baptism']?.toString() ?? '',
              parentage: 'Father: ${row['father_first_name']} ${row['father_last_name']} | Mother: ${row['mother_first_name']} ${row['mother_maiden_last_name']}',
              matchScore: score,
              rawData: Map<String, dynamic>.from(row),
            ));
          }
        }
      }

      // 2. Confirmation Records
      if (sacramentType == 'All' || sacramentType == 'Confirmation') {
        final res = await _client.from('confirmation_records').select().limit(50);
        for (final row in res as List) {
          int score = 0;
          final rFirst = (row['confirmand_first_name'] ?? '').toString().toLowerCase();
          final rMiddle = (row['confirmand_middle_name'] ?? '').toString().toLowerCase();
          final rLast = (row['confirmand_last_name'] ?? '').toString().toLowerCase();
          final rDob = row['date_of_birth']?.toString();
          final rConf = row['date_of_confirmation']?.toString();
          final rFat = '${row['father_first_name'] ?? ''} ${row['father_last_name'] ?? ''}'.toLowerCase();
          final rMot = '${row['mother_first_name'] ?? ''} ${row['mother_maiden_last_name'] ?? ''}'.toLowerCase();

          if (fName.isNotEmpty && rFirst.contains(fName)) score++;
          if (lName.isNotEmpty && rLast.contains(lName)) score++;
          if (mName.isNotEmpty && rMiddle.contains(mName)) score++;
          if (birthDate != null && rDob != null && rDob.startsWith(birthDate.toIso8601String().substring(0, 10))) score++;
          if (sacramentDate != null && rConf != null && rConf.startsWith(sacramentDate.toIso8601String().substring(0, 10))) score++;
          if (fatName.isNotEmpty && rFat.contains(fatName)) score++;
          if (motName.isNotEmpty && rMot.contains(motName)) score++;

          if (score >= 2) {
            final confirmandFull = '${row['confirmand_first_name'] ?? ''} ${row['confirmand_last_name'] ?? ''}'.trim();
            matches.add(SacramentMatchResult(
              recordId: row['record_id'] ?? '',
              sacramentType: 'Confirmation',
              fullName: confirmandFull,
              bookRef: 'Book ${row['book_number']}, Page ${row['page_number']}, Line ${row['line_number']}',
              dateOfSacrament: row['date_of_confirmation']?.toString() ?? '',
              parentage: 'Father: ${row['father_first_name']} ${row['father_last_name']} | Mother: ${row['mother_first_name']} ${row['mother_maiden_last_name']}',
              matchScore: score,
              rawData: Map<String, dynamic>.from(row),
            ));
          }
        }
      }

      // 3. Matrimony Records (Supports searching by Groom OR Bride name)
      if (sacramentType == 'All' || sacramentType == 'Matrimony') {
        final res = await _client.from('matrimony_records').select().limit(50);
        for (final row in res as List) {
          int score = 0;
          final gFirstDb = (row['groom_first_name'] ?? '').toString().toLowerCase();
          final gLastDb = (row['groom_last_name'] ?? '').toString().toLowerCase();
          final bFirstDb = (row['bride_first_name'] ?? '').toString().toLowerCase();
          final bLastDb = (row['bride_last_name'] ?? '').toString().toLowerCase();
          final rMar = row['date_of_marriage']?.toString();

          if (gFirst.isNotEmpty && gFirstDb.contains(gFirst)) score++;
          if (gLast.isNotEmpty && gLastDb.contains(gLast)) score++;
          if (bFirst.isNotEmpty && bFirstDb.contains(bFirst)) score++;
          if (bLast.isNotEmpty && bLastDb.contains(bLast)) score++;
          if (sacramentDate != null && rMar != null && rMar.startsWith(sacramentDate.toIso8601String().substring(0, 10))) score++;

          // For matrimony, matching groom or bride name fields counts towards score
          if (score >= 2 || (gLast.isNotEmpty && gLastDb.contains(gLast)) || (bLast.isNotEmpty && bLastDb.contains(bLast))) {
            final couple = '${row['groom_first_name']} ${row['groom_last_name']} & ${row['bride_first_name']} ${row['bride_last_name']}';
            matches.add(SacramentMatchResult(
              recordId: row['record_id'] ?? '',
              sacramentType: 'Matrimony',
              fullName: couple,
              bookRef: 'Book ${row['book_number']}, Page ${row['page_number']}, Line ${row['line_number']}',
              dateOfSacrament: row['date_of_marriage']?.toString() ?? '',
              parentage: 'Groom & Bride Canonical Union',
              matchScore: max(2, score),
              rawData: Map<String, dynamic>.from(row),
            ));
          }
        }
      }

      // 4. Death Records
      if (sacramentType == 'All' || sacramentType == 'Death') {
        final res = await _client.from('death_records').select().limit(50);
        for (final row in res as List) {
          int score = 0;
          final rFirst = (row['deceased_first_name'] ?? '').toString().toLowerCase();
          final rMiddle = (row['deceased_middle_name'] ?? '').toString().toLowerCase();
          final rLast = (row['deceased_last_name'] ?? '').toString().toLowerCase();
          final rBurial = row['date_of_burial']?.toString();

          if (fName.isNotEmpty && rFirst.contains(fName)) score++;
          if (lName.isNotEmpty && rLast.contains(lName)) score++;
          if (mName.isNotEmpty && rMiddle.contains(mName)) score++;
          if (sacramentDate != null && rBurial != null && rBurial.startsWith(sacramentDate.toIso8601String().substring(0, 10))) score++;

          if (score >= 2 || (lName.isNotEmpty && rLast.contains(lName))) {
            final deceasedFull = '${row['deceased_first_name'] ?? ''} ${row['deceased_last_name'] ?? ''}'.trim();
            matches.add(SacramentMatchResult(
              recordId: row['record_id'] ?? '',
              sacramentType: 'Death',
              fullName: deceasedFull,
              bookRef: 'Book ${row['book_number']}, Page ${row['page_number']}, Line ${row['line_number']}',
              dateOfSacrament: row['date_of_burial']?.toString() ?? '',
              parentage: 'Burial Record',
              matchScore: max(2, score),
              rawData: Map<String, dynamic>.from(row),
            ));
          }
        }
      }

    } catch (e) {
      debugPrint('[PabuklatService] Search error: $e');
    }

    // Sort matches by highest score first
    matches.sort((a, b) => b.matchScore.compareTo(a.matchScore));
    return matches;
  }

  /// Submits the Pabuklat request associated with an existing matched record
  static Future<void> createPabuklatRequest({
    required String sacramentType,
    required String recordId,
    required String matchedRecordSummary,
    required String requesterName,
    required String contactNumber,
    required String purpose,
  }) async {
    final user = AuthService.currentUser;
    final requestId = 'REQ-${DateTime.now().millisecondsSinceEpoch}';

    final payload = {
      'service_request_id': requestId,
      'requester_name': requesterName.trim(),
      'contact_number': contactNumber.trim(),
      'email': user?.email,
      'service_type': 'Pabuklat / $sacramentType Certificate',
      'sacrament_type': sacramentType,
      'record_id': recordId,
      'matched_record_summary': matchedRecordSummary,
      'service_request_details': 'Purpose: $purpose\nMatched Record ID: $recordId',
      'request_status': 'submitted',
      'created_by': user?.userId,
      'created_at': DateTime.now().toIso8601String(),
    };

    await _client.from('service_requests').insert(payload);

    try {
      await _client.from('notifications').insert({
        'target_role': 'secretary',
        'title': 'New Pabuklat Request',
        'message': '$requesterName requested a $sacramentType certificate. Record verification required.',
        'notification_type': 'pabuklat_request',
        'reference_id': requestId,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }
}