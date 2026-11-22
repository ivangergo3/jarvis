import {execFileSync, spawnSync} from 'node:child_process';
import path from 'node:path';

// An Intel Node process can run under Rosetta. Probe the host independently so
// the local preview always targets the architecture that can run it natively.
export function previewArchitecture() {
  if (process.platform !== 'darwin') {
    throw new Error('The desktop preview requires macOS.');
  }
  for (const [arch, nodeArch] of [
    ['arm64', 'arm64'],
    ['x86_64', 'x64'],
  ]) {
    if (spawnSync('/usr/bin/arch', ['-' + arch, '/usr/bin/true']).status === 0)
      return nodeArch;
  }
  throw new Error('Unable to determine the host macOS architecture.');
}

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
    previewArchitecture() === 'arm64' ? 'arm64' : 'x86_64',
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
