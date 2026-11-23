-- psql receives the fixture stage flag from the surrounding harness.
begin;
select set_config('jarvis.owner_id', '10000000-0000-4000-8000-000000000001', true);
select session_id as session from jarvis.sessions where title='First' \gset
\set owner 10000000-0000-4000-8000-000000000001
\set project 20000000-0000-4000-8000-000000000001
\set run 60000000-0000-4000-8000-000000000001
\set generation 70000000-0000-4000-8000-000000000001
\if :seed
select jarvis.bind_provider_run(:'owner',:'project',:'session',:'run',:'generation','persisted-thread','persisted-turn');
select jarvis.observe_provider_state(:'owner',:'project',:'session',:'run',:'generation','persisted-thread','persisted-turn','completed');
select jarvis.observe_provider_item(:'owner',:'project',:'session',:'run',:'generation','persisted-thread','persisted-turn','persisted-item','retained',convert_to('private retained text','UTF8'));
\else
do $$
begin
  if not exists (select 1 from jarvis.provider_runs x join jarvis.cli_threads t using(owner_id, project_id, session_id)
    join jarvis.provider_items i using(owner_id,run_id) join jarvis.provider_chunks c using(owner_id,content_id)
    where t.thread_id='persisted-thread' and x.turn_id='persisted-turn' and x.observation->>'state'='completed'
      and i.item_id='persisted-item' and c.body=convert_to('private retained text','UTF8'))
    or not exists (select 1 from jarvis.events where envelope->>'kind'='run.output'
      and envelope->'payload'->'content'->'ref'->>'sha256'=encode(sha256(convert_to('private retained text','UTF8')),'hex'))
    or exists(select 1 from jarvis.events where position('private retained text' in envelope::text)>0)
  then raise exception 'durable provider binding, output ref or retained bytes failed'; end if;
end;
$$;
\endif
commit;
