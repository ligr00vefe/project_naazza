import 'package:flutter/material.dart';

class FoodSearchRequest {
  const FoodSearchRequest(this.name, {this.search = true});
  final String name;
  final bool search;
}

class FoodSearchDialog extends StatefulWidget {
  const FoodSearchDialog({super.key});
  @override
  State<FoodSearchDialog> createState() => _FoodSearchDialogState();
}

class _FoodSearchDialogState extends State<FoodSearchDialog> {
  final _name = TextEditingController();
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit(bool search) {
    final name = _name.text.trim();
    if (name.isNotEmpty) {
      Navigator.pop(context, FoodSearchRequest(name, search: search));
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('음식 추가'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('검색하면 AI가 영양정보를 추정해요. 이름만 추가하면 열량은 미기록으로 남아요.'),
        const SizedBox(height: 16),
        TextField(
          controller: _name,
          autofocus: true,
          maxLength: 80,
          decoration: const InputDecoration(labelText: '음식 이름'),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('취소'),
      ),
      TextButton(onPressed: () => _submit(false), child: const Text('이름만 추가')),
      FilledButton(
        onPressed: () => _submit(true),
        child: const Text('영양정보 검색'),
      ),
    ],
  );
}
