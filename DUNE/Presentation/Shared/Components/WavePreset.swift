import SwiftUI

/// Tab-specific wave animation presets.
///
/// Each tab has a distinct wave character:
/// - **today**: Slow, gentle — calm monitoring
/// - **train**: Dynamic, dual-layer — energetic activity
/// - **wellness**: Broad, smooth — balance and stability
enum WavePreset: Sendable {
    case today
    case train
    case wellness

    // MARK: - Primary wave parameters

    var amplitude: CGFloat {
        switch self {
        case .today:    0.04
        case .train:    0.08
        case .wellness: 0.05
        }
    }

    var frequency: CGFloat {
        switch self {
        case .today:    1.5
        case .train:    2.5
        case .wellness: 1.8
        }
    }

    var opacity: Double {
        switch self {
        case .today:    0.12
        case .train:    0.15
        case .wellness: 0.14
        }
    }

    var verticalOffset: CGFloat { 0.5 }

    var bottomFade: CGFloat { 0.4 }

    // MARK: - Secondary wave (Train only)

    /// Train tab uses a secondary overlay wave for an energetic dual-layer effect.
    var secondaryWave: SecondaryWave? {
        switch self {
        case .train:
            SecondaryWave(amplitude: 0.04, frequency: 3.5, opacity: 0.08, phaseOffset: .pi / 3)
        default:
            nil
        }
    }
}

// MARK: - Secondary Wave

extension WavePreset {
    struct SecondaryWave: Sendable {
        let amplitude: CGFloat
        let frequency: CGFloat
        let opacity: Double
        let phaseOffset: CGFloat
    }
}

// MARK: - Environment Keys

private struct WavePresetKey: EnvironmentKey {
    static let defaultValue: WavePreset = .today
}

private struct WaveColorKey: EnvironmentKey {
    static let defaultValue: Color = DS.Color.warmGlow
}

private struct WeatherAtmosphereKey: EnvironmentKey {
    static let defaultValue: WeatherAtmosphere = .default
}

extension EnvironmentValues {
    var wavePreset: WavePreset {
        get { self[WavePresetKey.self] }
        set { self[WavePresetKey.self] = newValue }
    }

    var waveColor: Color {
        get { self[WaveColorKey.self] }
        set { self[WaveColorKey.self] = newValue }
    }

    var weatherAtmosphere: WeatherAtmosphere {
        get { self[WeatherAtmosphereKey.self] }
        set { self[WeatherAtmosphereKey.self] = newValue }
    }
}
