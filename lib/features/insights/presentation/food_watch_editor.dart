import '../../../core/widgets/app_scaffold.dart';
import 'package:flutter/material.dart';
import '../../../app/theme/app_design.dart';
import '../../../core/widgets/word_wrap_text.dart';
import '../../records/domain/health_record.dart';
import '../domain/food_observation.dart';

class FoodWatchEditor extends StatefulWidget {
  const FoodWatchEditor({
    super.key,
    this.watch,
    required this.records,
    required this.onSave,
    required this.onDelete,
  });
  final FoodWatch? watch;
  final List<HealthRecord> records;
  final Future<void> Function(FoodWatch) onSave;
  final Future<void> Function() onDelete;
  @override
  State<FoodWatchEditor> createState() => _FoodWatchEditorState();
}

class _FoodWatchEditorState extends State<FoodWatchEditor> {
  late final _name = TextEditingController(text: widget.watch?.name);
  final _alias = TextEditingController();
  late final _aliases = {...?widget.watch?.aliases};
  late final _symptoms = {...widget.watch?.symptoms ?? observationSymptoms};
  String? _error;
  bool _busy = false;
  String _query = '';
  @override
  void dispose() {
    _name.dispose();
    _alias.dispose();
    super.dispose();
  }

  Future<void> _submit({bool delete = false}) async {
    final name = _name.text.trim();
    final aliases = {
      ..._aliases,
      if (_alias.text.trim().isNotEmpty) _alias.text.trim(),
    };
    if (!delete && (name.isEmpty || aliases.isEmpty || _symptoms.isEmpty)) {
      setState(() => _error = '관찰 이름, 포함할 음식 이름, 증상을 각각 선택해 주세요.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (delete) {
        await widget.onDelete();
      } else {
        await widget.onSave(
          FoodWatch(
            id:
                widget.watch?.id ??
                'watch-${DateTime.now().microsecondsSinceEpoch}',
            name: name,
            aliases: aliases.toList(),
            symptoms: _symptoms.toList(),
          ),
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = '저장하지 못했어요. 연결을 확인하고 다시 시도해 주세요.';
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final names = {..._aliases, ...recordedFoodNames(widget.records)}.toList()
      ..sort();
    return AppScaffold(
      appBar: AppBar(
        title: Text(widget.watch == null ? '관찰 음식 추가' : '포함할 음식 설정'),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: Text(_busy ? '저장 중…' : '관찰 음식 저장'),
              ),
              if (widget.watch != null)
                TextButton(
                  onPressed: _busy ? null : () => _submit(delete: true),
                  child: const Text('관찰 목록에서 삭제'),
                ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          TextField(
            controller: _name,
            maxLength: 60,
            decoration: const InputDecoration(
              labelText: '관찰 이름',
              hintText: '예: 돈까스',
            ),
          ),
          const SizedBox(height: 18),
          const WordWrapText('함께 볼 기록 이름', style: AppDesign.sectionTitle),
          const SizedBox(height: 8),
          const WordWrapText(
            '포함할 이름을 직접 확인해요. 띄어쓰기만 다른 이름은 함께 검색돼요.',
            style: AppDesign.caption,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _alias,
            maxLength: 120,
            decoration: InputDecoration(
              labelText: '음식 이름 직접 추가',
              suffixIcon: IconButton(
                icon: const Icon(Icons.add),
                onPressed: _busy
                    ? null
                    : () {
                        if (_alias.text.trim().isNotEmpty) {
                          setState(() {
                            _aliases.add(_alias.text.trim());
                            _alias.clear();
                          });
                        }
                      },
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            decoration: const InputDecoration(
              labelText: '기록에서 음식 찾기',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final alias in _aliases)
                InputChip(
                  label: Text(alias),
                  onDeleted: _busy
                      ? null
                      : () => setState(() => _aliases.remove(alias)),
                ),
            ],
          ),
          for (final name
              in names
                  .where((s) => foodKey(s).contains(foodKey(_query)))
                  .take(30))
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: WordWrapText(name, style: AppDesign.body),
              value: _aliases.contains(name),
              onChanged: _busy
                  ? null
                  : (v) => setState(() {
                      if (v == true) {
                        _aliases.add(name);
                      } else {
                        _aliases.remove(name);
                      }
                    }),
            ),
          const SizedBox(height: 18),
          const WordWrapText('관찰할 증상', style: AppDesign.sectionTitle),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in observationSymptoms)
                FilterChip(
                  label: Text(s),
                  selected: _symptoms.contains(s),
                  onSelected: _busy
                      ? null
                      : (v) => setState(() {
                          if (v) {
                            _symptoms.add(s);
                          } else {
                            _symptoms.remove(s);
                          }
                        }),
                ),
            ],
          ),
          const SizedBox(height: 22),
          const WordWrapText(
            '섭취 당일·다음날의 변화를 살펴봐요. 연결한 증상은 종료 기록까지 이어서 볼 수 있어요.',
            style: AppDesign.body,
          ),
          const SizedBox(height: 10),
          const WordWrapText(
            '제품·용량·영양정보는 합치지 않고 원본에 유지해요.',
            style: AppDesign.caption,
          ),
        ],
      ),
    );
  }
}
