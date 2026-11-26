-- R256–R262 (t261u/t264u, v0.13.0): approved installers ('Asentaja').
--
-- Before: any user could switch on an installer profile and type any company name.
-- Now:
--  * Only Molaplan admins (private.shop_admins, the same list as the order shop) grant or revoke the
--    installer status and set the verified name + company shown to customers.
--  * Every approved installer has a permanent public installer ID (e.g. MPL-K7Q-M2X).
--  * A customer looks the installer up by that ID (only verified, public data comes back) and grants
--    access with an ordinary share of kind 'installer' straight to that user (active at once – the
--    customer confirmed the verified identity). The credential stays sealed to the installer's key.
--  * Revoking the status closes all the installer's shares at once (payload wiped); the home bridge
--    asks public.share_access() before serving a shared request and drops closed shares.
--  * profiles.installer / company can no longer be written by users; installer is kept in sync from
--    public.installers (older apps read it).
-- Idempotent (safe to run twice). No defaults are shipped: admins and installers are deployment data.

create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

-- private.shop_admins / private.jwt_email() / private.is_shop_admin() come from the shop migration;
-- recreated here (same definitions) so this file also works on its own.
create table if not exists private.shop_admins (email text primary key check (email = lower(email)));
create or replace function private.jwt_email() returns text
language sql stable set search_path = '' as $$
  select lower(coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'email', '')) $$;
create or replace function private.is_shop_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from private.shop_admins a where a.email = private.jwt_email() and a.email <> '') $$;
revoke all on function private.is_shop_admin() from public, anon;
grant execute on function private.is_shop_admin() to authenticated;

-- Installers ---------------------------------------------------------------------------------------
create table if not exists public.installers (
  user_id uuid primary key references auth.users (id) on delete cascade,
  public_id text not null unique check (public_id ~ '^MPL-[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{3}-[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{3}$'),
  display_name text not null check (char_length(btrim(display_name)) between 1 and 80),
  company text not null default '' check (char_length(company) <= 120),
  note text not null default '' check (char_length(note) <= 1000),          -- admin only
  status text not null default 'active' check (status in ('active', 'revoked')),
  granted_by text not null default '',
  granted_at timestamptz not null default now(),
  revoked_at timestamptz,
  updated_at timestamptz not null default now()
);
alter table public.installers enable row level security;
revoke all on public.installers from anon, authenticated;
-- The installer reads their own row (not the admin note); everything else goes through the functions.
grant select (user_id, public_id, display_name, company, status, granted_at, revoked_at) on public.installers to authenticated;
drop policy if exists "installers: own select" on public.installers;
create policy "installers: own select" on public.installers for select to authenticated
  using ((select auth.uid()) = user_id);

create or replace function private.is_installer(p_uid uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select p_uid is not null and exists (select 1 from public.installers i where i.user_id = p_uid and i.status = 'active') $$;
revoke all on function private.is_installer(uuid) from public, anon;
grant execute on function private.is_installer(uuid) to authenticated;

-- Applications ('Hae asentajaksi') ----------------------------------------------------------------
create table if not exists public.installer_applications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  email text not null default '',
  display_name text not null check (char_length(btrim(display_name)) between 1 and 80),
  company text not null default '' check (char_length(company) <= 120),
  message text not null default '' check (char_length(message) <= 1000),
  status text not null default 'new' check (status in ('new', 'approved', 'declined')),
  created_at timestamptz not null default now(),
  decided_at timestamptz
);
create unique index if not exists installer_applications_open_idx on public.installer_applications (user_id) where status = 'new';
alter table public.installer_applications enable row level security;
revoke all on public.installer_applications from anon, authenticated;
grant select on public.installer_applications to authenticated;
grant insert (display_name, company, message) on public.installer_applications to authenticated;
grant delete on public.installer_applications to authenticated;
drop policy if exists "installer applications: own select" on public.installer_applications;
drop policy if exists "installer applications: own insert" on public.installer_applications;
drop policy if exists "installer applications: own withdraw" on public.installer_applications;
create policy "installer applications: own select" on public.installer_applications for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "installer applications: own insert" on public.installer_applications for insert to authenticated
  with check ((select auth.uid()) = user_id and status = 'new');
create policy "installer applications: own withdraw" on public.installer_applications for delete to authenticated
  using ((select auth.uid()) = user_id and status = 'new');

create or replace function public.installer_application_fill() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  new.email := coalesce(nullif(private.jwt_email(), ''), (select lower(u.email) from auth.users u where u.id = new.user_id), '');
  return new;
end $$;
revoke all on function public.installer_application_fill() from public, anon, authenticated;
drop trigger if exists installer_application_fill on public.installer_applications;
create trigger installer_application_fill before insert on public.installer_applications
  for each row execute function public.installer_application_fill();

