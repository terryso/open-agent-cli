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
  - _bmad-output/implementation-artifacts/1-3-streaming-output-renderer.md
  - Sources/OpenAgentCLI/ANSI.swift
  - Sources/OpenAgentCLI/CLI.swift
  - Tests/OpenAgentCLITests/AgentFactoryTests.swift
  - open-agent-sdk-swift/Sources/OpenAgentSDK/Types/SDKMessage.swift
  - open-agent-sdk-swift/Sources/OpenAgentSDK/Types/TokenUsage.swift
---

# ATDD Checklist: Story 1.3 -- Streaming Output Renderer

## TDD Red Phase (Current)

All tests are designed to **FAIL** until `OutputRenderer` is implemented. Tests use
`XCTSkip` or throw at initialization because the types (`OutputRenderer`,
`OutputRendering`, `AnyTextOutputStream`, `MockTextOutputStream`) do not yet exist.

- **Total Tests:** 27
- **Test File:** `Tests/OpenAgentCLITests/OutputRendererTests.swift`
- **Test Framework:** XCTest (Swift Package Manager)
- **Execution Mode:** Sequential (backend project -- no browser tests needed)

## Acceptance Criteria Coverage

| AC# | Criterion | Test Scenarios | Priority |
|-----|-----------|---------------|----------|
| AC#1 | partialMessage streams text chunk-by-chunk, no buffering | `testPartialMessage_outputsTextWithoutNewline`, `testPartialMessage_multipleChunks_concatenates` | P0 |
| AC#2 | assistant with error shows red error type + actionable guidance | `testAssistant_error_showsRedError`, `testAssistant_noError_producesNoOutput` | P0 |
| AC#3 | result shows summary line with turns/cost/duration; error subtypes red; cancelled grey | `testResult_success_summaryLine`, `testResult_errorMaxTurns_redHighlight`, `testResult_errorDuringExecution_redHighlight`, `testResult_errorMaxBudgetUsd_redHighlight`, `testResult_cancelled_greyDisplay` | P0 |
| AC#4 | system messages shown in grey with `[system]` prefix | `testSystem_init_greyPrefix`, `testSystem_compactBoundary_greyPrefix`, `testSystem_status_greyPrefix` | P1 |
| AC#5 | error result shows each error message in red with actionable guidance | `testResult_error_showsEachErrorMessage`, `testResult_error_providesActionableGuidance` | P0 |
| AC#6 | All SDKMessage cases handled, including @unknown default | `testRender_handlesAllKnownCases`, `testRender_toolUse_basicOutput`, `testRender_toolResult_success`, `testRender_toolResult_error_showsRed`, `testRenderStream_consumesEntireStream` | P0 |

## Test Strategy

### Test Level Selection

This is a **backend Swift** project. All tests are **unit tests** at the XCTest level.

