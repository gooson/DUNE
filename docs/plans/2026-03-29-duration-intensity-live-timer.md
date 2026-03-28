---
tags: [watch, ios, durationIntensity, plank, timer, ux]
date: 2026-03-29
category: plan
status: draft
---

# durationIntensity 운동 세트별 라이브 타이머

## Problem

플랭크 등 `durationIntensity` 운동이 수동 "분" 입력 UI를 사용 중.
사용자가 ±1 버튼으로 분을 입력하는 방식은 부자연스러움.
실제 사용: 플랭크 시작 → 홀드 → 끝나면 탭 → 시간 자동 기록.

## Scope

- strength flow(세트 구조)는 유지
- CardioSession(러닝 플로우) 사용하지 않음
- 수동 분 입력 → **세트별 카운트업 타이머**로 교체
- iOS + Watch 동시 적용

## Design

### UX 플로우

```
세트 시작 → 타이머 자동 시작 (0:00 카운트업)
          → 홀드 중 (0:01, 0:02, ... 실시간 표시)
          → "세트 완료" 탭
          → 경과 시간을 해당 세트 duration으로 기록
          → 휴식 타이머 → 다음 세트 (타이머 리셋)
```

### 타이머 표시 형식

- **MM:SS** (예: `1:30`)
- 큰 글씨, 모노스페이스
- "세트 완료" 버튼 아래에 위치 (기존 ±1 버튼 영역 대체)

### 수동 편집 불필요

타이머가 자동 기록하므로 SetInputSheet의 duration 수동 편집 삭제.
"세트 완료" 시 경과 시간이 곧 duration.

## Affected Files

### Watch

| 파일 | 변경 | 설명 |
|------|------|------|
| `DUNEWatch/Views/MetricsView.swift` | 수정 | `durationInputCardContent` → 라이브 타이머 표시, `completeSet()` → 경과 시간 사용 |
| `DUNEWatch/Views/SetInputSheet.swift` | 수정 | `durationContent` 제거 (수동 입력 불필요) |

### iOS

| 파일 | 변경 | 설명 |
|------|------|------|
| `DUNE/Presentation/Exercise/WorkoutSessionView.swift` | 수정 | `durationIntensityInput()` → 라이브 타이머 표시 |
| `DUNE/Presentation/Exercise/WorkoutSessionViewModel.swift` | 수정 | 세트별 타이머 상태 추가, `completeSet` 시 경과 시간 기록 |

## Implementation Steps

### Step 1: Watch MetricsView 타이머 추가

1. `@State private var setStartDate: Date? = nil` 추가
2. `durationInputCardContent` 교체:
   - 세트 진입 시 `setStartDate = Date()` 설정
   - `TimelineView(.periodic(from: .now, by: 1))` 로 매초 갱신
   - `MM:SS` 형식으로 경과 시간 표시
3. `completeSet()` 의 durationIntensity 분기 수정:
   - `guard let start = setStartDate` 로 시작 시간 확인
   - `let elapsed = Date().timeIntervalSince(start)`
   - `Int(elapsed)` 를 초 단위로 `workoutManager.completeSet(duration:)` 에 전달
   - `setStartDate = nil` 리셋
4. `prefillFromEntry()` 의 durationIntensity 분기에서 `setStartDate = Date()` 설정

### Step 2: Watch SetInputSheet duration 제거

1. `durationContent` 분기를 타이머 안내 텍스트로 대체 (또는 해당 inputType일 때 sheet 자체를 표시하지 않음)
2. `durationMinutes`, `crownDurationDouble` 바인딩 정리

### Step 3: iOS WorkoutSessionView 타이머 추가

1. ViewModel에 `@Published var setStartDate: Date?` 추가
2. `durationIntensityInput()` 교체:
   - `TimelineView` 로 매초 갱신되는 카운트업 타이머 표시
   - MINUTES 라벨 + ±1 버튼 제거
3. 세트 시작 시 (세트 화면 진입) `setStartDate = Date()` 설정

### Step 4: iOS ViewModel completeSet 수정

1. durationIntensity 분기에서 `setStartDate` → 경과 시간 계산
2. `EditableSet.duration`에 경과 초를 분으로 변환하여 저장 (기존 데이터 흐름 유지)
3. `setStartDate = nil` 리셋

## Edge Cases

- 세트 중간에 앱 백그라운드 → `Date()` 기반이므로 정확함
- 0초에 즉시 "세트 완료" → 최소 1초 guard
- Watch에서 세트 진입 시 SetInputSheet 표시 → durationIntensity이면 skip

## 테스트 전략

- Watch UI 테스트: 플랭크 세트 완료 flow 캡처
- iOS 시뮬레이터: 플랭크 타이머 표시 캡처
- 기존 setsRepsWeight/setsReps 운동은 영향 없음 확인
