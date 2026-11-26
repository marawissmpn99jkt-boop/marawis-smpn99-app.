-- Restrict aircraft selection to items the member actually owns.
revoke update (selected_aircraft) on public.air_force_profiles from authenticated;
create or replace function public.air_force_select_aircraft(p_aircraft_id text)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not exists(select 1 from public.air_force_owned_aircraft where user_id=v_uid and aircraft_id=p_aircraft_id) then
    raise exception 'Aircraft is not in your hangar';
  end if;
  update public.air_force_profiles set selected_aircraft=p_aircraft_id where user_id=v_uid;
end; $$;
revoke all on function public.air_force_select_aircraft(text) from public, anon;
grant execute on function public.air_force_select_aircraft(text) to authenticated;
