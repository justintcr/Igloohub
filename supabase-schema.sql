-- ============================================================
-- IGLOO HUB — DATABASE SCHEMA
-- The Cool Roofing Co. · 4 September 2026
--
-- Paste this whole file into Supabase → SQL Editor → New query,
-- then click Run. It should report: Success. No rows returned.
--
-- Safe to run more than once. Nothing is deleted.
-- ============================================================


-- ------------------------------------------------------------
-- 1. TEAM
-- Maps each Supabase login to a person, their PIN and their role.
-- The app looks a person up here after they sign in.
-- ------------------------------------------------------------
create table if not exists app_users (
  id          uuid primary key references auth.users(id) on delete cascade,
  pin         text not null unique,
  name        text not null,
  title       text not null,
  role        text not null check (role in ('admin','manager','rep','office')),
  active      boolean not null default true,
  created_at  timestamptz not null default now()
);

comment on table app_users is
  'One row per person. id must match the Supabase Authentication user.';


-- ------------------------------------------------------------
-- 2. RECORDS
-- Every estimate presented and every job signed. CRC-1041 onward.
-- ------------------------------------------------------------
create table if not exists records (
  no            text primary key,
  ts            timestamptz not null default now(),
  status        text not null default 'Presented'
                check (status in ('Presented','Signed','Lost')),
  rep           text,
  rep_id        uuid references auth.users(id),

  address       text,
  customer      text,
  phone         text,
  roofr         text,

  pkg           text,
  product       text,
  color         text,

  squares       numeric,
  facets        integer,
  complexity    text,
  pitch         text,
  layers        text,
  vaulted       boolean default false,

  par_sq        numeric,
  sale_sq       numeric,
  above         numeric,
  total         numeric,
  deposit       numeric,
  extras        numeric default 0,
  base_pay      numeric,
  tier_pct      integer,

  quoted        jsonb default '[]'::jsonb,
  measurements  jsonb default '{}'::jsonb,
  inspection    jsonb default '{}'::jsonb,

  fin_plan      text,
  lost_why      text,
  note          text,
  roofr_sent_at timestamptz,
  signed_at     timestamptz,

  device        text,
  updated_at    timestamptz not null default now()
);

create index if not exists records_rep_idx    on records(rep);
create index if not exists records_status_idx on records(status);
create index if not exists records_ts_idx     on records(ts desc);


-- ------------------------------------------------------------
-- 3. LEADS
-- What Cindy assigns out to the reps.
-- ------------------------------------------------------------
create table if not exists leads (
  id           text primary key,
  created_at   timestamptz not null default now(),

  name         text,
  address      text,
  phone        text,
  source       text,
  received     text,

  assigned_to  text,
  assigned_id  uuid references auth.users(id),
  status       text not null default 'New'
               check (status in ('New','Contacted','Appointment set',
                                 'Presented','Signed','Lost')),

  appt_date    date,
  appt_time    text,

  roofr        text,
  squares      numeric,
  notes        text,
  record_no    text references records(no),
  updated_at   timestamptz not null default now()
);

create index if not exists leads_assigned_idx on leads(assigned_to);
create index if not exists leads_status_idx   on leads(status);
create index if not exists leads_appt_idx     on leads(appt_date);


-- ------------------------------------------------------------
-- 4. WORKSHEETS
-- One row per rep per week. Weekly period, Monday to Sunday.
-- ------------------------------------------------------------
create table if not exists worksheets (
  id            uuid primary key default gen_random_uuid(),
  rep           text not null,
  rep_id        uuid references auth.users(id),
  week_start    date not null,

  status        text not null default 'draft'
                check (status in ('draft','submitted','approved')),
  start_volume  numeric default 0,
  start_manual  boolean default false,

  submitted_at  timestamptz,
  approved_at   timestamptz,
  approved_by   text,

  updated_at    timestamptz not null default now(),
  unique (rep, week_start)
);

create index if not exists worksheets_week_idx on worksheets(week_start desc);


