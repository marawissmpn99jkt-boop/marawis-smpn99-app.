alter table public.multiplayer_rooms
  drop constraint if exists multiplayer_rooms_game_type_check;
alter table public.multiplayer_rooms
  add constraint multiplayer_rooms_game_type_check
  check (game_type in ('quiz_arena','who_leader','draw_guess','reaction_rush','this_or_that'));

alter table public.multiplayer_events
  drop constraint if exists multiplayer_events_event_type_check;
alter table public.multiplayer_events
  add constraint multiplayer_events_event_type_check
  check (event_type in ('answer','vote','draw','guess','system','reaction_tap','choice_vote','undo','clear'));

drop policy if exists "Room participants can submit game events" on public.multiplayer_events;
create policy "Room participants can submit game events" on public.multiplayer_events
for insert to authenticated with check (
  actor_id = (select auth.uid()) and exists (
    select 1 from public.multiplayer_players p
    where p.room_id = multiplayer_events.room_id and p.user_id = (select auth.uid())
  )
  and (
    event_type <> 'draw' or exists (
      select 1 from public.multiplayer_rooms r
      where r.id = multiplayer_events.room_id
        and r.game_state->>'drawer_id' = (select auth.uid())::text
    )
  )
  and (
    event_type <> 'guess' or not (payload ? 'accepted') or exists (
      select 1 from public.multiplayer_rooms r
      where r.id = multiplayer_events.room_id
        and r.game_state->>'drawer_id' = (select auth.uid())::text
    )
  )
);
