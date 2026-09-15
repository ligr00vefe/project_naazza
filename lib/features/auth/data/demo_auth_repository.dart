import 'dart:async';
import '../domain/auth_user.dart';
import 'auth_repository.dart';

class DemoAuthRepository implements AuthRepository {
  final _controller = StreamController<AuthUser?>.broadcast();
  AuthUser? _currentUser;

  @override
  AuthUser? get currentUser => _currentUser;

  @override
  Stream<AuthUser?> get authStateChanges async* {
    yield _currentUser;
    yield* _controller.stream;
  }

  @override
  Future<void> signIn({required String username, required String pin}) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    _currentUser = AuthUser(id: 'demo-user', username: username);
    _controller.add(_currentUser);
  }

  @override
  Future<void> signUp({required String username, required String pin}) async {
    await signIn(username: username, pin: pin);
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _controller.add(null);
  }
}
