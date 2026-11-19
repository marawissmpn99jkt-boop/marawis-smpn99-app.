drop policy if exists attempts_insert_own on public.marawis_quiz_attempts;
revoke insert,update,delete on public.marawis_quiz_attempts from authenticated;
