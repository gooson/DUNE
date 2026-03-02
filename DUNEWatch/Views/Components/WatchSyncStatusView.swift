import SwiftUI

/// Reusable sync status indicator for Watch views.
/// Shows the current WatchConnectivityManager sync state with appropriate icon and label.
struct WatchSyncStatusView: View {
    @Environment(WatchConnectivityManager.self) private var connectivity

    var body: some View {
        HStack(spacing: 4) {
            switch connectivity.syncStatus {
            case .syncing:
                ProgressView()
                    .frame(width: 12, height: 12)
                Text("Syncing...")
            case .synced(let date):
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(DS.Color.positive)
                Text(syncTimeLabel(from: date))
            case .failed(let message):
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(DS.Color.caution)
                Text(message)
            case .notConnected:
                Image(systemName: "iphone.slash")
                    .foregroundStyle(.secondary)
                Text("iPhone not connected")
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private func syncTimeLabel(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return String(localized: "Just synced")
        } else if interval < 3600 {
            let mins = Int(interval / 60).formattedWithSeparator
            return String(localized: "\(mins) min ago")
        } else {
            let hours = Int(interval / 3600).formattedWithSeparator
            return String(localized: "\(hours)h ago")
        }
    }
}
