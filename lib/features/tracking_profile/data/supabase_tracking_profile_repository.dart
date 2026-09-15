import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/tracking_profile.dart';
import 'tracking_profile_repository.dart';

class SupabaseTrackingProfileRepository implements TrackingProfileRepository {
  SupabaseTrackingProfileRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<TrackingProfile?> load(String userId) async {
    _ensureCurrentUser(userId);
    final response = await _client.rpc('load_tracking_profile');
    if (response == null) return null;
    final data = Map<String, dynamic>.from(response as Map);
    return TrackingProfile(
      conditionKeys: List<String>.from(
        data['condition_keys'] as List? ?? const [],
      ),
      metrics: [
        for (final value in data['metrics'] as List? ?? const [])
          TrackingMetricSelection(
            metricKey:
                Map<String, dynamic>.from(value as Map)['metric_key'] as String,
            enabled:
                Map<String, dynamic>.from(value)['enabled'] as bool? ?? true,
            quickLogOrder:
                Map<String, dynamic>.from(value)['quick_log_order'] as int? ??
                0,
          ),
      ],
      remindersEnabled: data['reminders_enabled'] as bool? ?? false,
    );
  }

  @override
  Future<void> save(String userId, TrackingProfile profile) async {
    _ensureCurrentUser(userId);
    await _client.rpc(
      'save_tracking_profile',
      params: {
        'p_condition_keys': profile.conditionKeys,
        'p_metrics': [
          for (final metric in profile.metrics)
            {
              'metric_key': metric.metricKey,
              'enabled': metric.enabled,
              'quick_log_order': metric.quickLogOrder,
            },
        ],
        'p_reminders_enabled': profile.remindersEnabled,
      },
    );
  }

  void _ensureCurrentUser(String userId) {
    if (_client.auth.currentUser?.id != userId) {
      throw StateError('현재 로그인한 사용자의 설정만 처리할 수 있습니다.');
    }
  }
}
