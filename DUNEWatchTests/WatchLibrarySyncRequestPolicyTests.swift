import Foundation
import Testing
@testable import DUNEWatch

@Suite("WatchLibrarySyncRequestPolicy")
struct WatchLibrarySyncRequestPolicyTests {
    @Test("Missing library uses syncing status when reachable")
    func missingLibraryReachableStatus() {
        let status = WatchLibrarySyncRequestPolicy.statusWhenLibraryMissing(isReachable: true)
        #expect(status == .syncing)
    }

    @Test("Missing library uses notConnected status when unreachable")
    func missingLibraryNotConnectedStatus() {
        let status = WatchLibrarySyncRequestPolicy.statusWhenLibraryMissing(isReachable: false)
        #expect(status == .notConnected)
    }

    @Test("Force request bypasses interval")
    func forceRequestBypassesInterval() {
        let now = Date()
        let shouldRequest = WatchLibrarySyncRequestPolicy.shouldRequest(
            lastRequestAt: now,
            now: now,
            force: true
        )
        #expect(shouldRequest)
    }

    @Test("First request is allowed when no history exists")
    func firstRequestAllowed() {
        let shouldRequest = WatchLibrarySyncRequestPolicy.shouldRequest(
            lastRequestAt: nil,
            now: Date(),
            force: false
        )
        #expect(shouldRequest)
    }

    @Test("Request is throttled inside minimum interval")
    func requestThrottledInsideInterval() {
        let now = Date()
        let last = now.addingTimeInterval(-2)
        let shouldRequest = WatchLibrarySyncRequestPolicy.shouldRequest(
            lastRequestAt: last,
            now: now,
            force: false,
            minimumInterval: 8
        )
        #expect(!shouldRequest)
    }

    @Test("Request is allowed after minimum interval")
    func requestAllowedAfterInterval() {
        let now = Date()
        let last = now.addingTimeInterval(-20)
        let shouldRequest = WatchLibrarySyncRequestPolicy.shouldRequest(
            lastRequestAt: last,
            now: now,
            force: false,
            minimumInterval: 8
        )
        #expect(shouldRequest)
    }
}
