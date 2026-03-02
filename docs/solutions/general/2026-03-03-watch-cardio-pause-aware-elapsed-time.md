---
tags: [watchos, cardio, pace, elapsed-time, pause]
category: general
date: 2026-03-03
status: implemented
severity: important
related_files:
  - DUNEWatch/Managers/WorkoutManager.swift
  - DUNEWatch/Views/CardioMetricsView.swift
  - DUNEWatchTests/WorkoutElapsedTimeTests.swift
---

# Solution: Watch Cardio Pause-Aware Elapsed Time

## Problem

watch cardio 세션에서 elapsed time과 pace 계산이 wall-clock 기준으로 동작해 pause 구간이 포함됐다.

### Symptoms

- pause 후 재개하면 pace가 실제보다 느리게 표시됨
- cardio 상단 타이머가 pause 중에도 증가함

### Root Cause

- `WorkoutManager.updatePace()`가 `Date() - startDate`를 직접 사용
- `CardioMetricsView.elapsedTime`도 동일하게 `startDate` 기반 계산
- pause lifecycle에서 누적 pause duration을 보존하지 않음

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `WorkoutManager.swift` | `pausedDuration`, `pauseStart`, `beginPause`, `endPause` 추가 | pause 구간 누적/종료 시점을 정확히 반영 |
| `WorkoutManager.swift` | `WorkoutElapsedTime.activeElapsedTime(...)` 도입 | pace/타이머가 동일 계산식을 사용하도록 단일 소스화 |
| `WorkoutManager.swift` | `updatePace()`를 active elapsed 기반으로 변경 | pause 포함 pace 왜곡 제거 |
| `CardioMetricsView.swift` | 타이머 표시를 `workoutManager.activeElapsedTime(at:)`로 변경 | UI elapsed와 내부 pace 계산 일치 |
| `WorkoutElapsedTimeTests.swift` | no-pause / paused / clamp-to-zero 테스트 추가 | 시간 계산 회귀 방지 |

### Key Code

```swift
enum WorkoutElapsedTime {
    static func activeElapsedTime(
        startDate: Date?,
        pausedDuration: TimeInterval,
        pauseStart: Date?,
        isPaused: Bool,
        now: Date
    ) -> TimeInterval {
        guard let startDate else { return 0 }
        var elapsed = now.timeIntervalSince(startDate) - pausedDuration
        if isPaused, let pauseStart {
            elapsed -= now.timeIntervalSince(pauseStart)
        }
        return Swift.max(elapsed, 0)
    }
}
```

## Prevention

### Checklist Addition

- [ ] workout elapsed/pace 계산은 wall-clock 직접 계산 대신 active elapsed 단일 함수 경유
- [ ] pause/resume/end 상태 전이에서 pause 누적값 확정(`endPause`) 처리
- [ ] UI 표시 시간과 도메인 계산 시간이 동일 helper를 사용하도록 유지

### Rule Addition (if applicable)

기존 `watch-navigation.md` / `testing-required.md` 범위 내에서 적용 가능하며 신규 rule 파일 추가는 필요 없음.

## Lessons Learned

- watchOS workout에서 pause time은 지표 정확도에 직접 영향을 주므로 상태 전이와 시간 계산을 분리하면 재발한다.
- 계산식을 helper로 단일화하면 UI와 도메인 로직의 drift를 줄일 수 있다.
