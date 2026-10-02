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
  max_participants int default 6 check (max_participants is null or max_participants between 2 and 100000),
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
alter table public.events add column if not exists extra_info text not null default '';   -- lisätiedot (yritys / julkinen)
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
alter table public.events drop constraint if exists events_extra_info_check;
alter table public.events add constraint events_extra_info_check check (
  char_length(extra_info) <= 1000 and (kind <> 'community' or extra_info = ''));
alter table public.events drop constraint if exists events_ends_check;
alter table public.events add constraint events_ends_check check (
  ends_at is null or (ends_at >= starts_at and ends_at <= starts_at + interval '62 days'));
-- max_participants NULL = ei rajaa – kaikki tapahtumatyypit, myös tavalliset (2026-10-01); muuten 2–100000.
-- (Ennen: NULL vain julkisille/yritystapahtumille ja tavallisille 2–50. Idempotentti: ei muuta olemassa olevia rivejä.)
alter table public.events alter column max_participants drop not null;
alter table public.events drop constraint if exists events_max_participants_check;
alter table public.events add constraint events_max_participants_check check (
  max_participants is null or max_participants between 2 and 100000);
alter table public.events drop constraint if exists events_description_check;
alter table public.events add constraint events_description_check check (
  char_length(description) <= case when kind = 'community' then 600 else 2000 end);
create index if not exists events_last_idx on public.events (last_at);
create index if not exists events_business_idx on public.events (business_id);
-- Kansikuva (osio 8b): Storage-polku julkisessa event-covers-bucketissa
-- Polku: <uuid>/<satunnainen nimi>.webp|.jpg ; ensimmäinen kansio = tapahtuma (kansikuva) tai keskustelu (chatti)
create or replace function public.path_uuid(p text) returns uuid
language sql immutable as $$
  select case when split_part(coalesce(p, ''), '/', 1) ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
              then split_part(p, '/', 1)::uuid end
$$;
create or replace function public.valid_image_path(p text) returns boolean
language sql immutable as $$
  select coalesce(p ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-z_-]{6,64}\.(webp|jpg)$', false)
$$;

alter table public.events add column if not exists cover_path text;
alter table public.events drop constraint if exists events_cover_path_check;
alter table public.events add constraint events_cover_path_check check (
  cover_path is null or (public.valid_image_path(cover_path) and public.path_uuid(cover_path) = id));

-- Ilmoitusten linkit: myös yritystili, kaverit ja joukkuetilin pyyntö ('team', 7e)
alter table public.notifications drop constraint if exists notifications_link_kind_check;
alter table public.notifications add constraint notifications_link_kind_check
  check (link_kind in ('request','help','chat','event','admin','business','friend','team'));

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

-- plpgsql: rungon taulut tarkistetaan vasta suoritettaessa (ryhmätaulut luodaan osiossa 8c)
create or replace function public.is_conversation_member(cid uuid) returns boolean
language plpgsql stable security definer set search_path = public as $$
begin
  return exists (
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
      or
      (c.kind = 'group' and exists (
         select 1 from public.group_members m where m.group_id = c.group_id and m.user_id = auth.uid()))
      or
      (c.kind = 'team' and (
         exists (select 1 from public.teams t where t.id = c.team_id and t.owner_id = auth.uid())
         or exists (select 1 from public.team_members m where m.team_id = c.team_id and m.user_id = auth.uid())))
    ));
end $$;

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
  new.name := btrim(regexp_replace(new.name, '\s+', ' ', 'g'));
  if auth.uid() is not null and not public.is_admin() then
    if tg_op = 'INSERT' then
      if public.is_banned() then raise exception 'account_banned' using errcode = 'P0001'; end if;
      -- uusi vapaatekstilaji: käytettävissä heti omassa tapahtumassa, yhteiseen listaan vasta ylläpidon hyväksynnän jälkeen (8a)
      if public.looks_commercial(new.name) then raise exception 'commercial_content' using errcode = 'P0001'; end if;
      if (select count(*) from public.activities a where a.created_by = auth.uid() and a.created_at > now() - interval '1 day') >= 10 then
        raise exception 'activity_rate_limited' using errcode = 'P0001';
      end if;
      new.is_custom := true;
      new.created_by := auth.uid();
      new.sort_order := 1000;
      new.created_at := now();
      new.status := 'pending';
      new.name_i18n := '{}'::jsonb;
      new.reviewed_by := null;
      new.reviewed_at := null;
    end if;
  end if;
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
  new.extra_info := case when new.kind = 'community' then '' else btrim(coalesce(new.extra_info, '')) end;
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
    -- kuva (8b): vain tapahtuma- ja ryhmächatit, tiedoston on oltava tallennettu chat-images-bucketiin
    if new.image_path is not null then
      if not public.valid_image_path(new.image_path) or public.path_uuid(new.image_path) is distinct from new.conversation_id then
        raise exception 'image_path_invalid' using errcode = 'P0001';
      end if;
      if not public.can_post_image(new.conversation_id) then
        raise exception 'image_not_allowed' using errcode = 'P0001';
      end if;
      if not public.storage_object_exists('chat-images', new.image_path) then
        raise exception 'image_missing' using errcode = 'P0001';
      end if;
    end if;
    -- ryhmächatit (8c): sama mainossuoja kuin tavallisissa tapahtumissa (ylläpito saa kirjoittaa vapaasti)
    if exists (select 1 from public.conversations c where c.id = new.conversation_id and c.kind = 'group')
       and not public.is_admin() and public.looks_commercial(new.body) then
      raise exception 'commercial_content' using errcode = 'P0001';
    end if;
  end if;
  new.body := btrim(coalesce(new.body, ''));
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
    if (new.target_type = 'event' and not exists (select 1 from public.events where id = new.target_id))
       or (new.target_type = 'event_cover' and not exists (select 1 from public.events where id = new.target_id and cover_path is not null))
       or (new.target_type = 'message' and not exists (select 1 from public.messages m where m.id = new.target_id
             and m.kind = 'user' and public.is_conversation_member(m.conversation_id)))
       or (new.target_type = 'group' and not public.group_visible(new.target_id)) then
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
  if new.target_type in ('event','event_cover') then
    select title into t from public.events where id = new.target_id;
  elsif new.target_type = 'group' then
    select name into t from public.groups where id = new.target_id;
  else
    select case when m.image_path is not null then '📷 ' else '' end || left(m.body, 60) into t from public.messages m where m.id = new.target_id;
  end if;
  perform public.notify_admins('🚩', 'admin_new_report', jsonb_build_object('title', coalesce(t, '')), 'Uusi ilmoitus: “' || coalesce(t, '') || '”', 'admin', new.target_id);
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
         (select b.logo_url from public.businesses b where b.id = e.business_id) as business_logo,
         e.cover_path, e.extra_info
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

-- 5b. LIVE-KANNAN AJAUTUMA (havaittu 2026-10-01): Supabasen hallintapaneelissa tehdyt muutokset, joita tämä tiedosto ei
--     luonut. Kaikki ehdollisia -> tuoreessa kannassa no-op.
--     * profiles/businesses/teams.username NOT NULL ilman oletusta -> rekisteröityminen (handle_new_user),
--       yrityshakemus ja joukkueen luonti kaatuivat -> annetaan uniikki oletusarvo.
--     * "Anyone can read business usernames" (select true kaikille) paljasti käsittelemättömät yrityshakemukset.
--     * legacy-taulut friends (taulu, ei näkymä) ja friend_requests (vanha muoto) -> siirretään uuteen muotoon.
--     * joukkuetaulujen vanhat sallivat politiikat ("teams:lukevat", "team_events:luovat" with check true, ...).
--     * search_profiles() oli anonin kutsuttavissa (security definer -> kaikkien nimet).
do $$
declare r record;
begin
  -- username-sarakkeet: oletusarvo, jotta insertit, jotka eivät tunne saraketta, eivät kaadu
  for r in select c.table_name, c.column_default from information_schema.columns c
           where c.table_schema = 'public' and c.column_name = 'username'
             and c.table_name in ('profiles','businesses','teams') and c.is_nullable = 'NO' loop
    if r.column_default is null then
      execute format('alter table public.%I alter column username set default (%L || replace(gen_random_uuid()::text, ''-'', ''''))',
                     r.table_name, left(r.table_name, 1) || '_');
    end if;
  end loop;
  if to_regclass('public.businesses') is not null then
    drop policy if exists "Anyone can read business usernames" on public.businesses;
  end if;

  -- friend_requests vanhassa muodossa (status varchar, ei responded_at, aikaleimat ilman aikavyöhykettä)
  if to_regclass('public.friend_requests') is not null
     and not exists (select 1 from information_schema.columns where table_schema = 'public'
                     and table_name = 'friend_requests' and column_name = 'responded_at') then
    delete from public.friend_requests where requester_id is null or target_id is null or requester_id = target_id;
    alter table public.friend_requests drop constraint if exists friend_requests_requester_id_target_id_event_id_key;
    alter table public.friend_requests add column responded_at timestamptz;
    alter table public.friend_requests alter column status type text using (case when status = 'rejected' then 'declined' else coalesce(status, 'pending') end);
    update public.friend_requests set status = 'pending' where status not in ('pending','accepted','declined');
    alter table public.friend_requests alter column created_at type timestamptz using coalesce(created_at, now()) at time zone 'UTC',
                                       alter column updated_at type timestamptz using coalesce(updated_at, now()) at time zone 'UTC';
    update public.friend_requests set created_at = coalesce(created_at, now()), updated_at = coalesce(updated_at, now());
    alter table public.friend_requests alter column requester_id set not null, alter column target_id set not null,
      alter column status set not null, alter column status set default 'pending',
      alter column created_at set not null, alter column created_at set default now(),
      alter column updated_at set not null, alter column updated_at set default now();
    alter table public.friend_requests add constraint friend_requests_status_check check (status in ('pending','accepted','declined'));
    alter table public.friend_requests add constraint friend_requests_not_self check (requester_id <> target_id);
    alter table public.friend_requests drop constraint if exists friend_requests_event_id_fkey;
    alter table public.friend_requests add constraint friend_requests_event_id_fkey
      foreign key (event_id) references public.events(id) on delete set null;
    -- yksi rivi / pari (uusi uniikki indeksi): pidetään hyväksytty tai uusin
    delete from public.friend_requests f using public.friend_requests g
      where least(f.requester_id, f.target_id) = least(g.requester_id, g.target_id)
        and greatest(f.requester_id, f.target_id) = greatest(g.requester_id, g.target_id) and f.id <> g.id
        and ((g.status = 'accepted') :: int, g.updated_at, g.id) > ((f.status = 'accepted') :: int, f.updated_at, f.id);
  end if;

  -- friends taulukkona (GitHub/hallintapaneeli) -> rivit friend_requestsiin, taulu pois (tilalle näkymä osiossa 7c)
  if exists (select 1 from pg_class c where c.oid = to_regclass('public.friends') and c.relkind = 'r') then
    if to_regclass('public.friend_requests') is null then
      create table public.friend_requests (
        id uuid primary key default gen_random_uuid(),
        requester_id uuid not null references public.profiles(id) on delete cascade,
        target_id uuid not null references public.profiles(id) on delete cascade,
        event_id uuid references public.events(id) on delete set null,
        status text not null default 'pending' check (status in ('pending','accepted','declined')),
        created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
        responded_at timestamptz, constraint friend_requests_not_self check (requester_id <> target_id));
    end if;
    insert into public.friend_requests (requester_id, target_id, status, created_at, updated_at, responded_at)
      select distinct on (least(f.requester_id, f.addressee_id), greatest(f.requester_id, f.addressee_id))
             f.requester_id, f.addressee_id,
             case f.status when 'accepted' then 'accepted' when 'rejected' then 'declined' else 'pending' end,
             f.created_at, f.updated_at, case when f.status <> 'pending' then f.updated_at end
        from public.friends f
       where f.requester_id <> f.addressee_id
         and not exists (select 1 from public.friend_requests x
                          where least(x.requester_id, x.target_id) = least(f.requester_id, f.addressee_id)
                            and greatest(x.requester_id, x.target_id) = greatest(f.requester_id, f.addressee_id))
       order by least(f.requester_id, f.addressee_id), greatest(f.requester_id, f.addressee_id), (f.status = 'accepted') desc, f.updated_at desc;
    drop table public.friends cascade;
  end if;
  drop function if exists public.friends_after_change();

  -- joukkuetaulut hallintapaneelin muodossa: puuttuvat sarakkeet + NOT NULL -kentät, joita UI lähettää nullina
  if to_regclass('public.teams') is not null then
    alter table public.teams add column if not exists description text not null default '';
  end if;
  if to_regclass('public.team_events') is not null then
    alter table public.team_events add column if not exists updated_at timestamptz not null default now();
    if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'team_events'
               and column_name = 'place_name' and is_nullable = 'NO') then
      alter table public.team_events alter column place_name drop not null, alter column place_address drop not null;
    end if;
    if exists (select 1 from pg_constraint where conname = 'team_events_created_by_fkey' and confdeltype <> 'n') then
      alter table public.team_events alter column created_by drop not null;
      alter table public.team_events drop constraint team_events_created_by_fkey;
      alter table public.team_events add constraint team_events_created_by_fkey
        foreign key (created_by) references public.profiles(id) on delete set null;
    end if;
  end if;
  if to_regclass('public.team_event_rsvps') is not null then
    delete from public.team_event_rsvps where status not in ('going','maybe');  -- 'not' = ei ilmoittautumista (UI poistaa rivin)
    alter table public.team_event_rsvps add column if not exists role_in_event text not null default '' check (char_length(role_in_event) <= 30);
    alter table public.team_event_rsvps add column if not exists notes text not null default '' check (char_length(notes) <= 100);
  end if;
  if exists (select 1 from pg_constraint where conname = 'team_messages_sender_id_fkey' and confdeltype <> 'n') then
    alter table public.team_messages alter column sender_id drop not null;
    alter table public.team_messages drop constraint team_messages_sender_id_fkey;
    alter table public.team_messages add constraint team_messages_sender_id_fkey
      foreign key (sender_id) references public.profiles(id) on delete set null;
  end if;
  for r in select tablename, policyname from pg_policies where schemaname = 'public'
             and tablename in ('teams','team_members','team_roles','team_places','team_events','team_event_rsvps','team_messages')
             and (policyname ~ '^team[a-z_]*:[a-z]' or policyname = 'Anyone can read team usernames') loop
    execute format('drop policy %I on public.%I', r.policyname, r.tablename);
  end loop;

  -- search_profiles(): vain kirjautuneille
  if to_regprocedure('public.search_profiles(text)') is not null then
    revoke execute on function public.search_profiles(text) from public, anon;
    grant execute on function public.search_profiles(text) to authenticated;
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

-- Live-kannassa activities oli luotu uudelleen (tyhjä, events_activity_id_fkey hävinnyt) -> palautetaan viiteavain,
-- kun kaikki tapahtumien lajit löytyvät (muuten jätetään väliin, ettei skripti kaadu).
do $$
begin
  if not exists (select 1 from pg_constraint where conrelid = 'public.events'::regclass and conname = 'events_activity_id_fkey')
     and not exists (select 1 from public.events e where not exists (select 1 from public.activities a where a.id = e.activity_id)) then
    alter table public.events add constraint events_activity_id_fkey
      foreign key (activity_id) references public.activities(id) on update cascade;
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 7. GITHUB-YHDISTÄMINEN 2026-10-01: annetaan/tarvitaan (items), joukkueet (teams), kaverit (friends)
--    Kaikki osiot ovat idempotentteja ja tulevat taulujen/funktioiden luonnin JÄLKEEN (RLS + oikeudet lopussa).
--    HUOM: Supabase antaa uusille tauluille oletuksena oikeudet myös anonille -> suljetaan erikseen.
-- ---------------------------------------------------------------------

-- 7a. ANNETAAN / TARVITAAN (items) – tietokantapohja GitHubista; käyttöliittymä on vielä kesken (ff=items)
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

create table if not exists public.item_contacts (
  item_id      uuid primary key references public.items(id) on delete cascade,
  contact_name text not null check (char_length(contact_name) between 2 and 40),
  phone        text check (phone is null or phone = '' or phone ~ '^\+?[0-9][0-9 ()-]{5,19}$'),
  email        text not null default '' check (email = '' or (char_length(email) between 3 and 254 and position('@' in email) > 1)),
  created_at   timestamptz not null default now()
);

create or replace function public.items_before_write() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null then
    if public.is_banned() then raise exception 'account_banned' using errcode = 'P0001'; end if;
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
  new.updated_at := now();
  if public.looks_commercial(new.title) or public.looks_commercial(new.description) then
    raise exception 'commercial_content' using errcode = 'P0001';
  end if;
  return new;
end $$;
drop trigger if exists items_updated_at on public.items;
drop function if exists public.items_updated_at();
drop trigger if exists items_before_write on public.items;
create trigger items_before_write before insert or update on public.items
  for each row execute function public.items_before_write();

create or replace function public.item_contacts_before_insert() returns trigger
language plpgsql security definer set search_path = public as $$
declare em text;
begin
  select u.email into em from auth.users u where u.id = auth.uid();
  new.email := coalesce(em, '');
  new.contact_name := btrim(new.contact_name);
  new.phone := btrim(coalesce(new.phone, ''));
  return new;
end $$;
drop trigger if exists item_contacts_before_insert on public.item_contacts;
create trigger item_contacts_before_insert before insert on public.item_contacts
  for each row execute function public.item_contacts_before_insert();

create or replace function public.submit_item(it jsonb, contact jsonb) returns uuid
language plpgsql security invoker set search_path = public as $$
declare iid uuid;
begin
  if auth.uid() is null then raise exception 'not_authenticated' using errcode = 'P0001'; end if;
  insert into public.items (kind, title, description, city, district, photo_url)
  values (it->>'kind', btrim(it->>'title'), coalesce(it->>'description', ''),
          btrim(it->>'city'), btrim(coalesce(it->>'district', '')), coalesce(it->>'photo_url', ''))
  returning id into iid;
  insert into public.item_contacts (item_id, contact_name, phone)
  values (iid, contact->>'name', coalesce(contact->>'phone', ''));
  return iid;
end $$;

create or replace function public.close_item(iid uuid, new_status text) returns void
language plpgsql security invoker set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated' using errcode = 'P0001'; end if;
  if new_status not in ('taken','closed') then raise exception 'invalid_status' using errcode = 'P0001'; end if;
  update public.items set status = new_status where id = iid and (owner_id = auth.uid() or public.is_admin());
end $$;

alter table public.items         enable row level security;
alter table public.item_contacts enable row level security;
drop policy if exists "items: kaikki lukevat saatavilla olevat" on public.items;
create policy "items: kaikki lukevat saatavilla olevat" on public.items
  for select to authenticated using (status = 'available' or owner_id = auth.uid() or public.is_admin());
drop policy if exists "items: kirjautunut luo oman" on public.items;
create policy "items: kirjautunut luo oman" on public.items
  for insert to authenticated with check (owner_id = auth.uid() and status = 'available' and not public.is_banned());
drop policy if exists "items: omistaja tai ylläpito muokkaa" on public.items;
create policy "items: omistaja tai ylläpito muokkaa" on public.items
  for update to authenticated using (owner_id = auth.uid() or public.is_admin())
  with check (owner_id = auth.uid() or public.is_admin());
drop policy if exists "items: omistaja tai ylläpito poistaa" on public.items;
create policy "items: omistaja tai ylläpito poistaa" on public.items
  for delete to authenticated using (owner_id = auth.uid() or public.is_admin());
drop policy if exists "item_contacts: omistaja ja ylläpito lukevat" on public.item_contacts;
create policy "item_contacts: omistaja ja ylläpito lukevat" on public.item_contacts
  for select to authenticated using (
    public.is_admin() or exists (select 1 from public.items i where i.id = item_id and i.owner_id = auth.uid()));
drop policy if exists "item_contacts: omistaja lisää" on public.item_contacts;
create policy "item_contacts: omistaja lisää" on public.item_contacts
  for insert to authenticated with check (
    exists (select 1 from public.items i where i.id = item_id and i.owner_id = auth.uid()));

-- 7b. JOUKKUEET / SEURAT – perustaulut. Hallinta (roolit, toistuvat tapahtumat, kutsut, chat, RLS) osiossa 9a.
--     Joukkue syntyy vain ylläpidon hyväksymästä joukkuetilipyynnöstä (7e).
create table if not exists public.teams (
  id          uuid primary key default gen_random_uuid(),
  name        text not null check (char_length(name) between 2 and 50),
  sport       text not null default '' check (char_length(sport) <= 40),
  description text not null default '' check (char_length(description) <= 300),
  logo_url    text not null default '',
  owner_id    uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
alter table public.teams drop constraint if exists teams_logo_url_check;
alter table public.teams add constraint teams_logo_url_check check (
  logo_url = '' or (logo_url ~ '^https://[^\s<>"'']+$' and char_length(logo_url) <= 400));
create index if not exists teams_owner_idx on public.teams (owner_id);
alter table public.teams alter column owner_id set default auth.uid();

create table if not exists public.team_members (
  id         uuid primary key default gen_random_uuid(),
  team_id    uuid not null references public.teams(id) on delete cascade,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  role       text not null default 'member' check (role in ('admin','coach','player','member')),
  joined_at  timestamptz not null default now(),
  unique (team_id, user_id)
);
create index if not exists team_members_team_idx on public.team_members (team_id);
create index if not exists team_members_user_idx on public.team_members (user_id);

create table if not exists public.team_roles (
  id         uuid primary key default gen_random_uuid(),
  team_id    uuid not null references public.teams(id) on delete cascade,
  name       text not null check (char_length(name) between 1 and 30),
  color      text not null default '#7C6FFF' check (char_length(color) <= 20),
  sort_order int  not null default 0,
  unique (team_id, name)
);
create index if not exists team_roles_team_idx on public.team_roles (team_id);

create table if not exists public.team_places (
  id         uuid primary key default gen_random_uuid(),
  team_id    uuid not null references public.teams(id) on delete cascade,
  name       text not null check (char_length(name) between 2 and 60),
  address    text not null default '' check (char_length(address) <= 120),
  lat        double precision check (lat is null or lat between -90 and 90),
  lng        double precision check (lng is null or lng between -180 and 180),
  notes      text not null default '' check (char_length(notes) <= 200),
  sort_order int  not null default 0
);
create index if not exists team_places_team_idx on public.team_places (team_id);

create table if not exists public.team_events (
  id               uuid primary key default gen_random_uuid(),
  team_id          uuid not null references public.teams(id) on delete cascade,
  title            text not null check (char_length(title) between 2 and 60),
  description      text not null default '' check (char_length(description) <= 400),
  event_date       date not null,
  event_time       time,
  place_id         uuid references public.team_places(id) on delete set null,
  place_name       text check (place_name is null or char_length(place_name) <= 60),
  place_address    text check (place_address is null or char_length(place_address) <= 120),
  max_participants int check (max_participants is null or max_participants >= 1),
  created_by       uuid default auth.uid() references public.profiles(id) on delete set null,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
-- Jos taulu luotiin GitHubin aiemmalla määrittelyllä (starts_at/location_id), lisätään UI:n sarakkeet ja löysätään vanhat
alter table public.team_events add column if not exists event_date date;
alter table public.team_events add column if not exists event_time time;
alter table public.team_events add column if not exists place_id uuid references public.team_places(id) on delete set null;
alter table public.team_events add column if not exists place_name text;
alter table public.team_events add column if not exists place_address text;
do $$
begin
  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'team_events' and column_name = 'starts_at') then
    execute 'alter table public.team_events alter column starts_at drop not null';
    execute 'update public.team_events set event_date = (starts_at at time zone ''Europe/Helsinki'')::date, event_time = (starts_at at time zone ''Europe/Helsinki'')::time where event_date is null and starts_at is not null';
  end if;
  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'team_events' and column_name = 'location_id') then
    execute 'update public.team_events e set place_id = e.location_id, place_name = p.name, place_address = nullif(p.address, '''')
               from public.team_places p where p.id = e.location_id and e.place_id is null';
  end if;
  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'team_events' and column_name = 'created_by' and is_nullable = 'NO') then
    execute 'alter table public.team_events alter column created_by drop not null';
  end if;
