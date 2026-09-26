import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppThemeController {
  // Global notifier holding the active ThemeMode
  static final ValueNotifier<ThemeMode> themeModeNotifier =
  ValueNotifier<ThemeMode>(ThemeMode.light);

  static bool get isDarkMode => themeModeNotifier.value == ThemeMode.dark;

  /// Toggles theme in memory and synchronizes the preference to Supabase public.users
  static Future<void> toggleTheme(bool isDark, {String? userId}) async {
    themeModeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;

    if (userId != null && userId.isNotEmpty) {
      try {
        await Supabase.instance.client
            .from('users')
            .update({'dark_mode_enabled': isDark})
            .eq('user_id', userId);
      } catch (e) {
        debugPrint('Non-blocking theme preference sync notice: $e');
      }
    }
  }

  /// Synchronizes theme preference loaded from user account record upon login/session restore
  static void applyUserPreference(bool isDark) {
    themeModeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  }
}