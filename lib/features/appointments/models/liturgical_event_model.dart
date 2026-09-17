import 'package:flutter/material.dart';

class LiturgicalEvent {
  final String key;
  final String name;
  final DateTime date;
  final String colorName; // white, red, purple, green
  final int grade; // 0=weekday, 3=memorial, 4=feast, 5=feast of the lord, 6=solemnity, 7=higher solemnity
  final String gradeName; // Solemnity, Feast, Memorial, etc.
  final bool isHolyDayOfObligation;
  final bool blocksAppointments;
  final bool isPhilippineSpecific; // true = Philippine Proper (Blue), false = Universal/Global (Red)
  final String? common;

  LiturgicalEvent({
    required this.key,
    required this.name,
    required this.date,
    required this.colorName,
    required this.grade,
    required this.gradeName,
    this.isHolyDayOfObligation = false,
    this.blocksAppointments = false,
    this.isPhilippineSpecific = false,
    this.common,
  });

  /// Event category color: Blue for PH-specific, Red for Global
  Color get categoryBadgeColor {
    return isPhilippineSpecific ? const Color(0xFF2563EB) : const Color(0xFFDC2626);
  }

  Color get categorySurfaceColor {
    return isPhilippineSpecific ? const Color(0xFFEFF6FF) : const Color(0xFFFEF2F2);
  }

  /// Official vestment color (white/gold, red, violet, green)
  Color get liturgicalColor {
    switch (colorName.toLowerCase()) {
      case 'white':
        return const Color(0xFFD4AF37);
      case 'red':
        return const Color(0xFFDC2626);
      case 'purple':
      case 'violet':
        return const Color(0xFF7C3AED);
      case 'green':
      default:
        return const Color(0xFF15803D);
    }
  }

  factory LiturgicalEvent.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    if (json['date'] is int) {
      parsedDate = DateTime.fromMillisecondsSinceEpoch((json['date'] as int) * 1000);
    } else {
      parsedDate = DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now();
    }

    final gradeNum = int.tryParse(json['grade']?.toString() ?? '0') ?? 0;
    final nameStr = json['name']?.toString() ?? 'Liturgical Celebration';

    final isBlocked = gradeNum >= 6 ||
        nameStr.toLowerCase().contains('ash wednesday') ||
        nameStr.toLowerCase().contains('good friday') ||
        nameStr.toLowerCase().contains('holy saturday') ||
        nameStr.toLowerCase().contains('holy thursday') ||
        nameStr.toLowerCase().contains('all souls');

    final bool isPh = json['is_philippine'] == true ||
        json['national'] == true ||
        nameStr.toLowerCase().contains('santo niño') ||
        nameStr.toLowerCase().contains('nazarene') ||
        nameStr.toLowerCase().contains('lorenzo ruiz') ||
        nameStr.toLowerCase().contains('john paul ii') ||
        nameStr.toLowerCase().contains('philippines');

    return LiturgicalEvent(
      key: json['event_key']?.toString() ?? json['key']?.toString() ?? '',
      name: nameStr,
      date: DateTime(parsedDate.year, parsedDate.month, parsedDate.day),
      colorName: (json['color'] is List && (json['color'] as List).isNotEmpty)
          ? json['color'][0].toString()
          : (json['color']?.toString() ?? 'white'),
      grade: gradeNum,
      gradeName: json['grade_display']?.toString() ?? (gradeNum >= 6 ? 'Solemnity' : 'Feast'),
      isHolyDayOfObligation: json['is_holy_day'] == true || gradeNum == 7,
      blocksAppointments: isBlocked,
      isPhilippineSpecific: isPh,
      common: json['common']?.toString(),
    );
  }
}