end $$;
alter table public.team_events alter column created_by set default auth.uid();
create index if not exists team_events_team_idx on public.team_events (team_id);
create index if not exists team_events_date_idx on public.team_events (event_date);

create table if not exists public.team_event_rsvps (
  id            uuid primary key default gen_random_uuid(),
  event_id      uuid not null references public.team_events(id) on delete cascade,
  user_id       uuid not null references public.profiles(id) on delete cascade,
  status        text not null default 'going',
  role_in_event text not null default '' check (char_length(role_in_event) <= 30),
  notes         text not null default '' check (char_length(notes) <= 100),
  created_at    timestamptz not null default now(),
  unique (event_id, user_id)
);
alter table public.team_event_rsvps add column if not exists status text not null default 'going';
alter table public.team_event_rsvps drop constraint if exists team_event_rsvps_status_check;
alter table public.team_event_rsvps add constraint team_event_rsvps_status_check check (status in ('going','maybe'));
create index if not exists team_event_rsvps_event_idx on public.team_event_rsvps (event_id);
create index if not exists team_event_rsvps_user_idx on public.team_event_rsvps (user_id);

create table if not exists public.team_messages (
  id         uuid primary key default gen_random_uuid(),
  team_id    uuid not null references public.teams(id) on delete cascade,
  sender_id  uuid default auth.uid() references public.profiles(id) on delete set null,
  message    text not null check (char_length(message) between 1 and 500),
  created_at timestamptz not null default now()
);
alter table public.team_messages add column if not exists created_at timestamptz not null default now();
alter table public.team_messages alter column sender_id set default auth.uid();
alter table public.team_messages alter column sender_id drop not null;
do $$
begin
  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'team_messages' and column_name = 'sent_at') then
    execute 'update public.team_messages set created_at = sent_at where sent_at is not null and created_at <> sent_at';
  end if;
end $$;
create index if not exists team_messages_team_idx on public.team_messages (team_id, created_at);

create or replace function public.touch_updated_at() returns trigger language plpgsql as $$
begin new.updated_at := now(); return new; end $$;
drop trigger if exists teams_updated_at on public.teams;
create trigger teams_updated_at before update on public.teams for each row execute function public.touch_updated_at();
drop trigger if exists team_events_updated_at on public.team_events;
create trigger team_events_updated_at before update on public.team_events for each row execute function public.touch_updated_at();
drop function if exists public.teams_updated_at();
drop function if exists public.team_events_updated_at();

-- Apufunktiot (security definer) -> ei rekursiota teams <-> team_members -politiikoissa
-- Rooli: manager (joukkueenjohtaja; omistaja on aina manager), coach, member, parent (osio 9a)
create or replace function public.team_role(tid uuid) returns text
language sql stable security definer set search_path = public as $$
  select case when exists (select 1 from public.teams t where t.id = tid and t.owner_id = auth.uid()) then 'manager'
              else (select m.role from public.team_members m where m.team_id = tid and m.user_id = auth.uid()) end
$$;
create or replace function public.is_team_member(tid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and public.team_role(tid) is not null
$$;
create or replace function public.is_team_admin(tid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(public.team_role(tid) = 'manager', false)
$$;
create or replace function public.is_team_coach(tid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(public.team_role(tid) in ('manager','coach'), false)
$$;
create or replace function public.team_of_event(eid uuid) returns uuid
language sql stable security definer set search_path = public as $$
  select team_id from public.team_events where id = eid
$$;

alter table public.teams            enable row level security;
alter table public.team_members     enable row level security;
alter table public.team_roles       enable row level security;
alter table public.team_places      enable row level security;
alter table public.team_events      enable row level security;
alter table public.team_event_rsvps enable row level security;
alter table public.team_messages    enable row level security;

-- vanhat (rekursiiviset) GitHub-politiikat pois
drop policy if exists "teams: jäsenet näkevät" on public.teams;
drop policy if exists "teams: kirjautunut luo" on public.teams;
drop policy if exists "teams: omistaja muokkaa" on public.teams;
drop policy if exists "teams: omistaja poistaa" on public.teams;
drop policy if exists "team_members: jäsenet näkevät" on public.team_members;
drop policy if exists "team_members: omistaja lisää" on public.team_members;
drop policy if exists "team_members: omistaja poistaa" on public.team_members;
drop policy if exists "team_roles: jäsenet näkevät" on public.team_roles;
drop policy if exists "team_roles: omistaja muokkaa" on public.team_roles;
drop policy if exists "team_roles: omistaja poistaa" on public.team_roles;
drop policy if exists "team_places: jäsenet näkevät" on public.team_places;
drop policy if exists "team_places: omistaja muokkaa" on public.team_places;
drop policy if exists "team_places: omistaja poistaa" on public.team_places;
drop policy if exists "team_events: jäsenet näkevät" on public.team_events;
drop policy if exists "team_events: omistaja/coach luo" on public.team_events;
drop policy if exists "team_events: omistaja/coach muokkaa" on public.team_events;
drop policy if exists "team_events: omistaja/coach poistaa" on public.team_events;
drop policy if exists "team_event_rsvps: jäsenet näkevät" on public.team_event_rsvps;
drop policy if exists "team_event_rsvps: jäsen ilmoittautuu" on public.team_event_rsvps;
drop policy if exists "team_event_rsvps: jäsen peruu" on public.team_event_rsvps;
drop policy if exists "team_messages: jäsenet näkevät" on public.team_messages;
drop policy if exists "team_messages: jäsenet lähettävät" on public.team_messages;

-- Vanhat väljät politiikat pois – tiukat politiikat osiossa 9a (joukkue näkyy vain jäsenille, kirjoitukset RPC:llä)
drop policy if exists "teams: kirjautuneet näkevät" on public.teams;
drop policy if exists "teams: kirjautunut luo oman" on public.teams;
drop policy if exists "teams: ylläpitäjä muokkaa" on public.teams;
drop policy if exists "teams: omistaja poistaa oman" on public.teams;

drop policy if exists "team_members: jäsenet näkevät jäsenet" on public.team_members;
drop policy if exists "team_members: liity tai ylläpitäjä lisää" on public.team_members;
drop policy if exists "team_members: ylläpitäjä muuttaa roolin" on public.team_members;
drop policy if exists "team_members: eroa tai ylläpitäjä poistaa" on public.team_members;

drop policy if exists "team_roles: jäsenet lukevat" on public.team_roles;
drop policy if exists "team_roles: ylläpitäjä hallitsee" on public.team_roles;
drop policy if exists "team_places: jäsenet lukevat" on public.team_places;
drop policy if exists "team_places: ylläpitäjä hallitsee" on public.team_places;
drop policy if exists "team_events: jäsenet lukevat" on public.team_events;
drop policy if exists "team_events: valmentaja hallitsee" on public.team_events;
drop policy if exists "team_event_rsvps: jäsenet lukevat" on public.team_event_rsvps;
drop policy if exists "team_event_rsvps: jäsen ilmoittautuu" on public.team_event_rsvps;
drop policy if exists "team_event_rsvps: jäsen muuttaa omaa" on public.team_event_rsvps;
drop policy if exists "team_event_rsvps: jäsen peruu oman" on public.team_event_rsvps;
drop policy if exists "team_messages: jäsenet lukevat" on public.team_messages;
create policy "team_messages: jäsenet lukevat" on public.team_messages for select to authenticated using (public.is_team_member(team_id));
drop policy if exists "team_messages: jäsen lähettää" on public.team_messages;

-- 7c. KAVERIT: kaveripyynnöt, kaverilista (näkymä) ja kutsut tapahtumiin. Kirjoitukset vain RPC:iden kautta.
create table if not exists public.friend_requests (
  id           uuid primary key default gen_random_uuid(),
  requester_id uuid not null references public.profiles(id) on delete cascade,
  target_id    uuid not null references public.profiles(id) on delete cascade,
  event_id     uuid references public.events(id) on delete set null,
  status       text not null default 'pending' check (status in ('pending','accepted','declined')),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  responded_at timestamptz,
  constraint friend_requests_not_self check (requester_id <> target_id)
);
create unique index if not exists friend_requests_pair_key on public.friend_requests
  (least(requester_id, target_id), greatest(requester_id, target_id));
create index if not exists friend_requests_target_idx on public.friend_requests (target_id, status);
create index if not exists friend_requests_requester_idx on public.friend_requests (requester_id, created_at);

create table if not exists public.event_invites (
  event_id   uuid not null references public.events(id) on delete cascade,
  inviter_id uuid not null references public.profiles(id) on delete cascade,
  invitee_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (event_id, inviter_id, invitee_id)
);
create index if not exists event_invites_invitee_idx on public.event_invites (invitee_id);
create index if not exists event_invites_inviter_idx on public.event_invites (inviter_id, created_at);

create or replace view public.friends with (security_invoker = true) as
  select requester_id as user_id, target_id as friend_id, coalesce(responded_at, updated_at) as since
    from public.friend_requests where status = 'accepted'
  union all
  select target_id, requester_id, coalesce(responded_at, updated_at)
    from public.friend_requests where status = 'accepted';

create or replace function public.are_friends(a uuid, b uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.friend_requests r where r.status = 'accepted'
    and least(r.requester_id, r.target_id) = least(a, b) and greatest(r.requester_id, r.target_id) = greatest(a, b))
$$;

-- Kaveripyyntö. Jos toinen on jo pyytänyt sinua -> hyväksytään. Hylättyä omaa pyyntöä ei voi lähettää uudelleen
-- (hylkäystä ei kerrota pyytäjälle). Toinen osapuoli voi silti lähettää oman pyynnön.
create or replace function public.send_friend_request(p_target uuid, p_event uuid default null) returns text
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); r public.friend_requests; nm text;
begin
  if me is null then raise exception 'not_authenticated' using errcode = 'P0001'; end if;
  if public.is_banned() then raise exception 'account_banned' using errcode = 'P0001'; end if;
  if p_target is null or p_target = me then raise exception 'friend_self' using errcode = 'P0001'; end if;
  if not exists (select 1 from public.profiles where id = p_target) then
    raise exception 'friend_target_missing' using errcode = 'P0001';
  end if;
  if (select count(*) from public.friend_requests where requester_id = me and created_at > now() - interval '1 day') >= 50 then
    raise exception 'friend_rate_limited' using errcode = 'P0001';
  end if;
  nm := public.display_name_of(me);
  select * into r from public.friend_requests
    where least(requester_id, target_id) = least(me, p_target) and greatest(requester_id, target_id) = greatest(me, p_target)
    for update;
  if found then
    if r.status = 'accepted' then return 'accepted'; end if;
    if r.requester_id = p_target and r.status = 'pending' then
      update public.friend_requests set status = 'accepted', responded_at = now(), updated_at = now() where id = r.id;
      perform public.notify(p_target, '🤝', 'friend_accepted', jsonb_build_object('name', nm), nm || ' hyväksyi kaveripyyntösi', 'friend', r.id);
      return 'accepted';
    end if;
    if r.requester_id = me then
      if r.status = 'pending' then return 'pending'; end if;
      raise exception 'friend_request_declined' using errcode = 'P0001';
    end if;
    update public.friend_requests
      set requester_id = me, target_id = p_target, status = 'pending', event_id = p_event,
          created_at = now(), updated_at = now(), responded_at = null
      where id = r.id;
  else
    insert into public.friend_requests (requester_id, target_id, event_id) values (me, p_target, p_event) returning * into r;
  end if;
  if not exists (select 1 from public.notifications n where n.user_id = p_target and n.code = 'friend_request'
                 and n.params->>'from' = me::text and n.created_at > now() - interval '1 day') then
    perform public.notify(p_target, '👋', 'friend_request', jsonb_build_object('name', nm, 'from', me), nm || ' lähetti sinulle kaveripyynnön', 'friend', r.id);
  end if;
  return 'pending';
end $$;

create or replace function public.respond_friend_request(p_request uuid, p_accept boolean) returns void
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); r public.friend_requests; nm text;
begin
  if me is null then raise exception 'not_authenticated' using errcode = 'P0001'; end if;
  select * into r from public.friend_requests where id = p_request and target_id = me and status = 'pending' for update;
  if not found then raise exception 'friend_request_not_found' using errcode = 'P0001'; end if;
  update public.friend_requests
    set status = case when p_accept then 'accepted' else 'declined' end, responded_at = now(), updated_at = now()
    where id = r.id;
  if p_accept then
    nm := public.display_name_of(me);
    perform public.notify(r.requester_id, '🤝', 'friend_accepted', jsonb_build_object('name', nm), nm || ' hyväksyi kaveripyyntösi', 'friend', r.id);
  end if;
end $$;

-- Poistaa kaveruuden (kumpi tahansa) tai perii oman odottavan pyynnön
create or replace function public.remove_friend(p_other uuid) returns void
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid();
begin
  if me is null then raise exception 'not_authenticated' using errcode = 'P0001'; end if;
  delete from public.friend_requests
    where least(requester_id, target_id) = least(me, p_other) and greatest(requester_id, target_id) = greatest(me, p_other)
      and (status = 'accepted' or (status = 'pending' and requester_id = me));
end $$;

-- Kutsu kaveri tapahtumaan: vain kavereita, vain tulevia tapahtumia, yksi kutsu / tapahtuma / kaveri
create or replace function public.invite_friend_to_event(p_event uuid, p_friend uuid) returns void
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); e public.events; nm text; n int;
begin
  if me is null then raise exception 'not_authenticated' using errcode = 'P0001'; end if;
  if public.is_banned() then raise exception 'account_banned' using errcode = 'P0001'; end if;
  select * into e from public.events where id = p_event;
  if not found then raise exception 'event_not_found' using errcode = 'P0001'; end if;
  if coalesce(e.ends_at, e.starts_at) < now() then raise exception 'event_in_past' using errcode = 'P0001'; end if;
  if not public.are_friends(me, p_friend) then raise exception 'not_friends' using errcode = 'P0001'; end if;
  if (select count(*) from public.event_invites where inviter_id = me and created_at > now() - interval '1 day') >= 100 then
    raise exception 'friend_rate_limited' using errcode = 'P0001';
  end if;
  insert into public.event_invites (event_id, inviter_id, invitee_id) values (p_event, me, p_friend)
    on conflict do nothing;
  get diagnostics n = row_count;
  if n > 0 then
    nm := public.display_name_of(me);
    perform public.notify(p_friend, '💌', 'event_invite', jsonb_build_object('name', nm, 'title', e.title), nm || ' kutsui sinut tapahtumaan “' || e.title || '”', 'event', p_event);
  end if;
end $$;

alter table public.friend_requests enable row level security;
alter table public.event_invites   enable row level security;
drop policy if exists "friend_requests: osapuolet lukevat" on public.friend_requests;
create policy "friend_requests: osapuolet lukevat" on public.friend_requests for select to authenticated
  using (requester_id = auth.uid() or target_id = auth.uid() or public.is_admin());
drop policy if exists "event_invites: osapuolet lukevat" on public.event_invites;
create policy "event_invites: osapuolet lukevat" on public.event_invites for select to authenticated
  using (inviter_id = auth.uid() or invitee_id = auth.uid());

-- 7d. OIKEUDET uusille tauluille ja funktioille
revoke all on public.items, public.item_contacts, public.teams, public.team_members, public.team_roles,
  public.team_places, public.team_events, public.team_event_rsvps, public.team_messages,
  public.friend_requests, public.event_invites, public.friends from anon;
grant select, insert, update, delete on public.items, public.item_contacts, public.teams, public.team_members,
  public.team_roles, public.team_places, public.team_events, public.team_event_rsvps, public.team_messages to authenticated;
revoke insert, update, delete on public.friend_requests, public.event_invites from authenticated;
grant select on public.friend_requests, public.event_invites, public.friends to authenticated;

revoke execute on function public.submit_item(jsonb, jsonb) from public, anon;
revoke execute on function public.close_item(uuid, text) from public, anon;
revoke execute on function public.is_team_member(uuid) from public, anon;
revoke execute on function public.is_team_admin(uuid) from public, anon;
revoke execute on function public.is_team_coach(uuid) from public, anon;
revoke execute on function public.team_of_event(uuid) from public, anon;
revoke execute on function public.are_friends(uuid, uuid) from public, anon;
revoke execute on function public.send_friend_request(uuid, uuid) from public, anon;
revoke execute on function public.respond_friend_request(uuid, boolean) from public, anon;
revoke execute on function public.remove_friend(uuid) from public, anon;
revoke execute on function public.invite_friend_to_event(uuid, uuid) from public, anon;
revoke execute on function public.items_before_write() from public, anon, authenticated;
revoke execute on function public.item_contacts_before_insert() from public, anon, authenticated;
grant execute on function public.submit_item(jsonb, jsonb) to authenticated;
grant execute on function public.close_item(uuid, text) to authenticated;
grant execute on function public.is_team_member(uuid) to authenticated;
grant execute on function public.is_team_admin(uuid) to authenticated;
grant execute on function public.is_team_coach(uuid) to authenticated;
grant execute on function public.team_of_event(uuid) to authenticated;
grant execute on function public.are_friends(uuid, uuid) to authenticated;
grant execute on function public.send_friend_request(uuid, uuid) to authenticated;
grant execute on function public.respond_friend_request(uuid, boolean) to authenticated;
grant execute on function public.remove_friend(uuid) to authenticated;
grant execute on function public.invite_friend_to_event(uuid, uuid) to authenticated;

