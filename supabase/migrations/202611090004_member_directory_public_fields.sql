-- Marawis Smpn99: data publik direktori anggota
-- Aman dijalankan setelah migrasi 001-003.

alter table public.members
  add column if not exists display_name text,
  add column if not exists avatar_url text;

-- Sinkronkan nama dan foto dari profil privat ke direktori publik.
update public.members m
set
  display_name = coalesce(p.full_name, split_part(coalesce(p.email, ''), '@', 1), 'Anggota'),
  avatar_url = p.avatar_url,
  updated_at = now()
from public.profiles p
where p.id = m.id;

create or replace function public.sync_member_directory_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.members (id, display_name, avatar_url)
  values (
    new.id,
    coalesce(new.full_name, split_part(coalesce(new.email, ''), '@', 1), 'Anggota'),
    new.avatar_url
  )
  on conflict (id) do update set
    display_name = excluded.display_name,
    avatar_url = excluded.avatar_url,
    updated_at = now();
  return new;
end;
$$;

drop trigger if exists sync_member_directory_after_profile_change on public.profiles;
create trigger sync_member_directory_after_profile_change
after insert or update of full_name, email, avatar_url on public.profiles
for each row execute procedure public.sync_member_directory_profile();

grant select on public.members to authenticated;
