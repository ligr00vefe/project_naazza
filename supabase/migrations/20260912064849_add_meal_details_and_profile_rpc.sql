-- Preserve structured meal analysis data and save tracking preferences atomically.

alter table public.meals
  add column if not exists details jsonb not null default '{}'::jsonb;

alter table public.meals
  add constraint meals_details_object_check
  check (jsonb_typeof(details) = 'object');

alter table public.user_conditions
  add constraint user_conditions_condition_key_check
  check (
    condition_key in (
      'diabetes',
      'ibd',
      'post_cholecystectomy',
      'kidney',
      'custom'
    )
  );

alter table public.user_tracking_metrics
  add constraint user_tracking_metrics_metric_key_check
  check (
    metric_key in (
      'blood_glucose',
      'carbohydrate',
      'meal_time',
      'bowel',
      'abdominal_pain',
      'bloating',
      'fatigue',
      'fat',
      'meal_amount',
      'diarrhea',
      'sodium',
      'potassium',
      'phosphorus',
      'water_intake'
    )
  );

create or replace function public.load_tracking_profile()
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $function$
  select jsonb_build_object(
    'condition_keys',
    coalesce(
      (
        select jsonb_agg(condition.condition_key order by condition.condition_key)
        from public.user_conditions as condition
        where condition.user_id = preferences.user_id
      ),
      '[]'::jsonb
    ),
    'metrics',
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'metric_key', metric.metric_key,
            'enabled', metric.enabled,
            'quick_log_order', metric.quick_log_order
          )
          order by metric.quick_log_order, metric.metric_key
        )
        from public.user_tracking_metrics as metric
        where metric.user_id = preferences.user_id
      ),
      '[]'::jsonb
    ),
    'reminders_enabled',
    preferences.reminders_enabled
  )
  from public.user_preferences as preferences
  where preferences.user_id = (select auth.uid())
    and preferences.onboarding_completed;
$function$;

create or replace function public.save_tracking_profile(
  p_condition_keys text[],
  p_metrics jsonb,
  p_reminders_enabled boolean
)
returns void
language plpgsql
security invoker
set search_path = ''
as $function$
declare
  v_user_id uuid := (select auth.uid());
begin
  if v_user_id is null then
    raise exception 'Authentication is required.' using errcode = '42501';
  end if;

  if coalesce(cardinality(p_condition_keys), 0) = 0 then
    raise exception 'At least one condition is required.' using errcode = '22023';
  end if;

  if jsonb_typeof(p_metrics) is distinct from 'array' then
    raise exception 'p_metrics must be a JSON array.' using errcode = '22023';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_user_id::text, 0)
  );

  delete from public.user_conditions where user_id = v_user_id;
  delete from public.user_tracking_metrics where user_id = v_user_id;

  insert into public.user_conditions (user_id, condition_key)
  select v_user_id, condition.condition_key
  from unnest(p_condition_keys) as condition(condition_key);

  insert into public.user_tracking_metrics (
    user_id,
    metric_key,
    enabled,
    quick_log_order
  )
  select
    v_user_id,
    metric.metric_key,
    coalesce(metric.enabled, true),
    coalesce(metric.quick_log_order, 0)
  from jsonb_to_recordset(p_metrics) as metric(
    metric_key text,
    enabled boolean,
    quick_log_order integer
  );

  insert into public.user_preferences (
    user_id,
    reminders_enabled,
    onboarding_completed
  )
  values (v_user_id, p_reminders_enabled, true)
  on conflict (user_id) do update
  set reminders_enabled = excluded.reminders_enabled,
      onboarding_completed = true,
      updated_at = now();
end;
$function$;

revoke all on function public.load_tracking_profile()
  from public, anon;
grant execute on function public.load_tracking_profile()
  to authenticated;

revoke all on function public.save_tracking_profile(text[], jsonb, boolean)
  from public, anon;
grant execute on function public.save_tracking_profile(text[], jsonb, boolean)
  to authenticated;

