import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../auth/models/user_model.dart';
import '../../auth/presentation/admin_users_page.dart';
import '../../auth/services/auth_service.dart';
import '../../dashboard/presentation/admin_dashboard_view.dart';
import '../../profile/presentation/profile_view.dart';

class AdminNavigationShell extends StatefulWidget {
  final UserModel currentUser;

  const AdminNavigationShell({super.key, required this.currentUser});

  @override
  State<AdminNavigationShell> createState() => _AdminNavigationShellState();
}

class _AdminNavigationShellState extends State<AdminNavigationShell> {
  int _currentIndex = 0;
  late final List<Widget> _views;

  @override
  void initState() {
    super.initState();
    _views = [
      AdminDashboardView(
        currentUser: widget.currentUser,
        onNavigateTab: (targetIndex) => setState(() => _currentIndex = targetIndex),
      ),
      const AdminUsersPage(),
      _buildSystemHealthView(),
      ProfileView(currentUser: widget.currentUser),
    ];
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Confirm Log Out', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to end your administrative session?'),
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth >= 900;

        if (isDesktop) {
          return Scaffold(
            backgroundColor: ParishColors.backgroundLight,
            body: Row(
              children: [
                _buildDesktopSidebar(),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1400),
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

        return Scaffold(
          backgroundColor: ParishColors.backgroundLight,
          appBar: _buildMobileTopBar(),
          body: SafeArea(child: _views[_currentIndex]),
          bottomNavigationBar: _buildMobileBottomBar(),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Desktop Sidebar Navigation
  // ---------------------------------------------------------------------------
  Widget _buildDesktopSidebar() {
    final isSuperAdmin = widget.currentUser.userRole.toLowerCase() == 'superadmin';

    return Container(
      width: 280,
      color: ParishColors.cardWhite,
      child: Column(
        children: [
          const SizedBox(height: 36),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: ParishColors.marianBlueSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: ParishColors.goldAccent, width: 2.5),
            ),
            child: const Icon(Icons.admin_panel_settings, size: 36, color: ParishColors.marianBlue),
          ),
          const SizedBox(height: 14),
          const Text(
            'ParishServe',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: ParishColors.marianBlue),
          ),
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: isSuperAdmin ? ParishColors.goldLight : ParishColors.marianBlueSurface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isSuperAdmin ? ParishColors.goldAccent : ParishColors.marianBlue,
              ),
            ),
            child: Text(
              isSuperAdmin ? 'SUPERADMIN CONSOLE' : 'SYSTEM ADMIN CONSOLE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isSuperAdmin ? ParishColors.goldAccent : ParishColors.marianBlue,
              ),
            ),
          ),
          const SizedBox(height: 36),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _buildSidebarItem(index: 0, label: 'Dashboard', icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard),
                const SizedBox(height: 8),
                _buildSidebarItem(index: 1, label: 'User Governance', icon: Icons.manage_accounts_outlined, activeIcon: Icons.manage_accounts),
                const SizedBox(height: 8),
                _buildSidebarItem(index: 2, label: 'System Health & Config', icon: Icons.settings_suggest_outlined, activeIcon: Icons.settings_suggest),
                const SizedBox(height: 8),
                _buildSidebarItem(index: 3, label: 'Admin Profile', icon: Icons.person_outline, activeIcon: Icons.person),
              ],
            ),
          ),

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
                        widget.currentUser.firstName.isNotEmpty ? widget.currentUser.firstName[0].toUpperCase() : 'A',
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
                            widget.currentUser.roleDisplay,
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
  // Mobile App Bar & Navigation Bar
  // ---------------------------------------------------------------------------
  PreferredSizeWidget _buildMobileTopBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(70),
      child: Container(
        decoration: BoxDecoration(
          color: ParishColors.cardWhite,
          border: Border(bottom: BorderSide(color: ParishColors.borderGrey, width: 1.2)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
                  child: const Icon(Icons.admin_panel_settings, size: 26, color: ParishColors.marianBlue),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ParishServe Admin',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ParishColors.marianBlue),
                      ),
                      Text(
                        '${widget.currentUser.firstName} • ${widget.currentUser.roleDisplay}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: ParishColors.textMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout, color: ParishColors.mercyRed),
                  tooltip: 'Log Out',
                  onPressed: () => _confirmLogout(context),
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
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard, color: ParishColors.marianBlue),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.manage_accounts_outlined),
              selectedIcon: Icon(Icons.manage_accounts, color: ParishColors.marianBlue),
              label: 'Users',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_suggest_outlined),
              selectedIcon: Icon(Icons.settings_suggest, color: ParishColors.marianBlue),
              label: 'System',
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

  // ---------------------------------------------------------------------------
  // Infrastructure Diagnostics & Diocesan Tenant Scaling
  // ---------------------------------------------------------------------------
  Widget _buildSystemHealthView() {
    final isSuperAdmin = widget.currentUser.userRole.toLowerCase() == 'superadmin';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'System Diagnostics & Infrastructure',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: ParishColors.textDark),
          ),
          Text(
            'Environment parameters and security policies',
            style: TextStyle(fontSize: 13, color: ParishColors.textMuted),
          ),
          const SizedBox(height: 20),

          // Security Boundary Advisory Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ParishColors.marianBlueSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ParishColors.marianBlue.withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.shield, color: ParishColors.marianBlue, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Canonical Data Isolation Active (Canon 535 / RA 10173)',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'System Administrators are restricted to user account provisioning, access governance, and infrastructure health. Canonical sacramental books and financial ledgers are restricted to clergy and chancery personnel.',
                        style: TextStyle(fontSize: 12, color: ParishColors.textMuted, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Server & Database Health Status
          Text('Cloud Infrastructure & Storage', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
          const SizedBox(height: 12),

          _buildStatusTile(
            title: 'Supabase PostgreSQL 15 Engine',
            subtitle: 'ACID Relational Core • Active Connection',
            icon: Icons.storage,
            status: 'HEALTHY',
            statusColor: ParishColors.oliveGreen,
          ),
          const SizedBox(height: 10),
          _buildStatusTile(
            title: 'Supabase Private Storage Bucket',
            subtitle: 'appointment-documents • Auto-Purge Protocol Enabled',
            icon: Icons.folder_special_outlined,
            status: 'READY',
            statusColor: ParishColors.oliveGreen,
          ),
          const SizedBox(height: 10),
          _buildStatusTile(
            title: 'ESP32 Smart Archive Mesh Network',
            subtitle: 'Sacramental Archive Room & Liturgical Vault Nodes',
            icon: Icons.sensors,
            status: 'ONLINE (4 NODES)',
            statusColor: ParishColors.oliveGreen,
          ),

          const SizedBox(height: 24),

          // Superadmin Multi-Parish Tenant Scaling Preview
          Text('Diocesan Multi-Parish Scaling', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
          const SizedBox(height: 4),
          Text('Tenant management for future multi-parish deployments', style: TextStyle(fontSize: 12, color: ParishColors.textMuted)),
          const SizedBox(height: 12),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: ParishColors.cardWhite,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ParishColors.borderGrey),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Active Parish Tenant:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: ParishColors.goldLight, borderRadius: BorderRadius.circular(6)),
                      child: const Text('PRIMARY TENANT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ParishColors.goldAccent)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('St. John Paul II Parish (Labuin, Sta. Cruz, Laguna)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ParishColors.marianBlue)),
                Text('Diocese of San Pablo • Vicarial District IV', style: TextStyle(fontSize: 12, color: ParishColors.textMuted)),
                const Divider(height: 24),
                if (isSuperAdmin)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ParishColors.marianBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Multi-parish tenant provisioning will be enabled in Phase 2.'),
                          backgroundColor: ParishColors.marianBlue,
                        ),
                      );
                    },
                    icon: const Icon(Icons.add_business, size: 18),
                    label: const Text('Provision New Diocesan Parish Tenant'),
                  )
                else
                  Text(
                    'Multi-tenant configuration requires Super Administrator privileges.',
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: ParishColors.textMuted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required String status,
    required Color statusColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ParishColors.borderGrey),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ParishColors.backgroundLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: ParishColors.marianBlue, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
                Text(subtitle, style: TextStyle(fontSize: 12, color: ParishColors.textMuted)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
            ),
          ),
        ],
      ),
    );
  }
}