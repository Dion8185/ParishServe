import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/services/auth_service.dart';
import '../models/mass_intention_model.dart';

class MassIntentionService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Fetch all mass intentions ordered by scheduled date and time
  static Future<List<MassIntentionModel>> getMassIntentions({String? statusFilter}) async {
    var query = _client.from('mass_intentions').select();

    if (statusFilter != null && statusFilter.toLowerCase() != 'all') {
      query = query.eq('intention_status', statusFilter.toLowerCase());
    }

    final response = await query
        .order('scheduled_date', ascending: true)
        .order('mass_time', ascending: true);

    return (response as List)
        .map((row) => MassIntentionModel.fromMap(row as Map<String, dynamic>))
        .toList();
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
          return emailMatches.map((e) => MassIntentionModel.fromMap(e)).toList();
        }
      }

      final nameMatches = await _client
          .from('mass_intentions')
          .select()
          .ilike('requester_name', '%$cleanName%')
          .order('scheduled_date', ascending: false);

      return (nameMatches as List).map((e) => MassIntentionModel.fromMap(e)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Create and register a complete Mass Intention
  static Future<MassIntentionModel> createMassIntention({
    required String requesterName,
    required String contactNumber,
    String? email,
    required String date,       // YYYY-MM-DD
    required String massTime,   // "17:30:00", "08:00:00", "16:00:00"
    required List<String> thanksgivingList,
    required List<String> reposeSoulsList,
    required List<String> specialIntentionsList,
    String? otherIntentions,
    required double stipendAmount,
    String paymentMethod = 'GCash',
    String? gcashReferenceNo,
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
    if (parsedDate.weekday == DateTime.wednesday || parsedDate.weekday == DateTime.friday) {
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
    final bool isStaff = AuthService.currentUser?.userRole.toLowerCase() != 'user';

    // Walk-ins handled directly by Secretary are confirmed with verified cash intake
    final String initialStatus = isStaff ? 'confirmed' : 'pending';
    final String paymentStatus = isStaff
        ? 'verified'
        : (gcashReferenceNo != null && gcashReferenceNo.trim().isNotEmpty ? 'verified' : 'pending');

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
      'other_intentions': otherIntentions?.trim().isEmpty ?? true ? null : otherIntentions!.trim(),
      'stipend_amount': stipendAmount,
      'payment_method': paymentMethod,
      'payment_status': paymentStatus,
      'gcash_reference_no': gcashReferenceNo?.trim().isEmpty ?? true ? null : gcashReferenceNo!.trim(),
      'intention_status': initialStatus,
      'remarks': remarks?.trim().isEmpty ?? true ? null : remarks!.trim(),
    };

    final response = await _client
        .from('mass_intentions')
        .insert(payload)
        .select()
        .single();

    return MassIntentionModel.fromMap(response);
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

    final bool isParishioner = AuthService.currentUser?.userRole.toLowerCase() == 'user';
    final targetStatus = isParishioner ? 'pending' : 'confirmed';

    final now = DateTime.now();
    final dateStamp =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final auditLog =
        '[Rescheduled on $dateStamp]: Moved from $previousDate ($previousTime) to $newDate ($newMassTime). Reason: $reason';

    final updatedRemarks = (previousRemarks == null || previousRemarks.trim().isEmpty)
        ? auditLog
        : '$previousRemarks\n$auditLog';

    await _client.from('mass_intentions').update({
      'scheduled_date': newDate,
      'mass_time': newMassTime,
      'intention_status': targetStatus,
      'remarks': updatedRemarks,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('intention_id', intentionId);
  }

  /// Update Mass Intention status
  static Future<void> updateStatus(String intentionId, String newStatus) async {
    await _client.from('mass_intentions').update({
      'intention_status': newStatus.toLowerCase(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('intention_id', intentionId);
  }

  /// Generates sequential Intention ID: INT-YY-XXXX
  static Future<String> _generateIntentionId() async {
    final now = DateTime.now();
    final yearSuffix = (now.year % 100).toString().padLeft(2, '0');

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

    final timestampSeq = (now.millisecondsSinceEpoch ~/ 100 % 9000 + 1000).toString();
    return 'INT-$yearSuffix-$timestampSeq';
  }
}