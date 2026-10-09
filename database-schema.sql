-- RegFinder production database schema
create extension if not exists pgcrypto;

create table if not exists registrations (
  id uuid primary key default gen_random_uuid(),
  registration text unique not null,
  source_price numeric(12,2) not null,
  style text not null check (style in ('Current','Prefix','Suffix','Dateless')),
  vehicle_age_note text,
  source_name text,
  source_reference text,
  source_checked_at timestamptz,
  status text not null default 'pending' check (status in ('pending','verified','unavailable','sold','hidden')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists fee_tiers (
  id bigint generated always as identity primary key,
  max_source_price numeric(12,2),
  service_fee numeric(12,2) not null,
  sort_order int not null
);

create table if not exists finder_leads (
  id uuid primary key default gen_random_uuid(),
  wanted text not null,
  budget text,
  vehicle_year text,
  email text not null,
  status text not null default 'new',
  created_at timestamptz not null default now()
);

create table if not exists orders (
  id uuid primary key default gen_random_uuid(),
  reference text unique not null,
  registration_id uuid references registrations(id),
  registration_text text not null,
  customer_name text not null,
  customer_email text not null,
  source_price numeric(12,2) not null,
  service_fee numeric(12,2) not null,
  total numeric(12,2) not null,
  status text not null default 'awaiting_verification',
  payment_reference text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists registrations_registration_idx on registrations (registration);
create index if not exists orders_email_idx on orders (customer_email);
create index if not exists orders_reference_idx on orders (reference);

-- Enable RLS before production and expose writes only through authenticated/admin
-- or server-side endpoints. Do not give anonymous clients unrestricted table writes.
alter table registrations enable row level security;
alter table fee_tiers enable row level security;
alter table finder_leads enable row level security;
alter table orders enable row level security;
