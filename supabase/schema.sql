-- CivicLens AI — Supabase Schema
-- Run this in the Supabase SQL editor

-- Enable PostGIS for geo queries
create extension if not exists postgis;

-- ─── PROFILES ────────────────────────────────────────────────────────────────
create table public.profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  full_name    text not null,
  city         text not null,
  avatar_url   text,
  role         text not null default 'citizen',  -- citizen | official | admin
  civic_score  integer not null default 0,
  reports_submitted  integer not null default 0,
  reports_resolved   integer not null default 0,
  appreciations_given integer not null default 0,
  badges       text[] not null default '{}',
  created_at   timestamptz not null default now()
);
alter table public.profiles enable row level security;
create policy "Users can view all profiles" on public.profiles for select using (true);
create policy "Users update own profile" on public.profiles for update using (auth.uid() = id);

-- Auto-create profile on sign-up
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.profiles (id, full_name, city)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', 'Anonymous'),
    coalesce(new.raw_user_meta_data->>'city', 'Unknown')
  );
  return new;
end;
$$;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ─── REPORTS ─────────────────────────────────────────────────────────────────
create table public.reports (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references public.profiles(id) on delete cascade,
  title          text not null,
  description    text not null,
  category       text not null,    -- infrastructure | environment | safety | public_service | appreciation | other
  severity       text not null,    -- low | medium | high | critical
  status         text not null default 'pending',  -- pending | under_review | in_progress | resolved | closed
  latitude       double precision not null,
  longitude      double precision not null,
  location       geography(Point, 4326),  -- computed column for geo queries
  address        text not null,
  city           text not null,
  image_urls     text[] not null default '{}',
  tags           text[] not null default '{}',
  department     text,
  ai_summary     text,
  official_response text,
  upvote_count   integer not null default 0,
  is_anonymous   boolean not null default false,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz,
  resolved_at    timestamptz
);

-- Populate geography column automatically
create or replace function public.reports_set_location()
returns trigger language plpgsql as $$
begin
  new.location = st_setsrid(st_makepoint(new.longitude, new.latitude), 4326);
  return new;
end;
$$;
create trigger reports_location_trigger
  before insert or update on public.reports
  for each row execute procedure public.reports_set_location();

alter table public.reports enable row level security;
create policy "Anyone can view reports" on public.reports for select using (true);
create policy "Auth users can insert" on public.reports for insert with check (auth.uid() = user_id);
create policy "Owner can update" on public.reports for update using (auth.uid() = user_id);

-- Geo query RPC
create or replace function public.reports_within_radius(lat double precision, lng double precision, radius_km double precision)
returns setof public.reports language sql as $$
  select * from public.reports
  where st_dwithin(
    location,
    st_setsrid(st_makepoint(lng, lat), 4326)::geography,
    radius_km * 1000
  )
  order by created_at desc;
$$;

-- Upvote RPC
create or replace function public.increment_report_upvote(report_id uuid)
returns void language sql as $$
  update public.reports set upvote_count = upvote_count + 1 where id = report_id;
$$;

-- ─── PUBLIC OFFICIALS ────────────────────────────────────────────────────────
create table public.public_officials (
  id                 uuid primary key default gen_random_uuid(),
  name               text not null,
  role               text not null,
  department         text not null,
  city               text not null,
  avatar_url         text,
  appreciation_count integer not null default 0,
  resolved_issues    integer not null default 0,
  performance_score  double precision not null default 0.0,
  created_at         timestamptz not null default now()
);
alter table public.public_officials enable row level security;
create policy "Anyone can view officials" on public.public_officials for select using (true);

-- ─── APPRECIATIONS ───────────────────────────────────────────────────────────
create table public.appreciations (
  id              uuid primary key default gen_random_uuid(),
  from_user_id    uuid not null references public.profiles(id) on delete cascade,
  to_official_id  uuid not null references public.public_officials(id) on delete cascade,
  official_name   text not null,
  official_role   text not null,
  message         text not null,
  achievement     text,
  department      text,
  is_public       boolean not null default true,
  like_count      integer not null default 0,
  created_at      timestamptz not null default now()
);
alter table public.appreciations enable row level security;
create policy "Anyone can view public appreciations" on public.appreciations
  for select using (is_public = true or auth.uid() = from_user_id);
create policy "Auth users can insert" on public.appreciations
  for insert with check (auth.uid() = from_user_id);

-- Like RPC
create or replace function public.increment_appreciation_like(appreciation_id uuid)
returns void language sql as $$
  update public.appreciations set like_count = like_count + 1 where id = appreciation_id;
$$;

-- ─── NOTIFICATIONS ───────────────────────────────────────────────────────────
create table public.notifications (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles(id) on delete cascade,
  title      text not null,
  body       text not null,
  type       text,   -- report_update | appreciation | resolution | comment
  data       jsonb,
  is_read    boolean not null default false,
  created_at timestamptz not null default now()
);
alter table public.notifications enable row level security;
create policy "Users see own notifications" on public.notifications
  for select using (auth.uid() = user_id);
create policy "Users update own notifications" on public.notifications
  for update using (auth.uid() = user_id);

-- ─── FCM TOKENS ──────────────────────────────────────────────────────────────
create table public.user_fcm_tokens (
  user_id    uuid not null references public.profiles(id) on delete cascade,
  token      text not null,
  updated_at timestamptz not null default now(),
  primary key (user_id, token)
);
alter table public.user_fcm_tokens enable row level security;
create policy "Users manage own tokens" on public.user_fcm_tokens
  for all using (auth.uid() = user_id);

-- ─── STORAGE ─────────────────────────────────────────────────────────────────
insert into storage.buckets (id, name, public)
values ('civic-images', 'civic-images', true)
on conflict do nothing;

create policy "Anyone can view civic images" on storage.objects
  for select using (bucket_id = 'civic-images');
create policy "Auth users can upload" on storage.objects
  for insert with check (bucket_id = 'civic-images' and auth.role() = 'authenticated');
create policy "Owner can delete own images" on storage.objects
  for delete using (bucket_id = 'civic-images' and auth.uid()::text = (storage.foldername(name))[1]);
