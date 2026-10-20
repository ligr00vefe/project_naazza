import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../domain/bowel_form.dart';

class BowelFormSelector extends StatelessWidget {
  const BowelFormSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '가까운 상태를 골라요',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final form in BowelForm.values)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _FormOption(
                      form: form,
                      selected: form.type == value,
                      onTap: () => onChanged(form.type),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.blueSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$value · ${BowelForm.values.firstWhere((f) => f.type == value).label}',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const ValueKey('bowel-form-help'),
              onPressed: () => _showHelp(context),
              child: const Text('설명 보기'),
            ),
          ),
        ],
      ),
    ),
  );

  void _showHelp(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.8,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '상태 설명',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const CloseButton(),
                ],
              ),
              const Text(
                '숫자가 클수록 묽은 편이에요.',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: BowelForm.values.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final form = BowelForm.values[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${form.type} · ${form.label}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          form.description,
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormOption extends StatelessWidget {
  const _FormOption({
    required this.form,
    required this.selected,
    required this.onTap,
  });
  final BowelForm form;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '${form.type}번, ${form.label}',
    selected: selected,
    inMutuallyExclusiveGroup: true,
    button: true,
    onTap: onTap,
    excludeSemantics: true,
    child: Material(
      color: selected ? AppColors.primary : AppColors.surface,
      shape: CircleBorder(
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.outline,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('bowel-form-${form.type}'),
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Center(
            child: Text(
              '${form.type}',
              style: TextStyle(
                color: selected ? Colors.white : AppColors.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
