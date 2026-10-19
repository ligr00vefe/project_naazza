-- NAAZZA initial schema. All rows are private to their authenticated owner.

create table public.user_conditions (user_id uuid not null references auth.users(id) on delete cascade, condition_key text not null, created_at timestamptz not null default now(), primary key (user_id, condition_key));
create table public.user_tracking_metrics (user_id uuid not null references auth.users(id) on delete cascade, metric_key text not null, enabled boolean not null default true, quick_log_order integer not null default 0 check (quick_log_order >= 0), created_at timestamptz not null default now(), primary key (user_id, metric_key));
create index user_tracking_metrics_user_order_idx on public.user_tracking_metrics (user_id, quick_log_order);
create table public.user_preferences (user_id uuid primary key references auth.users(id) on delete cascade, reminders_enabled boolean not null default false, onboarding_completed boolean not null default false, created_at timestamptz not null default now(), updated_at timestamptz not null default now());

create table public.meals (id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade, eaten_at timestamptz not null, meal_type text not null default 'meal', food_name text not null, amount_text text, energy_kcal numeric(10, 2) not null default 0 check (energy_kcal >= 0), memo text, created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create index meals_user_eaten_at_idx on public.meals (user_id, eaten_at desc);
create table public.condition_logs (id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade, recorded_at timestamptz not null, response_status text not null check (response_status in ('normal', 'symptom', 'later', 'skipped')), symptoms text[] not null default '{}', memo text, created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create index condition_logs_user_recorded_at_idx on public.condition_logs (user_id, recorded_at desc);
create table public.bowel_logs (id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade, recorded_at timestamptz not null, bristol_type smallint not null check (bristol_type between 1 and 7), urgency text, pain text, amount text, memo text, created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create index bowel_logs_user_recorded_at_idx on public.bowel_logs (user_id, recorded_at desc);
create table public.visit_events (id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade, visit_at timestamptz not null, visit_type text not null default 'regular', facility_label text, next_visit_at timestamptz, memo text, details jsonb not null default '{}'::jsonb, created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create index visit_events_user_visit_at_idx on public.visit_events (user_id, visit_at desc);

alter table public.user_conditions enable row level security;
alter table public.user_tracking_metrics enable row level security;
alter table public.user_preferences enable row level security;
alter table public.meals enable row level security;
alter table public.condition_logs enable row level security;
alter table public.bowel_logs enable row level security;
alter table public.visit_events enable row level security;
revoke all on table public.user_conditions, public.user_tracking_metrics, public.user_preferences, public.meals, public.condition_logs, public.bowel_logs, public.visit_events from anon;
grant select, insert, update, delete on table public.user_conditions, public.user_tracking_metrics, public.user_preferences, public.meals, public.condition_logs, public.bowel_logs, public.visit_events to authenticated;

do $policies$
declare table_name text;
begin
  foreach table_name in array array['user_conditions', 'user_tracking_metrics', 'user_preferences', 'meals', 'condition_logs', 'bowel_logs', 'visit_events'] loop
    execute format('create policy %I on public.%I for select to authenticated using ((select auth.uid()) = user_id)', table_name || '_select_own', table_name);
    execute format('create policy %I on public.%I for insert to authenticated with check ((select auth.uid()) = user_id)', table_name || '_insert_own', table_name);
    execute format('create policy %I on public.%I for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id)', table_name || '_update_own', table_name);
    execute format('create policy %I on public.%I for delete to authenticated using ((select auth.uid()) = user_id)', table_name || '_delete_own', table_name);
  end loop;
end
$policies$;

insert into storage.buckets (id, name, public) values ('meals', 'meals', false) on conflict (id) do update set public = false;
create policy meals_storage_select_own on storage.objects for select to authenticated using (bucket_id = 'meals' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy meals_storage_insert_own on storage.objects for insert to authenticated with check (bucket_id = 'meals' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy meals_storage_update_own on storage.objects for update to authenticated using (bucket_id = 'meals' and (storage.foldername(name))[1] = (select auth.uid())::text) with check (bucket_id = 'meals' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy meals_storage_delete_own on storage.objects for delete to authenticated using (bucket_id = 'meals' and (storage.foldername(name))[1] = (select auth.uid())::text);
