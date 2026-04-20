---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
  - step-05-validate-and-complete
lastStep: step-05-validate-and-complete
lastSaved: 2026-04-20
storyId: 3-2
inputDocuments:
  - _bmad-output/implementation-artifacts/3-2-list-and-resume-past-sessions.md
  - Sources/OpenAgentCLI/AgentFactory.swift
  - Sources/OpenAgentCLI/CLI.swift
  - Sources/OpenAgentCLI/REPLLoop.swift
  - Tests/OpenAgentCLITests/REPLLoopTests.swift
  - Tests/OpenAgentCLITests/SessionSaveTests.swift
  - Tests/OpenAgentCLITests/AgentFactoryTests.swift
tddPhase: RED
detectedStack: backend
testFramework: XCTest
---

# ATDD Checklist - Story 3.2: List and Resume Past Sessions

## Story Summary

**As a user**, I want to view past conversations and resume one of them, so I can continue a previous task.

## Preflight Verification

| Prerequisite | Status |
|---|---|
| Story approved with clear acceptance criteria | PASS |
| Test framework configured (XCTest) | PASS |
| Development environment available | PASS |
| Existing 271 tests passing | PASS |
| Stack detected: backend (Swift CLI) | PASS |
| SDK SessionStore API available (list, load) | PASS |
| SDK SessionMetadata has firstPrompt, id, updatedAt | PASS |
| SDK SessionData has metadata and messages | PASS |

## Generation Mode

| Dimension | Value |
|---|---|
| Detected Stack | backend |
| Generation Mode | AI Generation (standard scenarios) |
| Test Framework | XCTest |
| TDD Phase | RED (failing tests) |

## Test Strategy

### Acceptance Criteria to Test Mapping

| AC | Description | Test Level | Priority |
|---|---|---|---|
| AC#1 | /sessions displays history session list with ID, date, first message preview | Integration | P0 |
| AC#2 | /resume <id> loads session and continues conversation | Integration | P0 |
| AC#3 | /resume invalid-id shows "Session not found" | Unit | P0 |

### Test Priority Matrix

| Priority | Risk | Business Impact | Test Count |
|---|---|---|---|
| P0 | High - Core feature (session management) | High - User-facing | 10 |
| P1 | Medium - Regression | Medium - Existing features | 4 |
| Total | | | 14 |

## Test File

**File:** `Tests/OpenAgentCLITests/SessionListResumeTests.swift`

### Test Methods and AC Coverage

| # | Test Method | AC | Priority | Description |
|---|---|---|---|---|
| 1 | `testSessionsCommand_emptyList_showsNoSessions` | #1 | P0 | Empty session list shows "No saved sessions." |
| 2 | `testSessionsCommand_withSessions_showsList` | #1 | P0 | Sessions exist, shows formatted list with ID, date, preview |
| 3 | `testSessionsCommand_doesNotExit` | #1 | P0 | /sessions does not exit REPL |
| 4 | `testResumeCommand_validId_resumesSession` | #2 | P0 | /resume with valid ID shows resume confirmation |
| 5 | `testResumeCommand_doesNotExit` | #2 | P0 | /resume does not exit REPL |
| 6 | `testResumeCommand_invalidId_showsNotFound` | #3 | P0 | /resume invalid-id shows "Session not found" |
| 7 | `testResumeCommand_noArgs_showsUsage` | #3 | P0 | /resume without args shows usage message |
| 8 | `testSlashCommand_helpIncludesSessionsCommand` | #1 | P0 | /help lists /sessions |
| 9 | `testSlashCommand_helpIncludesResumeCommand` | #2 | P0 | /help lists /resume |
| 10 | `testCreateAgent_returnsSessionStore` | #1,#2 | P0 | createAgent returns (Agent, SessionStore) tuple |
| 11 | `testREPLLoop_acceptsSessionStore` | #1,#2 | P0 | REPLLoop init accepts sessionStore parameter |
| 12 | `testREPLLoop_withoutSessionStore_stillWorks` | - | P1 | Backward compat: REPLLoop works without sessionStore |
| 13 | `testCreateAgent_withSessionStoreReturn_modelStillCorrect` | - | P1 | Regression: model passthrough with tuple return |
| 14 | `testCreateAgent_withSessionStoreReturn_maxTurnsStillCorrect` | - | P1 | Regression: maxTurns passthrough with tuple return |

