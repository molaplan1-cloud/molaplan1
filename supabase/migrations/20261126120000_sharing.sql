-- R215–R217 (t215u, v0.9.0): device sharing and the installer role ('Asentaja').
--
-- Nothing secret is stored in clear text here:
--  * profiles.share_pub is a PUBLIC X25519 key (the private half is derived from the account key on
--    the user's own devices).
--  * shares.payload is the bridge credential sealed to the recipient's share key (ciphertext).
--  * shares.summary only holds tile titles / view names for the lists.
--  * Invite codes are stored as a SHA-256 hash, single use, with an expiry.
-- The permission itself is enforced by the owner's home bridge on every request; these rows are the
-- invitation / acceptance / revocation workflow and the lists.

create table if not exists public.profiles (
  user_id uuid primary key default auth.uid() references auth.users (id) on delete cascade,
  display_name text not null default '' check (char_length(display_name) <= 80),
  share_pub text check (share_pub is null or share_pub ~ '^[A-Za-z0-9_-]{43}$'),
  installer boolean not null default false,
  company text not null default '' check (char_length(company) <= 120),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
revoke all on public.profiles from anon, authenticated;
grant select, insert, delete on public.profiles to authenticated;
grant update (display_name, share_pub, installer, company) on public.profiles to authenticated;

drop policy if exists "profiles: own select" on public.profiles;
drop policy if exists "profiles: own insert" on public.profiles;
drop policy if exists "profiles: own update" on public.profiles;
drop policy if exists "profiles: own delete" on public.profiles;
create policy "profiles: own select" on public.profiles for select to authenticated using ((select auth.uid()) = user_id);
create policy "profiles: own insert" on public.profiles for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "profiles: own update" on public.profiles for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "profiles: own delete" on public.profiles for delete to authenticated using ((select auth.uid()) = user_id);

create table if not exists public.shares (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  recipient_id uuid references auth.users (id) on delete cascade,
  kind text not null default 'share' check (kind in ('share', 'installer')),
  -- pending: waiting for the recipient (email invite) or for a code to be used
  -- claimed: a code was used, the owner's app now seals the credential
  -- active: in use · declined: the recipient said no / left · revoked: the owner took it back
  status text not null default 'pending' check (status in ('pending', 'claimed', 'active', 'declined', 'revoked')),
  label text not null default '' check (char_length(label) <= 120),
  level text not null default 'limited' check (level in ('full', 'limited')),
  summary jsonb not null default '{}'::jsonb check (octet_length(summary::text) < 20000),
  owner_name text not null default '' check (char_length(owner_name) <= 120),
  recipient_name text not null default '' check (char_length(recipient_name) <= 120),
  recipient_pub text check (recipient_pub is null or recipient_pub ~ '^[A-Za-z0-9_-]{43}$'),
  payload text check (payload is null or octet_length(payload) < 20000),
  code_hash text check (code_hash is null or code_hash ~ '^[0-9a-f]{64}$'),
  code_expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint shares_not_self check (recipient_id is null or recipient_id <> owner_id),
  -- either addressed to a user, or an open code invite
  constraint shares_target check (recipient_id is not null or code_hash is not null or status in ('revoked', 'declined'))
);

create index if not exists shares_owner_idx on public.shares (owner_id);
create index if not exists shares_recipient_idx on public.shares (recipient_id) where recipient_id is not null;
create unique index if not exists shares_code_idx on public.shares (code_hash) where code_hash is not null;

alter table public.shares enable row level security;
revoke all on public.shares from anon, authenticated;
grant select, delete on public.shares to authenticated;
grant insert (id, recipient_id, kind, label, level, summary, owner_name, recipient_name, recipient_pub, payload, code_hash,
  code_expires_at) on public.shares to authenticated;
-- The owner may only change these; who the share is for is fixed (a claim goes through claim_invite).
grant update (status, label, level, summary, owner_name, payload) on public.shares to authenticated;

drop policy if exists "shares: owner or recipient select" on public.shares;
drop policy if exists "shares: owner insert" on public.shares;
drop policy if exists "shares: owner update" on public.shares;
drop policy if exists "shares: owner delete" on public.shares;
create policy "shares: owner or recipient select" on public.shares for select to authenticated
  using ((select auth.uid()) = owner_id or (select auth.uid()) = recipient_id);
create policy "shares: owner insert" on public.shares for insert to authenticated
  with check ((select auth.uid()) = owner_id and status = 'pending');
create policy "shares: owner update" on public.shares for update to authenticated
  using ((select auth.uid()) = owner_id) with check ((select auth.uid()) = owner_id);
create policy "shares: owner delete" on public.shares for delete to authenticated using ((select auth.uid()) = owner_id);

create or replace function public.touch_updated_at() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end $$;

drop trigger if exists profiles_touch on public.profiles;
create trigger profiles_touch before update on public.profiles for each row execute function public.touch_updated_at();

-- The owner's own status changes (the recipient's go through the functions below, which run as the
-- table owner). The owner can never accept on the recipient's behalf.
create or replace function public.shares_guard() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
  if current_user <> 'authenticated' then
    new.updated_at := now();
    return new;
  end if;
  if old.status in ('revoked', 'declined') and new is distinct from old then
    raise exception 'a closed share cannot be changed' using errcode = '42501';
  end if;
  new.updated_at := now();
  if new.status <> old.status then
    if not (
      (old.status = 'pending' and new.status = 'revoked') or
      (old.status = 'claimed' and new.status in ('active', 'revoked')) or
      (old.status = 'active' and new.status = 'revoked')
    ) then
      raise exception 'share status % -> % not allowed', old.status, new.status using errcode = '42501';
    end if;
    if new.status = 'active' and new.payload is null then
      raise exception 'an active share needs its sealed credential' using errcode = '23514';
    end if;
  end if;
  if new.status = 'revoked' then
    new.payload := null;
    new.code_hash := null;
  end if;
  return new;
end $$;

drop trigger if exists shares_guard on public.shares;
create trigger shares_guard before update on public.shares for each row execute function public.shares_guard();

-- ---------------------------------------------------------------- functions for the recipient

create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

-- Looks up a Molaplan user by exact e-mail for an invite: only the public share key and name.
create or replace function private.find_share_recipient(p_email text)
returns table (user_id uuid, display_name text, share_pub text, installer boolean)
language sql stable security definer set search_path = '' as $$
  select p.user_id, p.display_name, p.share_pub, p.installer
  from auth.users u
  join public.profiles p on p.user_id = u.id
  where (select auth.uid()) is not null
    and lower(u.email) = lower(trim(p_email))
    and u.id <> (select auth.uid())
    and p.share_pub is not null
  limit 1;
$$;

create or replace function private.accept_share(p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid(); s public.shares;
begin
  if uid is null then raise exception 'not signed in' using errcode = '28000'; end if;
  select * into s from public.shares where id = p_id and recipient_id = uid for update;
  if not found or s.status <> 'pending' or s.payload is null then
    raise exception 'no such invite' using errcode = 'P0002';
  end if;
  if s.kind = 'installer' and not exists (select 1 from public.profiles where user_id = uid and installer) then
    raise exception 'installer profile required' using errcode = '42501';
  end if;
  update public.shares set status = 'active' where id = p_id;
end $$;

create or replace function private.leave_share(p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'not signed in' using errcode = '28000'; end if;
  update public.shares set status = 'declined', payload = null, code_hash = null
  where id = p_id and recipient_id = uid and status in ('pending', 'claimed', 'active');
  if not found then raise exception 'no such share' using errcode = 'P0002'; end if;
end $$;

-- Uses an invite code (the app sends its SHA-256, never the code). Single use, expires.
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
  if s.kind = 'installer' and not me.installer then
    raise exception 'installer profile required' using errcode = '42501';
  end if;
  update public.shares
     set recipient_id = uid, recipient_pub = me.share_pub,
         recipient_name = coalesce(nullif(me.company, ''), me.display_name),
         status = 'claimed', code_hash = null
   where id = s.id;
  return s.id;
end $$;

revoke all on function private.find_share_recipient(text) from public, anon;
revoke all on function private.accept_share(uuid) from public, anon;
revoke all on function private.leave_share(uuid) from public, anon;
revoke all on function private.claim_invite(text) from public, anon;
grant execute on function private.find_share_recipient(text) to authenticated;
grant execute on function private.accept_share(uuid) to authenticated;
grant execute on function private.leave_share(uuid) to authenticated;
grant execute on function private.claim_invite(text) to authenticated;

create or replace function public.find_share_recipient(p_email text)
returns table (user_id uuid, display_name text, share_pub text, installer boolean)
language sql stable security invoker set search_path = '' as $$ select * from private.find_share_recipient(p_email); $$;
create or replace function public.accept_share(p_id uuid) returns void
language sql security invoker set search_path = '' as $$ select private.accept_share(p_id); $$;
create or replace function public.leave_share(p_id uuid) returns void
language sql security invoker set search_path = '' as $$ select private.leave_share(p_id); $$;
create or replace function public.claim_invite(p_code_hash text) returns uuid
language sql security invoker set search_path = '' as $$ select private.claim_invite(p_code_hash); $$;

revoke all on function public.find_share_recipient(text) from public, anon;
revoke all on function public.accept_share(uuid) from public, anon;
revoke all on function public.leave_share(uuid) from public, anon;
revoke all on function public.claim_invite(text) from public, anon;
revoke all on function public.touch_updated_at() from public, anon, authenticated;
revoke all on function public.shares_guard() from public, anon, authenticated;
grant execute on function public.find_share_recipient(text) to authenticated;
grant execute on function public.accept_share(uuid) to authenticated;
grant execute on function public.leave_share(uuid) to authenticated;
grant execute on function public.claim_invite(text) to authenticated;
