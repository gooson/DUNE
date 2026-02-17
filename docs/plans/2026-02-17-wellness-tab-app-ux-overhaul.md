---
topic: Wellness 탭 통합 & 앱 전체 UX 개편
date: 2026-02-17
status: draft
confidence: high
related_solutions:
  - general/2026-02-17-chart-ux-layout-stability.md
related_brainstorms:
  - 2026-02-17-wellness-tab-app-ux-overhaul.md
  - 2026-02-16-dashboard-ux-redesign.md
---

# Implementation Plan: Wellness 탭 통합 & 앱 전체 UX 개편

## Context

현재 Dailve 앱은 4탭(Condition / Activity / Sleep / Body)으로 구성되어 있다. Sleep 탭(카드 3개)과 Body 탭(카드 3개+Form)이 각각 얇은 콘텐츠로 독립 탭을 차지한다. 수면과 체성분은 "회복/웰니스"의 두 축으로 밀접하게 연관되지만, 별도 탭에서 분리되어 사용자가 왔다갔다해야 한다.

### 핵심 변경
- **4탭 → 3탭**: Sleep + Body를 **Wellness** 탭으로 통합
- **탭 리네이밍**: Condition → **Today**, Activity → **Train**
- **앱 전체 UX 일관성**: 3탭 전체의 디자인 패턴 통일
- **레퍼런스**: Oura(고급감) + Apple Health(정보밀도) + WHOOP(데이터집약) + Bear(따뜻한 여백)

### 이전 작업과의 관계
- `docs/plans/2026-02-16-ui-ux-redesign.md`: 디자인 시스템 기반(DesignSystem.swift, 카드 컴포넌트, Empty State, 적응형 그리드) — **이미 구현 완료**
- `docs/brainstorms/2026-02-16-dashboard-ux-redesign.md`: Dashboard 개선 계획 — 일부 구현됨 (ScoreContributors, Skeleton, 섹션 그룹핑)
- 이번 플랜은 위 작업 위에 **탭 구조 변경 + Wellness 통합 + 전체 일관성**을 추가

## Requirements

### Functional

1. 4탭 → 3탭 전환 (Today / Train / Wellness)
2. Wellness 탭: Single Scroll로 수면+체성분 통합
3. SleepHeroCard: Score ring + Duration + Efficiency + Stage를 하나의 카드로 압축
4. BodySnapshotCard: 최신값 + 7일 변화량 표시
5. Body 히스토리: 상세 화면(BodyHistoryDetailView)으로 분리
6. Body 입력: 현재 Form Sheet 유지 (toolbar + 버튼)
7. Today 탭: Sleep/Weight 미니카드 → Wellness 탭 교차 참조 (Phase 2)
8. Train 탭: 리네이밍만, 구조 유지

### Non-functional

- 모든 탭에서 일관된 카드 스타일, 배경 그라디언트, Empty State 패턴
- Dynamic Type 전 단계 지원
- iPad sizeClass 대응 (기존 `.sidebarAdaptable` 유지)
- Wellness 탭 데이터 로딩: Sleep + Body 병렬 fetch (async let)
- 60fps 스크롤 유지

## Approach

**점진적 마이그레이션** — 기존 SleepView/BodyCompositionView의 카드 컴포넌트를 재사용하면서 WellnessView라는 새 컨테이너에 조합한다. ViewModel은 기존 것을 그대로 사용하고, 새 WellnessViewModel은 두 VM의 로딩을 조율하는 coordinator 역할만 한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| **WellnessView가 기존 VM 2개를 직접 소유** | 간단, 기존 코드 변경 최소 | WellnessView가 비대해질 수 있음 | **채택** |
| WellnessViewModel이 모든 데이터를 관리 | 단일 VM, 깔끔한 인터페이스 | SleepVM/BodyVM 중복 코드, 마이그레이션 비용 | 기각 |
| Segmented Picker (Sleep \| Body) | 각 섹션 독립적, 익숙한 패턴 | 정보 분산 유지, Single Scroll 결정에 위배 | 기각 |
| 기존 SleepView/BodyCompositionView를 embed | 코드 변경 0 | 중복 NavigationTitle, 불필요한 Empty State, 일관성 부재 | 기각 |

## Affected Files

### 신규 생성

| File | Description |
|------|-------------|
| `Presentation/Wellness/WellnessView.swift` | 통합 탭 root view (Single Scroll) |
| `Presentation/Wellness/Components/SleepHeroCard.swift` | 수면 점수+스테이지 통합 카드 |
| `Presentation/Wellness/Components/BodySnapshotCard.swift` | 체성분 최신값+변화 카드 |
| `Presentation/Wellness/BodyHistoryDetailView.swift` | 체성분 히스토리 상세 화면 (push destination) |

