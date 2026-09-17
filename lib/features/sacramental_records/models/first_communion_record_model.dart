class FirstCommunionRecordModel {
  final String recordId;
  final int year;
  final String controlNumber;

  final String communicantFirstName;
  final String? communicantMiddleName;
  final String communicantLastName;
  final DateTime dateOfCommunion;
  final String baptismParish;
  final DateTime? baptismDate;

  final String? fatherFirstName;
  final String? fatherMiddleName;
  final String? fatherLastName;

  final String? motherFirstName;
  final String? motherMiddleName;
  final String? motherMaidenLastName;

  final String ministerFirstName;
  final String? ministerMiddleName;
  final String ministerLastName;

  final String? remarks;
  final String? scannedImageUrl;
  final bool isVerified;
  final String? encodedBy;
  final DateTime? createdAt;

  FirstCommunionRecordModel({
    required this.recordId,
    required this.year,
    required this.controlNumber,
    required this.communicantFirstName,
    this.communicantMiddleName,
    required this.communicantLastName,
    required this.dateOfCommunion,
    required this.baptismParish,
    this.baptismDate,
    this.fatherFirstName,
    this.fatherMiddleName,
    this.fatherLastName,
    this.motherFirstName,
    this.motherMiddleName,
    this.motherMaidenLastName,
    required this.ministerFirstName,
    this.ministerMiddleName,
    required this.ministerLastName,
    this.remarks,
    this.scannedImageUrl,
    this.isVerified = false,
    this.encodedBy,
    this.createdAt,
  });

  String get communicantFullName {
    final buffer = StringBuffer(communicantFirstName);
    if (communicantMiddleName != null && communicantMiddleName!.trim().isNotEmpty) {
      buffer.write(' $communicantMiddleName');
    }
    buffer.write(' $communicantLastName');
    return buffer.toString();
  }

  String get fatherFullName {
    if (fatherFirstName == null || fatherFirstName!.trim().isEmpty) return '—';
    final buffer = StringBuffer(fatherFirstName!);
    if (fatherMiddleName != null && fatherMiddleName!.trim().isNotEmpty) {
      buffer.write(' $fatherMiddleName');
    }
    if (fatherLastName != null && fatherLastName!.trim().isNotEmpty) {
      buffer.write(' $fatherLastName');
    }
    return buffer.toString();
  }

  String get motherFullName {
    if (motherFirstName == null || motherFirstName!.trim().isEmpty) return '—';
    final buffer = StringBuffer(motherFirstName!);
    if (motherMiddleName != null && motherMiddleName!.trim().isNotEmpty) {
      buffer.write(' $motherMiddleName');
    }
    if (motherMaidenLastName != null && motherMaidenLastName!.trim().isNotEmpty) {
      buffer.write(' $motherMaidenLastName');
    }
    return buffer.toString();
  }

  String get ministerFullName {
    final buffer = StringBuffer('Rev. Fr. $ministerFirstName');
    if (ministerMiddleName != null && ministerMiddleName!.trim().isNotEmpty) {
      buffer.write(' $ministerMiddleName');
    }
    buffer.write(' $ministerLastName');
    return buffer.toString();
  }

  String get referenceDisplay => 'Year $year • Control # $controlNumber';

  factory FirstCommunionRecordModel.fromMap(Map<String, dynamic> map) {
    return FirstCommunionRecordModel(
      recordId: map['record_id'] ?? '',
      year: int.tryParse(map['year']?.toString() ?? '${DateTime.now().year}') ?? DateTime.now().year,
      controlNumber: map['control_number'] ?? '',
      communicantFirstName: map['communicant_first_name'] ?? '',
      communicantMiddleName: map['communicant_middle_name'],
      communicantLastName: map['communicant_last_name'] ?? '',
      dateOfCommunion: DateTime.tryParse(map['date_of_communion']?.toString() ?? '') ?? DateTime.now(),
      baptismParish: map['baptism_parish'] ?? '',
      baptismDate: map['baptism_date'] != null ? DateTime.tryParse(map['baptism_date'].toString()) : null,
      fatherFirstName: map['father_first_name'],
      fatherMiddleName: map['father_middle_name'],
      fatherLastName: map['father_last_name'],
      motherFirstName: map['mother_first_name'],
      motherMiddleName: map['mother_middle_name'],
      motherMaidenLastName: map['mother_maiden_last_name'],
      ministerFirstName: map['minister_first_name'] ?? '',
      ministerMiddleName: map['minister_middle_name'],
      ministerLastName: map['minister_last_name'] ?? '',
      remarks: map['remarks'],
      scannedImageUrl: map['scanned_image_url'],
      isVerified: map['is_verified'] ?? false,
      encodedBy: map['encoded_by'],
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'record_id': recordId,
      'year': year,
      'control_number': controlNumber,
      'communicant_first_name': communicantFirstName,
      'communicant_middle_name': communicantMiddleName,
      'communicant_last_name': communicantLastName,
      'date_of_communion': dateOfCommunion.toIso8601String().substring(0, 10),
      'baptism_parish': baptismParish,
      'baptism_date': baptismDate?.toIso8601String().substring(0, 10),
      'father_first_name': fatherFirstName,
      'father_middle_name': fatherMiddleName,
      'father_last_name': fatherLastName,
      'mother_first_name': motherFirstName,
      'mother_middle_name': motherMiddleName,
      'mother_maiden_last_name': motherMaidenLastName,
      'minister_first_name': ministerFirstName,
      'minister_middle_name': ministerMiddleName,
      'minister_last_name': ministerLastName,
      'remarks': remarks,
      'scanned_image_url': scannedImageUrl,
      'is_verified': isVerified,
      'encoded_by': encodedBy,
    };
  }
}