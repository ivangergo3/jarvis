import assert from 'node:assert/strict';
import {isBuiltin, registerHooks} from 'node:module';

// Model a renderer that has no Node polyfills. Only imports from the case's
// public contract are constrained; the host still runs the test under Node.
const contract = new URL('./packages/contracts/src/index.ts', import.meta.url)
  .href;
registerHooks({
  resolve(specifier, context, nextResolve) {
    if (context.parentURL === contract && isBuiltin(specifier)) {
      throw new Error(
        `Renderer cannot load ${specifier} from the public contract`,
      );
    }
    return nextResolve(specifier, context);
  },
});

const {canSendDraft} = await import('./apps/client/src/draft.ts');
assert.equal(canSendDraft('project-a', 'chat-a', 'Ready'), true);
assert.equal(canSendDraft('project-a', 'chat-a', ''), false);
