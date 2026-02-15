---
source: review/architecture
priority: p2
status: ready
created: 2026-02-16
updated: 2026-02-16
---

# NavigationStack wrapping 중앙 집중화

## Problem

AdaptiveNavigation ViewModifier가 NavigationStack 래핑을 처리하지만,
새 View 추가 시 직접 NavigationStack을 사용할 수 있는 구조.
Lint rule이나 규칙 문서화로 방지 필요.

## Solution Options

1. `.claude/rules/`에 "View에서 직접 NavigationStack 사용 금지, adaptiveNavigation() 사용" 규칙 추가
2. SwiftLint custom rule로 NavigationStack 직접 사용 감지
3. AdaptiveNavigation 사용법 문서화 (README 또는 코드 주석)

## Location

- `Dailve/Presentation/Shared/Components/AdaptiveNavigation.swift`
- All tab detail views (DashboardView, ExerciseView, SleepView, BodyCompositionView)
