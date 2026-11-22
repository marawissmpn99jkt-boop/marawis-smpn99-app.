create or replace function public.validate_marawis_qr_checkin()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $function$
declare
  v_token text;
  v_starts_at timestamptz;
  v_ends_at timestamptz;
begin
  if auth.uid() is null then
    raise exception 'Silakan login terlebih dahulu.';
  end if;

  -- Preserve the existing staff workflow for manual attendance management.
  if exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and p.role in ('pengurus', 'pembina')
  ) then
    return new;
  end if;

  if new.member_id is distinct from auth.uid() then
    raise exception 'Akun hanya dapat mencatat check-in untuk dirinya sendiri.';
  end if;

  if new.status <> 'hadir' or new.notes is null or left(new.notes, 3) <> 'QR:' then
    raise exception 'Check-in harus menggunakan QR kegiatan yang valid.';
  end if;

  v_token := substring(new.notes from 4);
  if length(v_token) < 20 or not exists (
    select 1 from public.activity_checkin_codes c
    where c.activity_id = new.activity_id
      and c.token = v_token
      and c.enabled = true
      and (c.expires_at is null or c.expires_at > now())
  ) then
    raise exception 'QR tidak valid atau sudah dinonaktifkan.';
  end if;

  if not exists (
    select 1 from public.members m
    where m.id = new.member_id and m.membership_status = 'aktif'
  ) then
    raise exception 'Akun ini tidak memiliki status anggota aktif.';
  end if;

  select a.starts_at, a.ends_at into v_starts_at, v_ends_at
  from public.activities a where a.id = new.activity_id;

  if not found then
    raise exception 'Kegiatan tidak ditemukan.';
  end if;

  if now() < v_starts_at - interval '60 minutes'
     or now() > coalesce(v_ends_at, v_starts_at + interval '4 hours') + interval '4 hours' then
    raise exception 'Periode check-in kegiatan ini sudah berakhir atau belum dimulai.';
  end if;

  new.marked_by := auth.uid();
  new.notes := 'Check-in QR';
  return new;
end;
$function$;

revoke all on function public.validate_marawis_qr_checkin() from public, anon, authenticated;
