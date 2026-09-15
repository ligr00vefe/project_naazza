class AuthUser {
  const AuthUser({
    required this.id,
    required this.username,
    this.email,
    this.role = 'member',
  });

  final String id;
  final String username;
  final String? email;
  final String role;

  bool get isAdmin => role == 'admin';
}
