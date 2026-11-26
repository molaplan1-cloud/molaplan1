-- RLS / function tests for approved installers (R256–R262). Raises on the first failure.
\set ON_ERROR_STOP on
begin;
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'admin@example.test'),
  ('00000000-0000-0000-0000-0000000000b2', 'customer@example.test'),
  ('00000000-0000-0000-0000-0000000000c3', 'installer@example.test'),
  ('00000000-0000-0000-0000-0000000000d4', 'selfmade@example.test');
insert into private.shop_admins values ('admin@example.test') on conflict do nothing;

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

-- Profiles (keys published by each app).
select pg_temp.as_user('00000000-0000-0000-0000-0000000000b2', 'customer@example.test');
insert into public.profiles (display_name, share_pub) values ('Asiakas', repeat('B', 43));
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000c3', 'installer@example.test');
insert into public.profiles (display_name, share_pub) values ('Asentaja', repeat('C', 43));
reset role;
-- A profile that was self-enabled under the old model (simulated as the DB owner, like a pre-0.13 row).
insert into public.profiles (user_id, display_name, share_pub) values ('00000000-0000-0000-0000-0000000000d4', 'Itse', repeat('D', 43));
alter table public.profiles disable trigger profiles_installer_init;
update public.profiles set installer = true, company = 'Oma Oy' where user_id = '00000000-0000-0000-0000-0000000000d4';
alter table public.profiles enable trigger profiles_installer_init;

-- 1. Nobody can make themselves an installer.
select pg_temp.as_user('00000000-0000-0000-0000-0000000000d4', 'selfmade@example.test');
-- (Old apps may still send the columns; the write is accepted but has no effect.)
update public.profiles set installer = true, company = 'X';
select pg_temp.expect($q$ select installer::text || '/' || company from public.profiles where user_id = auth.uid() $q$, 'false/', 'self-enable via profile has no effect');
select pg_temp.expect_fail($q$ insert into public.installers (user_id, public_id, display_name) values (auth.uid(), 'MPL-AAA-AAA', 'x') $q$, 'insert installers row');
select pg_temp.expect_fail($q$ select public.admin_grant_installer('selfmade@example.test', 'Itse') $q$, 'non-admin grant');
select pg_temp.expect_fail($q$ select * from public.admin_list_installers() $q$, 'non-admin list');
select pg_temp.expect_fail($q$ select * from public.admin_find_user('example') $q$, 'non-admin find user');
select pg_temp.expect_fail($q$ select public.admin_revoke_installer('00000000-0000-0000-0000-0000000000c3') $q$, 'non-admin revoke');
select pg_temp.expect_fail($q$ select * from public.admin_list_installer_applications() $q$, 'non-admin applications');
-- an application is allowed (one open at a time), visible to its author only
insert into public.installer_applications (display_name, company, message) values ('Itse', 'Oma Oy', 'Haluan asentajaksi');
select pg_temp.expect_fail($q$ insert into public.installer_applications (display_name) values ('Toinen') $q$, 'second open application');
select pg_temp.expect_fail($q$ insert into public.installer_applications (display_name, status) values ('x', 'approved') $q$, 'self-approved application');
select pg_temp.expect($q$ select count(*)::text from public.installer_applications $q$, '1', 'own application visible');
select pg_temp.expect($q$ select email from public.installer_applications $q$, 'selfmade@example.test', 'email filled from the session');
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000b2', 'customer@example.test');
select pg_temp.expect($q$ select count(*)::text from public.installer_applications $q$, '0', 'others cannot see applications');
reset role;

-- 2. Migration: a self-enabled installer without approval loses the flag (re-run the cleanup).
update public.profiles p set installer = false, company = ''
 where p.installer and not exists (select 1 from public.installers i where i.user_id = p.user_id and i.status = 'active');
select pg_temp.expect($q$ select installer::text from public.profiles where user_id = '00000000-0000-0000-0000-0000000000d4' $q$, 'false', 'old flag cleared');

