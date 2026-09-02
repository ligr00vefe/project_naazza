import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;
import '../domain/auth_user.dart';
import 'auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);
  final SupabaseClient _client;

  AuthUser? _mapUser(User? user) => user == null
      ? null
      : AuthUser(
          id: user.id,
          email: user.email ?? '',
          isEmailVerified: user.emailConfirmedAt != null,
        );

  @override
  bool get isEmailVerified =>
      _client.auth.currentUser?.emailConfirmedAt != null;

  @override
  AuthUser? get currentUser => _mapUser(_client.auth.currentUser);

  @override
  Stream<AuthUser?> get authStateChanges => _client.auth.onAuthStateChange.map(
    (event) => _mapUser(event.session?.user),
  );

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<void> signUp({required String email, required String password}) async {
    await _client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: 'naazza://auth-callback',
    );
  }

  @override
  Future<void> resendEmailVerification({required String email}) =>
      _client.auth.resend(
        type: OtpType.signup,
        email: email,
        emailRedirectTo: 'naazza://auth-callback',
      );

  @override
  Future<bool> refreshEmailVerification({
    required String email,
    required String password,
  }) async {
    if (_client.auth.currentSession == null) {
      try {
        await _client.auth.signInWithPassword(email: email, password: password);
      } on AuthException catch (error) {
        if (error.message.toLowerCase().contains('email not confirmed')) {
          return false;
        }
        rethrow;
      }
    } else {
      await _client.auth.refreshSession();
    }
    return isEmailVerified;
  }

  @override
  Future<void> signOut() => _client.auth.signOut();
}
