-- Co-hortdinate — Supabase schema
-- Paste this whole file into Supabase → SQL Editor → New query → Run.
-- Safe privacy model: a family can only ever see families it shares a group with.

create extension if not exists pgcrypto;

-- ───────────── Tables ─────────────

create table if not exists families (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 60),
  created_at timestamptz not null default now()
);

-- Partner join code lives in its own table so other group members can't see it
create table if not exists family_codes (
  family_id uuid primary key references families on delete cascade,
  join_code text not null unique default upper(substr(md5(gen_random_uuid()::text), 1, 6))
);

-- Each login belongs to exactly one family (both parents can log in to the same family)
create table if not exists family_users (
  user_id uuid primary key references auth.users on delete cascade,
  family_id uuid not null references families on delete cascade
);

create table if not exists groups (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 60),
  invite_code text not null unique default upper(substr(md5(gen_random_uuid()::text), 1, 8)),
  created_at timestamptz not null default now()
);

create table if not exists group_families (
  group_id uuid not null references groups on delete cascade,
  family_id uuid not null references families on delete cascade,
  role text not null default 'member' check (role in ('admin', 'member')),
  joined_at timestamptz not null default now(),
  primary key (group_id, family_id)
);

-- Holiday periods per group (seeded with official NZ dates; admins adjust to their school)
create table if not exists group_holidays (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references groups on delete cascade,
  name text not null,
  start_date date not null,
  end_date date not null,
  note text,
  check (end_date >= start_date)
);

create table if not exists kids (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references families on delete cascade,
  first_name text not null check (char_length(first_name) between 1 and 40),
  birth_month date,          -- stored as the 1st of the birth month, used to show age
  gender text check (gender in ('girl', 'boy', 'other')),
  created_at timestamptz not null default now()
);

-- One row per family per day: need care / hosting (with capacity) / home / away
create table if not exists day_plans (
  family_id uuid not null references families on delete cascade,
  date date not null,
  status text not null check (status in ('need', 'host', 'home', 'away')),
  capacity int not null default 0 check (capacity between 0 and 20),
  note text check (char_length(note) <= 140),
  updated_at timestamptz not null default now(),
  primary key (family_id, date)
);

-- One row per kid per day they're at a programme (or other arrangement, e.g. grandparents)
create table if not exists kid_programmes (
  id uuid primary key default gen_random_uuid(),
  kid_id uuid not null references kids on delete cascade,
  date date not null,
  programme text not null check (char_length(programme) between 1 and 80),
  unique (kid_id, date)
);

create index if not exists day_plans_date_idx on day_plans (date);
create index if not exists kid_programmes_date_idx on kid_programmes (date);
create index if not exists kids_family_idx on kids (family_id);
create index if not exists group_families_family_idx on group_families (family_id);

-- ───────────── Helper functions ─────────────

create or replace function my_family() returns uuid
language sql stable security definer set search_path = public as $$
  select family_id from family_users where user_id = auth.uid()
$$;

