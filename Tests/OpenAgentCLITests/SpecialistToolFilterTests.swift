import XCTest
import OpenAgentSDK
@testable import OpenAgentCLI

// MARK: - ATDD Red Phase: Story 6.2 Specialist Tools & Tool Filtering
//
// These tests define the EXPECTED behavior of specialist tool loading,
// tool-allow filtering, and tool-deny filtering. They follow the TDD
// red-green-refactor cycle.
//
// Acceptance Criteria Coverage:
//   AC#1: --tools specialist loads all specialist tools
//   AC#2: --tool-deny "Bash,Write" excludes specified tools
//   AC#3: --tool-allow "Read,Grep,Glob" restricts to specified tools only
//
// Edge Cases:
//   - tool-allow + tool-deny combined (deny takes precedence)
//   - empty tool-allow / tool-deny (no filtering)
//   - specialist tier includes Agent tool (createAgentTool)
//   - all tier loads core + specialist combined
//   - tool filtering works with specialist tier

final class SpecialistToolFilterTests: XCTestCase {

    // MARK: - Helpers

    /// Build ParsedArgs with common defaults, allowing tool-related overrides.
    private func makeArgs(
        apiKey: String? = "test-api-key",
        baseURL: String? = "https://api.example.com/v1",
        model: String = "glm-5.1",
        provider: String? = nil,
        mode: String = "default",
        tools: String = "specialist",
        toolAllow: [String]? = nil,
        toolDeny: [String]? = nil
    ) -> ParsedArgs {
        ParsedArgs(
            helpRequested: false,
            versionRequested: false,
            prompt: nil,
            model: model,
            apiKey: apiKey,
            baseURL: baseURL,
            provider: provider,
            mode: mode,
            tools: tools,
            mcpConfigPath: nil,
            hooksConfigPath: nil,
            skillDir: nil,
            skillName: nil,
            sessionId: nil,
            noRestore: false,
            maxTurns: 10,
            maxBudgetUsd: nil,
            systemPrompt: nil,
            thinking: nil,
            quiet: false,
            output: "text",
            logLevel: nil,
            toolAllow: toolAllow,
            toolDeny: toolDeny,
            shouldExit: false,
            exitCode: 0,
            errorMessage: nil,
            helpMessage: nil
        )
    }

    // MARK: - AC#1: --tools specialist loads all specialist tools

    /// AC#1: Specialist tier should load all specialist tools.
    /// The story spec says: Worktree, Plan, Cron, TodoWrite, LSP, Config,
    /// RemoteTrigger, MCP Resource tools.
    func testSpecialistTier_loadsAllSpecialistTools() {
        let tools = AgentFactory.mapToolTier("specialist")
        let names = Set(tools.map { $0.name })

        // Story 6.2 lists these specialist tools (13 per SDK):
        let expectedSpecialistTools: Set<String> = [
            "EnterWorktree", "ExitWorktree",
            "EnterPlanMode", "ExitPlanMode",
            "CronCreate", "CronDelete", "CronList",
            "TodoWrite",
            "LSP",
            "Config",
            "RemoteTrigger",
            "ListMcpResources", "ReadMcpResource"
        ]

        XCTAssertTrue(names.isSuperset(of: expectedSpecialistTools),
            "Specialist tier should contain all expected specialist tools. " +
            "Missing: \(expectedSpecialistTools.subtracting(names)). " +
            "Got: \(names.sorted())")
    }

    /// AC#1: Specialist tier should contain at least 13 tools (the known specialist set).
    func testSpecialistTier_hasExpectedCount() {
        let tools = AgentFactory.mapToolTier("specialist")

        XCTAssertGreaterThanOrEqual(tools.count, 13,
            "Specialist tier should load at least 13 specialist tools (AC#1). Got \(tools.count): " +
            tools.map { $0.name }.sorted().joined(separator: ", "))
    }

