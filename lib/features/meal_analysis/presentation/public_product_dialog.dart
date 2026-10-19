import '../data/ingredient_cache.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/meal_analysis.dart';
import '../domain/public_product.dart';

typedef PublicProductLookup =
    Future<Map<String, dynamic>> Function(String query, int page);

Future<Map<String, dynamic>> _lookup(String query, int page) async {
  final response = await Supabase.instance.client.functions.invoke(
    'product-nutrition',
    body: {'query': query, 'page': page},
  );
  return Map<String, dynamic>.from(response.data as Map);
}

typedef IngredientLookup =
    Future<Map<String, dynamic>> Function(String report, String company);

class PublicProductDialog extends StatefulWidget {
  const PublicProductDialog({
    super.key,
    required this.photo,
    this.lookup,
    this.onManual,
    this.ingredientLookup,
  });
  final PublicProductLookup? lookup;
  final IngredientLookup? ingredientLookup;
  final VoidCallback? onManual;
  final IdentifiedProduct photo;
  @override
  State<PublicProductDialog> createState() => _PublicProductDialogState();
}

class _PublicProductDialogState extends State<PublicProductDialog> {
  List<PublicProduct> _products = [];
  String? _message;
  bool _loading = true, _hasMore = false;
  int _page = 1;
  late final TextEditingController _query;
  String? _resolvedQuery;
  bool _searchAdjusted = false;
  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _query = TextEditingController(text: widget.photo.name);
    _load();
  }

  bool _ingredientsLoading = false;
  final Map<String, String> _ingredientMessages = {};

  Future<void> _loadIngredients(PublicProduct product) async {
    if (_ingredientsLoading) return;
    final id = product.data['id']?.toString() ?? product.name;
    final report = product.data['reportNumber']?.toString() ?? '';
    setState(() => _ingredientsLoading = true);
    try {
      final data = await (widget.ingredientLookup ?? cachedIngredients)(
        report,
        product.manufacturer,
      ).timeout(const Duration(seconds: 8));
      if (!mounted) return;
      setState(() {
        if (data['status'] == 'ingredients' && data['hasMore'] == false) {
          final rows = (data['rows'] as List).whereType<Map>();
          _ingredientMessages[id] =
              '공공데이터 원재료: ${rows.map((r) => r['ingredientText']).join(' / ')}\n${data['companyVerified'] == true ? '' : '업체명 표기가 달라요. 포장과 대조해 주세요.\n'}알레르기 표시·같은 시설 제조 정보는 미확인이에요.';
        } else {
          _ingredientMessages[id] = switch (data['status']) {
            'not_configured' ||
            'authentication_failed' => '원재료 정보 연결 설정이 준비되지 않았어요.',
            'not_found' => '등록된 원재료 정보를 찾지 못했어요. 포장 표시를 확인해 주세요.',
            'ingredients' || 'identity_mismatch' =>
              '업체 일치 또는 전체 목록을 확인하지 못했어요. 원재료 정보는 적용하지 않았어요.',
            'timeout' => '원재료 조회가 지연되고 있어요. 다시 시도할 수 있어요.',
            'quota_exceeded' => '원재료 서비스의 조회 한도에 도달했어요.',
            _ => '원재료 정보에 연결하지 못했어요. 다시 시도할 수 있어요.',
          };
        }
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _ingredientMessages[id] = '원재료 정보에 연결하지 못했어요. 다시 시도할 수 있어요.',
        );
      }
    } finally {
      if (mounted) setState(() => _ingredientsLoading = false);
    }
  }

  Future<void> _load({bool next = false}) async {
    setState(() {
      _loading = true;
      _message = null;
    });
    final page = next ? _page + 1 : 1;
    final query = next
        ? (_resolvedQuery ?? _query.text.trim())
        : _query.text.trim();
    if (query.isEmpty) {
      setState(() {
        _loading = false;
        _message = '검색할 제품명을 입력해 주세요.';
      });
      return;
    }
    if (!next) {
      _products = [];
      _hasMore = false;
    }
    try {
      final data = await (widget.lookup ?? _lookup)(
        query,
        page,
      ).timeout(const Duration(seconds: 8));
      final status = data['status'];
      if (!mounted) return;
      setState(() {
        if (status == 'candidates') {
          _resolvedQuery = data['searchedQuery']?.toString() ?? query;
          _searchAdjusted = data['searchAdjusted'] == true;
          final products = (data['candidates'] as List)
              .whereType<Map>()
              .map((p) => PublicProduct(Map<String, dynamic>.from(p)))
              .toList();
          _products = next ? [..._products, ...products] : products;
          _page = page;
          _hasMore = data['hasMore'] == true;
        } else {
          _message = switch (status) {
            'not_found' =>
              '제품명 표기를 바꿔 조회했지만 후보를 찾지 못했어요. 제품명을 수정해 검색하거나 영양표를 촬영해 주세요.',
            'not_configured' || 'authentication_failed' =>
              '제품 정보 연결 설정이 준비되지 않았어요. 직접 입력으로 기록할 수 있어요.',
            'timeout' => '제품 조회가 지연되고 있어요. 다시 조회하거나 직접 입력해 주세요.',
            'quota_exceeded' => '제품 정보 서비스의 조회 한도에 도달했어요. 직접 입력으로 기록할 수 있어요.',
            _ => '제품 정보에 연결하지 못했어요. 다시 조회하거나 직접 입력해 주세요.',
          };
        }
      });
    } on TimeoutException {
      if (mounted) {
        setState(() => _message = '제품 조회가 지연되고 있어요. 다시 조회하거나 직접 입력해 주세요.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = '제품 조회에 연결하지 못했어요. 다시 조회하거나 직접 입력해 주세요.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('영양정보 확인'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('사진에서 읽은 이름: ${widget.photo.name}'),
            const SizedBox(height: 8),
            TextField(
              controller: _query,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: '제품명 검색',
                helperText: '잘못 읽은 글자나 브랜드·맛 표기를 수정할 수 있어요.',
              ),
              onSubmitted: (_) {
                if (!_loading) _load();
              },
            ),
            TextButton(
              onPressed: _loading ? null : () => _load(),
              child: const Text('제품명으로 검색'),
            ),
            if (_searchAdjusted && _products.isNotEmpty)
              Text('검색 표기 보정: $_resolvedQuery · 같은 제품인지 확인해 주세요.'),
            const SizedBox(height: 8),
            const Text('음식·제품명과 용량을 확인해 주세요. 상품은 제조사와 맛도 같은지 확인해 주세요.'),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(_message!),
              ),
            if (_products.isNotEmpty)
              const Text('규격은 박스 전체일 수 있어요. 사진의 낱봉지·맛·제조사와 같은지 확인해 주세요.'),
            for (final product in _products)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.name),
                      Text(
                        '업체: ${product.manufacturer.isEmpty ? "미확인" : product.manufacturer}',
                      ),
                      Text(
                        '규격: ${product.packageText.isEmpty ? "미확인" : product.packageText} · 기준량: ${product.basisText}',
                      ),
                      Text(
                        '데이터 기준일: ${product.referenceDate.isEmpty ? "미확인" : product.referenceDate}',
                      ),
                      if (product.confirmedFood(widget.photo) == null)
                        const Text('용량·열량 대조가 필요해요. 이 후보는 자동 적용할 수 없어요.')
                      else
                        Text(
                          '${product.confirmedFood(widget.photo)!.wholeCalories.round()} kcal / ${product.isProduct ? '1개' : '표시 용량'}',
                        ),
                      if (RegExp(r'^\d{5,30}$').hasMatch(
                        product.data['reportNumber']?.toString() ?? '',
                      ))
                        TextButton(
                          onPressed: _ingredientsLoading
                              ? null
                              : () => _loadIngredients(product),
                          child: const Text('원재료 정보 확인'),
                        ),
                      if (_ingredientMessages[product.data['id']?.toString() ??
                              product.name] !=
                          null)
                        Text(
                          _ingredientMessages[product.data['id']?.toString() ??
                              product.name]!,
                        ),
                      TextButton(
                        onPressed:
                            _loading ||
                                _ingredientsLoading ||
                                product.confirmedFood(widget.photo) == null
                            ? null
                            : () => Navigator.pop(
                                context,
                                product.confirmedFood(widget.photo),
                              ),
                        child: Text(
                          product.isProduct ? '현재 제품과 같아요' : '이 음식으로 기록하기',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(12),
                child: LinearProgressIndicator(),
              ),
            if (!_loading && _hasMore)
              TextButton(
                onPressed: () => _load(next: true),
                child: const Text('다른 후보 더 보기'),
              ),
          ],
        ),
      ),
    ),
    actions: [
      if (widget.onManual != null)
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            widget.onManual!();
          },
          child: const Text('사진 첨부해 직접 입력'),
        ),
      if (!_loading && _message != null)
        TextButton(onPressed: () => _load(), child: const Text('다시 조회')),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('닫기'),
      ),
    ],
  );
}
