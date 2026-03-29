---
tags: [dashboard, today, consolidation, ux, cards, sections]
date: 2026-03-29
category: solution
status: implemented
---

# Today Tab Section Consolidation

## Problem

Today 탭에 13개 섹션이 순차 스크롤. 코칭 메시지가 3곳(BriefingEntry, CoachingCard, InsightCards)에 파편화되고, 날씨 카드와 모닝 브리핑에 날씨 정보가 중복, 수면 부채 배지가 하단에 고립.

## Solution

### 3-Zone 구조로 통합 (13 → 9 섹션)

**Zone A (Glanceable)**: Hero + TodayBriefCard (= BriefingEntry + WeatherCard + CoachingCard)
**Zone B (Context)**: RecoverySleepCard (= SleepDeficit + sleep InsightCards) + SmartInsightsSection (= non-sleep InsightCards + TemplateNudge) + HealthQA
**Zone C (Data)**: Pinned, Condition, Activity, Body (유지)

### 핵심 설계 결정

1. **Weather 네비게이션**: `NavigationLink(value:)` 대신 `@State weatherDetailNavigation` + `navigationDestination(item:)` 사용. 기존 `for: WeatherSnapshot.self` destination은 dead code이므로 제거.
2. **인사이트 분배**: `sleepInsightCards` / `nonSleepInsightCards` computed properties로 분배.
3. **조건부 표시**: 빈 카드/섹션 자동 숨김.
4. **WeatherSnapshot.humidity**: 0-1 스케일 → ×100 변환 필요.

## Prevention

- 새 카드는 기존 Zone 안에서 위치 선택
- 같은 맥락 정보는 한 카드로 통합
- DS.Color에 없는 토큰 사용 전 DesignSystem.swift 확인
- `navigationDestination` 추가 시 동일 타입 기존 destination 확인
