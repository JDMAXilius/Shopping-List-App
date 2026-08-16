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

------------------------------------------------------------------------------
-- invite: members only, in and out. NO anon path of any kind — joins go through
-- join_kitchen() keyed on the exact token; capability URLs must not be enumerable.
------------------------------------------------------------------------------
create policy invite_select on invite
  for select to authenticated
  using (public.is_kitchen_member(kitchen_id));

create policy invite_insert on invite
  for insert to authenticated
  with check (public.is_kitchen_member(kitchen_id));

create policy invite_update on invite
  for update to authenticated
  using (public.is_kitchen_member(kitchen_id))
  with check (public.is_kitchen_member(kitchen_id));

revoke delete, truncate on invite from anon, authenticated;

-- Trigger over a create_invite() wrapper: the one-live-token invariant then holds
-- for EVERY insert path (direct policy insert today, any future function), not
-- only for callers who remember to use the wrapper.
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

create function public.create_kitchen(p_name text)
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
  insert into kitchen (name) values (btrim(p_name)) returning id into kid;
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
revoke execute on function public.consume_scan(uuid) from public, anon, authenticated;
revoke execute on function public.refund_scan(uuid) from public, anon, authenticated;
revoke execute on function public.invite_revoke_prior() from public, anon, authenticated;

grant execute on function public.create_kitchen(text) to authenticated;
grant execute on function public.join_kitchen(text) to authenticated;  -- anonymous-auth guests ARE `authenticated`
grant execute on function public.consume_scan(uuid) to service_role;
grant execute on function public.refund_scan(uuid) to service_role;
