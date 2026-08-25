import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/auth_user.dart';

abstract interface class AuthRepository {
  AuthUser? get currentUser;
  Stream<AuthUser?> get authStateChanges;
  Future<void> signIn({required String email, required String password});
  Future<void> signUp({required String email, required String password});
  Future<void> signOut();
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) =>
      throw StateError('AuthRepository must be provided during bootstrap.'),
);
final authStateProvider = StreamProvider<AuthUser?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});
