-- Maryeli Lash Studio — Esquema Supabase (Postgres + RLS)
-- Ejecuta este script en el SQL Editor de tu proyecto Supabase (uzmzafnjlunrfnptpuzw).

-- 1. Tabla de configuración del estudio (pública para lectura, editable desde admin)
create table if not exists public.studio_config (
  id text primary key default 'default',
  admin_pin text not null default '2026',
  config jsonb not null,
  updated_at timestamptz not null default now()
);

alter table public.studio_config enable row level security;

-- Solo lectura de la columna config (sin exponer admin_pin si se consulta vía vista o RPC)
revoke all on public.studio_config from anon, authenticated;
grant select (id, config, updated_at) on public.studio_config to anon, authenticated;

create policy "Public can read studio config"
  on public.studio_config
  for select
  to anon, authenticated
  using (id = 'default');

-- Insertar configuración inicial de Costa Rica
insert into public.studio_config (id, admin_pin, config)
values (
  'default',
  '2026',
  '{
    "studioName": "Maryeli Lash Studio",
    "whatsapp": "50664730344",
    "sinpe": "6473-0344",
    "anticipo": "₡5,000",
    "mapsUrl": "https://maps.app.goo.gl/jLE2VRxH5RAAuLeVA",
    "instagramUrl": "https://www.instagram.com/maryeli_lash_studio/",
    "hoursWeekday": "9:00 AM – 7:00 PM",
    "hoursSaturday": "9:00 AM – 4:00 PM",
    "services": [
      { "id": "fibras-c", "name": "Fibras Tecnológicas C", "shortName": "Fibras C", "subtitle": "Efecto Natural • 90 min", "price": "₡20,000" },
      { "id": "fibras-cc", "name": "Fibras Tecnológicas CC", "shortName": "Fibras CC", "subtitle": "Mirada Abierta • 105 min", "price": "₡22,000" },
      { "id": "fibras-yy", "name": "Fibras Tecnológicas YY", "shortName": "Fibras YY", "subtitle": "Volumen Suave • 120 min", "price": "₡25,000" },
      { "id": "fibras-4dw", "name": "Fibras Tecnológicas 4DW", "shortName": "Fibras 4DW", "subtitle": "Volumen & Densidad • 130 min", "price": "₡28,000" }
    ]
  }'::jsonb
)
on conflict (id) do nothing;

-- 2. Tabla de citas (appointments)
create table if not exists public.appointments (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  appointment_date date not null,
  appointment_time text not null,
  service text not null,
  client_name text not null,
  client_phone text not null,
  notes text default 'Ninguna',
  status text not null default 'Pendiente SINPE',
  created_at timestamptz not null default now()
);

-- Índice único parcial: impide doble reserva en la misma fecha y hora (si no está cancelada)
create unique index if not exists appointments_unique_active_slot
  on public.appointments (appointment_date, appointment_time)
  where status <> 'Cancelada';

create index if not exists appointments_date_idx
  on public.appointments (appointment_date);

alter table public.appointments enable row level security;

revoke all on public.appointments from anon, authenticated;
grant insert (code, appointment_date, appointment_time, service, client_name, client_phone, notes)
  on public.appointments to anon, authenticated;

-- Cualquier clienta puede crear una cita nueva
create policy "Public can create appointments"
  on public.appointments
  for insert
  to anon, authenticated
  with check (status = 'Pendiente SINPE');

-- 3. Funciones RPC seguras (no exponen teléfonos ni datos de otras clientas al público)
create or replace function public.get_booked_slots(p_date date)
returns table (appointment_time text)
language sql
security definer
set search_path = ''
as $$
  select a.appointment_time
  from public.appointments a
  where a.appointment_date = p_date
    and a.status <> 'Cancelada';
$$;

grant execute on function public.get_booked_slots(date) to anon, authenticated;

create or replace function public.admin_get_appointments(p_pin text)
returns setof public.appointments
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_pin text;
begin
  select sc.admin_pin into v_pin from public.studio_config sc where sc.id = 'default';
  if p_pin is distinct from v_pin then
    raise exception 'PIN incorrecto';
  end if;
  return query
    select * from public.appointments
    order by appointment_date desc, created_at desc
    limit 100;
end;
$$;

grant execute on function public.admin_get_appointments(text) to anon, authenticated;

create or replace function public.admin_update_appointment_status(p_pin text, p_id uuid, p_status text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_pin text;
begin
  select sc.admin_pin into v_pin from public.studio_config sc where sc.id = 'default';
  if p_pin is distinct from v_pin then
    raise exception 'PIN incorrecto';
  end if;
  update public.appointments
  set status = p_status
  where id = p_id;
end;
$$;

grant execute on function public.admin_update_appointment_status(text, uuid, text) to anon, authenticated;

create or replace function public.admin_save_config(p_pin text, p_config jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_pin text;
begin
  select sc.admin_pin into v_pin from public.studio_config sc where sc.id = 'default';
  if p_pin is distinct from v_pin then
    raise exception 'PIN incorrecto';
  end if;
  update public.studio_config
  set config = p_config, updated_at = now()
  where id = 'default';
end;
$$;

grant execute on function public.admin_save_config(text, jsonb) to anon, authenticated;
