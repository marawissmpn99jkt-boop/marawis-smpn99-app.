-- Secure staff role elevation with a shared second password.
-- Only the trusted Edge Function (service_role) may change profiles.role.
create or replace function public.protect_marawis_profile_role()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.role is distinct from old.role
     and auth.role() is distinct from 'service_role'
     and not public.is_marawis_admin() then
    raise exception 'Role hanya dapat diubah oleh admin Marawis.';
  end if;
  return new;
end;
$$;

create table if not exists public.staff_access_attempts (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  attempted_at timestamptz not null default now()
);

create index if not exists staff_access_attempts_user_time_idx
  on public.staff_access_attempts (user_id, attempted_at desc);

alter table public.staff_access_attempts enable row level security;
revoke all on table public.staff_access_attempts from public, anon, authenticated;
