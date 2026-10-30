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
