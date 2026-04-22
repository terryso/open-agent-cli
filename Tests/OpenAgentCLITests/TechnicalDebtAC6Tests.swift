import XCTest
@testable import OpenAgentCLI

// MARK: - ATDD Red Phase: Story 8-1 AC#6 CostTracker Sendable Conformance
//
// These tests define the EXPECTED behavior after adding @unchecked Sendable
// conformance to CostTracker.
//
// They will FAIL until CostTracker is marked as `@unchecked Sendable` (TDD red phase).
//
// Acceptance Criteria Coverage:
//   AC#6: CostTracker satisfies Sendable conformance for Swift 6 compatibility
//
// Proposed solution: Mark CostTracker as `final class CostTracker: @unchecked Sendable`

final class TechnicalDebtAC6Tests: XCTestCase {

    // MARK: - P2: CostTracker conforms to Sendable

    /// AC#6: CostTracker should conform to Sendable.
    ///
    /// This test verifies that CostTracker can be used in concurrent contexts
    /// by checking Sendable conformance at compile time.
    ///
    /// This test will FAIL (not compile) until CostTracker is marked @unchecked Sendable.
    func testCostTracker_conformsToSendable() {
        // Verify CostTracker can be used where Sendable is required.
        // If CostTracker does not conform to Sendable, this function
        // won't compile.
        let tracker = CostTracker()

        // Use the tracker in a way that requires Sendable conformance
        func requireSendable<T: Sendable>(_ value: T) -> Bool {
            return true
        }

        let result = requireSendable(tracker)
        XCTAssertTrue(result,
            "CostTracker should conform to Sendable (AC#6)")
    }

    // MARK: - P2: CostTracker functional test (regression guard)

    /// AC#6: Adding Sendable should not change CostTracker functionality.
    func testCostTracker_resetWorks() {
        let tracker = CostTracker()
        tracker.cumulativeCostUsd = 5.0
        tracker.cumulativeInputTokens = 100
        tracker.cumulativeOutputTokens = 50

        tracker.reset()

        XCTAssertEqual(tracker.cumulativeCostUsd, 0.0,
            "reset() should zero out cost")
        XCTAssertEqual(tracker.cumulativeInputTokens, 0,
            "reset() should zero out input tokens")
        XCTAssertEqual(tracker.cumulativeOutputTokens, 0,
            "reset() should zero out output tokens")
    }

    /// AC#6: CostTracker mutation works correctly after Sendable conformance.
    func testCostTracker_mutationWorks() {
        let tracker = CostTracker()

        tracker.cumulativeCostUsd = 1.5
        tracker.cumulativeInputTokens = 500
        tracker.cumulativeOutputTokens = 200

        XCTAssertEqual(tracker.cumulativeCostUsd, 1.5)
        XCTAssertEqual(tracker.cumulativeInputTokens, 500)
        XCTAssertEqual(tracker.cumulativeOutputTokens, 200)
    }
}
