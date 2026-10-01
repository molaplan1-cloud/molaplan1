-- Run on a scratch Postgres (NOT the live DB):
--   createdb mtest && psql -d mtest -f supabase/tests/00-supabase-stub.sql -f supabase/schema.sql -f supabase/tests/friends-teams-unlimited.sql
-- Merge 2026-10-01: friends, event invites, unlimited participants, teams RLS. Run on a DB with stub + schema.sql.
\set ON_ERROR_STOP 1
\set QUIET 1
create or replace function public.t_login(e text) returns void language plpgsql as $$
begin perform set_config('request.jwt.claims', json_build_object('sub',(select id from auth.users where email=e),'role','authenticated')::text, true); end $$;
create or replace function public.t_expect_error(q text, pat text) returns void language plpgsql as $$
begin
  begin execute q;
  exception when others then
    if sqlerrm ilike '%'||pat||'%' then raise notice 'OK  expected error: %', sqlerrm; return; end if;
    raise exception 'Expected error like "%" but got: %', pat, sqlerrm;
  end;
  raise exception 'Expected error like "%" but statement succeeded: %', pat, q;
end $$;
create or replace function public.t_ok(c boolean, m text) returns void language plpgsql as $$
begin if not coalesce(c,false) then raise exception 'FAILED: %', m; end if; raise notice 'OK  %', m; end $$;
grant execute on function public.t_expect_error(text,text), public.t_ok(boolean,text), public.t_login(text) to authenticated, anon;
create or replace function public.t_uid(e text) returns uuid language sql security definer as $$ select id from auth.users where email=e $$;
grant execute on function public.t_uid(text) to authenticated, anon;

insert into auth.users (email, email_confirmed_at) values ('fa@t.fi', now()), ('fb@t.fi', now()), ('fc@t.fi', now()), ('fadm@t.fi', now());
update public.profiles set display_name = initcap(split_part(split_part((select email from auth.users u where u.id = profiles.id),'@',1),'f',2)), onboarded = true;
update public.profiles set is_admin = true where id = public.t_uid('fadm@t.fi');

-- ===== friend requests
begin; select t_login('fa@t.fi'); set local role authenticated;
select t_expect_error('insert into friend_requests(requester_id,target_id) values (auth.uid(), t_uid(''fb@t.fi''))', 'permission denied');
select t_ok(send_friend_request(t_uid('fb@t.fi')) = 'pending', 'A sends friend request to B');
select t_ok(send_friend_request(t_uid('fb@t.fi')) = 'pending', 'sending again is a no-op (still pending)');
select t_expect_error('select send_friend_request(auth.uid())', 'friend_self');
select t_ok((select count(*) from friend_requests) = 1, 'A sees own request');
commit;
begin; select t_login('fc@t.fi'); set local role authenticated;
select t_ok((select count(*) from friend_requests) = 0, 'C cannot see A-B request');
select t_ok((select count(*) from notifications) = 0, 'C has no notifications');
commit;
begin; select t_login('fb@t.fi'); set local role authenticated;
select t_ok((select count(*) from notifications where code = 'friend_request' and link_kind = 'friend') = 1, 'B notified (friend_request)');
select t_expect_error('update friend_requests set status = ''accepted''', 'permission denied');
select respond_friend_request((select id from friend_requests limit 1), true);
select t_ok((select status from friend_requests limit 1) = 'accepted', 'B accepts');
select t_ok((select count(*) from friends where user_id = auth.uid() and friend_id = t_uid('fa@t.fi')) = 1, 'friends view: B -> A');
select t_expect_error('select respond_friend_request((select id from friend_requests limit 1), true)', 'friend_request_not_found');
commit;
begin; select t_login('fa@t.fi'); set local role authenticated;
select t_ok((select count(*) from notifications where code = 'friend_accepted') = 1, 'A notified (friend_accepted)');
select t_ok((select count(*) from friends where user_id = auth.uid()) = 1, 'friends view: A has 1 friend');
select t_ok(are_friends(auth.uid(), t_uid('fb@t.fi')), 'are_friends(A,B)');
commit;

