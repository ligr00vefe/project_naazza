import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';

final reduceMotionProvider = StateProvider<bool>((ref) => false);

class AccessibilitySettingsPage extends ConsumerWidget {
  const AccessibilitySettingsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reduceMotion = ref.watch(reduceMotionProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('설정 및 접근성')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.motion_photos_off_outlined),
              title: const Text('모션 줄이기'),
              subtitle: const Text('캐릭터 움직임과 화면 전환 효과를 최소화해요.'),
              value: reduceMotion,
              onChanged: (value) =>
                  ref.read(reduceMotionProvider.notifier).state = value,
            ),
          ),
          const Card(
            child: ListTile(
              leading: Icon(Icons.text_fields_rounded),
              title: Text('글자 크기'),
              subtitle: Text('기기의 글자 크기 설정을 그대로 적용합니다.'),
            ),
          ),
          const Card(
            child: ListTile(
              leading: Icon(Icons.contrast_rounded),
              title: Text('색상 외 정보 제공'),
              subtitle: Text('선택과 상태를 색상뿐 아니라 아이콘과 텍스트로 함께 표시합니다.'),
            ),
          ),
          const SizedBox(height: 18),
          Text('데이터 관리', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.file_download_outlined),
            title: const Text('기록 내보내기'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/export'),
          ),
        ],
      ),
    );
  }
}
