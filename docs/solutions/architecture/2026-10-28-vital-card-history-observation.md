---
tags: [observation, equatable, sparkline, today, health-history]
category: architecture
date: 2026-10-28
severity: important
status: reviewed
related_files:
  - DUNE/Presentation/Shared/Models/VitalCardData.swift
  - DUNETests/DashboardViewModelTests.swift
related_solutions: []
---

# Solution: 과거 건강 기록 수정과 카드 갱신

## Problem

Today에 기존 HRV/RHR 수면 기록을 시각화하는 추세를 추가했다. 최신 측정값·날짜는 그대로이고 과거 값만 수정되면 데이터는 바뀌어도 그래프 갱신 알림이 생략될 수 있었다.

### Root Cause

`@Observable` ViewModel의 카드 배열은 `Equatable` 비교를 사용한다. `VitalCardData`의 사용자 정의 equality가 `sparklineData`를 제외하여 과거 기록만 다른 배열을 같다고 판단했다. 같은 조건을 재현한 Observation 축소 프로그램에서 변경 알림이 0회였다.

## Solution

| File | Change | Reason |
|---|---|---|
| VitalCardData.swift | equality와 hash에 sparklineData 포함 | 시계열만 바뀐 카드도 새로운 표시 상태로 취급 |
| DashboardViewModelTests.swift | 동일 최신값·시각의 과거값 변경 테스트 | 배열 Observation 알림 1회와 Set 계약 검증 |

### Key Code

```swift
&& lhs.sparklineData == rhs.sparklineData
// hash(into:)에도 동일 필드 사용
hasher.combine(sparklineData)
```

## Prevention

화면에 새 필드를 렌더링하기 시작할 때 사용자 정의 equality도 함께 검토한다. 최신 값이 바뀌는 정상 경로만으로는 과거 기록 수정의 갱신 누락을 잡을 수 없다. 똑같은 최신값·시각을 가진 두 상태로 실제 Observation 알림을 검증한다.

이 문서에 교정 내용을 보존하고 `.claude/**` 규칙은 수정하지 않았다.

## Lessons Learned

배열 내용이 메모리에 바뀌는 것과 화면의 관찰자가 갱신되는 것은 별개다. 표시 DTO에 필드를 추가하거나 기존 필드를 새로 쓰면 값 비교가 그 표시 변경을 구분하는지 확인해야 한다. 이번 회귀 테스트는 단순 getter가 아니라 실제 프레임워크 알림 경로를 검사한다.
