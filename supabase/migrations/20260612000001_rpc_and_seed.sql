-- ─── increment_civic_score RPC ────────────────────────────────────────────────
create or replace function public.increment_civic_score(user_id uuid, points integer)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update profiles
  set civic_score = civic_score + points
  where id = user_id;
end;
$$;

grant execute on function public.increment_civic_score(uuid, integer) to authenticated;

-- ─── Trigger: auto-increment reports_submitted on insert ─────────────────────
create or replace function public.on_report_inserted()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update profiles
  set
    reports_submitted = reports_submitted + 1,
    civic_score       = civic_score + 10
  where id = new.user_id;
  return new;
end;
$$;

drop trigger if exists trg_report_inserted on public.reports;
create trigger trg_report_inserted
  after insert on public.reports
  for each row execute function public.on_report_inserted();

-- ─── Trigger: increment reports_resolved when status → resolved ───────────────
create or replace function public.on_report_resolved()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'resolved' and old.status <> 'resolved' then
    update profiles
    set
      reports_resolved = reports_resolved + 1,
      civic_score      = civic_score + 20
    where id = new.user_id;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_report_resolved on public.reports;
create trigger trg_report_resolved
  after update on public.reports
  for each row execute function public.on_report_resolved();

-- ─── Trigger: increment appreciations_given on insert ────────────────────────
create or replace function public.on_appreciation_inserted()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update profiles
  set
    appreciations_given = appreciations_given + 1,
    civic_score         = civic_score + 5
  where id = new.user_id;
  return new;
end;
$$;

drop trigger if exists trg_appreciation_inserted on public.appreciations;
create trigger trg_appreciation_inserted
  after insert on public.appreciations
  for each row execute function public.on_appreciation_inserted();

-- ─── Seed: public officials ───────────────────────────────────────────────────
insert into public.public_officials (name, role, department, city, avatar_url)
values
  ('Rajesh Kumar Sharma',  'Municipal Commissioner',        'Municipal Corporation',   'Mumbai', null),
  ('Priya Nair',           'Deputy Municipal Commissioner', 'Water Supply Department', 'Mumbai', null),
  ('Anil Deshmukh',        'Chief Engineer',                'Roads & Infrastructure',  'Mumbai', null),
  ('Sunita Patil',         'Collector',                     'District Administration', 'Pune',   null),
  ('Vijay Mehta',          'Mayor',                         'Municipal Corporation',   'Pune',   null),
  ('Lakshmi Krishnan',     'Commissioner',                  'Traffic Police',          'Chennai',null),
  ('Rahul Verma',          'Chief Medical Officer',         'Health Department',       'Delhi',  null),
  ('Meera Joshi',          'Director',                      'Sanitation Department',   'Mumbai', null)
on conflict do nothing;
