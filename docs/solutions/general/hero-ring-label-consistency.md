---
tags: [ui, localization, hero-card, ring, consistency]
date: 2026-03-02
category: solution
status: implemented
---

# Hero Ring Label Consistency

## Problem

Today 탭의 `ConditionHeroView` 링 내부에 점수 레이블("CONDITION")이 누락되어 Activity("READINESS"), Wellness("WELLNESS") 탭과 시각적 불일치 발생. 추가로 `ConditionScoreDetailView`에서 `"CONDITION"` 문자열이 `String(localized:)` 없이 하드코딩.

## Solution

1. `ConditionHeroView` 링 ZStack 내부를 `VStack(spacing: 2)`로 변경, `Text(Labels.scoreLabel)` 추가
2. `ConditionScoreDetailView`의 하드코딩 → `Labels.scoreLabel` (String(localized:)) 적용
3. xcstrings에 "CONDITION" 키 등록 (ko: "컨디션", ja: "コンディション")

## Prevention

- 새 Hero 카드 추가 시 링 내부 레이블 포함 여부 체크
- `HeroScoreCard` 패턴(VStack + score + label) 참조
- `String(localized:)` 래핑 + xcstrings 3개 언어 등록 누락 방지
