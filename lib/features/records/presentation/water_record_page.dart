import '../../../core/widgets/app_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_design.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/word_wrap_text.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/health_record.dart';
import '../domain/water_record.dart';
import 'records_controller.dart';
import 'water_cup_rating.dart';

class WaterRecordPage extends ConsumerStatefulWidget {
  const WaterRecordPage({super.key, this.record, this.initialRecordedAt});
  final HealthRecord? record;
  final DateTime? initialRecordedAt;
  @override
  ConsumerState<WaterRecordPage> createState() => _WaterRecordPageState();
}

class _WaterRecordPageState extends ConsumerState<WaterRecordPage> {
  late DateTime _day;
  int _cups = 0;
  bool _loaded = false, _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _day = waterDay(
      widget.record?.recordedAt ?? widget.initialRecordedAt ?? DateTime.now(),
    );
    if (widget.record != null) {
      _cups = requireWaterCups(widget.record!.data['cups']);
      _loaded = true;
    }
  }

  HealthRecord? _existing(List<HealthRecord> records, DateTime day) => records
      .where(
        (r) =>
            r.type == HealthRecordType.water && waterDay(r.recordedAt) == day,
      )
      .firstOrNull;
  Future<void> _date() async {
    final chosen = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(1),
      lastDate: DateTime.now(),
    );
    if (chosen == null || !mounted) return;
    final existing = _existing(
      ref.read(recordsProvider).value ?? [],
      waterDay(chosen),
    );
    if (widget.record != null &&
        existing != null &&
        existing.id != widget.record!.id) {
      setState(() => _error = '그 날짜에는 물 기록이 있어요. 해당 날짜의 기록에서 수정해 주세요.');
      return;
    }
    setState(() {
      _day = waterDay(chosen);
      if (widget.record == null) {
        _cups = existing == null ? 0 : requireWaterCups(existing.data['cups']);
      }
      _error = null;
    });
  }

  Future<void> _save() async {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null || !_loaded || _saving) return;
    if (_day.isAfter(waterDay(DateTime.now()))) {
      setState(() => _error = '오늘과 지난 날짜만 기록할 수 있어요.');
      return;
    }
    final existing =
        widget.record ?? _existing(ref.read(recordsProvider).value ?? [], _day);
    final record = HealthRecord(
      id: existing?.id ?? 'water-${DateTime.now().microsecondsSinceEpoch}',
      userId: user.id,
      type: HealthRecordType.water,
      recordedAt: _day,
      title: '물 마시기',
      summary: '$_cups컵',
      data: {'cups': _cups},
    );
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(recordsProvider.notifier)
          .saveWater(record, editing: existing != null);
      if (mounted) {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/home');
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '저장하지 못했어요. 선택한 컵 수는 유지돼요. 다시 시도해 주세요.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recordsProvider);
    if (!_loaded && state.hasValue) {
      final old = _existing(state.value!, _day);
      _cups = old == null ? 0 : requireWaterCups(old.data['cups']);
      _loaded = true;
    }
    return AppScaffold(
      appBar: AppBar(title: const Text('물 마시기')),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(20),
        child: FilledButton(
          key: const ValueKey('water-save'),
          onPressed: !_loaded || _saving ? null : _save,
          child: Text(_saving ? '저장 중…' : '$_cups컵 저장'),
        ),
      ),
      body: !_loaded
          ? state.hasError
                ? Center(
                    child: TextButton(
                      onPressed: () => ref.invalidate(recordsProvider),
                      child: const Text('기록 다시 불러오기'),
                    ),
                  )
                : const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                AppCard(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    key: const ValueKey('water-date'),
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: Text(
                      '${_day.year}.${_day.month.toString().padLeft(2, '0')}.${_day.day.toString().padLeft(2, '0')}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _saving ? null : _date,
                  ),
                ),
                const SizedBox(height: 16),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 22),
                      Center(
                        child: WordWrapText(
                          _day == waterDay(DateTime.now())
                              ? '오늘 마신 물'
                              : '이날 마신 물',
                          style: AppDesign.sectionTitle,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          '$_cups컵',
                          key: const ValueKey('water-cup-count'),
                          style: AppDesign.metric.copyWith(fontSize: 32),
                        ),
                      ),
                      const SizedBox(height: 18),
                      WaterCupRating(
                        value: _cups,
                        onChanged: _saving
                            ? null
                            : (v) => setState(() => _cups = v),
                      ),
                      const SizedBox(height: 14),
                      const WordWrapText(
                        '컵을 누르거나 좌우로 밀어 선택해요.',
                        style: AppDesign.caption,
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton(
                          onPressed: _saving
                              ? null
                              : () => setState(() => _cups = 0),
                          child: const Text('선택 지우기'),
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: WordWrapText(
                      _error!,
                      style: AppDesign.body.copyWith(color: Colors.red),
                    ),
                  ),
              ],
            ),
    );
  }
}
