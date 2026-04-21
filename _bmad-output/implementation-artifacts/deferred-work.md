# Deferred Work

## Deferred from: code review of 3-1-auto-save-sessions-on-exit.md (2026-04-20)

- **Force-unwrap on .data(using: .utf8)! in closeAgentSafely** — Pre-existing pattern (now 7 occurrences total in CLI.swift, 1 new in this change). The new occurrence is in `closeAgentSafely` at CLI.swift:138. Not introduced by this change, already tracked.
- **testCreateAgent_sessionSavedToDisk_afterClose lacks disk-write verification** — Test only verifies close() succeeds without error. Full disk-write verification requires AgentOptions to expose a custom sessionsDir parameter. Low priority; the SDK's internal tests cover the write path.

## Deferred from: code review of 2-3-skills-loading-and-invocation.md (2026-04-20)

- **Force-unwrap on .data(using: .utf8)! in error paths** — Pre-existing pattern (6 occurrences total in CLI.swift, 3 new in this change). Not introduced by this change.
- **Misleading error message in registry guard** — CLI.swift line 48 shows "Skill not found" when the actual condition is "no registry could be built". Defensive code that should never trigger.
- **AgentOptions not populated with skill fields** — createAgent does not set skillDirectories/skillNames/skillRegistry on AgentOptions, relying solely on SkillTool injection. Functionally equivalent but deviates from spec's recommended autoDiscoverSkills() approach. Intentional design choice.
- **Missing test for --skill + positional prompt combined path** — The code path where both --skill and a prompt are provided is untested. Low priority.

## Deferred from: code review of 4-2-sub-agent-delegation.md (2026-04-20)

- **testToolPool_advancedWithSkill_includesBoth name misleading** — Test name claims "includesBoth" but only asserts Agent tool presence, not Skill tool. Pre-existing test quality gap. Low priority.
- **Weak ANSI color assertions in tests** — `testRenderTaskStarted_usesYellowANSI` and `testRenderTaskProgress_usesGreyANSI` use `|| contains("\u{001B}[")` fallback that matches any ANSI code. By-design test simplification. Low risk.
- **AC#3 and AC#4 have no automated tests** — Sub-agent output continuation (AC#3) and permission/API inheritance (AC#4) are SDK-internal behaviors not testable at CLI level. Acknowledged in story design.

## Deferred from: code review of 5-1-permission-mode-configuration.md (2026-04-20)

- **Single-shot mode + default/plan mode: stdin EOF causes silent deny of all write tools** — When using `--prompt` (single-shot) with `--mode default` or `--mode plan`, stdin is non-interactive. The `FileHandleInputReader.readLine()` returns nil (EOF), causing `canUseTool` to return `.deny("No input received")` for all write operations. This silently blocks all write tools in single-shot mode when permission mode requires approval. Deferred to Story 5.2 (Interactive Permission Prompts) which will address non-interactive context handling.
- **PermissionHandler bypasses OutputRendering protocol, writes directly to output stream** — `PermissionHandler.promptUser` writes to `renderer.output` (AnyTextOutputStream) directly instead of using the `OutputRendering` protocol methods. This is a deliberate architectural choice since `OutputRendering` is designed for `SDKMessage` events, not permission prompts. Pre-existing design pattern.

## Deferred from: code review of 6-2-specialist-tools-and-tool-filtering.md (2026-04-21)

- **Duplicated makeArgs helper in SpecialistToolFilterTests and ToolLoadingTests** — Identical `makeArgs` helper in two test files. Maintenance burden when ParsedArgs fields change, but acceptable for test isolation. Pre-existing pattern from ToolLoadingTests.
- **testSpecialistTier_hasExpectedCount uses weak >= 13 assertion** — Uses `XCTAssertGreaterThanOrEqual` instead of exact count. Intentional for forward compatibility if SDK adds more specialist tools.
