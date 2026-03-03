import SwiftUI

/// Latest-first notification inbox accessed from the Today tab toolbar.
struct NotificationHubView: View {
    @State private var items: [NotificationInboxItem] = []
    @State private var unreadCount = 0

    private let inboxManager = NotificationInboxManager.shared

    var body: some View {
        List {
            if items.isEmpty {
                ContentUnavailableView(
                    "No Notifications",
                    systemImage: "bell.slash",
                    description: Text("알림이 도착하면 여기에 표시됩니다.")
                )
            } else {
                ForEach(items) { item in
                    Button {
                        inboxManager.open(itemID: item.id)
                    } label: {
                        notificationRow(for: item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .englishNavigationTitle("Notifications")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Read All") {
                    inboxManager.markAllRead()
                }
                .disabled(unreadCount == 0)
            }
        }
        .task {
            reload()
        }
        .onReceive(NotificationCenter.default.publisher(for: NotificationInboxManager.inboxDidChangeNotification)) { _ in
            reload()
        }
    }

    private func reload() {
        items = inboxManager.items()
        unreadCount = inboxManager.unreadCount()
    }

    private func notificationRow(for item: NotificationInboxItem) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(spacing: DS.Spacing.xs) {
                if !item.isRead {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 8, height: 8)
                }

                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Spacer()

                Text(item.createdAt, format: .relative(presentation: .named))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(item.body)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            if item.route?.destination == .workoutDetail {
                Label("Workout Detail", systemImage: "figure.strengthtraining.traditional")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, DS.Spacing.xxs)
    }
}

#Preview {
    NavigationStack {
        NotificationHubView()
    }
}
