import 'package:flutter/material.dart';

void main() {
  runApp(const ParishServeApp());
}

/// ============================================================================
/// PARISH THEME & COAT OF ARMS PALETTE DEFINITION
/// ============================================================================
class ParishColors {
  // Marian Blue (Primary Coat of Arms Field, Shield & Marian 'M')
  static const Color marianBlue = Color(0xFF164E87);
  static const Color marianBlueLight = Color(0xFF246EB9);
  static const Color marianBlueSurface = Color(0xFFEDF4FB);

  // Papal & Wheat Gold (Outer Ring & Rice Stalks)
  static const Color goldAccent = Color(0xFFD49B18);
  static const Color goldLight = Color(0xFFFFF7E6);

  // Divine Mercy Crimson (Accent Ray / Urgent Alerts / Notifications)
  static const Color mercyRed = Color(0xFFB91C1C);
  static const Color mercyRedSurface = Color(0xFFFDF2F2);

  // Olive Green (Dove's Olive Branch / Safe Environmental Status)
  static const Color oliveGreen = Color(0xFF2D6A4F);
  static const Color oliveGreenSurface = Color(0xFFEDF7F2);

  // High-Contrast Neutrals (Senior-Friendly WCAG AAA Readability)
  static const Color textDark = Color(0xFF1E293B);
  static const Color textMuted = Color(0xFF475569);
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color borderGrey = Color(0xFFCBD5E1);
}

class ParishServeApp extends StatelessWidget {
  const ParishServeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ParishServe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: ParishColors.backgroundLight,
        colorScheme: ColorScheme.fromSeed(
          seedColor: ParishColors.marianBlue,
          primary: ParishColors.marianBlue,
          secondary: ParishColors.goldAccent,
          surface: ParishColors.cardWhite,
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: ParishColors.textDark,
            letterSpacing: -0.5,
          ),
          titleLarge: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: ParishColors.textDark,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: ParishColors.textDark,
          ),
          bodyMedium: TextStyle(
            fontSize: 15,
            color: ParishColors.textMuted,
          ),
        ),
      ),
      home: const LoginView(),
    );
  }
}

