import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../auth/models/user_model.dart';
import '../../auth/presentation/admin_users_page.dart';
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
  // Role-Based Access Control (RBAC) Governance Engine
  // ===========================================================================
  bool _isModuleAllowed(int index) {
    final role = widget.currentUser?.userRole.toLowerCase() ?? 'user';

    switch (index) {
      case 0: // Overview (Dashboard)
        return true;

      case 1: // Sacramental Records Module
      // Clergy, Secretariat, and Encoders (Canon 535)
        return role == 'parishpriest' ||
            role == 'secretary' ||
            role == 'encoder' ||
            role == 'superadmin';

      case 2: // Receipts & Cashiering Module
      // Secretariat, Clergy, PFC Auditors, Parishioners (Personal Receipts)
        return role == 'parishpriest' ||
            role == 'secretary' ||
            role == 'pfc' ||
            role == 'user' ||
            role == 'superadmin';

      case 3: // Appointments & Scheduling Module
      // Secretariat, Clergy, Parishioners (Self-service Bookings)
        return role == 'parishpriest' ||
            role == 'secretary' ||
            role == 'user' ||
            role == 'superadmin';

      case 4: // Asset Inventory Module (CustodiaIMS)
      // Staff, Clergy, Encoders (Field Audits), PFC Auditors (Valuation)
        return role == 'parishpriest' ||
            role == 'secretary' ||
            role == 'encoder' ||
            role == 'pfc' ||
            role == 'admin' ||
            role == 'superadmin';

      case 5: // Smart Archive (ESP32 IoT Telemetry)
      // Technical Administrators, Secretariat, Clergy
        return role == 'parishpriest' ||
            role == 'secretary' ||
            role == 'admin' ||
            role == 'superadmin';

      case 6: // User Profile & System Preferences
        return true;

      default:
        return false;
    }
  }

  String _getRestrictedReason(int index) {
    switch (index) {
      case 1:
        return 'Access Restricted: Canonical Sacramental Registers (Canon 535) are restricted to Clergy, Secretariat, and Encoders.';
      case 2:
        return 'Access Restricted: Financial records and cashiering are restricted to Secretariat, PFC Auditors, and Clergy.';
      case 3:
        return 'Access Restricted: Pastoral scheduling is reserved for Secretariat, Clergy, and Parishioner bookings.';
      case 4:
        return 'Access Restricted: Diocesan property inventory and audits are restricted to authorized church personnel and PFC auditors.';
      case 5:
        return 'Access Restricted: Archive micro-climate hardware calibration is reserved for Technical Administrators and Clergy.';
      default:
        return 'Access Restricted: Your account role does not have authorization to view this module.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildTopNavigationBar(context),
      body: SafeArea(
        child: _isModuleAllowed(_currentIndex)
            ? _views[_currentIndex]
            : _buildUnauthorizedView(),
      ),
      bottomNavigationBar: _buildGcashStyleBottomBar(),
    );
  }

  /// Unified Top Navigation Bar
  PreferredSizeWidget _buildTopNavigationBar(BuildContext context) {
    final role = widget.currentUser?.userRole.toLowerCase() ?? 'user';
    final isAdmin = role == 'admin' || role == 'superadmin';

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
              color: Colors.black.withValues(alpha: 0.03),
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
                // Parish Logo / Emblem
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

                // Parish Title & Location / Staff Subtitle
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'St. John Paul II Parish',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: ParishColors.marianBlue,
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

                // Admin-Specific User Provisioning Quick Link
                if (isAdmin)
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: IconButton(
                      icon: const Icon(Icons.manage_accounts, color: ParishColors.marianBlue, size: 24),
                      tooltip: 'Admin: Manage Accounts',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AdminUsersPage()),
                        );
                      },
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
                        const Icon(
                          Icons.notifications_outlined,
                          size: 26,
                          color: ParishColors.marianBlue,
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

  /// GCash-style Navigation Bar with Role-Sensitive Item Disabling
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
          // 6 Side Items (3 on Left, 3 on Right)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: _buildNavItem(index: 1, label: 'Records', icon: Icons.menu_book_outlined, activeIcon: Icons.menu_book)),
              Expanded(child: _buildNavItem(index: 2, label: 'Receipts', icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long)),
              Expanded(child: _buildNavItem(index: 3, label: 'Appts', icon: Icons.calendar_month_outlined, activeIcon: Icons.calendar_month)),
              const SizedBox(width: 72), // Spacer for elevated circular center button
              Expanded(child: _buildNavItem(index: 4, label: 'Assets', icon: Icons.inventory_2_outlined, activeIcon: Icons.inventory_2)),
              Expanded(child: _buildNavItem(index: 5, label: 'IoT', icon: Icons.sensors_outlined, activeIcon: Icons.sensors)),
              Expanded(child: _buildNavItem(index: 6, label: 'Profile', icon: Icons.person_outline, activeIcon: Icons.person)),
            ],
          ),

          // Elevated Circular Center Button (Always accessible to all users)
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
                          color: ParishColors.marianBlue.withValues(alpha: 0.35),
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
                      color: _currentIndex == 0 ? ParishColors.marianBlue : ParishColors.textMuted,
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
                        ? ParishColors.marianBlue
                        : (isAllowed ? ParishColors.textMuted : ParishColors.borderGrey),
                  ),
                ),
                // Lock overlay for unauthorized modules
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
                    ? ParishColors.marianBlue
                    : (isAllowed ? ParishColors.textMuted : const Color(0xFF94A3B8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Security Fallback View if an unauthorized index is requested
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