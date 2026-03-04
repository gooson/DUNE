---
tags: [watch, cardio, ux, workout-end, swipe-controls]
date: 2026-03-04
category: brainstorm
status: draft
---

# Brainstorm: Watch 유산소 운동 종료 UX 개선

## Problem Statement

현재 Watch 유산소 운동 중 종료/일시정지 버튼이 **5개 세로 페이지 중 4번째(Controls)**에 위치하여, 사용자가 메트릭 3페이지를 스크롤해야 종료할 수 있다. Apple Fitness는 메인 화면에서 **우측 스와이프** 한 번으로 즉시 컨트롤에 접근 가능하며, 이 패턴으로 전환이 필요하다.

### 현재 페이지 구조 (세로 TabView)

| Page | Content |
|------|---------|
| 1. cardioMain | 경과 시간, 거리, 페이스, HR, 칼로리 |
| 2. hrZone | HR Zone 바, 현재/평균 HR |
| 3. cardioSecondary | 활동별 보조 메트릭 (평균 페이스 등) |
| **4. controls** | **종료 + 일시정지 버튼** ← 여기까지 스크롤 필요 |
| 5. nowPlaying | 미디어 컨트롤 |

## Target Users

- Watch 단독 유산소 운동 사용자 (러닝, 사이클링, 수영 등)
- 운동 중 빠르게 종료/일시정지가 필요한 상황 (신호 대기, 운동 완료 등)

## Success Criteria

1. 메인 메트릭 화면에서 **1회 스와이프**로 종료/일시정지 컨트롤 접근
2. 기존 세로 스크롤 메트릭 페이지 탐색에 간섭 없음
3. Apple Fitness 사용자에게 친숙한 인터랙션
4. 오조작으로 인한 의도치 않은 종료 방지 (confirmationDialog 유지)

## Proposed Approach

### 인터랙션 패턴: 우측 스와이프

- 모든 메트릭 페이지에서 **우측 스와이프(leading edge → trailing)**하면 컨트롤 오버레이/페이지 표시
- 컨트롤 화면: **종료 버튼 + 일시정지/재개 버튼** (Apple Fitness 레이아웃)
- 종료 탭 시 기존 `confirmationDialog` 표시 유지

### 페이지 구조 변경

| Before (5 pages) | After (3 pages) |
|---|---|
| 1. cardioMain | 1. cardioMain |
| 2. hrZone | 2. hrZone |
| 3. cardioSecondary | 3. nowPlaying |
| 4. controls ← 제거 | ← 우측 스와이프로 이동 |
| 5. nowPlaying | |

- **Controls 페이지 제거** → 세로 페이지 5→3으로 축소
- cardioSecondary(보조 메트릭)는 기존 유지 여부 검토 필요 (메인 페이지에 통합 가능성)

### 기술 구현 방향

1. `SessionPagingView`에서 cardio 모드의 `.controls` 탭 제거
2. 새로운 `SwipeToControlOverlay` 또는 `horizontalPage` 기반 컨트롤 레이어 추가
3. 가능 옵션:
   - **옵션 A**: `TabView(.horizontalPage)` wrapping — 좌측=컨트롤, 우측=기존 세로 TabView
   - **옵션 B**: Custom `DragGesture` 오버레이 — 우측 스와이프 감지 후 컨트롤 시트 표시
   - **옵션 C**: `.containerRelativeFrame` + `ScrollView(.horizontal)` — 수평 스크롤 내 컨트롤 페이지

## Constraints

- watchOS 세로 TabView 내에서 수평 제스처 충돌 가능성 검토 필요
- Apple Fitness의 정확한 구현은 비공개이므로 유사 UX로 구현
- `SessionPagingView`가 strength 모드와 공유되므로 cardio-only 분기 필요
- 기존 `ControlsView`의 `confirmationDialog` 로직 재사용

## Edge Cases

- **스와이프 중 Digital Crown 조작**: 수평 스와이프와 세로 페이지 전환 동시 발생 방지
- **일시정지 상태에서 스와이프**: 일시정지 중에도 동일하게 동작
- **Always-on Display (저조도)**: 컨트롤 스와이프 비활성화 (현재도 저조도 시 메인 메트릭으로 복귀)
- **NowPlaying 페이지 접근**: Controls 제거 후에도 NowPlaying은 세로 스크롤로 접근 가능

## Scope

### MVP (Must-have)

- 우측 스와이프로 종료/일시정지 컨트롤 접근
- 기존 Controls 세로 페이지 제거
- confirmationDialog 유지
- cardioSecondary 페이지 유지 (별도 통합은 후순위)

### Nice-to-have (Future)

- 스와이프 애니메이션 polish (블러, 스프링 등)
- Haptic feedback on swipe
- Water Lock 기능 통합 (수영 모드)
- cardioSecondary 메트릭을 메인 페이지에 통합하여 2페이지로 축소

## Open Questions

1. watchOS `TabView(.verticalPage)` 내에서 수평 스와이프 제스처가 충돌 없이 동작하는지 PoC 필요
2. cardioSecondary 페이지도 함께 제거하여 메인+NowPlaying 2페이지로 갈 것인지
3. Strength 모드도 동일한 스와이프 패턴을 적용할 것인지 (현재 Controls가 1번째 페이지)

## Next Steps

- [ ] `/plan watch-cardio-end-ux` 로 구현 계획 생성
- [ ] watchOS 수평 스와이프 + 세로 TabView 공존 PoC
