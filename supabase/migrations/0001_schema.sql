-- Bagged schema (ARCHITECTURE.md §7). RLS is ENABLED for every table here;
-- policies live in 0002_rls.sql — between the two, tables are default-deny, never open.

create table kitchen (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  created_at  timestamptz not null default now()
);

create table member (
  kitchen_id  uuid not null references kitchen (id) on delete cascade,
  user_id     uuid not null,
  role        text not null check (role in ('owner', 'guest')),
  joined_at   timestamptz not null default now(),
  primary key (kitchen_id, user_id)
);

create index member_user_idx on member (user_id);

create table invite (
  kitchen_id  uuid not null references kitchen (id) on delete cascade,
  token       text primary key,
  created_at  timestamptz not null default now(),
  revoked_at  timestamptz
);

create index invite_kitchen_idx on invite (kitchen_id);

-- THE sync table. seq is the pull cursor: pull is
--   WHERE kitchen_id = $1 AND seq > $2 ORDER BY seq
-- (created_at commits out of order; a timestamp cursor loses ops).
-- Push is INSERT ... ON CONFLICT (id) DO NOTHING — idempotent by contract:
-- client re-delivery after crash-before-mark is the NORMAL case, not an error.
create table op (
  id          uuid primary key,
  seq         bigserial,
  kitchen_id  uuid not null references kitchen (id),
  device_id   uuid not null,
  clock       bigint not null,
  wall_clock  bigint not null,
  type        text not null,
  payload     jsonb not null,
  created_at  timestamptz not null default now()
);

create index op_kitchen_seq_idx on op (kitchen_id, seq);

create table entitlement (
  user_id     uuid primary key,
  is_plus     boolean not null default false,
  scans_used  int not null default 0,
  updated_at  timestamptz not null default now()
);

-- Rate-limit ledger for scan-receipt: who and when, NEVER receipt content.
create table scan_audit (
  id          bigserial primary key,
  user_id     uuid not null,
  created_at  timestamptz not null default now()
);

create index scan_audit_user_time_idx on scan_audit (user_id, created_at);

alter table kitchen     enable row level security;
alter table member      enable row level security;
alter table invite      enable row level security;
alter table op          enable row level security;
alter table entitlement enable row level security;
alter table scan_audit  enable row level security;

-- Clients subscribe to Realtime inserts on op for their kitchen (RLS applies).
do $$
begin
  alter publication supabase_realtime add table public.op;
exception
  when undefined_object then null;  -- vanilla-postgres test container: no realtime publication
  when duplicate_object then null;
end $$;
