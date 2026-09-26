import 'package:flutter/material.dart';
import '../constants/colors.dart';

class ParishTheme {
  // ===========================================================================
  // Light Theme Configuration (Clean Parchment & Deep Marian Navy)
  // ===========================================================================
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      cardColor: const Color(0xFFFFFFFF),
      cardTheme: const CardThemeData(
        color: Color(0xFFFFFFFF),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Color(0xFFFFFFFF),
        surfaceTintColor: Colors.transparent,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFFFFFFF),
        foregroundColor: Color(0xFF1E293B),
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFCBD5E1),
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: ParishColors.marianBlue, width: 1.8),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFFFFFFFF),
        indicatorColor: const Color(0xFFEDF4FB),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: ParishColors.marianBlue,
            );
          }
          return const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Color(0xFF475569),
          );
        }),
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: ParishColors.marianBlue,
        brightness: Brightness.light,
        primary: ParishColors.marianBlue,
        secondary: ParishColors.goldAccent,
        surface: const Color(0xFFFFFFFF),
        onSurface: const Color(0xFF1E293B),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
        bodyMedium: TextStyle(fontSize: 15, color: Color(0xFF475569)),
      ),
    );
  }

  // ===========================================================================
  // Dark Theme Configuration (Nocturnal Marian Slate & Cerulean High-Contrast)
  // ===========================================================================
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      cardColor: const Color(0xFF1E293B),
      cardTheme: const CardThemeData(
        color: Color(0xFF1E293B),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Color(0xFF1E293B),
        surfaceTintColor: Colors.transparent,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E293B),
        foregroundColor: Color(0xFFF8FAFC),
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF334155),
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF0F172A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF60A5FA), width: 1.8),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF1E293B),
        indicatorColor: const Color(0xFF1E3A5F),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF60A5FA),
            );
          }
          return const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Color(0xFF94A3B8),
          );
        }),
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: ParishColors.marianBlue,
        brightness: Brightness.dark,
        primary: const Color(0xFF60A5FA), // High-contrast Marian Cerulean
        secondary: ParishColors.goldAccent,
        surface: const Color(0xFF1E293B),
        onSurface: const Color(0xFFF8FAFC),
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