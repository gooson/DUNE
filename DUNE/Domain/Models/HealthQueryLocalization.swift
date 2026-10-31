import Foundation

/// Carries the invoking Siri language through actor hops without changing the app's locale.
enum HealthQueryLocalization {
    @TaskLocal static var locale: Locale = .current

    static func localized(_ value: String.LocalizationValue) -> String {
        // Unlike String's locale argument, the resource locale selects translations.
        String(localized: LocalizedStringResource(value, locale: locale))
    }
}
