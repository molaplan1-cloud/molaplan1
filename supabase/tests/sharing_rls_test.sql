-- RLS / permission tests for R215–R217 (shares, profiles, invite functions).
-- Every check raises on failure; the runner stops at the first error (ON_ERROR_STOP).
\set ON_ERROR_STOP on
begin;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'owner@example.test'),
  ('00000000-0000-0000-0000-0000000000b2', 'friend@example.test'),
  ('00000000-0000-0000-0000-0000000000c3', 'installer@example.test'),
  ('00000000-0000-0000-0000-0000000000d4', 'stranger@example.test');

create or replace function pg_temp.as_user(u text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', u, true);
  execute 'set local role authenticated';
end $$;

create or replace function pg_temp.expect_fail(q text, what text) returns void language plpgsql as $$
begin
  begin
    execute q;
  exception when others then
    return;
  end;
  raise exception 'EXPECTED FAILURE did not happen: %', what;
end $$;

create or replace function pg_temp.expect_rows(q text, n int, what text) returns void language plpgsql as $$
declare got int;
begin
  execute 'select count(*) from (' || q || ') x' into got;
  if got <> n then raise exception 'FAIL %: expected % rows, got %', what, n, got; end if;
end $$;

-- 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx' style keys (43 chars base64url)
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1');
insert into public.profiles (display_name, share_pub) values ('Owner', repeat('A', 43));
select pg_temp.expect_fail($q$ insert into public.profiles (user_id, display_name) values ('00000000-0000-0000-0000-0000000000b2', 'fake') $q$,
  'profile for someone else');
reset role;

select pg_temp.as_user('00000000-0000-0000-0000-0000000000b2');
insert into public.profiles (display_name, share_pub) values ('Friend', repeat('B', 43));
select pg_temp.expect_rows($q$ select * from public.profiles $q$, 1, 'profiles: only own row visible');
reset role;

select pg_temp.as_user('00000000-0000-0000-0000-0000000000c3');
-- R256: a user cannot make themselves an installer any more; an admin grants it (here: directly as the DB owner).
-- (Old apps still send installer/company: accepted, but the trigger keeps them from public.installers.)
insert into public.profiles (display_name, share_pub, installer, company) values ('Asentaja', repeat('C', 43), true, 'Fake Oy');
select pg_temp.expect_rows($q$ select * from public.profiles where installer or company <> '' $q$, 0, 'self-made installer profile has no effect');
update public.profiles set installer = true, company = 'Fake Oy';
select pg_temp.expect_rows($q$ select * from public.profiles where installer or company <> '' $q$, 0, 'self-enable installer has no effect');
reset role;
insert into public.installers (user_id, public_id, display_name, company)
values ('00000000-0000-0000-0000-0000000000c3', 'MPL-AAA-CCC', 'Asentaja', 'Lämpö Oy');

select pg_temp.as_user('00000000-0000-0000-0000-0000000000d4');
insert into public.profiles (display_name, share_pub) values ('Stranger', repeat('D', 43));
reset role;

-- owner finds the friend by e-mail (only public data), not himself, not unknown addresses
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1');
select pg_temp.expect_rows($q$ select * from public.find_share_recipient('Friend@Example.test') where share_pub = repeat('B', 43) $q$, 1, 'lookup by email');
select pg_temp.expect_rows($q$ select * from public.find_share_recipient('owner@example.test') $q$, 0, 'lookup self');
select pg_temp.expect_rows($q$ select * from public.find_share_recipient('nobody@example.test') $q$, 0, 'lookup unknown');

-- direct share to the friend
insert into public.shares (id, recipient_id, label, level, summary, owner_name, recipient_name, recipient_pub, payload)
values ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-0000000000b2', 'Sauna', 'limited',
  '{"tiles":[{"id":"t1","title":"Sauna"}]}', 'Owner', 'Friend', repeat('B', 43), 'sealed-ciphertext');
-- cannot create a share in someone else's name or already active
select pg_temp.expect_fail($q$ insert into public.shares (owner_id, recipient_id, payload) values
  ('00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-0000000000d4', 'x') $q$, 'share as another owner');
select pg_temp.expect_fail($q$ insert into public.shares (recipient_id, status) values ('00000000-0000-0000-0000-0000000000b2', 'active') $q$,
  'insert active');
select pg_temp.expect_fail($q$ insert into public.shares (recipient_id) values ('00000000-0000-0000-0000-0000000000a1') $q$, 'share to self');
-- the owner cannot accept on the recipient's behalf, nor redirect the share
select pg_temp.expect_fail($q$ update public.shares set status = 'active' where id = '11111111-1111-1111-1111-111111111111' $q$,
  'owner accepts himself');
select pg_temp.expect_fail($q$ update public.shares set recipient_id = '00000000-0000-0000-0000-0000000000d4' where id = '11111111-1111-1111-1111-111111111111' $q$,
  'owner redirects share');
reset role;

-- a stranger sees nothing and cannot touch it
select pg_temp.as_user('00000000-0000-0000-0000-0000000000d4');
select pg_temp.expect_rows($q$ select * from public.shares $q$, 0, 'stranger sees no shares');
update public.shares set label = 'hacked' where id = '11111111-1111-1111-1111-111111111111';
select pg_temp.expect_fail($q$ select public.accept_share('11111111-1111-1111-1111-111111111111') $q$, 'stranger accepts');
reset role;
select pg_temp.expect_rows($q$ select * from public.shares where label = 'Sauna' $q$, 1, 'stranger update had no effect');

