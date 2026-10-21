import '../../../core/widgets/app_page.dart';
import 'package:flutter/material.dart';
import '../../../app/theme/app_design.dart';
import '../../../core/widgets/word_wrap_text.dart';
import '../domain/birth_date.dart';
import 'birth_date_field.dart';

class NutritionProfileFields extends StatelessWidget {
  const NutritionProfileFields({
    super.key,
    required this.birthDate,
    required this.sex,
    required this.lifeStage,
    required this.onBirthDate,
    required this.onSex,
    required this.onLifeStage,
    this.enabled = true,
  });
  final DateTime? birthDate;
  final String? sex, lifeStage;
  final ValueChanged<DateTime?> onBirthDate;
  final ValueChanged<String?> onSex, onLifeStage;
  final bool enabled;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text('생년월일', style: AppDesign.body),
      const SizedBox(height: 8),
      BirthDateField(
        value: birthDate,
        enabled: enabled,
        onChanged: onBirthDate,
      ),
      if (birthDate != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            '만 ${ageOn(birthDate!, DateTime.now())}세',
            key: const ValueKey('calculated-age'),
            style: AppDesign.body,
          ),
        ),
      const SizedBox(height: 18),
      ProfileSexSelector(value: sex, onChanged: onSex, enabled: enabled),
      if (sex == 'female') ...[
        const SizedBox(height: 18),
        DropdownButtonFormField<String>(
          key: ValueKey('nutrition-life-$lifeStage'),
          initialValue: lifeStage,
          decoration: const InputDecoration(labelText: '추가 기준'),
          items: const [
            DropdownMenuItem(value: 'general', child: Text('일반')),
            DropdownMenuItem(value: 'pregnant1', child: Text('임신 1기')),
            DropdownMenuItem(value: 'pregnant2', child: Text('임신 2기')),
            DropdownMenuItem(value: 'pregnant3', child: Text('임신 3기')),
            DropdownMenuItem(value: 'nursing', child: Text('수유 중')),
            DropdownMenuItem(value: null, child: Text('나중에 설정')),
          ],
          onChanged: enabled ? onLifeStage : null,
        ),
      ],
      const SizedBox(height: 14),
      const WordWrapText(
        '내 정보에 맞춰 권장량을 비교해요. 나중에 더보기에서 입력하거나 바꿀 수 있어요.',
        style: AppDesign.caption,
      ),
    ],
  );
}

class ProfileSexSelector extends StatelessWidget {
  const ProfileSexSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.compact = false,
  });
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool enabled, compact;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text('성별 · 필수', style: AppDesign.body),
      const SizedBox(height: 8),
      LayoutBuilder(
        builder: (context, box) => Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in const [
              ('male', '남성', Icons.male_rounded),
              ('female', '여성', Icons.female_rounded),
            ])
              SizedBox(
                width: MediaQuery.textScalerOf(context).scale(13) > 20
                    ? box.maxWidth
                    : (box.maxWidth - 8) / 2,
                child: compact
                    ? ChoiceChip(
                        key: ValueKey('nutrition-sex-${item.$1}'),
                        label: Text(item.$2),
                        avatar: Icon(item.$3, size: 18),
                        selected: value == item.$1,
                        onSelected: enabled ? (_) => onChanged(item.$1) : null,
                      )
                    : AppChoiceTile(
                        key: ValueKey('nutrition-sex-${item.$1}'),
                        label: item.$2,
                        icon: item.$3,
                        selected: value == item.$1,
                        onTap: enabled ? () => onChanged(item.$1) : null,
                      ),
              ),
          ],
        ),
      ),
    ],
  );
}
