# SwiftData + CloudKit Rules

## @Relationship는 반드시 Optional

CloudKit은 모든 relationship을 Optional로 요구한다. 위반 시 두 번째 앱 실행부터 `ModelContainer` fatal crash.

```swift
// BAD: CloudKit crash
@Relationship(deleteRule: .cascade, inverse: \Child.parent)
var children: [Child] = []

// GOOD: CloudKit compatible
@Relationship(deleteRule: .cascade, inverse: \Child.parent)
var children: [Child]? = []
```

## Optional 배열 접근 패턴

```swift
// Computed property에서 nil-coalescing 사용
var completedChildren: [Child] {
    (children ?? []).filter(\.isCompleted)
}

// 새 항목 할당은 배열 구성 후 한 번에
var newChildren: [Child] = []
for item in items {
    newChildren.append(Child(...))
}
record.children = newChildren
```

## 새 @Model 추가 시 VersionedSchema 동기화 필수

`ModelContainer(for:)`에 모델을 추가하면 최신 `VersionedSchema.models`에도 반드시 추가.
불일치 시 staged migration이 "unknown coordinator model version" (134504) 에러로 실패하며,
store 삭제 fallback으로도 복구 불가 (새 store 생성에도 스키마 일치 필요).

## 스키마 변경 테스트

@Model 변경 후 반드시:
1. 앱 삭제 → 설치 → 실행 (첫 실행: 로컬 스토어 생성)
2. 앱 종료 → 재실행 (두 번째 실행: CloudKit 스키마 검증)
3. 두 번째 실행에서 crash가 없어야 통과

## ModelContainer Fallback

MVP 단계에서는 스키마 변경으로 인한 crash 방지를 위해 store 파일 삭제 fallback 사용:

```swift
do {
    modelContainer = try ModelContainer(for: ...)
} catch {
    Self.deleteStoreFiles(at: config.url) // .sqlite, -wal, -shm
    modelContainer = try ModelContainer(for: ...)
}
```