-- profiles: the installer flag and company are no longer the user's to set ------------------------
revoke insert, update on public.profiles from authenticated;
grant insert (user_id, display_name, share_pub) on public.profiles to authenticated;
grant update (display_name, share_pub) on public.profiles to authenticated;

create or replace function private.sync_profile_installer(p_uid uuid) returns void
language sql security definer set search_path = '' as $$
  update public.profiles p
     set installer = coalesce(i.status = 'active', false),
         company = coalesce(case when i.status = 'active' then i.company end, '')
    from (select p_uid as uid) x
    left join public.installers i on i.user_id = x.uid
   where p.user_id = x.uid
     and (p.installer is distinct from coalesce(i.status = 'active', false)
          or p.company is distinct from coalesce(case when i.status = 'active' then i.company end, ''));
$$;
revoke all on function private.sync_profile_installer(uuid) from public, anon, authenticated;

create or replace function public.installers_after() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  perform private.sync_profile_installer(coalesce(new.user_id, old.user_id));
  if tg_op = 'DELETE' or new.status <> 'active' then
    -- Status taken away: every customer access of this installer closes now.
    update public.shares set status = 'revoked', payload = null, code_hash = null
     where recipient_id = coalesce(new.user_id, old.user_id) and kind = 'installer'
       and status in ('pending', 'claimed', 'active');
  end if;
  return null;
end $$;
revoke all on function public.installers_after() from public, anon, authenticated;
drop trigger if exists installers_after on public.installers;
create trigger installers_after after insert or update or delete on public.installers
  for each row execute function public.installers_after();

create or replace function public.installers_touch() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
  new.updated_at := now();
  if new.status = 'revoked' and old.status is distinct from 'revoked' then new.revoked_at := now(); end if;
  if new.status = 'active' then new.revoked_at := null; end if;
  if new.public_id <> old.public_id then raise exception 'the installer ID is permanent' using errcode = '42501'; end if;
  return new;
end $$;
revoke all on function public.installers_touch() from public, anon, authenticated;
drop trigger if exists installers_touch on public.installers;
create trigger installers_touch before update on public.installers for each row execute function public.installers_touch();

-- A new profile row (first app start) picks up an existing approval.
create or replace function public.profiles_installer_init() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  new.installer := private.is_installer(new.user_id);
  new.company := coalesce((select i.company from public.installers i where i.user_id = new.user_id and i.status = 'active'), '');
  return new;
end $$;
revoke all on function public.profiles_installer_init() from public, anon, authenticated;
drop trigger if exists profiles_installer_init on public.profiles;
create trigger profiles_installer_init before insert on public.profiles for each row execute function public.profiles_installer_init();

-- Migration: self-enabled installer profiles without an approval lose the flag.
update public.profiles p set installer = false, company = ''
 where p.installer and not exists (select 1 from public.installers i where i.user_id = p.user_id and i.status = 'active');

-- Shares of kind 'installer' -----------------------------------------------------------------------
-- Insert: 'pending' as before (code invites, e-mail invites), or 'active' at once when it goes
-- straight to an approved installer with the sealed credential (the ID-based grant).
grant insert (id, recipient_id, kind, status, label, level, summary, owner_name, recipient_name, recipient_pub, payload, code_hash,
  code_expires_at) on public.shares to authenticated;
drop policy if exists "shares: owner insert" on public.shares;
create policy "shares: owner insert" on public.shares for insert to authenticated
  with check (
    (select auth.uid()) = owner_id and (
      status = 'pending'
      or (status = 'active' and kind = 'installer' and recipient_id is not null and payload is not null
          and code_hash is null and (select private.is_installer(recipient_id)))
    )
  );

-- Whatever the path, an installer share can only be open for an approved installer.
create or replace function public.shares_installer_guard() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.kind = 'installer' and new.recipient_id is not null and new.status in ('pending', 'claimed', 'active')
     and not private.is_installer(new.recipient_id) then
    raise exception 'installer profile required' using errcode = '42501';
  end if;
  if new.kind = 'installer' and new.recipient_id is not null and new.status in ('pending', 'claimed', 'active') then
    -- The customer always sees the verified name, never a typed one.
    new.recipient_name := (select coalesce(nullif(i.company, '') || ' · ', '') || i.display_name
                             from public.installers i where i.user_id = new.recipient_id);
  end if;
  return new;
end $$;
revoke all on function public.shares_installer_guard() from public, anon, authenticated;
drop trigger if exists shares_installer_guard on public.shares;
create trigger shares_installer_guard before insert or update on public.shares
  for each row execute function public.shares_installer_guard();

