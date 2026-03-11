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

## 기존 @Model 필드 변경도 새 Schema 버전 필요

최신 `VersionedSchema`가 live model type를 직접 참조하는 상태에서
필드를 추가/삭제/변경하면 배포된 checksum이 drift한다.

- 이미 배포된 최신 버전은 snapshot model로 고정
- 실제 변경은 새 `VersionedSchema` + migration stage로 승격

그렇지 않으면 기존 store가 어떤 declared schema에도 매칭되지 않아
`unknown coordinator model version` (134504) 로 다시 깨질 수 있다.

## 스키마 변경 테스트

@Model 변경 후 반드시:
1. 앱 삭제 → 설치 → 실행 (첫 실행: 로컬 스토어 생성)
2. 앱 종료 → 재실행 (두 번째 실행: CloudKit 스키마 검증)
3. 두 번째 실행에서 crash가 없어야 통과

## ModelContainer Recovery

`ModelContainer` 초기화 실패 시에는 모든 에러에 대해 store 파일을 삭제하면 안 된다.
CloudKit 계정 상태, 권한, 파일 잠금, 디스크 오류까지 데이터 유실로 이어질 수 있다.

삭제 재시도는 다음 조건에서만 허용한다:
- `NSPersistentStoreIncompatibleVersionHashError` 등 명확한 migration 에러 코드
- `unknown coordinator model version`, `missing mapping model` 등 명확한 migration 시그니처

그 외 초기화 실패는 store를 보존한 채 in-memory fallback 또는 사용자 복구 경로로 처리한다.
