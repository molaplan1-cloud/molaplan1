-- =====================================================================
--  Molaplan – Supabase-tietokanta (Postgres)
--  Aja koko tiedosto Supabasen SQL Editorissa (Dashboard → SQL Editor).
--  Skripti on idempotentti: sen voi ajaa uudelleen (esim. päivitysten
--  jälkeen) ilman että data katoaa.
--
--  Sisältö:
--   1. Taulut + indeksit
--   2. Apufunktiot (is_admin, can_help, …)
--   3. Triggerit (profiili rekisteröityessä, 18+/hullu-liput, chatit,
--      järjestelmäviestit, ilmoitukset, tilamuutosten historia)
--   4. Row Level Security -säännöt jokaiselle taululle
--   5. Oikeudet (grantit), Realtime-julkaisu
--   6. Lajien (activities) perusdata
--   (1b. Julkiset tapahtumat + yritystilit ja yritysten tapahtumat)
--
--  Ylläpitäjä asetetaan VAIN SQL:llä: katso supabase/make-admin.sql
-- =====================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------
-- 1. TAULUT
-- ---------------------------------------------------------------------

-- Julkinen profiili (näkyy kirjautuneille käyttäjille)
create table if not exists public.profiles (
  id             uuid primary key references auth.users(id) on delete cascade,
  display_name   text not null default '' check (char_length(display_name) <= 40),
  city           text not null default 'Helsinki' check (char_length(city) <= 40),
  custom_city    text not null default '' check (char_length(custom_city) <= 40),
  district       text not null default '' check (char_length(district) <= 40),
  favs           text[] not null default '{}' check (cardinality(favs) <= 100),
  bio            text not null default '' check (char_length(bio) <= 300),
  onboarded      boolean not null default false,
  is_admin       boolean not null default false,   -- vain SQL:llä (trigger estää muutokset API:n kautta)
  email_verified boolean not null default false,   -- synkronoidaan auth.users.email_confirmed_at -kentästä
  language       text check (language is null or language in ('en','fi','es','sv')),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
alter table public.profiles add column if not exists language text check (language is null or language in ('en','fi','es','sv'));

-- Yksityiset tiedot: vain käyttäjä itse ja ylläpitäjät
create table if not exists public.profile_private (
  id         uuid primary key references public.profiles(id) on delete cascade,
  phone      text check (phone is null or phone ~ '^\+?[0-9][0-9 ()-]{5,19}$'),
  updated_at timestamptz not null default now()
);

-- Lajit: perusdata (seed alla) + käyttäjien lisäämät
create table if not exists public.activities (
  id          text primary key check (id ~ '^[a-z0-9_]{2,40}$'),
  name        text not null check (char_length(name) between 2 and 28),
  emoji       text not null default '✨' check (char_length(emoji) between 1 and 16 and emoji !~ '[<>&"''\\]'),
  hue         int  not null default 260 check (hue between 0 and 359),
  is_crazy    boolean not null default false,
  crazy_level smallint not null default 0 check (crazy_level between 0 and 3),
  is_adult    boolean not null default false,
  is_custom   boolean not null default true,
  sort_order  int not null default 1000,
  created_by  uuid default auth.uid() references public.profiles(id) on delete set null,
  created_at  timestamptz not null default now()
);
create unique index if not exists activities_name_lower_key on public.activities (lower(name));

-- Tapahtumat
create table if not exists public.events (
  id               uuid primary key default gen_random_uuid(),
  host_id          uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  activity_id      text not null references public.activities(id) on update cascade,
  title            text not null check (char_length(title) between 3 and 60),
  description      text not null default '' check (char_length(description) <= 600),
  starts_at        timestamptz not null,
  city             text not null check (char_length(city) between 1 and 40),
  district         text not null default '' check (char_length(district) <= 40),
  place            text not null check (char_length(place) between 2 and 70),
  lat              double precision check (lat between -90 and 90),
  lng              double precision check (lng between -180 and 180),
  max_participants int null default null check (max_participants is null or max_participants between 2 and 100000),
  skill_level      text not null default 'all' check (skill_level in ('all','beginner','intermediate','advanced')),
  is_crazy         boolean not null default false,
  crazy_level      smallint not null default 0 check (crazy_level between 0 and 3),
  is_adult         boolean not null default false,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create index if not exists events_city_starts_idx on public.events (lower(city), starts_at);
create index if not exists events_starts_idx on public.events (starts_at);
create index if not exists events_host_idx on public.events (host_id);
create index if not exists events_activity_idx on public.events (activity_id);

create table if not exists public.event_participants (
  event_id  uuid not null references public.events(id) on delete cascade,
  user_id   uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (event_id, user_id)
);
create index if not exists event_participants_user_idx on public.event_participants (user_id);

-- Tehdään yhdessä hyvää: avunpyynnöt (aina ilmaisia, ei hintoja)
create table if not exists public.help_requests (
  id                uuid primary key default gen_random_uuid(),
  requester_id      uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  category          text not null check (category in ('siivous','maalaus','koira','kuljetus','seura','muutto','kauppa','piha','muu')),
  title             text not null check (char_length(title) between 4 and 70),
  description       text not null check (char_length(description) between 10 and 1500),
  needs             text not null default '' check (char_length(needs) <= 100),
  city              text not null check (char_length(city) between 1 and 40),
  district          text not null check (char_length(district) between 1 and 40),
  place             text not null default '' check (char_length(place) <= 70),
  lat               double precision not null check (lat between -90 and 90),
  lng               double precision not null check (lng between -180 and 180),
  dest_lat          double precision check (dest_lat between -90 and 90),
  dest_lng          double precision check (dest_lng between -180 and 180),
  dest_label        text check (char_length(dest_label) <= 60),
  starts_at         timestamptz not null,
  duration          text not null default '' check (char_length(duration) <= 30),
  helpers_needed    int not null default 1 check (helpers_needed between 1 and 10),
  status            text not null default 'pending' check (status in ('pending','info','approved','rejected','closed')),
  admin_reason      text not null default '' check (char_length(admin_reason) <= 300),
  consent_voluntary boolean not null default false,
  consent_terms     boolean not null default false,
  consent_review    boolean not null default false,
  email_verified    boolean not null default false,   -- tilannekuva lähetyshetkellä
  history           jsonb not null default '[]'::jsonb,
  reviewed_by       uuid references public.profiles(id) on delete set null,
  reviewed_at       timestamptz,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  constraint help_requests_consents check (consent_voluntary and consent_terms and consent_review),
  constraint help_requests_no_prices check (title !~ '€' and description !~ '€' and needs !~ '€'),
  constraint help_requests_dest check (category <> 'kuljetus' or (dest_lat is not null and dest_lng is not null and coalesce(dest_label,'') <> ''))
);
create index if not exists help_requests_status_idx on public.help_requests (status, starts_at);
create index if not exists help_requests_requester_idx on public.help_requests (requester_id);

-- Pyytäjän yhteystiedot: näkyvät vain pyytäjälle, ylläpitäjille ja hyväksytyille auttajille
create table if not exists public.help_request_contacts (
  request_id   uuid primary key references public.help_requests(id) on delete cascade,
  contact_name text not null check (char_length(contact_name) between 2 and 40),
  phone        text not null check (phone ~ '^\+?[0-9][0-9 ()-]{5,19}$'),
  email        text not null check (char_length(email) between 3 and 254 and position('@' in email) > 1),
  created_at   timestamptz not null default now()
);

-- Avuntarjoukset (tarjous = hyväksytty auttaja, kunnes paikat täynnä)
create table if not exists public.help_offers (
  request_id uuid not null references public.help_requests(id) on delete cascade,
  helper_id  uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (request_id, helper_id)
);
create index if not exists help_offers_helper_idx on public.help_offers (helper_id);

-- Chatit: yksi keskustelu per tapahtuma / avunpyyntö
create table if not exists public.conversations (
  id              uuid primary key default gen_random_uuid(),
  kind            text not null check (kind in ('event','help')),
  event_id        uuid unique references public.events(id) on delete cascade,
  help_request_id uuid unique references public.help_requests(id) on delete cascade,
  created_at      timestamptz not null default now(),
  constraint conversations_target check (
    (kind = 'event' and event_id is not null and help_request_id is null) or
    (kind = 'help'  and help_request_id is not null and event_id is null))
);

create table if not exists public.messages (
  id              uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id       uuid references public.profiles(id) on delete set null,  -- null = järjestelmäviesti
  kind            text not null default 'user' check (kind in ('user','system')),
  body            text not null check (char_length(body) between 1 and 1000),
  code            text check (code is null or code ~ '^[a-z_]{2,40}$'),   -- järjestelmäviestin käännösavain
  params          jsonb not null default '{}'::jsonb,
  created_at      timestamptz not null default now()
);
alter table public.messages add column if not exists code text check (code is null or code ~ '^[a-z_]{2,40}$');
alter table public.messages add column if not exists params jsonb not null default '{}'::jsonb;
create index if not exists messages_conv_created_idx on public.messages (conversation_id, created_at);

create table if not exists public.conversation_reads (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id         uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  last_read_at    timestamptz not null default now(),
  primary key (conversation_id, user_id)
);

create table if not exists public.notifications (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles(id) on delete cascade,
  icon       text not null default '🔔' check (char_length(icon) <= 16),
  body       text not null check (char_length(body) <= 500),
  link_kind  text check (link_kind in ('request','help','chat','event','admin')),
  link_id    uuid,
  code       text check (code is null or code ~ '^[a-z_]{2,40}$'),        -- käännösavain (client kääntää)
  params     jsonb not null default '{}'::jsonb,
  read_at    timestamptz,
  created_at timestamptz not null default now()
);
alter table public.notifications add column if not exists code text check (code is null or code ~ '^[a-z_]{2,40}$');
alter table public.notifications add column if not exists params jsonb not null default '{}'::jsonb;
-- skill_level: vakaat avaimet (käännetään clientissä)
do $$ begin
  if exists (select 1 from pg_constraint where conname = 'events_skill_level_check'
             and pg_get_constraintdef(oid) like '%Kaikki tasot%') then
    alter table public.events drop constraint events_skill_level_check;
    update public.events set skill_level = case skill_level when 'Aloittelija' then 'beginner' when 'Keskitaso' then 'intermediate' when 'Kokenut' then 'advanced' else 'all' end;
    alter table public.events alter column skill_level set default 'all';
    alter table public.events add constraint events_skill_level_check check (skill_level in ('all','beginner','intermediate','advanced'));
  end if;
end $$;
create index if not exists notifications_user_created_idx on public.notifications (user_id, created_at desc);

-- ---------------------------------------------------------------------
-- 1b. JULKISET TAPAHTUMAT (ylläpidon kuratoimat) JA YRITYSTEN TAPAHTUMAT
--     events.kind: 'community' = käyttäjän oma tapahtuma (järjestäjä = host_id)
--                  'public'    = ylläpidon lisäämä julkinen tapahtuma (juoksut, festivaalit, markkinat…);
--                                ei henkilöjärjestäjää (host_id null), ulkoinen järjestäjä + virallinen linkki
--                  'business'  = yrityksen tapahtuma (businesses); ei henkilöä näkyvissä (host_id null)
-- ---------------------------------------------------------------------

-- Suomalaisen Y-tunnuksen tarkiste (muoto 1234567-8, painot 7,9,10,5,8,4,2; mod 11)
create or replace function public.valid_y_tunnus(t text) returns boolean
language plpgsql immutable as $$
declare w int[] := array[7,9,10,5,8,4,2]; s int := 0; r int; c int;
begin
  if t is null or t !~ '^[0-9]{7}-[0-9]$' then return false; end if;
  for i in 1..7 loop s := s + substr(t, i, 1)::int * w[i]; end loop;
  r := s % 11;
  if r = 1 then return false; end if;
  c := case when r = 0 then 0 else 11 - r end;
  return c = substr(t, 9, 1)::int;
end $$;

-- "Tänään" Suomen aikaa (tilauksen voimassaolo on päiväkohtainen)
create or replace function public.today_fi() returns date
language sql stable as $$ select (now() at time zone 'Europe/Helsinki')::date $$;

-- Yrityksen julkinen profiili (EI henkilön profiili). Yhteys- ja laskutustiedot erillisessä taulussa.
create table if not exists public.businesses (
  id                        uuid primary key default gen_random_uuid(),
  name                      text not null check (char_length(name) between 2 and 80),
  business_code             text not null check (char_length(business_code) between 2 and 40),  -- Y-tunnus / business ID
  country                   text not null default 'FI' check (country ~ '^[A-Z]{2}$'),
  logo_url                  text not null default '' check (logo_url = '' or (logo_url ~ '^https://[^\s<>"'']+$' and char_length(logo_url) <= 400)),
  website                   text not null default '' check (website = '' or (website ~ '^https://[^\s<>"'']+$' and char_length(website) <= 300)),
  description               text not null default '' check (char_length(description) <= 500),
  status                    text not null default 'pending' check (status in ('pending','approved','rejected')),
  admin_reason              text not null default '' check (char_length(admin_reason) <= 300),
  subscription_active_until date,                       -- ylläpito asettaa laskutuksen jälkeen (esim. +1 kk)
  expiring_notified_for     date,                       -- sisäinen: "päättyy pian" -ilmoitus lähetetty tälle päivälle
  expired_notified_for      date,                       -- sisäinen: "päättyi" -ilmoitus lähetetty tälle päivälle
  consent_terms             boolean not null default false,
  created_by                uuid default auth.uid() references public.profiles(id) on delete set null,
  reviewed_by               uuid references public.profiles(id) on delete set null,
  reviewed_at               timestamptz,
  created_at                timestamptz not null default now(),
  updated_at                timestamptz not null default now(),
  constraint businesses_terms check (consent_terms),
  constraint businesses_fi_code check (country <> 'FI' or public.valid_y_tunnus(business_code))
);
create unique index if not exists businesses_code_active_key on public.businesses (country, upper(business_code))
  where status in ('pending','approved');
create index if not exists businesses_status_idx on public.businesses (status, subscription_active_until);

-- Yhteys- ja laskutustiedot: vain yrityksen jäsenet ja ylläpito (ei koskaan vierailijoille)
create table if not exists public.business_private (
  business_id     uuid primary key references public.businesses(id) on delete cascade,
  contact_email   text not null check (char_length(contact_email) between 3 and 254 and position('@' in contact_email) > 1),
  phone           text not null check (phone ~ '^\+?[0-9][0-9 ()-]{5,19}$'),
  billing_address text not null default '' check (char_length(billing_address) <= 300),
  e_invoice       text not null default '' check (char_length(e_invoice) <= 120),   -- verkkolaskuosoite + välittäjä
  updated_at      timestamptz not null default now(),
  constraint business_private_billing check (char_length(btrim(billing_address)) >= 5 or char_length(btrim(e_invoice)) >= 5)
);

-- Yrityksen omistajat (henkilöt) – eivät näy tapahtumissa
create table if not exists public.business_members (
  business_id uuid not null references public.businesses(id) on delete cascade,
  user_id     uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  role        text not null default 'owner' check (role in ('owner','editor')),
  created_at  timestamptz not null default now(),
  primary key (business_id, user_id)
);
create index if not exists business_members_user_idx on public.business_members (user_id);

-- Tapahtumien uudet kentät
alter table public.events add column if not exists kind text not null default 'community';
alter table public.events add column if not exists ends_at timestamptz;
alter table public.events add column if not exists organizer_name text not null default '';
alter table public.events add column if not exists official_url text not null default '';
alter table public.events add column if not exists price_info text not null default '';
alter table public.events add column if not exists business_id uuid;
alter table public.events add column if not exists last_at timestamptz generated always as (coalesce(ends_at, starts_at)) stored;
alter table public.events alter column host_id drop not null;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'events_business_id_fkey') then
    alter table public.events add constraint events_business_id_fkey
      foreign key (business_id) references public.businesses(id) on delete cascade;
  end if;
end $$;
alter table public.events drop constraint if exists events_kind_check;
alter table public.events add constraint events_kind_check check (kind in ('community','public','business'));
alter table public.events drop constraint if exists events_kind_fields;
alter table public.events add constraint events_kind_fields check (
  (kind = 'community' and host_id is not null and business_id is null and organizer_name = '' and official_url = '' and price_info = '')
  or (kind = 'public' and host_id is null and business_id is null and char_length(organizer_name) >= 2)
  or (kind = 'business' and host_id is null and business_id is not null));
alter table public.events drop constraint if exists events_organizer_name_check;
alter table public.events add constraint events_organizer_name_check check (char_length(organizer_name) <= 80);
alter table public.events drop constraint if exists events_official_url_check;
alter table public.events add constraint events_official_url_check check (
  official_url = '' or (official_url ~ '^https://[^\s<>"'']+$' and char_length(official_url) <= 300));
alter table public.events drop constraint if exists events_price_info_check;
alter table public.events add constraint events_price_info_check check (char_length(price_info) <= 120);
alter table public.events drop constraint if exists events_ends_check;
alter table public.events add constraint events_ends_check check (
  ends_at is null or (ends_at >= starts_at and ends_at <= starts_at + interval '62 days'));
alter table public.events drop constraint if exists events_max_participants_check;
alter table public.events add constraint events_max_participants_check check (
  (max_participants is null or max_participants between 2 and 100000) and (max_participants is null or kind <> 'community' or max_participants <= 50));
alter table public.events drop constraint if exists events_description_check;
alter table public.events add constraint events_description_check check (
  char_length(description) <= case when kind = 'community' then 600 else 2000 end);
create index if not exists events_last_idx on public.events (last_at);
create index if not exists events_business_idx on public.events (business_id);

-- Ilmoitusten linkit: myös yritystili
alter table public.notifications drop constraint if exists notifications_link_kind_check;
alter table public.notifications add constraint notifications_link_kind_check
  check (link_kind in ('request','help','chat','event','admin','business'));

-- ---------------------------------------------------------------------
-- 1c. MAINOSTUSSUOJA JA MODEROINTI
--     Tavalliset tapahtumat ovat yksityishenkilöiden yhteisiä menoja: niissä ei saa mainostaa yritystä tai
--     maksullista palvelua (yrityksille on maksullinen yritystili). Tarkistus: looks_commercial() alla,
--     sama sääntö sovelluksessa (AD_RE). Kulujen jakaminen on sallittua ("omakustanteinen", "jaetaan kulut").
--     Ilmoitukset (reports) → ylläpito voi poistaa tapahtuman, varoittaa tai estää käyttäjän (profiles.banned).
-- ---------------------------------------------------------------------
alter table public.profiles add column if not exists banned boolean not null default false;   -- vain ylläpito (RPC)

create or replace function public.looks_commercial(t text) returns boolean
language sql immutable as $$
  select coalesce(
       lower(t) ~ '(https?://|www\.)'
    or lower(t) ~ '[a-z0-9-]\.(com|fi|se|es|net|org|io|eu|uk|info|biz|shop|store|online|app)([^a-z0-9]|$)'
    or lower(t) ~ '[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}'
    or t ~ '(^|[^0-9])(\+|00)?[0-9]([ ()-]?[0-9]){6,}'
    or t ~ '€'
    or t ~ '(^|[^0-9])-[0-9]{1,2} ?%'
    or lower(t) ~ '(alennus|alennuk|rabatt|descuento|discount)'
    or lower(t) ~ ('(^|[^a-z0-9åäöéáíóúñüç])('
         || 'eur|euro|euroa|euron|euroja|euros|hinta[a-z]*|hinnat|hinnoit[a-z]*|alennus[a-z]*|alennuk[a-z]*|tarjous[a-z]*|tarjoukse[a-z]*'
         || '|varaa|varaus[a-z]*|varauks[a-z]*|osta|ostaa|myynti[a-z]*|myynnissä|myydään|kampanj[a-z]*'
         || '|price|prices|pricing|discount[a-z]*|buy|book now|promo[a-z]*|coupon[a-z]*'
         || '|precio|precios|oferta|ofertas|descuento|descuentos|rebaja|rebajas|cupón|cupon'
         || '|pris|priser|rabatt[a-z]*|erbjudande[a-z]*|köp|köpa|boka|rea'
         || ')($|[^a-z0-9åäöéáíóúñüç])')
  , false)
$$;

create or replace function public.is_banned() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select p.banned from public.profiles p where p.id = auth.uid()), false)
$$;

