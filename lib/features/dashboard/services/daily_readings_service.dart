import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/daily_reading_model.dart';

class DailyReadingsService {
  static const String _baseUrl = 'https://cpbjr.github.io/catholic-readings-api';
  static DailyReadingModel? _cachedTodayReading;
  static String? _cachedDateKey;

  /// Fetches daily Mass readings and saint/feast data for a given date (defaults to today)
  static Future<DailyReadingModel?> getDailyReading({DateTime? targetDate}) async {
    final date = targetDate ?? DateTime.now();
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final dateKey = '$year-$month-$day';

    // In-memory cache hit for today
    if (_cachedTodayReading != null && _cachedDateKey == dateKey) {
      return _cachedTodayReading;
    }

    try {
      final readingsUrl = Uri.parse('$_baseUrl/readings/$year/$month-$day.json');
      final calendarUrl = Uri.parse('$_baseUrl/liturgical-calendar/$year/$month-$day.json');

      // Concurrent fetch of readings and liturgical calendar
      final responses = await Future.wait([
        http.get(readingsUrl).timeout(const Duration(seconds: 6)),
        http.get(calendarUrl).timeout(const Duration(seconds: 6)),
      ]);

      if (responses[0].statusCode == 200) {
        final readingsJson = jsonDecode(responses[0].body) as Map<String, dynamic>;
        Map<String, dynamic>? calendarJson;

        if (responses[1].statusCode == 200) {
          try {
            calendarJson = jsonDecode(responses[1].body) as Map<String, dynamic>;
          } catch (_) {}
        }

        final model = DailyReadingModel.fromJson(readingsJson, calendarJson);
        _cachedTodayReading = model;
        _cachedDateKey = dateKey;
        return model;
      }
    } catch (e) {
      debugPrint('Notice: Error fetching Catholic daily readings from API: $e');
    }

    return null;
  }
}