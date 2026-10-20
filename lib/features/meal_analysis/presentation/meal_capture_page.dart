import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/record_datetime_field.dart';
import '../../records/domain/record_draft_date.dart';
import 'public_product_dialog.dart';
import '../domain/photo_food_resolution.dart';
import '../../records/presentation/meal_record_page.dart';
import '../domain/photo_failure.dart';
import 'photo_analysis_policy.dart';
import 'food_portion_dialog.dart';
import 'food_search_dialog.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../app/theme/app_colors.dart';
import '../../auth/data/auth_repository.dart';
import '../../records/domain/health_record.dart';
import '../../records/presentation/records_controller.dart';
import '../../records/presentation/meal_category_selector.dart';
import '../data/meal_analysis_repository.dart';
import '../domain/meal_analysis.dart';

class MealCapturePage extends ConsumerStatefulWidget {
  const MealCapturePage({
    super.key,
    this.pickImage,
    this.autoLookup = true,
    this.publicLookup,
    this.initialRecordedAt,
  });
  final bool autoLookup;
  final DateTime? initialRecordedAt;
  final PublicProductLookup? publicLookup;
  final Future<XFile?> Function(ImageSource source)? pickImage;
  @override
  ConsumerState<MealCapturePage> createState() => _MealCapturePageState();
}

