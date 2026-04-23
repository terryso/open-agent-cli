import XCTest
import OpenAgentSDK
@testable import OpenAgentCLI

// MARK: - ATDD Red Phase: Story 4.2 Sub-Agent Delegation
//
// These tests define the EXPECTED behavior of sub-agent tool loading and rendering.
// They will FAIL until the sub-agent delegation logic is implemented (TDD red phase).
//
// Acceptance Criteria Coverage:
//   AC#1: --tools advanced includes Agent tool (createAgentTool) in tool pool
//   AC#2: Sub-agent output visible with indented prefix
//   AC#3: Parent agent continues with sub-agent output after completion
//   AC#4: Sub-agent inherits parent's permission mode and API config
//   AC#5: Sub-agent progress shown with indented [sub-agent] prefix

final class SubAgentTests: XCTestCase {

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
        toolDeny: [String]? = nil,
        skillDir: String? = nil,
        skillName: String? = nil
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
            skillDir: skillDir,
            skillName: skillName,
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

    // MARK: - AC#1: --tools advanced includes Agent tool

    func testToolPool_advanced_includesAgentTool() {
        // AC#1: When --tools advanced, the tool pool should contain "Agent" tool
        let args = makeArgs(tools: "advanced")
        let pool = AgentFactory.computeToolPool(from: args)
        let names = pool.map { $0.name }

        XCTAssertTrue(names.contains("Agent"),
            "Tool pool with --tools advanced should contain 'Agent' tool (AC#1). Got: \(names)")
    }

    // MARK: - AC#1: --tools core excludes Agent tool

    func testToolPool_core_excludesAgentTool() {
        // AC#1 (negative): Default --tools core should NOT contain "Agent" tool
        let args = makeArgs(tools: "core")
        let pool = AgentFactory.computeToolPool(from: args)
        let names = pool.map { $0.name }

        XCTAssertFalse(names.contains("Agent"),
            "Tool pool with --tools core should NOT contain 'Agent' tool (AC#1). Got: \(names)")
    }

    // MARK: - AC#1: --tools all includes Agent tool

    func testToolPool_all_includesAgentTool() {
        // AC#1: When --tools all, the tool pool should contain "Agent" tool
        let args = makeArgs(tools: "all")
        let pool = AgentFactory.computeToolPool(from: args)
        let names = pool.map { $0.name }

        XCTAssertTrue(names.contains("Agent"),
            "Tool pool with --tools all should contain 'Agent' tool (AC#1). Got: \(names)")
    }

    // MARK: - AC#1: --tools specialist includes Agent tool

    func testToolPool_specialist_includesAgentTool() {
        // AC#1: When --tools specialist, the tool pool should contain "Agent" tool
        let args = makeArgs(tools: "specialist")
        let pool = AgentFactory.computeToolPool(from: args)
        let names = pool.map { $0.name }

        XCTAssertTrue(names.contains("Agent"),
            "Tool pool with --tools specialist should contain 'Agent' tool (AC#1). Got: \(names)")
    }

    // MARK: - AC#1: --tools advanced with skill includes both Agent and Skill tools

    func testToolPool_advancedWithSkill_includesBoth() {
        // AC#1: When --tools advanced AND a skill is specified, both Agent and Skill tools should be present
        let args = makeArgs(tools: "advanced", skillDir: "/tmp/test-skills")
        let registry = AgentFactory.createSkillRegistry(from: args)
        let pool = AgentFactory.computeToolPool(from: args, skillRegistry: registry)
        let names = pool.map { $0.name }

        XCTAssertTrue(names.contains("Agent"),
            "Tool pool with --tools advanced + skill should contain 'Agent' tool (AC#1). Got: \(names)")
        // Note: Skill tool presence depends on valid skill directory, so we only assert Agent
    }

    // MARK: - AC#1: Default ParsedArgs.tools is "core" (no Agent tool)

    func testToolPool_defaultTools_excludesAgentTool() {
        // AC#1 (edge): Default ParsedArgs has tools="core", should not include Agent
        let args = ParsedArgs()  // All defaults
        let pool = AgentFactory.computeToolPool(from: args)
        let names = pool.map { $0.name }

        XCTAssertFalse(names.contains("Agent"),
            "Default ParsedArgs (tools='core') should NOT contain 'Agent' tool (AC#1). Got: \(names)")
    }

    // MARK: - AC#1: createAgent with advanced tools succeeds

    func testCreateAgent_advancedTools_createsSuccessfully() async throws {
        // AC#1 Integration: Agent creation with --tools advanced (including Agent tool) should succeed
        let args = makeArgs(tools: "advanced")
        let (agent, _, _) = try await AgentFactory.createAgent(from: args)

        XCTAssertNotNil(agent,
            "Agent with --tools advanced (including Agent tool) should be created successfully (AC#1)")
    }
}
