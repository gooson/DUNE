import Testing
@testable import DUNE

@Suite("WorkoutSourceClassifier")
struct WorkoutSourceClassifierTests {
    @Test("Main bundle source is app family")
    func mainBundleMatch() {
        let result = WorkoutSourceClassifier.isFromAppFamily(
            sourceBundleIdentifier: "com.raftel.dailve",
            appBundleIdentifier: "com.raftel.dailve"
        )

        #expect(result == true)
    }

    @Test("Watch companion child bundle is app family")
    func watchCompanionMatch() {
        let result = WorkoutSourceClassifier.isFromAppFamily(
            sourceBundleIdentifier: "com.raftel.dailve.watchkitapp",
            appBundleIdentifier: "com.raftel.dailve"
        )

        #expect(result == true)
    }

    @Test("Non-watch child bundle is not app family workout source")
    func nonWatchChildBundleNoMatch() {
        let result = WorkoutSourceClassifier.isFromAppFamily(
            sourceBundleIdentifier: "com.raftel.dailve.widget",
            appBundleIdentifier: "com.raftel.dailve"
        )

        #expect(result == false)
    }

    @Test("Unrelated bundle is not app family")
    func unrelatedBundleNoMatch() {
        let result = WorkoutSourceClassifier.isFromAppFamily(
            sourceBundleIdentifier: "com.thirdparty.fitness",
            appBundleIdentifier: "com.raftel.dailve"
        )

        #expect(result == false)
    }

    @Test("Empty app bundle fails closed")
    func emptyAppBundleFailsClosed() {
        let result = WorkoutSourceClassifier.isFromAppFamily(
            sourceBundleIdentifier: "com.raftel.dailve.watchkitapp",
            appBundleIdentifier: ""
        )

        #expect(result == false)
    }
}
