begin;
create table public.alcohol_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  recorded_at timestamptz not null,
  drink_type text not null,
  servings numeric(10,2) not null check(servings>0),
  glass_label text not null,
  glass_ml numeric(10,2) not null check(glass_ml>0),
  total_ml numeric(12,2) not null check(total_ml>0),
  memo text,
  created_at timestamptz not null default now()
);
create index alcohol_logs_user_time on public.alcohol_logs(user_id,recorded_at);
alter table public.alcohol_logs enable row level security;
create policy alcohol_owner on public.alcohol_logs for all to authenticated
  using((select auth.uid())=user_id) with check((select auth.uid())=user_id);
grant select,insert,update,delete on public.alcohol_logs to authenticated;
commit;
