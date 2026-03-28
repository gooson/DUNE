---
tags: [exercise, consolidation, migration, dedup, json]
date: 2026-03-29
category: plan
status: draft
---

# Plan: 운동 변형(Variant) 통합 — JSON 제거 + 기록 마이그레이션

## Problem Statement

운동 라이브러리에 동일 본운동의 변형(tempo, paused, volume, unilateral, EMOM, AMRAP, ladder, mobility-flow, static-hold, recovery-flow, endurance, intervals, recovery)이 개별 JSON 엔트리로 존재하여:
- 총 529개 운동 중 392개가 변형 → 137개가 실제 고유 운동
- 기존 canonical dedup이 일부(tempo, paused, endurance, intervals, recovery)만 커버
- volume, unilateral, EMOM, AMRAP, ladder, mobility-flow, static-hold은 dedup 미대상
- 기존 ExerciseRecord/ExerciseDefaultRecord가 변형 ID를 참조 중 → 통합 필요

## Scope

### 제거 대상: suffix 기반 변형 (392개)

| Suffix | 설명 | 대상 수 |
|--------|------|---------|
| `-tempo` | 템포 | ~80 |
| `-paused` | 일시정지 | ~80 |
| `-unilateral` | 싱글암/레그 | ~80 |
| `-volume` | 볼륨 | ~50 |
| `-endurance` | 지구력 세트 | ~50 |
| `-emom` | EMOM | ~10 |
| `-amrap` | AMRAP | ~10 |
| `-ladder` | 래더 | ~10 |
| `-intervals` | 인터벌 | ~5 |
| `-recovery` | 회복 | ~5 |
| `-recovery-flow` | 회복 플로우 | ~5 |
| `-mobility-flow` | 모빌리티 플로우 | ~5 |
| `-static-hold` | 정적 홀드 | ~5 |

### 제거 대상: standalone single-leg/single-arm (4개)

| 변형 ID | → 통합 대상 |
|---------|------------|
| `single-leg-press-machine` | `leg-press` |
| `single-leg-extension-machine` | `leg-extension` |
| `single-leg-curl-machine` | `leg-curl` |
| `single-arm-shoulder-press-machine` | `shoulder-press-machine` |

### 유지: `single-leg-deadlift`

독립 운동으로 유지 (non-single-leg equivalent 없음). 단, 그 변형들(-tempo, -paused, -unilateral, -endurance)은 제거.

## Affected Files

| File | Change | Risk |
|------|--------|------|
| `DUNE/Data/Resources/exercises.json` | 392+4 엔트리 제거, 기존 base에 aliases 추가 | High — 핵심 데이터 |
| `DUNE/Data/ExerciseLibraryService.swift` | legacyIDMapping 추가, canonical index 단순화 | Medium |
| `DUNE/Domain/UseCases/QuickStartPopularityService.swift` | canonicalSuffix에 volume/unilateral/emom/amrap/ladder/mobility-flow/static-hold 추가 | Low |
| `DUNE/Domain/Protocols/ExerciseLibraryQuerying.swift` | 변경 없음 (representativeExercise 유지) | None |
| `DUNE/App/DUNEApp.swift` | 마이그레이션 호출 추가 | Low |
| `DUNE/Data/ExerciseLibraryService.swift` | `migrateRecords(in:)` 메서드 추가 | Medium |
| `DUNEWatch/Managers/RecentExerciseTracker.swift` | canonical suffix 동기화 | Low |
| `DUNETests/ExerciseDefinitionTests.swift` | 테스트 업데이트 | Low |

## Implementation Steps

### Step 1: exercises.json 정리 (Python 스크립트)

1. 모든 suffix 기반 변형 엔트리 제거
2. 4개 standalone single-leg/single-arm 엔트리 제거
3. 제거된 변형의 name/localizedName을 base exercise의 aliases에 추가
4. 결과: ~137개 고유 운동만 남음

### Step 2: QuickStartCanonicalService suffix 확장

기존 canonical suffix에 누락된 패턴 추가:
- `-volume`, `-unilateral`
- `-emom`, `-amrap`, `-ladder`
- `-mobility-flow`, `-static-hold`
- 한국어 name suffix도 추가: ` 볼륨`, ` 앰랩`, ` 래더`, ` 이몸` 등

### Step 3: ExerciseLibraryService — legacyIDMapping

```swift
static let legacyIDMapping: [String: String]
```

제거된 396개 변형 ID → base exercise ID 매핑. `exercise(byID:)`에서 fallback으로 사용.

### Step 4: 기록 마이그레이션

`ExerciseLibraryService.migrateRecords(in:)`:
1. ExerciseRecord.exerciseDefinitionID가 legacyIDMapping에 있으면 → base ID로 업데이트
2. ExerciseDefaultRecord.exerciseDefinitionID도 동일 처리
3. WorkoutTemplate의 TemplateExercise.exerciseDefinitionID도 동일 처리

### Step 5: 앱 시작 시 마이그레이션 호출

DUNEApp.init 또는 ContentView.task에서 one-time migration 실행.

### Step 6: canonical index 단순화

변형이 JSON에서 제거되었으므로 canonical index 빌드 로직이 자연히 단순해짐. buildCanonicalIndex는 유지하되 매칭할 변형이 대폭 줄어듦.

### Step 7: Watch canonical suffix 동기화

RecentExerciseTracker에 Step 2와 동일한 suffix 추가.

### Step 8: 테스트 업데이트

- ExerciseDefinitionTests: allExercises count 업데이트, variant lookup 테스트
- legacyIDMapping 테스트: 제거된 ID → base ID 매핑 확인
- Migration 테스트: 모의 record migration 검증

## Test Strategy

1. **Unit test**: legacyIDMapping이 모든 제거된 ID를 커버하는지 검증
2. **Unit test**: `exercise(byID: "push-up-tempo")` → fallback으로 `push-up` 반환
3. **Unit test**: migration 후 ExerciseRecord.exerciseDefinitionID가 base ID인지 확인
4. **Build test**: `scripts/build-ios.sh` 통과
5. **Manual**: 앱 실행 후 운동 목록에서 변형이 사라졌는지 확인

## Risks & Edge Cases

| Risk | Mitigation |
|------|-----------|
| 기존 기록이 변형 ID를 참조 | legacyIDMapping fallback + runtime migration |
| CloudKit sync로 다른 기기에서 변형 ID가 돌아옴 | 매 launch마다 migration 체크 (idempotent) |
| Watch에서 변형 ID로 기록 | Watch canonical suffix 동기화 |
| WorkoutTemplate이 변형 ID 참조 | 템플릿도 migration 대상 포함 |
| Custom exercise가 제거된 ID와 충돌 | custom exercise는 별도 네임스페이스 (UUID 기반) |
