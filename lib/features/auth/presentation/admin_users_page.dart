import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/colors.dart';
import '../models/user_model.dart';
import '../services/admin_user_service.dart';
import '../services/auth_service.dart';
import 'admin_archived_users_page.dart';

// =============================================================================
// Canonical & SJP2 Role Theme Color Helper (WCAG AAA Contrast Compliant)
// =============================================================================
class RoleThemeHelper {
  final Color primary;
  final Color background;
  final Color text;
  final Color border;

  const RoleThemeHelper({
    required this.primary,
    required this.background,
    required this.text,
    required this.border,
  });

  static RoleThemeHelper getTheme(String role) {
    switch (role.toLowerCase()) {
      case 'superadmin':
        return const RoleThemeHelper(
          primary: Color(0xFF0F172A), // Pure Black
          background: Color(0xFF0F172A), // Solid Black Badge
          text: Colors.white,
          border: Color(0xFF0F172A),
        );
      case 'admin':
        return const RoleThemeHelper(
          primary: Color(0xFF475569), // Neutral Gray
          background: Color(0xFFF1F5F9), // Light Gray Surface
          text: Color(0xFF334155), // High-Contrast Charcoal Gray
          border: Color(0xFF94A3B8),
        );
      case 'parishpriest':
        return const RoleThemeHelper(
          primary: Color(0xFFB91C1C), // Divine Mercy / Apostolic Crimson
          background: Color(0xFFFEF2F2),
          text: Color(0xFF991B1B), // Deep Crimson Text
          border: Color(0xFFF87171),
        );
      case 'secretary':
        return const RoleThemeHelper(
          primary: Color(0xFFD49B18), // SJP2 Papal Gold
          background: Color(0xFFFFFBEB),
          text: Color(0xFF92400E), // High-Contrast Deep Amber/Gold
          border: Color(0xFFFBBF24),
        );
      case 'encoder':
        return const RoleThemeHelper(
          primary: Color(0xFF7C3AED), // Canonical Scribe Violet / Liturgical Purple
          background: Color(0xFFF5F3FF),
          text: Color(0xFF5B21B6), // Deep Violet Text
          border: Color(0xFFA78BFA),
        );
      case 'pfc':
        return const RoleThemeHelper(
          primary: Color(0xFF2D6A4F), // Temporal Stewardship Olive Green
          background: Color(0xFFF0FDF4),
          text: Color(0xFF166534), // Deep Forest Green Text
          border: Color(0xFF4ADE80),
        );
      case 'user':
      default:
        return const RoleThemeHelper(
          primary: Color(0xFF164E87), // Marian Blue (SJP2 Core Patronal Color)
          background: Color(0xFFEFF6FF),
          text: Color(0xFF1E40AF), // Deep Marian Navy Text
          border: Color(0xFF60A5FA),
        );
    }
  }
}

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  List<UserModel> _allUsers = const [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  String _selectedRoleFilter = 'All Roles';

  // Sorting & Pagination State
  String _sortBy = 'Full Name';
  bool _sortAscending = true;
  int _currentPage = 0;
  int _rowsPerPage = 10;

  final List<String> _sortOptions = ['Full Name', 'ID', 'Assigned Role', 'Username'];

  List<String> get _roleFilterOptions {
    final callerRole = AuthService.currentUser?.userRole.toLowerCase() ?? '';
    final isSuperAdmin = callerRole == 'superadmin';

    return [
      'All Roles',
      'Parishioners',
      'Secretaries',
      'Encoders',
      'Priests',
      'PFC Auditors',
      if (isSuperAdmin) 'Admins',
      if (isSuperAdmin) 'Superadmins',
    ];
  }

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final users = await AdminUserService.getAllUsers();
      if (!mounted) return;
      setState(() {
        _allUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _allUsers = const [];
        _isLoading = false;
      });
    }
  }

  int get _archivedCount {
    if (_allUsers.isEmpty) return 0;
    return _allUsers.where((u) => !u.accountStatus).length;
  }

  void _openUserModal({UserModel? userToEdit}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _UserFormDialog(
        userToEdit: userToEdit,
        onSaved: _loadUsers,
      ),
    );
  }

  Future<void> _confirmArchiveUser(UserModel user) async {
    final currentUserId = AuthService.currentUser?.userId;

    if (user.userId == currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Action Denied: You cannot archive your own active account.'),
          backgroundColor: ParishColors.mercyRed,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.archive_outlined, color: ParishColors.mercyRed, size: 26),
            SizedBox(width: 10),
            Text('Archive Account?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(
          'Are you sure you want to archive "${user.fullName}" (${user.userId})? '
              'This account will be moved to the Archive quarantine and will be blocked from logging into ParishServe.',
          style: TextStyle(fontSize: 13.5, color: ParishColors.textDark, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: ParishColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ParishColors.mercyRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Move to Archive'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await AdminUserService.setAccountStatus(user.userId, false);
      _loadUsers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Account "${user.fullName}" moved to the Archive.'),
          backgroundColor: ParishColors.mercyRed,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Archive action failed: $e'), backgroundColor: ParishColors.mercyRed),
      );
    }
  }

  List<UserModel> get _processedActiveUsers {
    if (_allUsers.isEmpty) return const [];

    var list = _allUsers.where((u) => u.accountStatus).toList();

    if (_selectedRoleFilter == 'Parishioners') {
      list = list.where((u) => u.userRole.toLowerCase() == 'user').toList();
    } else if (_selectedRoleFilter == 'Secretaries') {
      list = list.where((u) => u.userRole.toLowerCase() == 'secretary').toList();
    } else if (_selectedRoleFilter == 'Encoders') {
      list = list.where((u) => u.userRole.toLowerCase() == 'encoder').toList();
    } else if (_selectedRoleFilter == 'Priests') {
      list = list.where((u) => u.userRole.toLowerCase() == 'parishpriest').toList();
    } else if (_selectedRoleFilter == 'PFC Auditors') {
      list = list.where((u) => u.userRole.toLowerCase() == 'pfc').toList();
    } else if (_selectedRoleFilter == 'Admins') {
      list = list.where((u) => u.userRole.toLowerCase() == 'admin').toList();
    } else if (_selectedRoleFilter == 'Superadmins') {
      list = list.where((u) => u.userRole.toLowerCase() == 'superadmin').toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      list = list.where((u) {
        return u.fullName.toLowerCase().contains(q) ||
            u.username.toLowerCase().contains(q) ||
            u.email.toLowerCase().contains(q) ||
            u.userId.toLowerCase().contains(q) ||
            u.userRole.toLowerCase().contains(q);
      }).toList();
    }

    list.sort((a, b) {
      int comparison;
      switch (_sortBy) {
        case 'ID':
          comparison = a.userId.compareTo(b.userId);
          break;
        case 'Assigned Role':
          comparison = a.roleDisplay.compareTo(b.roleDisplay);
          break;
        case 'Username':
          comparison = a.username.compareTo(b.username);
          break;
        case 'Full Name':
        default:
          comparison = a.fullName.compareTo(b.fullName);
      }
      return _sortAscending ? comparison : -comparison;
    });

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final callerRole = AuthService.currentUser?.userRole.toLowerCase() ?? '';
    final isSuperAdmin = callerRole == 'superadmin';

    final processed = _processedActiveUsers;
    final totalCount = processed.length;
    final totalPages = max(1, (totalCount / _rowsPerPage).ceil());
    if (_currentPage >= totalPages) _currentPage = totalPages - 1;

    final startIndex = _currentPage * _rowsPerPage;
    final endIndex = min(startIndex + _rowsPerPage, totalCount);
    final pagedUsers = (startIndex >= totalCount) ? <UserModel>[] : processed.sublist(startIndex, endIndex);

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth >= 900;

        return Scaffold(
          backgroundColor: ParishColors.backgroundLight,
          body: Padding(
            padding: EdgeInsets.all(isDesktop ? 32 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(isDesktop, isSuperAdmin),
                const SizedBox(height: 18),
                _buildControlsBar(isDesktop),
                const SizedBox(height: 18),

                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                      ? Center(child: Text('Error: $_error', style: const TextStyle(color: ParishColors.mercyRed)))
                      : pagedUsers.isEmpty
                      ? Center(
                    child: Text(
                      'No active accounts match your search or role filter.',
                      style: TextStyle(color: ParishColors.textMuted, fontSize: 14),
                    ),
                  )
                      : isDesktop
                      ? _buildDesktopDataTable(pagedUsers)
                      : _buildMobileCardList(pagedUsers),
                ),
                const SizedBox(height: 14),

                if (totalCount > 0 && !_isLoading)
                  _buildPaginationToolbar(totalCount, totalPages, startIndex, endIndex),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isDesktop, bool isSuperAdmin) {
    if (isDesktop) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'User & Access Governance',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                ),
                Text(
                  isSuperAdmin
                      ? 'Active accounts directory: Parish staff, clients, and administrators'
                      : 'Active accounts directory: Parish operations staff and parishioners',
                  style: TextStyle(fontSize: 12.5, color: ParishColors.textMuted),
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.refresh, color: ParishColors.marianBlue),
                onPressed: _loadUsers,
                tooltip: 'Refresh Records',
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: ParishColors.mercyRed, width: 1.5),
                  foregroundColor: ParishColors.mercyRed,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminArchivedUsersPage()),
                  );
                  _loadUsers();
                },
                icon: const Icon(Icons.archive_outlined, size: 18),
                label: Text('Archive ($_archivedCount)', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ParishColors.marianBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _openUserModal(),
                icon: const Icon(Icons.person_add, size: 18),
                label: const Text('Provision User', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'User Governance',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: ParishColors.textDark),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: ParishColors.marianBlue),
              onPressed: _loadUsers,
              tooltip: 'Refresh Records',
            ),
          ],
        ),
        Text(
          'Active directory of parish accounts',
          style: TextStyle(fontSize: 12, color: ParishColors.textMuted),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: ParishColors.mercyRed, width: 1.5),
                  foregroundColor: ParishColors.mercyRed,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminArchivedUsersPage()),
                  );
                  _loadUsers();
                },
                icon: const Icon(Icons.archive_outlined, size: 16),
                label: Text('Archive ($_archivedCount)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ParishColors.marianBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _openUserModal(),
                icon: const Icon(Icons.person_add, size: 16),
                label: const Text('New User', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildControlsBar(bool isDesktop) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ParishColors.borderGrey),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.search, size: 20, color: ParishColors.marianBlue),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  onChanged: (val) => setState(() {
                    _searchQuery = val;
                    _currentPage = 0;
                  }),
                  style: TextStyle(fontSize: 13.5, color: ParishColors.textDark),
                  decoration: InputDecoration(
                    hintText: 'Search active accounts by name, username, email, ID...',
                    hintStyle: TextStyle(fontSize: 13, color: ParishColors.textMuted),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              if (_searchQuery.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear, size: 16),
                  onPressed: () => setState(() => _searchQuery = ''),
                ),
            ],
          ),
          const Divider(height: 18),

          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              // Role Filter Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: ParishColors.backgroundLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ParishColors.borderGrey),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.filter_alt_outlined, size: 16, color: ParishColors.marianBlue),
                    const SizedBox(width: 6),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedRoleFilter,
                        isDense: true,
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                        items: _roleFilterOptions.map((role) {
                          return DropdownMenuItem(value: role, child: Text(role));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedRoleFilter = val;
                              _currentPage = 0;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Sorting Controls
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: ParishColors.backgroundLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ParishColors.borderGrey),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.sort, size: 16, color: ParishColors.marianBlue),
                    const SizedBox(width: 6),
                    Text('Sort: ', style: TextStyle(fontSize: 12, color: ParishColors.textMuted, fontWeight: FontWeight.bold)),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _sortBy,
                        isDense: true,
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                        items: _sortOptions.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _sortBy = val);
                        },
                      ),
                    ),
                    IconButton(
                      icon: Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward, size: 16, color: ParishColors.marianBlue),
                      tooltip: _sortAscending ? 'Ascending' : 'Descending',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => setState(() => _sortAscending = !_sortAscending),
                    ),
                  ],
                ),
              ),

              // Rows Per Page
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: ParishColors.backgroundLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ParishColors.borderGrey),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Rows: ', style: TextStyle(fontSize: 12, color: ParishColors.textMuted, fontWeight: FontWeight.w600)),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _rowsPerPage,
                        isDense: true,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ParishColors.marianBlue),
                        items: const [
                          DropdownMenuItem(value: 5, child: Text('5')),
                          DropdownMenuItem(value: 10, child: Text('10')),
                          DropdownMenuItem(value: 25, child: Text('25')),
                          DropdownMenuItem(value: 50, child: Text('50')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _rowsPerPage = val;
                              _currentPage = 0;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Desktop View: Responsive Flex Table (100% Width & Always-Visible Actions)
  // ---------------------------------------------------------------------------
  Widget _buildDesktopDataTable(List<UserModel> users) {
    final currentUserId = AuthService.currentUser?.userId;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: ParishColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ParishColors.borderGrey),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          child: Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            columnWidths: const {
              0: FixedColumnWidth(115), // ID
              1: FlexColumnWidth(2.3),  // Full Name
              2: FlexColumnWidth(2.7),  // Username / Email
              3: FlexColumnWidth(2.6),  // Assigned Role
              4: FixedColumnWidth(100), // Actions (Always visible & docked on right!)
            },
            children: [
              // Header Row
              TableRow(
                decoration: BoxDecoration(color: ParishColors.marianBlueSurface),
                children: [
                  _buildHeaderCell('ID'),
                  _buildHeaderCell('Full Name'),
                  _buildHeaderCell('Username / Email'),
                  _buildHeaderCell('Assigned Role'),
                  _buildHeaderCell('Actions', align: TextAlign.center),
                ],
              ),
              // Data Rows
              ...users.map((user) {
                final isSelf = user.userId == currentUserId;
                final roleTheme = RoleThemeHelper.getTheme(user.userRole);

                return TableRow(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: ParishColors.borderGrey.withOpacity(0.4)),
                    ),
                  ),
                  children: [
                    // ID Badge
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: roleTheme.background,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: roleTheme.border, width: 1.2),
                          ),
                          child: Text(
                            user.userId,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: roleTheme.text,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Full Name
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: roleTheme.background,
                            child: Text(
                              user.firstName.isNotEmpty ? user.firstName[0].toUpperCase() : 'U',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: roleTheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    user.fullName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isSelf) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: ParishColors.marianBlueSurface,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'YOU',
                                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: ParishColors.marianBlue),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Username / Email
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            user.username,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            user.email,
                            style: TextStyle(fontSize: 11.5, color: ParishColors.textMuted),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // Assigned Role
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: roleTheme.background,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: roleTheme.border, width: 1.2),
                          ),
                          child: Text(
                            user.roleDisplay,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: roleTheme.text,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),

                    // Actions (Always visible on desktop!)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18, color: ParishColors.marianBlue),
                            tooltip: 'Edit Credentials',
                            onPressed: () => _openUserModal(userToEdit: user),
                          ),
                          IconButton(
                            icon: const Icon(Icons.archive_outlined, size: 18, color: ParishColors.mercyRed),
                            tooltip: isSelf ? 'Cannot archive self' : 'Archive Account',
                            onPressed: isSelf ? null : () => _confirmArchiveUser(user),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String label, {TextAlign align = TextAlign.left}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: Text(
        label,
        textAlign: align,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF1E293B)),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Mobile View: Cards with Color-Coded Badges
  // ---------------------------------------------------------------------------
  Widget _buildMobileCardList(List<UserModel> users) {
    final currentUserId = AuthService.currentUser?.userId;

    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final isSelf = user.userId == currentUserId;
        final roleTheme = RoleThemeHelper.getTheme(user.userRole);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ParishColors.cardWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelf ? ParishColors.marianBlue : ParishColors.borderGrey,
              width: isSelf ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: roleTheme.background,
                    child: Text(
                      user.firstName.isNotEmpty ? user.firstName[0].toUpperCase() : 'U',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: roleTheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                user.fullName,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isSelf) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(color: ParishColors.marianBlueSurface, borderRadius: BorderRadius.circular(4)),
                                child: const Text('YOU', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: ParishColors.marianBlue)),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          '${user.username} • ${user.email}',
                          style: TextStyle(fontSize: 12, color: ParishColors.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: roleTheme.background,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: roleTheme.border, width: 1.2),
                    ),
                    child: Text(
                      user.userId,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: roleTheme.text),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: roleTheme.background,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: roleTheme.border, width: 1.2),
                      ),
                      child: Text(
                        user.roleDisplay,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: roleTheme.text),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20, color: ParishColors.marianBlue),
                        onPressed: () => _openUserModal(userToEdit: user),
                        tooltip: 'Edit User',
                      ),
                      IconButton(
                        icon: const Icon(Icons.archive_outlined, size: 20, color: ParishColors.mercyRed),
                        onPressed: isSelf ? null : () => _confirmArchiveUser(user),
                        tooltip: 'Archive Account',
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPaginationToolbar(int totalItems, int totalPages, int startIndex, int endIndex) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isNarrow = constraints.maxWidth < 460;

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            color: ParishColors.cardWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ParishColors.borderGrey),
          ),
          child: isNarrow
              ? Column(
            children: [
              Text(
                'Showing ${startIndex + 1}–$endIndex of $totalItems active',
                style: TextStyle(fontSize: 12, color: ParishColors.textMuted),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.first_page, size: 20),
                    onPressed: _currentPage > 0 ? () => setState(() => _currentPage = 0) : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 20),
                    onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: ParishColors.marianBlueSurface, borderRadius: BorderRadius.circular(6)),
                    child: Text(
                      '${_currentPage + 1} / $totalPages',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: ParishColors.marianBlue),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 20),
                    onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.last_page, size: 20),
                    onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage = totalPages - 1) : null,
                  ),
                ],
              ),
            ],
          )
              : Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing ${startIndex + 1}–$endIndex of $totalItems active',
                style: TextStyle(fontSize: 12, color: ParishColors.textMuted),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.first_page, size: 20),
                    onPressed: _currentPage > 0 ? () => setState(() => _currentPage = 0) : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 20),
                    onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: ParishColors.marianBlueSurface, borderRadius: BorderRadius.circular(6)),
                    child: Text(
                      '${_currentPage + 1} / $totalPages',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: ParishColors.marianBlue),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 20),
                    onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.last_page, size: 20),
                    onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage = totalPages - 1) : null,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// =============================================================================
