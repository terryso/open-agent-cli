---
stepsCompleted: ['step-01-preflight-and-context', 'step-02-generation-mode', 'step-03-test-strategy', 'step-04-generate-tests']
lastStep: 'step-04-generate-tests'
lastSaved: '2026-04-21'
storyId: '5-3'
storyTitle: 'Graceful Interrupt Handling'
inputDocuments:
  - '_bmad-output/implementation-artifacts/5-3-graceful-interrupt-handling.md'
  - 'Sources/OpenAgentCLI/REPLLoop.swift'
  - 'Sources/OpenAgentCLI/CLI.swift'
  - 'Sources/OpenAgentCLI/PermissionHandler.swift'
  - 'Sources/OpenAgentCLI/OutputRenderer.swift'
  - 'Sources/OpenAgentCLI/AgentFactory.swift'
  - 'Tests/OpenAgentCLITests/REPLLoopTests.swift'
  - 'Tests/OpenAgentCLITests/PermissionHandlerTests.swift'
---

# ATDD Checklist: Story 5.3 - Graceful Interrupt Handling

## Preflight Summary

- **Stack:** Backend (Swift)
- **Test Framework:** XCTest
- **Story Status:** ready-for-dev
- **Test Dir:** Tests/OpenAgentCLITests/
- **Generation Mode:** AI Generation (backend project, no browser recording)

## Acceptance Criteria Mapping

### AC#1: SIGINT during Agent streaming interrupts and re-shows prompt
| Test | Level | Priority | File |
|------|-------|----------|------|
| testSignalHandler_registersHandlers | Unit | P0 | SignalHandlerTests.swift |
| testSignalHandler_singleSIGINT_returnsInterrupt | Unit | P0 | SignalHandlerTests.swift |
| testSignalHandler_clearInterrupt_resetsState | Unit | P0 | SignalHandlerTests.swift |
| testREPLLoop_interrupt_resumesPrompt | Integration | P0 | REPLLoopInterruptTests.swift |
| testREPLLoop_interrupt_outputsCaretC | Integration | P0 | REPLLoopInterruptTests.swift |

### AC#2: SIGINT during permission prompt cancels and re-shows prompt
| Test | Level | Priority | File |
|------|-------|----------|------|
| testREPLLoop_interruptDuringPermissionPrompt | Integration | P0 | REPLLoopInterruptTests.swift |
| testPermissionPrompt_readLineNil_returnsDeny | Unit | P1 | SignalHandlerTests.swift |

### AC#3: Double Ctrl+C within 1 second exits CLI
| Test | Level | Priority | File |
|------|-------|----------|------|
| testSignalHandler_doubleSIGINT_returnsForceExit | Unit | P0 | SignalHandlerTests.swift |
| testSignalHandler_slowDoubleSIGINT_returnsInterrupt | Unit | P0 | SignalHandlerTests.swift |
| testREPLLoop_forceExit_exitsREPL | Integration | P0 | REPLLoopInterruptTests.swift |

### AC#4: SIGTERM saves session and exits cleanly
| Test | Level | Priority | File |
|------|-------|----------|------|
| testSignalHandler_SIGTERM_returnsTerminate | Unit | P0 | SignalHandlerTests.swift |
| testREPLLoop_terminate_savesSessionAndExits | Integration | P0 | REPLLoopInterruptTests.swift |

## Test Strategy

- **Unit tests** for SignalHandler: Direct signal registration and state query using `raise()` and `check()`
- **Integration tests** for REPLLoop interrupt behavior: Use MockInputReader with signal injection to verify REPL loop control flow
- **No E2E tests** - Backend project, no browser-based testing needed
- **Mock patterns:** Reuse existing `MockInputReader`, `MockTextOutputStream`, `MockTool` from other test files
- **Signal testing approach:** Use `raise(SIGINT)` / `raise(SIGTERM)` in tests to trigger real signal handlers, then verify state via `SignalHandler.check()`
- **REPLLoop testing approach:** Create a mockable signal-checking mechanism (via protocol or testable import) so tests can simulate signal events without sending real signals during test execution

## New Types Required (to be implemented)

1. **`SignalEvent` enum** - `.none`, `.interrupt`, `.forceExit`, `.terminate` cases
2. **`SignalHandler` enum** - Static methods: `register()`, `check()`, `clearInterrupt()`
3. **REPLLoop modifications** - Integrate signal checking into stream consumption loop

## TDD Red Phase Status

All 13 new tests will fail until the following are implemented:

1. **`SignalEvent` enum** - Type does not exist (4 test files affected)
2. **`SignalHandler` enum** - Type does not exist with `register()`, `check()`, `clearInterrupt()` static methods (8 test errors)
3. **REPLLoop interrupt integration** - No signal checking in stream consumption loop (5 integration test errors)

Total compilation errors: 26+ (3 unique categories)

## Implementation Required to Turn Tests Green

### New file: SignalHandler.swift
1. Define `SignalEvent` enum with `.none`, `.interrupt`, `.forceExit`, `.terminate` cases
2. Define `SignalHandler` enum with `register()`, `check() -> SignalEvent`, `clearInterrupt()` static methods
3. Use `sigaction` for cross-platform signal registration (Darwin/Glibc)
4. Track SIGINT timestamps for double-press detection (1 second window)
5. Use volatile flags for thread-safe signal handler communication

### Modified file: REPLLoop.swift
1. In `start()`, check `SignalHandler.check()` during stream consumption
2. On `.interrupt`: call `agent.interrupt()`, output `^C\n`, continue REPL loop
3. On `.forceExit`: call `agent.interrupt()`, break REPL loop (triggers `closeAgentSafely`)
4. On `.terminate`: break REPL loop (triggers `closeAgentSafely`)

### Modified file: CLI.swift
1. Call `SignalHandler.register()` at startup
2. Check for `.terminate` signal in REPL mode to trigger graceful shutdown

## Test Files Created/Modified

1. `Tests/OpenAgentCLITests/SignalHandlerTests.swift` (8 new test methods - NEW FILE)
2. `Tests/OpenAgentCLITests/REPLLoopInterruptTests.swift` (5 new test methods - NEW FILE)
