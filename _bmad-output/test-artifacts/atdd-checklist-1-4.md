---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
  - step-04c-aggregate
  - step-05-validate-and-complete
lastStep: step-05-validate-and-complete
lastSaved: '2026-04-19'
inputDocuments:
  - _bmad-output/implementation-artifacts/1-4-interactive-repl-loop.md
  - Sources/OpenAgentCLI/CLI.swift
  - Sources/OpenAgentCLI/OutputRenderer.swift
  - Sources/OpenAgentCLI/AgentFactory.swift
  - Sources/OpenAgentCLI/ArgumentParser.swift
  - Tests/OpenAgentCLITests/OutputRendererTests.swift
  - Tests/OpenAgentCLITests/AgentFactoryTests.swift
---

# ATDD Checklist: Story 1.4 -- Interactive REPL Loop

## TDD Red Phase (Current)

All tests are designed to **FAIL** until `REPLLoop` and `InputReading` are implemented.
Tests fail at compilation because `REPLLoop`, `InputReading`, and `FileHandleInputReader`
do not yet exist.

- **Total Tests:** 22
- **Test File:** `Tests/OpenAgentCLITests/REPLLoopTests.swift`
- **Test Framework:** XCTest (Swift Package Manager)
- **Execution Mode:** Sequential (backend project -- no browser tests needed)

## Acceptance Criteria Coverage

| AC# | Criterion | Test Scenarios | Priority |
|-----|-----------|---------------|----------|
| AC#1 | REPL shows `>` prompt, waits for input | `testREPLLoop_showsPromptOnStart`, `testREPLLoop_emptyInput_returnsNilImmediately` | P0 |
| AC#2 | Message sent to Agent, streaming via OutputRenderer | `testREPLLoop_sendsInputToAgent`, `testREPLLoop_streamsResponseThroughRenderer` | P0 |
| AC#3 | Prompt reappears after response | `testREPLLoop_promptReappearsAfterResponse`, `testREPLLoop_promptReappearsAfterSlashCommand` | P0 |
| AC#4 | `/help` shows available REPL commands | `testREPLLoop_helpCommand_showsAvailableCommands`, `testREPLLoop_helpCommand_doesNotExit` | P0 |
| AC#5 | `/exit` and `/quit` exit gracefully | `testREPLLoop_exitCommand_exitsLoop`, `testREPLLoop_quitCommand_exitsLoop`, `testREPLLoop_exitAfterMessages_exitsGracefully`, `testREPLLoop_exitCaseInsensitive`, `testREPLLoop_quitCaseInsensitive` | P0 |
| AC#6 | Empty/whitespace input ignored | `testREPLLoop_emptyLine_ignored`, `testREPLLoop_whitespaceOnly_ignored`, `testREPLLoop_tabOnly_ignored`, `testREPLLoop_mixedWhitespace_ignored`, `testREPLLoop_multipleEmptyLines_ignored` | P0 |
| Edge | Unknown slash command | `testREPLLoop_unknownSlashCommand_showsError`, `testREPLLoop_unknownSlashCommand_doesNotExit` | P1 |
| Infra | InputReading protocol | `testInputReadingProtocol_mockInputReaderConforms`, `testInputReadingProtocol_promptPassedCorrectly` | P2 |

## Test Strategy

### Test Level Selection

This is a **backend Swift** project. All tests are **unit tests** at the XCTest level.

- **Unit tests** for REPL loop control flow (input dispatch, command handling, prompt management)
- Mock-based testing: `MockInputReader` injects predefined input sequences
- `MockTextOutputStream` captures output for assertion (reuse from OutputRendererTests)
- No integration/E2E tests needed for this component

### Priority Matrix

| Priority | Count | Description |
|----------|-------|-------------|
| P0 | 17 | Core REPL behavior: prompt display, message dispatch, exit commands, empty input |
| P1 | 2 | Unknown slash command handling |
| P2 | 3 | InputReading protocol conformance, edge cases |

### Generation Mode

**AI Generation** -- Backend project, no browser recording needed. Tests generated from acceptance criteria and architecture design.

## Test File Structure

```
Tests/OpenAgentCLITests/
  REPLLoopTests.swift    # 22 tests covering all 6 acceptance criteria + edge cases
```

## Detailed Test Inventory

### AC#1: Prompt Display on Start (P0)

1. `testREPLLoop_showsPromptOnStart` -- REPL displays "> " prompt immediately on start
2. `testREPLLoop_emptyInput_returnsNilImmediately` -- EOF (Ctrl+D) exits cleanly without hanging

### AC#2: Message Sent to Agent with Streaming (P0)

3. `testREPLLoop_sendsInputToAgent` -- User message triggers Agent.stream() via OutputRenderer
4. `testREPLLoop_streamsResponseThroughRenderer` -- Agent response rendered through OutputRenderer pipeline

### AC#3: Prompt Reappears After Response (P0)

5. `testREPLLoop_promptReappearsAfterResponse` -- After each message+response, "> " prompt shown again
6. `testREPLLoop_promptReappearsAfterSlashCommand` -- After non-exit slash command, prompt reappears

### AC#4: /help Command (P0)

7. `testREPLLoop_helpCommand_showsAvailableCommands` -- /help lists /help, /exit, /quit
8. `testREPLLoop_helpCommand_doesNotExit` -- /help does not terminate the loop

### AC#5: /exit and /quit Commands (P0)

