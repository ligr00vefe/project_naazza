alter table public.bowel_logs
  add column had_bowel_movement boolean not null default true,
  add column constipation boolean not null default false;
alter table public.bowel_logs alter column bristol_type drop not null;
alter table public.bowel_logs add constraint bowel_logs_movement_form_check
  check ((had_bowel_movement and bristol_type is not null) or (not had_bowel_movement and bristol_type is null));
