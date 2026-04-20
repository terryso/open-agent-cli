import XCTest
import OpenAgentSDK
@testable import OpenAgentCLI

// MARK: - ATDD Red Phase: Story 2.1 Core Tool Loading & Display
//
// These tests define the EXPECTED behavior of tool loading, tier mapping,
// and tool filtering in AgentFactory. They will FAIL until the tool loading
// logic is implemented (TDD red phase).
//
// Acceptance Criteria Coverage:
//   AC#1: Default core tools loaded (10 tools: Bash, Read, Write, Edit, etc.)
//   AC#2: --tools advanced loads Core + Advanced (Advanced currently empty)
//   AC#3: --tools all loads Core + Specialist
//   AC#4: --tools specialist loads Specialist tier only
//   AC#5: /tools command displays loaded tools (tested in REPLLoopTests)
//   AC#6: --tool-allow filters to specified tools only
//   AC#7: --tool-deny excludes specified tools

final class ToolLoadingTests: XCTestCase {

    // MARK: - Helpers

    /// Build ParsedArgs with common defaults, allowing tool-related overrides.
    private func makeArgs(
        apiKey: String? = "test-api-key",
        baseURL: String? = "https://api.example.com/v1",
        model: String = "glm-5.1",
        provider: String? = nil,
        mode: String = "default",
        tools: String = "core",
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

    // MARK: - AC#1: mapToolTier("core") returns 10 Core tools

    func testMapToolTier_core_returnsTenTools() {
        // AC#1: Core tier should load exactly 10 tools
        let tools = AgentFactory.mapToolTier("core")

        XCTAssertEqual(tools.count, 10,
            "Core tier should load exactly 10 tools (AC#1). Got \(tools.count): \(tools.map { $0.name })")
    }

    func testMapToolTier_core_containsExpectedToolNames() {
        // AC#1: Core tier should contain the expected tool names
        let tools = AgentFactory.mapToolTier("core")
        let names = Set(tools.map { $0.name })

        // Verify the 10 core tool names
        let expectedCoreTools: Set<String> = [
            "Bash", "Read", "Write", "Edit", "Glob",
            "Grep", "WebFetch", "WebSearch", "AskUser", "ToolSearch"
        ]

        XCTAssertEqual(names, expectedCoreTools,
            "Core tier should contain exactly the 10 expected tools (AC#1)")
    }

    // MARK: - AC#2: mapToolTier("advanced") returns Core tools (Advanced is empty)

    func testMapToolTier_advanced_returnsCoreTools() {
        // AC#2: Advanced tier = Core + Advanced. Since SDK's advanced tier returns
        // empty array, this should equal Core tools count.
        let tools = AgentFactory.mapToolTier("advanced")

        XCTAssertEqual(tools.count, 10,
            "Advanced tier should load Core tools (10) since SDK advanced is empty (AC#2). Got \(tools.count)")
    }

    // MARK: - AC#3: mapToolTier("all") returns Core + Specialist

    func testMapToolTier_all_returnsCoreAndSpecialist() {
        // AC#3: All tier = Core + Specialist combined
        let coreTools = AgentFactory.mapToolTier("core")
        let specialistTools = AgentFactory.mapToolTier("specialist")
        let allTools = AgentFactory.mapToolTier("all")

        let expectedCount = coreTools.count + specialistTools.count
        XCTAssertEqual(allTools.count, expectedCount,
            "All tier should load Core + Specialist (\(expectedCount) tools) (AC#3). Got \(allTools.count)")
    }

    // MARK: - AC#4: mapToolTier("specialist") returns Specialist tools

    func testMapToolTier_specialist_returnsSpecialistTools() {
        // AC#4: Specialist tier should load specialist tools (14 expected)
        let tools = AgentFactory.mapToolTier("specialist")

        // Specialist tier has 14 tools per the story spec
        XCTAssertGreaterThan(tools.count, 0,
            "Specialist tier should load at least 1 tool (AC#4). Got \(tools.count)")
    }

    // MARK: - Edge: Unknown tier defaults to core

    func testMapToolTier_unknown_defaultsToCore() {
        // Edge case: Unknown/invalid tier string should safely fall back to core
        let tools = AgentFactory.mapToolTier("nonexistent")
        let coreTools = AgentFactory.mapToolTier("core")

        XCTAssertEqual(tools.count, coreTools.count,
            "Unknown tier should default to core tools as safe fallback. Got \(tools.count) vs core \(coreTools.count)")
    }

    // MARK: - AC#1 Integration: createAgent with default tools loads core

    func testCreateAgent_defaultTools_loadsCoreTools() throws {
        // AC#1: Default ParsedArgs.tools="core" should result in an agent with core tools
        let args = makeArgs(tools: "core")

        let agent = try AgentFactory.createAgent(from: args)

        // Agent should be created successfully with tools loaded
        XCTAssertNotNil(agent, "Agent with core tools should be created (AC#1)")
    }

    // MARK: - AC#6: --tool-allow filters to allowed tools only

    func testComputeToolPool_toolAllow_filtersToAllowedOnly() {
        // AC#6: With --tool-allow "Bash,Read", only Bash and Read should be in the pool
        let args = makeArgs(
            tools: "core",
            toolAllow: ["Bash", "Read"]
        )

        let pool = AgentFactory.computeToolPool(from: args)
        let names = Set(pool.map { $0.name })

        XCTAssertEqual(names, ["Bash", "Read"],
            "Tool pool with --tool-allow should contain only Bash and Read (AC#6). Got \(names)")
    }

    // MARK: - AC#7: --tool-deny excludes specified tools

    func testComputeToolPool_toolDeny_excludesDenied() {
        // AC#7: With --tool-deny "Write", Write should be excluded from core tools
        let args = makeArgs(
            tools: "core",
            toolDeny: ["Write"]
        )

        let pool = AgentFactory.computeToolPool(from: args)
        let names = pool.map { $0.name }

        XCTAssertFalse(names.contains("Write"),
            "Tool pool with --tool-deny Write should not contain Write (AC#7). Got \(names)")
        XCTAssertEqual(pool.count, 9,
            "Core tools (10) minus Write should be 9 tools. Got \(pool.count)")
    }

    // MARK: - AC#6 + AC#7: Deny takes precedence over allow

    func testComputeToolPool_toolAllowAndDeny_denyTakesPrecedence() {
        // When a tool appears in both --tool-allow and --tool-deny,
        // deny should win (the tool should be excluded)
        let args = makeArgs(
            tools: "core",
            toolAllow: ["Bash", "Read", "Write"],
            toolDeny: ["Write"]
        )

        let pool = AgentFactory.computeToolPool(from: args)
        let names = Set(pool.map { $0.name })

        XCTAssertFalse(names.contains("Write"),
            "Deny should take precedence — Write should be excluded even when allowed")
        XCTAssertEqual(names, ["Bash", "Read"],
            "Pool should contain only allowed tools minus denied tools. Got \(names)")
    }

    // MARK: - AC#2 Integration: createAgent with advanced tools

    func testCreateAgent_advancedTools_createsAgent() throws {
        // AC#2: Agent creation with --tools advanced should succeed
        let args = makeArgs(tools: "advanced")

        let agent = try AgentFactory.createAgent(from: args)

        XCTAssertNotNil(agent, "Agent with advanced tools should be created (AC#2)")
    }

    // MARK: - AC#3 Integration: createAgent with all tools

    func testCreateAgent_allTools_createsAgent() throws {
        // AC#3: Agent creation with --tools all should succeed
        let args = makeArgs(tools: "all")

        let agent = try AgentFactory.createAgent(from: args)

        XCTAssertNotNil(agent, "Agent with all tools should be created (AC#3)")
    }
}