-- 7e. JOUKKUETILIN PYYNTÖ (2026-10-01): käyttäjä pyytää joukkue-/seuratiliä → ylläpito hyväksyy tai hylkää käsin
--     (ylläpitojono). Ei maksua eikä hintaa. Hyväksyntä luo joukkueen ja joukkueen hallintasivun (osio 9a).
--     Kirjoitukset vain RPC:iden kautta (request_team_account, admin_review_team_request). anon: ei mitään.
create table if not exists public.team_requests (
  id            uuid primary key default gen_random_uuid(),
  requester_id  uuid not null references public.profiles(id) on delete cascade,
  team_name     text not null check (char_length(team_name) between 2 and 80),
  sport         text not null check (char_length(sport) between 2 and 60),
  city          text not null check (char_length(city) between 2 and 60),
  contact_name  text not null check (char_length(contact_name) between 2 and 80),
  contact_email text not null check (char_length(contact_email) <= 200 and contact_email ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'),
  contact_phone text not null default '' check (contact_phone = '' or contact_phone ~ '^\+?[0-9][0-9 ()-]{5,19}$'),
  description   text not null default '' check (char_length(description) <= 800),
  status        text not null default 'pending' check (status in ('pending','approved','rejected')),
  admin_reason  text not null default '' check (char_length(admin_reason) <= 300),
  reviewed_by   uuid references public.profiles(id) on delete set null,
  reviewed_at   timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index if not exists team_requests_requester_idx on public.team_requests (requester_id, created_at desc);
create index if not exists team_requests_status_idx on public.team_requests (status, created_at);

create or replace function public.request_team_account(req jsonb) returns uuid
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); rid uuid;
  v_name text := btrim(regexp_replace(coalesce(req->>'team_name', ''), '\s+', ' ', 'g'));
  v_sport text := btrim(regexp_replace(coalesce(req->>'sport', ''), '\s+', ' ', 'g'));
  v_city text := btrim(regexp_replace(coalesce(req->>'city', ''), '\s+', ' ', 'g'));
  v_cname text := btrim(regexp_replace(coalesce(req->>'contact_name', ''), '\s+', ' ', 'g'));
  v_email text := lower(btrim(coalesce(req->>'contact_email', '')));
  v_phone text := btrim(coalesce(req->>'contact_phone', ''));
  v_desc text := btrim(coalesce(req->>'description', ''));
begin
  if me is null then raise exception 'not_authenticated' using errcode = 'P0001'; end if;
  if public.is_banned() then raise exception 'account_banned' using errcode = 'P0001'; end if;
  if not coalesce((select email_verified from public.profiles where id = me), false) then
    raise exception 'email_not_verified' using errcode = 'P0001';
  end if;
  if char_length(v_name) not between 2 and 80 or char_length(v_sport) not between 2 and 60
     or char_length(v_city) not between 2 and 60 or char_length(v_cname) not between 2 and 80
     or char_length(v_desc) > 800 or char_length(v_email) > 200
     or v_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'
     or (v_phone <> '' and v_phone !~ '^\+?[0-9][0-9 ()-]{5,19}$') then
    raise exception 'team_request_invalid' using errcode = 'P0001';
  end if;
  if (select count(*) from public.team_requests where requester_id = me and status = 'pending') >= 3
     or (select count(*) from public.team_requests where requester_id = me and created_at > now() - interval '1 day') >= 5 then
    raise exception 'too_many_team_requests' using errcode = 'P0001';
  end if;
  insert into public.team_requests (requester_id, team_name, sport, city, contact_name, contact_email, contact_phone, description)
  values (me, v_name, v_sport, v_city, v_cname, v_email, v_phone, v_desc)
  returning id into rid;
  perform public.notify_admins('👥', 'admin_new_team_request', jsonb_build_object('name', v_name, 'sport', v_sport, 'city', v_city),
    'Uusi joukkuetilipyyntö: “' || v_name || '” (' || v_sport || ', ' || v_city || ')', 'admin', rid);
  return rid;
end $$;

-- Ylläpito: hyväksy / hylkää (hylkäyksessä syy pakollinen). Hyväksyntä luo joukkueen (osio 9a, pyytäjästä
-- joukkueenjohtaja) ja avaa hallintasivun; pyytäjä saa ilmoituksen.
create or replace function public.admin_review_team_request(p_id uuid, p_status text, p_reason text default '') returns void
language plpgsql security definer set search_path = public as $$
declare r public.team_requests; v_reason text := left(btrim(coalesce(p_reason, '')), 300); tid uuid;
begin
  if auth.uid() is null or not public.is_admin() then raise exception 'admin_only' using errcode = 'P0001'; end if;
  if p_status not in ('approved', 'rejected') then raise exception 'team_request_invalid' using errcode = 'P0001'; end if;
  if p_status = 'rejected' and char_length(v_reason) < 3 then raise exception 'reason_required' using errcode = 'P0001'; end if;
  select * into r from public.team_requests where id = p_id for update;
  if not found then raise exception 'team_request_not_found' using errcode = 'P0001'; end if;
  if r.status <> 'pending' then raise exception 'team_request_already_reviewed' using errcode = 'P0001'; end if;
  update public.team_requests
     set status = p_status, admin_reason = case when p_status = 'rejected' then v_reason else '' end,
         reviewed_by = auth.uid(), reviewed_at = now(), updated_at = now()
   where id = p_id;
  if p_status = 'approved' then
    tid := public.create_team_from_request(r);
    perform public.notify(r.requester_id, '✅', 'team_request_approved', jsonb_build_object('name', r.team_name),
      'Joukkuetilipyyntö “' || r.team_name || '” hyväksyttiin 🎉 Joukkueen hallintasivu on nyt avattu sinulle.', 'team', tid);
  else
    perform public.notify(r.requester_id, '❌', 'team_request_rejected', jsonb_build_object('name', r.team_name, 'reason', v_reason),
      'Joukkuetilipyyntöä “' || r.team_name || '” ei hyväksytty. Syy: ' || v_reason, 'team', r.id);
  end if;
end $$;

alter table public.team_requests enable row level security;
drop policy if exists "team_requests: pyytäjä ja ylläpito lukevat" on public.team_requests;
create policy "team_requests: pyytäjä ja ylläpito lukevat" on public.team_requests for select to authenticated
  using (requester_id = auth.uid() or public.is_admin());
revoke all on public.team_requests from public, anon, authenticated;
grant select on public.team_requests to authenticated;
revoke execute on function public.request_team_account(jsonb) from public, anon;
revoke execute on function public.admin_review_team_request(uuid, text, text) from public, anon;
grant execute on function public.request_team_account(jsonb) to authenticated;
grant execute on function public.admin_review_team_request(uuid, text, text) to authenticated;

-- ---------------------------------------------------------------------
-- 8. KUVAT, CHATTIRYHMÄT JA LAJILISTA (2026-10-02)
--    8a. Lajit: käännetyt nimet (name_i18n), tila (approved/pending/rejected), ylläpidon jono, lisälajit.
--        Suosikit = profiles.favs (käyttäjän tähdittämät lajit, näkyvät ensin suodattimessa ja luontilomakkeessa).
--    8b. Kuvat (Supabase Storage): tapahtuman kansikuva (julkinen bucket event-covers, satunnainen polku
--        <event_id>/<satunnainen>.webp) ja chattikuvat (yksityinen bucket chat-images, polku <conversation_id>/…,
--        luku vain keskustelun jäsenille – signed URL). Bucketin raja: 256 kt, vain image/webp + image/jpeg.
--        Client pakkaa (pitkä sivu ≤1600 px, ≤ ~200 kt, EXIF/GPS pois uudelleenpiirrolla).
--    8c. Chattiryhmät: avoin (haku + lähellä, kuka tahansa liittyy) tai suljettu (kutsu perustajalta/moderaattorilta
--        tai hyväksytty liittymispyyntö). Perustaja poistaa jäseniä ja nimittää moderaattorit. Chat = conversations
--        (kind 'group'), realtime + kuvat. Kirjoitukset vain RPC:iden kautta. anon: ei mitään.
--    8d. Ilmoitukset (reports) myös viesteistä/kuvista, kansikuvista ja ryhmistä; ylläpito poistaa.
-- ---------------------------------------------------------------------

-- 8a. LAJIT --------------------------------------------------------------
alter table public.activities add column if not exists name_i18n jsonb not null default '{}'::jsonb;
alter table public.activities add column if not exists status text not null default 'approved';
alter table public.activities add column if not exists reviewed_by uuid references public.profiles(id) on delete set null;
alter table public.activities add column if not exists reviewed_at timestamptz;
alter table public.activities drop constraint if exists activities_status_check;
alter table public.activities add constraint activities_status_check check (status in ('approved','pending','rejected'));
alter table public.activities drop constraint if exists activities_name_i18n_check;
alter table public.activities add constraint activities_name_i18n_check check (
  jsonb_typeof(name_i18n) = 'object' and pg_column_size(name_i18n) <= 1000);
create index if not exists activities_status_idx on public.activities (status, created_at);

-- Käännetyt nimet perusdatan lajeille (sama kuin i18n.js act.<id>)
update public.activities a set name_i18n = v.n::jsonb
from (values
  ('padel','{"fi":"Padel","en":"Padel","sv":"Padel","es":"Pádel"}'),
  ('sulkapallo','{"fi":"Sulkapallo","en":"Badminton","sv":"Badminton","es":"Bádminton"}'),
  ('tennis','{"fi":"Tennis","en":"Tennis","sv":"Tennis","es":"Tenis"}'),
  ('juoksu','{"fi":"Juoksu","en":"Running","sv":"Löpning","es":"Correr"}'),
  ('kavely','{"fi":"Kävely","en":"Walking","sv":"Promenader","es":"Caminar"}'),
  ('vaellus','{"fi":"Vaellus","en":"Hiking","sv":"Vandring","es":"Senderismo"}'),
  ('pyoraily','{"fi":"Pyöräily","en":"Cycling","sv":"Cykling","es":"Ciclismo"}'),
  ('kuntosali','{"fi":"Kuntosali","en":"Gym","sv":"Gym","es":"Gimnasio"}'),
  ('jooga','{"fi":"Jooga","en":"Yoga","sv":"Yoga","es":"Yoga"}'),
  ('uinti','{"fi":"Uinti","en":"Swimming","sv":"Simning","es":"Natación"}'),
  ('frisbeegolf','{"fi":"Frisbeegolf","en":"Disc golf","sv":"Discgolf","es":"Disc golf"}'),
  ('jalkapallo','{"fi":"Jalkapallo","en":"Football","sv":"Fotboll","es":"Fútbol"}'),
  ('salibandy','{"fi":"Salibandy","en":"Floorball","sv":"Innebandy","es":"Floorball"}'),
  ('lautapelit','{"fi":"Lautapelit","en":"Board games","sv":"Brädspel","es":"Juegos de mesa"}'),
  ('kahvi','{"fi":"Kahvi & juttelu","en":"Coffee & chat","sv":"Kaffe & prat","es":"Café y charla"}'),
  ('valokuvaus','{"fi":"Valokuvaus","en":"Photography","sv":"Fotografering","es":"Fotografía"}'),
  ('kalastus','{"fi":"Kalastus","en":"Fishing","sv":"Fiske","es":"Pesca"}'),
  ('neulonta','{"fi":"Neulonta","en":"Knitting","sv":"Stickning","es":"Punto"}'),
  ('kieltenvaihto','{"fi":"Kieltenvaihto","en":"Language exchange","sv":"Språkutbyte","es":"Intercambio de idiomas"}'),
  ('konsertit','{"fi":"Konsertit","en":"Concerts","sv":"Konserter","es":"Conciertos"}'),
  ('festivaali','{"fi":"Festivaalit","en":"Festivals","sv":"Festivaler","es":"Festivales"}'),
  ('markkinat','{"fi":"Markkinat","en":"Markets & fairs","sv":"Marknader","es":"Mercadillos y ferias"}'),
  ('juoksutapahtuma','{"fi":"Juoksutapahtumat","en":"Running events","sv":"Löpartävlingar","es":"Carreras populares"}'),
  ('kulttuuri','{"fi":"Kulttuuri","en":"Culture","sv":"Kultur","es":"Cultura"}'),
  ('nakuuinti','{"fi":"Nakuuinti","en":"Skinny dipping","sv":"Nakenbad","es":"Baño nudista"}'),
  ('pelle','{"fi":"Pellekokoontuminen","en":"Clown meetup","sv":"Clownträff","es":"Quedada de payasos"}'),
  ('konjakkipiknik','{"fi":"Konjakkipiknik","en":"Cognac picnic","sv":"Konjakspicknick","es":"Pícnic con coñac"}'),
  ('pyjamabrunssi','{"fi":"Pyjamabrunssi","en":"Pyjama brunch","sv":"Pyjamasbrunch","es":"Brunch en pijama"}'),
  ('karaokepuisto','{"fi":"Karaoke puistossa","en":"Karaoke in the park","sv":"Karaoke i parken","es":"Karaoke en el parque"}'),
  ('vesisota','{"fi":"Vesipyssytaistelu","en":"Water pistol fight","sv":"Vattenpistolkrig","es":"Guerra de pistolas de agua"}'),
  ('flashmob','{"fi":"Tanssia bussipysäkillä","en":"Dancing at the bus stop","sv":"Dans vid busshållplatsen","es":"Bailar en la parada del bus"}'),
  ('avanto','{"fi":"Avantouinti auringonnousussa","en":"Ice swimming at sunrise","sv":"Vinterbad i soluppgången","es":"Baño helado al amanecer"}'),
  ('huonorunous','{"fi":"Vuoden huonoin runo -ilta","en":"Worst Poem of the Year night","sv":"Årets sämsta dikt-kväll","es":"Noche del peor poema del año"}'),
  ('kasari','{"fi":"Pukeudu 80-luvuksi","en":"Dress up 80s style","sv":"Klä ut dig i 80-talsstil","es":"Vístete de los 80"}')
) as v(id, n)
where a.id = v.id and a.name_i18n is distinct from v.n::jsonb;

-- Lisää yleisiä lajeja hakua varten (ei lisätä, jos samanniminen laji on jo olemassa toisella id:llä)
insert into public.activities (id, name, emoji, hue, is_crazy, crazy_level, is_adult, is_custom, sort_order, created_by, status, name_i18n)
select v.id, v.name, v.emoji, v.hue, false, 0, false, false, v.so, null, 'approved', v.n::jsonb
from (values
  ('koripallo','Koripallo','🏀', 25,250,'{"fi":"Koripallo","en":"Basketball","sv":"Basket","es":"Baloncesto"}'),
  ('lentopallo','Lentopallo','🏐', 45,260,'{"fi":"Lentopallo","en":"Volleyball","sv":"Volleyboll","es":"Voleibol"}'),
  ('golf','Golf','⛳',110,270,'{"fi":"Golf","en":"Golf","sv":"Golf","es":"Golf"}'),
  ('kiipeily','Kiipeily','🧗', 20,280,'{"fi":"Kiipeily","en":"Climbing","sv":"Klättring","es":"Escalada"}'),
  ('hiihto','Hiihto','⛷️',200,290,'{"fi":"Hiihto","en":"Cross-country skiing","sv":"Längdskidåkning","es":"Esquí de fondo"}'),
  ('luistelu','Luistelu','⛸️',195,300,'{"fi":"Luistelu","en":"Ice skating","sv":"Skridskoåkning","es":"Patinaje sobre hielo"}'),
  ('melonta','Melonta','🛶',185,310,'{"fi":"Melonta","en":"Kayaking","sv":"Paddling","es":"Piragüismo"}'),
  ('sup','SUP-lautailu','🏄',190,320,'{"fi":"SUP-lautailu","en":"Stand-up paddling","sv":"SUP-paddling","es":"Paddle surf"}'),
  ('tanssi','Tanssi','💃',320,330,'{"fi":"Tanssi","en":"Dancing","sv":"Dans","es":"Baile"}'),
  ('shakki','Shakki','♟️',240,340,'{"fi":"Shakki","en":"Chess","sv":"Schack","es":"Ajedrez"}'),
  ('poytatennis','Pöytätennis','🏓',160,350,'{"fi":"Pöytätennis","en":"Table tennis","sv":"Bordtennis","es":"Tenis de mesa"}'),
  ('squash','Squash','🎾', 70,360,'{"fi":"Squash","en":"Squash","sv":"Squash","es":"Squash"}'),
  ('jaakiekko','Jääkiekko','🏒',210,370,'{"fi":"Jääkiekko","en":"Ice hockey","sv":"Ishockey","es":"Hockey sobre hielo"}'),
  ('kirjapiiri','Kirjapiiri','📚',280,380,'{"fi":"Kirjapiiri","en":"Book club","sv":"Bokcirkel","es":"Club de lectura"}')
) as v(id, name, emoji, hue, so, n)
where not exists (select 1 from public.activities x where lower(x.name) = lower(v.name) and x.id <> v.id)
on conflict (id) do update set
  name = excluded.name, emoji = excluded.emoji, hue = excluded.hue, is_custom = false,
  sort_order = excluded.sort_order, status = 'approved', name_i18n = excluded.name_i18n;

-- Uusi laji (käyttäjä) -> ylläpidolle ilmoitus (jono "Lajit")
create or replace function public.activities_after_insert() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'pending' then
    perform public.notify_admins('🏷️', 'admin_new_activity', jsonb_build_object('name', new.name),
      'Uusi laji odottaa hyväksyntää: “' || new.name || '”', 'admin', null);
  end if;
  return null;
end $$;
drop trigger if exists activities_after_insert on public.activities;
create trigger activities_after_insert after insert on public.activities
  for each row execute function public.activities_after_insert();

-- Ylläpito: hyväksy (lisää yhteiseen listaan, valinnaisesti käännökset) / hylkää. Lisääjä saa ilmoituksen.
create or replace function public.admin_review_activity(p_id text, p_status text, p_names jsonb default null) returns void
language plpgsql security definer set search_path = public as $$
declare a public.activities; n jsonb := '{}'::jsonb; k text; v text;
begin
  if auth.uid() is null or not public.is_admin() then raise exception 'admin_only' using errcode = 'P0001'; end if;
  if p_status not in ('approved','rejected') then raise exception 'activity_status_invalid' using errcode = 'P0001'; end if;
  select * into a from public.activities where id = p_id for update;
  if not found then raise exception 'activity_not_found' using errcode = 'P0001'; end if;
  if p_names is not null and jsonb_typeof(p_names) = 'object' then
    for k, v in select key, btrim(value) from jsonb_each_text(p_names) loop
      if k in ('fi','en','sv','es') and char_length(v) between 2 and 40 then n := n || jsonb_build_object(k, v); end if;
    end loop;
  end if;
  update public.activities set status = p_status, name_i18n = a.name_i18n || n,
         reviewed_by = auth.uid(), reviewed_at = now() where id = p_id;
  if a.created_by is not null and a.status is distinct from p_status then
    if p_status = 'approved' then
      perform public.notify(a.created_by, '🏷️', 'activity_approved', jsonb_build_object('name', a.name),
        'Ehdottamasi laji “' || a.name || '” lisättiin kaikkien lajilistaan 🎉', null, null);
    else
      perform public.notify(a.created_by, 'ℹ️', 'activity_rejected', jsonb_build_object('name', a.name),
        'Ehdottamaasi lajia “' || a.name || '” ei lisätty yhteiseen listaan. Voit silti käyttää sitä omissa tapahtumissasi.', null, null);
    end if;
  end if;
end $$;

-- 8b. KUVAT ---------------------------------------------------------------

alter table public.messages add column if not exists image_path text;
alter table public.messages add column if not exists image_w int;
alter table public.messages add column if not exists image_h int;
alter table public.messages drop constraint if exists messages_image_check;
alter table public.messages add constraint messages_image_check check (
  (image_path is null and image_w is null and image_h is null)
  or (public.valid_image_path(image_path) and public.path_uuid(image_path) = conversation_id
      and coalesce(image_w, 1) between 1 and 4000 and coalesce(image_h, 1) between 1 and 4000));
alter table public.messages drop constraint if exists messages_body_check;
alter table public.messages add constraint messages_body_check check (
  char_length(body) <= 1000 and (char_length(body) >= 1 or image_path is not null));
create index if not exists messages_image_idx on public.messages (image_path) where image_path is not null;

-- Saako kutsuja muokata tapahtumaa (kansikuva)? järjestäjä, ylläpito tai yrityksen jäsen (aktiivinen tilaus)
create or replace function public.can_edit_event(eid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.events e where e.id = eid and (
    (e.host_id is not null and e.host_id = auth.uid()) or public.is_admin()
    or (e.business_id is not null and public.business_can_post(e.business_id))))
$$;
-- Kuvia saa lähettää tapahtuma-, ryhmä- ja joukkuechatteihin (ei avunpyyntöjen chatteihin), vain jäsenet, ei estetyt
create or replace function public.can_post_image(cid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select not public.is_banned() and public.is_conversation_member(cid)
     and exists (select 1 from public.conversations c where c.id = cid and c.kind in ('event','group','team'))
$$;
-- Ylläpito näkee chattikuvan vain, jos siitä on avoin ilmoitus
create or replace function public.image_reported(p text) returns boolean
language sql stable security definer set search_path = public as $$
  select public.is_admin() and exists (
    select 1 from public.reports r join public.messages m on m.id = r.target_id
    where r.target_type = 'message' and r.status = 'open' and m.image_path = p)
$$;

-- Kansikuvan ja chattikuvan on oltava oikeasti tallennettu (storage.objects), muuten polku hylätään
create or replace function public.storage_object_exists(b text, p text) returns boolean
language plpgsql stable security definer set search_path = public as $$
begin
  if to_regclass('storage.objects') is null then return true; end if;   -- ei Storagea (paikallinen testikanta)
  return exists (select 1 from storage.objects o where o.bucket_id = b and o.name = p);
end $$;

create or replace function public.events_cover_check() returns trigger
language plpgsql as $$
begin
  if new.cover_path is not null and new.cover_path is distinct from (case when tg_op = 'UPDATE' then old.cover_path end) then
    if auth.uid() is not null and public.is_banned() then raise exception 'account_banned' using errcode = 'P0001'; end if;
    if not public.valid_image_path(new.cover_path) or public.path_uuid(new.cover_path) is distinct from new.id then
      raise exception 'image_path_invalid' using errcode = 'P0001';
    end if;
    if not public.storage_object_exists('event-covers', new.cover_path) then
      raise exception 'image_missing' using errcode = 'P0001';
    end if;
  end if;
  return new;
end $$;
drop trigger if exists events_cover_check on public.events;
create trigger events_cover_check before insert or update of cover_path on public.events
  for each row execute function public.events_cover_check();

-- Storage-bucketit ja -säännöt (vain jos Supabase Storage on käytössä)
do $$
begin
  if to_regclass('storage.buckets') is null or to_regclass('storage.objects') is null then
    raise notice 'storage schema missing - skipping buckets/policies';
    return;
  end if;
  insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
    values ('event-covers', 'event-covers', true, 262144, array['image/webp','image/jpeg'])
    on conflict (id) do update set public = true, file_size_limit = 262144, allowed_mime_types = array['image/webp','image/jpeg'];
  insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
    values ('chat-images', 'chat-images', false, 262144, array['image/webp','image/jpeg'])
    on conflict (id) do update set public = false, file_size_limit = 262144, allowed_mime_types = array['image/webp','image/jpeg'];

  drop policy if exists "molaplan covers: editor uploads" on storage.objects;
  create policy "molaplan covers: editor uploads" on storage.objects for insert to authenticated
    with check (bucket_id = 'event-covers' and public.valid_image_path(name) and not public.is_banned()
                and public.can_edit_event(public.path_uuid(name)));
  drop policy if exists "molaplan covers: editor reads" on storage.objects;
  create policy "molaplan covers: editor reads" on storage.objects for select to authenticated
    using (bucket_id = 'event-covers' and (public.can_edit_event(public.path_uuid(name)) or public.is_admin()));
  drop policy if exists "molaplan covers: editor deletes" on storage.objects;
  create policy "molaplan covers: editor deletes" on storage.objects for delete to authenticated
    using (bucket_id = 'event-covers' and (public.can_edit_event(public.path_uuid(name)) or public.is_admin()));

  drop policy if exists "molaplan chat images: members upload" on storage.objects;
  create policy "molaplan chat images: members upload" on storage.objects for insert to authenticated
    with check (bucket_id = 'chat-images' and public.valid_image_path(name) and public.can_post_image(public.path_uuid(name)));
  drop policy if exists "molaplan chat images: members read" on storage.objects;
  create policy "molaplan chat images: members read" on storage.objects for select to authenticated
    using (bucket_id = 'chat-images' and (public.is_conversation_member(public.path_uuid(name)) or public.image_reported(name)));
  drop policy if exists "molaplan chat images: uploader or admin deletes" on storage.objects;
  create policy "molaplan chat images: uploader or admin deletes" on storage.objects for delete to authenticated
    using (bucket_id = 'chat-images' and (owner_id = auth.uid()::text or public.is_admin()));
end $$;

-- 8c. CHATTIRYHMÄT ----------------------------------------------------------
create table if not exists public.groups (
  id          uuid primary key default gen_random_uuid(),
  name        text not null check (char_length(name) between 3 and 60),
  description text not null default '' check (char_length(description) <= 600),
  visibility  text not null default 'open' check (visibility in ('open','closed')),
  activity_id text references public.activities(id) on update cascade on delete set null,
  city        text not null default '' check (char_length(city) <= 40),
  district    text not null default '' check (char_length(district) <= 40),
  lat         double precision check (lat between -90 and 90),
  lng         double precision check (lng between -180 and 180),
  founder_id  uuid references public.profiles(id) on delete set null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index if not exists groups_visibility_idx on public.groups (visibility, created_at desc);
create index if not exists groups_founder_idx on public.groups (founder_id, created_at);

create table if not exists public.group_members (
  group_id  uuid not null references public.groups(id) on delete cascade,
  user_id   uuid not null references public.profiles(id) on delete cascade,
  role      text not null default 'member' check (role in ('founder','moderator','member')),
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);
create unique index if not exists group_members_one_founder on public.group_members (group_id) where role = 'founder';
create index if not exists group_members_user_idx on public.group_members (user_id);

create table if not exists public.group_invites (
  group_id   uuid not null references public.groups(id) on delete cascade,
  invitee_id uuid not null references public.profiles(id) on delete cascade,
  inviter_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  primary key (group_id, invitee_id)
);
create index if not exists group_invites_invitee_idx on public.group_invites (invitee_id);
create index if not exists group_invites_inviter_idx on public.group_invites (inviter_id, created_at);

create table if not exists public.group_join_requests (
  group_id   uuid not null references public.groups(id) on delete cascade,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  message    text not null default '' check (char_length(message) <= 200),
  status     text not null default 'pending' check (status in ('pending','approved','declined')),
  created_at timestamptz not null default now(),
  decided_by uuid references public.profiles(id) on delete set null,
  decided_at timestamptz,
  primary key (group_id, user_id)
);
create index if not exists group_join_requests_user_idx on public.group_join_requests (user_id, created_at);

-- Ryhmän chat = conversations.kind 'group'
alter table public.conversations add column if not exists group_id uuid;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'conversations_group_id_fkey') then
    alter table public.conversations add constraint conversations_group_id_fkey
      foreign key (group_id) references public.groups(id) on delete cascade;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'conversations_group_id_key') then
    alter table public.conversations add constraint conversations_group_id_key unique (group_id);
  end if;
end $$;
alter table public.conversations drop constraint if exists conversations_kind_check;
alter table public.conversations add constraint conversations_kind_check check (kind in ('event','help','group'));
alter table public.conversations drop constraint if exists conversations_target;
alter table public.conversations add constraint conversations_target check (
  (kind = 'event' and event_id is not null and help_request_id is null and group_id is null) or
  (kind = 'help'  and help_request_id is not null and event_id is null and group_id is null) or
  (kind = 'group' and group_id is not null and event_id is null and help_request_id is null));

alter table public.notifications drop constraint if exists notifications_link_kind_check;
alter table public.notifications add constraint notifications_link_kind_check
  check (link_kind in ('request','help','chat','event','admin','business','friend','team','group'));

create or replace function public.group_role(gid uuid) returns text
language sql stable security definer set search_path = public as $$
  select m.role from public.group_members m where m.group_id = gid and m.user_id = auth.uid()
$$;
create or replace function public.is_group_member(gid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.group_members m where m.group_id = gid and m.user_id = auth.uid())
$$;
create or replace function public.is_group_mod(gid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.group_members m where m.group_id = gid and m.user_id = auth.uid()
                 and m.role in ('founder','moderator'))
$$;
create or replace function public.group_member_count(gid uuid) returns int
language sql stable security definer set search_path = public as $$
  select count(*)::int from public.group_members where group_id = gid
$$;
-- Ryhmä näkyy listassa: avoimet kaikille kirjautuneille; suljetut jäsenille, kutsutuille ja pyynnön tehneille
create or replace function public.group_visible(gid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.groups g where g.id = gid and (
    g.visibility = 'open' or public.is_admin()
    or exists (select 1 from public.group_members m where m.group_id = g.id and m.user_id = auth.uid())
    or exists (select 1 from public.group_invites i where i.group_id = g.id and i.invitee_id = auth.uid())
    or exists (select 1 from public.group_join_requests r where r.group_id = g.id and r.user_id = auth.uid())))
$$;

create or replace function public.group_input_ok(v_name text, v_desc text) returns void
language plpgsql stable security definer set search_path = public as $$
begin
  if char_length(v_name) not between 3 and 60 or char_length(v_desc) > 600 then
    raise exception 'group_invalid' using errcode = 'P0001';
  end if;
  if not public.is_admin() and (public.looks_commercial(v_name) or public.looks_commercial(v_desc)) then
    raise exception 'commercial_content' using errcode = 'P0001';
  end if;
end $$;

create or replace function public.create_group(p jsonb) returns uuid
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); gid uuid; cid uuid;
  v_name text := btrim(regexp_replace(coalesce(p->>'name', ''), '\s+', ' ', 'g'));
  v_desc text := btrim(coalesce(p->>'description', ''));
  v_vis text := coalesce(nullif(p->>'visibility', ''), 'open');
  v_act text := nullif(p->>'activity_id', '');
