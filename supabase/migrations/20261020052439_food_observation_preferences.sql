create table if not exists public.food_observation_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  watches jsonb not null default '[]'::jsonb check (jsonb_typeof(watches) = 'array'),
  updated_at timestamptz not null default now()
);
alter table public.food_observation_preferences enable row level security;
revoke all on public.food_observation_preferences from anon;
grant select, insert, update, delete on public.food_observation_preferences to authenticated;
create policy food_observation_preferences_select_own on public.food_observation_preferences
  for select to authenticated using ((select auth.uid()) = user_id);
create policy food_observation_preferences_insert_own on public.food_observation_preferences
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy food_observation_preferences_update_own on public.food_observation_preferences
  for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy food_observation_preferences_delete_own on public.food_observation_preferences
  for delete to authenticated using ((select auth.uid()) = user_id);
