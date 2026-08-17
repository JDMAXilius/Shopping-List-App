-- RLS policies + SECURITY DEFINER surface. This IS the authorization layer:
-- there is no middleware behind it. Sharing model: membership-scoped (ARCHITECTURE.md §7).

-- Membership predicates as SECURITY DEFINER (owner bypasses RLS): a plain subselect on
-- member inside member's own policy would recurse; this breaks the cycle in one place.
create function public.is_kitchen_member(kid uuid)
returns boolean
language sql stable security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from member where kitchen_id = kid and user_id = auth.uid()
  );
$$;

create function public.is_kitchen_owner(kid uuid)
returns boolean
language sql stable security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from member
    where kitchen_id = kid and user_id = auth.uid() and role = 'owner'
  );
$$;

revoke execute on function public.is_kitchen_member(uuid) from public;
revoke execute on function public.is_kitchen_owner(uuid) from public;
grant execute on function public.is_kitchen_member(uuid) to anon, authenticated;
grant execute on function public.is_kitchen_owner(uuid) to anon, authenticated;

------------------------------------------------------------------------------
-- kitchen: members read/rename. No INSERT policy — creation only via
-- create_kitchen(), which writes kitchen + owner member atomically (no WITH
-- CHECK hole where a kitchen is created without its owner row). No DELETE at v1.
------------------------------------------------------------------------------
create policy kitchen_select on kitchen
  for select to authenticated
  using (public.is_kitchen_member(id));

create policy kitchen_update on kitchen
  for update to authenticated
  using (public.is_kitchen_member(id))
  with check (public.is_kitchen_member(id));

revoke insert, delete, truncate on kitchen from anon, authenticated;

------------------------------------------------------------------------------
-- member: members see their kitchen's roster. INSERT only via the definer
-- functions. Leave = delete own row; owners may remove guests (never a fellow
-- owner — an owner cannot be evicted).
------------------------------------------------------------------------------
create policy member_select on member
  for select to authenticated
  using (public.is_kitchen_member(kitchen_id));

create policy member_delete on member
  for delete to authenticated
  using (
    user_id = auth.uid()
    or (public.is_kitchen_owner(kitchen_id) and role = 'guest')
  );

revoke insert, update, truncate on member from anon, authenticated;

-- A kitchen must never lose its last owner: the remaining data would be orphaned
-- with guests inside. (Cascade from a kitchen DELETE is blocked too — v1 has none.)
create function public.member_guard_last_owner()
returns trigger
language plpgsql security definer
set search_path = public, pg_temp
as $$
begin
  if old.role = 'owner' and not exists (
    select 1 from member
    where kitchen_id = old.kitchen_id and role = 'owner' and user_id <> old.user_id
  ) then
    raise exception 'last_owner' using errcode = '55006';
  end if;
  return old;
end;
$$;

create trigger member_guard_last_owner
  before delete on member
  for each row execute function public.member_guard_last_owner();

-- Eviction IS eviction: removal without token rotation would let the removed
-- guest walk straight back in. Any departure kills every live invite.
create function public.member_revoke_invites()
returns trigger
language plpgsql security definer
set search_path = public, pg_temp
as $$
begin
  update invite set revoked_at = now()
   where kitchen_id = old.kitchen_id and revoked_at is null;
  return old;
end;
$$;

create trigger member_revoke_invites
  after delete on member
  for each row execute function public.member_revoke_invites();

------------------------------------------------------------------------------
-- invite: members only, in and out. NO anon path of any kind — joins go through
-- join_kitchen() keyed on the exact token; capability URLs must not be enumerable.
-- Tokens are SERVER-minted via create_invite(): no client INSERT, so no
-- client-chosen (guessable) token can ever exist.
------------------------------------------------------------------------------
create policy invite_select on invite
  for select to authenticated
  using (public.is_kitchen_member(kitchen_id));

create policy invite_update on invite
  for update to authenticated
  using (public.is_kitchen_member(kitchen_id))
  with check (public.is_kitchen_member(kitchen_id));

revoke insert, delete, truncate on invite from anon, authenticated;

-- Trigger, not only create_invite() logic: the one-live-token invariant then
-- holds for EVERY insert path (any future function), not just the wrapper.
create function public.invite_revoke_prior()
returns trigger
language plpgsql security definer
set search_path = public, pg_temp
as $$
begin
  update invite
     set revoked_at = now()
   where kitchen_id = new.kitchen_id
     and token <> new.token
     and revoked_at is null;
  return new;
end;
$$;

create trigger invite_single_live
  before insert on invite
  for each row execute function public.invite_revoke_prior();

