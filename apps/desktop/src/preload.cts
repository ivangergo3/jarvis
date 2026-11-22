import electron = require('electron');
const {contextBridge, ipcRenderer} = electron;

interface ShellInfo {
  readonly mode: 'fixture';
  readonly version: 1;
}

async function readShellInfo(...args: readonly unknown[]): Promise<ShellInfo> {
  if (args.length !== 0)
    throw new TypeError('Unexpected fixture information arguments');
  const value: unknown = await ipcRenderer.invoke('jarvis:read-shell-info');
  if (
    typeof value !== 'object' ||
    value === null ||
    !('mode' in value) ||
    value.mode !== 'fixture' ||
    !('version' in value) ||
    value.version !== 1 ||
    Object.keys(value).length !== 2
  ) {
    throw new TypeError('Invalid fixture information');
  }
  return {mode: value.mode, version: value.version};
}

if (process.isMainFrame) {
  contextBridge.exposeInMainWorld('jarvisPreview', {readShellInfo});
}
