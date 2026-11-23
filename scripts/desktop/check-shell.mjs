import assert from 'node:assert/strict';
import path from 'node:path';
import {chromium, expect} from '@playwright/test';

async function checkShell(state, profile, evidence) {
  // Only attach to the ephemeral loopback endpoint emitted by our owned app.
  const browser = await chromium.connectOverCDP(state.endpoint, {
    noDefaults: true,
    timeout: 10_000,
    artifactsDir: path.join(path.dirname(profile), 'playwright-artifacts'),
  });
  try {
    const url = 'jarvis-preview://fixture/index.html';
    const findPage = () =>
      browser
        .contexts()
        .flatMap((context) => context.pages())
        .find((page) => page.url() === url);
    await expect.poll(() => Boolean(findPage())).toBe(true);
    const page = findPage();
    const startupErrors = [];
    page.on('pageerror', (error) => startupErrors.push(error.message));
    page.setDefaultTimeout(10_000);
    await expect(
      page.getByRole('heading', {name: 'Synthetic workspace'}),
    ).toBeVisible();
    await expect
      .poll(() => state.window)
      .toEqual({
        packaged: true,
        visible: true,
        sandboxed: true,
        profile,
        sessionData: profile,
      });
    const isolation = await page.evaluate(async () => ({
      node: typeof window.require,
      process: typeof window.process,
      bridge: Object.keys(window.jarvisPreview),
      information: await window.jarvisPreview.readShellInfo(),
      rejectedArguments: await window.jarvisPreview
        .readShellInfo('unexpected')
        .then(
          () => false,
          () => true,
        ),
      popupDenied: window.open('about:blank') === null,
    }));
    assert.deepEqual(isolation, {
      node: 'undefined',
      process: 'undefined',
      bridge: ['readShellInfo'],
      information: {mode: 'fixture', version: 1},
      rejectedArguments: true,
      popupDenied: true,
    });
    await page.screenshot({path: path.join(evidence, 'workspace.png')});
    await page.getByRole('link', {name: 'Observatory'}).click();
    await expect(
      page.getByRole('heading', {name: 'Observatory'}),
    ).toBeVisible();
    await page.getByRole('button', {name: 'Sessions'}).click();
    await expect(
      page.getByText('Shell verification', {exact: true}),
    ).toBeVisible();
    const session = page.getByRole('button', {name: /Shell verification/});
    await expect(
      page.getByRole('button', {name: 'Graph', exact: true}),
    ).toHaveAttribute('aria-pressed', 'true');
    await expect
      .poll(() =>
        page
          .locator('.team-reactor')
          .evaluate((image) => image.complete && image.naturalWidth > 0),
      )
      .toBe(true);
    await page.getByRole('button', {name: 'Cards', exact: true}).focus();
    await page.keyboard.press('Tab');
    await expect(session).toBeFocused();
    await page.keyboard.press('Enter');
    await expect(session).toHaveAttribute('aria-pressed', 'true');
    const endpointError = await session.evaluate((card) => {
      const canvas = card.closest('.team-canvas');
      const wire = canvas.querySelector('polyline.selected');
      const endpoint = wire.points.getItem(wire.points.numberOfItems - 1);
      const point = new DOMPoint(endpoint.x, endpoint.y).matrixTransform(
        wire.getScreenCTM(),
      );
      const rect = card.getBoundingClientRect();
      return Math.max(
        Math.min(Math.abs(point.x - rect.left), Math.abs(point.x - rect.right)),
        Math.abs(point.y - (rect.top + rect.height / 2)),
      );
    });
    assert.ok(
      endpointError <= 1,
      'The highlighted connector must reach the selected card edge',
    );
    await page.getByRole('button', {name: 'Cards', exact: true}).click();
    await expect(session).toHaveAttribute('aria-pressed', 'true');
    await expect(page.locator('.team-wires')).toHaveCount(0);
    await page.getByRole('button', {name: 'Graph', exact: true}).click();
    await expect(session).toHaveAttribute('aria-pressed', 'true');
    await expect(session.locator('.team-port')).toBeVisible();
    const originalViewport = await page.evaluate(() => ({
      width: innerWidth,
      height: innerHeight,
    }));
    await page.setViewportSize({width: 480, height: 360});
    await expect
      .poll(() =>
        page
          .locator('.team-viewport')
          .evaluate(
            (viewport) =>
              window.innerWidth === 480 &&
              viewport.clientWidth > 0 &&
              viewport.clientWidth <= window.innerWidth &&
              viewport.querySelector('.team-canvas').clientWidth ===
                viewport.clientWidth,
          ),
      )
      .toBe(true);
    await expect
      .poll(() =>
        session.locator('strong').evaluate((label) => {
          const box = label.getBoundingClientRect();
          const range = document.createRange();
          range.selectNodeContents(label);
          return [...range.getClientRects()].every(
            (rect) =>
              rect.left >= box.left - 1 &&
              rect.right <= box.right + 1 &&
              rect.bottom <= box.bottom + 1,
          );
        }),
      )
      .toBe(true);
    // Move a physical wheel over the scrollport after its own vertical range
    // has been exhausted. The rest of the window must remain reachable.
    const wheel = await page.locator('.team-viewport').evaluate((el) => {
      el.scrollIntoView({block: 'start'});
      el.scrollTop = el.scrollHeight;
      const rect = el.getBoundingClientRect();
      const x = rect.left + Math.min(24, rect.width / 2);
      const y = Math.max(0, rect.top) + 16;
      if (!el.contains(document.elementFromPoint(x, y)))
        throw new Error('Wheel target is hidden');
      return {x, y, start: document.scrollingElement.scrollTop};
    });
    await page.mouse.move(wheel.x, wheel.y);
    await page.mouse.wheel(0, 240);
    await expect
      .poll(() => page.evaluate(() => document.scrollingElement.scrollTop))
      .toBeGreaterThan(wheel.start);
    await page.setViewportSize(originalViewport);
    await page.screenshot({path: path.join(evidence, 'project.png')});
    const destinations = [
      'jarvis-preview://fixture/navigation-check',
      'https://jarvis-preview.invalid/navigation-check',
    ];
    for (const destination of destinations) {
      await page.evaluate(
        (target) => window.location.assign(target),
        destination,
      );
      await expect.poll(() => state.denied).toBe(destination);
      assert.equal(page.url(), url);
    }
    assert.deepEqual(startupErrors, []);
    const navigateFixture = (target) =>
      page.evaluate(
        (url) => window.location.assign(url),
        url.replace('/index.html', '/' + target),
      );
    await navigateFixture('minimize-for-verification');
    await expect
      .poll(() => state.visibility)
      .toMatchObject({minimized: true, focused: false, windows: 1});
    await expect
      .poll(() => page.evaluate(() => document.hasFocus()))
      .toBe(false);
    await navigateFixture('activate-for-verification');
    let restored;
    await expect
      .poll(async () => {
        const native = state.visibility;
        if (
          !native ||
          native.minimized ||
          !native.visible ||
          !native.focused ||
          native.windows !== 1
        )
          return false;
        const rendererFocused = await page.evaluate(() => document.hasFocus());
        const projectVisible = await page
          .getByText('Shell verification', {exact: true})
          .isVisible();
        if (native !== state.visibility || !rendererFocused || !projectVisible)
          return false;
        restored = {...native};
        return true;
      })
      .toBe(true);
    await page.close();
    return {
      packaged: true,
      visible: true,
      sandboxed: true,
      privateProfile: true,
      isolation,
      url,
      blockedDestinations: destinations,
      restoredFromMinimized: restored,
    };
  } finally {
    // An attached browser disconnects from the remote endpoint on close.
    await browser.close();
  }
}

if (!process.send) throw new Error('Expected the packaged preview supervisor.');
const [profile, evidence] = process.argv.slice(2);
const disconnected = () => process.exit(1);
process.once('disconnect', disconnected);
const state = {};
process.on('message', async (message) => {
  if (message.visibility) {
    state.visibility = message.visibility;
    return;
  }
  if (message.denied) {
    state.denied = message.denied;
    return;
  }
  if (!message.start || state.endpoint) return;
  Object.assign(state, message.start);
  try {
    const receipt = await checkShell(state, profile, evidence);
    await new Promise((resolve, reject) =>
      process.send({receipt}, (error) => (error ? reject(error) : resolve())),
    );
  } catch (error) {
    process.exitCode = 1;
    if (process.connected) process.send({error: error.message});
  } finally {
    process.removeListener('disconnect', disconnected);
    if (process.connected) process.disconnect();
  }
});
