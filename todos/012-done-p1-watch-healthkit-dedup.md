---
source: review/healthkit-dedup
priority: p1
status: done
created: 2026-02-18
updated: 2026-02-22
---

# Watch HealthKit Dedup 보완

## 배경

HealthKit dedup 리뷰에서 Watch 관련 3개 이슈 발견. 현재 dedup PR 범위 밖이므로 별도 작업으로 분리.

## 이슈

### C2: Watch 기록 healthKitWorkoutID 미설정
- Watch에서 생성한 ExerciseRecord는 `healthKitWorkoutID = nil`
- CloudKit 동기화 후 iPhone에서 dedup의 primaryFilter(healthKitWorkoutID match)가 실패
- bundleIdentifier fallback으로 커버되지만, Watch 앱의 bundleIdentifier가 다를 수 있음
- **수정 완료**:
  - `WorkoutManager`에 `isFinalizingWorkout` + `waitForWorkoutFinalization()` 추가
  - `SessionSummaryView.saveAndDismiss`에서 finalization 대기 후 `healthKitWorkoutID` 저장

### M4: Watch completeSet 범위 검증 없음
- reps/weight 입력에 min/max 범위 체크 없이 저장
- CloudKit 전파 위험
- **수정 완료**: `WorkoutManager.completeSet(weight:reps:)`에 범위 guard 적용 (`weight: 0...500`, `reps: 0...1000`)

### M5: Watch saveAndDismiss 상태 리셋 타이밍
- HealthKit write 완료 전에 state 리셋
- Correction Log #43 위반 (`isSaving` 리셋은 View에서 insert 완료 후)
- **수정 완료**:
  - `SessionSummaryView` 저장 버튼을 finalization 중 disable
  - HealthKit finalization 대기 -> SwiftData 저장 -> `workoutManager.reset()` 순서로 변경

## 영향 파일

- `DailveWatch/Managers/WorkoutManager.swift`
- `DailveWatch/Views/SessionSummaryView.swift`
