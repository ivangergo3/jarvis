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
    "${sql[@]}" -v seed=false -f infra/local-db/qualification/provider-restart.sql
    "${sql[@]}" -v writer=false -f infra/local-db/qualification/provider-retraction.sql
    ledger="$PGHOST/postgres-events.jsonl"
    for owner in 10000000-0000-4000-8000-000000000001 10000000-0000-4000-8000-000000000002; do
      "${sql[@]}" -qAt -c 'begin' -c "set local jarvis.owner_id='$owner'" \
        -c 'select envelope from jarvis.events order by sequence' -c 'commit'
    done > "$ledger"
    pnpm --filter @jarvis/contracts run build
    pnpm --filter @jarvis/contracts exec node --input-type=module - "$ledger" < infra/local-db/qualification/decode-replay.mjs ;;
  unavailable)
    if "${sql[@]}" -c 'select 1' >/dev/null 2>&1; then
      echo 'Fixture unexpectedly reachable after stop.' >&2; exit 1
    fi ;;
  *) exit 2 ;;
esac
