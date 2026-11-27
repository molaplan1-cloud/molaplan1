-- RLS / function tests for the admin 'Käyttäjät' tab (R530–R539). Raises on the first failure.
\set ON_ERROR_STOP on
begin;
insert into auth.users (id, email, created_at, last_sign_in_at, email_confirmed_at) values
  ('00000000-0000-0000-0000-0000000000a1', 'admin@example.test',    '2026-01-01 10:00+00', '2026-11-01 10:00+00', '2026-01-01 10:01+00'),
  ('00000000-0000-0000-0000-0000000000a2', 'admin2@example.test',   '2026-01-02 10:00+00', '2026-11-02 10:00+00', '2026-01-02 10:01+00'),
  ('00000000-0000-0000-0000-0000000000b2', 'customer@example.test', '2026-02-01 10:00+00', '2026-11-20 08:00+00', '2026-02-01 10:01+00'),
  ('00000000-0000-0000-0000-0000000000c3', 'installer@example.test','2026-03-01 10:00+00', '2026-11-15 08:00+00', '2026-03-01 10:01+00'),
  ('00000000-0000-0000-0000-0000000000d4', 'banned@example.test',   '2026-04-01 10:00+00', '2026-10-01 08:00+00', '2026-04-01 10:01+00'),
  ('00000000-0000-0000-0000-0000000000e5', 'delete-me@example.test','2026-05-01 10:00+00', null,                   '2026-05-01 10:01+00'),
  ('00000000-0000-0000-0000-0000000000f6', 'new@example.test',      '2026-06-01 10:00+00', null,                   null);
insert into private.shop_admins values ('admin@example.test'), ('admin2@example.test') on conflict do nothing;