### 수정

| File | Change Type | Description |
|------|-------------|-------------|
| `App/AppSection.swift` | MODIFY | `.sleep`+`.body` 제거, `.wellness` 추가, 리네이밍 |
| `App/ContentView.swift` | MODIFY | 4탭→3탭, 새 View 연결 |
| `Presentation/Sleep/SleepView.swift` | KEEP | 그대로 유지 (WellnessView에서 카드 추출 사용) |
| `Presentation/Sleep/SleepViewModel.swift` | KEEP | 그대로 유지 (WellnessView에서 소유) |
| `Presentation/BodyComposition/BodyCompositionView.swift` | KEEP | Form Sheet 재사용, 히스토리 섹션 추출 |
| `Presentation/BodyComposition/BodyCompositionViewModel.swift` | KEEP | 그대로 유지 (WellnessView에서 소유) |
| `Presentation/Dashboard/DashboardView.swift` | MODIFY | navigationTitle "Today"로 변경 |
| `Presentation/Activity/ActivityView.swift` | MODIFY | navigationTitle "Train"으로 변경 |

### 삭제 없음

기존 Sleep/BodyComposition 디렉토리는 유지. WellnessView가 해당 ViewModel과 카드 컴포넌트를 import하여 사용.

## Implementation Steps

### Phase 1: 탭 구조 변경 (뼈대)

#### Step 1: AppSection enum 수정

- **Files**: `App/AppSection.swift`
- **Changes**:
  - `case dashboard` → `case today` (title: "Today", icon: `"heart.text.clipboard"`)
  - `case exercise` → `case train` (title: "Train", icon: `"flame"`)
  - `case sleep` + `case body` 제거
  - `case wellness` 추가 (title: "Wellness", icon: `"leaf.fill"`)
- **Verification**: 빌드 성공, 컴파일러가 모든 switch exhaustiveness 에러를 잡아줌

#### Step 2: ContentView 탭 구조 변경

- **Files**: `App/ContentView.swift`
- **Changes**:
  - Sleep 탭, Body 탭 제거
  - Wellness 탭 추가: `Tab(AppSection.wellness.title, ...) { NavigationStack { WellnessView() } }`
  - Dashboard 탭의 AppSection 참조를 `.today`로 변경
  - Activity 탭의 AppSection 참조를 `.train`으로 변경
- **Verification**: 앱 실행 시 3탭 표시, 각 탭 네비게이션 정상

#### Step 3: DashboardView/ActivityView navigationTitle 변경

- **Files**: `DashboardView.swift`, `ActivityView.swift`
- **Changes**:
  - DashboardView: `.navigationTitle("Dailve")` → `.navigationTitle("Today")`
  - ActivityView: `.navigationTitle("Activity")` → `.navigationTitle("Train")`
- **Verification**: 각 탭 진입 시 새 타이틀 확인

### Phase 2: WellnessView 구현

#### Step 4: WellnessView 기본 구조

- **Files**: `Presentation/Wellness/WellnessView.swift` (신규)
- **Changes**:
  ```
  WellnessView
  ├── @State sleepViewModel = SleepViewModel()
  ├── @State bodyViewModel = BodyCompositionViewModel()
  ├── @Environment(\.modelContext)
  ├── @Query(sort: \BodyCompositionRecord.date, order: .reverse) records
  │
  ├── .task { async let + 병렬 로딩 }
  ├── .refreshable { 병렬 리로드 }
  ├── .navigationTitle("Wellness")
  │
  ├── ScrollView
  │   ├── [Loading] WellnessSkeletonView
  │   ├── [Empty] EmptyStateView (둘 다 없을 때)
  │   ├── Sleep Section
  │   │   ├── Section Header "Sleep"
  │   │   ├── SleepHeroCard (Step 5에서 구현)
  │   │   └── SleepTrendCard (기존 weeklyTrendCard 재사용)
  │   ├── Body Section
  │   │   ├── Section Header "Body"
  │   │   ├── BodySnapshotCard (Step 6에서 구현)
  │   │   ├── WeightTrendChart (기존 weightTrendChart 재사용)
  │   │   └── NavigationLink "View All Records"
  │   └── Quick Actions
  │       └── "Add Body Record" 버튼
  │
  ├── .toolbar { + 버튼 (Body 입력) }
  ├── .sheet (Add/Edit BodyCompositionFormSheet — 기존 재사용)
  └── .navigationDestination(for: BodyHistoryDestination.self)
  ```
