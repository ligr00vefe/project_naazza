import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Shared type and spacing tokens. Root screens must not duplicate these values.
abstract final class AppDesign {
  static const pagePadding = EdgeInsets.fromLTRB(20, 12, 20, 28);
  static const cardPadding = EdgeInsets.all(16);
  static const radius = 22.0;
  static const sectionGap = 22.0;
  static const cardGap = 10.0;
  static const pageTitle = TextStyle(
    fontSize: 18,
    height: 1.3,
    fontWeight: FontWeight.w700,
    color: AppColors.text,
  );
  static const sectionTitle = TextStyle(
    fontSize: 15,
    height: 1.4,
    fontWeight: FontWeight.w700,
    color: AppColors.text,
  );
  static const body = TextStyle(
    fontSize: 13,
    height: 1.5,
    color: AppColors.text,
  );
  static const caption = TextStyle(
    fontSize: 12,
    height: 1.5,
    color: AppColors.muted,
  );
  static const metric = TextStyle(
    fontSize: 22,
    height: 1.2,
    fontWeight: FontWeight.w700,
    color: AppColors.primary,
  );
}
