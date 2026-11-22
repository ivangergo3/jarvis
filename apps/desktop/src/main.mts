import {app, BrowserWindow, ipcMain, net, protocol, session} from 'electron';
import {lstatSync, readdirSync, realpathSync} from 'node:fs';
import {tmpdir} from 'node:os';
import path from 'node:path';
import {pathToFileURL} from 'node:url';

const scheme = 'jarvis-preview';
const documentUrl = 'jarvis-preview://fixture/index.html';
app.setName('Jarvis Preview');
const smoke = app.commandLine.hasSwitch('jarvis-fixture-smoke');
const profile = smoke
  ? app.commandLine.getSwitchValue('jarvis-fixture-smoke')
  : path.join(app.getPath('appData'), 'Jarvis Preview');
if (smoke) {
  const directory = lstatSync(profile, {throwIfNoEntry: false});
  const name = path.basename(profile);
  if (
    path.dirname(profile) !== path.resolve(tmpdir()) ||
    !/^jarvis-preview-smoke-[A-Za-z0-9]{6}$/.test(name) ||
    !directory?.isDirectory() ||
    directory.uid !== process.getuid?.() ||
    (directory.mode & 0o077) !== 0 ||
    realpathSync(profile) !== path.join(realpathSync(tmpdir()), name) ||
    readdirSync(profile).length !== 0
  ) {
    console.error('Expected a private empty Jarvis Preview smoke profile.');
    process.exit(1);
  }
}
app.setPath('userData', profile);
app.setPath('sessionData', profile);
app.enableSandbox();
protocol.registerSchemesAsPrivileged([
  {scheme, privileges: {standard: true, secure: true}},
]);

let shell: BrowserWindow | undefined;

async function startShell() {
  const root = app.isPackaged
    ? path.join(app.getAppPath(), 'renderer')
    : path.join(app.getAppPath(), '../client/dist');
  const files = new Map([['/index.html', path.join(root, 'index.html')]]);
  for (const entry of readdirSync(path.join(root, 'assets'), {
    withFileTypes: true,
  })) {
    if (
      entry.isFile() &&
      (/\.(css|js)$/.test(entry.name) ||
        /^reactor-[\w-]+\.png$/.test(entry.name))
    ) {
      files.set('/assets/' + entry.name, path.join(root, 'assets', entry.name));
    }
  }
  const isolated = session.fromPartition('jarvis-preview-fixture');
  isolated.setPermissionCheckHandler(() => false);
  isolated.setPermissionRequestHandler((_contents, _permission, callback) =>
    callback(false),
  );
  isolated.on('will-download', (event) => event.preventDefault());
  isolated.protocol.handle(scheme, (request) => {
    const url = new URL(request.url);
    const file = files.get(url.pathname);
    if (
      request.method !== 'GET' ||
      url.host !== 'fixture' ||
      url.username ||
      url.password ||
      url.search ||
      !file
    )
      return new Response(null, {status: 404});
    return net.fetch(pathToFileURL(file).href);
  });
  shell = new BrowserWindow({
    title: 'Jarvis Preview',
    width: 940,
    height: 620,
    minWidth: 480,
    minHeight: 360,
    backgroundColor: '#081117',
    show: false,
    webPreferences: {
      session: isolated,
      preload: path.join(import.meta.dirname, 'preload.cjs'),
      sandbox: true,
      contextIsolation: true,
      nodeIntegration: false,
      webviewTag: false,
      webSecurity: true,
    },
  });
  const window = shell;
  window.webContents.setWindowOpenHandler(() => ({action: 'deny'}));
  window.webContents.on('will-frame-navigate', (event) => {
    event.preventDefault();
    if (smoke) {
      console.log('JARVIS_SMOKE_DENIED ' + JSON.stringify(event.url));
    }
  });
  window.webContents.on('will-attach-webview', (event) =>
    event.preventDefault(),
  );
  ipcMain.handle(
    'jarvis:read-shell-info',
    (event, ...args: readonly unknown[]) => {
      if (
        window.isDestroyed() ||
        event.sender !== window.webContents ||
        event.senderFrame !== window.webContents.mainFrame ||
        event.senderFrame.url !== documentUrl ||
        args.length !== 0
      )
        throw new Error('Invalid desktop request');
      return {mode: 'fixture', version: 1} as const;
    },
  );
  window.on('closed', () => {
    shell = undefined;
  });
  window.once('ready-to-show', () => {
    window.show();
    if (smoke) {
      const renderer = app
        .getAppMetrics()
        .find((item) => item.pid === window.webContents.getOSProcessId());
      console.log(
        'JARVIS_SMOKE_WINDOW ' +
          JSON.stringify({
            packaged: app.isPackaged,
            visible: window.isVisible(),
            sandboxed: renderer?.sandboxed,
            profile: app.getPath('userData'),
            sessionData: app.getPath('sessionData'),
          }),
      );
    }
  });
  await window.loadURL(documentUrl);
}

app.on('window-all-closed', () => app.quit());
app
  .whenReady()
  .then(startShell)
  .catch(() => {
    console.error('The Jarvis Preview fixture could not start.');
    app.exit(1);
  });