// User CRUD Modal Dialog (ParishServe-Themed)
// =============================================================================

class _UserFormDialog extends StatefulWidget {
  final UserModel? userToEdit;
  final VoidCallback onSaved;

  const _UserFormDialog({this.userToEdit, required this.onSaved});

  @override
  State<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<_UserFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;

  final _firstNameFocus = FocusNode();
  final _lastNameFocus = FocusNode();
  final _usernameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _firstNameBlurred = false;
  bool _lastNameBlurred = false;
  bool _usernameBlurred = false;
  bool _emailBlurred = false;
  bool _passwordBlurred = false;

  bool _obscurePassword = true;
  String _selectedRole = 'secretary';
  bool _isSaving = false;
  bool _hasAttemptedSubmit = false;
  String? _formError;

  bool get isEditMode => widget.userToEdit != null;

  static const List<String> _keyboardWalks = [
    'asdf', 'sdfg', 'dfgh', 'fghj', 'ghjk', 'hjkl',
    'qwer', 'wert', 'erty', 'rtyu', 'tyui', 'yuio', 'uiop',
    'zxcv', 'xcvb', 'cvbn', 'vbnm',
    'fdsa', 'gfds', 'hgfd', 'jhgf', 'kjhg', 'lkjh',
    'rewq', 'trew', 'ytre', 'uytr', 'iuyt', 'poiuy',
  ];

