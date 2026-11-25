-- Tile background images (t112u): private bucket, one folder per user (= auth.uid()).
-- Free tier: files are ≤ 200 KB JPEG (app compresses), bucket hard limit 256 KB, app caps 40 images/user.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('tile-images', 'tile-images', false, 262144, array['image/jpeg'])
on conflict (id) do update
  set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "tile images: own read" on storage.objects;
drop policy if exists "tile images: own insert" on storage.objects;
drop policy if exists "tile images: own update" on storage.objects;
drop policy if exists "tile images: own delete" on storage.objects;

create policy "tile images: own read" on storage.objects for select to authenticated
  using (bucket_id = 'tile-images' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "tile images: own insert" on storage.objects for insert to authenticated
  with check (bucket_id = 'tile-images' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "tile images: own update" on storage.objects for update to authenticated
  using (bucket_id = 'tile-images' and (storage.foldername(name))[1] = (select auth.uid())::text)
  with check (bucket_id = 'tile-images' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "tile images: own delete" on storage.objects for delete to authenticated
  using (bucket_id = 'tile-images' and (storage.foldername(name))[1] = (select auth.uid())::text);
