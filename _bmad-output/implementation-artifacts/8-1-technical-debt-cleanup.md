# Story 8.1: Technical Debt Cleanup

Status: done

## Story

As a developer and maintainer,
I want to clean up all known deferred work and technical debt in a single pass,
so that the codebase is in a healthy, safe, and maintainable state before any further development.

## Acceptance Criteria

### AC#1: Eliminate all force-unwrap `data(using: .utf8)!`

**Given** 16 instances of `.data(using: .utf8)!` force-unwrap exist across CLI source files
**When** the cleanup is performed
**Then** all force-unwraps are replaced with a safe `writeToStderr(_:)` helper or `?? Data()` fallback
**And** all existing tests pass

Files and exact occurrences (line numbers from current source):
- `CLI.swift` -- 9 occurrences (lines 30, 48, 55, 87, 93, 112, 162, 219, 234)
- `ConfigLoader.swift` -- 4 occurrences (lines 192, 269, 278, 297)
- `AgentFactory.swift` -- 3 occurrences (lines 199, 207, 211)

Proposed solution: Create a `writeToStderr(_:)` helper in `ANSI.swift` (or a new `StdioHelpers.swift`) that centralizes safe stderr writing.

### AC#2: Fix handleFork / handleResume ParsedArgs field omission

**Given** a user has explicitly set parameters via `--model` and `--baseURL`
**When** `/fork` or `/resume` is executed
**Then** the new Agent preserves all user-explicitly-set parameters (`explicitlySet` set copied completely)
**And** `stdin` field is correctly passed (though fork/resume doesn't use stdin, maintain data integrity)

Files: `REPLLoop.swift` -- `handleFork()` (line ~368) and `handleResume()` (line ~590)

Proposed solution: Use struct copy (`var copy = args; copy.sessionId = newId`) instead of manual field-by-field construction.

### AC#3: Fix stdin infinite blocking on terminal

**Given** a user runs `openagent --stdin` without piping input
**When** stdin is a terminal (tty)
**Then** an error message is displayed within a reasonable timeout (e.g., 3 seconds) and the CLI exits
**Or** on startup, `isatty()` is detected and terminal stdin shows a clear error and exits

Files: `CLI.swift` -- `readStdin()` function (line ~192)

Proposed solution: Add `isatty(STDIN_FILENO)` check; terminal stdin should directly report error and exit.

### AC#4: Fix --stdin + --skill combination undefined behavior

**Given** a user passes both `--stdin` and `--skill`
**When** CLI starts
**Then** a clear error message is displayed: "Cannot use --stdin and --skill together"
**And** the process exits with code 1

Files: `CLI.swift` -- argument validation stage

### AC#5: Fix single-shot + default/plan mode silently denying write tools

**Given** a user runs `openagent --mode default "help me create a file"`
**When** the Agent requests tool permission approval
**Then** in non-interactive mode, the system auto-approves all tools (equivalent to temporarily elevating to bypassPermissions)
**Or** displays a clear warning: "Permission approval requires interactive mode; running in bypassPermissions for this session"
**And** the exit code reflects the actual behavior

Files: `PermissionHandler.swift` or `CLI.swift`

### AC#6: Add Sendable conformance to CostTracker

**Given** the project may migrate to Swift 6 strict concurrency mode in the future
**When** the compiler checks Sendable conformance
**Then** `CostTracker` satisfies conformance via `@unchecked Sendable` or actor isolation
**And** existing functionality is unaffected

Files: `REPLLoop.swift` -- `CostTracker` class (line ~50)

### AC#7: Clean up orphaned fork sessions

**Given** `/fork` is executed and `SessionStore.fork()` succeeds but `AgentFactory.createAgent()` fails
**When** the error occurs
**Then** the system attempts to delete the just-created orphaned session
**And** a friendly error message is shown to the user
**And** the original session is unaffected

Files: `REPLLoop.swift` -- `handleFork()`

## Tasks / Subtasks

- [x] Task 1: Create safe stderr writing helper (AC: #1)
  - [x] Add `writeToStderr(_:)` helper function in `ANSI.swift` (or new `StdioHelpers.swift`)
  - [x] Replace all 16 `FileHandle.standardError.write(...data(using: .utf8)!)` calls with the safe helper
  - [x] Verify in `CLI.swift`, `ConfigLoader.swift`, `AgentFactory.swift`
  - [x] Run full test suite to confirm no regressions

- [x] Task 2: Simplify ParsedArgs copy in handleFork/handleResume (AC: #2)
  - [x] Refactor `handleFork()` to use `var forkArgs = args; forkArgs.sessionId = forkedId` instead of manual construction
  - [x] Refactor `handleResume()` similarly
  - [x] Verify that `explicitlySet`, `customTools`, and all other fields are preserved
  - [x] Add/update regression tests for fork and resume with explicitly set parameters

- [x] Task 3: Add isatty() check for --stdin (AC: #3)
  - [x] In `CLI.swift` `readStdin()` or before its call, add `isatty(STDIN_FILENO)` check
  - [x] When stdin is a terminal, display error: "Error: --stdin requires piped input. Use 'echo \"text\" | openagent --stdin'."
  - [x] Exit with code 1
  - [x] Add test to `StdinInputTests.swift`

- [x] Task 4: Add --stdin + --skill mutual exclusion (AC: #4)
  - [x] In `ArgumentParser.swift` after argument parsing, check if both `args.stdin` and `args.skillName != nil`
  - [x] If both set, print error and exit with code 1
  - [x] Add test to `TechnicalDebtAC4Tests.swift`

- [x] Task 5: Fix non-interactive permission auto-approval (AC: #5)
  - [x] In `PermissionHandler.swift`, change non-interactive behavior from deny to auto-approve with warning
  - [x] Update `checkNonInteractive()` to return `.allow()` with a warning message instead of `.deny()`
  - [x] Add/update tests in `PermissionHandlerTests.swift` and `TechnicalDebtAC5Tests.swift`

- [x] Task 6: Add Sendable conformance to CostTracker (AC: #6)
  - [x] Mark `CostTracker` as `@unchecked Sendable` (it already uses class reference semantics for mutation within a struct)
  - [x] Verify it compiles without warnings
  - [x] No functional change expected

- [x] Task 7: Add orphan cleanup to handleFork (AC: #7)
  - [x] In `handleFork()`, wrap `AgentFactory.createAgent()` in a do/catch that calls `sessionStore.delete(sessionId:)` on failure
  - [x] Ensure the error message is user-friendly
  - [x] Add test in `TechnicalDebtAC7Tests.swift`

- [x] Task 8: Full regression verification (AC: #1-#7)
  - [x] Run `swift test` and confirm all tests pass
  - [x] Pay special attention to fork/resume path regression tests
  - [x] Verify no new force-unwraps were introduced

## Dev Notes

### Architecture Context

This is a technical debt story in the final Epic (Epic 8: Technical Debt & Validation). All prior epics (1-7) are complete or in-progress with all stories done. The 7 acceptance criteria address deferred items accumulated during code reviews across Stories 1-7.

The project is a Swift CLI built on top of OpenAgentSDK. Key architectural principles:
- **Thin orchestration layer** -- CLI parses input, delegates to SDK, renders output
- **Zero internal SDK access** -- only `import OpenAgentSDK`
- **Zero third-party dependencies** -- Foundation only
- **Protocol-based testability** -- `InputReading`, `OutputRendering`
- **One-type-per-file convention** -- PascalCase filenames matching type names

### Key Source Files

| File | Lines | Role |
|------|-------|------|
| `Sources/OpenAgentCLI/CLI.swift` | 237 | Top-level orchestrator, dispatches to REPL/single-shot/skill modes |
| `Sources/OpenAgentCLI/REPLLoop.swift` | 667 | Interactive loop, slash command handling, CostTracker |
| `Sources/OpenAgentCLI/PermissionHandler.swift` | 294 | `CanUseToolFn` closures for permission modes |
| `Sources/OpenAgentCLI/ConfigLoader.swift` | 300 | Loads `~/.openagent/config.json`, two-pass JSON loading |
| `Sources/OpenAgentCLI/AgentFactory.swift` | 407 | Creates SDK Agent from ParsedArgs, tool pool assembly |
| `Sources/OpenAgentCLI/ANSI.swift` | 52 | Terminal ANSI escape code helpers |
| `Sources/OpenAgentCLI/ArgumentParser.swift` | 361 | Custom CLI flag parsing |

### AC#1 Detail: Force-Unwrap Locations

All 16 occurrences follow the same pattern:
```swift
FileHandle.standardError.write("some string\n".data(using: .utf8)!)
```

The proposed helper should:
```swift
static func writeToStderr(_ message: String) {
    FileHandle.standardError.write(message.data(using: .utf8) ?? Data())
}
```

Place this in `ANSI.swift` (already has terminal output helpers) or create a small `StdioHelpers.swift`. Placing in `ANSI.swift` avoids creating a new file for a single function.

Note: Story 7.7's dev notes already identified this as a recurring pattern. The `?? Data()` fallback is safe because `String.data(using: .utf8)` only returns nil for strings with non-Unicode scalars, which is impossible with our hardcoded ASCII error messages.

### AC#2 Detail: Current ParsedArgs Copy Problem

The current `handleFork()` (REPLLoop.swift line ~368) and `handleResume()` (line ~590) manually construct a new `ParsedArgs` by listing every field:

```swift
var forkArgs = ParsedArgs(
    helpRequested: args.helpRequested,
    versionRequested: args.versionRequested,
    prompt: args.prompt,
    model: args.model,
    apiKey: args.apiKey,
    // ... 20+ fields ...
)
forkArgs.explicitlySet = args.explicitlySet
forkArgs.customTools = args.customTools
```

This is fragile -- every time a new field is added to `ParsedArgs`, these two call sites must be updated. The fix is simpler:

```swift
var forkArgs = args
forkArgs.sessionId = forkedId
```

Since `ParsedArgs` is a struct, `var forkArgs = args` creates a full copy. Then just override the `sessionId`. This automatically preserves `explicitlySet`, `customTools`, and any future fields.

**Risk:** Verify that `stdin` field is correctly passed. After fork/resume, `stdin` should be `false` (no re-reading stdin). The current manual construction sets it to the original value, but the struct copy approach also does this. Since fork/resume creates a new REPL loop, `stdin` being `true` shouldn't cause issues because the REPL reads from the terminal, not stdin. But verify this.

### AC#3 Detail: stdin Terminal Blocking

Current `readStdin()` in CLI.swift (line ~192):
```swift
static func readStdin() throws -> String? {
    let data = FileHandle.standardInput.readDataToEndOfFile()
    // ...
}
```

`readDataToEndOfFile()` blocks indefinitely when stdin is a terminal (no EOF). The fix is to check `isatty()` before calling it.

Import `Darwin` (macOS) or `Glibc` (Linux) for `isatty()` and `STDIN_FILENO`:
```swift
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

// In readStdin() or before calling it:
if isatty(STDIN_FILENO) != 0 {
    FileHandle.standardError.write("Error: --stdin requires piped input...\n".data(using: .utf8)!)
    Foundation.exit(1)
}
```

### AC#4 Detail: --stdin + --skill Mutual Exclusion

Both `--stdin` and `--skill` aim to provide the prompt content. `--stdin` reads from pipe, `--skill` invokes a skill's `promptTemplate`. Using both is ambiguous.

Validation should go in `CLI.swift` after `ArgumentParser.parse()` and before `readStdin()`:
```swift
if args.stdin && args.skillName != nil {
    FileHandle.standardError.write("Error: Cannot use --stdin and --skill together.\n")
    Foundation.exit(1)
}
```

### AC#5 Detail: Non-Interactive Permission Behavior

Current behavior in `PermissionHandler.swift` `checkNonInteractive()`:
```swift
private static func checkNonInteractive(...) -> CanUseToolResult? {
    guard !isInteractive else { return nil }
    let message = nonInteractiveDenialMessage(toolName: tool.name)
    renderer.output.write("\(ANSI.yellow("...")) \(message)\n")
    return .deny(message)
}
```

This denies tools in non-interactive mode (single-shot). But in single-shot mode, the user likely expects the agent to actually perform actions. The fix should auto-approve with a warning:

```swift
if !isInteractive {
    let message = "Non-interactive mode: auto-approving '\(tool.name)' (use --mode bypassPermissions to suppress this warning)."
    renderer.output.write("\(ANSI.yellow("...")) \(message)\n")
    return .allow()
}
```

Alternatively, elevate the entire session to `bypassPermissions` in `CLI.swift` when `args.prompt != nil` (single-shot). This is cleaner because it avoids per-tool warnings.

### AC#6 Detail: CostTracker Sendable

`CostTracker` is a simple class with mutable properties:
```swift
final class CostTracker {
    var cumulativeCostUsd: Double = 0.0
    var cumulativeInputTokens: Int = 0
    var cumulativeOutputTokens: Int = 0
    func reset() { ... }
}
```

It's used inside `REPLLoop` (a struct) and mutated from async contexts. Mark it `@unchecked Sendable`:
```swift
final class CostTracker: @unchecked Sendable {
```

This is safe because:
- It's only accessed from the main REPL loop (single concurrent access)
- No actual concurrent mutation occurs
- The `@unchecked` annotation documents the intentional decision

### AC#7 Detail: Orphaned Fork Sessions

Current `handleFork()` flow:
1. `store.fork(sourceSessionId:)` -- creates new session on disk
2. `AgentFactory.createAgent(from: forkArgs)` -- may throw
3. If step 2 throws, the forked session remains on disk (orphaned)

Fix:
```swift
do {
    let (newAgent, _) = try await AgentFactory.createAgent(from: forkArgs)
    // ... success path ...
} catch {
    // Clean up orphaned session
    if let store = sessionStore {
        try? await store.delete(sessionId: forkedId)  // Best-effort cleanup
    }
    renderer.output.write("Error creating forked session: \(error.localizedDescription)\n")
}
```

Check if `SessionStore` has a `delete(sessionId:)` method. If not, use file-system cleanup or log a warning that the orphan could not be cleaned.

### Testing Standards

- Each AC must have corresponding unit tests
- Full test suite `swift test` must pass (currently ~600 tests)
- Particular attention to fork/resume path regression tests (`SessionForkTests.swift`, `SessionListResumeTests.swift`)
- Use protocol-based mocking (`InputReading`, `OutputRendering`) for REPL tests
- Test file naming: `*Tests.swift` in `Tests/OpenAgentCLITests/`
- Use `XCTest` framework (no third-party test libs)
- Test stderr output capture: use fd-level `dup`/`dup2` (NOT `freopen`/`fclose` which breaks C stderr stream -- learned in Story 7.7)

### Previous Story Intelligence (Story 7.7)

Key learnings from the most recent story:
1. `renderer.output.write()` is the standard output method for all terminal output
2. `ConfigLoader.apply()` uses `explicitlySet` to avoid overwriting CLI args -- new fields must follow this pattern
3. Full regression test suite (~600 tests) must pass after all changes
4. `AgentFactory.computeToolPool()` is the core tool assembly point
5. Process script execution pattern exists in `AgentFactory.executeExternalTool()` for reference
6. `[String: Any]` is not directly `Decodable` -- use `JSONSerialization` for custom decoding
7. stderr capture in tests: use fd-level `dup`/`dup2` instead of `freopen`/`fclose`

### Git Intelligence

Recent commits show steady feature delivery (Stories 7.2-7.7, plus bug fixes):
- `fc9520e` test: add e2e tests as separate target, CI runs unit tests only
- `dcaa925` fix: pass explicitlySet and customTools in /fork and /resume agent recreation
- `84c211d` feat: implement skills listing and custom tool registration (Story 7.7)

The `dcaa925` commit already partially addressed AC#2 by adding `explicitlySet` and `customTools` pass-through. The full struct copy approach would make this more robust.

### Out of Scope

The following deferred items were evaluated and accepted as-is:

1. **PermissionHandler bypasses OutputRendering protocol** -- Intentional architectural choice; OutputRendering is designed for SDKMessage events, not permission prompts
2. **testToolPool_advancedWithSkill_includesBoth naming inaccuracy** -- Low priority test naming issue
3. **Weak ANSI color assertions** -- Intentional simplification for test readability
4. **AC#3/AC#4 sub-agent test automation** -- SDK internal behavior, CLI layer cannot test
5. **Duplicate makeArgs helpers** -- Acceptable test isolation
6. **testSpecialistTier_hasExpectedCount weak assertion** -- Intentional forward-compatible design
7. **AgentOptions not populating skill field** -- Intentional equivalent design choice
8. **testCreateAgent missing disk write verification** -- Low priority, SDK internal coverage

### Project Structure Notes

All changes are within existing source files. No new files needed except potentially one helper function added to `ANSI.swift`.

```
Sources/OpenAgentCLI/
  CLI.swift              -- AC#1 (force-unwrap), AC#3 (isatty), AC#4 (--stdin+--skill), AC#5 (non-interactive)
  REPLLoop.swift         -- AC#2 (struct copy), AC#6 (Sendable), AC#7 (orphan cleanup)
  PermissionHandler.swift -- AC#5 (non-interactive permission behavior)
  ConfigLoader.swift      -- AC#1 (force-unwrap)
  AgentFactory.swift      -- AC#1 (force-unwrap)
  ANSI.swift              -- AC#1 (writeToStderr helper, if placed here)

Tests/OpenAgentCLITests/
  ArgumentParserTests.swift    -- AC#4 test
  StdinInputTests.swift        -- AC#3 test
  PermissionHandlerTests.swift -- AC#5 test
  SessionForkTests.swift       -- AC#2, AC#7 tests
  SessionListResumeTests.swift -- AC#2 regression
```

### References

- [Source: _bmad-output/planning-artifacts/epics.md -- Epic 8 not present; Story 8.1 derived from code review findings]
- [Source: _bmad-output/planning-artifacts/prd.md -- NFR3.2 actionable error messages, NFR2.5 graceful Ctrl+C]
- [Source: _bmad-output/planning-artifacts/architecture.md -- Error handling patterns, file structure conventions]
- [Source: _bmad-output/planning-artifacts/next-phase-backlog.md -- 8.2-8.4 are future work]
- [Source: Sources/OpenAgentCLI/CLI.swift -- readStdin(), createAgentOrExit(), closeAgentSafely()]
- [Source: Sources/OpenAgentCLI/REPLLoop.swift -- handleFork(), handleResume(), CostTracker]
- [Source: Sources/OpenAgentCLI/PermissionHandler.swift -- checkNonInteractive(), createCanUseTool()]
- [Source: Sources/OpenAgentCLI/ConfigLoader.swift -- load(), apply(), warnIfMissing()]
- [Source: Sources/OpenAgentCLI/AgentFactory.swift -- createCustomTools(), computeToolPool()]
- [Source: _bmad-output/implementation-artifacts/7-7-skills-listing-and-custom-tool-registration.md -- previous story learnings]

## Dev Agent Record

### Agent Model Used

Claude GLM-5.1

### Debug Log References

- AC1 test SourceDir.path resolved incorrectly to /Users/nick/CascadeProjects/ -- fixed by walking up to find Package.swift instead of hardcoding 3 levels
- AC2 fork/resume tests used temp SessionStore but agents saved to default store -- fixed by using default SessionStore() matching the pattern in SessionForkTests
- PermissionHandler non-interactive deny tests updated to expect .allow behavior instead of .deny

### Completion Notes List

- AC#1: Created ANSI.writeToStderr() helper, replaced all 16 force-unwraps across CLI.swift (9), ConfigLoader.swift (4), AgentFactory.swift (3). AgentFactory uses `?? Data()` inline instead of ANSI.writeToStderr() since it doesn't import Foundation's FileHandle in the same way.
- AC#2: Replaced manual ParsedArgs construction in handleFork() and handleResume() with struct copy (`var forkArgs = args; forkArgs.sessionId = newId`). Automatically preserves all fields including explicitlySet, customTools, stdin, etc.
- AC#3: Added isatty(STDIN_FILENO) check in CLI.readStdin() with new CLI.StdinError.terminalInput error case. Imports Darwin/Glibc conditionally.
- AC#4: Added mutual exclusion validation in ArgumentParser.parse() for --stdin + --skill combination.
- AC#5: Changed PermissionHandler.checkNonInteractive() from .deny to .allow() with warning message. Updated 3 existing tests in PermissionHandlerTests.swift to match new behavior.
- AC#6: Marked CostTracker as `@unchecked Sendable` -- single-line change, no functional impact.
- AC#7: Added `try? await store.delete(sessionId: forkedId)` cleanup in handleFork() catch block after AgentFactory failure.
- Full regression: 628 tests pass, 0 failures.

### File List

- Sources/OpenAgentCLI/ANSI.swift -- Added writeToStderr() helper method
- Sources/OpenAgentCLI/CLI.swift -- Replaced 9 force-unwraps with ANSI.writeToStderr(); added isatty() check; added StdinError.terminalInput case
- Sources/OpenAgentCLI/ConfigLoader.swift -- Replaced 4 force-unwraps with ANSI.writeToStderr()
- Sources/OpenAgentCLI/AgentFactory.swift -- Replaced 3 force-unwraps with safe `?? Data()` fallback
- Sources/OpenAgentCLI/REPLLoop.swift -- Refactored handleFork/handleResume to use struct copy; added orphan cleanup; added @unchecked Sendable to CostTracker
- Sources/OpenAgentCLI/PermissionHandler.swift -- Changed checkNonInteractive() from deny to auto-approve with warning
- Sources/OpenAgentCLI/ArgumentParser.swift -- Added --stdin + --skill mutual exclusion validation
- Tests/OpenAgentCLITests/PermissionHandlerTests.swift -- Updated 3 non-interactive deny tests to expect .allow behavior
- Tests/OpenAgentCLITests/TechnicalDebtAC1Tests.swift -- Fixed SourceDir.path to walk up to Package.swift
- Tests/OpenAgentCLITests/TechnicalDebtAC2Tests.swift -- Fixed fork/resume tests to use default SessionStore

### Change Log

- 2026-04-22: Implemented all 7 ACs for Story 8.1 Technical Debt Cleanup. All 628 tests pass.
