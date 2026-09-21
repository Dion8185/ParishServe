import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../auth/models/user_model.dart';
import '../../auth/presentation/login_view.dart';
import '../../dashboard/presentation/parishioner_dashboard_view.dart';
import '../../dashboard/presentation/pages/parish_calendar_page.dart';
import '../../profile/presentation/profile_view.dart';

class ParishionerNavigationShell extends StatefulWidget {
  final UserModel currentUser;

  const ParishionerNavigationShell({super.key, required this.currentUser});

  @override
  State<ParishionerNavigationShell> createState() => _ParishionerNavigationShellState();
}

class _ParishionerNavigationShellState extends State<ParishionerNavigationShell> {
  int _currentIndex = 0;
  late final List<Widget> _views;

  @override
  void initState() {
    super.initState();
    _views = [
      ParishionerDashboardView(currentUser: widget.currentUser),
      const ParishCalendarPage(),
      ProfileView(currentUser: widget.currentUser),
    ];
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Confirm Log Out', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to securely end your session?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ParishColors.mercyRed, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginView()),
                    (route) => false,
              );
            },
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth >= 900;

        if (isDesktop) {
          // ==========================================
          // DESKTOP / TABLET LAYOUT (Sidebar)
          // ==========================================
          return Scaffold(
            backgroundColor: ParishColors.backgroundLight,
            body: Row(
              children: [
                _buildDesktopSidebar(),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(30),
                          bottomLeft: Radius.circular(30),
                        ),
                        child: Container(
                          color: ParishColors.backgroundLight,
                          child: _views[_currentIndex],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // ==========================================
        // MOBILE LAYOUT (Top App Bar & Bottom Nav)
        // ==========================================
        return Scaffold(
          backgroundColor: ParishColors.backgroundLight,
          appBar: _buildMobileTopBar(context),
          body: SafeArea(child: _views[_currentIndex]),
          bottomNavigationBar: _buildMobileBottomBar(),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // DESKTOP WIDGETS
  // ---------------------------------------------------------------------------
  Widget _buildDesktopSidebar() {
    return Container(
      width: 280,
      color: ParishColors.cardWhite,
      child: Column(
        children: [
          const SizedBox(height: 40),
          // Parish Logo & Title
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: ParishColors.marianBlueSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: ParishColors.goldAccent, width: 2.5),
            ),
            child: const Icon(Icons.church, size: 36, color: ParishColors.marianBlue),
          ),
          const SizedBox(height: 16),
          const Text(
            'St. John Paul II Parish',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ParishColors.marianBlue),
          ),
          Text(
            'Client Portal',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ParishColors.textMuted),
          ),
          const SizedBox(height: 40),

          // Navigation Links
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _buildSidebarItem(index: 0, label: 'Overview', icon: Icons.home_outlined, activeIcon: Icons.home),
                const SizedBox(height: 8),
                _buildSidebarItem(index: 1, label: 'Parish Calendar', icon: Icons.calendar_month_outlined, activeIcon: Icons.calendar_month),
                const SizedBox(height: 8),
                _buildSidebarItem(index: 2, label: 'My Profile', icon: Icons.person_outline, activeIcon: Icons.person),
              ],
            ),
          ),

          // User Badge & Logout at Bottom
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: ParishColors.borderGrey, width: 1)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: ParishColors.marianBlueSurface,
                      child: Text(
                        widget.currentUser.firstName[0],
                        style: const TextStyle(fontWeight: FontWeight.bold, color: ParishColors.marianBlue),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.currentUser.fullName,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            widget.currentUser.email,
                            style: TextStyle(fontSize: 11, color: ParishColors.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ParishColors.mercyRed,
                      side: const BorderSide(color: ParishColors.mercyRed),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _confirmLogout(context),
                    icon: const Icon(Icons.logout, size: 16),
                    label: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem({required int index, required String label, required IconData icon, required IconData activeIcon}) {
    final bool isSelected = _currentIndex == index;

    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? ParishColors.marianBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? Colors.white : ParishColors.textMuted,
              size: 22,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : ParishColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MOBILE WIDGETS
  // ---------------------------------------------------------------------------
  PreferredSizeWidget _buildMobileTopBar(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(70),
      child: Container(
        decoration: BoxDecoration(
          color: ParishColors.cardWhite,
          border: Border(bottom: BorderSide(color: ParishColors.borderGrey, width: 1.2)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: ParishColors.marianBlueSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ParishColors.goldAccent, width: 2),
                  ),
                  child: const Icon(Icons.church, size: 26, color: ParishColors.marianBlue),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'St. John Paul II Parish',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ParishColors.marianBlue, letterSpacing: -0.2),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Client Portal',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: ParishColors.textMuted),
                      ),
                    ],
                  ),
                ),
                CircleAvatar(
                  radius: 18,
                  backgroundColor: ParishColors.backgroundLight,
                  child: Text(
                    widget.currentUser.firstName[0],
                    style: const TextStyle(fontWeight: FontWeight.bold, color: ParishColors.marianBlue),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, -3))],
        border: Border(top: BorderSide(color: ParishColors.borderGrey, width: 1.2)),
      ),
      child: SafeArea(
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) => setState(() => _currentIndex = index),
          backgroundColor: Colors.transparent,
          indicatorColor: ParishColors.marianBlueSurface,
          elevation: 0,
          height: 65,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: ParishColors.marianBlue),
              label: 'Overview',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month, color: ParishColors.marianBlue),
              label: 'Calendar',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: ParishColors.marianBlue),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}