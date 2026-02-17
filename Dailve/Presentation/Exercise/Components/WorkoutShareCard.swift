import SwiftUI

/// Data model for generating a shareable workout summary card
struct WorkoutShareData: Sendable {
    let exerciseName: String
    let date: Date
    let sets: [SetInfo]
    let duration: TimeInterval
    let estimatedCalories: Double?
    let personalBest: String?
    let exerciseIcon: String

    struct SetInfo: Sendable {
        let setNumber: Int
        let weight: Double?
        let reps: Int?
        let duration: TimeInterval?
        let distance: Double?
        let setType: SetType
    }
}

/// Shareable workout summary card rendered as a SwiftUI View.
/// Used with ShareLink via ImageRenderer to produce a sharable image.
struct WorkoutShareCard: View {
    let data: WorkoutShareData
    let weightUnit: WeightUnit

    private var formattedDate: String {
        data.date.formatted(.dateTime.month(.abbreviated).day().year())
    }

    private var formattedDuration: String {
        let mins = Int(data.duration) / 60
        let secs = Int(data.duration) % 60
        if mins > 0 {
            return "\(mins)m \(secs)s"
        }
        return "\(secs)s"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 16)

            // Divider
            Rectangle()
                .fill(.white.opacity(0.15))
                .frame(height: 1)

            // Sets summary
            setsSection
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

            // Divider
            Rectangle()
                .fill(.white.opacity(0.15))
                .frame(height: 1)

            // Footer stats
            footerStats
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

            // Branding
            branding
                .padding(.bottom, 16)
        }
        .frame(width: 360)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.12, blue: 0.18),
                    Color(red: 0.08, green: 0.08, blue: 0.14)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: data.exerciseIcon)
                .font(.title2)
                .foregroundStyle(Color(red: 0.4, green: 0.85, blue: 0.6))

            VStack(alignment: .leading, spacing: 4) {
                Text(data.exerciseName)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                Text(formattedDate)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()

            if let pb = data.personalBest {
                VStack(spacing: 2) {
                    Image(systemName: "trophy.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text(pb)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.orange)
                    Text("PR")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.orange.opacity(0.7))
                }
            }
        }
    }

    // MARK: - Sets

    private var setsSection: some View {
        VStack(spacing: 8) {
            // Column header
            HStack {
                Text("SET")
                    .frame(width: 30, alignment: .leading)
                Text("TYPE")
                    .frame(width: 50, alignment: .leading)
                Spacer()
                Text("DETAILS")
                    .frame(alignment: .trailing)
            }
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white.opacity(0.4))

            ForEach(Array(data.sets.prefix(8).enumerated()), id: \.offset) { index, set in
                setRow(set, index: index)
            }

            if data.sets.count > 8 {
                Text("+\(data.sets.count - 8) more sets")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
    }

    private func setRow(_ set: WorkoutShareData.SetInfo, index: Int) -> some View {
        HStack {
            Text("\(set.setNumber)")
                .frame(width: 30, alignment: .leading)
                .foregroundStyle(.white.opacity(0.7))

            Text(set.setType.shortLabel)
                .font(.system(size: 10, weight: .medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(setTypeColor(set.setType).opacity(0.2), in: Capsule())
                .foregroundStyle(setTypeColor(set.setType))
                .frame(width: 50, alignment: .leading)

            Spacer()

            Text(setDetail(set))
                .foregroundStyle(.white)
        }
        .font(.system(size: 13, weight: .medium, design: .monospaced))
    }

    private func setDetail(_ set: WorkoutShareData.SetInfo) -> String {
        var parts: [String] = []
        if let w = set.weight, w > 0 {
            let display = weightUnit.fromKg(w)
            parts.append("\(display.formatted(.number.precision(.fractionLength(0...1))))\(weightUnit.displayName)")
        }
        if let r = set.reps, r > 0 {
            parts.append("\(r) reps")
        }
        if let d = set.duration, d > 0 {
            let mins = Int(d) / 60
            let secs = Int(d) % 60
            parts.append(mins > 0 ? "\(mins)m\(secs)s" : "\(secs)s")
        }
        if let dist = set.distance, dist > 0 {
            parts.append("\(dist.formatted(.number.precision(.fractionLength(0...2))))km")
        }
        return parts.joined(separator: " x ")
    }

    private func setTypeColor(_ type: SetType) -> Color {
        switch type {
        case .warmup: .yellow
        case .working: Color(red: 0.4, green: 0.85, blue: 0.6)
        case .drop: .cyan
        case .failure: .red
        }
    }

    // MARK: - Footer

    private var footerStats: some View {
        HStack(spacing: 0) {
            statItem(
                icon: "number",
                value: "\(data.sets.count)",
                label: "Sets"
            )

            Spacer()

            statItem(
                icon: "clock",
                value: formattedDuration,
                label: "Duration"
            )

            Spacer()

            if let cal = data.estimatedCalories, cal > 0 {
                statItem(
                    icon: "flame.fill",
                    value: "\(Int(cal))",
                    label: "kcal"
                )
            } else {
                statItem(
                    icon: "repeat",
                    value: "\(totalReps)",
                    label: "Reps"
                )
            }
        }
    }

    private var totalReps: Int {
        data.sets.compactMap(\.reps).reduce(0, +)
    }

    private func statItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    // MARK: - Branding

    private var branding: some View {
        HStack(spacing: 4) {
            Image(systemName: "heart.fill")
                .font(.system(size: 8))
                .foregroundStyle(Color(red: 0.4, green: 0.85, blue: 0.6))
            Text("Dailve")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.3))
        }
    }
}

// SetType.shortLabel is defined in ExerciseCategory+View.swift
