-- RLS attack tests: kitchen A vs kitchen B, proven not assumed.
-- Run against a local Supabase stack with migrations applied:
--   supabase start && supabase db reset
--   psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" \
--        -v ON_ERROR_STOP=1 -f supabase/tests/rls.test.sql
-- Or on vanilla PG16: create the shim first (roles anon/authenticated/service_role,
-- Supabase default privileges, auth schema + auth.users + auth.uid() reading
-- request.jwt.claims->>'sub'), then apply 0001+0002 and run this file as superuser.
-- Every check is a plpgsql ASSERT; the first failure aborts. Everything rolls back
-- EXCEPT section 13 (dblink concurrency needs real commits; it cleans up after itself).
-- Section 13 requires the dblink extension (contrib; present on Supabase).

begin;

-- Fixtures: three users. A owns a kitchen; B is the attacker who later joins; C joins later still.
insert into auth.users (id, aud, role, email) values
  ('00000000-0000-0000-0000-00000000000a', 'authenticated', 'authenticated', 'a@test.local'),
  ('00000000-0000-0000-0000-00000000000b', 'authenticated', 'authenticated', 'b@test.local'),
  ('00000000-0000-0000-0000-00000000000c', 'authenticated', 'authenticated', 'c@test.local');

insert into entitlement (user_id, is_plus, scans_used)
values ('00000000-0000-0000-0000-00000000000a', true, 0);

------------------------------------------------------------------------------
-- 1. A creates a kitchen; invites are server-minted only; push_ops is idempotent.
------------------------------------------------------------------------------
do $$
declare kid uuid; tok text; n int;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims',
    '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);

  kid := public.create_kitchen('Kitchen A');
  perform set_config('test.kitchen_a', kid::text, true);

  -- MED-2: a member cannot INSERT an invite row directly — no client-chosen tokens.
  begin
    insert into invite (kitchen_id, token) values (kid, 'evil-client-token');
    raise exception 'member direct invite INSERT must be denied';
  exception when insufficient_privilege then null;
  end;

  tok := public.create_invite(kid);
  assert length(tok) >= 43, 'create_invite mints a 256-bit base64url token';
  assert tok !~ '[+/=]', 'token is URL-safe';
  perform set_config('test.tok1', tok, true);

  insert into op (id, kitchen_id, device_id, clock, wall_clock, type, payload)
  values ('11111111-1111-1111-1111-111111111111', kid,
          '22222222-2222-2222-2222-222222222222', 1, 1723800000000, 'add',
          '{"name":"milk"}'::jsonb);

  -- HIGH-2: crash-before-mark re-delivery via push_ops — duplicate is a counted no-op.
  n := public.push_ops(jsonb_build_array(
    jsonb_build_object('id', '11111111-1111-1111-1111-111111111111',
      'kitchen_id', kid, 'device_id', '22222222-2222-2222-2222-222222222222',
      'clock', 1, 'wall_clock', 1723800000000, 'type', 'add', 'payload', '{"name":"milk"}'::jsonb),
    jsonb_build_object('id', '11111111-1111-1111-1111-222222222222',
      'kitchen_id', kid, 'device_id', '22222222-2222-2222-2222-222222222222',
      'clock', 2, 'wall_clock', 1723800000500, 'type', 'add', 'payload', '{"name":"eggs"}'::jsonb)));
  assert n = 1, 'partial-overlap batch inserts only the new op';
  n := public.push_ops(jsonb_build_array(
    jsonb_build_object('id', '11111111-1111-1111-1111-111111111111',
      'kitchen_id', kid, 'device_id', '22222222-2222-2222-2222-222222222222',
      'clock', 1, 'wall_clock', 1723800000000, 'type', 'add', 'payload', '{"name":"milk"}'::jsonb),
    jsonb_build_object('id', '11111111-1111-1111-1111-222222222222',
      'kitchen_id', kid, 'device_id', '22222222-2222-2222-2222-222222222222',
      'clock', 2, 'wall_clock', 1723800000500, 'type', 'add', 'payload', '{"name":"eggs"}'::jsonb)));
  assert n = 0, 'identical batch re-push returns 0 and raises nothing';

  select count(*) into n from op where kitchen_id = kid;
  assert n = 2, 'push is idempotent on op id';
  select count(*) into n from kitchen where id = kid;
  assert n = 1, 'A sees own kitchen';
  select count(*) into n from member where kitchen_id = kid and user_id = auth.uid() and role = 'owner';
  assert n = 1, 'create_kitchen wrote the owner member row atomically';
  raise notice 'ok 1: A creates kitchen; server-minted invite; push_ops idempotent';
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
declare ka uuid := current_setting('test.kitchen_a')::uuid; n int; t text;
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

  -- push_ops is SECURITY INVOKER: RLS must deny B exactly like the bare insert
  begin
    n := public.push_ops(jsonb_build_array(jsonb_build_object(
      'id', gen_random_uuid(), 'kitchen_id', ka, 'device_id', gen_random_uuid(),
      'clock', 1, 'wall_clock', 1, 'type', 'add', 'payload', '{}'::jsonb)));
    raise exception 'B must not push_ops into kitchen A';
  exception when insufficient_privilege then null;
  end;

  begin
    t := public.create_invite(ka);
    raise exception 'B must not mint an invite for kitchen A';
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
-- 4. Anon cannot enumerate invites, even with the exact token; anon cannot join or mint.
------------------------------------------------------------------------------
do $$
declare n int; t text;
begin
  perform set_config('role', 'anon', true);
  perform set_config('request.jwt.claims', '{"role":"anon"}', true);
  select count(*) into n from invite where token = current_setting('test.tok1');
  assert n = 0, 'anon must not SELECT invite even by exact token';
  begin
    perform public.join_kitchen(current_setting('test.tok1'));
    raise exception 'anon must not execute join_kitchen';
  exception when insufficient_privilege then null;
  end;
  begin
    t := public.create_invite(current_setting('test.kitchen_a')::uuid);
    raise exception 'anon must not execute create_invite';
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
  kid := public.join_kitchen(current_setting('test.tok1'));
  assert kid = ka, 'join_kitchen returns the kitchen id';
  select count(*) into n from kitchen where id = ka;
  assert n = 1, 'B sees kitchen A after joining';
  select count(*) into n from op where kitchen_id = ka;
  assert n = 2, 'B pulls kitchen A ops after joining';
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
declare tok text; n int;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims',
    '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);
  tok := public.create_invite(current_setting('test.kitchen_a')::uuid);
  perform set_config('test.tok2', tok, true);
  select count(*) into n from invite
   where token = current_setting('test.tok1') and revoked_at is not null;
  assert n = 1, 'create_invite revoked the prior token';
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
    kid := public.join_kitchen(current_setting('test.tok1'));
    raise exception 'revoked token must not join';
  exception when no_data_found then null;
  end;
  begin
    kid := public.join_kitchen('tok-guessed');
    raise exception 'unknown token must not join';
  exception when no_data_found then null;  -- same error as revoked: no oracle
  end;
  kid := public.join_kitchen(current_setting('test.tok2'));
  assert kid = current_setting('test.kitchen_a')::uuid, 'current token joins C';
  raise notice 'ok 6b: revoked/unknown tokens 404 identically; live token joins';
