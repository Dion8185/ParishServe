import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../auth/models/user_model.dart';
import '../../dashboard/presentation/dashboard_view.dart';
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
      body: SafeArea(child: _views[_currentIndex]),
      bottomNavigationBar: _buildGcashStyleBottomBar(),
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