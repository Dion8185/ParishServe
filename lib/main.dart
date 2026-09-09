import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/login_view.dart';

void main() {
  runApp(const ParishServeApp());
}

class ParishServeApp extends StatelessWidget {
  const ParishServeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ParishServe',
      debugShowCheckedModeBanner: false,
      theme: ParishTheme.lightTheme,
      home: const LoginView(),
    );
  }
}