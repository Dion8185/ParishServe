import 'package:flutter/material.dart';
import '../constants/colors.dart';

class ParishTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: ParishColors.backgroundLight,
      colorScheme: ColorScheme.fromSeed(
        seedColor: ParishColors.marianBlue,
        primary: ParishColors.marianBlue,
        secondary: ParishColors.goldAccent,
        surface: ParishColors.cardWhite,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: ParishColors.textDark,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: ParishColors.textDark,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: ParishColors.textDark,
        ),
        bodyMedium: TextStyle(
          fontSize: 15,
          color: ParishColors.textMuted,
        ),
      ),
    );
  }
}