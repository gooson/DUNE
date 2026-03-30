---
tags: [vital-card, sleep, unit, localization, layout]
date: 2026-03-30
category: plan
status: draft
---

# 고정됨 수면 카드 중복 단위 제거 및 카드 크기 정규화

## Problem Statement

Today 탭 고정됨(Pinned) 섹션의 수면 카드가 "5시간 35분 분"으로 표시됨.
`hoursMinutesFormatted`가 이미 시간 단위를 포함한 포맷("5시간 35분")을 반환하는데,
`resolvedUnitLabel`이 추가로 "분"을 표시하여 중복.

이로 인해 value 텍스트가 좁은 영역에 갇혀 `minimumScaleFactor`로 과도하게 축소되고,
다른 카드(HRV "28 ms", RHR "63 bpm")와 시각적 불일치 발생.

## Root Cause

`DashboardViewModel`에서 sleep HealthMetric 생성 시 `unit: "min"` 사용.
`resolvedUnitLabel`이 이를 `String(localized: "min")` → "분"으로 변환하여 표시.

WellnessViewModel은 이미 `unit: ""` 사용 (올바른 패턴).

## Affected Files

| 파일 | 변경 내용 |
|------|----------|
| `DUNE/Presentation/Dashboard/DashboardViewModel.swift` | sleep metric `unit: "min"` → `unit: ""` (2곳) |
| `DUNE/Presentation/Shared/Extensions/HealthMetric+View.swift` | `resolvedUnitLabel`에 sleep guard 추가 (방어) |

## Implementation Steps

### Step 1: DashboardViewModel sleep unit 수정
- line ~875, ~919: `unit: "min"` → `unit: ""`

### Step 2: resolvedUnitLabel 방어 코드 추가
- sleep category일 때 항상 `""` 반환 (formattedValue와 일관성)

## Test Strategy

- 기존 HealthMetricTests 통과 확인
- `scripts/build-ios.sh` 빌드 확인

## Risk / Edge Cases

- `unit` 필드가 비어도 change display에는 영향 없음 (change는 숫자만 표시)
- WellnessViewModel이 이미 `unit: ""` 사용 중 → 검증된 패턴
