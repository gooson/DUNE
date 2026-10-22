---
tags: [swiftui, wellness, hero-card, navigation, sleep-detail, accessibility, ipad-layout]
category: general
date: 2026-10-22
severity: important
related_files: [DUNE/Presentation/Wellness/Components/WellnessHeroCard.swift, DUNEUITests/Smoke/WellnessSmokeTests.swift, Shared/Resources/Localizable.xcstrings]
related_solutions: [docs/solutions/general/2026-10-22-contextual-first-fold-hero.md, docs/solutions/design/hero-cta-button-pattern.md]
---

# Solution: Wellness 히어로에서 점수와 수면의 상세 목적지 분리

## Problem

### Symptoms

- Wellness 히어로에 점수와 수면 요약이 함께 보이지만 카드 전체가 점수 상세로 열려, 수면 영역을 눌러도 수면 상세로 가지 않았다.
- 카드의 단일 상세 힌트와 별도 수면 링크는 각 영역의 탭 결과를 예측하기 어렵게 했다.
- 첫 수정에서는 수면 링크가 중복되고, 점수 상세 힌트가 빠졌으며, iPad 두 열의 상세 힌트 높이가 달랐다. 수면 데이터가 없을 때 VoiceOver 설명도 수면 영역임을 알리기에 부족했다.

### Root Cause

서로 다른 두 정보의 목적지를 하나의 히어로 카드에 묶었다. 각 정보 영역이 독립적인 탐색 단위라는 의미를 링크 구조와 보이는 행동 문구에 반영하지 않았고, 두 열의 높이를 실제 캡처에서 확인하기 전까지 정렬 문제를 놓쳤다.

## Solution

### Changes Made

| File | Change | Reason |
|---|---|---|
| `WellnessHeroCard.swift` | 점수와 수면을 각각 형제 `NavigationLink`로 구성하고 `Wellness Details` / `Sleep Details`를 각 링크 내부에 배치 | 보이는 정보, 탭 영역, 도착 화면을 일치시킴 |
| `WellnessHeroCard.swift` | iPad 일반 글씨의 두 열에서만 내부 `Spacer`로 상세 힌트의 세로 위치를 맞추고, 수면 데이터가 없는 접근성 설명에 `Sleep`을 포함 | 넓은 카드의 시각적 정렬과 VoiceOver 의미를 개선 |
| `Localizable.xcstrings` | 새 점수 상세 문구의 한국어·일본어 번역 추가 | 상세 힌트의 현지화 유지 |
| `WellnessSmokeTests.swift` 및 테마 UI 테스트 | 점수·수면 영역의 개별 목적지, 식별자, 주요 테마 배치를 검증 | 링크 회귀와 화면 배치 문제를 감지 |
| `docs/design/phone-design-map/actual/` | Wellness H01의 iPhone·iPad 실제 캡처와 비교 갤러리 갱신 | 구현과 시안을 같은 화면에서 확인 |

### Key Code

```swift
NavigationLink(value: WellnessScoreDestination()) {
    wellnessScoreContent
        .contentShape(Rectangle())
}
.accessibilityIdentifier("wellness-hero-score")

NavigationLink(value: sleepMetric) {
    sleepSectionContent
        .contentShape(Rectangle())
}
.accessibilityIdentifier("wellness-hero-sleep")
```

실제 구현은 수면 측정값이 없을 때 수면 링크를 만들지 않는다. 두 상세 힌트는 각각 해당 링크의 레이블 안에 있다. iPad의 세로 정렬용 `Spacer`는 `horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize`일 때만 사용한다.

## Prevention

### Checklist Addition

- [ ] 히어로에 서로 다른 정보가 있다면 각 영역의 탭 결과가 정보의 의미와 일치하는가?
- [ ] 보이는 상세 문구가 실제 링크의 레이블 안에 있고 중복 행동이 없는가?
- [ ] VoiceOver가 데이터 유무와 목적지를 구별할 수 있는가?
- [ ] iPhone 세로 배치와 iPad 두 열 배치를 실제 캡처에서 확인했는가?
- [ ] 각 링크를 눌러 다른 상세 화면에 도착하는 UI 테스트가 있는가?

별도 전역 규칙은 추가하지 않았다. 기존 CTA·탭 소유권 규칙으로 구조를 설명할 수 있고, 이번 사례의 세부 판단은 이 문서와 UI 테스트에 기록했다. 관련 TODO는 이미 `todos/done/`에 있으며 이번 변경에서 상태를 바꿀 미완료 TODO는 없었다.

## Lessons Learned

하나의 카드가 두 주제를 담으면 카드 전체를 하나의 링크로 취급하기보다 사용자가 누를 정보의 경계를 먼저 정해야 한다. 최종 텍스트와 데이터가 들어간 실제 iPad 캡처까지 확인해야 두 열의 행동 문구 정렬과 접근성 설명을 검증할 수 있다.
