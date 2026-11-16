import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/database/local_database_service.dart';
import '../../../core/services/records_sync_service.dart';
import '../../auth/services/auth_service.dart';
import '../../receipts/services/secretary_service.dart';
import '../models/mass_intention_model.dart';
import 'payment_reference_service.dart';

class MassIntentionService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Safely updates the local SQLite `mass_intentions` cache by filtering
  /// out columns that do not exist in the local SQLite table schema.
  static Future<void> _safeLocalMassIntentionUpdate(
      String intentionId,
      Map<String, dynamic> payload,
      ) async {
    if (kIsWeb) return;
    try {
      final db = await LocalDatabaseService.instance.database;
      if (db == null) return;

      final tableInfo =
      await db.rawQuery('PRAGMA table_info(mass_intentions)');
      final validColumns = tableInfo
          .map((row) => row['name']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .toSet();

      if (validColumns.isEmpty) return;

      final filteredPayload = <String, dynamic>{};
      payload.forEach((key, value) {
        if (validColumns.contains(key)) {
          filteredPayload[key] = value;
        }
      });

      if (filteredPayload.isNotEmpty) {
        await db.update(
          'mass_intentions',
          filteredPayload,
          where: 'intention_id = ?',
          whereArgs: [intentionId],
        );
      }
    } catch (e) {
      debugPrint('[MassIntentionService] Local SQLite update skipped: $e');
    }
  }

  /// Fetch all mass intentions ordered by scheduled date and time.
  /// Online/Web: queries Supabase and caches to SQLite.
  /// Offline native: queries SQLite directly.
  static Future<List<MassIntentionModel>> getMassIntentions({
    String? statusFilter,
    String? verificationFilter,
  }) async {
    final isOnline = await RecordsSyncService.instance.checkConnectivity();

    if (isOnline || kIsWeb) {
      try {
        var query = _client.from('mass_intentions').select();

        if (statusFilter != null && statusFilter.toLowerCase() != 'all') {
          query = query.eq('intention_status', statusFilter.toLowerCase());
        }

        if (verificationFilter != null &&
            verificationFilter.toLowerCase() != 'all') {
          query = query.eq(
              'verification_status', verificationFilter.toLowerCase());
        }

        final response = await query
            .order('scheduled_date', ascending: true)
            .order('mass_time', ascending: true);

        final list = (response as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();

        if (!kIsWeb) {
          await RecordsSyncService.instance.cacheRemoteRecordsLocally(
            'mass_intentions',
            list,
          );
        }

        return list.map((row) => MassIntentionModel.fromMap(row)).toList();
      } catch (e) {
        debugPrint('[MassIntentionService] Remote fetch error: $e');
        if (kIsWeb) return [];
      }
    }

    // Direct SQLite Query for Native Offline
    final db = await LocalDatabaseService.instance.database;
    if (db != null) {
      try {
        String? whereClause;
        List<dynamic>? whereArgs;

        if (statusFilter != null && statusFilter.toLowerCase() != 'all') {
          whereClause = 'intention_status = ?';
          whereArgs = [statusFilter.toLowerCase()];
        }

        final rows = await db.query(
          'mass_intentions',
          where: whereClause,
          whereArgs: whereArgs,
          orderBy: 'scheduled_date ASC, mass_time ASC',
        );

        return rows.map((r) => MassIntentionModel.fromMap(r)).toList();
      } catch (_) {}
    }

    return [];
  }

  /// Fetch mass intentions created by current logged-in parishioner
  static Future<List<MassIntentionModel>> getMyMassIntentions() async {
    final user = AuthService.currentUser;
    if (user == null) return [];

    final cleanEmail = user.email.trim().toLowerCase();
    final cleanName = user.fullName.trim();

    try {
      final idMatches = await _client
          .from('mass_intentions')
          .select()
          .eq('created_by', user.userId)
          .order('scheduled_date', ascending: false);

      if ((idMatches as List).isNotEmpty) {
        return idMatches.map((e) => MassIntentionModel.fromMap(e)).toList();
      }

      if (cleanEmail.isNotEmpty) {
        final emailMatches = await _client
            .from('mass_intentions')
            .select()
            .ilike('email', cleanEmail)
            .order('scheduled_date', ascending: false);

        if ((emailMatches as List).isNotEmpty) {
          return emailMatches
              .map((e) => MassIntentionModel.fromMap(e))
              .toList();
        }
      }

      final nameMatches = await _client
          .from('mass_intentions')
          .select()
          .ilike('requester_name', '%$cleanName%')
          .order('scheduled_date', ascending: false);

      return (nameMatches as List)
          .map((e) => MassIntentionModel.fromMap(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Uploads GCash payment receipt screenshot bytes to Supabase Storage
  static Future<String?> uploadReceiptImage({
    required String intentionId,
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    try {
      final cleanExtension =
      fileName.contains('.') ? fileName.split('.').last : 'jpg';
      final filePath =
          'gcash_receipts/$intentionId/receipt_${DateTime.now().millisecondsSinceEpoch}.$cleanExtension';

      await _client.storage.from('certificate-assets').uploadBinary(
        filePath,
        fileBytes,
        fileOptions: FileOptions(
          contentType: cleanExtension == 'pdf'
              ? 'application/pdf'
              : 'image/$cleanExtension',
          upsert: true,
        ),
      );

      return _client.storage.from('certificate-assets').getPublicUrl(filePath);
    } catch (e) {
      debugPrint(
          '[MassIntentionService] Error uploading receipt screenshot: $e');
      return null;
    }
  }

  /// Create and register a complete Mass Intention.
  /// - GCash QR payments are automatically approved, verified, and transferred to
  ///   Receipts Management (`parish_transactions`) ONLY if the GCash reference and
  ///   amount match an unused entry in `payment_references`.
  /// - Unmatched/unverified GCash submissions remain pending and are NOT transferred
  ///   to Receipts Management until verified.
  static Future<MassIntentionModel> createMassIntention({
    required String requesterName,
    required String contactNumber,
    String? email,
    required String date, // YYYY-MM-DD
    required String massTime, // "17:30:00", "08:00:00", "16:00:00"
    required List<String> thanksgivingList,
    required List<String> reposeSoulsList,
    required List<String> specialIntentionsList,
    String? otherIntentions,
    required double stipendAmount,
    String paymentMethod = 'GCash',
    String? gcashReferenceNo,
    String? receiptImageUrl,
    String? ocrReferenceNumber,
    double? ocrAmount,
    String? ocrRawText,
    String? remarks,
  }) async {
    if (requesterName.trim().isEmpty) throw 'Requester name is required.';
    if (contactNumber.trim().isEmpty) throw 'Contact number is required.';

    final totalIntentions = thanksgivingList.length +
        reposeSoulsList.length +
        specialIntentionsList.length +
        (otherIntentions != null && otherIntentions.trim().isNotEmpty ? 1 : 0);

    if (totalIntentions == 0) {
      throw 'Please provide at least one intention name under Thanksgiving, Repose of the Soul, Special Intentions, or Others.';
    }

    final parsedDate = DateTime.tryParse(date);
    if (parsedDate == null) throw 'Invalid date selected.';

    // Strict Day Validation: Wednesdays (3), Fridays (5), and Sundays (7) only
    if (parsedDate.weekday != DateTime.wednesday &&
        parsedDate.weekday != DateTime.friday &&
        parsedDate.weekday != DateTime.sunday) {
      throw 'Mass Intentions can only be scheduled on Wednesdays, Fridays, and Sundays.';
    }

    // Strict Time Validation
    if (parsedDate.weekday == DateTime.wednesday ||
        parsedDate.weekday == DateTime.friday) {
      if (!massTime.startsWith('17:30')) {
        throw 'Weekday Mass Intentions (Wednesdays & Fridays) can only be set at 5:30 PM.';
      }
    } else if (parsedDate.weekday == DateTime.sunday) {
      if (!massTime.startsWith('08:00') && !massTime.startsWith('16:00')) {
        throw 'Sunday Mass Intentions can only be scheduled at 8:00 AM or 4:00 PM.';
      }
    }

    final intentionId = await _generateIntentionId();
    final String? currentUserId = AuthService.currentUser?.userId;
    final bool isStaff =
        AuthService.currentUser?.userRole.toLowerCase() != 'user';

    // Users are strictly locked to GCash. Secretary may accept Walk-In Cash or GCash.
    final String effectivePaymentMethod = isStaff ? paymentMethod : 'GCash';
    final bool isImmediateCashConfirmation =
        isStaff && effectivePaymentMethod.toLowerCase().contains('cash');

    // Automated counter-check against existing payment references for GCash QR payments
    String? matchedRefId;
    bool isAutoVerifiedByGcashQr = false;

    if (effectivePaymentMethod == 'GCash') {
      final refToSearch = (gcashReferenceNo != null &&
          gcashReferenceNo.trim().isNotEmpty)
          ? gcashReferenceNo.trim()
          : (ocrReferenceNumber?.trim() ?? '');
      final double amountToVerify =
      (ocrAmount != null && ocrAmount > 0) ? ocrAmount : stipendAmount;

      if (refToSearch.isNotEmpty) {
        final existingRef = await PaymentReferenceService.findMatchingReference(
          referenceNumber: refToSearch,
          expectedAmount: amountToVerify,
        );

        final bool ocrMatchesStipend =
            ocrAmount == null || (ocrAmount - stipendAmount).abs() < 0.01;

        if (existingRef != null &&
            existingRef.isUnused &&
            ocrMatchesStipend) {
          matchedRefId = existingRef.referenceId;
          isAutoVerifiedByGcashQr = true;
        }
      }
    }

    final bool shouldAutoApprove =
        isImmediateCashConfirmation || isAutoVerifiedByGcashQr;

    final String initialStatus = shouldAutoApprove ? 'confirmed' : 'pending';
    final String initialPaymentStatus =
    shouldAutoApprove ? 'verified' : 'pending';
    final String initialVerificationStatus = shouldAutoApprove
        ? 'verified'
        : (effectivePaymentMethod == 'GCash' ? 'unmatched' : 'pending');

    final payload = {
      'intention_id': intentionId,
      'created_by': currentUserId,
      'requester_name': requesterName.trim(),
      'contact_number': contactNumber.trim(),
      'email': email?.trim().isEmpty ?? true ? null : email!.trim(),
      'scheduled_date': date,
      'mass_time': massTime,
      'thanksgiving_list': thanksgivingList,
      'repose_souls_list': reposeSoulsList,
      'special_intentions_list': specialIntentionsList,
      'other_intentions':
      otherIntentions?.trim().isEmpty ?? true ? null : otherIntentions!.trim(),
      'stipend_amount': stipendAmount,
      'payment_method': effectivePaymentMethod,
      'payment_status': initialPaymentStatus,
      'gcash_reference_no': gcashReferenceNo?.trim().isEmpty ?? true
          ? null
          : gcashReferenceNo!.trim(),
      'intention_status': initialStatus,
      'remarks': remarks?.trim().isEmpty ?? true ? null : remarks!.trim(),
      'receipt_image_url': receiptImageUrl,
      'ocr_reference_number': ocrReferenceNumber,
      'ocr_amount': ocrAmount,
      'ocr_raw_text': ocrRawText,
      'verification_status': initialVerificationStatus,
      'matching_reference_id': matchedRefId,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    final isOnline = await RecordsSyncService.instance.checkConnectivity();

    if (isOnline || kIsWeb) {
      try {
        final response = await _client
            .from('mass_intentions')
            .insert(payload)
            .select()
            .single();

        final created = MassIntentionModel.fromMap(response);

        // Only transfer to Receipts Management if automatically approved & verified
        if (isAutoVerifiedByGcashQr) {
          final txnRecord = await _generateReceiptForIntention(created, 'GCash');
          if (matchedRefId != null && matchedRefId.isNotEmpty) {
            await PaymentReferenceService.markAsUsed(
              referenceId: matchedRefId,
              intentionId: created.intentionId,
              transactionId: txnRecord['transaction_id']?.toString(),
            );
          }
        } else if (isImmediateCashConfirmation) {
          await _generateReceiptForIntention(created, 'Cash');
        }

        if (!kIsWeb) {
          try {
            await RecordsSyncService.instance.cacheRemoteRecordsLocally(
              'mass_intentions',
              [response],
            );
          } catch (_) {}
        }

        return created;
      } catch (e) {
        if (kIsWeb) rethrow;
      }
    }

    // Offline on Native
    await RecordsSyncService.instance.queueOfflineChange(
      tableName: 'mass_intentions',
      recordId: intentionId,
      operation: 'INSERT',
      data: payload,
    );

    return MassIntentionModel.fromMap(payload);
  }

  /// Secretary approval of Mass Intention and Payment:
  /// 1. Updates status to confirmed and verified in Supabase and SQLite
  /// 2. Generates the official receipt in parish_transactions
  /// 3. Marks reference as used (linked to intention and transaction)
  static Future<Map<String, dynamic>> approveAndVerifyIntention({
    required MassIntentionModel intention,
    required double verifiedAmount,
    required String verifiedRefNumber,
    String? matchingReferenceId,
  }) async {
    final now = DateTime.now();
    final updatePayload = {
      'intention_status': 'confirmed',
      'payment_status': 'verified',
      'verification_status': 'verified',
      'gcash_reference_no': verifiedRefNumber.trim(),
      'stipend_amount': verifiedAmount,
      'matching_reference_id':
      matchingReferenceId ?? intention.matchingReferenceId,
      'updated_at': now.toIso8601String(),
    };

    await _client
        .from('mass_intentions')
        .update(updatePayload)
        .eq('intention_id', intention.intentionId);

    await _safeLocalMassIntentionUpdate(intention.intentionId, updatePayload);

    // Generate Official Receipt in parish_transactions
    final updatedModel = intention.copyWith(
      intentionStatus: 'confirmed',
      paymentStatus: 'verified',
      verificationStatus: 'verified',
      gcashReferenceNo: verifiedRefNumber.trim(),
      stipendAmount: verifiedAmount,
    );

    final txnRecord = await _generateReceiptForIntention(
      updatedModel,
      intention.paymentMethod,
    );

    // If matching payment reference is present, mark as used with transaction link
    final refId = matchingReferenceId ?? intention.matchingReferenceId;
    if (refId != null && refId.isNotEmpty) {
      await PaymentReferenceService.markAsUsed(
        referenceId: refId,
        intentionId: intention.intentionId,
        transactionId: txnRecord['transaction_id']?.toString(),
      );
    }

    return txnRecord;
  }

  /// Secretary rejection of Mass Intention:
  /// 1. Updates status to rejected (auto-archived)
  /// 2. Releases reference back to unused if reserved
  /// 3. Strict rule: NO receipt is created for rejected intentions
  static Future<void> rejectIntention({
    required String intentionId,
    required String reason,
    String? matchingReferenceId,
  }) async {
    final now = DateTime.now();
    final dateStamp =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final auditNote = '[REJECTED on $dateStamp]: $reason';

    final res = await _client
        .from('mass_intentions')
        .select('remarks, matching_reference_id')
        .eq('intention_id', intentionId)
        .maybeSingle();

    final prevRemarks = res?['remarks']?.toString();
    final combinedRemarks = (prevRemarks == null || prevRemarks.isEmpty)
        ? auditNote
        : '$prevRemarks\n$auditNote';

    final updatePayload = {
      'intention_status': 'rejected',
      'payment_status': 'rejected',
      'verification_status': 'rejected',
      'remarks': combinedRemarks,
      'updated_at': now.toIso8601String(),
    };

    await _client
        .from('mass_intentions')
        .update(updatePayload)
        .eq('intention_id', intentionId);

    await _safeLocalMassIntentionUpdate(intentionId, updatePayload);

    final refId =
        matchingReferenceId ?? res?['matching_reference_id']?.toString();
    if (refId != null && refId.isNotEmpty) {
      await PaymentReferenceService.releaseReference(refId);
    }
  }

  /// Internal generator: Connects verified Mass Intention directly to the official Parish Receipts system
  static Future<Map<String, dynamic>> _generateReceiptForIntention(
      MassIntentionModel item,
      String paymentMode,
      ) async {
    final lines = <String>[];
    if (item.thanksgivingList.isNotEmpty) {
      lines.add('• Thanksgiving: ${item.thanksgivingList.join(", ")}');
    }
    if (item.reposeSoulsList.isNotEmpty) {
      lines.add('• Repose of Souls: ${item.reposeSoulsList.join(", ")}');
    }
    if (item.specialIntentionsList.isNotEmpty) {
      lines.add('• Special Petitions: ${item.specialIntentionsList.join(", ")}');
    }
    if (item.otherIntentions != null && item.otherIntentions!.isNotEmpty) {
      lines.add('• Others: ${item.otherIntentions}');
    }

    final normalizedMode =
    paymentMode.toLowerCase().contains('gcash') ? 'GCash' : 'Cash';
    final serviceTitle =
        'Mass Intention (${item.dayOfWeekName}, ${item.formattedDate} at ${item.formattedTime12Hour})';
    final refNote = (item.gcashReferenceNo != null &&
        item.gcashReferenceNo!.isNotEmpty)
        ? '\nGCash Ref: ${item.gcashReferenceNo}'
        : '';
    final details =
        '• $serviceTitle\n${lines.join("\n")}\nTender Mode: $normalizedMode$refNote\nIntention ID: ${item.intentionId}';

    return await SecretaryService.createTransaction(
      payorName: item.requesterName,
      payorContact: item.contactNumber,
      relatedService: serviceTitle,
      transactionDetails: details,
      transactionAmount: item.stipendAmount,
      transactionType: 'mass_intention',
      paymentMode: normalizedMode,
      receiptImageUrl: item.receiptImageUrl,
      verificationStatus: 'verified',
      transactionDate: item.scheduledDate,
    );
  }

  /// Reschedule a specific Mass Intention to another valid Mass slot
  static Future<void> rescheduleMassIntention({
    required String intentionId,
    required String newDate,
    required String newMassTime,
    required String reason,
    String? previousRemarks,
    String? previousDate,
    String? previousTime,
  }) async {
    final parsedDate = DateTime.tryParse(newDate);
    if (parsedDate == null) throw 'Invalid date selected.';

    if (parsedDate.weekday != DateTime.wednesday &&
        parsedDate.weekday != DateTime.friday &&
        parsedDate.weekday != DateTime.sunday) {
      throw 'Mass Intentions can only be moved to Wednesdays, Fridays, and Sundays.';
    }

    final bool isParishioner =
        AuthService.currentUser?.userRole.toLowerCase() == 'user';
    final targetStatus = isParishioner ? 'pending' : 'confirmed';

    final now = DateTime.now();
    final dateStamp =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final auditLog =
        '[Rescheduled on $dateStamp]: Moved from $previousDate ($previousTime) to $newDate ($newMassTime). Reason: $reason';

    final updatedRemarks =
    (previousRemarks == null || previousRemarks.trim().isEmpty)
        ? auditLog
        : '$previousRemarks\n$auditLog';

    final updatePayload = {
      'scheduled_date': newDate,
      'mass_time': newMassTime,
      'intention_status': targetStatus,
      'remarks': updatedRemarks,
      'updated_at': DateTime.now().toIso8601String(),
    };

    final isOnline = await RecordsSyncService.instance.checkConnectivity();
    if (isOnline || kIsWeb) {
      try {
        await _client
            .from('mass_intentions')
            .update(updatePayload)
            .eq('intention_id', intentionId);

        await _safeLocalMassIntentionUpdate(intentionId, updatePayload);
        return;
      } catch (e) {
        if (kIsWeb) rethrow;
      }
    }

    // Offline on Native
    await RecordsSyncService.instance.queueOfflineChange(
      tableName: 'mass_intentions',
      recordId: intentionId,
      operation: 'UPDATE',
      data: updatePayload,
    );
  }

  /// Update Mass Intention status
  static Future<void> updateStatus(
      String intentionId, String newStatus) async {
    final updatePayload = {
      'intention_status': newStatus.toLowerCase(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    final isOnline = await RecordsSyncService.instance.checkConnectivity();
    if (isOnline || kIsWeb) {
      try {
        await _client
            .from('mass_intentions')
            .update(updatePayload)
            .eq('intention_id', intentionId);

        await _safeLocalMassIntentionUpdate(intentionId, updatePayload);
        return;
      } catch (e) {
        if (kIsWeb) rethrow;
      }
    }

    // Offline on Native
    await RecordsSyncService.instance.queueOfflineChange(
      tableName: 'mass_intentions',
      recordId: intentionId,
      operation: 'UPDATE',
      data: updatePayload,
    );
  }

  /// Generates sequential Intention ID: INT-YY-XXXX
  static Future<String> _generateIntentionId() async {
    final now = DateTime.now();
    final yearSuffix = (now.year % 100).toString().padLeft(2, '0');

    final isOnline = await RecordsSyncService.instance.checkConnectivity();
    if (isOnline || kIsWeb) {
      try {
        final records = await _client
            .from('mass_intentions')
            .select('intention_id')
            .like('intention_id', 'INT-$yearSuffix-%')
            .order('created_at', ascending: false)
            .limit(50);

        int highest = 0;
        for (final item in records) {
          final id = item['intention_id']?.toString() ?? '';
          final parts = id.split('-');
          if (parts.length >= 3) {
            final seq = int.tryParse(parts[2]);
            if (seq != null && seq > highest && seq < 10000) {
              highest = seq;
            }
          }
        }

        if (highest > 0) {
          final nextSeq = (highest + 1).toString().padLeft(4, '0');
          return 'INT-$yearSuffix-$nextSeq';
        }
      } catch (_) {}
    }

    // Direct SQLite check if offline
    final db = await LocalDatabaseService.instance.database;
    if (db != null) {
      try {
        final localRows = await db.rawQuery(
          "SELECT intention_id FROM mass_intentions WHERE intention_id LIKE 'INT-$yearSuffix-%'",
        );
        int highest = 0;
        for (final item in localRows) {
          final id = item['intention_id']?.toString() ?? '';
          final parts = id.split('-');
          if (parts.length >= 3) {
            final seq = int.tryParse(parts[2]);
            if (seq != null && seq > highest && seq < 10000) {
              highest = seq;
            }
          }
        }
        if (highest > 0) {
          final nextSeq = (highest + 1).toString().padLeft(4, '0');
          return 'INT-$yearSuffix-$nextSeq';
        }
      } catch (_) {}
    }

    final timestampSeq =
    (now.millisecondsSinceEpoch ~/ 100 % 9000 + 1000).toString();
    return 'INT-$yearSuffix-$timestampSeq';
  }
}