/// ============================================================================
/// 0. STATIC LOGIN PAGE (Accessible, High-Contrast & Senior-Friendly)
/// ============================================================================
class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ParishColors.backgroundLight,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Parish Coat of Arms Emblem Container
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: ParishColors.marianBlueSurface,
                    shape: BoxShape.circle,
                    border: Border.all(color: ParishColors.goldAccent, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.church,
                    size: 52,
                    color: ParishColors.marianBlue,
                  ),
                ),
                const SizedBox(height: 16),

                // Parish & System Titles
                const Text(
                  'St. John Paul II Parish',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: ParishColors.marianBlue,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Diocese of San Pablo • Labuin, Sta. Cruz, Laguna',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ParishColors.textMuted,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: ParishColors.goldLight,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: ParishColors.goldAccent, width: 1.2),
                  ),
                  child: const Text(
                    'ParishServe Management Portal',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: ParishColors.textDark,
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // Login Form Card
                Container(
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Staff Sign In',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: ParishColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Enter your parish credentials to proceed.',
                        style: TextStyle(fontSize: 13, color: ParishColors.textMuted),
                      ),
                      const SizedBox(height: 20),

                      // Username Field
                      const Text(
                        'Username or Staff ID',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: TextEditingController(text: 'parish.secretary'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.person, color: ParishColors.marianBlue, size: 24),
                          filled: true,
                          fillColor: ParishColors.backgroundLight,
                          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: ParishColors.borderGrey),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: ParishColors.marianBlue, width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Password Field
                      const Text(
                        'Password',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        obscureText: _obscurePassword,
                        controller: TextEditingController(text: '••••••••••'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.lock, color: ParishColors.marianBlue, size: 24),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: ParishColors.textMuted,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          filled: true,
                          fillColor: ParishColors.backgroundLight,
                          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: ParishColors.borderGrey),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: ParishColors.marianBlue, width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Assigned Role Indicator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: ParishColors.marianBlueSurface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.badge_outlined, size: 20, color: ParishColors.marianBlue),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Role: Parish Secretary / Office Staff',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ParishColors.marianBlue),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),

                      // Oversized Primary Login Button
                      SizedBox(
                        width: double.infinity,
                        height: 58,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ParishColors.marianBlue,
                            foregroundColor: Colors.white,
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => const MainNavigationShell()),
                            );
                          },
                          icon: const Icon(Icons.login, size: 24),
                          label: const Text(
                            'LOG IN TO PARISHSERVE',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Elderly/Staff Assistance Banner
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.help_outline, size: 20, color: ParishColors.textMuted),
                    const SizedBox(width: 6),
                    TextButton(
                      onPressed: () => _showLoginHelpDialog(context),
                      child: const Text(
                        'Need assistance logging in? Tap here',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: ParishColors.marianBlue,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Papal Coat of Arms Motto
                const Text(
                  'TOTUS TUUS',
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                    color: ParishColors.goldAccent,
                    letterSpacing: 2.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLoginHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.support_agent, color: ParishColors.marianBlue, size: 28),
            SizedBox(width: 8),
            Text('Staff Assistance', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'If you forgot your password or require role access:',
              style: TextStyle(fontSize: 14, color: ParishColors.textDark),
            ),
            SizedBox(height: 12),
            Text(
              '• Approach the Parish Priest or Parish Technical Staff.\n• Passwords can be reset directly at the Parish Secretariat terminal.',
              style: TextStyle(fontSize: 13, color: ParishColors.textMuted),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ParishColors.marianBlue,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }
}

/// ============================================================================
/// MAIN NAVIGATION SHELL (Bottom Bar with Generous Touch Targets)
/// ============================================================================
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

/// ============================================================================
/// 1. DASHBOARD & OVERVIEW VIEW (With Notification Bell, Calendar & Logout)
/// ============================================================================
class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Coat of Arms Emblem, Title, Notification Bell & Logout
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: ParishColors.marianBlueSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ParishColors.goldAccent, width: 2),
                ),
                child: const Icon(Icons.church, size: 32, color: ParishColors.marianBlue),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'St. John Paul II Parish',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: ParishColors.marianBlue,
                      ),
                    ),
                    Text(
                      'ParishServe Portal',
                      style: TextStyle(fontSize: 13, color: ParishColors.textMuted),
                    ),
                  ],
                ),
              ),
              // Accessible Notification Bell with Badge
              InkWell(
                onTap: () => _showNotificationModal(context),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: ParishColors.cardWhite,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ParishColors.borderGrey, width: 1.5),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(Icons.notifications_outlined, size: 26, color: ParishColors.marianBlue),
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
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Accessible Log Out Button
              InkWell(
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginView()),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: ParishColors.cardWhite,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ParishColors.borderGrey, width: 1.5),
                  ),
                  child: const Icon(Icons.logout, size: 24, color: ParishColors.mercyRed),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Smart Archive Telemetry Banner (Module 3 - ESP32 Preview)
          _buildArchiveTelemetryCard(context),

          const SizedBox(height: 22),

          // Parish Calendar Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Parish Event Calendar', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: ParishColors.goldLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'September 2026',
                  style: TextStyle(fontWeight: FontWeight.bold, color: ParishColors.goldAccent, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text('Tap any highlighted date to view scheduled church events.', style: TextStyle(fontSize: 13, color: ParishColors.textMuted)),
          const SizedBox(height: 12),
          _buildInteractiveCalendar(context),

          const SizedBox(height: 24),
          const Text('Quick Operational Actions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          _buildLargeActionCard(
            context: context,
            icon: Icons.document_scanner,
            title: 'Scan Sacramental Page (OCR)',
            subtitle: 'Digitize Baptism, Confirmation, or Marriage books',
            accentColor: ParishColors.marianBlue,
            onTap: () => _showOcrScanModal(context),
          ),
          const SizedBox(height: 12),
          _buildLargeActionCard(
            context: context,
            icon: Icons.edit_calendar,
            title: 'Schedule Parish Appointment',
            subtitle: 'Book Mass intentions, weddings, or baptism dates',
            accentColor: ParishColors.goldAccent,
            onTap: () => _showScheduleAppointmentModal(context),
          ),
          const SizedBox(height: 12),
          _buildLargeActionCard(
            context: context,
            icon: Icons.payments_outlined,
            title: 'Issue Ecclesiastical Receipt',
            subtitle: 'Record fees, certificate requests & donations',
            accentColor: ParishColors.oliveGreen,
            onTap: () => _showNewTransactionModal(context),
          ),
        ],
      ),
    );
  }

  Widget _buildArchiveTelemetryCard(BuildContext context) {
    return InkWell(
      onTap: () => _showSensorDetailModal(
        context,
        roomTitle: 'Sacramental Archive Room',
        nodeId: 'ESP32-NODE-01',
        temperature: '24.2 °C',
        humidity: '54 %',
        isWarning: false,
      ),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: ParishColors.cardWhite,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: ParishColors.borderGrey, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.sensors, color: ParishColors.marianBlue, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Archive Sensors (ESP32)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: ParishColors.oliveGreenSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: ParishColors.oliveGreen),
                  ),
                  child: const Text(
                    'SAFE STATUS',
                    style: TextStyle(
                      color: ParishColors.oliveGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 22),
            const Row(
              children: [
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.thermostat, size: 26, color: ParishColors.marianBlue),
                      SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Temperature', style: TextStyle(fontSize: 12, color: ParishColors.textMuted)),
                          Text('24.2 °C', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
                VerticalDivider(width: 20),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.water_drop_outlined, size: 26, color: ParishColors.marianBlue),
                      SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Humidity', style: TextStyle(fontSize: 12, color: ParishColors.textMuted)),
                          Text('54 %', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractiveCalendar(BuildContext context) {
    final daysOfWeek = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    final eventsMap = {
      6: 'Sunday Mass & Community Baptism',
      12: 'Nuptial Mass (Santos-Ramos Wedding)',
      15: 'Diocesan Asset Audit Inspection',
      20: 'Parish Confirmation Rites',
      27: 'Feast Day Preparation Meeting',
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ParishColors.borderGrey, width: 1.2),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: daysOfWeek
                .map((d) => SizedBox(
              width: 36,
              child: Text(
                d,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, color: ParishColors.marianBlue, fontSize: 14),
              ),
            ))
                .toList(),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 35,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemBuilder: (context, index) {
              const offset = 2; // September 2026 starts on Tuesday
              final dayNumber = index - offset + 1;

              if (dayNumber < 1 || dayNumber > 30) {
                return const SizedBox.shrink();
              }

              final hasEvent = eventsMap.containsKey(dayNumber);

              return InkWell(
                onTap: hasEvent
                    ? () => _showCalendarEventModal(
                  context,
                  date: 'September $dayNumber, 2026',
                  eventTitle: eventsMap[dayNumber]!,
                )
                    : null,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  decoration: BoxDecoration(
                    color: hasEvent ? ParishColors.goldLight : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: hasEvent ? ParishColors.goldAccent : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        '$dayNumber',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: hasEvent ? FontWeight.bold : FontWeight.normal,
                          color: hasEvent ? ParishColors.textDark : ParishColors.textMuted,
                        ),
                      ),
                      if (hasEvent)
                        Positioned(
                          bottom: 4,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: ParishColors.marianBlue,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLargeActionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: ParishColors.cardWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ParishColors.borderGrey, width: 1.2),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: accentColor.withOpacity(0.12),
              child: Icon(icon, size: 28, color: accentColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 13, color: ParishColors.textMuted)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 18, color: ParishColors.textMuted),
          ],
        ),
      ),
    );
  }
}

