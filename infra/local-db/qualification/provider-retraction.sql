-- The caller starts this only on its disposable Unix-socket fixture after the
-- restart assertions. The second psql is a separate committed transaction.
\set owner 10000000-0000-4000-8000-000000000001
\set project 20000000-0000-4000-8000-000000000001
\set run 60000000-0000-4000-8000-000000000001
\set generation 70000000-0000-4000-8000-000000000001
\if :writer
begin;
set local lock_timeout='4s';
select set_config('jarvis.owner_id',:'owner',true);
select session_id as session from jarvis.sessions where title='First' \gset
select jarvis.observe_provider_item(:'owner',:'project',:'session',:'run',:'generation',
  'persisted-thread','persisted-turn','persisted-item','withheld',null);
commit;
\else
begin isolation level repeatable read;
set local lock_timeout='4s';
select set_config('jarvis.owner_id',:'owner',true);
select i.entry_id, i.content_id, s.session_id from jarvis.provider_items i
  join jarvis.sessions s on s.owner_id=i.owner_id and s.title='First'
  where i.item_id='persisted-item' and i.disposition='retained' \gset
\set writer_committed `psql --no-password -Xq -v ON_ERROR_STOP=1 -v writer=true -f infra/local-db/qualification/provider-retraction.sql >/dev/null && echo true || echo false`
-- Fail this fixture on every supported psql version if the second client failed.
select 1 / (:'writer_committed'::boolean::integer);
-- Do not take a row lock until after the writer commits. The initial snapshot
-- still contains the old item, but must never authorize returning those bytes.
do $$
declare item jarvis.provider_items%rowtype; session uuid;
begin
  select * into strict item from jarvis.provider_items where item_id='persisted-item' and disposition='retained';
  select session_id into strict session from jarvis.sessions where title='First';
  begin
    if exists(select 1 from jarvis.read_history_part(item.owner_id,
        '20000000-0000-4000-8000-000000000001',session,item.entry_id,item.revision,item.content_id,0))
    then raise exception 'stale transaction disclosed retracted bytes'; end if;
  exception when serialization_failure then null;
  end;
end;
$$;
rollback;
\endif
