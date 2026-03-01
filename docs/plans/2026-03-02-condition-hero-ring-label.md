---
tags: [ui, localization, dashboard, hero-card]
date: 2026-03-02
category: plan
status: approved
---

# Today 탭 히어로 링 레이블 누락 수정

## Problem

Today 탭의 `ConditionHeroView` 링 내부에 "CONDITION" 레이블이 없어 Activity("READINESS"), Wellness("WELLNESS") 탭과 시각적 불일치.
추가로 `ConditionScoreDetailView`에서 `"CONDITION"` 문자열이 `String(localized:)` 없이 하드코딩되어 번역 불가.

## Root Cause

`ConditionHeroView`가 `HeroScoreCard`를 재사용하지 않고 직접 링을 구현하면서 `scoreLabel` 표시가 누락됨.

## Affected Files

| 파일 | 변경 내용 |
|------|----------|
| `DUNE/Presentation/Dashboard/Components/ConditionHeroView.swift` | 링 내부에 scoreLabel 추가 |
| `DUNE/Presentation/Dashboard/ConditionScoreDetailView.swift` | `"CONDITION"` → `String(localized:)` |
| `DUNE/Resources/Localizable.xcstrings` | "CONDITION" 키 + ko/ja 번역 추가 |

## Implementation Steps

1. `ConditionHeroView` — 링 ZStack 내부를 VStack으로 변경, scoreLabel 추가
2. `ConditionScoreDetailView` — 하드코딩 "CONDITION" → Labels enum 패턴 적용
3. `Localizable.xcstrings` — "CONDITION" 키에 ko: "컨디션", ja: "コンディション" 추가
4. 빌드 검증