  @override
  void initState() {
    super.initState();
    final u = widget.userToEdit;
    _firstNameController = TextEditingController(text: u?.firstName ?? '');
    _lastNameController = TextEditingController(text: u?.lastName ?? '');
    _usernameController = TextEditingController(text: u?.username ?? '');
    _emailController = TextEditingController(text: u?.email ?? '');
    _passwordController = TextEditingController(text: u != null ? '••••••••' : '');

    if (u != null) {
      _selectedRole = u.userRole.toLowerCase();
    }

    _firstNameFocus.addListener(() {
      if (!_firstNameFocus.hasFocus) setState(() => _firstNameBlurred = true);
    });
    _lastNameFocus.addListener(() {
      if (!_lastNameFocus.hasFocus) setState(() => _lastNameBlurred = true);
    });
    _usernameFocus.addListener(() {
      if (!_usernameFocus.hasFocus) setState(() => _usernameBlurred = true);
    });
    _emailFocus.addListener(() {
      if (!_emailFocus.hasFocus) setState(() => _emailBlurred = true);
    });
    _passwordFocus.addListener(() {
      if (!_passwordFocus.hasFocus) setState(() => _passwordBlurred = true);
    });

    _passwordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _firstNameFocus.dispose();
    _lastNameFocus.dispose();
    _usernameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();

    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateName(String? value, String fieldLabel) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldLabel is required.';
    }
    if (value.startsWith(' ')) {
      return '$fieldLabel cannot start with a space.';
    }
    if (value.endsWith(' ') && _hasAttemptedSubmit) {
      return '$fieldLabel cannot end with a space.';
    }
    if (value.contains(RegExp(r'\s{2,}'))) {
      return '$fieldLabel cannot contain consecutive spaces.';
    }

