---
tags: [watch, cardio, tabview, swipe, controls, ux]
date: 2026-03-04
category: solution
status: implemented
---

# Watch 유산소 운동 종료 UX: 우측 스와이프 컨트롤

## Problem

유산소 운동 중 종료/일시정지 버튼이 세로 TabView 5페이지 중 4번째에 위치하여, 메트릭 3페이지를 스크롤해야 접근 가능. Apple Fitness는 메인 화면에서 1회 스와이프로 즉시 접근.

## Solution

### Flat horizontal TabView (Apple Fitness 패턴)

세로 `.verticalPage` TabView를 **수평 기본 스타일 TabView**로 교체:

```
[Controls] ← [MainMetrics] → [HRZone] → [Secondary] → [NowPlaying]
                (default)
```

- Controls는 좌측 첫 페이지 (우측 스와이프 1회로 접근)
- 기본 선택: MainMetrics (2번째 페이지)
- 모든 페이지 수평 스와이프로 탐색

### Nested TabView 금지

초기 구현에서 horizontal(outer) + vertical(inner) 중첩을 시도했으나 리뷰에서 거부:
- watchOS에서 문서화되지 않은 패턴, 디바이스에서 제스처 충돌 위험
- Digital Crown 라우팅 불확실 (어느 TabView가 Crown focus를 잡는지 미정의)
- 페이지 인디케이터 시각적 중복
- AOD 복귀 시 이중 애니메이션 패스

### DRY: ControlsView 통합

별도 `CardioControlsView` 대신 기존 `ControlsView`에 `showSkip: Bool = true` 파라미터 추가:
- Cardio: `ControlsView(showSkip: false)`
- Strength: `ControlsView()` (기본값 true)

### 성능: isCardioMode를 값으로 전달

`SessionPagingView`가 `@Environment(WorkoutManager.self)`를 읽으면 모든 WorkoutManager 업데이트(HR, 시간)에 body 재평가. `isCardioMode`는 세션 중 변하지 않으므로 `let isCardioMode: Bool`로 부모에서 전달.

## Prevention

- watchOS에서 **nested TabView 금지** — 항상 flat paging 사용
- 모드별 분기 View는 **mode-specific private enum**으로 tab case 분리 (타입 시스템이 잘못된 case 조합 방지)
- `@Observable` 환경 객체의 불변 속성은 **값으로 캡처**하여 불필요한 re-render 차단
