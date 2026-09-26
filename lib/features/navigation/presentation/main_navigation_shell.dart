import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../auth/models/user_model.dart';
import '../../auth/services/auth_service.dart';
import '../../dashboard/presentation/dashboard_view.dart';
import '../../dashboard/presentation/dialogs/notification_dialog.dart';
import '../../sacramental_records/presentation/records_view.dart';
import '../../receipts/presentation/receipts_view.dart';
import '../../appointments/presentation/appointments_view.dart';
import '../../asset_inventory/presentation/asset_inventory_view.dart';
import '../../smart_archive/presentation/smart_archive_view.dart';
import '../../profile/presentation/profile_view.dart';

class MainNavigationShell extends StatefulWidget {
  final UserModel? currentUser;

  const MainNavigationShell({super.key, this.currentUser});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  // Index Mapping:
  // 0: Overview (Center Button)
  // 1: Records
  // 2: Receipts
  // 3: Appointments
  // 4: Assets
  // 5: Smart Archive (IoT)
  // 6: Profile
  int _currentIndex = 0;

  late final List<Widget> _views;

  @override
  void initState() {
    super.initState();
    _views = [
      DashboardView(currentUser: widget.currentUser),
      const SacramentalRecordsView(),
      const ReceiptManagementView(),
      const AppointmentsView(),
      const AssetInventoryView(),
      const SmartArchiveView(),
      ProfileView(currentUser: widget.currentUser),
    ];
  }

  // ===========================================================================
  // Pastoral & Operational Role-Based Access Control (RBAC)
  // ===========================================================================
  bool _isModuleAllowed(int index) {
    final role = widget.currentUser?.userRole.toLowerCase() ?? '';

    switch (index) {
      case 0: // Overview (Dashboard)
        return true;

      case 1: // Sacramental Records Module (Canon 535)
      // Clergy, Secretariat, and Records Encoders
        return role == 'parishpriest' ||
            role == 'secretary' ||
            role == 'encoder';

      case 2: // Receipts & Cashiering Module
      // Secretariat, Clergy, and Parish Finance Council (PFC) Auditors
        return role == 'parishpriest' ||
            role == 'secretary' ||
            role == 'pfc';

      case 3: // Appointments & Liturgical Scheduling Module
      // Secretariat and Clergy
        return role == 'parishpriest' ||
            role == 'secretary';

      case 4: // Temporal Asset Inventory (CustodiaIMS)
      // Clergy, Secretariat, Encoders (Auditing), and PFC Auditors (Valuation)
        return role == 'parishpriest' ||
            role == 'secretary' ||
            role == 'encoder' ||
            role == 'pfc';

      case 5: // Smart Archive (ESP32 IoT Telemetry)
      // Secretariat and Clergy
        return role == 'parishpriest' ||
            role == 'secretary';

      case 6: // User Profile & System Preferences
        return true;

      default:
        return false;
    }
  }

