import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../auth/models/user_model.dart';
import '../../auth/presentation/dialogs/forgot_password_dialog.dart';
import '../../auth/services/auth_service.dart';

class ProfileView extends StatefulWidget {
  final UserModel? currentUser;

  const ProfileView({super.key, this.currentUser});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  bool _largeFontEnabled = true;
  bool _audioAlertsEnabled = true;

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: ParishColors.cardWhite,
        title: const Row(
          children: [
            Icon(Icons.logout, color: ParishColors.mercyRed, size: 24),
            SizedBox(width: 8),
            Text('Confirm Log Out', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Text(
          'Are you sure you want to end your current ParishServe session? You will be returned to the sign-in screen.',
          style: TextStyle(fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: ParishColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ParishColors.mercyRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await AuthService.signOut();
            },
            child: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.currentUser;
    final fullName = user?.fullName ?? 'Parish Community Member';
    final role = user?.roleDisplay ?? 'Parishioner Client (U)';
    final userId = user?.userId ?? 'U26-0001';
    final email = user?.email ?? 'parishioner@sjp2parish.ph';
    final username = user?.username ?? 'parishioner_user';
    final isStaff = user?.userRole.toLowerCase() != 'user';

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth >= 850;

        return Scaffold(
          backgroundColor: ParishColors.backgroundLight,
          body: SingleChildScrollView(
            padding: EdgeInsets.all(isDesktop ? 28.0 : 20.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Section Breadcrumb Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isDesktop ? 'User Profile & System Preferences' : 'My Profile',
                              style: TextStyle(
                                fontSize: isDesktop ? 22 : 19,
                                fontWeight: FontWeight.bold,
                                color: ParishColors.textDark,
                              ),
                            ),
                            Text(
                              'Manage account credentials, display preferences, and security access',
                              style: TextStyle(fontSize: 12.5, color: ParishColors.textMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Multi-Column Layout on Desktop vs Stacked on Mobile
                    if (isDesktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Column: Profile Hero & Sign Out
                          Expanded(
                            flex: 4,
                            child: Column(
                              children: [
                                _buildProfileHeroCard(fullName, role, userId, username, isStaff),
                                const SizedBox(height: 20),
                                _buildLogoutButton(context),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),

                          // Right Column: Details, Preferences & Security
                          Expanded(
                            flex: 6,
                            child: Column(
                              children: [
                                _buildCredentialsCard(fullName, username, email, userId, role, isStaff),
                                const SizedBox(height: 20),
                                _buildPreferencesCard(user),
                                const SizedBox(height: 20),
                                _buildSecurityCard(context, email),
                              ],
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          _buildProfileHeroCard(fullName, role, userId, username, isStaff),
                          const SizedBox(height: 20),
                          _buildCredentialsCard(fullName, username, email, userId, role, isStaff),
                          const SizedBox(height: 20),
                          _buildPreferencesCard(user),
                          const SizedBox(height: 20),
                          _buildSecurityCard(context, email),
                          const SizedBox(height: 24),
                          _buildLogoutButton(context),
                        ],
                      ),

                    const SizedBox(height: 28),

                    // Footer Institutional Branding
                    Center(
                      child: Column(
                        children: [
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
                          const SizedBox(height: 2),
                          Text(
                            'ParishServe v1.0.0 • St. John Paul II Parish, Diocese of San Pablo',
                            style: TextStyle(fontSize: 11.5, color: ParishColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // Profile Hero Card (Identity & Badge)
  // ===========================================================================

  Widget _buildProfileHeroCard(String fullName, String role, String userId, String username, bool isStaff) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ParishColors.borderGrey, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar with Papal Gold Ring
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ParishColors.marianBlueSurface,
              border: Border.all(color: ParishColors.goldAccent, width: 3),
            ),
            child: Center(
              child: Text(
                fullName.isNotEmpty ? fullName[0].toUpperCase() : 'P',
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.bold,
                  color: ParishColors.marianBlueAdaptive,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Full Name
          Text(
            fullName,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: ParishColors.textDark),
          ),
          const SizedBox(height: 3),
          Text(
            '@$username',
            style: TextStyle(fontSize: 13, color: ParishColors.textMuted, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 10),

          // Role Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: ParishColors.marianBlueSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ParishColors.marianBlueAdaptive.withOpacity(0.3)),
            ),
            child: Text(
              role,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: ParishColors.marianBlueAdaptive),
            ),
          ),
          const SizedBox(height: 12),

          // ID Pill with Copy Action
          InkWell(
            onTap: () => _copyToClipboard(userId, isStaff ? 'Staff ID' : 'Parishioner ID'),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: ParishColors.backgroundLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ParishColors.borderGrey),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${isStaff ? "Staff" : "Account"} ID: $userId',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ParishColors.textMuted),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.copy, size: 13, color: ParishColors.textMuted),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 6),

          // Status Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: ParishColors.oliveGreen,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'ACCOUNT ACTIVE & VERIFIED',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: ParishColors.oliveGreen,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Credentials & Assignment Section Card
  // ===========================================================================

  Widget _buildCredentialsCard(String fullName, String username, String email, String userId, String role, bool isStaff) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ParishColors.borderGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.badge_outlined, color: ParishColors.marianBlueAdaptive, size: 20),
              const SizedBox(width: 8),
              Text(
                'Canonical Credentials & Assignment',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ParishColors.textDark),
              ),
            ],
          ),
          const Divider(height: 24),
          _buildInfoTile(
            Icons.person_outline,
            'Full Legal Name',
            fullName,
          ),
          const Divider(height: 20),
          _buildInfoTile(
            Icons.email_outlined,
            'Registered Email Address',
            email,
            trailing: IconButton(
              icon: Icon(Icons.copy, size: 16, color: ParishColors.marianBlueAdaptive),
              tooltip: 'Copy Email',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => _copyToClipboard(email, 'Email address'),
            ),
          ),
          const Divider(height: 20),
          _buildInfoTile(
            Icons.church_outlined,
            'Ecclesiastical Jurisdiction',
            'St. John Paul II Parish • Diocese of San Pablo (Laguna)',
          ),
          const Divider(height: 20),
          _buildInfoTile(
            Icons.verified_user_outlined,
            'Authorization Status',
            isStaff ? 'Canonical Staff Authorization Active' : 'Verified Registered Parishioner',
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Appearance & Accessibility Preferences Card (With DB Sync)
  // ===========================================================================

  Widget _buildPreferencesCard(UserModel? user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ParishColors.borderGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune, color: ParishColors.marianBlueAdaptive, size: 20),
              const SizedBox(width: 8),
              Text(
                'Display & Accessibility Preferences',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ParishColors.textDark),
              ),
            ],
          ),
          const Divider(height: 24),

          // Active Dark Mode Switch (Persisted to Database)
          SwitchListTile(
            activeColor: ParishColors.marianBlueAdaptive,
            contentPadding: EdgeInsets.zero,
            secondary: Icon(
              AppThemeController.isDarkMode ? Icons.dark_mode : Icons.light_mode,
              color: ParishColors.goldAccent,
            ),
            title: const Text('Dark Mode (Marian Nocturnal Theme)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: const Text('Saved per account across sign-in sessions', style: TextStyle(fontSize: 12)),
            value: AppThemeController.isDarkMode,
            onChanged: (val) {
              AppThemeController.toggleTheme(val, userId: user?.userId);
              setState(() {});
            },
          ),
          const Divider(height: 16),

          // Large Font Switch
          SwitchListTile(
            activeColor: ParishColors.marianBlueAdaptive,
            contentPadding: EdgeInsets.zero,
            secondary: Icon(Icons.format_size, color: ParishColors.marianBlueAdaptive),
            title: const Text('High Readability Typography', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: const Text('Enlarges text labels conforming to senior accessibility standards', style: TextStyle(fontSize: 12)),
            value: _largeFontEnabled,
            onChanged: (val) => setState(() => _largeFontEnabled = val),
          ),
          const Divider(height: 16),

          // ESP32 Audio Alerts Switch
          SwitchListTile(
            activeColor: ParishColors.marianBlueAdaptive,
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.volume_up_outlined, color: ParishColors.oliveGreen),
            title: const Text('Smart Archive Environmental Audio Alerts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: const Text('Triggers tone notification on archive relative humidity breaches (>60% RH)', style: TextStyle(fontSize: 12)),
            value: _audioAlertsEnabled,
            onChanged: (val) => setState(() => _audioAlertsEnabled = val),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Security & Session Governance Card
  // ===========================================================================

  Widget _buildSecurityCard(BuildContext context, String email) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ParishColors.borderGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.security, color: ParishColors.marianBlueAdaptive, size: 20),
              const SizedBox(width: 8),
              Text(
                'Security Governance & Privacy',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ParishColors.textDark),
              ),
            ],
          ),
          const Divider(height: 24),

          // Change Password Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Account Password', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
                    const SizedBox(height: 2),
                    Text('Update your credentials via secure 6-digit email OTP verification', style: TextStyle(fontSize: 11.5, color: ParishColors.textMuted)),
                  ],
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: ParishColors.marianBlueAdaptive, width: 1.2),
                  foregroundColor: ParishColors.marianBlueAdaptive,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onPressed: () => showForgotPasswordDialog(context, initialIdentifier: email),
                icon: const Icon(Icons.lock_reset, size: 16),
                label: const Text('Change Password', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Data Privacy Law / Canon 535 Notice Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ParishColors.backgroundLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ParishColors.borderGrey),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.shield_outlined, color: ParishColors.oliveGreen, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Protected under Philippine Data Privacy Act of 2012 (RA 10173) and Codex Iuris Canonici (Canon 535). All sacramental entries and financial registers are confidential and protected by Row-Level Security (RLS).',
                    style: TextStyle(fontSize: 11, color: ParishColors.textMuted, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Logout Button
  // ===========================================================================

  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: ParishColors.mercyRed,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 1,
        ),
        onPressed: () => _confirmLogout(context),
        icon: const Icon(Icons.logout, size: 20),
        label: const Text(
          'LOG OUT OF SYSTEM',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
      ),
    );
  }

  // ===========================================================================
  // Info Tile Component
  // ===========================================================================

  Widget _buildInfoTile(IconData icon, String label, String value, {Widget? trailing}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: ParishColors.marianBlueAdaptive, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11.5, color: ParishColors.textMuted)),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: ParishColors.textDark),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }
}