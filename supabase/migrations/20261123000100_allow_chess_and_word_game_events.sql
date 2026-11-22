-- Keep every event type currently emitted by the Flutter multiplayer client.
-- The previous constraint omitted chess_move (and word_answer), causing
-- Postgres error 23514 when players make a move or submit a word-game answer.
alter table public.multiplayer_events
  drop constraint if exists multiplayer_events_event_type_check;

alter table public.multiplayer_events
  add constraint multiplayer_events_event_type_check
  check (
    event_type in (
      'answer',
      'vote',
      'draw',
      'guess',
      'system',
      'reaction_tap',
      'choice_vote',
      'undo',
      'clear',
      'chess_move',
      'word_answer'
    )
  );
