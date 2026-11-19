alter table public.announcements
  add column if not exists media_url text,
  add column if not exists media_type text;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'announcement-media',
  'announcement-media',
  true,
  104857600,
  array['image/jpeg','image/png','image/webp','image/gif','video/mp4','video/webm','video/quicktime']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Announcement media public read" on storage.objects;
create policy "Announcement media public read"
on storage.objects for select
to public
using (bucket_id = 'announcement-media');

drop policy if exists "Announcement media staff upload" on storage.objects;
create policy "Announcement media staff upload"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'announcement-media'
  and exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid())
      and p.role in ('pengurus', 'pembina')
  )
);

drop policy if exists "Announcement media staff update" on storage.objects;
create policy "Announcement media staff update"
on storage.objects for update
to authenticated
using (
  bucket_id = 'announcement-media'
  and exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid())
      and p.role in ('pengurus', 'pembina')
  )
)
with check (
  bucket_id = 'announcement-media'
  and exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid())
      and p.role in ('pengurus', 'pembina')
  )
);

drop policy if exists "Announcement media staff delete" on storage.objects;
create policy "Announcement media staff delete"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'announcement-media'
  and exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid())
      and p.role in ('pengurus', 'pembina')
  )
);
