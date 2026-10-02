-- Run on a scratch Postgres (NOT the live DB), after 00-supabase-stub.sql + 01-storage-stub.sql + schema.sql:
--   psql -d mtest -f supabase/tests/orgs.sql
-- 2026-10-02 (osio 9): team management (approval creates team, roles, invites, roster, RSVPs, series, docs, team chat)
-- and business management (organisers via link, read-only when expired, recurring business events).
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
create or replace function public.t_uid(e text) returns uuid language sql security definer as $$ select id from auth.users where email=e $$;
create or replace function public.t_n(c text, u uuid) returns int language sql security definer as $$ select count(*)::int from public.notifications where code = c and user_id = u $$;
grant execute on function public.t_expect_error(text,text), public.t_ok(boolean,text), public.t_login(text), public.t_uid(text),
  public.t_n(text,uuid) to authenticated, anon;
create temp table ids (k text primary key, v uuid);
grant all on ids to authenticated, anon;

insert into auth.users (email, email_confirmed_at) values ('oa@t.fi', now()), ('ob@t.fi', now()), ('oc@t.fi', now()), ('od@t.fi', now()),
  ('oe@t.fi', now()), ('oban@t.fi', now()), ('oadm@t.fi', now()), ('bo@t.fi', now()), ('be@t.fi', now()), ('bx@t.fi', now());
update public.profiles set display_name = initcap(split_part((select email from auth.users u where u.id = profiles.id),'@',1)), onboarded = true
  where id in (select id from auth.users where email like '%@t.fi' and email ~ '^(o|b)');
update public.profiles set is_admin = true where id = public.t_uid('oadm@t.fi');
-- friends: oa <-> ob, oa <-> oban
insert into public.friend_requests (requester_id, target_id, status, responded_at) values
  (public.t_uid('oa@t.fi'), public.t_uid('ob@t.fi'), 'accepted', now()), (public.t_uid('oa@t.fi'), public.t_uid('oban@t.fi'), 'accepted', now());

-- ===== approval creates the team
begin; select t_login('oa@t.fi'); set local role authenticated;
select t_expect_error($q$insert into teams (name, sport) values ('Oma', 'Futis')$q$, 'permission denied');
insert into ids values ('req', request_team_account('{"team_name":"Kallion Kiekko","sport":"Jääkiekko","city":"Helsinki","contact_name":"Oa","contact_email":"oa@t.fi"}'));
select t_ok((select count(*) from teams) = 0, 'pending request has no team yet');
commit;
begin; select t_login('oe@t.fi'); set local role authenticated;
select t_expect_error($q$select admin_review_team_request((select v from ids where k='req'), 'approved')$q$, 'admin_only');
commit;
begin; select t_login('oadm@t.fi'); set local role authenticated;
select admin_review_team_request((select v from ids where k='req'), 'approved');
insert into ids select 'team', id from teams where team_request_id = (select v from ids where k='req');
select t_ok((select count(*) from ids where k='team') = 1, 'admin approval created exactly one team');
commit;
update public.profiles set banned = true where id = public.t_uid('oban@t.fi');
begin; select t_login('oa@t.fi'); set local role authenticated;
select t_ok((select owner_id = auth.uid() and name = 'Kallion Kiekko' and city = 'Helsinki' and sport = 'Jääkiekko' from teams), 'requester owns the team (name, city, sport copied)');
select t_ok(team_role((select v from ids where k='team')) = 'manager' and is_team_admin((select v from ids where k='team')), 'requester is team manager');
select t_ok(t_n('team_request_approved', auth.uid()) = 1 and (select link_id from notifications where code = 'team_request_approved') = (select v from ids where k='team'), 'approval notification links to the team');
select t_ok((select count(*) from conversations where kind = 'team' and team_id = (select v from ids where k='team')) = 1, 'team chat created');
select t_ok((select count(*) from messages m join conversations c on c.id = m.conversation_id where c.team_id = (select v from ids where k='team') and m.code = 'team_created') = 1, 'team chat welcome message');
select update_team((select v from ids where k='team'), '{"description":"Harrastejoukkue Kalliosta","activity_id":"jaakiekko"}');
select t_ok((select description from teams) = 'Harrastejoukkue Kalliosta', 'manager updates team info');
select t_expect_error($q$update teams set name = 'X'$q$, 'permission denied');
commit;
begin; select t_login('oadm@t.fi'); set local role authenticated;
select t_ok((select count(*) from teams) = 1 and (select count(*) from team_members) = 1, 'admin sees the team');
commit;

