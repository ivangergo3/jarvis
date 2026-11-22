-- Run with psql -v ON_ERROR_STOP=1 on the disposable qualification database.
-- All fixture rows, including synthetic auth users, are rolled back.
begin;
do $$
declare
  owner_a uuid := gen_random_uuid();
  owner_b uuid := gen_random_uuid();
  project uuid := gen_random_uuid();
begin
  if not exists (
    select 1 from pg_namespace where nspname = 'jarvis' and nspowner = 'postgres'::regrole
  ) or exists (
    select 1 from unnest(array['anon','authenticated','service_role']) client
    where has_schema_privilege(client, 'jarvis', 'USAGE,CREATE')
      or has_table_privilege(client, 'jarvis.projects', 'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER')
      or has_table_privilege(client, 'jarvis.installation', 'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER')
  ) then raise exception 'unexpected Jarvis schema owner or client grants'; end if;

  if (select count(*) from pg_class where relnamespace = 'jarvis'::regnamespace
      and relname in ('installation','projects') and relrowsecurity) <> 2
    or (select count(*) from jarvis.installation where singleton and installation_id is not null) <> 1
  then raise exception 'missing row isolation or installation identity'; end if;
  begin
    insert into jarvis.installation default values;
    raise exception 'a second installation was accepted';
  exception when unique_violation then null;
  end;

  begin
    insert into jarvis.installation (singleton) values (false);
    raise exception 'an installation with a false singleton was accepted';
  exception when check_violation then null;
  end;

  insert into auth.users(id) values (owner_a), (owner_b);
  insert into jarvis.projects values (owner_a, project, 'A'), (owner_b, project, 'B');
  begin
    insert into jarvis.projects values (owner_a, project, 'Duplicate');
    raise exception 'a duplicate project ID for the same owner was accepted';
  exception when unique_violation then null;
  end;
end;
$$;
rollback;