-- Ilmoitukset asiattomasta sisällöstä (nyt: tapahtumat)
create table if not exists public.reports (
  id          uuid primary key default gen_random_uuid(),
  reporter_id uuid default auth.uid() references public.profiles(id) on delete set null,
  target_type text not null default 'event' check (target_type in ('event')),
  target_id   uuid not null,
  reason      text not null check (reason in ('business_ad','inappropriate','spam','other')),
  note        text not null default '' check (char_length(note) <= 300),
  status      text not null default 'open' check (status in ('open','resolved','dismissed')),
  resolved_by uuid references public.profiles(id) on delete set null,
  resolved_at timestamptz,
  created_at  timestamptz not null default now()
);
create unique index if not exists reports_once_key on public.reports (reporter_id, target_type, target_id);
create index if not exists reports_status_idx on public.reports (status, created_at);

-- ---------------------------------------------------------------------
-- 2. APUFUNKTIOT
-- ---------------------------------------------------------------------

create or replace function public.set_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

-- Onko kutsuja ylläpitäjä?
create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select p.is_admin from public.profiles p where p.id = auth.uid()), false)
$$;

-- Saako kutsuja tarjota apua? (vahvistettu sähköposti + ilmoitettu puhelinnumero)
create or replace function public.can_help() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.profiles p
    join public.profile_private pp on pp.id = p.id
    where p.id = auth.uid() and p.email_verified and coalesce(pp.phone, '') <> '')
$$;

create or replace function public.is_helper(rid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.help_offers o where o.request_id = rid and o.helper_id = auth.uid())
$$;

create or replace function public.is_conversation_member(cid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.conversations c
    where c.id = cid and (
      (c.event_id is not null and exists (
         select 1 from public.event_participants p where p.event_id = c.event_id and p.user_id = auth.uid()))
      or
      (c.help_request_id is not null and exists (
         select 1 from public.help_requests h
         where h.id = c.help_request_id and h.status in ('approved','closed')
           and (h.requester_id = auth.uid() or exists (
                 select 1 from public.help_offers o where o.request_id = h.id and o.helper_id = auth.uid()))))
    ))
$$;

