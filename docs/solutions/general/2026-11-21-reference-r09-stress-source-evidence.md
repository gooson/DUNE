---
tags: [design-map, native-capture, stress-source-evidence, r09]
category: general
date: 2026-11-21
severity: important
related_files:
  - DUNE/Presentation/Dashboard/DashboardViewModel.swift
  - docs/design/phone-design-map/actual/index.html
related_solutions: []
---

# Solution: R09 누적 스트레스 원자료 상태

## Problem

### Symptoms

A stress number could be assembled from condition and extrapolated exercise proxies.

### Root Cause

Dashboard input assembly used substitute values rather than each model source.

## Solution

### Changes Made

| File | Change | Reason |
|---|---|---|
| `DUNE/Presentation/Dashboard/DashboardViewModel.swift` | Use recorded HRV, sleep timing, and workouts; show source status until sufficient. | Match the approved R09 behavior. |
| `docs/design/phone-design-map/actual/r09-2026-11-21/` | Preserve actual passed native captures with a horizontal gallery and per-image provenance. | Make captured states reviewable across viewport sizes. |
| `docs/design/phone-design-map/actual/index.html` and `docs/design/layout-map/index.html` | Link the feature gallery from the actual and relevant layout map. | Keep proposal, implementation, and screenshot evidence distinct. |

### Evidence and limits

[R09 native gallery](../../design/phone-design-map/actual/r09-2026-11-21/index.html) · [provenance and scope](../../design/phone-design-map/actual/r09-2026-11-21/README.md). Visual inspection recorded in the bundle: 원본 화면 검토 완료 · 총점 대신 누적 스트레스의 HRV·수면·훈련 부하별 기록 상태가 한 카드 안에 보인다. iPad mini 실기기 캡처: Cumulative Stress는 숫자 없이 Stress evidence unavailable을 표시하고 HRV·Training Load Recorded, Sleep No record를 구분한다. 카드의 글자와 상태가 잘림 없이 보인다. Duo 접힘 LCD 1398×2034 원본: Cumulative Stress 카드는 숫자 없이 evidence unavailable을 표시하고 HRV·Training Load Recorded, Sleep No record를 잘림 없이 구분한다. 펼친 화면에서 누적 스트레스 근거 부족 메시지 아래에 HRV 기록 있음, 수면 기록 없음, 훈련 부하 기록 있음이 표시된다.. Unverified devices: none. Uncaptured named states: none.

## Prevention

### Checklist Addition

- [ ] Tie a changed health score or sleep state to source provenance, an exact passed selector, and per-device visual review before marking it complete.

## Lessons Learned

An XCTest capture proves its tested route and fixture; it cannot certify other states or devices.
