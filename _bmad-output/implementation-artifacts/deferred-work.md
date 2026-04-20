# Deferred Work

## Deferred from: code review of 3-1-auto-save-sessions-on-exit.md (2026-04-20)

- **Force-unwrap on .data(using: .utf8)! in closeAgentSafely** — Pre-existing pattern (now 7 occurrences total in CLI.swift, 1 new in this change). The new occurrence is in `closeAgentSafely` at CLI.swift:138. Not introduced by this change, already tracked.
- **testCreateAgent_sessionSavedToDisk_afterClose lacks disk-write verification** — Test only verifies close() succeeds without error. Full disk-write verification requires AgentOptions to expose a custom sessionsDir parameter. Low priority; the SDK's internal tests cover the write path.

## Deferred from: code review of 2-3-skills-loading-and-invocation.md (2026-04-20)

- **Force-unwrap on .data(using: .utf8)! in error paths** — Pre-existing pattern (6 occurrences total in CLI.swift, 3 new in this change). Not introduced by this change.
- **Misleading error message in registry guard** — CLI.swift line 48 shows "Skill not found" when the actual condition is "no registry could be built". Defensive code that should never trigger.
- **AgentOptions not populated with skill fields** — createAgent does not set skillDirectories/skillNames/skillRegistry on AgentOptions, relying solely on SkillTool injection. Functionally equivalent but deviates from spec's recommended autoDiscoverSkills() approach. Intentional design choice.
- **Missing test for --skill + positional prompt combined path** — The code path where both --skill and a prompt are provided is untested. Low priority.