-- decline + re-send rules
begin; select t_login('fc@t.fi'); set local role authenticated;
select t_ok(send_friend_request(t_uid('fa@t.fi')) = 'pending', 'C sends to A');
commit;
begin; select t_login('fa@t.fi'); set local role authenticated;
select respond_friend_request((select id from friend_requests where requester_id = t_uid('fc@t.fi')), false);
select t_ok((select status from friend_requests where requester_id = t_uid('fc@t.fi')) = 'declined', 'A declines C');
commit;
begin; select t_login('fc@t.fi'); set local role authenticated;
select t_expect_error('select send_friend_request(t_uid(''fa@t.fi''))', 'friend_request_declined');
commit;
begin; select t_login('fa@t.fi'); set local role authenticated;
select t_ok(send_friend_request(t_uid('fc@t.fi')) = 'pending', 'A can later send own request to C (row flips)');
select remove_friend(t_uid('fc@t.fi'));
select t_ok((select count(*) from friend_requests where target_id = t_uid('fc@t.fi')) = 0, 'A cancels own pending request');
commit;
-- mutual request auto-accepts
begin; select t_login('fc@t.fi'); set local role authenticated;
select t_ok(send_friend_request(t_uid('fb@t.fi')) = 'pending', 'C -> B pending');
commit;
begin; select t_login('fb@t.fi'); set local role authenticated;
select t_ok(send_friend_request(t_uid('fc@t.fi')) = 'accepted', 'B -> C while C asked B = accepted');
commit;

-- ===== invites
begin; select t_login('fa@t.fi'); set local role authenticated;
insert into events (activity_id, title, starts_at, city, place, max_participants) values ('kahvi', 'Kahvit', now() + interval '1 day', 'Helsinki', 'Kallio', 6);
select invite_friend_to_event((select id from events where title = 'Kahvit'), t_uid('fb@t.fi'));
select invite_friend_to_event((select id from events where title = 'Kahvit'), t_uid('fb@t.fi'));
select t_ok((select count(*) from event_invites) = 1, 'invite stored once');
select t_expect_error('select invite_friend_to_event((select id from events where title = ''Kahvit''), t_uid(''fc@t.fi''))', 'not_friends');
select t_expect_error('insert into event_invites(event_id, inviter_id, invitee_id) values ((select id from events limit 1), auth.uid(), t_uid(''fc@t.fi''))', 'permission denied');
commit;
begin; select t_login('fb@t.fi'); set local role authenticated;
select t_ok((select count(*) from notifications where code = 'event_invite' and link_kind = 'event' and params->>'title' = 'Kahvit') = 1, 'B notified once (event_invite)');
commit;
begin; select t_login('fa@t.fi'); set local role authenticated;
select remove_friend(t_uid('fb@t.fi'));
select t_ok((select count(*) from friends) = 0, 'A removes B');
commit;

-- ===== unlimited participants
begin; select t_login('fadm@t.fi'); set local role authenticated;
insert into events (kind, activity_id, title, starts_at, ends_at, city, place, organizer_name, max_participants)
  values ('public', 'juoksu', 'Iso juoksu', now() + interval '2 day', now() + interval '2 day 3 hours', 'Helsinki', 'Kaisaniemi', 'Kaupunki', null);
