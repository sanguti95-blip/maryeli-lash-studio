-- Maryeli Lash Studio — Extensión de Esquema Supabase (v2)
-- Agrega Reagendado de Citas, Promociones, Galería e Ingresos/Gastos.
-- Ejecuta este script en el SQL Editor de tu proyecto Supabase (uzmzafnjlunrfnptpuzw).

-- 1. Promociones
create table if not exists public.promotions (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text default '',
  badge text default 'Promo',
  promo_price text not null,
  regular_price text default '',
  valid_until text default '',
  active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.promotions enable row level security;
revoke all on public.promotions from anon, authenticated;
grant select on public.promotions to anon, authenticated;

create policy "Public can read active promotions"
  on public.promotions
  for select
  to anon, authenticated
  using (active = true);

-- 2. Galería de Trabajos
create table if not exists public.gallery_items (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  category text not null,
  subtitle text default '',
  image_url text not null,
  featured boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.gallery_items enable row level security;
revoke all on public.gallery_items from anon, authenticated;
grant select on public.gallery_items to anon, authenticated;

create policy "Public can read featured gallery"
  on public.gallery_items
  for select
  to anon, authenticated
  using (featured = true);

-- 3. Movimientos Financieros (Ingresos y Gastos)
create table if not exists public.transactions (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('income', 'expense')),
  category text not null,
  description text default '',
  amount_crc integer not null check (amount_crc >= 0),
  tx_date date not null default current_date,
  deductible boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists transactions_date_idx on public.transactions (tx_date desc);

alter table public.transactions enable row level security;
revoke all on public.transactions from anon, authenticated;

-- 4. RPC: Consultar cita por código (solo datos seguros, sin exponer lista global)
create or replace function public.get_appointment_by_code(p_code text)
returns table (
  code text,
  appointment_date date,
  appointment_time text,
  service text,
  client_name text,
  status text
)
language sql
security definer
set search_path = ''
as $$
  select a.code, a.appointment_date, a.appointment_time, a.service, a.client_name, a.status
  from public.appointments a
  where upper(a.code) = upper(trim(p_code))
  limit 1;
$$;

grant execute on function public.get_appointment_by_code(text) to anon, authenticated;

-- 5. RPC: Reagendar cita por código
create or replace function public.reschedule_appointment(p_code text, p_new_date date, p_new_time text)
returns table (
  code text,
  appointment_date date,
  appointment_time text,
  service text,
  client_name text,
  status text
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (
    select 1 from public.appointments a
    where a.appointment_date = p_new_date
      and a.appointment_time = p_new_time
      and a.status <> 'Cancelada'
      and upper(a.code) <> upper(trim(p_code))
  ) then
    raise exception 'Ese horario acaba de ser ocupado. Por favor elige otro.';
  end if;

  update public.appointments
  set appointment_date = p_new_date,
      appointment_time = p_new_time,
      status = 'Reagendada'
  where upper(appointments.code) = upper(trim(p_code));

  if not found then
    raise exception 'No encontramos una cita con ese código.';
  end if;

  return query
    select a.code, a.appointment_date, a.appointment_time, a.service, a.client_name, a.status
    from public.appointments a
    where upper(a.code) = upper(trim(p_code))
    limit 1;
end;
$$;

grant execute on function public.reschedule_appointment(text, date, text) to anon, authenticated;

-- 6. RPCs Admin: Transacciones (Ingresos y Gastos)
create or replace function public.admin_list_transactions(p_pin text)
returns setof public.transactions
language plpgsql
security definer
set search_path = ''
as $$
declare v_pin text;
begin
  select sc.admin_pin into v_pin from public.studio_config sc where sc.id = 'default';
  if p_pin is distinct from v_pin then raise exception 'PIN incorrecto'; end if;
  return query select * from public.transactions order by tx_date desc, created_at desc limit 100;
end;
$$;

grant execute on function public.admin_list_transactions(text) to anon, authenticated;

create or replace function public.admin_add_transaction(
  p_pin text,
  p_kind text,
  p_category text,
  p_description text,
  p_amount_crc integer,
  p_tx_date date,
  p_deductible boolean default false
)
returns public.transactions
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_pin text;
  v_row public.transactions;
begin
  select sc.admin_pin into v_pin from public.studio_config sc where sc.id = 'default';
  if p_pin is distinct from v_pin then raise exception 'PIN incorrecto'; end if;
  insert into public.transactions (kind, category, description, amount_crc, tx_date, deductible)
  values (p_kind, p_category, p_description, p_amount_crc, coalesce(p_tx_date, current_date), coalesce(p_deductible, false))
  returning * into v_row;
  return v_row;
end;
$$;

grant execute on function public.admin_add_transaction(text, text, text, text, integer, date, boolean) to anon, authenticated;

-- 7. RPCs Admin: Promociones
create or replace function public.admin_list_promotions(p_pin text)
returns setof public.promotions
language plpgsql
security definer
set search_path = ''
as $$
declare v_pin text;
begin
  select sc.admin_pin into v_pin from public.studio_config sc where sc.id = 'default';
  if p_pin is distinct from v_pin then raise exception 'PIN incorrecto'; end if;
  return query select * from public.promotions order by created_at desc;
end;
$$;

grant execute on function public.admin_list_promotions(text) to anon, authenticated;

create or replace function public.admin_save_promotion(
  p_pin text,
  p_title text,
  p_description text,
  p_badge text,
  p_promo_price text,
  p_regular_price text,
  p_valid_until text
)
returns public.promotions
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_pin text;
  v_row public.promotions;
begin
  select sc.admin_pin into v_pin from public.studio_config sc where sc.id = 'default';
  if p_pin is distinct from v_pin then raise exception 'PIN incorrecto'; end if;
  insert into public.promotions (title, description, badge, promo_price, regular_price, valid_until, active)
  values (p_title, p_description, p_badge, p_promo_price, p_regular_price, p_valid_until, true)
  returning * into v_row;
  return v_row;
end;
$$;

grant execute on function public.admin_save_promotion(text, text, text, text, text, text, text) to anon, authenticated;

create or replace function public.admin_toggle_promotion(p_pin text, p_id uuid, p_active boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_pin text;
begin
  select sc.admin_pin into v_pin from public.studio_config sc where sc.id = 'default';
  if p_pin is distinct from v_pin then raise exception 'PIN incorrecto'; end if;
  update public.promotions set active = p_active where id = p_id;
end;
$$;

grant execute on function public.admin_toggle_promotion(text, uuid, boolean) to anon, authenticated;
