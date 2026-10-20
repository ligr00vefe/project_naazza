import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme/app_colors.dart';

class MainNavigationBar extends StatelessWidget {
  const MainNavigationBar({super.key, required this.selectedIndex});
  final int selectedIndex;
  @override
  Widget build(BuildContext context) => NavigationBar(
    selectedIndex: selectedIndex,
    onDestinationSelected: (index) => context.go(
      ['/home', '/calendar', '/record', '/insights', '/settings'][index],
    ),
    destinations: const [
      NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home_rounded),
        label: '홈',
      ),
      NavigationDestination(
        icon: Icon(Icons.calendar_month_outlined),
        selectedIcon: Icon(Icons.calendar_month_rounded),
        label: '캘린더',
      ),
      NavigationDestination(icon: _RecordAction(), label: '기록하기'),
      NavigationDestination(icon: Icon(Icons.bar_chart_rounded), label: '인사이트'),
      NavigationDestination(icon: Icon(Icons.more_horiz_rounded), label: '더보기'),
    ],
  );
}

class _RecordAction extends StatelessWidget {
  const _RecordAction();
  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    height: 44,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(colors: [Color(0xFF488BFF), AppColors.primary]),
      boxShadow: [
        BoxShadow(
          color: Color(0x303B6FF5),
          blurRadius: 10,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
  );
}
