#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif
import Foundation

// MARK: - SignalEvent

/// Signal event types that the REPL loop can react to.
///
/// Represents the different signal states that `SignalHandler.check()` can return.
/// The REPL loop polls this during stream consumption to detect interrupts.
enum SignalEvent: Equatable, Sendable {
    /// No signal received.
    case none
    /// SIGINT (Ctrl+C) — interrupt current operation.
    case interrupt
    /// Double SIGINT within 1 second — force quit.
    case forceExit
    /// SIGTERM — graceful shutdown.
    case terminate
}

// MARK: - SignalHandler

/// Registers SIGINT/SIGTERM handlers and provides a thread-safe query interface.
///
/// Uses `sigaction` for reliable signal handling on both Darwin and Linux.
/// Signal handlers only set volatile flags — all real work happens in the
/// REPL loop's cooperative polling via `check()`.
///
/// ## Thread Safety
///
/// Signal handlers execute asynchronously on an arbitrary thread. They only
/// write to `sig_atomic_t`-compatible variables (plain CInt/time_t, accessed
/// atomically on all supported platforms). The `check()` method runs on the
/// main thread and only reads these flags. `nonisolated(unsafe)` is used to
/// suppress Swift concurrency warnings because these variables are accessed
/// from C signal handlers (which Swift's concurrency model cannot express).
enum SignalHandler {

    // MARK: - Internal State (volatile flags)

    /// Count of SIGINTs received since last check. Incremented by signal handler.
    nonisolated(unsafe) private static var sigintCount: CInt = 0

    /// Whether a SIGTERM has been received since the last check.
    nonisolated(unsafe) private static var sigtermFlag: CInt = 0

    /// Timestamp of the most recent SIGINT, used for double-press detection.
    nonisolated(unsafe) private static var lastSigintTime: time_t = 0

    /// Timestamp of the *previous* SIGINT batch that was already consumed.
    /// Set by check() when it processes a SIGINT, used for the next batch.
    nonisolated(unsafe) private static var prevSigintTime: time_t = 0

    /// Whether signal handlers have been registered.
    nonisolated(unsafe) private static var registered = false

    // MARK: - Public API

    /// Register SIGINT and SIGTERM handlers. Call once at CLI startup.
    ///
    /// Uses `sigaction` instead of `signal()` for consistent cross-platform
    /// behavior. Idempotent — calling multiple times is safe (no-op after first).
    static func register() {
        guard !registered else { return }
        registered = true

        // SIGINT handler: increment count and record timestamp
        var sigintAction = sigaction()
        sigintAction.__sigaction_u.__sa_handler = { _ in
            SignalHandler.sigintCount &+= 1  // Overflow-wrap (safe for counter)
            SignalHandler.lastSigintTime = time(nil)
        }
        sigintAction.sa_flags = 0
        #if canImport(Darwin)
        sigintAction.sa_flags = SA_RESTART
        #endif
        _ = sigaction(SIGINT, &sigintAction, nil)

        // SIGTERM handler
        var sigtermAction = sigaction()
        sigtermAction.__sigaction_u.__sa_handler = { _ in
            SignalHandler.sigtermFlag = 1
        }
        sigtermAction.sa_flags = 0
        _ = sigaction(SIGTERM, &sigtermAction, nil)
    }

    /// Check current signal state and consume the event.
    ///
    /// This is the main polling method called from the REPL loop. It checks
    /// the volatile flags set by signal handlers and returns the appropriate
    /// `SignalEvent`. Calling this consumes the event — a subsequent call
    /// will return `.none` unless another signal arrives.
    ///
    /// - Returns: The highest-priority signal event, or `.none`.
    static func check() -> SignalEvent {
        // Check SIGTERM first (highest priority — always exits)
        if sigtermFlag != 0 {
            sigtermFlag = 0
            return .terminate
        }

        // Check SIGINT: consume the count of pending SIGINTs
        let count = sigintCount
        if count > 0 {
            sigintCount = 0

            let currentTime = lastSigintTime

            // If 2+ SIGINTs arrived before we checked, it's a double-press
            if count >= 2 {
                prevSigintTime = 0
                return .forceExit
            }

            // Single SIGINT: check if it's within 1 second of the previous one
            if prevSigintTime > 0 {
                let elapsed = currentTime - prevSigintTime
                prevSigintTime = currentTime
                if elapsed >= 0 && elapsed <= 1 {
                    return .forceExit
                }
            } else {
                prevSigintTime = currentTime
            }

            return .interrupt
        }

        return .none
    }

    /// Reset interrupt state (after handling an interrupt).
    ///
    /// Call this after successfully handling a `.interrupt` event to ensure
    /// clean state for the next REPL iteration. Also resets the double-press
    /// timestamp so a new interrupt cycle starts fresh.
    static func clearInterrupt() {
        sigintCount = 0
        lastSigintTime = 0
        prevSigintTime = 0
    }

    // MARK: - Test-Only API

    /// Set the internal state for testing purposes.
    ///
    /// This method is only intended for use in test targets (via `@testable import`).
    /// It directly manipulates the internal flags to simulate signal delivery
    /// without sending actual OS signals.
    ///
    /// - Parameters:
    ///   - sigint: Whether to set the SIGINT flag.
    ///   - sigterm: Whether to set the SIGTERM flag.
    ///   - simulateDoublePress: Whether to simulate a double SIGINT (within 1s).
    static func setTestFlags(sigint: Bool = false, sigterm: Bool = false, simulateDoublePress: Bool = false) {
        if sigint {
            if simulateDoublePress {
                // Simulate two SIGINTs by setting count to 2
                sigintCount = 2
                lastSigintTime = time(nil)
            } else {
                sigintCount = 1
                lastSigintTime = time(nil)
            }
        }
        if sigterm {
            sigtermFlag = 1
        }
    }
}
