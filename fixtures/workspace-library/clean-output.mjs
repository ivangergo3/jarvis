import { rmSync } from "node:fs";

// The fixture package owns this generated directory on cache hits and misses.
rmSync(new URL("./dist/", import.meta.url), { recursive: true, force: true });
