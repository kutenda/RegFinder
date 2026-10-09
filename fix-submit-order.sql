-- RegFinder hotfix: customer enquiry RPC
-- Run this once in Supabase > SQL Editor.
-- Recreates submit_order with the parameter names used by the live website.
-- DROP is required because PostgreSQL will not rename existing function input parameters with CREATE OR REPLACE.

drop function if exists public.submit_order(text,text,text);

create function public.submit_order(
  p_registration_text text,
  p_customer_name text,
  p_customer_email text
)
returns table(
  reference text,
  registration_text text,
  total numeric,
  status text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reg public.registrations%rowtype;
  v_fee numeric;
  v_ref text;
begin
  if length(trim(coalesce(p_registration_text,''))) < 1
     or length(trim(coalesce(p_customer_name,''))) < 1
     or length(trim(coalesce(p_customer_email,''))) < 3 then
    raise exception 'Required fields missing';
  end if;

  select r.*
    into v_reg
  from public.registrations as r
  where upper(r.registration) = upper(trim(p_registration_text))
    and r.status = 'verified'
  limit 1;

  if v_reg.id is null then
    raise exception 'Registration is not currently verified';
  end if;

  select f.service_fee
    into v_fee
  from public.fee_tiers as f
  where f.max_source_price is null
     or v_reg.source_price <= f.max_source_price
  order by f.sort_order
  limit 1;

  if v_fee is null then
    raise exception 'Pricing is not configured';
  end if;

  v_ref := 'RF-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,8));

  insert into public.orders(
    reference,
    registration_id,
    registration_text,
    customer_name,
    customer_email,
    source_price,
    service_fee,
    total,
    status
  ) values (
    v_ref,
    v_reg.id,
    v_reg.registration,
    left(trim(p_customer_name),120),
    left(lower(trim(p_customer_email)),254),
    v_reg.source_price,
    v_fee,
    v_reg.source_price + v_fee,
    'awaiting_verification'
  );

  return query
  select
    v_ref::text,
    v_reg.registration::text,
    (v_reg.source_price + v_fee)::numeric,
    'awaiting_verification'::text;
end;
$$;

revoke all on function public.submit_order(text,text,text) from public;
grant execute on function public.submit_order(text,text,text) to anon, authenticated;
