import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/tracking_profile/presentation/tracking_profile_controller.dart';
import '../../features/tracking_profile/presentation/tracking_profile_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final profileState = ref.watch(trackingProfileProvider);
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/setup', builder: (_, _) => const TrackingProfilePage()),
      GoRoute(
        path: '/tracking-profile',
        builder: (_, _) => const TrackingProfilePage(editing: true),
      ),
      GoRoute(path: '/home', builder: (_, _) => const HomePage()),
    ],
    redirect: (_, state) {
      if (authState.isLoading) return null;
      final signedIn = authState.value != null;
      final onLogin = state.matchedLocation == '/login';
      final onSetup = state.matchedLocation == '/setup';
      if (!signedIn && !onLogin) return '/login';
      if (!signedIn) return null;
      if (profileState.isLoading) return null;
      final hasProfile = profileState.value != null;
      if (!hasProfile && !onSetup) return '/setup';
      if (hasProfile && (onLogin || onSetup)) return '/home';
      return null;
    },
  );
});
