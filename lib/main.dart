import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'features/sacramental_records/presentation/pages/certificate_verification_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://wdosrvmkgdrkcotlkzgi.supabase.co',
    anonKey: 'sb_publishable_wzE6ee-MEqpM8Qz7H8awDQ_4q1i2oJq',
  );

  runApp(const ParishServeApp());
}

/// Detects whether the current browser URL is an external QR certificate verification scan
bool _isVerificationUrl() {
  if (!kIsWeb) return false;
  final uri = Uri.base;

  // Checks for verification path or query token in both standard (?v=...)
  // and hash-routing formats (/#/verify?v=...)
  final hasVerifyPath = uri.path.contains('verify') || uri.fragment.contains('verify');
  final hasTokenParam = uri.queryParameters.containsKey('v') || uri.fragment.contains('v=');

  return hasVerifyPath || hasTokenParam;
}

class ParishServeApp extends StatelessWidget {
  const ParishServeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isVerification = _isVerificationUrl();

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppThemeController.themeModeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: isVerification
              ? 'Certificate Verification - Saint John Paul II Parish'
              : 'ParishServe',
          debugShowCheckedModeBanner: false,
          theme: ParishTheme.lightTheme,
          darkTheme: ParishTheme.darkTheme,
          themeMode: currentMode,
          // Bypasses AuthGate if the request is an external verification scan
          home: isVerification
              ? const CertificateVerificationPage()
              : const AuthGate(),
          onGenerateRoute: (settings) {
            if (settings.name != null && settings.name!.startsWith('/verify')) {
              final uri = Uri.parse(settings.name!);
              final token = uri.queryParameters['v'];
              return MaterialPageRoute(
                builder: (_) => CertificateVerificationPage(initialVerificationId: token),
              );
            }
            return null;
          },
        );
      },
    );
  }
}