class MassIntentionModel {
  final String intentionId;
  final String? createdBy;
  final String requesterName;
  final String contactNumber;
  final String? email;
  final DateTime scheduledDate;
  final String massTime; // "17:30:00", "08:00:00", "16:00:00"
  final List<String> thanksgivingList;
  final List<String> reposeSoulsList;
  final List<String> specialIntentionsList;
  final String? otherIntentions;
  final double stipendAmount;
  final String paymentMethod;
  final String paymentStatus;
  final String? gcashReferenceNo;
  final String intentionStatus; // 'pending', 'confirmed', 'rejected', 'cancelled'
  final String? remarks;
  final String? receiptImageUrl;
  final String? ocrReferenceNumber;
  final double? ocrAmount;
  final String? ocrRawText;
  final String verificationStatus; // 'pending', 'verified', 'rejected', 'unmatched'
  final String? matchingReferenceId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  MassIntentionModel({
    required this.intentionId,
    this.createdBy,
    required this.requesterName,
    required this.contactNumber,
    this.email,
    required this.scheduledDate,
    required this.massTime,
    this.thanksgivingList = const [],
    this.reposeSoulsList = const [],
    this.specialIntentionsList = const [],
    this.otherIntentions,
    this.stipendAmount = 0.0,
    this.paymentMethod = 'GCash',
    this.paymentStatus = 'pending',
    this.gcashReferenceNo,
    this.intentionStatus = 'pending',
    this.remarks,
    this.receiptImageUrl,
    this.ocrReferenceNumber,
    this.ocrAmount,
    this.ocrRawText,
    this.verificationStatus = 'pending',
    this.matchingReferenceId,
    this.createdAt,
    this.updatedAt,
  });

  String get formattedDate {
    return '${scheduledDate.year}-${scheduledDate.month.toString().padLeft(2, '0')}-${scheduledDate.day.toString().padLeft(2, '0')}';
  }

  String get dayOfWeekName {
    switch (scheduledDate.weekday) {
      case DateTime.monday:
        return 'Monday';
      case DateTime.tuesday:
        return 'Tuesday';
      case DateTime.wednesday:
        return 'Wednesday';
      case DateTime.thursday:
        return 'Thursday';
      case DateTime.friday:
        return 'Friday';
      case DateTime.saturday:
        return 'Saturday';
      case DateTime.sunday:
        return 'Sunday';
      default:
        return '';
    }
  }

  String get formattedTime12Hour {
    try {
      final clean = massTime.trim().split('+')[0].split('.')[0].trim();
      final parts = clean.split(':');
      int hour = int.parse(parts[0]);
      int minute = int.parse(parts[1]);
      final period = hour >= 12 ? 'PM' : 'AM';
      final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      return '${hour12.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
    } catch (_) {
      return massTime;
    }
  }

  /// Prominent, high-readability schedule indicator (Day, Date, and Time)
  String get formattedScheduleDisplay {
    return '$dayOfWeekName, $formattedDate at $formattedTime12Hour';
  }

  int get totalIntentionsCount {
    int count = thanksgivingList.length + reposeSoulsList.length + specialIntentionsList.length;
    if (otherIntentions != null && otherIntentions!.trim().isNotEmpty) count++;
    return count;
  }

  bool get isApprovedAndVerified =>
      intentionStatus.toLowerCase() == 'confirmed' &&
          verificationStatus.toLowerCase() == 'verified';

  bool get isRejected =>
      intentionStatus.toLowerCase() == 'rejected' ||
          intentionStatus.toLowerCase() == 'cancelled';

  factory MassIntentionModel.fromMap(Map<String, dynamic> map) {
    List<String> parseList(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) {
        return raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
      }
      return [];
    }

