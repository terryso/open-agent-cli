# Deferred Work

## Deferred from: code review of 7-5-session-fork.md (2026-04-22)

- ~~**Missing `stdin` and `explicitlySet` in ParsedArgs copy**~~ — **Resolved by Story 8-1 AC#2:** Replaced manual field-by-field construction with struct copy (`var forkArgs = args; forkArgs.sessionId = newId`), which automatically preserves all fields including `stdin`, `explicitlySet`, and `customTools`.
- ~~**No cleanup of forked session on AgentFactory failure**~~ — **Resolved by Story 8-1 AC#7:** Added `try? await store.delete(sessionId: forkedId)` in the catch block of `handleFork()`.

## Deferred from: code review of 7-1-pipe-stdin-input-mode.md (2026-04-21)

- ~~**readStdin() hangs on terminal stdin**~~ — **Resolved by Story 8-1 AC#3:** Added `isatty(STDIN_FILENO)` check in `CLI.readStdin()` that throws `StdinError.terminalInput` with clear error message when stdin is a terminal.
- ~~**--stdin + --skill interaction undefined**~~ — **Resolved by Story 8-1 AC#4:** Added mutual exclusion validation in `ArgumentParser.parse()` that rejects the combination with a clear error message.
- ~~**AC#3 only partially satisfied**~~ — **Resolved by Story 8-1 AC#3:** The isatty() check fully addresses the terminal blocking issue. Running `openagent --stdin` without a pipe now exits with an error immediately.

## Deferred from: code review of 3-1-auto-save-sessions-on-exit.md (2026-04-20)

- ~~**Force-unwrap on .data(using: .utf8)! in closeAgentSafely**~~ — **Resolved by Story 8-1 AC#1:** All 16 force-unwraps across CLI.swift (9), ConfigLoader.swift (4), and AgentFactory.swift (3) replaced with safe `ANSI.writeToStderr()` or `?? Data()` fallback.
- **testCreateAgent_sessionSavedToDisk_afterClose lacks disk-write verification** — Test only verifies close() succeeds without error. Full disk-write verification requires AgentOptions to expose a custom sessionsDir parameter. Low priority; the SDK's internal tests cover the write path.

## Deferred from: code review of 2-3-skills-loading-and-invocation.md (2026-04-20)

- ~~**Force-unwrap on .data(using: .utf8)! in error paths**~~ — **Resolved by Story 8-1 AC#1:** Same as above; all CLI.swift force-unwraps eliminated.
- **Misleading error message in registry guard** — CLI.swift line 48 shows "Skill not found" when the actual condition is "no registry could be built". Defensive code that should never trigger.
- **AgentOptions not populated with skill fields** — createAgent does not set skillDirectories/skillNames/skillRegistry on AgentOptions, relying solely on SkillTool injection. Functionally equivalent but deviates from spec's recommended autoDiscoverSkills() approach. Intentional design choice.
- **Missing test for --skill + positional prompt combined path** — The code path where both --skill and a prompt are provided is untested. Low priority.

## Deferred from: code review of 4-2-sub-agent-delegation.md (2026-04-20)

- **testToolPool_advancedWithSkill_includesBoth name misleading** — Test name claims "includesBoth" but only asserts Agent tool presence, not Skill tool. Pre-existing test quality gap. Low priority.
- **Weak ANSI color assertions in tests** — `testRenderTaskStarted_usesYellowANSI` and `testRenderTaskProgress_usesGreyANSI` use `|| contains("\u{001B}[")` fallback that matches any ANSI code. By-design test simplification. Low risk.
- **AC#3 and AC#4 have no automated tests** — Sub-agent output continuation (AC#3) and permission/API inheritance (AC#4) are SDK-internal behaviors not testable at CLI level. Acknowledged in story design.

## Deferred from: code review of 5-1-permission-mode-configuration.md (2026-04-20)

- ~~**Single-shot mode + default/plan mode: stdin EOF causes silent deny of all write tools**~~ — **Resolved by Story 8-1 AC#5:** Changed `PermissionHandler.checkNonInteractive()` from `.deny()` to `.allow()` with a warning message. Non-interactive single-shot mode now auto-approves tools instead of silently denying them.
- **PermissionHandler bypasses OutputRendering protocol, writes directly to output stream** — `PermissionHandler.promptUser` writes to `renderer.output` (AnyTextOutputStream) directly instead of using the `OutputRendering` protocol methods. This is a deliberate architectural choice since `OutputRendering` is designed for `SDKMessage` events, not permission prompts. Pre-existing design pattern.

## Deferred from: code review of 6-2-specialist-tools-and-tool-filtering.md (2026-04-21)

- **Duplicated makeArgs helper in SpecialistToolFilterTests and ToolLoadingTests** — Identical `makeArgs` helper in two test files. Maintenance burden when ParsedArgs fields change, but acceptable for test isolation. Pre-existing pattern from ToolLoadingTests.
- **testSpecialistTier_hasExpectedCount uses weak >= 13 assertion** — Uses `XCTAssertGreaterThanOrEqual` instead of exact count. Intentional for forward compatibility if SDK adds more specialist tools.

## Deferred from: code review of 6-3-dynamic-repl-commands.md (2026-04-21)

- ~~**`CostTracker` not `Sendable`**~~ — **Resolved by Story 8-1 AC#6:** Marked as `@unchecked Sendable`. Safe because CostTracker is only accessed from the main REPL loop with no concurrent mutation.
