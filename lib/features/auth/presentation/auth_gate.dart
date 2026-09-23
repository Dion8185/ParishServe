import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/colors.dart';
import '../../navigation/presentation/admin_navigation_shell.dart';
import '../../navigation/presentation/main_navigation_shell.dart';
import '../../navigation/presentation/parishioner_navigation_shell.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import 'login_view.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  UserModel? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initAuthListener();
  }

  void _initAuthListener() {
    // Listen to session changes (login, logout, token refresh)
    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final session = data.session;

      if (session == null) {
        if (mounted) {
          setState(() {
            _currentUser = null;
            _isLoading = false;
          });
        }
        return;
      }

      // If user session changed, re-hydrate profile from public.users
      final sessionEmail = session.user.email;
      if (_currentUser == null || _currentUser!.email.toLowerCase() != sessionEmail?.toLowerCase()) {
        if (mounted) setState(() => _isLoading = true);

        final freshUser = await AuthService.restoreSession();

        if (mounted) {
          setState(() {
            _currentUser = freshUser;
            _isLoading = false;
          });
        }
      }
    });

    // Initial check on boot (Web F5 or Mobile cold start)
    _checkInitialSession();
  }

  Future<void> _checkInitialSession() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final user = await AuthService.restoreSession();
    if (mounted) {
      setState(() {
        _currentUser = user;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildSplashLoading();
    }

    final session = Supabase.instance.client.auth.currentSession;

    // Unauthenticated or deactivated
    if (session == null || _currentUser == null || !_currentUser!.accountStatus) {
      return const LoginView();
    }

    // Dynamic 3-Tier Routing
    return _routeByRole(_currentUser!);
  }

  Widget _routeByRole(UserModel user) {
    final role = user.userRole.toLowerCase();

    // 1. Parishioner Client Portal
    if (role == 'user') {
      return ParishionerNavigationShell(currentUser: user);
    }

    // 2. System Administration Console
    if (role == 'admin' || role == 'superadmin') {
      return AdminNavigationShell(currentUser: user);
    }

    // 3. Parish Secretariat, Clergy & Financial Operations
    return MainNavigationShell(currentUser: user);
  }

  Widget _buildSplashLoading() {
    return Scaffold(
      backgroundColor: ParishColors.backgroundLight,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: ParishColors.marianBlueSurface,
                shape: BoxShape.circle,
                border: Border.all(color: ParishColors.goldAccent, width: 2.5),
              ),
              child: const Icon(Icons.church, size: 42, color: ParishColors.marianBlue),
            ),
            const SizedBox(height: 18),
            const Text(
              'St. John Paul II Parish',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: ParishColors.marianBlue,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Authenticating session...',
              style: TextStyle(fontSize: 13, color: ParishColors.textMuted),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                color: ParishColors.marianBlue,
                strokeWidth: 2.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}