    return MassIntentionModel(
      intentionId: map['intention_id'] ?? '',
      createdBy: map['created_by'],
      requesterName: map['requester_name'] ?? '',
      contactNumber: map['contact_number'] ?? '',
      email: map['email'],
      scheduledDate: DateTime.tryParse(map['scheduled_date']?.toString() ?? '') ?? DateTime.now(),
      massTime: map['mass_time']?.toString() ?? '17:30:00',
      thanksgivingList: parseList(map['thanksgiving_list']),
      reposeSoulsList: parseList(map['repose_souls_list']),
      specialIntentionsList: parseList(map['special_intentions_list']),
      otherIntentions: map['other_intentions'],
      stipendAmount: double.tryParse(map['stipend_amount']?.toString() ?? '0') ?? 0.0,
      paymentMethod: map['payment_method'] ?? 'GCash',
      paymentStatus: map['payment_status'] ?? 'pending',
      gcashReferenceNo: map['gcash_reference_no'],
      intentionStatus: map['intention_status'] ?? 'pending',
      remarks: map['remarks'],
      receiptImageUrl: map['receipt_image_url'],
      ocrReferenceNumber: map['ocr_reference_number'],
      ocrAmount: map['ocr_amount'] != null ? double.tryParse(map['ocr_amount'].toString()) : null,
      ocrRawText: map['ocr_raw_text'],
      verificationStatus: map['verification_status'] ?? 'pending',
      matchingReferenceId: map['matching_reference_id']?.toString(),
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'intention_id': intentionId,
      'created_by': createdBy,
      'requester_name': requesterName,
      'contact_number': contactNumber,
      'email': email,
      'scheduled_date': formattedDate,
      'mass_time': massTime,
      'thanksgiving_list': thanksgivingList,
      'repose_souls_list': reposeSoulsList,
      'special_intentions_list': specialIntentionsList,
      'other_intentions': otherIntentions,
      'stipend_amount': stipendAmount,
      'payment_method': paymentMethod,
      'payment_status': paymentStatus,
      'gcash_reference_no': gcashReferenceNo,
      'intention_status': intentionStatus,
      'remarks': remarks,
      'receipt_image_url': receiptImageUrl,
      'ocr_reference_number': ocrReferenceNumber,
      'ocr_amount': ocrAmount,
      'ocr_raw_text': ocrRawText,
      'verification_status': verificationStatus,
      'matching_reference_id': matchingReferenceId,
    };
  }

  MassIntentionModel copyWith({
    String? intentionId,
    String? createdBy,
    String? requesterName,
    String? contactNumber,
    String? email,
    DateTime? scheduledDate,
    String? massTime,
    List<String>? thanksgivingList,
    List<String>? reposeSoulsList,
    List<String>? specialIntentionsList,
    String? otherIntentions,
    double? stipendAmount,
    String? paymentMethod,
    String? paymentStatus,
    String? gcashReferenceNo,
    String? intentionStatus,
    String? remarks,
    String? receiptImageUrl,
    String? ocrReferenceNumber,
    double? ocrAmount,
    String? ocrRawText,
    String? verificationStatus,
    String? matchingReferenceId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MassIntentionModel(
      intentionId: intentionId ?? this.intentionId,
      createdBy: createdBy ?? this.createdBy,
      requesterName: requesterName ?? this.requesterName,
      contactNumber: contactNumber ?? this.contactNumber,
      email: email ?? this.email,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      massTime: massTime ?? this.massTime,
      thanksgivingList: thanksgivingList ?? this.thanksgivingList,
      reposeSoulsList: reposeSoulsList ?? this.reposeSoulsList,
      specialIntentionsList: specialIntentionsList ?? this.specialIntentionsList,
      otherIntentions: otherIntentions ?? this.otherIntentions,
      stipendAmount: stipendAmount ?? this.stipendAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      gcashReferenceNo: gcashReferenceNo ?? this.gcashReferenceNo,
      intentionStatus: intentionStatus ?? this.intentionStatus,
      remarks: remarks ?? this.remarks,
      receiptImageUrl: receiptImageUrl ?? this.receiptImageUrl,
      ocrReferenceNumber: ocrReferenceNumber ?? this.ocrReferenceNumber,
      ocrAmount: ocrAmount ?? this.ocrAmount,
      ocrRawText: ocrRawText ?? this.ocrRawText,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      matchingReferenceId: matchingReferenceId ?? this.matchingReferenceId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}