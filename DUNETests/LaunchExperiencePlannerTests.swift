import Testing
@testable import DUNE

@Suite("LaunchExperiencePlanner")
struct LaunchExperiencePlannerTests {
    @Test("Authorization requests run only when eligible and not yet completed this launch")
    func authorizationRequestsRunOnlyWhenEligible() {
        let shouldRequest = LaunchExperiencePlanner.shouldRequestAuthorization(
            for: LaunchAuthorizationRequestState(
                isEligible: true,
                hasCompletedRequest: false,
                hasAttemptedThisLaunch: false,
                shouldBypassLaunchExperience: false
            )
        )

        #expect(shouldRequest)
    }

    @Test("Authorization requests are skipped after a failed attempt in the same launch")
    func authorizationRequestsDoNotRepeatWithinSingleLaunch() {
        let shouldRequest = LaunchExperiencePlanner.shouldRequestAuthorization(
            for: LaunchAuthorizationRequestState(
                isEligible: true,
                hasCompletedRequest: false,
                hasAttemptedThisLaunch: true,
                shouldBypassLaunchExperience: false
            )
        )

        #expect(shouldRequest == false)
    }

    @Test("Authorization requests are skipped once the request completed")
    func authorizationRequestsDoNotRepeatAfterCompletion() {
        let shouldRequest = LaunchExperiencePlanner.shouldRequestAuthorization(
            for: LaunchAuthorizationRequestState(
                isEligible: true,
                hasCompletedRequest: true,
                hasAttemptedThisLaunch: false,
                shouldBypassLaunchExperience: false
            )
        )

        #expect(shouldRequest == false)
    }

    @Test("Authorization requests are skipped when launch extras are bypassed")
    func authorizationRequestsRespectBypassMode() {
        let shouldRequest = LaunchExperiencePlanner.shouldRequestAuthorization(
            for: LaunchAuthorizationRequestState(
                isEligible: true,
                hasCompletedRequest: false,
                hasAttemptedThisLaunch: false,
                shouldBypassLaunchExperience: true
            )
        )

        #expect(shouldRequest == false)
    }

    @Test("Bypass mode goes straight to ready")
    func bypassModeSkipsAllLaunchSteps() {
        let step = LaunchExperiencePlanner.nextStep(
            for: LaunchExperienceState(
                shouldBypassLaunchExperience: true,
                hasShownCloudSyncConsent: false,
                shouldRequestHealthKitAuthorization: true,
                shouldRequestNotificationAuthorization: true,
                shouldPresentWhatsNew: true
            )
        )

        #expect(step == .ready)
    }

    @Test("Consent is first on a fresh launch")
    func consentComesFirst() {
        let step = LaunchExperiencePlanner.nextStep(
            for: LaunchExperienceState(
                shouldBypassLaunchExperience: false,
                hasShownCloudSyncConsent: false,
                shouldRequestHealthKitAuthorization: true,
                shouldRequestNotificationAuthorization: true,
                shouldPresentWhatsNew: true
            )
        )

        #expect(step == .cloudSyncConsent)
    }

    @Test("HealthKit follows consent before notifications and What's New")
    func healthKitPrecedesLaterSteps() {
        let step = LaunchExperiencePlanner.nextStep(
            for: LaunchExperienceState(
                shouldBypassLaunchExperience: false,
                hasShownCloudSyncConsent: true,
                shouldRequestHealthKitAuthorization: true,
                shouldRequestNotificationAuthorization: true,
                shouldPresentWhatsNew: true
            )
        )

        #expect(step == .healthKitAuthorization)
    }

    @Test("Notifications run before What's New once HealthKit is handled")
    func notificationsPrecedeWhatsNew() {
        let step = LaunchExperiencePlanner.nextStep(
            for: LaunchExperienceState(
                shouldBypassLaunchExperience: false,
                hasShownCloudSyncConsent: true,
                shouldRequestHealthKitAuthorization: false,
                shouldRequestNotificationAuthorization: true,
                shouldPresentWhatsNew: true
            )
        )

        #expect(step == .notificationAuthorization)
    }

    @Test("What's New is last before ready")
    func whatsNewIsLastInteractiveStep() {
        let step = LaunchExperiencePlanner.nextStep(
            for: LaunchExperienceState(
                shouldBypassLaunchExperience: false,
                hasShownCloudSyncConsent: true,
                shouldRequestHealthKitAuthorization: false,
                shouldRequestNotificationAuthorization: false,
                shouldPresentWhatsNew: true
            )
        )

        #expect(step == .whatsNew)
    }

    @Test("Ready is returned when all launch steps are complete")
    func readyWhenNothingElseRemains() {
        let step = LaunchExperiencePlanner.nextStep(
            for: LaunchExperienceState(
                shouldBypassLaunchExperience: false,
                hasShownCloudSyncConsent: true,
                shouldRequestHealthKitAuthorization: false,
                shouldRequestNotificationAuthorization: false,
                shouldPresentWhatsNew: false
            )
        )

        #expect(step == .ready)
    }
}