-- ===== invites: friend invite, links, roster member, parent link
begin; select t_login('oa@t.fi'); set local role authenticated;
select t_expect_error($q$select invite_to_team((select v from ids where k='team'), t_uid('oe@t.fi'), 'member')$q$, 'not_friends');
select invite_to_team((select v from ids where k='team'), t_uid('ob@t.fi'), 'member');
insert into ids values ('coachlink', create_team_invite_link((select v from ids where k='team'), 'coach', null));
insert into ids values ('kid', add_team_roster_member((select v from ids where k='team'), '  Pikku   Ville ', 'Maalivahti'));
select t_ok((select display_name from team_members where id = (select v from ids where k='kid')) = 'Pikku Ville', 'roster member without account (name trimmed)');
insert into ids values ('parentlink', create_team_invite_link((select v from ids where k='team'), 'parent', (select v from ids where k='kid')));
select t_expect_error($q$select create_team_invite_link((select v from ids where k='team'), 'member', (select v from ids where k='kid'))$q$, 'team_member_not_found');
select t_expect_error($q$insert into team_members (team_id, user_id, role) values ((select v from ids where k='team'), t_uid('oe@t.fi'), 'member')$q$, 'permission denied');
commit;
begin; select t_login('ob@t.fi'); set local role authenticated;
select t_ok(t_n('team_invite', auth.uid()) = 1, 'friend notified of team invite');
select t_ok((select count(*) from teams) = 1 and (select count(*) from team_members) = 0, 'invitee sees the team but not the roster');
select respond_team_invite((select v from ids where k='team'), true);
select t_ok(team_role((select v from ids where k='team')) = 'member', 'friend joined as member');
select t_ok((select count(*) from team_members) = 3, 'member sees roster');
select t_expect_error($q$select create_team_invite_link((select v from ids where k='team'), 'member', null)$q$, 'team_staff_only');
commit;
-- the invite-link table is staff-only, but previews work for anyone logged in with a valid token
begin; select t_login('od@t.fi'); set local role authenticated;
select t_ok((team_link_preview((select v from ids where k='coachlink')))->>'role' = 'coach', 'link preview (coach)');
select t_ok(join_team_by_link((select v from ids where k='coachlink')) = (select v from ids where k='team'), 'coach joins by link');
select t_ok(team_role((select v from ids where k='team')) = 'coach', 'role from link = coach');
select t_ok((select count(*) from team_invite_links) >= 2, 'coach sees invite links');
commit;
begin; select t_login('oc@t.fi'); set local role authenticated;
select t_ok((team_link_preview((select v from ids where k='parentlink')))->>'member_name' = 'Pikku Ville', 'parent link preview names the child');
select join_team_by_link((select v from ids where k='parentlink'));
select t_ok((select role = 'parent' and linked_member = (select v from ids where k='kid') from team_members where user_id = auth.uid()), 'parent linked to the roster child');
select t_ok((select count(*) from team_invite_links) = 0, 'parent cannot list invite links');
commit;
begin; select t_login('oa@t.fi'); set local role authenticated;
select t_ok(t_n('team_member_joined', auth.uid()) = 3, 'manager notified of 3 joins');
select t_expect_error($q$select set_team_member((select id from team_members where user_id = auth.uid()), '{"role":"coach"}')$q$, 'team_owner_stays_manager');
select t_expect_error($q$select remove_team_member((select id from team_members where user_id = auth.uid()))$q$, 'team_owner_stays_manager');
select set_team_member((select id from team_members where user_id = t_uid('ob@t.fi')), '{"title":"Kapteeni-ehdokas"}');
commit;
begin; select t_login('od@t.fi'); set local role authenticated;
select t_expect_error($q$select set_team_member((select id from team_members where user_id = t_uid('ob@t.fi')), '{"role":"coach"}')$q$, 'team_manager_only');
select set_team_member((select id from team_members where user_id = t_uid('ob@t.fi')), '{"title":"Hyökkääjä"}');
select t_ok((select title from team_members where user_id = t_uid('ob@t.fi')) = 'Hyökkääjä', 'coach sets a title');
select t_expect_error($q$select remove_team_member((select id from team_members where user_id = t_uid('ob@t.fi')))$q$, 'team_manager_only');
select t_expect_error($q$select create_team_invite_link((select v from ids where k='team'), 'coach', null)$q$, 'team_manager_only');
insert into team_roles (team_id, name) values ((select v from ids where k='team'), 'Huoltaja-vastaava');
select t_ok((select count(*) from team_roles) = 1, 'coach adds a custom title');
commit;
begin; select t_login('ob@t.fi'); set local role authenticated;
select t_expect_error($q$insert into team_roles (team_id, name) values ((select v from ids where k='team'), 'X')$q$, 'row-level security');
commit;

