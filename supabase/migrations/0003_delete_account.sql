-- 0003_delete_account.sql — in-app account deletion. App Review 5.1.1(v) requires it
-- before Bagged can be submitted at all (TERMINAL_TICKET_FOUNDER_BLOCKERS §7).
--
-- WHAT deletion means is settled in DECISIONS.md → "Deleting an account"; this file
-- implements exactly that ruling and invents nothing:
--   * the person leaves, the household keeps its list;
--   * member + entitlement + scan_audit + auth user go (scan_audit because it is the
--     one table holding a user_id next to a timestamp);
--   * last one out takes the lights — a kitchen with no other member goes, with its
--     invites and its ops;
--   * ownership passes to the longest-standing remaining member, because a kitchen
--     with no owner is a kitchen nobody can invite into.
--
-- 0001 and 0002 are NOT edited here: they may already be applied to a live project.

------------------------------------------------------------------------------
-- delete_account(): NO PARAMETERS, deliberately.
--
-- Identity comes from auth.uid() and nowhere else. A p_user argument here would be
-- a delete-anyone's-account vulnerability behind one PostgREST call, and no amount of
-- "the client only ever passes its own id" makes that safe. There is nothing to spoof
-- because there is nothing to pass — a caller who tries delete_account('<victim>')
-- gets 42883 undefined_function, which is proven in the RLS suite (section 17).
--
-- SECURITY DEFINER because the work spans tables clients cannot write (op DELETE and
-- member UPDATE are revoked outright; scan_audit and entitlement are service-role
-- only). Explicit search_path, as every definer function in 0002 has.
--
-- Returns a counts-only summary: no kitchen ids, no user ids, nothing an edge function
-- could log into an incident about the person who just asked to be forgotten.
------------------------------------------------------------------------------
create function public.delete_account()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  uid uuid := auth.uid();
  k record;
  heir uuid;
  others int;
  rc int;
  kitchens_deleted int := 0;
  kitchens_kept int := 0;
  owners_promoted int := 0;
  ops_deleted int := 0;
  member_rows int := 0;
  scan_rows int := 0;
  ent_rows int := 0;
  auth_deleted boolean := false;
