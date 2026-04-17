-- CareFlow E-Health demo schema.
-- Run this in the Supabase SQL editor for project ktbpsliejglodmonmzhs.
-- The policies below are intentionally permissive for a public demo app.
-- Replace them with authenticated, role-based policies for real clinical use.

create extension if not exists pgcrypto;

create table if not exists patients (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  date_of_birth date not null,
  preferred_language text not null default 'English',
  risk_level text not null default 'Moderate',
  care_goal text not null default '',
  created_at timestamptz not null default now()
);

create table if not exists clinicians (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  specialty text not null,
  accepting_appointments boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists appointments (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references patients(id) on delete cascade,
  clinician_id uuid references clinicians(id) on delete set null,
  scheduled_start timestamptz not null,
  scheduled_end timestamptz not null,
  type text not null default 'Telehealth',
  status text not null default 'Requested',
  reason text not null,
  created_at timestamptz not null default now(),
  constraint appointments_time_order check (scheduled_start < scheduled_end)
);

create table if not exists encounters (
  id uuid primary key default gen_random_uuid(),
  appointment_id uuid references appointments(id) on delete set null,
  patient_id uuid not null references patients(id) on delete cascade,
  clinician_id uuid references clinicians(id) on delete set null,
  status text not null default 'NotStarted',
  chief_complaint text not null default '',
  assessment text not null default '',
  plan text not null default '',
  started_at timestamptz default now(),
  ended_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists prescriptions (
  id uuid primary key default gen_random_uuid(),
  encounter_id uuid references encounters(id) on delete set null,
  patient_id uuid not null references patients(id) on delete cascade,
  clinician_id uuid references clinicians(id) on delete set null,
  status text not null default 'Draft',
  medication_name text not null,
  dose text not null,
  route text not null default 'Oral',
  frequency text not null,
  repeats integer not null default 0 check (repeats >= 0),
  issued_at timestamptz default now(),
  expires_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists lab_orders (
  id uuid primary key default gen_random_uuid(),
  encounter_id uuid references encounters(id) on delete set null,
  patient_id uuid not null references patients(id) on delete cascade,
  clinician_id uuid references clinicians(id) on delete set null,
  test_name text not null,
  status text not null default 'Ordered',
  flag text not null default 'Pending',
  ordered_at timestamptz default now(),
  created_at timestamptz not null default now()
);

create table if not exists vital_observations (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references patients(id) on delete cascade,
  type text not null,
  value numeric not null,
  unit text not null,
  source text not null default 'Manual',
  observed_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table if not exists clinical_alerts (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references patients(id) on delete cascade,
  vital_observation_id uuid references vital_observations(id) on delete set null,
  lab_order_id uuid references lab_orders(id) on delete set null,
  type text not null,
  severity text not null,
  status text not null default 'Raised',
  message text not null,
  raised_at timestamptz default now(),
  resolved_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists message_threads (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references patients(id) on delete cascade,
  subject text not null,
  status text not null default 'Open',
  latest_message text not null,
  priority text not null default 'Routine',
  created_at timestamptz not null default now(),
  closed_at timestamptz
);

create table if not exists audit_events (
  id uuid primary key default gen_random_uuid(),
  actor_name text not null,
  action text not null,
  resource_type text not null,
  resource_id uuid not null,
  occurred_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

alter table patients enable row level security;
alter table clinicians enable row level security;
alter table appointments enable row level security;
alter table encounters enable row level security;
alter table prescriptions enable row level security;
alter table lab_orders enable row level security;
alter table vital_observations enable row level security;
alter table clinical_alerts enable row level security;
alter table message_threads enable row level security;
alter table audit_events enable row level security;

drop policy if exists "demo anon access" on patients;
drop policy if exists "demo anon access" on clinicians;
drop policy if exists "demo anon access" on appointments;
drop policy if exists "demo anon access" on encounters;
drop policy if exists "demo anon access" on prescriptions;
drop policy if exists "demo anon access" on lab_orders;
drop policy if exists "demo anon access" on vital_observations;
drop policy if exists "demo anon access" on clinical_alerts;
drop policy if exists "demo anon access" on message_threads;
drop policy if exists "demo anon access" on audit_events;

create policy "demo anon access" on patients for all to anon using (true) with check (true);
create policy "demo anon access" on clinicians for all to anon using (true) with check (true);
create policy "demo anon access" on appointments for all to anon using (true) with check (true);
create policy "demo anon access" on encounters for all to anon using (true) with check (true);
create policy "demo anon access" on prescriptions for all to anon using (true) with check (true);
create policy "demo anon access" on lab_orders for all to anon using (true) with check (true);
create policy "demo anon access" on vital_observations for all to anon using (true) with check (true);
create policy "demo anon access" on clinical_alerts for all to anon using (true) with check (true);
create policy "demo anon access" on message_threads for all to anon using (true) with check (true);
create policy "demo anon access" on audit_events for all to anon using (true) with check (true);

create index if not exists appointments_patient_idx on appointments(patient_id);
create index if not exists encounters_patient_idx on encounters(patient_id);
create index if not exists prescriptions_patient_idx on prescriptions(patient_id);
create index if not exists lab_orders_patient_idx on lab_orders(patient_id);
create index if not exists vital_observations_patient_idx on vital_observations(patient_id);
create index if not exists clinical_alerts_patient_idx on clinical_alerts(patient_id);
create index if not exists message_threads_patient_idx on message_threads(patient_id);
