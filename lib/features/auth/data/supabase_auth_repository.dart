import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;
import '../domain/auth_failure.dart';
import '../domain/auth_user.dart';
import 'auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);
  final SupabaseClient _client;

  String _normalize(String username) => username.trim().toLowerCase();

  AuthUser? _mapUser(User? user) {
    if (user == null) return null;
    final username =
        user.userMetadata?['username']?.toString() ??
        user.email?.split('@').first ??
        '';
    return AuthUser(
      id: user.id,
      username: username,
      email: user.userMetadata?['email']?.toString(),
      role: user.appMetadata['role']?.toString() ?? 'member',
    );
  }

  @override
  AuthUser? get currentUser => _mapUser(_client.auth.currentUser);

  @override
  Stream<AuthUser?> get authStateChanges => _client.auth.onAuthStateChange.map(
    (event) => _mapUser(event.session?.user),
  );

  @override
  Future<void> signIn({required String username, required String pin}) async {
    try {
      final response = await _client.functions.invoke(
        'username-login',
        body: {'username': _normalize(username), 'pin': pin},
      );
      final data = response.data;
      if (data is! Map || data['refresh_token'] is! String) {
        final message = data is Map ? data['message']?.toString() : null;
        throw AuthFailure(message ?? '아이디 또는 비밀번호가 맞지 않아.');
      }
      await _client.auth.setSession(data['refresh_token'] as String);
    } on FunctionException catch (error) {
      final details = error.details;
      final message = details is Map ? details['message']?.toString() : null;
      throw AuthFailure(message ?? '아이디 또는 비밀번호가 맞지 않아.');
    } on AuthException catch (error) {
      throw _toFailure(error);
    }
  }

  @override
  Future<void> signUp({required String username, required String pin}) async {
    try {
      final response = await _client.functions.invoke(
        'username-signup',
        body: {'username': _normalize(username), 'pin': pin},
      );
      if (response.status < 200 || response.status >= 300) {
        final data = response.data;
        final message = data is Map ? data['message']?.toString() : null;
        throw AuthFailure(message ?? '회원가입을 처리하지 못했어.');
      }
      await signIn(username: username, pin: pin);
    } on FunctionException catch (error) {
      final details = error.details;
      final message = details is Map ? details['message']?.toString() : null;
      throw AuthFailure(message ?? '회원가입을 처리하지 못했어. 잠시 뒤 다시 시도해 줘.');
    }
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  AuthFailure _toFailure(AuthException error) {
    final message = switch (error.code) {
      'invalid_credentials' => '아이디 또는 비밀번호가 맞지 않아.',
      'user_already_exists' || 'email_exists' => '이미 사용 중인 아이디야.',
      'over_request_rate_limit' => '요청이 너무 잦아. 잠시 뒤 다시 시도해 줘.',
      'signup_disabled' => '현재 신규 회원가입이 중단되어 있어.',
      _ => '인증 요청을 처리하지 못했어. 네트워크 상태를 확인해 줘.',
    };
    return AuthFailure(message, code: error.code);
  }
}
