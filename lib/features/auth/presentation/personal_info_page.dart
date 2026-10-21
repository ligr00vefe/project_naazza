import '../domain/profile_validation.dart';
import '../domain/auth_failure.dart';
import '../../../core/widgets/app_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/app_page.dart';
import '../data/auth_repository.dart';
import 'nutrition_profile_fields.dart';

class PersonalInfoPage extends ConsumerStatefulWidget {
  const PersonalInfoPage({super.key});
  @override
  ConsumerState<PersonalInfoPage> createState() => _PersonalInfoPageState();
}

class _PersonalInfoPageState extends ConsumerState<PersonalInfoPage> {
  final _name = TextEditingController();
  String? _validationError;
  DateTime? _birthDate;
  String? _sex, _lifeStage;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    final user = ref.read(authRepositoryProvider).currentUser;
    _name.text = user?.displayName ?? '';
    _birthDate = user?.birthDate;
    _sex = user?.nutritionSex;
    _lifeStage = user?.nutritionLifeStage;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    try {
      requireProfileSex(_sex);
      normalizeDisplayName(_name.text);
    } on AuthFailure catch (error) {
      setState(() => _validationError = error.message);
      return;
    }
    setState(() {
      _saving = true;
      _validationError = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .updateNutritionProfile(
            displayName: _name.text,
            birthDate: _birthDate,
            sex: _sex,
            lifeStage: _lifeStage,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('내 정보를 저장했어요.')));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('저장하지 못했어요. 다시 시도해 주세요.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(title: const AppPageTitle('내 정보')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const AppSectionHeader('내 정보와 영양 기준'),
          AppCard(
            child: TextField(
              key: const ValueKey('profile-name'),
              controller: _name,
              enabled: !_saving,
              maxLength: 30,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: '이름',
                hintText: '환영 인사에 사용할 이름',
                prefixIcon: Icon(Icons.person_outline_rounded),
                counterText: '',
                helperText: '홈에서 이름으로 인사해요.',
              ),
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: NutritionProfileFields(
              birthDate: _birthDate,
              sex: _sex,
              lifeStage: _lifeStage,
              enabled: !_saving,
              onBirthDate: (v) => setState(() => _birthDate = v),
              onSex: (v) => setState(() {
                _sex = v;
                _validationError = null;
                _lifeStage = v == 'female' ? 'general' : null;
              }),
              onLifeStage: (v) => setState(() => _lifeStage = v),
            ),
          ),
          if (_validationError != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _validationError!,
                key: const ValueKey('profile-validation'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 20),
          FilledButton(
            key: const ValueKey('personal-info-save'),
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '저장 중' : '저장하기'),
          ),
        ],
      ),
    );
  }
}
