import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RecordHubPage extends StatelessWidget {
  const RecordHubPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('기록하기')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('어떤 기록을 남길까요?', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 18),
        _RecordChoice(
          icon: Icons.restaurant_rounded,
          title: '식사 기록',
          subtitle: '사진 분석 또는 직접 입력',
          onTap: () => context.push('/record/meal-photo'),
        ),
        const SizedBox(height: 12),
        _RecordChoice(
          icon: Icons.health_and_safety_rounded,
          title: '컨디션·증상 기록',
          subtitle: '이상 없음·증상·건너뛰기 구분',
          onTap: () => context.push('/record/condition'),
        ),
        const SizedBox(height: 12),
        _RecordChoice(
          icon: Icons.circle_rounded,
          title: '배변 기록',
          subtitle: '브리스톨 척도와 상태 기록',
          onTap: () => context.push('/record/bowel'),
        ),
        const SizedBox(height: 12),
        _RecordChoice(
          icon: Icons.medical_services_rounded,
          title: '진료/내원 기록',
          subtitle: '검사·상담·처방 변경과 다음 일정',
          onTap: () => context.push('/record/visit'),
        ),
      ],
    ),
  );
}

class _RecordChoice extends StatelessWidget {
  const _RecordChoice({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.all(18),
      leading: CircleAvatar(child: Icon(icon)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    ),
  );
}
