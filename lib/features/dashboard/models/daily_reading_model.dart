class DailyReadingModel {
  final String date;
  final String monthDay;
  final String season;
  final String firstReading;
  final String psalm;
  final String? secondReading;
  final String gospel;
  final String? usccbLink;

  // Optional celebration & saint details from liturgical calendar endpoint
  final String? celebrationName;
  final String? celebrationType;
  final String? saintQuote;
  final String? saintDescription;
  final String? saintImageUrl;

  DailyReadingModel({
    required this.date,
    required this.monthDay,
    required this.season,
    required this.firstReading,
    required this.psalm,
    this.secondReading,
    required this.gospel,
    this.usccbLink,
    this.celebrationName,
    this.celebrationType,
    this.saintQuote,
    this.saintDescription,
    this.saintImageUrl,
  });

  factory DailyReadingModel.fromJson(
      Map<String, dynamic> readingsJson, [
        Map<String, dynamic>? calendarJson,
      ]) {
    final readingsMap = readingsJson['readings'] as Map<String, dynamic>? ?? {};

    Map<String, dynamic>? celebrationMap;
    if (calendarJson != null && calendarJson['celebration'] is Map) {
      celebrationMap = calendarJson['celebration'] as Map<String, dynamic>;
    }

    return DailyReadingModel(
      date: readingsJson['date']?.toString() ?? '',
      monthDay: readingsJson['monthDay']?.toString() ?? '',
      season: readingsJson['season']?.toString() ?? 'Ordinary Time',
      firstReading: readingsMap['firstReading']?.toString() ?? 'First Reading not specified',
      psalm: readingsMap['psalm']?.toString() ?? 'Responsorial Psalm not specified',
      secondReading: readingsMap['secondReading']?.toString(),
      gospel: readingsMap['gospel']?.toString() ?? 'Gospel not specified',
      usccbLink: readingsJson['usccbLink']?.toString(),
      celebrationName: celebrationMap?['name']?.toString(),
      celebrationType: celebrationMap?['type']?.toString(),
      saintQuote: celebrationMap?['quote']?.toString(),
      saintDescription: celebrationMap?['description']?.toString(),
      saintImageUrl: celebrationMap?['image']?.toString(),
    );
  }
}