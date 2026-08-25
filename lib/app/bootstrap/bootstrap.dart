import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/data/demo_auth_repository.dart';
import '../../features/auth/data/supabase_auth_repository.dart';
import '../../features/records/data/demo_records_repository.dart';
import '../../features/records/data/records_repository.dart';
import '../../features/records/data/supabase_records_repository.dart';
import '../../features/meal_analysis/data/demo_meal_analysis_repository.dart';
import '../../features/meal_analysis/data/meal_analysis_repository.dart';
import '../../features/meal_analysis/data/supabase_meal_analysis_repository.dart';
import '../../features/tracking_profile/data/demo_tracking_profile_repository.dart';
import '../../features/tracking_profile/data/supabase_tracking_profile_repository.dart';
import '../../features/tracking_profile/data/tracking_profile_repository.dart';

class BootstrapDependencies {
  const BootstrapDependencies({
    required this.config,
    required this.authRepository,
    required this.trackingProfileRepository,
    required this.recordsRepository,
    required this.mealAnalysisRepository,
  });
  final AppConfig config;
  final AuthRepository authRepository;
  final TrackingProfileRepository trackingProfileRepository;
  final RecordsRepository recordsRepository;
  final MealAnalysisRepository mealAnalysisRepository;
}

Future<BootstrapDependencies> bootstrap() async {
  final config = AppConfig.fromEnvironment();
  final AuthRepository repository;
  final TrackingProfileRepository trackingRepository;
  final RecordsRepository recordsRepository;
  final MealAnalysisRepository mealAnalysisRepository;
  if (config.hasSupabaseConfiguration) {
    await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.supabasePublishableKey,
    );
    repository = SupabaseAuthRepository(Supabase.instance.client);
    trackingRepository = SupabaseTrackingProfileRepository(
      Supabase.instance.client,
    );
    recordsRepository = SupabaseRecordsRepository(Supabase.instance.client);
    mealAnalysisRepository = SupabaseMealAnalysisRepository(
      Supabase.instance.client,
    );
  } else {
    repository = DemoAuthRepository();
    trackingRepository = DemoTrackingProfileRepository();
    recordsRepository = DemoRecordsRepository();
    mealAnalysisRepository = DemoMealAnalysisRepository();
  }
  return BootstrapDependencies(
    config: config,
    authRepository: repository,
    trackingProfileRepository: trackingRepository,
    recordsRepository: recordsRepository,
    mealAnalysisRepository: mealAnalysisRepository,
  );
}