end $$;
reset role;

------------------------------------------------------------------------------
-- 7. Membership lifecycle: guests cannot evict the owner; owner removes guests;
--    eviction revokes every live invite (the evicted token cannot walk back in);
--    the last owner cannot self-delete.
------------------------------------------------------------------------------
do $$
declare ka uuid := current_setting('test.kitchen_a')::uuid; kid uuid; n int;
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

  -- MED-1: eviction is eviction — no live invite survives a departure
  select count(*) into n from invite where kitchen_id = ka and revoked_at is null;
  assert n = 0, 'removing a member revoked every live invite';

  perform set_config('request.jwt.claims',
    '{"sub":"00000000-0000-0000-0000-00000000000c","role":"authenticated"}', true);
  begin
    kid := public.join_kitchen(current_setting('test.tok2'));
    raise exception 'evicted C must not rejoin with the pre-eviction token';
  exception when no_data_found then null;
  end;

  perform set_config('request.jwt.claims',
    '{"sub":"00000000-0000-0000-0000-00000000000b","role":"authenticated"}', true);
  delete from member where kitchen_id = ka and user_id = auth.uid();
  get diagnostics n = row_count;
  assert n = 1, 'B leaves (deletes own row)';
  select count(*) into n from op where kitchen_id = ka;
  assert n = 0, 'after leaving, B reads nothing';

  -- LOW: the last owner cannot delete themselves out of a kitchen
  perform set_config('request.jwt.claims',
    '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);
  begin
    delete from member where kitchen_id = ka and user_id = auth.uid();
    raise exception 'last owner self-delete must be blocked';
  exception when object_in_use then null;  -- 55006 'last_owner'
  end;
  select count(*) into n from member where kitchen_id = ka and role = 'owner';
  assert n = 1, 'owner row survives the blocked delete';
  raise notice 'ok 7: membership lifecycle enforced; eviction revokes tokens';
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

------------------------------------------------------------------------------
-- 9. Webhook ordering fence: stale/replayed entitlement events are no-ops.
------------------------------------------------------------------------------
do $$
declare ub uuid := '00000000-0000-0000-0000-00000000000b'; v boolean; n int;
begin
  perform set_config('role', 'service_role', true);
  perform public.apply_entitlement_event(ub, true,  '2026-08-02T00:00:00Z');
  perform public.apply_entitlement_event(ub, false, '2026-08-01T00:00:00Z');  -- stale replay
  perform set_config('role', 'none', true); reset role;
  select is_plus into v from entitlement where user_id = ub;
  assert v = true, 'stale EXPIRATION replay must not undo a newer purchase';

  perform set_config('role', 'service_role', true);
  perform public.apply_entitlement_event(ub, false, '2026-08-03T00:00:00Z');  -- genuinely newer
  perform set_config('role', 'none', true); reset role;
  select is_plus into v from entitlement where user_id = ub;
  assert v = false, 'newer event applies';
  select scans_used into n from entitlement where user_id = ub;
  assert n = 0, 'webhook path never touches scans_used';

  -- clients cannot call the webhook apply
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims',
    '{"sub":"00000000-0000-0000-0000-00000000000b","role":"authenticated"}', true);
  begin
    perform public.apply_entitlement_event(ub, true, now());
    raise exception 'apply_entitlement_event must be service-role only';
  exception when insufficient_privilege then null;
  end;
  raise notice 'ok 9: event-time fence — replays are no-ops; service-role only';
end $$;
reset role;

------------------------------------------------------------------------------
-- 10. The op sequence is not readable: last_value is a cross-kitchen volume oracle.
------------------------------------------------------------------------------
do $$
declare n bigint;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims',
    '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);
  begin
    select last_value into n from public.op_seq;
    raise exception 'op_seq SELECT must be denied for clients';
  exception when insufficient_privilege then null;
  end;
  raise notice 'ok 10: op_seq unreadable by clients (USAGE only)';
end $$;
reset role;

------------------------------------------------------------------------------
-- 11. create_kitchen caps at 20 owned kitchens.
------------------------------------------------------------------------------
do $$
declare kid uuid; i int;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims',
    '{"sub":"00000000-0000-0000-0000-00000000000d","role":"authenticated"}', true);
  for i in 1..20 loop
    kid := public.create_kitchen('K' || i);
  end loop;
  begin
    kid := public.create_kitchen('K21');
    raise exception 'the 21st owned kitchen must be rejected';
  exception when program_limit_exceeded then null;  -- 54000 'kitchen_limit'
  end;
  raise notice 'ok 11: kitchen farming capped at 20';
end $$;
reset role;

------------------------------------------------------------------------------
-- 12. Quota round-trip — the ledger scan-receipt's refund path stands on.
--     The function consumes a scan BEFORE calling Claude and refunds on every
--     failure after that point (including the new 502 for a model response that
--     violates RECEIPT_SCHEMA), and it reports `free_scan_charged` from the result.
--     So: consume+refund must be an EXACT no-op, a refused scan must never charge,
--     the refund must never mint quota, and Plus must never touch the free counter.
------------------------------------------------------------------------------
do $$
declare
  ue uuid := '00000000-0000-0000-0000-00000000000e';
  r record; n int;
