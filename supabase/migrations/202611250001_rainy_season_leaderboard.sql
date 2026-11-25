-- Shared Rainy Season leaderboard.
-- Scores are submitted through a security-invoker RPC and ownership RLS policies.
-- A member can only create or update their own leaderboard row.

create table if not exists public.rainy_season_scores (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Anggota',
  xp integer not null default 0 check (xp >= 0),
  updated_at timestamptz not null default now()
);

alter table public.rainy_season_scores enable row level security;

drop policy if exists "Authenticated members read rainy season leaderboard"
  on public.rainy_season_scores;
create policy "Authenticated members read rainy season leaderboard"
  on public.rainy_season_scores
  for select
  to authenticated
  using (true);

revoke all on public.rainy_season_scores from anon, public;
grant select, insert, update on public.rainy_season_scores to authenticated;

drop policy if exists "Members submit own Rainy Season score"
  on public.rainy_season_scores;
create policy "Members submit own Rainy Season score"
  on public.rainy_season_scores
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "Members update own Rainy Season score"
  on public.rainy_season_scores;
create policy "Members update own Rainy Season score"
  on public.rainy_season_scores
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create or replace function public.submit_rainy_season_score(p_xp integer)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_display_name text;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  if p_xp is null or p_xp < 0 or p_xp > 1000000 then
    raise exception 'Invalid Rainy Season XP';
  end if;

  select coalesce(nullif(trim(full_name), ''), 'Anggota')
    into v_display_name
    from public.profiles
    where id = v_user_id;

  insert into public.rainy_season_scores (user_id, display_name, xp, updated_at)
  values (v_user_id, coalesce(v_display_name, 'Anggota'), p_xp, now())
  on conflict (user_id) do update
    set display_name = excluded.display_name,
        xp = greatest(rainy_season_scores.xp, excluded.xp),
        updated_at = now();
end;
$$;

revoke all on function public.submit_rainy_season_score(integer) from public, anon;
grant execute on function public.submit_rainy_season_score(integer) to authenticated;
