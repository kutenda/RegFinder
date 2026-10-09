-- RegFinder production hardening + pricing seed
-- Run this once in Supabase SQL Editor after database-schema.sql.

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'customer' check (role in ('customer','admin')),
  created_at timestamptz not null default now()
);
alter table public.profiles enable row level security;

create or replace function public.is_admin()
returns boolean
language sql stable security definer set search_path=public
as $$ select exists(select 1 from public.profiles where id=auth.uid() and role='admin') $$;

-- Automatically create a customer profile for future Auth users.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path=public
as $$ begin insert into public.profiles(id) values(new.id) on conflict do nothing; return new; end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();

-- Seed the agreed service-fee structure if the table is empty.
insert into public.fee_tiers(max_source_price,service_fee,sort_order)
select * from (values
 (299::numeric,29::numeric,1),(499,39,2),(749,49,3),(999,59,4),(1499,69,5),
 (1999,89,6),(2999,119,7),(4999,149,8),(9999,179,9),(null::numeric,249,10)
) v(max_source_price,service_fee,sort_order)
where not exists(select 1 from public.fee_tiers);

-- Replace permissive prototype policies with production policies.
drop policy if exists "public can submit finder requests" on public.finder_leads;
drop policy if exists "public can submit order enquiries" on public.orders;
drop policy if exists "public can view verified registrations" on public.registrations;
drop policy if exists "public can view fee tiers" on public.fee_tiers;
drop policy if exists "admins manage registrations" on public.registrations;
drop policy if exists "admins manage fee tiers" on public.fee_tiers;
drop policy if exists "admins manage finder leads" on public.finder_leads;
drop policy if exists "admins manage orders" on public.orders;
drop policy if exists "users read own profile" on public.profiles;

create policy "public can view verified registrations" on public.registrations for select to anon, authenticated using(status='verified' or public.is_admin());
create policy "public can view fee tiers" on public.fee_tiers for select to anon, authenticated using(true);
create policy "admins manage registrations" on public.registrations for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "admins manage fee tiers" on public.fee_tiers for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "admins manage finder leads" on public.finder_leads for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "admins manage orders" on public.orders for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "users read own profile" on public.profiles for select to authenticated using(id=auth.uid() or public.is_admin());

-- Public submissions go through validated functions instead of table writes.
revoke insert, update, delete on public.finder_leads from anon;
revoke insert, update, delete on public.orders from anon;

grant select on public.registrations, public.fee_tiers to anon, authenticated;
grant select, insert, update, delete on public.registrations, public.fee_tiers, public.finder_leads, public.orders to authenticated;

create or replace function public.submit_finder_lead(p_wanted text,p_budget text,p_vehicle_year text,p_email text)
returns uuid language plpgsql security definer set search_path=public
as $$ declare v_id uuid; begin
 if length(trim(coalesce(p_wanted,'')))<1 or length(trim(coalesce(p_email,'')))<3 then raise exception 'Required fields missing'; end if;
 insert into public.finder_leads(wanted,budget,vehicle_year,email,status)
 values(left(trim(p_wanted),120),left(trim(coalesce(p_budget,'')),80),nullif(left(trim(coalesce(p_vehicle_year,'')),40),''),left(lower(trim(p_email)),254),'new') returning id into v_id;
 return v_id;
end $$;

grant execute on function public.submit_finder_lead(text,text,text,text) to anon, authenticated;

-- Secure order creation: registration and pricing are looked up server-side.
create or replace function public.submit_order(p_registration text,p_customer_name text,p_customer_email text)
returns table(reference text,registration_text text,total numeric,status text)
language plpgsql security definer set search_path=public
as $$ declare r public.registrations%rowtype; v_fee numeric; v_ref text; begin
 select * into r from public.registrations where upper(registration)=upper(trim(p_registration)) and status='verified' limit 1;
 if r.id is null then raise exception 'Registration is not currently verified'; end if;
 select service_fee into v_fee from public.fee_tiers where max_source_price is null or r.source_price<=max_source_price order by sort_order limit 1;
 if v_fee is null then raise exception 'Pricing is not configured'; end if;
 v_ref:='RF-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,8));
 insert into public.orders(reference,registration_id,registration_text,customer_name,customer_email,source_price,service_fee,total,status)
 values(v_ref,r.id,r.registration,left(trim(p_customer_name),120),left(lower(trim(p_customer_email)),254),r.source_price,v_fee,r.source_price+v_fee,'awaiting_verification');
 return query select v_ref,r.registration,r.source_price+v_fee,'awaiting_verification'::text;
end $$;
grant execute on function public.submit_order(text,text,text) to anon, authenticated;

create or replace function public.track_order(p_reference text,p_email text)
returns table(reference text,registration_text text,total numeric,status text,created_at timestamptz)
language sql security definer set search_path=public
as $$ select o.reference,o.registration_text,o.total,o.status,o.created_at from public.orders o where upper(o.reference)=upper(trim(p_reference)) and lower(o.customer_email)=lower(trim(p_email)) limit 1 $$;
grant execute on function public.track_order(text,text) to anon, authenticated;

-- Admin creation after making an Auth user in Supabase:
-- insert into public.profiles(id,role) values ('AUTH-USER-UUID','admin')
-- on conflict(id) do update set role='admin';