begin
  perform set_config('role', 'service_role', true);

  select * into r from public.consume_scan(ue);
  assert r.allowed and not r.is_plus and r.scans_used = 1,
    'the first free scan is allowed and counted';

  -- The compensation the function issues on a 502/422 restores it exactly.
  perform public.refund_scan(ue);
  select scans_used into n from entitlement where user_id = ue;
  assert n = 0, 'consume + refund is an exact no-op — a failed parse costs no free scan';

  perform public.consume_scan(ue);
  perform public.consume_scan(ue);
  select * into r from public.consume_scan(ue);
  assert r.allowed and r.scans_used = 3, 'the third free scan is still allowed';

  -- The 402 boundary: refused WITHOUT incrementing, so a paywalled call charges nothing
  -- and needs no refund. Repeat it — a retry loop must not run the counter away either.
  select * into r from public.consume_scan(ue);
  assert not r.allowed and r.scans_used = 3, 'a refused scan does not increment';
  select * into r from public.consume_scan(ue);
  assert not r.allowed and r.scans_used = 3, 'repeated refusals still do not increment';

  -- Refund floors at zero: it compensates, it never mints scans.
  update entitlement set scans_used = 0 where user_id = ue;
  perform public.refund_scan(ue);
  select scans_used into n from entitlement where user_id = ue;
  assert n = 0, 'refund floors at zero — it can never mint free scans';

  -- Plus consumes no free quota, which is why the function reports free_scan_charged
  -- = false for a Plus caller. Corollary, accepted and not a bug: if the RevenueCat
  -- webhook flips is_plus between consume and refund, the refund no-ops — the user is
  -- Plus by then, so the free counter no longer gates them.
  update entitlement set is_plus = true, scans_used = 2 where user_id = ue;
  select * into r from public.consume_scan(ue);
  assert r.allowed and r.is_plus and r.scans_used = 2,
    'a Plus scan is allowed and does not touch the free counter';
  perform public.refund_scan(ue);
  select scans_used into n from entitlement where user_id = ue;
  assert n = 2, 'refund_scan is inert for a Plus user';

  perform set_config('role', 'none', true); reset role;

  -- Neither half of the ledger is client-callable: a user who could call refund_scan
  -- would have infinite free scans.
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims',
    '{"sub":"00000000-0000-0000-0000-00000000000e","role":"authenticated"}', true);
  begin
    perform public.refund_scan(ue);
    raise exception 'refund_scan must be service-role only';
  exception when insufficient_privilege then null;
  end;
  raise notice 'ok 12: quota round-trip exact; refusals free; refund service-role only';
end $$;
reset role;

do $$ begin raise notice 'ALL RLS TESTS PASSED (sections 1-12, rolled back)'; end $$;

rollback;

------------------------------------------------------------------------------
-- 13. HIGH-1 commit-ordered seq, proven with two REAL concurrent transactions
--     (dblink; runs outside the rollback — commits are the point — then cleans up).
--     A kitchen-mate's op insert must BLOCK until the first insert commits, so no
--     pull cursor can ever pass seq N+1 while N is still uncommitted (lost-op gap).
------------------------------------------------------------------------------
create extension if not exists dblink;
do $$
declare
  -- The host and port are asked of the running server rather than left to libpq's defaults:
  -- `dbname=` alone reaches /var/run/postgresql:5432, so on any cluster started somewhere else
  -- this whole section died with "could not establish connection" — the one section that proves
  -- commit-ordered seq, skipped by an environment detail. `unix_socket_directories` can hold a
  -- list; the first entry is the one libpq would have used.
  conn text := format('dbname=%s host=%s port=%s', current_database(),
                      split_part(current_setting('unix_socket_directories'), ',', 1),
                      current_setting('port'));
  kt uuid := 'eeeeeeee-0000-0000-0000-000000000001';
  s1 bigint; s2 bigint; n int;
begin
  perform dblink_exec(conn,
    format('insert into kitchen (id, name) values (%L, ''seq-race-test'')', kt));
  perform dblink_connect('c1', conn);
  perform dblink_connect('c2', conn);

  -- c1: open transaction, insert op, DO NOT commit — holds the per-kitchen lock
  perform dblink_exec('c1', format(
    'begin; insert into op (id, kitchen_id, device_id, clock, wall_clock, type, payload) '
    || 'values (''eeeeeeee-0000-0000-0000-0000000000a1'', %L, gen_random_uuid(), 1, 1, ''add'', ''{}'')', kt));

  -- c2: same kitchen, async — must block on the advisory lock
  perform dblink_send_query('c2', format(
    'insert into op (id, kitchen_id, device_id, clock, wall_clock, type, payload) '
    || 'values (''eeeeeeee-0000-0000-0000-0000000000a2'', %L, gen_random_uuid(), 2, 2, ''add'', ''{}'')', kt));
  perform pg_sleep(0.5);
  assert dblink_is_busy('c2') = 1,
    'second kitchen-mate insert must BLOCK until the first commits (critic repro)';

  perform dblink_exec('c1', 'commit');
  for n in 1..100 loop
    exit when dblink_is_busy('c2') = 0;
    perform pg_sleep(0.05);
  end loop;
  assert dblink_is_busy('c2') = 0, 'blocked insert proceeds once the lock holder commits';
  perform t.r from dblink_get_result('c2') as t(r text);
  perform t.r from dblink_get_result('c2') as t(r text);  -- drain

  select seq into s1 from op where id = 'eeeeeeee-0000-0000-0000-0000000000a1';
  select seq into s2 from op where id = 'eeeeeeee-0000-0000-0000-0000000000a2';
  assert s1 < s2, 'seq order matches commit order — the cursor can never skip an op';

  perform dblink_disconnect('c1');
  perform dblink_disconnect('c2');
  perform dblink_exec(conn, format('delete from op where kitchen_id = %L', kt));
  perform dblink_exec(conn, format('delete from kitchen where id = %L', kt));
  raise notice 'ok 13: seq is commit-ordered — concurrent kitchen-mate insert blocked';
end $$;

-- ---------------------------------------------------------------------------
-- 14. An invite is server-minted and server-revoked. A member cannot write one.
--     Both halves were reachable before: revoked_at back to null resurrected every
--     link the owner had killed, and a chosen token is the guessable capability
--     this schema exists to prevent.
--
--     This section runs AFTER section 13's rollback, so it carries its own
--     transaction and its own fixtures — the users at the top of this file are
--     long gone by here. (It was written assuming otherwise, and assuming an
--     `owner_a()` helper that does not exist, so it aborted in its declare block
--     and asserted NOTHING. Never trust a section that only ever ran after an
--     earlier one had already failed.)
-- ---------------------------------------------------------------------------
begin;

