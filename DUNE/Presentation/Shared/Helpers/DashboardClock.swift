import Foundation

enum DashboardClock {
    static func now() -> Date {
        let now = Date()
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--uitesting"),
           let index = arguments.firstIndex(of: "--ui-dashboard-hour"),
           arguments.indices.contains(index + 1),
           let hour = Int(arguments[index + 1]),
           (0...23).contains(hour),
           let date = Calendar.autoupdatingCurrent.date(bySettingHour: hour, minute: 0, second: 0, of: now) {
            return date
        }
        #endif
        return now
    }
}
