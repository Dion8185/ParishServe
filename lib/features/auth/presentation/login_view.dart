import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../navigation/presentation/main_navigation_shell.dart';
import '../../navigation/presentation/parishioner_navigation_shell.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import 'dialogs/login_help_dialog.dart';
import 'parishioner_register_view.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final TextEditingController _identifierController = TextEditingController(text: 'lucator51plus1@gmail.com');
  final TextEditingController _passwordController = TextEditingController(text: 'ParishServe@123');

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text;

    if (identifier.isEmpty || password.isEmpty) {
      _showErrorDialog('Please enter both username/email and password.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = await AuthService.login(
        identifier: identifier,
        password: password,
      );

      if (!mounted) return;

      if (user == null) {
        _showErrorDialog('Invalid username/email or password. Please verify your credentials.');
      } else if (!user.accountStatus) {
        _showErrorDialog('This account (${user.userId}) has been deactivated. Please contact the Parish Priest or Administrator.');
      } else {
        // ---- ROLE-BASED REDIRECTION ----
        if (user.userRole.toLowerCase() == 'user') {
          // Send Parishioners to the Client Web Portal
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ParishionerNavigationShell(currentUser: user),
            ),
          );
        } else {
          // Send Internal Staff to the Staff Management Portal
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MainNavigationShell(currentUser: user),
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('Sign In Error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: ParishColors.mercyRed, size: 28),
            SizedBox(width: 8),
            Text('Sign In Error', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(message, style: TextStyle(fontSize: 14, color: ParishColors.textDark)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ParishColors.marianBlue,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

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
                // Parish Emblem Container
                Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    color: ParishColors.marianBlueSurface,
                    shape: BoxShape.circle,
                    border: Border.all(color: ParishColors.goldAccent, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.church, size: 48, color: ParishColors.marianBlue),
                ),
                const SizedBox(height: 14),

                const Text(
                  'St. John Paul II Parish',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: ParishColors.marianBlue,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Diocese of San Pablo • Labuin, Sta. Cruz, Laguna',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ParishColors.textMuted),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: ParishColors.goldLight,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: ParishColors.goldAccent, width: 1.2),
                  ),
                  child: Text(
                    'ParishServe Management Portal',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                  ),
                ),

                const SizedBox(height: 24),

                // Form Card
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: ParishColors.cardWhite,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: ParishColors.borderGrey, width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Portal Sign In',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Enter your username or parish email to log in.',
                        style: TextStyle(fontSize: 13, color: ParishColors.textMuted),
                      ),
                      const SizedBox(height: 20),

                      const Text('Username or Email', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _identifierController,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.person, color: ParishColors.marianBlue),
                          filled: true,
                          fillColor: ParishColors.backgroundLight,
                          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      const Text('Password', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.lock, color: ParishColors.marianBlue),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: ParishColors.textMuted),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          filled: true,
                          fillColor: ParishColors.backgroundLight,
                          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 18),

                      Text('Quick Test Account:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ParishColors.textMuted)),
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildQuickAccountChip('lucator51plus1@gmail.com', 'Superadmin'),
                            _buildQuickAccountChip('secretary', 'Secretary'),
                            _buildQuickAccountChip('parishpriest', 'Priest'),
                            _buildQuickAccountChip('admin', 'Admin'),
                            _buildQuickAccountChip('encoder', 'Encoder'),
                            _buildQuickAccountChip('pfc_auditor', 'PFC'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),

                      SizedBox(
                        width: double.infinity,
                        height: 58,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ParishColors.marianBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: _isLoading ? null : _handleLogin,
                          child: _isLoading
                              ? const SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                              : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.login, size: 22),
                              SizedBox(width: 8),
                              Text(
                                'LOG IN TO PARISHSERVE',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Parishioner Self-Registration Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: ParishColors.marianBlue, width: 1.5),
                            foregroundColor: ParishColors.marianBlue,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _isLoading
                              ? null
                              : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ParishionerRegisterView(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.person_add_alt_1, size: 20),
                          label: const Text(
                            'New Parishioner? Create an Account',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.help_outline, size: 18, color: ParishColors.textMuted),
                    const SizedBox(width: 4),
                    TextButton(
                      onPressed: () => showLoginHelpDialog(context),
                      child: const Text(
                        'Need assistance logging in? Tap here',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ParishColors.marianBlue),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),
                const Text(
                  'TOTUS TUUS',
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 13,
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

  Widget _buildQuickAccountChip(String identifier, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        backgroundColor: ParishColors.marianBlueSurface,
        label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ParishColors.marianBlue)),
        onPressed: () {
          setState(() {
            _identifierController.text = identifier;
            _passwordController.text = 'ParishServe@123';
          });
        },
      ),
    );
  }
}