- **Unit tests** for pure rendering logic (OutputRenderer + TextOutputStream abstraction)
- No integration or E2E tests needed for this component (it's a pure rendering function)

### Priority Matrix

| Priority | Count | Description |
|----------|-------|-------------|
| P0 | 18 | Core rendering: partialMessage, assistant errors, result summary, error subtypes, forward compat |
| P1 | 6 | System messages, tool use/result basic rendering |
| P2 | 3 | Edge cases: empty text, zero-cost result, very long text |

## Test File Structure

```
Tests/OpenAgentCLITests/
  OutputRendererTests.swift    # 27 tests covering all 6 acceptance criteria
```

## Detailed Test Inventory

### AC#1: partialMessage Streaming (P0)

1. `testPartialMessage_outputsTextWithoutNewline` -- Single chunk outputs text with empty terminator
2. `testPartialMessage_multipleChunks_concatenates` -- Multiple chunks concatenate without separators
3. `testPartialMessage_emptyString_noOutput` -- Empty string chunk produces no output

### AC#2: Assistant Error Handling (P0)

4. `testAssistant_error_showsRedError` -- AssistantData with error renders red ANSI error
5. `testAssistant_error_includesErrorType` -- Error output includes the error case name (e.g., rateLimit)
6. `testAssistant_noError_producesNoOutput` -- Normal assistant (no error) produces no output (already streamed via partialMessage)

### AC#3: Result Summary Line (P0)

7. `testResult_success_summaryLine` -- Success: `--- Turns: N | Cost: $X.XXXX | Duration: Xs`
8. `testResult_success_correctTurns` -- Verifies numTurns value in summary
9. `testResult_success_correctCost` -- Verifies cost formatting (4 decimal places)
10. `testResult_success_correctDuration` -- Verifies duration conversion ms -> seconds
11. `testResult_errorMaxTurns_redHighlight` -- Error subtype renders with red ANSI
12. `testResult_errorDuringExecution_redHighlight` -- Error subtype renders with red ANSI
13. `testResult_errorMaxBudgetUsd_redHighlight` -- Error subtype renders with red ANSI
14. `testResult_cancelled_greyDisplay` -- Cancelled renders with dim/grey ANSI
15. `testResult_errorMaxStructuredOutputRetries_redHighlight` -- Error subtype renders with red ANSI

### AC#4: System Messages (P1)

16. `testSystem_init_greyPrefix` -- System init renders as `[system] message` with dim
17. `testSystem_compactBoundary_greyPrefix` -- compactBoundary renders same format
18. `testSystem_status_greyPrefix` -- status renders same format

### AC#5: Error Details (P0)

19. `testResult_error_showsEachErrorMessage` -- Multiple errors each displayed
20. `testResult_error_providesActionableGuidance` -- Error output includes guidance text

### AC#6: Forward Compatibility + Full Coverage (P0/P1)

21. `testRender_toolUse_basicOutput` -- ToolUse renders tool name in cyan
22. `testRender_toolResult_success` -- Successful tool result renders content
23. `testRender_toolResult_error_showsRed` -- Tool result error renders in red
24. `testRender_handlesAllKnownCases_noCrash` -- All SDKMessage cases render without crash
25. `testRenderStream_consumesEntireStream` -- renderStream processes all messages in AsyncStream
26. `testOutputRenderer_usesCustomTextOutputStream` -- Verifies TextOutputStream abstraction works
27. `testOutputRenderer_defaultInit_succeeds` -- Default init creates a working renderer

## Implementation Guidance

### Types to Create

1. `Sources/OpenAgentCLI/OutputRenderer.swift`:
   - `protocol OutputRendering: Sendable` with `render(_:)` and `renderStream(_:)`
   - `struct OutputRenderer: OutputRendering` with `TextOutputStream` abstraction
   - `struct AnyTextOutputStream: TextOutputStream` (type erasure)
   - `struct FileHandleTextOutputStream: TextOutputStream` (stdout)

2. `Sources/OpenAgentCLI/OutputRenderer+SDKMessage.swift`:
   - Extension on `OutputRenderer` with per-case render methods

3. `Sources/OpenAgentCLI/ANSI.swift`:
   - Add `green(_:)` and `yellow(_:)` if needed (verify at implementation time)

4. `Sources/OpenAgentCLI/CLI.swift`:
   - Replace placeholder prints with OutputRenderer.stream integration

### Test Infrastructure

The test file includes `MockTextOutputStream` inline -- no separate fixture file needed.

## Next Steps (TDD Green Phase)

After implementing the feature:

1. Run tests: `swift test --filter OutputRendererTests`
2. Verify tests PASS (green phase)
3. If any tests fail, fix implementation or test as appropriate
4. Commit passing tests alongside implementation

## Risks and Assumptions

- **Assumption:** All SDK data types have public `init` (confirmed from SDK source)
- **Assumption:** `@unknown default` on SDKMessage switch will not be needed for current 19 cases, but tests verify graceful handling
- **Risk:** ANSI escape codes in assertions may vary by terminal -- tests check for presence of expected escape sequences
- **Risk:** AsyncStream testing requires `async` test methods (XCTest supports this on macOS 13+)