    /// AC#1: Specialist tier does NOT include core tools.
    /// PRD FR3.3 says --tools specialist loads specialist layer only.
    /// Users who need core + specialist should use --tools all.
    func testSpecialistTier_doesNotIncludeCoreTools() {
        let specialistTools = AgentFactory.mapToolTier("specialist")
        let coreTools = AgentFactory.mapToolTier("core")

        let specialistNames = Set(specialistTools.map { $0.name })
        let coreNames = Set(coreTools.map { $0.name })

        // Verify no overlap between specialist and core tool sets
        let overlap = specialistNames.intersection(coreNames)
        XCTAssertTrue(overlap.isEmpty,
            "Specialist tier should NOT include core tools. " +
            "Overlap found: \(overlap). " +
            "Use --tools all for core + specialist.")
    }

    /// AC#1: computeToolPool with --tools specialist includes Agent tool.
    /// When specialist is selected, sub-agent delegation should be available.
    func testSpecialistTier_includesAgentTool() {
        let args = makeArgs(tools: "specialist")
        let pool = AgentFactory.computeToolPool(from: args)
        let names = pool.map { $0.name }

        XCTAssertTrue(names.contains("Agent"),
            "Specialist tier tool pool should include Agent tool for sub-agent delegation (AC#1). " +
            "Got: \(names)")
    }

    /// AC#1: --tools all loads core + specialist combined.
    func testAllTier_loadsCoreAndSpecialistTools() {
        let coreTools = AgentFactory.mapToolTier("core")
        let specialistTools = AgentFactory.mapToolTier("specialist")
        let allTools = AgentFactory.mapToolTier("all")

        let expectedCount = coreTools.count + specialistTools.count
        XCTAssertEqual(allTools.count, expectedCount,
            "All tier should load Core + Specialist (\(expectedCount) tools). " +
            "Got \(allTools.count)")
    }

    /// AC#1: Integration test - createAgent with --tools specialist succeeds.
    func testCreateAgent_specialistTools_createsAgent() async throws {
        let args = makeArgs(tools: "specialist")

        let agent = try await AgentFactory.createAgent(from: args).0

        XCTAssertNotNil(agent,
            "Agent creation with --tools specialist should succeed (AC#1)")
    }

    // MARK: - AC#2: --tool-deny excludes specified tools

    /// AC#2: --tool-deny "Bash,Write" correctly excludes both tools from core pool.
    func testToolDeny_excludesSpecifiedTools() {
        let args = makeArgs(
            tools: "core",
            toolDeny: ["Bash", "Write"]
        )

        let pool = AgentFactory.computeToolPool(from: args)
        let names = pool.map { $0.name }

        let unfilteredPool = AgentFactory.computeToolPool(from: makeArgs(tools: "core"))
        XCTAssertFalse(names.contains("Bash"),
            "Bash should be excluded by --tool-deny (AC#2)")
        XCTAssertFalse(names.contains("Write"),
            "Write should be excluded by --tool-deny (AC#2)")
        XCTAssertEqual(pool.count, unfilteredPool.count - 2,
            "Core minus Bash and Write should be \(unfilteredPool.count - 2) tools. Got \(pool.count)")
    }

    /// AC#2: --tool-deny with a single tool excludes only that tool.
    func testToolDeny_singleTool() {
        let args = makeArgs(
            tools: "core",
            toolDeny: ["Bash"]
        )

        let pool = AgentFactory.computeToolPool(from: args)
        let names = pool.map { $0.name }

        let unfilteredPool = AgentFactory.computeToolPool(from: makeArgs(tools: "core"))
        XCTAssertFalse(names.contains("Bash"),
            "Bash should be excluded by --tool-deny (AC#2)")
        XCTAssertEqual(pool.count, unfilteredPool.count - 1,
            "Core minus Bash should be \(unfilteredPool.count - 1) tools. Got \(pool.count)")
    }