**Total: 14 test methods (10 P0 + 4 P1)**

## TDD Red Phase Status

### APIs Not Yet Implemented (Expected Compilation Errors)

| Missing API | Source File | Task | Error Count |
|---|---|---|---|
| `AgentFactory.createAgent(from:)` returns `(Agent, SessionStore)` | AgentFactory.swift | Task 1 | 3 |
| `REPLLoop.init(sessionStore:)` parameter | REPLLoop.swift | Task 2,3 | 9 |

### Error Categories

1. **`cannot convert value of type 'Agent' to specified type '(_, _)'`** -- AgentFactory.createAgent needs to return `(Agent, SessionStore)` tuple instead of just `Agent`. Affects 3 test methods.

2. **`extra argument 'sessionStore' in call`** -- REPLLoop.init needs a new `sessionStore: SessionStore?` parameter. Affects 9 test methods.

### Runtime Behavior Changes Needed

| Change | Source File | Task |
|---|---|---|
| Change createAgent return type to `(Agent, SessionStore)` | AgentFactory.swift | Task 1 |
| Add `sessionStore` parameter to REPLLoop.init | REPLLoop.swift | Task 2 |
| Add `/sessions` command in handleSlashCommand | REPLLoop.swift | Task 2 |
| Add `/resume <id>` command in handleSlashCommand | REPLLoop.swift | Task 3 |
| Update `printHelp()` with /sessions and /resume | REPLLoop.swift | Task 2 |
| Update CLI.swift to pass SessionStore to REPLLoop | CLI.swift | Task 4 |
| Update `createAgentOrExit` return type | CLI.swift | Task 4 |
| Update all existing test fixtures for tuple return | Multiple test files | Task 5 |

### Regression Verification

| Check | Status |
|---|---|
| All 271 existing tests pass (pre-change baseline) | PASS |
| No changes to existing source files | PASS |
| No changes to existing test files | PASS |
| Build succeeds (source only, no tests) | PASS |

## Implementation Requirements (Green Phase Guide)

### Task 1: AgentFactory Returns SessionStore

Change `AgentFactory.createAgent(from:)` in `AgentFactory.swift`:

```swift
static func createAgent(from args: ParsedArgs) throws -> (Agent, SessionStore) {
    // ... existing validation ...
    let sessionStore = SessionStore()
    // ... existing options assembly ...
    let agent = OpenAgentSDK.createAgent(options: options)
    return (agent, sessionStore)
}
```

All callers must destructure: `let (agent, sessionStore) = try AgentFactory.createAgent(from: args)`

Affected files:
- `CLI.swift` -- `createAgentOrExit` function
- `Tests/OpenAgentCLITests/AgentFactoryTests.swift` -- all `createAgent` calls
- `Tests/OpenAgentCLITests/SessionSaveTests.swift` -- all `createAgent` calls
- `Tests/OpenAgentCLITests/REPLLoopTests.swift` -- `makeTestAgent()` helper
- `Tests/OpenAgentCLITests/ToolLoadingTests.swift` -- if applicable
- `Tests/OpenAgentCLITests/SkillLoadingTests.swift` -- if applicable

### Task 2: REPLLoop /sessions Command

Add `sessionStore` parameter to REPLLoop:

```swift
struct REPLLoop {
    let agent: Agent
    let renderer: OutputRenderer
    let reader: InputReading
    let toolNames: [String]
    let skillRegistry: SkillRegistry?
    let sessionStore: SessionStore?

    init(agent: Agent, renderer: OutputRenderer, reader: InputReading,
         toolNames: [String] = [], skillRegistry: SkillRegistry? = nil,
         sessionStore: SessionStore? = nil) {
        // ...
    }
}
```

