// =============================================================================
// FILE: lib/features/sacramental_records/utils/placeholder_registry.dart
// =============================================================================

/// Canonical Placeholder Registry & Dynamic Replacer Engine
/// Saint John Paul II Parish - Diocese of San Pablo
class PlaceholderRegistry {
  PlaceholderRegistry._();

  // ===========================================================================
  // Universal Purpose Presets
  // ===========================================================================

  static const List<String> standardPurposes = [
    'For Personal Records',
    'For School Requirements',
    'For Employment',
    'For Marriage Requirements',
    'For Legal Requirements',
    'For Government Requirements',
    'For Baptismal Sponsorship (Godparent)',
    'For Confirmation Sponsorship',
    'For SSS / GSIS / Passport Application',
    'Other / Custom Purpose',
  ];

  // ===========================================================================
  // Available Dynamic Placeholders per Sacrament
  // ===========================================================================

  static const Map<String, List<String>> sacramentPlaceholders = {
    'Baptism': [
      '{Full Name}',
      '{First Name}',
      '{Middle Name}',
      '{Last Name}',
      '{Date of Birth}',
      '{nth Day of Birth}',
      '{Day of Birth}',
      '{Month of Birth}',
      '{Year of Birth}',
      '{Place of Birth}',
      '{Gender}',
      '{Legitimacy}',
      '{Father\'s Name}',
      '{Mother\'s Name}',
      '{Godfather\'s Name}',
      '{Godmother\'s Name}',
      '{Other Sponsors}',
      '{Date of Baptism}',
      '{nth Day}',
      '{nth Day of Baptism}',
      '{Day of Baptism}',
      '{Month of Baptism}',
      '{Year of Baptism}',
      '{Place of Baptism}',
      '{Minister Name}',
      '{Book Number}',
      '{Page Number}',
      '{Line Number}',
      '{Registry Reference}',
      '{Purpose}',
      '{Date Issued}',
      '{nth Day Issued}',
      '{Month of Issue}',
      '{Year of Issue}',
    ],
    'Confirmation': [
      '{Full Name}',
      '{First Name}',
      '{Middle Name}',
      '{Last Name}',
      '{Date of Birth}',
      '{nth Day of Birth}',
      '{Day of Birth}',
      '{Month of Birth}',
      '{Year of Birth}',
      '{Age}',
      '{Father\'s Name}',
      '{Mother\'s Name}',
      '{Date of Baptism}',
      '{nth Day of Baptism}',
      '{Month of Baptism}',
      '{Year of Baptism}',
      '{Place of Baptism}',
      '{Date of Confirmation}',
      '{nth Day}',
      '{nth Day of Confirmation}',
      '{Day of Confirmation}',
      '{Month of Confirmation}',
      '{Year of Confirmation}',
      '{Place of Confirmation}',
      '{Godfather\'s Name}',
      '{Godmother\'s Name}',
      '{Minister Name}',
      '{Book Number}',
      '{Page Number}',
      '{Line Number}',
      '{Registry Reference}',
      '{Purpose}',
      '{Date Issued}',
      '{nth Day Issued}',
      '{Month of Issue}',
      '{Year of Issue}',
    ],
    'First Communion': [
      '{Full Name}',
      '{First Name}',
      '{Middle Name}',
      '{Last Name}',
      '{Father\'s Name}',
      '{Mother\'s Name}',
      '{Date of Baptism}',
      '{nth Day of Baptism}',
      '{Month of Baptism}',
      '{Year of Baptism}',
      '{Place of Baptism}',
      '{Date of First Communion}',
      '{Date of Communion}',
      '{nth Day}',
      '{nth Day of Communion}',
      '{nth Day of First Communion}',
      '{Day of Communion}',
      '{Month of Communion}',
      '{Month of First Communion}',
      '{Year of Communion}',
      '{Year of First Communion}',
      '{Place of First Communion}',
      '{Minister Name}',
      '{Record Number}',
      '{Year}',
      '{Purpose}',
      '{Date Issued}',
      '{nth Day Issued}',
      '{Month of Issue}',
      '{Year of Issue}',
    ],
    'Matrimony': [
      '{Groom Name}',
      '{Groom Age}',
      '{Groom Civil Status}',
      '{Groom Date of Birth}',
      '{nth Day of Groom Birth}',
      '{Month of Groom Birth}',
      '{Year of Groom Birth}',
      '{Groom Father\'s Name}',
      '{Groom Mother\'s Name}',
      '{Bride Name}',
      '{Bride Age}',
      '{Bride Civil Status}',
      '{Bride Date of Birth}',
      '{nth Day of Bride Birth}',
      '{Month of Bride Birth}',
      '{Year of Bride Birth}',
      '{Bride Father\'s Name}',
      '{Bride Mother\'s Name}',
      '{Marriage Type}',
      '{Date of Marriage}',
      '{nth Day}',
      '{nth Day of Marriage}',
      '{Day of Marriage}',
      '{Month of Marriage}',
      '{Year of Marriage}',
      '{Place of Marriage}',
      '{Godfather\'s Name}',
      '{Godmother\'s Name}',
      '{Other Sponsors}',
      '{Marriage License Number}',
      '{Minister Name}',
      '{Book Number}',
      '{Page Number}',
      '{Line Number}',
      '{Registry Reference}',
      '{Purpose}',
      '{Date Issued}',
      '{nth Day Issued}',
      '{Month of Issue}',
      '{Year of Issue}',
    ],
    'Death': [
      '{Full Name}',
      '{First Name}',
      '{Middle Name}',
      '{Last Name}',
      '{Age}',
      '{Gender}',
      '{Civil Status}',
      '{Residence}',
      '{Spouse\'s Name}',
      '{Father\'s Name}',
      '{Mother\'s Name}',
      '{Date of Death}',
      '{nth Day of Death}',
      '{Day of Death}',
      '{Month of Death}',
      '{Year of Death}',
      '{Date of Burial}',
      '{nth Day}',
      '{nth Day of Burial}',
      '{Day of Burial}',
      '{Month of Burial}',
      '{Year of Burial}',
      '{Place of Death}',
      '{Place of Burial}',
      '{Cause of Death}',
      '{Minister Name}',
      '{Book Number}',
      '{Page Number}',
      '{Line Number}',
      '{Registry Reference}',
      '{Purpose}',
      '{Date Issued}',
      '{nth Day Issued}',
      '{Month of Issue}',
      '{Year of Issue}',
    ],
    'Conversion': [
      '{Full Name}',
      '{First Name}',
      '{Middle Name}',
      '{Last Name}',
      '{Date of Birth}',
      '{nth Day of Birth}',
      '{Day of Birth}',
      '{Month of Birth}',
      '{Year of Birth}',
      '{Place of Birth}',
      '{Prior Church}',
      '{Prior Baptism Date}',
      '{nth Day of Prior Baptism}',
      '{Month of Prior Baptism}',
      '{Year of Prior Baptism}',
      '{Father\'s Name}',
      '{Mother\'s Name}',
      '{Date of Reception}',
      '{nth Day}',
      '{nth Day of Reception}',
      '{Day of Reception}',
      '{Month of Reception}',
      '{Year of Reception}',
      '{Place of Reception}',
      '{Godfather\'s Name}',
      '{Godmother\'s Name}',
      '{Minister Name}',
      '{Book Number}',
      '{Page Number}',
      '{Line Number}',
      '{Registry Reference}',
      '{Purpose}',
      '{Date Issued}',
      '{nth Day Issued}',
      '{Month of Issue}',
      '{Year of Issue}',
    ],
  };

