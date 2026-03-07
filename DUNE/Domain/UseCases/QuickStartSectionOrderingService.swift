import Foundation

struct QuickStartSectionOrdering: Sendable {
    let recentIDs: [String]
    let preferredIDs: [String]
    let popularIDs: [String]

    var priorityIDs: [String] {
        recentIDs + preferredIDs + popularIDs
    }
}

enum QuickStartSectionOrderingService {
    static func make(
        recentIDs: [String],
        preferredIDs: [String],
        popularIDs: [String],
        canonicalize: (String) -> String
    ) -> QuickStartSectionOrdering {
        var seenCanonicalIDs = Set<String>()

        func uniqueIDs(from ids: [String]) -> [String] {
            ids.compactMap { id in
                guard !id.isEmpty else { return nil }
                let canonicalID = canonicalize(id)
                let key = canonicalID.isEmpty ? id : canonicalID
                guard seenCanonicalIDs.insert(key).inserted else { return nil }
                return id
            }
        }

        return QuickStartSectionOrdering(
            recentIDs: uniqueIDs(from: recentIDs),
            preferredIDs: uniqueIDs(from: preferredIDs),
            popularIDs: uniqueIDs(from: popularIDs)
        )
    }
}
