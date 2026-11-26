-- Air Force public race lobbies use the existing multiplayer room infrastructure.
create or replace function public.air_force_create_room()
returns table(room_id uuid, room_code text)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_code text;
  v_id uuid;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  loop
    v_code := lpad((floor(random() * 1000000))::int::text, 6, '0');
    exit when not exists (select 1 from public.multiplayer_rooms r where r.room_code = v_code and r.status = 'waiting');
  end loop;
  insert into public.multiplayer_rooms(room_code, game_type, host_id, max_players, game_state)
  values (v_code, 'air_force_race', v_uid, 8, jsonb_build_object('mode','checkpoint_race'))
  returning id into v_id;
  return query select v_id, v_code;
end;
$$;

create or replace function public.air_force_start_room(p_room_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  update public.multiplayer_rooms
     set status = 'playing',
         game_state = coalesce(game_state, '{}'::jsonb) || jsonb_build_object('started_at', now(), 'mode', 'checkpoint_race'),
         updated_at = now()
   where id = p_room_id and host_id = v_uid and game_type = 'air_force_race' and status = 'waiting';
  if not found then raise exception 'Room tidak ditemukan atau kamu bukan host'; end if;
end;
$$;

revoke all on function public.air_force_create_room() from public, anon;
revoke all on function public.air_force_start_room(uuid) from public, anon;
grant execute on function public.air_force_create_room() to authenticated;
grant execute on function public.air_force_start_room(uuid) to authenticated;
