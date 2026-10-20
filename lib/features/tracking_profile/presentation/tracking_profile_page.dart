import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/nutrition_profile_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../settings/presentation/accessibility_settings.dart';
import '../domain/tracking_catalog.dart';
import '../domain/tracking_profile.dart';
import 'tracking_profile_controller.dart';

const _green = Color(0xFF3B6FF5);
const _muted = Color(0xFF7585A1);

class TrackingProfilePage extends ConsumerStatefulWidget {
  const TrackingProfilePage({super.key, this.editing = false});
  final bool editing;
  @override
  ConsumerState<TrackingProfilePage> createState() =>
      _TrackingProfilePageState();
}

class _TrackingProfilePageState extends ConsumerState<TrackingProfilePage> {
  final _conditions = <String>{};
  final _choices = <String, bool>{};
  final _scroll = ScrollController();
  bool _remindersEnabled = true, _initialized = false;
  int _step = 0;
  bool _saving = false;
  DateTime? _birthDate;
  String? _sex, _lifeStage;
  @override
  void initState() {
    super.initState();
    final user = ref.read(authRepositoryProvider).currentUser;
    _birthDate = user?.birthDate;
    _sex = user?.nutritionSex;
    _lifeStage = user?.nutritionLifeStage;
  }

  List<String> get _recommended => _conditions.contains('custom')
      ? TrackingCatalog.metrics.map((m) => m.key).toList()
      : TrackingCatalog.conditions
            .where((c) => _conditions.contains(c.key))
            .expand((c) => c.metricKeys)
            .toSet()
            .toList();
  List<String> get _visibleMetrics =>
      {..._recommended, ..._choices.keys}.toList();

  void _loadExisting(TrackingProfile? profile) {
    if (_initialized || !widget.editing || profile == null) return;
    _conditions.addAll(profile.conditionKeys);
    for (final metric in profile.metrics) {
      if (TrackingCatalog.metrics.any((m) => m.key == metric.metricKey)) {
        _choices[metric.metricKey] = metric.enabled;
      }
    }
    _remindersEnabled = profile.remindersEnabled;
    _initialized = true;
    _seedRecommendations();
  }

  void _seedRecommendations() {
    for (final key in _recommended) {
      // Keep explicit OFF choices, including after goal removal/reselection.
      _choices.putIfAbsent(key, () => !_conditions.contains('custom'));
    }
  }

  void _toggleCondition(ConditionDefinition condition) => setState(() {
    if (!_conditions.add(condition.key)) _conditions.remove(condition.key);
    _seedRecommendations();
  });

  void _goTo(int step) {
    if (_saving ||
        ref.read(trackingProfileProvider).isLoading ||
        (step > 0 && _conditions.isEmpty)) {
      return;
    }
    if (_scroll.hasClients) _scroll.jumpTo(0);
    setState(() => _step = step);
  }

