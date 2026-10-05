// =============================================================================
// FILE: lib/features/sacramental_records/models/death_record_model.dart
// =============================================================================

class DeathRecordModel {
  final String recordId;
  final String bookNumber;
  final String pageNumber;
  final String lineNumber;

  // Deceased Identity (Defuncti)
  final String deceasedFirstName;
  final String? deceasedMiddleName;
  final String deceasedLastName;
  final String? deceasedSuffix;
  final String gender;
  final String age;
  final String civilStatus;
  final String residence;

  // Relatives (Spouse or Parents)
  final String? spouseFirstName;
  final String? spouseMiddleName;
  final String? spouseLastName;

  final String? fatherFirstName;
  final String? fatherMiddleName;
  final String? fatherLastName;

  final String? motherFirstName;
  final String? motherMiddleName;
  final String motherMaidenLastName;

  // Death & Burial Circumstances
  final DateTime dateOfDeath;
  final DateTime dateOfBurial;
  final String placeOfBurial;
  final String? causeOfDeath;
  final bool sacramentsReceived;
  final String? sacramentsNotes;

  // Liturgical Administration
  final String liturgicalService;
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

  DeathRecordModel({
    required this.recordId,
    required this.bookNumber,
    required this.pageNumber,
    required this.lineNumber,
    required this.deceasedFirstName,
    this.deceasedMiddleName,
    required this.deceasedLastName,
    this.deceasedSuffix,
    required this.gender,
    required this.age,
    required this.civilStatus,
    required this.residence,
    this.spouseFirstName,
    this.spouseMiddleName,
    this.spouseLastName,
    this.fatherFirstName,
    this.fatherMiddleName,
    this.fatherLastName,
    this.motherFirstName,
    this.motherMiddleName,
    this.motherMaidenLastName = '',
    required this.dateOfDeath,
    required this.dateOfBurial,
    required this.placeOfBurial,
    this.causeOfDeath,
    this.sacramentsReceived = true,
    this.sacramentsNotes,
    this.liturgicalService = 'Funeral Mass',
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

  String get deceasedFullName {
    final buffer = StringBuffer(deceasedFirstName);
    if (deceasedMiddleName != null && deceasedMiddleName!.trim().isNotEmpty) {
      buffer.write(' $deceasedMiddleName');
    }
    buffer.write(' $deceasedLastName');
    if (deceasedSuffix != null && deceasedSuffix!.trim().isNotEmpty) {
      buffer.write(' $deceasedSuffix');
    }
    return buffer.toString();
  }

  String get spouseFullName {
    if (spouseFirstName == null || spouseFirstName!.trim().isEmpty) return '—';
    final buffer = StringBuffer(spouseFirstName!);
    if (spouseMiddleName != null && spouseMiddleName!.trim().isNotEmpty) {
      buffer.write(' $spouseMiddleName');
    }
    if (spouseLastName != null && spouseLastName!.trim().isNotEmpty) {
      buffer.write(' $spouseLastName');
    }
    return buffer.toString();
  }

  String get parentsFullName {
    final hasFather = fatherFirstName != null && fatherFirstName!.trim().isNotEmpty;
    final hasMother = motherFirstName != null && motherFirstName!.trim().isNotEmpty;

    if (!hasFather && !hasMother) return '—';

    final fName = hasFather ? '$fatherFirstName ${fatherLastName ?? ""}'.trim() : 'Unknown';
    final mName = hasMother ? '$motherFirstName $motherMaidenLastName'.trim() : 'Unknown';
    return '$fName & $mName';
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

  factory DeathRecordModel.fromMap(Map<String, dynamic> map) {
    // Robust boolean parsing for both Supabase bool and SQLite int (1/0)
    final rawVerified = map['is_verified'];
    final bool isVerifiedParsed = rawVerified == true ||
        rawVerified == 1 ||
        rawVerified == 'true' ||
        rawVerified == '1';

    final rawSacraments = map['sacraments_received'];
    final bool isSacramentsParsed = rawSacraments == null ||
        rawSacraments == true ||
        rawSacraments == 1 ||
        rawSacraments == 'true' ||
        rawSacraments == '1';

    return DeathRecordModel(
      recordId: map['record_id']?.toString() ?? '',
      bookNumber: map['book_number']?.toString() ?? '',
      pageNumber: map['page_number']?.toString() ?? '',
      lineNumber: map['line_number']?.toString() ?? '',
      deceasedFirstName: map['deceased_first_name']?.toString() ?? '',
      deceasedMiddleName: map['deceased_middle_name']?.toString(),
      deceasedLastName: map['deceased_last_name']?.toString() ?? '',
      deceasedSuffix: map['deceased_suffix']?.toString(),
      gender: map['gender']?.toString() ?? 'Male',
      age: map['age']?.toString() ?? '',
      civilStatus: map['civil_status']?.toString() ?? 'Single',
      residence: map['residence']?.toString() ?? '',
      spouseFirstName: map['spouse_first_name']?.toString(),
      spouseMiddleName: map['spouse_middle_name']?.toString(),
      spouseLastName: map['spouse_last_name']?.toString(),
      fatherFirstName: map['father_first_name']?.toString(),
      fatherMiddleName: map['father_middle_name']?.toString(),
      fatherLastName: map['father_last_name']?.toString(),
      motherFirstName: map['mother_first_name']?.toString(),
      motherMiddleName: map['mother_middle_name']?.toString(),
      motherMaidenLastName: map['mother_maiden_last_name']?.toString() ?? '',
      dateOfDeath: DateTime.tryParse(map['date_of_death']?.toString() ?? '') ?? DateTime.now(),
      dateOfBurial: DateTime.tryParse(map['date_of_burial']?.toString() ?? '') ?? DateTime.now(),
      placeOfBurial: map['place_of_burial']?.toString() ?? '',
      causeOfDeath: map['cause_of_death']?.toString(),
      sacramentsReceived: isSacramentsParsed,
      sacramentsNotes: map['sacraments_notes']?.toString(),
      liturgicalService: map['liturgical_service']?.toString() ?? 'Funeral Mass',
      stipend: double.tryParse(map['stipend']?.toString() ?? '0.00') ?? 0.00,
      ministerFirstName: map['minister_first_name']?.toString() ?? '',
      ministerMiddleName: map['minister_middle_name']?.toString(),
      ministerLastName: map['minister_last_name']?.toString() ?? '',
      remarks: map['remarks']?.toString(),
      parishName: map['parish_name']?.toString() ?? 'St. John Paul II Parish',
      scannedImageUrl: map['scanned_image_url']?.toString(),
      ocrRawText: map['ocr_raw_text']?.toString(),
      isVerified: isVerifiedParsed,
      encodedBy: map['encoded_by']?.toString(),
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
      'deceased_first_name': deceasedFirstName,
      'deceased_middle_name': deceasedMiddleName,
      'deceased_last_name': deceasedLastName,
      'deceased_suffix': deceasedSuffix,
      'gender': gender,
      'age': age,
      'civil_status': civilStatus,
      'residence': residence,
      'spouse_first_name': spouseFirstName,
      'spouse_middle_name': spouseMiddleName,
      'spouse_last_name': spouseLastName,
      'father_first_name': fatherFirstName,
      'father_middle_name': fatherMiddleName,
      'father_last_name': fatherLastName,
      'mother_first_name': motherFirstName,
      'mother_middle_name': motherMiddleName,
      'mother_maiden_last_name': motherMaidenLastName,
      'date_of_death': dateOfDeath.toIso8601String().substring(0, 10),
      'date_of_burial': dateOfBurial.toIso8601String().substring(0, 10),
      'place_of_burial': placeOfBurial,
      'cause_of_death': causeOfDeath,
      'sacraments_received': sacramentsReceived,
      'sacraments_notes': sacramentsNotes,
      'liturgical_service': liturgicalService,
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