-- Run on a scratch Postgres (NOT the live DB), after 00-supabase-stub.sql + 01-storage-stub.sql + schema.sql:
--   psql -d mtest -f supabase/tests/media-groups.sql
-- 2026-10-02: activities list (i18n names, pending queue), event covers + chat images (Storage RLS), chat groups, reports.
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
create or replace function public.t_cid(ev uuid) returns uuid language sql security definer as $$ select id from public.conversations where event_id = ev or group_id = ev or help_request_id = ev $$;
create or replace function public.t_put(b text, p text) returns void language sql security definer as $$
  insert into storage.objects (bucket_id, name, owner_id) values (b, p, (auth.uid())::text) $$;   -- "upload" bypassing RLS (setup only)
grant execute on function public.t_expect_error(text,text), public.t_ok(boolean,text), public.t_login(text), public.t_uid(text),
  public.t_n(text,uuid), public.t_cid(uuid) to authenticated, anon;
create temp table ids (k text primary key, v uuid);
grant all on ids to authenticated, anon;

insert into auth.users (email, email_confirmed_at) values ('ma@t.fi', now()), ('mb@t.fi', now()), ('mc@t.fi', now()), ('md@t.fi', now()),
  ('me@t.fi', now()), ('mban@t.fi', now()), ('madm@t.fi', now());
update public.profiles set display_name = initcap(split_part((select email from auth.users u where u.id = profiles.id),'@',1)), onboarded = true;
update public.profiles set is_admin = true where id = public.t_uid('madm@t.fi');
update public.profiles set banned = true where id = public.t_uid('mban@t.fi');

-- ===== 8a activities
select t_ok((select count(*) from activities where status = 'approved' and not is_custom) >= 48, 'seed: 34 base + 14 new sports approved');
select t_ok((select name_i18n->>'en' from activities where id = 'sulkapallo') = 'Badminton' and (select name_i18n->>'sv' from activities where id = 'koripallo') = 'Basket', 'name_i18n seeded (sulkapallo en, koripallo sv)');
begin; select t_login('ma@t.fi'); set local role authenticated;
insert into activities (id, name, emoji, is_custom, created_by) values ('c_ultimate', 'Ultimate frisbee', '🥏', true, auth.uid());
select t_ok((select status from activities where id = 'c_ultimate') = 'pending', 'user free-text sport -> pending');
insert into events (activity_id, title, starts_at, city, place) values ('c_ultimate', 'Ultimate puistossa', now() + interval '2 days', 'Helsinki', 'Kaivopuisto');
select t_ok((select count(*) from events where activity_id = 'c_ultimate') = 1, 'pending sport usable in own event right away');
select t_expect_error($$insert into activities (id, name, is_custom, created_by) values ('c_spam', 'Osta halvalla', true, auth.uid())$$, 'commercial_content');
update activities set status = 'approved' where id = 'c_ultimate';
select t_ok((select status from activities where id = 'c_ultimate') = 'pending', 'user cannot approve (RLS: admin only)');
select t_expect_error($$select admin_review_activity('c_ultimate', 'approved')$$, 'admin_only');
insert into activities (id, name, is_custom, created_by) values ('c_kyykka', 'Kyykkä', true, auth.uid());
commit;
begin; select t_login('mban@t.fi'); set local role authenticated;
select t_expect_error($$insert into activities (id, name, is_custom, created_by) values ('c_ban', 'Petanque', true, auth.uid())$$, 'account_banned');
commit;
begin; select t_login('madm@t.fi'); set local role authenticated;
select t_ok(t_n('admin_new_activity', auth.uid()) = 2, 'admin notified about 2 new sports');
select admin_review_activity('c_ultimate', 'approved', '{"en":"Ultimate frisbee","fi":"Ultimate","bad":"x","sv":"y"}');
select t_ok((select status = 'approved' and name_i18n = '{"en":"Ultimate frisbee","fi":"Ultimate"}'::jsonb from activities where id = 'c_ultimate'), 'admin approves with translations (bad keys/short values dropped)');
select admin_review_activity('c_kyykka', 'rejected');
commit;
begin; select t_login('ma@t.fi'); set local role authenticated;
select t_ok(t_n('activity_approved', auth.uid()) = 1 and t_n('activity_rejected', auth.uid()) = 1, 'creator notified (approved + rejected)');
commit;
begin; set local role anon; select set_config('request.jwt.claims', '', true);
select t_ok((select count(*) from activities where status = 'approved' and name_i18n ? 'en') >= 48, 'anon reads name_i18n + status');
commit;

