-- Server-validated Sky Run sessions. Client score is cosmetic and never determines rewards.
create table if not exists public.air_force_matches (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.air_force_matches enable row level security;
revoke all on public.air_force_matches from anon, authenticated, public;

-- Remove the old client-score-based reward endpoint.
drop function if exists public.air_force_finish_match(integer);

create or replace function public.air_force_start_match()
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_match_id uuid;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;

  insert into public.air_force_profiles(user_id)
  values (v_uid) on conflict (user_id) do nothing;

  -- Expire abandoned sessions so a closed browser cannot lock a player out.
  update public.air_force_matches
  set completed_at = now()
  where user_id = v_uid
    and completed_at is null
    and started_at < now() - interval '5 minutes';

  if exists (
    select 1 from public.air_force_matches
    where user_id = v_uid and completed_at is null
  ) then
    raise exception 'A Sky Run session is already active';
  end if;

  if exists (
    select 1 from public.air_force_profiles
    where user_id = v_uid
      and last_match_at > now() - interval '30 seconds'
  ) then
    raise exception 'Please wait before starting another Sky Run';
  end if;

  insert into public.air_force_matches(user_id)
  values (v_uid) returning id into v_match_id;

  return v_match_id;
end;
$$;

create or replace function public.air_force_finish_match(p_match_id uuid)
returns table(ap_earned integer, xp_earned integer, new_level integer)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_started_at timestamptz;
  v_completed_at timestamptz;
  v_xp integer := 25;
  v_ap integer := 75;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if p_match_id is null then raise exception 'Invalid match session'; end if;

  select started_at, completed_at
    into v_started_at, v_completed_at
  from public.air_force_matches
  where id = p_match_id and user_id = v_uid
  for update;

  if not found then raise exception 'Sky Run session not found'; end if;
  if v_completed_at is not null then raise exception 'Sky Run session already claimed'; end if;
  if v_started_at > now() - interval '24 seconds' then
    raise exception 'Complete the full Sky Run before claiming rewards';
  end if;
  if v_started_at < now() - interval '5 minutes' then
    raise exception 'Sky Run session expired. Start a new run';
  end if;

  update public.air_force_matches
  set completed_at = now()
  where id = p_match_id and user_id = v_uid and completed_at is null;

  update public.air_force_profiles
  set ap = ap + v_ap,
      xp = xp + v_xp,
      matches = matches + 1,
      level = 1 + floor(((xp + v_xp)::numeric) / 250)::integer,
      last_match_at = now()
  where user_id = v_uid;

  return query
  select v_ap, v_xp, p.level
  from public.air_force_profiles p
  where p.user_id = v_uid;
end;
$$;

revoke all on function public.air_force_start_match() from public, anon;
revoke all on function public.air_force_finish_match(uuid) from public, anon;
grant execute on function public.air_force_start_match() to authenticated;
grant execute on function public.air_force_finish_match(uuid) to authenticated;
