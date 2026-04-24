import Foundation
@testable import OpenAgentCLI

// MARK: - Mock Input Reader

/// Mock input reader that returns a predefined sequence of lines.
///
/// Simulates terminal input for REPLLoop testing. Returns each line in order,
/// then returns nil (EOF) when the sequence is exhausted.
final class MockInputReader: InputReading, @unchecked Sendable {
    var lines: [String?]
    var callCount = 0
    var promptHistory: [String] = []

    init(_ lines: [String?]) {
        self.lines = lines
    }

    func readLine(prompt: String) -> String? {
        promptHistory.append(prompt)
        guard callCount < lines.count else { return nil }
        let line = lines[callCount]
        callCount += 1
        return line
    }
}