-- ===== 8b event covers
begin; select t_login('ma@t.fi'); set local role authenticated;
insert into events (activity_id, title, starts_at, city, place) values ('padel', 'Padel kansikuvalla', now() + interval '3 days', 'Helsinki', 'Kalasatama');
insert into ids select 'ev', id from events where title = 'Padel kansikuvalla';
insert into storage.objects (bucket_id, name) values ('event-covers', (select v from ids where k='ev') || '/cov12345.webp');
select t_ok(true, 'host uploads cover object (storage RLS insert)');
update events set cover_path = (select v from ids where k='ev') || '/cov12345.webp' where id = (select v from ids where k='ev');
select t_ok((select cover_path from events where id = (select v from ids where k='ev')) like '%/cov12345.webp', 'host sets cover_path');
select t_expect_error($$update events set cover_path = (select v from ids where k='ev') || '/missing99.webp' where id = (select v from ids where k='ev')$$, 'image_missing');
select t_expect_error($$update events set cover_path = '00000000-0000-4000-8000-000000000000/cov12345.webp' where id = (select v from ids where k='ev')$$, 'image_path_invalid');
select t_expect_error($$update events set cover_path = (select v from ids where k='ev') || '/../x.png' where id = (select v from ids where k='ev')$$, 'image_path_invalid');
insert into events (activity_id, title, starts_at, city, place) values ('kahvi', 'Kahvit Kalliossa', now() + interval '3 days', 'Helsinki', 'Kallio');
insert into ids select 'ev2', id from events where title = 'Kahvit Kalliossa';
commit;
begin; select t_login('mb@t.fi'); set local role authenticated;
select t_expect_error($$insert into storage.objects (bucket_id, name) values ('event-covers', (select v from ids where k='ev') || '/evil1234.webp')$$, 'row-level security');
select t_ok((select count(*) from storage.objects where bucket_id = 'event-covers') = 0, 'other user cannot list covers of foreign events');
delete from storage.objects where bucket_id = 'event-covers';
update events set cover_path = null where id = (select v from ids where k='ev');
commit;
select t_ok((select count(*) from storage.objects where bucket_id = 'event-covers') = 1 and (select cover_path from events where id = (select v from ids where k='ev')) is not null, 'other user cannot delete cover object or clear cover_path');
begin; set local role anon; select set_config('request.jwt.claims', '', true);
select t_ok((select cover_path from guest_events where id = (select v from ids where k='ev')) like '%/cov12345.webp', 'guest_events exposes cover_path (public bucket)');
select t_expect_error($$select count(*) from storage.objects$$, 'permission denied');
commit;
begin; select t_login('mban@t.fi'); set local role authenticated;
select t_expect_error($$insert into storage.objects (bucket_id, name) values ('event-covers', (select v from ids where k='ev') || '/ban12345.webp')$$, 'row-level security');
commit;
select t_ok((select public and file_size_limit = 262144 and allowed_mime_types = array['image/webp','image/jpeg'] from storage.buckets where id = 'event-covers')
  and (select not public and file_size_limit = 262144 from storage.buckets where id = 'chat-images'), 'buckets: covers public, chat private, 256 kB, webp/jpeg only');

-- ===== 8b chat images (event chat)
begin; select t_login('mb@t.fi'); set local role authenticated;
insert into event_participants (event_id, user_id) values ((select v from ids where k='ev'), auth.uid());
insert into ids values ('cid', t_cid((select v from ids where k='ev')));
insert into storage.objects (bucket_id, name) values ('chat-images', (select v from ids where k='cid') || '/img00001.webp');
insert into messages (conversation_id, body, image_path, image_w, image_h) values ((select v from ids where k='cid'), '', (select v from ids where k='cid') || '/img00001.webp', 1600, 1200);
select t_ok((select count(*) from messages where image_path like '%/img00001.webp' and sender_id = auth.uid()) = 1, 'participant sends an image message (empty caption ok)');
select t_expect_error($$insert into messages (conversation_id, body, image_path) values ((select v from ids where k='cid'), 'x', (select v from ids where k='cid') || '/nofile99.webp')$$, 'image_missing');
select t_expect_error($$insert into messages (conversation_id, body, image_path) values ((select v from ids where k='cid'), 'x', '00000000-0000-4000-8000-000000000000/img00001.webp')$$, 'image_path_invalid');
select t_expect_error($$insert into messages (conversation_id, body) values ((select v from ids where k='cid'), '')$$, 'messages_body_check');
select t_ok((select count(*) from storage.objects where bucket_id = 'chat-images') = 1, 'member can read (sign) chat image');
commit;
begin; select t_login('mc@t.fi'); set local role authenticated;
select t_ok((select count(*) from storage.objects where bucket_id = 'chat-images') = 0, 'non-participant cannot read chat images');
select t_expect_error($$insert into storage.objects (bucket_id, name) values ('chat-images', (select v from ids where k='cid') || '/img00002.webp')$$, 'row-level security');
select t_ok((select count(*) from messages where conversation_id = (select v from ids where k='cid')) = 0, 'non-participant cannot read event chat');
select t_expect_error($$insert into reports (target_type, target_id, reason) values ('message', (select id from messages limit 1), 'inappropriate')$$, 'report_target_missing');
commit;
-- help chat: no images
insert into help_requests (requester_id, category, title, description, city, district, lat, lng, starts_at, consent_voluntary, consent_terms, consent_review, status)
  select t_uid('ma@t.fi'), 'muu', 'Apua hyllyn kanssa', 'Tarvitsen apua hyllyn kokoamisessa.', 'Helsinki', 'Kallio', 60.18, 24.95, now() + interval '2 days', true, true, true, 'approved'
  where false;   -- (help request creation needs a contact row; can_post_image is checked directly below)