select t_ok((select max_participants is null from events where title = 'Iso juoksu'), 'public event with max_participants NULL (no limit)');
commit;
begin; select t_login('fa@t.fi'); set local role authenticated;
-- 2026-10-01: community events may be unlimited too (NULL) and have more than 50 places; 1 or > 100000 is still rejected
insert into events (activity_id, title, starts_at, city, place, max_participants) values ('kahvi', 'Rajaton', now() + interval '1 day', 'Helsinki', 'Kallio', null);
select t_ok((select max_participants is null and kind = 'community' from events where title = 'Rajaton'), 'community event with max_participants NULL (no limit)');
insert into events (activity_id, title, starts_at, city, place, max_participants) values ('kahvi', 'Iso piknik', now() + interval '1 day', 'Helsinki', 'Kallio', 300);
select t_ok((select max_participants = 300 from events where title = 'Iso piknik'), 'community event with 300 places (old cap was 50)');
select t_expect_error('insert into events (activity_id, title, starts_at, city, place, max_participants) values (''kahvi'', ''Yksin'', now() + interval ''1 day'', ''Helsinki'', ''Kallio'', 1)', 'events_max_participants_check');
select t_expect_error('insert into events (activity_id, title, starts_at, city, place, max_participants) values (''kahvi'', ''Liikaa'', now() + interval ''1 day'', ''Helsinki'', ''Kallio'', 100001)', 'events_max_participants_check');
update events set max_participants = 8 where title = 'Rajaton';
select t_ok((select max_participants = 8 from events where title = 'Rajaton'), 'host can switch an unlimited community event back to a limit');
update events set max_participants = null where title = 'Rajaton';
select t_ok((select max_participants is null from events where title = 'Rajaton'), 'host can switch a community event to no limit');
insert into event_participants (event_id, user_id) values ((select id from events where title = 'Iso juoksu'), auth.uid());
commit;
begin; select t_login('fb@t.fi'); set local role authenticated;
insert into event_participants (event_id, user_id) values ((select id from events where title = 'Iso juoksu'), auth.uid());
insert into event_participants (event_id, user_id) values ((select id from events where title = 'Rajaton'), auth.uid());
select t_ok((select count(*) = 2 from event_participants where event_id = (select id from events where title = 'Rajaton')), 'joining an unlimited community event works');
commit;
begin; select t_login('fc@t.fi'); set local role authenticated;
insert into event_participants (event_id, user_id) values ((select id from events where title = 'Iso juoksu'), auth.uid());
select t_ok((select count(*) from event_participants where event_id = (select id from events where title = 'Iso juoksu')) >= 1, 'joining an unlimited event works');
commit;

-- ===== teams (no RLS recursion, coach/member rules)
begin; select t_login('fa@t.fi'); set local role authenticated;
insert into teams (name, sport) values ('FC Kallio', 'Jalkapallo');
insert into team_members (team_id, user_id, role) values ((select id from teams where name = 'FC Kallio'), auth.uid(), 'admin');
select t_ok((select count(*) from teams where name = 'FC Kallio') = 1, 'teams select works (no recursion)');
commit;
begin; select t_login('fb@t.fi'); set local role authenticated;
select t_expect_error('insert into team_members (team_id, user_id, role) values ((select id from teams where name = ''FC Kallio''), auth.uid(), ''admin'')', 'row-level security');
insert into team_members (team_id, user_id, role) values ((select id from teams where name = 'FC Kallio'), auth.uid(), 'member');
select t_expect_error('insert into team_events (team_id, title, event_date) values ((select id from teams where name = ''FC Kallio''), ''Treeni'', current_date + 1)', 'row-level security');
commit;
begin; select t_login('fa@t.fi'); set local role authenticated;
insert into team_events (team_id, title, event_date, event_time) values ((select id from teams where name = 'FC Kallio'), 'Treenit', current_date + 1, '18:00');
select t_ok((select created_by = auth.uid() from team_events where title = 'Treenit'), 'team event created by coach/admin, created_by defaults to caller');
commit;
begin; select t_login('fb@t.fi'); set local role authenticated;
insert into team_event_rsvps (event_id, user_id, status) values ((select id from team_events where title = 'Treenit'), auth.uid(), 'going');
select t_ok((select count(*) from team_members m join teams t on t.id = m.team_id where t.name = 'FC Kallio') = 2 and (select count(*) from team_event_rsvps r join team_events e on e.id = r.event_id where e.title = 'Treenit') = 1, 'member sees members + RSVPs');
commit;
begin; select t_login('fc@t.fi'); set local role authenticated;
select t_ok((select count(*) from team_events) = 0 and (select count(*) from team_members) = 0, 'non-member sees no team events/members');
commit;

-- ===== anon
begin; set local role anon;
select t_expect_error('select * from friend_requests', 'permission denied');
select t_expect_error('select * from teams', 'permission denied');
select t_expect_error('select send_friend_request(gen_random_uuid())', 'permission denied');
commit;
select 'ALL MERGE SQL TESTS PASSED' as result;
