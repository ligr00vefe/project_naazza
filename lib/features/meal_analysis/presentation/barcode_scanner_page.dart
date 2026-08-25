import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../app/theme/app_colors.dart';
import '../../auth/data/auth_repository.dart';
import '../../records/domain/health_record.dart';
import '../../records/presentation/records_controller.dart';
import '../data/meal_analysis_repository.dart';
import '../domain/meal_analysis.dart';

class BarcodeScannerPage extends ConsumerStatefulWidget {
  const BarcodeScannerPage({super.key});
  @override
  ConsumerState<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends ConsumerState<BarcodeScannerPage> {
  final _controller = MobileScannerController(
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
    ],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  final _manual = TextEditingController();
  bool _lookingUp = false;
  String? _barcode, _error;
  FoodCandidate? _product;
  double _amountG = 0;
  @override
  void dispose() {
    _controller.dispose();
    _manual.dispose();
    super.dispose();
  }

  Future<void> _detect(BarcodeCapture capture) async {
    final value = capture.barcodes.firstOrNull?.rawValue;
    if (value == null || _lookingUp || _product != null) return;
    await _lookup(value);
  }

  Future<void> _lookup(String value) async {
    if (value.trim().isEmpty) return;
    await _controller.stop();
    setState(() {
      _lookingUp = true;
      _barcode = value.trim();
      _error = null;
    });
    try {
      final product = await ref
          .read(mealAnalysisRepositoryProvider)
          .lookupBarcode(value.trim());
      if (!mounted) return;
      setState(() {
        _product = product;
        _amountG = product?.amountG ?? 0;
        if (product == null) _error = '제품 정보를 찾지 못했어요. 직접 검색해 주세요.';
      });
    } catch (error) {
      if (mounted) setState(() => _error = '제품 조회에 실패했어요. ($error)');
    } finally {
      if (mounted) setState(() => _lookingUp = false);
    }
  }

  Future<void> _save() async {
    final product = _product;
    if (product == null || _amountG <= 0) return;
    final user = ref.read(authRepositoryProvider).currentUser!;
    final nutrition = product.nutrition.forAmount(_amountG);
    await ref
        .read(recordsProvider.notifier)
        .create(
          HealthRecord(
            id: 'meal-${DateTime.now().microsecondsSinceEpoch}',
            userId: user.id,
            type: HealthRecordType.meal,
            recordedAt: DateTime.now(),
            title: product.name,
            summary:
                '${_amountG.round()}g · ${nutrition.energyKcal.round()} kcal',
            data: {
              'meal_type': 'meal',
              'amount_text': '${_amountG.round()}g',
              'energy_kcal': nutrition.energyKcal.round(),
              'barcode': _barcode,
              'items': [
                {
                  'name': product.name,
                  'normalized_name': product.normalizedName,
                  'amount_g': _amountG,
                  'tags': product.tags,
                  'source_type': 'barcode',
                },
              ],
            },
          ),
        );
    if (mounted && !ref.read(recordsProvider).hasError) context.go('/timeline');
  }

  void _retry() {
    setState(() {
      _product = null;
      _barcode = null;
      _error = null;
    });
    _controller.start();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('바코드로 기록')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      children: [
        Text(
          '제품 바코드를 화면 안에 맞춰주세요',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 6),
        const Text(
          '영양정보는 저장 전에 반드시 확인해 주세요.',
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 18),
        if (_product == null && !_lookingUp)
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(
              height: 300,
              child: MobileScanner(
                controller: _controller,
                onDetect: _detect,
                errorBuilder: (_, error) => _ScannerError(
                  message: error.errorDetails?.message ?? '카메라를 사용할 수 없어요.',
                ),
              ),
            ),
          ),
        if (_lookingUp)
          const Padding(
            padding: EdgeInsets.all(48),
            child: Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('제품 정보를 확인하고 있어요...'),
              ],
            ),
          ),
        if (_error != null)
          Card(
            color: const Color(0xFFFFF4EF),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!),
            ),
          ),
        if (_product != null)
          _ProductCard(
            product: _product!,
            amountG: _amountG,
            onAmount: (value) => setState(() => _amountG = value),
          ),
        if (_product == null && !_lookingUp) ...[
          const SizedBox(height: 14),
          TextField(
            controller: _manual,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: '바코드 번호 직접 입력',
              suffixIcon: IconButton(
                onPressed: () => _lookup(_manual.text),
                icon: const Icon(Icons.search_rounded),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (_error != null)
          OutlinedButton(onPressed: _retry, child: const Text('다시 스캔')),
        TextButton(
          onPressed: () => context.push('/record/meal'),
          child: const Text('제품을 직접 입력하기'),
        ),
      ],
    ),
    bottomNavigationBar: _product == null
        ? null
        : SafeArea(
            minimum: const EdgeInsets.all(20),
            child: FilledButton(
              onPressed: _save,
              child: const Text('제품 식사 저장'),
            ),
          ),
  );
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.amountG,
    required this.onAmount,
  });
  final FoodCandidate product;
  final double amountG;
  final ValueChanged<double> onAmount;
  @override
  Widget build(BuildContext context) {
    final nutrition = product.nutrition.forAmount(amountG);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.verified_rounded, color: AppColors.primary),
            const SizedBox(height: 8),
            Text(product.name, style: Theme.of(context).textTheme.titleLarge),
            Text(
              product.tags.map((e) => '#$e').join(' '),
              style: const TextStyle(color: AppColors.primary),
            ),
            const SizedBox(height: 18),
            Text('섭취량 ${amountG.round()}g'),
            Slider(
              value: amountG.clamp(1, 500),
              min: 1,
              max: 500,
              divisions: 499,
              onChanged: onAmount,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('예상 열량'),
                Text(
                  '${nutrition.energyKcal.round()} kcal',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ScannerError extends StatelessWidget {
  const _ScannerError({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.black87,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          '$message\n아래에서 바코드 번호를 직접 입력할 수 있어요.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    ),
  );
}