begin
  if me is null then raise exception 'not_authenticated' using errcode = 'P0001'; end if;
  if public.is_banned() then raise exception 'account_banned' using errcode = 'P0001'; end if;
  if v_vis not in ('open','closed') then raise exception 'group_invalid' using errcode = 'P0001'; end if;
  perform public.group_input_ok(v_name, v_desc);
  if v_act is not null and not exists (select 1 from public.activities where id = v_act) then v_act := null; end if;
  if (select count(*) from public.groups where founder_id = me and created_at > now() - interval '1 day') >= 5 then
    raise exception 'group_rate_limited' using errcode = 'P0001';
  end if;
  insert into public.groups (name, description, visibility, activity_id, city, district, lat, lng, founder_id)
  values (v_name, v_desc, v_vis, v_act, left(btrim(coalesce(p->>'city', '')), 40), left(btrim(coalesce(p->>'district', '')), 40),
          case when (p->>'lat') ~ '^-?[0-9]+(\.[0-9]+)?$' and abs((p->>'lat')::float8) <= 90 then (p->>'lat')::float8 end,
          case when (p->>'lng') ~ '^-?[0-9]+(\.[0-9]+)?$' and abs((p->>'lng')::float8) <= 180 then (p->>'lng')::float8 end, me)
  returning id into gid;
  insert into public.group_members (group_id, user_id, role) values (gid, me, 'founder');
  insert into public.conversations (kind, group_id) values ('group', gid) returning id into cid;
  perform public.post_system_message(cid, 'group_created', jsonb_build_object('name', v_name), 'Ryhmä “' || v_name || '” perustettiin – tervetuloa! 👋');
  return gid;
end $$;

create or replace function public.update_group(p_id uuid, p jsonb) returns void
language plpgsql security definer set search_path = public as $$
declare g public.groups;
  v_name text; v_desc text; v_vis text; v_act text;
begin
  if auth.uid() is null then raise exception 'not_authenticated' using errcode = 'P0001'; end if;
  if public.is_banned() then raise exception 'account_banned' using errcode = 'P0001'; end if;
  select * into g from public.groups where id = p_id for update;
  if not found then raise exception 'group_not_found' using errcode = 'P0001'; end if;
  if coalesce(public.group_role(p_id), '') <> 'founder' and not public.is_admin() then raise exception 'group_founder_only' using errcode = 'P0001'; end if;
  v_name := btrim(regexp_replace(coalesce(p->>'name', g.name), '\s+', ' ', 'g'));
  v_desc := btrim(coalesce(p->>'description', g.description));
  v_vis := coalesce(nullif(p->>'visibility', ''), g.visibility);
  v_act := case when p ? 'activity_id' then nullif(p->>'activity_id', '') else g.activity_id end;
  if v_vis not in ('open','closed') then raise exception 'group_invalid' using errcode = 'P0001'; end if;
  perform public.group_input_ok(v_name, v_desc);
  if v_act is not null and not exists (select 1 from public.activities where id = v_act) then v_act := null; end if;
  update public.groups set name = v_name, description = v_desc, visibility = v_vis, activity_id = v_act,
    city = case when p ? 'city' then left(btrim(coalesce(p->>'city', '')), 40) else city end,
    district = case when p ? 'district' then left(btrim(coalesce(p->>'district', '')), 40) else district end,
    updated_at = now()
  where id = p_id;
end $$;

-- Ryhmän poisto: perustaja tai ylläpito (chatti ja jäsenyydet poistuvat cascade-säännöillä)
create or replace function public.delete_group(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated' using errcode = 'P0001'; end if;
  if coalesce(public.group_role(p_id), '') <> 'founder' and not public.is_admin() then raise exception 'group_founder_only' using errcode = 'P0001'; end if;
  delete from public.groups where id = p_id;
  update public.reports set status = 'resolved', resolved_by = auth.uid(), resolved_at = now()
    where target_type = 'group' and target_id = p_id and status = 'open';
end $$;

create or replace function public.group_add_member(gid uuid, uid uuid) returns void
language plpgsql security definer set search_path = public as $$
declare cid uuid; nm text; g public.groups;
begin
  insert into public.group_members (group_id, user_id, role) values (gid, uid, 'member') on conflict do nothing;
  if not found then return; end if;
  delete from public.group_invites where group_id = gid and invitee_id = uid;
  update public.group_join_requests set status = 'approved', decided_at = coalesce(decided_at, now()) where group_id = gid and user_id = uid and status = 'pending';
  select * into g from public.groups where id = gid;
  select id into cid from public.conversations where group_id = gid;
  nm := public.display_name_of(uid);
  perform public.post_system_message(cid, 'joined', jsonb_build_object('name', nm), nm || ' liittyi mukaan 🎉');
  if g.founder_id is not null and g.founder_id <> uid and g.founder_id <> auth.uid() then
    perform public.notify(g.founder_id, '👥', 'group_member_joined', jsonb_build_object('name', nm, 'group', g.name),
      nm || ' liittyi ryhmääsi “' || g.name || '”', 'group', gid);
  end if;
end $$;

-- Liity: avoimeen kuka tahansa; suljettuun vain kutsulla (kutsu hyväksytään samalla)
create or replace function public.join_group(p_id uuid) returns text
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); g public.groups;
begin
  if me is null then raise exception 'not_authenticated' using errcode = 'P0001'; end if;
  if public.is_banned() then raise exception 'account_banned' using errcode = 'P0001'; end if;
  select * into g from public.groups where id = p_id;
  if not found then raise exception 'group_not_found' using errcode = 'P0001'; end if;
  if public.is_group_member(p_id) then return 'member'; end if;
  if g.visibility = 'closed' and not exists (select 1 from public.group_invites where group_id = p_id and invitee_id = me) then
    raise exception 'group_closed' using errcode = 'P0001';
  end if;
  if (select count(*) from public.group_members where user_id = me) >= 200 then
    raise exception 'group_rate_limited' using errcode = 'P0001';
  end if;
  perform public.group_add_member(p_id, me);
  return 'member';
end $$;

create or replace function public.leave_group(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); cid uuid; nm text;
begin
  if me is null then raise exception 'not_authenticated' using errcode = 'P0001'; end if;
  if public.group_role(p_id) = 'founder' then raise exception 'founder_cannot_leave' using errcode = 'P0001'; end if;
  delete from public.group_members where group_id = p_id and user_id = me;
  if found then
    select id into cid from public.conversations where group_id = p_id;
    nm := public.display_name_of(me);
    perform public.post_system_message(cid, 'group_left', jsonb_build_object('name', nm), nm || ' poistui ryhmästä');
  end if;
end $$;

-- Kutsu: perustaja tai moderaattori. Kutsuttu saa ilmoituksen ja voi liittyä (myös suljettuun).
create or replace function public.invite_to_group(p_id uuid, p_user uuid) returns void
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); g public.groups; nm text; n int;
begin
  if me is null then raise exception 'not_authenticated' using errcode = 'P0001'; end if;
  if public.is_banned() then raise exception 'account_banned' using errcode = 'P0001'; end if;
  select * into g from public.groups where id = p_id;
  if not found then raise exception 'group_not_found' using errcode = 'P0001'; end if;
  if not public.is_group_mod(p_id) then raise exception 'group_mod_only' using errcode = 'P0001'; end if;
  if p_user is null or p_user = me or not exists (select 1 from public.profiles where id = p_user) then
    raise exception 'group_invite_invalid' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.group_members where group_id = p_id and user_id = p_user) then return; end if;
  if (select count(*) from public.group_invites where inviter_id = me and created_at > now() - interval '1 day') >= 100 then
    raise exception 'group_rate_limited' using errcode = 'P0001';
  end if;
  insert into public.group_invites (group_id, invitee_id, inviter_id) values (p_id, p_user, me) on conflict do nothing;
  get diagnostics n = row_count;
  if n > 0 then
    nm := public.display_name_of(me);
    perform public.notify(p_user, '💌', 'group_invite', jsonb_build_object('name', nm, 'group', g.name),
      nm || ' kutsui sinut ryhmään “' || g.name || '”', 'group', p_id);
  end if;
end $$;

create or replace function public.respond_group_invite(p_id uuid, p_accept boolean) returns void
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); i public.group_invites; g public.groups; nm text;
begin
  if me is null then raise exception 'not_authenticated' using errcode = 'P0001'; end if;
  select * into i from public.group_invites where group_id = p_id and invitee_id = me for update;
  if not found then raise exception 'group_invite_not_found' using errcode = 'P0001'; end if;
  if p_accept then
    if public.is_banned() then raise exception 'account_banned' using errcode = 'P0001'; end if;
    perform public.group_add_member(p_id, me);
    select * into g from public.groups where id = p_id;
    nm := public.display_name_of(me);
    if i.inviter_id is not null and i.inviter_id is distinct from g.founder_id then
      perform public.notify(i.inviter_id, '🤝', 'group_invite_accepted', jsonb_build_object('name', nm, 'group', g.name),
        nm || ' hyväksyi kutsusi ryhmään “' || g.name || '”', 'group', p_id);
    end if;
  else
    delete from public.group_invites where group_id = p_id and invitee_id = me;
  end if;
end $$;

-- Liittymispyyntö suljettuun ryhmään (linkin kautta). Hylätyn pyynnön voi uusia 7 päivän päästä.
create or replace function public.request_join_group(p_id uuid, p_message text default '') returns text
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); g public.groups; r public.group_join_requests; nm text; m record;
  v_msg text := left(btrim(coalesce(p_message, '')), 200);
