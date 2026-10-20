import '../domain/birth_date.dart';
import '../domain/auth_failure.dart';
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
  Future<void> signUp({
    required String username,
    required String pin,
    DateTime? birthDate,
  }) async {
    await signIn(username: username, pin: pin);
    await updateBirthDate(birthDate);
  }

  @override
  Future<void> updateBirthDate(DateTime? birthDate) => updateNutritionProfile(
    birthDate: birthDate,
    sex: currentUser?.nutritionSex,
    lifeStage: currentUser?.nutritionLifeStage,
  );

  @override
  Future<void> updateNutritionProfile({
    DateTime? birthDate,
    String? sex,
    String? lifeStage,
  }) async {
    if (birthDate != null && parseBirthDate(birthDateText(birthDate)) == null) {
      throw const AuthFailure('생년월일을 확인해 줘.');
    }
    final user = _currentUser;
    if (user == null) throw const AuthFailure('로그인 후 다시 시도해 줘.');
    _currentUser = AuthUser(
      id: user.id,
      username: user.username,
      email: user.email,
      role: user.role,
      birthDate: birthDate,
      nutritionSex: sex,
      nutritionLifeStage: sex == 'male' ? 'general' : lifeStage,
    );
    _controller.add(_currentUser);
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _controller.add(null);
  }
}