-- 3. Admin grants: permanent readable ID, verified name, profile in sync.
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1', 'admin@example.test');
select pg_temp.expect($q$ select count(*)::text from public.admin_find_user('installer@') $q$, '1', 'admin finds user by email');
select pg_temp.expect($q$ select count(*)::text from public.admin_find_user('ex') $q$, '0', 'too short search');
select pg_temp.expect_fail($q$ select public.admin_grant_installer('nobody@example.test', 'X') $q$, 'grant unknown email');
select pg_temp.expect_fail($q$ select public.admin_grant_installer('installer@example.test', '  ') $q$, 'grant without name');
select public.admin_grant_installer('installer@example.test', 'Asentaja Ari', 'Lämpö Oy', 'tarkistettu Y-tunnus');
select public.admin_grant_installer('selfmade@example.test', 'Itse Ilkka', 'Kevytyrittäjä', '');
select pg_temp.expect($q$ select (public_id ~ '^MPL-[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{3}-[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{3}$')::text
  from public.admin_list_installers() where email = 'installer@example.test' $q$, 'true', 'ID format');
select pg_temp.expect($q$ select (count(distinct public_id) = count(*) and count(*) filter (where email like '%@example.test') = 2)::text from public.admin_list_installers() $q$, 'true', 'IDs unique');
select pg_temp.expect($q$ select status from public.admin_list_installer_applications() $q$, 'approved', 'application approved by the grant');
reset role;
select pg_temp.expect($q$ select installer::text || company from public.profiles where user_id = '00000000-0000-0000-0000-0000000000c3' $q$,
  'trueLämpö Oy', 'profile synced');
create temp table ids as select user_id, public_id from public.installers;
grant select on ids to authenticated, anon;

-- 4. The installer sees their own row (not the admin note), nobody else's.
select pg_temp.as_user('00000000-0000-0000-0000-0000000000c3', 'installer@example.test');
select pg_temp.expect($q$ select display_name from public.installers $q$, 'Asentaja Ari', 'own installer row');
select pg_temp.expect_fail($q$ select note from public.installers $q$, 'admin note hidden');
select pg_temp.expect_fail($q$ update public.installers set display_name = 'Muu' $q$, 'installer edits own row');
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000b2', 'customer@example.test');
select pg_temp.expect($q$ select count(*)::text from public.installers $q$, '0', 'customer cannot list installers');

-- 5. Customer looks up by ID (typing variations) and grants access directly (active at once).
select pg_temp.expect($q$ select display_name || '/' || company || '/' || share_pub from public.find_installer(
  lower(replace((select public_id from ids where user_id = '00000000-0000-0000-0000-0000000000c3'), '-', ' '))) $q$,
  'Asentaja Ari/Lämpö Oy/' || repeat('C', 43), 'find by ID');
select pg_temp.expect($q$ select count(*)::text from public.find_installer('MPL-ZZZ-ZZZ') $q$, '0', 'unknown ID');
insert into public.shares (id, recipient_id, kind, status, label, level, summary, owner_name, recipient_name, recipient_pub, payload)
values ('44444444-4444-4444-4444-444444444444', '00000000-0000-0000-0000-0000000000c3', 'installer', 'active', '', 'full',
  '{"tiles":[{"id":"t1","title":"Lämpöpumppu"}]}', 'Asiakas', 'Typed Fake Name', repeat('C', 43), 'sealed');
select pg_temp.expect($q$ select recipient_name from public.shares where id = '44444444-4444-4444-4444-444444444444' $q$,
  'Lämpö Oy · Asentaja Ari', 'verified name stored, typed one ignored');
-- not to a non-installer, not active without a credential, not an active normal share
select pg_temp.expect_fail($q$ insert into public.shares (recipient_id, kind, status, payload) values
  ('00000000-0000-0000-0000-0000000000a1', 'installer', 'active', 'x') $q$, 'installer share to a non-installer');
select pg_temp.expect_fail($q$ insert into public.shares (recipient_id, kind) values
  ('00000000-0000-0000-0000-0000000000a1', 'installer') $q$, 'pending installer share to a non-installer');
select pg_temp.expect_fail($q$ insert into public.shares (recipient_id, kind, status) values
  ('00000000-0000-0000-0000-0000000000c3', 'installer', 'active') $q$, 'active without credential');
select pg_temp.expect_fail($q$ insert into public.shares (recipient_id, kind, status, payload) values
  ('00000000-0000-0000-0000-0000000000a1', 'share', 'active', 'x') $q$, 'normal share active at once');