begin
  if me is null then raise exception 'not_authenticated' using errcode = 'P0001'; end if;
  if public.is_banned() then raise exception 'account_banned' using errcode = 'P0001'; end if;
  select * into g from public.groups where id = p_id;
  if not found then raise exception 'group_not_found' using errcode = 'P0001'; end if;
  if public.is_group_member(p_id) then return 'member'; end if;
  if g.visibility = 'open' or exists (select 1 from public.group_invites where group_id = p_id and invitee_id = me) then
    perform public.join_group(p_id); return 'member';
  end if;
  if not public.is_admin() and public.looks_commercial(v_msg) then raise exception 'commercial_content' using errcode = 'P0001'; end if;
  select * into r from public.group_join_requests where group_id = p_id and user_id = me for update;
  if found then
    if r.status = 'pending' then return 'pending'; end if;
    if r.status = 'declined' and r.decided_at > now() - interval '7 days' then
      raise exception 'group_request_declined' using errcode = 'P0001';
    end if;
  end if;
  if (select count(*) from public.group_join_requests where user_id = me and created_at > now() - interval '1 day') >= 30 then
    raise exception 'group_rate_limited' using errcode = 'P0001';
  end if;
  insert into public.group_join_requests (group_id, user_id, message, status, created_at)
    values (p_id, me, v_msg, 'pending', now())
    on conflict (group_id, user_id) do update set message = excluded.message, status = 'pending', created_at = now(),
      decided_by = null, decided_at = null;
  nm := public.display_name_of(me);
  for m in select user_id from public.group_members where group_id = p_id and role in ('founder','moderator') loop
    perform public.notify(m.user_id, '🙋', 'group_join_request', jsonb_build_object('name', nm, 'group', g.name),
      nm || ' pyytää liittyä ryhmään “' || g.name || '”', 'group', p_id);
  end loop;
  return 'pending';
end $$;

create or replace function public.review_join_request(p_id uuid, p_user uuid, p_approve boolean) returns void
language plpgsql security definer set search_path = public as $$
declare g public.groups; r public.group_join_requests;
begin
  if auth.uid() is null then raise exception 'not_authenticated' using errcode = 'P0001'; end if;
  if not public.is_group_mod(p_id) then raise exception 'group_mod_only' using errcode = 'P0001'; end if;
  select * into r from public.group_join_requests where group_id = p_id and user_id = p_user and status = 'pending' for update;
  if not found then raise exception 'group_request_not_found' using errcode = 'P0001'; end if;
  select * into g from public.groups where id = p_id;
  update public.group_join_requests set status = case when p_approve then 'approved' else 'declined' end,
    decided_by = auth.uid(), decided_at = now() where group_id = p_id and user_id = p_user;
  if p_approve then
    perform public.group_add_member(p_id, p_user);
    perform public.notify(p_user, '✅', 'group_request_approved', jsonb_build_object('group', g.name),
      'Liittymispyyntösi ryhmään “' || g.name || '” hyväksyttiin 🎉', 'group', p_id);
  end if;
end $$;

-- Perustaja poistaa jäsenen (myös moderaattorin); ylläpito voi myös
create or replace function public.remove_group_member(p_id uuid, p_user uuid) returns void
language plpgsql security definer set search_path = public as $$
declare g public.groups; cid uuid; nm text;
begin
  if auth.uid() is null then raise exception 'not_authenticated' using errcode = 'P0001'; end if;
  if coalesce(public.group_role(p_id), '') <> 'founder' and not public.is_admin() then raise exception 'group_founder_only' using errcode = 'P0001'; end if;
  if p_user = auth.uid() then raise exception 'group_remove_self' using errcode = 'P0001'; end if;
  select * into g from public.groups where id = p_id;
  if exists (select 1 from public.group_members where group_id = p_id and user_id = p_user and role = 'founder') then
    raise exception 'group_remove_founder' using errcode = 'P0001';
  end if;
  delete from public.group_members where group_id = p_id and user_id = p_user;
  if found then
    delete from public.group_invites where group_id = p_id and invitee_id = p_user;
    select id into cid from public.conversations where group_id = p_id;
    nm := public.display_name_of(p_user);
    perform public.post_system_message(cid, 'group_member_removed', jsonb_build_object('name', nm), nm || ' poistettiin ryhmästä');
    perform public.notify(p_user, 'ℹ️', 'group_removed', jsonb_build_object('group', g.name),
      'Sinut poistettiin ryhmästä “' || g.name || '”', null, null);
  end if;
end $$;

-- Perustaja nimittää / poistaa moderaattorin
create or replace function public.set_group_role(p_id uuid, p_user uuid, p_role text) returns void
language plpgsql security definer set search_path = public as $$
declare g public.groups; cur text;
begin
  if auth.uid() is null then raise exception 'not_authenticated' using errcode = 'P0001'; end if;
  if coalesce(public.group_role(p_id), '') <> 'founder' then raise exception 'group_founder_only' using errcode = 'P0001'; end if;
  if p_role not in ('moderator','member') then raise exception 'group_invalid' using errcode = 'P0001'; end if;
  select role into cur from public.group_members where group_id = p_id and user_id = p_user for update;
  if not found or cur = 'founder' then raise exception 'group_member_not_found' using errcode = 'P0001'; end if;
  if cur = p_role then return; end if;
  update public.group_members set role = p_role where group_id = p_id and user_id = p_user;
  select * into g from public.groups where id = p_id;
  if p_role = 'moderator' then
    perform public.notify(p_user, '⭐', 'group_moderator', jsonb_build_object('group', g.name),
      'Sinut nimitettiin ryhmän “' || g.name || '” moderaattoriksi', 'group', p_id);
  end if;
end $$;

-- Esikatselu linkin kautta (myös suljettu ryhmä): nimi, kuvaus, jäsenmäärä – ei jäsenlistaa eikä viestejä
create or replace function public.group_preview(p_id uuid)
returns table (id uuid, name text, description text, visibility text, activity_id text, city text,
               member_count int, my_role text, invited boolean, request_status text)
language sql stable security definer set search_path = public as $$
  select g.id, g.name, g.description, g.visibility, g.activity_id, g.city, public.group_member_count(g.id),
         public.group_role(g.id),
         exists (select 1 from public.group_invites i where i.group_id = g.id and i.invitee_id = auth.uid()),
         (select r.status from public.group_join_requests r where r.group_id = g.id and r.user_id = auth.uid())
  from public.groups g where g.id = p_id and auth.uid() is not null
$$;

-- Perustaja poistuu (tilin poisto) -> vanhin moderaattori / jäsen perustajaksi; tyhjä ryhmä poistetaan
create or replace function public.group_members_after_delete() returns trigger
language plpgsql security definer set search_path = public as $$
declare nxt uuid;
begin
  if old.role <> 'founder' or not exists (select 1 from public.groups where id = old.group_id) then return null; end if;
  select user_id into nxt from public.group_members where group_id = old.group_id
    order by (role = 'moderator') desc, joined_at asc limit 1;
  if nxt is null then
    delete from public.groups where id = old.group_id;
  else
    update public.group_members set role = 'founder' where group_id = old.group_id and user_id = nxt;
    update public.groups set founder_id = nxt, updated_at = now() where id = old.group_id;
  end if;
  return null;
end $$;
drop trigger if exists group_members_after_delete on public.group_members;
create trigger group_members_after_delete after delete on public.group_members
  for each row execute function public.group_members_after_delete();

-- Listanäkymä: jäsenmäärä ja oma rooli (RLS: security_invoker)
create or replace view public.groups_v with (security_invoker = true) as
  select g.*, public.group_member_count(g.id) as member_count, public.group_role(g.id) as my_role
  from public.groups g;

alter table public.groups              enable row level security;
alter table public.group_members       enable row level security;
alter table public.group_invites       enable row level security;
alter table public.group_join_requests enable row level security;
drop policy if exists "groups: näkyvät" on public.groups;
create policy "groups: näkyvät" on public.groups for select to authenticated using (public.group_visible(id));
drop policy if exists "group_members: jäsenet ja ylläpito lukevat" on public.group_members;
create policy "group_members: jäsenet ja ylläpito lukevat" on public.group_members for select to authenticated
  using (user_id = auth.uid() or public.is_group_member(group_id) or public.is_admin());
drop policy if exists "group_invites: osapuolet ja moderaattorit lukevat" on public.group_invites;
create policy "group_invites: osapuolet ja moderaattorit lukevat" on public.group_invites for select to authenticated
  using (invitee_id = auth.uid() or inviter_id = auth.uid() or public.is_group_mod(group_id));
drop policy if exists "group_join_requests: pyytäjä ja moderaattorit lukevat" on public.group_join_requests;
create policy "group_join_requests: pyytäjä ja moderaattorit lukevat" on public.group_join_requests for select to authenticated
  using (user_id = auth.uid() or public.is_group_mod(group_id) or public.is_admin());

-- 8d. ILMOITUKSET (reports): myös viestit/kuvat, kansikuvat ja ryhmät ----------------------
alter table public.reports drop constraint if exists reports_target_type_check;
alter table public.reports add constraint reports_target_type_check check (target_type in ('event','message','event_cover','group'));

-- Ylläpito näkee ilmoitetun viestin (myös kuvan polun), vaikka ei ole keskustelun jäsen
drop policy if exists "messages: ylläpito näkee ilmoitetut" on public.messages;
create policy "messages: ylläpito näkee ilmoitetut" on public.messages for select to authenticated
  using (public.is_admin() and exists (select 1 from public.reports r where r.target_type = 'message' and r.target_id = messages.id));

-- Ylläpito: poista ilmoitettu sisältö. Palauttaa poistettavan kuvan polun (client poistaa tiedoston Storage-API:lla).
create or replace function public.admin_remove_content(p_type text, p_id uuid) returns text
language plpgsql security definer set search_path = public as $$
declare pth text;
begin
  if auth.uid() is null or not public.is_admin() then raise exception 'admin_only' using errcode = 'P0001'; end if;
  if p_type = 'message' then
    delete from public.messages where id = p_id returning image_path into pth;
  elsif p_type = 'event_cover' then
    select cover_path into pth from public.events where id = p_id;
    update public.events set cover_path = null where id = p_id;
  elsif p_type = 'group' then
    delete from public.groups where id = p_id;
  else
    raise exception 'report_target_invalid' using errcode = 'P0001';
  end if;
  update public.reports set status = 'resolved', resolved_by = auth.uid(), resolved_at = now()
    where target_type = p_type and target_id = p_id and status = 'open';
  return pth;
end $$;

-- 8e. OIKEUDET -------------------------------------------------------------------------------
revoke all on public.groups, public.group_members, public.group_invites, public.group_join_requests, public.groups_v from anon;
revoke insert, update, delete, truncate, references, trigger on public.groups, public.group_members, public.group_invites, public.group_join_requests, public.groups_v from authenticated;
grant select on public.groups, public.group_members, public.group_invites, public.group_join_requests, public.groups_v to authenticated;

grant select (name_i18n, status) on public.activities to anon;
grant select (cover_path) on public.events to anon;   -- guest_events.cover_path (osio 5b)

do $$
declare f text;
begin
  foreach f in array array[
    'public.admin_review_activity(text, text, jsonb)', 'public.can_edit_event(uuid)', 'public.can_post_image(uuid)',
    'public.image_reported(text)', 'public.storage_object_exists(text, text)',
    'public.group_role(uuid)', 'public.is_group_member(uuid)', 'public.is_group_mod(uuid)', 'public.group_member_count(uuid)',
    'public.group_visible(uuid)', 'public.group_input_ok(text, text)', 'public.create_group(jsonb)', 'public.update_group(uuid, jsonb)',
    'public.delete_group(uuid)', 'public.group_add_member(uuid, uuid)', 'public.join_group(uuid)', 'public.leave_group(uuid)',
    'public.invite_to_group(uuid, uuid)', 'public.respond_group_invite(uuid, boolean)', 'public.request_join_group(uuid, text)',
    'public.review_join_request(uuid, uuid, boolean)', 'public.remove_group_member(uuid, uuid)', 'public.set_group_role(uuid, uuid, text)',
    'public.group_preview(uuid)', 'public.admin_remove_content(text, uuid)'] loop
    execute format('revoke execute on function %s from public, anon', f);
  end loop;
  foreach f in array array[
    'public.admin_review_activity(text, text, jsonb)', 'public.can_edit_event(uuid)', 'public.can_post_image(uuid)',
    'public.image_reported(text)', 'public.storage_object_exists(text, text)', 'public.group_role(uuid)', 'public.is_group_member(uuid)', 'public.is_group_mod(uuid)',
    'public.group_member_count(uuid)', 'public.group_visible(uuid)', 'public.create_group(jsonb)', 'public.update_group(uuid, jsonb)',
    'public.delete_group(uuid)', 'public.join_group(uuid)', 'public.leave_group(uuid)', 'public.invite_to_group(uuid, uuid)',
    'public.respond_group_invite(uuid, boolean)', 'public.request_join_group(uuid, text)', 'public.review_join_request(uuid, uuid, boolean)',
    'public.remove_group_member(uuid, uuid)', 'public.set_group_role(uuid, uuid, text)', 'public.group_preview(uuid)',
    'public.admin_remove_content(text, uuid)'] loop
    execute format('grant execute on function %s to authenticated', f);
  end loop;
  -- sisäiset: ei API-kutsuttavia
  revoke execute on function public.group_add_member(uuid, uuid) from authenticated;
  revoke execute on function public.group_input_ok(text, text) from authenticated;
  revoke execute on function public.activities_after_insert() from public, anon, authenticated;
  revoke execute on function public.group_members_after_delete() from public, anon, authenticated;
end $$;


-- ---------------------------------------------------------------------
-- 9. JOUKKUEIDEN JA YRITYSTEN HALLINTA (2026-10-02)
--    9a joukkueet: ylläpidon hyväksymä joukkuetilipyyntö luo joukkueen (pyytäjä = joukkueenjohtaja);
--       harjoitukset/pelit/palaverit + toistuvuus, paikat, ohjeet/ohjelma/muistiinpanot, joukkueen chat
--       (conversations.kind 'team': kuvat, ilmoitukset, realtime), ilmoittautumiset, jäsenet ja roolit
--       (joukkueenjohtaja, valmentaja, jäsen, huoltaja ↔ jäsen), kapteeni per tapahtuma, tittelit.
--    9b yritykset: järjestäjät (omistaja hallitsee kutsulinkillä), toistuvat yritystapahtumat, hinta ja
--       lisätiedot; päättynyt tilaus = vain luku.
--    Kirjoitukset jäseniin, kutsuihin, ilmoittautumisiin ja sarjoihin vain RPC:iden kautta. anon: ei mitään.
-- ---------------------------------------------------------------------

-- Toistuvuus: päivät väliltä [p_from, p_to], joiden ISO-viikonpäivä (1 = ma … 7 = su) on listalla
create or replace function public.series_dates(p_days int[], p_from date, p_to date) returns setof date
language sql immutable as $$
  select d::date from generate_series(p_from::timestamp, p_to::timestamp, interval '1 day') d
  where extract(isodow from d)::int = any(p_days)
$$;
create or replace function public.valid_weekdays(p int[]) returns boolean
language sql immutable as $$
  select p is not null and cardinality(p) between 1 and 7 and p <@ array[1,2,3,4,5,6,7]
$$;

-- 9a. JOUKKUEET ------------------------------------------------------------

-- teams: hyväksytystä pyynnöstä, kaupunki ja laji (lajilistasta oletustitteleitä varten)
alter table public.teams add column if not exists team_request_id uuid;
alter table public.teams add column if not exists city text not null default '';
alter table public.teams add column if not exists activity_id text;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'teams_team_request_id_fkey') then
    alter table public.teams add constraint teams_team_request_id_fkey
      foreign key (team_request_id) references public.team_requests(id) on delete set null;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'teams_activity_id_fkey') then
    alter table public.teams add constraint teams_activity_id_fkey
      foreign key (activity_id) references public.activities(id) on update cascade on delete set null;
  end if;
end $$;
create unique index if not exists teams_team_request_key on public.teams (team_request_id) where team_request_id is not null;
alter table public.teams drop constraint if exists teams_name_check;
alter table public.teams add constraint teams_name_check check (char_length(name) between 2 and 80);
alter table public.teams drop constraint if exists teams_sport_check;
alter table public.teams add constraint teams_sport_check check (char_length(sport) <= 60);
alter table public.teams drop constraint if exists teams_description_check;
alter table public.teams add constraint teams_description_check check (char_length(description) <= 800);
alter table public.teams drop constraint if exists teams_city_check;
alter table public.teams add constraint teams_city_check check (char_length(city) <= 60);

-- team_members: roolit manager (joukkueenjohtaja) / coach / member / parent (huoltaja, linkitetty jäseneen),
-- titteli (esim. maalivahti), jäsen ilman omaa tiliä (esim. junioripelaaja, nimi näkyy vain joukkueelle)
alter table public.team_members drop constraint if exists team_members_role_check;
update public.team_members set role = 'manager' where role = 'admin';
update public.team_members set role = 'member' where role = 'player';
alter table public.team_members add constraint team_members_role_check check (role in ('manager','coach','member','parent'));
alter table public.team_members add column if not exists title text not null default '';
alter table public.team_members add column if not exists display_name text not null default '';
alter table public.team_members add column if not exists linked_member uuid;
alter table public.team_members alter column user_id drop not null;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'team_members_linked_member_fkey') then
    alter table public.team_members add constraint team_members_linked_member_fkey
      foreign key (linked_member) references public.team_members(id) on delete set null;
  end if;
end $$;
alter table public.team_members drop constraint if exists team_members_title_check;
alter table public.team_members add constraint team_members_title_check check (char_length(title) <= 40);
alter table public.team_members drop constraint if exists team_members_identity_check;
alter table public.team_members add constraint team_members_identity_check check (
  (user_id is not null and display_name = '') or (user_id is null and char_length(display_name) between 2 and 40 and role = 'member'));
alter table public.team_members drop constraint if exists team_members_parent_check;
alter table public.team_members add constraint team_members_parent_check check (linked_member is null or role = 'parent');
create index if not exists team_members_linked_idx on public.team_members (linked_member);

-- team_roles = joukkueen omat tittelit (lajin oletustittelit tulevat sovelluksesta); team_places = tallennetut paikat
alter table public.team_places add column if not exists created_at timestamptz not null default now();

-- Toistuvat harjoitukset / pelit / palaverit
create table if not exists public.team_event_series (
  id            uuid primary key default gen_random_uuid(),
  team_id       uuid not null references public.teams(id) on delete cascade,
  kind          text not null default 'training' check (kind in ('training','game','meeting')),
  title         text not null check (char_length(title) between 2 and 60),
  description   text not null default '' check (char_length(description) <= 400),
  weekdays      int[] not null check (public.valid_weekdays(weekdays)),
  start_time    time not null,
  duration_min  int not null default 90 check (duration_min between 5 and 1440),
  starts_on     date not null,
  ends_on       date not null,
  place_id      uuid references public.team_places(id) on delete set null,
  place_name    text not null default '' check (char_length(place_name) <= 60),
  place_address text not null default '' check (char_length(place_address) <= 120),
  created_by    uuid default auth.uid() references public.profiles(id) on delete set null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  constraint team_event_series_range check (ends_on >= starts_on and ends_on <= starts_on + 400)
);
create index if not exists team_event_series_team_idx on public.team_event_series (team_id);

-- team_events: live-kannassa event_time oli tekstiä (''), muutetaan time-tyypiksi
do $$ begin
  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'team_events'
             and column_name = 'event_time' and data_type <> 'time without time zone') then
    alter table public.team_events alter column event_time drop default;
    alter table public.team_events alter column event_time drop not null;
    alter table public.team_events alter column event_time type time using
      (case when btrim(event_time::text) ~ '^[0-9]{1,2}:[0-9]{2}(:[0-9]{2})?$' then btrim(event_time::text)::time end);
  end if;
end $$;
alter table public.team_events alter column place_name set default '';
alter table public.team_events alter column place_address set default '';
alter table public.team_events add column if not exists kind text not null default 'training';
alter table public.team_events add column if not exists duration_min int not null default 90;
alter table public.team_events add column if not exists series_id uuid;
alter table public.team_events add column if not exists cancelled boolean not null default false;
alter table public.team_events add column if not exists modified boolean not null default false;
alter table public.team_events add column if not exists captain_member uuid;
alter table public.team_events add column if not exists opponent text not null default '';
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'team_events_series_id_fkey') then
    alter table public.team_events add constraint team_events_series_id_fkey
      foreign key (series_id) references public.team_event_series(id) on delete set null;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'team_events_captain_member_fkey') then
    alter table public.team_events add constraint team_events_captain_member_fkey
      foreign key (captain_member) references public.team_members(id) on delete set null;
  end if;
