class UserModel {
  final String userId;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String userRole;
  final bool accountStatus;
  final bool darkModeEnabled;

  UserModel({
    required this.userId,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.userRole,
    required this.accountStatus,
    this.darkModeEnabled = false,
  });

  String get fullName => '$firstName $lastName';

  String get roleDisplay {
    switch (userRole.toLowerCase()) {
      case 'superadmin':
        return 'Super Administrator (S)';
      case 'admin':
        return 'Administrator (A)';
      case 'secretary':
        return 'Parish Secretary (Sc)';
      case 'encoder':
        return 'Records Encoder (E)';
      case 'parishpriest':
        return 'Parish Priest (P)';
      case 'pfc':
        return 'Parish Finance Council Auditor (PFC)';
      case 'user':
        return 'Parishioner / Client (U)';
      default:
        return userRole.toUpperCase();
    }
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      userId: map['user_id'] ?? '',
      username: map['username'] ?? '',
      email: map['email'] ?? '',
      firstName: map['first_name'] ?? '',
      lastName: map['last_name'] ?? '',
      userRole: map['user_role'] ?? 'secretary',
      accountStatus: map['account_status'] ?? true,
      darkModeEnabled: map['dark_mode_enabled'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'username': username,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'user_role': userRole,
      'account_status': accountStatus,
      'dark_mode_enabled': darkModeEnabled,
    };
  }
}