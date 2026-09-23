import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../models/user_model.dart';
import '../services/admin_user_service.dart';
import '../services/auth_service.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  List<UserModel> _users = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';

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
      setState(() => _users = users);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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

  Future<void> _toggleStatus(UserModel user) async {
    final currentUserId = AuthService.currentUser?.userId;

    if (user.userId == currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Action Denied: You cannot deactivate your own account.'),
          backgroundColor: ParishColors.mercyRed,
        ),
      );
      return;
    }

    try {
      final newStatus = !user.accountStatus;
      await AdminUserService.setAccountStatus(user.userId, newStatus);
      _loadUsers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Account ${user.username} has been ${newStatus ? 'activated' : 'deactivated'}.'),
          backgroundColor: newStatus ? ParishColors.oliveGreen : ParishColors.mercyRed,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status update failed: $e'), backgroundColor: ParishColors.mercyRed),
      );
    }
  }

  List<UserModel> get _filteredUsers {
    if (_searchQuery.trim().isEmpty) return _users;
    final q = _searchQuery.toLowerCase().trim();
    return _users.where((u) {
      return u.fullName.toLowerCase().contains(q) ||
          u.username.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q) ||
          u.userId.toLowerCase().contains(q) ||
          u.userRole.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final callerRole = AuthService.currentUser?.userRole.toLowerCase() ?? '';
    final isSuperAdmin = callerRole == 'superadmin';
    final currentUserId = AuthService.currentUser?.userId;

    return Scaffold(
      backgroundColor: ParishColors.backgroundLight,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'User & Access Governance',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                    ),
                    Text(
                      isSuperAdmin
                          ? 'Superadmin Access: Managing all parish staff and administrative accounts'
                          : 'Admin Access: Managing parish staff and client accounts',
                      style: TextStyle(fontSize: 13, color: ParishColors.textMuted),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: ParishColors.marianBlue),
                  onPressed: _loadUsers,
                  tooltip: 'Refresh Users',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search Bar
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: ParishColors.cardWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ParishColors.borderGrey),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 20, color: ParishColors.marianBlue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: TextStyle(fontSize: 13.5, color: ParishColors.textDark),
                      decoration: InputDecoration(
                        hintText: 'Search by name, username, email, ID, or role...',
                        hintStyle: TextStyle(fontSize: 13, color: ParishColors.textMuted),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // User List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(child: Text('Error: $_error', style: const TextStyle(color: ParishColors.mercyRed)))
                  : _filteredUsers.isEmpty
                  ? Center(child: Text('No accounts match your query.', style: TextStyle(color: ParishColors.textMuted)))
                  : ListView.builder(
                itemCount: _filteredUsers.length,
                itemBuilder: (context, index) {
                  final user = _filteredUsers[index];
                  final isSelf = user.userId == currentUserId;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: ParishColors.cardWhite,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelf
                            ? ParishColors.marianBlue
                            : ParishColors.borderGrey,
                        width: isSelf ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: user.accountStatus ? ParishColors.marianBlueSurface : ParishColors.mercyRedSurface,
                          child: Text(
                            user.firstName.isNotEmpty ? user.firstName[0].toUpperCase() : 'U',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: user.accountStatus ? ParishColors.marianBlue : ParishColors.mercyRed,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    user.fullName,
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ParishColors.textDark),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: ParishColors.goldLight,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      user.userId,
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: ParishColors.goldAccent),
                                    ),
                                  ),
                                  if (isSelf) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: ParishColors.marianBlueSurface,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'YOU',
                                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: ParishColors.marianBlue),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${user.email} • Role: ${user.roleDisplay}',
                                style: TextStyle(fontSize: 12, color: ParishColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              activeColor: ParishColors.oliveGreen,
                              value: user.accountStatus,
                              onChanged: isSelf ? null : (_) => _toggleStatus(user),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20, color: ParishColors.marianBlue),
                              onPressed: () => _openUserModal(userToEdit: user),
                              tooltip: 'Edit User',
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: ParishColors.marianBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Add New User', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _openUserModal(),
      ),
    );
  }
}

