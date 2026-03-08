import SwiftUI

struct VisionImmersiveExperienceView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @State private var viewModel: VisionImmersiveExperienceViewModel
    @State private var breathPhase = 0.18
    @State private var journeyProgress = 0.0
    @State private var hasStartedAnimations = false

    init(sharedHealthDataService: SharedHealthDataService? = nil) {
        _viewModel = State(
            initialValue: VisionImmersiveExperienceViewModel(
                sharedHealthDataService: sharedHealthDataService
            )
        )
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if let summary = viewModel.summary {
                VisionImmersiveSceneView(
                    summary: summary,
                    mode: viewModel.selectedMode,
                    breathPhase: breathPhase,
                    journeyProgress: journeyProgress
                )
            }

            VStack(spacing: 24) {
                header
                Spacer()
                controlPanel
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 28)
        }
        .preferredSurroundingsEffect(surroundingsEffect)
        .task {
            await viewModel.loadIfNeeded()
            startAnimationsIfNeeded()
        }
        .onChange(of: reduceMotion) { _, _ in
            startAnimationsIfNeeded(restartTimeline: true)
        }
        .onChange(of: viewModel.selectedMode) { _, _ in
            startAnimationsIfNeeded(restartTimeline: true)
        }
        .onChange(of: viewModel.summary?.sleepJourney.segments.count) { _, _ in
            startAnimationsIfNeeded(restartTimeline: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: .simulatorAdvancedMockDataDidChange)) { _ in
            Task {
                await viewModel.reload()
                startAnimationsIfNeeded(restartTimeline: true)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Immersive Recovery Space")
                    .font(.largeTitle.weight(.bold))

                Text(headerSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 560, alignment: .leading)
            }

            Spacer()

            HStack(spacing: 12) {
                Button {
                    Task {
                        await viewModel.reload()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }

                Button {
                    Task {
                        await dismissImmersiveSpace()
                    }
                } label: {
                    Label("Close Space", systemImage: "xmark")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 30, style: .continuous))
    }

    private var controlPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            Picker("Experience", selection: $viewModel.selectedMode) {
                ForEach(VisionImmersiveMode.allCases) { mode in
                    Text(verbatim: mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            switch viewModel.loadState {
            case .idle, .loading:
                loadingState
            case .failed(let message):
                messageCard(message, icon: "exclamationmark.triangle.fill")
            case .ready:
                readyPanel
            }
        }
        .padding(24)
        .frame(maxWidth: 760, alignment: .leading)
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 34, style: .continuous))
    }

    private var readyPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(panelTitle)
                        .font(.title3.weight(.semibold))
                    Text(panelSubtitle)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let score = viewModel.summary?.atmosphere.score {
                    statPill(
                        title: String(localized: "Condition"),
                        value: score.formatted()
                    )
                }
            }

            HStack(spacing: 12) {
                statPill(
                    title: String(localized: "Cadence"),
                    value: cadenceValue
                )
                statPill(
                    title: String(localized: "Sleep"),
                    value: sleepValue
                )
                statPill(
                    title: String(localized: "Session"),
                    value: sessionValue
                )
            }

            if viewModel.selectedMode == .recovery {
                HStack(spacing: 12) {
                    Button(viewModel.recoveryButtonTitle) {
                        Task {
                            if viewModel.isRecoverySessionActive {
                                await viewModel.completeRecoverySession()
                            } else {
                                viewModel.startRecoverySession()
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isSavingMindfulSession)

                    Text(viewModel.recoveryStatusText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else if viewModel.selectedMode == .sleepJourney {
                Text(sleepJourneyStatus)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text(atmosphereStatus)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let message = viewModel.message {
                messageCard(message, icon: "waveform.badge.exclamationmark")
            }
        }
    }

    private var loadingState: some View {
        VStack(alignment: .leading, spacing: 12) {
            ProgressView()
            Text("Loading immersive health data")
                .font(.headline)
            Text("DUNE is fetching condition and sleep context for this space.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func messageCard(_ message: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.tint)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func statPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: title)
                .font(.callout)
                .foregroundStyle(.secondary)
            Text(verbatim: value)
                .font(.headline.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var panelTitle: String {
        switch viewModel.selectedMode {
        case .atmosphere:
            viewModel.summary?.atmosphere.title ?? String(localized: "Recovery Atmosphere")
        case .recovery:
            viewModel.summary?.recoverySession.title ?? String(localized: "Recovery Session")
        case .sleepJourney:
            viewModel.summary?.sleepJourney.title ?? String(localized: "Sleep Journey")
        }
    }

    private var panelSubtitle: String {
        switch viewModel.selectedMode {
        case .atmosphere:
            viewModel.summary?.atmosphere.subtitle ?? String(localized: "Condition-driven surroundings and recovery tone.")
        case .recovery:
            viewModel.summary?.recoverySession.subtitle ?? String(localized: "Guided cadence for downshifting and mindful recovery.")
        case .sleepJourney:
            viewModel.summary?.sleepJourney.subtitle ?? String(localized: "Latest sleep stages mapped into a spatial timeline.")
        }
    }

    private var cadenceValue: String {
        guard let cadence = viewModel.summary?.recoverySession.cadence else { return "--" }
        return "\(cadence.inhaleSeconds)-\(cadence.exhaleSeconds)s"
    }

    private var sleepValue: String {
        guard let sleepJourney = viewModel.summary?.sleepJourney, sleepJourney.hasData else {
            return "--"
        }
        return "\(Int(sleepJourney.totalMinutes.rounded()).formatted()) min"
    }

    private var sessionValue: String {
        guard let recoverySession = viewModel.summary?.recoverySession else { return "--" }
        return "\(recoverySession.suggestedDurationMinutes.formatted()) min"
    }

    private var atmosphereStatus: String {
        guard let atmosphere = viewModel.summary?.atmosphere else {
            return String(localized: "Atmosphere will react once your recovery context has loaded.")
        }
        if let score = atmosphere.score {
            return String(localized: "Condition score \(score.formatted()) is driving the current surroundings preset.")
        }
        return String(localized: "This atmosphere is using fallback recovery guidance.")
    }

    private var sleepJourneyStatus: String {
        guard let sleepJourney = viewModel.summary?.sleepJourney else {
            return String(localized: "Sleep stages are not available yet.")
        }
        guard sleepJourney.hasData else {
            return String(localized: "Sleep stages are not available yet.")
        }

        let activeStage = activeSleepSegment?.stage
        if let activeStage {
            return String(localized: "Current stage focus: \(displayName(for: activeStage))")
        }

        return String(localized: "Sleep timeline is cycling through your latest available stages.")
    }

    private var headerSubtitle: String {
        viewModel.selectedMode.subtitle
    }

    private var activeSleepSegment: ImmersiveRecoverySummary.SleepJourney.Segment? {
        guard let sleepJourney = viewModel.summary?.sleepJourney, sleepJourney.hasData else { return nil }
        return sleepJourney.segments.first { segment in
            journeyProgress >= segment.startProgress && journeyProgress <= segment.endProgress
        } ?? sleepJourney.segments.last
    }

    private var surroundingsEffect: SurroundingsEffect {
        guard let summary = viewModel.summary else { return .semiDark }

        switch viewModel.selectedMode {
        case .atmosphere:
            switch summary.atmosphere.preset {
            case .sunrise:
                return SurroundingsEffect.colorMultiply(Color(red: 0.96, green: 0.78, blue: 0.42))
            case .clouded:
                return SurroundingsEffect.colorMultiply(Color(red: 0.62, green: 0.76, blue: 0.88))
            case .mist:
                return SurroundingsEffect.semiDark
            case .storm:
                return SurroundingsEffect.dark
            }
        case .recovery:
            switch summary.recoverySession.recommendation {
            case .sustain:
                return SurroundingsEffect.colorMultiply(Color(red: 0.42, green: 0.84, blue: 0.76))
            case .rebalance:
                return SurroundingsEffect.colorMultiply(Color(red: 0.52, green: 0.74, blue: 0.92))
            case .restore:
                return SurroundingsEffect.dim(intensity: 0.54)
            }
        case .sleepJourney:
            switch activeSleepSegment?.stage {
            case .awake:
                return SurroundingsEffect.colorMultiply(Color(red: 0.92, green: 0.80, blue: 0.42))
            case .core:
                return SurroundingsEffect.colorMultiply(Color(red: 0.40, green: 0.70, blue: 0.90))
            case .deep:
                return SurroundingsEffect.dark
            case .rem:
                return SurroundingsEffect.colorMultiply(Color(red: 0.92, green: 0.58, blue: 0.66))
            case .unspecified, .none:
                return SurroundingsEffect.semiDark
            }
        }
    }

    private func displayName(for stage: SleepStage.Stage) -> String {
        switch stage {
        case .awake:
            String(localized: "Awake")
        case .core:
            String(localized: "Core")
        case .deep:
            String(localized: "Deep")
        case .rem:
            String(localized: "REM")
        case .unspecified:
            String(localized: "Unspecified")
        }
    }

    private func startAnimationsIfNeeded(restartTimeline: Bool = false) {
        if reduceMotion {
            hasStartedAnimations = false
            breathPhase = 0.58
            journeyProgress = activeSleepSegment?.startProgress ?? 0.0
            return
        }

        if !hasStartedAnimations {
            hasStartedAnimations = true

            withAnimation(.easeInOut(duration: 4.8).repeatForever(autoreverses: true)) {
                breathPhase = 1.0
            }

            withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) {
                journeyProgress = 1.0
            }
            return
        }

        guard restartTimeline else { return }

        journeyProgress = 0.0
        withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) {
            journeyProgress = 1.0
        }
    }
}
