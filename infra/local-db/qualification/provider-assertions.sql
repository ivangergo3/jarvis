-- The surrounding rehearsal provides temporary owner/project/session records.
begin;
set local role fixture_backend;
do $$
declare
  o constant uuid := '10000000-0000-4000-8000-000000000001';
  p constant uuid := '20000000-0000-4000-8000-000000000001';
  s uuid;
  r uuid := gen_random_uuid();
  g uuid := gen_random_uuid();
  bytes bytea := convert_to(repeat('private-synthetic-item',1800),'UTF8');
  before_n bigint;
  chunks bytea;
  entry uuid;
  cid uuid;
begin
  perform set_config('jarvis.owner_id',o::text,true);
  select session_id into strict s from jarvis.sessions where owner_id=o and project_id=p and title='First';
  select sequence into before_n from jarvis.owner_cursors where owner_id=o;
  perform jarvis.bind_provider_run(o,p,s,r,g,'thread-A','turn-A');
  perform jarvis.bind_provider_run(o,p,s,r,g,'thread-A','turn-A');
  begin
    perform jarvis.bind_provider_run(o,p,s,r,g,'other-thread','turn-A');
    raise exception 'allowed rebinding to a different CLI session';
  exception when sqlstate 'JV409' then null; end;

  begin
    perform jarvis.bind_provider_run(o,p,s,gen_random_uuid(),gen_random_uuid(),'thread-A','turn-A');
    raise exception 'a reconnect attached the same CLI turn to a second run';
  exception when sqlstate 'JV409' then null; end;

  if jarvis.observe_provider_state(o,p,s,r,gen_random_uuid(),'thread-A','turn-A','running')
    or jarvis.observe_provider_item(o,p,s,r,g,'thread-A','turn-B','item','retained',bytes)
  then raise exception 'a foreign source produced a public event'; end if;
  if not jarvis.observe_provider_state(o,p,s,r,g,'thread-A','turn-A','running') or
    not jarvis.observe_provider_state(o,p,s,r,g,'thread-A','turn-A','completed') or
    jarvis.observe_provider_state(o,p,s,r,g,'thread-A','turn-A','running')
  then raise exception 'invalid run observation ordering'; end if;
  if not jarvis.observe_provider_item(o,p,s,r,g,'thread-A','turn-A','item','retained',bytes) or
    jarvis.observe_provider_item(o,p,s,r,g,'thread-A','turn-A','item','retained',bytes)
  then raise exception 'invalid private item deduplication'; end if;
  select string_agg(c.body,''::bytea order by c.byte_offset) into chunks
    from jarvis.provider_chunks c join jarvis.provider_items i using(owner_id,content_id)
    where (i.owner_id,i.run_id,i.item_id)=(o,r,'item');
  if chunks is distinct from bytes or
    exists(select from jarvis.events where position('private-synthetic-item' in envelope::text)>0)
  then raise exception 'private storage or public projection failed'; end if;
  select entry_id,content_id into strict entry,cid from jarvis.provider_items
    where (owner_id,run_id,item_id)=(o,r,'item');
  if (select body from jarvis.read_history_part(o,p,s,entry,1,cid,32769)) is distinct from substring(bytes from 32770)
    or exists(select from jarvis.read_history_part(o,p,s,entry,2,cid,0))
    or exists(select from jarvis.read_history_part(o,p,gen_random_uuid(),entry,1,cid,0))
    or exists(select from jarvis.read_history_part(gen_random_uuid(),p,s,entry,1,cid,0))
  then raise exception 'private read did not enforce owner, revision, destination or offset'; end if;
  if not jarvis.observe_provider_item(o,p,s,r,g,'thread-A','turn-A','item','withheld',null)
  then raise exception 'withholding did not update the source item'; end if;
  if jarvis.observe_provider_item(o,p,s,r,g,'thread-A','turn-A','item','retained',bytes)
  then raise exception 'replay after withholding produced a fresh event'; end if;
  if exists(select from jarvis.provider_chunks c join jarvis.provider_items i using(owner_id,content_id)
      where (i.owner_id,i.run_id,i.item_id)=(o,r,'item'))
  or exists(select from jarvis.read_history_part(o,p,s,entry,1,cid,0))
  then raise exception 'later withholding permitted stale private content'; end if;
  if (select sequence from jarvis.owner_cursors where owner_id=o) is distinct from before_n+5
    or (select envelope->'payload'->'content'->>'kind' from jarvis.events
      where owner_id=o and sequence=before_n+5) is distinct from 'removed'
  then raise exception 'public source sequence or removed content ref missing'; end if;
end;
$$;
rollback;
