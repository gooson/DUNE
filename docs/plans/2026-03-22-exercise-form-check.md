---
topic: exercise-form-check
date: 2026-03-22
status: draft
confidence: high
related_solutions:
  - docs/solutions/architecture/2026-03-16-realtime-dual-pipeline-posture.md
  - docs/solutions/performance/2026-03-16-cvpixelbuffer-pool-starvation-fix.md
related_brainstorms:
  - docs/brainstorms/2026-03-16-realtime-video-posture-analysis.md
---

# Implementation Plan: 운동 폼 판정 (Phase 4B)

## Context

Phase 4A에서 듀얼 파이프라인(2D 연속 + 3D 주기적) 기반 실시간 자세 분석이 구축됨.
현재는 일상 자세 점수(어깨 비대칭, 허리 기울기 등)만 실시간 표시.
Phase 4B는 **특정 운동을 선택하면 해당 운동의 폼 체크포인트를 실시간 판정**하는 기능을 추가한다.

## Requirements

### Functional

- 운동 선택 → 폼 체크 모드 진입 (Squat, Deadlift, Overhead Press)
- 운동 phase 자동 감지 (하강/최저점/상승)
- 체크포인트별 pass/caution/fail 실시간 표시
- 렙 자동 카운트
- 기존 일상 자세 모드와 운동 폼 모드 간 전환

### Non-functional

- Domain layer에 Vision/UI 의존 없음 (순수 기하학 연산)
- 2D keypoints 기반 동작 (3D는 보정용, 필수 아님)
- 기존 `RealtimePoseTracker` 파이프라인 재사용 (새 파이프라인 금지)
- 운동 규칙 추가가 용이한 구조 (새 운동 = 새 규칙 데이터만 추가)

## Approach

`RealtimePoseTracker`의 `handleFrame`에서 2D keypoints를 받는 기존 흐름에 **ExerciseFormAnalyzer** 훅을 추가.
운동별 규칙은 데이터 구조체로 정의하고, Analyzer가 시계열 각도 데이터를 활용해 phase 감지 + 체크포인트 판정을 수행.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| Tracker 내부에 form logic 직접 삽입 | 간단 | Tracker가 비대해짐, 테스트 어려움 | Rejected |
| 별도 FormTracker 클래스 신설 | 완전 분리 | 카메라 파이프라인 중복 | Rejected |
| **Analyzer를 Tracker에 주입** | 관심사 분리, 테스트 용이, 기존 파이프라인 재사용 | Tracker에 optional dependency 추가 | **Selected** |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `Domain/Models/ExerciseFormRule.swift` | New | 운동별 폼 규칙 모델 (체크포인트, phase 정의, 각도 범위) |
| `Domain/Models/ExerciseFormState.swift` | New | 실시간 폼 판정 상태 (phase, 체크포인트 결과, 렙 카운트) |
| `Domain/Services/ExerciseFormAnalyzer.swift` | New | 시계열 각도 → phase 감지 + 체크포인트 판정 (순수 기하학) |
| `Domain/Models/RealtimePoseState.swift` | Modify | `formState: ExerciseFormState?` 추가 |
| `Data/Services/RealtimePoseTracker.swift` | Modify | `formAnalyzer` optional 주입, handleFrame에서 호출 |
| `Presentation/Posture/RealtimePostureViewModel.swift` | Modify | 운동 선택, 폼 모드 상태, formState 바인딩 |
| `Presentation/Posture/RealtimePostureView.swift` | Modify | 운동 선택 UI, 폼 체크 오버레이 |
| `Presentation/Posture/Components/FormCheckOverlay.swift` | New | 체크포인트별 pass/caution/fail 실시간 표시 |
| `Presentation/Posture/Components/ExercisePickerSheet.swift` | New | 폼 체크 운동 선택 sheet |
| `DUNETests/ExerciseFormAnalyzerTests.swift` | New | Analyzer 유닛 테스트 |

## Implementation Steps

### Step 1: Domain Models — ExerciseFormRule & ExerciseFormState

- **Files**: `Domain/Models/ExerciseFormRule.swift`, `Domain/Models/ExerciseFormState.swift`
- **Changes**:
  - `ExerciseFormRule`: 운동 ID, phase 정의(하강/최저점/상승), 체크포인트별 각도 범위
  - `FormCheckpoint`: 관절 triplet(a, vertex, c) + pass/caution/fail 각도 범위
  - `ExercisePhase`: enum (setup, descent, bottom, ascent, lockout)
  - `ExerciseFormState`: 현재 phase, 체크포인트 결과, 렙 카운트, 누적 점수
  - 초기 3개 운동(barbell-squat, conventional-deadlift, overhead-press) 규칙을 static 정의
- **Verification**: 컴파일 성공, 모델 instantiation 테스트

### Step 2: Domain Service — ExerciseFormAnalyzer

- **Files**: `Domain/Services/ExerciseFormAnalyzer.swift`
- **Changes**:
  - `processFrame(keypoints:)` → 2D keypoints에서 체크포인트별 각도 계산
  - Phase 감지: primary angle(예: squat의 knee angle)의 시계열 변화 추적
    - 연속 N프레임(5) 동일 방향 → phase 전환 (debounce)
  - 체크포인트 판정: 각 phase에서 활성인 체크포인트만 평가
  - 렙 카운트: descent→bottom→ascent→lockout 완전 사이클 = 1 rep
  - 순수 Foundation/simd, Vision/UI import 금지
