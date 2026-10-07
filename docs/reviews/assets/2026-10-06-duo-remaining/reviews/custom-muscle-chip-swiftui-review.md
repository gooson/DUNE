# Custom exercise muscle chip SwiftUI review

Observed in Book 90 maximum accessibility text native `010-2007x2853.png`: the four-column adaptive 90pt grid compressed the `Shoulders` chip into four visual lines (`Sho / ul- / der / s`). The accessibility hierarchy retained the full label but measured the chip at roughly 90.7 × 212.3pt; this was a visual layout defect.

`CreateCustomExerciseView.swift` now uses a single flexible column when Dynamic Type is an accessibility size. Each chip receives the column width, keeps its label vertically sized, and has at least 44pt content height before padding. This also gives long labels such as `Hamstrings` and `Quadriceps` room to render as words. The ordinary Dynamic Type grid remains adaptive with minimum 90pt columns. The existing selection action, color, labels, and identifiers are unchanged; no localization string was added.

Static verification: `xcrun swiftc -frontend -parse` and `git diff --check` passed for the edited file. No app build or native recheck was run in this delegated task. The queued template route should verify the whole `Shoulders` label and chip bounds at maximum accessibility size on Book and Closed viewports, including that the chip remains tappable after scrolling it into view.
