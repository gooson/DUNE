---
tags: [rpe, exercise, workout-set, intensity, swiftdata, migration, picker]
date: 2026-03-12
category: architecture
status: implemented
---

# Per-Set RPE (Rate of Perceived Exertion) Integration

## Problem

운동 세션의 주관적 강도를 세션 레벨에서만 측정하고 있어, 세트별 난이도 변화를 추적할 수 없었다. RPE(자각적 운동 강도)를 세트 단위로 수집하여 더 정밀한 강도 분석이 필요했다.

## Solution

### Data Layer
- `WorkoutSet.rpe: Double?` 필드 추가 (V13 schema migration)
- `WatchSetData.rpe: Double?` DTO 필드 추가 (WatchConnectivity)
- Migration: `V12WorkoutSet` → `V13WorkoutSet` (addedColumns: .rpe)

### Domain Layer
- `RPELevel` struct: Modified Borg scale 6.0-10.0, 0.5 step
  - `validate(_:)`: 범위 검증 + 0.5 단위 snap
  - `displayLabel`: 카테고리명 (Light/Moderate/Hard/Very Hard/Max Effort)
  - `rir`: Reps In Reserve 매핑 (0-4)
- `WorkoutIntensityService.averageSetRPE(sets:)`: 세트별 RPE → 세션 effort (1-10) 변환
  - Warmup 세트 제외
  - 6.0-10.0 → 1-10 linear mapping

### Presentation Layer
- `SetRPEPickerView`: 9-button compact horizontal picker
- 3개 workout view에 통합: WorkoutSession / Template / Compound
- `ExerciseRecord+SetRPE.swift`: DRY helper (`applySetBasedRPE()`)
- `ExerciseSessionDetailView`: RPE badge 표시

### Key Pattern: applySetBasedRPE()

```swift
extension ExerciseRecord {
    func applySetBasedRPE(using service: WorkoutIntensityService = .init()) {
        let inputs = (sets ?? []).map {
            SetRPEInput(rpe: $0.rpe, setType: $0.setType)
        }
        if let effort = service.averageSetRPE(sets: inputs) {
            rpe = effort
        }
    }
}
```

이 패턴으로 3개 View에서 중복되던 5줄 블록을 1줄 호출로 통합.

## Prevention

- 3개 이상 View에서 동일 비즈니스 로직이 반복되면 즉시 Extension으로 추출
- `RPELevel.displayLabel`은 숫자가 아닌 카테고리명 반환 — 테스트 작성 시 실제 구현 확인 필수
- SwiftData schema 추가 시 V{N} migration + VersionedSchema.models 동기화 필수

## Lessons Learned

1. **테스트와 구현 불일치 조기 발견**: `displayLabel`이 "6"이 아닌 "Light"를 반환하는 것을 리뷰에서 발견. 테스트 작성 시 실제 구현을 먼저 읽어야 함.
2. **DRY 3-occurrence rule 유효**: 3개 View에 동일 패턴이 나타나자마자 추출하여 유지보수성 확보.
3. **Layer boundary 준수**: Domain의 `WorkoutIntensityService`가 Data의 `WorkoutSet`을 직접 참조할 수 없으므로, Presentation Extension에서 브릿지 역할 수행.
