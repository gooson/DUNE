---
tags: [watch, cardio, ux, swipe-controls, session-paging]
date: 2026-03-04
category: plan
status: draft
---

# Plan: Watch 유산소 운동 종료 UX — 우측 스와이프 컨트롤

## 개요

유산소 운동 중 종료/일시정지 버튼을 **우측 스와이프**로 즉시 접근 가능하도록 변경.
Apple Fitness 패턴: 메인 메트릭 화면에서 우측 스와이프 → 컨트롤 화면.

## 핵심 변경

| 항목 | Before | After |
|------|--------|-------|
| 컨트롤 접근 | 세로 4번째 페이지 스크롤 | 우측 스와이프 1회 |
| 페이지 구성 (Cardio) | 5페이지 (Main→HRZone→Secondary→Controls→NowPlaying) | 좌우 2페이지 (Controls ← 스와이프 → 세로 3페이지) |
| 종료 확인 | confirmationDialog | confirmationDialog (유지) |

## 기술 구현

### 접근 방식: 수평 TabView 래핑

watchOS 기본 `TabView` 스타일은 **수평 페이지**. `.verticalPage`는 명시 지정 시만 세로.

```
[Controls] ←→ [Vertical TabView: Main | HRZone | Secondary | NowPlaying]
   (좌)              (우, 기본)
```

- 외부: 수평 `TabView` (기본 스타일) — 2페이지
- 내부 (우측): 세로 `TabView(.verticalPage)` — 기존 메트릭 페이지
- 기본 선택: 우측 (메트릭)

### Strength 모드 영향 없음

Strength는 현재 Controls가 1번째 페이지(세로). 변경 범위는 **cardio 모드만**.

## Affected Files

| File | Action | 설명 |
|------|--------|------|
| `DUNEWatch/Views/SessionPagingView.swift` | **Major Edit** | Cardio: 수평 TabView 래퍼 추가, Controls 탭 제거 |
| `DUNEWatch/Views/CardioControlsView.swift` | **New** | 카디오 전용 컨트롤 (End + Pause/Resume) |
| `DUNEWatch/Views/ControlsView.swift` | Minor Edit | Strength 전용으로 정리 (cardio 분기 제거) |

## Implementation Steps

### Step 1: CardioControlsView 생성

- `ControlsView`에서 cardio 전용 로직 추출
- End 버튼 + confirmationDialog + Pause/Resume 버튼
- Skip 버튼 불필요 (cardio에는 exercise list 없음)

### Step 2: SessionPagingView 수정 — Cardio 모드

- Cardio: 수평 TabView(기본 스타일) 래퍼 적용
  - 좌: `CardioControlsView`
  - 우: 세로 `TabView(.verticalPage)` with Main, HRZone, Secondary, NowPlaying
- 기본 selection: 우측 (메트릭 페이지)
- Always-on display: selectedTab을 `.cardioMain`으로 복귀 (기존 동작 유지)

### Step 3: ControlsView 정리

- Cardio 분기 코드 제거 (`isCardioMode` 체크)
- Strength 전용으로 단순화

### Step 4: 빌드 검증

- `scripts/build-ios.sh` 빌드 통과 확인