-- Yritystilin jäsen / aktiivinen tilaus (hyväksytty + voimassa tänään tai myöhemmin)
create or replace function public.is_business_member(bid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.business_members m where m.business_id = bid and m.user_id = auth.uid())
$$;
create or replace function public.business_active(bid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.businesses b where b.id = bid and b.status = 'approved'
                 and b.subscription_active_until is not null and b.subscription_active_until >= public.today_fi())
$$;
-- Saako kutsuja julkaista yrityksen tapahtuman? (aktiivinen tilaus + jäsen tai ylläpitäjä)
create or replace function public.business_can_post(bid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select public.business_active(bid) and (public.is_business_member(bid) or public.is_admin())
$$;

-- 18+-tunnistus (alkoholi / alastomuus) – sama sääntö kuin sovelluksessa
create or replace function public.looks_adult(t text) returns boolean
language sql immutable as $$
  select coalesce(lower(t) ~ '(naku|alasti|alaston|konjak|viini|olut|oluen|kalja|bisse|shamp|kuohu|cocktail|drinkk|viski|siideri|lonkero|känn|kossu|vodka|rommi|punssi|pubi|baari|wine|beer|naked|nude|nudis|whisk|brandy|cognac|cerveza|desnud|sangr[ií]a|tequila|naken|nakna|nakenbad|(^|[^a-z])vino)', false)
$$;

create or replace function public.display_name_of(uid uuid) returns text
language sql stable security definer set search_path = public as $$
  select coalesce(nullif((select p.display_name from public.profiles p where p.id = uid), ''), 'Joku')
$$;

-- Ilmoitukset ja järjestelmäviestit tallennetaan käännösavaimella (code) + parametreilla (params);
-- client näyttää ne käyttäjän kielellä. body = suomenkielinen varateksti.
drop function if exists public.notify(uuid, text, text, text, uuid);
drop function if exists public.notify_admins(text, text, text, uuid);
drop function if exists public.post_system_message(uuid, text);

create or replace function public.notify(uid uuid, ic text, cd text, prm jsonb, txt text, lk text, lid uuid) returns void
language sql security definer set search_path = public as $$
  insert into public.notifications (user_id, icon, code, params, body, link_kind, link_id)
  select uid, ic, cd, coalesce(prm, '{}'::jsonb), left(txt, 500), lk, lid where uid is not null
$$;

create or replace function public.notify_admins(ic text, cd text, prm jsonb, txt text, lk text, lid uuid) returns void
language sql security definer set search_path = public as $$
  insert into public.notifications (user_id, icon, code, params, body, link_kind, link_id)
  select p.id, ic, cd, coalesce(prm, '{}'::jsonb), left(txt, 500), lk, lid from public.profiles p where p.is_admin
$$;

create or replace function public.post_system_message(cid uuid, cd text, prm jsonb, txt text) returns void
language sql security definer set search_path = public as $$
  insert into public.messages (conversation_id, sender_id, kind, code, params, body)
  select cid, null, 'system', cd, coalesce(prm, '{}'::jsonb), left(txt, 1000) where cid is not null
$$;

-- ---------------------------------------------------------------------
-- 3. TRIGGERIT
-- ---------------------------------------------------------------------

-- 3a. Profiili luodaan automaattisesti rekisteröityessä
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, display_name, email_verified)
  values (new.id, coalesce(left(new.raw_user_meta_data->>'display_name', 40), ''), new.email_confirmed_at is not null)
  on conflict (id) do nothing;
  insert into public.profile_private (id) values (new.id) on conflict (id) do nothing;
  return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- 3b. Sähköpostin vahvistus synkronoidaan profiiliin
create or replace function public.handle_user_email_confirmed() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  update public.profiles set email_verified = (new.email_confirmed_at is not null) where id = new.id;
  return new;
end $$;
drop trigger if exists on_auth_user_email_confirmed on auth.users;
create trigger on_auth_user_email_confirmed after update of email_confirmed_at on auth.users
  for each row execute function public.handle_user_email_confirmed();

-- 3c. Käyttäjä ei voi muuttaa is_admin / email_verified -kenttiä API:n kautta
create or replace function public.profiles_protect() returns trigger
language plpgsql as $$
begin
  if auth.uid() is not null then          -- kutsu tulee sovelluksesta (JWT), ei SQL Editorista
    if tg_op = 'INSERT' then
      new.is_admin := false;
      new.email_verified := false;
      new.banned := false;
    else
      new.id := old.id;
      new.is_admin := old.is_admin;
      new.email_verified := old.email_verified;
      new.created_at := old.created_at;
      -- esto muuttuu vain ylläpidon RPC:llä (security definer → current_user ei ole authenticated)
      if current_user in ('authenticated', 'anon') then new.banned := old.banned; end if;
    end if;
  end if;
  return new;
end $$;
drop trigger if exists profiles_protect on public.profiles;
create trigger profiles_protect before insert or update on public.profiles
  for each row execute function public.profiles_protect();
drop trigger if exists profiles_updated_at on public.profiles;
create trigger profiles_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();
drop trigger if exists profile_private_updated_at on public.profile_private;
create trigger profile_private_updated_at before update on public.profile_private
  for each row execute function public.set_updated_at();

-- 3d. Lajit: käyttäjän lisäämät ovat aina "custom"; 18+ tunnistetaan nimestä
create or replace function public.activities_before_write() returns trigger
language plpgsql as $$
begin
  if auth.uid() is not null and not public.is_admin() then
    if tg_op = 'INSERT' then
      new.is_custom := true;
      new.created_by := auth.uid();
      new.sort_order := 1000;
      new.created_at := now();
    end if;
  end if;
  new.name := btrim(regexp_replace(new.name, '\s+', ' ', 'g'));
  if public.looks_adult(new.name) then new.is_adult := true; end if;
  if new.is_crazy and new.crazy_level = 0 then new.crazy_level := 2; end if;
  if not new.is_crazy then new.crazy_level := 0; end if;
  return new;
end $$;
drop trigger if exists activities_before_write on public.activities;
create trigger activities_before_write before insert or update on public.activities
  for each row execute function public.activities_before_write();

-- 3e. Tapahtumat: hullu/18+-liput lajin ja otsikon perusteella, järjestäjä = kutsuja.
--     Julkiset tapahtumat vain ylläpidolle; yritystapahtumat vain aktiivisen tilauksen yrityksille.
--     Julkisissa ja yritystapahtumissa ei ole henkilöjärjestäjää (host_id = null).
create or replace function public.events_before_write() returns trigger
language plpgsql as $$
declare a record;
begin
  if tg_op = 'UPDATE' then
    new.kind := old.kind;                 -- tyyppiä / yritystä ei voi vaihtaa jälkikäteen
    new.business_id := old.business_id;
  end if;
  new.kind := coalesce(new.kind, 'community');
  if auth.uid() is not null then
    if public.is_banned() then
      raise exception 'account_banned' using errcode = 'P0001';
    end if;
    -- tavalliset tapahtumat: ei yritysmainontaa, linkkejä, yhteystietoja eikä hintoja (yrityksille on yritystili)
    if new.kind = 'community' and not public.is_admin()
       and (public.looks_commercial(new.title) or public.looks_commercial(new.description)) then
      raise exception 'commercial_content' using errcode = 'P0001';
    end if;
    if new.kind = 'public' and not public.is_admin() then
      raise exception 'public_event_admin_only' using errcode = 'P0001';
    end if;
    if new.kind = 'business' and (tg_op = 'INSERT' or not public.is_admin())
       and not public.business_can_post(new.business_id) then
      raise exception 'business_subscription_required' using errcode = 'P0001';
    end if;
    if tg_op = 'INSERT' then
      new.created_at := now();
      if new.kind = 'community' and not public.is_admin() then new.host_id := auth.uid(); end if;
      if not public.is_admin() and new.starts_at < now() - interval '10 minutes' then
        raise exception 'event_in_past' using errcode = 'P0001';
      end if;
    else
      new.created_at := old.created_at;
      if not public.is_admin() then new.host_id := old.host_id; end if;
    end if;
  end if;
  if new.kind <> 'community' then new.host_id := null; end if;
  new.organizer_name := btrim(coalesce(new.organizer_name, ''));
  new.official_url := btrim(coalesce(new.official_url, ''));
  new.price_info := btrim(coalesce(new.price_info, ''));
  select * into a from public.activities where id = new.activity_id;
  if found then
    new.is_crazy := new.is_crazy or a.is_crazy;
    new.is_adult := new.is_adult or a.is_adult;
    if new.is_crazy and new.crazy_level = 0 then new.crazy_level := coalesce(nullif(a.crazy_level, 0), 2); end if;
  end if;
  if public.looks_adult(new.title) then new.is_adult := true; end if;
  if not new.is_crazy then new.crazy_level := 0; end if;
  return new;
end $$;
drop trigger if exists events_before_write on public.events;
create trigger events_before_write before insert or update on public.events
  for each row execute function public.events_before_write();
drop trigger if exists events_updated_at on public.events;
create trigger events_updated_at before update on public.events
  for each row execute function public.set_updated_at();

-- Uusi tapahtuma → chat + järjestäjä osallistujaksi + tervetuloviesti
-- (julkisissa / yritystapahtumissa ei järjestäjähenkilöä: chat on "Etsi seuraa" -keskustelu)
create or replace function public.events_after_insert() returns trigger
language plpgsql security definer set search_path = public as $$
declare cid uuid;
begin
  insert into public.conversations (kind, event_id) values ('event', new.id)
    on conflict (event_id) do nothing returning id into cid;
  if new.host_id is not null then
    insert into public.event_participants (event_id, user_id) values (new.id, new.host_id)
      on conflict do nothing;
  end if;
  if new.kind = 'community' then
    perform public.post_system_message(cid, 'event_created', '{}'::jsonb, 'Tapahtuma luotu – toivota osallistujat tervetulleiksi! 👋');
  else
    perform public.post_system_message(cid, 'find_company', '{}'::jsonb, 'Etsi seuraa: kerro täällä, milloin ja mistä lähdet – sovitaan yhteinen lähtö! 👋');
  end if;
  return new;
end $$;
drop trigger if exists events_after_insert on public.events;
create trigger events_after_insert after insert on public.events
  for each row execute function public.events_after_insert();

-- 3f. Osallistuminen: kapasiteetti, järjestelmäviestit, ilmoitus järjestäjälle
create or replace function public.participants_before_insert() returns trigger
language plpgsql security definer set search_path = public as $$
declare e record; n int;
begin
  select * into e from public.events where id = new.event_id for update;
  if not found then raise exception 'event_not_found' using errcode = 'P0001'; end if;
  if new.user_id is distinct from e.host_id then
    if coalesce(e.ends_at, e.starts_at) < now() - interval '1 hour' then
      raise exception 'event_in_past' using errcode = 'P0001';
    end if;
    select count(*) into n from public.event_participants where event_id = new.event_id;
    if e.max_participants is not null and n >= e.max_participants then
      raise exception 'event_full' using errcode = 'P0001';
    end if;
  end if;
  new.joined_at := now();
  return new;
end $$;
drop trigger if exists participants_before_insert on public.event_participants;
create trigger participants_before_insert before insert on public.event_participants
  for each row execute function public.participants_before_insert();

