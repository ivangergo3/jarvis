import {execFileSync, spawnSync} from 'node:child_process';
import path from 'node:path';

export function verifyPreviewBundle(appPath) {
  const info = JSON.parse(
    execFileSync(
      '/usr/bin/plutil',
      [
        '-convert',
        'json',
        '-o',
        '-',
        path.join(appPath, 'Contents/Info.plist'),
      ],
      {encoding: 'utf8'},
    ),
  );
  if (
    info.CFBundleIdentifier !== 'dev.greg.jarvis.preview' ||
    info.CFBundleExecutable !== 'Jarvis Preview'
  ) {
    throw new Error('Expected the dev.greg.jarvis.preview macOS bundle.');
  }
  execFileSync('/usr/bin/lipo', [
    path.join(appPath, 'Contents/MacOS', info.CFBundleExecutable),
    '-verify_arch',
    process.arch === 'arm64' ? 'arm64' : 'x86_64',
  ]);
  const details = spawnSync(
    '/usr/bin/codesign',
    ['--display', '--verbose=2', appPath],
    {encoding: 'utf8'},
  );
  if (details.status !== 0 || !/^Signature=adhoc$/m.test(details.stderr)) {
    throw new Error('Expected the local preview’s ad-hoc signature.');
  }
  execFileSync('/usr/bin/codesign', [
    '--verify',
    '--deep',
    '--strict',
    appPath,
  ]);
}
