/// Canonical & Demographic Validation Utilities for Sacramental Records (Liber Ordinarius)
/// Saint John Paul II Parish - Diocese of San Pablo
class SacramentalValidators {
  SacramentalValidators._(); // Private constructor to prevent instantiation

  // ===========================================================================
  // Regex Patterns
  // ===========================================================================

  /// Allows English alphabet, Latin/Spanish diacritics (À-ÿ, Ñ, ñ),
  /// hyphens, periods, single quotes, apostrophes, and spaces.
  static final RegExp nameRegExp = RegExp(r"^[a-zA-ZÀ-ÿÑñ\s\.\-\'’]+$");

  /// Standard Philippine mobile numbers (09XXXXXXXXX or +639XXXXXXXXX)
  /// and standard 7- to 10-digit landline numbers.
  static final RegExp phoneRegExp = RegExp(r'^(09\d{9}|\+639\d{9}|\d{7,10})$');

  /// Form control numbers: FCM-YYYY-XXXX
  static final RegExp communionControlNoRegExp = RegExp(r'^FCM-\d{4}-\d{4}$');

  // ===========================================================================
  // 1. Physical Ledger Coordinates (Canon 535 Bounds)
  // ===========================================================================

  /// Validates physical ledger Book Number: Integer between 1 and 200.
  static String? validateBookNumber(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Book number is required.';
    final num = int.tryParse(text);
    if (num == null) return 'Book number must be a valid number.';
    if (num < 1 || num > 200) return 'Book number must be between 1 and 200.';
    return null;
  }

  /// Validates physical ledger Page Number: Integer between 1 and 100.
  static String? validatePageNumber(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Page number is required.';
    final num = int.tryParse(text);
    if (num == null) return 'Page number must be a valid number.';
    if (num < 1 || num > 100) return 'Page number must be between 1 and 100.';
    return null;
  }

  /// Validates physical ledger Line Number: Integer between 1 and 10.
  static String? validateLineNumber(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Line number is required.';
    final num = int.tryParse(text);
    if (num == null) return 'Line number must be a valid number.';
    if (num < 1 || num > 10) return 'Line number must be between 1 and 10.';
    return null;
  }

  // ===========================================================================
  // 2. Personal & Lineage Names
  // ===========================================================================

  /// Validates personal names (First, Middle, Last names, Minister, Sponsors).
  /// Enforces alphabet + diacritics check and minimum length of 2 characters.
  static String? validateName(
      String? value,
      String fieldName, {
        bool isRequired = true,
        int minLength = 2,
        int maxLength = 100,
      }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      if (isRequired) return '$fieldName is required.';
      return null;
    }

    if (text.length < minLength) {
      return '$fieldName must be at least $minLength characters.';
    }

    if (text.length > maxLength) {
      return '$fieldName cannot exceed $maxLength characters.';
    }

    if (!nameRegExp.hasMatch(text)) {
      return 'Enter a valid name (letters, hyphens, and spaces only).';
    }

