-- Source for the already-applied production migration
-- 20261117063834_assigned_task_status_updates.
-- Assignees may update only the status of tasks assigned to their own account.

create or replace function public.protect_assigned_program_task_fields()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.role() is distinct from 'service_role'
     and not public.is_marawis_admin() then
    if new.id is distinct from old.id
       or new.program_id is distinct from old.program_id
       or new.title is distinct from old.title
       or new.assigned_to is distinct from old.assigned_to
       or new.due_date is distinct from old.due_date
       or new.notes is distinct from old.notes
       or new.created_at is distinct from old.created_at then
      raise exception 'Anggota hanya dapat memperbarui status tugas yang ditugaskan kepadanya.';
    end if;
    new.updated_at := now();
  end if;
  return new;
end;
$$;

revoke execute on function public.protect_assigned_program_task_fields()
  from public, anon, authenticated;

drop trigger if exists protect_assigned_program_task_fields_trigger
  on public.program_tasks;
create trigger protect_assigned_program_task_fields_trigger
before update on public.program_tasks
for each row
execute function public.protect_assigned_program_task_fields();

drop policy if exists "Assignees update own task status"
  on public.program_tasks;
create policy "Assignees update own task status"
on public.program_tasks
for update
to authenticated
using (assigned_to = (select auth.uid()))
with check (assigned_to = (select auth.uid()));
