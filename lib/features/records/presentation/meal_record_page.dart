import '../../../core/widgets/record_datetime_field.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import '../../meal_analysis/data/meal_analysis_repository.dart';
import 'meal_photo.dart';
import '../domain/meal_group.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/health_record.dart';
import 'records_controller.dart';
import 'meal_category_selector.dart';

class ManualMealPhoto {
  const ManualMealPhoto({
    required this.bytes,
    required this.filename,
    this.productName,
    this.amountText,
    this.energyKcal,
  });
  final String? productName, amountText;
  final double? energyKcal;
  final Uint8List bytes;
  final String filename;
}

class MealRecordPage extends ConsumerStatefulWidget {
  const MealRecordPage({
    super.key,
    this.record,
    this.pickImage,
    this.initialPhoto,
  });
  final ManualMealPhoto? initialPhoto;
  final Future<XFile?> Function(ImageSource source)? pickImage;
  final HealthRecord? record;
  @override
  ConsumerState<MealRecordPage> createState() => _MealRecordPageState();
}

class _MealRecordPageState extends ConsumerState<MealRecordPage> {
  late final TextEditingController _food;
  late final TextEditingController _amount;
  late final TextEditingController _kcal;
  late final TextEditingController _memo;
  DateTime _eatenAt = DateTime.now();
  String _mealType = 'meal';
  bool _smallMeal = false;
  bool _saving = false, _saved = false;
  Uint8List? _photoBytes;
  String? _photoPath, _newPhotoPath;
  String _filename = 'meal.jpg';

  @override
  void initState() {
    super.initState();
    _photoBytes = widget.initialPhoto?.bytes;
    _filename = widget.initialPhoto?.filename ?? 'meal.jpg';
    final record = widget.record;
    _eatenAt = record?.recordedAt.toLocal() ?? DateTime.now();
    _food = TextEditingController(
      text: record?.title ?? widget.initialPhoto?.productName ?? '',
    );
    _amount = TextEditingController(
      text:
          record?.data['amount_text']?.toString() ??
          (widget.initialPhoto?.amountText?.isNotEmpty == true
              ? widget.initialPhoto!.amountText!
              : widget.initialPhoto?.productName != null
              ? '1개'
              : '1인분'),
    );
    _kcal = TextEditingController(
      text: record == null
          ? (widget.initialPhoto?.energyKcal?.toString() ?? '')
          : mealCalories(record).toString(),
    );
    _memo = TextEditingController(text: record?.data['memo']?.toString() ?? '');
    _mealType = record?.data['meal_type']?.toString() ?? 'meal';
    _smallMeal = record?.data['small_meal'] == true;
    _photoPath = record?.data['photo_path']?.toString();
  }

