---
topic: watch-popular-recent-carousel
date: 2026-02-28
status: draft
confidence: high
related_solutions:
  - architecture/2026-02-28-watch-ux-enhancement-patterns
  - architecture/2026-02-18-watch-navigation-state-management
  - architecture/2026-02-27-watch-equipment-icon-patterns
related_brainstorms:
  - 2026-02-28-watch-popular-recent-carousel
  - 2026-02-27-watch-ux-renewal
---

# Implementation Plan: Watch Popular/Recent 풀스크린 캐러셀

## Context

현재 Watch 홈(RoutineListView)은 텍스트 리스트 기반으로, Quick Start(Popular/Recent)와 루틴이 분리된 별도 화면에 있다. 사용자가 운동을 시작하려면 최소 2-3탭이 필요하고, 시각적 식별이 어렵다.

**목표**: 루틴 + Popular + Recent를 하나의 풀스크린 캐러셀로 통합. 각 운동/루틴이 화면 전체를 차지하고, 디지털 크라운 스크롤 시 축소 전환 효과로 다음 카드가 진입하는 UX.

## Requirements

### Functional

- F1: 각 카드가 Watch 화면 전체를 차지 (아이콘 + 이름 중앙 배치)
- F2: 디지털 크라운 스크롤 시 현재 카드 축소(0.85) + 다음 카드 진입
- F3: 카드 순서: 루틴(최근 수행순) → Popular(5개) → Recent(5개) → "모든 운동"
- F4: 카드 탭 → WorkoutPreview 네비게이션 (기존 경로 유지)
- F5: 섹션 라벨(Popular/Recent/Routine) 카드 상단 표시
- F6: 운동 카드에 최근 기록 표시 (무게 · 횟수 · N일 전)
- F7: 루틴 카드에 운동 아이콘 배열 + 메타 정보 표시
- F8: "모든 운동" 카드 → QuickStartAllExercisesView 네비게이션

### Non-functional

- NF1: 16장 카드까지 smooth 스크롤 (jank 없음)
- NF2: 기존 WatchRoute 네비게이션 경로 100% 호환
- NF3: DS 토큰(warmGlow, wave background, typography) 일관 적용
- NF4: 신규 사용자(루틴 0, 이력 0)에서도 의미 있는 기본 화면

## Approach

**ScrollView + `.scrollTargetBehavior(.paging)`** 사용 (watchOS 11+).