-- ===== places, events, captain, RSVPs (self, parent for child, staff)
begin; select t_login('oa@t.fi'); set local role authenticated;
insert into team_places (team_id, name, address, lat, lng) values ((select v from ids where k='team'), ' Kallion jäähalli ', 'Helsinginkatu 25', 60.1872, 24.9535);
select t_ok((select name from team_places) = 'Kallion jäähalli', 'saved place (trimmed, with pin)');
insert into team_events (team_id, kind, title, event_date, event_time, place_id, opponent, captain_member)
  values ((select v from ids where k='team'), 'game', 'Kotipeli', current_date + 3, '18:30', (select id from team_places), 'Vallilan Veto',
          (select id from team_members where user_id = t_uid('ob@t.fi')));
insert into ids select 'game', id from team_events where title = 'Kotipeli';
select t_expect_error($q$insert into team_events (team_id, title, event_date, captain_member) values ((select v from ids where k='team'), 'Huono', current_date + 1, (select id from team_members where user_id = t_uid('oc@t.fi')))$q$, 'team_member_not_found');
commit;
begin; select t_login('ob@t.fi'); set local role authenticated;
select t_expect_error($q$insert into team_events (team_id, title, event_date) values ((select v from ids where k='team'), 'Oma', current_date + 1)$q$, 'row-level security');
select team_rsvp((select v from ids where k='game'), (select id from team_members where user_id = auth.uid()), 'going');
select t_expect_error($q$select team_rsvp((select v from ids where k='game'), (select v from ids where k='kid'), 'going')$q$, 'team_rsvp_not_allowed');
select t_expect_error($q$insert into team_event_rsvps (event_id, member_id, status) values ((select v from ids where k='game'), (select v from ids where k='kid'), 'going')$q$, 'permission denied');
select t_ok((select captain_member from team_events) = (select id from team_members where user_id = auth.uid()), 'member sees captain');
commit;
begin; select t_login('oc@t.fi'); set local role authenticated;
select team_rsvp((select v from ids where k='game'), (select v from ids where k='kid'), 'maybe');
select team_rsvp((select v from ids where k='game'), (select v from ids where k='kid'), 'going');
select t_ok((select status = 'going' and responded_by = auth.uid() from team_event_rsvps where member_id = (select v from ids where k='kid')), 'parent answers for the child (upsert)');
select t_expect_error($q$select team_rsvp((select v from ids where k='game'), (select id from team_members where user_id = auth.uid()), 'going')$q$, 'team_rsvp_not_allowed');
commit;
begin; select t_login('od@t.fi'); set local role authenticated;
select team_rsvp((select v from ids where k='game'), (select id from team_members where user_id = t_uid('oa@t.fi')), 'no');
select t_ok((select count(*) from team_event_rsvps) = 3, 'staff answers for others; 3 RSVPs');
update team_events set cancelled = true where id = (select v from ids where k='game');
commit;
begin; select t_login('ob@t.fi'); set local role authenticated;
select t_ok(t_n('team_event_cancelled', auth.uid()) = 1, 'going member notified of cancellation');
select t_expect_error($q$select team_rsvp((select v from ids where k='game'), (select id from team_members where user_id = auth.uid()), 'no')$q$, 'team_event_closed');
commit;
begin; select t_login('oc@t.fi'); set local role authenticated;
select t_ok(t_n('team_event_cancelled', auth.uid()) = 1, 'parent of going child notified of cancellation');
commit;
begin; select t_login('oa@t.fi'); set local role authenticated;
select t_ok(t_n('team_event_cancelled', auth.uid()) = 0, 'member who said no is not notified');
commit;

