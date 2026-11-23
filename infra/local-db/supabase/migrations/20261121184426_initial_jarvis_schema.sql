-- The migration login owns the private schema. Runtime roles are assigned by the
-- repository/auth slices. Nothing here grants a browser access to Jarvis records.
create schema jarvis authorization postgres;
revoke all on schema jarvis from public, anon, authenticated, service_role;

create table jarvis.installation (
  singleton boolean primary key default true check (singleton),
  installation_id uuid not null unique default gen_random_uuid(),
  initialized_at timestamptz not null default now()
);
insert into jarvis.installation (singleton) values (true);

create table jarvis.projects (
  owner_id uuid not null references auth.users (id) on delete restrict,
  project_id uuid not null,
  title text not null check (length(btrim(title)) > 0 and length(title) <= 256),
  primary key (owner_id, project_id)
);

alter table jarvis.installation owner to postgres;
alter table jarvis.projects owner to postgres;
alter table jarvis.installation enable row level security;
alter table jarvis.projects enable row level security;
revoke all on all tables in schema jarvis from public, anon, authenticated, service_role;