-- ------------------------------------------------------------
-- 5. WORKSHEET ROWS
-- Up to ten jobs per week. Auto-filled from records or typed by hand.
-- ------------------------------------------------------------
create table if not exists worksheet_rows (
  id            uuid primary key default gen_random_uuid(),
  worksheet_id  uuid not null references worksheets(id) on delete cascade,
  position      integer not null,

  source        text not null default 'manual'
                check (source in ('record','manual')),
  record_no     text references records(no),

  job_date      date,
  customer      text,
  pkg_id        text,
  complexity    text,
  sold_squares  numeric,
  sale_sq       numeric,
  par_sq        numeric,
  par_override  boolean default false,

  fin_plan      text,
  fee_share     numeric default 0,
  note          text,

  edited_by     text,
  edited_at     timestamptz,
  updated_at    timestamptz not null default now(),
  unique (worksheet_id, position)
);


-- ------------------------------------------------------------
-- 6. JOB STATE
-- Production stage and deposit status, kept apart from the record
-- so Dawson and Jennifer can move a job without touching the sale.
-- ------------------------------------------------------------
create table if not exists job_state (
  record_no    text primary key references records(no) on delete cascade,
  stage        text not null default 'deposit'
               check (stage in ('deposit','materials','scheduled',
                                'building','punch','done')),
  deposit_paid boolean not null default false,
  deposit_at   timestamptz,
  crew         text,
  build_date   date,
  pm           text,
  notes        text,
  updated_at   timestamptz not null default now()
);


-- ============================================================
-- SECURITY
-- Row Level Security is on for every table. Nothing is readable
-- without a signed-in account.
-- ============================================================

alter table app_users      enable row level security;
alter table records        enable row level security;
alter table leads          enable row level security;
alter table worksheets     enable row level security;
alter table worksheet_rows enable row level security;
alter table job_state      enable row level security;


-- Helper: is the signed-in person an admin, manager or office?
create or replace function is_staff()
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1 from app_users
    where id = auth.uid()
      and active
      and role in ('admin','manager','office')
  );
$$;

-- Helper: the signed-in person's display name
create or replace function my_name()
returns text
language sql
security definer
set search_path = public
as $$
  select name from app_users where id = auth.uid();
$$;


-- --- app_users -----------------------------------------------
drop policy if exists "read team" on app_users;
create policy "read team" on app_users
  for select using (auth.uid() is not null);


-- --- records -------------------------------------------------
-- Reps see only their own. Staff see everything.
drop policy if exists "read records" on records;
create policy "read records" on records
  for select using (is_staff() or rep = my_name());

drop policy if exists "write records" on records;
create policy "write records" on records
  for insert with check (is_staff() or rep = my_name());

drop policy if exists "update records" on records;
create policy "update records" on records
  for update using (is_staff() or rep = my_name());

drop policy if exists "delete records" on records;
create policy "delete records" on records
  for delete using (is_staff() or rep = my_name());


-- --- leads ---------------------------------------------------
-- Reps see their own plus anything unassigned. Staff see everything.
drop policy if exists "read leads" on leads;
create policy "read leads" on leads
  for select using (
    is_staff() or assigned_to = my_name() or assigned_to is null
  );

drop policy if exists "write leads" on leads;
create policy "write leads" on leads
  for insert with check (is_staff());

drop policy if exists "update leads" on leads;
create policy "update leads" on leads
  for update using (is_staff() or assigned_to = my_name());

drop policy if exists "delete leads" on leads;
create policy "delete leads" on leads
  for delete using (is_staff());


-- --- worksheets ----------------------------------------------
drop policy if exists "read worksheets" on worksheets;
create policy "read worksheets" on worksheets
  for select using (is_staff() or rep = my_name());

drop policy if exists "write worksheets" on worksheets;
create policy "write worksheets" on worksheets
  for insert with check (is_staff() or rep = my_name());

-- A rep can edit their own week only while it is still a draft.
-- Staff can edit any week, which is how Jennifer reopens one.
drop policy if exists "update worksheets" on worksheets;
create policy "update worksheets" on worksheets
  for update using (
    is_staff() or (rep = my_name() and status = 'draft')
  );