end $$;
alter table public.team_events drop constraint if exists team_events_kind_check;
alter table public.team_events add constraint team_events_kind_check check (kind in ('training','game','meeting'));
alter table public.team_events drop constraint if exists team_events_duration_check;
alter table public.team_events add constraint team_events_duration_check check (duration_min between 5 and 1440);
alter table public.team_events drop constraint if exists team_events_description_check;
alter table public.team_events add constraint team_events_description_check check (char_length(description) <= 400);
alter table public.team_events drop constraint if exists team_events_opponent_check;
alter table public.team_events add constraint team_events_opponent_check check (char_length(opponent) <= 60);
alter table public.team_events drop constraint if exists team_events_place_name_check;
alter table public.team_events add constraint team_events_place_name_check check (place_name is null or char_length(place_name) <= 60);
alter table public.team_events drop constraint if exists team_events_place_address_check;
alter table public.team_events add constraint team_events_place_address_check check (place_address is null or char_length(place_address) <= 120);
alter table public.team_events drop constraint if exists team_events_max_participants_check;
alter table public.team_events add constraint team_events_max_participants_check check (max_participants is null or max_participants >= 1);
create index if not exists team_events_series_idx on public.team_events (series_id, event_date);

-- Ilmoittautumiset jäsenriveittäin (huoltaja vastaa linkitetyn jäsenen puolesta; jäsen ilman tiliä mahdollinen)
alter table public.team_event_rsvps add column if not exists member_id uuid;
alter table public.team_event_rsvps add column if not exists responded_by uuid;
alter table public.team_event_rsvps add column if not exists updated_at timestamptz not null default now();
alter table public.team_event_rsvps alter column user_id drop not null;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'team_event_rsvps_member_id_fkey') then
    alter table public.team_event_rsvps add constraint team_event_rsvps_member_id_fkey
      foreign key (member_id) references public.team_members(id) on delete cascade;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'team_event_rsvps_responded_by_fkey') then
    alter table public.team_event_rsvps add constraint team_event_rsvps_responded_by_fkey
      foreign key (responded_by) references public.profiles(id) on delete set null;
  end if;
end $$;
update public.team_event_rsvps r set member_id = m.id from public.team_events e, public.team_members m
  where r.member_id is null and e.id = r.event_id and m.team_id = e.team_id and m.user_id = r.user_id;
delete from public.team_event_rsvps where member_id is null;
alter table public.team_event_rsvps alter column member_id set not null;
alter table public.team_event_rsvps drop constraint if exists team_event_rsvps_status_check;
alter table public.team_event_rsvps add constraint team_event_rsvps_status_check check (status in ('going','maybe','no'));
alter table public.team_event_rsvps drop constraint if exists team_event_rsvps_event_id_user_id_key;
create unique index if not exists team_event_rsvps_event_member_key on public.team_event_rsvps (event_id, member_id);

-- Ohjeet, ohjelma ja muistiinpanot (muistiinpanot voi rajata vain valmentajille/johdolle)
create table if not exists public.team_docs (
  id          uuid primary key default gen_random_uuid(),
  team_id     uuid not null references public.teams(id) on delete cascade,
  kind        text not null default 'instructions' check (kind in ('instructions','programme','notes')),
  title       text not null check (char_length(title) between 1 and 80),
  body        text not null default '' check (char_length(body) <= 8000),
  staff_only  boolean not null default false,
  sort_order  int not null default 0,
  updated_by  uuid default auth.uid() references public.profiles(id) on delete set null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index if not exists team_docs_team_idx on public.team_docs (team_id, kind, sort_order);

-- Kutsut: kaverikutsu (ilmoitus) ja kutsulinkki (token; huoltajalinkki voi kohdistua tiettyyn jäseneen)
create table if not exists public.team_invites (
  team_id    uuid not null references public.teams(id) on delete cascade,
  invitee_id uuid not null references public.profiles(id) on delete cascade,
  inviter_id uuid references public.profiles(id) on delete set null,
  role       text not null default 'member' check (role in ('member','parent','coach')),
  created_at timestamptz not null default now(),
  primary key (team_id, invitee_id)
);
create index if not exists team_invites_invitee_idx on public.team_invites (invitee_id);
create table if not exists public.team_invite_links (
  token       uuid primary key default gen_random_uuid(),
  team_id     uuid not null references public.teams(id) on delete cascade,
  role        text not null default 'member' check (role in ('member','parent','coach')),
  for_member  uuid references public.team_members(id) on delete cascade,
  created_by  uuid references public.profiles(id) on delete set null,
  created_at  timestamptz not null default now(),
  expires_at  timestamptz not null default now() + interval '14 days',
  max_uses    int not null default 30 check (max_uses between 1 and 200),
  uses        int not null default 0,
  revoked     boolean not null default false,
  constraint team_invite_links_parent check (for_member is null or role = 'parent')
);
create index if not exists team_invite_links_team_idx on public.team_invite_links (team_id, created_at desc);

-- Joukkueen chat = conversations.kind 'team'
alter table public.conversations add column if not exists team_id uuid;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'conversations_team_id_fkey') then
    alter table public.conversations add constraint conversations_team_id_fkey
      foreign key (team_id) references public.teams(id) on delete cascade;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'conversations_team_id_key') then
    alter table public.conversations add constraint conversations_team_id_key unique (team_id);
  end if;
end $$;
alter table public.conversations drop constraint if exists conversations_kind_check;
alter table public.conversations add constraint conversations_kind_check check (kind in ('event','help','group','team'));
alter table public.conversations drop constraint if exists conversations_target;
alter table public.conversations add constraint conversations_target check (
  (kind = 'event' and event_id is not null and help_request_id is null and group_id is null and team_id is null) or
  (kind = 'help'  and help_request_id is not null and event_id is null and group_id is null and team_id is null) or
  (kind = 'group' and group_id is not null and event_id is null and help_request_id is null and team_id is null) or
  (kind = 'team'  and team_id is not null and event_id is null and help_request_id is null and group_id is null));

-- Apufunktiot: rooli ja jäsenyys (team_role, is_team_*) ovat osiossa 7b
create or replace function public.team_member_count(tid uuid) returns int
language sql stable security definer set search_path = public as $$
  select count(*)::int from public.team_members where team_id = tid
$$;
create or replace function public.team_staff_ids(tid uuid) returns setof uuid
language sql stable security definer set search_path = public as $$
  select user_id from public.team_members where team_id = tid and role in ('manager','coach') and user_id is not null
  union select owner_id from public.teams where id = tid
$$;
create or replace function public.team_conv(tid uuid) returns uuid
language sql stable security definer set search_path = public as $$
  select id from public.conversations where team_id = tid
$$;

-- Joukkueen luonti vain ylläpidon hyväksynnästä (ei suoraa insertiä). Uudelleenajettava: sama pyyntö = sama joukkue.
create or replace function public.create_team_from_request(r public.team_requests) returns uuid
language plpgsql security definer set search_path = public as $$
declare tid uuid; cid uuid; act text;
begin
  select id into tid from public.teams where team_request_id = r.id;
  if tid is not null then return tid; end if;
  select a.id into act from public.activities a
    where a.status = 'approved' and (lower(a.name) = lower(r.sport) or exists (
      select 1 from jsonb_each_text(a.name_i18n) n where lower(n.value) = lower(r.sport))) limit 1;
  insert into public.teams (name, sport, description, city, owner_id, team_request_id, activity_id)
  values (left(r.team_name, 80), left(r.sport, 60), left(r.description, 800), left(r.city, 60), r.requester_id, r.id, act)
  returning id into tid;
  insert into public.team_members (team_id, user_id, role) values (tid, r.requester_id, 'manager')
    on conflict (team_id, user_id) do update set role = 'manager';
  insert into public.conversations (kind, team_id) values ('team', tid) returning id into cid;
  perform public.post_system_message(cid, 'team_created', jsonb_build_object('name', r.team_name),
    'Joukkue “' || r.team_name || '” on valmis – tervetuloa! 👋');
  return tid;
end $$;

-- admin_review_team_request (7e) kutsuu create_team_from_request-funktiota hyväksynnässä

create or replace function public.update_team(p_id uuid, p jsonb) returns void
language plpgsql security definer set search_path = public as $$
declare t public.teams; v_act text;
begin
  if auth.uid() is null then raise exception 'not_authenticated' using errcode = 'P0001'; end if;
  if public.is_banned() then raise exception 'account_banned' using errcode = 'P0001'; end if;
  select * into t from public.teams where id = p_id for update;
  if not found then raise exception 'team_not_found' using errcode = 'P0001'; end if;
  if not public.is_team_admin(p_id) then raise exception 'team_manager_only' using errcode = 'P0001'; end if;
  v_act := case when p ? 'activity_id' then nullif(p->>'activity_id', '') else t.activity_id end;
  if v_act is not null and not exists (select 1 from public.activities where id = v_act) then v_act := null; end if;
  update public.teams set
    name = coalesce(nullif(btrim(regexp_replace(coalesce(p->>'name', ''), '\s+', ' ', 'g')), ''), t.name),
    description = case when p ? 'description' then left(btrim(coalesce(p->>'description', '')), 800) else t.description end,
    sport = case when p ? 'sport' then left(btrim(coalesce(p->>'sport', '')), 60) else t.sport end,
    city = case when p ? 'city' then left(btrim(coalesce(p->>'city', '')), 60) else t.city end,
    activity_id = v_act
  where id = p_id;
end $$;

-- Jäsenen lisäys (sisäinen): kutsulinkki / kaverikutsu. Huoltajalinkki liittää huoltajan valittuun jäseneen.
create or replace function public.team_add_member(tid uuid, uid uuid, p_role text, p_for uuid) returns uuid
language plpgsql security definer set search_path = public as $$
declare mid uuid; nm text; t public.teams; r record;
begin
  select id into mid from public.team_members where team_id = tid and user_id = uid;
  if mid is not null then
    if p_for is not null then
      update public.team_members set linked_member = p_for, role = 'parent' where id = mid and role in ('member','parent');
    end if;
    return mid;
  end if;
  insert into public.team_members (team_id, user_id, role, linked_member)
    values (tid, uid, coalesce(p_role, 'member'), case when p_role = 'parent' then p_for end) returning id into mid;
  delete from public.team_invites where team_id = tid and invitee_id = uid;
  select * into t from public.teams where id = tid;
  nm := public.display_name_of(uid);
  perform public.post_system_message(public.team_conv(tid), 'joined', jsonb_build_object('name', nm), nm || ' liittyi mukaan 🎉');
  for r in select s from public.team_staff_ids(tid) s loop
    if r.s <> uid then
      perform public.notify(r.s, '👥', 'team_member_joined', jsonb_build_object('name', nm, 'team', t.name),
        nm || ' liittyi joukkueeseen “' || t.name || '”', 'team', tid);
    end if;
  end loop;
  return mid;
end $$;