class _UserFormDialog extends StatefulWidget {
  final UserModel? userToEdit;
  final VoidCallback onSaved;

  const _UserFormDialog({this.userToEdit, required this.onSaved});

  @override
  State<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<_UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _usernameController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;

  String _selectedRole = 'secretary';
  bool _isSaving = false;
  String? _formError;

  @override
  void initState() {
    super.initState();
    final u = widget.userToEdit;
    _usernameController = TextEditingController(text: u?.username ?? '');
    _emailController = TextEditingController(text: u?.email ?? '');
    _passwordController = TextEditingController(text: u != null ? '••••••••' : '');
    _firstNameController = TextEditingController(text: u?.firstName ?? '');
    _lastNameController = TextEditingController(text: u?.lastName ?? '');
    if (u != null) {
      _selectedRole = u.userRole.toLowerCase();
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
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
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _formError = null;
    });

    try {
      if (widget.userToEdit == null) {
        await AdminUserService.createUser(
          username: _usernameController.text,
          email: _emailController.text,
          password: _passwordController.text,
          firstName: _firstNameController.text,
          lastName: _lastNameController.text,
          userRole: _selectedRole,
        );
      } else {
        await AdminUserService.updateUser(
          userId: widget.userToEdit!.userId,
          username: _usernameController.text,
          email: _emailController.text,
          firstName: _firstNameController.text,
          lastName: _lastNameController.text,
          userRole: _selectedRole,
          accountStatus: widget.userToEdit!.accountStatus,
        );
      }

      if (!mounted) return;
      Navigator.pop(context);
      widget.onSaved();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User account saved successfully.'), backgroundColor: ParishColors.oliveGreen),
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
    final isEditing = widget.userToEdit != null;
    final options = _getPermittedRoleOptions();

    // Ensure selected role is valid in list
    if (!options.any((o) => o['value'] == _selectedRole)) {
      _selectedRole = options.first['value']!;
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(isEditing ? 'Edit User Account' : 'Provision New User', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_formError != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: ParishColors.mercyRedSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: ParishColors.mercyRed),
                    ),
                    child: Text(_formError!, style: const TextStyle(color: ParishColors.mercyRed, fontSize: 12)),
                  ),
                ],
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _firstNameController,
                        decoration: InputDecoration(
                          labelText: 'First Name *',
                          filled: true,
                          fillColor: ParishColors.backgroundLight,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _lastNameController,
                        decoration: InputDecoration(
                          labelText: 'Last Name *',
                          filled: true,
                          fillColor: ParishColors.backgroundLight,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'Username *',
                    filled: true,
                    fillColor: ParishColors.backgroundLight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  validator: (v) => (v?.trim().length ?? 0) < 3 ? 'Min 3 characters' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email Address *',
                    filled: true,
                    fillColor: ParishColors.backgroundLight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  validator: (v) => (v?.contains('@') ?? false) ? null : 'Valid email required',
                ),
                const SizedBox(height: 10),
                if (!isEditing) ...[
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Initial Password *',
                      filled: true,
                      fillColor: ParishColors.backgroundLight,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    validator: (v) => (v?.length ?? 0) < 6 ? 'Min 6 characters' : null,
                  ),
                  const SizedBox(height: 10),
                ],
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  items: options.map((r) {
                    return DropdownMenuItem(value: r['value'], child: Text(r['label']!, style: const TextStyle(fontSize: 13)));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedRole = val);
                  },
                  decoration: InputDecoration(
                    labelText: 'Assigned Role *',
                    filled: true,
                    fillColor: ParishColors.backgroundLight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: ParishColors.marianBlue, foregroundColor: Colors.white),
          onPressed: _isSaving ? null : _save,
          child: Text(_isSaving ? 'Saving...' : 'Save User'),
        ),
      ],
    );
  }
}