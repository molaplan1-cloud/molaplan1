-- RLS / function tests for the order shop (R240). Raises on the first failure.
\set ON_ERROR_STOP on
begin;
insert into private.shop_admins values ('admin@example.test') on conflict do nothing;
insert into private.shop_secret (id, hash) values (1, encode(sha256(convert_to(repeat('s', 40), 'UTF8')), 'hex'))
  on conflict (id) do update set hash = excluded.hash;

create or replace function pg_temp.as_anon() returns void language plpgsql as $$
begin perform set_config('request.jwt.claims', '', true); execute 'set local role anon'; end $$;
create or replace function pg_temp.as_email(e text) returns void language plpgsql as $$
begin perform set_config('request.jwt.claims', json_build_object('email', e, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated'; end $$;
create or replace function pg_temp.reset() returns void language plpgsql as $$
begin execute 'reset role'; end $$;
create or replace function pg_temp.expect_fail(q text, what text) returns void language plpgsql as $$
begin
  begin execute q; exception when others then return; end;
  raise exception 'EXPECTED FAILURE did not happen: %', what;
end $$;
create or replace function pg_temp.expect(q text, want bigint, what text) returns void language plpgsql as $$
declare got bigint;
begin execute q into got;
  if got is distinct from want then raise exception '%: got %, want %', what, got, want; end if; end $$;
grant execute on all functions in schema pg_temp to anon, authenticated;

-- seed catalog: 5 visible products, prices all 'quote'
select pg_temp.expect('select count(*) from public.shop_products', 5, 'seeded products');
select pg_temp.expect($q$select count(*) from public.shop_products where price_mode <> 'quote' or price_cents is not null$q$, 0, 'no invented prices');
update public.shop_products set hidden = true where name = 'Asennuspalvelu';

-- anon: reads visible products only, cannot write or read orders/settings
select pg_temp.as_anon();
select pg_temp.expect('select count(*) from public.shop_products', 4, 'anon sees visible only');
select pg_temp.expect_fail($q$insert into public.shop_products (name) values ('x')$q$, 'anon insert product');
select pg_temp.expect_fail('select count(*) from public.shop_orders', 'anon read orders');
select pg_temp.expect_fail($q$insert into public.shop_orders (name, email) values ('a', 'a@b.fi')$q$, 'anon direct order insert');
select pg_temp.expect_fail('select count(*) from public.shop_settings', 'anon read settings');
select pg_temp.expect_fail($q$select public.shop_submit_order('wrong-secret-wrong-secret-wrong-secret!', '{}')$q$, 'submit without secret');
select pg_temp.expect_fail($q$select public.shop_submit_order(repeat('s', 40), jsonb_build_object('name','A','email','a@example.test','consent',true,
  'items', jsonb_build_array(jsonb_build_object('product_id', (select id from public.shop_products where name='Asennuspalvelu'), 'qty', 1))))$q$, 'hidden product');
select pg_temp.expect_fail($q$select public.shop_submit_order(repeat('s', 40), jsonb_build_object('name','A','email','a@example.test','consent',false,
  'items', jsonb_build_array(jsonb_build_object('product_id', (select id from public.shop_products where unlocks_pc_app), 'qty', 1))))$q$, 'no consent');
select pg_temp.expect_fail($q$select public.shop_submit_order(repeat('s', 40), jsonb_build_object('name','A','email','a@example.test','consent',true,'items','[]'::jsonb))$q$, 'empty cart');
-- valid submit (qty clamped to max_quantity, name snapshot from DB not from client)
select pg_temp.expect($q$select (public.shop_submit_order(repeat('s', 40), jsonb_build_object('name',' Asiakas ','email','Buyer@Example.test','consent',true,'lang','sv',
  'items', jsonb_build_array(jsonb_build_object('product_id', (select id from public.shop_products where unlocks_pc_app), 'qty', 5000, 'name', 'HACK', 'price_cents', 1)))) ->> 'number')::bigint$q$,
  1001, 'order number');
select pg_temp.expect_fail($q$select public.shop_log_message('nope', gen_random_uuid(), 'auto', 's', 'b', true, '')$q$, 'log without secret');
select pg_temp.reset();
select pg_temp.expect($q$select count(*) from public.shop_orders where name='Asiakas' and email='buyer@example.test' and lang='sv' and unlocks_pc_app
  and (items->0->>'qty')::int = 20 and items->0->>'name' = 'Molaplan PC-sovellus (Windows)' and items->0->>'price_cents' is null$q$, 1, 'snapshot + clamp');

-- stranger: no orders, no admin, no license
select pg_temp.as_email('buyer@example.test');
select pg_temp.expect('select count(*) from public.shop_orders', 0, 'customer cannot list orders');
select pg_temp.expect($q$select (public.is_shop_admin())::int$q$, 0, 'customer is not admin');
select pg_temp.expect($q$select (public.my_shop_downloads()->>'pc_app')::boolean::int$q$, 0, 'not paid yet');
select pg_temp.expect($q$with u as (update public.shop_products set name='x' returning 1) select count(*) from u$q$, 0, 'customer cannot edit');
select pg_temp.reset();

-- admin: everything; status change logged; paid unlocks download for the same email only
select pg_temp.as_email('ADMIN@example.test');
select pg_temp.expect($q$select (public.is_shop_admin())::int$q$, 1, 'admin');
select pg_temp.expect('select count(*) from public.shop_products', 5, 'admin sees hidden');
select pg_temp.expect('select count(*) from public.shop_orders', 1, 'admin reads orders');
select pg_temp.expect('select count(*) from public.shop_settings', 1, 'admin reads settings');
insert into public.shop_products (name, price_mode, price_cents) values ('Testi', 'fixed', 1990);
select pg_temp.expect_fail($q$insert into public.shop_products (name, price_mode) values ('Bad', 'fixed')$q$, 'fixed price needs cents');
update public.shop_orders set status = 'tarjottu', offer_cents = 12000, seen = true;
insert into public.shop_order_messages (order_id, kind, author, subject, body, delivered)
  select id, 'out', 'admin@example.test', 'Tarjous', 'x', true from public.shop_orders;
update public.shop_orders set status = 'maksettu';
select pg_temp.expect($q$select count(*) from public.shop_order_messages where kind='status'$q$, 2, 'status log');
select pg_temp.expect_fail($q$update public.shop_orders set status='bogus'$q$, 'status check');
select pg_temp.reset();
select pg_temp.as_email('buyer@example.test');
select pg_temp.expect($q$select (public.my_shop_downloads()->>'pc_app')::boolean::int$q$, 1, 'paid unlocks');
select pg_temp.reset();
select pg_temp.as_email('other@example.test');
select pg_temp.expect($q$select (public.my_shop_downloads()->>'pc_app')::boolean::int$q$, 0, 'other email locked');
select pg_temp.reset();
rollback;
\echo shop RLS tests OK
