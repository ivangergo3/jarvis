import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {mkdtempSync, readFileSync, rmSync, writeFileSync} from 'node:fs';
import {tmpdir} from 'node:os';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {test} from 'vitest';
import {parse} from 'yaml';

test('Compose publishes only the explicit loopback DB and gateway bindings', () => {
  const file = new URL('../../infra/local-db/compose.yaml', import.meta.url);
  const {services} = parse(readFileSync(file, 'utf8'));
  assert.deepEqual(Object.keys(services).sort(), ['auth', 'db', 'gateway']);
  assert.deepEqual(services.db.ports, ['127.0.0.1:${JARVIS_DB_PORT:?}:5432']);
  assert.deepEqual(services.gateway.ports, [
    '127.0.0.1:${JARVIS_API_PORT:?}:8000',
  ]);
  assert.deepEqual(services.auth.ports ?? [], []);
  assert.equal(services.auth.environment.GOTRUE_DISABLE_SIGNUP, 'true');
  assert.equal(services.gateway.environment.KONG_ADMIN_LISTEN, 'off');
  assert.deepEqual(services.db.entrypoint, [
    '/bin/sh',
    '/opt/jarvis/start-postgres.sh',
  ]);
  assert.ok(
    services.db.volumes.includes(
      './start-postgres.sh:/opt/jarvis/start-postgres.sh:ro',
    ),
  );
  assert.deepEqual(services.db.healthcheck.test, [
    'CMD',
    'pg_isready',
    '-h',
    '127.0.0.1',
    '-U',
    'postgres',
    '-d',
    'postgres',
  ]);
  assert.deepEqual(services.db.command, [
    'postgres',
    '-D',
    '/etc/postgresql',
    '-c',
    'log_statement=none',
    '-c',
    'log_min_error_statement=panic',
    '-c',
    'log_min_duration_statement=-1',
  ]);
  assert.equal(
    services.auth.environment.GOTRUE_DB_DATABASE_URL,
    'postgres://supabase_auth_admin@db:5432/postgres',
  );
  assert.equal(
    services.auth.environment.PGPASSWORD,
    '${JARVIS_AUTH_PASSWORD:?}',
  );
  for (const [name, image] of Object.entries({
    db: 'postgres',
    auth: 'gotrue',
    gateway: 'kong',
  })) {
    const service = services[name];
    assert.ok(
      service.image.startsWith('public.ecr.aws/supabase/' + image + '@'),
    );
    assert.equal(service.network_mode, undefined);
    assert.match(service.image, /@sha256:[a-f0-9]{64}$/);
  }
});

test('database bootstrap validates the generated password before touching a volume', (t) => {
  const root = mkdtempSync(path.join(tmpdir(), 'jarvis-image-probe-'));
  t.onTestFinished(() => rmSync(root, {recursive: true, force: true}));
  const entry = fileURLToPath(
    new URL('../../infra/local-db/start-postgres.sh', import.meta.url),
  );
  writeFileSync(
    path.join(root, 'docker-entrypoint.sh'),
    '#!/bin/sh\nprintf "%s\\n" "$@"\n',
    {mode: 0o700},
  );
  const run = (password) =>
    spawnSync('/bin/sh', [entry, 'postgres', '-D', '/etc/postgresql'], {
      encoding: 'utf8',
      env: {PATH: root, POSTGRES_PASSWORD: password},
    });
  for (const password of [
    '',
    'a'.repeat(63),
    'a'.repeat(65),
    'A'.repeat(64),
    "'" + 'a'.repeat(63),
  ]) {
    const failure = run(password);
    assert.equal(failure.status, 64);
    assert.equal(failure.stdout, '');
    assert.equal(
      failure.stderr.trim(),
      'Expected a Jarvis-generated database password.',
    );
  }
  const accepted = run('19af'.repeat(16));
  assert.equal(accepted.status, 0);
  assert.equal(accepted.stdout, 'postgres\n-D\n/etc/postgresql\n');
});
