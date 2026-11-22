import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
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
  for (const service of Object.values(services)) {
    assert.equal(service.network_mode, undefined);
    assert.match(service.image, /@sha256:[a-f0-9]{64}$/);
  }
});
