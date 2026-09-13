class BaptismRecordModel {
  final String recordId;
  final String bookNumber;
  final String pageNumber;
  final String lineNumber;

  final String childFirstName;
  final String? childMiddleName;
  final String childLastName;
  final String? childSuffix;

  final DateTime dateOfBirth;
  final String? age;
  final String placeOfBirth;
  final String? gender;
  final String? legitimacy;

  final String fatherFirstName;
  final String? fatherMiddleName;
  final String fatherLastName;
  final String? fatherPlaceOfBirth;

  final String motherFirstName;
  final String? motherMiddleName;
  final String motherMaidenLastName;
  final String? motherPlaceOfBirth;

  final String? parentsContactNumber;
  final String? parentsResidence;
  final String? parentsMarriageType;

  final String sponsor1FirstName;
  final String? sponsor1MiddleName;
  final String sponsor1LastName;
  final String? sponsor1Residence;

  final String sponsor2FirstName;
  final String? sponsor2MiddleName;
  final String sponsor2LastName;
  final String? sponsor2Residence;

  final String? otherGodparents;

  final String parishName;

  final String ministerFirstName;
  final String? ministerMiddleName;
  final String ministerLastName;

  final DateTime dateOfBaptism;
  final String placeOfBaptism;
  final double? stipend;
  final String? remarks;

  final String? scannedImageUrl;
  final String? ocrRawText;

  final bool isVerified;
  final String? encodedBy;
  final DateTime? dateEncoded;
  final DateTime? createdAt;

  BaptismRecordModel({
    required this.recordId,
    required this.bookNumber,
    required this.pageNumber,
    required this.lineNumber,
    required this.childFirstName,
    this.childMiddleName,
    required this.childLastName,
    this.childSuffix,
    required this.dateOfBirth,
    this.age,
    required this.placeOfBirth,
    this.gender,
    this.legitimacy,
    required this.fatherFirstName,
    this.fatherMiddleName,
    required this.fatherLastName,
    this.fatherPlaceOfBirth,
    required this.motherFirstName,
    this.motherMiddleName,
    required this.motherMaidenLastName,
    this.motherPlaceOfBirth,
    this.parentsContactNumber,
    this.parentsResidence,
    this.parentsMarriageType,
    required this.sponsor1FirstName,
    this.sponsor1MiddleName,
    required this.sponsor1LastName,
    this.sponsor1Residence,
    required this.sponsor2FirstName,
    this.sponsor2MiddleName,
    required this.sponsor2LastName,
    this.sponsor2Residence,
    this.otherGodparents,
    required this.parishName,
    required this.ministerFirstName,
    this.ministerMiddleName,
    required this.ministerLastName,
    required this.dateOfBaptism,
    required this.placeOfBaptism,
    this.stipend,
    this.remarks,
    this.scannedImageUrl,
    this.ocrRawText,
    this.isVerified = false,
    this.encodedBy,
    this.dateEncoded,
    this.createdAt,
  });

  String get childFullName {
    final buffer = StringBuffer(childFirstName);
    if (childMiddleName != null && childMiddleName!.trim().isNotEmpty) {
      buffer.write(' $childMiddleName');
    }
    buffer.write(' $childLastName');
    if (childSuffix != null && childSuffix!.trim().isNotEmpty) {
      buffer.write(' $childSuffix');
    }
    return buffer.toString();
  }

  String get fatherFullName {
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

  String get sponsor2FullName {
    final buffer = StringBuffer(sponsor2FirstName);
    if (sponsor2MiddleName != null && sponsor2MiddleName!.trim().isNotEmpty) {
      buffer.write(' $sponsor2MiddleName');
    }
    buffer.write(' $sponsor2LastName');
    return buffer.toString();
  }

  String get bookReference => 'Book $bookNumber, Page $pageNumber, Line $lineNumber';

  factory BaptismRecordModel.fromMap(Map<String, dynamic> map) {
    return BaptismRecordModel(
      recordId: map['record_id'] ?? '',
      bookNumber: map['book_number'] ?? '',
      pageNumber: map['page_number'] ?? '',
      lineNumber: map['line_number'] ?? '',
      childFirstName: map['child_first_name'] ?? '',
      childMiddleName: map['child_middle_name'],
      childLastName: map['child_last_name'] ?? '',
      childSuffix: map['child_suffix'],
      dateOfBirth: DateTime.tryParse(map['date_of_birth']?.toString() ?? '') ?? DateTime.now(),
      age: map['age'],
      placeOfBirth: map['place_of_birth'] ?? '',
      gender: map['gender'],
      legitimacy: map['legitimacy'],
      fatherFirstName: map['father_first_name'] ?? '',
      fatherMiddleName: map['father_middle_name'],
      fatherLastName: map['father_last_name'] ?? '',
      fatherPlaceOfBirth: map['father_place_of_birth'],
      motherFirstName: map['mother_first_name'] ?? '',
      motherMiddleName: map['mother_middle_name'],
      motherMaidenLastName: map['mother_maiden_last_name'] ?? '',
      motherPlaceOfBirth: map['mother_place_of_birth'],
      parentsContactNumber: map['parents_contact_number'],
      parentsResidence: map['parents_residence'],
      parentsMarriageType: map['parents_marriage_type'],
      sponsor1FirstName: map['sponsor_1_first_name'] ?? '',
      sponsor1MiddleName: map['sponsor_1_middle_name'],
      sponsor1LastName: map['sponsor_1_last_name'] ?? '',
      sponsor1Residence: map['sponsor_1_residence'],
      sponsor2FirstName: map['sponsor_2_first_name'] ?? '',
      sponsor2MiddleName: map['sponsor_2_middle_name'],
      sponsor2LastName: map['sponsor_2_last_name'] ?? '',
      sponsor2Residence: map['sponsor_2_residence'],
      otherGodparents: map['other_godparents'],
      parishName: map['parish_name'] ?? 'St. John Paul II Parish',
      ministerFirstName: map['minister_first_name'] ?? '',
      ministerMiddleName: map['minister_middle_name'],
      ministerLastName: map['minister_last_name'] ?? '',
      dateOfBaptism: DateTime.tryParse(map['date_of_baptism']?.toString() ?? '') ?? DateTime.now(),
      placeOfBaptism: map['place_of_baptism'] ?? 'St. John Paul II Parish Church',
      stipend: map['stipend'] != null ? double.tryParse(map['stipend'].toString()) : null,
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
      'child_first_name': childFirstName,
      'child_middle_name': childMiddleName,
      'child_last_name': childLastName,
      'child_suffix': childSuffix,
      'date_of_birth': dateOfBirth.toIso8601String().substring(0, 10),
      'age': age,
      'place_of_birth': placeOfBirth,
      'gender': gender,
      'legitimacy': legitimacy,
      'father_first_name': fatherFirstName,
      'father_middle_name': fatherMiddleName,
      'father_last_name': fatherLastName,
      'father_place_of_birth': fatherPlaceOfBirth,
      'mother_first_name': motherFirstName,
      'mother_middle_name': motherMiddleName,
      'mother_maiden_last_name': motherMaidenLastName,
      'mother_place_of_birth': motherPlaceOfBirth,
      'parents_contact_number': parentsContactNumber,
      'parents_residence': parentsResidence,
      'parents_marriage_type': parentsMarriageType,
      'sponsor_1_first_name': sponsor1FirstName,
      'sponsor_1_middle_name': sponsor1MiddleName,
      'sponsor_1_last_name': sponsor1LastName,
      'sponsor_1_residence': sponsor1Residence,
      'sponsor_2_first_name': sponsor2FirstName,
      'sponsor_2_middle_name': sponsor2MiddleName,
      'sponsor_2_last_name': sponsor2LastName,
      'sponsor_2_residence': sponsor2Residence,
      'other_godparents': otherGodparents,
      'parish_name': parishName,
      'minister_first_name': ministerFirstName,
      'minister_middle_name': ministerMiddleName,
      'minister_last_name': ministerLastName,
      'date_of_baptism': dateOfBaptism.toIso8601String().substring(0, 10),
      'place_of_baptism': placeOfBaptism,
      'stipend': stipend,
      'remarks': remarks,
      'scanned_image_url': scannedImageUrl,
      'ocr_raw_text': ocrRawText,
      'is_verified': isVerified,
      'encoded_by': encodedBy,
    };
  }
}