  String _getRestrictedReason(int index) {
    switch (index) {
      case 1:
        return 'Access Restricted: Canonical Sacramental Registers (Canon 535) are strictly restricted to Clergy, Secretariat, and Encoders.';
      case 2:
        return 'Access Restricted: Financial ledgers and cashiering are restricted to Secretariat, PFC Auditors, and Clergy.';
      case 3:
        return 'Access Restricted: Pastoral scheduling and clergy calendars are reserved for Secretariat and Clergy.';
      case 4:
        return 'Access Restricted: Diocesan property inventory is restricted to authorized custodial personnel and PFC auditors.';
      case 5:
        return 'Access Restricted: Archive micro-climate hardware monitoring is reserved for Secretariat and Clergy.';
      default:
        return 'Access Restricted: Your assigned operational role does not have authorization to view this module.';
    }
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: ParishColors.cardWhite,
        title: const Text('Confirm Log Out', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to end your current session?'),
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
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppThemeController.themeModeNotifier,
      builder: (context, currentMode, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final bool isDesktop = constraints.maxWidth >= 900;

            if (isDesktop) {
              // ==========================================
              // DESKTOP LAYOUT (Responsive Sidebar)
              // ==========================================
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
                              child: _isModuleAllowed(_currentIndex)
                                  ? _views[_currentIndex]
                                  : _buildUnauthorizedView(),
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
            // MOBILE / TABLET LAYOUT (Top Bar & GCash Bottom Bar)
            // ==========================================
            return Scaffold(
              backgroundColor: ParishColors.backgroundLight,
              appBar: _buildTopNavigationBar(context),
              body: SafeArea(
                child: _isModuleAllowed(_currentIndex)
                    ? _views[_currentIndex]
                    : _buildUnauthorizedView(),
              ),
              bottomNavigationBar: _buildGcashStyleBottomBar(),
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // DESKTOP SIDEBAR
  // ---------------------------------------------------------------------------
  Widget _buildDesktopSidebar() {
    final displayName = widget.currentUser?.firstName ?? 'Staff';
    final userRole = widget.currentUser?.roleDisplay ?? 'Parish Staff';

    return Container(
      width: 280,
      color: ParishColors.cardWhite,
      child: Column(
        children: [
          const SizedBox(height: 36),
          // Parish Logo & Title
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: ParishColors.marianBlueSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: ParishColors.goldAccent, width: 2.5),
            ),
            child: const Icon(Icons.church, size: 34, color: ParishColors.marianBlue),
          ),
          const SizedBox(height: 14),
          Text(
            'St. John Paul II Parish',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: ParishColors.marianBlueAdaptive,
            ),
          ),
          Text(
            'Ecclesiastical Operations Console',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: ParishColors.textMuted,
            ),
          ),
          const SizedBox(height: 28),

          // Sidebar Navigation Links
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildSidebarItem(index: 0, label: 'Overview', icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard),
                const SizedBox(height: 4),
                _buildSidebarItem(index: 1, label: 'Sacramental Records', icon: Icons.menu_book_outlined, activeIcon: Icons.menu_book),
                const SizedBox(height: 4),
                _buildSidebarItem(index: 2, label: 'Receipts & POS', icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long),
                const SizedBox(height: 4),
                _buildSidebarItem(index: 3, label: 'Appointments & Masses', icon: Icons.calendar_month_outlined, activeIcon: Icons.calendar_month),
                const SizedBox(height: 4),
                _buildSidebarItem(index: 4, label: 'Diocesan Assets', icon: Icons.inventory_2_outlined, activeIcon: Icons.inventory_2),
                const SizedBox(height: 4),
                _buildSidebarItem(index: 5, label: 'Smart Archive IoT', icon: Icons.sensors_outlined, activeIcon: Icons.sensors),
                const SizedBox(height: 4),
                _buildSidebarItem(index: 6, label: 'Staff Profile & Theme', icon: Icons.person_outline, activeIcon: Icons.person),
              ],
            ),
          ),

          // Notification Alert Shortcut
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: InkWell(
              onTap: () => showNotificationModal(context),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: ParishColors.backgroundLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ParishColors.borderGrey),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_active_outlined, size: 18, color: ParishColors.mercyRed),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '3 Active Parish Alerts',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: const BoxDecoration(color: ParishColors.mercyRed, shape: BoxShape.circle),
                      child: const Text('3', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // User Identity Card & Logout
          Container(
            padding: const EdgeInsets.all(18),
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
                        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'S',
                        style: TextStyle(fontWeight: FontWeight.bold, color: ParishColors.marianBlueAdaptive),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.currentUser?.fullName ?? 'Parish Staff',
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            userRole,
                            style: TextStyle(fontSize: 11, color: ParishColors.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 38,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ParishColors.mercyRed,
                      side: const BorderSide(color: ParishColors.mercyRed),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _confirmLogout(context),
                    icon: const Icon(Icons.logout, size: 16),
                    label: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem({
    required int index,
    required String label,
    required IconData icon,
    required IconData activeIcon,
  }) {
    final bool isAllowed = _isModuleAllowed(index);
    final bool isSelected = _currentIndex == index && isAllowed;

    return InkWell(
      onTap: () {
        if (!isAllowed) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.lock, color: Colors.white, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_getRestrictedReason(index), style: const TextStyle(fontSize: 12))),
                ],
              ),
              backgroundColor: ParishColors.mercyRed,
              duration: const Duration(seconds: 3),
            ),
          );
          return;
        }
        setState(() => _currentIndex = index);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isSelected ? ParishColors.marianBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Opacity(
              opacity: isAllowed ? 1.0 : 0.35,
              child: Icon(
                isSelected ? activeIcon : icon,
                color: isSelected ? Colors.white : ParishColors.textMuted,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : (isAllowed ? ParishColors.textDark : ParishColors.textMuted.withOpacity(0.5)),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!isAllowed)
              const Icon(Icons.lock, size: 13, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MOBILE TOP APP BAR
  // ---------------------------------------------------------------------------
  PreferredSizeWidget _buildTopNavigationBar(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(70),
      child: Container(
        decoration: BoxDecoration(
          color: ParishColors.cardWhite,
          border: Border(
            bottom: BorderSide(color: ParishColors.borderGrey, width: 1.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: ParishColors.marianBlueSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: ParishColors.goldAccent, width: 2),
                  ),
                  child: const Icon(
                    Icons.church,
                    size: 28,
                    color: ParishColors.marianBlue,
                  ),
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'St. John Paul II Parish',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: ParishColors.marianBlueAdaptive,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        widget.currentUser != null
                            ? '${widget.currentUser!.firstName} • ${widget.currentUser!.roleDisplay}'
                            : 'Diocese of San Pablo • Labuin, Sta. Cruz',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: ParishColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),

                // Notification Bell with Badge
                InkWell(
                  onTap: () => showNotificationModal(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: ParishColors.backgroundLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ParishColors.borderGrey, width: 1.2),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Icons.notifications_outlined,
                          size: 26,
                          color: ParishColors.marianBlueAdaptive,
                        ),
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: ParishColors.mercyRed,
                              shape: BoxShape.circle,
                            ),
                            child: const Text(
                              '3',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MOBILE GCASH-STYLE BOTTOM BAR
  // ---------------------------------------------------------------------------
  Widget _buildGcashStyleBottomBar() {
    return Container(
      height: 84,
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, -3),
          ),
        ],
        border: Border(top: BorderSide(color: ParishColors.borderGrey, width: 1.2)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: _buildNavItem(index: 1, label: 'Records', icon: Icons.menu_book_outlined, activeIcon: Icons.menu_book)),
              Expanded(child: _buildNavItem(index: 2, label: 'Receipts', icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long)),
              Expanded(child: _buildNavItem(index: 3, label: 'Appts', icon: Icons.calendar_month_outlined, activeIcon: Icons.calendar_month)),
              const SizedBox(width: 72), // Elevated center gap
              Expanded(child: _buildNavItem(index: 4, label: 'Assets', icon: Icons.inventory_2_outlined, activeIcon: Icons.inventory_2)),
              Expanded(child: _buildNavItem(index: 5, label: 'IoT', icon: Icons.sensors_outlined, activeIcon: Icons.sensors)),
              Expanded(child: _buildNavItem(index: 6, label: 'Profile', icon: Icons.person_outline, activeIcon: Icons.person)),
            ],
          ),

          Positioned(
            top: -22,
            child: GestureDetector(
              onTap: () => setState(() => _currentIndex = 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentIndex == 0 ? ParishColors.marianBlue : ParishColors.marianBlueLight,
                      border: Border.all(color: ParishColors.cardWhite, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: ParishColors.marianBlue.withOpacity(0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.church,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Overview',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _currentIndex == 0 ? ParishColors.marianBlueAdaptive : ParishColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String label,
    required IconData icon,
    required IconData activeIcon,
  }) {
    final bool isAllowed = _isModuleAllowed(index);
    final bool isSelected = _currentIndex == index && isAllowed;

    return InkWell(
      onTap: () {
        if (!isAllowed) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.lock, color: Colors.white, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _getRestrictedReason(index),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              backgroundColor: ParishColors.mercyRed,
              duration: const Duration(seconds: 3),
            ),
          );
          return;
        }

        setState(() => _currentIndex = index);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Opacity(
                  opacity: isAllowed ? 1.0 : 0.35,
                  child: Icon(
                    isSelected ? activeIcon : icon,
                    size: 24,
                    color: isSelected
                        ? ParishColors.marianBlueAdaptive
                        : (isAllowed ? ParishColors.textMuted : ParishColors.borderGrey),
                  ),
                ),
                if (!isAllowed)
                  const Positioned(
                    top: -2,
                    right: -5,
                    child: Icon(
                      Icons.lock,
                      size: 11,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected
                    ? ParishColors.marianBlueAdaptive
                    : (isAllowed ? ParishColors.textMuted : const Color(0xFF94A3B8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnauthorizedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: ParishColors.mercyRedSurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shield_outlined, size: 54, color: ParishColors.mercyRed),
            ),
            const SizedBox(height: 18),
            Text(
              'Module Access Restricted',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: ParishColors.textDark),
            ),
            const SizedBox(height: 8),
            Text(
              _getRestrictedReason(_currentIndex),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: ParishColors.textMuted, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: ParishColors.marianBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () => setState(() => _currentIndex = 0),
              icon: const Icon(Icons.home, size: 18),
              label: const Text('Return to Overview'),
            ),
          ],
        ),
      ),
    );
  }
}