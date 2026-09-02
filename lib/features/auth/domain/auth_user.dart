class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    this.isEmailVerified = true,
  });
  final String id;
  final String email;
  final bool isEmailVerified;
}
