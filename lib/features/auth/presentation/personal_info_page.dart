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
  DateTime? _birthDate;
  String? _sex, _lifeStage;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    final user = ref.read(authRepositoryProvider).currentUser;
    _birthDate = user?.birthDate;
    _sex = user?.nutritionSex;
    _lifeStage = user?.nutritionLifeStage;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .updateNutritionProfile(
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
            child: NutritionProfileFields(
              birthDate: _birthDate,
              sex: _sex,
              lifeStage: _lifeStage,
              enabled: !_saving,
              onBirthDate: (v) => setState(() => _birthDate = v),
              onSex: (v) => setState(() {
                _sex = v;
                _lifeStage = v == 'female' ? 'general' : null;
              }),
              onLifeStage: (v) => setState(() => _lifeStage = v),
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
