class ConfirmationRecordModel {
  final String recordId;
  final String bookNumber;
  final String pageNumber;
  final String lineNumber;
  final DateTime registryDate;
  final String entryStatus; // ORIGINAL, CORRECTED, INCOMPLETE

  final String confirmandFirstName;
  final String? confirmandMiddleName;
  final String confirmandLastName;
  final String? confirmandSuffix;
  final DateTime? dateOfBirth;
  final int age;
  final DateTime dateOfBaptism; // Required canonical date
  final String churchBaptized;
  final String? address;

  final String fatherFirstName;
  final String? fatherMiddleName;
  final String fatherLastName;
  final String? fatherOrigin;

  final String motherFirstName;
  final String? motherMiddleName;
  final String motherMaidenLastName;
  final String? motherOrigin;

  final String sponsor1FirstName;
  final String? sponsor1MiddleName;
  final String sponsor1LastName;
  final String? sponsor1OriginAddress;

  final String? sponsor2FirstName;
  final String? sponsor2MiddleName;
  final String? sponsor2LastName;
  final String? sponsor2OriginAddress;

  final DateTime dateOfConfirmation;
  final double stipend;
  final String ministerFirstName;
  final String? ministerMiddleName;
  final String ministerLastName;
  final String parishName;
  final String? remarks;

  final String? scannedImageUrl;
  final String? ocrRawText;
  final bool isVerified;
  final String? encodedBy;
  final DateTime? dateEncoded;
  final DateTime? createdAt;

  ConfirmationRecordModel({
    required this.recordId,
    required this.bookNumber,
    required this.pageNumber,
    required this.lineNumber,
    required this.registryDate,
    this.entryStatus = 'ORIGINAL',
    required this.confirmandFirstName,
    this.confirmandMiddleName,
    required this.confirmandLastName,
    this.confirmandSuffix,
    this.dateOfBirth,
    this.age = 0,
    required this.dateOfBaptism,
    required this.churchBaptized,
    this.address,
    required this.fatherFirstName,
    this.fatherMiddleName,
    required this.fatherLastName,
    this.fatherOrigin,
    required this.motherFirstName,
    this.motherMiddleName,
    required this.motherMaidenLastName,
    this.motherOrigin,
    required this.sponsor1FirstName,
    this.sponsor1MiddleName,
    required this.sponsor1LastName,
    this.sponsor1OriginAddress,
    this.sponsor2FirstName,
    this.sponsor2MiddleName,
    this.sponsor2LastName,
    this.sponsor2OriginAddress,
    required this.dateOfConfirmation,
    this.stipend = 0.00,
    required this.ministerFirstName,
    this.ministerMiddleName,
    required this.ministerLastName,
    this.parishName = 'St. John Paul II Parish',
    this.remarks,
    this.scannedImageUrl,
    this.ocrRawText,
    this.isVerified = false,
    this.encodedBy,
    this.dateEncoded,
    this.createdAt,
  });

  String get confirmandFullName {
    final buffer = StringBuffer(confirmandFirstName);
    if (confirmandMiddleName != null && confirmandMiddleName!.trim().isNotEmpty) {
      buffer.write(' $confirmandMiddleName');
    }
    buffer.write(' $confirmandLastName');
    if (confirmandSuffix != null && confirmandSuffix!.trim().isNotEmpty) {
      buffer.write(' $confirmandSuffix');
    }
    return buffer.toString();
  }

  String get fatherFullName {
    if (fatherFirstName.toLowerCase() == 'not indicated') {
      return '—';
    }
    final buffer = StringBuffer(fatherFirstName);
    if (fatherMiddleName != null && fatherMiddleName!.trim().isNotEmpty) {
      buffer.write(' $fatherMiddleName');
    }
    buffer.write(' $fatherLastName');
    return buffer.toString();
  }

