-- Symptom lifecycle is supplementary user-entered data. Existing owner RLS on
-- condition_logs remains in force. No new public table or authorization claim.
alter table public.condition_logs add column if not exists details jsonb not null default '{}'::jsonb;
