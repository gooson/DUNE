---
tags: [vital-card, sleep, unit, localization, display, pinned-metrics]
date: 2026-03-30
category: solution
status: implemented
---

# 수면 카드 중복 단위 표시 ("5시간 35분 분")

## Problem

Today 탭 고정됨(Pinned) 섹션의 수면 카드가 "5시간 35분 분"으로 표시됨.
`hoursMinutesFormatted`가 반환하는 "5시간 35분"에 이미 시간 단위가 포함되어 있는데,
`resolvedUnitLabel`이 추가로 "분"(`String(localized: "min")`)을 표시.

### 근본 원인

`DashboardViewModel`에서 sleep HealthMetric 생성 시 `unit: "min"` 사용.
`resolvedUnitLabel`이 이를 `String(localized: "min")` → "분"으로 변환하여 표시.

WellnessViewModel은 이미 `unit: ""` 사용 (올바른 패턴). DashboardViewModel만 불일치.

## Solution

`DashboardViewModel`의 sleep HealthMetric 생성 2곳에서 `unit: "min"` → `unit: ""`로 변경.

이는 WellnessViewModel의 기존 패턴과 일치하며, `category.unitLabel`이 sleep에 대해 이미 `""`를 반환하므로
별도 방어 코드 불필요.

## Prevention

- Sleep metric은 `hoursMinutesFormatted`로 시간 단위가 포함된 포맷을 사용하므로, `unit` 필드를 `""` 으로 설정
- 새 HealthMetric 생성 시 `formattedNumericValue`가 이미 단위를 포함하는지 확인 후 `unit` 결정
- `category.unitLabel`이 `""` 인 카테고리는 `unit` 도 `""` 으로 맞출 것

## Lessons Learned

- 같은 모델을 두 ViewModel에서 생성하는 경우, 한쪽에서 올바른 패턴을 사용해도 다른 쪽에서 불일치하면 버그
- 한국어처럼 단위가 접미사로 붙는 언어에서 중복 단위는 영어보다 더 눈에 띔 ("5h 35m min" vs "5시간 35분 분")
