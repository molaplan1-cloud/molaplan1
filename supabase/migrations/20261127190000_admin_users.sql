-- R530–R539 (t321u, v0.20.8): admin 'Käyttäjät' tab.
-- SECURITY DEFINER RPCs that list / inspect Molaplan accounts and let an admin ban or
-- GDPR-delete one. Every function calls private.require_admin() (private.shop_admins).
-- Only account metadata is returned: no vault, config, tokens, cameras or shared tiles.
-- Ban is auth.users.banned_until (same column the Auth admin API uses). Shop orders are
-- not deleted with the account (invoicing retention). Idempotent (safe to run twice).

create or replace function private.admin_guard_target(p_user uuid) returns void
language plpgsql stable security definer set search_path = '' as $$
begin
  if p_user is null then
    raise exception 'user not found' using errcode = 'P0002';
  end if;
  if p_user = auth.uid() then
    raise exception 'cannot modify yourself' using errcode = '42501';
  end if;
  if exists (
    select 1
      from auth.users u
      join private.shop_admins a on a.email = lower(u.email)
     where u.id = p_user
  ) then
    raise exception 'cannot modify an admin' using errcode = '42501';
  end if;
end $$;
revoke all on function private.admin_guard_target(uuid) from public, anon, authenticated;

create or replace function private.admin_revoke_sessions(p_user uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if to_regclass('auth.sessions') is not null then
    delete from auth.sessions where user_id = p_user;
  end if;
  if to_regclass('auth.refresh_tokens') is not null then
    begin
      delete from auth.refresh_tokens where user_id = p_user;
    exception when undefined_column then
      null;
    end;
  end if;
end $$;
revoke all on function private.admin_revoke_sessions(uuid) from public, anon, authenticated;

create or replace function private.admin_purge_user_files(p_user uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if p_user is null then return; end if;
  if to_regclass('storage.objects') is not null then
    delete from storage.objects
     where bucket_id = 'tile-images'
       and name like p_user::text || '/%';
  end if;
end $$;
revoke all on function private.admin_purge_user_files(uuid) from public, anon, authenticated;

-- Shared filter: escaped ILIKE on email or display name (empty query = everyone).
create or replace function public.admin_list_users(p_query text default '', p_limit int default 50, p_offset int default 0)
returns table (
  user_id uuid,
  email text,
  display_name text,
  created_at timestamptz,
  last_sign_in_at timestamptz,
  email_confirmed boolean,
  banned boolean,
  banned_until timestamptz,
  is_admin boolean,
  installer_status text,
  installer_public_id text,
  order_count bigint,
  total_count bigint
)
language plpgsql stable security definer set search_path = '' as $$
declare
  q text;
  lim int;
  off int;
begin
  perform private.require_admin();
  q := replace(replace(replace(lower(btrim(coalesce(p_query, ''))), '\', '\\'), '%', '\%'), '_', '\_');
  lim := least(greatest(coalesce(p_limit, 50), 1), 100);
  off := greatest(coalesce(p_offset, 0), 0);
  return query
    select u.id,
           lower(u.email)::text,
           coalesce(p.display_name, ''),
           u.created_at,
           u.last_sign_in_at,
           (u.email_confirmed_at is not null),
           (u.banned_until is not null and u.banned_until > now()),
           u.banned_until,
           exists (select 1 from private.shop_admins a where a.email = lower(u.email)),
           i.status,
           i.public_id,
           (select count(*) from public.shop_orders o where lower(o.email) = lower(u.email)),
           count(*) over ()
      from auth.users u
      left join public.profiles p on p.user_id = u.id
      left join public.installers i on i.user_id = u.id
     where q = ''
        or lower(u.email) like '%' || q || '%' escape '\'
        or lower(coalesce(p.display_name, '')) like '%' || q || '%' escape '\'
     order by u.created_at desc nulls last, lower(u.email)
     limit lim offset off;
end $$;
revoke all on function public.admin_list_users(text, int, int) from public, anon;
grant execute on function public.admin_list_users(text, int, int) to authenticated;

create or replace function public.admin_get_user(p_user uuid)
returns table (
  user_id uuid,
  email text,
  display_name text,
  created_at timestamptz,
  last_sign_in_at timestamptz,
  email_confirmed boolean,
  banned boolean,
  banned_until timestamptz,
  is_admin boolean,
  installer_status text,
  installer_public_id text,
  order_count bigint,
  orders jsonb
)
language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.require_admin();
  if p_user is null or not exists (select 1 from auth.users u where u.id = p_user) then
    raise exception 'user not found' using errcode = 'P0002';
  end if;
  return query
    select u.id,
           lower(u.email)::text,
           coalesce(p.display_name, ''),
           u.created_at,
           u.last_sign_in_at,
           (u.email_confirmed_at is not null),
           (u.banned_until is not null and u.banned_until > now()),
           u.banned_until,
           exists (select 1 from private.shop_admins a where a.email = lower(u.email)),
           i.status,
           i.public_id,
           (select count(*) from public.shop_orders o where lower(o.email) = lower(u.email)),
           coalesce((
             select jsonb_agg(jsonb_build_object(
                      'id', o.id,
                      'number', o.number,
                      'status', o.status,
                      'created_at', o.created_at
                    ) order by o.created_at desc)
               from public.shop_orders o
              where lower(o.email) = lower(u.email)
           ), '[]'::jsonb)
      from auth.users u
      left join public.profiles p on p.user_id = u.id
      left join public.installers i on i.user_id = u.id
     where u.id = p_user;
end $$;
revoke all on function public.admin_get_user(uuid) from public, anon;
grant execute on function public.admin_get_user(uuid) to authenticated;

-- Ban / unban. Sets auth.users.banned_until (GoTrue honours this on login / refresh)
-- and drops sessions so an existing refresh token cannot be reused.
create or replace function public.admin_set_user_banned(p_user uuid, p_banned boolean)
returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_admin();
  perform private.admin_guard_target(p_user);
  update auth.users
     set banned_until = case when p_banned then now() + interval '100 years' else null end
   where id = p_user;
  if not found then
    raise exception 'user not found' using errcode = 'P0002';
  end if;
  if p_banned then
    perform private.admin_revoke_sessions(p_user);
  end if;
end $$;
revoke all on function public.admin_set_user_banned(uuid, boolean) from public, anon;
grant execute on function public.admin_set_user_banned(uuid, boolean) to authenticated;

-- GDPR delete of another account. The caller must type the account email (checked here).
-- Reuses the same auth.users delete as private.delete_user(); cascaded rows go with it.
-- Shop orders are kept (invoicing retention). Tile-image files are removed when Storage exists.
create or replace function public.admin_delete_user(p_user uuid, p_confirm_email text)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  em text;
begin
  perform private.require_admin();
  perform private.admin_guard_target(p_user);
  select lower(u.email) into em from auth.users u where u.id = p_user;
  if em is null or em = '' then
    raise exception 'user not found' using errcode = 'P0002';
  end if;
  if lower(btrim(coalesce(p_confirm_email, ''))) is distinct from em then
    raise exception 'email confirmation does not match' using errcode = '22023';
  end if;
  perform private.admin_purge_user_files(p_user);
  perform private.admin_revoke_sessions(p_user);
  delete from public.user_sync where user_id = p_user;
  delete from auth.users where id = p_user;
end $$;
revoke all on function public.admin_delete_user(uuid, text) from public, anon;
grant execute on function public.admin_delete_user(uuid, text) to authenticated;
