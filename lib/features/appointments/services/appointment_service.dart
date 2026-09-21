import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/services/auth_service.dart';
import '../models/appointment_model.dart';
import 'liturgical_calendar_service.dart';

class AppointmentService {
  static final SupabaseClient _client = Supabase.instance.client;

  // --- Utility Methods ---
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

  static TimeOfDay minutesToTimeOfDay(int totalMinutes) {
    final h = (totalMinutes ~/ 60) % 24;
    final m = totalMinutes % 60;
    return TimeOfDay(hour: h, minute: m);
  }

  // --- Storage & ID Methods ---
  static Future<String?> uploadIdDocument({required String appointmentId, required Uint8List fileBytes, required String fileName}) async {
    try {
      final cleanExtension = fileName.contains('.') ? fileName.split('.').last : 'jpg';
      final filePath = '$appointmentId/valid_id_${DateTime.now().millisecondsSinceEpoch}.$cleanExtension';
      await _client.storage.from('appointment-documents').uploadBinary(
        filePath,
        fileBytes,
        fileOptions: FileOptions(contentType: cleanExtension == 'pdf' ? 'application/pdf' : 'image/$cleanExtension', upsert: true),
      );
      return filePath;
    } catch (e) {
      debugPrint('Error uploading ID document: $e');
      return null;
    }
  }

  static Future<String?> getSignedIdDocumentUrl(String filePath) async {
    try {
      return await _client.storage.from('appointment-documents').createSignedUrl(filePath, 60 * 15);
    } catch (e) {
      debugPrint('Error generating signed URL: $e');
      return null;
    }
  }

  // --- Appointment Logic ---
  static Future<List<AppointmentModel>> getAppointments({String? statusFilter}) async {
    var query = _client.from('appointments').select();
    if (statusFilter != null && statusFilter.toLowerCase() != 'all') {
      query = query.eq('appointment_status', statusFilter.toLowerCase());
    }
    final response = await query.order('requested_date', ascending: true).order('requested_time', ascending: true);
    return (response as List).map((row) => AppointmentModel.fromMap(row as Map<String, dynamic>)).toList();
  }

  static Future<String?> checkDuplicateRequester({required String requesterName, required String date, String? excludeAppointmentId}) async {
    final cleanName = requesterName.trim().toLowerCase();
    final parsedDate = DateTime.tryParse(date);
    final cleanDate = parsedDate != null ? '${parsedDate.year}-${parsedDate.month.toString().padLeft(2, '0')}-${parsedDate.day.toString().padLeft(2, '0')}' : date.trim();
    var query = _client.from('appointments').select('appointment_id, service_type, requester_name, requested_time, end_time').eq('requested_date', cleanDate).neq('appointment_status', 'cancelled');
    if (excludeAppointmentId != null) query = query.neq('appointment_id', excludeAppointmentId);
    final bookings = await query;
    for (final b in bookings) {
      if (b['requester_name'].toString().trim().toLowerCase() == cleanName) {
        return 'Duplicate Booking Notice: "$requesterName" already has a booking on this date.';
      }
    }
    return null;
  }

