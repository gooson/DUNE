import Testing
@testable import DUNEWatch

@Suite("CardioMetricProfile")
struct CardioMetricProfileTests {

    // MARK: - Profile Mapping

    @Test("Running activities map to .running profile")
    func runningMapping() {
        let activities: [WorkoutActivityType] = [.running, .walking, .hiking, .stairClimbing, .stairStepper, .stepTraining]
        for activity in activities {
            #expect(CardioMetricProfile.profile(for: activity) == .running, "Expected .running for \(activity)")
        }
    }

    @Test("Cycling activities map to .cycling profile")
    func cyclingMapping() {
        let activities: [WorkoutActivityType] = [.cycling, .handCycling]
        for activity in activities {
            #expect(CardioMetricProfile.profile(for: activity) == .cycling, "Expected .cycling for \(activity)")
        }
    }

    @Test("Swimming maps to .swimming profile")
    func swimmingMapping() {
        #expect(CardioMetricProfile.profile(for: .swimming) == .swimming)
    }

    @Test("Elliptical and rowing map to .running (pace-based)")
    func paceBasedMapping() {
        #expect(CardioMetricProfile.profile(for: .elliptical) == .running)
        #expect(CardioMetricProfile.profile(for: .rowing) == .running)
    }

    @Test("Unknown activity types map to .generic")
    func genericMapping() {
        #expect(CardioMetricProfile.profile(for: .jumpRope) == .generic)
        #expect(CardioMetricProfile.profile(for: .yoga) == .generic)
    }

    // MARK: - Metric Configuration

    @Test("Running profile shows distance and pace, not speed")
    func runningMetrics() {
        let profile = CardioMetricProfile.running
        #expect(profile.showsDistance)
        #expect(profile.showsPace)
        #expect(!profile.showsSpeed)
    }

    @Test("Cycling profile shows distance and speed, not pace")
    func cyclingMetrics() {
        let profile = CardioMetricProfile.cycling
        #expect(profile.showsDistance)
        #expect(!profile.showsPace)
        #expect(profile.showsSpeed)
    }

    @Test("Swimming profile shows distance and pace, not speed")
    func swimmingMetrics() {
        let profile = CardioMetricProfile.swimming
        #expect(profile.showsDistance)
        #expect(profile.showsPace)
        #expect(!profile.showsSpeed)
    }

    @Test("Generic profile shows no distance, pace, or speed")
    func genericMetrics() {
        let profile = CardioMetricProfile.generic
        #expect(!profile.showsDistance)
        #expect(!profile.showsPace)
        #expect(!profile.showsSpeed)
    }
}