    final trimmed = value.trim();
    if (trimmed.length < 2) {
      return '$fieldLabel must be at least 2 characters.';
    }
    if (trimmed.length > 50) {
      return '$fieldLabel cannot exceed 50 characters.';
    }

    final nameRegex = RegExp(r"^[a-zA-ZÀ-ÿ\u0100-\u024FÑñ\s.\-’']+$");
    if (!nameRegex.hasMatch(trimmed)) {
      return '$fieldLabel contains invalid characters.';
    }

    final lower = trimmed.toLowerCase();

    if (RegExp(r'(.)\1{2,}', caseSensitive: false).hasMatch(trimmed)) {
      return '$fieldLabel cannot contain 3 or more of the same letter in a row.';
    }

    if (RegExp(r'(.{2,4})\1{2,}', caseSensitive: false).hasMatch(lower)) {
      return 'Please enter a valid $fieldLabel (repetitive pattern detected).';
    }

    for (final walk in _keyboardWalks) {
      if (lower.contains(walk)) {
        return '$fieldLabel cannot be a keyboard sequence (e.g. "$walk").';
      }
    }

    final onlyLetters = lower.replaceAll(RegExp(r'[^a-zà-ÿñ]'), '');
    if (onlyLetters.length >= 3) {
      final hasVowel = RegExp(r'[aeiouyà-ÿ]').hasMatch(onlyLetters);
      if (!hasVowel) {
        return '$fieldLabel must contain at least one vowel.';
      }

      if (RegExp(r'[bcdfghjklmnpqrstvwxz]{5,}').hasMatch(onlyLetters)) {
        return '$fieldLabel contains too many consecutive consonants.';
      }
    }