Add `/sessions` case in `handleSlashCommand`:

```swift
case "/sessions":
    handleSessionsList()
```

Implement `handleSessionsList()`:

```swift
private func handleSessionsList() {
    guard let store = sessionStore else {
        renderer.output.write("Session management not available.\n")
        return
    }
    do {
        let sessions = try store.list()
        if sessions.isEmpty {
            renderer.output.write("No saved sessions.\n")
        } else {
            renderer.output.write("Saved sessions (\(sessions.count)):\n")
            for session in sessions {
                let shortId = String(session.id.prefix(8))
                let preview = session.firstPrompt?.prefix(50).description ?? "(no preview)"
                renderer.output.write("  \(shortId)  \(session.messageCount) msgs  \"\(preview)\"\n")
            }
        }
    } catch {
        renderer.output.write("Error listing sessions: \(error.localizedDescription)\n")
    }
}
```

### Task 3: REPLLoop /resume Command

Add `/resume` case in `handleSlashCommand`:

```swift
case "/resume":
    handleResume(parts)
```

Implement `handleResume()`:

```swift
private func handleResume(_ parts: [Substring]) {
    guard parts.count > 1 else {
        renderer.output.write("Usage: /resume <session-id>\n")
        return
    }
    let sessionId = String(parts[1])
    guard let store = sessionStore else {
        renderer.output.write("Session management not available.\n")
        return
    }
    do {
        if let _ = try store.load(sessionId: sessionId) {
            // Session exists -- resume would require replacing the Agent instance
            // This needs an AgentHolder wrapper or mutating approach
            renderer.output.write("Session found: \(sessionId). Resume not yet fully implemented.\n")
        } else {
            renderer.output.write("Session not found: \(sessionId)\n")
        }
    } catch {
        renderer.output.write("Error loading session: \(error.localizedDescription)\n")
    }
}
```

### Task 4: CLI.swift Updates

Update `createAgentOrExit` return type and pass SessionStore to REPLLoop:

```swift
private static func createAgentOrExit(from args: ParsedArgs) -> (Agent, SessionStore) {
    do {
        return try AgentFactory.createAgent(from: args)
    } catch {
        // ... existing error handling ...
    }
}
```

Pass sessionStore to REPLLoop in all 3 REPL creation sites.

### Task 5: Test Fixture Updates

All existing tests calling `AgentFactory.createAgent(from:)` must update:

```swift
// Before:
let agent = try AgentFactory.createAgent(from: args)

// After:
let (agent, _) = try AgentFactory.createAgent(from: args)
```

### Task 6: Update printHelp()

```swift
let help = """
Available commands:
  /help          Show this help message
  /tools         Show loaded tools
  /skills        Show loaded skills
  /sessions      List saved sessions
  /resume <id>   Resume a saved session
  /exit          Exit the REPL
  /quit          Exit the REPL
"""
```

## Key Risks and Assumptions

| Risk | Mitigation |
|---|---|
| AgentFactory return type change breaks all test fixtures | Batch update all callers with `let (agent, _) = ...` |
| REPLLoop is a struct -- cannot mutate agent for /resume | Use AgentHolder class wrapper or accept agent replacement requires restart |
| SessionStore is an actor -- test isolation needed | Use temp directories for each test |
| SessionStore.init(sessionsDir:) may not be public | Verify SDK API; fallback to default SessionStore() |
| 271 existing tests must still pass after return type change | Run full suite after fixture updates |

## Next Steps

1. **Green Phase**: Implement Tasks 1-4 per story specification
2. **Fixture Update**: Update all test files for tuple return (Task 5)
3. **Verify**: All 14 new tests pass + all 271 existing tests pass (285 total)
4. **Refactor**: Clean up any duplication between new and existing test helpers
