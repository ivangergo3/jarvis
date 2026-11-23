-- Only the trusted backend writes provider identifiers or reads retained bytes.
create table jarvis.cli_threads (
  owner_id uuid not null,
  project_id uuid not null,
  session_id uuid not null,
  thread_id text not null check (octet_length(thread_id) between 1 and 2048),
  primary key (owner_id, project_id, session_id),
  unique (owner_id, thread_id),
  foreign key (owner_id, project_id, session_id) references jarvis.sessions
);
create table jarvis.provider_runs (
  owner_id uuid not null,
  project_id uuid not null,
  session_id uuid not null,
  run_id uuid not null,
  generation_id uuid not null,
  turn_id text not null check (octet_length(turn_id) between 1 and 2048),
  observation jsonb,
  revision bigint not null default 0 check (revision >= 0),
  primary key (owner_id, run_id),
  -- A reconnect does not turn an existing CLI turn into a second Jarvis run.
  unique (owner_id,project_id,session_id,turn_id),
  foreign key (owner_id, project_id, session_id) references jarvis.cli_threads
);
create table jarvis.provider_items (
  owner_id uuid not null,
  run_id uuid not null,
  item_id text not null check (octet_length(item_id) between 1 and 2048),
  entry_id uuid not null default gen_random_uuid(),
  revision bigint not null default 1 check (revision > 0),
  content_id uuid not null default gen_random_uuid(),
  disposition text not null check (disposition in ('retained','withheld','run_limit','owner_limit')),
  byte_count integer not null default 0 check (byte_count between 0 and 8388608),
  digest bytea check (octet_length(digest)=32),
  primary key (owner_id, run_id, item_id),
  unique (owner_id,content_id),
  foreign key (owner_id,run_id) references jarvis.provider_runs,
  check ((digest is not null) = (disposition = 'retained')),
  check (disposition = 'retained' or byte_count = 0)
);
create table jarvis.provider_chunks (
  owner_id uuid not null,
  content_id uuid not null,
  byte_offset integer not null check (byte_offset >= 0 and byte_offset % 32768 = 0),
  body bytea not null check (octet_length(body) between 1 and 32768),
  primary key (owner_id,content_id,byte_offset),
  foreign key (owner_id,content_id) references jarvis.provider_items(owner_id,content_id)
);
alter table jarvis.provider_chunks enable row level security;
create policy backend_chunks on jarvis.provider_chunks to jarvis_repository
  using (owner_id = nullif(current_setting('jarvis.owner_id', true), '')::uuid);
revoke all on jarvis.provider_chunks from public,anon,authenticated,service_role;
grant select,insert,delete on jarvis.provider_chunks to jarvis_repository;
alter table jarvis.cli_threads enable row level security;
alter table jarvis.provider_runs enable row level security;
alter table jarvis.provider_items enable row level security;
create policy backend_threads on jarvis.cli_threads to jarvis_repository
  using (owner_id = nullif(current_setting('jarvis.owner_id', true), '')::uuid);
create policy backend_runs on jarvis.provider_runs to jarvis_repository
  using (owner_id = nullif(current_setting('jarvis.owner_id', true), '')::uuid);
create policy backend_items on jarvis.provider_items to jarvis_repository
  using (owner_id = nullif(current_setting('jarvis.owner_id', true), '')::uuid);
revoke all on jarvis.cli_threads,jarvis.provider_runs,jarvis.provider_items from public,anon,authenticated,service_role;
grant select,insert on jarvis.cli_threads,jarvis.provider_runs,jarvis.provider_items to jarvis_repository;
grant update(observation,revision) on jarvis.provider_runs to jarvis_repository;
grant update(disposition,revision,byte_count,digest) on jarvis.provider_items to jarvis_repository;

create function jarvis.append_provider_event(o uuid, kind text, target jsonb, payload jsonb)
returns bigint language plpgsql security invoker set search_path=pg_catalog as $$
declare
  n bigint;
  eid uuid := gen_random_uuid();
