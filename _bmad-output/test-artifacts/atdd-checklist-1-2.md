---
stepsCompleted:
  - step-01-preflight-and-context
  - step-02-generation-mode
  - step-03-test-strategy
  - step-04-generate-tests
  - step-05-validate-and-complete
lastStep: step-05-validate-and-complete
lastSaved: '2026-04-19'
workflowType: testarch-atdd
inputDocuments:
  - _bmad-output/implementation-artifacts/1-2-agent-factory-with-core-configuration.md
  - _bmad-output/planning-artifacts/epics.md
  - _bmad-output/planning-artifacts/architecture.md
  - Sources/OpenAgentCLI/ArgumentParser.swift
  - Sources/OpenAgentCLI/CLI.swift
  - Sources/OpenAgentCLI/ConfigLoader.swift
  - Tests/OpenAgentCLITests/ArgumentParserTests.swift
  - Tests/OpenAgentCLITests/ConfigLoaderTests.swift
---

# ATDD Checklist - Epic 1, Story 1.2: Agent Factory & Core Configuration

**Date:** 2026-04-19
**Author:** Nick (TEA Agent)
**Primary Test Level:** Unit (XCTest)

---

## Story Summary

As a developer, I want the CLI to create an SDK Agent using three core configuration parameters (base_url, api_key, model), so that I can connect to any compatible LLM API (GLM, Anthropic, OpenAI, etc.).

**As a** developer
**I want** the CLI to create an SDK Agent using base_url, api_key, and model configuration
**So that** I can connect to any compatible LLM API

---

## Acceptance Criteria

1. **AC#1:** Given `--api-key <key> --base-url <url> --model <model>`, Agent uses specified base_url, api_key, and model
2. **AC#2:** Given only `--api-key` and `--base-url` (no --model), Agent uses default model "glm-5.1"
3. **AC#3:** Given `OPENAGENT_API_KEY` env var and no `--api-key`, Agent uses env var API key
4. **AC#4:** Given no API key at all, displays error "Set --api-key or OPENAGENT_API_KEY" and exits code 1
5. **AC#5:** Given `--max-turns 5` and `--max-budget 1.0`, AgentOptions.maxTurns=5, maxBudgetUsd=1.0

---

## Test Strategy

### Stack Detection

- **Detected stack:** `backend` (Swift Package Manager, Package.swift, no frontend dependencies)
- **Test framework:** XCTest (Swift built-in)
- **Test runner:** `swift test`

### Test Level Selection

| Level | Usage | Justification |
|-------|-------|---------------|
| Unit | Primary | AgentFactory is a static enum with pure conversion logic + SDK factory call |
| Integration | Included | Full pipeline tests: ArgumentParser.parse -> AgentFactory.createAgent |
| E2E | N/A | No browser-based testing needed for backend Swift CLI |

### Priority Assignments

- **P0 (Critical):** AC#1-AC#5 direct coverage -- full params, default model, API key validation, max-turns/budget
- **P1 (High):** Provider conversion, permission mode conversion, thinking config, tool allow/deny, system prompt
- **P2 (Medium):** LogLevel mapping helper, invalid provider/mode error paths
- **P3 (Low):** Combined configuration test, cwd setting

---

## Generation Mode

**Mode:** AI Generation (sequential)
**Rationale:** Backend project with XCTest. Acceptance criteria are clear and well-defined. No UI recording needed.

---

## Failing Tests Created (RED Phase)

### Unit Tests (38 tests)

**File:** `Tests/OpenAgentCLITests/AgentFactoryTests.swift` (530 lines)

#### AC#1: Full params -- api-key + base-url + model (3 tests)

- **[P0]** `testCreateAgent_fullParams_returnsAgent` -- Verifies Agent is non-nil with full params
  - **Status:** RED - `cannot find 'AgentFactory' in scope`
  - **Verifies:** AC#1 (agent creation with full params)

- **[P0]** `testCreateAgent_fullParams_usesSpecifiedModel` -- Verifies agent.model == "custom-model"
  - **Status:** RED - `cannot find 'AgentFactory' in scope`
  - **Verifies:** AC#1 (model passed through)

- **[P1]** `testCreateAgent_fullParams_usesSpecifiedBaseURL` -- Verifies creation succeeds with custom baseURL
  - **Status:** RED - `cannot find 'AgentFactory' in scope`
  - **Verifies:** AC#1 (baseURL passed through)

#### AC#2: Default model "glm-5.1" (2 tests)