    /// AC#2: --tool-deny works correctly with specialist tier tools.
    func testToolDeny_withSpecialistTools() {
        let args = makeArgs(
            tools: "specialist",
            toolDeny: ["CronCreate", "TodoWrite"]
        )

        let pool = AgentFactory.computeToolPool(from: args)
        let names = pool.map { $0.name }

        XCTAssertFalse(names.contains("CronCreate"),
            "CronCreate should be excluded by --tool-deny in specialist tier (AC#2)")
        XCTAssertFalse(names.contains("TodoWrite"),
            "TodoWrite should be excluded by --tool-deny in specialist tier (AC#2)")
    }

    /// AC#2: --tool-deny works with --tools all (both core + specialist filtering).
    func testToolDeny_withAllTier() {
        let args = makeArgs(
            tools: "all",
            toolDeny: ["Bash", "CronCreate"]
        )

        let pool = AgentFactory.computeToolPool(from: args)
        let names = pool.map { $0.name }

        XCTAssertFalse(names.contains("Bash"),
            "Bash should be excluded from all tier by --tool-deny (AC#2)")
        XCTAssertFalse(names.contains("CronCreate"),
            "CronCreate should be excluded from all tier by --tool-deny (AC#2)")
    }

    // MARK: - AC#3: --tool-allow restricts to specified tools only

    /// AC#3: --tool-allow "Read,Grep,Glob" restricts pool to only those 3 tools.
    func testToolAllow_restrictsToSpecifiedTools() {
        let args = makeArgs(
            tools: "core",
            toolAllow: ["Read", "Grep", "Glob"]
        )

        let pool = AgentFactory.computeToolPool(from: args)
        let names = Set(pool.map { $0.name })

        XCTAssertEqual(names, ["Read", "Grep", "Glob"],
            "Tool pool with --tool-allow should contain only Read, Grep, Glob (AC#3). " +
            "Got \(names)")
    }

    /// AC#3: --tool-allow with a single tool restricts to just that tool.
    func testToolAllow_singleTool() {
        let args = makeArgs(
            tools: "core",
            toolAllow: ["Read"]
        )

        let pool = AgentFactory.computeToolPool(from: args)
        let names = Set(pool.map { $0.name })

        XCTAssertEqual(names, ["Read"],
            "Tool pool with --tool-allow Read should contain only Read (AC#3). " +
            "Got \(names)")
    }

    /// AC#3: --tool-allow works correctly with specialist tier.
    func testToolAllow_withSpecialistTools() {
        let args = makeArgs(
            tools: "specialist",
            toolAllow: ["LSP", "Config", "TodoWrite"]
        )

        let pool = AgentFactory.computeToolPool(from: args)
        let names = Set(pool.map { $0.name })

        // Only the allowed tools from specialist tier should be present (exact match)
        XCTAssertEqual(names, ["LSP", "Config", "TodoWrite"],
            "Tool pool should contain exactly the allowed specialist tools (AC#3). " +
            "Got \(names)")
    }

    /// AC#3: --tool-allow with tool names that don't exist in the tier results in empty pool.
    func testToolAllow_nonExistentTools_resultsInEmptyOrFilteredPool() {
        let args = makeArgs(
            tools: "core",
            toolAllow: ["NonExistentTool1", "NonExistentTool2"]
        )

        let pool = AgentFactory.computeToolPool(from: args)

        // Pool should be empty since none of the allowed tools exist in core
        XCTAssertTrue(pool.isEmpty,
            "Tool pool with --tool-allow for non-existent tools should be empty. " +
            "Got \(pool.count) tools: \(pool.map { $0.name })")
    }

    // MARK: - AC#2 + AC#3: Deny takes precedence over allow