begin
  insert into jarvis.owner_cursors as c values(o,1) on conflict(owner_id)
    do update set sequence=c.sequence+1 returning sequence into n;
  insert into jarvis.events values(o,n,eid,jsonb_build_object(
    'schemaVersion',1,'ownerId',o,'sequence',n::text,'eventId',eid,
    'occurredAt',to_char(clock_timestamp() at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
    'kind',kind,'target',target,'payload',payload));
  return n;
end;
$$;
revoke all on function jarvis.append_provider_event(uuid,text,jsonb,jsonb)
  from public,anon,authenticated,service_role;
grant execute on function jarvis.append_provider_event(uuid,text,jsonb,jsonb) to jarvis_repository;

-- The caller has already verified the Codex thread/turn on a Jarvis-owned
-- channel. Retry returns the original association. A changed binding fails closed.
create function jarvis.bind_provider_run(o uuid,p uuid,s uuid,r uuid,g uuid,th text,tu text)
returns void language plpgsql security invoker set search_path=pg_catalog as $$
declare
  newly_bound boolean;
begin
  perform set_config('jarvis.owner_id',o::text,true);
  insert into jarvis.cli_threads values (o,p,s,th) on conflict do nothing;
  newly_bound := found;
  if not exists (select 1 from jarvis.cli_threads where
    (owner_id,project_id,session_id,thread_id)=(o,p,s,th))
  then raise exception using errcode='JV409',message='destination_mismatch'; end if;
  insert into jarvis.provider_runs(owner_id,project_id,session_id,run_id,generation_id,turn_id)
    values (o,p,s,r,g,tu) on conflict do nothing;
  if not exists (select 1 from jarvis.provider_runs where
    (owner_id,project_id,session_id,run_id,generation_id,turn_id)=(o,p,s,r,g,tu))
  then raise exception using errcode='JV409',message='destination_mismatch'; end if;
  if newly_bound then
    perform jarvis.append_provider_event(o,'session.binding',jsonb_build_object('projectId',p,'sessionId',s),
      jsonb_build_object('binding','bound'));
  end if;
end;
$$;
revoke all on function jarvis.bind_provider_run(uuid,uuid,uuid,uuid,uuid,text,text)
  from public,anon,authenticated,service_role;
grant execute on function jarvis.bind_provider_run(uuid,uuid,uuid,uuid,uuid,text,text) to jarvis_repository;

-- A transport disconnect never calls this function. Only normalized, matching
-- observations can change a run. An interrupted event needs independent worker
-- cleanup evidence at the supervisor; that case is not inferred here.
create function jarvis.observe_provider_state(o uuid,p uuid,s uuid,r uuid,g uuid,th text,tu text,state text)
returns boolean language plpgsql security invoker set search_path=pg_catalog as $$
declare
  prior jarvis.provider_runs%rowtype;
  next_state jsonb;
begin
  perform set_config('jarvis.owner_id',o::text,true);
  select x.* into prior from jarvis.provider_runs x join jarvis.cli_threads t
    using(owner_id,project_id,session_id)
    where (x.owner_id,x.project_id,x.session_id,x.run_id,x.generation_id,t.thread_id,x.turn_id)=(o,p,s,r,g,th,tu)
    for update of x;
  if not found then return false; end if;
  if state not in ('running','completed','failed') or state is null then
    raise exception using errcode='22023',message='unsupported_observation';
  end if;
  if prior.observation->>'state'=state or prior.observation->>'state'='unknown'
    or (state='running' and prior.observation is not null) then return false; end if;
  next_state := case
    when prior.observation->>'state' in ('completed','failed') then
      jsonb_build_object('state','unknown','phase','provider_effect')
    when state='failed' then jsonb_build_object('state','failed','reason','execution_failed')
    else jsonb_build_object('state',state) end;
  update jarvis.provider_runs set observation=next_state,revision=revision+1
    where (owner_id,run_id)=(o,r);
  perform jarvis.append_provider_event(o,'run.state',jsonb_build_object('projectId',p,'sessionId',s,'runId',r),
    jsonb_build_object('revision',(prior.revision+1)::text,'observation',next_state));
  return true;
end;
$$;
revoke all on function jarvis.observe_provider_state(uuid,uuid,uuid,uuid,uuid,text,text,text)
  from public,anon,authenticated,service_role;
grant execute on function jarvis.observe_provider_state(uuid,uuid,uuid,uuid,uuid,text,text,text) to jarvis_repository;

-- The caller provides UTF-8 bytes for classified assistant text only. A late
-- withheld item retracts its earlier content; replay cannot restore the bytes.
create function jarvis.observe_provider_item(
  o uuid,p uuid,s uuid,r uuid,g uuid,th text,tu text,item text,disposition_in text,content bytea
) returns boolean language plpgsql security invoker set search_path=pg_catalog as $$
declare
  prior jarvis.provider_items%rowtype;
  saved jarvis.provider_items%rowtype;
  next_disposition text := disposition_in;
  bytes integer := coalesce(octet_length(content),0);
  new_digest bytea;
  run_bytes bigint;
  owner_bytes bigint;
  ref jsonb;
begin
  perform set_config('jarvis.owner_id',o::text,true);
  if not exists (select 1 from jarvis.provider_runs x join jarvis.cli_threads t
    using(owner_id,project_id,session_id)
    where (x.owner_id,x.project_id,x.session_id,x.run_id,x.generation_id,t.thread_id,x.turn_id)=(o,p,s,r,g,th,tu)
  ) then return false; end if;
  if item is null or octet_length(item) not between 1 and 2048
    or disposition_in is null or disposition_in not in ('retained','withheld','run_limit')
    or (disposition_in='retained')<>(content is not null)
  then raise exception using errcode='22023',message='invalid_private_item'; end if;

  -- Serialize both item deduplication and the per-owner byte allowance.
  perform pg_advisory_xact_lock(hashtextextended(o::text || ':private-output',0));
  select * into prior from jarvis.provider_items where (owner_id,run_id,item_id)=(o,r,item);
  if next_disposition='retained' then
    if bytes>8388608 then next_disposition := 'run_limit';
    else new_digest := sha256(content); end if;
  end if;
  if prior.entry_id is not null then
    if prior.disposition='withheld' or prior.disposition=next_disposition and
      (next_disposition<>'retained' or prior.digest=new_digest)
    then return false; end if;
    -- A discarded item must not be rehydrated by an old replay. Conflicting
    -- content under the original item ID is never treated as a new message.
    if prior.disposition<>'retained' and next_disposition<>'withheld' then return false; end if;
    if next_disposition='retained' then next_disposition:='withheld'; end if;
    delete from jarvis.provider_chunks where (owner_id,content_id)=(o,prior.content_id);
    update jarvis.provider_items set disposition=next_disposition,revision=revision+1,byte_count=0,digest=null
      where (owner_id,run_id,item_id)=(o,r,item) returning * into saved;
  else
    if next_disposition='retained' then
      select coalesce(sum(byte_count) filter(where run_id=r),0),coalesce(sum(byte_count),0)
        into run_bytes,owner_bytes from jarvis.provider_items where owner_id=o;
      if bytes+run_bytes>8388608 then next_disposition:='run_limit';
      elsif bytes+owner_bytes>1073741824 then next_disposition:='owner_limit'; end if;
    end if;
    insert into jarvis.provider_items(owner_id,run_id,item_id,disposition,byte_count,digest)
      values(o,r,item,next_disposition,case when next_disposition='retained' then bytes else 0 end,
             case when next_disposition='retained' then new_digest end) returning * into saved;
    if next_disposition='retained' then
      insert into jarvis.provider_chunks select o,saved.content_id,n,substring(content from n+1 for 32768)
        from generate_series(0,bytes-1,32768) n;
    end if;
  end if;
  ref:=case saved.disposition
    when 'retained' then jsonb_build_object('kind','retained_text','ref',jsonb_build_object(
      'contentId',saved.content_id,'bytes',saved.byte_count,'sha256',encode(saved.digest,'hex')))
    when 'withheld' then jsonb_build_object('kind','removed','contentId',saved.content_id)
    else jsonb_build_object('kind','truncated','retainedBytes',0,'cause',saved.disposition) end;
  perform jarvis.append_provider_event(o,'run.output',jsonb_build_object('projectId',p,'sessionId',s,'runId',r),
    jsonb_build_object('entryId',saved.entry_id,'entryRevision',saved.revision::text,'content',ref));
  return true;
end;
$$;
revoke all on function jarvis.observe_provider_item(uuid,uuid,uuid,uuid,uuid,text,text,text,text,bytea)
  from public,anon,authenticated,service_role;
grant execute on function jarvis.observe_provider_item(uuid,uuid,uuid,uuid,uuid,text,text,text,text,bytea) to jarvis_repository;

-- Read a single private chunk only while this exact history revision still
-- grants access to that content. Returning no rows means the reference is stale.
create function jarvis.read_history_part(
  o uuid,p uuid,s uuid,entry uuid,rev bigint,cid uuid,requested integer
) returns table(total integer,digest_hex text,body bytea)
language plpgsql security invoker set search_path=pg_catalog as $$
begin
  perform set_config('jarvis.owner_id',o::text,true);
  return query select i.byte_count,encode(i.digest,'hex'),
    case when i.byte_count=0 then ''::bytea
         else substring(c.body from (requested % 32768)+1) end
    from jarvis.provider_items i join jarvis.provider_runs x using(owner_id,run_id)
    left join jarvis.provider_chunks c on c.owner_id=i.owner_id and c.content_id=i.content_id
      and c.byte_offset=requested-(requested % 32768)
    where (i.owner_id,x.project_id,x.session_id,i.entry_id,i.revision,i.content_id)=(o,p,s,entry,rev,cid)
      and i.disposition='retained' and requested>=0
      and (requested<i.byte_count and c.body is not null or requested=0 and i.byte_count=0)
    -- Serialize this grant with withholding. An outdated REPEATABLE READ snapshot
    -- receives serialization_failure when the authoritative item has changed.
    for share of i;
end;
$$;
revoke all on function jarvis.read_history_part(uuid,uuid,uuid,uuid,bigint,uuid,integer)
  from public,anon,authenticated,service_role;
grant execute on function jarvis.read_history_part(uuid,uuid,uuid,uuid,bigint,uuid,integer) to jarvis_repository;
