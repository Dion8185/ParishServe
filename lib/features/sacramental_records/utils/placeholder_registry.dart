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
      '{Place of Birth}',
      '{Gender}',
      '{Legitimacy}',
      '{Father\'s Name}',
      '{Mother\'s Name}',
      '{Godfather\'s Name}',
      '{Godmother\'s Name}',
      '{Other Sponsors}',
      '{Date of Baptism}',
      '{Place of Baptism}',
      '{Minister Name}',
      '{Book Number}',
      '{Page Number}',
      '{Line Number}',
      '{Registry Reference}',
      '{Purpose}',
      '{Date Issued}',
    ],
    'Confirmation': [
      '{Full Name}',
      '{First Name}',
      '{Middle Name}',
      '{Last Name}',
      '{Date of Birth}',
      '{Age}',
      '{Father\'s Name}',
      '{Mother\'s Name}',
      '{Date of Baptism}',
      '{Place of Baptism}',
      '{Date of Confirmation}',
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
    ],
    'First Communion': [
      '{Full Name}',
      '{First Name}',
      '{Middle Name}',
      '{Last Name}',
      '{Father\'s Name}',
      '{Mother\'s Name}',
      '{Date of Baptism}',
      '{Place of Baptism}',
      '{Date of First Communion}',
      '{Place of First Communion}',
      '{Minister Name}',
      '{Record Number}',
      '{Year}',
      '{Purpose}',
      '{Date Issued}',
    ],
    'Matrimony': [
      '{Groom Name}',
      '{Groom Age}',
      '{Groom Civil Status}',
      '{Groom Father\'s Name}',
      '{Groom Mother\'s Name}',
      '{Bride Name}',
      '{Bride Age}',
      '{Bride Civil Status}',
      '{Bride Father\'s Name}',
      '{Bride Mother\'s Name}',
      '{Marriage Type}',
      '{Date of Marriage}',
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
      '{Date of Burial}',
      '{Place of Death}',
      '{Cause of Death}',
      '{Minister Name}',
      '{Book Number}',
      '{Page Number}',
      '{Line Number}',
      '{Registry Reference}',
      '{Purpose}',
      '{Date Issued}',
    ],
    'Conversion': [
      '{Full Name}',
      '{First Name}',
      '{Middle Name}',
      '{Last Name}',
      '{Date of Birth}',
      '{Place of Birth}',
      '{Prior Church}',
      '{Prior Baptism Date}',
      '{Father\'s Name}',
      '{Mother\'s Name}',
      '{Date of Reception}',
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
    ],
  };

  /// Returns supported placeholders for a given sacrament type.
  static List<String> getPlaceholdersFor(String sacramentType) {
    return sacramentPlaceholders[sacramentType] ?? [
      '{Full Name}',
      '{Purpose}',
      '{Date Issued}',
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
    final formattedIssueDate = _formatDate(now.toIso8601String().substring(0, 10));

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
      '{Date Issued}': formattedIssueDate,
      '{Book Number}': book,
      '{Page Number}': page,
      '{Line Number}': line,
      '{Registry Reference}': regRef,
    };

    if (sacramentType == 'Baptism') {
      map['{Full Name}'] = fullName('child');
      map['{First Name}'] = val('child_first_name');
      map['{Middle Name}'] = val('child_middle_name');
      map['{Last Name}'] = val('child_last_name');
      map['{Date of Birth}'] = _formatDate(val('date_of_birth'));
      map['{Place of Birth}'] = val('place_of_birth');
      map['{Gender}'] = val('gender');
      map['{Legitimacy}'] = val('legitimacy');
      map['{Father\'s Name}'] = fullName('father');
      map['{Mother\'s Name}'] = fullName('mother');
      map['{Godfather\'s Name}'] = fullName('sponsor_1');
      map['{Godmother\'s Name}'] = fullName('sponsor_2');
      map['{Other Sponsors}'] = val('other_godparents');
      map['{Date of Baptism}'] = _formatDate(val('date_of_baptism'));
      map['{Place of Baptism}'] = val('place_of_baptism', 'St. John Paul II Parish Church');
      map['{Minister Name}'] = 'Rev. Fr. ${fullName('minister')}';
    } else if (sacramentType == 'Confirmation') {
      map['{Full Name}'] = fullName('confirmand');
      map['{First Name}'] = val('confirmand_first_name');
      map['{Middle Name}'] = val('confirmand_middle_name');
      map['{Last Name}'] = val('confirmand_last_name');
      map['{Date of Birth}'] = _formatDate(val('date_of_birth'));
      map['{Age}'] = val('age');
      map['{Father\'s Name}'] = fullName('father');
      map['{Mother\'s Name}'] = fullName('mother');
      map['{Date of Baptism}'] = _formatDate(val('date_of_baptism'));
      map['{Place of Baptism}'] = val('church_baptized');
      map['{Date of Confirmation}'] = _formatDate(val('date_of_confirmation'));
      map['{Place of Confirmation}'] = val('parish_name', 'St. John Paul II Parish');
      map['{Godfather\'s Name}'] = fullName('sponsor_1');
      map['{Godmother\'s Name}'] = fullName('sponsor_2');
      map['{Minister Name}'] = 'Rev. Fr. ${fullName('minister')}';
    } else if (sacramentType == 'First Communion') {
      map['{Full Name}'] = fullName('communicant');
      map['{First Name}'] = val('communicant_first_name');
      map['{Middle Name}'] = val('communicant_middle_name');
      map['{Last Name}'] = val('communicant_last_name');
      map['{Father\'s Name}'] = fullName('father');
      map['{Mother\'s Name}'] = fullName('mother');
      map['{Date of Baptism}'] = _formatDate(val('baptism_date'));
      map['{Place of Baptism}'] = val('baptism_parish');
      map['{Date of First Communion}'] = _formatDate(val('date_of_communion'));
      map['{Place of First Communion}'] = 'St. John Paul II Parish Church';
      map['{Minister Name}'] = 'Rev. Fr. ${fullName('minister')}';
      map['{Record Number}'] = val('control_number');
      map['{Year}'] = val('year');
    } else if (sacramentType == 'Matrimony') {
      map['{Groom Name}'] = fullName('groom');
      map['{Groom Age}'] = val('groom_age');
      map['{Groom Civil Status}'] = val('groom_civil_status');
      map['{Groom Father\'s Name}'] = fullName('groom_father');
      map['{Groom Mother\'s Name}'] = fullName('groom_mother');
      map['{Bride Name}'] = fullName('bride');
      map['{Bride Age}'] = val('bride_age');
      map['{Bride Civil Status}'] = val('bride_civil_status');
      map['{Bride Father\'s Name}'] = fullName('bride_father');
      map['{Bride Mother\'s Name}'] = fullName('bride_mother');
      map['{Marriage Type}'] = val('marriage_type');
      map['{Date of Marriage}'] = _formatDate(val('date_of_marriage'));
      map['{Place of Marriage}'] = val('parish_name', 'St. John Paul II Parish Church');
      map['{Godfather\'s Name}'] = fullName('sponsor_1');
      map['{Godmother\'s Name}'] = fullName('sponsor_2');
      map['{Other Sponsors}'] = val('other_sponsors');
      map['{Marriage License Number}'] = val('marriage_license_no');
      map['{Minister Name}'] = 'Rev. Fr. ${fullName('solemnizer')}';
    } else if (sacramentType == 'Death') {
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
      map['{Date of Death}'] = _formatDate(val('date_of_death'));
      map['{Date of Burial}'] = _formatDate(val('date_of_burial'));
      map['{Place of Death}'] = val('place_of_burial');
      map['{Cause of Death}'] = val('cause_of_death');
      map['{Minister Name}'] = 'Rev. Fr. ${fullName('minister')}';
    } else if (sacramentType == 'Conversion') {
      map['{Full Name}'] = fullName('convert');
      map['{First Name}'] = val('convert_first_name');
      map['{Middle Name}'] = val('convert_middle_name');
      map['{Last Name}'] = val('convert_last_name');
      map['{Date of Birth}'] = _formatDate(val('date_of_birth'));
      map['{Place of Birth}'] = val('place_of_birth');
      map['{Prior Church}'] = val('prior_baptism_church');
      map['{Prior Baptism Date}'] = _formatDate(val('prior_baptism_date'));
      map['{Father\'s Name}'] = fullName('father');
      map['{Mother\'s Name}'] = fullName('mother');
      map['{Date of Reception}'] = _formatDate(val('date_of_reception'));
      map['{Place of Reception}'] = val('parish_name', 'St. John Paul II Parish Church');
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

  static String _formatDate(String? raw) {
    if (raw == null || raw.trim().isEmpty || raw == '—') return '—';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;

    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[parsed.month - 1]} ${parsed.day}, ${parsed.year}';
  }
}