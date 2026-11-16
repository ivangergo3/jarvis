# Swift verification at affected boundaries

Read current repository settings first: Swift compiler/toolchain version, language mode, strict-concurrency settings, deployment target and build configuration are distinct. A Swift 6 toolchain building Swift 5 mode does not establish Swift 6 checking. Preserve the supported OS and availability fallbacks. Migration is separate work unless authorized.

Keep UI-observable state on its appropriate actor, with explicit task ownership and cancellation. Avoid blocking I/O on the main actor. Review captures and values crossing isolation boundaries, reentrancy after `await`, stale results after navigation, ordering, child-process lifetime and cleanup after cancellation. `Task.detached`, `@unchecked Sendable`, `nonisolated(unsafe)` and blanket isolation annotations need a concrete ownership justification, not a comment to quiet the compiler. Do not add them as a blanket fix.

Use narrow error handling and safe decoding for external files/protocols. Bound retained events, streams and retries. Prefer typed states to booleans that permit contradictory lifecycle states. Review force unwraps/casts at untrusted boundaries for reachable crashes; do not replace errors with empty successful results.

Use the repository's chosen formatter in check mode and supported compiler settings; report checks that are not configured. Run focused Swift Testing or existing unit/integration tests for logic, and XCTest/XCUIAutomation or native interaction for affected UI/performance surfaces as appropriate. A SwiftPM unit suite does not imply an app UI test target exists. Confirm discovery and the artifact actually launched. Check cancellation, stale-result suppression, permission-denied/empty states and keyboard/accessibility behaviour where relevant. Profile performance claims against a comparable baseline.

Do not broaden filesystem permissions, activate microphones, send model turns or install a new toolchain implicitly to make a check pass. Use synthetic fixtures and label unavailable native checks. Fix causes without weakening settings; a narrowly justified exception remains visible with a compensating check and review/removal condition.

Primary references (recheck version-sensitive guidance when implementing): [Swift migration](https://www.swift.org/migration/documentation/migrationguide/), [Swift concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/), [swift-format](https://github.com/swiftlang/swift-format), [Apple testing](https://developer.apple.com/documentation/xcode/testing).