begin
  if uid is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;

  select count(*) into member_rows from member where user_id = uid;

  -- order by kitchen_id: two account deletions that share kitchens take the row locks
  -- below in the same order, so they queue instead of deadlocking.
  for k in
    select kitchen_id, role from member where user_id = uid order by kitchen_id
  loop
    -- "Am I the only member?" decides whether a household's whole list is destroyed, so
    -- it must not be answerable-then-false. A member INSERT takes a FOR KEY SHARE lock on
    -- its kitchen row for the foreign-key check, so taking FOR UPDATE here serializes this
    -- decision against a join_kitchen that is in flight for the same kitchen.
    perform 1 from kitchen where id = k.kitchen_id for update;

    select count(*) into others
      from member where kitchen_id = k.kitchen_id and user_id <> uid;

    if others = 0 then
      ------------------------------------------------------------------------
      -- Last one out takes the lights: nobody is left who could ever read this
      -- kitchen, so it goes with its invites and its ops.
      --
      -- THE ORDER IS THE POINT. op.kitchen_id references kitchen (id) with NO
      -- ON DELETE CASCADE (unlike member and invite), so `delete from kitchen`
      -- while ops exist is a foreign-key violation. Two ways out; this file
      -- takes the first ON PURPOSE:
      --   (a) delete the children explicitly, oldest dependency last — chosen;
      --   (b) alter op's constraint to on delete cascade — REJECTED, because it
      --       would turn every future `delete from kitchen` anywhere into a
      --       silent erasure of a household's entire shopping history. The
      --       missing cascade is a safety rail, not an oversight: it forces any
      --       code that destroys a kitchen to say out loud that it is also
      --       destroying the log. Only this function says it.
      ------------------------------------------------------------------------

      -- member_guard_last_owner (0002) refuses to let a kitchen lose its last owner,
      -- and it fires on cascade deletes too — so the sole owner of a kitchen cannot be
      -- deleted while their role is 'owner', by any path. The guard is right in general
      -- (a kitchen of ownerless guests is a slow death) and its subject here is a kitchen
      -- that will not exist by the end of this statement block. Demoting first is how
      -- this function satisfies the guard instead of weakening it: the guard is left
      -- fully armed for every other caller (proven in section 20), and the demotion is
      -- unreachable for anyone else — member UPDATE is revoked from anon and
      -- authenticated, and `others = 0` above was established under the row lock.
      update member set role = 'guest'
       where kitchen_id = k.kitchen_id and user_id = uid;

      delete from op where kitchen_id = k.kitchen_id;
      get diagnostics rc = row_count;
      ops_deleted := ops_deleted + rc;

      delete from invite where kitchen_id = k.kitchen_id;
      delete from member where kitchen_id = k.kitchen_id;
      delete from kitchen where id = k.kitchen_id;

      kitchens_deleted := kitchens_deleted + 1;
    else
      ------------------------------------------------------------------------
      -- Somebody else still lives here. The ops STAY.
      --
      -- They are the household's shopping list; deleting them would silently empty
      -- someone else's list days later with no explanation. And keeping them discloses
      -- nothing about the leaver: op carries device_id, never user_id, so the shared
      -- history was never attributed to a person's account in the first place. That
      -- single schema fact is what makes account deletion clean here — there is no
      -- op log to rewrite or anonymise.
      ------------------------------------------------------------------------
      if k.role = 'owner' and not exists (
        select 1 from member
         where kitchen_id = k.kitchen_id and user_id <> uid and role = 'owner'
      ) then
        -- Longest-standing remaining member inherits. joined_at can tie exactly (two
        -- guests who joined inside one transaction share now()), so user_id breaks the
        -- tie: an arbitrary-but-deterministic heir beats "whichever row the planner
        -- happened to return", which could promote two different people on two replays.
        select user_id into heir
          from member
         where kitchen_id = k.kitchen_id and user_id <> uid
         order by joined_at, user_id
         limit 1;

        update member set role = 'owner'
         where kitchen_id = k.kitchen_id and user_id = heir;
        owners_promoted := owners_promoted + 1;
      end if;

      -- Deleting this row fires member_revoke_invites (0002): the leaver's departure
      -- kills every live invite for the kitchen, exactly as an eviction does. The
      -- inheriting owner mints a fresh link; a link the leaver had already shared
      -- (a QR photo in a group chat) does not outlive their account.
      delete from member where kitchen_id = k.kitchen_id and user_id = uid;

      kitchens_kept := kitchens_kept + 1;
    end if;
  end loop;

  -- The two tables that hold this person and nothing shared.
  delete from scan_audit where user_id = uid;
  get diagnostics scan_rows = row_count;

  delete from entitlement where user_id = uid;
  get diagnostics ent_rows = row_count;

  ------------------------------------------------------------------------------
  -- The auth user. Attempted here, GUARANTEED by the delete-account edge function.
  --
  -- Whether `delete from auth.users` is reachable from a definer function owned by
  -- postgres on hosted Supabase is NOT something this repo can verify: auth.users is
  -- owned by supabase_auth_admin, the privileges postgres holds on the auth schema are
  -- a property of the hosted project (and have changed across platform versions), and
  -- the test shim here owns auth.users outright, so a green test proves nothing about
  -- production. So this is written to be correct under every one of those worlds:
  --   * no privilege / no schema  -> insufficient_privilege, caught, flag stays false;
  --   * RLS or a policy silently matching zero rows -> row_count = 0, flag stays false;
  --   * already gone (a replayed call) -> row_count = 0, flag stays false;
  --   * privilege present         -> row_count = 1, flag true, and the whole deletion
  --                                  including the auth user is ONE transaction.
  -- 'auth_user_deleted' therefore means "this call removed the row", never "the row is
  -- absent". false is an instruction to the caller: finish it through the Admin API.
  -- The exception block is a subtransaction, so a refusal here rolls back the auth
  -- delete alone and leaves the data deletion above standing and committed.
  ------------------------------------------------------------------------------
  begin
    delete from auth.users where id = uid;
    get diagnostics rc = row_count;
    auth_deleted := rc = 1;
  exception
    when insufficient_privilege or undefined_table or undefined_object or invalid_schema_name then
      auth_deleted := false;
  end;

  -- Counts only. Replaying this call is inert and returns all zeros, which is what makes
  -- the edge function safe to retry after a network failure.
  return jsonb_build_object(
    'kitchens_deleted', kitchens_deleted,
    'kitchens_kept', kitchens_kept,
    'owners_promoted', owners_promoted,
    'ops_deleted', ops_deleted,
    'member_rows_deleted', member_rows,
    'entitlement_deleted', ent_rows > 0,
    'scan_audit_rows_deleted', scan_rows,
    'auth_user_deleted', auth_deleted
  );
end;
$$;

comment on function public.delete_account() is
  'Deletes the CALLING account (auth.uid() only, no parameter): member rows, entitlement, '
  'scan_audit, kitchens with no other member (with their invites and ops), promoting the '
  'longest-standing remaining member where the caller owned a kitchen others still use. '
  'DECISIONS.md -> Deleting an account.';

------------------------------------------------------------------------------
-- Grants. Supabase's default privileges hand EXECUTE on every new function to anon
-- AND authenticated directly, so revoking from PUBLIC alone would leave anon able to
-- call this; each role is named.
--
-- The signature must match EXACTLY. A revoke naming a signature Postgres cannot match
-- does not fail in the harmless direction — it aborts the whole migration, and this
-- project has already shipped one such rollback that left RLS enabled with zero
-- policies while the test suite still printed ALL TESTS PASSED. delete_account takes
-- no arguments; if a future migration ever adds one, both lines below must be updated
-- in the same file, and the object must be verified to exist afterwards.
------------------------------------------------------------------------------
-- service_role is in this list too, unlike the functions in 0002. Verified, not assumed:
-- with only `from public, anon, authenticated` the proacl of this function still read
-- `service_role=X/postgres`, because the default privileges grant it by name as well. It
-- would have been harmless (auth.uid() is null under the service key, so the function
-- raises 28000 rather than deleting anyone) but "harmless because of a check inside the
-- body" is not how a delete-my-account entry point should be reachable.
revoke execute on function public.delete_account()
  from public, anon, authenticated, service_role;

-- authenticated only. Anonymous-auth guests ARE `authenticated`, and they must be able
-- to delete their account too — the no-account-wall rule does not get an exception for
-- the one operation App Review requires. The delete-account edge function reaches this
-- as the caller (anon key + the caller's Authorization header — the join-kitchen idiom),
-- so it needs no grant of its own.
grant execute on function public.delete_account() to authenticated;