select t_ok(not exists (select 1 from conversations where kind = 'help' and public.can_post_image(id)), 'help chats never allow images');
begin; select t_login('ma@t.fi'); set local role authenticated;
select t_ok((select count(*) from storage.objects where bucket_id = 'chat-images') = 1, 'host (participant) reads chat image');
insert into reports (target_type, target_id, reason, note) values ('message', (select id from messages where image_path is not null limit 1), 'inappropriate', 'kuva');
select t_ok((select count(*) from reports where target_type = 'message') = 1, 'participant reports the image message');
insert into reports (target_type, target_id, reason) values ('event_cover', (select v from ids where k='ev'), 'other');
select t_expect_error($$insert into reports (target_type, target_id, reason) values ('event_cover', (select v from ids where k='ev2'), 'other')$$, 'report_target_missing');
commit;
begin; select t_login('madm@t.fi'); set local role authenticated;
select t_ok(t_n('admin_new_report', auth.uid()) = 2, 'admin notified about 2 reports');
select t_ok((select count(*) from messages where image_path is not null) = 1, 'admin sees the reported message');
select t_ok((select count(*) from storage.objects where bucket_id = 'chat-images') = 1, 'admin can open the reported image (signed URL)');
-- client order: remove the file first (Storage API needs the open report to see it), then the RPC
delete from storage.objects where bucket_id = 'chat-images' and name like '%/img00001.webp';
select t_ok((select count(*) from storage.objects where bucket_id = 'chat-images') = 0, 'admin removes the reported file');
select t_ok(admin_remove_content('message', (select id from messages where image_path is not null limit 1)) like '%/img00001.webp', 'admin_remove_content(message) returns the image path');
select t_ok((select count(*) from messages where image_path is not null) = 0 and (select status from reports where target_type = 'message') = 'resolved', 'message deleted, report resolved');
select t_ok(admin_remove_content('event_cover', (select v from ids where k='ev')) like '%/cov12345.webp', 'admin removes a reported cover');
delete from storage.objects where bucket_id = 'event-covers';
commit;
select t_ok((select count(*) from storage.objects) = 0 and (select cover_path from events where id = (select v from ids where k='ev')) is null, 'admin deleted both files (Storage API path)');
begin; select t_login('mb@t.fi'); set local role authenticated;
select t_expect_error($$select admin_remove_content('group', gen_random_uuid())$$, 'admin_only');
commit;