    /// AC#2 + AC#3: When a tool is in both --tool-allow and --tool-deny,
    /// deny wins (the tool should be excluded).
    func testToolAllowAndDeny_denyTakesPrecedence() {
        let args = makeArgs(
            tools: "core",
            toolAllow: ["Bash", "Read", "Write"],
            toolDeny: ["Write"]
        )

        let pool = AgentFactory.computeToolPool(from: args)
        let names = Set(pool.map { $0.name })

        XCTAssertFalse(names.contains("Write"),
            "Deny should take precedence — Write should be excluded even when allowed (AC#2+AC#3)")
        XCTAssertEqual(names, ["Bash", "Read"],
            "Pool should contain only allowed tools minus denied tools. Got \(names)")
    }

    /// AC#2 + AC#3: Deny takes precedence with specialist tools.
    func testToolAllowAndDeny_denyTakesPrecedence_withSpecialistTools() {
        let args = makeArgs(
            tools: "specialist",
            toolAllow: ["LSP", "Config", "TodoWrite", "CronCreate"],
            toolDeny: ["CronCreate"]
        )

        let pool = AgentFactory.computeToolPool(from: args)
        let names = Set(pool.map { $0.name })

        XCTAssertFalse(names.contains("CronCreate"),
            "Deny should take precedence for specialist tools — CronCreate excluded (AC#2+AC#3)")
        XCTAssertTrue(names.contains("LSP"),
            "LSP should still be in the pool")
        XCTAssertTrue(names.contains("Config"),
            "Config should still be in the pool")
        XCTAssertTrue(names.contains("TodoWrite"),
            "TodoWrite should still be in the pool")
    }

    // MARK: - Edge Cases: Empty allow/deny lists

    /// Empty tool-allow array should NOT filter the tool pool.
    func testEmptyToolAllow_noFiltering() {
        let argsCoreOnly = makeArgs(tools: "core", toolAllow: nil)
        let argsEmptyAllow = makeArgs(tools: "core", toolAllow: [])

        let poolCore = AgentFactory.computeToolPool(from: argsCoreOnly)
        let poolEmpty = AgentFactory.computeToolPool(from: argsEmptyAllow)

        XCTAssertEqual(poolCore.count, poolEmpty.count,
            "Empty tool-allow should not change tool pool size. " +
            "Core: \(poolCore.count), Empty allow: \(poolEmpty.count)")
    }

    /// Empty tool-deny array should NOT filter the tool pool.
    func testEmptyToolDeny_noFiltering() {
        let argsCoreOnly = makeArgs(tools: "core", toolDeny: nil)
        let argsEmptyDeny = makeArgs(tools: "core", toolDeny: [])

        let poolCore = AgentFactory.computeToolPool(from: argsCoreOnly)
        let poolEmpty = AgentFactory.computeToolPool(from: argsEmptyDeny)

        XCTAssertEqual(poolCore.count, poolEmpty.count,
            "Empty tool-deny should not change tool pool size. " +
            "Core: \(poolCore.count), Empty deny: \(poolEmpty.count)")
    }

    // MARK: - Edge Cases: ArgumentParser integration for tool flags

    /// Verify ArgumentParser correctly parses --tool-allow comma-separated values.
    func testArgumentParser_toolAllow_parsesCommaSeparated() {
        let args = ArgumentParser.parse([
            "openagent",
            "--tool-allow", "Read,Grep,Glob"
        ])

        XCTAssertEqual(args.toolAllow, ["Read", "Grep", "Glob"],
            "ArgumentParser should split --tool-allow by commas")
        XCTAssertFalse(args.shouldExit,
            "Valid --tool-allow should not trigger exit")
    }

    /// Verify ArgumentParser correctly parses --tool-deny comma-separated values.
    func testArgumentParser_toolDeny_parsesCommaSeparated() {
        let args = ArgumentParser.parse([
            "openagent",
            "--tool-deny", "Bash,Write"
        ])

        XCTAssertEqual(args.toolDeny, ["Bash", "Write"],
            "ArgumentParser should split --tool-deny by commas")
        XCTAssertFalse(args.shouldExit,
            "Valid --tool-deny should not trigger exit")
    }

