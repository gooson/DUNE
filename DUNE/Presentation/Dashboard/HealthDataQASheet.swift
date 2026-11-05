import SwiftUI

struct HealthDataQASheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: HealthDataQAViewModel
    @FocusState private var isInputFocused: Bool

    init(viewModel: HealthDataQAViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isAvailable {
                    availableContent
                } else {
                    unavailableContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background { SheetWaveBackground().opacity(0.55) }
            .navigationTitle("Health Q&A")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink("Browse records") {
                        HealthQueryView(queryService: HealthQueryServiceRouting.current())
                    }
                    .accessibilityIdentifier("health-qa-browse-records")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .accessibilityIdentifier("health-qa-done")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onDisappear {
            Task { await viewModel.resetConversation() }
        }
    }

    private var availableContent: some View {
        VStack(spacing: DS.Spacing.md) {
            if viewModel.messages.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                        introductionCard
                        suggestedPrompts
                    }
                    .padding(.vertical, DS.Spacing.md)
                    .frame(maxWidth: 680)
                    .frame(maxWidth: .infinity)
                }
                .scrollBounceBehavior(.basedOnSize)
                .accessibilityIdentifier("health-qa-empty-scroll")
            } else {
                messageList
            }

            composer
                .frame(maxWidth: 680)
                .padding(.bottom, DS.Spacing.sm)
        }
        .padding(.horizontal, DS.Spacing.md)
    }

    private var introductionCard: some View {
        HeroCard(tintColor: DS.Color.warmGlow) {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                Image(systemName: "sparkles")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(DS.Color.warmGlow)
                    .frame(minWidth: 40, minHeight: 40)
                    .background(DS.Color.warmGlow.opacity(0.14), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text("Answers are informational and based on your recent DUNE health data.")
                        .accessibilityIdentifier("health-qa-overview-body")
                        .font(.footnote)
                        .foregroundStyle(DS.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if viewModel.messages.isEmpty {
                        Text("Try one of these questions to get started.")
                            .accessibilityIdentifier("health-qa-overview-guide")
                            .font(.subheadline.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var unavailableContent: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                HeroCard(tintColor: DS.Color.warmGlow) {
                    VStack(spacing: DS.Spacing.md) {
                        Image(systemName: "sparkles.slash")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundStyle(DS.Color.warmGlow)
                            .frame(width: 64, height: 64)
                            .background(DS.Color.warmGlow.opacity(0.14), in: Circle())
                            .accessibilityHidden(true)

                        Text("Health Q&A requires Apple Intelligence on a supported device.")
                            .accessibilityIdentifier("health-qa-unavailable-title")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("This feature uses on-device Foundation Models, so it only works on compatible hardware.")
                            .accessibilityIdentifier("health-qa-unavailable-body")
                            .font(.footnote)
                            .foregroundStyle(DS.Color.textSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity)
                }

                NavigationLink {
                    HealthQueryView(queryService: HealthQueryServiceRouting.current())
                } label: {
                    Label("Browse health records", systemImage: "heart.text.square")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .accessibilityIdentifier("health-qa-browse-records")
            }
            .padding(DS.Spacing.xl)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .accessibilityIdentifier("health-qa-unavailable-scroll")
    }

    private var suggestedPrompts: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            ForEach(viewModel.suggestedPrompts.indices, id: \.self) { index in
                let prompt = viewModel.suggestedPrompts[index]
                Button {
                    Task { await viewModel.send(prompt: prompt) }
                } label: {
                    HStack(spacing: DS.Spacing.md) {
                        Image(systemName: "sparkles")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DS.Color.warmGlow)
                            .frame(minWidth: 36, minHeight: 36)
                            .background(DS.Color.warmGlow.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                            .accessibilityHidden(true)
                        Text(prompt)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(DS.Spacing.md)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(index == 0 ? "health-qa-prompt-sleep" : "health-qa-prompt-\(index)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: DS.Spacing.sm) {
                    introductionCard

                    ForEach(viewModel.messages) { message in
                        HealthDataQAMessageBubble(message: message)
                            .id(message.id)
                    }

                    if viewModel.isSending {
                        HStack {
                            InlineCard {
                                HStack(spacing: DS.Spacing.sm) {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("Thinking...")
                                        .font(.footnote)
                                        .foregroundStyle(DS.Color.textSecondary)
                                }
                            }
                            Spacer(minLength: 24)
                        }
                    }
                }
                .padding(.vertical, DS.Spacing.xxs)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("health-qa-message-list")
            .onChange(of: viewModel.messages.count) { _, _ in
                guard let lastMessage = viewModel.messages.last else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                }
            }
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: DS.Spacing.sm) {
            TextField("Ask about sleep, recovery, or workouts", text: $viewModel.draft, axis: .vertical)
                .accessibilityIdentifier("health-qa-input")
                .textFieldStyle(.plain)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
                .focused($isInputFocused)
                .onSubmit {
                    Task { await viewModel.sendCurrentDraft() }
                }

            Button {
                Task { await viewModel.sendCurrentDraft() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .disabled(!viewModel.canSend)
            .accessibilityLabel("Send question")
            .accessibilityIdentifier("health-qa-send")
        }
    }
}

private struct HealthDataQAMessageBubble: View {
    let message: HealthDataQAMessage

    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack {
            if message.role == .assistant {
                InlineCard {
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        Text(message.text)
                            .accessibilityIdentifier("health-qa-answer-body")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)

                        if message.isFallback {
                            Text("Fallback answer")
                                .accessibilityIdentifier("health-qa-fallback-label")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Spacer(minLength: 28)
            } else {
                Spacer(minLength: 28)
                Text(message.text)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(theme.accentColor.opacity(0.18), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
            }
        }
    }
}
