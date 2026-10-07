# Workout completion singular copy: scoped review

Reviewed only the new `WorkoutCompletionSheet.swift` branch, its `Localizable.xcstrings` sibling key, and the corresponding exact UI-test summary lookup. Applied the project copy-voice skill and localization rule. No source edit, build, test, or simulator action.

**Findings:** No actionable regression found. `setCount == 1` renders `"<exercise> · 1 set"`; all other counts retain the existing `"… sets"` branch. Both use `formattedWithSeparator`, preserving the established number formatting. The new English key `%@ · %@ set` matches the two String interpolations (exercise name and formatted count); `\u{00B7}` in Swift resolves to the same middle dot as the catalog key. English supplies `set`, while Korean and Japanese keep their existing language-appropriate unit forms. Each localization has two `%@` arguments in the same order. The UI test now expects the singular label.

The manual branch is appropriate here because the count reaches `Text` as a preformatted String, yielding `%@` in the catalog key rather than a numeric `%lld` for plural variation. The existing plural key remains used, so no orphan was introduced. Xcode 27.1 build and final native share gate are still pending; this static review does not claim compilation or visual pass.
