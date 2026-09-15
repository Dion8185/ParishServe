import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/services/auth_service.dart';
import '../models/appointment_model.dart';
import 'liturgical_calendar_service.dart';

class AppointmentService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Fetch all appointments ordered by scheduled date and time
  static Future<List<AppointmentModel>> getAppointments({String? statusFilter}) async {
    var query = _client.from('appointments').select();

    if (statusFilter != null && statusFilter.toLowerCase() != 'all') {
      query = query.eq('appointment_status', statusFilter.toLowerCase());
    }

    final response = await query
        .order('requested_date', ascending: true)
        .order('requested_time', ascending: true);

    return (response as List)
        .map((row) => AppointmentModel.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Automated Conflict Checking, Operating Hours & Liturgical Law Engine
  static Future<void> checkScheduleConflict({
    required String date,       // YYYY-MM-DD
    required String startTime,  // HH:mm:ss
    required String endTime,    // HH:mm:ss
    required String venue,
    required String officiant,
    String? excludeAppointmentId,
  }) async {
    final parsedDate = DateTime.tryParse(date);
    if (parsedDate != null) {
      // 1. PARAMOUNT RULE: Mondays are strictly forbidden (Clergy Rest Day)
      if (parsedDate.weekday == DateTime.monday) {
        throw 'Paramount Rule Violation: Mondays are designated Clergy Rest Days and Parish Office closure. No services can be scheduled on Mondays.';
      }

      // 2. LITURGICAL LAW RULE: Cannot book on Solemnities & Major Catholic Liturgical Celebrations
      final isBlocked = await LiturgicalCalendarService.isDateBlocked(parsedDate);
      if (isBlocked) {
        final celebration = await LiturgicalCalendarService.getBlockingCelebration(parsedDate);
        final name = celebration?.name ?? 'Catholic Liturgical Celebration';
        throw 'Liturgical Law Prohibition: Appointments cannot be scheduled on this day due to: "$name". The parish clergy and altar are dedicated to the solemn liturgy.';
      }
    }

    // 3. OPERATING HOURS RULE: 06:00 AM to 07:00 PM
    if (startTime.compareTo('06:00:00') < 0 || endTime.compareTo('19:00:00') > 0) {
      throw 'Outside Operating Hours: Parish services must be scheduled between 6:00 AM and 7:00 PM.';
    }

    // 4. Collision Check Query
    var query = _client
        .from('appointments')
        .select('appointment_id, service_type, venue, officiant_name, requested_time, end_time')
        .eq('requested_date', date)
        .neq('appointment_status', 'cancelled');

    if (excludeAppointmentId != null) {
      query = query.neq('appointment_id', excludeAppointmentId);
    }

    final activeBookings = await query;

    for (final booking in activeBookings) {
      final existingStart = booking['requested_time'].toString();
      final existingEnd = booking['end_time'].toString();
      final existingVenue = booking['venue'].toString();
      final existingOfficiant = booking['officiant_name'].toString();
      final service = booking['service_type'].toString();

      final bool isOverlapping = (startTime.compareTo(existingEnd) < 0) &&
          (endTime.compareTo(existingStart) > 0);

      if (isOverlapping) {
        if (existingVenue.toLowerCase() == venue.toLowerCase()) {
          throw 'Schedule Conflict: "$venue" is already booked for "$service" between $existingStart and $existingEnd.';
        }
        if (existingOfficiant.toLowerCase() == officiant.toLowerCase()) {
          throw 'Clergy Conflict: $officiant is already scheduled for "$service" between $existingStart and $existingEnd.';
        }
      }
    }
  }

  /// Dedicated Rescheduling Method with Liturgical Checking
  static Future<void> rescheduleAppointment({
    required String appointmentId,
    required String newDate,      // YYYY-MM-DD
    required String newStartTime, // HH:mm:ss
    required String newEndTime,   // HH:mm:ss
    required String venue,
    required String officiant,
    required String reason,
    String? previousRemarks,
    String? previousDate,
    String? previousTimeRange,
  }) async {
    if (newStartTime.compareTo(newEndTime) >= 0) {
      throw 'End Time must be later than Start Time.';
    }

    // Runs Monday check, Liturgical Solemnity blocking, and collision check
    await checkScheduleConflict(
      date: newDate,
      startTime: newStartTime,
      endTime: newEndTime,
      venue: venue,
      officiant: officiant,
      excludeAppointmentId: appointmentId,
    );

    // Tuesday rule: status becomes pending if moved to Tuesday
    final parsedDate = DateTime.tryParse(newDate);
    final isTuesday = parsedDate != null && parsedDate.weekday == DateTime.tuesday;
    final targetStatus = isTuesday ? 'pending' : 'rescheduled';

    final now = DateTime.now();
    final dateStamp = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final tuesdayNote = isTuesday ? ' [NOTE: Moved to Tuesday - Awaiting Parish Priest Approval]' : '';
    final auditLog = '[Rescheduled on $dateStamp]$tuesdayNote: Moved from $previousDate ($previousTimeRange) to $newDate ($newStartTime-$newEndTime). Reason: $reason';

    final updatedRemarks = (previousRemarks == null || previousRemarks.trim().isEmpty)
        ? auditLog
        : '$previousRemarks\n$auditLog';

    await _client.from('appointments').update({
      'requested_date': newDate,
      'requested_time': newStartTime,
      'end_time': newEndTime,
      'venue': venue,
      'officiant_name': officiant,
      'appointment_status': targetStatus,
      'appointment_remarks': updatedRemarks,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('appointment_id', appointmentId);
  }

  /// Create and register a complete appointment with liturgical & rest day validation
  static Future<AppointmentModel> createAppointment({
    required String serviceType,
    required String requesterName,
    required String contactNumber,
    String? email,
    required String date,      // YYYY-MM-DD
    required String startTime, // HH:mm:ss
    required String endTime,   // HH:mm:ss
    required String venue,
    required String officiant,
    String? remarks,
  }) async {
    if (requesterName.trim().isEmpty) throw 'Requester Name is required.';
    if (contactNumber.trim().isEmpty) throw 'Contact Number is required.';
    if (serviceType.trim().isEmpty) throw 'Service Type is required.';
    if (startTime.compareTo(endTime) >= 0) {
      throw 'End Time must be later than Start Time.';
    }

    // Runs Monday, Liturgical Solemnity, and Venue/Priest conflict checks
    await checkScheduleConflict(
      date: date,
      startTime: startTime,
      endTime: endTime,
      venue: venue,
      officiant: officiant,
    );

    final appointmentId = await _generateAppointmentId();

    String? encoderId = AuthService.currentUser?.userId;
    if (encoderId == null || encoderId.isEmpty) {
      final defaultUser = await _client
          .from('users')
          .select('user_id')
          .eq('account_status', true)
          .limit(1)
          .maybeSingle();
      encoderId = defaultUser?['user_id'] ?? 'S26-0003';
    }

    // Tuesday Rule: Auto-assign 'pending' status for Priest review
    final parsedDate = DateTime.tryParse(date);
    final isTuesday = parsedDate != null && parsedDate.weekday == DateTime.tuesday;
    final initialStatus = isTuesday ? 'pending' : 'confirmed';

    final finalRemarks = isTuesday
        ? (remarks == null || remarks.trim().isEmpty
        ? '[Awaiting Parish Priest Tuesday Approval]'
        : '$remarks\n[Awaiting Parish Priest Tuesday Approval]')
        : remarks;

    final payload = {
      'appointment_id': appointmentId,
      'service_type': serviceType,
      'requester_name': requesterName.trim(),
      'contact_number': contactNumber.trim(),
      'email': email?.trim().isEmpty ?? true ? null : email!.trim(),
      'requested_date': date,
      'requested_time': startTime,
      'end_time': endTime,
      'venue': venue,
      'officiant_name': officiant,
      'appointment_status': initialStatus,
      'appointment_remarks': finalRemarks?.trim().isEmpty ?? true ? null : finalRemarks!.trim(),
    };

    final response = await _client
        .from('appointments')
        .insert(payload)
        .select()
        .single();

    return AppointmentModel.fromMap(response);
  }

  /// Update appointment status
  static Future<void> updateStatus(String appointmentId, String newStatus) async {
    await _client
        .from('appointments')
        .update({
      'appointment_status': newStatus.toLowerCase(),
      'updated_at': DateTime.now().toIso8601String(),
    })
        .eq('appointment_id', appointmentId);
  }

  /// Generates sequential Appointment ID: APT-YY-XXXX
  static Future<String> _generateAppointmentId() async {
    final now = DateTime.now();
    final yearSuffix = (now.year % 100).toString().padLeft(2, '0');

    try {
      final records = await _client
          .from('appointments')
          .select('appointment_id')
          .like('appointment_id', 'APT-$yearSuffix-%');

      int highest = 0;
      for (final item in records) {
        final id = item['appointment_id']?.toString() ?? '';
        final parts = id.split('-');
        if (parts.length >= 3) {
          final seq = int.tryParse(parts[2]);
          if (seq != null && seq > highest) {
            highest = seq;
          }
        }
      }

      final nextSeq = (highest + 1).toString().padLeft(4, '0');
      return 'APT-$yearSuffix-$nextSeq';
    } catch (_) {
      final timestampSeq = (now.millisecondsSinceEpoch % 10000).toString().padLeft(4, '0');
      return 'APT-$yearSuffix-$timestampSeq';
    }
  }
}