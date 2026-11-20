---
tags: [design-map, native-capture, readiness-score-bands, r05]
category: general
date: 2026-11-21
severity: important
related_files:
  - DUNE/Presentation/Activity/TrainingReadiness/TrainingReadinessDetailView.swift
  - docs/design/phone-design-map/actual/index.html
related_solutions: []
---

# Solution: R05 준비도 실제 점수 구간

## Problem

### Symptoms

The readiness detail did not locate the measured score on its four status ranges.

### Root Cause

Domain thresholds were not represented as a detail-view scale.

## Solution

### Changes Made

| File | Change | Reason |
|---|---|---|
| `DUNE/Presentation/Activity/TrainingReadiness/TrainingReadinessDetailView.swift` | Show the existing four ranges and current marker only when a measured score exists. | Match the approved R05 behavior. |
| `docs/design/phone-design-map/actual/r05-2026-11-21/` | Preserve actual passed native captures with a horizontal gallery and per-image provenance. | Make captured states reviewable across viewport sizes. |
| `docs/design/phone-design-map/actual/index.html` and `docs/design/layout-map/training-readiness-detail-a02.html` | Link the feature gallery from the actual and relevant layout map. | Keep proposal, implementation, and screenshot evidence distinct. |

### Evidence and limits

[R05 native gallery](../../design/phone-design-map/actual/r05-2026-11-21/index.html) · [provenance and scope](../../design/phone-design-map/actual/r05-2026-11-21/README.md). Visual inspection recorded in the bundle: 원본 화면 검토 완료 · 준비도 구간 카드 전체가 하단 탭 위에 들어온다. 0–39, 40–59, 60–79, 80–100 레이블과 현재 위치 표식이 보인다. iPad mini 원본 캡처: 준비도 77점과 보통 상태, 0–39/40–59/60–79/80–100 구간의 수치·설명·현재 점이 화면 폭 안에 모두 보이며 구간 카드가 하단에서 잘리지 않는다. Duo 접힘 LCD 1398×2034 원본: 준비도 구간 카드의 0–39, 40–59, 60–79, 80–100 숫자·문구와 77점 위치 표시가 모두 오른쪽 도킹 영역과 겹치지 않고 읽힌다. Duo 펼침 활성 LCD-1 2853×2007 물리 프레임: 준비도 77점의 검은 위치 점과 네 구간 수치·문구가 가로 카드에서 모두 잘림 없이 보이고 우측 도킹 영역과 분리된다.. Unverified devices: none. Uncaptured named states: none.

## Prevention

### Checklist Addition

- [ ] Tie a changed health score or sleep state to source provenance, an exact passed selector, and per-device visual review before marking it complete.

## Lessons Learned

An XCTest capture proves its tested route and fixture; it cannot certify other states or devices.