- **Verification**: 앱 실행 → Wellness 탭 → Sleep/Body 데이터 모두 로드 확인

#### Step 5: SleepHeroCard 구현

- **Files**: `Presentation/Wellness/Components/SleepHeroCard.swift` (신규)
- **Changes**:
  - 기존 SleepView의 `sleepScoreCard` + `stageBreakdownCard`를 **하나의 카드**로 합침
  - 좌측: ProgressRingView (수면 점수, DS.Color.sleep 사용)
  - 우측: Total duration + Efficiency
  - 하단: Stage horizontal bar + 축약 범례 (Deep/Core/REM/Awake)
  - `StandardCard` 래퍼 사용
  - 입력: `sleepScore: Int`, `totalMinutes: Double`, `efficiency: Double`, `stageBreakdown: [StageBreakdownItem]`
- **Verification**: Preview에서 다양한 데이터 상태 확인 (정상, 0점, stage 없음)

#### Step 6: BodySnapshotCard 구현

- **Files**: `Presentation/Wellness/Components/BodySnapshotCard.swift` (신규)
- **Changes**:
  - 기존 `latestValuesCard`를 개선
  - 3열: Weight / Body Fat / Muscle Mass
  - 각 항목: 최신값 + 단위 + 7일 전 대비 변화 (▲/▼/—)
  - 변화 방향에 따라 `DS.Color.positive` / `DS.Color.negative` / `.secondary`
  - 소스 표시 (HealthKit heart.fill / Manual)
  - `StandardCard` 래퍼 사용
  - 입력: `latestItem: BodyCompositionListItem`, `previousItem: BodyCompositionListItem?`
- **Verification**: Preview에서 변화 있음/없음/데이터 부분 누락 케이스 확인

#### Step 7: BodyHistoryDetailView 구현

- **Files**: `Presentation/Wellness/BodyHistoryDetailView.swift` (신규)
- **Changes**:
  - 기존 `BodyCompositionView.historySection` + `historyRow` 로직을 이동
  - `@Query` records 사용
  - `@Environment(\.modelContext)` for delete
  - Context menu: Edit + Delete
  - Edit 시 `bodyViewModel.startEditing(record)` + sheet 표시
  - NavigationTitle: "Body Records"
- **Verification**: 레코드 목록 표시, Edit/Delete 동작 확인

### Phase 3: 디자인 일관성

#### Step 8: Wellness 탭 배경 그라디언트 + Empty States

- **Files**: `WellnessView.swift`
- **Changes**:
  - `.background { LinearGradient(colors: [DS.Color.sleep.opacity(0.03), .clear], ...) }`
  - Sleep 데이터 없음: 섹션 내 mini EmptyState ("Wear Apple Watch to bed")
  - Body 데이터 없음: 섹션 내 mini EmptyState ("Add your first record")
  - 둘 다 없음: 전체 EmptyStateView
- **Verification**: 각 Empty State 조합 4가지 확인 (둘다있음, Sleep만, Body만, 둘다없음)

#### Step 9: SleepTrendCard 개선

- **Files**: `WellnessView.swift` 내부 또는 별도 컴포넌트
- **Changes**:
  - 기존 SleepView의 `weeklyTrendCard` 로직 재사용
  - 하단에 "Avg 7h 12m · Goal 8h" 요약 라인 추가
  - `StandardCard` 래퍼
  - 차트 높이 조정 (Wellness 탭에서는 120pt로 축소 — 공간 효율)
- **Verification**: 7일 데이터 바 차트 정상 렌더링

#### Step 10: WeightTrendChart 개선

- **Files**: `WellnessView.swift` 내부 또는 별도 컴포넌트
- **Changes**:
  - 기존 BodyCompositionView의 `weightTrendChart` 로직 재사용
  - `StandardCard` 래퍼
  - 차트 높이 조정 (150pt → 120pt)
  - 데이터 2개 미만이면 숨김 (현재와 동일)
- **Verification**: Weight 트렌드 차트 정상, 포인트 2개 미만 시 숨김

#### Step 11: 전체 탭 일관성 검증 + 빌드

- **Files**: 전체
- **Changes**:
  - 3탭 모두에서 일관된 패턴 확인:
    - `.refreshable` 적용
    - 배경 LinearGradient
    - Section header `DS.Typography.sectionTitle`
    - Loading/Empty/Error 상태 처리
  - xcodegen으로 프로젝트 재생성
  - 빌드 + 테스트 실행
- **Verification**: `xcodebuild build` 성공, 기존 테스트 통과

### Phase 4: 정리

