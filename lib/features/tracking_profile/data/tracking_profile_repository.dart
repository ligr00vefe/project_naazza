import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/tracking_profile.dart';

abstract interface class TrackingProfileRepository {
  Future<TrackingProfile?> load(String userId);
  Future<void> save(String userId, TrackingProfile profile);
}

final trackingProfileRepositoryProvider = Provider<TrackingProfileRepository>(
  (ref) => throw StateError(
    'TrackingProfileRepository must be provided during bootstrap.',
  ),
);
