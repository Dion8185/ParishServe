// =============================================================================
// FILE: lib/features/navigation/presentation/main_navigation_shell.dart
// =============================================================================

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../auth/models/user_model.dart';
import '../../auth/services/auth_service.dart';
import '../../dashboard/presentation/dashboard_view.dart';
import '../../dashboard/presentation/dialogs/notification_dialog.dart';
import '../../notifications/services/in_app_notification_service.dart';
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
  bool _isCenterHubPressed = false;

  late final List<Widget> _views;

  @override
  void initState() {
    super.initState();

    // Auto-synchronize staff push tags upon dashboard load
    if (widget.currentUser != null) {
      NotificationService.syncStaffUser(widget.currentUser!);
    }

    // Start live Supabase Realtime listener for in-app notification count & history
    InAppNotificationService.startRealtimeListener();

    // Consume and execute any pending notification payload received during cold-start / app-killed launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.consumePendingNotification(context);
    });

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
  void dispose() {
    InAppNotificationService.stopRealtimeListener();
    super.dispose();
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
        return role == 'parishpriest' ||
            role == 'secretary' ||
            role == 'encoder';

      case 2: // Receipts & Cashiering Module
        return role == 'parishpriest' ||
            role == 'secretary' ||
            role == 'pfc';

      case 3: // Appointments & Liturgical Scheduling Module
        return role == 'parishpriest' ||
            role == 'secretary';

      case 4: // Temporal Asset Inventory (CustodiaIMS)
        return role == 'parishpriest' ||
            role == 'secretary' ||
            role == 'encoder' ||
            role == 'pfc';

      case 5: // Smart Archive (ESP32 IoT Telemetry)
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

  void _onNavigationItemTapped(int index) {
    if (!_isModuleAllowed(index)) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.lock_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _getRestrictedReason(index),
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: ParishColors.mercyRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    if (_currentIndex != index) {
      HapticFeedback.selectionClick();
      setState(() => _currentIndex = index);
    }
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: ParishColors.cardWhite,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ParishColors.mercyRedSurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout_rounded, color: ParishColors.mercyRed, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('Confirm Sign Out', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Text(
          'Are you sure you want to end your administrative session for St. John Paul II Parish?',
          style: TextStyle(fontSize: 13.5, color: ParishColors.textDark, height: 1.4),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await AuthService.signOut();
            },
            child: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
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
              return Scaffold(
                backgroundColor: ParishColors.backgroundLight,
                body: Row(
                  children: [
                    _buildModernDesktopSidebar(),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1440),
                          child: ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(24),
                              bottomLeft: Radius.circular(24),
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

            // Mobile / Tablet View: True Floating Island Overlay
            return Scaffold(
              backgroundColor: ParishColors.backgroundLight,
              appBar: _buildModernMobileAppBar(context),
              body: Stack(
                children: [
                  // Layer 0: Page View (Extends full screen beneath the floating dock)
                  Positioned.fill(
                    child: _isModuleAllowed(_currentIndex)
                        ? _views[_currentIndex]
                        : _buildUnauthorizedView(),
                  ),

                  // Layer 1: True Floating Glass Island Dock with Crisp Outline
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _buildModernMobileFloatingDock(context),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // 1. DESKTOP SIDEBAR: Executive Catholic Chancery Architecture
  // ===========================================================================
  Widget _buildModernDesktopSidebar() {
    final displayName = widget.currentUser?.firstName ?? 'Staff';
    final userRole = widget.currentUser?.roleDisplay ?? 'Parish Staff';
    final isDark = AppThemeController.isDarkMode;

    return Container(
      width: 290,
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        border: Border(
          right: BorderSide(color: ParishColors.borderGrey.withOpacity(0.6), width: 1.0),
        ),
      ),
      child: Column(
        children: [
          // Header: Crest & Parish Brand
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    color: ParishColors.marianBlueSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: ParishColors.goldAccent, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: ParishColors.marianBlue.withOpacity(0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.church_rounded,
                      size: 28,
                      color: ParishColors.marianBlueAdaptive,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'St. John Paul II',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.2,
                          color: ParishColors.textDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Chancery Operations',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: ParishColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Categorized Navigation Sections
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              physics: const BouncingScrollPhysics(),
              children: [
                _buildSidebarSectionLabel('MAIN DESK'),
                _buildDesktopSidebarItem(
                  index: 0,
                  label: 'Overview & Activity',
                  icon: Icons.dashboard_outlined,
                  activeIcon: Icons.dashboard_rounded,
                ),
                _buildDesktopSidebarItem(
                  index: 1,
                  label: 'Sacramental Registers',
                  icon: Icons.menu_book_outlined,
                  activeIcon: Icons.menu_book_rounded,
                ),

                const SizedBox(height: 16),
                _buildSidebarSectionLabel('LITURGY & FINANCE'),
                _buildDesktopSidebarItem(
                  index: 2,
                  label: 'Receipts & Cashier POS',
                  icon: Icons.receipt_long_outlined,
                  activeIcon: Icons.receipt_long_rounded,
                ),
                _buildDesktopSidebarItem(
                  index: 3,
                  label: 'Schedules & Masses',
                  icon: Icons.calendar_month_outlined,
                  activeIcon: Icons.calendar_month_rounded,
                ),

                const SizedBox(height: 16),
                _buildSidebarSectionLabel('CUSTODIAL & ARCHIVE'),
                _buildDesktopSidebarItem(
                  index: 4,
                  label: 'Parish Asset Inventory',
                  icon: Icons.inventory_2_outlined,
                  activeIcon: Icons.inventory_2_rounded,
                ),
                _buildDesktopSidebarItem(
                  index: 5,
                  label: 'Smart Archive Telemetry',
                  icon: Icons.sensors_outlined,
                  activeIcon: Icons.sensors_rounded,
                ),

                const SizedBox(height: 16),
                _buildSidebarSectionLabel('ACCOUNT & SETTINGS'),
                _buildDesktopSidebarItem(
                  index: 6,
                  label: 'Staff Profile & Security',
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                ),
              ],
            ),
          ),

          // Footer Utility Panel (Notification Tray, Theme Switch & User Tag)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ParishColors.backgroundLight,
              border: Border(top: BorderSide(color: ParishColors.borderGrey.withOpacity(0.5))),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ValueListenableBuilder<int>(
                      valueListenable: InAppNotificationService.unreadCountNotifier,
                      builder: (context, unreadCount, _) {
                        final hasUnread = unreadCount > 0;

                        return InkWell(
                          onTap: () => showNotificationModal(context),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: hasUnread ? ParishColors.mercyRedSurface : ParishColors.cardWhite,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: hasUnread ? ParishColors.mercyRed.withOpacity(0.4) : ParishColors.borderGrey,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  hasUnread ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                                  size: 16,
                                  color: hasUnread ? ParishColors.mercyRed : ParishColors.marianBlueAdaptive,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  hasUnread ? '$unreadCount Alert${unreadCount > 1 ? "s" : ""}' : 'Alerts',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: hasUnread ? FontWeight.bold : FontWeight.w600,
                                    color: hasUnread ? ParishColors.mercyRed : ParishColors.textDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    // Light / Dark Mode Toggle
                    InkWell(
                      onTap: () {
                        AppThemeController.toggleTheme(!isDark, userId: widget.currentUser?.userId);
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: ParishColors.cardWhite,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: ParishColors.borderGrey),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                              size: 15,
                              color: isDark ? const Color(0xFFFBBF24) : ParishColors.marianBlue,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              isDark ? 'Dark' : 'Light',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: ParishColors.textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // User Identity Card & Sign Out
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ParishColors.cardWhite,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ParishColors.borderGrey.withOpacity(0.7)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: ParishColors.marianBlueSurface,
                        child: Text(
                          displayName.isNotEmpty ? displayName[0].toUpperCase() : 'S',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: ParishColors.marianBlueAdaptive,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.currentUser?.fullName ?? 'Parish Personnel',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: ParishColors.textDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              userRole,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: ParishColors.textMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout_rounded, size: 18),
                        color: ParishColors.mercyRed,
                        tooltip: 'Sign Out',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        onPressed: () => _confirmLogout(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
          color: ParishColors.textMuted.withOpacity(0.75),
        ),
      ),
    );
  }

  Widget _buildDesktopSidebarItem({
    required int index,
    required String label,
    required IconData icon,
    required IconData activeIcon,
  }) {
    final bool isAllowed = _isModuleAllowed(index);
    final bool isSelected = _currentIndex == index && isAllowed;

    return Padding(
      padding: const EdgeInsets.only(bottom: 3.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onNavigationItemTapped(index),
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? ParishColors.marianBlue
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              boxShadow: isSelected
                  ? [
                BoxShadow(
                  color: ParishColors.marianBlue.withOpacity(0.24),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
                  : null,
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
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : (isAllowed ? ParishColors.textDark : ParishColors.textMuted.withOpacity(0.5)),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!isAllowed)
                  Icon(Icons.lock_rounded, size: 13, color: ParishColors.borderGrey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 2. MODERN MOBILE APP BAR (Clean Glassmorphic Top Bar)
  // ===========================================================================
  PreferredSizeWidget _buildModernMobileAppBar(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(66),
      child: Container(
        decoration: BoxDecoration(
          color: ParishColors.cardWhite,
          border: Border(
            bottom: BorderSide(color: ParishColors.borderGrey.withOpacity(0.6), width: 1.0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: ParishColors.marianBlueSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ParishColors.goldAccent, width: 1.8),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.church_rounded,
                      size: 24,
                      color: ParishColors.marianBlueAdaptive,
                    ),
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
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                          color: ParishColors.marianBlueAdaptive,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        widget.currentUser != null
                            ? '${widget.currentUser!.firstName} • ${widget.currentUser!.roleDisplay}'
                            : 'Diocese of San Pablo • Chancery',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: ParishColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),

                InkWell(
                  onTap: () => showNotificationModal(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: ParishColors.backgroundLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ParishColors.borderGrey.withOpacity(0.7)),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          Icons.notifications_outlined,
                          size: 22,
                          color: ParishColors.marianBlueAdaptive,
                        ),
                        ValueListenableBuilder<int>(
                          valueListenable: InAppNotificationService.unreadCountNotifier,
                          builder: (context, unreadCount, _) {
                            if (unreadCount <= 0) return const SizedBox.shrink();

                            return Positioned(
                              top: 6,
                              right: 6,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: ParishColors.mercyRed,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                                child: Center(
                                  child: Text(
                                    unreadCount > 9 ? '9+' : '$unreadCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.bold,
                                      height: 1.0,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
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

  // ===========================================================================
  // 3. MODERN MOBILE FLOATING DOCK (Top-Layer Island with Crisp Defined Border)
  // ===========================================================================
  Widget _buildModernMobileFloatingDock(BuildContext context) {
    final bool isDark = AppThemeController.isDarkMode;
    final double bottomInset = MediaQuery.of(context).padding.bottom;

    return Padding(
      // Ensure the island floats cleanly above the system gesture bar with zero canvas background
      padding: EdgeInsets.fromLTRB(
        14,
        0,
        14,
        bottomInset > 0 ? bottomInset + 4 : 14,
      ),
      child: SizedBox(
        height: 84, // Headroom ensuring the elevated hero center button is not clipped
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            // Glassmorphic Floating Dock Shell with Unclipped Drop Shadow & Outline Border
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 68,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    // Deep ambient drop shadow to separate island from white backgrounds
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.45 : 0.12),
                      blurRadius: 22,
                      spreadRadius: 1,
                      offset: const Offset(0, 6),
                    ),
                    // Marian Blue rim shadow for elevated presence
                    BoxShadow(
                      color: ParishColors.marianBlue.withOpacity(isDark ? 0.20 : 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: (isDark ? const Color(0xFF1E293B) : ParishColors.cardWhite).withOpacity(0.92),
                        borderRadius: BorderRadius.circular(24),
                        // Crisp defined outline preventing blend with white background
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.20)
                              : ParishColors.borderGrey,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          // 3 Modules Left
                          Expanded(
                            child: _buildModernDockItem(
                              index: 1,
                              label: 'Records',
                              icon: Icons.menu_book_outlined,
                              activeIcon: Icons.menu_book_rounded,
                            ),
                          ),
                          Expanded(
                            child: _buildModernDockItem(
                              index: 2,
                              label: 'Receipts',
                              icon: Icons.receipt_long_outlined,
                              activeIcon: Icons.receipt_long_rounded,
                            ),
                          ),
                          Expanded(
                            child: _buildModernDockItem(
                              index: 3,
                              label: 'Appts',
                              icon: Icons.calendar_month_outlined,
                              activeIcon: Icons.calendar_month_rounded,
                            ),
                          ),

                          // Gap Reserved for Hero Center Hub
                          const SizedBox(width: 58),

                          // 3 Modules Right
                          Expanded(
                            child: _buildModernDockItem(
                              index: 4,
                              label: 'Assets',
                              icon: Icons.inventory_2_outlined,
                              activeIcon: Icons.inventory_2_rounded,
                            ),
                          ),
                          Expanded(
                            child: _buildModernDockItem(
                              index: 5,
                              label: 'IoT',
                              icon: Icons.sensors_outlined,
                              activeIcon: Icons.sensors_rounded,
                            ),
                          ),
                          Expanded(
                            child: _buildModernDockItem(
                              index: 6,
                              label: 'Profile',
                              icon: Icons.person_outline_rounded,
                              activeIcon: Icons.person_rounded,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Center Hero Hub Button ("Overview") with Spring Press Interaction
            Positioned(
              top: 0,
              child: GestureDetector(
                onTapDown: (_) => setState(() => _isCenterHubPressed = true),
                onTapUp: (_) {
                  setState(() => _isCenterHubPressed = false);
                  _onNavigationItemTapped(0);
                },
                onTapCancel: () => setState(() => _isCenterHubPressed = false),
                child: AnimatedScale(
                  scale: _isCenterHubPressed ? 0.92 : 1.0,
                  duration: const Duration(milliseconds: 140),
                  curve: Curves.easeOutBack,
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: _currentIndex == 0
                            ? [ParishColors.marianBlue, ParishColors.marianBlueLight]
                            : [
                          ParishColors.marianBlueLight.withOpacity(0.95),
                          ParishColors.marianBlue.withOpacity(0.95),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: _currentIndex == 0
                            ? ParishColors.goldAccent
                            : (isDark ? Colors.white.withOpacity(0.8) : ParishColors.cardWhite),
                        width: _currentIndex == 0 ? 3.0 : 2.4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.35 : 0.14),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: ParishColors.marianBlue.withOpacity(_currentIndex == 0 ? 0.45 : 0.22),
                          blurRadius: _currentIndex == 0 ? 16 : 8,
                          spreadRadius: _currentIndex == 0 ? 2 : 0,
                          offset: const Offset(0, 4),
                        ),
                        if (_currentIndex == 0)
                          BoxShadow(
                            color: ParishColors.goldAccent.withOpacity(0.35),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                      ],
                    ),
                    child: Center(
                      child: AnimatedScale(
                        scale: _currentIndex == 0 ? 1.08 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(
                          Icons.church_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Overview Floating Micro-Label
            Positioned(
              bottom: 4,
              child: IgnorePointer(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: _currentIndex == 0 ? FontWeight.w800 : FontWeight.w600,
                    letterSpacing: -0.1,
                    color: _currentIndex == 0
                        ? ParishColors.marianBlueAdaptive
                        : ParishColors.textMuted.withOpacity(0.85),
                  ),
                  child: const Text('Overview'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernDockItem({
    required int index,
    required String label,
    required IconData icon,
    required IconData activeIcon,
  }) {
    final bool isAllowed = _isModuleAllowed(index);
    final bool isSelected = _currentIndex == index && isAllowed;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onNavigationItemTapped(index),
        borderRadius: BorderRadius.circular(18),
        splashColor: ParishColors.marianBlue.withOpacity(0.08),
        highlightColor: ParishColors.marianBlue.withOpacity(0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  // Icon with Smooth Spring Scale
                  AnimatedScale(
                    scale: isSelected ? 1.14 : 1.0,
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutBack,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected ? ParishColors.marianBlueSurface : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Opacity(
                        opacity: isAllowed ? 1.0 : 0.35,
                        child: Icon(
                          isSelected ? activeIcon : icon,
                          size: 21,
                          color: isSelected
                              ? ParishColors.marianBlueAdaptive
                              : (isAllowed ? ParishColors.textDark.withOpacity(0.72) : ParishColors.borderGrey),
                        ),
                      ),
                    ),
                  ),

                  // Lock indicator for restricted roles
                  if (!isAllowed)
                    Positioned(
                      top: 1,
                      right: 2,
                      child: Container(
                        padding: const EdgeInsets.all(1.5),
                        decoration: BoxDecoration(
                          color: ParishColors.cardWhite,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.lock_rounded,
                          size: 10,
                          color: ParishColors.textMuted.withOpacity(0.8),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),

              // Active Indicator Under-Bar Glow
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: isSelected ? 12 : 0,
                height: 3,
                decoration: BoxDecoration(
                  color: isSelected ? ParishColors.marianBlueAdaptive : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: isSelected
                      ? [
                    BoxShadow(
                      color: ParishColors.marianBlueAdaptive.withOpacity(0.5),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                      : null,
                ),
              ),
              const SizedBox(height: 2),

              // Responsive Text Label
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 9.8,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  letterSpacing: -0.2,
                  color: isSelected
                      ? ParishColors.marianBlueAdaptive
                      : (isAllowed ? ParishColors.textDark.withOpacity(0.72) : ParishColors.borderGrey),
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 4. RESTRICTED MODULE VIEW (Canonical Isolation Guard)
  // ===========================================================================
  Widget _buildUnauthorizedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ParishColors.mercyRedSurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shield_outlined, size: 52, color: ParishColors.mercyRed),
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
              icon: const Icon(Icons.home_rounded, size: 18),
              label: const Text('Return to Overview'),
            ),
          ],
        ),
      ),
    );
  }
}