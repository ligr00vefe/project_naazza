create table public.water_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  drunk_on date not null,
  cups smallint not null check (cups between 0 and 7),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, drunk_on)
);
alter table public.water_logs enable row level security;
revoke all on public.water_logs from anon;
grant select,insert,update,delete on public.water_logs to authenticated;
create policy water_logs_select_own on public.water_logs for select to authenticated using ((select auth.uid())=user_id);
create policy water_logs_insert_own on public.water_logs for insert to authenticated with check ((select auth.uid())=user_id);
create policy water_logs_update_own on public.water_logs for update to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id);
create policy water_logs_delete_own on public.water_logs for delete to authenticated using ((select auth.uid())=user_id);
