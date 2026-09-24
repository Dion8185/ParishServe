import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../models/user_model.dart';
import '../services/admin_user_service.dart';
import '../services/auth_service.dart';
import 'admin_users_page.dart'; // Shares RoleThemeHelper

class AdminArchivedUsersPage extends StatefulWidget {
  const AdminArchivedUsersPage({super.key});

  @override
  State<AdminArchivedUsersPage> createState() => _AdminArchivedUsersPageState();
}

class _AdminArchivedUsersPageState extends State<AdminArchivedUsersPage> {
  List<UserModel> _archivedUsers = const [];
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
    _loadArchivedUsers();
  }

  Future<void> _loadArchivedUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final allUsers = await AdminUserService.getAllUsers();
      if (!mounted) return;
      setState(() {
        _archivedUsers = allUsers.where((u) => !u.accountStatus).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _archivedUsers = const [];
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmRestore(UserModel user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.restore, color: ParishColors.oliveGreen, size: 26),
            SizedBox(width: 10),
            Text('Restore Account?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(
          'Are you sure you want to restore "${user.fullName}" (${user.userId}) back to the active parish directory? The user will immediately be able to sign in again.',
          style: TextStyle(fontSize: 13.5, color: ParishColors.textDark, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: ParishColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ParishColors.oliveGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore to Active'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await AdminUserService.setAccountStatus(user.userId, true);
      _loadArchivedUsers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Account "${user.fullName}" restored to active directory.'),
          backgroundColor: ParishColors.oliveGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restore failed: $e'), backgroundColor: ParishColors.mercyRed),
      );
    }
  }

  List<UserModel> get _processedUsers {
    if (_archivedUsers.isEmpty) return const [];

    var list = List<UserModel>.from(_archivedUsers);

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
    final processed = _processedUsers;
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
          appBar: AppBar(
            backgroundColor: ParishColors.cardWhite,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: ParishColors.marianBlue, size: 26),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Archived Accounts Directory',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                ),
                Text(
                  'Soft-deleted accounts barred from system access (account_status = false)',
                  style: TextStyle(fontSize: 12, color: ParishColors.textMuted),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: ParishColors.marianBlue),
                onPressed: _loadArchivedUsers,
                tooltip: 'Refresh Archive',
              ),
            ],
          ),
          body: Padding(
            padding: EdgeInsets.all(isDesktop ? 32 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: ParishColors.mercyRed.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: ParishColors.mercyRed.withOpacity(0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.archive_outlined, color: ParishColors.mercyRed, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Archived Accounts Quarantine ($totalCount Records)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: ParishColors.textDark),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Users listed here cannot log in to ParishServe. Tap "Restore" on any record to reactivate their access.',
                              style: TextStyle(fontSize: 12, color: ParishColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
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
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 48, color: ParishColors.borderGrey),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isNotEmpty ? 'No archived accounts match your query.' : 'Archive is empty. All registered accounts are active.',
                          style: TextStyle(color: ParishColors.textMuted, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                      : isDesktop
                      ? _buildDesktopDataTable(pagedUsers)
                      : _buildMobileCardList(pagedUsers),
                ),
                const SizedBox(height: 14),

                if (totalCount > 0 && !_isLoading) _buildPaginationToolbar(totalCount, totalPages, startIndex, endIndex),
              ],
            ),
          ),
        );
      },
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
                    hintText: 'Search archived accounts by name, username, email, ID...',
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
  // Desktop View: Responsive Flex Table (100% Edge-to-Edge Width)
  // ---------------------------------------------------------------------------
  Widget _buildDesktopDataTable(List<UserModel> users) {
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
              1: FlexColumnWidth(2.2),  // Full Name
              2: FlexColumnWidth(2.5),  // Username / Email
              3: FlexColumnWidth(2.3),  // Assigned Role
              4: FixedColumnWidth(140), // Status Badge
              5: FixedColumnWidth(110), // Action Button (Always visible on right edge!)
            },
            children: [
              // Header Row
              TableRow(
                decoration: BoxDecoration(color: const Color(0xFFFEF2F2)),
                children: [
                  _buildHeaderCell('ID'),
                  _buildHeaderCell('Full Name'),
                  _buildHeaderCell('Username / Email'),
                  _buildHeaderCell('Assigned Role'),
                  _buildHeaderCell('Status'),
                  _buildHeaderCell('Action', align: TextAlign.center),
                ],
              ),
              // Data Rows
              ...users.map((user) {
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
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: roleTheme.primary),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              user.fullName,
                              style: TextStyle(fontWeight: FontWeight.bold, color: ParishColors.textMuted),
                              overflow: TextOverflow.ellipsis,
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
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: ParishColors.textMuted),
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

                    // Assigned Role Badge
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

                    // Status Badge
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: ParishColors.mercyRedSurface,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'ARCHIVED / LOCKED',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ParishColors.mercyRed),
                          ),
                        ),
                      ),
                    ),

                    // Action Button (Restore)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Center(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ParishColors.oliveGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _confirmRestore(user),
                          icon: const Icon(Icons.restore, size: 16),
                          label: const Text('Restore', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
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
    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final roleTheme = RoleThemeHelper.getTheme(user.userRole);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ParishColors.cardWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ParishColors.borderGrey),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: roleTheme.background,
                        child: Text(
                          user.firstName.isNotEmpty ? user.firstName[0].toUpperCase() : 'U',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: roleTheme.primary),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        user.fullName,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ParishColors.textMuted),
                      ),
                    ],
                  ),
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
              const SizedBox(height: 6),
              Text('${user.username} • ${user.email}', style: TextStyle(fontSize: 12, color: ParishColors.textMuted)),
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
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ParishColors.oliveGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _confirmRestore(user),
                    icon: const Icon(Icons.restore, size: 16),
                    label: const Text('Restore', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
                'Showing ${startIndex + 1}–$endIndex of $totalItems archived',
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
                'Showing ${startIndex + 1}–$endIndex of $totalItems archived',
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