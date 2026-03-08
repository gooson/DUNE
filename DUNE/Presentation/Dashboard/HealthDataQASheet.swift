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
            VStack(spacing: DS.Spacing.lg) {
                if viewModel.isAvailable {
                    availableContent
                } else {
                    unavailableContent
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.top, DS.Spacing.md)
            .padding(.bottom, DS.Spacing.sm)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .navigationTitle("Health Q&A")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onDisappear {
            Task { await viewModel.resetConversation() }
        }
    }

    private var availableContent: some View {
        VStack(spacing: DS.Spacing.lg) {
            InlineCard {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("Answers are informational and based on your recent DUNE health data.")
                        .font(.footnote)
                        .foregroundStyle(DS.Color.textSecondary)

                    if viewModel.messages.isEmpty {
                        Text("Try one of these questions to get started.")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if viewModel.messages.isEmpty {
                suggestedPrompts
            } else {
                messageList
            }

            composer
        }
    }

    private var unavailableContent: some View {
        Spacer()
            .overlay {
                VStack(spacing: DS.Spacing.md) {
                    Image(systemName: "sparkles.slash")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.tertiary)

                    Text("Health Q&A requires Apple Intelligence on a supported device.")
                        .font(.headline)
                        .multilineTextAlignment(.center)

                    Text("This feature uses on-device Foundation Models, so it only works on compatible hardware.")
                        .font(.footnote)
                        .foregroundStyle(DS.Color.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, DS.Spacing.xl)
            }
    }

    private var suggestedPrompts: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            ForEach(viewModel.suggestedPrompts, id: \.self) { prompt in
                Button {
                    Task { await viewModel.send(prompt: prompt) }
                } label: {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.secondary)
                        Text(prompt)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.sm)
                            .fill(.ultraThinMaterial)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: DS.Spacing.sm) {
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
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                .textFieldStyle(.plain)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                        .fill(.ultraThinMaterial)
                )
                .focused($isInputFocused)
                .onSubmit {
                    Task { await viewModel.sendCurrentDraft() }
                }

            Button {
                Task { await viewModel.sendCurrentDraft() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28, weight: .semibold))
            }
            .disabled(!viewModel.canSend)
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
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)

                        if message.isFallback {
                            Text("Fallback answer")
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
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.sm)
                            .fill(theme.accentColor.opacity(0.18))
                    )
            }
        }
    }
}