insert into auth.users (id, aud, role, email) values
  ('00000000-0000-0000-0000-0000000000e1', 'authenticated', 'authenticated', 'own-n@test.local'),
  ('00000000-0000-0000-0000-0000000000e2', 'authenticated', 'authenticated', 'gst-n@test.local');

do $$
declare
  kid uuid;
  tok text;
  owner_n uuid := '00000000-0000-0000-0000-0000000000e1';
  guest_n uuid := '00000000-0000-0000-0000-0000000000e2';
  n int;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims',
    json_build_object('sub', owner_n, 'role', 'authenticated')::text, true);
  kid := public.create_kitchen('Kitchen N');
  tok := public.create_invite(kid);

  perform set_config('request.jwt.claims',
    json_build_object('sub', guest_n, 'role', 'authenticated')::text, true);
  perform public.join_kitchen(tok);

  -- The owner kills the link the way the app does: a new one revokes the prior.
  perform set_config('request.jwt.claims',
    json_build_object('sub', owner_n, 'role', 'authenticated')::text, true);
  perform public.create_invite(kid);
  select count(*) into n from invite where kitchen_id = kid and revoked_at is null;
  assert n = 1, 'exactly one live token after a new link';

  -- Now the guest tries to undo that, and to name a token of their own. UPDATE is
  -- revoked outright, so the privilege check fires before any row is even matched.
  perform set_config('request.jwt.claims',
    json_build_object('sub', guest_n, 'role', 'authenticated')::text, true);
  begin
    update invite set revoked_at = null where kitchen_id = kid;
    raise exception 'a member resurrected a revoked invite';
  exception when insufficient_privilege then null;
  end;
  begin
    update invite set token = 'guest-chosen-000' where kitchen_id = kid;
    raise exception 'a member chose an invite token';
  exception when insufficient_privilege then null;
  end;

  -- And the owner cannot either: revocation is the server's job, not a member's.
  perform set_config('request.jwt.claims',
    json_build_object('sub', owner_n, 'role', 'authenticated')::text, true);
  begin
    update invite set revoked_at = null where kitchen_id = kid;
    raise exception 'the owner resurrected a revoked invite';
  exception when insufficient_privilege then null;
  end;
  select count(*) into n from invite where kitchen_id = kid and revoked_at is null;
  assert n = 1, 'still exactly one live token';
  raise notice 'ok 14: invite is server-minted and server-revoked';
end $$;
reset role;

rollback;

-- ---------------------------------------------------------------------------
-- 15-20. ACCOUNT DELETION (0003_delete_account.sql).
--     DECISIONS.md → "Deleting an account" is the ruling; these sections are the
--     proof that the SQL implements it and that it cannot be turned on anyone else.
--     Same shape as 14: each section is its own transaction with its own fixtures
--     (the users at the top of this file are long gone by here), each ends with
--     `reset role`, and every claim is an assert rather than a notice.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- 15. Last one out takes the lights — and takes NOTHING of anybody else's.
--     A solo kitchen goes with its ops and its invites (the ordered delete that
--     op.kitchen_id's missing ON DELETE CASCADE forces), entitlement and scan_audit
--     go, and an unrelated user's identical set of rows is untouched by the same call.
-- ---------------------------------------------------------------------------
begin;

insert into auth.users (id, aud, role, email) values
  ('00000000-0000-0000-0000-0000000000f1', 'authenticated', 'authenticated', 'solo@test.local'),
  ('00000000-0000-0000-0000-0000000000f2', 'authenticated', 'authenticated', 'bystd@test.local');

do $$
declare
  solo  uuid := '00000000-0000-0000-0000-0000000000f1';
  other uuid := '00000000-0000-0000-0000-0000000000f2';
  k_solo uuid; k_other uuid; res jsonb; n int;
begin
  -- The bystander's kitchen exists BEFORE the deletion, so every assertion about it
  -- afterwards is about data the delete had every opportunity to take.
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims',
    json_build_object('sub', other, 'role', 'authenticated')::text, true);
  k_other := public.create_kitchen('Kitchen Bystander');
  perform public.create_invite(k_other);
  insert into op (id, kitchen_id, device_id, clock, wall_clock, type, payload)
  values ('f2f2f2f2-0000-0000-0000-000000000001', k_other,
          'dddddddd-0000-0000-0000-000000000002', 1, 1723800000000, 'add', '{"name":"rice"}');

  perform set_config('request.jwt.claims',
    json_build_object('sub', solo, 'role', 'authenticated')::text, true);
  k_solo := public.create_kitchen('Kitchen Solo');
  perform public.create_invite(k_solo);
  insert into op (id, kitchen_id, device_id, clock, wall_clock, type, payload)
  values ('f1f1f1f1-0000-0000-0000-000000000001', k_solo,
          'dddddddd-0000-0000-0000-000000000001', 1, 1723800000000, 'add', '{"name":"milk"}'),
         ('f1f1f1f1-0000-0000-0000-000000000002', k_solo,
          'dddddddd-0000-0000-0000-000000000001', 2, 1723800000500, 'add', '{"name":"eggs"}');

  -- entitlement and scan_audit are service-role territory: seed them as the server does.
  perform set_config('role', 'none', true); reset role;
  insert into entitlement (user_id, is_plus, scans_used) values (solo, true, 2), (other, false, 1);
  insert into scan_audit (user_id) values (solo), (solo), (other);

  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims',
    json_build_object('sub', solo, 'role', 'authenticated')::text, true);
  res := public.delete_account();
  perform set_config('role', 'none', true); reset role;

  -- What it says it did
  assert (res->>'kitchens_deleted')::int = 1, 'the solo kitchen is reported deleted';
  assert (res->>'kitchens_kept')::int = 0, 'no kitchen was kept';
  assert (res->>'owners_promoted')::int = 0, 'nobody was promoted — there was nobody left';
  assert (res->>'ops_deleted')::int = 2, 'both ops of the dead kitchen are reported deleted';
  assert (res->>'member_rows_deleted')::int = 1, 'one membership reported deleted';
  assert (res->>'entitlement_deleted')::boolean, 'the entitlement row is reported deleted';
  assert (res->>'scan_audit_rows_deleted')::int = 2, 'both scan_audit rows reported deleted';

  -- What actually happened
  select count(*) into n from kitchen where id = k_solo;
  assert n = 0, 'the solo kitchen itself is gone';
  select count(*) into n from op where kitchen_id = k_solo;
  assert n = 0, 'the ops of a kitchen nobody is left in are gone (ordered delete: op has no cascade)';
  select count(*) into n from invite where kitchen_id = k_solo;
  assert n = 0, 'the invites of the dead kitchen are gone — no capability URL outlives it';
  select count(*) into n from member where user_id = solo;
  assert n = 0, 'the caller holds no membership anywhere';
  select count(*) into n from entitlement where user_id = solo;
  assert n = 0, 'the entitlement row is gone';
  select count(*) into n from scan_audit where user_id = solo;
  assert n = 0, 'scan_audit is gone — the one table holding a user_id beside a timestamp';

  -- auth.users: the flag is row_count, never optimism. This equality holds on a platform
  -- where the definer function may delete auth.users AND on one where it may not.
  assert (not exists (select 1 from auth.users where id = solo))
         = (res->>'auth_user_deleted')::boolean,
    'auth_user_deleted reports whether the row actually went, not that we tried';
  -- The shim owns auth.users, so the in-transaction branch is the one exercised here. A
  -- false on a locked-down platform is not a bug in this function: it is the instruction
  -- to finish through the Admin API, which the delete-account edge function always does.
  assert (res->>'auth_user_deleted')::boolean,
    'where the definer owner may delete auth.users, the whole deletion is one transaction';

  -- The bystander, whose data was equally reachable to a function that got identity wrong
  select count(*) into n from kitchen where id = k_other;
  assert n = 1, 'another user''s kitchen survives someone else''s account deletion';
  select count(*) into n from op where kitchen_id = k_other;
  assert n = 1, 'another user''s ops survive';
  select count(*) into n from invite where kitchen_id = k_other and revoked_at is null;
  assert n = 1, 'another user''s live invite survives';
  select count(*) into n from member where user_id = other and role = 'owner';
  assert n = 1, 'another user''s membership and role survive';
  select scans_used into n from entitlement where user_id = other;
  assert n = 1, 'another user''s entitlement row is untouched, value included';
  select count(*) into n from scan_audit where user_id = other;
  assert n = 1, 'another user''s scan_audit row is untouched';
  select count(*) into n from auth.users where id = other;
  assert n = 1, 'another user''s auth row is untouched';

  raise notice 'ok 15: solo kitchen, its ops, its invites, entitlement and scan_audit gone; bystander intact';
