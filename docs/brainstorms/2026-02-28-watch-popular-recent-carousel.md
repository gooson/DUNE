---
tags: [watch, watchos, ux, carousel, popular, recent, quick-start, routine, digital-crown]
date: 2026-02-28
category: brainstorm
status: draft
---

# Brainstorm: Watch Popular/Recent 풀스크린 캐러셀 UX

## Problem Statement

현재 Watch Quick Start의 Popular/Recent는 **텍스트 리스트**로 구성되어:
- 운동 식별에 텍스트 읽기가 필요 (시각적 즉각 인지 불가)
- 작은 행(row)에 여러 정보가 압축 → 눈에 잘 들어오지 않음
- Routine(템플릿)과 Quick Start가 분리된 별도 화면 → 전환 비용

**목표**: 각 운동이 화면 전체를 차지하고, 디지털 크라운 스크롤 시 축소되면서 다음 카드가 나타나는 **풀스크린 캐러셀** UX. Routine과 Quick Start를 하나의 스크롤 흐름으로 통합.

## Reference: 사용자 제안 패턴

첨부 이미지 (필라테스 운동 화면) 참조:
- 화면 중앙에 **운동 아이콘 (대형)** + **운동 이름** 상하 배치
- 배경은 어두운 그라데이션
- 크라운 스크롤 시작 → 현재 카드가 **약간 축소** → 위아래로 다음 카드 노출
- 화면 상단/하단에 부가 UI 배치 가능 (시계, 버튼 등)

## Target Users

- 헬스장에서 Watch만 착용하고 운동하는 사용자
- 자주 하는 운동 3-5개를 빠르게 시작하고 싶은 사용자
- 시각적으로 운동을 식별하고 싶은 사용자

## Success Criteria

1. **운동 선택 → 시작까지 2초 이내**: 크라운 1-2회 회전 + 탭
2. **텍스트 읽기 없이 운동 식별**: 아이콘만으로 "아 벤치프레스" 인지
3. **Routine + Quick Start 통합**: 한 화면에서 모든 시작 경로 접근
4. **레이아웃 안정성**: 크라운 스크롤 시 jank/jump 없이 부드러운 전환

## Proposed Design

### 1. 통합 홈 — 캐러셀 구조

```
┌─────────────────────────┐
│        01:44         ⟲  │  ← 상단: 시계 + 상태 아이콘
│                         │
│                         │
│         🏋️ (대형)       │  ← 중앙: 운동 아이콘 (60-80pt)
│                         │
│      바벨 벤치프레스      │  ← 운동 이름 (centered)
│     80kg · 3×10 · 2일전  │  ← 최근 기록 (secondary)
│                         │
│  [🔇]    [▶ START]  [⚙] │  ← 하단: 액션 버튼
└─────────────────────────┘
```

**크라운 스크롤 시**:
```
┌─────────────────────────┐
│        01:44         ⟲  │
│  ┌───────────────────┐  │
│  │    🏋️ (축소)      │  │  ← 현재 카드 축소 (scale 0.85)
│  │  바벨 벤치프레스    │  │
│  │  80kg · 3×10      │  │
│  └───────────────────┘  │
│  ┌───────────────────┐  │
│  │    🦵 (다음)       │  │  ← 다음 카드 진입
│  │   바벨 스쿼트      │  │
│  └───────────────────┘  │
└─────────────────────────┘
```

### 2. 카드 유형 3가지

#### A. 운동 카드 (Popular/Recent)
- **아이콘**: 장비 기반 커스텀 일러스트 (60pt, warmGlow tint)
- **이름**: `.title3.bold`, 1줄 truncation
- **부가 정보**: "80kg · 3×10 · 2일 전" (최근 기록이 있을 때만)
- **액션**: 탭 → 즉시 WorkoutPreview (세트 확인 후 시작)

