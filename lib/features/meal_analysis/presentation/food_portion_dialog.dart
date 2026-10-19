import 'package:flutter/material.dart';
import '../domain/meal_analysis.dart';

class FoodPortionDialog extends StatefulWidget {
  const FoodPortionDialog({super.key, required this.food, this.enablePortion});
  final FoodCandidate food;
  final bool? enablePortion;
  @override
  State<FoodPortionDialog> createState() => _FoodPortionDialogState();
}

class _FoodPortionDialogState extends State<FoodPortionDialog> {
  late bool _enabled;
  late final TextEditingController _total, _calories, _consumed;
  String? _error;
  @override
  void initState() {
    super.initState();
    _enabled = widget.enablePortion ?? widget.food.portioned;
    _total = TextEditingController(text: _number(widget.food.wholeAmountG));
    _calories = TextEditingController(text: _number(widget.food.wholeCalories));
    _consumed = TextEditingController(text: _number(widget.food.amountG));
  }

  String _number(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
  @override
  void dispose() {
    _total.dispose();
    _calories.dispose();
    _consumed.dispose();
    super.dispose();
  }

  double? get _preview {
    final total = double.tryParse(_total.text),
        calories = double.tryParse(_calories.text),
        amount = double.tryParse(_consumed.text);
    if (total == null ||
        !total.isFinite ||
        total <= 0 ||
        calories == null ||
        !calories.isFinite ||
        calories < 0 ||
        amount == null ||
        !amount.isFinite ||
        amount <= 0 ||
        (_enabled && amount > total)) {
      return null;
    }
    final result =
        calories *
        (amount / total) *
        (widget.food.isProduct ? widget.food.quantity : 1);
    return result.isFinite ? result : null;
  }

  void _apply() {
    if (_preview == null) {
      setState(() => _error = '전체 용량과 열량을 확인해 주세요. 먹은 양은 전체 용량 이하여야 해요.');
      return;
    }
    Navigator.pop(
      context,
      widget.food.withPortion(
        totalG: double.parse(_total.text),
        totalKcal: double.parse(_calories.text),
        consumedG: double.parse(_consumed.text),
        enabled: _enabled,
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    String suffix,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => setState(() => _error = null),
      decoration: InputDecoration(labelText: label, suffixText: suffix),
    ),
  );
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.food.name),
    content: SizedBox(
      width: 360,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('소분해서 먹었어요'),
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v ?? false),
            ),
            if (_enabled) ...[
              const Text('포장 전체 용량과 열량을 확인한 뒤 먹은 양을 입력해 주세요.'),
              const SizedBox(height: 16),
              _field(
                _total,
                widget.food.isProduct ? '1개 전체 용량' : '전체 용량',
                widget.food.amountUnit,
              ),
              _field(
                _calories,
                widget.food.isProduct ? '1개 전체 열량' : '전체 열량',
                'kcal',
              ),
            ],
            _field(
              _consumed,
              widget.food.isProduct ? '1개당 먹은 양' : '먹은 양',
              widget.food.amountUnit,
            ),
            Text(
              _preview == null
                  ? '입력값을 확인해 주세요.'
                  : '섭취 열량 ${_preview!.toStringAsFixed(1)} kcal',
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('취소'),
      ),
      FilledButton(onPressed: _apply, child: const Text('적용')),
    ],
  );
}

class FoodPortionControl extends StatelessWidget {
  const FoodPortionControl({
    super.key,
    required this.food,
    required this.onChanged,
  });
  final FoodCandidate food;
  final ValueChanged<FoodCandidate> onChanged;
  Future<void> edit(BuildContext context, {bool? enabled}) async {
    final updated = await showDialog<FoodCandidate>(
      context: context,
      builder: (_) => FoodPortionDialog(food: food, enablePortion: enabled),
    );
    if (updated != null) onChanged(updated);
  }

  @override
  Widget build(BuildContext context) => CheckboxListTile(
    contentPadding: EdgeInsets.zero,
    title: const Text('소분해서 먹었어요'),
    subtitle: food.portioned
        ? Text(
            '전체 ${food.wholeAmountG}${food.amountUnit} 중 ${food.amountG}${food.amountUnit} · ${(food.amountG / food.wholeAmountG * 100).toStringAsFixed(1)}%',
          )
        : null,
    value: food.portioned,
    onChanged: (value) {
      if (value == true) {
        edit(context, enabled: true);
      } else {
        onChanged(food.copyWith(portioned: false, amountG: food.wholeAmountG));
      }
    },
    secondary: food.portioned
        ? TextButton(
            onPressed: () => edit(context, enabled: true),
            child: const Text('수정'),
          )
        : null,
  );
}

class ProductQuantityControl extends StatelessWidget {
  const ProductQuantityControl({
    super.key,
    required this.food,
    required this.onChanged,
  });
  final FoodCandidate food;
  final ValueChanged<FoodCandidate> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        const Expanded(child: Text('상품 개수')),
        IconButton(
          tooltip: '개수 줄이기',
          onPressed: food.quantity > 1
              ? () => onChanged(food.copyWith(quantity: food.quantity - 1))
              : null,
          icon: const Icon(Icons.remove),
        ),
        Text('${food.quantity}개'),
        IconButton(
          tooltip: '개수 늘리기',
          onPressed: food.quantity < 99
              ? () => onChanged(food.copyWith(quantity: food.quantity + 1))
              : null,
          icon: const Icon(Icons.add),
        ),
      ],
    ),
  );
}
