import '../domain/tracking_profile.dart';
import 'tracking_profile_repository.dart';

class DemoTrackingProfileRepository implements TrackingProfileRepository {
  TrackingProfile? _profile;

  @override
  Future<TrackingProfile?> load(String userId) async => _profile;

  @override
  Future<void> save(String userId, TrackingProfile profile) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _profile = profile;
  }
}
