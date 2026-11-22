import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {createReadStream} from 'node:fs';
import {mkdir, mkdtemp, readFile, writeFile} from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {packager} from '@electron/packager';

const checksums = new Map([
  ['arm64', 'd080c3b05a01bd16137f2c12ab9ebf083c577757fe846844ba325bafa8e8bdf4'],
  ['x64', '1c80d2ccf71b02c8fd9940fd09cafe88090a48c1bab0193c79b597b08d890e79'],
]);
const checksum = checksums.get(process.arch);
if (process.platform !== 'darwin' || !checksum)
  throw new Error('The desktop preview requires Apple Silicon or Intel macOS.');
if (process.argv.length !== 2)
  throw new Error('Expected no packaging options.');
const root = fileURLToPath(new URL('../../', import.meta.url));
const desktop = path.join(root, 'apps/desktop');
const manifest = JSON.parse(
  await readFile(path.join(desktop, 'package.json'), 'utf8'),
);
const version = manifest.devDependencies.electron;
const parent = path.join(root, '.build/desktop-previews');
await mkdir(parent, {recursive: true});
const attempt = await mkdtemp(path.join(parent, 'build-'));
const stage = path.join(attempt, 'input');
await mkdir(stage);
function compile(member, args) {
  execFileSync('pnpm', ['--filter', member, 'exec', ...args], {
    cwd: root,
    stdio: 'inherit',
  });
}
// Build into this invocation's fresh staging tree. Other package and workspace
// builds can write their normal dist/ outputs while this bundle is assembled.
compile('@jarvis/client', ['tsc', '-p', 'tsconfig.json', '--noEmit']);
compile('@jarvis/client', [
  'vite',
  'build',
  '--base',
  './',
  '--outDir',
  path.join(stage, 'renderer'),
]);
compile('@jarvis/desktop', [
  'tsc',
  '-p',
  'tsconfig.json',
  '--outDir',
  path.join(stage, 'dist'),
]);
await writeFile(
  path.join(stage, 'package.json'),
  JSON.stringify({
    name: 'jarvis-preview',
    productName: 'Jarvis Preview',
    version: manifest.version,
    main: 'dist/main.mjs',
  }),
);
const electronZipDir = process.env.JARVIS_ELECTRON_ZIP_DIR;
if (electronZipDir) {
  const archive = path.join(
    electronZipDir,
    'electron-v' + version + '-darwin-' + process.arch + '.zip',
  );
  const hash = createHash('sha256');
  for await (const chunk of createReadStream(archive)) hash.update(chunk);
  if (hash.digest('hex') !== checksum) {
    throw new Error(
      'Cached Electron archive does not match the official 45.4.1 checksum.',
    );
  }
}
const [output] = await packager({
  dir: stage,
  out: path.join(attempt, 'output'),
  name: 'Jarvis Preview',
  appBundleId: 'dev.greg.jarvis.preview',
  helperBundleId: 'dev.greg.jarvis.preview.helper',
  icon: path.join(root, 'Resources/AppIcon.icns'),
  platform: 'darwin',
  arch: process.arch,
  electronVersion: version,
  ...(electronZipDir && {electronZipDir}),
  osxSign: {
    identity: '-',
    identityValidation: false,
    continueOnError: false,
    preAutoEntitlements: false,
    preEmbedProvisioningProfile: false,
    // The development-only ad-hoc identity has no Apple team identifier.
    optionsForFile: () => ({
      hardenedRuntime: false,
      entitlements: [],
      timestamp: 'none',
    }),
  },
  asar: true,
  prune: false,
  appCategoryType: 'public.app-category.developer-tools',
});
const appPath = path.join(output, 'Jarvis Preview.app');
console.log(appPath);
