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
  // Theme-Adaptive Brand Accents (WCAG AAA High-Contrast)
  // ===========================================================================
  /// Deep Marian Navy in light mode, high-contrast Marian Sky Blue in dark mode
  static Color get marianBlueAdaptive => AppThemeController.isDarkMode
      ? const Color(0xFF60A5FA) // Bright Marian Cerulean for dark backgrounds
      : const Color(0xFF164E87); // Deep Marian Navy for light backgrounds

  static Color get goldAccentAdaptive => AppThemeController.isDarkMode
      ? const Color(0xFFFBBF24) // Brighter Papal Amber
      : const Color(0xFFD49B18);

  static Color get mercyRedAdaptive => AppThemeController.isDarkMode
      ? const Color(0xFFF87171) // Readable soft crimson
      : const Color(0xFFB91C1C);

  static Color get oliveGreenAdaptive => AppThemeController.isDarkMode
      ? const Color(0xFF34D399) // Vivid liturgical emerald
      : const Color(0xFF2D6A4F);

  // ===========================================================================
  // Theme-Adaptive Canvas & Typography Colors
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

  // ===========================================================================
  // Theme-Adaptive Sacrament Banners & Surfaces (Fixes Glaring Pastels in Dark Mode)
  // ===========================================================================
  static Color get baptismSurface => AppThemeController.isDarkMode
      ? const Color(0xFF172554) // Deep ocean slate
      : const Color(0xFFEDF4FB); // Light water blue

  static Color get confirmationSurface => AppThemeController.isDarkMode
      ? const Color(0xFF450A0A) // Deep Pentecost crimson
      : const Color(0xFFFDF2F2); // Light pastel rose

  static Color get communionSurface => AppThemeController.isDarkMode
      ? const Color(0xFF3E2D0C) // Deep chalice gold
      : const Color(0xFFFFF7E6); // Light Eucharistic cream

  static Color get matrimonySurface => AppThemeController.isDarkMode
      ? const Color(0xFF4C0519) // Deep wine burgundy
      : const Color(0xFFFCE7F3); // Light nuptial pink

  static Color get deathSurface => AppThemeController.isDarkMode
      ? const Color(0xFF3B0764) // Deep solemn violet
      : const Color(0xFFF3E8FF); // Light lavender

  static Color get conversionSurface => AppThemeController.isDarkMode
      ? const Color(0xFF064E3B) // Deep forest green
      : const Color(0xFFEDF7F2); // Light olive
}