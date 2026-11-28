import SwiftUI

extension PersistentStoreOpening {
    @MainActor @ViewBuilder
    func content<Content: View>(
        retry: @escaping () -> Void,
        @ViewBuilder ready: (Value) -> Content
    ) -> some View {
        switch self {
        case let .ready(value):
            ready(value)
        case let .unavailable(diagnostic):
            ScrollView {
                VStack(spacing: 12) {
                    Image(systemName: "externaldrive.badge.exclamationmark")
                        .accessibilityHidden(true)
                    Text("Your records could not be opened.")
                        .font(.headline)
                    Text("Try again to reopen your existing records.")
                    Text(verbatim: diagnostic)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Retry", action: retry)
                        .accessibilityIdentifier("persistent-store-retry")
                }
                .multilineTextAlignment(.center)
                .padding()
            }
            .accessibilityIdentifier("persistent-store-unavailable")
        }
    }
}

extension View {
    /// Saving another workout successfully must never clear an older incomplete backup.
    func workoutBackupWarnings() -> some View {
        modifier(WorkoutBackupWarningModifier())
    }
}

private struct WorkoutBackupWarningModifier: ViewModifier {
    @State private var expanded = false
    @AppStorage(WorkoutBackupWarning.key) private var hasWarning = false

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .top) {
            if hasWarning {
                VStack(alignment: .leading, spacing: 4) {
                    Button("Apple Health backup incomplete") { expanded.toggle() }
                    if expanded {
                        Text("Some workout details are only on this device. Keep the original device and check the workout in DUNE.")
                            .font(.caption)
                    }
                }
                .padding(8)
                .background(.regularMaterial)
                .accessibilityIdentifier("workout-backup-incomplete")
            }
        }
    }
}
