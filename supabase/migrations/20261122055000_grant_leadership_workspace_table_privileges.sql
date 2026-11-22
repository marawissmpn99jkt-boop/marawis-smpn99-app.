-- Grant the Data API privileges required by the Leadership Workspace.
-- Row-level security policies continue to enforce member/staff access.
grant select, insert, update on table public.marawis_letters to authenticated;
grant select, insert, update, delete on table public.marawis_meetings to authenticated;
grant select, insert, update, delete on table public.marawis_emergency_announcements to authenticated;