-- ===== recurring trainings
begin; select t_login('od@t.fi'); set local role authenticated;
select t_expect_error($q$select save_team_series(jsonb_build_object('team_id', (select v from ids where k='team'), 'title', 'Treenit', 'weekdays', '[8]'::jsonb, 'start_time', '18:00', 'starts_on', current_date, 'ends_on', current_date + 30))$q$, 'team_series_invalid');
select t_expect_error($q$select save_team_series(jsonb_build_object('team_id', (select v from ids where k='team'), 'title', 'Treenit', 'weekdays', '[1]'::jsonb, 'start_time', '18:00', 'starts_on', current_date, 'ends_on', current_date + 500))$q$, 'team_series_invalid');
insert into ids values ('ser', save_team_series(jsonb_build_object('team_id', (select v from ids where k='team'), 'kind', 'training', 'title', 'Jäätreenit',
  'weekdays', '[2,4]'::jsonb, 'start_time', '17:30', 'duration_min', 75, 'starts_on', current_date + 1, 'ends_on', current_date + 28,
  'place_id', (select id from team_places))));
select t_ok((select count(*) from team_events where series_id = (select v from ids where k='ser')) = (select count(*) from series_dates('{2,4}', current_date + 1, current_date + 28)), 'one occurrence per Tue/Thu');
select t_ok((select bool_and(extract(isodow from event_date) in (2,4) and event_time = '17:30' and place_name = 'Kallion jäähalli') from team_events where series_id = (select v from ids where k='ser')), 'occurrences on chosen weekdays, time + place copied');
insert into ids select 'occ1', id from team_events where series_id = (select v from ids where k='ser') order by event_date limit 1;
insert into ids select 'occ2', id from team_events where series_id = (select v from ids where k='ser') order by event_date offset 1 limit 1;
update team_events set event_time = '19:00', description = 'Tänään myöhemmin' where id = (select v from ids where k='occ1');
update team_events set cancelled = true where id = (select v from ids where k='occ2');
select t_ok((select modified from team_events where id = (select v from ids where k='occ1')), 'edited occurrence marked modified');
commit;
begin; select t_login('ob@t.fi'); set local role authenticated;
select team_rsvp(e.id, (select id from team_members where user_id = auth.uid()), 'going') from team_events e
  where e.series_id = (select v from ids where k='ser') and not e.cancelled;
commit;
begin; select t_login('oa@t.fi'); set local role authenticated;
select save_team_series(jsonb_build_object('id', (select v from ids where k='ser'), 'kind', 'training', 'title', 'Jäätreenit',
  'weekdays', '[2,4]'::jsonb, 'start_time', '18:00', 'duration_min', 90, 'starts_on', current_date + 1, 'ends_on', current_date + 28, 'place_id', (select id from team_places)));
select t_ok((select bool_and(event_time = '18:00') from team_events where series_id = (select v from ids where k='ser') and not modified and not cancelled), 'series edit updates unmodified occurrences');
select t_ok((select event_time = '19:00' from team_events where id = (select v from ids where k='occ1')), 'modified occurrence kept');
select t_ok((select cancelled from team_events where id = (select v from ids where k='occ2')), 'cancelled occurrence stays cancelled');
select t_ok((select count(*) from team_event_rsvps r join team_events e on e.id = r.event_id where e.series_id = (select v from ids where k='ser'))
            = (select count(*) from team_events where series_id = (select v from ids where k='ser') and not cancelled), 'RSVPs kept through series edit');
select save_team_series(jsonb_build_object('id', (select v from ids where k='ser'), 'kind', 'training', 'title', 'Jäätreenit',
  'weekdays', '[4]'::jsonb, 'start_time', '18:00', 'duration_min', 90, 'starts_on', current_date + 1, 'ends_on', current_date + 28, 'place_id', (select id from team_places)));
