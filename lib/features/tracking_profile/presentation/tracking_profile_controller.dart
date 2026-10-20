import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_repository.dart';
import '../data/tracking_profile_repository.dart';
import '../domain/tracking_profile.dart';

final trackingProfileProvider =
    AsyncNotifierProvider<TrackingProfileController, TrackingProfile?>(
      TrackingProfileController.new,
    );

class TrackingProfileController extends AsyncNotifier<TrackingProfile?> {
  @override
  Future<TrackingProfile?> build() async {
    final userId = ref.watch(
      authStateProvider.select((state) => state.value?.id),
    );
    if (userId == null) return null;
    return ref.read(trackingProfileRepositoryProvider).load(userId);
  }

  Future<void> save(TrackingProfile profile) async {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) throw StateError('로그인이 필요합니다.');
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(trackingProfileRepositoryProvider).save(user.id, profile);
      return profile;
    });
  }
}