- **[P0]** `testCreateAgent_defaultModel_usesGLM` -- Verifies agent.model == "glm-5.1" when default
  - **Status:** RED - `cannot find 'AgentFactory' in scope`
  - **Verifies:** AC#2 (default model is glm-5.1)

- **[P0]** `testCreateAgent_explicitlyPassedGLM_usesGLM` -- Verifies explicit glm-5.1 works
  - **Status:** RED - `cannot find 'AgentFactory' in scope`
  - **Verifies:** AC#2 (explicit default model)

#### AC#3: API Key from environment variable (2 tests)

- **[P0]** `testCreateAgent_apiKeyFromArgs_succeeds` -- API key from ParsedArgs works
  - **Status:** RED - `cannot find 'AgentFactory' in scope`
  - **Verifies:** AC#3 (API key resolution)

- **[P0]** `testCreateAgent_apiKeyFromEnvVar_succeeds` -- Verifies ArgumentParser resolves OPENAGENT_API_KEY
  - **Status:** RED - `cannot find 'AgentFactory' in scope`
  - **Verifies:** AC#3 (env var key resolution chain)

#### AC#4: Missing API Key -> error (2 tests)

- **[P0]** `testCreateAgent_missingApiKey_throwsError` -- Throws AgentFactoryError when nil apiKey
  - **Status:** RED - `cannot find 'AgentFactoryError' in scope`
  - **Verifies:** AC#4 (missing key throws)

- **[P0]** `testCreateAgent_missingApiKey_errorIsActionable` -- Error mentions --api-key or OPENAGENT_API_KEY
  - **Status:** RED - `cannot find 'AgentFactoryError' in scope`
  - **Verifies:** AC#4 (actionable error message)

#### AC#5: max-turns and max-budget (3 tests)

- **[P0]** `testCreateAgent_maxTurns_passedToAgent` -- agent.maxTurns == 5
  - **Status:** RED - `cannot find 'AgentFactory' in scope`
  - **Verifies:** AC#5 (maxTurns pass-through)

- **[P1]** `testCreateAgent_maxBudget_passedThrough` -- Creation succeeds with maxBudgetUsd
  - **Status:** RED - `cannot find 'AgentFactory' in scope`
  - **Verifies:** AC#5 (maxBudgetUsd pass-through)

- **[P1]** `testCreateAgent_maxTurnsDefault_isTen` -- Default maxTurns == 10
  - **Status:** RED - `cannot find 'AgentFactory' in scope`
  - **Verifies:** AC#5 (default maxTurns)

#### LogLevel mapping helper (5 tests)

- **[P2]** `testMapLogLevel_debug_returnsDebug` -- "debug" -> LogLevel.debug
- **[P2]** `testMapLogLevel_info_returnsInfo` -- "info" -> LogLevel.info
- **[P2]** `testMapLogLevel_warn_returnsWarn` -- "warn" -> LogLevel.warn
- **[P2]** `testMapLogLevel_error_returnsError` -- "error" -> LogLevel.error
- **[P2]** `testMapLogLevel_nil_returnsNone` -- nil -> LogLevel.none

#### Provider conversion (4 tests)

- **[P1]** `testCreateAgent_providerAnthropic_succeeds` -- anthropic provider works
- **[P1]** `testCreateAgent_providerOpenAI_succeeds` -- openai provider works
- **[P2]** `testCreateAgent_invalidProvider_throwsError` -- Invalid provider throws AgentFactoryError
- **[P1]** `testCreateAgent_noProvider_defaultsToAnthropic` -- nil provider defaults to anthropic

#### Permission mode conversion (5 tests)

- **[P1]** `testCreateAgent_modeDefault_succeeds` -- "default" mode
- **[P1]** `testCreateAgent_modeBypassPermissions_succeeds` -- "bypassPermissions" mode
- **[P1]** `testCreateAgent_modePlan_succeeds` -- "plan" mode
- **[P1]** `testCreateAgent_modeAuto_succeeds` -- "auto" mode
- **[P2]** `testCreateAgent_invalidMode_throwsError` -- Invalid mode throws

#### Thinking config (2 tests)

- **[P1]** `testCreateAgent_thinkingEnabled_createsAgent` -- thinking=8192 passes through
- **[P1]** `testCreateAgent_thinkingNil_noThinking` -- nil thinking passes

#### Tool allow/deny (3 tests)

- **[P1]** `testCreateAgent_toolAllowPassed_createsAgent` -- allowedTools passthrough
- **[P1]** `testCreateAgent_toolDenyPassed_createsAgent` -- disallowedTools passthrough
- **[P1]** `testCreateAgent_toolAllowAndDeny_createsAgent` -- Both together