9. `testREPLLoop_exitCommand_exitsLoop` -- /exit terminates REPL after 1 input read
10. `testREPLLoop_quitCommand_exitsLoop` -- /quit terminates REPL after 1 input read
11. `testREPLLoop_exitAfterMessages_exitsGracefully` -- /exit works after processing messages
12. `testREPLLoop_exitCaseInsensitive` -- /EXIT also causes exit
13. `testREPLLoop_quitCaseInsensitive` -- /QUIT also causes exit

### AC#6: Empty/Whitespace Input Ignored (P0)

14. `testREPLLoop_emptyLine_ignored` -- Empty string skipped, prompt reappears
15. `testREPLLoop_whitespaceOnly_ignored` -- Spaces-only skipped
16. `testREPLLoop_tabOnly_ignored` -- Tabs-only skipped
17. `testREPLLoop_mixedWhitespace_ignored` -- Mixed spaces/tabs skipped
18. `testREPLLoop_multipleEmptyLines_ignored` -- Multiple consecutive empty lines all skipped

### Edge Cases: Unknown Slash Commands (P1)

19. `testREPLLoop_unknownSlashCommand_showsError` -- Unknown command shows "Unknown command" + "/help" suggestion
20. `testREPLLoop_unknownSlashCommand_doesNotExit` -- Unknown command does not exit REPL

### Protocol Conformance (P2)

21. `testInputReadingProtocol_mockInputReaderConforms` -- MockInputReader returns lines in order, nil after exhaustion
22. `testInputReadingProtocol_promptPassedCorrectly` -- Prompt parameter received by InputReading.readLine()

## Implementation Guidance

### Types to Create

1. `Sources/OpenAgentCLI/REPLLoop.swift`:
   - `protocol InputReading: Sendable` with `readLine(prompt:) -> String?`
   - `struct FileHandleInputReader: InputReading` -- reads from stdin via FileHandle
   - `struct REPLLoop` -- main loop with `agent`, `renderer`, `reader` properties
   - `func start() async` -- while-loop: read input, dispatch commands, stream to Agent
   - `private func handleSlashCommand(_ input: String) -> Bool` -- returns true if should exit
   - `private func printHelp()` -- outputs available commands

2. `Sources/OpenAgentCLI/CLI.swift`:
   - Replace REPL placeholder (lines 47-50) with REPLLoop instantiation
   - Create `FileHandleInputReader`, `OutputRenderer`, and `REPLLoop`
   - Call `await repl.start()` then `try? await agent.close()`

### Test Infrastructure

The test file includes `MockInputReader` inline (following the pattern from OutputRendererTests' `MockTextOutputStream`).

### Key Design Decisions

- **Protocol-based input abstraction**: `InputReading` protocol enables mock injection for tests
- **Case-insensitive commands**: `/EXIT`, `/Quit` all work via `.lowercased()`
- **Trimmed input check**: `trimmingCharacters(in: .whitespacesAndNewlines)` for empty detection
- **Agent close on exit**: `try? await agent.close()` handles double-close gracefully

## Running Tests

```bash
# Run all failing tests for this story (will fail at compile until REPLLoop exists)
swift test --filter REPLLoopTests

# Run all tests
swift test

# Build only (verify compilation)
swift build --build-tests
```

## Red-Green-Refactor Workflow

### RED Phase (Complete)

- All 22 tests written and failing at compilation
- Failure reason: `REPLLoop` and `InputReading` types do not exist
- Build error count: 22 errors (cannot find 'REPLLoop' in scope, cannot find type 'InputReading' in scope)

### GREEN Phase (Next Steps)

1. Create `Sources/OpenAgentCLI/REPLLoop.swift` with `InputReading` protocol, `FileHandleInputReader`, and `REPLLoop`
2. Update `Sources/OpenAgentCLI/CLI.swift` to integrate REPLLoop
3. Run `swift test --filter REPLLoopTests`
4. Fix any failing tests

### REFACTOR Phase

1. After all tests pass, review code for quality
2. Ensure existing 124 tests still pass (`swift test`)
3. Verify no code smells or duplications

## Risks and Assumptions

- **Assumption:** Agent.stream() with test API key will either produce messages or errors -- either way REPLLoop should handle it gracefully
- **Assumption:** The tests verify REPL loop control flow (prompt, command dispatch, exit) rather than actual Agent responses
- **Risk:** Tests that call `makeTestAgent()` create a real Agent object -- the Agent won't connect to a real LLM, but its stream() may behave unexpectedly
- **Risk:** Swift concurrency: `async` test methods in XCTest work on macOS 13+ (project minimum)

## Test Execution Evidence

### Initial Build Attempt (RED Phase Verification)

**Command:** `swift build --build-tests`

**Results:**
```
error: cannot find 'REPLLoop' in scope (x20)
error: cannot find type 'InputReading' in scope (x2)
Total errors: 22
Status: RED phase verified -- tests cannot compile until feature implemented
```

**Expected Failure Reasons:**
- All tests reference `REPLLoop` which does not exist yet
- `MockInputReader` conforms to `InputReading` protocol which does not exist yet
- After implementing REPLLoop.swift, tests should compile and pass

## Notes

- Tests follow the exact patterns established in Stories 1.1-1.3
- MockInputReader pattern mirrors MockTextOutputStream from Story 1.3
- Tests are isolated: each test creates its own REPLLoop instance with fresh mocks
- No test interdependencies: tests can run in any order

---

Generated by BMad TEA Agent -- 2026-04-19
