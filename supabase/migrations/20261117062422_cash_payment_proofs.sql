-- Private evidence storage for member cash-transfer submissions.
-- Members can upload and view only their own files; admins can view evidence for verification.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'cash-payment-proofs',
  'cash-payment-proofs',
  false,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do nothing;

drop policy if exists "Users view own cash payment proofs or admin" on storage.objects;
create policy "Users view own cash payment proofs or admin"
on storage.objects for select
to authenticated
using (
  bucket_id = 'cash-payment-proofs'
  and (
    (storage.foldername(name))[1] = (select auth.uid())::text
    or public.is_marawis_admin()
  )
);

drop policy if exists "Users upload own cash payment proofs" on storage.objects;
create policy "Users upload own cash payment proofs"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'cash-payment-proofs'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "Users delete own cash payment proofs" on storage.objects;
create policy "Users delete own cash payment proofs"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'cash-payment-proofs'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);
