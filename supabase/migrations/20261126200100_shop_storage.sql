-- Storage for the order shop (Supabase-only; skipped by tool/rls_test.sh).
-- shop-images: public product pictures (admins upload). shop-downloads: private PC-app zip, signed URLs
-- only for accounts with a paid PC-app order (private.has_pc_license()).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('shop-images', 'shop-images', true, 3145728, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set public = true, file_size_limit = 3145728, allowed_mime_types = excluded.allowed_mime_types;
insert into storage.buckets (id, name, public, file_size_limit)
values ('shop-downloads', 'shop-downloads', false, 209715200)
on conflict (id) do update set public = false, file_size_limit = 209715200;

drop policy if exists "shop images: admin write" on storage.objects;
create policy "shop images: admin write" on storage.objects for all to authenticated
  using (bucket_id = 'shop-images' and (select private.is_shop_admin()))
  with check (bucket_id = 'shop-images' and (select private.is_shop_admin()));

drop policy if exists "shop downloads: admin write" on storage.objects;
create policy "shop downloads: admin write" on storage.objects for all to authenticated
  using (bucket_id = 'shop-downloads' and (select private.is_shop_admin()))
  with check (bucket_id = 'shop-downloads' and (select private.is_shop_admin()));

drop policy if exists "shop downloads: licensed read" on storage.objects;
create policy "shop downloads: licensed read" on storage.objects for select to authenticated
  using (bucket_id = 'shop-downloads' and (select private.has_pc_license()));

-- Retention (privacy notice): requests that never became a sale are deleted after 24 months,
-- invoiced/paid/delivered orders after 7 years. Runs daily with pg_cron.
create or replace function private.shop_purge() returns void
language sql security definer set search_path = '' as $$
  delete from public.shop_orders
  where (status in ('uusi', 'tarjottu', 'peruttu') and updated_at < now() - interval '24 months')
     or (status in ('laskutettu', 'maksettu', 'toimitettu') and updated_at < now() - interval '7 years');
$$;
revoke all on function private.shop_purge() from public, anon, authenticated;
create extension if not exists pg_cron;
select cron.unschedule('shop-purge') where exists (select 1 from cron.job where jobname = 'shop-purge');
select cron.schedule('shop-purge', '17 3 * * *', 'select private.shop_purge()');
