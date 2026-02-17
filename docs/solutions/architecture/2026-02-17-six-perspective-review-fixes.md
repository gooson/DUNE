---
tags: [review, multi-perspective, layer-boundary, data-validation, task-management, DRY, watch-connectivity, isSaving, cancel-before-spawn]
category: architecture
date: 2026-02-17
severity: critical
related_files:
  - Dailve/Domain/Models/ExerciseCategory.swift
  - Dailve/Data/HealthKit/ExerciseCategory+HealthKit.swift
  - Dailve/Domain/Protocols/ExerciseLibraryQuerying.swift
  - Dailve/Presentation/Shared/Extensions/ExerciseRecord+WeeklyVolume.swift
  - Dailve/Presentation/Exercise/CompoundWorkoutViewModel.swift
  - Dailve/Presentation/Exercise/WorkoutSessionViewModel.swift
  - Dailve/Data/WatchConnectivity/WatchSessionManager.swift
  - DailveWatch/WatchConnectivityManager.swift
  - Dailve/Domain/UseCases/OneRMEstimationService.swift
related_solutions: []
---

# Solution: 6-Perspective Code Review Comprehensive Fix (Activity Tab Redesign)

## Problem

`feature/activity-tab-redesign` branch (62 files, ~7,498 lines) 의 6-관점 리뷰에서 **P1: 10, P2: 18, P3: 16** 건의 이슈가 발견됨. 보안, 성능, 아키텍처, 데이터 무결성, 단순성, 에이전트 네이티브 관점에서 발견된 문제들을 체계적으로 수정.

### Symptoms

- Domain 레이어에 HealthKit import 존재 (layer boundary 위반)
- `isSaving` 플래그가 record 반환 전에 리셋되어 중복 저장 가능
- Task 취소 시 `isLoading = false` 리셋으로 UI 상태 불일치
- WatchConnectivity 메시지 핸들링에 cancel-before-spawn 미적용
- Watch에서 받은 데이터에 범위 검증 없음
- weekly volume 계산이 3곳에서 중복
- `ExerciseLibraryQuerying` 프로토콜이 Data layer에 위치

### Root Cause

대규모 기능 추가(62 파일)에서 각 파일 단위 구현에 집중하여 cross-cutting concerns를 놓침:
1. **Layer boundary**: 빠른 구현을 위해 HealthKit 매핑을 Domain에 직접 작성
2. **Task lifecycle**: `isSaving` 리셋 타이밍을 record 생성 시점으로 잘못 배치
3. **DRY violation**: 3개 뷰에서 동일한 volume 계산을 독립적으로 구현
4. **Trust boundary**: Watch → iPhone 데이터를 무검증 수용

## Solution

### Changes Made (P1 — Critical, 10건)

| File | Change | Reason |
|------|--------|--------|
| `ActivityViewModel` | `guard !Task.isCancelled` 후에만 `isLoading = false` | 취소된 Task가 현재 로드 상태를 덮어쓰기 방지 |
| `CompoundWorkoutViewModel` | `didFinishSaving()` 패턴 도입 | View가 insert 완료 후 flag 리셋 |
| `WorkoutSessionViewModel` | 동일한 `didFinishSaving()` 패턴 | isSaving 조기 리셋 방지 |
| `WatchSessionManager` | `messageHandlerTask?.cancel()` + 새 Task 할당 | cancel-before-spawn 패턴 적용 |
| `WatchSessionManager` DTOs | `WatchSetData.isValid`, `WatchHeartRateSample.isValid` | Watch 데이터 범위 검증 (weight 0-500, reps 0-1000, HR 20-300) |
| `ExerciseRecord+WeeklyVolume` (NEW) | `weeklyMuscleVolume()` 공통 함수 + `ExerciseRecordVolumeProviding` 프로토콜 | 3곳 중복 제거 |
| `ExerciseLibraryQuerying` (MOVED) | Data → Domain layer | 의존성 방향 준수 |
| `ExerciseCategory` | HealthKit mapping → `ExerciseCategory+HealthKit.swift` (Data) | Domain에서 HealthKit import 제거 |
| `CustomExercise` | metValue 0.9-30.0 clamping, name 100자 제한 | CloudKit 전파 방지 |
| `WorkoutWriteService` | HealthKit authorization check | 권한 없을 때 silent failure 방지 |

### Changes Made (P2 — Important, 주요)

| File | Change | Reason |
|------|--------|--------|
| `ExerciseHistoryViewModel` | Volume 계산에 `w <= 500, r <= 1000` 바운드 + NaN guard | overflow 방어 |
| `ActivityView` | `.onChange(of: recentRecords)` → `.onChange(of: recentRecords.count)` | 불필요한 recomputation 감소 |
| `WatchConnectivityManager` (Watch) | cached `isReachable` → computed `WCSession.default.isReachable` | stale state 방지 |
| `UserCategoryManagementView` | name 50자 제한 + trim | CloudKit 전파 방지 |
| `WorkoutTemplate` | name 100자, sets 1-20, reps 1-100, weight 0-500 | 입력값 범위 검증 |
| `OneRMEstimationService` | single-pass `analyze()` + pow() guard | 2-pass → 1-pass 최적화 + NaN 방어 |