/// ============================================================================
/// 2. SACRAMENTAL RECORDS MODULE (Module 1 Static Prototype)
/// ============================================================================
class SacramentalRecordsView extends StatelessWidget {
  const SacramentalRecordsView({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sacramental Records', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const Text('Search registry or digitize manual books', style: TextStyle(color: ParishColors.textMuted)),
          const SizedBox(height: 18),

          Container(
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: ParishColors.cardWhite,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ParishColors.marianBlue, width: 1.8),
            ),
            child: const Row(
              children: [
                Icon(Icons.search, size: 28, color: ParishColors.marianBlue),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Search by Name, Year, or Book #...',
                    style: TextStyle(fontSize: 16, color: ParishColors.textMuted),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ParishColors.marianBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _showOcrScanModal(context),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('AI OCR Scan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: ParishColors.marianBlue, width: 1.8),
                      foregroundColor: ParishColors.marianBlue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _showManualEntryModal(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Manual Entry', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          const Text('Recent Sacramental Logs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          _buildRecordTile(
            context: context,
            name: 'Juan Miguel Dela Cruz',
            sacrament: 'BAPTISM',
            bookRef: 'Book 12, Page 143, Entry #04',
            date: 'Baptized: Oct 14, 2021',
          ),
          _buildRecordTile(
            context: context,
            name: 'Carlos Santos & Maria Ramos',
            sacrament: 'MATRIMONY',
            bookRef: 'Book 06, Page 52, Entry #01',
            date: 'Married: Feb 18, 2023',
          ),
          _buildRecordTile(
            context: context,
            name: 'Gabriel Morales',
            sacrament: 'CONFIRMATION',
            bookRef: 'Book 04, Page 88, Entry #19',
            date: 'Confirmed: Dec 08, 2022',
          ),
        ],
      ),
    );
  }

  Widget _buildRecordTile({
    required BuildContext context,
    required String name,
    required String sacrament,
    required String bookRef,
    required String date,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: ParishColors.marianBlueSurface,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  sacrament,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: ParishColors.marianBlue,
                  ),
                ),
              ),
              const Icon(Icons.qr_code_2, size: 26, color: ParishColors.textMuted),
            ],
          ),
          const SizedBox(height: 8),
          Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(bookRef, style: const TextStyle(fontSize: 14, color: ParishColors.textMuted)),
          Text(date, style: const TextStyle(fontSize: 14, color: ParishColors.textMuted)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: ParishColors.goldLight,
                foregroundColor: ParishColors.textDark,
                elevation: 0,
                side: const BorderSide(color: ParishColors.goldAccent, width: 1.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _showCertificatePreviewModal(
                context,
                name: name,
                sacrament: sacrament,
                bookRef: bookRef,
              ),
              icon: const Icon(Icons.print, size: 20, color: ParishColors.textDark),
              label: const Text('Generate Official Certificate', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

/// ============================================================================
/// 3. RECEIPT MANAGEMENT & TRANSACTIONS (Module 2 Static Prototype)
/// ============================================================================
class ReceiptManagementView extends StatelessWidget {
  const ReceiptManagementView({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Parish Receipts', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const Text('Issue ecclesiastical receipts & manage service fees', style: TextStyle(color: ParishColors.textMuted)),
          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: ParishColors.oliveGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => _showNewTransactionModal(context),
              icon: const Icon(Icons.receipt, size: 26),
              label: const Text('+ Record New Transaction', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 24),

          const Text('Recent Ecclesiastical Receipts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          _buildReceiptCard(
            context: context,
            receiptNo: 'REC-2026-00892',
            payer: 'Theresa Sanchez',
            purpose: 'Baptismal Certificate Request (Pabuklat)',
            amount: '₱ 150.00',
            date: 'Today, 10:15 AM',
            status: 'PAID',
          ),
          _buildReceiptCard(
            context: context,
            receiptNo: 'REC-2026-00891',
            payer: 'Fernando Gomez',
            purpose: 'Thanksgiving Mass Intention',
            amount: '₱ 300.00',
            date: 'Today, 09:30 AM',
            status: 'PAID',
          ),
          _buildReceiptCard(
            context: context,
            receiptNo: 'REC-2026-00890',
            payer: 'Anonymous Benefactor',
            purpose: 'Church Altar Repair Donation',
            amount: '₱ 1,000.00',
            date: 'Yesterday, 04:00 PM',
            status: 'PAID',
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptCard({
    required BuildContext context,
    required String receiptNo,
    required String payer,
    required String purpose,
    required String amount,
    required String date,
    required String status,
  }) {
    return InkWell(
      onTap: () => _showReceiptDetailModal(
        context,
        receiptNo: receiptNo,
        payer: payer,
        purpose: purpose,
        amount: amount,
        date: date,
      ),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ParishColors.cardWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ParishColors.borderGrey),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ParishColors.oliveGreenSurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.description, color: ParishColors.oliveGreen, size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        receiptNo,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ParishColors.marianBlue),
                      ),
                      Text(
                        amount,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: ParishColors.textDark),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(payer, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(purpose, style: const TextStyle(fontSize: 13, color: ParishColors.textMuted)),
                  const SizedBox(height: 4),
                  Text(date, style: const TextStyle(fontSize: 12, color: ParishColors.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ============================================================================
/// 4. ASSET INVENTORY & SMART ARCHIVE VIEW (Modules 3 & 5 Static Prototype)
/// ============================================================================
class AssetAndArchiveView extends StatelessWidget {
  const AssetAndArchiveView({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Assets & Smart Archive', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const Text('Inventory audits & environmental storage status', style: TextStyle(color: ParishColors.textMuted)),
          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: ParishColors.marianBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => _showAuditScanModal(context),
              icon: const Icon(Icons.qr_code_scanner, size: 28),
              label: const Text('Scan QR / Tap NFC for Audit', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 24),

          const Text('Storage Room Telemetry Nodes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _buildStorageNodeTile(
            context: context,
            roomTitle: 'Main Sacramental Archive Room',
            nodeId: 'ESP32-NODE-01',
            temperature: '24.2 °C',
            humidity: '54 %',
            isWarning: false,
          ),
          _buildStorageNodeTile(
            context: context,
            roomTitle: 'Liturgical Vessel & Robe Storage',
            nodeId: 'ESP32-NODE-02',
            temperature: '29.1 °C',
            humidity: '68 %',
            isWarning: true,
          ),

          const SizedBox(height: 24),
          const Text('Registered Parish Assets', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          _buildAssetItemCard(
            context: context,
            controlNo: 'JP2-2023-SAC-0014',
            itemName: 'Gold-Plated Ciboria (Sacred Vessel)',
            location: 'Sacristy Vault - Cabinet A',
            condition: 'VERIFIED / GOOD',
            conditionColor: ParishColors.oliveGreen,
          ),
          _buildAssetItemCard(
            context: context,
            controlNo: 'JP2-2022-AV-0008',
            itemName: 'Wireless Microphone Set (2 Pcs)',
            location: 'Altar Sound Station',
            condition: 'REQUIRES REPAIR',
            conditionColor: ParishColors.mercyRed,
          ),
        ],
      ),
    );
  }

  Widget _buildStorageNodeTile({
    required BuildContext context,
    required String roomTitle,
    required String nodeId,
    required String temperature,
    required String humidity,
    required bool isWarning,
  }) {
    return InkWell(
      onTap: () => _showSensorDetailModal(
        context,
        roomTitle: roomTitle,
        nodeId: nodeId,
        temperature: temperature,
        humidity: humidity,
        isWarning: isWarning,
      ),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isWarning ? ParishColors.mercyRedSurface : ParishColors.cardWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isWarning ? ParishColors.mercyRed : ParishColors.borderGrey,
            width: isWarning ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(roomTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isWarning ? ParishColors.mercyRed : ParishColors.oliveGreen,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isWarning ? 'HUMIDITY ALERT' : 'SAFE',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(nodeId, style: const TextStyle(fontSize: 12, color: ParishColors.textMuted)),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('Temp: $temperature', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(width: 20),
                Text('Humidity: $humidity', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssetItemCard({
    required BuildContext context,
    required String controlNo,
    required String itemName,
    required String location,
    required String condition,
    required Color conditionColor,
  }) {
    return InkWell(
      onTap: () => _showAssetDetailModal(
        context,
        controlNo: controlNo,
        itemName: itemName,
        location: location,
        condition: condition,
      ),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ParishColors.cardWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ParishColors.borderGrey),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: ParishColors.goldLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ParishColors.goldAccent),
              ),
              child: const Icon(Icons.inventory, color: ParishColors.goldAccent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    controlNo,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ParishColors.marianBlue),
                  ),
                  const SizedBox(height: 2),
                  Text(itemName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(location, style: const TextStyle(fontSize: 13, color: ParishColors.textMuted)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: conditionColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      condition,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: conditionColor),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ============================================================================
/// INTERACTIVE POP-UP MODALS & DIALOGS IMPLEMENTATION
/// ============================================================================

// 1. Notification Bell Modal
void _showNotificationModal(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.notifications_active, color: ParishColors.marianBlue, size: 28),
          SizedBox(width: 10),
          Text('Parish Alerts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildNotificationItem(
              icon: Icons.warning_amber_rounded,
              iconColor: ParishColors.mercyRed,
              title: 'Archive Humidity Alert (68%)',
              time: '15 mins ago',
              description: 'Vessel Storage node exceeded 60% relative humidity limit.',
            ),
            const Divider(),
            _buildNotificationItem(
              icon: Icons.assignment_late_outlined,
              iconColor: ParishColors.goldAccent,
              title: 'Priest Approval Required',
              time: '1 hour ago',
              description: 'Baptismal certificate for Juan Dela Cruz awaits review.',
            ),
            const Divider(),
            _buildNotificationItem(
              icon: Icons.calendar_today,
              iconColor: ParishColors.marianBlue,
              title: 'Upcoming Nuptial Mass',
              time: 'Tomorrow, 10:00 AM',
              description: 'Santos-Ramos Wedding scheduled at Main Altar.',
            ),
          ],
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ParishColors.marianBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Dismiss', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    ),
  );
}

Widget _buildNotificationItem({
  required IconData icon,
  required Color iconColor,
  required String title,
  required String time,
  required String description,
}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: iconColor, size: 26),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(time, style: const TextStyle(fontSize: 11, color: ParishColors.textMuted)),
              ],
            ),
            const SizedBox(height: 2),
            Text(description, style: const TextStyle(fontSize: 12, color: ParishColors.textMuted)),
          ],
        ),
      ),
    ],
  );
}

// 2. Calendar Event Details Modal
void _showCalendarEventModal(BuildContext context, {required String date, required String eventTitle}) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.event, color: ParishColors.goldAccent, size: 28),
          const SizedBox(width: 10),
          Expanded(child: Text(date, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: ParishColors.marianBlueSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Scheduled Activity', style: TextStyle(fontSize: 12, color: ParishColors.textMuted)),
                Text(eventTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ParishColors.marianBlue)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Row(
            children: [
              Icon(Icons.location_on_outlined, size: 18, color: ParishColors.textMuted),
              SizedBox(width: 6),
              Text('Venue: Main Church Altar', style: TextStyle(fontSize: 14, color: ParishColors.textDark)),
            ],
          ),
          const SizedBox(height: 6),
          const Row(
            children: [
              Icon(Icons.person_outline, size: 18, color: ParishColors.textMuted),
              SizedBox(width: 6),
              Text('Officiant: Rev. Fr. Parish Priest', style: TextStyle(fontSize: 14, color: ParishColors.textDark)),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Close', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ParishColors.marianBlue)),
        ),
      ],
    ),
  );
}