-- the friend sees it, cannot edit it directly, accepts it
select pg_temp.as_user('00000000-0000-0000-0000-0000000000b2');
select pg_temp.expect_rows($q$ select * from public.shares where status = 'pending' $q$, 1, 'recipient sees invite');
update public.shares set label = 'mine now' where id = '11111111-1111-1111-1111-111111111111';
select pg_temp.expect_fail($q$ delete from public.shares where id = '11111111-1111-1111-1111-111111111111' returning 1/0 $q$, 'recipient deletes');
select public.accept_share('11111111-1111-1111-1111-111111111111');
select pg_temp.expect_fail($q$ select public.accept_share('11111111-1111-1111-1111-111111111111') $q$, 'accept twice');
reset role;
select pg_temp.expect_rows($q$ select * from public.shares where status = 'active' and label = 'Sauna' $q$, 1, 'accepted, label unchanged');

-- the owner revokes: payload is wiped, then it is closed for good
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1');
update public.shares set status = 'revoked' where id = '11111111-1111-1111-1111-111111111111';
select pg_temp.expect_rows($q$ select * from public.shares where status = 'revoked' and payload is null $q$, 1, 'revoked wipes payload');
select pg_temp.expect_fail($q$ update public.shares set status = 'active', payload = 'x' where id = '11111111-1111-1111-1111-111111111111' $q$,
  'reopen revoked');

-- installer code invite
insert into public.shares (id, kind, label, level, owner_name, code_hash, code_expires_at)
values ('22222222-2222-2222-2222-222222222222', 'installer', 'Lämpöpumppu', 'full', 'Owner', repeat('ab', 32), now() + interval '7 days');
insert into public.shares (id, kind, code_hash, code_expires_at)
values ('33333333-3333-3333-3333-333333333333', 'installer', repeat('cd', 32), now() - interval '1 minute');
select pg_temp.expect_fail($q$ select public.claim_invite(repeat('ab', 32)) $q$, 'owner claims own code');
reset role;

-- a normal user (no installer profile) cannot use an installer code; nobody can see code rows
select pg_temp.as_user('00000000-0000-0000-0000-0000000000d4');
select pg_temp.expect_rows($q$ select * from public.shares $q$, 0, 'code rows not visible to others');
select pg_temp.expect_fail($q$ select public.claim_invite(repeat('ab', 32)) $q$, 'non-installer claims installer code');
reset role;

select pg_temp.as_user('00000000-0000-0000-0000-0000000000c3');
select pg_temp.expect_fail($q$ select public.claim_invite(repeat('cd', 32)) $q$, 'expired code');
select pg_temp.expect_fail($q$ select public.claim_invite(repeat('ef', 32)) $q$, 'unknown code');
select public.claim_invite(repeat('ab', 32));
select pg_temp.expect_rows($q$ select * from public.shares where status = 'claimed' and recipient_pub = repeat('C', 43) and recipient_name = 'Lämpö Oy · Asentaja' and code_hash is null $q$,
  1, 'claimed by installer, code used up');
reset role;
-- single use
select pg_temp.as_user('00000000-0000-0000-0000-0000000000b2');
select pg_temp.expect_fail($q$ select public.claim_invite(repeat('ab', 32)) $q$, 'code reused');
reset role;

-- owner seals the credential and activates; installer leaves later
select pg_temp.as_user('00000000-0000-0000-0000-0000000000a1');
select pg_temp.expect_fail($q$ update public.shares set status = 'active' where id = '22222222-2222-2222-2222-222222222222' $q$,
  'activate without credential');
update public.shares set status = 'active', payload = 'sealed-for-installer' where id = '22222222-2222-2222-2222-222222222222';
reset role;
select pg_temp.as_user('00000000-0000-0000-0000-0000000000c3');
select pg_temp.expect_rows($q$ select * from public.shares where kind = 'installer' and status = 'active' $q$, 1, 'installer sees customer');
select public.leave_share('22222222-2222-2222-2222-222222222222');
select pg_temp.expect_rows($q$ select * from public.shares where status = 'declined' and payload is null $q$, 1, 'left');
reset role;

-- anon has no access at all
set local role anon;
select pg_temp.expect_fail($q$ select * from public.shares $q$, 'anon select shares');
select pg_temp.expect_fail($q$ select * from public.profiles $q$, 'anon select profiles');
select pg_temp.expect_fail($q$ select public.find_share_recipient('friend@example.test') $q$, 'anon lookup');
select pg_temp.expect_fail($q$ select private.claim_invite(repeat('ab', 32)) $q$, 'anon private function');
reset role;

-- account deletion removes the user's shares and profile
delete from auth.users where id = '00000000-0000-0000-0000-0000000000a1';
select pg_temp.expect_rows($q$ select * from public.shares where owner_id = '00000000-0000-0000-0000-0000000000a1' $q$, 0, 'cascade shares');
select pg_temp.expect_rows($q$ select * from public.profiles where user_id = '00000000-0000-0000-0000-0000000000a1' $q$, 0, 'cascade profile');

\echo 'sharing RLS tests: all passed'
rollback;
