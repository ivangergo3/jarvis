-- An older transaction snapshot cannot safely decide whether a command was accepted.
begin isolation level repeatable read;
set local role fixture_backend;
do $$
begin
  perform jarvis.create_record('10000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000001','50000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000001',repeat('a',64),
    '20000000-0000-4000-8000-000000000001','First');
  raise exception 'A stale isolation level was accepted';
exception when sqlstate '25001' then null;
end;
$$;
rollback;

-- Install a late failing insert only in this disposable cluster. The cursor and
-- event have already been written when the receipt insert fails.
alter table jarvis.command_receipts add constraint injected_failure
  check (command_id <> '30000000-0000-4000-8000-000000000003');
set role fixture_backend;
do $$
declare
  owner_id constant uuid := '10000000-0000-4000-8000-000000000001';
  project_id constant uuid := '20000000-0000-4000-8000-000000000001';
  auth_session constant uuid := '40000000-0000-4000-8000-000000000001';
  epoch constant uuid := '50000000-0000-4000-8000-000000000001';
  accepted jsonb;
  refused jsonb;
  created jsonb;
begin
  begin
    perform jarvis.create_record(owner_id, auth_session, epoch, '30000000-0000-4000-8000-000000000001', repeat('a',64), project_id, 'Changed');
    raise exception 'Different payload reused an accepted command ID';
  exception when sqlstate 'JV409' then null;
  end;
  refused := jarvis.create_record('10000000-0000-4000-8000-000000000002', auth_session, epoch,
    '30000000-0000-4000-8000-000000000001',repeat('a',64),project_id,'Foreign');
  if refused->>'reason' is distinct from 'target_not_found' or refused->>'status' is distinct from 'definitively_refused' then
    raise exception 'Foreign project was accepted';
  end if;
  begin
    perform jarvis.create_record(owner_id, auth_session, epoch, '30000000-0000-4000-8000-000000000003', repeat('a',64), project_id, 'Rollback');
    raise exception 'Partial failure committed';
  exception when check_violation then null;
  end;
  accepted := jarvis.create_record(owner_id, auth_session, epoch, '30000000-0000-4000-8000-000000000002', repeat('a',64), project_id, 'Second');
  if accepted->>'sequence' is distinct from '2' or (select count(*) from jarvis.events) <> 2
    or (select count(*) from jarvis.sessions) <> 2 or (select count(*) from jarvis.command_receipts) <> 2
    then raise exception 'Incomplete or non-contiguous writes'; end if;
  if accepted->>'ownerId' is distinct from owner_id::text or accepted->>'originatingSessionId' is distinct from auth_session::text
    or accepted->>'controllerEpoch' is distinct from epoch::text or accepted->>'fingerprint' is distinct from repeat('a',64)
  then raise exception 'Receipt lost its immutable authority'; end if;
  created := jarvis.create_record(owner_id,auth_session,epoch,'30000000-0000-4000-8000-000000000004',
    repeat('b',64),null,'Owned project');
  if created->>'operation' is distinct from 'project.create' or not exists (
    select 1 from jarvis.projects p where p.project_id=(created->'target'->>'projectId')::uuid
  ) then raise exception 'Project and its public receipt diverged'; end if;
  if exists (select 1 from jarvis.events e where
    e.envelope->>'ownerId' is distinct from e.owner_id::text or e.envelope->>'eventId' is distinct from e.event_id::text
    or e.envelope->>'sequence' is distinct from e.sequence::text)
  then raise exception 'Public event identity disagrees with its stored key'; end if;
end;
$$;
reset role;
alter table jarvis.command_receipts drop constraint injected_failure;
do $$
begin
  if has_schema_privilege('anon', 'jarvis', 'usage') or has_schema_privilege('authenticated', 'jarvis', 'usage')
    or has_function_privilege('anon', 'jarvis.create_record(uuid,uuid,uuid,uuid,text,uuid,text)', 'execute')
    or has_function_privilege('authenticated', 'jarvis.create_record(uuid,uuid,uuid,uuid,text,uuid,text)', 'execute')
    then raise exception 'Client role can reach the repository'; end if;
end;
$$;
