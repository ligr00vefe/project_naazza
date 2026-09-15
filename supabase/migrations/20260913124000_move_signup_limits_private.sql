alter table public.signup_rate_limits set schema private;

create or replace function public.consume_signup_attempt(p_client_key text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_allowed boolean;
begin
  insert into private.signup_rate_limits (client_key, attempts)
  values (p_client_key, 1)
  on conflict (client_key) do update
  set
    window_started_at = case
      when private.signup_rate_limits.window_started_at < now() - interval '1 hour'
      then now()
      else private.signup_rate_limits.window_started_at
    end,
    attempts = case
      when private.signup_rate_limits.window_started_at < now() - interval '1 hour'
      then 1
      else private.signup_rate_limits.attempts + 1
    end
  returning attempts <= 10 into v_allowed;

  return v_allowed;
end;
$$;

revoke all on function public.consume_signup_attempt(text) from public, anon, authenticated;
grant execute on function public.consume_signup_attempt(text) to service_role;
