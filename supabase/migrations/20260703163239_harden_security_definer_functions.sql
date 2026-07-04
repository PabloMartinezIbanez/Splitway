-- Fix Supabase advisor warnings 0028/0029: SECURITY DEFINER functions in the
-- exposed `public` schema executable by the `anon` / `authenticated` roles.
--
-- Root cause: Postgres grants EXECUTE to PUBLIC by default on function creation,
-- and anon/authenticated inherit from PUBLIC. None of the original migrations
-- revoked that default grant.

-- 1. rls_auto_enable(): DDL event-trigger function backing the `ensure_rls`
--    event trigger (auto-enables RLS on newly created public tables). It is
--    never meant to be called via the Data API. It was applied directly on the
--    remote and never captured in a migration, so recreate it here for
--    reproducibility, ensure the event trigger exists, then revoke EXECUTE from
--    PUBLIC so anon/authenticated can no longer reach it.
create or replace function public.rls_auto_enable()
returns event_trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  cmd record;
begin
  for cmd in
    select *
    from pg_event_trigger_ddl_commands()
    where command_tag in ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      and object_type in ('table', 'partitioned table')
  loop
    if cmd.schema_name is not null
       and cmd.schema_name in ('public')
       and cmd.schema_name not in ('pg_catalog', 'information_schema')
       and cmd.schema_name not like 'pg_toast%'
       and cmd.schema_name not like 'pg_temp%' then
      begin
        execute format('alter table if exists %s enable row level security', cmd.object_identity);
        raise log 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      exception
        when others then
          raise log 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      end;
    else
      raise log 'rls_auto_enable: skip % (system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
    end if;
  end loop;
end;
$$;

do $$
begin
  if not exists (select 1 from pg_event_trigger where evtname = 'ensure_rls') then
    create event trigger ensure_rls
      on ddl_command_end
      when tag in ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      execute function public.rls_auto_enable();
  end if;
end $$;

revoke execute on function public.rls_auto_enable() from public;

-- 2. update_nickname(text): only ever mutates the caller's own profiles row,
--    which is already protected by RLS (auth.uid() = id for SELECT and UPDATE).
--    SECURITY DEFINER is unnecessary here, so switch to SECURITY INVOKER (the
--    linter only flags DEFINER functions) and drop the anon grant.
alter function public.update_nickname(text) security invoker;
revoke execute on function public.update_nickname(text) from public;
grant execute on function public.update_nickname(text) to authenticated;

-- 3. user_has_password(): must stay SECURITY DEFINER because `authenticated`
--    cannot read auth.users directly. It is scoped to auth.uid() and only
--    returns a boolean about the caller's own account. Remove the anon grant;
--    keep authenticated.
revoke execute on function public.user_has_password() from public;
grant execute on function public.user_has_password() to authenticated;

-- 4. get_user_ban_until(text): intentionally callable pre-auth by `anon` so the
--    login screen can show a useful "banned until X" message. Must stay
--    SECURITY DEFINER (reads auth.users without a session). Keep anon; remove
--    the authenticated grant (the real caller is anon). The remaining anon
--    warning is an accepted, documented trade-off.
revoke execute on function public.get_user_ban_until(text) from public;
grant execute on function public.get_user_ban_until(text) to anon;