  Future<void> _save() async {
    if (_conditions.isEmpty || ref.read(trackingProfileProvider).isLoading) {
      return;
    }
    setState(() => _saving = true);
    if (!widget.editing) {
      try {
        await ref
            .read(authRepositoryProvider)
            .updateNutritionProfile(
              birthDate: _birthDate,
              sex: _sex,
              lifeStage: _lifeStage,
            );
      } catch (_) {
        if (mounted) {
          setState(() => _saving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('내 정보를 저장하지 못했어요. 다시 시도해 주세요.')),
          );
        }
        return;
      }
    }
    final keys = _visibleMetrics;
    await ref
        .read(trackingProfileProvider.notifier)
        .save(
          TrackingProfile(
            conditionKeys: _conditions.toList(),
            metrics: [
              for (var i = 0; i < keys.length; i++)
                TrackingMetricSelection(
                  metricKey: keys[i],
                  enabled: _choices[keys[i]] ?? false,
                  quickLogOrder: i,
                ),
            ],
            remindersEnabled: _remindersEnabled,
          ),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ref.read(trackingProfileProvider).hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('설정을 저장하지 못했어요. 선택한 내용은 그대로예요. 다시 시도해 주세요.'),
        ),
      );
    } else if (widget.editing) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(trackingProfileProvider);
    _loadExisting(state.value);
    final loading = state.isLoading || _saving;
    final reduceMotion =
        ref.watch(reduceMotionProvider) ||
        MediaQuery.disableAnimationsOf(context);
    final compact = MediaQuery.sizeOf(context).height < 740;
    return PopScope(
      canPop: _step == 0 && !loading,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !loading && _step > 0) _goTo(_step - 1);
      },
      child: AppScaffold(
        backgroundColor: const Color(0xFFF2FCFA),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          toolbarHeight: 48,
          centerTitle: true,
          automaticallyImplyLeading: false,
          title: const Text(
            '맞춤 기록 설정',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF142443),
            ),
          ),
          leading: _step > 0 || widget.editing
              ? IconButton(
                  tooltip: '이전',
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: loading
                      ? null
                      : () {
                          if (_step > 0) {
                            _goTo(_step - 1);
                          } else {
                            context.pop();
                          }
                        },
                )
              : null,
        ),
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFEBFBF7), Color(0xFFF7FCFF)],
            ),
          ),
          child: widget.editing && !_initialized && loading
              ? const Center(child: CircularProgressIndicator())
              : Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: SingleChildScrollView(
                      controller: _scroll,
                      padding: EdgeInsets.fromLTRB(
                        24,
                        compact ? 8 : 20,
                        24,
                        12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _StepProgress(
                            step: _step,
                            thirdStep: !widget.editing,
                            enabled: !loading,
                            hasGoal: _conditions.isNotEmpty,
                            onStep: _goTo,
                          ),
                          SizedBox(height: compact ? 14 : 24),
                          AnimatedSwitcher(
                            duration: reduceMotion
                                ? Duration.zero
                                : const Duration(milliseconds: 180),
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
                            child: TweenAnimationBuilder<double>(
                              key: ValueKey(_step),
                              tween: Tween(begin: 0, end: 1),
                              duration: reduceMotion
                                  ? Duration.zero
                                  : const Duration(milliseconds: 280),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, child) => Opacity(
                                opacity: value,
                                child: Transform.translate(
                                  offset: Offset(0, (1 - value) * 24),
                                  child: child,
                                ),
                              ),
                              child: _step == 0
                                  ? _goals(compact, loading)
                                  : _step == 1
                                  ? _metrics(compact, loading)
                                  : _Panel(
                                      child: Padding(
                                        padding: const EdgeInsets.all(18),
                                        child: NutritionProfileFields(
                                          birthDate: _birthDate,
                                          sex: _sex,
                                          lifeStage: _lifeStage,
                                          enabled: !loading,
                                          onBirthDate: (v) =>
                                              setState(() => _birthDate = v),
                                          onSex: (v) => setState(() {
                                            _sex = v;
                                            _lifeStage = v == 'female'
                                                ? 'general'
                                                : null;
                                          }),
                                          onLifeStage: (v) =>
                                              setState(() => _lifeStage = v),
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
        bottomNavigationBar: ColoredBox(
          color: const Color(0xFFF7FCFF),
          child: SafeArea(
            minimum: const EdgeInsets.fromLTRB(24, 10, 24, 16),
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 472),
                child: Row(
                  children: [
                    if (_step > 0) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: loading ? null : () => _goTo(_step - 1),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            foregroundColor: _green,
                            side: const BorderSide(color: _green),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('이전'),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      flex: _step == 0 ? 1 : 2,
                      child: FilledButton(
                        key: const ValueKey('tracking-next'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _green,
                          minimumSize: const Size.fromHeight(50),
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: loading || _conditions.isEmpty
                            ? null
                            : () {
                                if (_step < (widget.editing ? 1 : 2)) {
                                  _goTo(_step + 1);
                                } else {
                                  _save();
                                }
                              },
                        child: loading
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _step < (widget.editing ? 1 : 2)
                                    ? '다음'
                                    : widget.editing
                                    ? '저장하기'
                                    : '시작하기',
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _heading(String title, String subtitle, bool compact) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 19,
          height: 1.35,
          fontWeight: FontWeight.w700,
          color: Color(0xFF142443),
        ),
      ),
      const SizedBox(height: 5),
      Text(
        subtitle,
        style: const TextStyle(fontSize: 12, height: 1.4, color: _muted),
      ),
      SizedBox(height: compact ? 14 : 20),
    ],
  );

  Widget _goals(bool compact, bool loading) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _heading('어떤 목표로 기록할까요?', '여러 개 골라도 좋아요', compact),
      _Panel(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              for (final goal in TrackingCatalog.conditions) ...[
                if (goal != TrackingCatalog.conditions.first)
                  const SizedBox(height: 6),
                _GoalRow(
                  goal: goal,
                  selected: _conditions.contains(goal.key),
                  compact: compact,
                  onTap: loading ? null : () => _toggleCondition(goal),
                ),
              ],
            ],
          ),
        ),
      ),
      const Padding(
        padding: EdgeInsets.only(top: 12),
        child: Text(
          '언제든지 설정에서 바꿀 수 있어요.',
          style: TextStyle(fontSize: 11, color: _muted),
        ),
      ),
    ],
  );

  Widget _metrics(bool compact, bool loading) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _heading('추적할 항목을 골라요', '필요한 항목만 켜두세요', compact),
      LayoutBuilder(
        builder: (context, box) {
          final columns = MediaQuery.textScalerOf(context).scale(13) > 20
              ? 2
              : 3;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final key in _visibleMetrics)
                SizedBox(
                  width: (box.maxWidth - 10 * (columns - 1)) / columns,
                  child: AppChoiceTile(
                    key: ValueKey('metric-$key'),
                    label: TrackingCatalog.metric(key).label,
                    icon: TrackingCatalog.metric(key).icon,
                    selected: _choices[key] ?? false,
                    onTap: loading
                        ? null
                        : () => setState(
                            () => _choices[key] = !(_choices[key] ?? false),
                          ),
                  ),
                ),
            ],
          );
        },
      ),
      const SizedBox(height: 12),
      _Panel(
        child: _MetricRow(
          label: '기록 알림',
          rowKey: const ValueKey('tracking-reminders'),
          value: _remindersEnabled,
          onChanged: loading
              ? null
              : (value) => setState(() => _remindersEnabled = value),
        ),
      ),
      const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text(
          '알림은 나중에 바꿀 수 있어요.',
          style: TextStyle(fontSize: 11, color: _muted),
        ),
      ),
    ],
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: const [
        BoxShadow(
          color: Color(0x07315337),
          blurRadius: 18,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: Material(color: Colors.transparent, child: child),
  );
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({
    required this.goal,
    required this.selected,
    required this.compact,
    required this.onTap,
  });
  final ConditionDefinition goal;
  final bool selected, compact;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: Material(
      color: selected ? const Color(0xFFE4FBF5) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: selected ? _green : Colors.transparent),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: compact ? 56 : 64),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF142443),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      goal.subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.3,
                        color: _muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 22,
                color: selected ? _green : const Color(0xFFA3B2C7),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.rowKey,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final Key rowKey;
  final bool value;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) => SwitchListTile(
    key: rowKey,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    dense: true,
    visualDensity: const VisualDensity(vertical: -2),
    title: Text(
      label,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    ),
    activeThumbColor: Colors.white,
    activeTrackColor: _green,
    value: value,
    onChanged: onChanged,
  );
}

class _StepProgress extends StatelessWidget {
  const _StepProgress({
    required this.step,
    required this.thirdStep,
    required this.enabled,
    required this.hasGoal,
    required this.onStep,
  });
  final int step;
  final bool thirdStep;
  final bool enabled, hasGoal;
  final ValueChanged<int> onStep;
  Widget _button(int i) => Expanded(
    child: TextButton(
      onPressed: !enabled || (i > 0 && !hasGoal) ? null : () => onStep(i),
      style: TextButton.styleFrom(
        foregroundColor: step == i ? _green : _muted,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(48, 40),
      ),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: step == i ? _green : const Color(0xFFE7EFF9),
            ),
            child: Text(
              '${i + 1}',
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontSize: 12,
                color: step == i ? Colors.white : _muted,
              ),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              i == 0
                  ? '관리 목표'
                  : i == 1
                  ? '추적 항목'
                  : '내 정보',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Row(
    children: [
      _button(0),
      const SizedBox(width: 8, child: Divider(color: Color(0xFFDBE9F5))),
      _button(1),
      if (thirdStep) ...[
        const SizedBox(width: 8, child: Divider(color: Color(0xFFDBE9F5))),
        _button(2),
      ],
    ],
  );
}
