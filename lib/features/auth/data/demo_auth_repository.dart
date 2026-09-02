import 'dart:async';
import '../domain/auth_user.dart';
import 'auth_repository.dart';

class DemoAuthRepository implements AuthRepository {
  final _controller = StreamController<AuthUser?>.broadcast();
  AuthUser? _currentUser;
  String? _pendingEmail;

  @override
  AuthUser? get currentUser => _currentUser;

  @override
  bool get isEmailVerified => _currentUser?.isEmailVerified ?? false;

  @override
  Stream<AuthUser?> get authStateChanges async* {
    yield _currentUser;
    yield* _controller.stream;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    _currentUser = AuthUser(id: 'demo-user', email: email);
    _controller.add(_currentUser);
  }

  @override
  Future<void> signUp({required String email, required String password}) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    _pendingEmail = email;
  }

  @override
  Future<void> resendEmailVerification({required String email}) async {}

  @override
  Future<bool> refreshEmailVerification({
    required String email,
    required String password,
  }) async => _pendingEmail == email;

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _controller.add(null);
  }
}
