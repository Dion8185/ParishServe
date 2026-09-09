import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../navigation/presentation/main_navigation_shell.dart';
import 'dialogs/login_help_dialog.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ParishColors.backgroundLight,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: ParishColors.marianBlueSurface,
                    shape: BoxShape.circle,
                    border: Border.all(color: ParishColors.goldAccent, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.church,
                    size: 52,
                    color: ParishColors.marianBlue,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'St. John Paul II Parish',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: ParishColors.marianBlue,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Diocese of San Pablo • Labuin, Sta. Cruz, Laguna',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ParishColors.textMuted,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: ParishColors.goldLight,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: ParishColors.goldAccent, width: 1.2),
                  ),
                  child: const Text(
                    'ParishServe Management Portal',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: ParishColors.textDark,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: ParishColors.cardWhite,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: ParishColors.borderGrey, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Staff Sign In',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: ParishColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Enter your parish credentials to proceed.',
                        style: TextStyle(fontSize: 13, color: ParishColors.textMuted),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Username or Staff ID',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: TextEditingController(text: 'parish.secretary'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.person, color: ParishColors.marianBlue, size: 24),
                          filled: true,
                          fillColor: ParishColors.backgroundLight,
                          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: ParishColors.borderGrey),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: ParishColors.marianBlue, width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Password',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        obscureText: _obscurePassword,
                        controller: TextEditingController(text: '••••••••••'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.lock, color: ParishColors.marianBlue, size: 24),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: ParishColors.textMuted,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          filled: true,
                          fillColor: ParishColors.backgroundLight,
                          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: ParishColors.borderGrey),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: ParishColors.marianBlue, width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: ParishColors.marianBlueSurface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.badge_outlined, size: 20, color: ParishColors.marianBlue),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Role: Parish Secretary / Office Staff',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ParishColors.marianBlue),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 58,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ParishColors.marianBlue,
                            foregroundColor: Colors.white,
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => const MainNavigationShell()),
                            );
                          },
                          icon: const Icon(Icons.login, size: 24),
                          label: const Text(
                            'LOG IN TO PARISHSERVE',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.help_outline, size: 20, color: ParishColors.textMuted),
                    const SizedBox(width: 6),
                    TextButton(
                      onPressed: () => showLoginHelpDialog(context),
                      child: const Text(
                        'Need assistance logging in? Tap here',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: ParishColors.marianBlue,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'TOTUS TUUS',
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                    color: ParishColors.goldAccent,
                    letterSpacing: 2.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}