    /// Verify ArgumentParser accepts --tools specialist as valid tier.
    func testArgumentParser_toolsSpecialist_accepted() {
        let args = ArgumentParser.parse([
            "openagent",
            "--tools", "specialist"
        ])

        XCTAssertEqual(args.tools, "specialist",
            "ArgumentParser should accept 'specialist' as valid tool tier")
        XCTAssertFalse(args.shouldExit,
            "Valid --tools specialist should not trigger exit")
    }

    /// Verify ArgumentParser rejects invalid tool tier.
    func testArgumentParser_invalidToolTier_rejected() {
        let args = ArgumentParser.parse([
            "openagent",
            "--tools", "invalid"
        ])

        XCTAssertTrue(args.shouldExit,
            "Invalid tool tier should trigger exit")
        XCTAssertEqual(args.exitCode, 1,
            "Invalid tool tier should set exit code 1")
        XCTAssertNotNil(args.errorMessage,
            "Invalid tool tier should produce an error message")
    }

    // MARK: - Full Pipeline Integration Tests

    /// Full pipeline: ArgumentParser -> AgentFactory with --tools specialist
    func testFullPipeline_specialistTools_argsToAgent() async throws {
        let parsedArgs = ArgumentParser.parse([
            "openagent",
            "--api-key", "pipeline-test-key",
            "--tools", "specialist"
        ])

        XCTAssertEqual(parsedArgs.tools, "specialist")
        XCTAssertFalse(parsedArgs.shouldExit)

        let agent = try await AgentFactory.createAgent(from: parsedArgs).0
        XCTAssertNotNil(agent,
            "Full pipeline with --tools specialist should create agent successfully")
    }

    /// Full pipeline: ArgumentParser -> AgentFactory with --tool-allow
    func testFullPipeline_toolAllow_argsToPool() async throws {
        let parsedArgs = ArgumentParser.parse([
            "openagent",
            "--api-key", "pipeline-test-key",
            "--tools", "core",
            "--tool-allow", "Read,Grep"
        ])

        let pool = AgentFactory.computeToolPool(from: parsedArgs)
        let names = Set(pool.map { $0.name })

        XCTAssertEqual(names, ["Read", "Grep"],
            "Full pipeline with --tool-allow should restrict pool. Got \(names)")
    }

    /// Full pipeline: ArgumentParser -> AgentFactory with --tool-deny
    func testFullPipeline_toolDeny_argsToPool() async throws {
        let parsedArgs = ArgumentParser.parse([
            "openagent",
            "--api-key", "pipeline-test-key",
            "--tools", "core",
            "--tool-deny", "Bash,Write"
        ])

        let pool = AgentFactory.computeToolPool(from: parsedArgs)
        let names = pool.map { $0.name }

        XCTAssertFalse(names.contains("Bash"))
        XCTAssertFalse(names.contains("Write"))
        let unfilteredPool = AgentFactory.computeToolPool(
            from: ArgumentParser.parse([
                "openagent",
                "--api-key", "pipeline-test-key",
                "--tools", "core"
            ])
        )
        XCTAssertEqual(pool.count, unfilteredPool.count - 2,
            "Core minus Bash and Write should be \(unfilteredPool.count - 2). Got \(pool.count)")
    }

    /// Full pipeline: combined specialist + allow + deny
    func testFullPipeline_specialistWithAllowAndDeny() async throws {
        let parsedArgs = ArgumentParser.parse([
            "openagent",
            "--api-key", "pipeline-test-key",
            "--tools", "specialist",
            "--tool-allow", "LSP,Config,TodoWrite,CronCreate",
            "--tool-deny", "CronCreate"
        ])

        let pool = AgentFactory.computeToolPool(from: parsedArgs)
        let names = Set(pool.map { $0.name })

        XCTAssertFalse(names.contains("CronCreate"),
            "Denied tool should be excluded even in specialist tier pipeline")
        XCTAssertTrue(names.contains("LSP"))
        XCTAssertTrue(names.contains("Config"))
        XCTAssertTrue(names.contains("TodoWrite"))
    }
}