  static Future<String?> checkScheduleConflictSilent({required String date, required String startTime, required String endTime, required String venue, required String officiant, String? excludeAppointmentId}) async {
    try {
      await checkScheduleConflict(date: date, startTime: startTime, endTime: endTime, venue: venue, officiant: officiant, excludeAppointmentId: excludeAppointmentId);
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  static Future<Map<String, TimeOfDay>?> findNextAvailableSlot({required String date, required int durationMinutes, required String venue, required String officiant, required TimeOfDay preferredStartTime, String? excludeAppointmentId}) async {
    final parsedDate = DateTime.tryParse(date);
    if (parsedDate == null || parsedDate.weekday == DateTime.monday || LiturgicalCalendarService.isDateBlockedSync(parsedDate)) return null;
    final cleanDate = '${parsedDate.year}-${parsedDate.month.toString().padLeft(2, '0')}-${parsedDate.day.toString().padLeft(2, '0')}';
    var query = _client.from('appointments').select('requested_time, end_time').eq('requested_date', cleanDate).neq('appointment_status', 'cancelled');
    if (excludeAppointmentId != null) query = query.neq('appointment_id', excludeAppointmentId);
    final activeBookings = await query;
    final List<Map<String, int>> bookedIntervals = activeBookings.map((b) => {'start': _timeToMinutes(b['requested_time']), 'end': _timeToMinutes(b['end_time'])}).toList();
    bookedIntervals.sort((a, b) => a['start']!.compareTo(b['start']!));
    int candidateStart = preferredStartTime.hour * 60 + preferredStartTime.minute;
    if (candidateStart < 360) candidateStart = 360;
    return _scanForFreeSlot(candidateStart: candidateStart, limitMin: 1140, durationMinutes: durationMinutes, bookedIntervals: bookedIntervals);
  }

  static Map<String, TimeOfDay>? _scanForFreeSlot({required int candidateStart, required int limitMin, required int durationMinutes, required List<Map<String, int>> bookedIntervals}) {
    int current = candidateStart;
    while (current + durationMinutes <= limitMin) {
      int candEnd = current + durationMinutes;
      Map<String, int>? collision = bookedIntervals.cast<Map<String, int>?>().firstWhere((b) => current < b!['end']! && candEnd > b['start']!, orElse: () => null);
      if (collision == null) return {'start': minutesToTimeOfDay(current), 'end': minutesToTimeOfDay(candEnd)};
      current = collision['end']!;
    }
    return null;
  }

  static Future<void> checkScheduleConflict({required String date, required String startTime, required String endTime, required String venue, required String officiant, String? excludeAppointmentId}) async {
    final parsedDate = DateTime.tryParse(date);
    if (parsedDate != null) {
      if (parsedDate.weekday == DateTime.monday) throw 'Mondays are designated Clergy Rest Days.';
      if (await LiturgicalCalendarService.isDateBlocked(parsedDate)) throw 'Appointments restricted due to liturgical solemnity.';
    }
    final newStart = _timeToMinutes(startTime);
    final newEnd = _timeToMinutes(endTime);
    if (newStart < 360 || newEnd > 1140) throw 'Outside Operating Hours (6 AM - 7 PM).';
    final cleanDate = parsedDate != null ? '${parsedDate.year}-${parsedDate.month.toString().padLeft(2, '0')}-${parsedDate.day.toString().padLeft(2, '0')}' : date.trim();
    var query = _client.from('appointments').select('*').eq('requested_date', cleanDate).neq('appointment_status', 'cancelled');
    if (excludeAppointmentId != null) query = query.neq('appointment_id', excludeAppointmentId);
    final activeBookings = await query;
    for (var b in activeBookings) {
      if ((newStart < _timeToMinutes(b['end_time'])) && (newEnd > _timeToMinutes(b['requested_time']))) {
        throw 'Schedule Conflict: This time window overlaps with existing services.';
      }
    }
  }

  static Future<void> rescheduleAppointment({
    required String appointmentId,
    required String newDate,
    required String newStartTime,
    required String newEndTime,
    required String venue,
    required String officiant,
    required String reason,
    String? previousRemarks,
    String? previousDate,
    String? previousTimeRange,
  }) async {
    final newStartMinutes = _timeToMinutes(newStartTime);
    final newEndMinutes = _timeToMinutes(newEndTime);
    if (newStartMinutes >= newEndMinutes) throw 'End Time must be later than Start Time.';
    await checkScheduleConflict(date: newDate, startTime: newStartTime, endTime: newEndTime, venue: venue, officiant: officiant, excludeAppointmentId: appointmentId);
    final parsedDate = DateTime.tryParse(newDate);
    final isTuesday = parsedDate != null && parsedDate.weekday == DateTime.tuesday;
    final targetStatus = isTuesday ? 'pending' : 'rescheduled';
    final now = DateTime.now();
    final dateStamp = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final auditLog = '[Rescheduled on $dateStamp]: Moved from $previousDate ($previousTimeRange) to $newDate ($newStartTime-$newEndTime). Reason: $reason';
    final updatedRemarks = (previousRemarks == null || previousRemarks.trim().isEmpty) ? auditLog : '$previousRemarks\n$auditLog';
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

  static Future<AppointmentModel> createAppointment({
    required String serviceType,
    required String requesterName,
    required String contactNumber,
    String? email,
    required String date,
    required String startTime,
    required String endTime,
    required String venue,
    required String officiant,
    String? idType,
    String? idNumber,
    String? idDocumentUrl,
    String? remarks,
  }) async {
    await checkScheduleConflict(date: date, startTime: startTime, endTime: endTime, venue: venue, officiant: officiant);
    final appointmentId = await _generateAppointmentId();
    final String? currentUserId = AuthService.currentUser?.userId;
    final bool isParishioner = AuthService.currentUser?.userRole.toLowerCase() == 'user';
    final isTuesday = DateTime.tryParse(date)?.weekday == DateTime.tuesday;
    final initialStatus = (isTuesday || isParishioner) ? 'pending' : 'confirmed';

    final payload = {
      'appointment_id': appointmentId,
      'created_by': currentUserId,
      'service_type': serviceType,
      'requester_name': requesterName.trim(),
      'contact_number': contactNumber.trim(),
      'email': email,
      'requested_date': date,
      'requested_time': startTime,
      'end_time': endTime,
      'venue': venue,
      'officiant_name': officiant,
      'id_type': idType,
      'id_number': idNumber,
      'id_document_url': idDocumentUrl,
      'appointment_status': initialStatus,
      'appointment_remarks': remarks,
    };
    final response = await _client.from('appointments').insert(payload).select().single();
    return AppointmentModel.fromMap(response);
  }

  static Future<void> updateStatus(String appointmentId, String newStatus) async {
    final cleanStatus = newStatus.toLowerCase();
    if (cleanStatus == 'completed') {
      final record = await _client.from('appointments').select('id_document_url').eq('appointment_id', appointmentId).maybeSingle();
      if (record?['id_document_url'] != null) {
        await _client.storage.from('appointment-documents').remove([record!['id_document_url']]);
        await _client.from('appointments').update({'id_document_url': null}).eq('appointment_id', appointmentId);
      }
    }
    await _client.from('appointments').update({'appointment_status': cleanStatus}).eq('appointment_id', appointmentId);
  }

  static Future<void> updateIdVerification({required String appointmentId, required bool isVerified, String? notes}) async {
    await _client.from('appointments').update({
      'is_id_verified': isVerified,
      'id_verified_by': AuthService.currentUser?.userId,
      'id_verified_at': DateTime.now().toIso8601String(),
      'id_verification_notes': notes,
    }).eq('appointment_id', appointmentId);
  }

  static Future<String> _generateAppointmentId() async {
    final now = DateTime.now();
    final yearSuffix = (now.year % 100).toString().padLeft(2, '0');
    final records = await _client.from('appointments').select('appointment_id').like('appointment_id', 'APT-$yearSuffix-%');
    int highest = 0;
    for (var r in records) {
      final parts = r['appointment_id'].toString().split('-');
      if (parts.length >= 3) highest = int.tryParse(parts[2]) ?? 0;
    }
    return 'APT-$yearSuffix-${(highest + 1).toString().padLeft(4, '0')}';
  }
}