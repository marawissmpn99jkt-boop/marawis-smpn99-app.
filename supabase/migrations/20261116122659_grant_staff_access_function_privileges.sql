-- Explicitly grant only the database operations required by the staff-access Edge Function.
grant select, update on table public.profiles to service_role;
grant select, insert, delete on table public.staff_access_attempts to service_role;
grant usage, select on sequence public.staff_access_attempts_id_seq to service_role;
grant insert on table public.audit_logs to service_role;