-- Kutsulinkit (henkilökunta luo; valmentajalinkin vain joukkueenjohtaja). Huoltajalinkki voi kohdistua jäseneen.
create or replace function public.create_team_invite_link(p_team uuid, p_role text default 'member', p_for uuid default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare tok uuid;
begin
  if auth.uid() is null then raise exception 'not_authenticated' using errcode = 'P0001'; end if;
  if public.is_banned() then raise exception 'account_banned' using errcode = 'P0001'; end if;
  if not public.is_team_coach(p_team) then raise exception 'team_staff_only' using errcode = 'P0001'; end if;
  if coalesce(p_role, '') not in ('member','parent','coach') then raise exception 'team_role_invalid' using errcode = 'P0001'; end if;
  if p_role = 'coach' and not public.is_team_admin(p_team) then raise exception 'team_manager_only' using errcode = 'P0001'; end if;
  if p_for is not null and (p_role <> 'parent' or not exists (
       select 1 from public.team_members where id = p_for and team_id = p_team and role = 'member')) then
    raise exception 'team_member_not_found' using errcode = 'P0001';
  end if;
  if (select count(*) from public.team_invite_links where team_id = p_team and created_at > now() - interval '1 day') >= 30 then
    raise exception 'too_many_invite_links' using errcode = 'P0001';
  end if;
  insert into public.team_invite_links (team_id, role, for_member, created_by) values (p_team, p_role, p_for, auth.uid())
    returning token into tok;
  return tok;
end $$;

create or replace function public.revoke_team_invite_link(p_token uuid) returns void
language plpgsql security definer set search_path = public as $$
declare tid uuid;
begin
  select team_id into tid from public.team_invite_links where token = p_token;
  if tid is null or not public.is_team_coach(tid) then raise exception 'team_staff_only' using errcode = 'P0001'; end if;
  update public.team_invite_links set revoked = true where token = p_token;
end $$;

-- Linkin esikatselu kirjautuneelle (joukkueen nimi, laji, rooli, kohdejäsen) – ei jäsenlistaa
create or replace function public.team_link_preview(p_token uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare l public.team_invite_links; t public.teams;
begin
  if auth.uid() is null then raise exception 'not_authenticated' using errcode = 'P0001'; end if;
  select * into l from public.team_invite_links where token = p_token;
  if not found or l.revoked or l.expires_at < now() or l.uses >= l.max_uses then
    raise exception 'invite_link_invalid' using errcode = 'P0001';
  end if;
  select * into t from public.teams where id = l.team_id;
  return jsonb_build_object('team_id', t.id, 'name', t.name, 'sport', t.sport, 'city', t.city, 'activity_id', t.activity_id,
    'role', l.role, 'member_name', (select coalesce(nullif(m.display_name, ''), public.display_name_of(m.user_id))
                                      from public.team_members m where m.id = l.for_member),
    'already_member', public.is_team_member(t.id), 'members', public.team_member_count(t.id));
end $$;

create or replace function public.join_team_by_link(p_token uuid) returns uuid
language plpgsql security definer set search_path = public as $$
declare l public.team_invite_links; was boolean;
begin
  if auth.uid() is null then raise exception 'not_authenticated' using errcode = 'P0001'; end if;
  if public.is_banned() then raise exception 'account_banned' using errcode = 'P0001'; end if;
  select * into l from public.team_invite_links where token = p_token for update;
  if not found or l.revoked or l.expires_at < now() or l.uses >= l.max_uses then
    raise exception 'invite_link_invalid' using errcode = 'P0001';
  end if;
  was := exists (select 1 from public.team_members where team_id = l.team_id and user_id = auth.uid());
  perform public.team_add_member(l.team_id, auth.uid(), l.role, l.for_member);
  if not was then update public.team_invite_links set uses = uses + 1 where token = p_token; end if;
  return l.team_id;
end $$;

-- Kaverikutsu (vain kavereille) + vastaus
create or replace function public.invite_to_team(p_team uuid, p_user uuid, p_role text default 'member') returns void
language plpgsql security definer set search_path = public as $$
declare t public.teams; nm text;
begin
  if auth.uid() is null then raise exception 'not_authenticated' using errcode = 'P0001'; end if;
  if public.is_banned() then raise exception 'account_banned' using errcode = 'P0001'; end if;
  if not public.is_team_coach(p_team) then raise exception 'team_staff_only' using errcode = 'P0001'; end if;
  if coalesce(p_role, '') not in ('member','parent','coach') then raise exception 'team_role_invalid' using errcode = 'P0001'; end if;
  if p_role = 'coach' and not public.is_team_admin(p_team) then raise exception 'team_manager_only' using errcode = 'P0001'; end if;
  if p_user is null or p_user = auth.uid() or not public.are_friends(auth.uid(), p_user) then
    raise exception 'not_friends' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.team_members where team_id = p_team and user_id = p_user) then
    raise exception 'already_team_member' using errcode = 'P0001';
  end if;
  if (select count(*) from public.team_invites where team_id = p_team and created_at > now() - interval '1 day') >= 100 then
    raise exception 'too_many_invites' using errcode = 'P0001';
  end if;
  select * into t from public.teams where id = p_team;
  insert into public.team_invites (team_id, invitee_id, inviter_id, role) values (p_team, p_user, auth.uid(), p_role)
    on conflict (team_id, invitee_id) do update set role = excluded.role, inviter_id = excluded.inviter_id, created_at = now();
  nm := public.display_name_of(auth.uid());
  perform public.notify(p_user, '👥', 'team_invite', jsonb_build_object('name', nm, 'team', t.name),
    nm || ' kutsui sinut joukkueeseen “' || t.name || '”', 'team', p_team);
end $$;

create or replace function public.respond_team_invite(p_team uuid, p_accept boolean) returns void
language plpgsql security definer set search_path = public as $$
declare i public.team_invites;
begin
  if auth.uid() is null then raise exception 'not_authenticated' using errcode = 'P0001'; end if;
  select * into i from public.team_invites where team_id = p_team and invitee_id = auth.uid() for update;
  if not found then raise exception 'team_invite_not_found' using errcode = 'P0001'; end if;
  delete from public.team_invites where team_id = p_team and invitee_id = auth.uid();
  if p_accept then
    if public.is_banned() then raise exception 'account_banned' using errcode = 'P0001'; end if;
    perform public.team_add_member(p_team, auth.uid(), i.role, null);
  end if;
end $$;

-- Jäsen ilman omaa tiliä (esim. juniori, jonka huoltaja ilmoittaa)
create or replace function public.add_team_roster_member(p_team uuid, p_name text, p_title text default '') returns uuid
language plpgsql security definer set search_path = public as $$
declare v text := btrim(regexp_replace(coalesce(p_name, ''), '\s+', ' ', 'g')); mid uuid;
begin
  if auth.uid() is null then raise exception 'not_authenticated' using errcode = 'P0001'; end if;
  if public.is_banned() then raise exception 'account_banned' using errcode = 'P0001'; end if;
  if not public.is_team_coach(p_team) then raise exception 'team_staff_only' using errcode = 'P0001'; end if;
  if char_length(v) not between 2 and 40 then raise exception 'team_member_name_invalid' using errcode = 'P0001'; end if;
  if public.team_member_count(p_team) >= 300 then raise exception 'team_full' using errcode = 'P0001'; end if;
  insert into public.team_members (team_id, user_id, role, display_name, title)
    values (p_team, null, 'member', v, left(btrim(coalesce(p_title, '')), 40)) returning id into mid;
  return mid;
end $$;

-- Rooli, titteli ja huoltajan linkitys. Roolit ja linkit: joukkueenjohtaja; titteli: henkilökunta. Omistaja pysyy johtajana.
create or replace function public.set_team_member(p_member uuid, p jsonb) returns void
language plpgsql security definer set search_path = public as $$
declare m public.team_members; t public.teams; v_role text; v_link uuid; v_title text; v_name text;
begin
  if auth.uid() is null then raise exception 'not_authenticated' using errcode = 'P0001'; end if;
  if public.is_banned() then raise exception 'account_banned' using errcode = 'P0001'; end if;
  select * into m from public.team_members where id = p_member for update;
  if not found then raise exception 'team_member_not_found' using errcode = 'P0001'; end if;
  if not public.is_team_coach(m.team_id) then raise exception 'team_staff_only' using errcode = 'P0001'; end if;
  select * into t from public.teams where id = m.team_id;
  v_role := coalesce(nullif(p->>'role', ''), m.role);
  v_link := case when p ? 'linked_member' then nullif(p->>'linked_member', '')::uuid else m.linked_member end;
  v_title := case when p ? 'title' then left(btrim(coalesce(p->>'title', '')), 40) else m.title end;
  v_name := case when p ? 'display_name' and m.user_id is null
                 then btrim(regexp_replace(coalesce(p->>'display_name', ''), '\s+', ' ', 'g')) else m.display_name end;
  if (v_role <> m.role or v_link is distinct from m.linked_member) and not public.is_team_admin(m.team_id) then
    raise exception 'team_manager_only' using errcode = 'P0001';
  end if;
  if v_role not in ('manager','coach','member','parent') then raise exception 'team_role_invalid' using errcode = 'P0001'; end if;
  if m.user_id is null and v_role <> 'member' then raise exception 'team_role_invalid' using errcode = 'P0001'; end if;
  if m.user_id = t.owner_id and v_role <> 'manager' then raise exception 'team_owner_stays_manager' using errcode = 'P0001'; end if;
  if v_role <> 'parent' then v_link := null; end if;
  if v_link is not null and not exists (select 1 from public.team_members x where x.id = v_link and x.team_id = m.team_id
                                         and x.role = 'member' and x.id <> m.id) then
    raise exception 'team_member_not_found' using errcode = 'P0001';
  end if;
  if m.user_id is null and char_length(v_name) not between 2 and 40 then raise exception 'team_member_name_invalid' using errcode = 'P0001'; end if;
  if m.role = 'member' and v_role <> 'member' then
    update public.team_members set linked_member = null where linked_member = m.id;
  end if;
  update public.team_members set role = v_role, linked_member = v_link, title = v_title, display_name = v_name where id = m.id;
  if v_role <> m.role and v_role in ('manager','coach') and m.user_id is not null and m.user_id <> auth.uid() then
    perform public.notify(m.user_id, '⭐', 'team_role_' || v_role, jsonb_build_object('team', t.name),
      'Sinut nimettiin ' || case when v_role = 'manager' then 'joukkueenjohtajaksi' else 'valmentajaksi' end
      || ' joukkueessa “' || t.name || '”', 'team', t.id);
  end if;
end $$;

-- Poisto: johtaja kenet tahansa (ei omistajaa), valmentaja tilittömät jäsenet, jäsen itsensä (lähtö)
create or replace function public.remove_team_member(p_member uuid) returns void
language plpgsql security definer set search_path = public as $$
declare m public.team_members; t public.teams; nm text;
begin
  if auth.uid() is null then raise exception 'not_authenticated' using errcode = 'P0001'; end if;
  select * into m from public.team_members where id = p_member for update;
  if not found then raise exception 'team_member_not_found' using errcode = 'P0001'; end if;
  select * into t from public.teams where id = m.team_id;
  if m.user_id is not null and m.user_id = t.owner_id then raise exception 'team_owner_stays_manager' using errcode = 'P0001'; end if;
  if not (coalesce(m.user_id = auth.uid(), false) or public.is_team_admin(m.team_id)
          or (m.user_id is null and public.is_team_coach(m.team_id))) then
    raise exception 'team_manager_only' using errcode = 'P0001';
  end if;
  nm := coalesce(nullif(m.display_name, ''), public.display_name_of(m.user_id));
  delete from public.team_members where id = m.id;
  if m.user_id is not null then
    if m.user_id = auth.uid() then
      perform public.post_system_message(public.team_conv(t.id), 'team_left', jsonb_build_object('name', nm), nm || ' lähti joukkueesta');
    else
      perform public.post_system_message(public.team_conv(t.id), 'team_member_removed', jsonb_build_object('name', nm),
        nm || ' poistettiin joukkueesta');
      perform public.notify(m.user_id, '👋', 'team_removed', jsonb_build_object('team', t.name),
        'Sinut poistettiin joukkueesta “' || t.name || '”', 'team', t.id);
    end if;
  end if;
end $$;

-- Tapahtuman tarkistukset: paikka, kapteeni ja sarja samasta joukkueesta; sarjan esiintymän muokkaus = "muokattu"
create or replace function public.team_events_before_write() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'UPDATE' then
    new.team_id := old.team_id; new.created_by := old.created_by; new.created_at := old.created_at;
    if new.series_id is distinct from old.series_id and new.series_id is not null then new.series_id := old.series_id; end if;
  elsif auth.uid() is not null then
    new.created_by := auth.uid(); new.cancelled := coalesce(new.cancelled, false);
  end if;
  new.title := btrim(regexp_replace(coalesce(new.title, ''), '\s+', ' ', 'g'));
  new.description := btrim(coalesce(new.description, ''));
  new.opponent := btrim(coalesce(new.opponent, ''));
  new.place_name := btrim(coalesce(new.place_name, ''));
  new.place_address := btrim(coalesce(new.place_address, ''));
  if new.place_id is not null and not exists (select 1 from public.team_places p where p.id = new.place_id and p.team_id = new.team_id) then
    raise exception 'team_place_not_found' using errcode = 'P0001';
  end if;
  if new.captain_member is not null and not exists (
       select 1 from public.team_members m where m.id = new.captain_member and m.team_id = new.team_id and m.role in ('member','coach','manager')) then
    raise exception 'team_member_not_found' using errcode = 'P0001';
  end if;
  if new.series_id is not null and not exists (select 1 from public.team_event_series s where s.id = new.series_id and s.team_id = new.team_id) then
    raise exception 'team_series_not_found' using errcode = 'P0001';
  end if;
  if tg_op = 'UPDATE' and new.series_id is not null and coalesce(current_setting('molaplan.series_sync', true), '') <> '1'
     and (new.event_date, new.event_time, new.duration_min, new.title, new.description, new.place_id, new.place_name, new.place_address, new.kind)
         is distinct from (old.event_date, old.event_time, old.duration_min, old.title, old.description, old.place_id, old.place_name, old.place_address, old.kind) then
    new.modified := true;
  end if;
  return new;
end $$;
drop trigger if exists team_events_before_write on public.team_events;
create trigger team_events_before_write before insert or update on public.team_events
  for each row execute function public.team_events_before_write();

-- Peruttu → ilmoitus tuleville/ehkä tuleville (ja linkitetyille huoltajille) + viesti joukkueen chattiin
create or replace function public.team_events_after_update() returns trigger
language plpgsql security definer set search_path = public as $$
declare r record; t public.teams; d text;
begin
  if new.cancelled and not old.cancelled then
    select * into t from public.teams where id = new.team_id;
    d := to_char(new.event_date, 'DD.MM.') || coalesce(' ' || to_char(new.event_time, 'HH24:MI'), '');
    for r in
      select distinct u from (
        select m.user_id u from public.team_event_rsvps x join public.team_members m on m.id = x.member_id
         where x.event_id = new.id and x.status in ('going','maybe') and m.user_id is not null
        union
        select p.user_id from public.team_event_rsvps x join public.team_members p on p.linked_member = x.member_id
         where x.event_id = new.id and x.status in ('going','maybe') and p.user_id is not null) q
      where u is distinct from auth.uid()
    loop
      perform public.notify(r.u, '🚫', 'team_event_cancelled', jsonb_build_object('title', new.title, 'date', d, 'team', t.name),
        '“' || new.title || '” (' || d || ') on peruttu – ' || t.name, 'team', new.team_id);
    end loop;
    perform public.post_system_message(public.team_conv(new.team_id), 'team_event_cancelled',
      jsonb_build_object('title', new.title, 'date', d, 'team', t.name), '“' || new.title || '” (' || d || ') on peruttu');
  end if;
  return null;
end $$;
drop trigger if exists team_events_after_update on public.team_events;
create trigger team_events_after_update after update of cancelled on public.team_events
  for each row execute function public.team_events_after_update();

-- Toistuvat tapahtumat: luonti ja muokkaus. Muokkaus päivittää tulevat, muokkaamattomat ja perumattomat
-- esiintymät päivämäärän mukaan (ilmoittautumiset säilyvät); poistuneet päivät poistetaan, uudet lisätään.
create or replace function public.save_team_series(p jsonb) returns uuid
language plpgsql security definer set search_path = public as $$
declare s public.team_event_series; sid uuid := nullif(p->>'id', '')::uuid; tid uuid; v_days int[]; v_from date; v_to date;
  v_title text := btrim(regexp_replace(coalesce(p->>'title', ''), '\s+', ' ', 'g'));
  v_kind text := coalesce(nullif(p->>'kind', ''), 'training'); v_time time; v_dur int; v_place uuid;
  v_pname text := left(btrim(coalesce(p->>'place_name', '')), 60); v_paddr text := left(btrim(coalesce(p->>'place_address', '')), 120);
  v_desc text := left(btrim(coalesce(p->>'description', '')), 400); today date := public.today_fi(); n int;
begin
  if auth.uid() is null then raise exception 'not_authenticated' using errcode = 'P0001'; end if;
  if public.is_banned() then raise exception 'account_banned' using errcode = 'P0001'; end if;
  if sid is not null then
    select * into s from public.team_event_series where id = sid for update;
    if not found then raise exception 'team_series_not_found' using errcode = 'P0001'; end if;
    tid := s.team_id;
  else
    tid := nullif(p->>'team_id', '')::uuid;
  end if;
  if tid is null or not public.is_team_coach(tid) then raise exception 'team_staff_only' using errcode = 'P0001'; end if;
  begin
    v_days := array(select distinct x::int from jsonb_array_elements_text(coalesce(p->'weekdays', '[]'::jsonb)) x order by 1);
    v_time := (p->>'start_time')::time;
    v_dur := coalesce(nullif(p->>'duration_min', '')::int, 90);
    v_from := (p->>'starts_on')::date;
    v_to := (p->>'ends_on')::date;
    v_place := nullif(p->>'place_id', '')::uuid;
  exception when others then raise exception 'team_series_invalid' using errcode = 'P0001';
  end;
  if not public.valid_weekdays(v_days) or v_time is null or v_from is null or v_to is null or v_to < v_from
     or v_to > v_from + 400 or v_dur not between 5 and 1440 or char_length(v_title) not between 2 and 60
     or v_kind not in ('training','game','meeting') or (sid is null and v_to < today) then
    raise exception 'team_series_invalid' using errcode = 'P0001';
  end if;
  if v_place is not null then
    select name, address into v_pname, v_paddr from public.team_places where id = v_place and team_id = tid;
    if not found then raise exception 'team_place_not_found' using errcode = 'P0001'; end if;
  end if;
  select count(*) into n from public.series_dates(v_days, greatest(v_from, today), v_to);
  if n > 370 then raise exception 'team_series_too_long' using errcode = 'P0001'; end if;
  perform set_config('molaplan.series_sync', '1', true);
  if sid is null then
    insert into public.team_event_series (team_id, kind, title, description, weekdays, start_time, duration_min, starts_on, ends_on,
                                          place_id, place_name, place_address, created_by)
      values (tid, v_kind, v_title, v_desc, v_days, v_time, v_dur, v_from, v_to, v_place, v_pname, v_paddr, auth.uid())
      returning id into sid;
  else
    update public.team_event_series set kind = v_kind, title = v_title, description = v_desc, weekdays = v_days, start_time = v_time,
      duration_min = v_dur, starts_on = v_from, ends_on = v_to, place_id = v_place, place_name = v_pname, place_address = v_paddr,
      updated_at = now() where id = sid;
    delete from public.team_events e where e.series_id = sid and e.event_date >= today and not e.modified and not e.cancelled
      and e.event_date not in (select public.series_dates(v_days, greatest(v_from, today), v_to));
    update public.team_events e set kind = v_kind, title = v_title, description = v_desc, event_time = v_time, duration_min = v_dur,
      place_id = v_place, place_name = v_pname, place_address = v_paddr
      where e.series_id = sid and e.event_date >= today and not e.modified and not e.cancelled;
  end if;
  insert into public.team_events (team_id, series_id, kind, title, description, event_date, event_time, duration_min,
                                  place_id, place_name, place_address, created_by)
    select tid, sid, v_kind, v_title, v_desc, d, v_time, v_dur, v_place, v_pname, v_paddr, auth.uid()
      from public.series_dates(v_days, greatest(v_from, today), v_to) d
     where not exists (select 1 from public.team_events e where e.series_id = sid and e.event_date = d);
  perform set_config('molaplan.series_sync', '0', true);
  return sid;
end $$;

-- Sarjan poisto: tulevat esiintymät poistetaan, menneet jäävät (series_id → null)
create or replace function public.delete_team_series(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare tid uuid;
begin
  select team_id into tid from public.team_event_series where id = p_id;
  if tid is null or not public.is_team_coach(tid) then raise exception 'team_staff_only' using errcode = 'P0001'; end if;
  delete from public.team_events where series_id = p_id and event_date >= public.today_fi();
  delete from public.team_event_series where id = p_id;
end $$;

-- Ilmoittautuminen: oma, huoltaja linkitetyn jäsenen puolesta tai henkilökunta kenen tahansa puolesta.
-- p_status null = vastaus pois. Peruttuun tai menneeseen ei voi enää ilmoittautua (henkilökunta voi kirjata jälkikäteen).
create or replace function public.team_rsvp(p_event uuid, p_member uuid, p_status text) returns void
language plpgsql security definer set search_path = public as $$
declare e public.team_events; m public.team_members; staff boolean;
begin
  if auth.uid() is null then raise exception 'not_authenticated' using errcode = 'P0001'; end if;
  if public.is_banned() then raise exception 'account_banned' using errcode = 'P0001'; end if;
  select * into e from public.team_events where id = p_event;
  if not found or not public.is_team_member(e.team_id) then raise exception 'team_event_not_found' using errcode = 'P0001'; end if;
  select * into m from public.team_members where id = p_member and team_id = e.team_id;
  if not found then raise exception 'team_member_not_found' using errcode = 'P0001'; end if;
  staff := public.is_team_coach(e.team_id);
  if not (coalesce(m.user_id = auth.uid(), false) or staff or exists (
            select 1 from public.team_members p where p.team_id = e.team_id and p.user_id = auth.uid()
               and p.role = 'parent' and p.linked_member = m.id)) then
    raise exception 'team_rsvp_not_allowed' using errcode = 'P0001';
  end if;
  if m.role = 'parent' then raise exception 'team_rsvp_not_allowed' using errcode = 'P0001'; end if;
  if not staff and (e.cancelled or e.event_date < public.today_fi()) then raise exception 'team_event_closed' using errcode = 'P0001'; end if;
  if p_status is null or p_status = '' then
    delete from public.team_event_rsvps where event_id = p_event and member_id = p_member;
    return;
  end if;
  if p_status not in ('going','maybe','no') then raise exception 'team_rsvp_invalid' using errcode = 'P0001'; end if;
  if p_status = 'going' and e.max_participants is not null and (
       select count(*) from public.team_event_rsvps where event_id = p_event and status = 'going' and member_id <> p_member) >= e.max_participants then
    raise exception 'event_full' using errcode = 'P0001';
  end if;
  insert into public.team_event_rsvps (event_id, member_id, user_id, status, responded_by, updated_at)
    values (p_event, p_member, m.user_id, p_status, auth.uid(), now())
    on conflict (event_id, member_id) do update set status = excluded.status, responded_by = excluded.responded_by, updated_at = now();
end $$;

-- Omistajan poistuminen (tilin poisto) → seuraava joukkueenjohtaja tai valmentaja omistajaksi
create or replace function public.teams_owner_handover() returns trigger
language plpgsql security definer set search_path = public as $$
declare nxt uuid;
begin
  if exists (select 1 from public.teams t where t.id = old.team_id and t.owner_id = old.user_id) then
    select user_id into nxt from public.team_members where team_id = old.team_id and user_id is not null
      order by (role = 'manager') desc, (role = 'coach') desc, joined_at limit 1;
    if nxt is not null then
      update public.teams set owner_id = nxt where id = old.team_id;
      update public.team_members set role = 'manager' where team_id = old.team_id and user_id = nxt;
    end if;
  end if;
  return null;
end $$;
drop trigger if exists teams_owner_handover on public.team_members;
create trigger teams_owner_handover after delete on public.team_members
  for each row execute function public.teams_owner_handover();

create or replace function public.team_docs_before_write() returns trigger
language plpgsql as $$
begin
  if tg_op = 'UPDATE' then new.team_id := old.team_id; new.created_at := old.created_at; end if;
  new.title := btrim(coalesce(new.title, ''));
  new.updated_by := auth.uid();
  new.updated_at := now();
  return new;
end $$;
drop trigger if exists team_docs_before_write on public.team_docs;
create trigger team_docs_before_write before insert or update on public.team_docs
  for each row execute function public.team_docs_before_write();
create or replace function public.team_places_before_write() returns trigger
language plpgsql as $$
begin
  if tg_op = 'UPDATE' then new.team_id := old.team_id; new.created_at := old.created_at; end if;
  new.name := btrim(coalesce(new.name, '')); new.address := btrim(coalesce(new.address, '')); new.notes := btrim(coalesce(new.notes, ''));
  return new;
end $$;
drop trigger if exists team_places_before_write on public.team_places;
create trigger team_places_before_write before insert or update on public.team_places
  for each row execute function public.team_places_before_write();

-- RLS: joukkue näkyy vain jäsenille, kutsutuille ja ylläpidolle. Jäsenet/kutsut/ilmoittautumiset/sarjat vain RPC:llä.
alter table public.team_event_series enable row level security;
alter table public.team_docs         enable row level security;
alter table public.team_invites      enable row level security;
alter table public.team_invite_links enable row level security;

drop policy if exists "teams: kirjautuneet näkevät" on public.teams;
drop policy if exists "teams: kirjautunut luo oman" on public.teams;
drop policy if exists "teams: ylläpitäjä muokkaa" on public.teams;
drop policy if exists "teams: omistaja poistaa oman" on public.teams;
drop policy if exists "teams: jäsenet, kutsutut ja ylläpito näkevät" on public.teams;
create policy "teams: jäsenet, kutsutut ja ylläpito näkevät" on public.teams for select to authenticated
  using (public.is_team_member(id) or public.is_admin()
         or exists (select 1 from public.team_invites i where i.team_id = teams.id and i.invitee_id = auth.uid()));
drop policy if exists "teams: omistaja tai ylläpito poistaa" on public.teams;
create policy "teams: omistaja tai ylläpito poistaa" on public.teams for delete to authenticated
  using (owner_id = auth.uid() or public.is_admin());

drop policy if exists "team_members: jäsenet näkevät jäsenet" on public.team_members;
drop policy if exists "team_members: liity tai ylläpitäjä lisää" on public.team_members;
drop policy if exists "team_members: ylläpitäjä muuttaa roolin" on public.team_members;
drop policy if exists "team_members: eroa tai ylläpitäjä poistaa" on public.team_members;
drop policy if exists "team_members: joukkue ja ylläpito näkevät" on public.team_members;
create policy "team_members: joukkue ja ylläpito näkevät" on public.team_members for select to authenticated
  using (public.is_team_member(team_id) or public.is_admin());

drop policy if exists "team_roles: jäsenet lukevat" on public.team_roles;
drop policy if exists "team_roles: ylläpitäjä hallitsee" on public.team_roles;
drop policy if exists "team_roles: joukkue lukee" on public.team_roles;
create policy "team_roles: joukkue lukee" on public.team_roles for select to authenticated using (public.is_team_member(team_id));
drop policy if exists "team_roles: henkilökunta hallitsee" on public.team_roles;
create policy "team_roles: henkilökunta hallitsee" on public.team_roles for all to authenticated
  using (public.is_team_coach(team_id)) with check (public.is_team_coach(team_id) and not public.is_banned());

drop policy if exists "team_places: jäsenet lukevat" on public.team_places;
drop policy if exists "team_places: ylläpitäjä hallitsee" on public.team_places;
drop policy if exists "team_places: joukkue lukee" on public.team_places;
create policy "team_places: joukkue lukee" on public.team_places for select to authenticated using (public.is_team_member(team_id));
drop policy if exists "team_places: henkilökunta hallitsee" on public.team_places;
create policy "team_places: henkilökunta hallitsee" on public.team_places for all to authenticated
  using (public.is_team_coach(team_id)) with check (public.is_team_coach(team_id) and not public.is_banned());

drop policy if exists "team_events: jäsenet lukevat" on public.team_events;
drop policy if exists "team_events: valmentaja hallitsee" on public.team_events;
drop policy if exists "team_events: joukkue lukee" on public.team_events;
create policy "team_events: joukkue lukee" on public.team_events for select to authenticated using (public.is_team_member(team_id));
drop policy if exists "team_events: henkilökunta hallitsee" on public.team_events;
create policy "team_events: henkilökunta hallitsee" on public.team_events for all to authenticated
  using (public.is_team_coach(team_id)) with check (public.is_team_coach(team_id) and not public.is_banned());

drop policy if exists "team_event_series: joukkue lukee" on public.team_event_series;
create policy "team_event_series: joukkue lukee" on public.team_event_series for select to authenticated
  using (public.is_team_member(team_id));

drop policy if exists "team_event_rsvps: jäsenet lukevat" on public.team_event_rsvps;
drop policy if exists "team_event_rsvps: jäsen ilmoittautuu" on public.team_event_rsvps;
drop policy if exists "team_event_rsvps: jäsen muuttaa omaa" on public.team_event_rsvps;
drop policy if exists "team_event_rsvps: jäsen peruu oman" on public.team_event_rsvps;
drop policy if exists "team_event_rsvps: joukkue lukee" on public.team_event_rsvps;
create policy "team_event_rsvps: joukkue lukee" on public.team_event_rsvps for select to authenticated
  using (public.is_team_member(public.team_of_event(event_id)));

drop policy if exists "team_docs: joukkue lukee" on public.team_docs;
create policy "team_docs: joukkue lukee" on public.team_docs for select to authenticated
  using (public.is_team_member(team_id) and (not staff_only or public.is_team_coach(team_id)));
drop policy if exists "team_docs: henkilökunta hallitsee" on public.team_docs;
create policy "team_docs: henkilökunta hallitsee" on public.team_docs for all to authenticated
  using (public.is_team_coach(team_id)) with check (public.is_team_coach(team_id) and not public.is_banned());

drop policy if exists "team_invites: osapuolet lukevat" on public.team_invites;
create policy "team_invites: osapuolet lukevat" on public.team_invites for select to authenticated
  using (invitee_id = auth.uid() or public.is_team_coach(team_id));
drop policy if exists "team_invite_links: henkilökunta lukee" on public.team_invite_links;
create policy "team_invite_links: henkilökunta lukee" on public.team_invite_links for select to authenticated
  using (public.is_team_coach(team_id));

-- team_messages = vanha, käyttämätön taulu (chat on nyt conversations.kind 'team'): ei uusia kirjoituksia
drop policy if exists "team_messages: jäsen lähettää" on public.team_messages;

-- 9b. YRITYKSET: omistaja hallitsee järjestäjiä (editor), järjestäjät luovat ja muokkaavat yrityksen tapahtumia.
--     Päättynyt tilaus = vain luku (business_can_post vaatii aktiivisen tilauksen myös poistoon).
create or replace function public.is_business_owner(bid uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.business_members m where m.business_id = bid and m.user_id = auth.uid() and m.role = 'owner')
$$;

drop policy if exists "businesses: jäsen tai ylläpito päivittää" on public.businesses;
drop policy if exists "businesses: omistaja tai ylläpito päivittää" on public.businesses;
create policy "businesses: omistaja tai ylläpito päivittää" on public.businesses
  for update to authenticated using (public.is_business_owner(id) or public.is_admin())
  with check (public.is_business_owner(id) or public.is_admin());
drop policy if exists "business_private: jäsen tai ylläpito lukee" on public.business_private;
drop policy if exists "business_private: omistaja tai ylläpito lukee" on public.business_private;
create policy "business_private: omistaja tai ylläpito lukee" on public.business_private
  for select to authenticated using (public.is_business_owner(business_id) or public.is_admin());
drop policy if exists "business_private: jäsen lisää" on public.business_private;
drop policy if exists "business_private: omistaja lisää" on public.business_private;
create policy "business_private: omistaja lisää" on public.business_private
  for insert to authenticated with check (public.is_business_owner(business_id));
drop policy if exists "business_private: jäsen tai ylläpito päivittää" on public.business_private;
drop policy if exists "business_private: omistaja tai ylläpito päivittää" on public.business_private;
create policy "business_private: omistaja tai ylläpito päivittää" on public.business_private
  for update to authenticated using (public.is_business_owner(business_id) or public.is_admin())
  with check (public.is_business_owner(business_id) or public.is_admin());
drop policy if exists "events: järjestäjä tai ylläpito poistaa" on public.events;
create policy "events: järjestäjä tai ylläpito poistaa" on public.events
  for delete to authenticated using (
    host_id = auth.uid() or public.is_admin() or (business_id is not null and public.business_can_post(business_id)));

-- Järjestäjäkutsu linkillä (omistaja, aktiivinen tilaus): 7 vrk, enintään 5 käyttöä
create table if not exists public.business_invite_links (
  token       uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  created_by  uuid references public.profiles(id) on delete set null,
  created_at  timestamptz not null default now(),
  expires_at  timestamptz not null default now() + interval '7 days',
  max_uses    int not null default 5 check (max_uses between 1 and 50),
  uses        int not null default 0,
  revoked     boolean not null default false
);
create index if not exists business_invite_links_biz_idx on public.business_invite_links (business_id, created_at desc);
alter table public.business_invite_links enable row level security;
drop policy if exists "business_invite_links: omistaja lukee" on public.business_invite_links;
create policy "business_invite_links: omistaja lukee" on public.business_invite_links for select to authenticated
  using (public.is_business_owner(business_id) or public.is_admin());

create or replace function public.create_business_invite_link(p_business uuid) returns uuid
language plpgsql security definer set search_path = public as $$
declare tok uuid;
begin
  if auth.uid() is null then raise exception 'not_authenticated' using errcode = 'P0001'; end if;
  if public.is_banned() then raise exception 'account_banned' using errcode = 'P0001'; end if;
  if not public.is_business_owner(p_business) then raise exception 'business_owner_only' using errcode = 'P0001'; end if;
  if not public.business_active(p_business) then raise exception 'business_subscription_required' using errcode = 'P0001'; end if;
  if (select count(*) from public.business_invite_links where business_id = p_business and created_at > now() - interval '1 day') >= 20 then
    raise exception 'too_many_invite_links' using errcode = 'P0001';
  end if;
  insert into public.business_invite_links (business_id, created_by) values (p_business, auth.uid()) returning token into tok;
  return tok;
end $$;

create or replace function public.revoke_business_invite_link(p_token uuid) returns void
language plpgsql security definer set search_path = public as $$
declare bid uuid;
begin
  select business_id into bid from public.business_invite_links where token = p_token;
  if bid is null or not (public.is_business_owner(bid) or public.is_admin()) then
    raise exception 'business_owner_only' using errcode = 'P0001';
  end if;
  update public.business_invite_links set revoked = true where token = p_token;
end $$;

create or replace function public.business_link_preview(p_token uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare l public.business_invite_links; b public.businesses;
begin
  if auth.uid() is null then raise exception 'not_authenticated' using errcode = 'P0001'; end if;
  select * into l from public.business_invite_links where token = p_token;
  if not found or l.revoked or l.expires_at < now() or l.uses >= l.max_uses or not public.business_active(l.business_id) then
    raise exception 'invite_link_invalid' using errcode = 'P0001';
  end if;
  select * into b from public.businesses where id = l.business_id;
  return jsonb_build_object('business_id', b.id, 'name', b.name, 'logo_url', b.logo_url,
    'already_member', public.is_business_member(b.id));
end $$;

create or replace function public.join_business_by_link(p_token uuid) returns uuid
language plpgsql security definer set search_path = public as $$
declare l public.business_invite_links; b public.businesses; nm text; r record;
begin
  if auth.uid() is null then raise exception 'not_authenticated' using errcode = 'P0001'; end if;
  if public.is_banned() then raise exception 'account_banned' using errcode = 'P0001'; end if;
  select * into l from public.business_invite_links where token = p_token for update;
  if not found or l.revoked or l.expires_at < now() or l.uses >= l.max_uses or not public.business_active(l.business_id) then
    raise exception 'invite_link_invalid' using errcode = 'P0001';
  end if;
  if public.is_business_member(l.business_id) then return l.business_id; end if;
  if (select count(*) from public.business_members where business_id = l.business_id) >= 30 then
    raise exception 'business_members_full' using errcode = 'P0001';
  end if;
  insert into public.business_members (business_id, user_id, role) values (l.business_id, auth.uid(), 'editor');
  update public.business_invite_links set uses = uses + 1 where token = p_token;
  select * into b from public.businesses where id = l.business_id;
  nm := public.display_name_of(auth.uid());
  for r in select user_id from public.business_members where business_id = b.id and role = 'owner' and user_id <> auth.uid() loop
    perform public.notify(r.user_id, '🏢', 'business_member_joined', jsonb_build_object('name', nm, 'business', b.name),
      nm || ' liittyi yrityksen “' || b.name || '” järjestäjäksi', 'business', b.id);
  end loop;
  return b.id;
end $$;

-- Järjestäjän poisto: omistaja (ei viimeistä omistajaa), järjestäjä itse tai ylläpito
create or replace function public.remove_business_member(p_business uuid, p_user uuid) returns void
language plpgsql security definer set search_path = public as $$
declare m public.business_members; b public.businesses;
begin
  if auth.uid() is null then raise exception 'not_authenticated' using errcode = 'P0001'; end if;
  select * into m from public.business_members where business_id = p_business and user_id = p_user for update;
  if not found then raise exception 'business_member_not_found' using errcode = 'P0001'; end if;
  if not (p_user = auth.uid() or public.is_business_owner(p_business) or public.is_admin()) then
    raise exception 'business_owner_only' using errcode = 'P0001';
  end if;
  if m.role = 'owner' and not public.is_admin() then raise exception 'business_owner_stays' using errcode = 'P0001'; end if;
  delete from public.business_members where business_id = p_business and user_id = p_user;
  select * into b from public.businesses where id = p_business;
  if p_user <> auth.uid() then
    perform public.notify(p_user, '👋', 'business_removed', jsonb_build_object('business', b.name),
      'Sinut poistettiin yrityksen “' || b.name || '” järjestäjistä', 'business', b.id);
  end if;
end $$;

-- Toistuvat yritystapahtumat: sarja luo jokaisesta päivästä tavallisen yritystapahtuman (oma chat, osallistujat).
-- Muokkaus päivittää tulevat, erikseen muokkaamattomat esiintymät; poistuneet päivät poistetaan.
create table if not exists public.business_event_series (
  id               uuid primary key default gen_random_uuid(),
  business_id      uuid not null references public.businesses(id) on delete cascade,
  activity_id      text not null references public.activities(id) on update cascade,
  title            text not null check (char_length(title) between 3 and 60),
  description      text not null default '' check (char_length(description) <= 2000),
  city             text not null check (char_length(city) between 1 and 40),
  district         text not null default '' check (char_length(district) <= 40),
  place            text not null check (char_length(place) between 2 and 70),
  lat              double precision check (lat between -90 and 90),
  lng              double precision check (lng between -180 and 180),
  weekdays         int[] not null check (public.valid_weekdays(weekdays)),
  start_time       time not null,
  duration_min     int check (duration_min is null or duration_min between 5 and 1440),
  starts_on        date not null,
  ends_on          date not null,
  tz               text not null default 'Europe/Helsinki' check (char_length(tz) <= 40),
  price_info       text not null default '' check (char_length(price_info) <= 120),
  official_url     text not null default '' check (official_url = '' or (official_url ~ '^https://[^\s<>"'']+$' and char_length(official_url) <= 300)),
  extra_info       text not null default '' check (char_length(extra_info) <= 1000),
  max_participants int check (max_participants is null or max_participants between 2 and 100000),
  skill_level      text not null default 'all' check (skill_level in ('all','beginner','intermediate','advanced')),
  created_by       uuid default auth.uid() references public.profiles(id) on delete set null,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  constraint business_event_series_range check (ends_on >= starts_on and ends_on <= starts_on + 400)
);
create index if not exists business_event_series_biz_idx on public.business_event_series (business_id);
alter table public.business_event_series enable row level security;
drop policy if exists "business_event_series: jäsenet ja ylläpito lukevat" on public.business_event_series;
create policy "business_event_series: jäsenet ja ylläpito lukevat" on public.business_event_series for select to authenticated
  using (public.is_business_member(business_id) or public.is_admin());

alter table public.events add column if not exists series_id uuid;
alter table public.events add column if not exists series_modified boolean not null default false;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'events_series_id_fkey') then
    alter table public.events add constraint events_series_id_fkey
      foreign key (series_id) references public.business_event_series(id) on delete set null;
  end if;
end $$;
create index if not exists events_series_idx on public.events (series_id, starts_at);

create or replace function public.events_series_mark() returns trigger
language plpgsql as $$
begin
  if coalesce(current_setting('molaplan.series_sync', true), '') = '1' then return new; end if;
  if tg_op = 'INSERT' then new.series_id := null; new.series_modified := false; return new; end if;
  new.series_id := old.series_id;
  if old.series_id is not null and (new.starts_at, new.ends_at, new.title, new.description, new.place, new.city, new.price_info, new.extra_info)
       is distinct from (old.starts_at, old.ends_at, old.title, old.description, old.place, old.city, old.price_info, old.extra_info) then
    new.series_modified := true;
  end if;
  return new;
end $$;
drop trigger if exists events_series_mark on public.events;
create trigger events_series_mark before insert or update on public.events
  for each row execute function public.events_series_mark();

create or replace function public.save_business_series(p jsonb) returns uuid
language plpgsql security definer set search_path = public as $$
declare s public.business_event_series; sid uuid := nullif(p->>'id', '')::uuid; bid uuid; v public.business_event_series;
  today date := public.today_fi(); n int;
begin
  if auth.uid() is null then raise exception 'not_authenticated' using errcode = 'P0001'; end if;
  if public.is_banned() then raise exception 'account_banned' using errcode = 'P0001'; end if;
  if sid is not null then
    select * into s from public.business_event_series where id = sid for update;
    if not found then raise exception 'business_series_not_found' using errcode = 'P0001'; end if;
    bid := s.business_id;
  else
    bid := nullif(p->>'business_id', '')::uuid;
  end if;
  if bid is null or not public.business_can_post(bid) then raise exception 'business_subscription_required' using errcode = 'P0001'; end if;
  begin
    v.activity_id := p->>'activity_id';
    v.title := btrim(regexp_replace(coalesce(p->>'title', ''), '\s+', ' ', 'g'));
    v.description := btrim(coalesce(p->>'description', ''));
    v.city := btrim(coalesce(p->>'city', ''));
    v.district := left(btrim(coalesce(p->>'district', '')), 40);
    v.place := btrim(coalesce(p->>'place', ''));
    v.lat := nullif(p->>'lat', '')::double precision;
    v.lng := nullif(p->>'lng', '')::double precision;
    v.weekdays := array(select distinct x::int from jsonb_array_elements_text(coalesce(p->'weekdays', '[]'::jsonb)) x order by 1);
    v.start_time := (p->>'start_time')::time;
    v.duration_min := nullif(p->>'duration_min', '')::int;
    v.starts_on := (p->>'starts_on')::date;
    v.ends_on := (p->>'ends_on')::date;
    v.tz := coalesce(nullif(p->>'tz', ''), 'Europe/Helsinki');
    v.price_info := btrim(coalesce(p->>'price_info', ''));
    v.official_url := btrim(coalesce(p->>'official_url', ''));
    v.extra_info := btrim(coalesce(p->>'extra_info', ''));
    v.max_participants := nullif(p->>'max_participants', '')::int;
    v.skill_level := coalesce(nullif(p->>'skill_level', ''), 'all');
  exception when others then raise exception 'business_series_invalid' using errcode = 'P0001';
  end;
  if not public.valid_weekdays(v.weekdays) or v.start_time is null or v.starts_on is null or v.ends_on is null
     or v.ends_on < v.starts_on or v.ends_on > v.starts_on + 400 or (sid is null and v.ends_on < today)
     or not exists (select 1 from pg_timezone_names where name = v.tz)
     or not exists (select 1 from public.activities a where a.id = v.activity_id and a.status = 'approved') then
    raise exception 'business_series_invalid' using errcode = 'P0001';
  end if;
  select count(*) into n from public.series_dates(v.weekdays, greatest(v.starts_on, today), v.ends_on);
  if n > 120 then raise exception 'business_series_too_long' using errcode = 'P0001'; end if;
  perform set_config('molaplan.series_sync', '1', true);
  if sid is null then
    insert into public.business_event_series (business_id, activity_id, title, description, city, district, place, lat, lng, weekdays,
      start_time, duration_min, starts_on, ends_on, tz, price_info, official_url, extra_info, max_participants, skill_level, created_by)
    values (bid, v.activity_id, v.title, v.description, v.city, v.district, v.place, v.lat, v.lng, v.weekdays, v.start_time,
      v.duration_min, v.starts_on, v.ends_on, v.tz, v.price_info, v.official_url, v.extra_info, v.max_participants, v.skill_level, auth.uid())
    returning id into sid;
  else
    update public.business_event_series set activity_id = v.activity_id, title = v.title, description = v.description, city = v.city,
      district = v.district, place = v.place, lat = v.lat, lng = v.lng, weekdays = v.weekdays, start_time = v.start_time,
      duration_min = v.duration_min, starts_on = v.starts_on, ends_on = v.ends_on, tz = v.tz, price_info = v.price_info,
      official_url = v.official_url, extra_info = v.extra_info, max_participants = v.max_participants, skill_level = v.skill_level,
      updated_at = now() where id = sid;
    delete from public.events e where e.series_id = sid and not e.series_modified and e.starts_at > now()
      and (e.starts_at at time zone v.tz)::date not in (select public.series_dates(v.weekdays, greatest(v.starts_on, today), v.ends_on));
    update public.events e set activity_id = v.activity_id, title = v.title, description = v.description, city = v.city,
      district = v.district, place = v.place, lat = v.lat, lng = v.lng, price_info = v.price_info, official_url = v.official_url,
      extra_info = v.extra_info, max_participants = v.max_participants, skill_level = v.skill_level,
      starts_at = ((e.starts_at at time zone v.tz)::date + v.start_time) at time zone v.tz,
      ends_at = case when v.duration_min is null then null
                     else (((e.starts_at at time zone v.tz)::date + v.start_time) at time zone v.tz) + make_interval(mins => v.duration_min) end
     where e.series_id = sid and not e.series_modified and e.starts_at > now();
  end if;
  insert into public.events (kind, business_id, host_id, series_id, activity_id, title, description, starts_at, ends_at, city, district,
                             place, lat, lng, max_participants, skill_level, price_info, official_url, extra_info)
    select 'business', bid, null, sid, v.activity_id, v.title, v.description, (d + v.start_time) at time zone v.tz,
           case when v.duration_min is null then null else ((d + v.start_time) at time zone v.tz) + make_interval(mins => v.duration_min) end,
           v.city, v.district, v.place, v.lat, v.lng, v.max_participants, v.skill_level, v.price_info, v.official_url, v.extra_info
      from public.series_dates(v.weekdays, greatest(v.starts_on, today), v.ends_on) d
     where (d + v.start_time) at time zone v.tz > now()
       and not exists (select 1 from public.events e where e.series_id = sid and (e.starts_at at time zone v.tz)::date = d);
  perform set_config('molaplan.series_sync', '0', true);
  return sid;
end $$;

create or replace function public.delete_business_series(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare bid uuid;
begin
  select business_id into bid from public.business_event_series where id = p_id;
  if bid is null or not public.business_can_post(bid) then raise exception 'business_subscription_required' using errcode = 'P0001'; end if;
  delete from public.events where series_id = p_id and starts_at > now();
  delete from public.business_event_series where id = p_id;
end $$;

-- 9c. Oikeudet: anon ei mitään; suorat kirjoitukset vain henkilökunnan tauluihin (RLS), muu RPC:llä
revoke all on public.team_event_series, public.team_docs, public.team_invites, public.team_invite_links,
  public.business_invite_links, public.business_event_series from public, anon;
revoke all on public.teams, public.team_members, public.team_roles, public.team_places, public.team_events,
  public.team_event_rsvps, public.team_messages from anon;
revoke insert, update, delete on public.team_members, public.team_event_rsvps, public.team_messages, public.team_event_series,
  public.team_invites, public.team_invite_links, public.business_invite_links, public.business_event_series from authenticated;
revoke insert, update on public.teams from authenticated;
grant select on public.teams, public.team_members, public.team_event_rsvps, public.team_messages, public.team_event_series,
  public.team_invites, public.team_invite_links, public.business_invite_links, public.business_event_series to authenticated;
grant delete on public.teams to authenticated;
grant select, insert, update, delete on public.team_docs, public.team_places, public.team_roles, public.team_events to authenticated;
grant select (extra_info) on public.events to anon;   -- guest_events.extra_info (osio 5b)

do $$
declare f text;
begin
  foreach f in array array[
    'series_dates(int[], date, date)', 'valid_weekdays(int[])', 'team_role(uuid)', 'team_member_count(uuid)',
    'update_team(uuid, jsonb)', 'create_team_invite_link(uuid, text, uuid)', 'revoke_team_invite_link(uuid)',
    'team_link_preview(uuid)', 'join_team_by_link(uuid)', 'invite_to_team(uuid, uuid, text)', 'respond_team_invite(uuid, boolean)',
    'add_team_roster_member(uuid, text, text)', 'set_team_member(uuid, jsonb)', 'remove_team_member(uuid)',
    'save_team_series(jsonb)', 'delete_team_series(uuid)', 'team_rsvp(uuid, uuid, text)',
    'is_business_owner(uuid)', 'create_business_invite_link(uuid)', 'revoke_business_invite_link(uuid)',
    'business_link_preview(uuid)', 'join_business_by_link(uuid)', 'remove_business_member(uuid, uuid)',
    'save_business_series(jsonb)', 'delete_business_series(uuid)']
  loop
    execute 'revoke execute on function public.' || f || ' from public, anon';
    execute 'grant execute on function public.' || f || ' to authenticated';
  end loop;
  foreach f in array array[
    'create_team_from_request(public.team_requests)', 'team_add_member(uuid, uuid, text, uuid)', 'team_staff_ids(uuid)',
    'team_conv(uuid)', 'team_events_before_write()', 'team_events_after_update()', 'teams_owner_handover()',
    'team_docs_before_write()', 'team_places_before_write()', 'events_series_mark()']
  loop
    execute 'revoke execute on function public.' || f || ' from public, anon, authenticated';
  end loop;
end $$;

-- Valmis! 🎉