  static const List<String> monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  /// Returns English ordinal representation of a day number (e.g. 1st, 2nd, 3rd, 4th, 21st, 22nd)
  static String formatOrdinal(int number) {
    if (number <= 0) return '$number';
    final mod100 = number % 100;
    if (mod100 >= 11 && mod100 <= 13) {
      return '${number}th';
    }
    switch (number % 10) {
      case 1:
        return '${number}st';
      case 2:
        return '${number}nd';
      case 3:
        return '${number}rd';
      default:
        return '${number}th';
    }
  }

  /// Extracts decomposed date components (ordinal day, numeric day, month name, year)
  static Map<String, String> _decomposeDate(String? raw) {
    if (raw == null || raw.trim().isEmpty || raw == '—') {
      return {
        'formatted': '—',
        'ordinalDay': '—',
        'day': '—',
        'month': '—',
        'year': '—',
      };
    }
    final parsed = DateTime.tryParse(raw.trim());
    if (parsed == null) {
      return {
        'formatted': raw,
        'ordinalDay': '—',
        'day': '—',
        'month': '—',
        'year': '—',
      };
    }

    final monthName = monthNames[parsed.month - 1];
    final ordinalDay = formatOrdinal(parsed.day);
    final dayStr = '${parsed.day}';
    final yearStr = '${parsed.year}';
    final formatted = '$monthName ${parsed.day}, ${parsed.year}';

    return {
      'formatted': formatted,
      'ordinalDay': ordinalDay,
      'day': dayStr,
      'month': monthName,
      'year': yearStr,
    };
  }

