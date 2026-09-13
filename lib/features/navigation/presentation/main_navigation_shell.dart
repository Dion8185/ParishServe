import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../auth/models/user_model.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Unified Top Navigation Bar (Visible across all tabs)
      appBar: _buildTopNavigationBar(context),
      body: SafeArea(child: _views[_currentIndex]),
      bottomNavigationBar: _buildGcashStyleBottomBar(),
    );
  }

  /// Unified Top Navigation Bar with Parish Logo on Left & Notifications on Right
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
                // Parish Logo / Emblem Container (Left Side)
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

                // Notification Bell with Badge (Right Side)
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

  /// GCash-style Navigation Bar with Elevated Center Circular Button
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
              const SizedBox(width: 72), // Middle spacer for elevated circle
              Expanded(child: _buildNavItem(index: 4, label: 'Assets', icon: Icons.inventory_2_outlined, activeIcon: Icons.inventory_2)),
              Expanded(child: _buildNavItem(index: 5, label: 'IoT', icon: Icons.sensors_outlined, activeIcon: Icons.sensors)),
              Expanded(child: _buildNavItem(index: 6, label: 'Profile', icon: Icons.person_outline, activeIcon: Icons.person)),
            ],
          ),

          // Elevated Circular Center Button (GCash QR-Style for "Overview / Dashboard")
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
    final bool isSelected = _currentIndex == index;

    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              size: 24,
              color: isSelected ? ParishColors.marianBlue : ParishColors.textMuted,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? ParishColors.marianBlue : ParishColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}