import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;
import '../domain/auth_user.dart';
import 'auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);
  final SupabaseClient _client;

  AuthUser? _mapUser(User? user) =>
      user == null ? null : AuthUser(id: user.id, email: user.email ?? '');

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
  Future<SignUpResult> signUp({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
    );
    return SignUpResult(requiresEmailConfirmation: response.session == null);
  }

  @override
  Future<void> resendSignUpConfirmation({required String email}) async {
    await _client.auth.resend(type: OtpType.signup, email: email);
  }

  @override
  Future<void> signOut() => _client.auth.signOut();
}
