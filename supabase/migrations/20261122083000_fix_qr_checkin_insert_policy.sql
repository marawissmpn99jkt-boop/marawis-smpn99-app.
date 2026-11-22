drop policy if exists "Members check in with QR" on public.attendance;
create policy "Members check in with QR"
on public.attendance
for insert
to authenticated
with check (
  member_id = (select auth.uid())
  and status = 'hadir'
);
