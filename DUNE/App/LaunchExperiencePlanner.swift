import Foundation

enum LaunchExperienceStep: Equatable {
    case cloudSyncConsent
    case whatsNew
    case ready
}

struct LaunchExperienceState: Equatable {
    let shouldBypassLaunchExperience: Bool
    let hasShownCloudSyncConsent: Bool
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

        if state.shouldPresentWhatsNew {
            return .whatsNew
        }

        return .ready
    }
}