create or replace function pg_temp.as_user(u text, e text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', u, true);
  perform set_config('request.jwt.claims', json_build_object('sub', u, 'email', e, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end $$;
create or replace function pg_temp.as_anon() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claims', '', true);
  execute 'set local role anon';
end $$;
create or replace function pg_temp.expect_fail(q text, what text) returns void language plpgsql as $$
begin
  begin execute q; exception when others then return; end;
  raise exception 'EXPECTED FAILURE did not happen: %', what;
end $$;
create or replace function pg_temp.expect(q text, want text, what text) returns void language plpgsql as $$
declare got text;
begin execute q into got;
  if got is distinct from want then raise exception 'FAIL %: got %, want %', what, got, want; end if; end $$;
grant execute on all functions in schema pg_temp to anon, authenticated;

-- Profiles (display names only; share_pub must never leak through the admin RPCs).
select pg_temp.as_user('00000000-0000-0000-0000-0000000000b2', 'customer@example.test');
insert into public.profiles (display_name, share_pub) values ('Matti Meikäläinen', repeat('B', 43));
insert into public.user_sync (user_id, config, vault) values ('00000000-0000-0000-0000-0000000000b2', '{"secret":"no"}'::jsonb, 'vault-ciphertext');
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000e5', 'delete-me@example.test');
insert into public.user_sync (user_id, config, vault) values ('00000000-0000-0000-0000-0000000000e5', '{"x":1}'::jsonb, 'vault-del');
reset role;

-- Shop orders belong to the customer email (not deleted with the account).
insert into public.shop_orders (id, name, email, status, created_at)
values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', 'Matti', 'customer@example.test', 'uusi',     '2026-11-01 10:00+00'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2', 'Matti', 'customer@example.test', 'maksettu', '2026-11-10 10:00+00');

-- A session that must disappear on ban / delete.
insert into auth.sessions (id, user_id) values
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1', '00000000-0000-0000-0000-0000000000d4'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2', '00000000-0000-0000-0000-0000000000e5');

-- 1. Anon and a normal user cannot call the admin RPCs.
select pg_temp.as_anon();
select pg_temp.expect_fail($q$ select * from public.admin_list_users() $q$, 'anon list users');
select pg_temp.expect_fail($q$ select * from public.admin_get_user('00000000-0000-0000-0000-0000000000b2') $q$, 'anon get user');
select pg_temp.expect_fail($q$ select public.admin_set_user_banned('00000000-0000-0000-0000-0000000000d4', true) $q$, 'anon ban');
select pg_temp.expect_fail($q$ select public.admin_delete_user('00000000-0000-0000-0000-0000000000e5', 'delete-me@example.test') $q$, 'anon delete');
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000b2', 'customer@example.test');
select pg_temp.expect_fail($q$ select * from public.admin_list_users() $q$, 'customer list users');
select pg_temp.expect_fail($q$ select * from public.admin_get_user('00000000-0000-0000-0000-0000000000b2') $q$, 'customer get user');
select pg_temp.expect_fail($q$ select public.admin_set_user_banned('00000000-0000-0000-0000-0000000000d4', true) $q$, 'customer ban');
select pg_temp.expect_fail($q$ select public.admin_delete_user('00000000-0000-0000-0000-0000000000e5', 'delete-me@example.test') $q$, 'customer delete');
-- The customer still cannot read anyone else's sync row (unchanged RLS).
select pg_temp.expect($q$ select count(*)::text from public.user_sync $q$, '1', 'customer sees only own sync');
reset role;

-- 2. Admin list: paging, search by email and name, columns, no private payload.
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1', 'admin@example.test');
select pg_temp.expect($q$ select count(*)::text from public.admin_list_users() $q$, '7', 'admin lists every account');
select pg_temp.expect($q$ select max(total_count)::text from public.admin_list_users('', 2, 0) $q$, '7', 'total_count is the full match, not the page');
select pg_temp.expect($q$ select count(*)::text from public.admin_list_users('', 2, 0) $q$, '2', 'page size 2');
select pg_temp.expect($q$ select ((select email from public.admin_list_users('', 2, 0) offset 1 limit 1) is distinct from
  (select email from public.admin_list_users('', 2, 2) limit 1))::text $q$, 'true', 'offset pages differ');
select pg_temp.expect($q$ select email from public.admin_list_users('customer@') $q$, 'customer@example.test', 'search by email');
select pg_temp.expect($q$ select email from public.admin_list_users('meikäläinen') $q$, 'customer@example.test', 'search by display name');
select pg_temp.expect($q$ select count(*)::text from public.admin_list_users('zzz-no-such') $q$, '0', 'empty search result');
select pg_temp.expect($q$ select (order_count::text || '/' || email_confirmed::text || '/' || banned::text || '/' || is_admin::text)
  from public.admin_list_users('customer@') $q$, '2/true/false/false', 'customer columns');
select pg_temp.expect($q$ select (email_confirmed::text || '/' || banned::text) from public.admin_list_users('new@') $q$,
  'false/false', 'unconfirmed not banned');
select pg_temp.expect($q$ select is_admin::text from public.admin_list_users('admin2@') $q$, 'true', 'other admin flagged');
-- LIKE metacharacters are literals, not wildcards.
select pg_temp.expect($q$ select count(*)::text from public.admin_list_users('%') $q$, '0', 'percent is literal');

-- 3. Detail: orders listed, no vault / config / share key in the payload.
select pg_temp.expect($q$ select (order_count::text || '/' || (orders::jsonb -> 0 ->> 'status') || '/' || jsonb_array_length(orders)::text)
  from public.admin_get_user('00000000-0000-0000-0000-0000000000b2') $q$, '2/maksettu/2', 'detail orders newest first');
select pg_temp.expect($q$ select (orders::text like '%vault%' or orders::text like '%share_pub%' or orders::text like '%secret%')::text
  from public.admin_get_user('00000000-0000-0000-0000-0000000000b2') $q$, 'false', 'no private fields in orders json');
select pg_temp.expect_fail($q$ select * from public.admin_get_user('00000000-0000-0000-0000-0000000000ff') $q$, 'get unknown user');

-- Grant installer so the list shows the status (and a link target).
select public.admin_grant_installer('installer@example.test', 'Asentaja Ari', 'Lämpö Oy');
select pg_temp.expect($q$ select (installer_status || '/' || (installer_public_id ~ '^MPL-'))::text
  from public.admin_list_users('installer@') $q$, 'active/true', 'installer status in the list');
reset role;

-- 4. Admins cannot ban or delete themselves or another admin.
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1', 'admin@example.test');
select pg_temp.expect_fail($q$ select public.admin_set_user_banned('00000000-0000-0000-0000-0000000000a1', true) $q$, 'ban self');
select pg_temp.expect_fail($q$ select public.admin_set_user_banned('00000000-0000-0000-0000-0000000000a2', true) $q$, 'ban other admin');
select pg_temp.expect_fail($q$ select public.admin_delete_user('00000000-0000-0000-0000-0000000000a1', 'admin@example.test') $q$, 'delete self');
select pg_temp.expect_fail($q$ select public.admin_delete_user('00000000-0000-0000-0000-0000000000a2', 'admin2@example.test') $q$, 'delete other admin');

-- 5. Ban / unban a normal user; sessions are dropped on ban.
select public.admin_set_user_banned('00000000-0000-0000-0000-0000000000d4', true);
select pg_temp.expect($q$ select banned::text from public.admin_list_users('banned@') $q$, 'true', 'user is banned');
reset role;
select pg_temp.expect($q$ select (banned_until > now())::text from auth.users where id = '00000000-0000-0000-0000-0000000000d4' $q$,
  'true', 'banned_until in the future');
select pg_temp.expect($q$ select count(*)::text from auth.sessions where user_id = '00000000-0000-0000-0000-0000000000d4' $q$,
  '0', 'sessions revoked on ban');
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1', 'admin@example.test');
select public.admin_set_user_banned('00000000-0000-0000-0000-0000000000d4', false);
select pg_temp.expect($q$ select banned::text from public.admin_list_users('banned@') $q$, 'false', 'user is unbanned');
reset role;
select pg_temp.expect($q$ select (banned_until is null)::text from auth.users where id = '00000000-0000-0000-0000-0000000000d4' $q$,
  'true', 'banned_until cleared');

-- 6. GDPR delete: email must match; user + sync gone; shop orders kept; sessions gone.
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1', 'admin@example.test');
select pg_temp.expect_fail($q$ select public.admin_delete_user('00000000-0000-0000-0000-0000000000e5', 'wrong@example.test') $q$,
  'delete with wrong email');
select public.admin_delete_user('00000000-0000-0000-0000-0000000000e5', 'delete-me@example.test');
select pg_temp.expect($q$ select count(*)::text from public.admin_list_users('delete-me@') $q$, '0', 'deleted user not listed');
select pg_temp.expect($q$ select count(*)::text from public.admin_list_users() $q$, '6', 'six accounts remain');
reset role;
select pg_temp.expect($q$ select count(*)::text from auth.users where id = '00000000-0000-0000-0000-0000000000e5' $q$, '0', 'auth row gone');
select pg_temp.expect($q$ select count(*)::text from public.user_sync where user_id = '00000000-0000-0000-0000-0000000000e5' $q$, '0', 'sync gone');
select pg_temp.expect($q$ select count(*)::text from auth.sessions where user_id = '00000000-0000-0000-0000-0000000000e5' $q$, '0', 'sessions gone');
select pg_temp.expect($q$ select count(*)::text from public.shop_orders $q$, '2', 'shop orders kept');

\echo 'admin users RLS tests: all passed'
rollback;
