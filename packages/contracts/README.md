# Local wire contracts

The browser and backend import stable typed IDs and wire values from `@jarvis/contracts`. A request names its entire destination by ID, including its worker generation and request revision. IDs use a canonical lowercase UUID. General command IDs are random version 4 UUIDs. Timestamps use UTC with three fractional digits. Decimal cursors fit a signed 64-bit counter, with zero as the initial cursor. Revisions and event sequences start at one.

The pinned Zod 4.6.7 declarations reference the WHATWG URL type. The pnpm patch gives Zod’s URL helpers a module-local type when the consumer compiles with only ES2023 libraries. Consumers with native URL declarations retain that type. The patch changes only TypeScript declarations.
