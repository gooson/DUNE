---
tags: [dashboard, iphone17, compact-layout, vital-card, truncation-check]
category: general
date: 2026-03-15
severity: minor
related_files:
  - DUNE/Presentation/Dashboard/DashboardView.swift
  - DUNE/Presentation/Wellness/Components/VitalCard.swift
  - DUNE/Presentation/Shared/Extensions/HealthMetric+View.swift
  - DUNE/App/TestDataSeeder.swift
related_solutions:
  - docs/solutions/general/2026-03-08-notification-hub-summary-inline-navigation-link-wrap.md
---

# Solution: Dashboard small-phone ellipsis verification

## Problem

Today 화면의 작은 폰 폭(iPhone 17)에서 Activity/Steps 계열 카드 값이 `...`로 잘리는지 확인이 필요했다.

### Symptoms

- 사용자 스크린샷에서 Activity 카드 값이 `6,7...`처럼 보였다.
- 현재 코드가 이미 수정된 상태인지, 아니면 여전히 재현 가능한지 불명확했다.

### Root Cause

현재 `VitalCard`는 값과 단위를 분리해 렌더링하고, 숫자 값에만 `.minimumScaleFactor(0.7)`와 `.lineLimit(1)`을 적용한다. 따라서 작은 기기에서 실제 위험 구간은 “카드 내부 폭” 대비 “값 + 단위 + change badge” 조합이 과도하게 길어지는 경우로 한정된다.

## Solution

앱 코드를 변경하지 않고, 현재 HEAD 기준 레이아웃 경로를 조사하고 iPhone 17 simulator 기동 + 한국어 locale screenshot + 문자열 폭 측정으로 검증했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `docs/plans/2026-03-15-dashboard-small-phone-ellipsis-check.md` | verification plan 추가 | 재현/수정 조건과 검증 경로를 명시적으로 기록 |
| `docs/solutions/general/2026-03-15-dashboard-small-phone-ellipsis-verification.md` | solution 문서 추가 | 같은 확인 작업을 다음에 반복하지 않도록 근거 축적 |

### Key Code

```swift
Text(data.value)
    .font(DS.Typography.cardScore)
    .minimumScaleFactor(0.7)
    .lineLimit(1)

if !data.unit.isEmpty {
    Text(data.unit)
        .font(.caption)
}
```

검증 결과:

- `DashboardView`는 iPhone 17 compact width에서 2열 grid를 유지한다.
- `StandardCard` padding까지 반영하면 카드 내부 폭은 대략 `142pt` 수준이다.
- 측정 기준으로 `6,540`, `6,740`, `12,540` 같은 5자리 steps 값은 현재 조합에서 수용 가능했다.
- 실제 위험 구간은 `126,540` 같은 6자리 이상 값 + 큰 change badge가 같이 붙는 경우였다.
- iPhone 17 simulator에서 한국어 locale로 Today 화면을 실행했을 때 상단 Today surface는 정상 렌더링됐다.

## Prevention

작은 폰 회귀는 “현재 seed 값이 아니라 값 문자열의 최대 길이” 기준으로 판단해야 한다.

### Checklist Addition

- [ ] compact 2열 카드에서 `value`, `unit`, `change`가 동시에 노출될 때 5자리/6자리 수치를 함께 검토한다.
- [ ] `Text(value)`에만 축소가 걸려 있다면 trailing badge 폭이 과도하지 않은지 같이 확인한다.

### Rule Addition (if applicable)

즉시 규칙 승격이 필요할 정도의 신규 패턴은 아니지만, compact card 검증 시 문자열 최대 길이와 badge 조합을 함께 보는 관행은 유지한다.

## Lessons Learned

- 현재 이슈는 “지금도 재현되는 버그”라기보다 “과거 스크린샷이 현재 HEAD에서도 가능한가”를 확인하는 성격에 가깝다.
- 공통 카드 컴포넌트에서 값과 단위를 분리하고 숫자에만 scale factor를 적용한 구조는 작은 폰 방어에 효과적이다.
- UI 회귀 확인은 가능하면 simulator screenshot과 문자열 폭 계산을 같이 남겨야 추후 재판단이 빠르다.
