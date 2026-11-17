-- Restrict trigger-only SECURITY DEFINER functions to their owner.
-- This migration is already present in the production migration history.
revoke execute on function public.handle_new_marawis_user() from public, anon, authenticated;
revoke execute on function public.protect_marawis_profile_role() from public, anon, authenticated;
revoke execute on function public.protect_member_admin_fields() from public, anon, authenticated;
revoke execute on function public.sync_member_directory_profile() from public, anon, authenticated;