- **Verification**: 유닛 테스트에서 mock keypoints로 phase 전환/렙 카운트 검증

### Step 3: Tracker Integration

- **Files**: `Data/Services/RealtimePoseTracker.swift`, `Domain/Models/RealtimePoseState.swift`
- **Changes**:
  - `RealtimePoseState`에 `formState: ExerciseFormState?` 추가
  - `RealtimePoseTracker`에 `var formAnalyzer: ExerciseFormAnalyzer?` 추가
  - `handleFrame`에서 keypoints가 유효하면 `formAnalyzer?.processFrame(keypoints:)` 호출
  - formAnalyzer의 state를 `RealtimePoseState.formState`에 반영
  - `setExercise(_ rule: ExerciseFormRule?)` 메서드: analyzer 생성/해제
- **Verification**: 기존 일상 자세 모드가 formAnalyzer=nil일 때 동일하게 동작

### Step 4: ViewModel & Exercise Selection

- **Files**: `Presentation/Posture/RealtimePostureViewModel.swift`
- **Changes**:
  - `selectedExercise: ExerciseFormRule?` 추가
  - `formState: ExerciseFormState?` 추가 (tracker state에서 전달)
  - `selectExercise(_ rule: ExerciseFormRule?)`: tracker에 전달
  - `isFormMode: Bool` computed (selectedExercise != nil)
  - `applyState()`에서 formState 동기화
- **Verification**: 운동 선택/해제 시 모드 전환 확인

### Step 5: UI — ExercisePickerSheet & FormCheckOverlay

- **Files**: `Presentation/Posture/Components/ExercisePickerSheet.swift`, `Presentation/Posture/Components/FormCheckOverlay.swift`, `Presentation/Posture/RealtimePostureView.swift`
- **Changes**:
  - `ExercisePickerSheet`: 3개 운동 선택, 현재 선택 표시, 해제(일상 모드) 옵션
  - `FormCheckOverlay`: 체크포인트별 pass/caution/fail 표시, 렙 카운트, phase indicator
  - `RealtimePostureView`: 운동 선택 버튼 추가, 폼 모드일 때 FormCheckOverlay 표시
  - 폼 모드에서도 기존 스켈레톤/각도 오버레이 유지
- **Verification**: 운동 선택 → 폼 오버레이 표시, 해제 → 일상 모드 복귀

### Step 6: Unit Tests

- **Files**: `DUNETests/ExerciseFormAnalyzerTests.swift`
- **Changes**:
  - Squat phase 감지 (standing→descent→bottom→ascent→lockout)
  - 체크포인트 판정 (pass/caution/fail 각도 범위)
  - 렙 카운트 정확성
  - Edge: 급격한 각도 변화(노이즈) → debounce로 오판 방지
  - Edge: 부분 keypoints(일부 관절 미감지) → graceful skip
- **Verification**: 모든 테스트 pass

### Step 7: Localization

- **Files**: `Shared/Resources/Localizable.xcstrings`
- **Changes**:
  - 운동 이름은 번역 면제 (국제 표준 영어)
  - 체크포인트 레이블, phase 이름, UI 문구 en/ko/ja 추가
- **Verification**: 누락 없이 3개 언어 등록

## Edge Cases

| Case | Handling |
|------|----------|
| 카메라에서 하반신만 보임 | 가용한 체크포인트만 평가, 나머지 "unmeasurable" |
| 프레임 드롭으로 급격한 각도 변화 | 5프레임 연속 확인으로 debounce |
| 운동 중 사람 일시 미감지 | 마지막 유효 state 유지 (기존 0.3s timeout) |
| 잘못된 운동 선택 (데드리프트 중인데 스쿼트 선택) | 사용자 책임, 체크포인트 fail이 자연스럽게 표시 |
| 폼 체크 중 카메라 전환 | formAnalyzer 상태 리셋 (새 시점에서 다시 시작) |

## Testing Strategy

- **Unit tests**: ExerciseFormAnalyzer — mock keypoints 시퀀스로 phase/rep/checkpoint 검증
- **Manual verification**: 시뮬레이터에서 카메라 불가 → 실기기에서 스쿼트 동작 촬영하며 폼 판정 확인
- **기존 테스트 회귀**: PostureAnalysisServiceTests, PostureCaptureServiceTests 통과 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 2D keypoints로 depth 없이 정확한 폼 판정 어려움 | Medium | Medium | 3D 보정 활용, 체크포인트 threshold을 보수적으로 설정 |
| Phase 감지 오판 (노이즈) | Medium | Low | 5프레임 debounce + hysteresis |
| Tracker 성능 영향 | Low | Medium | formAnalyzer는 순수 수학 연산, O(1) per frame |
| 카메라 시점에 따른 각도 오차 | Medium | Medium | 측면 촬영 권장 가이드 제공, 정면/측면 규칙 분리 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 기존 듀얼 파이프라인 인프라가 안정적이고, 추가하는 것은 순수 기하학 연산 레이어. Domain 모델 + Analyzer + UI overlay 3개 레이어로 명확히 분리되어 있어 리스크가 낮음.
