import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/config/app_config.dart';
import '../../auth/data/auth_repository.dart';
import '../../records/domain/health_record.dart';
import '../../records/presentation/records_controller.dart';
import '../data/meal_analysis_repository.dart';
import '../domain/meal_analysis.dart';

class MealCapturePage extends ConsumerStatefulWidget {
  const MealCapturePage({super.key});
  @override
  ConsumerState<MealCapturePage> createState() => _MealCapturePageState();
}

class _MealCapturePageState extends ConsumerState<MealCapturePage> {
  final _picker = ImagePicker();
  Uint8List? _imageBytes;
  String _filename = 'meal.jpg';
  String? _photoPath;
  List<FoodCandidate> _foods = [];
  bool _analyzing = false;
  String? _error;

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 82,
      );
      if (file == null) return;
      _imageBytes = await file.readAsBytes();
      _filename = file.name;
      if (mounted) setState(() {});
      await _analyze();
    } catch (error) {
      setState(() => _error = '이미지를 불러오지 못했어요: $error');
    }
  }

  Future<void> _analyze({bool demo = false}) async {
    final bytes = demo ? Uint8List.fromList([0]) : _imageBytes;
    if (bytes == null) return;
    setState(() {
      _analyzing = true;
      _error = null;
    });
    try {
      final user = ref.read(authRepositoryProvider).currentUser!;
      final result = await ref
          .read(mealAnalysisRepositoryProvider)
          .analyze(userId: user.id, imageBytes: bytes, filename: _filename);
      if (!mounted) {
        return;
      }
      setState(() {
        _foods = result.foods;
        _photoPath = result.photoPath;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'AI 분석에 실패했어요. 직접 입력을 이용해 주세요. ($error)');
      }
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  Future<void> _searchAndAdd() async {
    final controller = TextEditingController();
    final query = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('음식 직접 검색'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '음식 이름'),
        ),
        actions: [
          TextButton(onPressed: () => context.pop(), child: const Text('취소')),
          FilledButton(
            onPressed: () => context.pop(controller.text.trim()),
            child: const Text('검색'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (query == null || query.isEmpty) {
      return;
    }
    try {
      final results = await ref
          .read(mealAnalysisRepositoryProvider)
          .searchNutrition(query);
      if (mounted && results.isNotEmpty) {
        setState(() => _foods.add(results.first));
      }
    } catch (error) {
      if (mounted) setState(() => _error = '검색하지 못했어요: $error');
    }
  }

  Future<void> _editAmount(int index) async {
    final controller = TextEditingController(
      text: _foods[index].amountG.toStringAsFixed(0),
    );
    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${_foods[index].name} 섭취량'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(suffixText: 'g'),
        ),
        actions: [
          TextButton(onPressed: () => context.pop(), child: const Text('취소')),
          FilledButton(
            onPressed: () => context.pop(double.tryParse(controller.text)),
            child: const Text('적용'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null && value > 0) {
      setState(() => _foods[index] = _foods[index].copyWith(amountG: value));
    }
  }

  Future<void> _save() async {
    if (_foods.isEmpty) return;
    final user = ref.read(authRepositoryProvider).currentUser!;
    final total = _foods.fold<double>(
      0,
      (sum, food) => sum + food.nutrition.forAmount(food.amountG).energyKcal,
    );
    final record = HealthRecord(
      id: 'meal-${DateTime.now().microsecondsSinceEpoch}',
      userId: user.id,
      type: HealthRecordType.meal,
      recordedAt: DateTime.now(),
      title: _foods.map((food) => food.name).join(', '),
      summary: '${_foods.length}개 음식 · ${total.round()} kcal',
      data: {
        'meal_type': 'meal',
        'amount_text': '${_foods.length}개 음식',
        'energy_kcal': total.round(),
        'photo_path': _photoPath,
        'items': [
          for (final food in _foods)
            {
              'name': food.name,
              'normalized_name': food.normalizedName,
              'amount_g': food.amountG,
              'tags': food.tags,
              'confidence': food.confidence,
            },
        ],
      },
    );
    await ref.read(recordsProvider.notifier).create(record);
    if (mounted && !ref.read(recordsProvider).hasError) context.go('/timeline');
  }

  @override
  Widget build(BuildContext context) {
    final isDemo = !ref.watch(appConfigProvider).hasSupabaseConfiguration;
    final totalKcal = _foods.fold<double>(
      0,
      (sum, food) => sum + food.nutrition.forAmount(food.amountG).energyKcal,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('음식 사진 기록')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          Text(
            '음식 등록 방식 선택',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const Text(
            'AI 결과는 참고용이며 저장 전에 반드시 확인해 주세요.',
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
          if (isDemo && _foods.isEmpty) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _analyzing ? null : () => _analyze(demo: true),
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('데모 사진 분석 실행'),
            ),
          ],
          if (_foods.isEmpty) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.push('/record/barcode'),
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('제품 바코드로 기록'),
            ),
          ],
          if (_analyzing)
            const Padding(
              padding: EdgeInsets.all(28),
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('음식을 분석하고 있어요...'),
                ],
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: MaterialBanner(
                content: Text(_error!),
                actions: [
                  TextButton(
                    onPressed: _searchAndAdd,
                    child: const Text('직접 입력'),
                  ),
                ],
              ),
            ),
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
            for (var index = 0; index < _foods.length; index++)
              _FoodCard(
                food: _foods[index],
                onAmount: () => _editAmount(index),
                onDelete: () => setState(() => _foods.removeAt(index)),
              ),
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
            onPressed: () => context.push('/record/meal'),
            child: const Text('사진 없이 직접 입력하기'),
          ),
        ],
      ),
      bottomNavigationBar: _foods.isEmpty
          ? null
          : SafeArea(
              minimum: const EdgeInsets.all(20),
              child: FilledButton(
                onPressed: ref.watch(recordsProvider).isLoading ? null : _save,
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
  });
  final FoodCandidate food;
  final VoidCallback onAmount;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) {
    final nutrition = food.nutrition.forAmount(food.amountG);
    final needsReview = food.confidence < 0.85;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: needsReview
                    ? const Color(0xFFFFF2D5)
                    : const Color(0xFFE6F6EE),
                child: Icon(
                  needsReview
                      ? Icons.priority_high_rounded
                      : Icons.check_rounded,
                  color: needsReview ? Colors.orange : AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      food.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${(food.confidence * 100).round()}% · ${nutrition.energyKcal.round()} kcal',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    Wrap(
                      spacing: 4,
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
                child: Text('${food.amountG.round()}g'),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