  String get motherFullName {
    final buffer = StringBuffer(motherFirstName);
    if (motherMiddleName != null && motherMiddleName!.trim().isNotEmpty) {
      buffer.write(' $motherMiddleName');
    }
    buffer.write(' $motherMaidenLastName');
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

  String get sponsor1FullName {
    final buffer = StringBuffer(sponsor1FirstName);
    if (sponsor1MiddleName != null && sponsor1MiddleName!.trim().isNotEmpty) {
      buffer.write(' $sponsor1MiddleName');
    }
    buffer.write(' $sponsor1LastName');
    return buffer.toString();
  }

  String? get sponsor2FullName {
    if (sponsor2FirstName == null || sponsor2FirstName!.trim().isEmpty) return null;
    final buffer = StringBuffer(sponsor2FirstName!);
    if (sponsor2MiddleName != null && sponsor2MiddleName!.trim().isNotEmpty) {
      buffer.write(' $sponsor2MiddleName');
    }
    if (sponsor2LastName != null && sponsor2LastName!.trim().isNotEmpty) {
      buffer.write(' $sponsor2LastName');
    }
    return buffer.toString();
  }

  String get bookReference => 'Book $bookNumber, Page $pageNumber, Line $lineNumber';

  factory ConfirmationRecordModel.fromMap(Map<String, dynamic> map) {
    return ConfirmationRecordModel(
      recordId: map['record_id'] ?? '',
      bookNumber: map['book_number'] ?? '',
      pageNumber: map['page_number'] ?? '',
      lineNumber: map['line_number'] ?? '',
      registryDate: DateTime.tryParse(map['registry_date']?.toString() ?? '') ?? DateTime.now(),
      entryStatus: map['entry_status'] ?? 'ORIGINAL',
      confirmandFirstName: map['confirmand_first_name'] ?? '',
      confirmandMiddleName: map['confirmand_middle_name'],
      confirmandLastName: map['confirmand_last_name'] ?? '',
      confirmandSuffix: map['confirmand_suffix'],
      dateOfBirth: map['date_of_birth'] != null ? DateTime.tryParse(map['date_of_birth'].toString()) : null,
      age: int.tryParse(map['age']?.toString() ?? '0') ?? 0,
      dateOfBaptism: DateTime.tryParse(map['date_of_baptism']?.toString() ?? '') ?? DateTime.now(),
      churchBaptized: map['church_baptized'] ?? '',
      address: map['address'],
      fatherFirstName: map['father_first_name'] ?? '',
      fatherMiddleName: map['father_middle_name'],
      fatherLastName: map['father_last_name'] ?? '',
      fatherOrigin: map['father_origin'],
      motherFirstName: map['mother_first_name'] ?? '',
      motherMiddleName: map['mother_middle_name'],
      motherMaidenLastName: map['mother_maiden_last_name'] ?? '',
      motherOrigin: map['mother_origin'],
      sponsor1FirstName: map['sponsor_1_first_name'] ?? '',
      sponsor1MiddleName: map['sponsor_1_middle_name'],
      sponsor1LastName: map['sponsor_1_last_name'] ?? '',
      sponsor1OriginAddress: map['sponsor_1_origin_address'],
      sponsor2FirstName: map['sponsor_2_first_name'],
      sponsor2MiddleName: map['sponsor_2_middle_name'],
      sponsor2LastName: map['sponsor_2_last_name'],
      sponsor2OriginAddress: map['sponsor_2_origin_address'],
      dateOfConfirmation: DateTime.tryParse(map['date_of_confirmation']?.toString() ?? '') ?? DateTime.now(),
      stipend: double.tryParse(map['stipend']?.toString() ?? '0.00') ?? 0.00,
      ministerFirstName: map['minister_first_name'] ?? '',
      ministerMiddleName: map['minister_middle_name'],
      ministerLastName: map['minister_last_name'] ?? '',
      parishName: map['parish_name'] ?? 'St. John Paul II Parish',
      remarks: map['remarks'],
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
      'registry_date': registryDate.toIso8601String().substring(0, 10),
      'entry_status': entryStatus,
      'confirmand_first_name': confirmandFirstName,
      'confirmand_middle_name': confirmandMiddleName,
      'confirmand_last_name': confirmandLastName,
      'confirmand_suffix': confirmandSuffix,
      'date_of_birth': dateOfBirth?.toIso8601String().substring(0, 10),
      'age': age,
      'date_of_baptism': dateOfBaptism.toIso8601String().substring(0, 10),
      'church_baptized': churchBaptized,
      'address': address,
      'father_first_name': fatherFirstName,
      'father_middle_name': fatherMiddleName,
      'father_last_name': fatherLastName,
      'father_origin': fatherOrigin,
      'mother_first_name': motherFirstName,
      'mother_middle_name': motherMiddleName,
      'mother_maiden_last_name': motherMaidenLastName,
      'mother_origin': motherOrigin,
      'sponsor_1_first_name': sponsor1FirstName,
      'sponsor_1_middle_name': sponsor1MiddleName,
      'sponsor_1_last_name': sponsor1LastName,
      'sponsor_1_origin_address': sponsor1OriginAddress,
      'sponsor_2_first_name': sponsor2FirstName,
      'sponsor_2_middle_name': sponsor2MiddleName,
      'sponsor_2_last_name': sponsor2LastName,
      'sponsor_2_origin_address': sponsor2OriginAddress,
      'date_of_confirmation': dateOfConfirmation.toIso8601String().substring(0, 10),
      'stipend': stipend,
      'minister_first_name': ministerFirstName,
      'minister_middle_name': ministerMiddleName,
      'minister_last_name': ministerLastName,
      'parish_name': parishName,
      'remarks': remarks,
      'scanned_image_url': scannedImageUrl,
      'ocr_raw_text': ocrRawText,
      'is_verified': isVerified,
      'encoded_by': encodedBy,
    };
  }
}