select t_ok((select bool_and(extract(isodow from event_date) = 4 or modified or cancelled) from team_events where series_id = (select v from ids where k='ser')), 'weekday change removes other days (except edited/cancelled)');
select delete_team_series((select v from ids where k='ser'));
select t_ok((select count(*) from team_events where series_id is not null) = 0 and (select count(*) from team_event_series) = 0, 'series delete removes future occurrences');
commit;
begin; select t_login('ob@t.fi'); set local role authenticated;
select t_expect_error($q$select save_team_series(jsonb_build_object('team_id', (select v from ids where k='team'), 'title', 'X', 'weekdays', '[1]'::jsonb, 'start_time', '18:00', 'starts_on', current_date, 'ends_on', current_date + 7))$q$, 'team_staff_only');
commit;

-- ===== docs (instructions / programme / staff-only notes)
begin; select t_login('od@t.fi'); set local role authenticated;
insert into team_docs (team_id, kind, title, body) values ((select v from ids where k='team'), 'instructions', 'Varusteet', 'Kypärä ja maalivahdin varusteet mukaan.');
insert into team_docs (team_id, kind, title, body, staff_only) values ((select v from ids where k='team'), 'notes', 'Kokoonpano', 'Ketjut lauantaille', true);
select t_ok((select count(*) from team_docs) = 2 and (select bool_and(updated_by = auth.uid()) from team_docs), 'coach writes docs');
commit;
begin; select t_login('ob@t.fi'); set local role authenticated;
select t_ok((select count(*) from team_docs) = 1, 'member sees only non-staff docs');
select t_expect_error($q$insert into team_docs (team_id, title) values ((select v from ids where k='team'), 'X')$q$, 'row-level security');
commit;

-- ===== team chat: members only, images, reports
create or replace function pg_temp.tcid() returns uuid language sql as $$ select id from public.conversations where team_id = (select v from ids where k='team') $$;
begin; select t_login('oc@t.fi'); set local role authenticated;
insert into messages (conversation_id, body) values (pg_temp.tcid(), 'Ville pääsee mukaan lauantaina');
select t_ok(can_post_image(pg_temp.tcid()), 'team member (parent) may post images');
insert into storage.objects (bucket_id, name) values ('chat-images', pg_temp.tcid() || '/img00001.webp');
insert into messages (conversation_id, body, image_path, image_w, image_h) values (pg_temp.tcid(), '', pg_temp.tcid() || '/img00001.webp', 800, 600);
commit;
begin; select t_login('ob@t.fi'); set local role authenticated;
select t_ok((select count(*) from storage.objects where bucket_id = 'chat-images') = 1, 'member reads team chat image');
insert into reports (target_type, target_id, reason) values ('message', (select id from messages where image_path is not null), 'inappropriate');
select t_ok((select count(*) from reports) = 1, 'member reports a team chat message');
commit;
begin; select t_login('oe@t.fi'); set local role authenticated;
select t_ok((select count(*) from messages) = 0 and (select count(*) from conversations) = 0 and (select count(*) from storage.objects) = 0, 'outsider sees no team chat');
select t_expect_error($q$insert into messages (conversation_id, body) values ((select id from conversations limit 1), 'hei')$q$, 'row-level security');
select t_expect_error($q$select join_team_by_link(gen_random_uuid())$q$, 'invite_link_invalid');
select t_ok((select count(*) from teams) = 0 and (select count(*) from team_docs) = 0 and (select count(*) from team_places) = 0, 'outsider sees no team data');
commit;
begin; select t_login('oban@t.fi'); set local role authenticated;
select t_expect_error($q$select respond_team_invite((select v from ids where k='team'), true)$q$, 'team_invite_not_found');
commit;

-- ===== removal + leaving
begin; select t_login('oa@t.fi'); set local role authenticated;
select remove_team_member((select id from team_members where user_id = t_uid('ob@t.fi')));
commit;
begin; select t_login('ob@t.fi'); set local role authenticated;
select t_ok(t_n('team_removed', auth.uid()) = 1, 'removed member notified');
select t_ok((select count(*) from teams) = 0 and (select count(*) from messages) = 0 and (select count(*) from team_events) = 0, 'removed member sees nothing');
commit;
begin; select t_login('oc@t.fi'); set local role authenticated;
select remove_team_member((select id from team_members where user_id = auth.uid()));
select t_ok((select count(*) from teams) = 0, 'parent left the team');
commit;
begin; select t_login('od@t.fi'); set local role authenticated;
select remove_team_member((select v from ids where k='kid'));
select t_ok((select count(*) from team_members) = 2, 'coach removes a roster member (RSVPs cascade)');
commit;
begin; set local role anon;
select t_expect_error('select * from teams', 'permission denied');
select t_expect_error('select * from team_docs', 'permission denied');
select t_expect_error('select * from team_invite_links', 'permission denied');
select t_expect_error('select * from business_event_series', 'permission denied');
select t_expect_error($q$select team_link_preview(gen_random_uuid())$q$, 'permission denied');
commit;