- `containerRelativeFrame(.vertical)` — 각 카드 풀스크린 사이징
- `scrollTransition` — 축소 + opacity 전환 효과
- `LazyVStack` + `.scrollTargetLayout()` — 메모리 효율적 렌더링

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| TabView(.verticalPage) | watchOS 네이티브, 안정적 | scrollTransition 미지원 → 축소 효과 불가 | **Rejected** |
| ScrollView + paging | scrollTransition 지원, 유연한 커스텀 | iOS 26 시작 index != 0 버그 (workaround 있음) | **Selected** |
| GeometryReader 수동 | 완전한 커스텀 제어 | 구현 복잡, 크라운 직접 처리 | **Rejected** |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNEWatch/Views/CarouselHomeView.swift` | **New** | 통합 캐러셀 홈 뷰 (루틴+Popular+Recent) |
| `DUNEWatch/Views/Components/ExerciseCardView.swift` | **New** | 풀스크린 운동 카드 |
| `DUNEWatch/Views/Components/RoutineCardView.swift` | **Modify** | 풀스크린 루틴 카드로 재설계 |
| `DUNEWatch/ContentView.swift` | **Modify** | idle 상태 root → CarouselHomeView |
| `DUNEWatch/Views/RoutineListView.swift` | **Delete** | 캐러셀에 흡수 |
| `DUNEWatch/Views/QuickStartPickerView.swift` | **Modify** | QuickStartPickerView 삭제, AllExercisesView만 유지 |
| `DUNEWatch/DesignSystem.swift` | **Modify** | 캐러셀 전용 토큰 추가 (typography, spacing) |

## Implementation Steps

### Step 1: CarouselCard 데이터 모델 정의

- **Files**: `DUNEWatch/Views/CarouselHomeView.swift` (상단에 정의)
- **Changes**:
  ```swift
  enum CarouselCardSection: String {
      case routine, popular, recent, allExercises
  }

  struct CarouselCard: Identifiable, Hashable {
      let id: String
      let section: CarouselCardSection
      let content: Content

      enum Content: Hashable {
          case exercise(WatchExerciseInfo)
          case routine(WorkoutSessionTemplate)
          case allExercises
      }
  }
  ```
- **Verification**: 컴파일 확인

### Step 2: ExerciseCardView 생성

- **Files**: `DUNEWatch/Views/Components/ExerciseCardView.swift`
- **Changes**:
  - 풀스크린 레이아웃: VStack(center) { sectionLabel, icon(60pt), name, subtitle }
  - EquipmentIcon.resolve(for:) init-time pre-resolve (Correction #162)
  - subtitle: "80kg · 10reps · 2일 전" (RecentExerciseTracker.latestSet + lastUsed)
  - WatchWaveBackground 배경
  - DS.Typography.exerciseName (headline.bold) for name
  - DS.Typography.metricLabel (caption2) for subtitle
- **Verification**: #Preview에서 단독 카드 렌더 확인

### Step 3: RoutineCardView 풀스크린으로 재설계

- **Files**: `DUNEWatch/Views/Components/RoutineCardView.swift`
- **Changes**:
  - 풀스크린 레이아웃: VStack(center) { sectionLabel, iconStrip(4개), name, metaInfo }
  - 아이콘 배열: 최대 4개 장비 아이콘 (36pt each, HStack)
  - 메타 정보: "4종목 · 16세트 · ~45분"
  - 기존 TemplateCardView 로직 재활용 (meta 계산)
- **Verification**: #Preview에서 단독 카드 렌더 확인

### Step 4: CarouselHomeView 구현

- **Files**: `DUNEWatch/Views/CarouselHomeView.swift`
- **Changes**:
  ```swift
  struct CarouselHomeView: View {
      @Query(sort: \WorkoutTemplate.updatedAt, order: .reverse)
      private var templates: [WorkoutTemplate]
      @Environment(WatchConnectivityManager.self) private var connectivity

      @State private var cards: [CarouselCard] = []

      var body: some View {
          ScrollView(.vertical) {
              LazyVStack(spacing: 0) {
                  ForEach(cards) { card in
                      cardView(for: card)
                          .containerRelativeFrame(.vertical)
                  }
              }
              .scrollTargetLayout()
          }
          .scrollTargetBehavior(.paging)
          .scrollTransition { content, phase in
              content
                  .scaleEffect(phase.isIdentity ? 1.0 : 0.85)
                  .opacity(phase.isIdentity ? 1.0 : 0.6)
          }
      }
  }
  ```
  - `rebuildCards()`: 루틴 → Popular(5) → Recent(5) → AllExercises 순서 조합
  - `@State cards` + `onChange(of: templates.count)` + `onChange(of: connectivity.exerciseLibrary.count)` 무효화 (Correction #47, #87)
  - cardView(for:) switch → ExerciseCardView / RoutineCardView / AllExercisesCard
- **Verification**: 시뮬레이터에서 크라운 스크롤 + 축소 효과 확인

### Step 5: ContentView 라우팅 변경

- **Files**: `DUNEWatch/ContentView.swift`
- **Changes**:
  - idle 상태 root: `RoutineListView()` → `CarouselHomeView()`
  - `.quickStart` route 삭제 (더 이상 별도 화면 불필요)
  - `.quickStartAll` route 유지 ("모든 운동" 카드 목적지)
  - WatchRoute에서 `.quickStart` case 제거
- **Verification**: 앱 실행 → 캐러셀 홈 표시 확인

### Step 6: RoutineListView 삭제 + QuickStartPickerView 정리

- **Files**:
  - `DUNEWatch/Views/RoutineListView.swift` — 삭제
  - `DUNEWatch/Views/QuickStartPickerView.swift` — QuickStartPickerView 제거, QuickStartAllExercisesView만 유지
- **Changes**:
  - QuickStartPickerView 코드 삭제 (캐러셀에 흡수)
  - file-scope helper 함수(`exerciseSubtitle`, `uniqueByCanonical`, `snapshotFromExercise`) → CarouselHomeView 또는 Shared helper로 이동
  - QuickStartAllExercisesView는 그대로 유지 (카테고리 브라우징 + 검색)
- **Verification**: 빌드 성공 + dead code 없음

### Step 7: DS 토큰 추가 + 시각 조정

- **Files**: `DUNEWatch/DesignSystem.swift`
- **Changes**:
  - `DS.Typography.cardTitle` — `.title3.bold()` (카드 중앙 운동 이름)
  - `DS.Typography.cardSubtitle` — `.caption.weight(.medium)` (최근 기록)
  - `DS.Typography.sectionBadge` — `.caption2.weight(.semibold)` (섹션 라벨)
  - `DS.Spacing.cardIconSize: CGFloat = 60` — 카드 아이콘 크기
  - `DS.Animation.cardSnap` — `.spring(duration: 0.3, bounce: 0.1)` (스크롤 snap)
- **Verification**: 토큰 적용 후 시각적 일관성 확인

### Step 8: 빈 상태 + 엣지 케이스 처리

- **Files**: `DUNEWatch/Views/CarouselHomeView.swift`
- **Changes**:
  - 루틴 0개 + 이력 0: 기본 추천 5개 (Bench/Squat/Deadlift/OHP/Pull-up) + "모든 운동"
  - 라이브러리 미동기화: "iPhone과 동기화 필요" 단일 카드
  - 카드 1장: 스크롤 불필요, 풀스크린 고정
  - Popular/Recent에 최근 기록 없는 운동: subtitle 생략, 아이콘+이름만
- **Verification**: 각 엣지 케이스 시뮬레이터에서 수동 확인

### Step 9: 빌드 검증 + 최종 정리

- **Files**: 전체
- **Changes**:
  - `scripts/build-ios.sh` 실행 (Correction #95)
  - Watch 빌드: `xcodebuild -scheme DailveWatch -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=26.2'`
  - dead code 확인 + 삭제된 파일 참조 정리
  - xcodegen generate (새 파일 추가/삭제 반영)
