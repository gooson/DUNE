---
tags: [life-tab, auto-achievement, workout-card, ux-ui, swiftui, design-system]
category: architecture
date: 2026-03-04
severity: important
related_files:
  - DUNE/Presentation/Life/LifeView.swift
  - docs/plans/2026-03-04-life-tab-auto-workout-card-ux-ui.md
related_solutions:
  - docs/solutions/architecture/2026-03-04-life-tab-healthkit-auto-achievements.md
  - docs/solutions/architecture/2026-02-28-habit-tab-implementation-patterns.md
---

# Solution: Life 탭 자동 운동 카드 통합 UX/UI

## Problem

Life 탭의 `Auto Workout Achievements`가 rule 단위 카드(9개)로 길게 나열되어, 루틴 사용자가 핵심 질문(루틴을 지켰는지)을 빠르게 확인하기 어려웠다.

### Symptoms

- 카드 개수가 많아 스캔 비용이 큼
- 유사 목표(운동 횟수/근력/부위별)가 분리되어 정보가 파편화됨
- iPad 폭에서 카드가 과도하게 넓어져 밀도가 떨어짐

### Root Cause

- 도메인 규칙 출력(개별 rule)을 UI에서 1:1 카드로 그대로 렌더링함
- 표시 계층에 통합/축약 규칙이 없어 비슷한 유형이 분산됨
- 폭 제한/그리드 레이아웃이 없어 Regular width에서 시각적 응집력이 낮음

## Solution

도메인 계산 로직은 유지하고, `LifeView`에서 출력만 통합해 루틴 중심 카드 구조로 재배치했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Life/LifeView.swift` | 자동 성취 섹션을 3개 통합 그룹 카드(루틴/근력/러닝)로 재구성 | 유사 목표 결합 + 카드 수 축소 |
| `DUNE/Presentation/Life/LifeView.swift` | 상단 완료 요약 배지(`done/total`) 추가 | 루틴 준수 상태를 즉시 인지 |
| `DUNE/Presentation/Life/LifeView.swift` | Regular width에서 `LazyVGrid` + `maxWidth` 적용 | 과도한 카드 너비 축소 |
| `DUNE/Presentation/Life/LifeView.swift` | 강도/부위 세부값 0인 항목을 조건부 숨김 | 불완전 데이터 과노출 방지 |
| `docs/plans/2026-03-04-life-tab-auto-workout-card-ux-ui.md` | 구현 계획 추가 | 변경 범위/검증 기준 기록 |

### Key Code

```swift
private var autoAchievementGroups: [AutoAchievementGroup] {
    [
        makeAutoGroup(id: "routine", title: "Routine Consistency", icon: "calendar.badge.clock", ruleIDs: ["weeklyWorkout5", "weeklyWorkout7"]),
        makeAutoGroup(id: "strength", title: "Strength Split", icon: "dumbbell.fill", ruleIDs: ["weeklyStrength3", "weeklyChest3", "weeklyBack3", "weeklyLowerBody3", "weeklyShoulders3", "weeklyArms3"]),
        makeAutoGroup(id: "running", title: "Running Distance", icon: "figure.run", ruleIDs: ["weeklyRunning15km"])
    ]
    .filter { !$0.metrics.isEmpty }
}
```

```swift
if isRegular {
    LazyVGrid(columns: [GridItem(.flexible(), spacing: DS.Spacing.md), GridItem(.flexible())], spacing: DS.Spacing.md) {
        ForEach(groups) { group in
            autoAchievementGroupCard(group)
        }
    }
}
```

## Prevention

### Checklist Addition

- [ ] 규칙 엔진 출력이 많은 경우 UI에서 도메인 rule을 그대로 1:1 카드로 노출하지 않는가?
- [ ] 사용자의 핵심 질문(예: 루틴 준수 여부)을 상단 요약으로 제공하는가?
- [ ] Regular width에서 카드 최대 폭/그리드 밀도를 검토했는가?
- [ ] 0값 세부 항목은 숨김/축약 정책을 적용했는가?

### Rule Addition (if applicable)

현재는 기존 디자인 시스템/레이어 규칙으로 충분하며, 신규 rule 파일 추가는 보류한다.

## Lessons Learned

- 자동 계산의 정확도와 별개로, 표시 계층의 정보 구조가 UX 품질을 크게 좌우한다.
- 루틴 사용자 관점에서는 개별 규칙 나열보다 "통합 요약 + 핵심 그룹"이 탐색 비용을 줄인다.
- iPad/Regular 대응에서 폭 제한을 함께 설계하지 않으면 카드 UI는 쉽게 느슨해진다.