-- ===== business: owner, organisers (editors), expiry = read-only, recurring events
begin;
insert into public.businesses (name, business_code, country, status, consent_terms, created_by, subscription_active_until)
  values ('Kallion Kuntosali Oy', 'SE5566778899', 'SE', 'approved', true, public.t_uid('bo@t.fi'), public.today_fi() + 30);
insert into ids select 'biz', id from public.businesses where name = 'Kallion Kuntosali Oy';
insert into public.business_members (business_id, user_id, role) values ((select v from ids where k='biz'), public.t_uid('bo@t.fi'), 'owner');
insert into public.business_private (business_id, contact_email, phone, billing_address) values ((select v from ids where k='biz'), 'bo@t.fi', '+358401234567', 'Helsinginkatu 1, Helsinki');
commit;
begin; select t_login('be@t.fi'); set local role authenticated;
select t_expect_error($q$select create_business_invite_link((select v from ids where k='biz'))$q$, 'business_owner_only');
commit;
begin; select t_login('bo@t.fi'); set local role authenticated;
insert into ids values ('blink', create_business_invite_link((select v from ids where k='biz')));
commit;
begin; select t_login('be@t.fi'); set local role authenticated;
select t_ok((business_link_preview((select v from ids where k='blink')))->>'name' = 'Kallion Kuntosali Oy', 'organiser link preview');
select join_business_by_link((select v from ids where k='blink'));
select t_ok((select role from business_members where user_id = auth.uid()) = 'editor', 'joined as organiser (editor)');
select t_ok((select count(*) from business_private) = 0, 'organiser cannot read billing details');
update businesses set description = 'x' where id = (select v from ids where k='biz');
select t_ok((select description from businesses where id = (select v from ids where k='biz')) = '', 'organiser cannot edit the business profile');
insert into events (kind, business_id, host_id, activity_id, title, starts_at, city, place, price_info, extra_info)
  values ('business', (select v from ids where k='biz'), null, 'kuntosali', 'Avoin kuntopiiri', now() + interval '2 days', 'Helsinki', 'Kallion sali', '10 € / kerta', 'Ota oma juomapullo.');
select t_ok((select extra_info from events where title = 'Avoin kuntopiiri') = 'Ota oma juomapullo.', 'organiser creates a business event with price + extra info');
select t_expect_error($q$select save_business_series(jsonb_build_object('business_id', (select v from ids where k='biz'), 'activity_id', 'kuntosali', 'title', 'Aamujooga', 'city', 'Helsinki', 'place', 'Kallion sali', 'weekdays', '[1,3]'::jsonb, 'start_time', '07:00', 'starts_on', current_date + 1, 'ends_on', current_date + 30, 'tz', 'Mars/Olympus'))$q$, 'business_series_invalid');
insert into ids values ('bser', save_business_series(jsonb_build_object('business_id', (select v from ids where k='biz'), 'activity_id', 'kuntosali',
  'title', 'Aamujooga', 'city', 'Helsinki', 'place', 'Kallion sali', 'lat', 60.18, 'lng', 24.95, 'weekdays', '[1,3]'::jsonb, 'start_time', '07:00',
  'duration_min', 60, 'starts_on', current_date + 1, 'ends_on', current_date + 30, 'price_info', '12 €', 'extra_info', 'Matot löytyvät salilta.', 'max_participants', 15)));