// 3. AI OCR Scan Modal (Module 1)
void _showOcrScanModal(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.document_scanner, color: ParishColors.marianBlue, size: 28),
          SizedBox(width: 10),
          Text('AI OCR Document Scan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              color: ParishColors.backgroundLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ParishColors.marianBlue, width: 1.5),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.camera_alt_outlined, size: 48, color: ParishColors.marianBlue),
                SizedBox(height: 8),
                Text('Align ledger record inside frame', style: TextStyle(color: ParishColors.textMuted, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ParishColors.oliveGreenSurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: ParishColors.oliveGreen, size: 22),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'AI Match Confidence: 98.4%\nAutomated book/page extraction ready.',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ParishColors.oliveGreen),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel', style: TextStyle(fontSize: 16, color: ParishColors.textMuted)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: ParishColors.marianBlue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Extract & Digitize', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}

// 4. Manual Entry Form Modal (Module 1)
void _showManualEntryModal(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('New Sacramental Entry', style: TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogTextField(label: 'Sacrament Type', hint: 'Baptism / Matrimony / Confirmation'),
            _buildDialogTextField(label: 'Full Name of Subject', hint: 'First, Middle, Last Name'),
            _buildDialogTextField(label: 'Book & Page Reference', hint: 'e.g., Book 12, Page 45, Entry 02'),
            _buildDialogTextField(label: 'Parents / Witnesses', hint: 'Names separated by comma'),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Discard')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: ParishColors.marianBlue,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Save Record'),
        ),
      ],
    ),
  );
}

