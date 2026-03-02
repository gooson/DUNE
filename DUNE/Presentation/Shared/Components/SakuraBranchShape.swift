import SwiftUI

enum SakuraBranchPattern {
    case trunk
    case flowering
    case airy
}

/// Cherry branch silhouette stroke shape for Sakura theme.
///
/// Uses a primary branch curve plus short twig offsets to avoid generic wave feel.
struct SakuraBranchShape: Shape {
    let amplitude: CGFloat
    let frequency: CGFloat
    var phase: CGFloat
    let verticalOffset: CGFloat
    let twigDensity: CGFloat
    let pattern: SakuraBranchPattern

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    private let samples: WaveSamples

    init(
        amplitude: CGFloat = 0.08,
        frequency: CGFloat = 1.2,
        phase: CGFloat = 0,
        verticalOffset: CGFloat = 0.72,
        twigDensity: CGFloat = 0.35,
        pattern: SakuraBranchPattern = .trunk
    ) {
        self.amplitude = amplitude
        self.frequency = frequency
        self.phase = phase
        self.verticalOffset = verticalOffset
        self.twigDensity = twigDensity
        self.pattern = pattern
        self.samples = WaveSamples(frequency: frequency)
    }

    func path(in rect: CGRect) -> Path {
        guard rect.width > 0, rect.height > 0 else { return Path() }

        let amp = rect.height * amplitude
        let centerY = rect.height * verticalOffset

        var ridgePoints: [CGPoint] = []
        ridgePoints.reserveCapacity(samples.points.count)

        for pt in samples.points {
            let x = pt.x * rect.width
            let angle = pt.angle + phase
            let y = branchWave(at: angle)

            ridgePoints.append(CGPoint(x: x, y: centerY + amp * y))
        }

        var path = Path()
        for (idx, point) in ridgePoints.enumerated() {
            if idx == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        let config = twigConfig
        let strideCount = max(config.minStride, Int(config.baseStride - twigDensity * config.strideDensityScale))
        if strideCount > 0 {
            for idx in stride(from: 4, to: ridgePoints.count - 4, by: strideCount) {
                let base = ridgePoints[idx]
                let lengthScale = lengthVariance(at: idx)
                let twigLength = amp * (config.baseLength + twigDensity * config.lengthDensityScale) * lengthScale
                let baseAngle = CGFloat(idx).truncatingRemainder(dividingBy: 2) == 0 ? config.primaryAngle : config.secondaryAngle
                let twigAngle = baseAngle + angleVariance(at: idx, strength: config.angleJitter)
                let twigEnd = CGPoint(
                    x: base.x - twigLength * cos(twigAngle),
                    y: base.y + twigLength * sin(twigAngle)
                )
                path.move(to: base)
                path.addLine(to: twigEnd)

                if config.addCounterTwig, idx % (strideCount * 2) == 0 {
                    let counterLength = twigLength * config.counterLengthRatio * (0.76 + 0.24 * abs(cos(CGFloat(idx) * 0.31 + phase * 0.72)))
                    let counterAngle = config.counterAngle + angleVariance(at: idx + 3, strength: config.counterAngleJitter)
                    let counterEnd = CGPoint(
                        x: base.x + counterLength * cos(counterAngle),
                        y: base.y + counterLength * sin(counterAngle)
                    )
                    path.move(to: base)
                    path.addLine(to: counterEnd)
                }
            }
        }

        return path
    }

    private func branchWave(at angle: CGFloat) -> CGFloat {
        switch pattern {
        case .trunk:
            var y = sin(angle)
            y += 0.22 * sin(0.62 * angle + 1.1)
            y += 0.08 * sin(2.3 * angle + 0.4)
            return y
        case .flowering:
            var y = 0.84 * sin(0.92 * angle + 0.48)
            y += 0.30 * sin(1.86 * angle + 1.32)
            y += 0.13 * sin(3.35 * angle + 0.18)
            return y
        case .airy:
            var y = 0.68 * sin(1.28 * angle + 0.22)
            y += 0.19 * sin(0.54 * angle + 1.54)
            y += 0.05 * sin(4.1 * angle + 0.72)
            return y
        }
    }

    private var twigConfig: TwigConfig {
        switch pattern {
        case .trunk:
            TwigConfig(
                minStride: 4,
                baseStride: 11,
                strideDensityScale: 7,
                baseLength: 0.28,
                lengthDensityScale: 0.38,
                primaryAngle: -0.68,
                secondaryAngle: -0.44,
                addCounterTwig: false,
                counterAngle: 0,
                counterLengthRatio: 0,
                angleJitter: 0.08,
                counterAngleJitter: 0
            )
        case .flowering:
            TwigConfig(
                minStride: 3,
                baseStride: 9,
                strideDensityScale: 6,
                baseLength: 0.24,
                lengthDensityScale: 0.42,
                primaryAngle: -0.96,
                secondaryAngle: -0.58,
                addCounterTwig: true,
                counterAngle: 0.82,
                counterLengthRatio: 0.55,
                angleJitter: 0.26,
                counterAngleJitter: 0.22
            )
        case .airy:
            TwigConfig(
                minStride: 5,
                baseStride: 13,
                strideDensityScale: 5,
                baseLength: 0.20,
                lengthDensityScale: 0.28,
                primaryAngle: -0.60,
                secondaryAngle: -0.36,
                addCounterTwig: false,
                counterAngle: 0,
                counterLengthRatio: 0,
                angleJitter: 0.18,
                counterAngleJitter: 0
            )
        }
    }

    private func angleVariance(at index: Int, strength: CGFloat) -> CGFloat {
        guard strength > 0 else { return 0 }
        let t = CGFloat(index)
        let harmonicA = sin(t * 0.43 + phase * 0.72)
        let harmonicB = cos(t * 0.19 + phase * 1.17)
        return strength * (harmonicA * 0.68 + harmonicB * 0.32)
    }

    private func lengthVariance(at index: Int) -> CGFloat {
        let t = CGFloat(index)
        return 0.78 + 0.42 * abs(sin(t * 0.27 + phase * 0.45))
    }
}

private struct TwigConfig {
    let minStride: Int
    let baseStride: CGFloat
    let strideDensityScale: CGFloat
    let baseLength: CGFloat
    let lengthDensityScale: CGFloat
    let primaryAngle: CGFloat
    let secondaryAngle: CGFloat
    let addCounterTwig: Bool
    let counterAngle: CGFloat
    let counterLengthRatio: CGFloat
    let angleJitter: CGFloat
    let counterAngleJitter: CGFloat
}
