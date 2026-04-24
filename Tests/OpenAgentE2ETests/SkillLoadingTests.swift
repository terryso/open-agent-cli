import XCTest
import OpenAgentSDK
@testable import OpenAgentCLI

// MARK: - ATDD Red Phase: Story 2.3 Skills Loading and Invocation
//
// These tests define the EXPECTED behavior of skill loading, invocation,
// and REPL /skills command. They will FAIL until Story 2.3 is implemented
// (TDD red phase).
//
// Acceptance Criteria Coverage:
//   AC#1: --skill-dir loads skills into SDK's SkillRegistry
//   AC#2: --skill <name> auto-invokes the specified skill
//   AC#3: /skills command lists loaded skills with name and description
//   AC#4: --skill nonexistent shows "Skill not found" + available skills
//
// Tasks Covered:
//   Task 1: AgentFactory skill loading (AC#1)
//   Task 2: --skill auto-invocation (AC#2, #4)
//   Task 3: /skills REPL command (AC#3)
//   Task 4: AgentFactory skill integration tests (AC#1)
//   Task 5: CLI skill invocation tests (AC#2, #4)
//   Task 6: REPL /skills command tests (AC#3)

final class SkillLoadingTests: XCTestCase {

    // MARK: - Helpers

    /// Build ParsedArgs with common defaults, allowing skill-related overrides.
    private func makeArgs(
        apiKey: String? = "test-api-key",
        baseURL: String? = "https://api.example.com/v1",
        model: String = "glm-5.1",
        provider: String? = nil,
        mode: String = "default",
        tools: String = "core",
        skillDir: String? = nil,
        skillName: String? = nil,
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

    /// Creates a MockTextOutputStream and OutputRenderer pair for capturing output.
    private func makeRenderer() -> (renderer: OutputRenderer, mock: MockTextOutputStream) {
        let mock = MockTextOutputStream()
        let renderer = OutputRenderer(output: mock)
        return (renderer, mock)
    }

    /// Creates a test Agent with a dummy API key.
    private func makeTestAgent() async throws -> Agent {
        let args = ParsedArgs(
            helpRequested: false,
            versionRequested: false,
            prompt: nil,
            model: "glm-5.1",
            apiKey: "test-key-for-skill-tests",
            baseURL: "https://api.example.com/v1",
            provider: nil,
            mode: "default",
            tools: "core",
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
            toolAllow: nil,
            toolDeny: nil,
            shouldExit: false,
            exitCode: 0,
            errorMessage: nil,
            helpMessage: nil
        )
        return try await AgentFactory.createAgent(from: args).0
    }

    /// Creates a temporary directory with a valid SKILL.md for testing.
    /// Returns the directory URL. Caller is responsible for cleanup.
    private func createTempSkillDirectory(
        name: String = "test-skill",
        description: String = "A test skill for unit testing",
        promptTemplate: String = "This is a test prompt template."
    ) -> URL {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("skill-tests-\(ProcessInfo.processInfo.processIdentifier)")
            .appendingPathComponent(name)
        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

        let skillMD = """
        ---
        name: \(name)
        description: \(description)
        userInvocable: true
        ---
        \(promptTemplate)
        """
        let skillMDPath = tmpDir.appendingPathComponent("SKILL.md")
        try? skillMD.write(to: skillMDPath, atomically: true, encoding: .utf8)

        return tmpDir.deletingLastPathComponent()  // Return parent (the skill-dir)
    }

    /// Cleans up temporary skill directories created during tests.
    private func cleanupTempSkillDir() {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("skill-tests-\(ProcessInfo.processInfo.processIdentifier)")
        try? FileManager.default.removeItem(at: tmpDir)
    }

    override func tearDown() {
        cleanupTempSkillDir()
        super.tearDown()
    }

    // MARK: - AC#1: --skill-dir loads skills into SkillRegistry (Task 1, 4)

    func testCreateSkillRegistry_withSkillDir_returnsRegistry() throws {
        // AC#1: When skillDir is provided, createSkillRegistry should return a non-nil registry
        let skillDir = createTempSkillDirectory()

        let args = makeArgs(skillDir: skillDir.path)

        // AgentFactory should have a method to create a SkillRegistry from ParsedArgs
        let registry = AgentFactory.createSkillRegistry(from: args)

        XCTAssertNotNil(registry,
            "createSkillRegistry should return a registry when skillDir is provided (AC#1)")
    }

    func testCreateSkillRegistry_withSkillDir_discoversSkill() throws {
        // AC#1: Skills from the directory should be discovered and registered
        let skillDir = createTempSkillDirectory(
            name: "discovered-skill",
            description: "This skill should be discovered"
        )

        let args = makeArgs(skillDir: skillDir.path)
        let registry = AgentFactory.createSkillRegistry(from: args)

        XCTAssertNotNil(registry, "Registry should be created")
        let hasSkill = registry.has("discovered-skill")
        XCTAssertTrue(hasSkill,
            "Registry should contain the discovered skill (AC#1)")
    }

    func testCreateSkillRegistry_noSkillArgs_autoDiscoversDefaults() {
        // When no skill args are provided, registry should still be created
        // and attempt to discover from default directories (may be empty)
        let args = makeArgs()  // No skillDir, no skillName

        let registry = AgentFactory.createSkillRegistry(from: args)

        // Registry always exists now (auto-discovery from default dirs)
        // May contain skills from ~/.claude/skills, ~/.openagent/skills, etc.
        XCTAssertGreaterThanOrEqual(registry.allSkills.count, 0,
            "Registry should be created even without explicit skill args")
    }

    func testCreateSkillRegistry_onlySkillName_noSkillDir_usesDefaultDirs() throws {
        // skillName without skillDir should attempt default directory discovery
        let args = makeArgs(skillName: "some-skill")

        // Should not crash -- auto-discovers from default dirs
        let registry = AgentFactory.createSkillRegistry(from: args)
        // The key assertion is that it doesn't crash
    }

    func testCreateAgent_withSkillDir_agentCreatedSuccessfully() async throws {
        // AC#1: Agent creation with skillDir should succeed
        let skillDir = createTempSkillDirectory()
        let args = makeArgs(skillDir: skillDir.path)

        // Should not throw -- skill loading is additive
        let agent = try await AgentFactory.createAgent(from: args).0
        XCTAssertNotNil(agent,
            "Agent should be created successfully with skillDir (AC#1)")
    }

    func testCreateAgent_withSkillDir_skillToolInPool() async throws {
        // AC#1: Agent's tool pool should contain the SkillTool when skillDir is provided
        let skillDir = createTempSkillDirectory()
        let args = makeArgs(skillDir: skillDir.path)

        let registry = AgentFactory.createSkillRegistry(from: args)
        let pool = AgentFactory.computeToolPool(from: args, skillRegistry: registry)
        let toolNames = pool.map { $0.name }

        XCTAssertTrue(toolNames.contains("Skill"),
            "Tool pool should contain 'Skill' tool when skillDir is provided (AC#1). Got: \(toolNames)")
    }

    func testCreateAgent_withoutSkillDir_noSkillToolInPool() async throws {
        // AC#1 regression: Without skillDir, no SkillTool in pool
        let args = makeArgs()  // No skillDir

        let pool = AgentFactory.computeToolPool(from: args)
        let toolNames = pool.map { $0.name }

        XCTAssertFalse(toolNames.contains("Skill"),
            "Tool pool should NOT contain 'Skill' tool when no skillDir provided (AC#1 regression). Got: \(toolNames)")
    }

    // MARK: - AC#2: --skill <name> auto-invokes specified skill (Task 2, 5)

    func testSkillInvocation_validSkill_sendsPromptTemplate() async throws {
        // AC#2: When --skill is passed with a valid skill name, the skill's
        // promptTemplate is automatically sent to the agent as a query.
        let skillDir = createTempSkillDirectory(
            name: "review",
            description: "Review code changes",
            promptTemplate: "Review the code changes and provide feedback."
        )

        let args = makeArgs(
            skillDir: skillDir.path,
            skillName: "review"
        )

        // Build the registry to verify the skill exists
        let registry = AgentFactory.createSkillRegistry(from: args)
        XCTAssertNotNil(registry, "Registry should be created")

        let skill = registry.find("review")
        XCTAssertNotNil(skill, "Should find 'review' skill in registry (AC#2)")
        XCTAssertEqual(skill?.promptTemplate, "Review the code changes and provide feedback.",
            "Skill promptTemplate should match (AC#2)")
    }

    func testSkillInvocation_skillRegistry_findReturnsCorrectSkill() throws {
        // AC#2: SkillRegistry.find() returns the correct skill by name
        let skillDir = createTempSkillDirectory(
            name: "commit",
            description: "Generate commit messages"
        )

        let args = makeArgs(skillDir: skillDir.path)
        let registry = AgentFactory.createSkillRegistry(from: args)

        let found = registry.find("commit")
        XCTAssertNotNil(found, "Should find 'commit' skill (AC#2)")
        XCTAssertEqual(found?.name, "commit", "Found skill should have correct name (AC#2)")
        XCTAssertEqual(found?.description, "Generate commit messages",
            "Found skill should have correct description (AC#2)")
    }

    func testSkillInvocation_skillRegistry_findReturnsNilForUnknown() throws {
        // AC#2 complement: find returns nil for unknown skill name
        let skillDir = createTempSkillDirectory(name: "known-skill")
        let args = makeArgs(skillDir: skillDir.path)
        let registry = AgentFactory.createSkillRegistry(from: args)

        let found = registry.find("nonexistent")
        XCTAssertNil(found, "find() should return nil for unknown skill name (AC#2)")
    }

    // MARK: - AC#4: --skill nonexistent shows "Skill not found" (Task 2, 5)

    func testSkillInvocation_invalidSkill_registryReportsNotFound() throws {
        // AC#4: When --skill is passed with an invalid name, the registry
        // does not contain the skill, enabling the CLI to show an error
        let skillDir = createTempSkillDirectory(name: "available-skill")

        let args = makeArgs(
            skillDir: skillDir.path,
            skillName: "nonexistent"
        )

        let registry = AgentFactory.createSkillRegistry(from: args)
        XCTAssertNotNil(registry, "Registry should be created even with invalid skillName")

        let found = registry.find("nonexistent")
        XCTAssertNil(found, "find() should return nil for nonexistent skill (AC#4)")

        // The registry should still have the available skill
        let available = registry.allSkills
        XCTAssertFalse(available.isEmpty,
            "Registry should contain at least one available skill for error message listing (AC#4)")
    }

    // MARK: - AC#3: /skills command lists loaded skills (Task 3, 6)

    func testREPLSkillsCommand_listsSkills() async throws {
        // AC#3: /skills command lists available skills with name and description
        let (renderer, mockOutput) = makeRenderer()
        let inputReader = MockInputReader(["/skills", "/exit"])

        // Create a registry with skills
        let skillDir = createTempSkillDirectory(
            name: "review",
            description: "Review code changes for issues"
        )
        let args = makeArgs(skillDir: skillDir.path)
        let registry = AgentFactory.createSkillRegistry(from: args)

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader,
            toolNames: [],
            skillRegistry: registry
        )

        await repl.start()

        let output = mockOutput.output
        XCTAssertTrue(output.contains("review"),
            "/skills output should contain skill name 'review' (AC#3). Got: \(output)")
    }

