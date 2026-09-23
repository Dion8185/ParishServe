import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../auth/models/user_model.dart';
import '../../auth/presentation/login_view.dart';
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

  @override
  Widget build(BuildContext context) {
    final user = widget.currentUser;
    final fullName = user?.fullName ?? 'Parish Staff Member';
    final role = user?.roleDisplay ?? 'Parish Secretary (Sc)';
    final userId = user?.userId ?? 'S26-0003';
    final email = user?.email ?? 'secretary@sjp2parish.ph';

    return Scaffold(
      backgroundColor: ParishColors.backgroundLight,
      // NOTE: appBar removed here so it seamlessly uses MainNavigationShell's persistent Top Bar!
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Profile Header Card
            Container(
              width: double.infinity,
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
                children: [
                  // Avatar with Papal Gold Ring
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ParishColors.marianBlueSurface,
                      border: Border.all(color: ParishColors.goldAccent, width: 3),
                    ),
                    child: Center(
                      child: Text(
                        fullName.isNotEmpty ? fullName[0].toUpperCase() : 'P',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: ParishColors.marianBlue,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Name & Role
                  Text(
                    fullName,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: ParishColors.marianBlueSurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      role,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ParishColors.marianBlue),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Staff ID: $userId',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ParishColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Credentials & Assignment Section
            _buildSectionHeader('Parish Credentials & Assignment'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ParishColors.cardWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ParishColors.borderGrey),
              ),
              child: Column(
                children: [
                  _buildInfoTile(Icons.email_outlined, 'Official Email', email),
                  const Divider(height: 20),
                  _buildInfoTile(Icons.church_outlined, 'Parish Assignment', 'St. John Paul II Parish (Labuin, Sta. Cruz)'),
                  const Divider(height: 20),
                  _buildInfoTile(Icons.verified_user_outlined, 'Canonical Authorization', 'Active & Certified'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Accessibility & Display Preferences Section
            _buildSectionHeader('Appearance & Accessibility'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: ParishColors.cardWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ParishColors.borderGrey),
              ),
              child: Column(
                children: [
                  // ACTIVE GLOBAL DARK MODE TOGGLE
                  SwitchListTile(
                    activeColor: ParishColors.marianBlue,
                    contentPadding: EdgeInsets.zero,
                    secondary: Icon(
                      AppThemeController.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                      color: ParishColors.goldAccent,
                    ),
                    title: const Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    subtitle: const Text('Reduce glare and eye strain for night shifts', style: TextStyle(fontSize: 12)),
                    value: AppThemeController.isDarkMode,
                    onChanged: (val) {
                      AppThemeController.toggleTheme(val);
                      setState(() {});
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    activeColor: ParishColors.marianBlue,
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.format_size, color: ParishColors.marianBlue),
                    title: const Text('Large Font Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    subtitle: const Text('Enhance label readability for staff', style: TextStyle(fontSize: 12)),
                    value: _largeFontEnabled,
                    onChanged: (val) => setState(() => _largeFontEnabled = val),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    activeColor: ParishColors.marianBlue,
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.volume_up_outlined, color: ParishColors.oliveGreen),
                    title: const Text('ESP32 Telemetry Audio Alert', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    subtitle: const Text('Sound alarm on archive humidity breaches', style: TextStyle(fontSize: 12)),
                    value: _audioAlertsEnabled,
                    onChanged: (val) => setState(() => _audioAlertsEnabled = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Logout Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ParishColors.mercyRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => _confirmLogout(context),
                icon: const Icon(Icons.logout, size: 22),
                label: const Text('LOG OUT OF SYSTEM', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 14),

            Text(
              'ParishServe v1.0.0 • Diocese of San Pablo',
              style: TextStyle(fontSize: 12, color: ParishColors.textMuted),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          title,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ParishColors.textDark),
        ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: ParishColors.marianBlue, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: ParishColors.textMuted)),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
            ],
          ),
        ),
      ],
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Confirm Log Out', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to end your current ParishServe session?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ParishColors.mercyRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await AuthService.signOut();
            },
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }
}