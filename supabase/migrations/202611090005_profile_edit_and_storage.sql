-- Marawis Smpn99: keamanan edit profil dan penyimpanan foto
-- Jalankan setelah migrasi 001 sampai 004.

-- Pengguna boleh memperbarui profil miliknya sendiri.
drop policy if exists "Users update own profile" on public.profiles;
create policy "Users update own profile"
on public.profiles for update
to authenticated
using (id = (select auth.uid()))
with check (id = (select auth.uid()));

-- Role tidak boleh diubah sendiri oleh anggota biasa.
create or replace function public.protect_marawis_profile_role()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.role is distinct from old.role
     and not public.is_marawis_admin() then
    raise exception 'Role hanya dapat diubah oleh admin Marawis.';
  end if;
  return new;
end;
$$;

drop trigger if exists protect_marawis_profile_role_trigger on public.profiles;
create trigger protect_marawis_profile_role_trigger
before update of role on public.profiles
for each row execute procedure public.protect_marawis_profile_role();

-- Bucket publik agar foto profil dapat ditampilkan di direktori anggota.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'profile-avatars',
  'profile-avatars',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update set
  public = true,
  file_size_limit = 5242880,
  allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp'];

drop policy if exists "Public can view profile avatars" on storage.objects;
create policy "Public can view profile avatars"
on storage.objects for select
using (bucket_id = 'profile-avatars');

drop policy if exists "Users upload own profile avatar" on storage.objects;
create policy "Users upload own profile avatar"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'profile-avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "Users update own profile avatar" on storage.objects;
create policy "Users update own profile avatar"
on storage.objects for update
to authenticated
using (
  bucket_id = 'profile-avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text
)
with check (
  bucket_id = 'profile-avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "Users delete own profile avatar" on storage.objects;
create policy "Users delete own profile avatar"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'profile-avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

-- Anggota boleh mengubah kelas dan bio miliknya sendiri, bukan jabatan/status.
drop policy if exists "Users update own member details" on public.members;
create policy "Users update own member details"
on public.members for update
to authenticated
using (id = (select auth.uid()))
with check (id = (select auth.uid()));

create or replace function public.protect_member_admin_fields()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if (not public.is_marawis_admin())
     and (
       new.position is distinct from old.position
       or new.membership_status is distinct from old.membership_status
       or new.joined_at is distinct from old.joined_at
     ) then
    raise exception 'Jabatan, status keanggotaan, dan tanggal bergabung hanya dapat diubah admin.';
  end if;
  return new;
end;
$$;

drop trigger if exists protect_member_admin_fields_trigger on public.members;
create trigger protect_member_admin_fields_trigger
before update on public.members
for each row execute procedure public.protect_member_admin_fields();