create or replace function public.participants_after_change() returns trigger
language plpgsql security definer set search_path = public as $$
declare e record; cid uuid; nm text;
begin
  if tg_op = 'INSERT' then
    select * into e from public.events where id = new.event_id;
    if not found or new.user_id = e.host_id then return null; end if;
    select id into cid from public.conversations where event_id = new.event_id;
    nm := public.display_name_of(new.user_id);
    perform public.post_system_message(cid, 'joined', jsonb_build_object('name', nm), nm || ' liittyi mukaan 🎉');
    perform public.notify(e.host_id, '🙌', 'joined_your_event', jsonb_build_object('name', nm, 'title', e.title), nm || ' liittyi tapahtumaasi “' || e.title || '”', 'event', e.id);
  else
    select * into e from public.events where id = old.event_id;
    if not found then return null; end if;            -- tapahtuma poistettu (cascade)
    select id into cid from public.conversations where event_id = old.event_id;
    perform public.post_system_message(cid, 'left', jsonb_build_object('name', public.display_name_of(old.user_id)), public.display_name_of(old.user_id) || ' perui osallistumisen');
  end if;
  return null;
end $$;
drop trigger if exists participants_after_change on public.event_participants;
create trigger participants_after_change after insert or delete on public.event_participants
  for each row execute function public.participants_after_change();

-- 3g. Avunpyynnöt
create or replace function public.help_requests_before_insert() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null then
    new.requester_id := auth.uid();
    new.status := 'pending';
    new.admin_reason := '';
    new.reviewed_by := null;
    new.reviewed_at := null;
    new.created_at := now();
    if not coalesce((select email_verified from public.profiles where id = auth.uid()), false) then
      raise exception 'email_not_verified' using errcode = 'P0001';
    end if;
    if new.starts_at < now() - interval '10 minutes' then
      raise exception 'request_in_past' using errcode = 'P0001';
    end if;
  end if;
  new.email_verified := coalesce((select email_verified from public.profiles where id = new.requester_id), false);
  new.history := jsonb_build_array(jsonb_build_object('s', 'sent', 't', now()));
  return new;
end $$;
drop trigger if exists help_requests_before_insert on public.help_requests;
create trigger help_requests_before_insert before insert on public.help_requests
  for each row execute function public.help_requests_before_insert();

create or replace function public.help_requests_before_update() returns trigger
language plpgsql as $$
declare wanted text;
begin
  if auth.uid() is not null and not public.is_admin() then
    -- pyytäjä: saa täydentää pending/info-tilassa, lähettää uudelleen (info → pending) tai sulkea
    wanted := new.status;
    if old.status in ('approved','rejected','closed') then
      new := old;
      if wanted = 'closed' and old.status = 'approved' then new.status := 'closed'; end if;
    else
      new.requester_id := old.requester_id;
      new.email_verified := old.email_verified;
      new.reviewed_by := old.reviewed_by;
      new.reviewed_at := old.reviewed_at;
      new.created_at := old.created_at;
      new.history := old.history;
      new.admin_reason := old.admin_reason;
      if wanted is distinct from old.status then
        if not ((wanted = 'pending' and old.status = 'info') or wanted = 'closed') then
          raise exception 'status_change_not_allowed' using errcode = 'P0001';
        end if;
      end if;
    end if;
    if new.status = 'pending' and old.status = 'info' then new.admin_reason := ''; end if;
  elsif auth.uid() is not null then
    if new.status is distinct from old.status then
      new.reviewed_by := auth.uid();
      new.reviewed_at := now();
    end if;
  end if;
  if new.status is distinct from old.status then
    new.history := old.history || jsonb_build_array(jsonb_build_object(
      's', case when old.status = 'info' and new.status = 'pending' then 'resub' else new.status end,
      't', now()));
  end if;
  new.updated_at := now();
  return new;
end $$;
drop trigger if exists help_requests_before_update on public.help_requests;
create trigger help_requests_before_update before update on public.help_requests
  for each row execute function public.help_requests_before_update();

create or replace function public.help_requests_after_insert() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.conversations (kind, help_request_id) values ('help', new.id)
    on conflict (help_request_id) do nothing;
  perform public.notify(new.requester_id, '📨', 'request_sent', jsonb_build_object('title', new.title), 'Pyyntösi “' || new.title || '” on lähetetty ja odottaa hyväksyntää.', 'request', new.id);
  perform public.notify_admins('🛡️', 'admin_new_request', jsonb_build_object('title', new.title), 'Uusi avunpyyntö odottaa tarkistusta: “' || new.title || '”', 'admin', new.id);
  return null;
end $$;
drop trigger if exists help_requests_after_insert on public.help_requests;
create trigger help_requests_after_insert after insert on public.help_requests
  for each row execute function public.help_requests_after_insert();

-- Pyynnöllä on oltava yhteystiedot (tarkistetaan transaktion lopussa)
create or replace function public.help_requests_require_contact() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if exists (select 1 from public.help_requests where id = new.id)
     and not exists (select 1 from public.help_request_contacts where request_id = new.id) then
    raise exception 'contact_required' using errcode = 'P0001';
  end if;
  return null;
end $$;
drop trigger if exists help_requests_require_contact on public.help_requests;
create constraint trigger help_requests_require_contact after insert on public.help_requests
  deferrable initially deferred
  for each row execute function public.help_requests_require_contact();

create or replace function public.help_requests_after_update() returns trigger
language plpgsql security definer set search_path = public as $$
declare cid uuid; r record;
begin
  if new.status is distinct from old.status then
    if new.status = 'approved' then
      perform public.notify(new.requester_id, '✅', 'request_approved', jsonb_build_object('title', new.title), 'Pyyntösi on hyväksytty ja julkaistu 💚 “' || new.title || '”', 'help', new.id);
    elsif new.status = 'rejected' then
      perform public.notify(new.requester_id, '❌', 'request_rejected', jsonb_build_object('title', new.title, 'reason', new.admin_reason), 'Pyyntöäsi “' || new.title || '” ei julkaistu. Syy: ' || new.admin_reason, 'request', new.id);
    elsif new.status = 'info' then
      perform public.notify(new.requester_id, '❓', 'request_info', jsonb_build_object('title', new.title, 'reason', new.admin_reason), 'Ylläpito pyytää lisätietoja pyyntöösi “' || new.title || '”: ' || new.admin_reason, 'request', new.id);
    elsif new.status = 'pending' and old.status = 'info' then
      perform public.notify_admins('🔁', 'admin_resubmitted', jsonb_build_object('title', new.title), 'Avunpyyntöä täydennettiin: “' || new.title || '”', 'admin', new.id);
    elsif new.status = 'closed' then
      select id into cid from public.conversations where help_request_id = new.id;
      perform public.post_system_message(cid, 'request_closed', '{}'::jsonb, 'Pyyntö on suljettu – kiitos kaikille avusta! 💚');
      for r in select helper_id from public.help_offers where request_id = new.id loop
        perform public.notify(r.helper_id, '💚', 'request_closed_thanks', jsonb_build_object('title', new.title), 'Pyyntö “' || new.title || '” on suljettu. Kiitos avusta!', 'chat', new.id);
      end loop;
    end if;
  end if;
  return null;
end $$;
drop trigger if exists help_requests_after_update on public.help_requests;
create trigger help_requests_after_update after update on public.help_requests
  for each row execute function public.help_requests_after_update();

-- Yhteystietojen sähköposti = tilin (vahvistettu) sähköposti
create or replace function public.help_contacts_before_insert() returns trigger
language plpgsql security definer set search_path = public as $$
declare em text;
begin
  select u.email into em from auth.users u
    join public.help_requests h on h.requester_id = u.id where h.id = new.request_id;
  if em is not null and em <> '' then new.email := em; end if;
  new.contact_name := btrim(new.contact_name);
  new.phone := btrim(new.phone);
  return new;
end $$;
drop trigger if exists help_contacts_before_insert on public.help_request_contacts;
create trigger help_contacts_before_insert before insert on public.help_request_contacts
  for each row execute function public.help_contacts_before_insert();

-- 3h. Avuntarjoukset: vain hyväksyttyihin, ei omiin, paikkoja rajallisesti, vahvistus vaaditaan
create or replace function public.help_offers_before_insert() returns trigger
language plpgsql security definer set search_path = public as $$
declare h record; n int;
begin
  if auth.uid() is not null then
    new.helper_id := auth.uid();
    if not public.can_help() then
      raise exception 'verification_required' using errcode = 'P0001';
    end if;
  end if;
  select * into h from public.help_requests where id = new.request_id for update;
  if not found or h.status <> 'approved' then raise exception 'request_not_open' using errcode = 'P0001'; end if;
  if h.requester_id = new.helper_id then raise exception 'own_request' using errcode = 'P0001'; end if;
  select count(*) into n from public.help_offers where request_id = new.request_id;
  if n >= h.helpers_needed then raise exception 'request_full' using errcode = 'P0001'; end if;
  new.created_at := now();
  return new;
end $$;
drop trigger if exists help_offers_before_insert on public.help_offers;
create trigger help_offers_before_insert before insert on public.help_offers
  for each row execute function public.help_offers_before_insert();

create or replace function public.help_offers_after_change() returns trigger
language plpgsql security definer set search_path = public as $$
declare h record; cid uuid; nm text;
begin
  if tg_op = 'INSERT' then
    select * into h from public.help_requests where id = new.request_id;
    select id into cid from public.conversations where help_request_id = new.request_id;
    nm := public.display_name_of(new.helper_id);
    perform public.post_system_message(cid, 'offered', jsonb_build_object('name', nm), nm || ' tarjoutui auttamaan 💚');
    perform public.notify(h.requester_id, '🙋', 'offered_your_request', jsonb_build_object('name', nm, 'title', h.title), nm || ' tarjoutui auttamaan pyyntöösi “' || h.title || '”', 'chat', h.id);
  else
    select * into h from public.help_requests where id = old.request_id;
    if not found then return null; end if;
    select id into cid from public.conversations where help_request_id = old.request_id;
    nm := public.display_name_of(old.helper_id);
    perform public.post_system_message(cid, 'withdrew', jsonb_build_object('name', nm), nm || ' perui avuntarjouksen');
    perform public.notify(h.requester_id, 'ℹ️', 'withdrew_your_request', jsonb_build_object('name', nm, 'title', h.title), nm || ' perui avuntarjouksensa pyyntöösi “' || h.title || '”', 'request', h.id);
  end if;
  return null;
end $$;
drop trigger if exists help_offers_after_change on public.help_offers;
create trigger help_offers_after_change after insert or delete on public.help_offers
  for each row execute function public.help_offers_after_change();

-- 3i. Viestit: lähettäjä = kutsuja
create or replace function public.messages_before_insert() returns trigger
language plpgsql as $$
begin
  if auth.uid() is not null and current_user in ('authenticated', 'anon') then
    if public.is_banned() then
      raise exception 'account_banned' using errcode = 'P0001';
    end if;
    new.sender_id := auth.uid();
    new.kind := 'user';
    new.code := null;
    new.params := '{}'::jsonb;
  end if;
  new.body := btrim(new.body);
  new.created_at := now();
  return new;
end $$;
drop trigger if exists messages_before_insert on public.messages;
create trigger messages_before_insert before insert on public.messages
  for each row execute function public.messages_before_insert();

-- 3j. Ilmoitukset: käyttäjä voi muuttaa vain luettu-tilaa
create or replace function public.notifications_before_update() returns trigger
language plpgsql as $$
begin
  if auth.uid() is not null then
    new := old;
    new.read_at := coalesce(old.read_at, now());
  end if;
  return new;