// 5. Official Certificate Preview Modal (Module 1)
void _showCertificatePreviewModal(
    BuildContext context, {
      required String name,
      required String sacrament,
      required String bookRef,
    }) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Certificate Preview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
        ],
      ),
      content: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ParishColors.cardWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ParishColors.goldAccent, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shield_outlined, size: 40, color: ParishColors.marianBlue),
            const SizedBox(height: 6),
            const Text(
              'PAROCHIA SANCTI IOANNIS PAULI II',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.8),
            ),
            const Text('Diocese of San Pablo', style: TextStyle(fontSize: 11, color: ParishColors.textMuted)),
            const Divider(height: 20),
            Text('CERTIFICATE OF $sacrament', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: ParishColors.marianBlue)),
            const SizedBox(height: 4),
            Text(bookRef, style: const TextStyle(fontSize: 12, color: ParishColors.textMuted)),
            const SizedBox(height: 14),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                border: Border.all(color: ParishColors.borderGrey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.qr_code_2, size: 70, color: ParishColors.textDark),
            ),
            const SizedBox(height: 6),
            const Text('QR Code for Parish Verification', style: TextStyle(fontSize: 10, color: ParishColors.textMuted)),
          ],
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: ParishColors.goldAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            icon: const Icon(Icons.print),
            label: const Text('Print Official Certificate', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    ),
  );
}

