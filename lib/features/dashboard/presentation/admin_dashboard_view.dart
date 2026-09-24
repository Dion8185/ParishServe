import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../auth/models/user_model.dart';
import '../../auth/services/admin_user_service.dart';

class AdminDashboardView extends StatefulWidget {
  final UserModel currentUser;
  final Function(int targetTabIndex) onNavigateTab;

  const AdminDashboardView({
    super.key,
    required this.currentUser,
    required this.onNavigateTab,
  });

  @override
  State<AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<AdminDashboardView> {
  bool _isLoading = true;
  List<UserModel> _users = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await AdminUserService.getAllUsers();
      if (!mounted) return;
      setState(() {
        _users = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  // Live Metrics Computation
  int get totalAccounts => _users.length;
  int get activeAccounts => _users.where((u) => u.accountStatus).length;
  int get deactivatedAccounts => _users.where((u) => !u.accountStatus).length;
  int get parishionerCount => _users.where((u) => u.userRole.toLowerCase() == 'user').length;
  int get staffCount => _users.where((u) {
    final r = u.userRole.toLowerCase();
    return r == 'secretary' || r == 'encoder' || r == 'parishpriest' || r == 'pfc';
  }).length;
  int get adminCount => _users.where((u) {
    final r = u.userRole.toLowerCase();
    return r == 'admin' || r == 'superadmin';
  }).length;

  @override
  Widget build(BuildContext context) {
    final bool isSuperAdmin = widget.currentUser.userRole.toLowerCase() == 'superadmin';

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth >= 900;

        return RefreshIndicator(
          onRefresh: _loadStatistics,
          color: ParishColors.marianBlue,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(isDesktop ? 32 : 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderBanner(isDesktop, isSuperAdmin),
                const SizedBox(height: 24),

                if (_isLoading)
                  const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
                else if (_errorMessage != null)
                  _buildErrorBanner()
                else ...[
                    // Dynamic KPI Metric Cards (Multi-column on desktop, 2x2 grid on mobile)
                    isDesktop ? _buildDesktopKpiRow() : _buildMobileKpiGrid(),
                    const SizedBox(height: 28),

                    // Content Sections
                    if (isDesktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 7, child: _buildRoleDistributionSection(isDesktop: true)),
                          const SizedBox(width: 24),
                          Expanded(flex: 5, child: _buildSystemOverviewSidebar(isSuperAdmin)),
                        ],
                      )
                    else
                      Column(
                        children: [
                          _buildRoleDistributionSection(isDesktop: false),
                          const SizedBox(height: 20),
                          _buildSystemOverviewSidebar(isSuperAdmin),
                        ],
                      ),
                  ],
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Top Administrative Banner
  // ---------------------------------------------------------------------------
  Widget _buildHeaderBanner(bool isDesktop, bool isSuperAdmin) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isDesktop ? 28 : 20),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ParishColors.borderGrey),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSuperAdmin ? ParishColors.goldLight : ParishColors.marianBlueSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSuperAdmin ? ParishColors.goldAccent : ParishColors.marianBlue,
                width: 1.5,
              ),
            ),
            child: Icon(
              isSuperAdmin ? Icons.workspace_premium : Icons.security,
              color: isSuperAdmin ? ParishColors.goldAccent : ParishColors.marianBlue,
              size: 32,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Welcome, ${widget.currentUser.firstName}',
                      style: TextStyle(
                        fontSize: isDesktop ? 22 : 18,
                        fontWeight: FontWeight.bold,
                        color: ParishColors.textDark,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: isSuperAdmin ? ParishColors.goldLight : ParishColors.marianBlueSurface,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isSuperAdmin ? 'SUPERADMIN' : 'SYSTEM ADMIN',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isSuperAdmin ? ParishColors.goldAccent : ParishColors.marianBlue,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isSuperAdmin
                      ? 'Global Overseer: Managing all operational staff, administrators, and multi-parish infrastructure.'
                      : 'Parish Administrator: Managing staff access, user accounts, and infrastructure health.',
                  style: TextStyle(fontSize: 12.5, color: ParishColors.textMuted, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // KPI Metrics (Desktop: 4 Cards in Row, Mobile: 2x2 Grid)
  // ---------------------------------------------------------------------------
  Widget _buildDesktopKpiRow() {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            title: 'Total Accounts',
            value: '$totalAccounts',
            subtitle: '$activeAccounts Active in System',
            icon: Icons.people_alt_outlined,
            color: ParishColors.marianBlue,
            onTap: () => widget.onNavigateTab(1),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMetricCard(
            title: 'Parishioner Clients',
            value: '$parishionerCount',
            subtitle: 'Online self-service portal',
            icon: Icons.person_outline,
            color: ParishColors.oliveGreen,
            onTap: () => widget.onNavigateTab(1),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMetricCard(
            title: 'Operational Staff',
            value: '$staffCount',
            subtitle: 'Priests, Secretaries, Encoders, PFC',
            icon: Icons.church_outlined,
            color: ParishColors.goldAccent,
            onTap: () => widget.onNavigateTab(1),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMetricCard(
            title: 'Security Posture',
            value: deactivatedAccounts == 0 ? '100%' : '$deactivatedAccounts Locked',
            subtitle: deactivatedAccounts == 0 ? 'All accounts verified & clean' : 'Deactivated accounts on file',
            icon: Icons.verified_user_outlined,
            color: deactivatedAccounts == 0 ? ParishColors.oliveGreen : ParishColors.mercyRed,
            onTap: () => widget.onNavigateTab(1),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileKpiGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        _buildMetricCard(
          title: 'Total Accounts',
          value: '$totalAccounts',
          subtitle: '$activeAccounts Active',
          icon: Icons.people_alt_outlined,
          color: ParishColors.marianBlue,
          onTap: () => widget.onNavigateTab(1),
        ),
        _buildMetricCard(
          title: 'Parishioners',
          value: '$parishionerCount',
          subtitle: 'Active portal users',
          icon: Icons.person_outline,
          color: ParishColors.oliveGreen,
          onTap: () => widget.onNavigateTab(1),
        ),
        _buildMetricCard(
          title: 'Staff Members',
          value: '$staffCount',
          subtitle: 'Secretaries & Clergy',
          icon: Icons.church_outlined,
          color: ParishColors.goldAccent,
          onTap: () => widget.onNavigateTab(1),
        ),
        _buildMetricCard(
          title: 'Security',
          value: deactivatedAccounts == 0 ? 'Optimal' : '$deactivatedAccounts Locked',
          subtitle: 'RA 10173 Compliance',
          icon: Icons.verified_user_outlined,
          color: deactivatedAccounts == 0 ? ParishColors.oliveGreen : ParishColors.mercyRed,
          onTap: () => widget.onNavigateTab(1),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ParishColors.cardWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ParishColors.borderGrey),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ParishColors.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Icon(icon, color: color, size: 20),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: ParishColors.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Account Distribution by Canonical Role
  // ---------------------------------------------------------------------------
  Widget _buildRoleDistributionSection({required bool isDesktop}) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ParishColors.borderGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Account Distribution by Canonical Role',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ParishColors.textDark),
              ),
              TextButton.icon(
                onPressed: () => widget.onNavigateTab(1),
                icon: const Icon(Icons.manage_accounts, size: 16),
                label: const Text('Manage Accounts', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildRoleProgressRow('Parishioners / Faithful (Clients)', parishionerCount, totalAccounts, ParishColors.marianBlue),
          const SizedBox(height: 14),
          _buildRoleProgressRow('Parish Secretaries (Operations)', _users.where((u) => u.userRole.toLowerCase() == 'secretary').length, totalAccounts, ParishColors.goldAccent),
          const SizedBox(height: 14),
          _buildRoleProgressRow('Records Encoders (Canonical Archiving)', _users.where((u) => u.userRole.toLowerCase() == 'encoder').length, totalAccounts, const Color(0xFF7C3AED)),
          const SizedBox(height: 14),
          _buildRoleProgressRow('Parish Priest & Parochial Vicars', _users.where((u) => u.userRole.toLowerCase() == 'parishpriest').length, totalAccounts, ParishColors.mercyRed),
          const SizedBox(height: 14),
          _buildRoleProgressRow('Parish Finance Council (PFC Auditors)', _users.where((u) => u.userRole.toLowerCase() == 'pfc').length, totalAccounts, ParishColors.oliveGreen),
          const SizedBox(height: 14),
          _buildRoleProgressRow('System Administrators & Superadmins', adminCount, totalAccounts, const Color(0xFF0F172A)),
        ],
      ),
    );
  }

  Widget _buildRoleProgressRow(String roleLabel, int count, int total, Color color) {
    final double ratio = total > 0 ? (count / total) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(roleLabel, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ParishColors.textDark)),
            Text('$count accounts (${(ratio * 100).toStringAsFixed(0)}%)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            backgroundColor: ParishColors.borderGrey.withOpacity(0.3),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // System Overview & Canonical Isolation Sidebar
  // ---------------------------------------------------------------------------
  Widget _buildSystemOverviewSidebar(bool isSuperAdmin) {
    return Column(
      children: [
        // Quick Action Shortcuts Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: ParishColors.cardWhite,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: ParishColors.borderGrey),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Administrative Actions', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ParishColors.marianBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => widget.onNavigateTab(1),
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('Provision New Account', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: ParishColors.borderGrey),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => widget.onNavigateTab(2),
                  icon: const Icon(Icons.dns_outlined, size: 18, color: ParishColors.marianBlue),
                  label: Text('Inspect Server Infrastructure', style: TextStyle(color: ParishColors.textDark, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Canonical Security Guard Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: ParishColors.backgroundLight,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: ParishColors.borderGrey),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.shield_outlined, color: ParishColors.oliveGreen, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Data Isolation Active', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
                    const SizedBox(height: 4),
                    Text(
                      'Canon 535 & RA 10173 policy in effect: Administrative accounts are strictly quarantined from sacramental records and cashiering books.',
                      style: TextStyle(fontSize: 11.5, color: ParishColors.textMuted, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ParishColors.mercyRedSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ParishColors.mercyRed),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: ParishColors.mercyRed),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Failed to load system metrics: $_errorMessage', style: const TextStyle(color: ParishColors.mercyRed, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}