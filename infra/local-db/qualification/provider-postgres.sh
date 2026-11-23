#!/bin/bash
set -euo pipefail
# Called only by session-postgres.sh, which creates a unique, private Unix socket.
[[ "$PGHOST" == /tmp/jarvis-session-pg.* && "$PGUSER" == fixture_backend ]] || exit 2
sql=(psql -X --no-password -v ON_ERROR_STOP=1)
case "$1" in
  before-restart)
    "${sql[@]}" -f infra/local-db/qualification/provider-assertions.sql
    "${sql[@]}" -v seed=true -f infra/local-db/qualification/provider-restart.sql ;;
  after-restart)
    "${sql[@]}" -v seed=false -f infra/local-db/qualification/provider-restart.sql ;;
  unavailable)
    if "${sql[@]}" -c 'select 1' >/dev/null 2>&1; then
      echo 'Fixture unexpectedly reachable after stop.' >&2; exit 1
    fi ;;
  *) exit 2 ;;
esac
