import '../../../core/widgets/app_page.dart';
import '../../../app/theme/app_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import '../../auth/presentation/auth_controller.dart';

final reduceMotionProvider = StateProvider<bool>((ref) => false);

class AccessibilitySettingsPage extends ConsumerWidget {
  const AccessibilitySettingsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reduceMotion = ref.watch(reduceMotionProvider);
    final signingOut = ref.watch(authControllerProvider).isLoading;
    return AppPage(
      title: '더보기',
      subtitle: '나에게 맞는 설정과 기록 관리를 한곳에서.',
      selectedIndex: 4,
      body: AppPageList(
        children: [
          const AppSectionHeader('맞춤 설정'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                AppListRow(
                  title: '관리 목표와 추적 항목',
                  subtitle: '목표와 기록할 항목을 변경해요.',
                  icon: Icons.tune_rounded,
                  onTap: () => context.push('/tracking-profile'),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                AppListRow(
                  title: '모션 줄이기',
                  subtitle: '화면 전환과 캐릭터 움직임을 줄여요.',
                  icon: Icons.motion_photos_off_outlined,
                  trailing: Switch(
                    value: reduceMotion,
                    onChanged: (value) =>
                        ref.read(reduceMotionProvider.notifier).state = value,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDesign.sectionGap),
          const AppSectionHeader('기본 적용 안내'),
          const AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                AppListRow(
                  title: '글자 크기 · 기기 설정 적용',
                  subtitle: '기기의 글자 크기 설정을 그대로 적용해요.',
                  icon: Icons.text_fields_rounded,
                ),
                Divider(height: 1, indent: 16, endIndent: 16),
                AppListRow(
                  title: '색상 외 정보 · 기본 적용',
                  subtitle: '색상과 함께 글자·아이콘으로 상태를 알려요.',
                  icon: Icons.contrast_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDesign.sectionGap),
          const AppSectionHeader('데이터 관리'),
          AppCard(
            padding: EdgeInsets.zero,
            child: AppListRow(
              title: '기록 내보내기',
              subtitle: '필요한 기록을 파일로 보관해요.',
              icon: Icons.file_download_outlined,
              onTap: () => context.push('/export'),
            ),
          ),
          const SizedBox(height: AppDesign.sectionGap),
          const AppSectionHeader('계정'),
          AppCard(
            padding: EdgeInsets.zero,
            child: AppListRow(
              title: signingOut ? '로그아웃 중' : '로그아웃',
              icon: Icons.logout_rounded,
              onTap: signingOut
                  ? null
                  : () async {
                      await ref.read(authControllerProvider.notifier).signOut();
                      if (context.mounted &&
                          ref.read(authControllerProvider).hasError) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('로그아웃하지 못했어요. 다시 시도해 주세요.'),
                          ),
                        );
                      }
                    },
            ),
          ),
        ],
      ),
    );
  }
}