end $$;
reset role;

rollback;

-- ---------------------------------------------------------------------------
-- 16. The household keeps its list. An owner leaves a kitchen that others still use:
--     the kitchen and every op survive (op carries device_id, never user_id, so
--     keeping them discloses nothing about the leaver), the longest-standing
--     remaining member becomes owner, and the departure revokes the live invite the
--     leaver had shared. A kitchen with no owner is a kitchen nobody can administer,
--     so the promotion is proven by USE, not just by the role column.
-- ---------------------------------------------------------------------------
begin;

insert into auth.users (id, aud, role, email) values
  ('00000000-0000-0000-0000-0000000000f3', 'authenticated', 'authenticated', 'own-h@test.local'),
  ('00000000-0000-0000-0000-0000000000f4', 'authenticated', 'authenticated', 'old-g@test.local'),
  ('00000000-0000-0000-0000-0000000000f5', 'authenticated', 'authenticated', 'new-g@test.local');

do $$
declare
  ownr uuid := '00000000-0000-0000-0000-0000000000f3';
  g_old uuid := '00000000-0000-0000-0000-0000000000f4';
  g_new uuid := '00000000-0000-0000-0000-0000000000f5';
  kid uuid; tok text; res jsonb; n int; r text;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims',
    json_build_object('sub', ownr, 'role', 'authenticated')::text, true);
  kid := public.create_kitchen('Kitchen Household');
  insert into op (id, kitchen_id, device_id, clock, wall_clock, type, payload)
  values ('f3f3f3f3-0000-0000-0000-000000000001', kid,
          'dddddddd-0000-0000-0000-000000000003', 1, 1723800000000, 'add', '{"name":"bread"}'),
         ('f3f3f3f3-0000-0000-0000-000000000002', kid,
          'dddddddd-0000-0000-0000-000000000003', 2, 1723800000500, 'add', '{"name":"butter"}');
  tok := public.create_invite(kid);

  perform set_config('request.jwt.claims',
    json_build_object('sub', g_old, 'role', 'authenticated')::text, true);
  perform public.join_kitchen(tok);
  perform set_config('request.jwt.claims',
    json_build_object('sub', g_new, 'role', 'authenticated')::text, true);
  perform public.join_kitchen(tok);

  -- joined_at defaults to now(), which is identical for everything inside one
  -- transaction, so "longest-standing" is spelled out here rather than left to a tie.
  -- (The tie case is section 19's whole subject.)
  perform set_config('role', 'none', true); reset role;
  update member set joined_at = now() - interval '3 days' where kitchen_id = kid and user_id = ownr;
  update member set joined_at = now() - interval '2 days' where kitchen_id = kid and user_id = g_old;
  update member set joined_at = now() - interval '1 day'  where kitchen_id = kid and user_id = g_new;

  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims',
    json_build_object('sub', ownr, 'role', 'authenticated')::text, true);
  res := public.delete_account();
  perform set_config('role', 'none', true); reset role;

  assert (res->>'kitchens_kept')::int = 1, 'the shared kitchen is reported kept';
  assert (res->>'kitchens_deleted')::int = 0, 'no kitchen was destroyed';
  assert (res->>'owners_promoted')::int = 1, 'one ownership transfer is reported';
  assert (res->>'ops_deleted')::int = 0, 'no op was deleted';

  select count(*) into n from kitchen where id = kid;
  assert n = 1, 'a kitchen with another member survives its owner deleting their account';
  select count(*) into n from op where kitchen_id = kid;
  assert n = 2, 'the household keeps its list — every op survives';
  select count(*) into n from op where kitchen_id = kid and payload->>'name' = 'bread';
  assert n = 1, 'the ops are the same ops, not replacements';
  select count(*) into n from member where kitchen_id = kid and user_id = ownr;
  assert n = 0, 'the leaver''s membership is gone';
  select role into r from member where kitchen_id = kid and user_id = g_old;
  assert r = 'owner', 'the LONGEST-STANDING remaining member inherits ownership';
  select role into r from member where kitchen_id = kid and user_id = g_new;
  assert r = 'guest', 'the later joiner is not promoted';
  select count(*) into n from member where kitchen_id = kid and role = 'owner';
  assert n = 1, 'exactly one owner — never zero, never two';
  select count(*) into n from invite where kitchen_id = kid and revoked_at is null;
  assert n = 0, 'a departure kills every live invite, exactly as an eviction does';

  -- Ownership is only real if it can be exercised: the heir must be able to do the two
  -- owner-only things — remove a guest (member_delete, is_kitchen_owner) and mint a link.
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims',
    json_build_object('sub', g_old, 'role', 'authenticated')::text, true);
  perform public.create_invite(kid);
  delete from member where kitchen_id = kid and user_id = g_new;
  perform set_config('role', 'none', true); reset role;
  select count(*) into n from member where kitchen_id = kid and user_id = g_new;
  assert n = 0, 'the inherited ownership is usable: the new owner can remove a guest';

  raise notice 'ok 16: shared kitchen and its ops survive; longest-standing member inherits a usable ownership';
