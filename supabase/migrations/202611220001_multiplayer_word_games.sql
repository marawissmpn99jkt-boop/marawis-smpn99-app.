alter table public.multiplayer_rooms
  drop constraint if exists multiplayer_rooms_game_type_check;
alter table public.multiplayer_rooms
  add constraint multiplayer_rooms_game_type_check
  check (game_type in ('quiz_arena','who_leader','draw_guess','reaction_rush','this_or_that','word_guess','word_scramble','emoji_guess'));

alter table public.multiplayer_events
  drop constraint if exists multiplayer_events_event_type_check;
alter table public.multiplayer_events
  add constraint multiplayer_events_event_type_check
  check (event_type in ('answer','vote','draw','guess','system','reaction_tap','choice_vote','undo','clear','word_answer'));
