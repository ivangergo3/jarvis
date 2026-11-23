# Local session repository qualification

After applying the installation and project migration, the session repository migration
creates the private `jarvis_repository` group. Grant this group only to a dedicated
backend database login. The backend supplies the verified local Supabase owner UUID
separately from the validated command. The server supplies the original Auth session, controller epoch and its canonical command fingerprint. The database checks the original request on retries and commits its public event and receipt atomically.
Keep the backend login out of Electron renderers, mobile clients and the Data API.

Start record mutations with `BEGIN ISOLATION LEVEL READ COMMITTED`. After a
concurrent writer commits, the waiting command reads its receipt in a fresh
statement snapshot. The database rejects other isolation levels before writing.

Use PostgreSQL server tools on PATH. Run the following from the repository root to
qualify the migration in a fresh Unix-socket-only cluster with synthetic Auth users:

```sh
bash infra/local-db/qualification/session-postgres.sh
```

The script retains its temporary directory on failure. It verifies concurrent duplicate
session creation, project creation, durable refusals, command conflicts, owner scoping, contiguous event sequences, rollback
of an injected late failure, client-role restrictions and persistence after a server restart.
An optional executable receives the stages `before-restart`, `after-restart` and
`unavailable` with the fixture backend login and socket. The repository adapter uses
these stages to check its typed results and database error mapping.