// 6. Record New Transaction Modal (Module 2)
void _showNewTransactionModal(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Record Ecclesiastical Receipt', style: TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogTextField(label: 'Payer / Requester', hint: 'e.g., Maria Santos'),
            _buildDialogTextField(label: 'Transaction Purpose', hint: 'Mass Intention / Certificate / Donation'),
            _buildDialogTextField(label: 'Amount Received (PHP)', hint: '₱ 0.00'),
            _buildDialogTextField(label: 'Auto Generated Receipt #', hint: 'REC-2026-00893', enabled: false),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: ParishColors.oliveGreen,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Issue Receipt'),
        ),
      ],
    ),
  );
}

// 7. Ecclesiastical Receipt Detail Modal (Module 2)
void _showReceiptDetailModal(
    BuildContext context, {
      required String receiptNo,
      required String payer,
      required String purpose,
      required String amount,
      required String date,
    }) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Parish Receipt', style: TextStyle(fontWeight: FontWeight.bold)),
          Text(receiptNo, style: const TextStyle(fontSize: 13, color: ParishColors.marianBlue)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Payer: $payer', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text('Purpose: $purpose', style: const TextStyle(fontSize: 14, color: ParishColors.textMuted)),
          Text('Date: $date', style: const TextStyle(fontSize: 13, color: ParishColors.textMuted)),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Amount:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text(amount, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: ParishColors.oliveGreen)),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: ParishColors.marianBlue, foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(ctx),
          icon: const Icon(Icons.print, size: 18),
          label: const Text('Reprint'),
        ),
      ],
    ),
  );
}

