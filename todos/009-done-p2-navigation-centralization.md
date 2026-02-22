---
source: review/architecture
priority: p2
status: done
created: 2026-02-16
updated: 2026-02-22
---

# NavigationStack wrapping 중앙 집중화

## Problem

AdaptiveNavigation 제거 이후, iOS 탭 루트 NavigationStack 소유권이 다시 암묵화됨.
새 View 추가 시 root-level 중첩 NavigationStack이 재도입될 수 있어 규칙 명시 필요.

## Solution

`.claude/rules/navigation-ownership.md` 추가:

- iOS 탭 루트 `NavigationStack`은 `Dailve/App/ContentView.swift`에서만 생성
- Feature root view에 root-level `NavigationStack` 추가 금지
- sheet/fullScreenCover/preview 내부의 지역적 `NavigationStack`은 허용
- 리뷰 체크포인트 명시

## Location

- `.claude/rules/navigation-ownership.md`
- `Dailve/App/ContentView.swift` (root ownership reference)

## Notes

- 기존 TODO의 AdaptiveNavigation 기준은 구조 변경으로 obsolete
- 현재 구조(`TabView(.sidebarAdaptable)` + tab-root `NavigationStack`) 기준으로 교정 완료