end $$;
reset role;

rollback;

-- ---------------------------------------------------------------------------
-- 17. THE attack. delete_account takes no argument, so there is no id to point at a
--     victim; anon cannot call it at all even holding a victim's sub claim; and a
--     caller with no sub deletes nothing. Everything a hostile caller can reach here
--     must leave the victim's kitchen, ops, entitlement, scan_audit and auth row alone.
-- ---------------------------------------------------------------------------
begin;

insert into auth.users (id, aud, role, email) values
  ('00000000-0000-0000-0000-0000000000f6', 'authenticated', 'authenticated', 'victim@test.local'),
  ('00000000-0000-0000-0000-0000000000f7', 'authenticated', 'authenticated', 'attack@test.local');

do $$
declare
  victim uuid := '00000000-0000-0000-0000-0000000000f6';
  attacker uuid := '00000000-0000-0000-0000-0000000000f7';
  kid uuid; res jsonb; n int;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims',
    json_build_object('sub', victim, 'role', 'authenticated')::text, true);
  kid := public.create_kitchen('Kitchen Victim');
  perform public.create_invite(kid);
  insert into op (id, kitchen_id, device_id, clock, wall_clock, type, payload)
  values ('f6f6f6f6-0000-0000-0000-000000000001', kid,
          'dddddddd-0000-0000-0000-000000000006', 1, 1723800000000, 'add', '{"name":"coffee"}');

  perform set_config('role', 'none', true); reset role;
  insert into entitlement (user_id, is_plus, scans_used) values (victim, true, 1);
  insert into scan_audit (user_id) values (victim);

  -- The attacker tries to name the victim. There is no signature that takes one.
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims',
    json_build_object('sub', attacker, 'role', 'authenticated')::text, true);
  begin
    execute 'select public.delete_account($1)' using victim;
    raise exception 'delete_account accepted a caller-supplied user id';
  exception when undefined_function then null;
  end;
  begin
    execute format('select public.delete_account(%L::uuid)', victim);
    raise exception 'delete_account accepted a caller-supplied user id (literal form)';
  exception when undefined_function then null;
  end;

  -- And calling it legitimately deletes the ATTACKER, whatever they were hoping.
  res := public.delete_account();
  perform set_config('role', 'none', true); reset role;
  assert (res->>'kitchens_deleted')::int = 0 and (res->>'kitchens_kept')::int = 0
     and (res->>'member_rows_deleted')::int = 0,
    'a caller with nothing deletes nothing and raises nothing';
  select count(*) into n from auth.users where id = attacker;
  assert n = 0, 'the attacker deleted their own account, which is all this function can do';

  select count(*) into n from kitchen where id = kid;
  assert n = 1, 'the victim''s kitchen is untouched';
  select count(*) into n from op where kitchen_id = kid;
  assert n = 1, 'the victim''s ops are untouched';
  select count(*) into n from member where user_id = victim and role = 'owner';
  assert n = 1, 'the victim is still the owner of their kitchen';
  select count(*) into n from entitlement where user_id = victim;
  assert n = 1, 'the victim''s entitlement is untouched';
  select count(*) into n from scan_audit where user_id = victim;
  assert n = 1, 'the victim''s scan_audit is untouched';
  select count(*) into n from auth.users where id = victim;
  assert n = 1, 'the victim''s auth user still exists';

  -- anon: holding the victim's sub claim is not enough, because EXECUTE is what stops it.
  perform set_config('role', 'anon', true);
  perform set_config('request.jwt.claims',
    json_build_object('sub', victim, 'role', 'anon')::text, true);
  begin
    perform public.delete_account();
    raise exception 'anon executed delete_account';
  exception when insufficient_privilege then null;
  end;
  perform set_config('role', 'none', true); reset role;
  select count(*) into n from member where user_id = victim;
  assert n = 1, 'anon holding a victim sub claim changed nothing';

  -- authenticated with no sub at all (a service or gateway call): identity is auth.uid()
  -- and nothing else, so there is nobody to delete.
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{}', true);
  begin
    perform public.delete_account();
    raise exception 'delete_account ran without an authenticated identity';
  exception when sqlstate '28000' then null;
  end;
  perform set_config('role', 'none', true); reset role;

  raise notice 'ok 17: no id to spoof, anon refused, no-sub refused; victim wholly intact';
end $$;
reset role;

rollback;

-- ---------------------------------------------------------------------------
-- 18. Several kitchens with different populations, ONE call: a solo kitchen the caller
--     owns (destroyed), a shared kitchen the caller owns (kept, heir promoted), and a
--     kitchen the caller merely joined (kept, nothing promoted, its owner untouched).
--     A per-kitchen decision that leaked across kitchens would either strand a
--     household's list or leave someone else's kitchen ownerless.
-- ---------------------------------------------------------------------------
begin;

