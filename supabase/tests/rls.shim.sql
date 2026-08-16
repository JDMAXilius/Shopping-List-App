-- TEST SCAFFOLDING ONLY — never applied to a real Supabase project.
-- Recreates just enough of the Supabase runtime on vanilla Postgres so that
-- 0001_schema.sql + 0002_rls.sql apply and rls.test.sql runs (see its header):
-- the three client roles, the auth schema with users + uid(), the extensions
-- schema Supabase installs pgcrypto into, and default privileges that mirror
-- Supabase's grants (clients act through roles; RLS does the denying).
--
-- Run order, as superuser on an empty database:
--   psql -f supabase/tests/rls.shim.sql
--   psql -f supabase/migrations/0001_schema.sql
--   psql -f supabase/migrations/0002_rls.sql
--   psql -v ON_ERROR_STOP=1 -f supabase/tests/rls.test.sql

do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin bypassrls;
  end if;
end $$;

create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;
create extension if not exists dblink;  -- section 13 of the suite

create schema if not exists auth;

create table if not exists auth.users (
  id     uuid primary key,
  aud    text,
  role   text,
  email  text
);

-- Supabase's auth.uid(): the sub claim of the request's JWT, set per-session by
-- the API gateway; the tests set it with set_config('request.jwt.claims', ...).
create or replace function auth.uid() returns uuid
language sql stable
as $$
  select nullif(current_setting('request.jwt.claims', true)::jsonb ->> 'sub', '')::uuid
$$;

-- Supabase grants: clients can reach the schemas; row access is RLS's job.
grant usage on schema public, extensions, auth to anon, authenticated, service_role;
grant execute on function auth.uid() to anon, authenticated, service_role;
alter default privileges in schema public
  grant select, insert, update, delete on tables to anon, authenticated, service_role;
alter default privileges in schema public
  grant usage, select on sequences to anon, authenticated, service_role;
alter default privileges in schema public
  grant execute on functions to anon, authenticated, service_role;
