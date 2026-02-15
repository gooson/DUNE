import OSLog

enum AppLogger {
    static let healthKit = Logger(subsystem: "com.dailve.health", category: "HealthKit")
    static let data = Logger(subsystem: "com.dailve.health", category: "Data")
    static let ui = Logger(subsystem: "com.dailve.health", category: "UI")
}
