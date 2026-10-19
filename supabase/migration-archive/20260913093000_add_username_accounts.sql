create table public.accounts (
  user_id uuid primary key references auth.users(id) on delete cascade,
  username text not null unique,
  email text null,
  role text not null default 'member',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint accounts_username_format check (
    username = lower(username)
    and username ~ '^[a-z0-9_]{3,20}$'
  ),
  constraint accounts_email_format check (
    email is null or email ~* '^[^@[:space:]]+@[^@[:space:]]+[.][^@[:space:]]+$'
  ),
  constraint accounts_role_check check (role in ('member', 'admin'))
);

alter table public.accounts enable row level security;

create policy accounts_select_own
on public.accounts for select
to authenticated
using ((select auth.uid()) = user_id);

create policy accounts_update_own
on public.accounts for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

grant select on public.accounts to authenticated;
grant update (email) on public.accounts to authenticated;
revoke all on public.accounts from anon;

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create or replace function private.handle_new_naazza_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_username text := lower(new.raw_user_meta_data ->> 'username');
  v_email text := nullif(new.raw_user_meta_data ->> 'email', '');
begin
  if v_username is null or v_username !~ '^[a-z0-9_]{3,20}$' then
    raise exception 'invalid username';
  end if;

  insert into public.accounts (user_id, username, email)
  values (new.id, v_username, v_email);

  return new;
end;
$$;

revoke all on function private.handle_new_naazza_user() from public, anon, authenticated;

create trigger on_auth_user_created_create_account
after insert on auth.users
for each row execute function private.handle_new_naazza_user();

create table public.signup_rate_limits (
  client_key text primary key,
  window_started_at timestamptz not null default now(),
  attempts integer not null default 0
);

alter table public.signup_rate_limits enable row level security;
revoke all on public.signup_rate_limits from public, anon, authenticated;

create or replace function public.consume_signup_attempt(p_client_key text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_allowed boolean;
begin
  insert into public.signup_rate_limits (client_key, attempts)
  values (p_client_key, 1)
  on conflict (client_key) do update
  set
    window_started_at = case
      when public.signup_rate_limits.window_started_at < now() - interval '1 hour'
      then now()
      else public.signup_rate_limits.window_started_at
    end,
    attempts = case
      when public.signup_rate_limits.window_started_at < now() - interval '1 hour'
      then 1
      else public.signup_rate_limits.attempts + 1
    end
  returning attempts <= 10 into v_allowed;

  return v_allowed;
end;
$$;

revoke all on function public.consume_signup_attempt(text) from public, anon, authenticated;
grant execute on function public.consume_signup_attempt(text) to service_role;