#### B. 루틴 카드 (Template)
- **아이콘**: 운동 아이콘 3-4개 가로 배열 (36pt each)
- **이름**: 루틴 이름 `.title3.bold`
- **부가 정보**: "4종목 · 16세트 · ~45분"
- **액션**: 탭 → WorkoutPreview (전체 운동 목록)

#### C. "모든 운동" 카드 (마지막)
- **아이콘**: `plus.circle.fill` SF Symbol (60pt)
- **이름**: "모든 운동 보기"
- **액션**: 탭 → QuickStartAllExercisesView (기존 카테고리/검색)

### 3. 카드 순서 알고리즘

```
[루틴 카드들 (최근 수행순)] → [Popular 운동 (사용 빈도순, 최대 5개)]
→ [Recent 운동 (최근 사용순, Popular 제외, 최대 5개)] → [모든 운동 카드]
```

- **루틴 우선**: 루틴 사용자는 첫 화면에서 바로 시작
- **신규 사용자**: 루틴 0개 → Popular부터 시작 (사용 이력 없으면 기본 추천)
- **총 카드 수**: 루틴(0-5) + Popular(3-5) + Recent(0-5) + 모든 운동(1) = 최대 16장

### 4. 구현 접근: watchOS ScrollView + paging

**옵션 A: TabView(.verticalPage)** (watchOS 10+)
```swift
TabView {
    ForEach(cards) { card in
        ExerciseCardView(card: card)
    }
}
.tabViewStyle(.verticalPage)
```
- 장점: 네이티브 페이징, Digital Crown 자동 지원
- 단점: 축소 효과(scale transition) 커스텀 어려움

**옵션 B: ScrollView + scrollTargetBehavior(.paging)** (watchOS 11+)
```swift
ScrollView(.vertical) {
    LazyVStack(spacing: 0) {
        ForEach(cards) { card in
            ExerciseCardView(card: card)
                .containerRelativeFrame(.vertical)
        }
    }
    .scrollTargetLayout()
}
.scrollTargetBehavior(.paging)
```
- 장점: `scrollTransition`으로 축소 효과 구현 가능
- 단점: watchOS 11(iOS 26)+ 필요 (우리 타겟과 일치)

**옵션 C: GeometryReader + 수동 스크롤**
- 장점: 완전한 커스텀 제어
- 단점: 구현 복잡, 크라운 이벤트 직접 처리 필요

**추천: 옵션 B** — iOS 26+ 타겟이므로 최신 API 활용. `scrollTransition` modifier로 축소/opacity 전환 자연스럽게 구현.

### 5. 스크롤 전환 효과

```swift
.scrollTransition { content, phase in
    content
        .scaleEffect(phase.isIdentity ? 1.0 : 0.85)
        .opacity(phase.isIdentity ? 1.0 : 0.6)
}
```

- **현재 카드**: scale 1.0, opacity 1.0
- **이전/다음 카드**: scale 0.85, opacity 0.6
- **전환**: 스프링 애니메이션 (.snappy)

### 6. 섹션 구분 인디케이터

캐러셀에서 "지금 Popular인지 Recent인지 Routine인지" 알 수 있도록:

**방안 A: 상단 라벨** — 현재 카드의 섹션을 상단에 표시
```
★ Popular        (warmGlow)
📁 Push Day      (accent)
🕐 Recent        (secondary)
```

**방안 B: 배경 색상 힌트** — 섹션별 미묘한 배경 gradient 차이
- Routine: warm gradient (기존 DS)
- Popular: amber tint
- Recent: neutral

**추천: 방안 A** — 명확하고 구현 단순

## Constraints