#### System prompt (2 tests)

- **[P1]** `testCreateAgent_systemPrompt_createsAgent` -- systemPrompt passthrough with verification
- **[P1]** `testCreateAgent_nilSystemPrompt_createsAgent` -- nil systemPrompt

#### cwd (1 test)

- **[P3]** `testCreateAgent_setsCwd` -- Creation succeeds with cwd set

#### Integration: Full pipeline (3 tests)

- **[P0]** `testFullPipeline_apiKeyAndModel_argsToAgent` -- ArgumentParser.parse -> AgentFactory.createAgent
  - **Status:** RED - `cannot find 'AgentFactory' in scope`
  - **Verifies:** Full AC#1 pipeline

- **[P0]** `testFullPipeline_missingApiKey_argsThrowAtFactory` -- Full pipeline: no key -> throw
  - **Status:** RED - `cannot find 'AgentFactory' in scope`
  - **Verifies:** Full AC#4 pipeline

- **[P0]** `testFullPipeline_envVarKey_resolvedByParser` -- Full pipeline: env var -> parser -> factory
  - **Status:** RED - `cannot find 'AgentFactory' in scope`
  - **Verifies:** Full AC#3 pipeline

#### Combined configuration (1 test)

- **[P3]** `testCreateAgent_allOptionsCombined_createsAgent` -- All options at once
  - **Status:** RED - `cannot find 'AgentFactory' in scope`

---

## Acceptance Criteria Coverage Matrix

| AC | Tests | Priority | Status |
|----|-------|----------|--------|
| AC#1: Full params -> Agent with specified config | 3 tests + 1 pipeline | P0 | RED |
| AC#2: Missing --model -> default "glm-5.1" | 2 tests | P0 | RED |
| AC#3: OPENAGENT_API_KEY env var -> Agent | 1 test + 1 pipeline | P0 | RED |
| AC#4: No API key -> error message, exit 1 | 2 tests + 1 pipeline | P0 | RED |
| AC#5: --max-turns 5, --max-budget 1.0 | 3 tests | P0 | RED |
| (Extended: provider conversion) | 4 tests | P1-P2 | RED |
| (Extended: permission mode) | 5 tests | P1-P2 | RED |
| (Extended: thinking config) | 2 tests | P1 | RED |
| (Extended: tool allow/deny) | 3 tests | P1 | RED |
| (Extended: system prompt) | 2 tests | P1 | RED |
| (Extended: logLevel mapping) | 5 tests | P2 | RED |
| (Extended: combined config) | 1 test | P3 | RED |

---

## Implementation Checklist

### Test: All 38 tests in AgentFactoryTests.swift

**File:** `Tests/OpenAgentCLITests/AgentFactoryTests.swift`

**Tasks to make these tests pass:**

- [ ] Create `Sources/OpenAgentCLI/AgentFactory.swift` with:
  - [ ] Define `AgentFactoryError` enum conforming to `LocalizedError`:
    - [ ] `.missingApiKey` -- message: guidance on --api-key / OPENAGENT_API_KEY
    - [ ] `.invalidProvider(String)` -- message: name the invalid provider
    - [ ] `.invalidMode(String)` -- message: name the invalid mode
  - [ ] Define `AgentFactory` enum with:
    - [ ] `static func createAgent(from args: ParsedArgs) throws -> Agent`
      - [ ] Validate API key is non-nil (throw `.missingApiKey`)
      - [ ] Convert provider string to `LLMProvider` (throw `.invalidProvider` if invalid)
      - [ ] Convert mode string to `PermissionMode` (throw `.invalidMode` if invalid)
      - [ ] Convert thinking int to `ThinkingConfig.enabled(budgetTokens:)`
      - [ ] Convert logLevel string using `mapLogLevel(_:)`
      - [ ] Build `AgentOptions` with all fields from ParsedArgs
      - [ ] Call `OpenAgentSDK.createAgent(options:)` and return result
    - [ ] `static func mapLogLevel(_ string: String?) -> LogLevel`
      - [ ] "debug" -> .debug, "info" -> .info, "warn" -> .warn, "error" -> .error, nil -> .none
  - [ ] **Critical**: Always pass `args.model` ("glm-5.1") to AgentOptions -- never rely on SDK default ("claude-sonnet-4-6")