end $$;
drop trigger if exists notifications_before_update on public.notifications;
create trigger notifications_before_update before update on public.notifications
  for each row execute function public.notifications_before_update();

-- 3k. RPC: avunpyyntö + yhteystiedot yhdessä transaktiossa (RLS voimassa)
create or replace function public.submit_help_request(req jsonb, contact jsonb) returns uuid
language plpgsql security invoker set search_path = public as $$
declare rid uuid;
begin
  if auth.uid() is null then raise exception 'not_authenticated' using errcode = 'P0001'; end if;
  insert into public.help_requests (
    category, title, description, needs, city, district, place, lat, lng,
    dest_lat, dest_lng, dest_label, starts_at, duration, helpers_needed,
    consent_voluntary, consent_terms, consent_review)
  values (
    req->>'category', req->>'title', req->>'description', coalesce(req->>'needs', ''),
    req->>'city', req->>'district', coalesce(req->>'place', ''),
    (req->>'lat')::double precision, (req->>'lng')::double precision,
    (req->>'dest_lat')::double precision, (req->>'dest_lng')::double precision, nullif(req->>'dest_label', ''),
    (req->>'starts_at')::timestamptz, coalesce(req->>'duration', ''), coalesce((req->>'helpers_needed')::int, 1),
    coalesce((req->>'consent_voluntary')::boolean, false),
    coalesce((req->>'consent_terms')::boolean, false),
    coalesce((req->>'consent_review')::boolean, false))
  returning id into rid;
  insert into public.help_request_contacts (request_id, contact_name, phone, email)
  values (rid, contact->>'name', contact->>'phone', coalesce(contact->>'email', ''));
  return rid;
end $$;

-- 3l. RPC: oman tilin poisto (poistaa myös kaiken käyttäjän datan cascade-säännöillä)
create or replace function public.delete_my_account() returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated' using errcode = 'P0001'; end if;
  delete from auth.users where id = auth.uid();
end $$;

-- 3m. Yritystilit: hakemus → ylläpito hyväksyy/hylkää → ylläpito asettaa tilauksen voimassaolon (laskutus käsin)
create or replace function public.businesses_before_write() returns trigger
language plpgsql as $$
begin
  if auth.uid() is not null and not public.is_admin() then
    if tg_op = 'INSERT' then
      new.status := 'pending';
      new.admin_reason := '';
      new.subscription_active_until := null;
      new.expiring_notified_for := null;
      new.expired_notified_for := null;
      new.reviewed_by := null;
      new.reviewed_at := null;
      new.created_by := auth.uid();
      new.created_at := now();
      if not coalesce((select email_verified from public.profiles where id = auth.uid()), false) then
        raise exception 'email_not_verified' using errcode = 'P0001';
      end if;
      if (select count(*) from public.businesses where created_by = auth.uid() and status <> 'rejected') >= 3 then
        raise exception 'too_many_businesses' using errcode = 'P0001';
      end if;
    else
      -- jäsen saa päivittää kuvauksen, logon, verkkosivun; hylätyn hakemuksen voi lähettää uudelleen
      new.id := old.id;
      new.created_by := old.created_by;
      new.created_at := old.created_at;
      new.subscription_active_until := old.subscription_active_until;
      new.expiring_notified_for := old.expiring_notified_for;
      new.expired_notified_for := old.expired_notified_for;
      new.reviewed_by := old.reviewed_by;
      new.reviewed_at := old.reviewed_at;
      new.admin_reason := old.admin_reason;
      if old.status = 'approved' then
        new.business_code := old.business_code;
        new.country := old.country;
      end if;
      if new.status is distinct from old.status then
        if not (old.status = 'rejected' and new.status = 'pending') then
          raise exception 'status_change_not_allowed' using errcode = 'P0001';
        end if;
        new.admin_reason := '';
      end if;
    end if;
  elsif auth.uid() is not null and tg_op = 'UPDATE' then
    if new.status is distinct from old.status then
      new.reviewed_by := auth.uid();
      new.reviewed_at := now();
    end if;
  end if;
  if tg_op = 'UPDATE' and new.subscription_active_until is distinct from old.subscription_active_until then
    -- ylläpito päätti tilauksen (päivä menneisyydessä) → erillistä "päättyi"-muistutusta ei enää lähetetä
    if new.subscription_active_until is not null and new.subscription_active_until < public.today_fi() then
      new.expired_notified_for := new.subscription_active_until;
    end if;
  end if;
  new.name := btrim(regexp_replace(coalesce(new.name, ''), '\s+', ' ', 'g'));
  new.business_code := upper(btrim(coalesce(new.business_code, '')));
  new.country := upper(btrim(coalesce(new.country, 'FI')));
  new.logo_url := btrim(coalesce(new.logo_url, ''));
  new.website := btrim(coalesce(new.website, ''));
  new.description := btrim(coalesce(new.description, ''));
  if tg_op = 'UPDATE' then new.updated_at := now(); end if;
  return new;
end $$;
drop trigger if exists businesses_before_write on public.businesses;
create trigger businesses_before_write before insert or update on public.businesses
  for each row execute function public.businesses_before_write();

create or replace function public.businesses_after_insert() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform public.notify_admins('🏢', 'admin_new_business', jsonb_build_object('name', new.name), 'Uusi yritystilihakemus: “' || new.name || '”', 'admin', new.id);
  return null;
end $$;
drop trigger if exists businesses_after_insert on public.businesses;
create trigger businesses_after_insert after insert on public.businesses
  for each row execute function public.businesses_after_insert();

-- Hakemuksella on oltava yhteys- ja laskutustiedot (tarkistetaan transaktion lopussa)
create or replace function public.businesses_require_private() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if exists (select 1 from public.businesses where id = new.id)
     and not exists (select 1 from public.business_private where business_id = new.id) then
    raise exception 'business_contact_required' using errcode = 'P0001';
  end if;
  return null;
end $$;
drop trigger if exists businesses_require_private on public.businesses;
create constraint trigger businesses_require_private after insert on public.businesses
  deferrable initially deferred
  for each row execute function public.businesses_require_private();

-- Ilmoitukset yrityksen omistajille: hyväksytty / hylätty / jatkettu / päätetty
create or replace function public.businesses_after_update() returns trigger
language plpgsql security definer set search_path = public as $$
declare r record; d text;
begin
  if new.status is distinct from old.status then
    if new.status = 'approved' then
      for r in select user_id from public.business_members where business_id = new.id loop
        perform public.notify(r.user_id, '✅', 'business_approved', jsonb_build_object('name', new.name), 'Yritystilisi “' || new.name || '” on hyväksytty 🎉 Tilaus aktivoidaan laskutuksen yhteydessä.', 'business', new.id);
      end loop;
    elsif new.status = 'rejected' then
      for r in select user_id from public.business_members where business_id = new.id loop
        perform public.notify(r.user_id, '❌', 'business_rejected', jsonb_build_object('name', new.name, 'reason', new.admin_reason), 'Yritystilihakemusta “' || new.name || '” ei hyväksytty. Syy: ' || new.admin_reason, 'business', new.id);
      end loop;
    elsif new.status = 'pending' and old.status = 'rejected' then
      perform public.notify_admins('🏢', 'admin_new_business', jsonb_build_object('name', new.name), 'Uusi yritystilihakemus: “' || new.name || '”', 'admin', new.id);
    end if;
  end if;
  if new.subscription_active_until is distinct from old.subscription_active_until and new.status = 'approved' then
    d := to_char(new.subscription_active_until, 'YYYY-MM-DD');
    if new.subscription_active_until is not null and new.subscription_active_until >= public.today_fi() then
      for r in select user_id from public.business_members where business_id = new.id loop
        perform public.notify(r.user_id, '📅', 'business_extended', jsonb_build_object('name', new.name, 'date', d), 'Yritystilin “' || new.name || '” tilaus on voimassa ' || to_char(new.subscription_active_until, 'DD.MM.YYYY') || ' asti.', 'business', new.id);
      end loop;
    else
      for r in select user_id from public.business_members where business_id = new.id loop
        perform public.notify(r.user_id, '⏹️', 'business_ended', jsonb_build_object('name', new.name), 'Yritystilin “' || new.name || '” tilaus on päätetty. Uusia yritystapahtumia ei voi julkaista.', 'business', new.id);
      end loop;
    end if;
  end if;
  return null;
end $$;
drop trigger if exists businesses_after_update on public.businesses;
create trigger businesses_after_update after update on public.businesses
  for each row execute function public.businesses_after_update();

-- Muistutukset: "päättyy 7 päivän sisällä" ja "päättyi". Ajetaan, kun ylläpitäjä avaa yritysjonon
-- (ja päivittäin automaattisesti, jos pg_cron on käytössä – ks. alla).
create or replace function public.business_expiry_sweep() returns int
language plpgsql security definer set search_path = public as $$
declare b record; r record; n int := 0; t date := public.today_fi();
begin
  if auth.uid() is not null and not public.is_admin() then
    raise exception 'admin_only' using errcode = 'P0001';
  end if;
  for b in select * from public.businesses where status = 'approved' and subscription_active_until is not null loop
    if b.subscription_active_until < t and b.expired_notified_for is distinct from b.subscription_active_until then
      for r in select user_id from public.business_members where business_id = b.id loop
        perform public.notify(r.user_id, '⏰', 'business_expired', jsonb_build_object('name', b.name), 'Yritystilin “' || b.name || '” tilaus on päättynyt. Uusia yritystapahtumia ei voi julkaista ennen jatkoa.', 'business', b.id);
      end loop;
      update public.businesses set expired_notified_for = b.subscription_active_until where id = b.id;
      n := n + 1;
    elsif b.subscription_active_until >= t and b.subscription_active_until <= t + 7
          and b.expiring_notified_for is distinct from b.subscription_active_until then
      for r in select user_id from public.business_members where business_id = b.id loop
        perform public.notify(r.user_id, '⏳', 'business_expiring', jsonb_build_object('name', b.name, 'date', to_char(b.subscription_active_until, 'YYYY-MM-DD')), 'Yritystilin “' || b.name || '” tilaus päättyy ' || to_char(b.subscription_active_until, 'DD.MM.YYYY') || '.', 'business', b.id);
      end loop;
      update public.businesses set expiring_notified_for = b.subscription_active_until where id = b.id;
      n := n + 1;
    end if;
  end loop;
  return n;
end $$;

-- 3n. RPC: yritystilihakemus (profiili + omistaja + yhteys-/laskutustiedot yhdessä transaktiossa, RLS voimassa)
create or replace function public.apply_business(biz jsonb, contact jsonb) returns uuid
language plpgsql security invoker set search_path = public as $$
declare bid uuid;
begin
  if auth.uid() is null then raise exception 'not_authenticated' using errcode = 'P0001'; end if;
  insert into public.businesses (name, business_code, country, logo_url, website, description, consent_terms, created_by)
  values (coalesce(biz->>'name', ''), coalesce(biz->>'business_code', ''), coalesce(nullif(biz->>'country', ''), 'FI'),
          coalesce(biz->>'logo_url', ''), coalesce(biz->>'website', ''), coalesce(biz->>'description', ''),
          coalesce((biz->>'consent_terms')::boolean, false), auth.uid())
  returning id into bid;
  insert into public.business_members (business_id, user_id, role) values (bid, auth.uid(), 'owner');
  insert into public.business_private (business_id, contact_email, phone, billing_address, e_invoice)
  values (bid, btrim(coalesce(contact->>'contact_email', '')), btrim(coalesce(contact->>'phone', '')),
          btrim(coalesce(contact->>'billing_address', '')), btrim(coalesce(contact->>'e_invoice', '')));
  return bid;
