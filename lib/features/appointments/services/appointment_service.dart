import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/services/auth_service.dart';
import '../models/appointment_model.dart';
import 'liturgical_calendar_service.dart';

class AppointmentService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Operating Hours Constraints: 9:00 AM (540 min) to 5:00 PM (1020 min)
  static const int operatingDayStartMin = 540; // 09:00 AM
  static const int operatingDayEndMin = 1020;  // 05:00 PM

  /// Converts time strings ("10:00:00", "10:00") to minutes from midnight (0–1439)
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

  /// Fetch all appointments subject to role constraints (or filtered by specific user)
  static Future<List<AppointmentModel>> getAppointments({
    String? statusFilter,
    String? userIdFilter,
  }) async {
    var query = _client.from('appointments').select();

    if (userIdFilter != null && userIdFilter.trim().isNotEmpty) {
      query = query.eq('created_by', userIdFilter.trim());
    }

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

  /// Fetch appointments belonging exclusively to the currently authenticated user
  static Future<List<AppointmentModel>> getMyAppointments() async {
    final user = AuthService.currentUser;
    if (user == null) return [];

    return getAppointments(userIdFilter: user.userId);
  }

  /// Uploads valid ID document bytes to private Supabase Storage bucket
  static Future<String?> uploadIdDocument({
    required String appointmentId,
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    try {
      final cleanExtension = fileName.contains('.') ? fileName.split('.').last : 'jpg';
      final filePath = '$appointmentId/valid_id_${DateTime.now().millisecondsSinceEpoch}.$cleanExtension';

      await _client.storage.from('appointment-documents').uploadBinary(
        filePath,
        fileBytes,
        fileOptions: FileOptions(
          contentType: cleanExtension == 'pdf' ? 'application/pdf' : 'image/$cleanExtension',
          upsert: true,
        ),
      );

      return filePath;
    } catch (e) {
      debugPrint('Error uploading ID document to Supabase Storage: $e');
      return null;
    }
  }

  /// Generates a signed URL or public URL for staff to view ID images
  static Future<String?> getSignedIdDocumentUrl(String filePath) async {
    try {
      var cleanPath = filePath.trim();

      if (cleanPath.startsWith('http://') || cleanPath.startsWith('https://')) {
        return cleanPath;
      }

      if (cleanPath.startsWith('/')) {
        cleanPath = cleanPath.substring(1);
      }
      if (cleanPath.startsWith('appointment-documents/')) {
        cleanPath = cleanPath.replaceFirst('appointment-documents/', '');
      }

      final signedUrl = await _client.storage
          .from('appointment-documents')
          .createSignedUrl(cleanPath, 60 * 60);

      return signedUrl;
    } catch (e) {
      debugPrint('Signed URL generation notice: $e. Falling back to public URL...');
      try {
        var cleanPath = filePath.trim();
        if (cleanPath.startsWith('/')) cleanPath = cleanPath.substring(1);
        if (cleanPath.startsWith('appointment-documents/')) {
          cleanPath = cleanPath.replaceFirst('appointment-documents/', '');
        }
        return _client.storage.from('appointment-documents').getPublicUrl(cleanPath);
      } catch (_) {
        return null;
      }
    }
  }

  /// Checks if the same requester already has an active booking on the target date
  static Future<String?> checkDuplicateRequester({
    required String requesterName,
    required String date,
    String? serviceType,
    String? excludeAppointmentId,
  }) async {
    final cleanName = requesterName.trim().toLowerCase();
    if (cleanName.length < 3) return null;

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
      final existingService = b['service_type'].toString().trim();

      if (existingName == cleanName) {
        final time =
            '${formatTime12Hour(b['requested_time'].toString())} – ${formatTime12Hour(b['end_time'].toString())}';

        if (serviceType != null &&
            serviceType.toLowerCase().contains('baptism') &&
            existingService.toLowerCase().contains('baptism')) {
          return 'Duplicate Baptism Booking: You already have a Community Baptism booked for this date ($time). A requester may only book one slot per date.';
        }

        return 'Duplicate Booking Notice: "$requesterName" already has an active booking for "$existingService" on this date ($time).';
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
    String? serviceType,
    String? excludeAppointmentId,
  }) async {
    try {
      await checkScheduleConflict(
        date: date,
        startTime: startTime,
        endTime: endTime,
        venue: venue,
        officiant: officiant,
        serviceType: serviceType,
        excludeAppointmentId: excludeAppointmentId,
      );
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  /// Finds the earliest non-conflicting time slot for a given day within 9:00 AM – 5:00 PM
  static Future<Map<String, TimeOfDay>?> findNextAvailableSlot({
    required String date,
    required int durationMinutes,
    required String venue,
    required String officiant,
    required TimeOfDay preferredStartTime,
    String? serviceType,
    String? excludeAppointmentId,
  }) async {
    final parsedDate = DateTime.tryParse(date);
    if (parsedDate == null) return null;

    if (parsedDate.weekday == DateTime.monday ||
        LiturgicalCalendarService.isDateBlockedSync(parsedDate)) {
      return null;
    }

    // Community Baptism is strictly locked to 11:00 AM on Weekends
    if (serviceType != null && serviceType.toLowerCase().contains('community baptism')) {
      return {
        'start': const TimeOfDay(hour: 11, minute: 0),
        'end': const TimeOfDay(hour: 12, minute: 0),
      };
    }

    final cleanDate =
        '${parsedDate.year}-${parsedDate.month.toString().padLeft(2, '0')}-${parsedDate.day.toString().padLeft(2, '0')}';

    var query = _client
        .from('appointments')
        .select('appointment_id, service_type, requested_time, end_time')
        .eq('requested_date', cleanDate)
        .neq('appointment_status', 'cancelled');

    if (excludeAppointmentId != null) {
      query = query.neq('appointment_id', excludeAppointmentId);
    }

    final activeBookings = await query;
    final List<Map<String, int>> bookedIntervals = [];

    for (final b in activeBookings) {
      final sType = (b['service_type'] ?? '').toString().toLowerCase();
      // Ignore other community baptisms since they are batched
      if (sType.contains('community baptism')) continue;

      bookedIntervals.add({
        'start': _timeToMinutes(b['requested_time'].toString()),
        'end': _timeToMinutes(b['end_time'].toString()),
      });
    }

    bookedIntervals.sort((a, b) => a['start']!.compareTo(b['start']!));

    int candidateStart = preferredStartTime.hour * 60 + preferredStartTime.minute;
    if (candidateStart < operatingDayStartMin) candidateStart = operatingDayStartMin;

    Map<String, TimeOfDay>? slot = _scanForFreeSlot(
      candidateStart: candidateStart,
      limitMin: operatingDayEndMin,
      durationMinutes: durationMinutes,
      bookedIntervals: bookedIntervals,
    );

    if (slot == null && candidateStart > operatingDayStartMin) {
      slot = _scanForFreeSlot(
        candidateStart: operatingDayStartMin,
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

  /// Automated Conflict Checking, Operating Hours (9 AM – 5 PM), and Batch Baptism Logic
  static Future<void> checkScheduleConflict({
    required String date,       // YYYY-MM-DD
    required String startTime,  // HH:mm:ss
    required String endTime,    // HH:mm:ss
    required String venue,
    required String officiant,
    String? serviceType,
    String? excludeAppointmentId,
  }) async {
    final parsedDate = DateTime.tryParse(date);
    if (parsedDate != null) {
      // 1. Mondays are strictly forbidden (Clergy Rest Day)
      if (parsedDate.weekday == DateTime.monday) {
        throw 'Paramount Rule Violation: Mondays are designated Clergy Rest Days and Parish Office closure. No appointments can be scheduled on Mondays.';
      }

      // 2. Liturgical Law Prohibition
      final isBlocked = await LiturgicalCalendarService.isDateBlocked(parsedDate);
      if (isBlocked) {
        final celebration = await LiturgicalCalendarService.getBlockingCelebration(parsedDate);
        final name = celebration?.name ?? 'Catholic Liturgical Celebration';
        throw 'Liturgical Law Prohibition: Appointments cannot be scheduled on this day due to: "$name". The parish clergy and altar are dedicated to the solemn liturgy.';
      }
    }

    final newStartMinutes = _timeToMinutes(startTime);
    final newEndMinutes = _timeToMinutes(endTime);
    final bool isCommunityBaptism = serviceType != null &&
        serviceType.toLowerCase().contains('community baptism');

    // 3. Operating Hours Enforcement:
    // Community Baptism is strictly locked at 11:00 AM on Weekends
    if (isCommunityBaptism) {
      if (parsedDate != null &&
          parsedDate.weekday != DateTime.saturday &&
          parsedDate.weekday != DateTime.sunday) {
        throw 'Schedule Restriction: Community Baptisms are strictly held on Weekends (Saturday & Sunday).';
      }
      if (!startTime.startsWith('11:00')) {
        throw 'Schedule Restriction: Community Baptisms are strictly scheduled starting at 11:00 AM.';
      }
    } else {
      // All other sacramental services must fall within 9:00 AM to 5:00 PM
      if (newStartMinutes < operatingDayStartMin || newEndMinutes > operatingDayEndMin) {
        throw 'Outside Parish Office Operating Hours: Parish services must be scheduled between 9:00 AM and 5:00 PM.';
      }
    }

    final cleanDate = parsedDate != null
        ? '${parsedDate.year}-${parsedDate.month.toString().padLeft(2, '0')}-${parsedDate.day.toString().padLeft(2, '0')}'
        : date.trim();

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
      final existingService = booking['service_type'].toString();
      final existingRequester = booking['requester_name'].toString();

      final existingStartMinutes = _timeToMinutes(existingStartStr);
      final existingEndMinutes = _timeToMinutes(existingEndStr);

      final bool isOverlapping = (newStartMinutes < existingEndMinutes) &&
          (newEndMinutes > existingStartMinutes);

      if (isOverlapping) {
        final bool existingIsCommunityBaptism =
        existingService.toLowerCase().contains('community baptism');

        // BAPTISM BATCH ALLOWANCE: If both are community baptisms at 11:00 AM, allow same time & venue
        if (isCommunityBaptism && existingIsCommunityBaptism) {
          continue; // Allowed: Batch baptism ceremony
        }

        final formattedExistStart = formatTime12Hour(existingStartStr);
        final formattedExistEnd = formatTime12Hour(existingEndStr);
        final formattedNewStart = formatTime12Hour(startTime);
        final formattedNewEnd = formatTime12Hour(endTime);

        if (existingVenue.toLowerCase() == venue.toLowerCase()) {
          throw 'Venue Conflict: Venue "$venue" is already booked for "$existingService" ($existingRequester) from $formattedExistStart to $formattedExistEnd. Your requested window ($formattedNewStart – $formattedNewEnd) overlaps with it.';
        }

        if (existingOfficiant.toLowerCase() == officiant.toLowerCase()) {
          throw 'Clergy Conflict: $officiant is already scheduled to preside over "$existingService" from $formattedExistStart to $formattedExistEnd. Time windows cannot overlap.';
        }

        throw 'Schedule Conflict: An appointment ("$existingService" - $existingRequester) is already scheduled on this day from $formattedExistStart to $formattedExistEnd.';
      }
    }
  }

  /// Rescheduling Method with Role-Aware Re-Approval & Operating Bounds
  static Future<void> rescheduleAppointment({
    required String appointmentId,
    required String newDate,      // YYYY-MM-DD
    required String newStartTime, // HH:mm:ss
    required String newEndTime,   // HH:mm:ss
    required String venue,
    required String officiant,
    required String reason,
    String? serviceType,
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
      serviceType: serviceType,
      excludeAppointmentId: appointmentId,
    );

    final bool isParishioner = AuthService.currentUser?.userRole.toLowerCase() == 'user';
    final parsedDate = DateTime.tryParse(newDate);
    final isTuesday = parsedDate != null && parsedDate.weekday == DateTime.tuesday;
    final targetStatus = (isTuesday || isParishioner) ? 'pending' : 'rescheduled';

    final now = DateTime.now();
    final dateStamp =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final tuesdayNote = isTuesday ? ' [NOTE: Moved to Tuesday - Awaiting Parish Priest Approval]' : '';
    final parishionerNote = isParishioner ? ' [Parishioner Online Reschedule Request - Awaiting Staff Re-Approval]' : '';
    final auditLog =
        '[Rescheduled on $dateStamp]$tuesdayNote$parishionerNote: Moved from $previousDate ($previousTimeRange) to $newDate ($newStartTime-$newEndTime). Reason: $reason';

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
      'reminder_24h_sent': false, // Reset reminder flags for new schedule
      'reminder_12h_sent': false,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('appointment_id', appointmentId);
  }

  /// Create and register an appointment with collision-proof retry mechanism
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
    String? idType,
    String? idNumber,
    String? idDocumentUrl,
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

    // Check single person booking limit
    final duplicateWarning = await checkDuplicateRequester(
      requesterName: requesterName,
      date: date,
      serviceType: serviceType,
    );
    if (duplicateWarning != null) {
      throw duplicateWarning;
    }

    await checkScheduleConflict(
      date: date,
      startTime: startTime,
      endTime: endTime,
      venue: venue,
      officiant: officiant,
      serviceType: serviceType,
    );

    final String? currentUserId = AuthService.currentUser?.userId;
    final bool isParishioner = AuthService.currentUser?.userRole.toLowerCase() == 'user';

    final parsedDate = DateTime.tryParse(date);
    final isTuesday = parsedDate != null && parsedDate.weekday == DateTime.tuesday;
    final String initialStatus = (isTuesday || isParishioner) ? 'pending' : 'confirmed';

    final String? finalRemarks = isTuesday
        ? (remarks == null || remarks.trim().isEmpty
        ? '[Awaiting Parish Priest Tuesday Approval]'
        : '$remarks\n[Awaiting Parish Priest Tuesday Approval]')
        : (isParishioner
        ? (remarks == null || remarks.trim().isEmpty
        ? '[Online Parishioner Booking - Awaiting Staff Clearance]'
        : '$remarks\n[Online Parishioner Booking - Awaiting Staff Clearance]')
        : remarks);

    // Collision-Proof Insert with retry for unique primary key constraint
    for (int attempt = 0; attempt < 4; attempt++) {
      final appointmentId = await _generateAppointmentId(attempt: attempt);

      final payload = {
        'appointment_id': appointmentId,
        'created_by': currentUserId,
        'service_type': serviceType,
        'requester_name': requesterName.trim(),
        'contact_number': contactNumber.trim(),
        'email': email?.trim().isEmpty ?? true ? null : email!.trim(),
        'requested_date': date,
        'requested_time': startTime,
        'end_time': endTime,
        'venue': venue,
        'officiant_name': officiant,
        'id_type': idType,
        'id_number': idNumber?.trim().isEmpty ?? true ? null : idNumber!.trim(),
        'id_document_url': idDocumentUrl,
        'is_id_verified': false,
        'appointment_status': initialStatus,
        'appointment_remarks': finalRemarks?.trim().isEmpty ?? true ? null : finalRemarks!.trim(),
      };

      try {
        final response = await _client
            .from('appointments')
            .insert(payload)
            .select()
            .single();

        return AppointmentModel.fromMap(response);
      } catch (e) {
        if (e is PostgrestException && e.code == '23505' && attempt < 3) {
          debugPrint('Duplicate appointment_id ($appointmentId) detected. Retrying with unique sequence...');
          continue;
        }
        rethrow;
      }
    }

    throw 'Could not generate a unique booking ID. Please try again.';
  }

  /// Update appointment status + triggers email notification only on FIRST transition to confirmed
  static Future<void> updateStatus(String appointmentId, String newStatus) async {
    final cleanStatus = newStatus.toLowerCase();

    // 1. Fetch current appointment record to inspect prior status
    final currentRecord = await _client
        .from('appointments')
        .select()
        .eq('appointment_id', appointmentId)
        .maybeSingle();

    if (currentRecord == null) {
      throw 'Appointment record not found.';
    }

    final priorStatus = (currentRecord['appointment_status'] ?? '').toString().toLowerCase();

    // Prevent duplicate re-approval if already confirmed
    if (priorStatus == 'confirmed' && cleanStatus == 'confirmed') {
      debugPrint('[AppointmentService] Appointment is already confirmed. Skipping duplicate status update and email dispatch.');
      return;
    }

    // 2. Auto-Purge Storage Cleanup on Completion (RA 10173 compliance)
    if (cleanStatus == 'completed') {
      try {
        final filePath = currentRecord['id_document_url']?.toString();
        if (filePath != null && filePath.isNotEmpty) {
          await _client.storage.from('appointment-documents').remove([filePath]);
          await _client
              .from('appointments')
              .update({'id_document_url': null})
              .eq('appointment_id', appointmentId);
        }
      } catch (e) {
        debugPrint('Non-blocking storage cleanup notice: $e');
      }
    }

    // 3. Update status in Database
    await _client.from('appointments').update({
      'appointment_status': cleanStatus,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('appointment_id', appointmentId);

    // 4. Automated Approval Email Trigger via Edge Function (Only when transitioning from pending/rescheduled -> confirmed)
    if (cleanStatus == 'confirmed' && priorStatus != 'confirmed') {
      try {
        if (currentRecord['email'] != null &&
            currentRecord['email'].toString().trim().isNotEmpty) {
          debugPrint('Dispatching single approval confirmation email to: ${currentRecord['email']}');

          await _client.functions.invoke(
            'send-booking-confirmation',
            body: {
              ...currentRecord,
              'appointment_status': 'confirmed',
            },
          );
        }
      } catch (e) {
        debugPrint('Non-blocking approval email notice: $e');
      }
    }
  }

  /// Update Valid ID verification state (Staff Secretariat action)
  static Future<void> updateIdVerification({
    required String appointmentId,
    required bool isVerified,
    String? notes,
  }) async {
    final staffId = AuthService.currentUser?.userId;

    await _client.from('appointments').update({
      'is_id_verified': isVerified,
      'id_verified_by': staffId,
      'id_verified_at': DateTime.now().toIso8601String(),
      'id_verification_notes': notes,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('appointment_id', appointmentId);
  }

  /// Generates sequential Appointment ID: APT-YY-XXXX with collision-proof fallback
  static Future<String> _generateAppointmentId({int attempt = 0}) async {
    final now = DateTime.now();
    final yearSuffix = (now.year % 100).toString().padLeft(2, '0');

    if (attempt > 0) {
      final uniqueRand = (now.microsecondsSinceEpoch % 90000 + 10000).toString();
      return 'APT-$yearSuffix-$uniqueRand';
    }

    try {
      final records = await _client
          .from('appointments')
          .select('appointment_id')
          .like('appointment_id', 'APT-$yearSuffix-%')
          .order('created_at', ascending: false)
          .limit(100);

      int highest = 0;
      for (final item in records) {
        final id = item['appointment_id']?.toString() ?? '';
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
        return 'APT-$yearSuffix-$nextSeq';
      }
    } catch (_) {}

    final timestampSeq = (now.millisecondsSinceEpoch ~/ 100 % 9000 + 1000).toString();
    return 'APT-$yearSuffix-$timestampSeq';
  }
}