    return null;
  }

  /// Validates generic required text fields (Addresses, Parishes, Places).
  static String? validateRequiredText(
      String? value,
      String fieldName, {
        int minLength = 2,
        int maxLength = 255,
      }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '$fieldName is required.';
    if (text.length < minLength) {
      return '$fieldName must be at least $minLength characters.';
    }
    if (text.length > maxLength) {
      return '$fieldName cannot exceed $maxLength characters.';
    }
    return null;
  }

  // ===========================================================================
  // 3. Contact, Demographics & Stipends
  // ===========================================================================

  /// Validates Philippine contact number.
  static String? validatePhoneNumber(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null; // Optional unless specified

    final clean = text.replaceAll(RegExp(r'[\s\-]'), '');
    if (!phoneRegExp.hasMatch(clean)) {
      return 'Enter a valid phone number (e.g., 09171234567 or (049) 501-1234).';
    }
    return null;
  }

  /// Validates monetary stipend / church offering (Non-negative decimal).
  static String? validateStipend(String? value, {bool allowZero = true}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null; // Blank indicates ₱0.00 / Gratis

    final amount = double.tryParse(text);
    if (amount == null) {
      return 'Enter a valid monetary amount (e.g. 150.00).';
    }

    if (!allowZero && amount <= 0) {
      return 'Stipend must be greater than 0.00.';
    }

    if (amount < 0) {
      return 'Stipend cannot be negative.';
    }

    return null;
  }

  /// Validates whole-number age (Canonically restricted between 0 and 150).
  static String? validateWholeNumberAge(String? value, {bool isRequired = true}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      if (isRequired) return 'Age is required.';
      return null;
    }

    final number = int.tryParse(text);
    if (number == null || number < 0) {
      return 'Please enter a valid whole number (e.g. 24).';
    }

    if (number > 150) {
      return 'Please enter a realistic age between 0 and 150.';
    }

    return null;
  }

  /// Validates First Communion archival reception year.
  static String? validateCommunionYear(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Communion year is required.';
    final year = int.tryParse(text);
    final currentYear = DateTime.now().year;

    if (year == null || year < 1900 || year > currentYear + 1) {
      return 'Please enter a valid year between 1900 and ${currentYear + 1}.';
    }

    return null;
  }

  /// Validates Control Number format (e.g. FCM-2026-0001).
  static String? validateCommunionControlNumber(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Control number is required.';
    if (!communionControlNoRegExp.hasMatch(text)) {
      return 'Invalid format. Expected: FCM-YYYY-XXXX (e.g. FCM-2026-0001).';
    }
    return null;
  }

  // ===========================================================================
  // 4. Chronological & Canonical Integrity Checks
  // ===========================================================================

  /// Validates Date of Birth (Must not be in the future).
  static String? validateDateOfBirth(DateTime? dob) {
    if (dob == null) return 'Date of Birth is required.';
    if (dob.isAfter(DateTime.now())) {
      return 'Date of Birth cannot be in the future.';
    }
    return null;
  }

  /// Validates Date of Baptism relative to Date of Birth.
  static String? validateBaptismDate(DateTime? baptismDate, DateTime? dob) {
    if (baptismDate == null) return 'Date of Baptism is required.';
    if (dob != null && baptismDate.isBefore(dob)) {
      return 'Date of Baptism cannot be earlier than Date of Birth.';
    }
    return null;
  }

  /// Validates Confirmation Date relative to required prior Baptism Date.
  static String? validateConfirmationDate(DateTime? confirmationDate, DateTime? baptismDate) {
    if (confirmationDate == null) return 'Date of Confirmation is required.';
    if (baptismDate != null && confirmationDate.isBefore(baptismDate)) {
      return 'Date of Confirmation cannot be earlier than Date of Baptism.';
    }
    return null;
  }

  /// Validates First Holy Communion date relative to prior Baptism Date.
  static String? validateCommunionDate(DateTime? communionDate, DateTime? baptismDate) {
    if (communionDate == null) return 'Date of First Holy Communion is required.';
    if (baptismDate != null && communionDate.isBefore(baptismDate)) {
      return 'Date of First Communion cannot be earlier than Date of Baptism.';
    }
    return null;
  }

  /// Validates Death and Burial dates consistency.
  static String? validateBurialDate(DateTime? burialDate, DateTime? deathDate) {
    if (deathDate == null) return 'Date of Death is required.';
    if (burialDate == null) return 'Date of Burial is required.';
    if (burialDate.isBefore(deathDate)) {
      return 'Date of Burial cannot be earlier than Date of Death.';
    }
    return null;
  }

  /// Validates Reception into Full Communion (Conversion) date relative to birth date.
  static String? validateReceptionDate(DateTime? receptionDate, DateTime? dob) {
    if (receptionDate == null) return 'Date of Reception into Full Communion is required.';
    if (dob != null && receptionDate.isBefore(dob)) {
      return 'Date of Reception cannot be earlier than Date of Birth.';
    }
    return null;
  }

  /// Validates prior non-Catholic baptism date relative to birth date.
  static String? validatePriorBaptismDate(DateTime? priorBaptismDate, DateTime? dob) {
    if (priorBaptismDate == null) return null; // Optional
    if (dob != null && priorBaptismDate.isBefore(dob)) {
      return 'Prior Baptism Date cannot be earlier than Date of Birth.';
    }
    return null;
  }
}