drop policy if exists "Players can leave their own room" on public.multiplayer_players;
create policy "Players can leave their own room" on public.multiplayer_players
for delete to authenticated using (user_id = (select auth.uid()));
grant delete on public.multiplayer_players to authenticated;
