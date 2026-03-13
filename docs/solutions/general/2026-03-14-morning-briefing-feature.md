---
tags: [morning-briefing, dashboard, template-engine, localization, accessibility]
date: 2026-03-14
category: solution
status: implemented
---

# Morning Briefing Feature

## Problem Statement

사용자가 앱을 열었을 때 오늘의 컨디션, 회복 상태, 운동 가이드, 주간 추세를 한눈에 파악할 수 있는 요약 브리핑이 필요했다. 기존에는 대시보드의 여러 카드를 개별적으로 확인해야 했다.

## Solution

### Architecture

```
Domain Layer:
  MorningBriefingData (Sendable struct) — 브리핑에 필요한 모든 데이터 집합
  BriefingTemplateEngine (enum) — 템플릿 기반 텍스트 생성

Presentation Layer:
  MorningBriefingViewModel — sheet 상태 + 날짜 기반 show-once 로직
  MorningBriefingView — 4개 섹션 staggered animation sheet
  BriefingEntryCard — hero 아래 재진입 카드
  DashboardView — 통합 (auto-show + manual re-open)
  SettingsView — on/off 토글
```

### Key Design Decisions

1. **새 HealthKit 쿼리 없음**: DashboardViewModel의 기존 데이터(`conditionScore`, `recentScores`, `insightCards`, `weatherSnapshot` 등)를 재사용. `buildBriefingData()`가 조립만 담당.

2. **Template-only MVP**: AI 텍스트 생성 없이 `BriefingTemplateEngine`이 조건 분기로 텍스트 생성. 향후 AI hybrid 확장 가능.

3. **Show-once via UserDefaults**: `lastBriefingDate` 키에 "yyyy-MM-dd" 문자열 저장. DateFormatter는 static let 캐싱 + POSIX locale.

4. **markBriefingShown() 시점**: `.task`가 아닌 `.onDisappear`에서 호출. 사용자가 sheet을 실제로 본 후에만 기록하여, 즉시 dismiss된 경우 다시 표시.

5. **@AppStorage 바인딩**: DashboardView에서 `MorningBriefingViewModel.isEnabled` 정적 메서드 대신 `@AppStorage("morningBriefingDisabled")`로 body에서 UserDefaults 직접 읽기 방지.

### Review Findings & Fixes

| Finding | Severity | Fix |
|---------|----------|-----|
| DateFormatter 매 호출 생성 | P1 | `private enum Cache { static let }` 패턴 |
| markBriefingShown() 타이밍 | P1 | `.task` → `.onDisappear` 이동 |
| conditionColor 중복 switch | P1 | `ConditionScore.Status.color` extension 사용 |
| isAnimating/beginAnimation() dead code | P1 | 삭제 |
| UserDefaults body 호출 | P1 | `@AppStorage` 바인딩 |
| Reduce Motion 미대응 | P1 | `accessibilityReduceMotion` 체크 추가 |
| 빈 sheet 위험 | P1 | data nil 시 sheet dismiss |
| 접근성 레이블 부재 | P1 | `.accessibilityLabel`/`.accessibilityHint` 추가 |
| 음수 sleepDuration | P2 | `>= 0` guard |

## Prevention

- **Formatter 캐싱**: NSObject 기반 formatter는 항상 `private enum Cache { static let }` — `performance-patterns.md` 규칙 재확인
- **markShown 타이밍**: 사용자 행동 기록은 "사용자가 실제로 본 후" 시점에 배치
- **Color 매핑 DRY**: 새 View에서 `ConditionScore.Status → Color` 필요 시 기존 `.color` extension 확인
- **Reduce Motion**: 모든 staggered/sequential 애니메이션에 `accessibilityReduceMotion` 체크 필수
- **Sheet content guard**: `sheet(isPresented:)` 내부에서 optional binding 시, data nil 대응 필수
