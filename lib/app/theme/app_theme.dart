import 'app_design.dart';
import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        error: AppColors.danger,
      ),
      scaffoldBackgroundColor: AppColors.background,
      fontFamilyFallback: const ['Pretendard', 'Noto Sans KR', 'sans-serif'],
    );
    return base.copyWith(
      textTheme: base.textTheme
          .apply(bodyColor: AppColors.text, displayColor: AppColors.text)
          .copyWith(
            displayLarge: AppDesign.metric.copyWith(fontSize: 28),
            displayMedium: AppDesign.metric.copyWith(fontSize: 26),
            displaySmall: AppDesign.metric.copyWith(fontSize: 24),
            headlineLarge: AppDesign.metric,
            headlineMedium: AppDesign.pageTitle,
            headlineSmall: AppDesign.pageTitle,
            titleLarge: AppDesign.sectionTitle,
            titleMedium: AppDesign.body.copyWith(fontWeight: FontWeight.w600),
            titleSmall: AppDesign.body.copyWith(fontWeight: FontWeight.w600),
            bodyLarge: AppDesign.body.copyWith(fontSize: 14),
            bodyMedium: AppDesign.body,
            bodySmall: AppDesign.caption,
            labelLarge: AppDesign.body.copyWith(fontWeight: FontWeight.w600),
            labelMedium: AppDesign.caption,
            labelSmall: AppDesign.caption.copyWith(fontSize: 11),
          ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppDesign.pageTitle,
        iconTheme: IconThemeData(size: 21, color: AppColors.primary),
      ),
      listTileTheme: const ListTileThemeData(
        titleTextStyle: AppDesign.body,
        subtitleTextStyle: AppDesign.caption,
        iconColor: AppColors.primary,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      chipTheme: ChipThemeData(
        labelStyle: AppDesign.caption.copyWith(color: AppColors.text),
        backgroundColor: Colors.white,
        selectedColor: const Color(0xFFEAF2E5),
        side: const BorderSide(color: AppColors.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: const Color(0xFFE8F1E2),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => AppDesign.caption.copyWith(
            fontSize: 11,
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.muted,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w400,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.muted,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesign.radius),
          side: const BorderSide(color: AppColors.outline),
        ),
      ),
    );
  }
}