select t_ok((select count(*) from events where series_id = (select v from ids where k='bser')) = (select count(*) from series_dates('{1,3}', current_date + 1, current_date + 30)), 'business series: one event per Mon/Wed');
select t_ok((select bool_and(to_char(starts_at at time zone 'Europe/Helsinki', 'HH24:MI') = '07:00' and ends_at = starts_at + interval '60 minutes' and price_info = '12 €' and kind = 'business') from events where series_id = (select v from ids where k='bser')), 'local 07:00 start, 60 min, price copied');
insert into ids select 'bocc', id from events where series_id = (select v from ids where k='bser') order by starts_at limit 1;
update events set title = 'Aamujooga – erikoiskerta' where id = (select v from ids where k='bocc');
select t_ok((select series_modified from events where id = (select v from ids where k='bocc')), 'edited business occurrence marked');
select save_business_series(jsonb_build_object('id', (select v from ids where k='bser'), 'activity_id', 'kuntosali', 'title', 'Aamujooga',
  'city', 'Helsinki', 'place', 'Kallion sali', 'weekdays', '[1,3]'::jsonb, 'start_time', '07:30', 'duration_min', 60, 'starts_on', current_date + 1, 'ends_on', current_date + 30, 'price_info', '14 €'));
select t_ok((select bool_and(price_info = '14 €' and to_char(starts_at at time zone 'Europe/Helsinki', 'HH24:MI') = '07:30') from events where series_id = (select v from ids where k='bser') and not series_modified), 'business series edit updates unmodified events');
select t_ok((select title from events where id = (select v from ids where k='bocc')) = 'Aamujooga – erikoiskerta', 'edited business occurrence kept');
update events set series_id = null where id = (select v from ids where k='bocc');
select t_ok((select series_id from events where id = (select v from ids where k='bocc')) is not null, 'client cannot detach series_id');
commit;
begin; select t_login('bx@t.fi'); set local role authenticated;
select t_expect_error($q$select save_business_series(jsonb_build_object('id', (select v from ids where k='bser'), 'title', 'X'))$q$, 'business_subscription_required');
select t_ok((select count(*) from business_event_series) = 0 and (select count(*) from business_invite_links) = 0, 'outsider sees no series/links');
commit;
begin; select t_login('bo@t.fi'); set local role authenticated;
select t_ok((select count(*) from business_event_series) = 1 and (select count(*) from business_private) = 1, 'owner sees series + billing');
commit;
-- subscription expires -> read-only
update public.businesses set subscription_active_until = public.today_fi() - 1 where id = (select v from ids where k='biz');
begin; select t_login('be@t.fi'); set local role authenticated;
select t_expect_error($q$update events set title = 'Uusi nimi' where title = 'Avoin kuntopiiri'$q$, 'business_subscription_required');
delete from events where title = 'Avoin kuntopiiri';
select t_ok((select count(*) from events where title = 'Avoin kuntopiiri') = 1, 'expired: organiser cannot delete');
select t_expect_error($q$select save_business_series(jsonb_build_object('id', (select v from ids where k='bser'), 'title', 'X'))$q$, 'business_subscription_required');
select t_expect_error($q$select delete_business_series((select v from ids where k='bser'))$q$, 'business_subscription_required');
commit;
begin; select t_login('bo@t.fi'); set local role authenticated;
select t_expect_error($q$select create_business_invite_link((select v from ids where k='biz'))$q$, 'business_subscription_required');
select remove_business_member((select v from ids where k='biz'), t_uid('be@t.fi'));
select t_expect_error($q$select remove_business_member((select v from ids where k='biz'), auth.uid())$q$, 'business_owner_stays');
commit;
begin; select t_login('be@t.fi'); set local role authenticated;
select t_ok(t_n('business_removed', auth.uid()) = 1 and (select count(*) from business_members) = 0, 'removed organiser notified, no longer a member');
commit;
update public.businesses set subscription_active_until = public.today_fi() + 30 where id = (select v from ids where k='biz');
begin; select t_login('bo@t.fi'); set local role authenticated;
select delete_business_series((select v from ids where k='bser'));
select t_ok((select count(*) from events where series_id is not null) = 0 and (select count(*) from business_event_series) = 0, 'business series delete removes future events');
select t_ok((select count(*) from guest_events where extra_info = 'Ota oma juomapullo.') = 1, 'guest_events exposes extra_info');
commit;
begin; set local role anon;
select t_ok((select count(*) from guest_events where extra_info = 'Ota oma juomapullo.') = 1, 'anon guest feed shows extra_info');
commit;
select 'ORGS SQL TESTS PASSED' as result;
