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
  final String intentionStatus;
  final String? remarks;
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
    this.createdAt,
    this.updatedAt,
  });

  String get formattedDate {
    return '${scheduledDate.year}-${scheduledDate.month.toString().padLeft(2, '0')}-${scheduledDate.day.toString().padLeft(2, '0')}';
  }

  String get formattedTime12Hour {
    try {
      final parts = massTime.split(':');
      int hour = int.parse(parts[0]);
      int minute = int.parse(parts[1]);
      final period = hour >= 12 ? 'PM' : 'AM';
      final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      return '${hour12.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
    } catch (_) {
      return massTime;
    }
  }

  int get totalIntentionsCount {
    int count = thanksgivingList.length + reposeSoulsList.length + specialIntentionsList.length;
    if (otherIntentions != null && otherIntentions!.trim().isNotEmpty) count++;
    return count;
  }

  factory MassIntentionModel.fromMap(Map<String, dynamic> map) {
    List<String> parseList(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) return raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
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
    };
  }
}