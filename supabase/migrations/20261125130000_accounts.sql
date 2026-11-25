-- Molaplan accounts: one sync row per user (config without secrets + client-side encrypted vault).
create table if not exists public.user_sync (
  user_id uuid primary key default auth.uid() references auth.users (id) on delete cascade,
  rev bigint not null default 1,
  config jsonb not null default '{}'::jsonb,
  -- {"kdf":"pbkdf2-sha256","iter":N,"salt":b64,"wrapped":b64}: account key wrapped with a key derived from the password.
  key_wrap jsonb,
  -- AES-256-GCM ciphertext (base64) of device passwords, cloud keys and home pairings. Server never sees the key.
  vault text,
  updated_at timestamptz not null default now(),
  updated_by text,
  constraint user_sync_config_size check (octet_length(config::text) < 2000000),
  constraint user_sync_vault_size check (vault is null or octet_length(vault) < 2000000)
);

alter table public.user_sync enable row level security;

revoke all on public.user_sync from anon;
grant select, insert, update, delete on public.user_sync to authenticated;

drop policy if exists "own row: select" on public.user_sync;
drop policy if exists "own row: insert" on public.user_sync;
drop policy if exists "own row: update" on public.user_sync;
drop policy if exists "own row: delete" on public.user_sync;
create policy "own row: select" on public.user_sync for select to authenticated using ((select auth.uid()) = user_id);
create policy "own row: insert" on public.user_sync for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "own row: update" on public.user_sync for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "own row: delete" on public.user_sync for delete to authenticated using ((select auth.uid()) = user_id);

-- Every update bumps the revision (clients update "where rev = <what I last saw>" to detect conflicts).
create or replace function public.user_sync_bump() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
  new.rev := old.rev + 1;
  new.updated_at := now();
  new.user_id := old.user_id;
  return new;
end $$;
drop trigger if exists user_sync_bump on public.user_sync;
create trigger user_sync_bump before update on public.user_sync for each row execute function public.user_sync_bump();

-- "Poista tili" (GDPR): deletes the caller's auth user; user_sync goes with it (on delete cascade).
create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

create or replace function private.delete_user() returns void
language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'not signed in' using errcode = '28000'; end if;
  delete from public.user_sync where user_id = uid;
  delete from auth.users where id = uid;
end $$;
revoke all on function private.delete_user() from public, anon;
grant execute on function private.delete_user() to authenticated;

create or replace function public.delete_my_account() returns void
language sql security invoker set search_path = '' as $$ select private.delete_user(); $$;
revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
