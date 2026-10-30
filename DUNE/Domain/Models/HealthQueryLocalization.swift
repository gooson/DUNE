import Foundation

/// Carries the invoking Siri language through actor hops without changing the app's locale.
enum HealthQueryLocalization {
    @TaskLocal static var locale: Locale = .current
}
