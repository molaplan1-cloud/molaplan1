-- Team account requests (schema.sql 7e). Run on a scratch DB with 00-supabase-stub.sql + schema.sql (never on live).
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

insert into auth.users (email, email_confirmed_at) values ('tra@t.fi', now()), ('trb@t.fi', now()), ('tradm@t.fi', now()), ('trn@t.fi', null);
update public.profiles set display_name = 'T', onboarded = true where id in (select id from auth.users where email like 'tr%@t.fi');
update public.profiles set is_admin = true where id = public.t_uid('tradm@t.fi');

-- ===== request
begin; select t_login('tra@t.fi'); set local role authenticated;
select t_expect_error('insert into team_requests(requester_id,team_name,sport,city,contact_name,contact_email) values (auth.uid(),''X'',''Futis'',''Espoo'',''A'',''a@t.fi'')', 'permission denied');
select t_expect_error($q$select request_team_account('{"team_name":"K","sport":"Salibandy","city":"Espoo","contact_name":"Aa","contact_email":"a@t.fi"}')$q$, 'team_request_invalid');
select t_expect_error($q$select request_team_account('{"team_name":"Kiekko","sport":"Salibandy","city":"Espoo","contact_name":"Aa","contact_email":"not-an-email"}')$q$, 'team_request_invalid');
select t_expect_error($q$select request_team_account('{"team_name":"Kiekko","sport":"Salibandy","city":"Espoo","contact_name":"Aa","contact_email":"a@t.fi","contact_phone":"abc"}')$q$, 'team_request_invalid');
select t_ok(request_team_account('{"team_name":"  Espoon   Kiekko ","sport":"Salibandy","city":"Espoo","contact_name":"Aino","contact_email":"A@T.fi","contact_phone":"+358 40 123 4567","description":"Harrastejoukkue"}') is not null, 'A requests a team account');
select t_ok((select team_name from team_requests) = 'Espoon Kiekko' and (select contact_email from team_requests) = 'a@t.fi' and (select status from team_requests) = 'pending', 'normalised, status pending');
select t_ok((select requester_id from team_requests) = auth.uid(), 'requester = caller');
select t_expect_error('update team_requests set status = ''approved''', 'permission denied');
select t_expect_error('delete from team_requests', 'permission denied');
select t_expect_error($q$select admin_review_team_request((select id from team_requests limit 1), 'approved')$q$, 'admin_only');
select request_team_account('{"team_name":"Toinen","sport":"Futis","city":"Espoo","contact_name":"Aino","contact_email":"a@t.fi"}');
select request_team_account('{"team_name":"Kolmas","sport":"Futis","city":"Espoo","contact_name":"Aino","contact_email":"a@t.fi"}');
select t_expect_error($q$select request_team_account('{"team_name":"Neljäs","sport":"Futis","city":"Espoo","contact_name":"Aino","contact_email":"a@t.fi"}')$q$, 'too_many_team_requests');
commit;
begin; select t_login('trn@t.fi'); set local role authenticated;
select t_expect_error($q$select request_team_account('{"team_name":"Kiekko","sport":"Salibandy","city":"Espoo","contact_name":"Nn","contact_email":"n@t.fi"}')$q$, 'email_not_verified');
commit;
-- ===== isolation
begin; select t_login('trb@t.fi'); set local role authenticated;
select t_ok((select count(*) from team_requests) = 0, 'other user sees no team requests');
select t_ok((select count(*) from notifications where code = 'admin_new_team_request') = 0, 'other user got no admin notification');
commit;
begin; set local role anon;
select t_expect_error('select count(*) from team_requests', 'permission denied');
select t_expect_error($q$select request_team_account('{"team_name":"Kiekko","sport":"Salibandy","city":"Espoo","contact_name":"Aa","contact_email":"a@t.fi"}')$q$, 'permission denied');
commit;
-- ===== admin review
begin; select t_login('tradm@t.fi'); set local role authenticated;
select t_ok((select count(*) from team_requests) = 3, 'admin sees all requests');
select t_ok((select count(*) from notifications where code = 'admin_new_team_request' and link_kind = 'admin') = 3, 'admin notified for each request');
select t_expect_error($q$select admin_review_team_request((select id from team_requests where team_name = 'Toinen'), 'rejected', '')$q$, 'reason_required');
select admin_review_team_request((select id from team_requests where team_name = 'Espoon Kiekko'), 'approved');
select admin_review_team_request((select id from team_requests where team_name = 'Toinen'), 'rejected', 'Tiedot puuttuvat');
select t_ok((select status from team_requests where team_name = 'Espoon Kiekko') = 'approved' and (select reviewed_by from team_requests where team_name = 'Espoon Kiekko') = auth.uid(), 'approved + reviewed_by');
select t_expect_error($q$select admin_review_team_request((select id from team_requests where team_name = 'Espoon Kiekko'), 'rejected', 'xxx')$q$, 'team_request_already_reviewed');
commit;
begin; select t_login('tra@t.fi'); set local role authenticated;
select t_ok((select count(*) from notifications where code = 'team_request_approved' and link_kind = 'team') = 1, 'requester notified: approved');
select t_ok((select count(*) from notifications where code = 'team_request_rejected' and params->>'reason' = 'Tiedot puuttuvat') = 1, 'requester notified: rejected with reason');
select t_ok((select admin_reason from team_requests where team_name = 'Toinen') = 'Tiedot puuttuvat', 'requester sees the reason');
select t_ok(request_team_account('{"team_name":"Neljäs","sport":"Futis","city":"Espoo","contact_name":"Aino","contact_email":"a@t.fi"}') is not null, 'after review, a new request is allowed again (only 1 pending left)');
commit;
-- ===== account deletion cascades
delete from auth.users where email = 'tra@t.fi';
select t_ok((select count(*) from public.team_requests) = 0, 'requests removed with the account');
select 'TEAM REQUEST TESTS PASSED' as result;
