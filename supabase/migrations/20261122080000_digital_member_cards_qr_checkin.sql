-- Digital member cards and secure QR event check-in.
alter table public.members add column if not exists card_code text;

update public.members
set card_code = 'MS99-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12))
where card_code is null or btrim(card_code) = '';

alter table public.members
  alter column card_code set default ('MS99-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12))),
  alter column card_code set not null;

create unique index if not exists members_card_code_uidx
  on public.members(card_code);

create table if not exists public.activity_checkin_codes (
  activity_id bigint primary key references public.activities(id) on delete cascade,
  token text not null,
  enabled boolean not null default true,
  expires_at timestamptz,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.activity_checkin_codes enable row level security;

drop policy if exists "Admins manage activity check-in codes" on public.activity_checkin_codes;
create policy "Admins manage activity check-in codes"
on public.activity_checkin_codes
for all
to authenticated
using (public.is_marawis_admin())
with check (public.is_marawis_admin());

grant select, insert, update, delete on public.activity_checkin_codes to authenticated;

create or replace function public.marawis_check_in(
  p_activity_id bigint,
  p_token text
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $function$
declare
  v_user_id uuid := auth.uid();
  v_starts_at timestamptz;
  v_ends_at timestamptz;
  v_inserted integer := 0;
begin
  if v_user_id is null then
    return jsonb_build_object('success', false, 'message', 'Silakan login terlebih dahulu.');
  end if;

  if not exists (
    select 1 from public.members m
    where m.id = v_user_id and m.membership_status = 'aktif'
  ) then
    return jsonb_build_object('success', false, 'message', 'Akun ini tidak memiliki status anggota aktif.');
  end if;

  if p_token is null or length(p_token) < 20 or not exists (
    select 1 from public.activity_checkin_codes c
    where c.activity_id = p_activity_id
      and c.token = p_token
      and c.enabled = true
      and (c.expires_at is null or c.expires_at > now())
  ) then
    return jsonb_build_object('success', false, 'message', 'QR tidak valid atau sudah dinonaktifkan.');
  end if;

  select a.starts_at, a.ends_at into v_starts_at, v_ends_at
  from public.activities a where a.id = p_activity_id;

  if not found then
    return jsonb_build_object('success', false, 'message', 'Kegiatan tidak ditemukan.');
  end if;

  if now() < v_starts_at - interval '60 minutes'
     or now() > coalesce(v_ends_at, v_starts_at + interval '4 hours') + interval '4 hours' then
    return jsonb_build_object('success', false, 'message', 'Periode check-in kegiatan ini sudah berakhir atau belum dimulai.');
  end if;

  insert into public.attendance (activity_id, member_id, status, notes, marked_by)
  values (p_activity_id, v_user_id, 'hadir', 'Check-in QR', v_user_id)
  on conflict (activity_id, member_id) do nothing;

  get diagnostics v_inserted = row_count;

  if v_inserted = 0 then
    return jsonb_build_object('success', false, 'message', 'Kehadiran untuk kegiatan ini sudah tercatat sebelumnya.');
  end if;

  return jsonb_build_object('success', true, 'message', 'Check-in berhasil. Kehadiran kamu sudah tercatat.');
end;
$function$;

revoke all on function public.marawis_check_in(bigint, text) from public, anon;
grant execute on function public.marawis_check_in(bigint, text) to authenticated;
