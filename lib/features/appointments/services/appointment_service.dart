import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/services/auth_service.dart';
import '../models/appointment_model.dart';
import 'liturgical_calendar_service.dart';

class AppointmentService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Converts time strings ("10:00:00", "10:00", "10:00:00+00") to minutes from midnight (0–1439)
  static int _timeToMinutes(String timeStr) {
    try {
      final clean = timeStr.trim().split('+')[0].split('.')[0].trim();
      final parts = clean.split(':');
      if (parts.length >= 2) {
        final h = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        return h * 60 + m;
      }
    } catch (_) {}
    return 0;
  }

  /// Formats time strings to 12-hour AM/PM format
  static String formatTime12Hour(String timeStr) {
    try {
      final clean = timeStr.trim().split('+')[0].split('.')[0].trim();
      final parts = clean.split(':');
      int hour = int.parse(parts[0]);
      int minute = int.parse(parts[1]);
      final period = hour >= 12 ? 'PM' : 'AM';
      final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      return '${hour12.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
    } catch (_) {
      return timeStr;
    }
  }

  /// Converts minutes from midnight back into a TimeOfDay
  static TimeOfDay minutesToTimeOfDay(int totalMinutes) {
    final h = (totalMinutes ~/ 60) % 24;
    final m = totalMinutes % 60;
    return TimeOfDay(hour: h, minute: m);
  }

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

  /// Checks if the same requester already has an active booking on the target date
  static Future<String?> checkDuplicateRequester({
    required String requesterName,
    required String date,
    String? excludeAppointmentId,
  }) async {
    final cleanName = requesterName.trim().toLowerCase();
    if (cleanName.length < 4) return null;

    final parsedDate = DateTime.tryParse(date);
    final cleanDate = parsedDate != null
        ? '${parsedDate.year}-${parsedDate.month.toString().padLeft(2, '0')}-${parsedDate.day.toString().padLeft(2, '0')}'
        : date.trim();

    var query = _client
        .from('appointments')
        .select('appointment_id, service_type, requester_name, requested_time, end_time')
        .eq('requested_date', cleanDate)
        .neq('appointment_status', 'cancelled');

    if (excludeAppointmentId != null) {
      query = query.neq('appointment_id', excludeAppointmentId);
    }

    final bookings = await query;
    for (final b in bookings) {
      final existingName = b['requester_name'].toString().trim().toLowerCase();
      if (existingName == cleanName) {
        final service = b['service_type'];
        final time = '${formatTime12Hour(b['requested_time'].toString())} – ${formatTime12Hour(b['end_time'].toString())}';
        return 'Duplicate Booking Notice: "$requesterName" already has an active booking for "$service" on this date ($time).';
      }
    }
    return null;
  }

  /// Non-throwing silent conflict checker used for live UI validation
  static Future<String?> checkScheduleConflictSilent({
    required String date,       // YYYY-MM-DD
    required String startTime,  // HH:mm:ss
    required String endTime,    // HH:mm:ss
    required String venue,
    required String officiant,
    String? excludeAppointmentId,
  }) async {
    try {
      await checkScheduleConflict(
        date: date,
        startTime: startTime,
        endTime: endTime,
        venue: venue,
        officiant: officiant,
        excludeAppointmentId: excludeAppointmentId,
      );
      return null; // Slot is free and valid!
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  /// Finds the earliest non-conflicting time slot for a given day and service duration
  static Future<Map<String, TimeOfDay>?> findNextAvailableSlot({
    required String date,
    required int durationMinutes,
    required String venue,
    required String officiant,
    required TimeOfDay preferredStartTime,
    String? excludeAppointmentId,
  }) async {
    final parsedDate = DateTime.tryParse(date);
    if (parsedDate == null) return null;

    if (parsedDate.weekday == DateTime.monday || LiturgicalCalendarService.isDateBlockedSync(parsedDate)) {
      return null;
    }

    final cleanDate = '${parsedDate.year}-${parsedDate.month.toString().padLeft(2, '0')}-${parsedDate.day.toString().padLeft(2, '0')}';

    var query = _client
        .from('appointments')
        .select('appointment_id, requested_time, end_time')
        .eq('requested_date', cleanDate)
        .neq('appointment_status', 'cancelled');

    if (excludeAppointmentId != null) {
      query = query.neq('appointment_id', excludeAppointmentId);
    }

    final activeBookings = await query;
    final List<Map<String, int>> bookedIntervals = [];

    for (final b in activeBookings) {
      bookedIntervals.add({
        'start': _timeToMinutes(b['requested_time'].toString()),
        'end': _timeToMinutes(b['end_time'].toString()),
      });
    }

    bookedIntervals.sort((a, b) => a['start']!.compareTo(b['start']!));

    const int dayStartMin = 360;  // 06:00 AM
    const int dayEndMin = 1140;   // 07:00 PM

    int candidateStart = preferredStartTime.hour * 60 + preferredStartTime.minute;
    if (candidateStart < dayStartMin) candidateStart = dayStartMin;

    Map<String, TimeOfDay>? slot = _scanForFreeSlot(
      candidateStart: candidateStart,
      limitMin: dayEndMin,
      durationMinutes: durationMinutes,
      bookedIntervals: bookedIntervals,
    );

    if (slot == null && candidateStart > dayStartMin) {
      slot = _scanForFreeSlot(
        candidateStart: dayStartMin,
        limitMin: candidateStart,
        durationMinutes: durationMinutes,
        bookedIntervals: bookedIntervals,
      );
    }

    return slot;
  }

  static Map<String, TimeOfDay>? _scanForFreeSlot({
    required int candidateStart,
    required int limitMin,
    required int durationMinutes,
    required List<Map<String, int>> bookedIntervals,
  }) {
    int current = candidateStart;

    while (current + durationMinutes <= limitMin) {
      final int candEnd = current + durationMinutes;

      Map<String, int>? collision;
      for (final b in bookedIntervals) {
        if (current < b['end']! && candEnd > b['start']!) {
          collision = b;
          break;
        }
      }

      if (collision == null) {
        return {
          'start': minutesToTimeOfDay(current),
          'end': minutesToTimeOfDay(candEnd),
        };
      } else {
        current = collision['end']!;
      }
    }
    return null;
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
    final newStartMinutes = _timeToMinutes(startTime);
    final newEndMinutes = _timeToMinutes(endTime);

    if (newStartMinutes < 360 || newEndMinutes > 1140) {
      throw 'Outside Operating Hours: Parish services must be scheduled between 6:00 AM and 7:00 PM.';
    }

    // 4. Clean normalized date (YYYY-MM-DD)
    final cleanDate = parsedDate != null
        ? '${parsedDate.year}-${parsedDate.month.toString().padLeft(2, '0')}-${parsedDate.day.toString().padLeft(2, '0')}'
        : date.trim();

    // 5. Query all active bookings for this date
    var query = _client
        .from('appointments')
        .select('appointment_id, service_type, venue, officiant_name, requested_time, end_time, requester_name')
        .eq('requested_date', cleanDate)
        .neq('appointment_status', 'cancelled');

    if (excludeAppointmentId != null) {
      query = query.neq('appointment_id', excludeAppointmentId);
    }

    final activeBookings = await query;

    for (final booking in activeBookings) {
      final existingStartStr = booking['requested_time'].toString();
      final existingEndStr = booking['end_time'].toString();
      final existingVenue = booking['venue'].toString();
      final existingOfficiant = booking['officiant_name'].toString();
      final service = booking['service_type'].toString();
      final requester = booking['requester_name'].toString();

      final existingStartMinutes = _timeToMinutes(existingStartStr);
      final existingEndMinutes = _timeToMinutes(existingEndStr);

      final bool isOverlapping = (newStartMinutes < existingEndMinutes) &&
          (newEndMinutes > existingStartMinutes);

      if (isOverlapping) {
        final formattedExistStart = formatTime12Hour(existingStartStr);
        final formattedExistEnd = formatTime12Hour(existingEndStr);
        final formattedNewStart = formatTime12Hour(startTime);
        final formattedNewEnd = formatTime12Hour(endTime);

        if (existingVenue.toLowerCase() == venue.toLowerCase()) {
          throw 'Schedule Conflict: Venue "$venue" is already booked for "$service" ($requester) from $formattedExistStart to $formattedExistEnd. Your requested window ($formattedNewStart – $formattedNewEnd) overlaps with it.';
        }

        if (existingOfficiant.toLowerCase() == officiant.toLowerCase()) {
          throw 'Clergy Conflict: $officiant is already scheduled to preside over "$service" from $formattedExistStart to $formattedExistEnd. Your requested window ($formattedNewStart – $formattedNewEnd) overlaps with it.';
        }

        throw 'Schedule Conflict: An appointment ("$service" - $requester) is already scheduled on this day from $formattedExistStart to $formattedExistEnd. Time windows cannot overlap on the parish schedule.';
      }
    }
  }

  /// Dedicated Rescheduling Method with Liturgical & Minute-based Collision Checking
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
    final newStartMinutes = _timeToMinutes(newStartTime);
    final newEndMinutes = _timeToMinutes(newEndTime);

    if (newStartMinutes >= newEndMinutes) {
      throw 'End Time must be later than Start Time.';
    }

    await checkScheduleConflict(
      date: newDate,
      startTime: newStartTime,
      endTime: newEndTime,
      venue: venue,
      officiant: officiant,
      excludeAppointmentId: appointmentId,
    );

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

    final startMinutes = _timeToMinutes(startTime);
    final endMinutes = _timeToMinutes(endTime);

    if (startMinutes >= endMinutes) {
      throw 'End Time must be later than Start Time.';
    }

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