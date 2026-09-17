import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../models/user_model.dart';
import '../services/admin_user_service.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  List<UserModel> _users = [];
  bool _isLoading = false;
  String? _error;

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
        _users = users;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _openUserModal({UserModel? userToEdit}) {
    showDialog(
      context: context,
      builder: (ctx) => _UserFormDialog(
        userToEdit: userToEdit,
        onSaved: _loadUsers,
      ),
    );
  }

  Future<void> _toggleStatus(UserModel user) async {
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
        SnackBar(content: Text('Failed to update status: $e'), backgroundColor: ParishColors.mercyRed),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ParishColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: ParishColors.cardWhite,
        elevation: 0,
        title: Text(
          'Admin: User & Access Management',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ParishColors.textDark),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: ParishColors.marianBlue),
            onPressed: _loadUsers,
            tooltip: 'Refresh Users',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Error: $_error', style: const TextStyle(color: ParishColors.mercyRed)))
          : ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _users.length,
        itemBuilder: (context, index) {
          final user = _users[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ParishColors.cardWhite,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ParishColors.borderGrey),
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
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ParishColors.textDark),
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
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Username: ${user.username} • Role: ${user.roleDisplay}',
                        style: TextStyle(fontSize: 13, color: ParishColors.textMuted),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Switch(
                      activeColor: ParishColors.oliveGreen,
                      value: user.accountStatus,
                      onChanged: (_) => _toggleStatus(user),
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

  final List<Map<String, String>> _roleOptions = [
    {'value': 'superadmin', 'label': 'Super Administrator (S)'},
    {'value': 'admin', 'label': 'Administrator (A)'},
    {'value': 'secretary', 'label': 'Parish Secretary (Sc)'},
    {'value': 'encoder', 'label': 'Records Encoder (E)'},
    {'value': 'parishpriest', 'label': 'Parish Priest (P)'},
    {'value': 'pfc', 'label': 'Parish Finance Council Auditor (PFC)'},
  ];

  @override
  void initState() {
    super.initState();
    final u = widget.userToEdit;
    _usernameController = TextEditingController(text: u?.username ?? '');
    _emailController = TextEditingController(text: u?.email ?? '');
    _passwordController = TextEditingController(text: u != null ? '••••••••' : 'ParishServe@123');
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
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.userToEdit != null;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(isEditing ? 'Edit User Account' : 'Register New User', style: const TextStyle(fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_formError != null) ...[
                  Container(
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
                TextFormField(
                  controller: _firstNameController,
                  decoration: InputDecoration(
                    labelText: 'First Name *',
                    filled: true,
                    fillColor: ParishColors.backgroundLight,
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _lastNameController,
                  decoration: InputDecoration(
                    labelText: 'Last Name *',
                    filled: true,
                    fillColor: ParishColors.backgroundLight,
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'Username *',
                    filled: true,
                    fillColor: ParishColors.backgroundLight,
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email Address *',
                    filled: true,
                    fillColor: ParishColors.backgroundLight,
                  ),
                  validator: (val) => val == null || !val.contains('@') ? 'Enter a valid email' : null,
                ),
                const SizedBox(height: 10),
                if (!isEditing) ...[
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password *',
                      filled: true,
                      fillColor: ParishColors.backgroundLight,
                    ),
                    validator: (val) => val == null || val.length < 6 ? 'Minimum 6 characters' : null,
                  ),
                  const SizedBox(height: 10),
                ],
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  items: _roleOptions.map((r) {
                    return DropdownMenuItem(value: r['value'], child: Text(r['label']!, style: const TextStyle(fontSize: 13)));
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedRole = val!),
                  decoration: InputDecoration(
                    labelText: 'User Role *',
                    filled: true,
                    fillColor: ParishColors.backgroundLight,
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