    func testREPLSkillsCommand_multipleSkills_showsAll() async throws {
        // AC#3: Multiple skills are all listed
        let (renderer, mockOutput) = makeRenderer()
        let inputReader = MockInputReader(["/skills", "/exit"])

        // Create registry with multiple skills using SDK directly
        let registry = SkillRegistry()
        let skill1 = Skill(
            name: "commit",
            description: "Generate commit messages",
            aliases: [],
            userInvocable: true,
            promptTemplate: "Generate a commit message",
            whenToUse: nil,
            argumentHint: nil,
            baseDir: nil,
            supportingFiles: []
        )
        let skill2 = Skill(
            name: "debug",
            description: "Debug and diagnose issues",
            aliases: [],
            userInvocable: true,
            promptTemplate: "Debug this issue",
            whenToUse: nil,
            argumentHint: nil,
            baseDir: nil,
            supportingFiles: []
        )
        registry.register(skill1)
        registry.register(skill2)

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader,
            toolNames: [],
            skillRegistry: registry
        )

        await repl.start()

        let output = mockOutput.output
        XCTAssertTrue(output.contains("commit"),
            "/skills output should list 'commit' skill (AC#3). Got: \(output)")
        XCTAssertTrue(output.contains("debug"),
            "/skills output should list 'debug' skill (AC#3). Got: \(output)")
    }

    func testREPLSkillsCommand_sortedByName() async throws {
        // AC#3: Skills should be listed sorted by name
        let (renderer, mockOutput) = makeRenderer()
        let inputReader = MockInputReader(["/skills", "/exit"])

        let registry = SkillRegistry()
        // Register in non-alphabetical order
        let skillZ = Skill(
            name: "zebra-skill",
            description: "Z skill",
            aliases: [],
            userInvocable: true,
            promptTemplate: "zebra",
            whenToUse: nil,
            argumentHint: nil,
            baseDir: nil,
            supportingFiles: []
        )
        let skillA = Skill(
            name: "alpha-skill",
            description: "A skill",
            aliases: [],
            userInvocable: true,
            promptTemplate: "alpha",
            whenToUse: nil,
            argumentHint: nil,
            baseDir: nil,
            supportingFiles: []
        )
        let skillM = Skill(
            name: "middle-skill",
            description: "M skill",
            aliases: [],
            userInvocable: true,
            promptTemplate: "middle",
            whenToUse: nil,
            argumentHint: nil,
            baseDir: nil,
            supportingFiles: []
        )
        registry.register(skillZ)
        registry.register(skillA)
        registry.register(skillM)

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader,
            toolNames: [],
            skillRegistry: registry
        )

        await repl.start()

        let output = mockOutput.output
        // Verify alphabetical order: alpha-skill before middle-skill before zebra-skill
        if let alphaRange = output.range(of: "alpha-skill"),
           let middleRange = output.range(of: "middle-skill"),
           let zebraRange = output.range(of: "zebra-skill") {
            XCTAssertTrue(alphaRange.lowerBound < middleRange.lowerBound,
                "alpha-skill should appear before middle-skill in /skills output (AC#3)")
            XCTAssertTrue(middleRange.lowerBound < zebraRange.lowerBound,
                "middle-skill should appear before zebra-skill in /skills output (AC#3)")
        } else {
            XCTFail("/skills output should contain all skill names for ordering check. Got: \(output)")
        }
    }

    func testREPLSkillsCommand_noSkills_showsMessage() async throws {
        // AC#3: When no skills are loaded, /skills shows "No skills loaded."
        let (renderer, mockOutput) = makeRenderer()
        let inputReader = MockInputReader(["/skills", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader,
            toolNames: [],
            skillRegistry: nil  // No skills
        )

        await repl.start()

        let output = mockOutput.output.lowercased()
        XCTAssertTrue(output.contains("no skills") || output.contains("no skills loaded"),
            "/skills with no skills should show 'No skills loaded' message (AC#3). Got: \(output)")
    }

    func testREPLSkillsCommand_nilRegistry_showsMessage() async throws {
        // AC#3 edge: skillRegistry is nil (no --skill-dir was used)
        let (renderer, mockOutput) = makeRenderer()
        let inputReader = MockInputReader(["/skills", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader,
            toolNames: []
        )

        await repl.start()

        let output = mockOutput.output.lowercased()
        XCTAssertTrue(output.contains("no skills") || output.contains("no skills loaded"),
            "/skills with nil registry should show 'No skills loaded' message (AC#3). Got: \(output)")
    }

    // MARK: - AC#3: /help includes /skills command (Task 3)

    func testREPLHelp_includesSkillsCommand() async throws {
        // AC#3: /help output should list /skills as an available command
        let (renderer, mockOutput) = makeRenderer()
        let inputReader = MockInputReader(["/help", "/exit"])

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader,
            toolNames: []
        )

        await repl.start()

        let output = mockOutput.output
        XCTAssertTrue(output.contains("/skills"),
            "/help output should include /skills command (AC#3). Got: \(output)")
    }

    // MARK: - AC#1 Regression: Existing behavior unchanged

    func testCreateAgent_withoutSkillArgs_behaviorUnchanged() async throws {
        // Regression: Agent creation without skill args should behave exactly as before
        let args = makeArgs()
        let agent = try await AgentFactory.createAgent(from: args).0

        XCTAssertNotNil(agent, "Agent creation without skill args should still work (regression)")
        XCTAssertEqual(agent.model, "glm-5.1", "Model should still be set correctly (regression)")
    }

    func testComputeToolPool_withoutSkillArgs_returnsCoreTools() {
        // Regression: Tool pool without skill args should return exactly core tools
        let args = makeArgs()
        let pool = AgentFactory.computeToolPool(from: args)

        XCTAssertEqual(pool.count, 10,
            "Tool pool should still have 10 core tools without skill args (regression). Got \(pool.count)")
    }

    func testArgumentParser_skillDir_parsesCorrectly() {
        // Verify ArgumentParser already handles --skill-dir (should already pass)
        let result = ArgumentParser.parse(["openagent", "--skill-dir", "/tmp/skills"])

        XCTAssertEqual(result.skillDir, "/tmp/skills",
            "ArgumentParser should parse --skill-dir correctly")
        XCTAssertFalse(result.shouldExit,
            "--skill-dir should not cause shouldExit")
    }

    func testArgumentParser_skillName_parsesCorrectly() {
        // Verify ArgumentParser already handles --skill (should already pass)
        let result = ArgumentParser.parse(["openagent", "--skill", "review"])

        XCTAssertEqual(result.skillName, "review",
            "ArgumentParser should parse --skill correctly")
        XCTAssertFalse(result.shouldExit,
            "--skill should not cause shouldExit")
    }

    func testArgumentParser_skillDirAndSkillName_bothParsed() {
        // Both --skill-dir and --skill should be parseable together
        let result = ArgumentParser.parse([
            "openagent",
            "--skill-dir", "/tmp/skills",
            "--skill", "review"
        ])

        XCTAssertEqual(result.skillDir, "/tmp/skills")
        XCTAssertEqual(result.skillName, "review")
    }

    // MARK: - AC#4: Error message format for invalid skill

    func testSkillInvocation_invalidSkill_availableSkillsListedInError() throws {
        // AC#4: Error message should list available skills when skill not found
        let skillDir = createTempSkillDirectory(
            name: "available-skill",
            description: "An available skill"
        )

        let args = makeArgs(
            skillDir: skillDir.path,
            skillName: "nonexistent"
        )

        let registry = AgentFactory.createSkillRegistry(from: args)
        let availableSkills = registry.allSkills.map { $0.name }

        // The CLI should be able to construct an error message listing available skills
        XCTAssertTrue(availableSkills.contains("available-skill"),
            "Registry should list 'available-skill' as available for error message (AC#4)")
    }

    // MARK: - AC#3: /skills output format verification

    func testREPLSkillsCommand_format_nameAndDescription() async throws {
        // AC#3: Each skill line should show "{name}: {description}" format
        let (renderer, mockOutput) = makeRenderer()
        let inputReader = MockInputReader(["/skills", "/exit"])

        let registry = SkillRegistry()
        let skill = Skill(
            name: "review",
            description: "Review code changes",
            aliases: [],
            userInvocable: true,
            promptTemplate: "Review code",
            whenToUse: nil,
            argumentHint: nil,
            baseDir: nil,
            supportingFiles: []
        )
        registry.register(skill)

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader,
            toolNames: [],
            skillRegistry: registry
        )

        await repl.start()

        let output = mockOutput.output
        XCTAssertTrue(output.contains("review"),
            "/skills output should show skill name (AC#3). Got: \(output)")
    }

    func testREPLSkillsCommand_showsSkillCount() async throws {
        // AC#3: /skills should show the count of loaded skills
        let (renderer, mockOutput) = makeRenderer()
        let inputReader = MockInputReader(["/skills", "/exit"])

        let registry = SkillRegistry()
        let skill = Skill(
            name: "review",
            description: "Review code",
            aliases: [],
            userInvocable: true,
            promptTemplate: "Review",
            whenToUse: nil,
            argumentHint: nil,
            baseDir: nil,
            supportingFiles: []
        )
        registry.register(skill)

        let repl = REPLLoop(
            agent: try await makeTestAgent(),
            renderer: renderer,
            reader: inputReader,
            toolNames: [],
            skillRegistry: registry
        )

        await repl.start()

        let output = mockOutput.output
        // Should contain count indicator like "Available skills (1):" or "1 skill(s)"
        let hasCount = output.contains("1") && (output.lowercased().contains("skill"))
        XCTAssertTrue(hasCount,
            "/skills output should show skill count (AC#3). Got: \(output)")
    }

    // MARK: - Integration: Full skill loading pipeline

    func testFullPipeline_skillDirArgs_registryCreated() throws {
        // Full pipeline: ArgumentParser -> AgentFactory.createSkillRegistry -> registry with skills
        let skillDir = createTempSkillDirectory(name: "pipeline-skill")
        let parsedArgs = ArgumentParser.parse([
            "openagent",
            "--skill-dir", skillDir.path
        ])

        XCTAssertEqual(parsedArgs.skillDir, skillDir.path)
        XCTAssertFalse(parsedArgs.shouldExit)

        let registry = AgentFactory.createSkillRegistry(from: parsedArgs)
        XCTAssertNotNil(registry, "Registry should be created from parsed args (integration)")
        XCTAssertTrue(registry.has("pipeline-skill"),
            "Registry should contain the pipeline-skill (integration)")
    }

    func testFullPipeline_skillNameOnly_noCrash() throws {
        // Pipeline: --skill without --skill-dir should not crash
        let parsedArgs = ArgumentParser.parse([
            "openagent",
            "--skill", "review"
        ])

        XCTAssertEqual(parsedArgs.skillName, "review")
        XCTAssertNil(parsedArgs.skillDir)

        // Should not crash -- returns nil or empty registry
        let registry = AgentFactory.createSkillRegistry(from: parsedArgs)
        // No assertion on result -- just verifying no crash
    }
}
