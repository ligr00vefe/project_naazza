import 'dart:async';
import 'features/meal_analysis/data/ingredient_cache.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/bootstrap/bootstrap.dart';
import 'core/config/app_config.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/tracking_profile/data/tracking_profile_repository.dart';
import 'features/records/data/records_repository.dart';
import 'features/meal_analysis/data/meal_analysis_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dependencies = await bootstrap();
  unawaited(cleanupIngredientCache().catchError((Object error) {}));
  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(dependencies.config),
        authRepositoryProvider.overrideWithValue(dependencies.authRepository),
        trackingProfileRepositoryProvider.overrideWithValue(
          dependencies.trackingProfileRepository,
        ),
        recordsRepositoryProvider.overrideWithValue(
          dependencies.recordsRepository,
        ),
        mealAnalysisRepositoryProvider.overrideWithValue(
          dependencies.mealAnalysisRepository,
        ),
      ],
      child: const NaazzaApp(),
    ),
  );
}
