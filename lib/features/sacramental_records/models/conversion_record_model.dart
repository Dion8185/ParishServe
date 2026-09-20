class ConversionRecordModel {
  final String recordId;
  final String bookNumber;
  final String pageNumber;
  final String lineNumber;
  final DateTime dateOfReception;

  // Person Received (Receptorum)
  final String convertFirstName;
  final String? convertMiddleName;
  final String convertLastName;
  final String? convertSuffix;

  // Birth Details (Nativitatis)
  final DateTime dateOfBirth;
  final String placeOfBirth;

  // Prior Baptism (Baptismi)
  final DateTime? priorBaptismDate;
  final String? priorBaptismChurch;
  final String? priorBaptismPlace;

  // Parents (Parentum)
  final String? fatherFirstName;
  final String? fatherMiddleName;
  final String? fatherLastName;
  final String? fatherReligion;

  final String? motherFirstName;
  final String? motherMiddleName;
  final String motherMaidenLastName;
  final String? motherReligion;

  // Witnesses (Testium)
  final String witness1FirstName;
  final String? witness1MiddleName;
  final String witness1LastName;

  final String? witness2FirstName;
  final String? witness2MiddleName;
  final String? witness2LastName;

  // Offering & Clergy (Stipendium & Ministri)
  final bool isGratis;
  final double stipend;
  final String ministerFirstName;
  final String? ministerMiddleName;
  final String ministerLastName;

  final String? remarks;
  final String parishName;
  final String? scannedImageUrl;
  final String? ocrRawText;
  final bool isVerified;
  final String? encodedBy;
  final DateTime? dateEncoded;
  final DateTime? createdAt;

  ConversionRecordModel({
    required this.recordId,
    required this.bookNumber,
    required this.pageNumber,
    required this.lineNumber,
    required this.dateOfReception,
    required this.convertFirstName,
    this.convertMiddleName,
    required this.convertLastName,
    this.convertSuffix,
    required this.dateOfBirth,
    required this.placeOfBirth,
    this.priorBaptismDate,
    this.priorBaptismChurch,
    this.priorBaptismPlace,
    this.fatherFirstName,
    this.fatherMiddleName,
    this.fatherLastName,
    this.fatherReligion,
    this.motherFirstName,
    this.motherMiddleName,
    required this.motherMaidenLastName,
    this.motherReligion,
    required this.witness1FirstName,
    this.witness1MiddleName,
    required this.witness1LastName,
    this.witness2FirstName,
    this.witness2MiddleName,
    this.witness2LastName,
    this.isGratis = true,
    this.stipend = 0.00,
    required this.ministerFirstName,
    this.ministerMiddleName,
    required this.ministerLastName,
    this.remarks,
    this.parishName = 'St. John Paul II Parish',
    this.scannedImageUrl,
    this.ocrRawText,
    this.isVerified = false,
    this.encodedBy,
    this.dateEncoded,
    this.createdAt,
  });

  String get convertFullName {
    final buffer = StringBuffer(convertFirstName);
    if (convertMiddleName != null && convertMiddleName!.trim().isNotEmpty) {
      buffer.write(' $convertMiddleName');
    }
    buffer.write(' $convertLastName');
    if (convertSuffix != null && convertSuffix!.trim().isNotEmpty) {
      buffer.write(' $convertSuffix');
    }
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
    buffer.write(' $motherMaidenLastName');
    return buffer.toString();
  }

  String get witness1FullName {
    final buffer = StringBuffer(witness1FirstName);
    if (witness1MiddleName != null && witness1MiddleName!.trim().isNotEmpty) {
      buffer.write(' $witness1MiddleName');
    }
    buffer.write(' $witness1LastName');
    return buffer.toString();
  }

  String? get witness2FullName {
    if (witness2FirstName == null || witness2FirstName!.trim().isEmpty) return null;
    final buffer = StringBuffer(witness2FirstName!);
    if (witness2MiddleName != null && witness2MiddleName!.trim().isNotEmpty) {
      buffer.write(' $witness2MiddleName');
    }
    if (witness2LastName != null && witness2LastName!.trim().isNotEmpty) {
      buffer.write(' $witness2LastName');
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

  String get bookReference => 'Book $bookNumber, Page $pageNumber, Line $lineNumber';

  factory ConversionRecordModel.fromMap(Map<String, dynamic> map) {
    return ConversionRecordModel(
      recordId: map['record_id'] ?? '',
      bookNumber: map['book_number'] ?? '',
      pageNumber: map['page_number'] ?? '',
      lineNumber: map['line_number'] ?? '',
      dateOfReception: DateTime.tryParse(map['date_of_reception']?.toString() ?? '') ?? DateTime.now(),
      convertFirstName: map['convert_first_name'] ?? '',
      convertMiddleName: map['convert_middle_name'],
      convertLastName: map['convert_last_name'] ?? '',
      convertSuffix: map['convert_suffix'],
      dateOfBirth: DateTime.tryParse(map['date_of_birth']?.toString() ?? '') ?? DateTime.now(),
      placeOfBirth: map['place_of_birth'] ?? '',
      priorBaptismDate: map['prior_baptism_date'] != null ? DateTime.tryParse(map['prior_baptism_date'].toString()) : null,
      priorBaptismChurch: map['prior_baptism_church'],
      priorBaptismPlace: map['prior_baptism_place'],
      fatherFirstName: map['father_first_name'],
      fatherMiddleName: map['father_middle_name'],
      fatherLastName: map['father_last_name'],
      fatherReligion: map['father_religion'],
      motherFirstName: map['mother_first_name'],
      motherMiddleName: map['mother_middle_name'],
      motherMaidenLastName: map['mother_maiden_last_name'] ?? '',
      motherReligion: map['mother_religion'],
      witness1FirstName: map['witness_1_first_name'] ?? '',
      witness1MiddleName: map['witness_1_middle_name'],
      witness1LastName: map['witness_1_last_name'] ?? '',
      witness2FirstName: map['witness_2_first_name'],
      witness2MiddleName: map['witness_2_middle_name'],
      witness2LastName: map['witness_2_last_name'],
      isGratis: map['is_gratis'] ?? true,
      stipend: double.tryParse(map['stipend']?.toString() ?? '0.00') ?? 0.00,
      ministerFirstName: map['minister_first_name'] ?? '',
      ministerMiddleName: map['minister_middle_name'],
      ministerLastName: map['minister_last_name'] ?? '',
      remarks: map['remarks'],
      parishName: map['parish_name'] ?? 'St. John Paul II Parish',
      scannedImageUrl: map['scanned_image_url'],
      ocrRawText: map['ocr_raw_text'],
      isVerified: map['is_verified'] ?? false,
      encodedBy: map['encoded_by'],
      dateEncoded: map['date_encoded'] != null ? DateTime.tryParse(map['date_encoded'].toString()) : null,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'record_id': recordId,
      'book_number': bookNumber,
      'page_number': pageNumber,
      'line_number': lineNumber,
      'date_of_reception': dateOfReception.toIso8601String().substring(0, 10),
      'convert_first_name': convertFirstName,
      'convert_middle_name': convertMiddleName,
      'convert_last_name': convertLastName,
      'convert_suffix': convertSuffix,
      'date_of_birth': dateOfBirth.toIso8601String().substring(0, 10),
      'place_of_birth': placeOfBirth,
      'prior_baptism_date': priorBaptismDate?.toIso8601String().substring(0, 10),
      'prior_baptism_church': priorBaptismChurch,
      'prior_baptism_place': priorBaptismPlace,
      'father_first_name': fatherFirstName,
      'father_middle_name': fatherMiddleName,
      'father_last_name': fatherLastName,
      'father_religion': fatherReligion,
      'mother_first_name': motherFirstName,
      'mother_middle_name': motherMiddleName,
      'mother_maiden_last_name': motherMaidenLastName,
      'mother_religion': motherReligion,
      'witness_1_first_name': witness1FirstName,
      'witness_1_middle_name': witness1MiddleName,
      'witness_1_last_name': witness1LastName,
      'witness_2_first_name': witness2FirstName,
      'witness_2_middle_name': witness2MiddleName,
      'witness_2_last_name': witness2LastName,
      'is_gratis': isGratis,
      'stipend': stipend,
      'minister_first_name': ministerFirstName,
      'minister_middle_name': ministerMiddleName,
      'minister_last_name': ministerLastName,
      'remarks': remarks,
      'parish_name': parishName,
      'scanned_image_url': scannedImageUrl,
      'ocr_raw_text': ocrRawText,
      'is_verified': isVerified,
      'encoded_by': encodedBy,
    };
  }
}