-- The ONLY way a token is minted: 256 bits server-side, base64url, priors revoked
-- by the trigger above. `extensions` in the path: Supabase installs pgcrypto there.
create function public.create_invite(p_kitchen uuid)
returns text
language plpgsql security definer
set search_path = public, extensions, pg_temp
as $$
declare tok text;
begin
  if not public.is_kitchen_member(p_kitchen) then
    raise exception 'not_a_member' using errcode = '42501';
  end if;
  tok := translate(encode(gen_random_bytes(32), 'base64'), '+/=', '-_');
  insert into invite (kitchen_id, token) values (p_kitchen, tok);
  return tok;
end;
$$;

------------------------------------------------------------------------------
-- op: append-only log. Members read and insert into their own kitchen only
-- (WITH CHECK evaluates the NEW row's kitchen_id — a member cannot address
-- another kitchen). Nobody updates or deletes, ever: no policy AND no privilege.
------------------------------------------------------------------------------
create policy op_select on op
  for select to authenticated
  using (public.is_kitchen_member(kitchen_id));

create policy op_insert on op
  for insert to authenticated
  with check (public.is_kitchen_member(kitchen_id));

revoke update, delete, truncate on op from anon, authenticated;

-- Clients may draw seq (op_assign_seq runs as invoker) but never read the global
-- counter: last_value is a cross-kitchen op-volume oracle.
revoke all on sequence op_seq from anon, authenticated;
grant usage on sequence op_seq to authenticated;

-- THE push path. SECURITY INVOKER: RLS still decides every row. Batch-idempotent
-- where bare .insert() is not — one redelivered duplicate 409s a whole PostgREST batch.
create function public.push_ops(p_ops jsonb)
returns int
language plpgsql security invoker
set search_path = public, pg_temp
as $$
declare r jsonb; inserted int; n int := 0;
begin
  if p_ops is null or jsonb_typeof(p_ops) <> 'array' then
    raise exception 'invalid_ops' using errcode = '22023';
  end if;
  for r in select * from jsonb_array_elements(p_ops) loop
    insert into op (id, kitchen_id, device_id, clock, wall_clock, type, payload)
    values ((r->>'id')::uuid, (r->>'kitchen_id')::uuid, (r->>'device_id')::uuid,
            (r->>'clock')::bigint, (r->>'wall_clock')::bigint, r->>'type', r->'payload')
    on conflict (id) do nothing;
    get diagnostics inserted = row_count;
    n := n + inserted;
  end loop;
  return n;
end;
$$;

------------------------------------------------------------------------------
-- entitlement: users read their own row only; ALL writes are service-role
-- (revenuecat-webhook, consume_scan) — clients never set their own quota.
------------------------------------------------------------------------------
create policy entitlement_select_own on entitlement
  for select to authenticated
  using (user_id = auth.uid());

revoke insert, update, delete, truncate on entitlement from anon, authenticated;

------------------------------------------------------------------------------
-- scan_audit: service-role only. No policies, no privileges for clients.
------------------------------------------------------------------------------
revoke all on scan_audit from anon, authenticated;
revoke all on sequence scan_audit_id_seq from anon, authenticated;

------------------------------------------------------------------------------
-- SECURITY DEFINER functions (all: explicit search_path, identity from
-- auth.uid() — never a client-supplied owner column).
------------------------------------------------------------------------------

-- p_id lets the phone keep the kitchen id its ops are ALREADY stamped with. Minting a fresh
-- one here stranded every op written before sharing: the engine is kitchen-scoped, so those ops
-- correctly never pushed, and the local projection is kitchen-blind, so the owner's own screen
-- still showed them. The guest joined to an empty list and nobody could see why.
-- Taking a caller id is safe because a uuid the caller already holds grants nothing: membership
-- is what SELECT is gated on, and this function writes the owner row itself. A collision with an
-- existing kitchen raises rather than joining one.
create function public.create_kitchen(p_name text, p_id uuid default gen_random_uuid())
returns uuid
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare
  uid uuid := auth.uid();
  kid uuid;
begin
  if uid is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  if p_name is null or length(btrim(p_name)) = 0 or length(p_name) > 80 then
    raise exception 'invalid_name' using errcode = '22023';
  end if;
  -- Nobody owns 20 kitchens for a real reason: cap stops scripted kitchen farming.
  if (select count(*) from member where user_id = uid and role = 'owner') >= 20 then
    raise exception 'kitchen_limit' using errcode = '54000';
  end if;
  if p_id is null then
    raise exception 'invalid_id' using errcode = '22023';
  end if;
  if exists (select 1 from kitchen where id = p_id) then
    raise exception 'kitchen_exists' using errcode = '23505';
  end if;
  insert into kitchen (id, name) values (p_id, btrim(p_name)) returning id into kid;
  insert into member (kitchen_id, user_id, role) values (kid, uid, 'owner');
  return kid;
