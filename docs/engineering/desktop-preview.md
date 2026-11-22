# Run Jarvis Preview on macOS

Use Node 24.19.0 and pnpm 10.7.1 from the repository root.

```sh
pnpm install --frozen-lockfile
pnpm desktop:package
```

The final output line gives the absolute path to `Jarvis Preview.app`. Open that bundle in Finder or pass its path to `open`. Each packaging run creates a new output directory under `.build/desktop-previews/`. Packaging downloads the pinned Electron runtime for the host architecture on the first run. To reuse a local copy of the official Electron archive for your Mac, set `JARVIS_ELECTRON_ZIP_DIR` to its directory.

The window shows a synthetic workspace. Select **Observatory**, then **Sessions** to see **Shell verification**. Use **All projects** to return to the workspace. The preview uses bundle identifier `dev.greg.jarvis.preview` and its own `Jarvis Preview` application-support directory.

The build uses an ad-hoc signature for local development. Developer ID distribution and notarization require separate qualification.
