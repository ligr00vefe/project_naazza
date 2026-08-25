import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../domain/tracking_catalog.dart';
import '../domain/tracking_profile.dart';
import 'tracking_profile_controller.dart';

class TrackingProfilePage extends ConsumerStatefulWidget {
  const TrackingProfilePage({super.key, this.editing = false});
  final bool editing;
  @override
  ConsumerState<TrackingProfilePage> createState() =>
      _TrackingProfilePageState();
}

class _TrackingProfilePageState extends ConsumerState<TrackingProfilePage> {
  final _conditions = <String>{};
  final _enabledMetrics = <String>{};
  bool _remindersEnabled = true;

  @override
  void initState() {
    super.initState();
    if (widget.editing) {
      final profile = ref.read(trackingProfileProvider).value;
      if (profile != null) {
        _conditions.addAll(profile.conditionKeys);
        _enabledMetrics.addAll(
          profile.metrics
              .where((item) => item.enabled)
              .map((item) => item.metricKey),
        );
        _remindersEnabled = profile.remindersEnabled;
      }
    }
  }

  List<String> get _recommendedMetricKeys {
    final keys = <String>[];
    for (final condition in TrackingCatalog.conditions) {
      if (_conditions.contains(condition.key)) {
        for (final key in condition.metricKeys) {
          if (!keys.contains(key)) keys.add(key);
        }
      }
    }
    return keys;
  }

  void _toggleCondition(ConditionDefinition condition) {
    setState(() {
      if (!_conditions.add(condition.key)) {
        _conditions.remove(condition.key);
      }
      _enabledMetrics.addAll(_recommendedMetricKeys);
    });
  }

  Future<void> _save() async {
    if (_conditions.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('관리 목표를 하나 이상 선택해 주세요.')));
      return;
    }
    final orderedKeys = <String>[
      ..._recommendedMetricKeys,
      ..._enabledMetrics.where((key) => !_recommendedMetricKeys.contains(key)),
    ];
    await ref
        .read(trackingProfileProvider.notifier)
        .save(
          TrackingProfile(
            conditionKeys: _conditions.toList(),
            metrics: [
              for (var index = 0; index < orderedKeys.length; index++)
                TrackingMetricSelection(
                  metricKey: orderedKeys[index],
                  enabled: _enabledMetrics.contains(orderedKeys[index]),
                  quickLogOrder: index,
                ),
            ],
            remindersEnabled: _remindersEnabled,
          ),
        );
    if (!mounted) return;
    final error = ref.read(trackingProfileProvider).error;
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('설정을 저장하지 못했어요: $error')));
    } else if (widget.editing) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final saveState = ref.watch(trackingProfileProvider);
    final recommended = _recommendedMetricKeys;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          widget.editing ? '맞춤 추적 설정' : 'NAAZZA',
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F9F4),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '나의 건강 여정을 함께해요 🌱',
                  style: TextStyle(color: AppColors.primary),
                ),
                const SizedBox(height: 10),
                Text(
                  '기록할 목표를 선택하고\n나에게 맞는 추적 항목을 설정해요',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 10),
                const Text(
                  '언제든지 설정에서 변경할 수 있어요.',
                  style: TextStyle(color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _SectionCard(
            title: '1. 관리 목표를 선택해 주세요',
            subtitle: '복수 선택 가능',
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final condition in TrackingCatalog.conditions)
                  _ConditionChoice(
                    definition: condition,
                    selected: _conditions.contains(condition.key),
                    onTap: () => _toggleCondition(condition),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: '2. 추적 항목을 설정해 주세요',
            subtitle: recommended.isEmpty
                ? '목표를 선택하면 항목을 추천해요'
                : '${recommended.length}개 추천됨',
            child: Column(
              children: [
                if (recommended.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      '선택한 목표에 맞는 항목이 여기에 표시됩니다.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  )
                else
                  for (final key in recommended)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: CircleAvatar(
                        backgroundColor: TrackingCatalog.metric(
                          key,
                        ).color.withValues(alpha: 0.14),
                        child: Icon(
                          TrackingCatalog.metric(key).icon,
                          color: TrackingCatalog.metric(key).color,
                        ),
                      ),
                      title: Text(
                        TrackingCatalog.metric(key).label,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text('Quick Log에 사용'),
                      value: _enabledMetrics.contains(key),
                      onChanged: (value) => setState(
                        () => value
                            ? _enabledMetrics.add(key)
                            : _enabledMetrics.remove(key),
                      ),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: '3. 알림 설정을 선택해 주세요',
            subtitle: '한 이벤트당 기본 1회',
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.notifications_rounded),
                  label: Text('알림 허용'),
                ),
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.notifications_off_outlined),
                  label: Text('나중에 설정'),
                ),
              ],
              selected: {_remindersEnabled},
              onSelectionChanged: (value) =>
                  setState(() => _remindersEnabled = value.first),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(20),
        child: FilledButton(
          onPressed: saveState.isLoading ? null : _save,
          child: saveState.isLoading
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('설정 완료하고 시작하기'),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final String title;
  final String subtitle;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 18),
          child,
        ],
      ),
    ),
  );
}

class _ConditionChoice extends StatelessWidget {
  const _ConditionChoice({
    required this.definition,
    required this.selected,
    required this.onTap,
  });
  final ConditionDefinition definition;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: MediaQuery.sizeOf(context).width > 560 ? 230 : double.infinity,
    child: Material(
      color: selected ? const Color(0xFFEAF7F0) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.outline,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Icon(
                definition.icon,
                color: selected ? AppColors.primary : AppColors.muted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      definition.label,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      definition.subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.primary,
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
