-- Marawis Smpn99: direktori anggota dan struktur kepengurusan

create table if not exists public.members (
  id uuid primary key references public.profiles(id) on delete cascade,
  class_name text,
  position text not null default 'Anggota',
  membership_status text not null default 'aktif'
    check (membership_status in ('aktif', 'nonaktif', 'alumni')),
  joined_at date,
  bio text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists members_class_idx on public.members(class_name);
create index if not exists members_status_idx on public.members(membership_status);

-- Buat entri direktori untuk akun yang sudah memiliki profil.
insert into public.members (id)
select id from public.profiles
on conflict (id) do nothing;

alter table public.members enable row level security;

drop policy if exists "Authenticated read active member directory" on public.members;
create policy "Authenticated read active member directory"
on public.members for select to authenticated
using (membership_status = 'aktif' or public.is_marawis_admin());

drop policy if exists "Admins manage member directory" on public.members;
create policy "Admins manage member directory"
on public.members for all to authenticated
using (public.is_marawis_admin())
with check (public.is_marawis_admin());

grant select, insert, update, delete on public.members to authenticated;

-- Profil privat (email dan data login) tetap hanya dapat dibaca pemilik/admin.
-- Direktori anggota memakai tabel members agar data privat tidak ikut terekspos.
