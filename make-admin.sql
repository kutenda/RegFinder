-- RegFinder: promote the Supabase Auth account to administrator
-- Run this AFTER creating/signing up the user kutendar@gmail.com in Supabase Authentication.

insert into public.profiles (id, role)
select id, 'admin'
from auth.users
where lower(email) = lower('kutendar@gmail.com')
on conflict (id) do update set role = 'admin';

-- Confirm the account was found and promoted.
select u.email, p.role
from auth.users u
join public.profiles p on p.id = u.id
where lower(u.email) = lower('kutendar@gmail.com');
