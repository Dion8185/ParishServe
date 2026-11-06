import 'package:flutter_test/flutter_test.dart';
import 'package:parishserve/features/sacramental_records/validators/sacramental_validators.dart';

void main() {
  group('Sacramental Date Validation Rules', () {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final pastDate = today.subtract(const Duration(days: 365));
    final futureDate = today.add(const Duration(days: 30));
    final dob = today.subtract(const Duration(days: 3650));

    test('Date of Baptism - Past, Present, and Future dates allowed', () {
      expect(SacramentalValidators.validateBaptismDate(pastDate, dob), isNull);
      expect(SacramentalValidators.validateBaptismDate(today, dob), isNull);
      expect(SacramentalValidators.validateBaptismDate(futureDate, dob), isNull);

      // Invalid relative order check remains working
      final invalidBaptism = dob.subtract(const Duration(days: 10));
      expect(
        SacramentalValidators.validateBaptismDate(invalidBaptism, dob),
        equals('Date of Baptism cannot be earlier than Date of Birth.'),
      );
    });

    test('Date of Confirmation - Past, Present, and Future dates allowed', () {
      final baptismDate = dob.add(const Duration(days: 100));
      expect(SacramentalValidators.validateConfirmationDate(pastDate, baptismDate), isNull);
      expect(SacramentalValidators.validateConfirmationDate(today, baptismDate), isNull);
      expect(SacramentalValidators.validateConfirmationDate(futureDate, baptismDate), isNull);

      // Relative chronological integrity check remains working
      final invalidConf = baptismDate.subtract(const Duration(days: 10));
      expect(
        SacramentalValidators.validateConfirmationDate(invalidConf, baptismDate),
        equals('Date of Confirmation cannot be earlier than Date of Baptism.'),
      );
    });

    test('Date of First Holy Communion - Past, Present, and Future dates allowed', () {
      final baptismDate = dob.add(const Duration(days: 100));
      expect(SacramentalValidators.validateCommunionDate(pastDate, baptismDate), isNull);
      expect(SacramentalValidators.validateCommunionDate(today, baptismDate), isNull);
      expect(SacramentalValidators.validateCommunionDate(futureDate, baptismDate), isNull);

      final invalidCommunion = baptismDate.subtract(const Duration(days: 10));
      expect(
        SacramentalValidators.validateCommunionDate(invalidCommunion, baptismDate),
        equals('Date of First Communion cannot be earlier than Date of Baptism.'),
      );
    });

    test('Date of Death & Burial - Past, Present, and Future dates allowed', () {
      final deathDatePast = today.subtract(const Duration(days: 10));
      final burialDateFuture = today.add(const Duration(days: 5));

      expect(SacramentalValidators.validateBurialDate(today, deathDatePast), isNull);
      expect(SacramentalValidators.validateBurialDate(burialDateFuture, today), isNull);

      // Invalid relative order check remains working
      expect(
        SacramentalValidators.validateBurialDate(pastDate, today),
        equals('Date of Burial cannot be earlier than Date of Death.'),
      );
    });

    test('Date of Reception (Conversion) - Past, Present, and Future dates allowed', () {
      expect(SacramentalValidators.validateReceptionDate(pastDate, dob), isNull);
      expect(SacramentalValidators.validateReceptionDate(today, dob), isNull);
      expect(SacramentalValidators.validateReceptionDate(futureDate, dob), isNull);
    });

    test('Certificate Date of Release - Present and Future only (No past dates)', () {
      expect(SacramentalValidators.validateCertificateReleaseDate(today), isNull);
      expect(SacramentalValidators.validateCertificateReleaseDate(futureDate), isNull);

      expect(
        SacramentalValidators.validateCertificateReleaseDate(pastDate),
        equals('Date Released must be today or a future date.'),
      );
    });

    test('Non-Sacrament Date Fields - Strict non-future rule preserved', () {
      expect(SacramentalValidators.validateNotFutureDate(today, 'Registry Date'), isNull);
      expect(SacramentalValidators.validateNotFutureDate(pastDate, 'Registry Date'), isNull);

      expect(
        SacramentalValidators.validateNotFutureDate(futureDate, 'Registry Date'),
        equals('Registry Date cannot be a future date.'),
      );

      expect(SacramentalValidators.validateDateOfBirth(dob), isNull);
      expect(
        SacramentalValidators.validateDateOfBirth(futureDate),
        equals('Date of Birth cannot be a future date.'),
      );
    });
  });
}