    return null;
  }

  String? _validateUsername(String? value) {
    if (value == null || value.isEmpty) {
      return 'Username is required.';
    }
    if (value.contains(' ')) {
      return 'Username cannot contain spaces.';
    }
    final trimmed = value.trim();
    if (trimmed.length < 3) {
      return 'Username must be at least 3 characters.';
    }
    if (trimmed.length > 30) {
      return 'Username cannot exceed 30 characters.';
    }

    if (RegExp(r'(.{2,})\1{2,}', caseSensitive: false).hasMatch(trimmed)) {
      return 'Username contains an invalid repetitive pattern.';
    }

    final usernameRegex = RegExp(r'^[a-zA-Z0-9_\-]+$');
    if (!usernameRegex.hasMatch(trimmed)) {
      return 'Only letters, numbers, underscores (_), and hyphens (-) are allowed.';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email address is required.';
    }
    if (value.contains(' ')) {
      return 'Email address cannot contain spaces.';
    }
    final trimmed = value.trim();
    if (trimmed.length > 254) {
      return 'Email address cannot exceed 254 characters.';
    }

    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(trimmed)) {
      return 'Please enter a valid email address (e.g. name@domain.com).';
    }
    return null;
  }

  bool _containsPredictablePatterns(String password) {
    final lower = password.toLowerCase();
    const commonSequences = [
      '123', '234', '345', '456', '567', '678', '789',
      'abc', 'bcd', 'cde', 'def', 'qwe', 'wer', 'ert', 'rty',
      'asd', 'sdf', 'dfg', 'zxc', 'xcv',
      'password', 'admin', 'parish',
    ];
    for (final seq in commonSequences) {
      if (lower.contains(seq)) return true;
    }
    return false;
  }

  String? _validatePassword(String? value) {
    if (isEditMode) return null;

    if (value == null || value.isEmpty) {
      return 'Initial password is required.';
    }
    if (value.startsWith(' ') || value.endsWith(' ')) {
      return 'Password cannot begin or end with spaces.';
    }

    final nonSpaceCount = value.replaceAll(' ', '').length;
    if (nonSpaceCount < 8) {
      return 'Password must contain at least 8 non-space characters.';
    }
    if (value.length > 128) {
      return 'Password cannot exceed 128 characters.';
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Password must include at least one uppercase letter (A-Z).';
    }
    if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=\[\]\\/~`]').hasMatch(value)) {
      return 'Password must include at least one special character.';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Password must include at least one number (0-9).';
    }

    if (_containsPredictablePatterns(value)) {
      return 'Password is too predictable. Avoid sequences like 123, asd, or common words.';
    }

    return null;
  }

  bool get _hasMinRealLength => _passwordController.text.replaceAll(' ', '').length >= 8;
  bool get _hasNoOuterSpaces =>
      _passwordController.text.isNotEmpty &&
          !_passwordController.text.startsWith(' ') &&
          !_passwordController.text.endsWith(' ');
  bool get _hasUppercase => RegExp(r'[A-Z]').hasMatch(_passwordController.text);
  bool get _hasSpecialChar =>
      RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=\[\]\\/~`]').hasMatch(_passwordController.text);
  bool get _hasNumber => RegExp(r'[0-9]').hasMatch(_passwordController.text);
  bool get _isNotPredictable => !_containsPredictablePatterns(_passwordController.text);

  int get _strengthScore {
    final text = _passwordController.text;
    final nonSpaceLength = text.replaceAll(' ', '').length;
    if (nonSpaceLength == 0) return 0;

    int score = 0;
    if (_hasMinRealLength && _hasNoOuterSpaces) score++;
    if (_hasUppercase) score++;
    if (_hasSpecialChar) score++;
    if (_hasNumber) score++;

    if (_containsPredictablePatterns(text) || nonSpaceLength < 10) {
      if (score > 2) score = 2;
    }

    return score;
  }

  List<Map<String, String>> _getPermittedRoleOptions() {
    final callerRole = AuthService.currentUser?.userRole.toLowerCase() ?? '';
    final isSuperAdmin = callerRole == 'superadmin';

    final operationalRoles = [
      {'value': 'secretary', 'label': 'Parish Secretary (Sc)'},
      {'value': 'encoder', 'label': 'Records Encoder (E)'},
      {'value': 'parishpriest', 'label': 'Parish Priest (P)'},
      {'value': 'pfc', 'label': 'Parish Finance Council Auditor (PFC)'},
      {'value': 'user', 'label': 'Parishioner Client (U)'},
    ];

    if (isSuperAdmin) {
      return [
        {'value': 'superadmin', 'label': 'Super Administrator (S)'},
        {'value': 'admin', 'label': 'System Administrator (A)'},
        ...operationalRoles,
      ];
    }

    return operationalRoles;
  }

  Future<void> _save() async {
    setState(() {
      _hasAttemptedSubmit = true;
      _formError = null;
    });

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      if (!isEditMode) {
        await AdminUserService.createUser(
          username: _usernameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          userRole: _selectedRole,
        );
      } else {
        await AdminUserService.updateUser(
          userId: widget.userToEdit!.userId,
          username: _usernameController.text.trim(),
          email: _emailController.text.trim(),
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          userRole: _selectedRole,
          accountStatus: widget.userToEdit!.accountStatus,
        );
      }

      if (!mounted) return;
      Navigator.pop(context);
      widget.onSaved();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditMode ? 'User credentials updated.' : 'Account provisioned successfully.'),
          backgroundColor: ParishColors.oliveGreen,
        ),
      );
    } catch (e) {
      setState(() {
        _formError = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = _getPermittedRoleOptions();
    if (!options.any((o) => o['value'] == _selectedRole)) {
      _selectedRole = options.first['value']!;
    }

    final textDarkColor = ParishColors.textDark;
    final textMutedColor = ParishColors.textMuted;
    final borderGreyColor = ParishColors.borderGrey;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      backgroundColor: ParishColors.cardWhite,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: double.maxFinite,
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: BoxDecoration(
                color: ParishColors.marianBlueSurface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                border: Border(bottom: BorderSide(color: borderGreyColor)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isEditMode ? ParishColors.goldLight : ParishColors.marianBlue,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isEditMode ? ParishColors.goldAccent : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      isEditMode ? Icons.edit_note : Icons.person_add_alt_1,
                      color: isEditMode ? ParishColors.goldAccent : Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEditMode ? 'Edit User Credentials' : 'Provision Parish Account',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textDarkColor,
                          ),
                        ),
                        Text(
                          isEditMode
                              ? 'Modifying Account: ${widget.userToEdit!.userId}'
                              : 'St. John Paul II Parish Staff & Client Directory',
                          style: TextStyle(fontSize: 12, color: textMutedColor),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_formError != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: ParishColors.mercyRedSurface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: ParishColors.mercyRed),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: ParishColors.mercyRed, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _formError!,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: ParishColors.mercyRed,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('First Name *'),
                                TextFormField(
                                  controller: _firstNameController,
                                  focusNode: _firstNameFocus,
                                  keyboardType: TextInputType.name,
                                  textCapitalization: TextCapitalization.words,
                                  onChanged: (_) {
                                    if (_hasAttemptedSubmit || _firstNameBlurred) _formKey.currentState?.validate();
                                  },
                                  validator: (v) {
                                    if (!_hasAttemptedSubmit && !_firstNameBlurred) return null;
                                    return _validateName(v, 'First name');
                                  },
                                  style: TextStyle(fontSize: 14, color: textDarkColor),
                                  decoration: _inputDecoration(hint: 'e.g. Maria'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Last Name *'),
                                TextFormField(
                                  controller: _lastNameController,
                                  focusNode: _lastNameFocus,
                                  keyboardType: TextInputType.name,
                                  textCapitalization: TextCapitalization.words,
                                  onChanged: (_) {
                                    if (_hasAttemptedSubmit || _lastNameBlurred) _formKey.currentState?.validate();
                                  },
                                  validator: (v) {
                                    if (!_hasAttemptedSubmit && !_lastNameBlurred) return null;
                                    return _validateName(v, 'Last name');
                                  },
                                  style: TextStyle(fontSize: 14, color: textDarkColor),
                                  decoration: _inputDecoration(hint: 'e.g. Santos'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      _buildFieldLabel('Username *'),
                      TextFormField(
                        controller: _usernameController,
                        focusNode: _usernameFocus,
                        keyboardType: TextInputType.text,
                        inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
                        onChanged: (_) {
                          if (_hasAttemptedSubmit || _usernameBlurred) {
                            _formKey.currentState?.validate();
                          }
                        },
                        validator: (v) {
                          if (!_hasAttemptedSubmit && !_usernameBlurred) return null;
                          return _validateUsername(v);
                        },
                        style: TextStyle(fontSize: 14, color: textDarkColor),
                        decoration: _inputDecoration(
                          hint: 'e.g. secretary_01',
                          prefixIcon: const Icon(Icons.alternate_email, size: 18, color: ParishColors.marianBlue),
                        ),
                      ),
                      const SizedBox(height: 16),

                      _buildFieldLabel('Email Address *'),
                      TextFormField(
                        controller: _emailController,
                        focusNode: _emailFocus,
                        keyboardType: TextInputType.emailAddress,
                        inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
                        onChanged: (_) {
                          if (_hasAttemptedSubmit || _emailBlurred) {
                            _formKey.currentState?.validate();
                          }
                        },
                        validator: (v) {
                          if (!_hasAttemptedSubmit && !_emailBlurred) return null;
                          return _validateEmail(v);
                        },
                        style: TextStyle(fontSize: 14, color: textDarkColor),
                        decoration: _inputDecoration(
                          hint: 'name@sjp2parish.ph',
                          prefixIcon: const Icon(Icons.email_outlined, size: 18, color: ParishColors.marianBlue),
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (!isEditMode) ...[
                        _buildFieldLabel('Initial Password *'),
                        TextFormField(
                          controller: _passwordController,
                          focusNode: _passwordFocus,
                          obscureText: _obscurePassword,
                          keyboardType: TextInputType.visiblePassword,
                          onChanged: (_) {
                            if (_hasAttemptedSubmit || _passwordBlurred) {
                              _formKey.currentState?.validate();
                            }
                          },
                          validator: (v) {
                            if (!_hasAttemptedSubmit && !_passwordBlurred) return null;
                            return _validatePassword(v);
                          },
                          style: TextStyle(fontSize: 14, color: textDarkColor),
                          decoration: _inputDecoration(
                            hint: 'Min. 8 chars with uppercase & symbol',
                            prefixIcon: const Icon(Icons.lock_outline, size: 18, color: ParishColors.marianBlue),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                size: 20,
                                color: textMutedColor,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        _buildPasswordStrengthWidget(),
                        const SizedBox(height: 16),
                      ],

                      _buildFieldLabel('Assigned Canonical Role *'),
                      DropdownButtonFormField<String>(
                        value: _selectedRole,
                        items: options.map((r) {
                          return DropdownMenuItem(
                            value: r['value'],
                            child: Text(r['label']!, style: TextStyle(fontSize: 13.5, color: textDarkColor)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedRole = val);
                        },
                        decoration: _inputDecoration(
                          hint: 'Select role',
                          prefixIcon: const Icon(Icons.shield_outlined, size: 18, color: ParishColors.marianBlue),
                        ),
                      ),
                      const SizedBox(height: 18),

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: ParishColors.backgroundLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderGreyColor),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline, size: 18, color: ParishColors.marianBlue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                !isEditMode
                                    ? 'Automated Database Provisioning: User will be registered in auth.users with auto-confirmed email, ready to sign in immediately.'
                                    : 'Updating account credentials in public.users. Role permissions will adjust on next session renewal.',
                                style: TextStyle(fontSize: 11.5, color: textMutedColor, height: 1.35),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: ParishColors.cardWhite,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
                border: Border(top: BorderSide(color: borderGreyColor)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    child: Text('Cancel', style: TextStyle(fontSize: 14, color: textMutedColor, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 46,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ParishColors.marianBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                      ),
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.check, size: 18),
                      label: Text(
                        _isSaving ? 'Saving...' : (isEditMode ? 'Update Credentials' : 'Provision Account'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
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

  Widget _buildPasswordStrengthWidget() {
    final text = _passwordController.text;
    if (text.isEmpty) return const SizedBox.shrink();

    final score = _strengthScore;
    Color strengthColor = ParishColors.mercyRed;
    String strengthLabel = 'Weak';

    if (score == 2) {
      strengthColor = Colors.orange;
      strengthLabel = 'Fair';
    } else if (score == 3) {
      strengthColor = ParishColors.goldAccent;
      strengthLabel = 'Good';
    } else if (score >= 4) {
      strengthColor = ParishColors.oliveGreen;
      strengthLabel = 'Strong';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ParishColors.backgroundLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ParishColors.borderGrey.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Password Strength:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
              Text(strengthLabel, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: strengthColor)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (score / 4.0).clamp(0.2, 1.0),
              minHeight: 5,
              backgroundColor: ParishColors.borderGrey.withOpacity(0.3),
              valueColor: AlwaysStoppedAnimation<Color>(strengthColor),
            ),
          ),
          const SizedBox(height: 10),

          _buildChecklistItem('At least 8 non-space characters', _hasMinRealLength && _hasNoOuterSpaces),
          _buildChecklistItem('At least 1 uppercase letter (A-Z) (Required)', _hasUppercase),
          _buildChecklistItem('At least 1 special character (!@#\$...) (Required)', _hasSpecialChar),
          _buildChecklistItem('At least 1 number (0-9)', _hasNumber),
          _buildChecklistItem('No predictable patterns (123, asd, passwords)', _isNotPredictable),
        ],
      ),
    );
  }

  Widget _buildChecklistItem(String label, bool isSatisfied) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3.0),
      child: Row(
        children: [
          Icon(
            isSatisfied ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 14,
            color: isSatisfied ? ParishColors.oliveGreen : ParishColors.textMuted.withOpacity(0.6),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSatisfied ? FontWeight.bold : FontWeight.normal,
              color: isSatisfied ? ParishColors.textDark : ParishColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: ParishColors.textDark)),
    );
  }

  InputDecoration _inputDecoration({String hint = '', Widget? prefixIcon, Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint.isNotEmpty ? hint : null,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: ParishColors.backgroundLight,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ParishColors.borderGrey)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: ParishColors.borderGrey)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: ParishColors.marianBlue, width: 1.8)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: ParishColors.mercyRed, width: 1.2)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: ParishColors.mercyRed, width: 1.8)),
      errorStyle: const TextStyle(fontSize: 11.5, color: ParishColors.mercyRed, fontWeight: FontWeight.w500),
    );
  }
}