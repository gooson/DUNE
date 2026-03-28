---
tags: [exercise, consolidation, migration, dedup, json, canonical, variant]
date: 2026-03-29
category: general
status: implemented
severity: important
related_files:
  - DUNE/Data/Resources/exercises.json
  - DUNE/Data/ExerciseLibraryService.swift
  - DUNE/Data/Services/ExerciseVariantMigration.swift
  - DUNE/Domain/UseCases/QuickStartPopularityService.swift
  - DUNEWatch/Managers/RecentExerciseTracker.swift
related_solutions:
  - docs/solutions/general/2026-03-07-exercise-variant-canonical-dedup.md
---

# Solution: 운동 라이브러리 변형(Variant) 통합 — JSON 제거 + 기록 마이그레이션

## Problem

exercises.json에 동일 운동의 변형(tempo, paused, volume, unilateral, EMOM, AMRAP, ladder, mobility-flow, static-hold, recovery-flow 등)이 개별 엔트리로 존재하여 529개 중 396개가 변형이었다.

기존 canonical dedup 시스템이 일부 변형만 처리하여 volume, unilateral, EMOM, AMRAP, ladder, mobility-flow, static-hold 변형은 검색/목록에서 여전히 노출되었고, 기존 ExerciseRecord/ExerciseDefaultRecord/WorkoutTemplate이 변형 ID를 참조하고 있었다.

### Root Cause

운동 라이브러리 초기 설계에서 변형을 별도 exercise definition으로 모델링했으나, 실제 운동 기록에서 변형 구분이 불필요한 경우가 대부분이었다.

## Solution

### 1. exercises.json 정리 (529 → 133개)

- 13가지 suffix 패턴(-tempo, -paused, -volume, -unilateral, -emom, -amrap, -ladder, -endurance, -intervals, -recovery, -recovery-flow, -mobility-flow, -static-hold) 기반 변형 392개 제거
- standalone single-leg/single-arm 4개를 base 운동에 통합 (single-leg-press-machine → leg-press 등)
- 제거된 변형의 이름/한국어 이름을 base exercise의 aliases에 추가 (검색 호환성 유지)

### 2. ExerciseLibraryService — 동적 해결

```swift
static func resolvedExerciseID(for id: String) -> String {
    if let merged = standaloneMerges[id] { return merged }
    let canonical = QuickStartCanonicalService.canonicalExerciseID(for: id)
    return canonical.isEmpty ? id : canonical
}
```

`exercise(byID:)` fallback으로 제거된 변형 ID도 base exercise로 해결.

### 3. QuickStartCanonicalService suffix 확장

누락된 suffix 패턴 추가: `-volume`, `-unilateral`, `-emom`, `-amrap`, `-ladder`, `-mobility-flow`, `-static-hold`. Watch RecentExerciseTracker도 동기화.

### 4. 런타임 마이그레이션

`ExerciseVariantMigration.migrateIfNeeded(in:)`: 앱 시작 시 한 번 실행, UserDefaults 플래그로 재실행 방지. ExerciseRecord, ExerciseDefaultRecord, WorkoutTemplate의 exerciseDefinitionID를 base ID로 업데이트.

## Prevention

- 새 운동 추가 시 변형을 별도 JSON 엔트리로 만들지 않고 base exercise에 tags/aliases로 추가
- canonical suffix 세트 변경 시 iOS QuickStartCanonicalService와 Watch RecentExerciseTracker 동시 업데이트
- `ExerciseLibraryService.resolvedExerciseID(for:)`를 통해 레거시 ID 호환성 자동 유지

## Lessons Learned

- 데이터 모델의 과잉 세분화(396개 변형)는 검색/목록 UX 복잡도와 기록 마이그레이션 비용을 크게 높임
- 서비스 레이어의 동적 해결(suffix stripping)이 하드코딩된 매핑보다 유지보수에 유리함
- 런타임 마이그레이션에는 반드시 skip 플래그를 추가하여 매 launch마다의 전체 스캔을 방지
