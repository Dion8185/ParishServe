import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../dashboard/presentation/dashboard_view.dart';
import '../../sacramental_records/presentation/records_view.dart';
import '../../receipts/presentation/receipts_view.dart';
import '../../appointments/presentation/appointments_view.dart';
import '../../asset_inventory/presentation/asset_inventory_view.dart';
import '../../smart_archive/presentation/smart_archive_view.dart';

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  // The 6 Distinct Primary Modules of ParishServe
  final List<Widget> _views = const [
    DashboardView(),
    SacramentalRecordsView(),
    ReceiptManagementView(),
    AppointmentsView(),
    AssetInventoryView(),
    SmartArchiveView(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _views[_currentIndex]),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: ParishColors.borderGrey, width: 1.5)),
        ),
        child: NavigationBar(
          height: 76,
          backgroundColor: ParishColors.cardWhite,
          indicatorColor: ParishColors.goldLight,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) => setState(() => _currentIndex = index),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined, size: 24, color: ParishColors.marianBlue),
              selectedIcon: Icon(Icons.dashboard, size: 26, color: ParishColors.marianBlue),
              label: 'Overview',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined, size: 24, color: ParishColors.marianBlue),
              selectedIcon: Icon(Icons.menu_book, size: 26, color: ParishColors.marianBlue),
              label: 'Records',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined, size: 24, color: ParishColors.marianBlue),
              selectedIcon: Icon(Icons.receipt_long, size: 26, color: ParishColors.marianBlue),
              label: 'Receipts',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined, size: 24, color: ParishColors.marianBlue),
              selectedIcon: Icon(Icons.calendar_month, size: 26, color: ParishColors.marianBlue),
              label: 'Appts',
            ),
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined, size: 24, color: ParishColors.marianBlue),
              selectedIcon: Icon(Icons.inventory_2, size: 26, color: ParishColors.marianBlue),
              label: 'Assets',
            ),
            NavigationDestination(
              icon: Icon(Icons.sensors_outlined, size: 24, color: ParishColors.marianBlue),
              selectedIcon: Icon(Icons.sensors, size: 26, color: ParishColors.marianBlue),
              label: 'IoT Archive',
            ),
          ],
        ),
      ),
    );
  }
}