-- Order shop (R240, t256u/t257u/t258u): product catalog, order requests, admin replies, PC-app download unlock.
-- Nothing is sold here: an order is a non-binding request; the offer and the invoice follow by email.
-- Idempotent (safe to run twice).

create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

-- Admins by account email. Managed with SQL only (no defaults are shipped; the deployment adds its own):
--   insert into private.shop_admins (email) values ('owner@example.com');
create table if not exists private.shop_admins (email text primary key check (email = lower(email)));

-- Shared secret of the shop Worker (only its sha256 is stored here); without it the anon role cannot submit.
create table if not exists private.shop_secret (id int primary key default 1 check (id = 1), hash text not null);

create or replace function private.jwt_email() returns text
language sql stable set search_path = '' as $$
  select lower(coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'email', '')) $$;

create or replace function private.is_shop_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from private.shop_admins a where a.email = private.jwt_email() and a.email <> '') $$;
revoke all on function private.is_shop_admin() from public, anon;
grant execute on function private.is_shop_admin() to authenticated;

create or replace function public.is_shop_admin() returns boolean
language sql stable security invoker set search_path = '' as $$ select private.is_shop_admin() $$;
revoke all on function public.is_shop_admin() from public, anon;
grant execute on function public.is_shop_admin() to authenticated;

-- Products & services ----------------------------------------------------------------------------
create table if not exists public.shop_products (
  id uuid primary key default gen_random_uuid(),
  sort int not null default 100,
  category text not null default 'Ohjelmistot',
  kind text not null default 'device' check (kind in ('software', 'device', 'service')),
  name text not null check (length(name) between 1 and 120),
  summary text not null default '' check (length(summary) <= 300),
  description text not null default '' check (length(description) <= 4000),
  i18n jsonb not null default '{}'::jsonb,               -- {"en":{"name","summary","description","category"},"sv":…,"es":…}
  price_mode text not null default 'quote' check (price_mode in ('fixed', 'quote')),
  price_cents int check (price_cents is null or price_cents >= 0),
  price_note text not null default '' check (length(price_note) <= 80),   -- e.g. "/ kpl", "alkaen"
  image_path text,                                        -- object in the public 'shop-images' bucket
  allow_quantity boolean not null default true,
  max_quantity int not null default 20 check (max_quantity between 1 and 999),
  ask_notes boolean not null default true,
  notes_label text not null default '' check (length(notes_label) <= 120),
  unlocks_pc_app boolean not null default false,          -- paid order -> PC app download for the same account email
  hidden boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (price_mode = 'quote' or price_cents is not null)
);
alter table public.shop_products enable row level security;
drop policy if exists "shop products: public read" on public.shop_products;
create policy "shop products: public read" on public.shop_products for select to anon using (not hidden);
drop policy if exists "shop products: signed-in read" on public.shop_products;
create policy "shop products: signed-in read" on public.shop_products for select to authenticated
  using (not hidden or (select private.is_shop_admin()));
drop policy if exists "shop products: admin write" on public.shop_products;
create policy "shop products: admin write" on public.shop_products for all to authenticated
  using ((select private.is_shop_admin())) with check ((select private.is_shop_admin()));
grant select on public.shop_products to anon, authenticated;
grant insert, update, delete on public.shop_products to authenticated;

-- Settings (one row): notification targets, sender texts, reply templates --------------------------
create table if not exists public.shop_settings (
  id int primary key default 1 check (id = 1),
  seller_name text not null default '',
  contact_email text not null default '',
  notify_emails text[] not null default '{}',
  ntfy_topic text not null default '',          -- private topic on ntfy.molaplan.com for new-order pushes
  reply_templates jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now()
);
alter table public.shop_settings enable row level security;
drop policy if exists "shop settings: admin" on public.shop_settings;
create policy "shop settings: admin" on public.shop_settings for all to authenticated
  using ((select private.is_shop_admin())) with check ((select private.is_shop_admin()));
grant select, insert, update on public.shop_settings to authenticated;

