import 'birth_date.dart';

class AuthUser {
  const AuthUser({
    required this.id,
    required this.username,
    this.email,
    this.displayName,
    this.birthDate,
    this.nutritionSex,
    this.nutritionLifeStage,
    this.role = 'member',
  });

  final String id;
  final String username;
  final String? email;
  final String? displayName;
  final String role;
  final DateTime? birthDate;
  final String? nutritionSex, nutritionLifeStage;
  int? ageAt(DateTime date) =>
      birthDate == null ? null : ageOn(birthDate!, date);
  int? get age => ageAt(DateTime.now());

  bool get isAdmin => role == 'admin';
}