end $$;

-- 3o. Ilmoitukset: ilmoittaja = kutsuja, kohteen oltava olemassa; ylläpidolle ilmoitus
create or replace function public.reports_before_write() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    if auth.uid() is not null then
      new.reporter_id := auth.uid();
      new.status := 'open';
      new.resolved_by := null;
      new.resolved_at := null;
      new.created_at := now();
    end if;
    if new.target_type = 'event' and not exists (select 1 from public.events where id = new.target_id) then
      raise exception 'report_target_missing' using errcode = 'P0001';
    end if;
    new.note := btrim(coalesce(new.note, ''));
  elsif new.status is distinct from old.status then
    new.resolved_by := auth.uid();
    new.resolved_at := case when new.status = 'open' then null else now() end;
  end if;
  return new;
end $$;
drop trigger if exists reports_before_write on public.reports;
create trigger reports_before_write before insert or update on public.reports
  for each row execute function public.reports_before_write();

create or replace function public.reports_after_insert() returns trigger
language plpgsql security definer set search_path = public as $$
declare t text;
begin
  select title into t from public.events where id = new.target_id;
  perform public.notify_admins('🚩', 'admin_new_report', jsonb_build_object('title', coalesce(t, '')), 'Uusi ilmoitus tapahtumasta “' || coalesce(t, '') || '”', 'admin', new.target_id);
  return null;
end $$;
drop trigger if exists reports_after_insert on public.reports;
create trigger reports_after_insert after insert on public.reports
  for each row execute function public.reports_after_insert();

