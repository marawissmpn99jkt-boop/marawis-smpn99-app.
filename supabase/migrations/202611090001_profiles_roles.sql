-- Marawis Smpn99: fondasi profil dan hak akses
-- Jalankan seluruh file ini di Supabase SQL Editor.
-- Role yang valid: anggota, pengurus, pembina.
-- Pengurus dan Pembina sama-sama memiliki hak akses admin penuh.

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  email text,
  avatar_url text,
  role text not null default 'anggota'
    check (role in ('anggota', 'pengurus', 'pembina')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.is_marawis_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = (select auth.uid())
      and role in ('pengurus', 'pembina')
  );
$$;

revoke all on function public.is_marawis_admin() from public;
grant execute on function public.is_marawis_admin() to authenticated;

create or replace function public.handle_new_marawis_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, email, avatar_url, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name'),
    new.email,
    new.raw_user_meta_data->>'avatar_url',
    'anggota'
  )
  on conflict (id) do update set
    full_name = excluded.full_name,
    email = excluded.email,
    avatar_url = excluded.avatar_url,
    updated_at = now();
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_marawis on auth.users;
create trigger on_auth_user_created_marawis
after insert on auth.users
for each row execute procedure public.handle_new_marawis_user();

-- Sinkronkan akun yang sudah terdaftar sebelum trigger dibuat.
insert into public.profiles (id, full_name, email, avatar_url, role)
select
  u.id,
  coalesce(u.raw_user_meta_data->>'full_name', u.raw_user_meta_data->>'name'),
  u.email,
  u.raw_user_meta_data->>'avatar_url',
  'anggota'
from auth.users u
on conflict (id) do update set
  full_name = coalesce(public.profiles.full_name, excluded.full_name),
  email = excluded.email,
  avatar_url = coalesce(public.profiles.avatar_url, excluded.avatar_url),
  updated_at = now();

alter table public.profiles enable row level security;

drop policy if exists "Users read own profile" on public.profiles;
create policy "Users read own profile"
on public.profiles for select
to authenticated
using (id = (select auth.uid()) or public.is_marawis_admin());

drop policy if exists "Admins manage profiles" on public.profiles;
create policy "Admins manage profiles"
on public.profiles for all
to authenticated
using (public.is_marawis_admin())
with check (public.is_marawis_admin());

grant select on public.profiles to authenticated;
grant insert, update, delete on public.profiles to authenticated;

-- PROMOSI ADMIN (jalankan manual setelah akun Google terkait muncul di Authentication > Users):
-- update public.profiles
-- set role = 'pengurus', updated_at = now()
-- where email = 'EMAIL_PENGURUS';
--
-- update public.profiles
-- set role = 'pembina', updated_at = now()
-- where email = 'EMAIL_PEMBINA';
--
-- Jangan pernah memberikan role admin berdasarkan pilihan di layar login.