-- --- worksheet rows ------------------------------------------
drop policy if exists "read rows" on worksheet_rows;
create policy "read rows" on worksheet_rows
  for select using (
    exists (
      select 1 from worksheets w
      where w.id = worksheet_id
        and (is_staff() or w.rep = my_name())
    )
  );

drop policy if exists "write rows" on worksheet_rows;
create policy "write rows" on worksheet_rows
  for insert with check (
    exists (
      select 1 from worksheets w
      where w.id = worksheet_id
        and (is_staff() or (w.rep = my_name() and w.status = 'draft'))
    )
  );

drop policy if exists "update rows" on worksheet_rows;
create policy "update rows" on worksheet_rows
  for update using (
    exists (
      select 1 from worksheets w
      where w.id = worksheet_id
        and (is_staff() or (w.rep = my_name() and w.status = 'draft'))
    )
  );

drop policy if exists "delete rows" on worksheet_rows;
create policy "delete rows" on worksheet_rows
  for delete using (
    exists (
      select 1 from worksheets w
      where w.id = worksheet_id
        and (is_staff() or (w.rep = my_name() and w.status = 'draft'))
    )
  );


-- --- job state -----------------------------------------------
-- Everyone signed in can read the board. Only staff move a job.
drop policy if exists "read job state" on job_state;
create policy "read job state" on job_state
  for select using (auth.uid() is not null);

drop policy if exists "write job state" on job_state;
create policy "write job state" on job_state
  for insert with check (is_staff());

drop policy if exists "update job state" on job_state;
create policy "update job state" on job_state
  for update using (is_staff());


-- ============================================================
-- HOUSEKEEPING
-- Stamp updated_at on every change, so the app can sync only
-- what has moved since it last looked.
-- ============================================================

create or replace function touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

do $$
declare t text;
begin
  foreach t in array array['records','leads','worksheets',
                           'worksheet_rows','job_state']
  loop
    execute format(
      'drop trigger if exists touch_%1$s on %1$s;
       create trigger touch_%1$s before update on %1$s
       for each row execute function touch_updated_at();', t);
  end loop;
end $$;


-- Live updates, so a change on one device appears on the others
-- without anyone refreshing.
do $$
begin
  begin
    alter publication supabase_realtime add table records;
  exception when duplicate_object then null; end;
  begin
    alter publication supabase_realtime add table leads;
  exception when duplicate_object then null; end;
  begin
    alter publication supabase_realtime add table job_state;
  exception when duplicate_object then null; end;
  begin
    alter publication supabase_realtime add table worksheets;
  exception when duplicate_object then null; end;
  begin
    alter publication supabase_realtime add table worksheet_rows;
  exception when duplicate_object then null; end;
end $$;


-- ============================================================
-- STEP 4 FOLLOW-UP — link the seven accounts
--
-- After you have created the seven users under Authentication,
-- come back here, run the SELECT below to get their ids, then
-- fill in the INSERT and run it.
-- ============================================================

-- select id, email from auth.users order by created_at;

-- insert into app_users (id, pin, name, title, role) values
--   ('paste-id-here', '1101', 'David Henry',    'Owner',                        'admin'),
--   ('paste-id-here', '1102', 'Justin Lee',     'Business development manager',  'admin'),
--   ('paste-id-here', '1103', 'Jackson Lee',    'Sales & production utility',    'rep'),
--   ('paste-id-here', '1104', 'John Nava',      'Sales representative',          'rep'),
--   ('paste-id-here', '1105', 'Dawson Henry',   'Production manager',            'admin'),
--   ('paste-id-here', '1106', 'Jennifer Henry', 'Finance',                       'admin'),
--   ('paste-id-here', '1107', 'Cindy DePree',   'Office coordinator',            'office')
-- on conflict (id) do update set
--   pin = excluded.pin, name = excluded.name,
--   title = excluded.title, role = excluded.role;
