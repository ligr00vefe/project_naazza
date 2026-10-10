import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
      NavigationDestination(icon: Icon(Icons.home_rounded), label: '홈'),
      NavigationDestination(
        icon: Icon(Icons.calendar_month_rounded),
        label: '캘린더',
      ),
      NavigationDestination(
        icon: Icon(Icons.add_circle_rounded),
        label: '기록하기',
      ),
      NavigationDestination(icon: Icon(Icons.bar_chart_rounded), label: '인사이트'),
      NavigationDestination(icon: Icon(Icons.menu_rounded), label: '더보기'),
    ],
  );
}
