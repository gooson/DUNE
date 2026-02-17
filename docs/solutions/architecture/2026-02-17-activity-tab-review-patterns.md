---
tags: [review, refactoring, dry, singleton, displayname, validation, swiftdata]
category: architecture
date: 2026-02-17
severity: important
related_files:
  - Dailve/Presentation/Exercise/WorkoutSessionViewModel.swift
  - Dailve/Data/ExerciseLibraryService.swift
  - Dailve/Presentation/Shared/Extensions/WorkoutSet+Summary.swift
  - Dailve/Presentation/Shared/Extensions/ExerciseCategory+View.swift
related_solutions:
  - architecture/2026-02-17-cloudkit-optional-relationship.md
---

# Solution: Activity Tab Review Findings — 반복 패턴 정리

## Problem

### Symptoms

Activity 탭 전면 개편 후 6관점 코드 리뷰에서 P1 4건, P2 8건, P3 3건 발견:

- **P1-1**: intensity 필드 미검증 (WorkoutSet에 저장 안 됨)
- **P1-2**: `ExerciseLibraryService`가 매번 새로 생성되어 JSON 중복 파싱
- **P1-3**: `setSummary` 로직이 3곳에서 중복
- **P1-4**: 미사용 `library` 파라미터가 View에 전달됨
- **P2**: `rawValue.capitalized`가 locale-unsafe, magic number 90.0 등

### Root Cause

기능 구현에 집중하며 아래 패턴을 누락:
1. 새 필드(`intensity`) 추가 시 **전체 파이프라인** (입력 → 검증 → 저장) 누락
2. JSON 파싱 서비스에 싱글턴 패턴 미적용
3. 중복 로직 추출 시점 판단 실패 (3곳 이상이면 즉시 추출)
4. `rawValue.capitalized` 대신 `displayName` computed property 사용 규칙 부재

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| WorkoutSet.swift | `intensity: Int?` 필드 추가 | 운동 강도 저장 |
| WorkoutSessionViewModel.swift | intensity/roundsBased 검증 블록 추가 | 입력 파이프라인 완성 |
| WorkoutSessionViewModel.swift | `maxIntensity = 10`, `defaultRestSeconds = 90` 상수화 | magic number 제거 |
| ExerciseLibraryService.swift | `static let shared` 싱글턴 추가 | JSON 중복 파싱 방지 |
| ExerciseLibraryService.swift | `try?` → `do/catch` + AppLogger | 에러 가시성 확보 |
| WorkoutSet+Summary.swift | `setSummary()` / `summary()` 공통 extension 추출 | DRY (3곳 중복 제거) |
| ExerciseCategory+View.swift | `displayName` computed property | locale-safe 표시명 |
| ExerciseListSection.swift | 미사용 `library` 프로퍼티 제거 | dead code 정리 |

### Key Code

```swift
// 1. 싱글턴 패턴 (JSON 파싱 서비스)
final class ExerciseLibraryService: ExerciseLibraryQuerying {
    static let shared = ExerciseLibraryService()
}

// 2. DRY: Collection extension으로 중복 제거
extension Collection where Element: WorkoutSet {
    func setSummary() -> String? { ... }
}

// 3. displayName 패턴 (rawValue.capitalized 대체)
extension MuscleGroup {
    var displayName: String { rawValue.capitalized }
}
```

## Prevention

### Checklist Addition

- [ ] 새 필드 추가 시 입력 → 검증 → 저장 → 표시 전체 파이프라인 확인
- [ ] JSON/리소스 파싱 서비스는 싱글턴 사용
- [ ] 동일 로직 3곳 이상 → 즉시 Collection extension 또는 공통 함수 추출
- [ ] `rawValue` 직접 표시 금지 → `displayName` computed property 사용

### Rule Addition

`.claude/rules/swift-layer-boundaries.md`에 추가 권장:

```
## Display Name Convention
- enum의 rawValue를 UI에 직접 표시하지 않음
- `Presentation/Shared/Extensions/{Type}+View.swift`에 `displayName` 프로퍼티 추가
- 예: `extension MuscleGroup { var displayName: String { rawValue.capitalized } }`
```

## Lessons Learned

1. **새 필드 = 전체 파이프라인 점검**: 모델에 필드를 추가하면 EditableSet → 검증 → WorkoutSet → 표시까지 모두 확인
2. **JSON 파싱은 비싸다**: 번들 JSON을 매번 파싱하면 메모리/CPU 낭비. 싱글턴으로 1회만 로드
3. **3곳 중복 = 추출 시점**: 2곳은 허용, 3곳부터는 반드시 공통화
4. **rawValue는 내부용**: UI에 표시할 때는 항상 displayName을 거쳐야 locale 변경에 유연