-- 3p. RPC: ylläpidon moderointi – varoitus / esto / eston poisto (profiles.banned)
create or replace function public.admin_moderate(uid uuid, action text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'admin_only' using errcode = 'P0001'; end if;
  if uid is null or uid = auth.uid() then raise exception 'moderation_target_invalid' using errcode = 'P0001'; end if;
  if action = 'warn' then
    perform public.notify(uid, '⚠️', 'moderation_warning', '{}'::jsonb, 'Ylläpidon varoitus: tavallisissa tapahtumissa ei saa mainostaa yritystä tai maksullista palvelua. Yrityksille on oma Yritystili.', null, null);
  elsif action = 'ban' then
    update public.profiles set banned = true where id = uid and not is_admin;
    perform public.notify(uid, '⛔', 'moderation_banned', '{}'::jsonb, 'Tilisi on estetty yhteisöohjeiden rikkomisen vuoksi: et voi enää luoda tapahtumia etkä lähettää viestejä.', null, null);
  elsif action = 'unban' then
    update public.profiles set banned = false where id = uid;
  else
    raise exception 'moderation_action_invalid' using errcode = 'P0001';
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 4. ROW LEVEL SECURITY
-- ---------------------------------------------------------------------
alter table public.profiles              enable row level security;
alter table public.profile_private       enable row level security;
alter table public.activities            enable row level security;
alter table public.events                enable row level security;
alter table public.event_participants    enable row level security;
alter table public.help_requests         enable row level security;
alter table public.help_request_contacts enable row level security;
alter table public.help_offers           enable row level security;
alter table public.conversations         enable row level security;
alter table public.messages              enable row level security;
alter table public.conversation_reads    enable row level security;
alter table public.notifications         enable row level security;

-- profiles
drop policy if exists "profiles: kirjautuneet lukevat" on public.profiles;
create policy "profiles: kirjautuneet lukevat" on public.profiles
  for select to authenticated using (true);
drop policy if exists "profiles: oma rivi lisätään" on public.profiles;
create policy "profiles: oma rivi lisätään" on public.profiles
  for insert to authenticated with check (id = auth.uid());
drop policy if exists "profiles: oma rivi päivitetään" on public.profiles;
create policy "profiles: oma rivi päivitetään" on public.profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- profile_private
drop policy if exists "profile_private: oma tai ylläpito lukee" on public.profile_private;
create policy "profile_private: oma tai ylläpito lukee" on public.profile_private
  for select to authenticated using (id = auth.uid() or public.is_admin());
drop policy if exists "profile_private: oma lisätään" on public.profile_private;
create policy "profile_private: oma lisätään" on public.profile_private
  for insert to authenticated with check (id = auth.uid());
drop policy if exists "profile_private: oma päivitetään" on public.profile_private;
create policy "profile_private: oma päivitetään" on public.profile_private
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- activities
drop policy if exists "activities: kirjautuneet lukevat" on public.activities;
create policy "activities: kirjautuneet lukevat" on public.activities
  for select to authenticated using (true);
drop policy if exists "activities: oma laji lisätään" on public.activities;
create policy "activities: oma laji lisätään" on public.activities
  for insert to authenticated with check (created_by = auth.uid() and is_custom);
drop policy if exists "activities: ylläpito muokkaa" on public.activities;
create policy "activities: ylläpito muokkaa" on public.activities
  for update to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists "activities: ylläpito poistaa" on public.activities;
create policy "activities: ylläpito poistaa" on public.activities
  for delete to authenticated using (public.is_admin());

-- events (julkiset: vain ylläpito; yritystapahtumat: aktiivisen tilauksen yrityksen jäsenet)
drop policy if exists "events: kirjautuneet lukevat" on public.events;
create policy "events: kirjautuneet lukevat" on public.events
  for select to authenticated using (true);
drop policy if exists "events: oma tapahtuma luodaan" on public.events;
create policy "events: oma tapahtuma luodaan" on public.events
  for insert to authenticated with check (not public.is_banned() and (
    (kind = 'community' and host_id = auth.uid())
    or (kind = 'public' and host_id is null and public.is_admin())
    or (kind = 'business' and host_id is null and public.business_can_post(business_id))));
drop policy if exists "events: järjestäjä muokkaa" on public.events;
create policy "events: järjestäjä muokkaa" on public.events
  for update to authenticated using (
    host_id = auth.uid() or public.is_admin() or (business_id is not null and public.is_business_member(business_id)))
  with check (
    host_id = auth.uid() or public.is_admin() or (business_id is not null and public.business_can_post(business_id)));
drop policy if exists "events: järjestäjä tai ylläpito poistaa" on public.events;
create policy "events: järjestäjä tai ylläpito poistaa" on public.events
  for delete to authenticated using (
    host_id = auth.uid() or public.is_admin() or (business_id is not null and public.is_business_member(business_id)));

-- event_participants
drop policy if exists "participants: kirjautuneet lukevat" on public.event_participants;
create policy "participants: kirjautuneet lukevat" on public.event_participants
  for select to authenticated using (true);
drop policy if exists "participants: liity itse" on public.event_participants;
create policy "participants: liity itse" on public.event_participants
  for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "participants: peru oma (ei järjestäjä)" on public.event_participants;
create policy "participants: peru oma (ei järjestäjä)" on public.event_participants
  for delete to authenticated using (
    (user_id = auth.uid() and not exists (
       select 1 from public.events e where e.id = event_id and e.host_id = auth.uid()))
    or public.is_admin());

-- help_requests
drop policy if exists "help_requests: näkyvyys" on public.help_requests;
create policy "help_requests: näkyvyys" on public.help_requests
  for select to authenticated using (
    status = 'approved' or requester_id = auth.uid() or public.is_admin() or public.is_helper(id));
drop policy if exists "help_requests: oma pyyntö luodaan" on public.help_requests;
create policy "help_requests: oma pyyntö luodaan" on public.help_requests
  for insert to authenticated with check (requester_id = auth.uid() and status = 'pending');
drop policy if exists "help_requests: pyytäjä tai ylläpito päivittää" on public.help_requests;
create policy "help_requests: pyytäjä tai ylläpito päivittää" on public.help_requests
  for update to authenticated using (requester_id = auth.uid() or public.is_admin())
  with check (requester_id = auth.uid() or public.is_admin());
drop policy if exists "help_requests: pyytäjä tai ylläpito poistaa" on public.help_requests;
create policy "help_requests: pyytäjä tai ylläpito poistaa" on public.help_requests
  for delete to authenticated using (requester_id = auth.uid() or public.is_admin());

-- help_request_contacts (puhelin & sähköposti)
drop policy if exists "contacts: pyytäjä, ylläpito ja auttajat lukevat" on public.help_request_contacts;
create policy "contacts: pyytäjä, ylläpito ja auttajat lukevat" on public.help_request_contacts
  for select to authenticated using (
    public.is_admin() or public.is_helper(request_id) or exists (
      select 1 from public.help_requests h where h.id = request_id and h.requester_id = auth.uid()));
drop policy if exists "contacts: pyytäjä lisää" on public.help_request_contacts;
create policy "contacts: pyytäjä lisää" on public.help_request_contacts
  for insert to authenticated with check (exists (
      select 1 from public.help_requests h where h.id = request_id and h.requester_id = auth.uid()));
drop policy if exists "contacts: pyytäjä päivittää" on public.help_request_contacts;
create policy "contacts: pyytäjä päivittää" on public.help_request_contacts
  for update to authenticated using (exists (
      select 1 from public.help_requests h where h.id = request_id and h.requester_id = auth.uid() and h.status in ('pending','info')));

-- help_offers
drop policy if exists "offers: näkyvät kun pyyntö näkyy" on public.help_offers;
create policy "offers: näkyvät kun pyyntö näkyy" on public.help_offers
  for select to authenticated using (
    helper_id = auth.uid() or exists (select 1 from public.help_requests h where h.id = request_id));
drop policy if exists "offers: tarjoa itse" on public.help_offers;
create policy "offers: tarjoa itse" on public.help_offers
  for insert to authenticated with check (helper_id = auth.uid());
drop policy if exists "offers: peru oma" on public.help_offers;
create policy "offers: peru oma" on public.help_offers
  for delete to authenticated using (helper_id = auth.uid() or public.is_admin());

-- conversations & messages
drop policy if exists "conversations: jäsenet lukevat" on public.conversations;
create policy "conversations: jäsenet lukevat" on public.conversations
  for select to authenticated using (public.is_conversation_member(id));
drop policy if exists "messages: jäsenet lukevat" on public.messages;
create policy "messages: jäsenet lukevat" on public.messages
  for select to authenticated using (public.is_conversation_member(conversation_id));
drop policy if exists "messages: jäsenet kirjoittavat" on public.messages;
create policy "messages: jäsenet kirjoittavat" on public.messages
  for insert to authenticated with check (
    sender_id = auth.uid() and kind = 'user' and public.is_conversation_member(conversation_id) and not public.is_banned());
drop policy if exists "messages: ylläpito poistaa" on public.messages;
create policy "messages: ylläpito poistaa" on public.messages
  for delete to authenticated using (public.is_admin() or sender_id = auth.uid());

-- conversation_reads
drop policy if exists "reads: omat" on public.conversation_reads;
create policy "reads: omat" on public.conversation_reads
  for all to authenticated using (user_id = auth.uid())
  with check (user_id = auth.uid() and public.is_conversation_member(conversation_id));

-- notifications (luodaan vain triggereillä)
drop policy if exists "notifications: omat luetaan" on public.notifications;
create policy "notifications: omat luetaan" on public.notifications
  for select to authenticated using (user_id = auth.uid());
drop policy if exists "notifications: omat merkitään luetuiksi" on public.notifications;
create policy "notifications: omat merkitään luetuiksi" on public.notifications
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists "notifications: omat poistetaan" on public.notifications;
create policy "notifications: omat poistetaan" on public.notifications
  for delete to authenticated using (user_id = auth.uid());

-- businesses / business_private / business_members
alter table public.businesses       enable row level security;
alter table public.business_private enable row level security;
alter table public.business_members enable row level security;
drop policy if exists "businesses: hyväksytyt, omat ja ylläpito lukevat" on public.businesses;
create policy "businesses: hyväksytyt, omat ja ylläpito lukevat" on public.businesses
  for select to authenticated using (
    status = 'approved' or created_by = auth.uid() or public.is_business_member(id) or public.is_admin());
drop policy if exists "businesses: hakemus luodaan" on public.businesses;
create policy "businesses: hakemus luodaan" on public.businesses
  for insert to authenticated with check (created_by = auth.uid() and status = 'pending');
drop policy if exists "businesses: jäsen tai ylläpito päivittää" on public.businesses;
create policy "businesses: jäsen tai ylläpito päivittää" on public.businesses
  for update to authenticated using (public.is_business_member(id) or public.is_admin())
  with check (public.is_business_member(id) or public.is_admin());
drop policy if exists "businesses: ylläpito poistaa" on public.businesses;
create policy "businesses: ylläpito poistaa" on public.businesses
  for delete to authenticated using (public.is_admin());

drop policy if exists "business_private: jäsen tai ylläpito lukee" on public.business_private;
create policy "business_private: jäsen tai ylläpito lukee" on public.business_private
  for select to authenticated using (public.is_business_member(business_id) or public.is_admin());
drop policy if exists "business_private: jäsen lisää" on public.business_private;
create policy "business_private: jäsen lisää" on public.business_private
  for insert to authenticated with check (public.is_business_member(business_id));
drop policy if exists "business_private: jäsen tai ylläpito päivittää" on public.business_private;
create policy "business_private: jäsen tai ylläpito päivittää" on public.business_private
  for update to authenticated using (public.is_business_member(business_id) or public.is_admin())
  with check (public.is_business_member(business_id) or public.is_admin());

drop policy if exists "business_members: omat, jäsenet ja ylläpito lukevat" on public.business_members;
create policy "business_members: omat, jäsenet ja ylläpito lukevat" on public.business_members
  for select to authenticated using (user_id = auth.uid() or public.is_business_member(business_id) or public.is_admin());
drop policy if exists "business_members: hakija lisää itsensä omistajaksi" on public.business_members;
create policy "business_members: hakija lisää itsensä omistajaksi" on public.business_members
  for insert to authenticated with check (
    (user_id = auth.uid() and role = 'owner' and exists (
       select 1 from public.businesses b where b.id = business_id and b.created_by = auth.uid()))
    or public.is_admin());
drop policy if exists "business_members: ylläpito poistaa" on public.business_members;
create policy "business_members: ylläpito poistaa" on public.business_members
  for delete to authenticated using (public.is_admin());

-- reports: ilmoittaja näkee omansa, ylläpito kaikki ja käsittelee
alter table public.reports enable row level security;
drop policy if exists "reports: omat ja ylläpito lukevat" on public.reports;
create policy "reports: omat ja ylläpito lukevat" on public.reports
  for select to authenticated using (reporter_id = auth.uid() or public.is_admin());
drop policy if exists "reports: ilmoita itse" on public.reports;
create policy "reports: ilmoita itse" on public.reports
  for insert to authenticated with check (reporter_id = auth.uid() and status = 'open');
drop policy if exists "reports: ylläpito käsittelee" on public.reports;
create policy "reports: ylläpito käsittelee" on public.reports
  for update to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists "reports: ylläpito poistaa" on public.reports;
create policy "reports: ylläpito poistaa" on public.reports
  for delete to authenticated using (public.is_admin());

-- items: kaikki näkevät saatavilla olevat; omistaja ja ylläpito muokkaa
alter table public.items enable row level security;
drop policy if exists "items: kaikki lukevat saatavilla olevat" on public.items;
create policy "items: kaikki lukevat saatavilla olevat" on public.items
  for select to authenticated using (status = 'available' or owner_id = auth.uid() or public.is_admin());
drop policy if exists "items: kirjautunut luo oman" on public.items;
create policy "items: kirjautunut luo oman" on public.items
  for insert to authenticated with check (owner_id = auth.uid() and status = 'available');
drop policy if exists "items: omistaja tai ylläpito muokkaa" on public.items;
create policy "items: omistaja tai ylläpito muokkaa" on public.items
  for update to authenticated using (owner_id = auth.uid() or public.is_admin())
  with check (owner_id = auth.uid() or public.is_admin());
drop policy if exists "items: omistaja tai ylläpito poistaa" on public.items;
create policy "items: omistaja tai ylläpito poistaa" on public.items
  for delete to authenticated using (owner_id = auth.uid() or public.is_admin());

-- item_contacts: omistaja ja ylläpito näkevät
alter table public.item_contacts enable row level security;
drop policy if exists "item_contacts: omistaja ja ylläpito lukevat" on public.item_contacts;
create policy "item_contacts: omistaja ja ylläpito lukevat" on public.item_contacts
  for select to authenticated using (
    public.is_admin() or exists (select 1 from public.items i where i.id = item_id and i.owner_id = auth.uid()));
drop policy if exists "item_contacts: omistaja lisää" on public.item_contacts;
create policy "item_contacts: omistaja lisää" on public.item_contacts
  for insert to authenticated with check (
    exists (select 1 from public.items i where i.id = item_id and i.owner_id = auth.uid()));

-- ---------------------------------------------------------------------
-- 5. OIKEUDET JA REALTIME
-- ---------------------------------------------------------------------
grant usage on schema public to anon, authenticated;
revoke all on all tables in schema public from anon;
grant select, insert, update, delete on all tables in schema public to authenticated;

-- 5b. VIERAILIJAT (anon, ei kirjautumista): vain julkinen, ei-arkaluonteinen data.
--     Ei koskaan: viestejä, yhteystietoja, profiileja, puhelinnumeroita, ylläpitotietoja.
--     Sarakekohtaiset oikeudet + RLS + security_invoker-näkymät (ei security definer -näkymiä).
alter table public.help_requests add column if not exists lat_approx double precision
  generated always as (round(lat::numeric, 2)::double precision) stored;   -- n. 1 km tarkkuus
alter table public.help_requests add column if not exists lng_approx double precision
  generated always as (round(lng::numeric, 2)::double precision) stored;

create or replace function public.event_participant_count(eid uuid) returns int
language sql stable security definer set search_path = public as $$
  select count(*)::int from public.event_participants where event_id = eid
$$;
create or replace function public.help_offer_count(rid uuid) returns int
language sql stable security definer set search_path = public as $$
  select count(*)::int from public.help_offers o join public.help_requests h on h.id = o.request_id
  where o.request_id = rid and h.status in ('approved','closed')
$$;
revoke execute on function public.event_participant_count(uuid) from public;
revoke execute on function public.help_offer_count(uuid) from public;
grant execute on function public.event_participant_count(uuid) to anon, authenticated;
grant execute on function public.help_offer_count(uuid) to anon, authenticated;

-- activities: kaikki paitsi created_by
drop policy if exists "activities: vierailijat lukevat" on public.activities;
create policy "activities: vierailijat lukevat" on public.activities
  for select to anon using (true);
grant select (id, name, emoji, hue, is_crazy, crazy_level, is_adult, is_custom, sort_order, created_at)
  on public.activities to anon;

-- events: tulevat / käynnissä olevat, ei 18+; ei host_id:tä
drop policy if exists "events: vierailijat näkevät julkiset" on public.events;
create policy "events: vierailijat näkevät julkiset" on public.events
  for select to anon using (not is_adult and last_at > now() - interval '1 day');
grant select (id, activity_id, title, description, starts_at, city, district, place, lat, lng,
              max_participants, skill_level, is_crazy, crazy_level, is_adult, created_at,
              kind, ends_at, last_at, organizer_name, official_url, price_info, business_id)
  on public.events to anon;

-- businesses: vain hyväksytyt, vain julkiset kentät (EI Y-tunnusta, yhteys-, laskutus- tai tilaustietoja)
drop policy if exists "businesses: vierailijat näkevät hyväksytyt" on public.businesses;
create policy "businesses: vierailijat näkevät hyväksytyt" on public.businesses
  for select to anon using (status = 'approved');
grant select (id, name, logo_url, website, description, country, status) on public.businesses to anon;

-- help_requests: vain hyväksytyt; ei pyytäjää, osoitetta, tarkkaa sijaintia, historiaa eikä ylläpidon kenttiä
drop policy if exists "help_requests: vierailijat näkevät hyväksytyt" on public.help_requests;
create policy "help_requests: vierailijat näkevät hyväksytyt" on public.help_requests
  for select to anon using (status = 'approved' and starts_at > now() - interval '1 day');
grant select (id, category, title, description, needs, city, district, lat_approx, lng_approx,
              starts_at, duration, helpers_needed, status, email_verified, created_at)
  on public.help_requests to anon;

create or replace view public.guest_events with (security_invoker = true) as
  select e.id, e.activity_id, e.title, e.description, e.starts_at, e.city, e.district, e.place,
         e.lat, e.lng, e.max_participants, e.skill_level, e.is_crazy, e.crazy_level, e.is_adult,
         e.created_at, public.event_participant_count(e.id) as participant_count,
         e.kind, e.ends_at, e.last_at, e.organizer_name, e.official_url, e.price_info, e.business_id,
         (select b.name from public.businesses b where b.id = e.business_id) as business_name,
         (select b.logo_url from public.businesses b where b.id = e.business_id) as business_logo
  from public.events e;
create or replace view public.guest_help_requests with (security_invoker = true) as
  select h.id, h.category, h.title, h.description, h.needs, h.city, h.district,
         h.lat_approx as lat, h.lng_approx as lng, h.starts_at, h.duration, h.helpers_needed,
         h.status, h.email_verified, h.created_at, public.help_offer_count(h.id) as helpers_count
  from public.help_requests h
  where h.status = 'approved';
revoke all on public.guest_events, public.guest_help_requests from anon, authenticated;
grant select on public.guest_events, public.guest_help_requests to anon, authenticated;

-- Sisäiset apufunktiot eivät saa olla kutsuttavissa API:n (RPC) kautta
revoke execute on function public.notify(uuid, text, text, jsonb, text, text, uuid) from public, anon, authenticated;
revoke execute on function public.notify_admins(text, text, jsonb, text, text, uuid) from public, anon, authenticated;
revoke execute on function public.post_system_message(uuid, text, jsonb, text) from public, anon, authenticated;
revoke execute on function public.display_name_of(uuid) from public, anon;
revoke execute on function public.submit_help_request(jsonb, jsonb) from public, anon;
revoke execute on function public.delete_my_account() from public, anon;
-- Vierailijat (anon) eivät tarvitse apufunktioita; ne palauttavat anonille aina false, mutta suljetaan varmuuden vuoksi
revoke execute on function public.is_admin() from public, anon;
revoke execute on function public.can_help() from public, anon;
revoke execute on function public.is_helper(uuid) from public, anon;
revoke execute on function public.is_conversation_member(uuid) from public, anon;
revoke execute on function public.is_business_member(uuid) from public, anon;
revoke execute on function public.business_active(uuid) from public, anon;
revoke execute on function public.business_can_post(uuid) from public, anon;
revoke execute on function public.business_expiry_sweep() from public, anon;
revoke execute on function public.apply_business(jsonb, jsonb) from public, anon;
grant execute on function public.is_business_member(uuid) to authenticated;
grant execute on function public.business_active(uuid) to authenticated;
grant execute on function public.business_can_post(uuid) to authenticated;
grant execute on function public.business_expiry_sweep() to authenticated;
grant execute on function public.apply_business(jsonb, jsonb) to authenticated;
revoke execute on function public.is_banned() from public, anon;
revoke execute on function public.admin_moderate(uuid, text) from public, anon;
grant execute on function public.is_banned() to authenticated;
grant execute on function public.admin_moderate(uuid, text) to authenticated;
grant execute on function public.submit_help_request(jsonb, jsonb) to authenticated;
grant execute on function public.delete_my_account() to authenticated;
grant execute on function public.is_admin() to authenticated;
grant execute on function public.can_help() to authenticated;
grant execute on function public.is_helper(uuid) to authenticated;
grant execute on function public.is_conversation_member(uuid) to authenticated;
grant execute on function public.display_name_of(uuid) to authenticated;
grant execute on function public.submit_item(jsonb, jsonb) to authenticated;
grant execute on function public.close_item(uuid, text) to authenticated;
revoke execute on function public.submit_item(jsonb, jsonb) from public, anon;
revoke execute on function public.close_item(uuid, text) from public, anon;

-- Yritystilausten muistutukset päivittäin, JOS pg_cron on jo asennettu (tätä skriptiä ei asenna sitä)
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('molaplan-business-expiry', '15 6 * * *', 'select public.business_expiry_sweep()');
  end if;
end $$;

-- Realtime: viestit ja ilmoitukset (RLS rajaa, kuka saa mitäkin)
do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
  if not exists (select 1 from pg_publication_tables
                 where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'messages') then
    alter publication supabase_realtime add table public.messages;
  end if;
  if not exists (select 1 from pg_publication_tables
                 where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'notifications') then
    alter publication supabase_realtime add table public.notifications;
  end if;
end $$;

-- Jo olemassa olevat käyttäjät (jos skripti ajetaan myöhemmin) saavat profiilin
insert into public.profiles (id, email_verified)
  select u.id, u.email_confirmed_at is not null from auth.users u
  on conflict (id) do nothing;
insert into public.profile_private (id)
  select p.id from public.profiles p
  on conflict (id) do nothing;

-- ---------------------------------------------------------------------
-- 1q. ANNETAAN / TARVITAAN (items)
-- ---------------------------------------------------------------------
create table if not exists public.items (
  id          uuid primary key default gen_random_uuid(),
  owner_id    uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  kind        text not null check (kind in ('give','need')),
  title       text not null check (char_length(title) between 3 and 80),
  description text not null default '' check (char_length(description) <= 1000),
  city        text not null check (char_length(city) between 1 and 40),
  district    text not null default '' check (char_length(district) <= 40),
  status      text not null default 'available' check (status in ('available','taken','closed')),
  photo_url   text not null default '' check (photo_url = '' or (photo_url ~ '^https://[^\s<>"'']+$' and char_length(photo_url) <= 400)),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint items_no_prices check (title !~ '€' and description !~ '€')
);
create index if not exists items_status_city_idx on public.items (status, lower(city));
create index if not exists items_owner_idx on public.items (owner_id);

-- Yhteystiedot: näkyvät vain omistajalle, ylläpitäjille ja kiinnostuneille (jatkossa: chatti)
create table if not exists public.item_contacts (
  item_id      uuid primary key references public.items(id) on delete cascade,
  contact_name text not null check (char_length(contact_name) between 2 and 40),
  phone        text check (phone is null or phone ~ '^\+?[0-9][0-9 ()-]{5,19}$'),
  email        text not null check (char_length(email) between 3 and 254 and position('@' in email) > 1),
  created_at   timestamptz not null default now()
);

-- Trigger: items updated_at
create or replace function public.items_updated_at() returns trigger
language plpgsql as $$
begin new.updated_at := now(); return new; end $$;
drop trigger if exists items_updated_at on public.items;
create trigger items_updated_at before update on public.items
  for each row execute function public.items_updated_at();

-- Trigger: items before insert – omistaja = kutsuja, ei kaupallista sisältöä
create or replace function public.items_before_write() returns trigger
language plpgsql as $$
begin
  if auth.uid() is not null then
    if public.is_banned() then
      raise exception 'account_banned' using errcode = 'P0001';
    end if;
    if tg_op = 'INSERT' then
      new.owner_id := auth.uid();
      new.status := 'available';
      new.created_at := now();
      if not coalesce((select email_verified from public.profiles where id = auth.uid()), false) then
        raise exception 'email_not_verified' using errcode = 'P0001';
      end if;
    else
      new.created_at := old.created_at;
      new.owner_id := old.owner_id;
    end if;
  end if;
  if public.looks_commercial(new.title) or public.looks_commercial(new.description) then
    raise exception 'commercial_content' using errcode = 'P0001';
  end if;
  return new;
end $$;
drop trigger if exists items_before_write on public.items;
create trigger items_before_write before insert or update on public.items
  for each row execute function public.items_before_write();

-- Trigger: item_contacts – sähköposti = tilin sähköposti
create or replace function public.item_contacts_before_insert() returns trigger
language plpgsql security definer set search_path = public as $$
declare em text;
begin
  select u.email into em from auth.users u where u.id = auth.uid();
  if em is not null and em <> '' then new.email := em; end if;
  new.contact_name := btrim(new.contact_name);
  new.phone := btrim(coalesce(new.phone, ''));
  return new;
end $$;
drop trigger if exists item_contacts_before_insert on public.item_contacts;
create trigger item_contacts_before_insert before insert on public.item_contacts
  for each row execute function public.item_contacts_before_insert();

-- RPC: lisaa item + yhteystiedot yhdessa transaktiossa
create or replace function public.submit_item(it jsonb, contact jsonb) returns uuid
language plpgsql security invoker set search_path = public as $$
declare iid uuid;
begin
  if auth.uid() is null then raise exception 'not_authenticated' using errcode = 'P0001'; end if;
  insert into public.items (kind, title, description, city, district, photo_url)
  values (
    it->>'kind', btrim(it->>'title'), coalesce(it->>'description', ''),
    btrim(it->>'city'), btrim(coalesce(it->>'district', '')),
    coalesce(it->>'photo_url', ''))
  returning id into iid;
  insert into public.item_contacts (item_id, contact_name, phone)
  values (iid, contact->>'name', coalesce(contact->>'phone', ''));
  return iid;
end $$;

-- RPC: sulje / merkitse otetuksi
create or replace function public.close_item(iid uuid, new_status text) returns void
language plpgsql security invoker set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated' using errcode = 'P0001'; end if;
  if new_status not in ('taken','closed') then
    raise exception 'invalid_status' using errcode = 'P0001';
  end if;
  update public.items set status = new_status
    where id = iid and (owner_id = auth.uid() or public.is_admin());
end $$;

-- ---------------------------------------------------------------------
-- 6. LAJIT (perusdata)
-- ---------------------------------------------------------------------
insert into public.activities (id, name, emoji, hue, is_crazy, crazy_level, is_adult, is_custom, sort_order, created_by) values
  ('padel',         'Padel',                         '🏓', 155, false, 0, false, false,  10, null),
  ('sulkapallo',    'Sulkapallo',                    '🏸', 190, false, 0, false, false,  20, null),
  ('tennis',        'Tennis',                        '🎾',  75, false, 0, false, false,  30, null),
  ('juoksu',        'Juoksu',                        '🏃',  12, false, 0, false, false,  40, null),
  ('kavely',        'Kävely',                        '🚶', 100, false, 0, false, false,  50, null),
  ('vaellus',       'Vaellus',                       '🥾', 125, false, 0, false, false,  60, null),
  ('pyoraily',      'Pyöräily',                      '🚴',  30, false, 0, false, false,  70, null),
  ('kuntosali',     'Kuntosali',                     '🏋️', 350, false, 0, false, false,  80, null),
  ('jooga',         'Jooga',                         '🧘', 280, false, 0, false, false,  90, null),
  ('uinti',         'Uinti',                         '🏊', 205, false, 0, false, false, 100, null),
  ('frisbeegolf',   'Frisbeegolf',                   '🥏',  45, false, 0, false, false, 110, null),
  ('jalkapallo',    'Jalkapallo',                    '⚽', 140, false, 0, false, false, 120, null),
  ('salibandy',     'Salibandy',                     '🏑', 222, false, 0, false, false, 130, null),
  ('lautapelit',    'Lautapelit',                    '🎲', 258, false, 0, false, false, 140, null),
  ('kahvi',         'Kahvi & juttelu',               '☕',  24, false, 0, false, false, 150, null),
  ('valokuvaus',    'Valokuvaus',                    '📷', 300, false, 0, false, false, 160, null),
  ('kalastus',      'Kalastus',                      '🎣', 195, false, 0, false, false, 170, null),
  ('neulonta',      'Neulonta',                      '🧶', 330, false, 0, false, false, 180, null),
  ('kieltenvaihto', 'Kieltenvaihto',                 '🗣️', 170, false, 0, false, false, 190, null),
  ('konsertit',     'Konsertit',                     '🎵', 312, false, 0, false, false, 200, null),
  ('festivaali',    'Festivaalit',                   '🎪', 330, false, 0, false, false, 210, null),
  ('markkinat',     'Markkinat',                     '🛍️',  36, false, 0, false, false, 220, null),
  ('juoksutapahtuma','Juoksutapahtumat',             '🏅',   8, false, 0, false, false, 230, null),
  ('kulttuuri',     'Kulttuuri',                     '🎭', 275, false, 0, false, false, 240, null),
  ('nakuuinti',     'Nakuuinti',                     '🌊', 200, true,  3, true,  false, 500, null),
  ('pelle',         'Pellekokoontuminen',            '🤡', 350, true,  2, false, false, 510, null),
  ('konjakkipiknik','Konjakkipiknik',                '🥃',  30, true,  1, true,  false, 520, null),
  ('pyjamabrunssi', 'Pyjamabrunssi',                 '🥞',  40, true,  1, false, false, 530, null),
  ('karaokepuisto', 'Karaoke puistossa',             '🎤', 290, true,  2, false, false, 540, null),
  ('vesisota',      'Vesipyssytaistelu',             '💦', 195, true,  2, false, false, 550, null),
  ('flashmob',      'Tanssia bussipysäkillä',        '🕺', 320, true,  3, false, false, 560, null),
  ('avanto',        'Avantouinti auringonnousussa',  '🌅',  20, true,  3, false, false, 570, null),
  ('huonorunous',   'Vuoden huonoin runo -ilta',     '📜', 260, true,  1, false, false, 580, null),
  ('kasari',        'Pukeudu 80-luvuksi',            '📼', 300, true,  2, false, false, 590, null)
on conflict (id) do update set
  name = excluded.name, emoji = excluded.emoji, hue = excluded.hue,
  is_crazy = excluded.is_crazy, crazy_level = excluded.crazy_level, is_adult = excluded.is_adult,
  is_custom = false, sort_order = excluded.sort_order;

-- Valmis! 🎉