### 기술적 제약
- **watchOS 26 필수**: `scrollTargetBehavior(.paging)` + `containerRelativeFrame` 사용
- **메모리**: LazyVStack이므로 16장 카드는 문제없음 (visible + buffer만 렌더)
- **Digital Crown**: `.scrollTargetBehavior(.paging)`에서 자동 처리
- **운동 아이콘**: 기존 Equipment Asset Catalog 재활용 (Correction #159 namespace 필수)

### UX 제약
- 풀스크린 카드 = 한 번에 1개만 보임 → 빠른 스캔이 어려울 수 있음
- 16장 카드 = 크라운 16회 회전 → 끝까지 도달 시간 (mitigation: "모든 운동"을 마지막에 배치)
- 터치 스크롤도 지원해야 함 (크라운만이 아님)

## Edge Cases

| 시나리오 | 대응 |
|---------|------|
| 루틴 0개 + 사용 이력 0 | 기본 추천 운동 5개 (Bench/Squat/Deadlift/OHP/Pull-up) + "모든 운동" |
| 운동 라이브러리 미동기화 | "iPhone과 동기화 필요" 단일 카드 표시 |
| 카드 1장뿐 | 스크롤 비활성화, 풀스크린 고정 |
| 긴 운동 이름 | `.lineLimit(1)` + `.truncationMode(.tail)` |
| 최근 기록 없는 Popular 운동 | 부가 정보 줄 생략, 아이콘+이름만 |
| 루틴 내 운동이 아이콘 없음 | generic SF Symbol fallback |
| 스크롤 중 탭 | 가장 가까운 카드로 snap 후 액션 무시 (의도치 않은 시작 방지) |

## Scope

### MVP (Must-have)
- [ ] 풀스크린 캐러셀 레이아웃 (ScrollView + paging)
- [ ] 운동 카드 (아이콘 중앙 + 이름 + 최근 기록)
- [ ] 루틴 카드 (아이콘 배열 + 메타 정보)
- [ ] "모든 운동" 카드 (마지막)
- [ ] 섹션 라벨 (Popular/Recent/Routine 구분)
- [ ] 스크롤 전환 효과 (축소 + opacity)
- [ ] 카드 탭 → WorkoutPreview 네비게이션

### Nice-to-have (Future)
- [ ] 요일/시간대 기반 스마트 정렬 (월요일에는 가슴 루틴 상위)
- [ ] 마지막 세트 PR 배지 (🏆 표시)
- [ ] 카드 롱프레스 → Quick Edit (세트 수/무게 조절)
- [ ] Haptic feedback on card snap
- [ ] 카드 순서 커스텀 (Watch에서 드래그)

## 기존 코드 영향 분석

| 파일 | 변경 내용 |
|------|----------|
| `DUNEWatch/Views/RoutineListView.swift` | **삭제 or 대폭 축소** — 캐러셀 통합 |
| `DUNEWatch/Views/QuickStartPickerView.swift` | **전면 재설계** — 캐러셀 뷰로 교체 |
| `DUNEWatch/ContentView.swift` | 홈 화면 라우팅 변경 |
| `DUNEWatch/Managers/RecentExerciseTracker.swift` | 기존 유지 (인터페이스 동일) |
| `DUNEWatch/Views/Components/ExerciseTileView.swift` | **신규 ExerciseCardView** 생성 |
| `DUNEWatch/Views/Components/RoutineCardView.swift` | **신규** 루틴 카드 뷰 |

## Open Questions

1. **카드 최대 수 제한**: Popular 5 + Recent 5가 적절한가? 더 줄여야 하나?
2. **탭 동작**: 탭 → 즉시 시작 vs 탭 → Preview → 시작 (현재 Preview 경유)
3. **빈 상태 디자인**: 신규 사용자 첫 경험에서 어떤 기본 추천을 보여줄지

## Related Documents

- `docs/brainstorms/2026-02-27-watch-ux-renewal.md` — Watch UX 전면 리뉴얼 (아이콘 체계, DS 통일)
- `docs/brainstorms/2026-02-18-watch-first-workout-ux.md` — Watch-First Workout UX
- `docs/brainstorms/2026-02-18-watch-design-overhaul.md` — Watch 디자인 전면 수정

## Next Steps

- [ ] `/plan watch-popular-recent-carousel` 로 구현 계획 생성
- [ ] watchOS ScrollView paging + scrollTransition 프로토타입
- [ ] 루틴 + Popular + Recent 통합 데이터 소스 설계
