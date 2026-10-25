-- Rately Farms: simple Supabase schema
-- Run this in Supabase SQL Editor after enabling Email auth.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  mobile_number text,
  farm_name text,
  created_at timestamptz not null default now()
);

create table if not exists public.batches (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  production_type text not null check (production_type in ('Bird Production', 'Egg Production')),
  production_category text not null,
  breed text not null,
  start_date date not null,
  initial_birds integer not null check (initial_birds > 0)
);

create table if not exists public.daily_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  batch_id uuid not null references public.batches(id) on delete cascade,
  record_date date not null,
  shed_number text,
  feed_type text,
  feed_kg numeric(12, 2) not null default 0 check (feed_kg >= 0),
  water_litre numeric(12, 2) not null default 0 check (water_litre >= 0),
  eggs_collected integer not null default 0 check (eggs_collected >= 0),
  mortality integer not null default 0 check (mortality >= 0),
  remarks text
);

create table if not exists public.expenses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  batch_id uuid not null references public.batches(id) on delete cascade,
  expense_date date not null,
  expense_type text not null,
  description text,
  amount numeric(12, 2) not null check (amount >= 0),
  remarks text
);

create table if not exists public.sales (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  batch_id uuid not null references public.batches(id) on delete cascade,
  sale_date date not null,
  sale_type text not null check (sale_type in ('Bird', 'Table Eggs', 'Hatching Eggs')),
  quantity integer not null check (quantity > 0),
  weight_kg numeric(12, 2) check (weight_kg is null or weight_kg > 0),
  unit_price numeric(12, 2) not null check (unit_price >= 0),
  buyer_name text,
  remarks text
);

create table if not exists public.weekly_weights (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  batch_id uuid not null references public.batches(id) on delete cascade,
  weight_date date not null,
  sample_count integer not null check (sample_count > 0),
  average_weight_kg numeric(12, 3) not null check (average_weight_kg > 0),
  remarks text
);

create table if not exists public.market_prices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  price_date date not null,
  price_type text not null check (price_type in ('Bird', 'Egg')),
  production_category text not null,
  breed text,
  unit text not null check (unit in ('kg', 'piece')),
  price numeric(12, 2) not null check (price >= 0),
  market_name text,
  remarks text
);

create index if not exists batches_user_id_idx on public.batches(user_id);
create index if not exists daily_records_batch_id_idx on public.daily_records(batch_id);
create index if not exists expenses_batch_id_idx on public.expenses(batch_id);
create index if not exists sales_batch_id_idx on public.sales(batch_id);
create index if not exists weekly_weights_batch_id_idx on public.weekly_weights(batch_id);
create index if not exists market_prices_date_idx on public.market_prices(price_date);

-- Keep profile creation automatic after signup.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, mobile_number, farm_name)
  values (new.id, new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'mobile_number', new.raw_user_meta_data ->> 'farm_name');
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

-- Row Level Security: each user sees only their own rows.
alter table public.profiles enable row level security;
alter table public.batches enable row level security;
alter table public.daily_records enable row level security;
alter table public.expenses enable row level security;
alter table public.sales enable row level security;
alter table public.weekly_weights enable row level security;
alter table public.market_prices enable row level security;

drop policy if exists profiles_owner on public.profiles;
create policy profiles_owner on public.profiles for all using (id = auth.uid()) with check (id = auth.uid());

do $$
declare t text;
begin
  foreach t in array array['batches','daily_records','expenses','sales','weekly_weights','market_prices'] loop
    execute format('drop policy if exists %I_owner on public.%I', t, t);
    execute format('create policy %I_owner on public.%I for all using (user_id = auth.uid()) with check (user_id = auth.uid())', t, t);
  end loop;
end $$;
