-- RLS attack tests: kitchen A vs kitchen B, proven not assumed.
-- Run against a local Supabase stack with migrations applied:
--   supabase start && supabase db reset
--   psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" \
--        -v ON_ERROR_STOP=1 -f supabase/tests/rls.test.sql
-- Every check is a plpgsql ASSERT; the first failure aborts. Everything rolls back.
-- Requires the Supabase auth schema + roles (anon/authenticated) — not vanilla postgres.

begin;

-- Fixtures: three users. A owns a kitchen; B is the attacker who later joins; C joins later still.
insert into auth.users (id, aud, role, email) values
  ('00000000-0000-0000-0000-00000000000a', 'authenticated', 'authenticated', 'a@test.local'),
  ('00000000-0000-0000-0000-00000000000b', 'authenticated', 'authenticated', 'b@test.local'),
  ('00000000-0000-0000-0000-00000000000c', 'authenticated', 'authenticated', 'c@test.local');

insert into entitlement (user_id, is_plus, scans_used)
values ('00000000-0000-0000-0000-00000000000a', true, 0);

------------------------------------------------------------------------------
-- 1. A creates a kitchen via create_kitchen, invites, writes ops; push is idempotent.
------------------------------------------------------------------------------
do $$
declare kid uuid; n int;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims',
    '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);

  kid := public.create_kitchen('Kitchen A');
  perform set_config('test.kitchen_a', kid::text, true);

  insert into invite (kitchen_id, token) values (kid, 'tok-a-1');

  insert into op (id, kitchen_id, device_id, clock, wall_clock, type, payload)
  values ('11111111-1111-1111-1111-111111111111', kid,
          '22222222-2222-2222-2222-222222222222', 1, 1723800000000, 'add',
          '{"name":"milk"}'::jsonb);
  -- crash-before-mark re-delivery: same id must be a silent no-op
  insert into op (id, kitchen_id, device_id, clock, wall_clock, type, payload)
  values ('11111111-1111-1111-1111-111111111111', kid,
          '22222222-2222-2222-2222-222222222222', 1, 1723800000000, 'add',
          '{"name":"milk"}'::jsonb)
  on conflict (id) do nothing;

  select count(*) into n from op where kitchen_id = kid;
  assert n = 1, 'push is idempotent on op id';
  select count(*) into n from kitchen where id = kid;
  assert n = 1, 'A sees own kitchen';
  select count(*) into n from member where kitchen_id = kid and user_id = auth.uid() and role = 'owner';
  assert n = 1, 'create_kitchen wrote the owner member row atomically';
  raise notice 'ok 1: A creates kitchen + invite + op; push idempotent';
end $$;
reset role;

------------------------------------------------------------------------------
-- 2. Append-only: even the owner can neither UPDATE nor DELETE ops.
------------------------------------------------------------------------------
do $$
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims',
    '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);
  begin
    update op set clock = 99 where id = '11111111-1111-1111-1111-111111111111';
    raise exception 'op UPDATE must be denied for members';
  exception when insufficient_privilege then null;
  end;
  begin
    delete from op where id = '11111111-1111-1111-1111-111111111111';
    raise exception 'op DELETE must be denied for members';
  exception when insufficient_privilege then null;
  end;
  raise notice 'ok 2: op log is append-only even for members';
end $$;
reset role;

------------------------------------------------------------------------------
-- 3. THE attack: B (authenticated, not a member) reads and writes kitchen A. All must fail.
------------------------------------------------------------------------------
do $$
declare ka uuid := current_setting('test.kitchen_a')::uuid; n int;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims',
    '{"sub":"00000000-0000-0000-0000-00000000000b","role":"authenticated"}', true);

  select count(*) into n from kitchen where id = ka;
  assert n = 0, 'B must not see kitchen A';
  select count(*) into n from member where kitchen_id = ka;
  assert n = 0, 'B must not see kitchen A members';
  select count(*) into n from invite where kitchen_id = ka;
  assert n = 0, 'B must not see kitchen A invites';
  select count(*) into n from op where kitchen_id = ka;
  assert n = 0, 'B must not see kitchen A ops';

  begin
    insert into op (id, kitchen_id, device_id, clock, wall_clock, type, payload)
    values (gen_random_uuid(), ka, gen_random_uuid(), 1, 1, 'add', '{}'::jsonb);
    raise exception 'B must not INSERT an op into kitchen A';
  exception when insufficient_privilege then null;
  end;

  begin
    insert into member (kitchen_id, user_id, role) values (ka, auth.uid(), 'owner');
    raise exception 'B must not INSERT a member row directly';
  exception when insufficient_privilege then null;
  end;

  -- B cannot read A's entitlement; consume_scan is service-role only
  select count(*) into n from entitlement
   where user_id = '00000000-0000-0000-0000-00000000000a';
  assert n = 0, 'B must not read A entitlement';
  begin
    perform * from public.consume_scan('00000000-0000-0000-0000-00000000000b');
    raise exception 'consume_scan must be service-role only';
  exception when insufficient_privilege then null;
  end;
  raise notice 'ok 3: B locked out of kitchen A in every direction';
end $$;
reset role;