#### Step 12: 기존 Sleep/Body 독립 탭 코드 정리

- **Files**: `Presentation/Sleep/SleepView.swift`, `Presentation/BodyComposition/BodyCompositionView.swift`
- **Changes**:
  - SleepView: 더 이상 탭 root가 아님. WellnessView에서 ViewModel만 사용하므로 SleepView.swift는 **유지** (future에 Sleep 상세 화면으로 재활용 가능)
  - BodyCompositionView: FormSheet와 ViewModel은 WellnessView에서 사용. BodyCompositionView.swift 자체는 **유지** (reference로 보존, 추후 삭제 판단)
  - 두 파일 모두 ContentView에서 더 이상 import되지 않음을 확인
- **Verification**: Dead code 확인 (WellnessView가 직접 VM을 사용하므로 기존 View 파일은 미참조 상태)

## Edge Cases

| Case | Handling |
|------|---------|
| Sleep 데이터 없음 + Body 있음 | Sleep 섹션 mini EmptyState, Body 섹션 정상 |
| Sleep 있음 + Body 없음 | Sleep 정상, Body 섹션 mini EmptyState |
| 둘 다 없음 | 전체 EmptyStateView (HealthKit 안내 + "Add Record" CTA) |
| Body 레코드 1개 (트렌드 불가) | WeightTrendChart 숨김, SnapshotCard만 표시 |
| Historical sleep data | `.ultraThinMaterial` 배너 (SleepHeroCard 상단) |
| iPad multitasking | `sizeClass` 기반 카드 너비 자동 조정 |
| Pull to refresh | Sleep + Body 동시 병렬 리로드 |
| Body Form Sheet dismiss 후 | records @Query 자동 업데이트 → SnapshotCard/TrendChart 갱신 |
| BodyHistoryDetailView에서 삭제 | @Query 자동 반영 → Wellness 탭 복귀 시 최신 상태 |

## Testing Strategy

- **Unit tests**:
  - `AppSectionTests`: 3개 case, title/icon 매핑 검증
  - 기존 `SleepViewModelTests`, `BodyCompositionViewModelTests` 통과 확인 (변경 없음)
- **Preview tests**:
  - SleepHeroCard: 정상 데이터, 0점, stage 없음
  - BodySnapshotCard: 전체 데이터, 부분 누락, 변화 없음
  - WellnessView: 4가지 Empty State 조합
- **시뮬레이터 테스트**:
  - iPhone 17 + iPad Pro: 탭 전환, Wellness 스크롤, Body 입력 플로우
  - 3탭 모두 정상 동작 확인
- **접근성 테스트**:
  - Dynamic Type 최대 크기에서 카드 레이아웃 깨짐 없음
  - VoiceOver로 Sleep/Body 섹션 탐색 가능
- **빌드 검증**:
  ```bash
  xcodebuild build -project Dailve/Dailve.xcodeproj -scheme Dailve \
    -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -quiet
  ```

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| AppSection enum 변경이 다른 곳에 참조됨 | 낮음 | 중간 | 컴파일러 exhaustiveness check가 모든 케이스 잡아줌 |
| Sleep+Body 동시 로딩 시 메모리 피크 | 낮음 | 낮음 | 기존 각 탭에서 이미 개별 로딩 — 동시해도 총량 동일 |
| @Query records가 WellnessView에서 정상 동작 | 낮음 | 높음 | SwiftData @Query는 View 위치 무관 — 동일 ModelContainer면 동작 |
| Body FormSheet가 WellnessView NavigationStack과 충돌 | 낮음 | 중간 | FormSheet 내부 NavigationStack은 독립 — 현재 구조 동일 |
| SleepHeroCard 레이아웃 복잡도 | 중간 | 낮음 | ProgressRingView 기존 컴포넌트 활용, Preview로 즉시 검증 |
| 12 Step 범위 | 중간 | 중간 | Phase별 독립 커밋, Phase 1만으로도 앱 동작 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**:
  1. SleepViewModel/BodyCompositionViewModel은 **변경 없이** 그대로 재사용
  2. 두 기존 View 모두 `navigationDestination` 없음 → NavigationStack 충돌 위험 0
  3. 카드 컴포넌트(StandardCard, HeroCard)가 이미 존재 → 새 카드는 조합만
  4. AppSection enum 변경은 컴파일러가 모든 switch 케이스를 잡아줌
  5. 디자인 시스템(DS)이 이미 구축되어 있어 토큰 추가 불필요
  6. 각 Phase가 독립적으로 동작 가능 — Phase 1만으로도 앱 빌드 가능
