-- MS HOUSE BARBER module for YOUNES CRM
-- Already applied to project axmtmljpdwmpsclxzldt on 2026-11-27.
insert into public.crm_tenants (slug,name,website,is_active)
values ('ms-house-barber','MS HOUSE BARBER',null,true)
on conflict (slug) do update set name=excluded.name, is_active=true;

create table if not exists public.crm_barbers (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.crm_tenants(id) default public.crm_current_tenant_id(),
  full_name text not null, phone text, specialty text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.crm_barber_services (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.crm_tenants(id) default public.crm_current_tenant_id(),
  name text not null, description text,
  duration_minutes integer not null default 30 check (duration_minutes between 5 and 240),
  price numeric(10,2) not null check (price >= 0),
  barber_fixed_fee numeric(10,2) not null default 0 check (barber_fixed_fee >= 0 and barber_fixed_fee <= price),
  is_active boolean not null default true,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.crm_barber_appointments (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.crm_tenants(id) default public.crm_current_tenant_id(),
  client_name text not null, client_phone text not null,
  barber_id uuid not null references public.crm_barbers(id),
  service_id uuid not null references public.crm_barber_services(id),
  starts_at timestamptz not null, ends_at timestamptz not null,
  status text not null default 'pending' check (status in ('pending','confirmed','in_progress','completed','cancelled','no_show')),
  price numeric(10,2) not null check (price >= 0),
  barber_fixed_fee numeric(10,2) not null default 0 check (barber_fixed_fee >= 0),
  salon_share numeric(10,2) generated always as (price - barber_fixed_fee) stored,
  payment_status text not null default 'unpaid' check (payment_status in ('unpaid','paid')),
  payment_method text check (payment_method in ('cash','card','transfer','other')),
  paid_to_barber boolean not null default false, notes text,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check (ends_at > starts_at), check (barber_fixed_fee <= price)
);
create index if not exists crm_barbers_tenant_idx on public.crm_barbers(tenant_id);
create index if not exists crm_barber_services_tenant_idx on public.crm_barber_services(tenant_id);
create index if not exists crm_barber_appointments_tenant_start_idx on public.crm_barber_appointments(tenant_id, starts_at desc);
create index if not exists crm_barber_appointments_barber_start_idx on public.crm_barber_appointments(barber_id, starts_at);
alter table public.crm_barbers enable row level security;
alter table public.crm_barber_services enable row level security;
alter table public.crm_barber_appointments enable row level security;
create policy "ms barber tenant access" on public.crm_barbers for all to authenticated
using (((select auth.jwt())->'app_metadata'->>'crm_role'='admin') or tenant_id=(select public.crm_current_tenant_id()))
with check (((select auth.jwt())->'app_metadata'->>'crm_role'='admin') or tenant_id=(select public.crm_current_tenant_id()));
create policy "ms barber services tenant access" on public.crm_barber_services for all to authenticated
using (((select auth.jwt())->'app_metadata'->>'crm_role'='admin') or tenant_id=(select public.crm_current_tenant_id()))
with check (((select auth.jwt())->'app_metadata'->>'crm_role'='admin') or tenant_id=(select public.crm_current_tenant_id()));
create policy "ms barber appointments tenant access" on public.crm_barber_appointments for all to authenticated
using (((select auth.jwt())->'app_metadata'->>'crm_role'='admin') or tenant_id=(select public.crm_current_tenant_id()))
with check (((select auth.jwt())->'app_metadata'->>'crm_role'='admin') or tenant_id=(select public.crm_current_tenant_id()));
grant select, insert, update, delete on public.crm_barbers, public.crm_barber_services, public.crm_barber_appointments to authenticated;
grant select on public.crm_barbers, public.crm_barber_services to anon;
create policy "public read active barbers for booking" on public.crm_barbers for select to anon
using (is_active=true and tenant_id=(select id from public.crm_tenants where slug='ms-house-barber' and is_active=true));
create policy "public read active barber services for booking" on public.crm_barber_services for select to anon
using (is_active=true and tenant_id=(select id from public.crm_tenants where slug='ms-house-barber' and is_active=true));
grant insert on public.crm_barber_appointments to anon;
create policy "public submit MS House booking" on public.crm_barber_appointments for insert to anon
with check (tenant_id=(select id from public.crm_tenants where slug='ms-house-barber' and is_active=true)
and status='pending' and payment_status='unpaid' and paid_to_barber=false and barber_fixed_fee <= price);

create or replace function public.ms_house_validate_appointment()
returns trigger language plpgsql security definer set search_path = pg_catalog, public
as $$
declare v_service public.crm_barber_services%rowtype; v_barber public.crm_barbers%rowtype;
begin
 if new.tenant_id <> (select id from public.crm_tenants where slug='ms-house-barber' and is_active=true) then raise exception 'Invalid salon'; end if;
 select * into v_service from public.crm_barber_services where id=new.service_id and tenant_id=new.tenant_id and is_active=true;
 if not found then raise exception 'Service unavailable'; end if;
 select * into v_barber from public.crm_barbers where id=new.barber_id and tenant_id=new.tenant_id and is_active=true;
 if not found then raise exception 'Barber unavailable'; end if;
 new.price:=v_service.price; new.barber_fixed_fee:=v_service.barber_fixed_fee;
 new.ends_at:=new.starts_at + make_interval(mins=>v_service.duration_minutes);
 if new.status not in ('cancelled','no_show') and exists (
  select 1 from public.crm_barber_appointments a where a.barber_id=new.barber_id and a.tenant_id=new.tenant_id
  and a.id is distinct from new.id and a.status not in ('cancelled','no_show')
  and a.starts_at<new.ends_at and a.ends_at>new.starts_at
 ) then raise exception 'This time slot is no longer available'; end if;
 return new;
end; $$;
revoke all on function public.ms_house_validate_appointment() from public, anon, authenticated;
create trigger ms_house_validate_appointment_trigger before insert or update on public.crm_barber_appointments
for each row execute function public.ms_house_validate_appointment();
