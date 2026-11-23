#!/bin/bash
# Start a private Unix-socket-only PostgreSQL cluster. Optional probe receives a lifecycle stage.
set -euo pipefail
cd "$(dirname "$0")/../../.."
bin=$(pg_config --bindir)
[[ -x "$bin/initdb" && -x "$bin/pg_ctl" ]] || { echo 'PostgreSQL server tools are required.' >&2; exit 1; }
scratch=$(mktemp -d /tmp/jarvis-session-pg.XXXXXX)
cluster="$scratch/data"
export PGHOST="$scratch" PGPORT=5432 PGDATABASE=postgres PGUSER=postgres
unset PGSERVICE PGSERVICEFILE PGHOSTADDR PGOPTIONS PGPASSWORD PGPASSFILE
ctl=("$bin/pg_ctl" -D "$cluster" -w)
sql=("$bin/psql" -X --no-password --set ON_ERROR_STOP=1 --quiet)
cleanup() {
    status=$?
    trap - EXIT
    if [[ -f "$cluster/postmaster.pid" ]]; then "${ctl[@]}" -m fast stop || exit 1; fi
    if [[ $status -eq 0 ]]; then rm -r "$scratch"; else echo "Retained failed fixture: $scratch" >&2; fi
    exit "$status"
}
trap cleanup EXIT
"$bin/initdb" -D "$cluster" --no-locale --encoding=UTF8 -U postgres -A trust >"$scratch/init.log"
cat >> "$cluster/postgresql.conf" <<SETTINGS
listen_addresses = ''
unix_socket_directories = '$scratch'
SETTINGS
"${ctl[@]}" -l "$scratch/server.log" start
"${sql[@]}" <<'SQL'
create role anon;
create role authenticated;
create role service_role;
create schema auth;
create table auth.users (id uuid primary key);
SQL
for migration in infra/local-db/supabase/migrations/*.sql; do "${sql[@]}" -1 -f "$migration"; done
"${sql[@]}" <<'SQL'
create role fixture_backend login in role jarvis_repository;
insert into auth.users values ('10000000-0000-4000-8000-000000000001'), ('10000000-0000-4000-8000-000000000002');
insert into jarvis.projects values ('10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', 'Synthetic');
SQL
owner='10000000-0000-4000-8000-000000000001'
project='20000000-0000-4000-8000-000000000001'
command='30000000-0000-4000-8000-000000000001'
auth_session='40000000-0000-4000-8000-000000000001'
epoch='50000000-0000-4000-8000-000000000001'
accept="select jarvis.create_record('$owner','$auth_session','$epoch','$command',repeat('a',64),'$project','First');"
PGUSER=fixture_backend "${sql[@]}" -Atc "$accept" >"$scratch/first" &
first=$!
PGUSER=fixture_backend "${sql[@]}" -Atc "$accept" >"$scratch/duplicate" &
second=$!
wait "$first"
wait "$second"
cmp "$scratch/first" "$scratch/duplicate"
"${sql[@]}" -f infra/local-db/qualification/session-assertions.sql
if (($#)); then PGUSER=fixture_backend "$@" before-restart; fi
"${ctl[@]}" -l "$scratch/server.log" -m fast restart
PGUSER=fixture_backend "${sql[@]}" -Atc "$accept" >"$scratch/restored"
cmp "$scratch/first" "$scratch/restored"
if (($#)); then PGUSER=fixture_backend "$@" after-restart; fi
"${ctl[@]}" -m fast stop
if (($#)); then PGUSER=fixture_backend "$@" unavailable; fi
echo 'Concurrent duplicate, rollback and restart checks passed on the disposable PostgreSQL cluster.'
