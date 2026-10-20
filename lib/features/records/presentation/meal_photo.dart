import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';

final _mealPhotoProvider = FutureProvider.autoDispose.family<Uint8List, String>(
  (ref, path) => Supabase.instance.client.storage.from('meals').download(path),
);

class MealPhotoThumbnail extends ConsumerWidget {
  const MealPhotoThumbnail({
    required this.path,
    required this.fallback,
    super.key,
  });

  final String path;
  final Widget fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(appConfigProvider).hasSupabaseConfiguration) {
      return fallback;
    }
    final image = ref.watch(_mealPhotoProvider(path));
    return image.when(
      loading: () => SizedBox.square(
        dimension: 52,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: const ColoredBox(
            color: Color(0xFFEAF4FF),
            child: Center(
              child: SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        ),
      ),
      error: (_, _) => fallback,
      data: (bytes) => Semantics(
        button: true,
        label: '식사 사진 크게 보기',
        child: InkWell(
          onTap: () => showDialog<void>(
            context: context,
            builder: (context) => Dialog(
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: Image.memory(bytes, fit: BoxFit.contain),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: IconButton.filledTonal(
                      tooltip: '닫기',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ),
          borderRadius: BorderRadius.circular(12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              bytes,
              width: 52,
              height: 52,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          ),
        ),
      ),
    );
  }
}
