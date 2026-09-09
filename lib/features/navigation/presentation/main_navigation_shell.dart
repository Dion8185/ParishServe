import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../dashboard/presentation/dashboard_view.dart';
import '../../sacramental_records/presentation/records_view.dart';
import '../../receipts/presentation/receipts_view.dart';
import '../../asset_inventory/presentation/assets_and_archive_view.dart';

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  final List<Widget> _views = const [
    DashboardView(),
    SacramentalRecordsView(),
    ReceiptManagementView(),
    AssetAndArchiveView(),
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
          height: 74,
          backgroundColor: ParishColors.cardWhite,
          indicatorColor: ParishColors.goldLight,
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) => setState(() => _currentIndex = index),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined, size: 28, color: ParishColors.marianBlue),
              selectedIcon: Icon(Icons.dashboard, size: 30, color: ParishColors.marianBlue),
              label: 'Overview',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined, size: 28, color: ParishColors.marianBlue),
              selectedIcon: Icon(Icons.menu_book, size: 30, color: ParishColors.marianBlue),
              label: 'Records',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined, size: 28, color: ParishColors.marianBlue),
              selectedIcon: Icon(Icons.receipt_long, size: 30, color: ParishColors.marianBlue),
              label: 'Receipts',
            ),
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined, size: 28, color: ParishColors.marianBlue),
              selectedIcon: Icon(Icons.inventory_2, size: 30, color: ParishColors.marianBlue),
              label: 'Assets & IoT',
            ),
          ],
        ),
      ),
    );
  }
}