// 8. Schedule Appointment Modal (Module 4)
void _showScheduleAppointmentModal(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Schedule Parish Service', style: TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogTextField(label: 'Service Requested', hint: 'Baptism, Wedding, Sick Call'),
            _buildDialogTextField(label: 'Requester Name', hint: 'Full Name'),
            _buildDialogTextField(label: 'Contact Number', hint: '09XX-XXX-XXXX'),
            _buildDialogTextField(label: 'Preferred Date & Time', hint: 'e.g., Sep 18, 2026 - 10:00 AM'),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: ParishColors.goldAccent,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Confirm Schedule'),
        ),
      ],
    ),
  );
}

// 9. Scan QR / NFC Audit Modal (Module 5)
void _showAuditScanModal(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Asset Audit Scanner', style: TextStyle(fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 140,
            width: double.infinity,
            decoration: BoxDecoration(
              color: ParishColors.marianBlueSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ParishColors.marianBlue, width: 2),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.nfc, size: 50, color: ParishColors.marianBlue),
                SizedBox(height: 8),
                Text('Scan Property QR or Wave NFC Tag', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text('Hold device within 4 cm of asset label.', style: TextStyle(fontSize: 12, color: ParishColors.textMuted)),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: ParishColors.marianBlue, foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Simulate Scan Result'),
        ),
      ],
    ),
  );
}

