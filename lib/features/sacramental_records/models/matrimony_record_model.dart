class MatrimonyRecordModel {
  final String recordId;
  final String bookNumber;
  final String pageNumber;
  final String lineNumber;
  final DateTime registryDate;
  final String entryStatus; // ORIGINAL, CORRECTED, INCOMPLETE

  // Groom
  final String groomFirstName;
  final String? groomMiddleName;
  final String groomLastName;
  final String? groomSuffix;
  final String groomCivilStatus;
  final int groomAge;
  final DateTime? groomDateOfBirth;
  final String? groomPlaceOfBirth;
  final String groomAddress;
  final String groomFatherFirstName;
  final String? groomFatherMiddleName;
  final String groomFatherLastName;
  final String groomMotherFirstName;
  final String? groomMotherMiddleName;
  final String groomMotherMaidenLast;

  // Bride
  final String brideFirstName;
  final String? brideMiddleName;
  final String brideLastName;
  final String? brideSuffix;
  final String brideCivilStatus;
  final int brideAge;
  final DateTime? brideDateOfBirth;
  final String? bridePlaceOfBirth;
  final String brideAddress;
  final String brideFatherFirstName;
  final String? brideFatherMiddleName;
  final String brideFatherLastName;
  final String brideMotherFirstName;
  final String? brideMotherMiddleName;
  final String brideMotherMaidenLast;

  // Sponsors
  final String sponsor1FirstName;
  final String? sponsor1MiddleName;
  final String sponsor1LastName;
  final String? sponsor1OriginAddress;

  final String sponsor2FirstName;
  final String? sponsor2MiddleName;
  final String sponsor2LastName;
  final String? sponsor2OriginAddress;

  final List<String> otherSponsors; // Dynamic list (not comma separated)

  // Ceremony Details
  final DateTime dateOfMarriage;
  final String marriageType;
  final bool isFilipinoForeigner;
  final String? marriageLicenseNo;
  final DateTime? licenseDateRegistered;
  final String? licensePlaceIssued;

  // Officiating Minister
  final String solemnizerFirstName;
  final String? solemnizerMiddleName;
  final String solemnizerLastName;
  final String? crasmNumber;
  final DateTime? crasmValidityDate;
  final double stipend;
  final String? remarks;

  final String parishName;
  final String? scannedImageUrl;
  final String? ocrRawText;
  final bool isVerified;
  final String? encodedBy;
  final DateTime? createdAt;

  MatrimonyRecordModel({
    required this.recordId,
    required this.bookNumber,
    required this.pageNumber,
    required this.lineNumber,
    required this.registryDate,
    required this.entryStatus,
    required this.groomFirstName,
    this.groomMiddleName,
    required this.groomLastName,
    this.groomSuffix,
    required this.groomCivilStatus,
    required this.groomAge,
    this.groomDateOfBirth,
    this.groomPlaceOfBirth,
    required this.groomAddress,
    required this.groomFatherFirstName,
    this.groomFatherMiddleName,
    required this.groomFatherLastName,
    required this.groomMotherFirstName,
    this.groomMotherMiddleName,
    required this.groomMotherMaidenLast,
    required this.brideFirstName,
    this.brideMiddleName,
    required this.brideLastName,
    this.brideSuffix,
    required this.brideCivilStatus,
    required this.brideAge,
    this.brideDateOfBirth,
    this.bridePlaceOfBirth,
    required this.brideAddress,
    required this.brideFatherFirstName,
    this.brideFatherMiddleName,
    required this.brideFatherLastName,
    required this.brideMotherFirstName,
    this.brideMotherMiddleName,
    required this.brideMotherMaidenLast,
    required this.sponsor1FirstName,
    this.sponsor1MiddleName,
    required this.sponsor1LastName,
    this.sponsor1OriginAddress,
    required this.sponsor2FirstName,
    this.sponsor2MiddleName,
    required this.sponsor2LastName,
    this.sponsor2OriginAddress,
    required this.otherSponsors,
    required this.dateOfMarriage,
    required this.marriageType,
    required this.isFilipinoForeigner,
    this.marriageLicenseNo,
    this.licenseDateRegistered,
    this.licensePlaceIssued,
    required this.solemnizerFirstName,
    this.solemnizerMiddleName,
    required this.solemnizerLastName,
    this.crasmNumber,
    this.crasmValidityDate,
    this.stipend = 0.00,
    this.remarks,
    required this.parishName,
    this.scannedImageUrl,
    this.ocrRawText,
    this.isVerified = false,
    this.encodedBy,
    this.createdAt,
  });

  String get groomFullName {
    final buffer = StringBuffer(groomFirstName);
    if (groomMiddleName != null && groomMiddleName!.trim().isNotEmpty) {
      buffer.write(' $groomMiddleName');
    }
    buffer.write(' $groomLastName');
    if (groomSuffix != null && groomSuffix!.trim().isNotEmpty) {
      buffer.write(' $groomSuffix');
    }
    return buffer.toString();
  }

  String get brideFullName {
    final buffer = StringBuffer(brideFirstName);
    if (brideMiddleName != null && brideMiddleName!.trim().isNotEmpty) {
      buffer.write(' $brideMiddleName');
    }
    buffer.write(' $brideLastName');
    if (brideSuffix != null && brideSuffix!.trim().isNotEmpty) {
      buffer.write(' $brideSuffix');
    }
    return buffer.toString();
  }

  String get bookReference => 'Book $bookNumber, Page $pageNumber, Line $lineNumber';

  factory MatrimonyRecordModel.fromMap(Map<String, dynamic> map) {
    List<String> parsedOtherSponsors = [];
    final rawOther = map['other_sponsors'];
    if (rawOther is String && rawOther.trim().isNotEmpty) {
      // Reconstitute from stored newline-separated text or comma-separated legacy format
      parsedOtherSponsors = rawOther.contains('\n')
          ? rawOther.split('\n').where((s) => s.trim().isNotEmpty).toList()
          : rawOther.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    }

    return MatrimonyRecordModel(
      recordId: map['record_id'] ?? '',
      bookNumber: map['book_number'] ?? '',
      pageNumber: map['page_number'] ?? '',
      lineNumber: map['line_number'] ?? '',
      registryDate: DateTime.tryParse(map['registry_date']?.toString() ?? '') ?? DateTime.now(),
      entryStatus: map['entry_status'] ?? 'ORIGINAL',
      groomFirstName: map['groom_first_name'] ?? '',
      groomMiddleName: map['groom_middle_name'],
      groomLastName: map['groom_last_name'] ?? '',
      groomSuffix: map['groom_suffix'],
      groomCivilStatus: map['groom_civil_status'] ?? 'Single',
      groomAge: int.tryParse(map['groom_age']?.toString() ?? '0') ?? 0,
      groomDateOfBirth: map['groom_date_of_birth'] != null ? DateTime.tryParse(map['groom_date_of_birth'].toString()) : null,
      groomPlaceOfBirth: map['groom_place_of_birth'],
      groomAddress: map['groom_address'] ?? '',
      groomFatherFirstName: map['groom_father_first_name'] ?? '',
      groomFatherMiddleName: map['groom_father_middle_name'],
      groomFatherLastName: map['groom_father_last_name'] ?? '',
      groomMotherFirstName: map['groom_mother_first_name'] ?? '',
      groomMotherMiddleName: map['groom_mother_middle_name'],
      groomMotherMaidenLast: map['groom_mother_maiden_last'] ?? '',
      brideFirstName: map['bride_first_name'] ?? '',
      brideMiddleName: map['bride_middle_name'],
      brideLastName: map['bride_last_name'] ?? '',
      brideSuffix: map['bride_suffix'],
      brideCivilStatus: map['bride_civil_status'] ?? 'Single',
      brideAge: int.tryParse(map['bride_age']?.toString() ?? '0') ?? 0,
      brideDateOfBirth: map['bride_date_of_birth'] != null ? DateTime.tryParse(map['bride_date_of_birth'].toString()) : null,
      bridePlaceOfBirth: map['bride_place_of_birth'],
      brideAddress: map['bride_address'] ?? '',
      brideFatherFirstName: map['bride_father_first_name'] ?? '',
      brideFatherMiddleName: map['bride_father_middle_name'],
      brideFatherLastName: map['bride_father_last_name'] ?? '',
      brideMotherFirstName: map['bride_mother_first_name'] ?? '',
      brideMotherMiddleName: map['bride_mother_middle_name'],
      brideMotherMaidenLast: map['bride_mother_maiden_last'] ?? '',
      sponsor1FirstName: map['sponsor_1_first_name'] ?? '',
      sponsor1MiddleName: map['sponsor_1_middle_name'],
      sponsor1LastName: map['sponsor_1_last_name'] ?? '',
      sponsor1OriginAddress: map['sponsor_1_origin_address'],
      sponsor2FirstName: map['sponsor_2_first_name'] ?? '',
      sponsor2MiddleName: map['sponsor_2_middle_name'],
      sponsor2LastName: map['sponsor_2_last_name'] ?? '',
      sponsor2OriginAddress: map['sponsor_2_origin_address'],
      otherSponsors: parsedOtherSponsors,
      dateOfMarriage: DateTime.tryParse(map['date_of_marriage']?.toString() ?? '') ?? DateTime.now(),
      marriageType: map['marriage_type'] ?? 'Between Catholics',
      isFilipinoForeigner: map['is_filipino_foreigner'] ?? false,
      marriageLicenseNo: map['marriage_license_no'],
      licenseDateRegistered: map['license_date_registered'] != null ? DateTime.tryParse(map['license_date_registered'].toString()) : null,
      licensePlaceIssued: map['license_place_issued'],
      solemnizerFirstName: map['solemnizer_first_name'] ?? '',
      solemnizerMiddleName: map['solemnizer_middle_name'],
      solemnizerLastName: map['solemnizer_last_name'] ?? '',
      crasmNumber: map['crasm_number'],
      crasmValidityDate: map['crasm_validity_date'] != null ? DateTime.tryParse(map['crasm_validity_date'].toString()) : null,
      stipend: double.tryParse(map['stipend']?.toString() ?? '0.00') ?? 0.00,
      remarks: map['remarks'],
      parishName: map['parish_name'] ?? 'St. John Paul II Parish',
      scannedImageUrl: map['scanned_image_url'],
      ocrRawText: map['ocr_raw_text'],
      isVerified: map['is_verified'] ?? false,
      encodedBy: map['encoded_by'],
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
      'groom_first_name': groomFirstName,
      'groom_middle_name': groomMiddleName,
      'groom_last_name': groomLastName,
      'groom_suffix': groomSuffix,
      'groom_civil_status': groomCivilStatus,
      'groom_age': groomAge,
      'groom_date_of_birth': groomDateOfBirth?.toIso8601String().substring(0, 10),
      'groom_place_of_birth': groomPlaceOfBirth,
      'groom_address': groomAddress,
      'groom_father_first_name': groomFatherFirstName,
      'groom_father_middle_name': groomFatherMiddleName,
      'groom_father_last_name': groomFatherLastName,
      'groom_mother_first_name': groomMotherFirstName,
      'groom_mother_middle_name': groomMotherMiddleName,
      'groom_mother_maiden_last': groomMotherMaidenLast,
      'bride_first_name': brideFirstName,
      'bride_middle_name': brideMiddleName,
      'bride_last_name': brideLastName,
      'bride_suffix': brideSuffix,
      'bride_civil_status': brideCivilStatus,
      'bride_age': brideAge,
      'bride_date_of_birth': brideDateOfBirth?.toIso8601String().substring(0, 10),
      'bride_place_of_birth': bridePlaceOfBirth,
      'bride_address': brideAddress,
      'bride_father_first_name': brideFatherFirstName,
      'bride_father_middle_name': brideFatherMiddleName,
      'bride_father_last_name': brideFatherLastName,
      'bride_mother_first_name': brideMotherFirstName,
      'bride_mother_middle_name': brideMotherMiddleName,
      'bride_mother_maiden_last': brideMotherMaidenLast,
      'sponsor_1_first_name': sponsor1FirstName,
      'sponsor_1_middle_name': sponsor1MiddleName,
      'sponsor_1_last_name': sponsor1LastName,
      'sponsor_1_origin_address': sponsor1OriginAddress,
      'sponsor_2_first_name': sponsor2FirstName,
      'sponsor_2_middle_name': sponsor2MiddleName,
      'sponsor_2_last_name': sponsor2LastName,
      'sponsor_2_origin_address': sponsor2OriginAddress,
      'other_sponsors': otherSponsors.join('\n'), // Stored cleanly newline-separated
      'date_of_marriage': dateOfMarriage.toIso8601String().substring(0, 10),
      'marriage_type': marriageType,
      'is_filipino_foreigner': isFilipinoForeigner,
      'marriage_license_no': marriageLicenseNo,
      'license_date_registered': licenseDateRegistered?.toIso8601String().substring(0, 10),
      'license_place_issued': licensePlaceIssued,
      'solemnizer_first_name': solemnizerFirstName,
      'solemnizer_middle_name': solemnizerMiddleName,
      'solemnizer_last_name': solemnizerLastName,
      'crasm_number': crasmNumber,
      'crasm_validity_date': crasmValidityDate?.toIso8601String().substring(0, 10),
      'stipend': stipend,
      'remarks': remarks,
      'parish_name': parishName,
      'scanned_image_url': scannedImageUrl,
      'ocr_raw_text': ocrRawText,
      'is_verified': isVerified,
      'encoded_by': encodedBy,
    };
  }
}