-- Seller name + contact are public (privacy page / footer); the rest stays admin-only.
create or replace function public.shop_public_info() returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce((select jsonb_build_object('seller_name', s.seller_name, 'contact_email', s.contact_email)
                   from public.shop_settings s where s.id = 1), '{}'::jsonb) $$;
grant execute on function public.shop_public_info() to anon, authenticated;

-- Orders -----------------------------------------------------------------------------------------
create sequence if not exists public.shop_order_number start 1001;
create table if not exists public.shop_orders (
  id uuid primary key default gen_random_uuid(),
  number int not null unique default nextval('public.shop_order_number'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  status text not null default 'uusi'
    check (status in ('uusi', 'tarjottu', 'laskutettu', 'maksettu', 'toimitettu', 'peruttu')),
  seen boolean not null default false,
  name text not null check (length(name) between 1 and 120),
  email text not null check (email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$' and length(email) <= 200),
  phone text not null default '' check (length(phone) <= 40),
  address text not null default '' check (length(address) <= 400),
  message text not null default '' check (length(message) <= 4000),
  items jsonb not null default '[]'::jsonb,     -- snapshot: [{product_id,name,kind,qty,notes,price_mode,price_cents,unlocks_pc_app}]
  lang text not null default 'fi',
  consent_at timestamptz not null default now(),
  offer_cents int check (offer_cents is null or offer_cents >= 0),
  admin_notes text not null default '',
  unlocks_pc_app boolean not null default false
);
alter table public.shop_orders enable row level security;
drop policy if exists "shop orders: admin" on public.shop_orders;
create policy "shop orders: admin" on public.shop_orders for all to authenticated
  using ((select private.is_shop_admin())) with check ((select private.is_shop_admin()));
grant select, update, delete on public.shop_orders to authenticated;   -- inserts only via shop_submit_order()
create index if not exists shop_orders_created on public.shop_orders (created_at desc);
create index if not exists shop_orders_email on public.shop_orders (lower(email));

create table if not exists public.shop_order_messages (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.shop_orders(id) on delete cascade,
  created_at timestamptz not null default now(),
  kind text not null check (kind in ('in', 'out', 'auto', 'note', 'status')),
  author text not null default '',
  subject text not null default '',
  body text not null default '',
  delivered boolean,                 -- out/auto: true sent, false failed (error has why), null = not tried (mailto)
  error text not null default ''
);
alter table public.shop_order_messages enable row level security;
drop policy if exists "shop messages: admin" on public.shop_order_messages;
create policy "shop messages: admin" on public.shop_order_messages for all to authenticated
  using ((select private.is_shop_admin())) with check ((select private.is_shop_admin()));
grant select, insert, update, delete on public.shop_order_messages to authenticated;
create index if not exists shop_messages_order on public.shop_order_messages (order_id, created_at);

create or replace function public.shop_touch() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin new.updated_at := now(); return new; end $$;
drop trigger if exists shop_products_touch on public.shop_products;
create trigger shop_products_touch before update on public.shop_products for each row execute function public.shop_touch();
drop trigger if exists shop_orders_touch on public.shop_orders;
create trigger shop_orders_touch before update on public.shop_orders for each row execute function public.shop_touch();

-- Status changes are logged on the order's thread.
create or replace function public.shop_order_status_log() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.status is distinct from old.status then
    insert into public.shop_order_messages (order_id, kind, author, body)
    values (new.id, 'status', private.jwt_email(), old.status || ' → ' || new.status);
  end if;
  return new;
end $$;
drop trigger if exists shop_orders_status_log on public.shop_orders;
create trigger shop_orders_status_log after update on public.shop_orders for each row execute function public.shop_order_status_log();

-- Submit (called by the shop Worker after Turnstile, with its secret) --------------------------------
create or replace function private.shop_secret_ok(p_secret text) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from private.shop_secret s
                 where p_secret is not null and length(p_secret) >= 32
                   and s.hash = encode(sha256(convert_to(p_secret, 'UTF8')), 'hex')) $$;
revoke all on function private.shop_secret_ok(text) from public, anon, authenticated;

create or replace function public.shop_submit_order(p_secret text, p jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  it jsonb; prod public.shop_products; q int; snap jsonb := '[]'::jsonb; pc boolean := false;
  o public.shop_orders; n int := 0; recent int;
begin
  if not private.shop_secret_ok(p_secret) then raise exception 'forbidden' using errcode = '42501'; end if;
  if jsonb_typeof(p -> 'items') <> 'array' or jsonb_array_length(p -> 'items') = 0 then
    raise exception 'empty cart' using errcode = '22023'; end if;
  if jsonb_array_length(p -> 'items') > 30 then raise exception 'too many items' using errcode = '22023'; end if;
  if coalesce((p ->> 'consent')::boolean, false) is not true then raise exception 'consent required' using errcode = '22023'; end if;
  select count(*) into recent from public.shop_orders where lower(email) = lower(p ->> 'email') and created_at > now() - interval '1 hour';
  if recent >= 5 then raise exception 'too many orders' using errcode = '54000'; end if;
  for it in select * from jsonb_array_elements(p -> 'items') loop
    select * into prod from public.shop_products where id = (it ->> 'product_id')::uuid and not hidden;
    if not found then raise exception 'unknown product' using errcode = '22023'; end if;
    q := greatest(1, least(coalesce((it ->> 'qty')::int, 1), case when prod.allow_quantity then prod.max_quantity else 1 end));
    snap := snap || jsonb_build_object('product_id', prod.id, 'name', prod.name, 'kind', prod.kind, 'qty', q,
      'notes', left(coalesce(it ->> 'notes', ''), 1000), 'price_mode', prod.price_mode, 'price_cents', prod.price_cents,
      'price_note', prod.price_note, 'unlocks_pc_app', prod.unlocks_pc_app);
    pc := pc or prod.unlocks_pc_app;
    n := n + 1;
  end loop;
  insert into public.shop_orders (name, email, phone, address, message, items, lang, unlocks_pc_app)
  values (btrim(p ->> 'name'), lower(btrim(p ->> 'email')), btrim(coalesce(p ->> 'phone', '')),
          btrim(coalesce(p ->> 'address', '')), btrim(coalesce(p ->> 'message', '')), snap,
          case when p ->> 'lang' in ('fi', 'en', 'sv', 'es') then p ->> 'lang' else 'fi' end, pc)
  returning * into o;
  return jsonb_build_object('id', o.id, 'number', o.number, 'items', o.items, 'name', o.name, 'email', o.email,
    'phone', o.phone, 'address', o.address, 'message', o.message, 'lang', o.lang,
    'settings', (select to_jsonb(s) - 'updated_at' from public.shop_settings s where s.id = 1));
end $$;
revoke all on function public.shop_submit_order(text, jsonb) from public;
grant execute on function public.shop_submit_order(text, jsonb) to anon, authenticated;

-- The Worker logs automatic emails (confirmation / notification) on the order.
create or replace function public.shop_log_message(p_secret text, p_order uuid, p_kind text, p_subject text,
  p_body text, p_delivered boolean, p_error text) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not private.shop_secret_ok(p_secret) then raise exception 'forbidden' using errcode = '42501'; end if;
  if p_kind not in ('auto', 'in') then raise exception 'bad kind' using errcode = '22023'; end if;
  insert into public.shop_order_messages (order_id, kind, author, subject, body, delivered, error)
  values (p_order, p_kind, 'molaplan.com', left(coalesce(p_subject, ''), 300), left(coalesce(p_body, ''), 20000),
          p_delivered, left(coalesce(p_error, ''), 500));
end $$;
revoke all on function public.shop_log_message(text, uuid, text, text, text, boolean, text) from public;
grant execute on function public.shop_log_message(text, uuid, text, text, text, boolean, text) to anon, authenticated;

-- PC app download: unlocked when a PC-app order of the caller's account email is paid or delivered.
create or replace function private.has_pc_license() returns boolean
language sql stable security definer set search_path = '' as $$
  select private.jwt_email() <> '' and exists (
    select 1 from public.shop_orders o
    where lower(o.email) = private.jwt_email() and o.unlocks_pc_app and o.status in ('maksettu', 'toimitettu')) $$;
revoke all on function private.has_pc_license() from public, anon;
grant execute on function private.has_pc_license() to authenticated;

create or replace function public.my_shop_downloads() returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('pc_app', private.has_pc_license(),
    'orders', coalesce((select jsonb_agg(jsonb_build_object('number', o.number, 'status', o.status, 'created_at', o.created_at)
                                         order by o.created_at desc)
                        from public.shop_orders o where lower(o.email) = private.jwt_email() and private.jwt_email() <> ''), '[]'::jsonb)) $$;
revoke all on function public.my_shop_downloads() from public, anon;
grant execute on function public.my_shop_downloads() to authenticated;

-- Seed (neutral wording, every price 'tarjouksen mukaan'; only when the catalog is empty) -------------
insert into public.shop_settings (id, reply_templates) values (1, jsonb_build_array(
  jsonb_build_object('title', 'Tarjous', 'subject', 'Tarjous tilaukseesi #{numero}', 'status', 'tarjottu',
    'body', E'Hei {nimi},\n\nkiitos tilauksestasi #{numero}. Tarjouksemme on {hinta}.\n\nJos tarjous sopii, vastaa tähän viestiin, niin lähetämme laskun. Tarjous on voimassa 30 päivää.\n\nYstävällisin terveisin\n{myyjä}'),
  jsonb_build_object('title', 'Lisätietoja', 'subject', 'Tilauksesi #{numero}: tarvitsemme lisätietoja', 'status', '',
    'body', E'Hei {nimi},\n\nkiitos tilauksestasi #{numero}. Tarvitsemme vielä muutaman lisätiedon ennen tarjousta:\n\n- \n\nYstävällisin terveisin\n{myyjä}'),
  jsonb_build_object('title', 'Lasku lähetetty', 'subject', 'Lasku tilaukseesi #{numero}', 'status', 'laskutettu',
    'body', E'Hei {nimi},\n\nlasku tilauksestasi #{numero} on lähetetty sinulle erikseen sähköpostilla laskutuspalvelun kautta.\n\nYstävällisin terveisin\n{myyjä}'),
  jsonb_build_object('title', 'Maksu saatu', 'subject', 'Maksu vastaanotettu – tilaus #{numero}', 'status', 'maksettu',
    'body', E'Hei {nimi},\n\nkiitos, maksusi on vastaanotettu. {lataus}\n\nYstävällisin terveisin\n{myyjä}'),
  jsonb_build_object('title', 'Toimitettu', 'subject', 'Tilaus #{numero} toimitettu', 'status', 'toimitettu',
    'body', E'Hei {nimi},\n\ntilauksesi #{numero} on toimitettu. Kerro, jos jokin ei toimi odotetusti.\n\nYstävällisin terveisin\n{myyjä}')
)) on conflict (id) do nothing;

do $$ begin
  if not exists (select 1 from public.shop_products) then
    insert into public.shop_products (sort, category, kind, name, summary, description, allow_quantity, ask_notes, notes_label, unlocks_pc_app, i18n) values
    (10, 'Ohjelmistot', 'software', 'Molaplan PC-sovellus (Windows)',
     'Ohjaus- ja tilasovellus Windows-tietokoneelle.',
     E'Molaplan kokoaa kodin ja mökin laitteet yhteen näkymään: valot, lämmityksen, kamerat, anturit ja muut. Sovellus toimii Windows 10- ja 11-koneilla. Maksun jälkeen lataus avautuu Molaplan-tilillesi, joka luodaan samalla sähköpostiosoitteella kuin tilaus.',
     true, true, 'Mitä haluat ohjata? (valinnainen)', true,
     '{"en":{"name":"Molaplan PC app (Windows)","summary":"Control and status app for a Windows PC.","category":"Software"},"sv":{"name":"Molaplan PC-app (Windows)","summary":"Styr- och statusapp för Windows-dator.","category":"Programvara"},"es":{"name":"App Molaplan para PC (Windows)","summary":"App de control y estado para un PC con Windows.","category":"Software"}}'),
    (20, 'Laitteet', 'device', 'Valmiiksi ohjelmoitu Android-tabletti',
     'Tabletti, jossa Molaplan on asennettu ja säädetty valmiiksi.',
     E'Tabletti toimitetaan Molaplan valmiiksi asennettuna, ja sen voi kiinnittää seinälle ohjauspaneeliksi. Se voi toimia myös kotisiltana etäkäyttöä varten. Kerro viestissä, mitä laitteita haluat ohjata, niin näkymä tehdään valmiiksi.',
     true, true, 'Toiveet (koko, seinäkiinnitys, laitteet)', false,
     '{"en":{"name":"Pre-programmed Android tablet","summary":"A tablet with Molaplan installed and set up.","category":"Devices"},"sv":{"name":"Färdigprogrammerad Android-surfplatta","summary":"En surfplatta med Molaplan installerat och inställt.","category":"Enheter"},"es":{"name":"Tableta Android preprogramada","summary":"Tableta con Molaplan instalado y configurado.","category":"Dispositivos"}}'),
    (30, 'Laitteet', 'device', 'ESP IR -ohjain',
     'Infrapunaohjain esimerkiksi ilmalämpöpumpulle tai televisiolle.',
     E'Pieni ESP32-pohjainen ohjain, joka lähettää infrapunakomentoja samaan tapaan kuin kaukosäädin. Sillä voi ohjata esimerkiksi ilmalämpöpumppua Molaplanista myös etänä. Kerro laitteen merkki ja malli.',
     true, true, 'Ohjattavan laitteen merkki ja malli', false,
     '{"en":{"name":"ESP IR controller","summary":"Infrared controller, e.g. for an air-source heat pump or a TV.","category":"Devices"},"sv":{"name":"ESP IR-styrning","summary":"IR-styrning t.ex. för luftvärmepump eller tv.","category":"Enheter"},"es":{"name":"Controlador IR ESP","summary":"Controlador infrarrojo, p. ej. para bomba de calor o TV.","category":"Dispositivos"}}'),
    (40, 'Palvelut', 'service', 'Asennuspalvelu',
     'Asennus ja käyttöönotto paikan päällä tai etänä.',
     E'Asennamme Molaplanin ja laitteet, liitämme ne kotiverkkoon ja teemme näkymän valmiiksi. Kerro paikkakunta ja mitä asennus koskee.',
     false, true, 'Paikkakunta ja asennettavat laitteet', false,
     '{"en":{"name":"Installation service","summary":"Installation and setup on site or remotely.","category":"Services"},"sv":{"name":"Installationstjänst","summary":"Installation och driftsättning på plats eller på distans.","category":"Tjänster"},"es":{"name":"Servicio de instalación","summary":"Instalación y puesta en marcha in situ o a distancia.","category":"Servicios"}}'),
    (50, 'Palvelut', 'service', 'Räätälöity ESP-laite',
     'Tarpeeseesi suunniteltu ESP32-laite.',
     E'Suunnittelemme ja rakennamme ESP32-pohjaisen laitteen juuri sinun tarpeeseesi, esimerkiksi anturin, releohjauksen tai mittauksen. Kuvaile, mitä laitteen pitäisi tehdä.',
     false, true, 'Mitä laitteen pitäisi tehdä?', false,
     '{"en":{"name":"Custom ESP device","summary":"An ESP32 device designed for your needs.","category":"Services"},"sv":{"name":"Skräddarsydd ESP-enhet","summary":"En ESP32-enhet för dina behov.","category":"Tjänster"},"es":{"name":"Dispositivo ESP a medida","summary":"Un dispositivo ESP32 diseñado para tus necesidades.","category":"Servicios"}}');
  end if;
end $$;
