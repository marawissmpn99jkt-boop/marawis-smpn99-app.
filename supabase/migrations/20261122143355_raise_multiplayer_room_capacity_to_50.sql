alter table public.multiplayer_rooms
  drop constraint if exists multiplayer_rooms_max_players_check;

alter table public.multiplayer_rooms
  add constraint multiplayer_rooms_max_players_check
  check (max_players >= 2 and max_players <= 50);