  /// Returns supported placeholders for a given sacrament type.
  static List<String> getPlaceholdersFor(String sacramentType) {
    return sacramentPlaceholders[sacramentType] ?? [
      '{Full Name}',
      '{Purpose}',
      '{Date Issued}',
      '{nth Day}',
      '{Month of Issue}',
      '{Year of Issue}',
      '{Book Number}',
      '{Page Number}',
      '{Line Number}',
    ];
  }

  // ===========================================================================
  // Dynamic Value Extraction from Raw Database Record
  // ===========================================================================

  static Map<String, String> extractPlaceholderValues({
    required String sacramentType,
    required Map<String, dynamic> recordData,
    required String purpose,
    DateTime? issueDate,
  }) {
    final now = issueDate ?? DateTime.now();
    final issueParts = _decomposeDate(now.toIso8601String().substring(0, 10));

    String val(String key, [String fallback = '—']) {
      final v = recordData[key];
      if (v == null) return fallback;
      final str = v.toString().trim();
      return str.isEmpty ? fallback : str;
    }

    String fullName(String prefix) {
      final f = val('${prefix}_first_name');
      final m = val('${prefix}_middle_name');
      var l = val('${prefix}_last_name');
      if (l == '—') l = val('${prefix}_maiden_last_name');
      if (l == '—') l = val('${prefix}_maiden_last');
      final s = val('${prefix}_suffix');

      if (f.toLowerCase() == 'not indicated') return '—';
      if (f == '—' && l == '—') return '—';

      final parts = <String>[];
      if (f != '—') parts.add(f);
      if (m != '—') parts.add(m);
      if (l != '—') parts.add(l);
      if (s != '—') parts.add(s);

      return parts.isEmpty ? '—' : parts.join(' ');
    }

    final book = val('book_number');
    final page = val('page_number');
    final line = val('line_number');
    final regRef = (book != '—') ? 'Book $book, Page $page, Line $line' : val('control_number');

    final map = <String, String>{
      '{Purpose}': purpose.trim().isEmpty ? 'General Legal / Personal Records' : purpose.trim(),
      '{Date Issued}': issueParts['formatted']!,
      '{nth Day Issued}': issueParts['ordinalDay']!,
      '{nth Day of Issue}': issueParts['ordinalDay']!,
      '{Day Issued}': issueParts['day']!,
      '{Day of Issue}': issueParts['day']!,
      '{Month of Issue}': issueParts['month']!,
      '{Month Issued}': issueParts['month']!,
      '{Year of Issue}': issueParts['year']!,
      '{Year Issued}': issueParts['year']!,
      '{Book Number}': book,
      '{Page Number}': page,
      '{Line Number}': line,
      '{Registry Reference}': regRef,
    };

    if (sacramentType == 'Baptism') {
      final birthParts = _decomposeDate(val('date_of_birth'));
      final baptismParts = _decomposeDate(val('date_of_baptism'));

      map['{Full Name}'] = fullName('child');
      map['{First Name}'] = val('child_first_name');
      map['{Middle Name}'] = val('child_middle_name');
      map['{Last Name}'] = val('child_last_name');

      map['{Date of Birth}'] = birthParts['formatted']!;
      map['{nth Day of Birth}'] = birthParts['ordinalDay']!;
      map['{Day of Birth}'] = birthParts['day']!;
      map['{Month of Birth}'] = birthParts['month']!;
      map['{Year of Birth}'] = birthParts['year']!;

      map['{Place of Birth}'] = val('place_of_birth');
      map['{Gender}'] = val('gender');
      map['{Legitimacy}'] = val('legitimacy');
      map['{Father\'s Name}'] = fullName('father');
      map['{Mother\'s Name}'] = fullName('mother');
      map['{Godfather\'s Name}'] = fullName('sponsor_1');
      map['{Godmother\'s Name}'] = fullName('sponsor_2');
      map['{Other Sponsors}'] = val('other_godparents');

      map['{Date of Baptism}'] = baptismParts['formatted']!;
      map['{nth Day}'] = baptismParts['ordinalDay']!;
      map['{nth Day of Baptism}'] = baptismParts['ordinalDay']!;
      map['{Day of Baptism}'] = baptismParts['day']!;
      map['{Month of Baptism}'] = baptismParts['month']!;
      map['{Year of Baptism}'] = baptismParts['year']!;

      map['{Place of Baptism}'] = val('place_of_baptism', 'St. John Paul II Parish');
      map['{Minister Name}'] = 'Rev. Fr. ${fullName('minister')}';
    } else if (sacramentType == 'Confirmation') {
      final birthParts = _decomposeDate(val('date_of_birth'));
      final baptismParts = _decomposeDate(val('date_of_baptism'));
      final confirmationParts = _decomposeDate(val('date_of_confirmation'));

      map['{Full Name}'] = fullName('confirmand');
      map['{First Name}'] = val('confirmand_first_name');
      map['{Middle Name}'] = val('confirmand_middle_name');
      map['{Last Name}'] = val('confirmand_last_name');

      map['{Date of Birth}'] = birthParts['formatted']!;
      map['{nth Day of Birth}'] = birthParts['ordinalDay']!;
      map['{Day of Birth}'] = birthParts['day']!;
      map['{Month of Birth}'] = birthParts['month']!;
      map['{Year of Birth}'] = birthParts['year']!;
      map['{Age}'] = val('age');

      map['{Father\'s Name}'] = fullName('father');
      map['{Mother\'s Name}'] = fullName('mother');

      map['{Date of Baptism}'] = baptismParts['formatted']!;
      map['{nth Day of Baptism}'] = baptismParts['ordinalDay']!;
      map['{Month of Baptism}'] = baptismParts['month']!;
      map['{Year of Baptism}'] = baptismParts['year']!;
      map['{Place of Baptism}'] = val('church_baptized');

      map['{Date of Confirmation}'] = confirmationParts['formatted']!;
      map['{nth Day}'] = confirmationParts['ordinalDay']!;
      map['{nth Day of Confirmation}'] = confirmationParts['ordinalDay']!;
      map['{Day of Confirmation}'] = confirmationParts['day']!;
      map['{Month of Confirmation}'] = confirmationParts['month']!;
      map['{Year of Confirmation}'] = confirmationParts['year']!;

      map['{Place of Confirmation}'] = val('parish_name', 'St. John Paul II Parish');
      map['{Godfather\'s Name}'] = fullName('sponsor_1');
      map['{Godmother\'s Name}'] = fullName('sponsor_2');
      map['{Minister Name}'] = 'Rev. Fr. ${fullName('minister')}';
    } else if (sacramentType == 'First Communion') {
      final baptismParts = _decomposeDate(val('baptism_date'));
      final communionParts = _decomposeDate(val('date_of_communion'));

      map['{Full Name}'] = fullName('communicant');
      map['{First Name}'] = val('communicant_first_name');
      map['{Middle Name}'] = val('communicant_middle_name');
      map['{Last Name}'] = val('communicant_last_name');
      map['{Father\'s Name}'] = fullName('father');
      map['{Mother\'s Name}'] = fullName('mother');

      map['{Date of Baptism}'] = baptismParts['formatted']!;
      map['{nth Day of Baptism}'] = baptismParts['ordinalDay']!;
      map['{Month of Baptism}'] = baptismParts['month']!;
      map['{Year of Baptism}'] = baptismParts['year']!;
      map['{Place of Baptism}'] = val('baptism_parish');

      map['{Date of First Communion}'] = communionParts['formatted']!;
      map['{Date of Communion}'] = communionParts['formatted']!;
      map['{nth Day}'] = communionParts['ordinalDay']!;
      map['{nth Day of Communion}'] = communionParts['ordinalDay']!;
      map['{nth Day of First Communion}'] = communionParts['ordinalDay']!;
      map['{Day of Communion}'] = communionParts['day']!;
      map['{Month of Communion}'] = communionParts['month']!;
      map['{Month of First Communion}'] = communionParts['month']!;
      map['{Year of Communion}'] = communionParts['year']!;
      map['{Year of First Communion}'] = communionParts['year']!;

      map['{Place of First Communion}'] = 'St. John Paul II Parish';
      map['{Minister Name}'] = 'Rev. Fr. ${fullName('minister')}';
      map['{Record Number}'] = val('control_number');
      map['{Year}'] = val('year');
    } else if (sacramentType == 'Matrimony') {
      final groomBirthParts = _decomposeDate(val('groom_date_of_birth'));
      final brideBirthParts = _decomposeDate(val('bride_date_of_birth'));
      final marriageParts = _decomposeDate(val('date_of_marriage'));

      map['{Groom Name}'] = fullName('groom');
      map['{Groom Age}'] = val('groom_age');
      map['{Groom Civil Status}'] = val('groom_civil_status');
      map['{Groom Date of Birth}'] = groomBirthParts['formatted']!;
      map['{nth Day of Groom Birth}'] = groomBirthParts['ordinalDay']!;
      map['{Month of Groom Birth}'] = groomBirthParts['month']!;
      map['{Year of Groom Birth}'] = groomBirthParts['year']!;
      map['{Groom Father\'s Name}'] = fullName('groom_father');
      map['{Groom Mother\'s Name}'] = fullName('groom_mother');

      map['{Bride Name}'] = fullName('bride');
      map['{Bride Age}'] = val('bride_age');
      map['{Bride Civil Status}'] = val('bride_civil_status');
      map['{Bride Date of Birth}'] = brideBirthParts['formatted']!;
      map['{nth Day of Bride Birth}'] = brideBirthParts['ordinalDay']!;
      map['{Month of Bride Birth}'] = brideBirthParts['month']!;
      map['{Year of Bride Birth}'] = brideBirthParts['year']!;
      map['{Bride Father\'s Name}'] = fullName('bride_father');
      map['{Bride Mother\'s Name}'] = fullName('bride_mother');

      map['{Marriage Type}'] = val('marriage_type');
      map['{Date of Marriage}'] = marriageParts['formatted']!;
      map['{nth Day}'] = marriageParts['ordinalDay']!;
      map['{nth Day of Marriage}'] = marriageParts['ordinalDay']!;
      map['{Day of Marriage}'] = marriageParts['day']!;
      map['{Month of Marriage}'] = marriageParts['month']!;
      map['{Year of Marriage}'] = marriageParts['year']!;

      map['{Place of Marriage}'] = val('parish_name', 'St. John Paul II Parish');
      map['{Godfather\'s Name}'] = fullName('sponsor_1');
      map['{Godmother\'s Name}'] = fullName('sponsor_2');
      map['{Other Sponsors}'] = val('other_sponsors');
      map['{Marriage License Number}'] = val('marriage_license_no');
      map['{Minister Name}'] = 'Rev. Fr. ${fullName('solemnizer')}';
    } else if (sacramentType == 'Death') {
      final deathParts = _decomposeDate(val('date_of_death'));
      final burialParts = _decomposeDate(val('date_of_burial'));

      map['{Full Name}'] = fullName('deceased');
      map['{First Name}'] = val('deceased_first_name');
      map['{Middle Name}'] = val('deceased_middle_name');
      map['{Last Name}'] = val('deceased_last_name');
      map['{Age}'] = val('age');
      map['{Gender}'] = val('gender');
      map['{Civil Status}'] = val('civil_status');
      map['{Residence}'] = val('residence');
      map['{Spouse\'s Name}'] = fullName('spouse');
      map['{Father\'s Name}'] = fullName('father');
      map['{Mother\'s Name}'] = fullName('mother');

      map['{Date of Death}'] = deathParts['formatted']!;
      map['{nth Day of Death}'] = deathParts['ordinalDay']!;
      map['{Day of Death}'] = deathParts['day']!;
      map['{Month of Death}'] = deathParts['month']!;
      map['{Year of Death}'] = deathParts['year']!;

      map['{Date of Burial}'] = burialParts['formatted']!;
      map['{nth Day}'] = burialParts['ordinalDay']!;
      map['{nth Day of Burial}'] = burialParts['ordinalDay']!;
      map['{Day of Burial}'] = burialParts['day']!;
      map['{Month of Burial}'] = burialParts['month']!;
      map['{Year of Burial}'] = burialParts['year']!;

      map['{Place of Death}'] = val('place_of_burial');
      map['{Place of Burial}'] = val('place_of_burial');
      map['{Cause of Death}'] = val('cause_of_death');
      map['{Minister Name}'] = 'Rev. Fr. ${fullName('minister')}';
    } else if (sacramentType == 'Conversion') {
      final birthParts = _decomposeDate(val('date_of_birth'));
      final receptionParts = _decomposeDate(val('date_of_reception'));
      final priorBaptismParts = _decomposeDate(val('prior_baptism_date'));

      map['{Full Name}'] = fullName('convert');
      map['{First Name}'] = val('convert_first_name');
      map['{Middle Name}'] = val('convert_middle_name');
      map['{Last Name}'] = val('convert_last_name');

      map['{Date of Birth}'] = birthParts['formatted']!;
      map['{nth Day of Birth}'] = birthParts['ordinalDay']!;
      map['{Day of Birth}'] = birthParts['day']!;
      map['{Month of Birth}'] = birthParts['month']!;
      map['{Year of Birth}'] = birthParts['year']!;

      map['{Place of Birth}'] = val('place_of_birth');
      map['{Prior Church}'] = val('prior_baptism_church');
      map['{Prior Baptism Date}'] = priorBaptismParts['formatted']!;
      map['{nth Day of Prior Baptism}'] = priorBaptismParts['ordinalDay']!;
      map['{Month of Prior Baptism}'] = priorBaptismParts['month']!;
      map['{Year of Prior Baptism}'] = priorBaptismParts['year']!;

      map['{Father\'s Name}'] = fullName('father');
      map['{Mother\'s Name}'] = fullName('mother');

      map['{Date of Reception}'] = receptionParts['formatted']!;
      map['{nth Day}'] = receptionParts['ordinalDay']!;
      map['{nth Day of Reception}'] = receptionParts['ordinalDay']!;
      map['{Day of Reception}'] = receptionParts['day']!;
      map['{Month of Reception}'] = receptionParts['month']!;
      map['{Year of Reception}'] = receptionParts['year']!;

      map['{Place of Reception}'] = val('parish_name', 'St. John Paul II Parish');
      map['{Godfather\'s Name}'] = fullName('witness_1');
      map['{Godmother\'s Name}'] = fullName('witness_2');
      map['{Minister Name}'] = 'Rev. Fr. ${fullName('minister')}';
    }

    return map;
  }

  /// Parses template text and replaces all recognized `{Placeholder}` tags.
  static String renderTemplate(String templateText, Map<String, String> values) {
    String output = templateText;
    values.forEach((tag, val) {
      output = output.replaceAll(tag, val);
    });
    return output;
  }

  /// Validates whether a custom user template contains unrecognized `{...}` tags.
  static List<String> findInvalidPlaceholders(String text, String sacramentType) {
    final validTags = getPlaceholdersFor(sacramentType);
    final regExp = RegExp(r'\{[^{}]+\}');
    final matches = regExp.allMatches(text);
    final invalid = <String>[];

    for (final match in matches) {
      final tag = match.group(0)!;
      if (!validTags.contains(tag)) {
        invalid.add(tag);
      }
    }
    return invalid;
  }
}