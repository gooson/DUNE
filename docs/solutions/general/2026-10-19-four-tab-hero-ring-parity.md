---
tags: [swiftui, hero-card, progress-ring, dynamic-type, design-map]
category: general
date: 2026-10-19
severity: important
related_files:
  - DUNE/Presentation/Shared/Components/ProgressRingView.swift
  - DUNE/Presentation/Dashboard/Components/DesertHorizonConditionHeroView.swift
  - DUNE/Presentation/Activity/ActivityView.swift
  - DUNE/Presentation/Wellness/Components/WellnessHeroCard.swift
  - DUNE/Presentation/Life/LifeView.swift
related_solutions: []
---

# Solution: 4탭 히어로 링을 Today 기준으로 통일

## Problem

### Symptoms

- 4탭 레이아웃 맵에는 각 히어로의 링이 있었지만 실제 앱은 Today에만 링이 남아 있었다.
- Activity·Wellness에 링을 처음 복구한 화면에서 링과 설명이 세로로 나열되거나 Wellness의 긴 설명이 카드 오른쪽에서 잘렸다.

### Root Cause

Today 링이 화면 내부의 전용 View여서 다른 탭에서 같은 지름·획·숫자 계층을 재사용할 수 없었다. 긴 문구를 링 옆의 제한된 폭에 전부 넣으면 iPhone 카드에서 줄바꿈 공간이 부족하다.

## Solution

### Changes Made

| File | Change | Reason |
|---|---|---|
| `ProgressRingView.swift` | `TabHeroScoreRing`에 124pt 지름, 11pt 획, 그라디언트, 숫자와 접근성 레이블을 모았다. | Today와 4탭의 링 형태를 동일하게 유지한다. |
| Today·Activity·Wellness·Life 히어로 | 공통 링에 각각 컨디션, 준비도, 웰니스 점수, 완료 습관 수를 전달했다. | 각 링을 실제 카드의 지표와 연결한다. |
| `WellnessHeroCard.swift` | 상태는 링 옆에 두고 긴 설명은 다음 행에서 카드 전체 폭을 쓴다. | iPhone의 문구 잘림을 없앤다. |
| 4탭 레이아웃 맵·실제 캡처 | 기준 치수를 맞추고 기기·테마·밝음/어두움별 원본 PNG 출처를 보존했다. | 시안과 실제 앱 화면을 혼동하지 않는다. |

### Verification

- iPhone DESERT HORIZON과 WATER LILIES의 밝음·어두움 4탭 UI 테스트 통과.
- iPad DESERT HORIZON의 밝음·어두움 4탭 UI 테스트 통과.
- Wellness 설명의 오른쪽 끝이 카드 안에 있는지 프레임으로 검증하고 실제 캡처를 확인했다.
- 해당 PNG와 테스트 결과 출처는 `docs/design/full-redesign-map/review/`의 두 히어로 링 폴더에 있다.

## Prevention

- 4탭 히어로의 핵심 시각 요소를 바꿀 때 레이아웃 맵의 네 화면과 실제 캡처를 먼저 대조한다.
- 링의 크기·획·숫자 계층은 공통 View에서 수정한다. 각 탭은 실제 지표와 상태색만 전달한다.
- 긴 현지화 문구는 링 옆 고정 폭을 가정하지 말고 카드 전체 폭에서 줄바꿈할 수 있게 배치한다.
- 기기 UDID가 다른 실제 캡처는 기존 인덱스에 덮어써서 최신 증거로 표시하지 않는다.

## Lessons Learned

요소 존재를 확인하는 UI 테스트만으로는 카드 내부 잘림을 발견하기 어렵다. 카드 프레임 검사와 실제 스크린샷 대조가 함께 필요하다.
