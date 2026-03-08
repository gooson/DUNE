---
tags: [review-followup, post-merge, activity, wellness, muscle-map, recommendation, ui-test]
category: general
date: 2026-03-09
severity: important
related_files:
  - DUNE/Presentation/Activity/ActivityView.swift
  - DUNE/Presentation/Exercise/TemplateExerciseResolver.swift
  - DUNE/Presentation/Shared/Components/MuscleMap3DScene.swift
  - DUNE/Presentation/Wellness/WellnessView.swift
  - DUNE/Presentation/Wellness/WellnessViewModel.swift
  - DUNETests/ActivityViewModelTests.swift
  - DUNETests/TemplateExerciseResolverTests.swift
  - DUNETests/WellnessViewModelTests.swift
  - DUNEUITests/Full/ActivityMuscleMapRegressionTests.swift
  - DUNEWatchUITests/Smoke/WatchHomeSmokeTests.swift
related_solutions:
  - docs/solutions/general/2026-03-07-post-merge-review-fix-pipeline.md
  - docs/solutions/performance/2026-03-09-realitykit-material-cache-guard.md
---

# Solution: PR Review Comment Follow-ups

## Problem

머지된 PR의 review comment가 현재 `main`에도 남아 있었는데, open PR만 보는 흐름으로는 이 후속 수정 누락을 잡기 어려웠다.

### Symptoms

- seeded watch smoke가 optional `Recent` section을 필수 surface처럼 가정했다.
- muscle map 3D 진입 테스트가 좌표 탭에 의존해 간헐적으로 실패했다.
- recommendation sequence가 일부 unresolved step을 조용히 drop했다.
- Activity/Wellness의 파생 상태가 edit-in-place 변경을 놓쳤다.
- RealityKit muscle/shell cache가 geometry 준비 전에 먼저 굳을 수 있었다.

### Root Cause

review comment triage를 current `main` 기준으로 다시 확인하는 절차가 없었고, change trigger도 count/newest record 같은 얕은 signal에만 의존하고 있었다.

## Solution

최근 merged PR review thread를 다시 수집해 stale after fix와 open follow-up을 분리한 뒤, open 항목만 한 배치로 반영했다. 구현 후에는 diff를 다시 읽어 `completedSets` 편집이 fingerprint에서 빠진 경로까지 추가로 보강했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNEWatchUITests/Smoke/WatchHomeSmokeTests.swift` | quick start list와 seeded row만 확인 | optional Recent section 가정 제거 |
| `DUNEUITests/Full/ActivityMuscleMapRegressionTests.swift` | muscle selector helper로 3D 진입 | 좌표 탭 flakes 제거 |
| `DUNE/Presentation/Exercise/TemplateExerciseResolver.swift` | unresolved sequence면 `nil` 반환, strength fallback 허용 | recommendation truncate 방지 |
| `DUNE/Presentation/Activity/ActivityView.swift` | records/injury trigger 보강, weekly report 재생성 추가 | edit-in-place도 파생 상태 재계산 |
| `DUNE/Presentation/Wellness/WellnessView*.swift` | sleep prediction recompute를 load 완료 시점으로 이동 | stale prediction 제거 |
| `DUNE/Presentation/Shared/Components/MuscleMap3DScene.swift` | geometry/shell 준비 전 cache write 차단 | preload cache 오염 방지 |
| `DUNETests/*.swift` | resolver, wellness, activity fingerprint 회귀 테스트 추가 | 후속 review fix 재발 방지 |

### Key Code

```swift
enum ActivityRecordChangeFingerprint {
    static func make(from records: [ExerciseRecord]) -> Int {
        var hasher = Hasher()
        for record in records {
            hasher.combine(record.id)
            hasher.combine(record.date)
            for set in record.completedSets {
                hasher.combine(set.id)
                hasher.combine(set.reps)
                hasher.combine(set.weight)
            }
        }
        return hasher.finalize()
    }
}
```

## Prevention

merged PR comment follow-up은 "이미 머지됐으니 끝"으로 닫지 말고, current `main` 기준으로 stale/open을 다시 분류해야 한다. 특히 Activity/Wellness처럼 파생 상태가 많은 화면은 record count만이 아니라 실제 계산 입력 전체가 trigger에 반영돼야 한다.

### Checklist Addition

- [ ] post-merge review fix에서 derived-state trigger가 관계 데이터(`completedSets`, active injury fields)까지 포함하는지 확인한다.
- [ ] UI regression test가 좌표 탭 대신 AXID selector를 사용하는지 확인한다.
- [ ] preload/cache 방어 수정은 "준비 전 write 금지"까지 같이 점검한다.

### Rule Addition (if applicable)

새 규칙 추가까지는 필요하지 않다. 현재 `.claude/rules/testing-required.md`와 review pipeline만으로 재발 방지가 가능하다.

## Lessons Learned

review comment를 한 번에 일괄 반영할 때는 처음 triage된 항목만 믿지 말고, 수정 후 diff를 다시 읽어 "이번 fix가 놓친 같은 계열 입력"을 한 번 더 찾는 편이 안전하다. 이번 배치에서는 `completedSets`가 바로 그런 누락 경로였다.
