---
tags: [swiftui, shared-health-snapshot, wellness, readiness, regression, fallback-window, zero-fill, viewmodel-test]
category: architecture
date: 2026-02-24
severity: important
related_files:
  - Dailve/Presentation/Wellness/WellnessViewModel.swift
  - Dailve/Presentation/Activity/ActivityViewModel.swift
  - DailveTests/WellnessViewModelTests.swift
  - DailveTests/ActivityViewModelTests.swift
related_solutions:
  - docs/solutions/architecture/2026-02-23-today-tab-ux-unification.md
  - docs/solutions/general/2026-02-19-review-p1-p2-training-volume-fixes.md
---

# Solution: Shared snapshot 통합 후 Wellness/Readiness 회귀 정합 복구

## Problem

Shared Health Snapshot 기반으로 Wellness/Activity 데이터를 통합한 뒤, 기존 UX/도메인 계약과 어긋나는 회귀가 발생했다.

### Symptoms

- Wellness 수면 sparkline이 7일 고정 길이가 아니라 데이터 존재 일수만 표시됨
- Activity Training Load 계산에서 shared snapshot 경로 사용 시 RHR fallback window가 30일 기준과 달라짐
- WellnessViewModel의 shared snapshot 경로에 대한 전용 회귀 테스트가 없어 동일 이슈 재발 위험이 높음

### Root Cause

- `sleepDailyDurations.suffix(7)` 기반 매핑은 결측일을 채우지 않아 차트 길이 계약(항상 7포인트)을 보장하지 못함
- Training Load 경로에서 snapshot 주입 여부에 따라 RHR fallback 호출 조건이 달라져, 기존 "최근 30일 내 최신 RHR 사용" 동작이 약화됨
- 통합 리팩터링 후 테스트 포커스가 서비스/대시보드 쪽에 치우치며 Wellness snapshot 적용 경로 단위 테스트가 빠짐

## Solution

ViewModel 로직에서 기존 계약을 명시적으로 복원하고, 해당 계약을 잠그는 회귀 테스트를 추가했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `Dailve/Presentation/Wellness/WellnessViewModel.swift` | `applySharedSnapshot`에서 `buildSleepWeeklySeries(from:)` 사용, 7일 고정 + 결측일 0분 보간 | 수면 sparkline 길이 계약 복원 |
| `Dailve/Presentation/Activity/ActivityViewModel.swift` | `safeTrainingLoadFetch(snapshot:)`에서 snapshot에 유효 RHR가 없을 때 `fetchLatestRestingHeartRate(withinDays: 30)` fallback 강제 | 기존 Training Load 계산 기준(30일 fallback) 유지 |
| `DailveTests/WellnessViewModelTests.swift` | shared snapshot 수면 7포인트/zero-fill 테스트 + snapshot condition score 소스 테스트 추가 | Wellness snapshot 경로 회귀 방지 |
| `DailveTests/ActivityViewModelTests.swift` | shared snapshot 경로에서도 RHR 요청 window가 30일인지 검증하는 테스트 추가 | fallback window 계약 회귀 방지 |

### Key Code

```swift
// Wellness: 항상 최근 7일을 생성하고 결측일은 0으로 채움
private func buildSleepWeeklySeries(from snapshot: SharedHealthSnapshot) -> [DailySleep] {
    let calendar = Calendar.current
    let totalsByDay = snapshot.sleepDailyDurations.reduce(into: [Date: Double]()) { partialResult, item in
        partialResult[calendar.startOfDay(for: item.date)] = item.totalMinutes
    }

    return (0..<7).reversed().compactMap { dayOffset in
        guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: snapshot.fetchedAt) else {
            return nil
        }
        let day = calendar.startOfDay(for: date)
        return DailySleep(date: day, totalMinutes: totalsByDay[day] ?? 0)
    }
}
```

```swift
// Activity: snapshot 경로에서도 기존 30일 RHR fallback 유지
if let snapshot {
    if let effectiveRHR = snapshot.effectiveRHR?.value {
        restingHR = effectiveRHR
    } else {
        restingHR = try await hrvService.fetchLatestRestingHeartRate(withinDays: 30)?.value
    }
} else {
    restingHR = try await hrvService.fetchLatestRestingHeartRate(withinDays: 30)?.value
}
```

## Prevention

### Checklist Addition

- [ ] Shared snapshot 전환 시 기존 fallback window(일수 단위) 계약이 유지되는지 테스트로 고정한다.
- [ ] 차트 데이터는 "포인트 개수 계약(예: 7일)"을 명시하고 결측일 처리 정책(0-fill/null-skip)을 코드에 고정한다.
- [ ] 통합 리팩터링 후에는 각 탭 ViewModel의 snapshot 적용 경로 단위 테스트를 최소 1개 이상 추가한다.

### Rule Addition (if applicable)

신규 rule 파일은 추가하지 않았고, 이번 케이스는 테스트로 계약을 고정했다.

## Lessons Learned

- 통합 레이어(Shared Snapshot) 도입 시 성능/중복 제거보다 "기존 UX/도메인 계약 보존"을 먼저 테스트로 잠가야 회귀를 줄일 수 있다.
- fallback 정책은 값 자체만큼 "탐색 window"가 중요하며, 코드 분기별로 동일 정책을 강제해야 한다.
- 차트는 값 정확도뿐 아니라 시각적 길이/정렬 계약이 UX 신뢰도에 직접 영향을 준다.
