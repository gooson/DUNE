import SwiftUI

extension HealthMetric {
    /// Formatted numeric value only (no unit). Use with `category.unitLabel` for display.
    var formattedNumericValue: String {
        switch category {
        case .hrv:
            return String(format: "%.0f", value)
        case .rhr:
            return String(format: "%.0f", value)
        case .sleep:
            return value.hoursMinutesFormatted
        case .exercise:
            switch unit {
            case "km":  return String(format: "%.1f", value)
            case "m":   return String(format: "%.0f", value)
            default:    return String(format: "%.0f", value)
            }
        case .steps:
            return String(format: "%.0f", value)
        case .weight:
            return String(format: "%.1f", value)
        case .bmi:
            return String(format: "%.1f", value)
        case .spo2:
            return String(format: "%.0f", value * 100) // stored as 0-1 decimal
        case .respiratoryRate:
            return String(format: "%.1f", value)
        case .vo2Max:
            return String(format: "%.1f", value)
        case .heartRateRecovery:
            return String(format: "%.0f", value)
        case .heartRate:
            return String(format: "%.0f", value)
        case .bodyFat:
            return String(format: "%.1f", value)
        case .leanBodyMass:
            return String(format: "%.1f", value)
        case .wristTemperature:
            return String(format: "%+.1f", value) // show as delta from baseline
        }
    }

    /// Combined value+unit for contexts needing a single string (accessibility, etc.).
    var formattedValue: String {
        // Sleep already includes "h m" in its formatted value
        if category == .sleep { return formattedNumericValue }
        let unit = resolvedUnitLabel
        if unit.isEmpty { return formattedNumericValue }
        return "\(formattedNumericValue) \(unit)"
    }

    /// Unit label resolved from override or category default.
    var resolvedUnitLabel: String {
        if !unit.isEmpty { return unit }
        return category.unitLabel
    }

    /// Absolute change value formatted (no arrow).
    var formattedChangeValue: String? {
        guard let change else { return nil }
        return String(format: "%.1f", abs(change))
    }

    /// SF Symbol name for change direction.
    var changeDirectionIcon: String? {
        guard let change else { return nil }
        return change > 0 ? "arrow.up.right" : "arrow.down.right"
    }

    /// Legacy combined format for backward compatibility.
    var formattedChange: String? {
        guard let change else { return nil }
        let arrow = change > 0 ? "\u{25B2}" : "\u{25BC}"
        return "\(arrow)\(String(format: "%.1f", abs(change)))"
    }
}

extension HealthMetric {
    /// Resolved icon: uses iconOverride if set, otherwise falls back to category default.
    var resolvedIconName: String {
        iconOverride ?? category.iconName
    }
}

extension HealthMetric.Category {
    var themeColor: Color {
        switch self {
        case .hrv:                DS.Color.hrv
        case .rhr:                DS.Color.rhr
        case .heartRate:          DS.Color.heartRate
        case .sleep:              DS.Color.sleep
        case .exercise:           DS.Color.activity
        case .steps:              DS.Color.steps
        case .weight:             DS.Color.body
        case .bmi:                DS.Color.body
        case .bodyFat:            DS.Color.body
        case .leanBodyMass:       DS.Color.body
        case .spo2:               DS.Color.vitals
        case .respiratoryRate:    DS.Color.vitals
        case .vo2Max:             DS.Color.fitness
        case .heartRateRecovery:  DS.Color.fitness
        case .wristTemperature:   DS.Color.vitals
        }
    }

    var iconName: String {
        switch self {
        case .hrv:                "waveform.path.ecg"
        case .rhr:                "heart.fill"
        case .heartRate:          "bolt.heart.fill"
        case .sleep:              "moon.zzz.fill"
        case .exercise:           "flame.fill"
        case .steps:              "figure.walk"
        case .weight:             "scalemass.fill"
        case .bmi:                "figure.stand"
        case .bodyFat:            "percent"
        case .leanBodyMass:       "figure.strengthtraining.traditional"
        case .spo2:               "lungs.fill"
        case .respiratoryRate:    "wind"
        case .vo2Max:             "figure.run"
        case .heartRateRecovery:  "heart.circle"
        case .wristTemperature:   "thermometer.medium"
        }
    }

    var displayName: String {
        switch self {
        case .hrv:                "Heart Rate Variability"
        case .rhr:                "Resting Heart Rate"
        case .heartRate:          "Heart Rate"
        case .sleep:              "Sleep"
        case .exercise:           "Exercise"
        case .steps:              "Steps"
        case .weight:             "Weight"
        case .bmi:                "BMI"
        case .bodyFat:            "Body Fat"
        case .leanBodyMass:       "Lean Body Mass"
        case .spo2:               "Blood Oxygen"
        case .respiratoryRate:    "Respiratory Rate"
        case .vo2Max:             "VO2 Max"
        case .heartRateRecovery:  "HR Recovery"
        case .wristTemperature:   "Wrist Temp"
        }
    }

    var unitLabel: String {
        switch self {
        case .hrv:                "ms"
        case .rhr:                "bpm"
        case .heartRate:          "bpm"
        case .sleep:              ""
        case .exercise:           "min"
        case .steps:              "steps"
        case .weight:             "kg"
        case .bmi:                ""
        case .bodyFat:            "%"
        case .leanBodyMass:       "kg"
        case .spo2:               "%"
        case .respiratoryRate:    "breaths/min"
        case .vo2Max:             "ml/kg/min"
        case .heartRateRecovery:  "bpm"
        case .wristTemperature:   "°C"
        }
    }
}
