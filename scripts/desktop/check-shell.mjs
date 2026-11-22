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
    await expect
      .poll(() => state.visibility)
      .toEqual({minimized: false, focused: true, visible: true, windows: 1});
    await expect
      .poll(() => page.evaluate(() => document.hasFocus()))
      .toBe(true);
    await expect(
      page.getByText('Shell verification', {exact: true}),
    ).toBeVisible();
    state.visibilityAtReopen = {...state.visibility};
    await page.close();
    return {
      packaged: true,
      visible: true,
      sandboxed: true,
      privateProfile: true,
      isolation,
      url,
      blockedDestinations: destinations,
      restoredFromMinimized: state.visibilityAtReopen,
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