end;
$$;

create function public.join_kitchen(invite_token text)
returns uuid
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare
  uid uuid := auth.uid();
  kid uuid;
begin
  if uid is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  select kitchen_id into kid
    from invite
   where token = invite_token and revoked_at is null;
  if kid is null then
    -- one error for missing AND revoked: no oracle distinguishing the two
    raise exception 'invite_not_found' using errcode = 'P0002';
  end if;
  insert into member (kitchen_id, user_id, role)
  values (kid, uid, 'guest')
  on conflict (kitchen_id, user_id) do nothing;  -- re-join is idempotent
  return kid;
end;
$$;

-- Free-tier quota consume: single conditional UPDATE — no read-then-write race.
create function public.consume_scan(p_user uuid)
returns table (allowed boolean, is_plus boolean, scans_used int)
language plpgsql security definer
set search_path = public, pg_temp
as $$
declare
  v_plus boolean;
  v_used int;
begin
  insert into entitlement (user_id) values (p_user)
  on conflict (user_id) do nothing;

  select e.is_plus into v_plus from entitlement e where e.user_id = p_user;
  if v_plus then
    return query select true, true, e.scans_used from entitlement e where e.user_id = p_user;
    return;
  end if;

  update entitlement e
     set scans_used = e.scans_used + 1, updated_at = now()
   where e.user_id = p_user and e.is_plus = false and e.scans_used < 3
  returning e.scans_used into v_used;

  if v_used is null then
    return query select false, false, e.scans_used from entitlement e where e.user_id = p_user;
  else
    return query select true, false, v_used;
  end if;
end;
$$;

-- RevenueCat webhook apply, fenced by event time: a stale or replayed event
-- (delivery is unordered) can never overwrite state from a NEWER event.
create function public.apply_entitlement_event(
  p_user uuid, p_is_plus boolean, p_event_at timestamptz)
returns void
language sql security definer
set search_path = public, pg_temp
as $$
  insert into entitlement (user_id, is_plus, plus_event_at)
  values (p_user, p_is_plus, p_event_at)
  on conflict (user_id) do update
    set is_plus = excluded.is_plus,
        plus_event_at = excluded.plus_event_at,
        updated_at = now()
    where entitlement.plus_event_at < excluded.plus_event_at;
$$;

-- Compensation when the upstream parse fails after a free scan was consumed:
-- a transient 502 must not burn one of only three free scans.
create function public.refund_scan(p_user uuid)
returns void
language sql security definer
set search_path = public, pg_temp
as $$
  update entitlement
     set scans_used = greatest(scans_used - 1, 0), updated_at = now()
   where user_id = p_user and is_plus = false;
$$;

-- Lock every definer function down explicitly. Revoking from PUBLIC alone is NOT
-- enough: Supabase's default privileges grant EXECUTE to anon/authenticated
-- directly on every new function — each role must be revoked by name, or any
-- authenticated user could call consume_scan(p_user) and burn someone else's quota.
revoke execute on function public.create_kitchen(text) from public, anon, authenticated;
revoke execute on function public.join_kitchen(text) from public, anon, authenticated;
revoke execute on function public.create_invite(uuid) from public, anon, authenticated;
revoke execute on function public.push_ops(jsonb) from public, anon, authenticated;
revoke execute on function public.consume_scan(uuid) from public, anon, authenticated;
revoke execute on function public.refund_scan(uuid) from public, anon, authenticated;
revoke execute on function public.apply_entitlement_event(uuid, boolean, timestamptz)
  from public, anon, authenticated;
revoke execute on function public.invite_revoke_prior() from public, anon, authenticated;
revoke execute on function public.member_guard_last_owner() from public, anon, authenticated;
revoke execute on function public.member_revoke_invites() from public, anon, authenticated;
revoke execute on function public.op_assign_seq() from public, anon, authenticated;

grant execute on function public.create_kitchen(text) to authenticated;
grant execute on function public.join_kitchen(text) to authenticated;  -- anonymous-auth guests ARE `authenticated`
grant execute on function public.create_invite(uuid) to authenticated;
grant execute on function public.push_ops(jsonb) to authenticated;
grant execute on function public.consume_scan(uuid) to service_role;
grant execute on function public.refund_scan(uuid) to service_role;
grant execute on function public.apply_entitlement_event(uuid, boolean, timestamptz) to service_role;
