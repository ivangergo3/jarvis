-- The backend supplies the authenticated owner separately from the command envelope.
-- Provision the trusted backend login separately and grant it this group role.
create role jarvis_repository nologin;
grant usage on schema jarvis to jarvis_repository;

create table jarvis.sessions (
  owner_id uuid not null,
  project_id uuid not null,
  session_id uuid not null,
  title text not null check (length(btrim(title)) > 0 and length(title) <= 256),
  primary key (owner_id, project_id, session_id),
  foreign key (owner_id, project_id) references jarvis.projects (owner_id, project_id)
);
create table jarvis.owner_cursors (
  owner_id uuid primary key references auth.users (id),
  sequence bigint not null check (sequence > 0)
);
create table jarvis.events (
  owner_id uuid not null references auth.users (id),
  sequence bigint not null check (sequence > 0),
  event_id uuid not null unique,
  envelope jsonb not null,
  primary key (owner_id, sequence)
);
create table jarvis.command_receipts (
  owner_id uuid not null references auth.users (id),
  command_id uuid not null,
  fingerprint text not null check (fingerprint ~ '^[a-f0-9]{64}$'),
  request jsonb not null,
  receipt jsonb not null,
  primary key (owner_id, command_id)
);

-- These private tables use a transaction-local owner set by the trusted backend.
alter table jarvis.sessions enable row level security;
alter table jarvis.owner_cursors enable row level security;
alter table jarvis.events enable row level security;
alter table jarvis.command_receipts enable row level security;
create policy repository_projects on jarvis.projects to jarvis_repository
  using (owner_id = nullif(current_setting('jarvis.owner_id', true), '')::uuid);
create policy repository_sessions on jarvis.sessions to jarvis_repository
  using (owner_id = nullif(current_setting('jarvis.owner_id', true), '')::uuid)
  with check (owner_id = nullif(current_setting('jarvis.owner_id', true), '')::uuid);
create policy repository_cursors on jarvis.owner_cursors to jarvis_repository
  using (owner_id = nullif(current_setting('jarvis.owner_id', true), '')::uuid)
  with check (owner_id = nullif(current_setting('jarvis.owner_id', true), '')::uuid);
create policy repository_events on jarvis.events to jarvis_repository
  using (owner_id = nullif(current_setting('jarvis.owner_id', true), '')::uuid)
  with check (owner_id = nullif(current_setting('jarvis.owner_id', true), '')::uuid);
create policy repository_receipts on jarvis.command_receipts to jarvis_repository
  using (owner_id = nullif(current_setting('jarvis.owner_id', true), '')::uuid)
  with check (owner_id = nullif(current_setting('jarvis.owner_id', true), '')::uuid);
revoke all on jarvis.sessions, jarvis.owner_cursors, jarvis.events, jarvis.command_receipts
  from public, anon, authenticated, service_role;
grant select, insert on jarvis.projects to jarvis_repository;
grant select, insert on jarvis.sessions, jarvis.events, jarvis.command_receipts to jarvis_repository;
grant select, insert, update (sequence) on jarvis.owner_cursors to jarvis_repository;

-- This server-only mutation takes the verified owner separately. The repository
-- validates the command and supplies its canonical SHA-256 fingerprint.
create function jarvis.create_record(
  p_owner uuid, p_auth_session uuid, p_epoch uuid, p_command uuid, p_fingerprint text,
  p_project uuid, p_title text
) returns jsonb
language plpgsql security invoker set search_path = pg_catalog
as $$
declare
  operation text := case when p_project is null then 'project.create' else 'session.create' end;
  request jsonb := jsonb_build_array(operation, p_project, p_title, p_auth_session, p_epoch);
  prior jarvis.command_receipts%rowtype;
  created_id uuid := gen_random_uuid();
  new_event uuid := gen_random_uuid();
  position bigint;
  stamp text;
  target jsonb;
  result jsonb;
  event_kind text;
  event_target jsonb;
  event_payload jsonb;
begin
  -- The receipt read must see the preceding writer after the command lock is acquired.
  if current_setting('transaction_isolation') <> 'read committed' then
    raise exception using errcode = '25001', message = 'record_command_requires_read_committed';
  end if;
  if p_owner is null or p_auth_session is null or p_epoch is null or p_command is null
    or p_fingerprint is null or p_fingerprint !~ '^[a-f0-9]{64}$' or p_title is null
  then raise exception using errcode = '22023', message = 'invalid_record_command'; end if;

  perform set_config('jarvis.owner_id', p_owner::text, true);
  perform pg_advisory_xact_lock(hashtextextended(p_owner::text || ':workspace-write', 0));
  select * into prior from jarvis.command_receipts where owner_id = p_owner and command_id = p_command;
  if found then
    if prior.request <> request or prior.fingerprint <> p_fingerprint then
      raise exception using errcode = 'JV409', message = 'command_id_reused';
    end if;
    return prior.receipt;
  end if;

  insert into jarvis.owner_cursors as c values (p_owner, 1)
    on conflict (owner_id) do update set sequence = c.sequence + 1 returning sequence into position;
  stamp := to_char(clock_timestamp() at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"');
  result := jsonb_build_object('schemaVersion',1,'ownerId',p_owner,'originatingSessionId',p_auth_session,
    'controllerEpoch',p_epoch,'commandId',p_command,'fingerprint',p_fingerprint,'recordedAt',stamp,
    'sequence',position::text);
  if p_project is not null and not exists (
    select 1 from jarvis.projects where owner_id = p_owner and project_id = p_project
  ) then
    result := result || jsonb_build_object('status','definitively_refused','reason','target_not_found',
      'attempted',jsonb_build_object('operation',operation,'target',jsonb_build_object('projectId',p_project)));
    event_kind := 'command.recorded';
    event_target := jsonb_build_object('commandId',p_command);
    event_payload := jsonb_build_object('status','definitively_refused');
  else
    if p_project is null then
      insert into jarvis.projects values (p_owner, created_id, p_title);
      target := jsonb_build_object('projectId',created_id);
      event_kind := 'project.created';
    else
      insert into jarvis.sessions values (p_owner, p_project, created_id, p_title);
      target := jsonb_build_object('projectId',p_project,'sessionId',created_id);
      event_kind := 'session.created';
    end if;
    result := result || jsonb_build_object('status','accepted','operation',operation,'target',target);
    event_target := target;
    event_payload := jsonb_build_object('commandId',p_command,'title',p_title);
  end if;
  insert into jarvis.events values (p_owner, position, new_event, jsonb_build_object(
    'schemaVersion',1,'ownerId',p_owner,'eventId',new_event,'sequence',position::text,
    'occurredAt',stamp,'kind',event_kind,'target',event_target,'payload',event_payload));
  insert into jarvis.command_receipts values (p_owner, p_command, p_fingerprint, request, result);
  return result;
end;
$$;
revoke all on function jarvis.create_record(uuid,uuid,uuid,uuid,text,uuid,text)
  from public, anon, authenticated, service_role;
grant execute on function jarvis.create_record(uuid,uuid,uuid,uuid,text,uuid,text) to jarvis_repository;
