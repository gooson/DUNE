---
tags: [watch, ux, set-input, navigation]
date: 2026-02-28
category: plan
status: draft
---

# Plan: Watch SetInputSheet — Previous Sets를 Toolbar 버튼으로 이동

## Summary

SetInputSheet에서 Previous Sets 히스토리를 상단 인라인 표시에서 좌상단 toolbar 버튼 → push navigation으로 변경. 무게 입력이 항상 최상단에 위치하도록 개선.

## Before / After

### Before
```
┌──────────────────────┐
│ Previous Sets        │ ← 세트 수만큼 길어짐
│  Set 1  60.0kg ×10  │
│  Set 2  60.0kg ×10  │
│ ──────────────────── │
│      62.5  kg        │ ← 스크롤 필요
│  [-2.5]    [+2.5]    │
│ ──────────────────── │
│  [-]   8 reps   [+]  │
│              [Done]  │
└──────────────────────┘
```

### After
```
┌──────────────────────┐
│ [🕐]          [Done] │ ← 좌상단 히스토리 버튼
│      62.5            │ ← 무게가 항상 최상단
│       kg             │
│  [-2.5]    [+2.5]    │
│ ──────────────────── │
│  [-]   8 reps   [+]  │
└──────────────────────┘

[🕐] 탭 시 push:
┌──────────────────────┐
│ < Back               │
│ Previous Sets        │
│  Set 1  60.0kg ×10  │
│  Set 2  62.5kg ×8   │
│  Set 3  60.0kg ×10  │
└──────────────────────┘
```

## Affected Files

| File | Action | Description |
|------|--------|-------------|
| `DUNEWatch/Views/SetInputSheet.swift` | Modify | NavigationStack 래핑, toolbar 버튼 추가, previousSetHistory를 별도 destination으로 분리 |

## Implementation Steps

### Step 1: SetInputSheet에 NavigationStack 래핑

- `body`의 `ScrollView`를 `NavigationStack`으로 감싸기
- 기존 `.toolbar`의 "Done" 버튼 유지 (`.confirmationAction`)

### Step 2: Previous Sets 인라인 표시 제거 + toolbar 버튼 추가

- `if !previousSets.isEmpty { previousSetHistory; Divider() }` 제거
- `.topBarLeading`에 히스토리 아이콘 버튼 추가
- 아이콘: `"list.bullet.clipboard"` (세트 기록 느낌)
- `previousSets`가 비어있으면 버튼 숨김

### Step 3: NavigationDestination으로 Previous Sets 화면 추가

- `@State private var showPreviousSets = false`
- `.navigationDestination(isPresented:)` 으로 push
- 기존 `previousSetHistory` computed property를 재활용하여 별도 View로 구성

### Step 4: Digital Crown / focusable 위치 조정

- `.focusable()`, `.digitalCrownRotation()` 이 NavigationStack 내부에서 정상 동작하는지 확인
- NavigationStack 래핑 후 modifier 순서 조정 필요할 수 있음

## Constraints

- watchOS sheet 내부 NavigationStack은 지원됨 (iOS의 sheet + NavigationStack 패턴과 동일)
- `.topBarLeading` placement가 watchOS에서 지원되는지 빌드로 검증 필요
- Digital Crown은 무게 입력에 바인딩되어 있으므로 push 화면에서는 스크롤용으로 자동 전환

## Correction Log 관련 항목

- #147: SVG body diagram 위 DragGesture 금지 → 해당 없음
- #172: body에서 UserDefaults 접근 금지 → previousSets는 외부에서 주입, OK
- #142: 최소 노출 타이머 CancellationError → 해당 없음

## Risk

- **Low**: NavigationStack 래핑이 Digital Crown rotation에 영향을 줄 수 있음 → 빌드 테스트로 확인
- **Low**: `.topBarLeading` 이 watchOS에서 렌더되지 않을 수 있음 → fallback으로 `.cancellationAction` 사용
