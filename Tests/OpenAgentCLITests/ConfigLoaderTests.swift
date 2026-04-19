import XCTest
@testable import OpenAgentCLI

final class ConfigLoaderTests: XCTestCase {

    // MARK: - load(from:) — file not found

    func testLoad_nonexistentFile_returnsNil() {
        let result = ConfigLoader.load(from: "/tmp/nonexistent_config_\(UUID().uuidString).json")
        XCTAssertNil(result, "Non-existent file should return nil")
    }

    // MARK: - load(from:) — valid JSON

    func testLoad_validJSON_parsesAllFields() throws {
        let path = "/tmp/test_config_\(UUID().uuidString).json"
        let json = """
        {
            "apiKey": "test-key-123",
            "baseURL": "https://api.example.com/v1",
            "model": "glm-5.1",
            "provider": "anthropic",
            "maxTurns": 20,
            "maxBudgetUsd": 5.0
        }
        """
        try json.write(toFile: path, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: path) }

        let config = ConfigLoader.load(from: path)
        XCTAssertNotNil(config)
        XCTAssertEqual(config?.apiKey, "test-key-123")
        XCTAssertEqual(config?.baseURL, "https://api.example.com/v1")
        XCTAssertEqual(config?.model, "glm-5.1")
        XCTAssertEqual(config?.provider, "anthropic")
        XCTAssertEqual(config?.maxTurns, 20)
        XCTAssertEqual(config?.maxBudgetUsd, 5.0)
    }

    func testLoad_partialJSON_onlySetsPresentFields() throws {
        let path = "/tmp/test_config_\(UUID().uuidString).json"
        let json = """
        { "apiKey": "partial-key" }
        """
        try json.write(toFile: path, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: path) }

        let config = ConfigLoader.load(from: path)
        XCTAssertNotNil(config)
        XCTAssertEqual(config?.apiKey, "partial-key")
        XCTAssertNil(config?.baseURL)
        XCTAssertNil(config?.model)
    }

    // MARK: - load(from:) — invalid JSON

    func testLoad_invalidJSON_returnsNil() throws {
        let path = "/tmp/test_config_\(UUID().uuidString).json"
        try "not valid json".write(toFile: path, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: path) }

        let config = ConfigLoader.load(from: path)
        XCTAssertNil(config, "Invalid JSON should return nil")
    }

    // MARK: - apply(_:to:) — fills nil fields

    func testApply_fillsNilFieldsFromConfig() {
        var args = ArgumentParser.parse(["openagent"])
        let config = CLIConfig(
            apiKey: "config-key",
            baseURL: "https://api.example.com",
            model: "custom-model",
            maxTurns: 25
        )

        ConfigLoader.apply(config, to: &args)

        XCTAssertEqual(args.apiKey, "config-key")
        XCTAssertEqual(args.baseURL, "https://api.example.com")
        XCTAssertEqual(args.model, "custom-model")
        XCTAssertEqual(args.maxTurns, 25)
    }

    func testApply_doesNotOverrideCLIArgs() {
        var args = ArgumentParser.parse(["openagent", "--api-key", "cli-key", "--model", "cli-model"])
        let config = CLIConfig(
            apiKey: "config-key",
            baseURL: "https://config.example.com",
            model: "config-model"
        )

        ConfigLoader.apply(config, to: &args)

        XCTAssertEqual(args.apiKey, "cli-key", "CLI --api-key should not be overridden")
        XCTAssertEqual(args.model, "cli-model", "CLI --model should not be overridden")
        XCTAssertEqual(args.baseURL, "https://config.example.com", "Config baseURL should fill nil field")
    }

    func testApply_nilConfig_doesNothing() {
        var args = ArgumentParser.parse(["openagent"])
        let originalKey = args.apiKey
        let originalModel = args.model

        ConfigLoader.apply(nil, to: &args)

        XCTAssertEqual(args.apiKey, originalKey)
        XCTAssertEqual(args.model, originalModel)
    }
}
