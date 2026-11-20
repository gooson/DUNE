---
tags: [design-map, native-capture, readiness-evidence, r08]
category: general
date: 2026-11-21
severity: important
related_files:
  - DUNE/Domain/UseCases/CalculateTrainingReadinessUseCase.swift
  - docs/design/phone-design-map/actual/index.html
related_solutions: []
---

# Solution: R08 준비도 근거 부족 상태

## Problem

### Symptoms

Missing recovery measurements could still yield a numeric readiness total.

### Root Cause

Fallback values were accepted as weighted readiness evidence.

## Solution

### Changes Made

| File | Change | Reason |
|---|---|---|
| `DUNE/Domain/UseCases/CalculateTrainingReadinessUseCase.swift` | Withhold unsupported totals and show the available sources in the Activity hero. | Match the approved R08 behavior. |
| `docs/design/phone-design-map/actual/r08-2026-11-21/` | Preserve actual passed native captures with a horizontal gallery and per-image provenance. | Make captured states reviewable across viewport sizes. |
| `docs/design/phone-design-map/actual/index.html` and `docs/design/layout-map/index.html` | Link the feature gallery from the actual and relevant layout map. | Keep proposal, implementation, and screenshot evidence distinct. |

### Evidence and limits

[R08 native gallery](../../design/phone-design-map/actual/r08-2026-11-21/index.html) · [provenance and scope](../../design/phone-design-map/actual/r08-2026-11-21/README.md). Visual inspection recorded in the bundle: 원본 화면 검토 완료 · 근거 일부 상태에는 Recovery가 표시되고, 근거 없음 상태에는 점수 대신 안내가 보인다. 빈 기록 테스트 기기에서는 권한 확인 안내도 함께 보인다. iPad mini 실기기 캡처: 부분 입력은 점수 없이 Available Data와 Recovery를 표시한다. 무입력은 Need More Data로 표시되지만 상단에 HealthKit 권한 오류 배너가 겹쳐 별도 원인 확인이 필요하다. Duo 접힘 LCD 1398×2034 원본: 부분 입력은 점수 없이 Available Data/Recovery를, 무입력은 Need More Data를 표시한다. 무입력에서는 기존 활동 오류 분류로 HealthKit 권한 배너가 readiness 제목 상단을 덮는다. 펼친 Duo의 준비도 카드에 Need More Data가 보이고 점수는 표시되지 않는다. 펼친 Duo의 준비도 카드에 추가 기록 안내와 Available Data, Recovery가 보인다.. Unverified devices: none. Uncaptured named states: none.

## Prevention

### Checklist Addition

- [ ] Tie a changed health score or sleep state to source provenance, an exact passed selector, and per-device visual review before marking it complete.

## Lessons Learned

An XCTest capture proves its tested route and fixture; it cannot certify other states or devices.