insert into auth.users (id, aud, role, email) values
  ('00000000-0000-0000-0000-0000000000f8', 'authenticated', 'authenticated', 'multi@test.local'),
  ('00000000-0000-0000-0000-0000000000f9', 'authenticated', 'authenticated', 'mate-q@test.local'),
  ('00000000-0000-0000-0000-0000000000fa', 'authenticated', 'authenticated', 'own-t@test.local');

do $$
declare
  m uuid := '00000000-0000-0000-0000-0000000000f8';
  mate uuid := '00000000-0000-0000-0000-0000000000f9';
  u uuid := '00000000-0000-0000-0000-0000000000fa';
  k_solo uuid; k_shared uuid; k_guest uuid; tok text; res jsonb; n int; r text;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims',
    json_build_object('sub', m, 'role', 'authenticated')::text, true);
  k_solo := public.create_kitchen('Kitchen P solo');
  perform public.create_invite(k_solo);
  insert into op (id, kitchen_id, device_id, clock, wall_clock, type, payload)
  values ('f8f8f8f8-0000-0000-0000-000000000001', k_solo,
          'dddddddd-0000-0000-0000-000000000008', 1, 1723800000000, 'add', '{"name":"salt"}');

  k_shared := public.create_kitchen('Kitchen Q shared');
  insert into op (id, kitchen_id, device_id, clock, wall_clock, type, payload)
  values ('f8f8f8f8-0000-0000-0000-000000000002', k_shared,
          'dddddddd-0000-0000-0000-000000000008', 2, 1723800001000, 'add', '{"name":"pasta"}'),
         ('f8f8f8f8-0000-0000-0000-000000000003', k_shared,
          'dddddddd-0000-0000-0000-000000000008', 3, 1723800001500, 'add', '{"name":"oil"}');
  tok := public.create_invite(k_shared);
  perform set_config('request.jwt.claims',
    json_build_object('sub', mate, 'role', 'authenticated')::text, true);
  perform public.join_kitchen(tok);

  -- A third kitchen the caller only joined.
  perform set_config('request.jwt.claims',
    json_build_object('sub', u, 'role', 'authenticated')::text, true);
  k_guest := public.create_kitchen('Kitchen T other household');
  insert into op (id, kitchen_id, device_id, clock, wall_clock, type, payload)
  values ('fafafafa-0000-0000-0000-000000000001', k_guest,
          'dddddddd-0000-0000-0000-00000000000a', 1, 1723800002000, 'add', '{"name":"tea"}');
  tok := public.create_invite(k_guest);
  perform set_config('request.jwt.claims',
    json_build_object('sub', m, 'role', 'authenticated')::text, true);
  perform public.join_kitchen(tok);

  res := public.delete_account();
  perform set_config('role', 'none', true); reset role;

  assert (res->>'kitchens_deleted')::int = 1, 'exactly one kitchen destroyed';
  assert (res->>'kitchens_kept')::int = 2, 'both populated kitchens kept';
  assert (res->>'owners_promoted')::int = 1, 'exactly one ownership transfer';
  assert (res->>'ops_deleted')::int = 1, 'only the dead kitchen''s op is deleted';
  assert (res->>'member_rows_deleted')::int = 3, 'all three memberships are gone';

  select count(*) into n from kitchen where id = k_solo;
  assert n = 0, 'the solo kitchen is destroyed';
  select count(*) into n from op where kitchen_id = k_solo;
  assert n = 0, 'the solo kitchen''s ops are destroyed';
  select count(*) into n from invite where kitchen_id = k_solo;
  assert n = 0, 'the solo kitchen''s invites are destroyed';

  select count(*) into n from kitchen where id = k_shared;
  assert n = 1, 'the shared kitchen survives the same call';
  select count(*) into n from op where kitchen_id = k_shared;
  assert n = 2, 'the shared kitchen''s ops survive the same call';
  select role into r from member where kitchen_id = k_shared and user_id = mate;
  assert r = 'owner', 'the remaining member of the shared kitchen inherits it';
  select count(*) into n from member where kitchen_id = k_shared;
  assert n = 1, 'only the leaver left the shared kitchen';

  select count(*) into n from kitchen where id = k_guest;
  assert n = 1, 'the kitchen the caller had merely joined survives';
  select count(*) into n from op where kitchen_id = k_guest;
  assert n = 1, 'its ops survive';
  select role into r from member where kitchen_id = k_guest and user_id = u;
  assert r = 'owner', 'its owner is still its owner — a guest leaving promotes nobody';
  select count(*) into n from member where kitchen_id = k_guest;
  assert n = 1, 'the guest membership is gone from it';
  select count(*) into n from member where user_id = m;
  assert n = 0, 'the caller is a member of nothing, anywhere';

  raise notice 'ok 18: one call, three kitchens, three different correct outcomes';
end $$;
reset role;

rollback;

-- ---------------------------------------------------------------------------
-- 19. The tie the schema makes ordinary: joined_at defaults to now(), so two guests
--     who join inside one transaction (a QR scan and a re-scan, a restore) hold the
--     SAME joined_at. "Longest-standing" is then undefined, and `order by joined_at
--     limit 1` would promote whichever row the planner returned — possibly a different
--     person on a replica or after a vacuum. user_id breaks the tie, so the heir is
--     arbitrary but deterministic, and there is always exactly one owner.
-- ---------------------------------------------------------------------------
begin;

insert into auth.users (id, aud, role, email) values
  ('00000000-0000-0000-0000-0000000000fb', 'authenticated', 'authenticated', 'own-tie@test.local'),
  ('00000000-0000-0000-0000-0000000000fc', 'authenticated', 'authenticated', 'tie-lo@test.local'),
  ('00000000-0000-0000-0000-0000000000fd', 'authenticated', 'authenticated', 'tie-hi@test.local');

