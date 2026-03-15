---
tags: [swiftui, navigation, swiftdata, query, navigation-destination]
date: 2026-03-16
category: architecture
status: implemented
---

# @Query 기반 navigationDestination 해결 패턴

## Problem

`WellnessView`에서 `PostureRecordDestination`으로 네비게이션할 때, destination closure에서 `PostureAssessmentRecord`를 ID로 조회해야 한다. 그러나:
- `WellnessView`는 자세 기록 `@Query`를 직접 가지고 있지 않음
- `.navigationDestination` closure 안에서 `@Query`를 사용할 수 없음
- `PostureAssessmentLinkView`에 `.navigationDestination`을 걸면, 같은 타입의 destination이 `PostureHistoryView`에도 등록되어 중복 경고 가능

## Solution

`PostureRecordLookupView`라는 작은 wrapper View를 생성:

```swift
private struct PostureRecordLookupView: View {
    let recordID: UUID
    @Query(sort: \PostureAssessmentRecord.date, order: .reverse)
    private var records: [PostureAssessmentRecord]

    var body: some View {
        if let record = records.first(where: { $0.id == recordID }) {
            PostureDetailView(record: record)
        } else {
            ContentUnavailableView("Record not found", systemImage: "exclamationmark.triangle")
        }
    }
}
```

Parent에서 사용:
```swift
.navigationDestination(for: PostureRecordDestination.self) { destination in
    PostureRecordLookupView(recordID: destination.id)
}
```

## Prevention

- `@Query`가 필요한 `navigationDestination`에서는 항상 lookup wrapper View 패턴 사용
- 같은 Destination 타입이 여러 level에서 등록되어도, SwiftUI는 가장 가까운 ancestor의 handler를 사용하므로 충돌 없음

## Lessons Learned

- SwiftData `@Query`는 View body에서만 동작하므로, navigation destination 해결에 직접 사용 불가
- 작은 wrapper View로 `@Query` 스코프를 분리하면 깔끔하게 해결됨
