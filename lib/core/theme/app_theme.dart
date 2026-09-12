import 'package:flutter/material.dart';
import '../constants/colors.dart';

class ParishTheme {
  // Light Theme Configuration
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      colorScheme: ColorScheme.fromSeed(
        seedColor: ParishColors.marianBlue,
        brightness: Brightness.light,
        primary: ParishColors.marianBlue,
        secondary: ParishColors.goldAccent,
        surface: const Color(0xFFFFFFFF),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
        bodyMedium: TextStyle(fontSize: 15, color: Color(0xFF475569)),
      ),
    );
  }

  // Dark Theme Configuration
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      colorScheme: ColorScheme.fromSeed(
        seedColor: ParishColors.marianBlue,
        brightness: Brightness.dark,
        primary: const Color(0xFF3B82F6),
        secondary: ParishColors.goldAccent,
        surface: const Color(0xFF1E293B),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFF8FAFC)),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFFF8FAFC)),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFFF8FAFC)),
        bodyMedium: TextStyle(fontSize: 15, color: Color(0xFF94A3B8)),
      ),
    );
  }
}