reset role;

-- 6. Bridge check: anon may ask one share's state.
select pg_temp.as_anon();
select pg_temp.expect($q$ select public.share_access('44444444-4444-4444-4444-444444444444') $q$, 'active', 'bridge check active');
select pg_temp.expect($q$ select public.share_access('99999999-9999-9999-9999-999999999999') $q$, 'gone', 'bridge check unknown');
select pg_temp.expect_fail($q$ select * from public.installers $q$, 'anon reads installers');
select pg_temp.expect_fail($q$ select * from public.find_installer('MPL-AAA-AAA') $q$, 'anon find installer');
select pg_temp.expect_fail($q$ select * from public.installer_applications $q$, 'anon applications');
reset role;

-- 7. Customer revokes (as before) / admin revokes the status: every access closes at once.
select pg_temp.as_user('00000000-0000-0000-0000-0000000000b2', 'customer@example.test');
insert into public.shares (id, recipient_id, kind, status, payload)
values ('55555555-5555-5555-5555-555555555555', '00000000-0000-0000-0000-0000000000c3', 'installer', 'active', 'sealed2');
update public.shares set status = 'revoked' where id = '55555555-5555-5555-5555-555555555555';
select pg_temp.expect($q$ select status || coalesce(payload, '-') from public.shares where id = '55555555-5555-5555-5555-555555555555' $q$,
  'revoked-', 'customer revoke');
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1', 'admin@example.test');
select public.admin_revoke_installer('00000000-0000-0000-0000-0000000000c3');
select pg_temp.expect_fail($q$ select public.admin_revoke_installer('00000000-0000-0000-0000-0000000000c3') $q$, 'revoke twice');
reset role;
select pg_temp.expect($q$ select status || coalesce(payload, '-') from public.shares where id = '44444444-4444-4444-4444-444444444444' $q$,
  'revoked-', 'admin revoke closes shares');
select pg_temp.expect($q$ select installer::text || company from public.profiles where user_id = '00000000-0000-0000-0000-0000000000c3' $q$,
  'false', 'profile synced on revoke');
select pg_temp.as_anon();
select pg_temp.expect($q$ select public.share_access('44444444-4444-4444-4444-444444444444') $q$, 'gone', 'bridge sees gone');
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000b2', 'customer@example.test');
select pg_temp.expect($q$ select count(*)::text from public.find_installer((select public_id from ids where user_id = '00000000-0000-0000-0000-0000000000c3')) $q$,
  '0', 'revoked installer not found');
select pg_temp.expect_fail($q$ insert into public.shares (recipient_id, kind, status, payload) values
  ('00000000-0000-0000-0000-0000000000c3', 'installer', 'active', 'x') $q$, 'grant to revoked installer');
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000c3', 'installer@example.test');
select pg_temp.expect($q$ select status from public.installers $q$, 'revoked', 'installer sees own revoked status');
reset role;

-- 8. Re-grant keeps the same permanent ID; the ID itself cannot be changed.
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1', 'admin@example.test');
select public.admin_grant_installer('installer@example.test', 'Asentaja Ari', 'Lämpö Oy');
select pg_temp.expect($q$ select (public_id = (select public_id from ids where user_id = '00000000-0000-0000-0000-0000000000c3'))::text
  from public.admin_list_installers() where email = 'installer@example.test' $q$, 'true', 'same ID after re-grant');
reset role;
select pg_temp.expect_fail($q$ update public.installers set public_id = 'MPL-AAA-AAA' where user_id = '00000000-0000-0000-0000-0000000000c3' $q$, 'ID change');
-- revoked shares stay closed after re-grant
select pg_temp.expect($q$ select status from public.shares where id = '44444444-4444-4444-4444-444444444444' $q$, 'revoked', 'old access stays closed');

-- 9. Account deletion removes the installer row.
delete from auth.users where id = '00000000-0000-0000-0000-0000000000d4';
select pg_temp.expect($q$ select count(*)::text from public.installers where user_id = '00000000-0000-0000-0000-0000000000d4' $q$, '0', 'cascade');

\echo 'installers RLS tests: all passed'
rollback;
