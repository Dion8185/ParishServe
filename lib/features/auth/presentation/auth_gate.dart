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
    // 1. Listen to Supabase auth state changes (login, logout, token refresh, recovery)
    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      // If password recovery is active, quarantine the session and DO NOT route to dashboard
      if (AuthService.isPasswordRecoveryInProgress ||
          data.event == AuthChangeEvent.passwordRecovery) {
        if (mounted) {
          setState(() {
            _currentUser = null;
            _isLoading = false;
          });
        }
        return;
      }

      // Explicit Sign Out event
      if (data.event == AuthChangeEvent.signedOut) {
        if (mounted) {
          setState(() {
            _currentUser = null;
            _isLoading = false;
          });
        }
        return;
      }

      final session = data.session;

      // If user session changed during normal authentication, re-hydrate profile
      if (session != null) {
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
      }
    });

    // 2. Initial check on boot (Supports 100% offline startup from local storage)
    _checkInitialSession();
  }

  Future<void> _checkInitialSession() async {
    // If recovery flag is active on boot, keep at LoginView
    if (AuthService.isPasswordRecoveryInProgress) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      // restoreSession() retrieves local cache first, enabling offline startup
      final user = await AuthService.restoreSession();
      if (mounted) {
        setState(() {
          _currentUser = user;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[AuthGate] Initial session restore error: $e');
      if (mounted) {
        setState(() {
          _currentUser = AuthService.currentUser;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildSplashLoading();
    }

    // Unauthenticated, deactivated account, or in the middle of password recovery
    if (_currentUser == null ||
        !_currentUser!.accountStatus ||
        AuthService.isPasswordRecoveryInProgress) {
      return const LoginView();
    }

    // Dynamic 3-Tier Role Routing (Works seamlessly both Online and Offline)
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
            Text(
              'St. John Paul II Parish',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: ParishColors.marianBlueAdaptive,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Loading secure parish session...',
              style: TextStyle(fontSize: 13, color: ParishColors.textMuted),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                color: ParishColors.marianBlueAdaptive,
                strokeWidth: 2.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}