import assert from "node:assert/strict";
import { workspaceGreeting } from "@jarvis/workspace-fixture";

const greeting = workspaceGreeting("the Jarvis workspace");
assert.equal(greeting, "Hello from the Jarvis workspace.");
console.log(greeting);
