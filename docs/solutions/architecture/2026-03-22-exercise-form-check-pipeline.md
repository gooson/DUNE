---
tags: [posture, exercise-form, realtime, phase-detection, rep-counting, dual-pipeline]
date: 2026-03-22
category: solution
status: implemented
---

# Exercise Form Check Pipeline (Phase 4B)

## Problem

Phase 4A 듀얼 파이프라인은 일상 자세 점수만 실시간 표시. 운동 중 특정 폼 체크포인트(스쿼트 깊이, 데드리프트 허리 각도 등)를 판정하는 기능이 없었다.

## Solution

기존 `RealtimePoseTracker` 파이프라인에 **ExerciseFormAnalyzer**를 optional dependency로 주입. 운동별 규칙 데이터를 선언적으로 정의하고, 2D keypoints에서 실시간 phase 감지 + checkpoint 판정 + 렙 카운트를 수행.

### Architecture

```
ExerciseFormRule (Domain/Models)
    └─ FormCheckpoint: jointA/vertex/c, passRange, cautionRange, activePhases
    └─ Phase thresholds: descent/bottom/lockout

ExerciseFormAnalyzer (Domain/Services)
    └─ processFrame(keypoints:) → ExerciseFormState
    └─ Phase detection with 5-frame debounce
    └─ Running sum/count scoring (no unbounded arrays)
    └─ keypointCache reuse (removeAll keepingCapacity)

RealtimePoseTracker (Data/Services)
    └─ formAnalyzer: ExerciseFormAnalyzer? (optional injection)
    └─ handleFrame → formAnalyzer?.processFrame()
    └─ state.formState = result

RealtimePostureView/ViewModel (Presentation)
    └─ ExercisePickerSheet: 운동 선택
    └─ FormCheckOverlay: 체크포인트 상태, phase, rep count
```

### Key Design Decisions

1. **Optional injection** (`setExercise(nil)` = 일상 모드): 기존 일상 자세 모드에 영향 없음
2. **Running sum/count**: 초기 구현은 unbounded array + reduce였으나, 리뷰에서 P1 — 30fps 환경에서 O(N) 누적. Running sum 패턴으로 O(1) 교체
3. **keypointCache reuse**: `Dictionary(_, uniquingKeysWith:)`는 매 프레임 heap 할당. `removeAll(keepingCapacity: true)` + repopulate로 재사용
4. **checkpointsByName**: 초기 구현은 `.first { $0.name == ... }` O(C²). init-time pre-compute로 O(1)
5. **Phase detection**: primaryAngle 변화 방향을 5프레임 연속 확인(debounce). 노이즈에 의한 오판 방지
6. **Dead branch fix**: `.setup/.lockout` case에서 `currentPhase = .descent` 후 `if currentPhase == .lockout` 체크 — 항상 false. `let wasLockout` capture으로 수정

### Files

| Layer | File | Role |
|-------|------|------|
| Domain | `ExerciseFormRule.swift` | 운동별 규칙 데이터 (3개 built-in) |
| Domain | `ExerciseFormState.swift` | 실시간 상태 (phase, checkpoints, reps) |
| Domain | `ExerciseFormAnalyzer.swift` | 순수 기하학 분석 서비스 |
| Domain | `RealtimePoseState.swift` | `formState: ExerciseFormState?` 추가 |
| Data | `RealtimePoseTracker.swift` | analyzer optional 주입 |
| Presentation | `ExercisePickerSheet.swift` | 운동 선택 sheet |
| Presentation | `FormCheckOverlay.swift` | 실시간 폼 오버레이 |
| Presentation | `RealtimePostureView.swift` | 통합 UI |
| Presentation | `RealtimePostureViewModel.swift` | 폼 모드 상태 관리 |

## Prevention

### Hot-path 성능 패턴
- 30fps 호출 경로에서 `Dictionary(_, uniquingKeysWith:)` 금지 → `removeAll(keepingCapacity:)` 재사용
- 30fps 경로에서 unbounded array append + reduce 금지 → running sum/count
- 30fps 경로에서 O(N) lookup 금지 → init-time dictionary pre-compute
- SwiftUI body 내 Color switch 금지 → static enum 상수

### Phase 상태 머신 패턴
- 상태 변경 후 변경 전 값을 체크하면 dead branch → `let wasX = ...` 패턴으로 capture
- Phase 전환 debounce: 단일 프레임 기반 전환은 노이즈에 취약 → 연속 N프레임 확인

## Lessons Learned

1. 카메라 파이프라인에 추가하는 모든 연산은 "30fps에서 이 코드가 반복 실행된다"는 관점으로 리뷰해야 한다
2. 운동 규칙을 데이터 구조체로 선언적 정의하면 새 운동 추가가 static let 하나로 가능
3. Optional dependency injection으로 기존 모드에 영향 없이 새 기능을 추가할 수 있다
