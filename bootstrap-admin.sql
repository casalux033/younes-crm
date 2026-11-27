-- Run this only AFTER creating the initial Auth user in Supabase Dashboard.
-- Auth > Users > Add user:
--   Email: admin@younes-crm.internal
--   Password: choose the temporary password privately
--   Confirm user / Auto-confirm: enabled
--
-- This SQL grants the first account CRM access and creates its profile.
-- It does not contain or change the user's password.

update auth.users
set raw_app_meta_data =
  coalesce(raw_app_meta_data, '{}'::jsonb)
  || jsonb_build_object('crm_access', true, 'crm_role', 'admin')
where lower(email) = 'admin@younes-crm.internal';

insert into public.crm_profiles
  (id, username, display_name, role, is_active, must_change_password)
select
  id, 'admin', 'YOUNES Admin', 'admin', true, true
from auth.users
where lower(email) = 'admin@younes-crm.internal'
on conflict (id) do update
set username = excluded.username,
    display_name = excluded.display_name,
    role = 'admin',
    is_active = true,
    must_change_password = true;

-- Verify: should return exactly one row.
select p.username, p.role, p.is_active, p.must_change_password
from public.crm_profiles p
join auth.users u on u.id = p.id
where lower(u.email) = 'admin@younes-crm.internal';
