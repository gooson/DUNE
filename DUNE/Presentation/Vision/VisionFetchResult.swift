import Foundation

/// Shared result wrapper for Vision-layer async fetches.
/// Carries both the fetched value and an optional user-facing message.
struct VisionFetchResult<Value: Sendable>: Sendable {
    let value: Value
    let message: String?
}