// 10. Sensor Diagnostics Modal (Module 3)
void _showSensorDetailModal(
    BuildContext context, {
      required String roomTitle,
      required String nodeId,
      required String temperature,
      required String humidity,
      required bool isWarning,
    }) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(roomTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Node ID: $nodeId', style: const TextStyle(color: ParishColors.textMuted, fontSize: 13)),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('Temperature: $temperature', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(width: 14),
              Text('Humidity: $humidity', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isWarning ? ParishColors.mercyRedSurface : ParishColors.oliveGreenSurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              isWarning
                  ? 'CRITICAL ALERT: Safe relative humidity exceeded (Threshold: 60%). Inspect room dehumidifier immediately.'
                  : 'STATUS OPTIMAL: Environmental conditions are within safe paper preservation ranges.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isWarning ? ParishColors.mercyRed : ParishColors.oliveGreen,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
      ],
    ),
  );
}

// 11. Asset Item Detail Modal (Module 5)
void _showAssetDetailModal(
    BuildContext context, {
      required String controlNo,
      required String itemName,
      required String location,
      required String condition,
    }) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(itemName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Diocese Control No: $controlNo', style: const TextStyle(color: ParishColors.marianBlue, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          Text('Location: $location', style: const TextStyle(fontSize: 14)),
          Text('Current Condition: $condition', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: ParishColors.marianBlue, foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Update Status'),
        ),
      ],
    ),
  );
}

// Helper Widget for Clean TextFields Inside Modals
Widget _buildDialogTextField({required String label, required String hint, bool enabled = true}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: ParishColors.backgroundLight,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    ),
  );
}