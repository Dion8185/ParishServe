class AppointmentModel {
  final String appointmentId;
  final String? scheduleId;
  final String? serviceRequestId;
  final String requesterName;
  final String contactNumber;
  final String? email;
  final String serviceType;
  final DateTime requestedDate;
  final String requestedTime; // e.g. "10:00:00"
  final String endTime;       // e.g. "11:30:00"
  final String venue;
  final String officiantName;
  final String appointmentStatus; // pending, confirmed, completed, rescheduled, cancelled
  final String? appointmentRemarks;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AppointmentModel({
    required this.appointmentId,
    this.scheduleId,
    this.serviceRequestId,
    required this.requesterName,
    required this.contactNumber,
    this.email,
    required this.serviceType,
    required this.requestedDate,
    required this.requestedTime,
    required this.endTime,
    required this.venue,
    required this.officiantName,
    this.appointmentStatus = 'pending',
    this.appointmentRemarks,
    this.createdAt,
    this.updatedAt,
  });

  /// Formats time string (HH:mm:ss) into human-friendly 12-hour AM/PM format
  String get formattedTimeRange {
    return '${_formatTime12Hour(requestedTime)} – ${_formatTime12Hour(endTime)}';
  }

  String get formattedDate {
    return '${requestedDate.year}-${requestedDate.month.toString().padLeft(2, '0')}-${requestedDate.day.toString().padLeft(2, '0')}';
  }

  static String _formatTime12Hour(String timeStr) {
    try {
      final parts = timeStr.split(':');
      int hour = int.parse(parts[0]);
      int minute = int.parse(parts[1]);
      final period = hour >= 12 ? 'PM' : 'AM';
      final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      return '${hour12.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
    } catch (_) {
      return timeStr;
    }
  }

  factory AppointmentModel.fromMap(Map<String, dynamic> map) {
    return AppointmentModel(
      appointmentId: map['appointment_id'] ?? '',
      scheduleId: map['schedule_id'],
      serviceRequestId: map['service_request_id'],
      requesterName: map['requester_name'] ?? '',
      contactNumber: map['contact_number'] ?? '',
      email: map['email'],
      serviceType: map['service_type'] ?? '',
      requestedDate: DateTime.tryParse(map['requested_date']?.toString() ?? '') ?? DateTime.now(),
      requestedTime: map['requested_time']?.toString() ?? '00:00:00',
      endTime: map['end_time']?.toString() ?? '00:00:00',
      venue: map['venue'] ?? 'Main Church Altar',
      officiantName: map['officiant_name'] ?? 'Rev. Fr. Joseph Santos',
      appointmentStatus: map['appointment_status'] ?? 'pending',
      appointmentRemarks: map['appointment_remarks'],
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'appointment_id': appointmentId,
      'schedule_id': scheduleId,
      'service_request_id': serviceRequestId,
      'requester_name': requesterName,
      'contact_number': contactNumber,
      'email': email,
      'service_type': serviceType,
      'requested_date': requestedDate.toIso8601String().substring(0, 10),
      'requested_time': requestedTime,
      'end_time': endTime,
      'venue': venue,
      'officiant_name': officiantName,
      'appointment_status': appointmentStatus,
      'appointment_remarks': appointmentRemarks,
    };
  }
}