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
  conn text := 'dbname=' || current_database();
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

do $$ begin raise notice 'ALL RLS TESTS PASSED (including seq commit-ordering)'; end $$;

-- ---------------------------------------------------------------------------
-- 14. An invite is server-minted and server-revoked. A member cannot write one.
--     Both halves were reachable before: revoked_at back to null resurrected every
--     link the owner had killed, and a chosen token is the guessable capability
--     this schema exists to prevent.
-- ---------------------------------------------------------------------------
do $$
declare
  kid uuid;
  tok text;
  guest uuid := '00000000-0000-0000-0000-0000000000ge'::uuid;
  n int;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', owner_a())::text, true);
  set local role authenticated;
  kid := public.create_kitchen('Kitchen N');
  tok := public.create_invite(kid);

  perform set_config('request.jwt.claims', json_build_object('sub', guest)::text, true);
  perform public.join_kitchen(tok);

  -- The owner kills the link the way the app does: a new one revokes the prior.
  perform set_config('request.jwt.claims', json_build_object('sub', owner_a())::text, true);
  perform public.create_invite(kid);
  select count(*) into n from invite where kitchen_id = kid and revoked_at is null;
  assert n = 1, 'exactly one live token after a new link';

  -- Now the guest tries to undo that, and to name a token of their own.
  perform set_config('request.jwt.claims', json_build_object('sub', guest)::text, true);
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

  perform set_config('request.jwt.claims', json_build_object('sub', owner_a())::text, true);
  select count(*) into n from invite where kitchen_id = kid and revoked_at is null;
  assert n = 1, 'still exactly one live token';
  raise notice 'ok 14 invite is server-minted and server-revoked';
end $$;
