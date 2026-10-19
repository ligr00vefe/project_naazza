alter table public.alcohol_logs
  add column details jsonb not null default '{}'::jsonb
  constraint alcohol_details_object check (jsonb_typeof(details) = 'object');
