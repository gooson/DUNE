import Foundation

/// Persists alert history and read state in UserDefaults.
/// Uses a dedicated serial queue to keep updates thread-safe.
final class NotificationInboxStore: @unchecked Sendable {
    static let shared = NotificationInboxStore()

    private enum Keys {
        static let inbox = (Bundle.main.bundleIdentifier ?? "com.dailve") + ".notificationInbox.items"
    }

    private let defaults: UserDefaults
    private let queue: DispatchQueue
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        defaults: UserDefaults = .standard,
        queue: DispatchQueue = DispatchQueue(label: "com.dune.notification-inbox-store")
    ) {
        self.defaults = defaults
        self.queue = queue
    }

    func items() -> [NotificationInboxItem] {
        queue.sync {
            loadItemsLocked().sorted { $0.createdAt > $1.createdAt }
        }
    }

    func unreadCount() -> Int {
        queue.sync {
            loadItemsLocked().filter { !$0.isRead }.count
        }
    }

    @discardableResult
    func append(
        insight: HealthInsight,
        source: NotificationInboxItem.Source = .localNotification
    ) -> NotificationInboxItem {
        queue.sync {
            var items = loadItemsLocked()
            let item = NotificationInboxItem(
                id: UUID().uuidString,
                insightType: insight.type,
                title: insight.title,
                body: insight.body,
                createdAt: insight.date,
                isRead: false,
                openedAt: nil,
                route: insight.route,
                source: source
            )
            items.append(item)
            saveItemsLocked(items)
            return item
        }
    }

    func item(withID id: String) -> NotificationInboxItem? {
        queue.sync {
            loadItemsLocked().first { $0.id == id }
        }
    }

    @discardableResult
    func markRead(id: String, openedAt: Date = Date()) -> NotificationInboxItem? {
        queue.sync {
            var items = loadItemsLocked()
            guard let index = items.firstIndex(where: { $0.id == id }) else { return nil }
            guard !items[index].isRead else { return items[index] }
            items[index].isRead = true
            items[index].openedAt = openedAt
            let updated = items[index]
            saveItemsLocked(items)
            return updated
        }
    }

    @discardableResult
    func markUnread(id: String) -> NotificationInboxItem? {
        queue.sync {
            var items = loadItemsLocked()
            guard let index = items.firstIndex(where: { $0.id == id }) else { return nil }
            guard items[index].isRead else { return items[index] }
            items[index].isRead = false
            items[index].openedAt = nil
            let updated = items[index]
            saveItemsLocked(items)
            return updated
        }
    }

    func markAllRead(openedAt: Date = Date()) {
        queue.sync {
            var items = loadItemsLocked()
            var didChange = false
            for index in items.indices where !items[index].isRead {
                items[index].isRead = true
                items[index].openedAt = openedAt
                didChange = true
            }
            if didChange {
                saveItemsLocked(items)
            }
        }
    }

    @discardableResult
    func delete(id: String) -> NotificationInboxItem? {
        queue.sync {
            var items = loadItemsLocked()
            guard let index = items.firstIndex(where: { $0.id == id }) else { return nil }
            let removed = items.remove(at: index)
            saveItemsLocked(items)
            return removed
        }
    }

    func deleteAll() {
        queue.sync {
            let items = loadItemsLocked()
            guard !items.isEmpty else { return }
            defaults.removeObject(forKey: Keys.inbox)
        }
    }

    private func loadItemsLocked() -> [NotificationInboxItem] {
        guard let data = defaults.data(forKey: Keys.inbox) else { return [] }
        guard let decoded = try? decoder.decode([NotificationInboxItem].self, from: data) else {
            defaults.removeObject(forKey: Keys.inbox)
            return []
        }
        return decoded
    }

    private func saveItemsLocked(_ items: [NotificationInboxItem]) {
        guard let data = try? encoder.encode(items) else { return }
        defaults.set(data, forKey: Keys.inbox)
    }
}
