import OSLog

enum AppLogger {
    static let healthKit = Logger(subsystem: "com.raftel.dailve", category: "HealthKit")
    static let data = Logger(subsystem: "com.raftel.dailve", category: "Data")
    static let ui = Logger(subsystem: "com.raftel.dailve", category: "UI")
}
