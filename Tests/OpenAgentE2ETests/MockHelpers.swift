import Foundation
@testable import OpenAgentCLI

// MARK: - Mock I/O Helpers for Integration Tests
//
// These mock I/O classes simulate stdin/stdout for automated testing.
// They are NOT mocking the system under test (Agent, REPLLoop are real).
// They only mock the terminal I/O boundary since tests cannot use real stdin/stdout.

// MARK: - MockInputReader

/// Returns a predefined sequence of lines, simulating terminal input.
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

// MARK: - MockTextOutputStream

/// Captures all written output into a string for test assertions.
final class MockTextOutputStream: TextOutputStream {
    var output = ""
    func write(_ string: String) {
        output += string
    }
}

// MARK: - SignalingMockInputReader

/// A mock input reader that sets `SignalHandler.setTestFlags(sigint: true)` when
/// returning a specific line index, simulating Ctrl+C delivery.
final class SignalingMockInputReader: InputReading, @unchecked Sendable {
    var lines: [String?]
    var callCount = 0
    var promptHistory: [String] = []
    let signalOnIndex: Int

    init(_ lines: [String?], signalOnIndex: Int) {
        self.lines = lines
        self.signalOnIndex = signalOnIndex
    }

    func readLine(prompt: String) -> String? {
        promptHistory.append(prompt)
        guard callCount < lines.count else { return nil }
        let line = lines[callCount]
        if callCount == signalOnIndex {
            SignalHandler.setTestFlags(sigint: true)
        }
        callCount += 1
        return line
    }
}

// MARK: - SignalMockInputReader

/// A mock input reader that can simulate signal delivery between reads.
final class SignalMockInputReader: InputReading, @unchecked Sendable {
    var lines: [String?]
    var callCount = 0
    var promptHistory: [String] = []

    let signalToInject: SignalEvent?
    let signalAfterRead: Int
    private var signalInjected = false

    init(lines: [String?], signalAfterRead: Int? = nil, signal: SignalEvent? = nil) {
        self.lines = lines
        self.signalAfterRead = signalAfterRead ?? -1
        self.signalToInject = signal
    }

    func readLine(prompt: String) -> String? {
        promptHistory.append(prompt)

        guard callCount < lines.count else { return nil }
        let line = lines[callCount]
        callCount += 1

        if callCount == signalAfterRead && !signalInjected {
            signalInjected = true
            if let signal = signalToInject {
                switch signal {
                case .interrupt:
                    SignalHandler.setTestFlags(sigint: true)
                case .forceExit:
                    SignalHandler.setTestFlags(sigint: true, simulateDoublePress: true)
                case .terminate:
                    SignalHandler.setTestFlags(sigterm: true)
                case .none:
                    break
                }
            }
        }
        return line
    }
}

// MARK: - MockInterruptOutputStream

/// Thread-safe output stream for concurrent write testing.
final class MockInterruptOutputStream: TextOutputStream, @unchecked Sendable {
    private let lock = NSLock()
    private var _output = ""

    var output: String {
        lock.lock()
        defer { lock.unlock() }
        return _output
    }

    func write(_ string: String) {
        lock.lock()
        _output += string
        lock.unlock()
    }
}
