import Foundation

/// Generates a daily summary paragraph from the day's health metrics.
/// Uses Foundation Models when available, falls back to template-based text.
struct GenerateDailyDigestUseCase: Sendable {

    func execute(metrics: DailyDigest.DigestMetrics) -> DailyDigest {
        let summary = buildTemplateSummary(from: metrics)
        return DailyDigest(summary: summary, metrics: metrics)
    }

    // MARK: - Template Fallback

    private func buildTemplateSummary(from m: DailyDigest.DigestMetrics) -> String {
        var parts: [String] = []

        // Condition
        if let score = m.conditionScore {
            if let delta = m.conditionDelta {
                let sign = delta >= 0 ? "+" : ""
                parts.append(
                    String(localized: "Today's condition score was \(score) (\(sign)\(delta) from yesterday).")
                )
            } else {
                parts.append(
                    String(localized: "Today's condition score was \(score).")
                )
            }
        }

        // Workout
        if let workout = m.workoutSummary {
            parts.append(
                String(localized: "You completed \(workout).")
            )
        } else {
            parts.append(
                String(localized: "Today was a rest day.")
            )
        }

        // Sleep
        if let sleepMin = m.sleepMinutes, sleepMin > 0 {
            let hours = Int(sleepMin) / 60
            let mins = Int(sleepMin) % 60
            if mins > 0 {
                parts.append(
                    String(localized: "Last night's sleep: \(hours)h \(mins)m.")
                )
            } else {
                parts.append(
                    String(localized: "Last night's sleep: \(hours) hours.")
                )
            }
        }

        // Sleep debt
        if let debt = m.sleepDebtMinutes, debt > 30 {
            let debtHours = Int(debt) / 60
            let debtMins = Int(debt) % 60
            if debtHours > 0 {
                parts.append(
                    String(localized: "Sleep debt remains at \(debtHours)h \(debtMins)m. Consider an earlier bedtime tonight.")
                )
            } else {
                parts.append(
                    String(localized: "Sleep debt: \(debtMins) minutes. Almost caught up!")
                )
            }
        }

        // Steps
        if let steps = m.stepsCount, steps > 0 {
            parts.append(
                String(localized: "\(steps.formatted()) steps today.")
            )
        }

        // Stress
        if let stress = m.stressLevel {
            switch stress {
            case .low:
                parts.append(
                    String(localized: "Stress levels are well managed.")
                )
            case .moderate:
                parts.append(
                    String(localized: "Stress is at a moderate level.")
                )
            case .elevated:
                parts.append(
                    String(localized: "Stress is elevated — prioritize recovery.")
                )
            case .high:
                parts.append(
                    String(localized: "Stress is high — take time to rest and recover.")
                )
            }
        }

        return parts.joined(separator: " ")
    }
}
