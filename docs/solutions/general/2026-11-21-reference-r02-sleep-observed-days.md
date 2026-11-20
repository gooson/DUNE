---
tags: [design-map, native-capture, sleep-observed-days, r02]
category: general
date: 2026-11-21
severity: important
related_files:
  - DUNE/Presentation/Wellness/Components/WellnessSleepSummaryCard.swift
  - docs/design/phone-design-map/actual/index.html
related_solutions: []
---

# Solution: R02 최근 수면 관측일·날짜 선택

## Problem

### Symptoms

Sparse nights did not have a clear observed count or prominent selected and average values.

### Root Cause

The sleep summary hierarchy did not separate observed days from missing calendar slots.

## Solution

### Changes Made

| File | Change | Reason |
|---|---|---|
| `DUNE/Presentation/Wellness/Components/WellnessSleepSummaryCard.swift` | Keep seven date slots, expose selected observed or missing date, and average observed nights only. | Match the approved R02 behavior. |
| `docs/design/phone-design-map/actual/r02-2026-11-21/` | Preserve actual passed native captures with a horizontal gallery and per-image provenance. | Make captured states reviewable across viewport sizes. |
| `docs/design/phone-design-map/actual/index.html` and `docs/design/layout-map/index.html` | Link the feature gallery from the actual and relevant layout map. | Keep proposal, implementation, and screenshot evidence distinct. |

### Evidence and limits

[R02 native gallery](../../design/phone-design-map/actual/r02-2026-11-21/index.html) · [provenance and scope](../../design/phone-design-map/actual/r02-2026-11-21/README.md). Visual inspection recorded in the bundle: 원본 화면 검토 완료 · 최근 수면 시간·날짜와 관측일 수가 보인다. 기록 수에 따라 일곱 날짜 중 측정한 날에만 막대가 있고, 누락일을 선택하면 한국어·영어에서 날짜와 기록 부재가 함께 표시된다. 기록이 없을 때 Need More Data와 Recorded 0 of 7 nights가 표시된다. 어두운 테마의 최대 접근성 글씨에서 시간과 평균이 줄바꿈되고 15·18·21 날짜 및 두 막대가 보인다. 어두운 테마 기본 글씨의 원본에는 최근 수면 카드 상단과 최신 시간이 보인다. 아래 그래프는 이 캡처의 화면 밖에 있다. iPad mini 영어·한국어 원본 캡처: 최근 수면 7시간 54분과 7일 평균 7시간 30분이 큰 값으로 보이고, 2/7 기록·선택한 11월 18일 기록 없음·7일 막대 두 개가 카드 안에 온전히 보인다. Duo 접힘 LCD 1398×2034 원본 영어·한국어 캡처: 최근 수면과 7일 평균이 큰 값으로 읽히고 2/7 관측, 선택한 18일 기록 없음, 17·21일 막대가 표시된다. 오른쪽 도킹 영역과 겹침은 없으며 하단 날짜 일부는 스크롤 범위 밖에 있다. Duo 펼침 활성 LCD-1 2853×2007 물리 프레임 영어·한국어 원본: 두 언어 모두 최근 7시간 54분, 7일 평균 7시간 30분, 관측 2/7, 선택한 18일 기록 없음과 실제 두 막대가 두 열 카드에서 잘림 없이 읽힌다.. Unverified devices: none. Uncaptured named states: ipad: H01-sleep-0-records, H01-sleep-1-records, H01-sleep-2-records, H01-sleep-2-records-MaxAX, H01-sleep-2-records-dark, H01-sleep-4-records, H01-sleep-7-records; duo: H01-sleep-0-records, H01-sleep-1-records, H01-sleep-2-records, H01-sleep-2-records-MaxAX, H01-sleep-2-records-dark, H01-sleep-4-records, H01-sleep-7-records; duo-open: H01-sleep-0-records, H01-sleep-1-records, H01-sleep-2-records, H01-sleep-2-records-MaxAX, H01-sleep-2-records-dark, H01-sleep-4-records, H01-sleep-7-records.

## Prevention

### Checklist Addition

- [ ] Tie a changed health score or sleep state to source provenance, an exact passed selector, and per-device visual review before marking it complete.

## Lessons Learned

An XCTest capture proves its tested route and fixture; it cannot certify other states or devices.
