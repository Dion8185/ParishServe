import 'package:flutter/material.dart';
import '../theme/theme_controller.dart';

class ParishColors {
  // ===========================================================================
  // Fixed Brand Accents (Coat of Arms)
  // ===========================================================================
  static const Color marianBlue = Color(0xFF164E87);
  static const Color marianBlueLight = Color(0xFF246EB9);
  static const Color goldAccent = Color(0xFFD49B18);
  static const Color mercyRed = Color(0xFFB91C1C);
  static const Color oliveGreen = Color(0xFF2D6A4F);

  // ===========================================================================
  // Theme-Adaptive Dynamic Colors
  // ===========================================================================
  static Color get backgroundLight => AppThemeController.isDarkMode
      ? const Color(0xFF0F172A) // Deep nocturnal Marian slate
      : const Color(0xFFF8FAFC); // Clean parchment white

  static Color get cardWhite => AppThemeController.isDarkMode
      ? const Color(0xFF1E293B) // Dark slate container
      : const Color(0xFFFFFFFF); // Pure white card

  static Color get textDark => AppThemeController.isDarkMode
      ? const Color(0xFFF8FAFC) // Crisp white for senior readability
      : const Color(0xFF1E293B); // Deep charcoal

  static Color get textMuted => AppThemeController.isDarkMode
      ? const Color(0xFF94A3B8) // High-contrast silver slate
      : const Color(0xFF475569); // Muted slate

  static Color get borderGrey => AppThemeController.isDarkMode
      ? const Color(0xFF334155) // Subtle dark border
      : const Color(0xFFCBD5E1); // Light grey border

  static Color get marianBlueSurface => AppThemeController.isDarkMode
      ? const Color(0xFF1E3A5F)
      : const Color(0xFFEDF4FB);

  static Color get goldLight => AppThemeController.isDarkMode
      ? const Color(0xFF3E2D0C)
      : const Color(0xFFFFF7E6);

  static Color get mercyRedSurface => AppThemeController.isDarkMode
      ? const Color(0xFF450A0A)
      : const Color(0xFFFDF2F2);

  static Color get oliveGreenSurface => AppThemeController.isDarkMode
      ? const Color(0xFF064E3B)
      : const Color(0xFFEDF7F2);
}