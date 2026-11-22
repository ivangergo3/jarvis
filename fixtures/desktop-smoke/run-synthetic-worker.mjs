import {runPackagedSmoke} from '../../scripts/desktop/smoke.mjs';

// Production validates the signed bundle before calling the same supervisor.
process.exitCode = await runPackagedSmoke(
  process.argv[2],
  Number(process.argv[3]),
  process.env.JARVIS_SMOKE_EVIDENCE_DIR,
);