-- accept / claim: approval comes from public.installers now.
create or replace function private.accept_share(p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid(); s public.shares;
begin
  if uid is null then raise exception 'not signed in' using errcode = '28000'; end if;
  select * into s from public.shares where id = p_id and recipient_id = uid for update;
  if not found or s.status <> 'pending' or s.payload is null then
    raise exception 'no such invite' using errcode = 'P0002';
  end if;
  if s.kind = 'installer' and not private.is_installer(uid) then
    raise exception 'installer profile required' using errcode = '42501';
  end if;
  update public.shares set status = 'active' where id = p_id;
end $$;

create or replace function private.claim_invite(p_code_hash text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid(); s public.shares; me public.profiles;
begin
  if uid is null then raise exception 'not signed in' using errcode = '28000'; end if;
  select * into me from public.profiles where user_id = uid;
  if not found or me.share_pub is null then
    raise exception 'profile key missing' using errcode = 'P0001';
  end if;
  select * into s from public.shares where code_hash = p_code_hash for update;
  if not found or s.status <> 'pending' or s.recipient_id is not null
     or (s.code_expires_at is not null and s.code_expires_at < now()) then
    raise exception 'invalid or expired code' using errcode = 'P0002';
  end if;
  if s.owner_id = uid then raise exception 'own invite' using errcode = '42501'; end if;
  if s.kind = 'installer' and not private.is_installer(uid) then
    raise exception 'installer profile required' using errcode = '42501';
  end if;
  update public.shares
     set recipient_id = uid, recipient_pub = me.share_pub,
         recipient_name = me.display_name,
         status = 'claimed', code_hash = null
   where id = s.id;
  return s.id;
end $$;

-- Looking up an installer by ID (customer side) ------------------------------------------------------
create or replace function private.normalize_installer_id(p text) returns text
language sql immutable set search_path = '' as $$
  select case when length(x) = 6 then 'MPL-' || substr(x, 1, 3) || '-' || substr(x, 4, 3) end
    from (select regexp_replace(regexp_replace(upper(coalesce(p, '')), '[^A-Z0-9]', '', 'g'), '^MPL', '') as x) t $$;
revoke all on function private.normalize_installer_id(text) from public, anon;
grant execute on function private.normalize_installer_id(text) to authenticated;

create or replace function public.find_installer(p_public_id text)
returns table (user_id uuid, public_id text, display_name text, company text, share_pub text)
language sql stable security definer set search_path = '' as $$
  select i.user_id, i.public_id, i.display_name, i.company, p.share_pub
    from public.installers i
    join public.profiles p on p.user_id = i.user_id
   where (select auth.uid()) is not null
     and i.status = 'active'
     and i.public_id = private.normalize_installer_id(p_public_id)
     and i.user_id <> (select auth.uid())
     and p.share_pub is not null
   limit 1;
$$;
revoke all on function public.find_installer(text) from public, anon;
grant execute on function public.find_installer(text) to authenticated;

-- The home bridge's per-request check (no session needed: the share id is a random UUID and the
-- answer is one word). 'active' = serve, 'pending' = not yet, 'gone' = drop it.
create or replace function public.share_access(p_share uuid) returns text
language sql stable security definer set search_path = '' as $$
  select coalesce((
    select case
      when s.status = 'active' and (s.kind <> 'installer' or private.is_installer(s.recipient_id)) then 'active'
      when s.status in ('pending', 'claimed') and (s.kind <> 'installer' or s.recipient_id is null or private.is_installer(s.recipient_id)) then 'pending'
      else 'gone' end
    from public.shares s where s.id = p_share), 'gone');
$$;
revoke all on function public.share_access(uuid) from public;
grant execute on function public.share_access(uuid) to anon, authenticated;

-- Admin functions (Molaplan admins only) -------------------------------------------------------------
create or replace function private.require_admin() returns void
language plpgsql stable security definer set search_path = '' as $$
begin
  if not private.is_shop_admin() then raise exception 'admin only' using errcode = '42501'; end if;
end $$;
revoke all on function private.require_admin() from public, anon;
grant execute on function private.require_admin() to authenticated;

create or replace function private.new_installer_id() returns text
language plpgsql volatile set search_path = '' as $$
declare a text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; b bytea; s text; i int; n int := 0;
begin
  loop
    b := decode(replace(gen_random_uuid()::text, '-', ''), 'hex');
    s := '';
    for i in 0..5 loop
      s := s || substr(a, 1 + (get_byte(b, i) % 31), 1);
    end loop;
    s := 'MPL-' || substr(s, 1, 3) || '-' || substr(s, 4, 3);
    exit when not exists (select 1 from public.installers where public_id = s);
    n := n + 1;
    if n > 50 then raise exception 'could not make an installer ID'; end if;
  end loop;
  return s;
end $$;
revoke all on function private.new_installer_id() from public, anon, authenticated;

create or replace function public.admin_find_user(p_email text)
returns table (user_id uuid, email text, display_name text, has_app boolean, installer_status text, public_id text)
language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.require_admin();
  return query
    select u.id, lower(u.email)::text, coalesce(p.display_name, ''), p.share_pub is not null, i.status, i.public_id
      from auth.users u
      left join public.profiles p on p.user_id = u.id
      left join public.installers i on i.user_id = u.id
     where lower(u.email) like '%' || lower(btrim(coalesce(p_email, ''))) || '%'
       and length(btrim(coalesce(p_email, ''))) >= 3
     order by lower(u.email)
     limit 20;
end $$;
revoke all on function public.admin_find_user(text) from public, anon;
grant execute on function public.admin_find_user(text) to authenticated;

create or replace function public.admin_list_installers()
returns table (user_id uuid, email text, public_id text, display_name text, company text, note text, status text,
               granted_by text, granted_at timestamptz, revoked_at timestamptz, customers bigint)
language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.require_admin();
  return query
    select i.user_id, lower(u.email)::text, i.public_id, i.display_name, i.company, i.note, i.status, i.granted_by,
           i.granted_at, i.revoked_at,
           (select count(*) from public.shares s where s.recipient_id = i.user_id and s.kind = 'installer' and s.status = 'active')
      from public.installers i join auth.users u on u.id = i.user_id
     order by i.status, i.display_name;
end $$;
revoke all on function public.admin_list_installers() from public, anon;
grant execute on function public.admin_list_installers() to authenticated;

-- Grants (or re-grants / edits) by account e-mail. The installer ID is made once and never changes.
create or replace function public.admin_grant_installer(p_email text, p_display_name text, p_company text default '', p_note text default '')
returns public.installers
language plpgsql security definer set search_path = '' as $$
declare uid uuid; r public.installers;
begin
  perform private.require_admin();
  select u.id into uid from auth.users u where lower(u.email) = lower(btrim(coalesce(p_email, '')));
  if uid is null then raise exception 'no Molaplan account with that e-mail' using errcode = 'P0002'; end if;
  insert into public.installers as i (user_id, public_id, display_name, company, note, status, granted_by)
  values (uid, private.new_installer_id(), btrim(p_display_name), btrim(coalesce(p_company, '')), coalesce(p_note, ''), 'active',
          private.jwt_email())
  on conflict (user_id) do update
     set display_name = excluded.display_name, company = excluded.company, note = excluded.note,
         status = 'active', granted_by = excluded.granted_by,
         granted_at = case when i.status = 'active' then i.granted_at else now() end
  returning * into r;
  update public.installer_applications set status = 'approved', decided_at = now() where user_id = uid and status = 'new';
  return r;
end $$;
revoke all on function public.admin_grant_installer(text, text, text, text) from public, anon;
grant execute on function public.admin_grant_installer(text, text, text, text) to authenticated;

create or replace function public.admin_revoke_installer(p_user uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_admin();
  update public.installers set status = 'revoked' where user_id = p_user and status = 'active';
  if not found then raise exception 'not an active installer' using errcode = 'P0002'; end if;
end $$;
revoke all on function public.admin_revoke_installer(uuid) from public, anon;
grant execute on function public.admin_revoke_installer(uuid) to authenticated;

create or replace function public.admin_list_installer_applications()
returns table (id uuid, user_id uuid, email text, display_name text, company text, message text, status text, created_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.require_admin();
  return query
    select a.id, a.user_id, a.email, a.display_name, a.company, a.message, a.status, a.created_at
      from public.installer_applications a
     order by (a.status = 'new') desc, a.created_at desc
     limit 200;
end $$;
revoke all on function public.admin_list_installer_applications() from public, anon;
grant execute on function public.admin_list_installer_applications() to authenticated;

create or replace function public.admin_decline_installer_application(p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_admin();
  update public.installer_applications set status = 'declined', decided_at = now() where id = p_id and status = 'new';
  if not found then raise exception 'no open application' using errcode = 'P0002'; end if;
end $$;
revoke all on function public.admin_decline_installer_application(uuid) from public, anon;
grant execute on function public.admin_decline_installer_application(uuid) to authenticated;

-- Keep profiles.installer in step for rows that already exist (re-run safe).
do $$ declare r record; begin
  for r in select user_id from public.installers loop perform private.sync_profile_installer(r.user_id); end loop;
end $$;
