-- Marawis Air Force: per-user progression and aircraft ownership.
create table if not exists public.air_force_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  ap integer not null default 0 check (ap >= 0),
  ac integer not null default 0 check (ac >= 0),
  xp integer not null default 0 check (xp >= 0),
  level integer not null default 1 check (level >= 1),
  matches integer not null default 0 check (matches >= 0),
  selected_aircraft text not null default 'f86',
  last_match_at timestamptz
);
create table if not exists public.air_force_owned_aircraft (
  user_id uuid not null references auth.users(id) on delete cascade,
  aircraft_id text not null,
  acquired_at timestamptz not null default now(),
  primary key(user_id, aircraft_id)
);
alter table public.air_force_profiles enable row level security;
alter table public.air_force_owned_aircraft enable row level security;
drop policy if exists "Members read own air force profile" on public.air_force_profiles;
create policy "Members read own air force profile" on public.air_force_profiles for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "Members update own selected aircraft" on public.air_force_profiles;
create policy "Members update own selected aircraft" on public.air_force_profiles for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
drop policy if exists "Members read own aircraft collection" on public.air_force_owned_aircraft;
create policy "Members read own aircraft collection" on public.air_force_owned_aircraft for select to authenticated using ((select auth.uid()) = user_id);
revoke all on public.air_force_profiles from anon, public;
revoke all on public.air_force_owned_aircraft from anon, public;
grant select, update (selected_aircraft) on public.air_force_profiles to authenticated;
grant select on public.air_force_owned_aircraft to authenticated;

create or replace function public.air_force_initialize()
returns void language plpgsql security definer set search_path = public, pg_temp as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  insert into public.air_force_profiles(user_id) values(v_uid) on conflict(user_id) do nothing;
  insert into public.air_force_owned_aircraft(user_id, aircraft_id) values(v_uid, 'f86') on conflict do nothing;
end; $$;
revoke all on function public.air_force_initialize() from public, anon;
grant execute on function public.air_force_initialize() to authenticated;

create or replace function public.air_force_convert_ap(p_amount integer)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if p_amount is null or p_amount < 10 or p_amount > 100000 or p_amount % 10 <> 0 then raise exception 'AP must be a multiple of 10'; end if;
  update public.air_force_profiles set ap = ap - p_amount, ac = ac + (p_amount / 10)
  where user_id = v_uid and ap >= p_amount;
  if not found then raise exception 'Insufficient AP'; end if;
end; $$;
revoke all on function public.air_force_convert_ap(integer) from public, anon;
grant execute on function public.air_force_convert_ap(integer) to authenticated;

create or replace function public.air_force_buy_aircraft(p_aircraft_id text)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
declare v_uid uuid := auth.uid(); v_price integer; v_level integer;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  select price, required_level into v_price, v_level from (values
    ('f86',0,1),('mig15',350,1),('mig21',1000,3),('f5',1200,3),
    ('f4',2600,5),('mig23',3000,5),('f16',6500,8),('f15',7200,8),('su27',7600,9),
    ('rafale',14000,12),('typhoon',15000,12),('f22',28000,16),('f35',30000,16)
  ) as catalog(id,price,required_level) where id=p_aircraft_id;
  if v_price is null then raise exception 'Unknown aircraft'; end if;
  if not exists(select 1 from public.air_force_profiles where user_id=v_uid and level>=v_level and ac>=v_price) then raise exception 'Level or AC insufficient'; end if;
  update public.air_force_profiles set ac=ac-v_price where user_id=v_uid and ac>=v_price;
  if not found then raise exception 'Insufficient AC'; end if;
  insert into public.air_force_owned_aircraft(user_id,aircraft_id) values(v_uid,p_aircraft_id);
exception when unique_violation then raise exception 'Aircraft already owned';
end; $$;
revoke all on function public.air_force_buy_aircraft(text) from public, anon;
grant execute on function public.air_force_buy_aircraft(text) to authenticated;

create or replace function public.air_force_finish_match(p_score integer)
returns table(ap_earned integer, xp_earned integer, new_level integer)
language plpgsql security definer set search_path = public, pg_temp as $$
declare v_uid uuid := auth.uid(); v_ap integer := 75; v_xp integer;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if p_score is null or p_score < 0 or p_score > 10000 then raise exception 'Invalid match score'; end if;
  v_xp := least(100, greatest(10, p_score / 10));
  update public.air_force_profiles
    set ap=ap+v_ap, xp=xp+v_xp, matches=matches+1,
        level=1+floor((xp+v_xp)::numeric/250)::integer, last_match_at=now()
    where user_id=v_uid and (last_match_at is null or last_match_at < now()-interval '30 seconds');
  if not found then raise exception 'Wait before submitting another match'; end if;
  return query select v_ap, v_xp, p.level from public.air_force_profiles p where p.user_id=v_uid;
end; $$;
revoke all on function public.air_force_finish_match(integer) from public, anon;
grant execute on function public.air_force_finish_match(integer) to authenticated;