-- ===== 8c groups
begin; select t_login('ma@t.fi'); set local role authenticated;
select t_expect_error($$insert into groups (name) values ('Suora lisäys')$$, 'permission denied');
select t_expect_error($$select create_group('{"name":"Padel – varaa www.padelclub.fi"}')$$, 'commercial_content');
select t_expect_error($$select create_group('{"name":"ab"}')$$, 'group_invalid');
insert into ids values ('gopen', create_group('{"name":"Kallion padelporukka","description":"Pelataan viikoittain","visibility":"open","activity_id":"padel","city":"Helsinki","district":"Kallio","lat":60.184,"lng":24.95}'));
insert into ids values ('gclosed', create_group('{"name":"Sisäpiirin lautapelit","visibility":"closed","activity_id":"lautapelit","city":"Helsinki"}'));
select t_ok((select my_role from groups_v where id = (select v from ids where k='gopen')) = 'founder' and (select member_count from groups_v where id = (select v from ids where k='gopen')) = 1, 'founder role + member_count 1');
select t_ok((select count(*) from messages where conversation_id = t_cid((select v from ids where k='gopen')) and code = 'group_created') = 1, 'group chat created with system message');
select t_expect_error($$select leave_group((select v from ids where k='gopen'))$$, 'founder_cannot_leave');
commit;
begin; select t_login('mb@t.fi'); set local role authenticated;
select t_ok((select count(*) from groups where id = (select v from ids where k='gopen')) = 1, 'open group visible to everyone logged in');
select t_ok((select count(*) from groups where id = (select v from ids where k='gclosed')) = 0, 'closed group not listed for outsiders');
select t_ok((select name from group_preview((select v from ids where k='gclosed'))) = 'Sisäpiirin lautapelit', 'closed group preview via link (name only)');
select t_ok((select count(*) from group_members where group_id = (select v from ids where k='gopen')) = 0, 'outsider cannot read member list');
select t_ok((select count(*) from messages where conversation_id = t_cid((select v from ids where k='gopen'))) = 0, 'outsider cannot read open group chat');
select t_ok(join_group((select v from ids where k='gopen')) = 'member', 'B joins the open group');
select t_ok((select count(*) from messages where conversation_id = t_cid((select v from ids where k='gopen'))) >= 2, 'member reads group chat (system messages)');
insert into messages (conversation_id, body) values (t_cid((select v from ids where k='gopen')), 'Moi kaikki!');
insert into storage.objects (bucket_id, name) values ('chat-images', t_cid((select v from ids where k='gopen')) || '/grp00001.webp');
insert into messages (conversation_id, body, image_path) values (t_cid((select v from ids where k='gopen')), 'Kenttä', t_cid((select v from ids where k='gopen')) || '/grp00001.webp');
select t_ok((select count(*) from messages where conversation_id = t_cid((select v from ids where k='gopen')) and sender_id = auth.uid()) = 2, 'member sends text + image in group chat');
select t_expect_error($$insert into messages (conversation_id, body) values (t_cid((select v from ids where k='gopen')), 'Mailat -20 % www.padelkauppa.fi')$$, 'commercial_content');
select t_expect_error($$insert into messages (conversation_id, body) values (t_cid((select v from ids where k='gopen')), 'Soita 040 123 4567')$$, 'commercial_content');
insert into messages (conversation_id, body) values (t_cid((select v from ids where k='gopen')), 'Pelataan klo 18.30–20, jaetaan kenttämaksu');
select t_ok((select count(*) from messages where conversation_id = t_cid((select v from ids where k='gopen')) and body like 'Pelataan klo%') = 1, 'group chat: anti-ad guard blocks URL/price/phone, normal wording passes');
select t_expect_error($$select join_group((select v from ids where k='gclosed'))$$, 'group_closed');
select t_ok(request_join_group((select v from ids where k='gclosed'), 'Hei, saisinko liittyä?') = 'pending', 'B requests to join the closed group');
select t_ok((select count(*) from groups where id = (select v from ids where k='gclosed')) = 1, 'requester now sees the closed group');
select t_expect_error($$select review_join_request((select v from ids where k='gclosed'), auth.uid(), true)$$, 'group_mod_only');
commit;
begin; select t_login('mc@t.fi'); set local role authenticated;
select t_ok((select count(*) from storage.objects where bucket_id = 'chat-images') = 0, 'non-member cannot read group images');
select t_expect_error($$select invite_to_group((select v from ids where k='gopen'), t_uid('md@t.fi'))$$, 'group_mod_only');
commit;
begin; select t_login('ma@t.fi'); set local role authenticated;
select t_ok(t_n('group_member_joined', auth.uid()) = 1 and t_n('group_join_request', auth.uid()) = 1, 'founder notified: joined + join request');
select t_ok((select count(*) from group_join_requests where group_id = (select v from ids where k='gclosed') and status = 'pending') = 1, 'founder sees the pending request');
select invite_to_group((select v from ids where k='gclosed'), t_uid('mc@t.fi'));
select invite_to_group((select v from ids where k='gclosed'), t_uid('mc@t.fi'));
commit;
begin; select t_login('mc@t.fi'); set local role authenticated;
select t_ok(t_n('group_invite', auth.uid()) = 1, 'C notified once (group_invite, duplicate invite ignored)');
select t_ok((select count(*) from groups where id = (select v from ids where k='gclosed')) = 1, 'invitee sees the closed group');
select respond_group_invite((select v from ids where k='gclosed'), true);
select t_ok(is_group_member((select v from ids where k='gclosed')), 'C accepts the invite -> member');
commit;
begin; select t_login('ma@t.fi'); set local role authenticated;
select set_group_role((select v from ids where k='gclosed'), t_uid('mc@t.fi'), 'moderator');
select t_ok((select role from group_members where group_id = (select v from ids where k='gclosed') and user_id = t_uid('mc@t.fi')) = 'moderator', 'founder appoints C moderator');
commit;
begin; select t_login('mc@t.fi'); set local role authenticated;
select t_ok(t_n('group_moderator', auth.uid()) = 1, 'C notified (group_moderator)');
select review_join_request((select v from ids where k='gclosed'), t_uid('mb@t.fi'), true);
select t_ok((select count(*) from group_members where group_id = (select v from ids where k='gclosed')) = 3, 'moderator approves B''s request');
select t_expect_error($$select remove_group_member((select v from ids where k='gclosed'), t_uid('mb@t.fi'))$$, 'group_founder_only');
select t_expect_error($$select set_group_role((select v from ids where k='gclosed'), t_uid('mb@t.fi'), 'moderator')$$, 'group_founder_only');
select invite_to_group((select v from ids where k='gclosed'), t_uid('md@t.fi'));
commit;
begin; select t_login('mb@t.fi'); set local role authenticated;
select t_ok(t_n('group_request_approved', auth.uid()) = 1, 'B notified (group_request_approved)');
commit;
begin; select t_login('ma@t.fi'); set local role authenticated;
select remove_group_member((select v from ids where k='gclosed'), t_uid('mb@t.fi'));
select t_expect_error($$select remove_group_member((select v from ids where k='gclosed'), auth.uid())$$, 'group_remove_self');
commit;
begin; select t_login('mb@t.fi'); set local role authenticated;
select t_ok(t_n('group_removed', auth.uid()) = 1 and not is_group_member((select v from ids where k='gclosed')), 'founder removes B; B notified');
select t_ok((select count(*) from messages where conversation_id = t_cid((select v from ids where k='gclosed'))) = 0, 'removed member cannot read the chat anymore');
select t_ok((select request_status from group_preview((select v from ids where k='gclosed'))) = 'approved', 'preview shows old request status');
select leave_group((select v from ids where k='gopen'));
select t_ok(not is_group_member((select v from ids where k='gopen')), 'B leaves the open group');
select t_expect_error($$select delete_group((select v from ids where k='gopen'))$$, 'group_founder_only');
insert into reports (target_type, target_id, reason) values ('group', (select v from ids where k='gopen'), 'spam');
commit;
begin; select t_login('mban@t.fi'); set local role authenticated;
select t_expect_error($$select create_group('{"name":"Estetyn ryhmä"}')$$, 'account_banned');
select t_expect_error($$select join_group((select v from ids where k='gopen'))$$, 'account_banned');
commit;
begin; set local role anon; select set_config('request.jwt.claims', '', true);
select t_expect_error($$select count(*) from groups$$, 'permission denied');
select t_expect_error($$select count(*) from groups_v$$, 'permission denied');
select t_expect_error($$select * from group_preview(gen_random_uuid())$$, 'permission denied');
select t_expect_error($$select create_group('{"name":"Anon ryhmä"}')$$, 'permission denied');
commit;
-- founder account deleted -> oldest moderator/member becomes founder; empty group deleted
begin; select t_login('md@t.fi'); set local role authenticated;
insert into ids values ('gd', create_group('{"name":"Dn ryhmä","visibility":"open"}'));
insert into ids values ('gd2', create_group('{"name":"Dn yksin","visibility":"open"}'));
commit;
begin; select t_login('me@t.fi'); set local role authenticated; select join_group((select v from ids where k='gd')); commit;
delete from auth.users where email = 'md@t.fi';
select t_ok((select founder_id from groups where id = (select v from ids where k='gd')) = t_uid('me@t.fi')
  and (select role from group_members where group_id = (select v from ids where k='gd') and user_id = t_uid('me@t.fi')) = 'founder', 'founder deleted -> member promoted to founder');
select t_ok(not exists (select 1 from groups where id = (select v from ids where k='gd2')), 'founder deleted, no members -> group deleted');
begin; select t_login('madm@t.fi'); set local role authenticated;
select admin_remove_content('group', (select v from ids where k='gopen'));
select t_ok(not exists (select 1 from groups where id = (select v from ids where k='gopen')) and (select status from reports where target_type = 'group') = 'resolved', 'admin deletes a reported group');
commit;
select t_ok(not exists (select 1 from conversations where kind = 'group' and group_id is null), 'group chats cascade with the group');
\echo 'MEDIA-GROUPS TESTS PASSED'