------------------------------------------------------------------------------
-- 4. Anon cannot enumerate invites, even with the exact token; anon cannot join.
------------------------------------------------------------------------------
do $$
declare n int;
begin
  perform set_config('role', 'anon', true);
  perform set_config('request.jwt.claims', '{"role":"anon"}', true);
  select count(*) into n from invite where token = 'tok-a-1';
  assert n = 0, 'anon must not SELECT invite even by exact token';
  begin
    perform public.join_kitchen('tok-a-1');
    raise exception 'anon must not execute join_kitchen';
  exception when insufficient_privilege then null;
  end;
  raise notice 'ok 4: no anon invite path';
end $$;
reset role;

------------------------------------------------------------------------------
-- 5. B joins with the valid token; reads now succeed; B can write ops.
------------------------------------------------------------------------------
do $$
declare ka uuid := current_setting('test.kitchen_a')::uuid; kid uuid; n int;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims',
    '{"sub":"00000000-0000-0000-0000-00000000000b","role":"authenticated"}', true);
  kid := public.join_kitchen('tok-a-1');
  assert kid = ka, 'join_kitchen returns the kitchen id';
  select count(*) into n from kitchen where id = ka;
  assert n = 1, 'B sees kitchen A after joining';
  select count(*) into n from op where kitchen_id = ka;
  assert n = 1, 'B pulls kitchen A ops after joining';
  insert into op (id, kitchen_id, device_id, clock, wall_clock, type, payload)
  values ('33333333-3333-3333-3333-333333333333', ka,
          '44444444-4444-4444-4444-444444444444', 2, 1723800001000, 'check',
          '"11111111-0000-0000-0000-000000000000"'::jsonb);
  select count(*) into n from member where kitchen_id = ka and user_id = auth.uid() and role = 'guest';
  assert n = 1, 'B joined as guest';
  raise notice 'ok 5: valid token joins B as guest with full membership';
end $$;
reset role;

------------------------------------------------------------------------------
-- 6. A new invite revokes the old token's future joins; unknown tokens fail identically.
------------------------------------------------------------------------------
do $$
declare n int;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims',
    '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);
  insert into invite (kitchen_id, token)
  values (current_setting('test.kitchen_a')::uuid, 'tok-a-2');
  select count(*) into n from invite where token = 'tok-a-1' and revoked_at is not null;
  assert n = 1, 'creating a new invite revoked the prior token';
  raise notice 'ok 6a: new invite revokes prior token';
end $$;
reset role;

do $$
declare kid uuid;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims',
    '{"sub":"00000000-0000-0000-0000-00000000000c","role":"authenticated"}', true);
  begin
    kid := public.join_kitchen('tok-a-1');
    raise exception 'revoked token must not join';
  exception when no_data_found then null;
  end;
  begin
    kid := public.join_kitchen('tok-guessed');
    raise exception 'unknown token must not join';
  exception when no_data_found then null;  -- same error as revoked: no oracle
  end;
  kid := public.join_kitchen('tok-a-2');
  assert kid = current_setting('test.kitchen_a')::uuid, 'current token joins C';
  raise notice 'ok 6b: revoked/unknown tokens 404 identically; live token joins';
end $$;
reset role;

------------------------------------------------------------------------------
-- 7. Membership lifecycle: guests cannot evict the owner; owner removes guests; leaving works.
------------------------------------------------------------------------------
do $$
declare ka uuid := current_setting('test.kitchen_a')::uuid; n int;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims',
    '{"sub":"00000000-0000-0000-0000-00000000000b","role":"authenticated"}', true);
  delete from member where kitchen_id = ka
    and user_id = '00000000-0000-0000-0000-00000000000a';
  get diagnostics n = row_count;
  assert n = 0, 'guest B must not delete the owner row';

  perform set_config('request.jwt.claims',
    '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);
  delete from member where kitchen_id = ka
    and user_id = '00000000-0000-0000-0000-00000000000c';
  get diagnostics n = row_count;
  assert n = 1, 'owner A removes guest C';

  perform set_config('request.jwt.claims',
    '{"sub":"00000000-0000-0000-0000-00000000000b","role":"authenticated"}', true);
  delete from member where kitchen_id = ka and user_id = auth.uid();
  get diagnostics n = row_count;
  assert n = 1, 'B leaves (deletes own row)';
  select count(*) into n from op where kitchen_id = ka;
  assert n = 0, 'after leaving, B reads nothing';
  raise notice 'ok 7: membership lifecycle enforced';
end $$;
reset role;

------------------------------------------------------------------------------
-- 8. Isolation is symmetric: B's own kitchen is invisible to A.
------------------------------------------------------------------------------
do $$
declare kid uuid; n int;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims',
    '{"sub":"00000000-0000-0000-0000-00000000000b","role":"authenticated"}', true);
  kid := public.create_kitchen('Kitchen B');
  perform set_config('test.kitchen_b', kid::text, true);

  perform set_config('request.jwt.claims',
    '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);
  select count(*) into n from kitchen
   where id = current_setting('test.kitchen_b')::uuid;
  assert n = 0, 'A must not see kitchen B';
  select count(*) into n from entitlement;
  assert n = 1, 'A sees exactly one entitlement row';
  select count(*) into n from entitlement where user_id = auth.uid();
  assert n = 1, '...and it is A own row';
  raise notice 'ok 8: isolation is symmetric; entitlement is own-row only';
end $$;
reset role;

do $$ begin raise notice 'ALL RLS TESTS PASSED'; end $$;

rollback;