  @override
  void dispose() {
    if (!_saved && _newPhotoPath != null) {
      unawaited(
        ref.read(mealAnalysisRepositoryProvider).discardPhoto(_newPhotoPath),
      );
    }
    _food.dispose();
    _amount.dispose();
    _kcal.dispose();
    _memo.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final file =
          await (widget.pickImage?.call(source) ??
              ImagePicker().pickImage(
                source: source,
                maxWidth: 1600,
                maxHeight: 1600,
                imageQuality: 82,
              ));
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      if (_newPhotoPath != null) {
        unawaited(
          ref.read(mealAnalysisRepositoryProvider).discardPhoto(_newPhotoPath),
        );
      }
      setState(() {
        _photoBytes = bytes;
        _filename = file.name;
        _newPhotoPath = null;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('사진을 불러오지 못했어요. 다시 선택해 주세요.')),
        );
      }
    }
  }

  void _removePhoto() {
    if (_newPhotoPath != null) {
      unawaited(
        ref.read(mealAnalysisRepositoryProvider).discardPhoto(_newPhotoPath),
      );
    }
    setState(() {
      _photoBytes = null;
      _photoPath = null;
      _newPhotoPath = null;
    });
  }

  Future<void> _save() async {
    if (_food.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('음식 이름을 입력해 주세요.')));
      return;
    }
    final user = ref.read(authRepositoryProvider).currentUser!;
    final parsedKcal = double.tryParse(_kcal.text.trim());
    final kcal = parsedKcal ?? 0;
    final calorieKnown = _kcal.text.trim().isNotEmpty;
    if ((calorieKnown && parsedKcal == null) || !kcal.isFinite || kcal < 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('열량을 올바른 숫자로 입력해 주세요.')));
      return;
    }
    setState(() => _saving = true);
    try {
      if (_photoBytes != null && _newPhotoPath == null) {
        final photoRepository = ref.read(mealAnalysisRepositoryProvider);
        _newPhotoPath = await photoRepository.uploadPhoto(
          userId: user.id,
          imageBytes: _photoBytes!,
          filename: _filename,
        );
        if (!mounted) {
          unawaited(photoRepository.discardPhoto(_newPhotoPath));
          return;
        }
      }
      final data = <String, Object?>{
        ...?widget.record?.data,
        'photo_path': _newPhotoPath ?? _photoPath,
        'meal_type': _mealType,
        'amount_text': _amount.text.trim(),
        'energy_kcal': calorieKnown ? kcal : null,
        'nutrition_known': calorieKnown,
        'small_meal': _smallMeal,
        'memo': _memo.text.trim(),
      };
      final record = HealthRecord(
        id:
            widget.record?.id ??
            'meal-${DateTime.now().microsecondsSinceEpoch}',
        userId: user.id,
        type: HealthRecordType.meal,
        recordedAt: _eatenAt,
        title: _food.text.trim(),
        summary: calorieKnown
            ? '${_amount.text.trim()} · $kcal kcal'
            : '${_amount.text.trim()} · 열량 미기록',
        data: data,
      );
      widget.record == null
          ? await ref.read(recordsProvider.notifier).create(record)
          : await ref.read(recordsProvider.notifier).updateRecord(record);
      if (mounted && !ref.read(recordsProvider).hasError) {
        _saved = true;
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/timeline');
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is StateError
                  ? error.message.toString()
                  : '사진을 저장하지 못했어요. 다시 시도해 주세요.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => _RecordScaffold(
    title: widget.record == null ? '식사 직접 입력' : '식사 기록 수정',
    description: widget.initialPhoto?.productName != null
        ? '사진에서 확인한 정보를 검토하고 부족한 내용을 입력해요.'
        : 'AI 없이 음식명과 섭취량을 직접 기록해요.',
    saving: _saving || ref.watch(recordsProvider).isLoading,
    onSave: _save,
    child: Column(
      children: [
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
        const SizedBox(height: 18),
        if (_photoBytes != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.memory(_photoBytes!, height: 160, fit: BoxFit.contain),
          ),
        if (_photoBytes == null && _photoPath != null)
          MealPhotoThumbnail(path: _photoPath!, fallback: const Text('첨부된 사진')),
        Wrap(
          spacing: 8,
          children: [
            TextButton.icon(
              onPressed: _saving ? null : () => _pickPhoto(ImageSource.camera),
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('사진 촬영'),
            ),
            TextButton.icon(
              onPressed: _saving ? null : () => _pickPhoto(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('사진 선택'),
            ),
            if (_photoBytes != null || _photoPath != null)
              TextButton(
                onPressed: _saving ? null : _removePhoto,
                child: const Text('사진 삭제'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _food,
          decoration: const InputDecoration(
            labelText: '음식 이름',
            prefixIcon: Icon(Icons.restaurant_rounded),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _amount,
          decoration: const InputDecoration(
            labelText: '섭취량',
            hintText: '예: 1인분, 200g',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _kcal,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: '열량',
            suffixText: 'kcal',
          ),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('소식했어요'),
          subtitle: const Text('평소보다 부담 없이 적게 먹었다면 체크해요.'),
          value: _smallMeal,
          onChanged: (value) => setState(() => _smallMeal = value),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _memo,
          maxLines: 3,
          decoration: const InputDecoration(labelText: '메모'),
        ),
      ],
    ),
  );
}

class _RecordScaffold extends StatelessWidget {
  const _RecordScaffold({
    required this.title,
    required this.description,
    required this.child,
    required this.saving,
    required this.onSave,
  });
  final String title;
  final String description;
  final Widget child;
  final bool saving;
  final VoidCallback onSave;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(20),
      children: [
        Text(description, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 22),
        Card(
          child: Padding(padding: const EdgeInsets.all(20), child: child),
        ),
      ],
    ),
    bottomNavigationBar: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        minimum: const EdgeInsets.all(20),
        child: FilledButton(
          onPressed: saving ? null : onSave,
          child: Text(saving ? '저장 중...' : '기록 저장하기'),
        ),
      ),
    ),
  );
}