### Changes Made (P3 — Minor)

| File | Change | Reason |
|------|--------|--------|
| `SetType.shortLabel` | private extension → shared `ExerciseCategory+View.swift` | DRY 원칙 |
| `WeightUnit.storageKey` | Domain → `WeightUnit+View.swift` (Presentation) | Layer boundary 준수 |
| `CompoundWorkoutMode+View.swift` (NEW) | `displayName` extension | rawValue UI 노출 금지 |
| `CompoundWorkoutView` | `config.mode.displayName` 사용 | hardcoded string 제거 |

### Key Code

**isSaving didFinishSaving 패턴:**
```swift
// ViewModel
func createValidatedRecord(weightUnit: WeightUnit) -> ExerciseRecord? {
    guard !isSaving else { return nil }
    isSaving = true
    // ... validation + record creation ...
    // Caller (View) must call didFinishSaving() after insert
    return record
}

func didFinishSaving() {
    isSaving = false
}

// View
if let record = viewModel.createValidatedRecord(weightUnit: weightUnit) {
    modelContext.insert(record)
    viewModel.didFinishSaving()  // Reset AFTER insert
}
```

**cancel-before-spawn 패턴:**
```swift
private var messageHandlerTask: Task<Void, Never>?

nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    let messageCopy = message.compactMapValues { $0 as? Data }
    Task { @MainActor in
        messageHandlerTask?.cancel()
        messageHandlerTask = Task { @MainActor in
            handleDecodedMessage(messageCopy)
        }
    }
}
```

**weeklyMuscleVolume 공통 함수 + Protocol:**
```swift
protocol ExerciseRecordVolumeProviding {
    var volumeDate: Date { get }
    var volumeSetCount: Int { get }
    var volumePrimaryMuscles: [MuscleGroup] { get }
    var volumeSecondaryMuscles: [MuscleGroup] { get }
}

extension Collection where Element: ExerciseRecordVolumeProviding {
    func weeklyMuscleVolume(from date: Date = Date(), days: Int = 7) -> [MuscleGroup: Int] {
        // Single implementation used by MuscleMapSummaryCard, MuscleMapView, VolumeAnalysisView
    }
}
```

## Prevention

### Checklist Addition

- [ ] `isSaving` flag 리셋은 반드시 View에서 insert 완료 후 `didFinishSaving()` 호출
- [ ] Task 취소 후 state update 전 `guard !Task.isCancelled` 확인
- [ ] WCSession delegate에서 새 Task 시작 전 이전 Task cancel
- [ ] 동일 계산이 3곳+ 중복되면 즉시 Protocol + Extension으로 추출
- [ ] Domain layer에 HealthKit/SwiftUI/SwiftData import 절대 금지
- [ ] Watch → iPhone 데이터는 반드시 `validated()` 패턴으로 필터링

### Rule Addition

기존 `.claude/rules/` 에 반영된 사항:
- `swift-layer-boundaries.md`: Domain import 제한 (이미 존재)
- `input-validation.md`: HealthKit 값 범위 검증 (이미 존재)
- `healthkit-patterns.md`: 쿼리 병렬화 (이미 존재)

추가 고려 규칙:
- **isSaving 패턴 규칙**: View-ViewModel 간 저장 플래그 관리 방법을 `.claude/rules/` 에 명문화 권장

## Lessons Learned

1. **대규모 변경(60+ files)에서는 cross-cutting concern이 누적됨**: 파일 단위 구현이 끝나면 반드시 6-관점 리뷰로 전체적 정합성 검증 필요
2. **isSaving 조기 리셋은 데이터 중복의 주 원인**: record를 반환하는 함수에서 `defer { isSaving = false }`는 위험. 반환값이 caller에게 전달된 뒤 insert 전에 flag가 리셋됨
3. **DRY 위반은 3곳에서 동시에 발생**: weekly volume 계산이 MuscleMapSummaryCard, MuscleMapView, VolumeAnalysisView에서 각각 독립 구현됨. Protocol + Collection Extension으로 한 번에 해결
4. **Trust boundary에서 검증 누락은 보안 리뷰에서만 발견됨**: Watch 데이터 검증은 기능 구현 시 자연스럽게 빠지는 항목. 리뷰어별 전문 관점이 효과적
5. **`guard !records.isEmpty` 같은 방어 코드도 테스트와 비즈니스 로직을 고려해야 함**: 빈 records는 첫 사용자에게 유효한 시나리오 (모든 근육이 "회복됨"). 테스트가 이를 잡아냄
6. **`Swift.max()` 같은 이름 충돌**: Collection extension 내에서 `max()` 호출 시 instance method와 충돌 가능. `Swift.max()` 로 명시적 모듈 지정 필요
