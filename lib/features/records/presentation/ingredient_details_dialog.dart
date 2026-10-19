import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../meal_analysis/data/ingredient_cache.dart';

typedef ProductIdentityLookup =
    Future<Map<String, dynamic>> Function(String name);
Future<Map<String, dynamic>> _identity(String name) async {
  final response = await Supabase.instance.client.functions.invoke(
    'product-nutrition',
    body: {'query': name},
  );
  return Map<String, dynamic>.from(response.data as Map);
}

class IngredientDetailsDialog extends StatefulWidget {
  const IngredientDetailsDialog({
    super.key,
    required this.item,
    this.fetcher,
    this.lookup,
  });
  final Map item;
  final IngredientFetcher? fetcher;
  final ProductIdentityLookup? lookup;
  @override
  State<IngredientDetailsDialog> createState() =>
      _IngredientDetailsDialogState();
}

class _IngredientDetailsDialogState extends State<IngredientDetailsDialog> {
  bool _loading = true;
  String? _message;
  Map<String, dynamic>? _data;
  List<Map> _candidates = [];
  String? _report, _company;
  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final source = widget.item['nutrition_source'];
    final report = source is Map
        ? source['reportNumber']?.toString() ?? ''
        : '';
    final company = source is Map
        ? (source['manufacturer'] ?? source['company'])?.toString() ?? ''
        : '';
    if (RegExp(r'^\d{5,30}$').hasMatch(report)) {
      await _load(report, company);
      return;
    }
    setState(() => _loading = true);
    try {
      final data = await (widget.lookup ?? _identity)(
        widget.item['name']?.toString() ?? '',
      ).timeout(const Duration(seconds: 8));
      if (!mounted) {
        return;
      }
      setState(() {
        _candidates = (data['candidates'] as List? ?? [])
            .whereType<Map>()
            .toList();
        if (_candidates.isEmpty) {
          _message = data['status'] == 'not_found'
              ? '원재료 조회용 제품 정보를 찾지 못했어요. 포장 표시를 확인해 주세요.'
              : '제품 정보에 연결하지 못했어요. 다시 시도할 수 있어요.';
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => _message = '제품 조회가 지연되거나 연결되지 않았어요. 다시 시도할 수 있어요.');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _load(String report, String company) async {
    _report = report;
    _company = company;
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final data = await (widget.fetcher ?? cachedIngredients)(
        report,
        company,
      ).timeout(const Duration(seconds: 8));
      if (!mounted) {
        return;
      }
      setState(() {
        if (data['status'] == 'ingredients') {
          _data = data;
          _candidates = [];
        } else {
          _message = switch (data['status']) {
            'not_found' => '등록된 원재료 정보가 없어요. 포장 표시를 확인해 주세요.',
            'not_configured' ||
            'authentication_failed' => '원재료 정보 연결 설정을 확인해야 해요.',
            'quota_exceeded' => '원재료 서비스의 조회 한도에 도달했어요.',
            'identity_mismatch' => '요청한 품목번호와 다른 결과라 표시하지 않았어요.',
            _ => '원재료 조회가 지연되거나 연결되지 않았어요. 다시 시도할 수 있어요.',
          };
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => _message = '원재료 조회가 지연되거나 연결되지 않았어요. 다시 시도할 수 있어요.');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('원재료 정보'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.item['name']?.toString() ?? '음식'),
            const SizedBox(height: 12),
            const Text('현재 조회된 정보예요. 기록 당시 제품과 다를 수 있어요.'),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(_message!),
              ),
            if (_candidates.isNotEmpty)
              const Text('기록한 제품의 제조사·맛·규격을 확인해 선택해 주세요.'),
            for (final product in _candidates)
              ListTile(
                title: Text(product['name']?.toString() ?? ''),
                subtitle: Text(
                  '${product['manufacturer'] ?? ''} · ${product['packageSizeText'] ?? ''}',
                ),
                enabled:
                    !_loading &&
                    RegExp(
                      r'^\d{5,30}$',
                    ).hasMatch(product['reportNumber']?.toString() ?? ''),
                onTap: () => _load(
                  product['reportNumber'].toString(),
                  product['manufacturer']?.toString() ?? '',
                ),
              ),
            if (_data != null) ...[
              if (_data!['companyVerified'] != true)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('업체명 표기가 기록과 달라요. 포장과 대조해 주세요.'),
                ),
              if (_data!['fromCache'] == true)
                const Text('오늘 조회한 정보를 다시 보여주고 있어요.'),
              if (_data!['hasMore'] == true) const Text('전체 목록이 아닌 일부 결과예요.'),
              for (final row
                  in (_data!['rows'] as List? ?? []).whereType<Map>()) ...[
                const SizedBox(height: 12),
                Text(row['ingredientText']?.toString() ?? ''),
                Text(
                  '업체: ${row['company'] ?? ''} · 변경일: ${row['changedAt'] ?? '미확인'}',
                ),
              ],
              const SizedBox(height: 12),
              const Text('알레르기 표시·같은 시설 제조 정보는 미확인이에요.'),
            ],
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(12),
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
    ),
    actions: [
      if (!_loading && _message != null)
        TextButton(
          onPressed: () =>
              _report == null ? _open() : _load(_report!, _company ?? ''),
          child: const Text('다시 조회'),
        ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('닫기'),
      ),
    ],
  );
}
