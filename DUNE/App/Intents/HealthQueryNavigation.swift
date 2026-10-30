import Foundation
import Observation

struct HealthQueryRoute: Identifiable {
    let id = UUID()
    let request: HealthQueryRequest
}
@MainActor
@Observable
final class HealthQueryNavigation {
    static let shared = HealthQueryNavigation()

    var route: HealthQueryRoute?

    func open(request: HealthQueryRequest) {
        route = HealthQueryRoute(request: request)
    }
}

/// Chooses the production service, with an explicit DEBUG-only UI-test override.
enum HealthQueryServiceRouting {
    @MainActor static func current() -> any HealthQuerying {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--uitesting"), args.contains("--ui-health-query-fixture") {
            return HealthQueryUITestFixture()
        }
        #endif
        return HealthQueryService.shared
    }
}