do $$
declare
  ownr uuid := '00000000-0000-0000-0000-0000000000fb';
  tie_lo uuid := '00000000-0000-0000-0000-0000000000fc';  -- smaller uuid, joins SECOND
  tie_hi uuid := '00000000-0000-0000-0000-0000000000fd';  -- larger uuid, joins FIRST
  kid uuid; tok text; res jsonb; n int; r text;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims',
    json_build_object('sub', ownr, 'role', 'authenticated')::text, true);
  kid := public.create_kitchen('Kitchen Tie');
  tok := public.create_invite(kid);

  -- Insertion order is deliberately the OPPOSITE of the uuid order, so a promotion that
  -- fell out of physical row order would pick tie_hi and fail the assert below.
  perform set_config('request.jwt.claims',
    json_build_object('sub', tie_hi, 'role', 'authenticated')::text, true);
  perform public.join_kitchen(tok);
  perform set_config('request.jwt.claims',
    json_build_object('sub', tie_lo, 'role', 'authenticated')::text, true);
  perform public.join_kitchen(tok);

  perform set_config('role', 'none', true); reset role;
  select count(distinct joined_at) into n from member where kitchen_id = kid;
  assert n = 1, 'the tie is real: one transaction, one now(), three identical joined_at';

  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims',
    json_build_object('sub', ownr, 'role', 'authenticated')::text, true);
  res := public.delete_account();
  perform set_config('role', 'none', true); reset role;

  assert (res->>'owners_promoted')::int = 1, 'a tie still produces exactly one promotion';
  select count(*) into n from member where kitchen_id = kid and role = 'owner';
  assert n = 1, 'a joined_at tie never leaves a kitchen with zero or two owners';
  select role into r from member where kitchen_id = kid and user_id = tie_lo;
  assert r = 'owner', 'the tie is broken deterministically by user_id, not by row order';
  select role into r from member where kitchen_id = kid and user_id = tie_hi;
  assert r = 'guest', 'the other tied member keeps their role';
  select count(*) into n from kitchen where id = kid;
  assert n = 1, 'the kitchen survives';

  raise notice 'ok 19: identical joined_at promotes exactly one, deterministically';
end $$;
reset role;

rollback;

-- ---------------------------------------------------------------------------
-- 20. Replay is inert, and the last-owner guard is STILL ARMED.
--     delete_account satisfies member_guard_last_owner by demoting the sole member of
--     a kitchen it is about to destroy in the same transaction. That is the one place
--     that may happen: if 0003 had instead disabled, replaced or loosened the guard,
--     a kitchen full of guests could be left with no owner — so this section re-tries
--     the guard from the client side and it must still refuse. It also proves the
--     demotion itself is unreachable for a client (member UPDATE is revoked), and that
--     a retried deletion (the edge function's network retry) changes nothing twice.
-- ---------------------------------------------------------------------------
begin;

insert into auth.users (id, aud, role, email) values
  ('00000000-0000-0000-0000-0000000000fe', 'authenticated', 'authenticated', 'replay@test.local'),
  ('00000000-0000-0000-0000-0000000000ff', 'authenticated', 'authenticated', 'guard@test.local'),
  ('00000000-0000-0000-0000-000000000100', 'authenticated', 'authenticated', 'guard-g@test.local');

do $$
declare
  z uuid := '00000000-0000-0000-0000-0000000000fe';
  gowner uuid := '00000000-0000-0000-0000-0000000000ff';
  gguest uuid := '00000000-0000-0000-0000-000000000100';
  kid uuid; k_solo uuid; tok text; res jsonb; res2 jsonb; n int; r text;
begin
  -- (a) replay
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims',
    json_build_object('sub', z, 'role', 'authenticated')::text, true);
  k_solo := public.create_kitchen('Kitchen Replay');
  insert into op (id, kitchen_id, device_id, clock, wall_clock, type, payload)
  values ('fefefefe-0000-0000-0000-000000000001', k_solo,
          'dddddddd-0000-0000-0000-00000000000e', 1, 1723800000000, 'add', '{"name":"jam"}');
  perform set_config('role', 'none', true); reset role;
  insert into entitlement (user_id, is_plus, scans_used) values (z, false, 3);
  insert into scan_audit (user_id) values (z);

  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims',
    json_build_object('sub', z, 'role', 'authenticated')::text, true);
  res := public.delete_account();
  -- The same JWT, replayed: the access token outlives the account row (it is stateless),
  -- so this IS reachable, and it must be a no-op rather than an error or a surprise.
  res2 := public.delete_account();
  perform set_config('role', 'none', true); reset role;

  assert (res->>'kitchens_deleted')::int = 1 and (res->>'ops_deleted')::int = 1,
    'the first call did the work';
  assert (res2->>'kitchens_deleted')::int = 0 and (res2->>'kitchens_kept')::int = 0
     and (res2->>'ops_deleted')::int = 0 and (res2->>'member_rows_deleted')::int = 0
     and (res2->>'scan_audit_rows_deleted')::int = 0
     and not (res2->>'entitlement_deleted')::boolean,
    'a replayed deletion is an all-zero no-op — safe for the edge function to retry';
  assert not (res2->>'auth_user_deleted')::boolean,
    'auth_user_deleted is false on replay: the row was already gone, so this call did not remove it';
  select count(*) into n from kitchen where id = k_solo;
  assert n = 0, 'the kitchen is gone after the pair of calls, not resurrected by the second';

  -- (b) the guard, re-tried from the client side
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims',
    json_build_object('sub', gowner, 'role', 'authenticated')::text, true);
  kid := public.create_kitchen('Kitchen Guarded');
  tok := public.create_invite(kid);
  perform set_config('request.jwt.claims',
    json_build_object('sub', gguest, 'role', 'authenticated')::text, true);
  perform public.join_kitchen(tok);

  perform set_config('request.jwt.claims',
    json_build_object('sub', gowner, 'role', 'authenticated')::text, true);
  -- The sole owner of a kitchen with guests still cannot walk out and leave it ownerless.
  begin
    delete from member where kitchen_id = kid and user_id = gowner;
    raise exception 'the last owner left a kitchen with guests in it';
  exception when sqlstate '55006' then null;
  end;
  -- And a client cannot perform the demotion delete_account performs internally.
  begin
    update member set role = 'guest' where kitchen_id = kid and user_id = gowner;
    raise exception 'a client demoted an owner directly';
  exception when insufficient_privilege then null;
  end;
  perform set_config('role', 'none', true); reset role;
  select role into r from member where kitchen_id = kid and user_id = gowner;
  assert r = 'owner', 'the last-owner guard is still armed after 0003 — the owner is still the owner';
  select count(*) into n from member where kitchen_id = kid;
  assert n = 2, 'nobody was removed by the refused attempts';

  raise notice 'ok 20: replay is an all-zero no-op; the last-owner guard is still armed';
end $$;
reset role;

rollback;

do $$ begin raise notice 'ALL RLS TESTS PASSED (including seq commit-ordering, invites and account deletion)'; end $$;
