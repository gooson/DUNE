import Foundation

enum LaunchExperienceStep: Equatable {
    case cloudSyncConsent
    case healthKitAuthorization
    case notificationAuthorization
    case whatsNew
    case ready
}

struct LaunchExperienceState: Equatable {
    let shouldBypassLaunchExperience: Bool
    let hasShownCloudSyncConsent: Bool
    let shouldRequestHealthKitAuthorization: Bool
    let shouldRequestNotificationAuthorization: Bool
    let shouldPresentWhatsNew: Bool
}

struct LaunchAuthorizationRequestState: Equatable {
    let isEligible: Bool
    let hasCompletedRequest: Bool
    let hasAttemptedThisLaunch: Bool
    let shouldBypassLaunchExperience: Bool
}

enum LaunchExperiencePlanner {
    static func shouldRequestAuthorization(for state: LaunchAuthorizationRequestState) -> Bool {
        state.isEligible
            && !state.hasCompletedRequest
            && !state.hasAttemptedThisLaunch
            && !state.shouldBypassLaunchExperience
    }

    static func nextStep(for state: LaunchExperienceState) -> LaunchExperienceStep {
        if state.shouldBypassLaunchExperience {
            return .ready
        }

        if !state.hasShownCloudSyncConsent {
            return .cloudSyncConsent
        }

        if state.shouldRequestHealthKitAuthorization {
            return .healthKitAuthorization
        }

        if state.shouldRequestNotificationAuthorization {
            return .notificationAuthorization
        }

        if state.shouldPresentWhatsNew {
            return .whatsNew
        }

        return .ready
    }
}
