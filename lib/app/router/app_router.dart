import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/export/presentation/export_page.dart';
import '../../features/favorites/presentation/favorite_meals_page.dart';
import '../../features/insights/presentation/insights_page.dart';
import '../../features/meal_analysis/presentation/meal_capture_page.dart';
import '../../features/meal_analysis/presentation/barcode_scanner_page.dart';
import '../../features/records/domain/health_record.dart';
import '../../features/records/presentation/bowel_record_page.dart';
import '../../features/records/presentation/condition_record_page.dart';
import '../../features/records/presentation/meal_record_page.dart';
import '../../features/records/presentation/record_hub_page.dart';
import '../../features/records/presentation/records_calendar_page.dart';
import '../../features/records/presentation/timeline_page.dart';
import '../../features/tracking_profile/presentation/tracking_profile_controller.dart';
import '../../features/tracking_profile/presentation/tracking_profile_page.dart';
import '../../features/settings/presentation/accessibility_settings.dart';
import '../../features/visits/presentation/visit_preparation_page.dart';
import '../../features/visits/presentation/visit_record_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  late final GoRouter router;
  router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/setup', builder: (_, _) => const TrackingProfilePage()),
      GoRoute(
        path: '/tracking-profile',
        builder: (_, _) => const TrackingProfilePage(editing: true),
      ),
      GoRoute(path: '/home', builder: (_, _) => const HomePage()),
      GoRoute(path: '/favorites', builder: (_, _) => const FavoriteMealsPage()),
      GoRoute(path: '/export', builder: (_, _) => const ExportPage()),
      GoRoute(
        path: '/settings',
        builder: (_, _) => const AccessibilitySettingsPage(),
      ),
      GoRoute(path: '/record', builder: (_, _) => const RecordHubPage()),
      GoRoute(
        path: '/record/meal-photo',
        builder: (_, _) => const MealCapturePage(),
      ),
      GoRoute(
        path: '/record/barcode',
        builder: (_, _) => const BarcodeScannerPage(),
      ),
      GoRoute(
        path: '/record/meal',
        builder: (_, state) =>
            MealRecordPage(record: state.extra as HealthRecord?),
      ),
      GoRoute(
        path: '/record/condition',
        builder: (_, state) =>
            ConditionRecordPage(record: state.extra as HealthRecord?),
      ),
      GoRoute(
        path: '/record/bowel',
        builder: (_, state) =>
            BowelRecordPage(record: state.extra as HealthRecord?),
      ),
      GoRoute(
        path: '/record/visit',
        builder: (_, state) =>
            VisitRecordPage(record: state.extra as HealthRecord?),
      ),
      GoRoute(
        path: '/visit/preparation',
        builder: (_, state) =>
            VisitPreparationPage(visit: state.extra! as HealthRecord),
      ),
      GoRoute(path: '/timeline', builder: (_, _) => const TimelinePage()),
      GoRoute(path: '/insights', builder: (_, _) => const InsightsPage()),
      GoRoute(
        path: '/calendar',
        builder: (_, _) => const RecordsCalendarPage(),
      ),
    ],
    redirect: (_, state) {
      final authState = ref.read(authStateProvider);
      final profileState = ref.read(trackingProfileProvider);
      if (authState.isLoading) return null;
      final signedIn = authState.value != null;
      final onLogin = state.matchedLocation == '/login';
      final onSetup = state.matchedLocation == '/setup';
      if (!signedIn && !onLogin) return '/login';
      if (!signedIn) return null;
      if (profileState.isLoading) return null;
      if (profileState.hasError) return onLogin ? '/home' : null;
      final hasProfile = profileState.value != null;
      if (!hasProfile && !onSetup) return '/setup';
      if (hasProfile && (onLogin || onSetup)) return '/home';
      return null;
    },
  );
  ref.listen(authStateProvider, (_, _) => router.refresh());
  ref.listen(trackingProfileProvider, (_, _) => router.refresh());
  ref.onDispose(router.dispose);
  return router;
});
