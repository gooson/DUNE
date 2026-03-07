---
tags: [swiftui, notifications, list, navigationlink, layout, localization]
date: 2026-03-08
category: solution
status: implemented
---

# Notification Hub Summary Inline NavigationLink Wrap

## Problem

알림 허브 empty state에서 summary 카드 문구 `받은 알림을 모두 확인했어요`가 부자연스럽게 두 줄로 줄바꿈되었다.

## Root Cause

summary 카드 상단 우측 설정 아이콘이 `NavigationLink`로 구현되어 있었다.  
`List` row 안의 inline `NavigationLink`는 label 크기보다 큰 row-style navigation affordance를 가져오고, trailing disclosure 영역까지 차지하면서 제목 텍스트의 실제 사용 가능 폭을 줄였다.

그 결과 한국어 번역처럼 길이가 긴 상태 문구가 작은 iPhone 폭에서 불필요하게 줄바꿈되었다.

## Solution

설정 아이콘을 inline `NavigationLink`에서 plain `Button` 기반 state navigation으로 교체했다.  
이미 화면에 존재하던 `destination = .settings` 라우팅을 재사용해서 시각적 disclosure를 제거하고, 상태 문구에는 한 줄 유지용 `lineLimit(1)`과 `minimumScaleFactor`를 추가했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Dashboard/NotificationHubView.swift` | summary 카드의 설정 아이콘을 `NavigationLink`에서 `Button`으로 교체, empty-state title에 one-line 보호 modifier 추가 | inline disclosure 제거, localized summary text wrap 방지 |
| `DUNEUITests/Smoke/DashboardSmokeTests.swift` | Notifications hub smoke test에 summary settings button 존재 assertion 추가 | UI 구조 변경 회귀 방지 |

## Prevention

- `List`/card 내부의 작은 trailing action은 `NavigationLink`보다 explicit button + destination state를 우선 검토한다.
- localized status copy는 compact width에서 한 줄 유지가 필요한 경우 `lineLimit`과 `minimumScaleFactor`를 함께 고려한다.
- screenshot에서 원치 않는 chevron이 보이면 내부 `NavigationLink`가 row semantics를 끌어오고 있는지 먼저 확인한다.