- [ ] Update `Sources/OpenAgentCLI/CLI.swift`:
  - [ ] Replace "Agent creation not yet implemented" with `AgentFactory.createAgent(from:)`
  - [ ] Replace "REPL mode not yet implemented" with `AgentFactory.createAgent(from:)`
  - [ ] Handle AgentFactoryError -> stderr message + exit(1)
  - [ ] Move API key nil check to AgentFactory (let it throw)
- [ ] Run tests: `swift test --filter AgentFactoryTests`
- [ ] All 38 tests pass (green phase)

**Estimated Effort:** 1-2 hours

---

## Running Tests

```bash
# Build tests only (faster, shows compilation errors)
swift build --build-tests

# Run all tests
swift test

# Run specific test file
swift test --filter AgentFactoryTests

# Run a single test by name
swift test --filter AgentFactoryTests/testCreateAgent_fullParams_returnsAgent

# Run both story test files
swift test --filter "AgentFactoryTests|ArgumentParserTests"
```

---

## Red-Green-Refactor Workflow

### RED Phase (Complete)

**TEA Agent Responsibilities:**

- 38 failing tests written in `AgentFactoryTests.swift`
- All tests exercise `AgentFactory.createAgent(from:)` and `AgentFactory.mapLogLevel(_:)`
- No subprocess spawning -- pure unit tests (some call ArgumentParser.parse for pipeline tests)
- All 5 acceptance criteria covered with dedicated test cases
- Extended coverage for provider, mode, thinking, tools, system prompt, logLevel
- Full pipeline integration tests verifying ArgumentParser -> AgentFactory chain

**Verification:**

```
Build errors: 96 (all "cannot find 'AgentFactory' in scope" or "cannot find type 'AgentFactoryError' in scope")
Test count: 38 test methods
Line count: 530 lines
Failure reason: AgentFactory and AgentFactoryError types do not exist yet (intentional)
```

---

### GREEN Phase (DEV Team - Next Steps)

1. Pick tests in priority order: P0 first (AC#1-AC#5), then P1 (provider/mode/thinking/tools), then P2 (logLevel/invalid), then P3 (combined)
2. Create `AgentFactory.swift` with `AgentFactoryError` enum and `AgentFactory` enum
3. Run `swift test --filter AgentFactoryTests` after each incremental implementation
4. Watch tests turn green one by one

---

### REFACTOR Phase (After All Tests Pass)

1. Review `AgentFactory.createAgent(from:)` for readability
2. Consider extracting conversion helpers if method becomes too long
3. Ensure tests still pass after each refactor

---

## Test Execution Evidence

### Initial Build Attempt (RED Phase Verification)

**Command:** `swift build --build-tests`

**Results:**

```
error: cannot find 'AgentFactory' in scope (multiple occurrences)
error: cannot find type 'AgentFactoryError' in scope (multiple occurrences)
Total build errors: 96
```

**Summary:**

- Total test methods: 38
- Passing: 0 (expected -- tests cannot compile)
- Failing: 38 (expected -- AgentFactory type not yet implemented)
- Build errors: 96 (all referencing AgentFactory and AgentFactoryError)
- Status: RED phase verified

**Expected Failure Reason:**
All tests reference `AgentFactory.createAgent(from:)` and `AgentFactoryError`, which are types that will be created in `Sources/OpenAgentCLI/AgentFactory.swift` as part of the implementation. This is the correct TDD red phase state.

---

## Notes

- **SDK Default vs CLI Default**: SDK's `AgentOptions.model` defaults to "claude-sonnet-4-6", but CLI's `ParsedArgs.model` defaults to "glm-5.1". AgentFactory must ALWAYS pass the ParsedArgs model value explicitly -- never rely on the SDK default.
- **Testability pattern**: `AgentFactory.createAgent(from:)` accepts a `ParsedArgs` struct, making it fully unit-testable. `mapLogLevel(_:)` is exposed as a static method for direct testing.
- **Error design**: `AgentFactoryError` uses `LocalizedError` with `errorDescription` to provide actionable error messages that guide users to fix the issue.
- **Existing ConfigLoader**: The configuration priority chain (CLI args > env vars > config file) is already handled by `ConfigLoader.apply()` in CLI.swift before AgentFactory is called. AgentFactory receives the final merged `ParsedArgs`.
- **Pipeline tests**: Three tests exercise the full chain from raw CLI args through ArgumentParser.parse() into AgentFactory.createAgent(), validating the integration between Story 1.1 and Story 1.2.

---

**Generated by BMad TEA Agent** - 2026-04-19