- **Verification**: iOS + watchOS 빌드 모두 성공

## Edge Cases

| Case | Handling |
|------|----------|
| 루틴 0개 + 이력 0 (신규 사용자) | 기본 추천 운동 5개 Popular 카드 + "모든 운동" 카드 |
| 운동 라이브러리 미동기화 | "iPhone과 동기화 필요" 안내 카드 1장 |
| 카드 1장만 존재 | 스크롤 비활성화, 풀스크린 고정 |
| 긴 운동 이름 (2줄+) | `.lineLimit(1)` + `.truncationMode(.tail)` |
| 최근 기록 없는 운동 | subtitle 줄 생략 (아이콘+이름만) |
| bodyweight 운동 (weight=0) | "0kg" 표시 금지, sets·reps만 (Correction #170) |
| iOS 26 paging 시작 index 버그 | `.scrollPosition(id:)` + `.onAppear` workaround |
| 운동 중 홈 복귀 시 | ContentView가 SessionPagingView 표시 (캐러셀 미노출) |

## Testing Strategy

- **Unit tests**: CarouselCard 생성 로직, 카드 순서 알고리즘, 빈 상태 fallback
- **Manual verification**:
  - 시뮬레이터 크라운 스크롤 → 축소/확대 전환 효과
  - 카드 탭 → WorkoutPreview 네비게이션
  - "모든 운동" → AllExercisesView 네비게이션
  - 운동 완료 후 Popular/Recent 순서 변경 반영
  - 루틴 0개 / 이력 0 / 라이브러리 미동기화 각각 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| scrollTransition watchOS 26 렌더링 성능 | Low | Medium | LazyVStack으로 visible 카드만 렌더. 16장 이내 제한 |
| iOS 26 paging 시작 index != 0 버그 | Medium | Low | `.scrollPosition(id:)` workaround 적용 |
| RoutineListView 삭제 시 누락 기능 | Low | High | 삭제 전 기능 체크리스트 대조 (sync status, empty state) |
| 크라운 스크롤 vs 터치 스크롤 물리 차이 | Low | Low | 실기기 테스트로 snap 강도 조정 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**:
  - watchOS 26 ScrollView paging API는 잘 문서화되어 있고, 기존 SessionPagingView에서 유사 패턴(TabView paging) 사용 경험 있음
  - 데이터 소스(RecentExerciseTracker, @Query templates)는 변경 없이 재활용
  - 네비게이션(WatchRoute)은 기존 경로 유지, `.quickStart` case만 제거
  - DS 토큰 이미 Watch에 구축되어 있어 시각적 일관성 보장
