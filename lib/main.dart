import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/presentation/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://wdosrvmkgdrkcotlkzgi.supabase.co',
    anonKey: 'sb_publishable_wzE6ee-MEqpM8Qz7H8awDQ_4q1i2oJq',
  );

  runApp(const ParishServeApp());
}

class ParishServeApp extends StatelessWidget {
  const ParishServeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppThemeController.themeModeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: 'ParishServe',
          debugShowCheckedModeBanner: false,
          theme: ParishTheme.lightTheme,
          darkTheme: ParishTheme.darkTheme,
          themeMode: currentMode,
          home: const AuthGate(),
        );
      },
    );
  }
}