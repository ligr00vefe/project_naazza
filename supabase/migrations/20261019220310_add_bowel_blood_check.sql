-- NULL distinguishes historical unrecorded status from an explicit negative.
alter table public.bowel_logs add column blood_in_stool boolean;
comment on column public.bowel_logs.blood_in_stool is 'User-reported visible blood; null means not recorded. Not a diagnosis.';