create or replace function can_see_family(f uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select f = my_family() or exists (
    select 1 from group_families a
    join group_families b on a.group_id = b.group_id
    where a.family_id = my_family() and b.family_id = f
  )
$$;

create or replace function is_group_member(g uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from group_families where group_id = g and family_id = my_family())
$$;

create or replace function is_group_admin(g uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from group_families where group_id = g and family_id = my_family() and role = 'admin')
$$;

create or replace function kid_family(k uuid) returns uuid
language sql stable security definer set search_path = public as $$
  select family_id from kids where id = k
$$;

-- ───────────── Actions (RPCs) ─────────────

create or replace function create_family(p_name text) returns families
language plpgsql security definer set search_path = public as $$
declare f families;
begin
  if auth.uid() is null then raise exception 'Not signed in'; end if;
  if my_family() is not null then raise exception 'You already belong to a family'; end if;
  insert into families (name) values (trim(p_name)) returning * into f;
  insert into family_codes (family_id) values (f.id);
  insert into family_users (user_id, family_id) values (auth.uid(), f.id);
  return f;
end $$;

create or replace function join_family(p_code text) returns families
language plpgsql security definer set search_path = public as $$
declare f families;
begin
  if auth.uid() is null then raise exception 'Not signed in'; end if;
  if my_family() is not null then raise exception 'You already belong to a family'; end if;
  select families.* into f from families join family_codes c on c.family_id = families.id
    where c.join_code = upper(trim(p_code));
  if f.id is null then raise exception 'That family code was not found'; end if;
  insert into family_users (user_id, family_id) values (auth.uid(), f.id);
  return f;
end $$;

create or replace function create_group(p_name text) returns groups
language plpgsql security definer set search_path = public as $$
declare g groups;
begin
  if my_family() is null then raise exception 'Set up your family first'; end if;
  insert into groups (name) values (trim(p_name)) returning * into g;
  insert into group_families (group_id, family_id, role) values (g.id, my_family(), 'admin');
  return g;
end $$;

create or replace function join_group(p_code text) returns groups
language plpgsql security definer set search_path = public as $$
declare g groups;
begin
  if my_family() is null then raise exception 'Set up your family first'; end if;
  select * into g from groups where invite_code = upper(trim(p_code));
  if g.id is null then raise exception 'That invite code was not found'; end if;
  insert into group_families (group_id, family_id) values (g.id, my_family())
    on conflict do nothing;
  return g;
end $$;

revoke execute on function create_family(text), join_family(text), create_group(text), join_group(text) from anon, public;
grant execute on function create_family(text), join_family(text), create_group(text), join_group(text) to authenticated;

-- ───────────── Row level security ─────────────

alter table families enable row level security;
alter table family_codes enable row level security;
alter table family_users enable row level security;
alter table groups enable row level security;
alter table group_families enable row level security;
alter table group_holidays enable row level security;
alter table kids enable row level security;
alter table day_plans enable row level security;
alter table kid_programmes enable row level security;

create policy fam_select on families for select to authenticated using (can_see_family(id));
create policy fam_update on families for update to authenticated using (id = my_family()) with check (id = my_family());

create policy code_select on family_codes for select to authenticated using (family_id = my_family());

create policy fu_select on family_users for select to authenticated using (user_id = auth.uid());

create policy grp_select on groups for select to authenticated using (is_group_member(id));
create policy grp_update on groups for update to authenticated using (is_group_admin(id)) with check (is_group_admin(id));

create policy gf_select on group_families for select to authenticated using (is_group_member(group_id));
create policy gf_delete on group_families for delete to authenticated
  using (family_id = my_family() or is_group_admin(group_id));

create policy gh_select on group_holidays for select to authenticated using (is_group_member(group_id));
create policy gh_insert on group_holidays for insert to authenticated with check (is_group_admin(group_id));
create policy gh_update on group_holidays for update to authenticated using (is_group_admin(group_id)) with check (is_group_admin(group_id));
create policy gh_delete on group_holidays for delete to authenticated using (is_group_admin(group_id));

create policy kids_select on kids for select to authenticated using (can_see_family(family_id));
create policy kids_insert on kids for insert to authenticated with check (family_id = my_family());
create policy kids_update on kids for update to authenticated using (family_id = my_family()) with check (family_id = my_family());
create policy kids_delete on kids for delete to authenticated using (family_id = my_family());

create policy dp_select on day_plans for select to authenticated using (can_see_family(family_id));
create policy dp_insert on day_plans for insert to authenticated with check (family_id = my_family());
create policy dp_update on day_plans for update to authenticated using (family_id = my_family()) with check (family_id = my_family());
create policy dp_delete on day_plans for delete to authenticated using (family_id = my_family());

create policy kp_select on kid_programmes for select to authenticated using (can_see_family(kid_family(kid_id)));
create policy kp_insert on kid_programmes for insert to authenticated with check (kid_family(kid_id) = my_family());
create policy kp_update on kid_programmes for update to authenticated using (kid_family(kid_id) = my_family()) with check (kid_family(kid_id) = my_family());
create policy kp_delete on kid_programmes for delete to authenticated using (kid_family(kid_id) = my_family());
