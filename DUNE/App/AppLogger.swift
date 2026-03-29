import OSLog

enum AppLogger {
    static let healthKit = Logger(subsystem: "com.raftel.dailve", category: "HealthKit")
    static let data = Logger(subsystem: "com.raftel.dailve", category: "Data")
    static let ui = Logger(subsystem: "com.raftel.dailve", category: "UI")
    static let notification = Logger(subsystem: "com.raftel.dailve", category: "Notification")
    static let exercise = Logger(subsystem: "com.raftel.dailve", category: "Exercise")
    static let ai = Logger(subsystem: "com.raftel.dailve", category: "AI")
}
