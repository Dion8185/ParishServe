import 'dart:convert';
import 'dart:io';
import '../models/liturgical_event_model.dart';

class LiturgicalCalendarService {
  static const String _apiEndpoint = 'https://litcal.johnromanodorazio.com/api/dev/calendar/nation/PH';
  static final Map<int, List<LiturgicalEvent>> _cachedYears = {};

  static Future<List<LiturgicalEvent>> getCalendarForYear(int year) async {
    if (_cachedYears.containsKey(year) && _cachedYears[year]!.isNotEmpty) {
      return _cachedYears[year]!;
    }

    List<LiturgicalEvent> events = [];

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final request = await client.getUrl(Uri.parse('$_apiEndpoint/$year'));
      final response = await request.close();

      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final data = jsonDecode(responseBody);

        if (data is Map && data.containsKey('litcal')) {
          final list = data['litcal'] as List;
          events = list.map((item) => LiturgicalEvent.fromJson(item as Map<String, dynamic>)).toList();
        } else if (data is List) {
          events = data.map((item) => LiturgicalEvent.fromJson(item as Map<String, dynamic>)).toList();
        }
      }
    } catch (_) {
      // Fall back to built-in Philippine National defaults
    }

    events = _mergeWithPhilippineNationalCalendar(events, year);
    _cachedYears[year] = events;
    return events;
  }

  static Future<bool> isDateBlocked(DateTime date) async {
    final events = await getCalendarForYear(date.year);
    return events.any((e) =>
    e.blocksAppointments &&
        e.date.year == date.year &&
        e.date.month == date.month &&
        e.date.day == date.day);
  }

  static Future<LiturgicalEvent?> getBlockingCelebration(DateTime date) async {
    final events = await getCalendarForYear(date.year);
    try {
      return events.firstWhere((e) =>
      e.blocksAppointments &&
          e.date.year == date.year &&
          e.date.month == date.month &&
          e.date.day == date.day);
    } catch (_) {
      return null;
    }
  }

  static bool isDateBlockedSync(DateTime date) {
    final events = _cachedYears[date.year] ?? _getPhilippineNationalDefaults(date.year);
    return events.any((e) =>
    e.blocksAppointments &&
        e.date.year == date.year &&
        e.date.month == date.month &&
        e.date.day == date.day);
  }

  static List<LiturgicalEvent> getCelebrationsForDateSync(DateTime date) {
    final events = _cachedYears[date.year] ?? _getPhilippineNationalDefaults(date.year);
    return events.where((e) =>
    e.date.year == date.year &&
        e.date.month == date.month &&
        e.date.day == date.day).toList();
  }

  static List<LiturgicalEvent> _mergeWithPhilippineNationalCalendar(List<LiturgicalEvent> apiEvents, int year) {
    final defaults = _getPhilippineNationalDefaults(year);
    final Set<String> existingKeys = apiEvents.map((e) => '${e.date.month}-${e.date.day}').toSet();

    final List<LiturgicalEvent> merged = List.from(apiEvents);
    for (final def in defaults) {
      final key = '${def.date.month}-${def.date.day}';
      if (!existingKeys.contains(key)) {
        merged.add(def);
      }
    }
    return merged;
  }

  static List<LiturgicalEvent> _getPhilippineNationalDefaults(int year) {
    final easter = _calculateEaster(year);
    final ashWednesday = easter.subtract(const Duration(days: 46));
    final holyThursday = easter.subtract(const Duration(days: 3));
    final goodFriday = easter.subtract(const Duration(days: 2));
    final holySaturday = easter.subtract(const Duration(days: 1));
    final ascension = easter.add(const Duration(days: 42));
    final pentecost = easter.add(const Duration(days: 49));
    final trinitySunday = easter.add(const Duration(days: 56));
    final corpusChristi = easter.add(const Duration(days: 63));
    final sacredHeart = easter.add(const Duration(days: 68));

    // 3rd Sunday of January: Feast of the Santo Niño
    final jan1 = DateTime(year, 1, 1);
    final daysToFirstSunday = (7 - jan1.weekday) % 7;
    final firstSundayOfJan = jan1.add(Duration(days: daysToFirstSunday));
    final santoNinoDate = firstSundayOfJan.add(const Duration(days: 14));

    return [
      // ==========================================
      // GLOBAL / UNIVERSAL LITURGICAL EVENTS (RED)
      // ==========================================
      LiturgicalEvent(
        key: 'mary_mother_of_god',
        name: 'Solemnity of Mary, the Holy Mother of God',
        date: DateTime(year, 1, 1),
        colorName: 'white',
        grade: 6,
        gradeName: 'Solemnity',
        isHolyDayOfObligation: true,
        blocksAppointments: true,
        isPhilippineSpecific: false,
      ),
      LiturgicalEvent(
        key: 'ash_wednesday',
        name: 'Ash Wednesday (Universal Day of Fast and Abstinence)',
        date: ashWednesday,
        colorName: 'purple',
        grade: 6,
        gradeName: 'Solemn Fast',
        blocksAppointments: true,
        isPhilippineSpecific: false,
      ),
      LiturgicalEvent(
        key: 'st_joseph',
        name: 'Solemnity of Saint Joseph, Spouse of the Blessed Virgin Mary',
        date: DateTime(year, 3, 19),
        colorName: 'white',
        grade: 6,
        gradeName: 'Solemnity',
        blocksAppointments: true,
        isPhilippineSpecific: false,
      ),
      LiturgicalEvent(
        key: 'annunciation',
        name: 'Solemnity of the Annunciation of the Lord',
        date: DateTime(year, 3, 25),
        colorName: 'white',
        grade: 6,
        gradeName: 'Solemnity',
        blocksAppointments: true,
        isPhilippineSpecific: false,
      ),
      LiturgicalEvent(
        key: 'holy_thursday',
        name: 'Holy Thursday (Evening Mass of the Lord\'s Supper)',
        date: holyThursday,
        colorName: 'white',
        grade: 7,
        gradeName: 'Paschal Triduum',
        blocksAppointments: true,
        isPhilippineSpecific: false,
      ),
      LiturgicalEvent(
        key: 'good_friday',
        name: 'Good Friday of the Passion of the Lord',
        date: goodFriday,
        colorName: 'red',
        grade: 7,
        gradeName: 'Paschal Triduum',
        blocksAppointments: true,
        isPhilippineSpecific: false,
      ),
      LiturgicalEvent(
        key: 'holy_saturday',
        name: 'Holy Saturday (The Easter Vigil in the Holy Night)',
        date: holySaturday,
        colorName: 'white',
        grade: 7,
        gradeName: 'Paschal Triduum',
        blocksAppointments: true,
        isPhilippineSpecific: false,
      ),
      LiturgicalEvent(
        key: 'easter_sunday',
        name: 'Easter Sunday of the Resurrection of the Lord',
        date: easter,
        colorName: 'white',
        grade: 7,
        gradeName: 'Solemnity of Solemnities',
        blocksAppointments: true,
        isPhilippineSpecific: false,
      ),
      LiturgicalEvent(
        key: 'ascension',
        name: 'Solemnity of the Ascension of the Lord',
        date: ascension,
        colorName: 'white',
        grade: 6,
        gradeName: 'Solemnity',
        blocksAppointments: true,
        isPhilippineSpecific: false,
      ),
      LiturgicalEvent(
        key: 'pentecost',
        name: 'Solemnity of Pentecost',
        date: pentecost,
        colorName: 'red',
        grade: 6,
        gradeName: 'Solemnity',
        blocksAppointments: true,
        isPhilippineSpecific: false,
      ),
      LiturgicalEvent(
        key: 'trinity_sunday',
        name: 'Solemnity of the Most Holy Trinity',
        date: trinitySunday,
        colorName: 'white',
        grade: 6,
        gradeName: 'Solemnity',
        blocksAppointments: true,
        isPhilippineSpecific: false,
      ),
      LiturgicalEvent(
        key: 'corpus_christi',
        name: 'Solemnity of the Most Holy Body and Blood of Christ',
        date: corpusChristi,
        colorName: 'white',
        grade: 6,
        gradeName: 'Solemnity',
        blocksAppointments: true,
        isPhilippineSpecific: false,
      ),
      LiturgicalEvent(
        key: 'sacred_heart',
        name: 'Solemnity of the Most Sacred Heart of Jesus',
        date: sacredHeart,
        colorName: 'white',
        grade: 6,
        gradeName: 'Solemnity',
        blocksAppointments: true,
        isPhilippineSpecific: false,
      ),
      LiturgicalEvent(
        key: 'assumption',
        name: 'Solemnity of the Assumption of the Blessed Virgin Mary',
        date: DateTime(year, 8, 15),
        colorName: 'white',
        grade: 6,
        gradeName: 'Solemnity',
        blocksAppointments: true,
        isPhilippineSpecific: false,
      ),
      LiturgicalEvent(
        key: 'all_saints',
        name: 'Solemnity of All Saints (Holy Day of Obligation)',
        date: DateTime(year, 11, 1),
        colorName: 'white',
        grade: 6,
        gradeName: 'Solemnity',
        isHolyDayOfObligation: true,
        blocksAppointments: true,
        isPhilippineSpecific: false,
      ),
      LiturgicalEvent(
        key: 'all_souls',
        name: 'The Commemoration of All the Faithful Departed (All Souls)',
        date: DateTime(year, 11, 2),
        colorName: 'purple',
        grade: 5,
        gradeName: 'Major Commemoration',
        blocksAppointments: true,
        isPhilippineSpecific: false,
      ),
      LiturgicalEvent(
        key: 'christmas_day',
        name: 'The Nativity of the Lord - Christmas (Holy Day of Obligation)',
        date: DateTime(year, 12, 25),
        colorName: 'white',
        grade: 6,
        gradeName: 'Solemnity',
        isHolyDayOfObligation: true,
        blocksAppointments: true,
        isPhilippineSpecific: false,
      ),

      // ==========================================
      // PHILIPPINE-SPECIFIC CATHOLIC EVENTS (BLUE)
      // ==========================================
      LiturgicalEvent(
        key: 'black_nazarene',
        name: 'Feast of the Black Nazarene (Traslacion)',
        date: DateTime(year, 1, 9),
        colorName: 'red',
        grade: 4,
        gradeName: 'Feast in the Philippines',
        blocksAppointments: false,
        isPhilippineSpecific: true,
      ),
      LiturgicalEvent(
        key: 'santo_nino',
        name: 'Feast of the Santo Niño (Patron of the Philippines)',
        date: santoNinoDate,
        colorName: 'white',
        grade: 5,
        gradeName: 'Feast of the Lord in the Philippines',
        blocksAppointments: true,
        isPhilippineSpecific: true,
      ),
      LiturgicalEvent(
        key: 'nativity_of_mary_ph',
        name: 'Feast of the Nativity of the Blessed Virgin Mary (National Feast in PH)',
        date: DateTime(year, 9, 8),
        colorName: 'white',
        grade: 4,
        gradeName: 'Special Feast in the Philippines',
        blocksAppointments: false,
        isPhilippineSpecific: true,
      ),
      LiturgicalEvent(
        key: 'st_lorenzo_ruiz',
        name: 'Feast of Saint Lorenzo Ruiz and Companions (First Filipino Martyr)',
        date: DateTime(year, 9, 28),
        colorName: 'red',
        grade: 4,
        gradeName: 'National Feast in the Philippines',
        blocksAppointments: false,
        isPhilippineSpecific: true,
      ),
      LiturgicalEvent(
        key: 'st_john_paul_ii',
        name: 'Solemnity of Saint John Paul II, Pope (Parish Titular Feast Day)',
        date: DateTime(year, 10, 22),
        colorName: 'white',
        grade: 6,
        gradeName: 'Parish Titular Solemnity',
        blocksAppointments: true,
        isPhilippineSpecific: true,
      ),
      LiturgicalEvent(
        key: 'immaculate_conception_ph',
        name: 'Solemnity of the Immaculate Conception (Principal Patroness of the Philippines)',
        date: DateTime(year, 12, 8),
        colorName: 'white',
        grade: 6,
        gradeName: 'National Patronal Solemnity (PH)',
        isHolyDayOfObligation: true,
        blocksAppointments: true,
        isPhilippineSpecific: true,
      ),
      LiturgicalEvent(
        key: 'our_lady_of_guadalupe',
        name: 'Feast of Our Lady of Guadalupe (Secondary Patroness of the Philippines)',
        date: DateTime(year, 12, 12),
        colorName: 'white',
        grade: 4,
        gradeName: 'Feast in the Philippines',
        blocksAppointments: false,
        isPhilippineSpecific: true,
      ),
    ];
  }

  static DateTime _calculateEaster(int year) {
    final a = year % 19;
    final b = year ~/ 100;
    final c = year % 100;
    final d = b ~/ 4;
    final e = b % 4;
    final f = (b + 8) ~/ 25;
    final g = (b - f + 1) ~/ 3;
    final h = (19 * a + b - d - g + 15) % 30;
    final i = c ~/ 4;
    final k = c % 4;
    final l = (32 + 2 * e + 2 * i - h - k) % 7;
    final m = (a + 11 * h + 22 * l) ~/ 451;
    final month = (h + l - 7 * m + 114) ~/ 31;
    final day = ((h + l - 7 * m + 114) % 31) + 1;
    return DateTime(year, month, day);
  }
}