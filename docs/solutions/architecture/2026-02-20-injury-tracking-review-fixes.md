---
tags: [injury, isSaving, didFinishSaving, computed-property-caching, DateFormatter, validation, endDate, review-fix, swiftui-rendering, onChange-cache]
category: architecture
date: 2026-02-20
severity: important
related_files:
  - Dailve/Presentation/Injury/InjuryViewModel.swift
  - Dailve/Presentation/Activity/ActivityView.swift
  - Dailve/Presentation/Wellness/WellnessView.swift
  - Dailve/Presentation/Injury/InjuryHistoryView.swift
  - Dailve/Presentation/Injury/InjuryCardView.swift
  - Dailve/Presentation/Injury/InjuryFormSheet.swift
  - Dailve/Presentation/Injury/InjuryStatisticsView.swift
  - Dailve/Domain/Services/InjuryStatisticsService.swift
related_solutions:
  - architecture/2026-02-17-wellness-tab-review-fixes
---

# Solution: Injury Tracking 6-관점 리뷰 수정

## Problem

### Symptoms

Injury tracking 기능의 6-관점 리뷰에서 P1 7건, P2 13건 이슈 발견:
- `isSaving` 플래그가 ViewModel 내부에서 리셋됨 (Correction #43 위반)
- computed property가 body 평가마다 O(N) 연산 반복
- `DateFormatter`가 매 렌더마다 생성
- 날짜 검증 누락 (endDate future, startDate lower-bound)
- ActivityView에서 불필요한 ViewModel 의존

### Root Cause

1. **isSaving 패턴 불일치**: `createValidatedRecord()`가 record 생성 후 내부에서 `isSaving = false` 리셋 — View에서 `modelContext.insert()` 전에 flag가 이미 해제되어 중복 저장 가능
2. **computed property 남용**: `injuryConflicts`, `activeRecords`, `endedRecords`, `activeInjuries`가 매 렌더마다 필터링/UseCase 실행
3. **Formatter 미캐싱**: `InjuryCardView.durationLabel`에서 `DateFormatter()`를 매번 생성
4. **검증 불완전**: endDate가 미래인 경우, startDate가 10년 이전인 경우 검증 없음

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `InjuryViewModel.swift` | `didFinishSaving()` 메서드 추가, `createValidatedRecord`에서 isSaving 리셋 제거 | Correction #43 준수 |
| `InjuryViewModel.swift` | `applyUpdate`에 `isSaving = true` 추가 | 이중 저장 방지 |
| `InjuryViewModel.swift` | `markAsRecovered`에 `guard !isSaving` 추가 | 동시 mutation 방지 |
| `InjuryViewModel.swift` | endDate future / startDate lower-bound 검증 추가 | 입력 범위 완성 |
| `ActivityView.swift` | `InjuryViewModel` → `CheckInjuryConflictUseCase` 직접 사용, `@State cachedInjuryConflicts` | 불필요한 ViewModel 의존 제거 + 캐싱 |
| `InjuryHistoryView.swift` | `@State cachedActiveRecords/EndedRecords` + `rebuildRecordCache()` | O(N) 필터 캐싱 |
| `WellnessView.swift` | `@State cachedActiveInjuries` + `refreshActiveInjuriesCache()` | O(N) 필터 캐싱 |
| `InjuryCardView.swift` | `private enum Cache { static let dateFormatter }` | Formatter 재사용 |
| `InjuryHistoryView.swift` | `navigationDestination` 내부 조건부 content 제거 | Correction #48 준수 |
| `InjuryStatisticsView.swift` | Chart에 `.clipped()` 추가 | Correction #70 준수 |
| `InjuryFormSheet.swift` | haptic을 validation 성공 후에만 트리거 | 실패 시 오해 방지 |
| `InjuryStatisticsService.swift` | `comparisonWindowDays > 0` guard 추가 | 방어 코딩 |
| `WellnessView.swift` / `InjuryHistoryView.swift` | edit sheet 닫힌 후 `resetForm()` 호출 | stale form data 방지 |

### Key Code

**didFinishSaving 패턴:**
```swift
// ViewModel — isSaving stays true after record creation
func createValidatedRecord() -> InjuryRecord? {
    guard !isSaving else { return nil }
    guard let validated = validateInputs() else { return nil }
    isSaving = true
    return InjuryRecord(...)  // isSaving NOT reset here
}

func didFinishSaving() { isSaving = false }

// View — reset after insert completes
if let record = viewModel.createValidatedRecord() {
    modelContext.insert(record)
    viewModel.didFinishSaving()
    viewModel.resetForm()
    viewModel.isShowingAddSheet = false
}
```

**computed property → @State 캐시 패턴:**
```swift
@State private var cachedActiveRecords: [InjuryRecord] = []

var body: some View {
    ForEach(cachedActiveRecords) { ... }
}
.onChange(of: allRecords.count) { _, _ in rebuildRecordCache() }
.onAppear { rebuildRecordCache() }

private func rebuildRecordCache() {
    cachedActiveRecords = allRecords.filter(\.isActive)
}
```

**View에서 UseCase 직접 사용 (ViewModel 불필요 시):**
```swift
// Before: ViewModel을 통해 UseCase 호출
@State private var injuryViewModel = InjuryViewModel()
private var conflicts: [InjuryConflict] {
    injuryViewModel.checkConflicts(...)  // 매 렌더마다 실행
}

// After: UseCase 직접 + 캐싱
private let conflictUseCase = CheckInjuryConflictUseCase()
@State private var cachedConflicts: [InjuryConflict] = []
// onChange/task에서만 recompute
```

## Prevention

### Checklist Addition

- [ ] `isSaving = true` 후 record/Bool 반환 시 ViewModel 내부에서 리셋하지 않음 — View의 `didFinishSaving()` 호출 확인
- [ ] computed property가 `@Query` 배열을 필터링하면 `@State` 캐시 + `onChange(of: count)` 패턴 적용 여부 확인
- [ ] `DateFormatter`, `NumberFormatter` 등 NSObject 기반 formatter가 body/computed property 내에서 생성되지 않는지 확인
- [ ] 날짜 입력 검증에 endDate future + startDate lower-bound 포함 확인
- [ ] View가 ViewModel을 데이터 변환/CRUD 없이 UseCase 호출만 위해 보유하고 있으면 UseCase 직접 사용 고려

### Rule Addition (if applicable)

기존 rules에 이미 대부분 커버됨:
- `swift-layer-boundaries.md` — ViewModel에서 isSaving 리셋 금지 패턴
- `input-validation.md` — 날짜 범위 검증

추가 규칙 제안 없음 — Correction Log에 기록으로 충분.

## Lessons Learned

1. **ViewModel 의존 최소화**: View가 ViewModel의 한 메서드만 사용한다면, 해당 UseCase/Service를 직접 사용하는 것이 의존 그래프를 단순화함. ActivityView가 InjuryViewModel 전체를 들고 있을 필요 없었음.

2. **computed property ≠ 무료**: SwiftUI body에서 `@Query` 배열을 필터링하는 computed property는 매 렌더마다 O(N). 데이터가 적어도 패턴을 잘못 세우면 나중에 문제됨. `@State` 캐시 + `onChange(of: count)` 무효화가 표준 패턴.

3. **리뷰 수정은 파일별 batch + 한 번의 빌드**: 6관점 리뷰 결과를 이슈별로 개별 수정하지 않고, 파일별로 묶어서 적용 후 1회 빌드+테스트로 검증. 중간 빌드를 생략하여 시간 절약.

4. **P2 스킵 기준**: Color 값 캐싱(JointMarkerView, muscleOverlay) 같은 미시 최적화는 실제 item 수가 적으면(< 20) 측정 가능한 impact 없음. 성능 P2는 실제 hot path 여부를 먼저 판단.
