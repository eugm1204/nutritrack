-- NutriTrack: schema + RLS
-- Corre no SQL Editor do Supabase.

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  daily_goal_calories int not null default 2200,
  weight_kg real,
  objective text not null default 'maintain',
  name text,
  birth_date date,
  sex text,
  height_cm real,
  activity_level text,
  target_weight_kg real,
  protein_goal_g int,
  carbs_goal_g int,
  fat_goal_g int,
  avatar_url text,
  onboarding_completed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.custom_foods (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  brand text,
  kcal_per_100g int not null,
  protein real,
  carbs real,
  fat real,
  reference_grams real not null default 100,
  created_at timestamptz not null default now()
);

create index if not exists custom_foods_user_idx on public.custom_foods (user_id);

create table if not exists public.error_logs (
  id bigint generated always as identity primary key,
  user_id uuid references auth.users(id) on delete cascade,
  action text,
  message text,
  stack text,
  created_at timestamptz not null default now()
);

create table if not exists public.meals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  image_url text,
  meal_name text not null default 'Refeição',
  total_calories int not null default 0,
  items jsonb not null default '[]'::jsonb,
  consumed_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists meals_user_date_idx on public.meals (user_id, consumed_at);

alter table public.profiles enable row level security;
alter table public.meals enable row level security;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own" on public.profiles
  for select using (auth.uid() = id);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own" on public.profiles
  for insert with check (auth.uid() = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles
  for update using (auth.uid() = id);

drop policy if exists "meals_select_own" on public.meals;
create policy "meals_select_own" on public.meals
  for select using (auth.uid() = user_id);

drop policy if exists "meals_insert_own" on public.meals;
create policy "meals_insert_own" on public.meals
  for insert with check (auth.uid() = user_id);

drop policy if exists "meals_delete_own" on public.meals;
create policy "meals_delete_own" on public.meals
  for delete using (auth.uid() = user_id);

-- Storage bucket para as fotos das refeições (público para leitura)
insert into storage.buckets (id, name, public)
values ('meal-photos', 'meal-photos', true)
on conflict (id) do nothing;

drop policy if exists "meal_photos_read_public" on storage.objects;
create policy "meal_photos_read_public" on storage.objects
  for select using (bucket_id = 'meal-photos');

drop policy if exists "meal_photos_insert_own" on storage.objects;
create policy "meal_photos_insert_own" on storage.objects
  for insert with check (
    bucket_id = 'meal-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "meal_photos_delete_own" on storage.objects;
create policy "meal_photos_delete_own" on storage.objects
  for delete using (
    bucket_id = 'meal-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
-- Custom foods (criados pelo utilizador)
alter table public.custom_foods enable row level security;

drop policy if exists "custom_foods_select_own" on public.custom_foods;
create policy "custom_foods_select_own" on public.custom_foods
  for select using (auth.uid() = user_id);

drop policy if exists "custom_foods_insert_own" on public.custom_foods;
create policy "custom_foods_insert_own" on public.custom_foods
  for insert with check (auth.uid() = user_id);

drop policy if exists "custom_foods_delete_own" on public.custom_foods;
create policy "custom_foods_delete_own" on public.custom_foods
  for delete using (auth.uid() = user_id);

-- Telemetria de erros
alter table public.error_logs enable row level security;

drop policy if exists "error_logs_insert_own" on public.error_logs;
create policy "error_logs_insert_own" on public.error_logs
  for insert with check (auth.uid() = user_id);

-- Bucket de avatares
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

drop policy if exists "avatars_read_public" on storage.objects;
create policy "avatars_read_public" on storage.objects
  for select using (bucket_id = 'avatars');

drop policy if exists "avatars_insert_own" on storage.objects;
create policy "avatars_insert_own" on storage.objects
  for insert with check (
    bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "avatars_update_own" on storage.objects;
create policy "avatars_update_own" on storage.objects
  for update using (
    bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text
  );
