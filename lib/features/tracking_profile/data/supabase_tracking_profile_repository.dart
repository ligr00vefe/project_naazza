import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/tracking_profile.dart';
import 'tracking_profile_repository.dart';

class SupabaseTrackingProfileRepository implements TrackingProfileRepository {
  SupabaseTrackingProfileRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<TrackingProfile?> load(String userId) async {
    final conditions = await _client
        .from('user_conditions')
        .select('condition_key')
        .eq('user_id', userId);
    final metrics = await _client
        .from('user_tracking_metrics')
        .select('metric_key, enabled, quick_log_order')
        .eq('user_id', userId)
        .order('quick_log_order');
    final preferences = await _client
        .from('user_preferences')
        .select('reminders_enabled, onboarding_completed')
        .eq('user_id', userId)
        .maybeSingle();
    if (preferences == null || preferences['onboarding_completed'] != true) {
      return null;
    }
    return TrackingProfile(
      conditionKeys: [
        for (final row in conditions) row['condition_key'] as String,
      ],
      metrics: [
        for (final row in metrics)
          TrackingMetricSelection(
            metricKey: row['metric_key'] as String,
            enabled: row['enabled'] as bool,
            quickLogOrder: row['quick_log_order'] as int,
          ),
      ],
      remindersEnabled: preferences['reminders_enabled'] as bool? ?? false,
    );
  }

  @override
  Future<void> save(String userId, TrackingProfile profile) async {
    await _client.from('user_conditions').delete().eq('user_id', userId);
    await _client.from('user_tracking_metrics').delete().eq('user_id', userId);
    if (profile.conditionKeys.isNotEmpty) {
      await _client.from('user_conditions').insert([
        for (final key in profile.conditionKeys)
          {'user_id': userId, 'condition_key': key},
      ]);
    }
    if (profile.metrics.isNotEmpty) {
      await _client.from('user_tracking_metrics').insert([
        for (final metric in profile.metrics)
          {
            'user_id': userId,
            'metric_key': metric.metricKey,
            'enabled': metric.enabled,
            'quick_log_order': metric.quickLogOrder,
          },
      ]);
    }
    await _client.from('user_preferences').upsert({
      'user_id': userId,
      'reminders_enabled': profile.remindersEnabled,
      'onboarding_completed': true,
    });
  }
}