class _MealCapturePageState extends ConsumerState<MealCapturePage> {
  final _picker = ImagePicker();
  MealAnalysisRepository? _photoRepository;
  int _analysisVersion = 0;
  int _failureCount = 0;
  PhotoFailure? _failureReason;
  bool get _suggestManual =>
      _failureCount >= 2 ||
      _failureReason == PhotoFailure.productUnidentified ||
      _failureReason == PhotoFailure.rateLimited;
  Uint8List? _imageBytes;
  String _filename = 'meal.jpg';
  String? _photoPath;
  List<FoodCandidate> _foods = [];
  List<IdentifiedProduct> _identifiedProducts = [];
  bool _analyzing = false;
  bool _takingLong = false;
  bool _smallMeal = false;
  DateTime _eatenAt = DateTime.now();
  String _mealType = 'meal';
  bool _saved = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _eatenAt = widget.initialRecordedAt ?? DateTime.now();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final file =
          await (widget.pickImage?.call(source) ??
              _picker.pickImage(
                source: source,
                maxWidth: 1600,
                maxHeight: 1600,
                imageQuality: 82,
              ));
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      unawaited(
        ref.read(mealAnalysisRepositoryProvider).discardPhoto(_photoPath),
      );
      _photoPath = null;
      _foods = [];
      _identifiedProducts = [];
      _imageBytes = bytes;
      _filename = file.name;
      _failureCount = 0;
      _failureReason = null;
      if (mounted) setState(() {});
      await _analyze();
    } catch (error) {
      if (mounted) setState(() => _error = '이미지를 불러오지 못했어요. 다시 선택해 주세요.');
    }
  }

  String _failureMessage(PhotoFailure reason) {
    _failureCount++;
    _failureReason = reason;
    return photoFailureMessage(
      timedOut: reason == PhotoFailure.timeout,
      failures: _failureCount,
      reason: reason,
    );
  }

  Future<void> _analyze() async {
    if (_analyzing) return;
    final bytes = _imageBytes;
    if (bytes == null) return;
    final version = ++_analysisVersion;
    setState(() {
      _analyzing = true;
      _takingLong = false;
      _error = null;
    });
    try {
      if (_photoPath != null) {
        unawaited(
          ref.read(mealAnalysisRepositoryProvider).discardPhoto(_photoPath),
        );
        _photoPath = null;
      }
      final user = ref.read(authRepositoryProvider).currentUser!;
      final repository = ref.read(mealAnalysisRepositoryProvider);
      _photoRepository = repository;
      var expired = false;
      final request = repository
          .analyze(userId: user.id, imageBytes: bytes, filename: _filename)
          .then(resolvePhotoFoods);
      unawaited(
        request.then<void>((result) {
          if (expired || !mounted || version != _analysisVersion) {
            unawaited(repository.discardPhoto(result.photoPath));
          }
        }, onError: (Object error, StackTrace stack) {}),
      );
      final MealAnalysisResult result;
      try {
        result = await runPhotoAnalysis(
          request,
          onSlow: () {
            if (mounted && version == _analysisVersion) {
              setState(() => _takingLong = true);
            }
          },
        );
      } on TimeoutException {
        expired = true;
        rethrow;
      }
      if (!mounted || version != _analysisVersion) return;
      setState(() {
        _foods = result.foods;
        _identifiedProducts = result.identifiedProducts;
        _photoPath = result.photoPath;
        if (result.foods.isNotEmpty) {
          _failureCount = 0;
          _failureReason = null;
        }
        if (result.foods.isEmpty && result.identifiedProducts.isEmpty) {
          _error = _failureMessage(result.failure ?? PhotoFailure.unknown);
        }
      });
      if (widget.autoLookup) {
        final products = [
          ...result.identifiedProducts,
          for (final food in result.foods.where((food) => food.isProduct))
            IdentifiedProduct(
              name: food.name,
              amountText: '${food.wholeAmountG}${food.amountUnit}',
              energyKcal: food.wholeCalories,
              confidence: food.confidence,
            ),
        ];
        if (products.length == 1) {
          setState(() {
            _analyzing = false;
            _takingLong = false;
          });
          final product = products.single;
          final index = _foods.indexWhere(
            (food) => food.isProduct && food.name == product.name,
          );
          await _lookupPublicProduct(
            product,
            replaceIndex: index < 0 ? null : index,
          );
        }
      }
    } catch (error) {
      if (mounted && version == _analysisVersion) {
        final reason = error is PhotoAnalysisException
            ? error.reason
            : error is TimeoutException
            ? PhotoFailure.timeout
            : null;
        setState(
          () => _error = reason != null
              ? _failureMessage(reason)
              : _failureMessage(PhotoFailure.unknown),
        );
      }
    } finally {
      if (mounted && version == _analysisVersion) {
        setState(() {
          _analyzing = false;
          _takingLong = false;
        });
      }
    }
  }

  void _cancelAnalysis() {
    if (!_analyzing) return;
    _analysisVersion++;
    setState(() {
      _analyzing = false;
      _takingLong = false;
      _error = null;
    });
  }

  Future<void> _lookupPublicProduct(
    IdentifiedProduct product, {
    int? replaceIndex,
  }) async {
    final food = await showDialog<FoodCandidate>(
      context: context,
      builder: (_) => PublicProductDialog(
        photo: product,
        lookup: widget.publicLookup,
        onManual: () => _manualEntry(product: product),
      ),
    );
    if (!mounted || food == null) return;
    setState(() {
      if (replaceIndex != null && replaceIndex < _foods.length) {
        final previous = _foods[replaceIndex];
        var replacement = food.copyWith(quantity: previous.quantity);
        if (previous.portioned) {
          replacement = replacement.withPortion(
            totalG: food.wholeAmountG,
            totalKcal: food.wholeCalories,
            consumedG: previous.amountG,
            enabled: true,
          );
        }
        _foods[replaceIndex] = replacement;
      } else {
        _foods.add(food);
      }
      _identifiedProducts.remove(product);
    });
  }

  void _manualEntry({IdentifiedProduct? product}) {
    _cancelAnalysis();
    product ??= _identifiedProducts.length == 1
        ? _identifiedProducts.first
        : null;
    context.push(
      recordDateRoute('/record/meal', _eatenAt),
      extra: _imageBytes == null
          ? null
          : ManualMealPhoto(
              bytes: _imageBytes!,
              filename: _filename,
              productName: product?.name,
              amountText: product?.amountText,
              energyKcal: product?.energyKcal,
            ),
    );
  }

  Future<void> _searchAndAdd() async {
    final request = await showDialog<FoodSearchRequest>(
      context: context,
      builder: (_) => const FoodSearchDialog(),
    );
    if (request == null || !mounted) return;
    if (!request.search) {
      setState(() {
        _error = null;
        _foods.add(
          FoodCandidate(
            name: request.name,
            normalizedName: request.name,
            confidence: 1,
            tags: const ['열량미기록'],
            nutrition: const NutritionFacts(
              baseAmountG: 100,
              energyKcal: 0,
              carbohydrateG: 0,
              proteinG: 0,
              fatG: 0,
              sodiumMg: 0,
            ),
          ),
        );
      });
      return;
    }
    await _lookupPublicProduct(
      IdentifiedProduct(name: request.name, confidence: 1),
    );
  }

  Future<void> _editAmount(int index) async {
    final food = await showDialog<FoodCandidate>(
      context: context,
      builder: (_) => FoodPortionDialog(food: _foods[index]),
    );
    if (food != null && mounted) setState(() => _foods[index] = food);
  }

  Future<void> _save() async {
    if (_foods.isEmpty) return;
    final user = ref.read(authRepositoryProvider).currentUser!;
    final total = _foods.fold<double>(
      0,
      (sum, food) => sum + food.consumedNutrition.energyKcal,
    );
    final record = HealthRecord(
      id: 'meal-${DateTime.now().microsecondsSinceEpoch}',
      userId: user.id,
      type: HealthRecordType.meal,
      recordedAt: _eatenAt,
      title: _foods.map((food) => food.name).join(', '),
      summary: '${_foods.length}개 음식 · ${total.round()} kcal',
      data: {
        'meal_type': _mealType,
        'amount_text': '${_foods.length}개 음식',
        'energy_kcal': total,
        'small_meal': _smallMeal,
        'photo_path': _photoPath,
        'items': [for (final food in _foods) food.toRecordItem()],
      },
    );
    await ref.read(recordsProvider.notifier).create(record);
    if (mounted && !ref.read(recordsProvider).hasError) {
      _saved = true;
      if (widget.initialRecordedAt != null && context.canPop()) {
        context.pop();
      } else {
        context.go('/timeline');
      }
    }
  }

  @override
  void dispose() {
    if (!_saved && _photoPath != null) {
      unawaited(_photoRepository?.discardPhoto(_photoPath));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalKcal = _foods.fold<double>(
      0,
      (sum, food) => sum + food.consumedNutrition.energyKcal,
    );
    return AppScaffold(
      appBar: AppBar(title: const Text('음식 사진 기록')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          Text(
            '음식 등록 방식 선택',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const Text(
            '음식이나 제품 포장 사진을 촬영해 주세요. 제품명과 영양표가 잘 보이면 인식에 도움이 돼요. AI 결과는 저장 전에 확인해 주세요.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 18),
          if (_imageBytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Image.memory(_imageBytes!, height: 240, fit: BoxFit.cover),
            )
          else
            Row(
              children: [
                Expanded(
                  child: _SourceCard(
                    icon: Icons.camera_alt_rounded,
                    label: '사진 촬영',
                    onTap: () => _pick(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SourceCard(
                    icon: Icons.photo_library_rounded,
                    label: '앨범 선택',
                    onTap: () => _pick(ImageSource.gallery),
                  ),
                ),
              ],
            ),
          if (_imageBytes != null && !_analyzing && _error == null)
            Row(
              children: [
                TextButton(
                  onPressed: () => _pick(ImageSource.camera),
                  child: const Text('다시 촬영'),
                ),
                TextButton(
                  onPressed: () => _pick(ImageSource.gallery),
                  child: const Text('다른 사진 선택'),
                ),
              ],
            ),
          if (_foods.isEmpty) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: _analyzing ? null : _searchAndAdd,
              child: const Text('음식 검색 또는 이름만 추가'),
            ),
            OutlinedButton.icon(
              onPressed: () =>
                  context.push(recordDateRoute('/record/barcode', _eatenAt)),
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('제품 바코드로 기록'),
            ),
          ],
          if (_analyzing)
            Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(
                    _takingLong
                        ? '분석이 지연되고 있어요. 기다리거나 직접 입력으로 기록할 수 있어요.'
                        : '음식을 분석하고 있어요...',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: _cancelAnalysis,
                        child: const Text('분석 대기 종료'),
                      ),
                      TextButton(
                        onPressed: _manualEntry,
                        child: const Text('사진 첨부해 직접 입력'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (_suggestManual)
                            FilledButton(
                              onPressed: _manualEntry,
                              child: const Text('사진 첨부해 직접 입력'),
                            ),
                          if (_imageBytes != null)
                            if (!_suggestManual &&
                                _failureReason?.isTransport == true)
                              FilledButton(
                                onPressed: _analyzing ? null : _analyze,
                                child: const Text('다시 분석'),
                              )
                            else
                              TextButton(
                                onPressed: _analyzing ? null : _analyze,
                                child: const Text('다시 분석'),
                              ),
                          if (!_suggestManual &&
                              _failureReason?.isTransport != true)
                            FilledButton(
                              onPressed: _analyzing
                                  ? null
                                  : () => _pick(ImageSource.camera),
                              child: const Text('재촬영하기'),
                            )
                          else
                            TextButton(
                              onPressed: _analyzing
                                  ? null
                                  : () => _pick(ImageSource.camera),
                              child: const Text('재촬영하기'),
                            ),
                          TextButton(
                            onPressed: _analyzing
                                ? null
                                : () => _pick(ImageSource.gallery),
                            child: const Text('다른 사진 선택'),
                          ),
                          if (!_suggestManual)
                            TextButton(
                              onPressed: _manualEntry,
                              child: const Text('사진 첨부해 직접 입력'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_identifiedProducts.isNotEmpty && !_analyzing) ...[
            const SizedBox(height: 16),
            Text('제품명을 확인했어요', style: Theme.of(context).textTheme.titleLarge),
            const Text('제품 정보를 조회하거나 사진을 첨부해 직접 입력할 수 있어요.'),
            for (final product in _identifiedProducts)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (product.amountText.isNotEmpty)
                        Text('사진에서 읽은 용량: ${product.amountText}'),
                      Text(
                        product.energyKcal == null
                            ? '열량은 사진에서 확인하지 못했어요.'
                            : '사진에서 읽은 열량: ${product.energyKcal!.round()} kcal',
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => _lookupPublicProduct(product),
                        child: const Text('공공데이터에서 제품 조회'),
                      ),
                      FilledButton(
                        onPressed: () => _manualEntry(product: product),
                        child: const Text('확인한 정보로 기록하기'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
          if (_foods.isNotEmpty) ...[
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '인식된 음식 ${_foods.length}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                TextButton.icon(
                  onPressed: _searchAndAdd,
                  icon: const Icon(Icons.add),
                  label: const Text('음식 추가'),
                ),
              ],
            ),
            for (var index = 0; index < _foods.length; index++) ...[
              _FoodCard(
                food: _foods[index],
                onChanged: (food) => setState(() => _foods[index] = food),
                onAmount: () => _editAmount(index),
                onDelete: () => setState(() => _foods.removeAt(index)),
              ),
              if (_foods[index].isProduct)
                TextButton(
                  onPressed: () => _lookupPublicProduct(
                    IdentifiedProduct(
                      name: _foods[index].name,
                      amountText:
                          '${_foods[index].wholeAmountG}${_foods[index].amountUnit}',
                      energyKcal: _foods[index].wholeCalories,
                    ),
                    replaceIndex: index,
                  ),
                  child: const Text('공공데이터에서 제품 정보 확인'),
                ),
            ],
            RecordDateTimeField(
              label: '식사 시각',
              value: _eatenAt,
              onChanged: (v) => setState(() => _eatenAt = v),
            ),
            const SizedBox(height: 16),
            MealCategorySelector(
              value: _mealType,
              onChanged: (value) => setState(() => _mealType = value),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              title: const Text('소식했어요'),
              subtitle: const Text('평소보다 부담 없이 적게 먹었다면 체크해요.'),
              value: _smallMeal,
              onChanged: (value) => setState(() => _smallMeal = value),
            ),
            if (_foods.any((food) => food.tags.contains('열량미기록')))
              Text('열량 미기록 음식이 있어요. 총합에는 알려진 열량만 포함돼요.'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '총 섭취 열량',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${totalKcal.round()} kcal',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          TextButton(
            onPressed: () =>
                context.push(recordDateRoute('/record/meal', _eatenAt)),
            child: const Text('사진 없이 직접 입력하기'),
          ),
        ],
      ),
      bottomNavigationBar: _foods.isEmpty
          ? null
          : SafeArea(
              minimum: const EdgeInsets.all(20),
              child: FilledButton(
                onPressed: _analyzing || ref.watch(recordsProvider).isLoading
                    ? null
                    : _save,
                child: const Text('식사 저장'),
              ),
            ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Column(
          children: [
            Icon(icon, size: 42, color: AppColors.primary),
            const SizedBox(height: 10),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    ),
  );
}

class _FoodCard extends StatelessWidget {
  const _FoodCard({
    required this.food,
    required this.onAmount,
    required this.onDelete,
    required this.onChanged,
  });
  final FoodCandidate food;
  final VoidCallback onAmount, onDelete;
  final ValueChanged<FoodCandidate> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        food.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        food.tags.contains('열량미기록')
                            ? '열량 미기록'
                            : '${food.consumedNutrition.energyKcal.round()} kcal · 인식 ${(food.confidence * 100).round()}%',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                      if (food.tags.isNotEmpty)
                        Wrap(
                          spacing: 6,
                          children: [
                            for (final tag in food.tags.take(3))
                              Text(
                                '#$tag',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.primary,
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: onAmount,
                  child: Text('${food.amountG}${food.amountUnit}'),
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            if (!food.tags.contains('열량미기록'))
              FoodPortionControl(food: food, onChanged: onChanged),
            if (food.isProduct)
              ProductQuantityControl(food: food, onChanged: onChanged),
          ],
        ),
      ),
    ),
  );
}
