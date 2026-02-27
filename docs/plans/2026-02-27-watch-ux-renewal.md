---
tags: [watch, watchos, ux, design-system, equipment-icons, template, exercise-selection]
date: 2026-02-27
category: plan
status: draft
source: docs/brainstorms/2026-02-27-watch-ux-renewal.md
---

# Plan: Watch UX 전면 리뉴얼

## Summary

Watch 앱의 텍스트 중심 UI를 시각적 타일 기반으로 전환하고, iOS 디자인 시스템과 완전 통일.

**범위**: 운동 선택 UI + 템플릿 카드 + 세트 입력 계층화 + DS 토큰 완전 적용
**예상 커밋**: 6개 (Phase별 1개)
**영향 파일**: 15개 수정 + 2개 신규

## Affected Files

| # | File | Action | Changes |
|---|------|--------|---------|
| 1 | `DUNEWatch/DesignSystem.swift` | **Modify** | Spacing, Radius, Typography, Animation, Gradient enum 추가 |
| 2 | `DUNEWatch/WatchConnectivityManager.swift` | **Modify** | WatchExerciseInfo에 `equipment` 필드 추가 |
| 3 | `DUNE/Presentation/Exercise/WorkoutSessionViewModel.swift` | **Modify** | iOS→Watch 동기화 시 equipment 포함 |
| 4 | `DUNEWatch/Views/QuickStartPickerView.swift` | **Modify** | 타일 UI 재설계 (아이콘+이름+최근 기록) |
| 5 | `DUNEWatch/Views/RoutineListView.swift` | **Modify** | 템플릿 카드 강화 (아이콘 미리보기+메타 정보) |
| 6 | `DUNEWatch/Views/WorkoutPreviewView.swift` | **Modify** | 장비 아이콘 표시 + DS 토큰 적용 |
| 7 | `DUNEWatch/Views/MetricsView.swift` | **Modify** | 정보 계층화 + 하드코딩 제거 + DS 토큰 |
| 8 | `DUNEWatch/Views/SetInputSheet.swift` | **Modify** | DS 토큰 적용 + 터치 타겟 확대 |
| 9 | `DUNEWatch/Views/RestTimerView.swift` | **Modify** | DS 토큰 적용 + gauge 크기 동적화 |
| 10 | `DUNEWatch/Views/ControlsView.swift` | **Modify** | DS 토큰 적용 |
| 11 | `DUNEWatch/Views/SessionSummaryView.swift` | **Modify** | DS 토큰 적용 + 장비 아이콘 표시 |
| 12 | `DUNEWatch/Views/SessionPagingView.swift` | **Modify** | DS 토큰 적용 |
| 13 | `DUNEWatch/Views/WatchWaveBackground.swift` | **Modify** | 파라미터화 (화면 크기 대응) |
| 14 | `DUNEWatch/ContentView.swift` | **Modify** | DS 토큰 적용 |
| 15 | `DUNEWatch/Views/ExerciseTileView.swift` | **Create** | 운동 타일 공통 컴포넌트 |
| 16 | `DUNEWatch/Views/TemplateCardView.swift` | **Create** | 템플릿 카드 공통 컴포넌트 |
| 17 | `Dailve/project.yml` | **Modify** | 신규 파일 등록 (xcodegen) |

## Prerequisites

- [ ] **SVG 아이콘 교체/업그레이드** (Recraft V4로 생성) — 사용자가 별도 수행
- [ ] Watch Asset Catalog에 Equipment SVG 복사 (`DUNEWatch/Assets.xcassets/Equipment/`)

> **주의**: 아이콘 에셋은 이 플랜의 코드 구현과 병렬로 진행 가능. 코드는 `Equipment.svgAssetName`을 통해 에셋을 참조하므로, 에셋이 없어도 fallback SF Symbol로 동작.

## Implementation Steps

### Phase 1: Watch DS 확장 (커밋 1)

**목표**: iOS DS와 대등한 토큰 체계를 Watch DS에 구축

**파일**: `DUNEWatch/DesignSystem.swift`

```swift
// 추가할 토큰들
enum Spacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 6    // Watch는 iOS(8)보다 축소
    static let md: CGFloat = 8
    static let lg: CGFloat = 12
    static let xl: CGFloat = 16
}

enum Radius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 18   // watchOS 표준 카드 라운드
}

enum Typography {
    static let exerciseName = Font.headline.bold()
    static let metricValue = Font.system(.title2, design: .rounded).monospacedDigit().bold()
    static let metricLabel = Font.caption2.weight(.medium)
    static let tileTitle = Font.system(.body, design: .rounded).weight(.semibold)
    static let tileSubtitle = Font.caption.weight(.medium)
}

enum Animation {
    // 기존
    static let waveDrift = ...
    // 추가
    static let standard = SwiftUI.Animation.snappy(duration: 0.3)
    static let numeric = SwiftUI.Animation.snappy(duration: 0.2)
}

enum Gradient {
    static let cardBackground = LinearGradient(
        colors: [DS.Color.warmGlow.opacity(DS.Opacity.subtle), .clear],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}
```

**검증**: 빌드 성공 (토큰 추가만, UI 변경 없음)

---

### Phase 2: WatchExerciseInfo DTO 확장 (커밋 2)

**목표**: Watch에 equipment 정보 전달

**파일 1**: `DUNEWatch/WatchConnectivityManager.swift`
```swift
struct WatchExerciseInfo: Codable, Sendable, Hashable {
    let id: String
    let name: String
    let inputType: String
    let defaultSets: Int
    let defaultReps: Int?
    let defaultWeightKg: Double?
    let equipment: String?  // ← 추가 (Equipment.rawValue)
}
```

**파일 2**: iOS측 동기화 코드 (`WorkoutSessionViewModel.swift` 또는 `WatchSessionManager.swift`)
- `WatchExerciseInfo` 생성 시 `equipment: exercise.equipment?.rawValue` 포함

**Correction #69 준수**: Watch DTO 필드 추가 시 양쪽 target 동기화

**검증**: 빌드 성공 + 기존 동기화 동작 유지 (Optional 필드이므로 하위 호환)

---

### Phase 3: 공통 컴포넌트 생성 (커밋 3)

**목표**: 운동 타일과 템플릿 카드를 재사용 가능한 컴포넌트로 추출

#### 3-A: ExerciseTileView.swift (신규)

```
┌──────────────────────┐
│ [🏋] Bench Press      │  ← 36pt 장비 아이콘 + 운동명
│      3×10 · 80 kg    │  ← sets×reps + 최근 무게
└──────────────────────┘
```

```swift
struct ExerciseTileView: View {
    let exercise: WatchExerciseInfo
    let latestWeight: Double?
    let latestReps: Int?

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            equipmentIcon
                .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(exercise.name)
                    .font(DS.Typography.tileTitle)
                    .lineLimit(1)
                metaText
                    .font(DS.Typography.tileSubtitle)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, DS.Spacing.sm)
    }

    @ViewBuilder
    private var equipmentIcon: some View {
        if let equipment = exercise.equipment,
           let _ = UIImage(named: "Equipment/equipment.\(equipment)") {
            Image("Equipment/equipment.\(equipment)")
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(DS.Color.warmGlow)
        } else {
            Image(systemName: "dumbbell.fill")
                .font(.title3)
                .foregroundStyle(DS.Color.warmGlow)
        }
    }
}
```

**핵심**:
- equipment가 nil이거나 에셋이 없으면 SF Symbol fallback
- `.renderingMode(.template)` + `DS.Color.warmGlow` 단색 렌더링
- 최소 44pt 터치 타겟 (padding 포함)

#### 3-B: TemplateCardView.swift (신규)

```
┌──────────────────────┐
│ Push Day              │
│ 🏋 🏋 💪 🏋           │  ← 장비 아이콘 미리보기
│ 4 exercises · ~45min  │
└──────────────────────┘
```

```swift
struct TemplateCardView: View {
    let template: WorkoutSessionTemplate
    let estimatedMinutes: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(template.name)
                .font(DS.Typography.tileTitle)

            equipmentIconRow

            HStack(spacing: DS.Spacing.xs) {
                Text("\(template.entries.count) exercises")
                if let mins = estimatedMinutes {
                    Text("·")
                    Text("~\(mins) min")
                }
            }
            .font(DS.Typography.tileSubtitle)
            .foregroundStyle(.secondary)
        }
        .padding(DS.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .fill(DS.Color.warmGlow.opacity(DS.Opacity.subtle))
        }
    }

    private var equipmentIconRow: some View {
        // 최대 4개 고유 장비 아이콘 + 초과 시 "+N"
    }
}
```

**검증**: Preview에서 다양한 데이터로 렌더링 확인

---

### Phase 4: 운동 선택 UI 재설계 (커밋 4)

**목표**: QuickStartPickerView + QuickStartAllExercisesView를 타일 기반으로 전환

**파일**: `DUNEWatch/Views/QuickStartPickerView.swift`

**변경 사항**:
1. 기존 텍스트 행 → `ExerciseTileView` 교체
2. Section header 스타일링 (DS.Typography 적용)
3. "All Exercises" 링크: `.foregroundStyle(.green)` → `DS.Color.warmGlow`
4. List 배경: `.scrollContentBackground(.hidden)` + `WatchWaveBackground()`
5. `latestWeight`/`latestReps` 조회를 ExerciseTileView에 전달

**QuickStartAllExercisesView**:
- 동일하게 ExerciseTileView 적용
- 검색 결과에서도 아이콘 표시

**Correction 준수**:
- #87: `.task(id:)` key는 content-aware Hasher
- #143: List + 웨이브는 `.scrollContentBackground(.hidden)` 필수

---

### Phase 5: 템플릿 카드 + 홈 화면 재설계 (커밋 5)

**목표**: RoutineListView의 템플릿 행을 TemplateCardView로 교체

**파일**: `DUNEWatch/Views/RoutineListView.swift`

**변경 사항**:
1. 기존 텍스트 행 → `TemplateCardView` 교체
2. Quick Start 섹션: DS.Color.positive → DS.Color.warmGlow 통일 검토
3. Empty state: DS 토큰으로 스타일링
4. Sync status: 기존 유지 (기능 변경 없음)

**WorkoutPreviewView**:
- 운동 목록에 장비 아이콘 추가 (exercise.equipment → Image)
- Start 버튼: 기존 DS.Color.positive 유지 (CTA 강조)

---

### Phase 6: 워크아웃 중 화면 DS 통일 (커밋 6)

**목표**: MetricsView, SetInputSheet, RestTimerView, ControlsView, SessionSummaryView의 하드코딩 제거

**공통 변경**:
- `cornerRadius: 10` → `DS.Radius.md`
- `.foregroundStyle(.green)` → `DS.Color.positive`
- `.font(.headline.bold())` → `DS.Typography.exerciseName`
- `.font(.system(.largeTitle, ...)` → `DS.Typography.metricValue`
- `.spacing(8)` → `DS.Spacing.md`
- `.padding(.horizontal, 8)` → `.padding(.horizontal, DS.Spacing.md)`

**MetricsView 추가 개선**:
- 입력 카드 배경: `DS.Gradient.cardBackground` 적용
- dot indicator: 기존 8pt → 10pt (시인성 향상)
- HR 뱃지: 우상단 고정 위치

**RestTimerView 추가 개선**:
- gauge 크기: `100` 고정 → `GeometryReader` 기반 동적 크기

**SessionSummaryView 추가 개선**:
- 운동 breakdown에 장비 아이콘 추가

---

## Watch Asset Catalog 설정

Equipment SVG를 Watch 타겟에서도 사용하려면:

**방법 A (권장)**: iOS Asset Catalog의 Equipment 폴더를 Watch 타겟에도 포함
- `project.yml`에서 Watch 타겟의 `sources`에 Equipment asset 경로 추가
- 또는 `Assets.xcassets`를 양쪽 타겟에 공유

**방법 B**: Watch 전용 Asset Catalog에 SVG 복사
- 중복 관리 부담, 비권장

## Test Strategy

### 유닛 테스트
- `WatchExerciseInfo` equipment 필드 인코딩/디코딩 (Optional backward compat)
- `ExerciseTileView` 아이콘 fallback 로직 (equipment nil → SF Symbol)

### 수동 테스트 (실기기)
- [ ] 운동 선택: 타일 터치 타겟 44pt 이상 확인
- [ ] 템플릿 카드: 아이콘 미리보기 렌더링 확인
- [ ] 세트 입력: Digital Crown 동작 유지 확인
- [ ] 38mm vs 46mm: 레이아웃 스케일링 확인
- [ ] 라이브러리 미동기화 시 fallback 아이콘 확인
- [ ] AOD 모드: 불필요한 애니메이션 정지 확인

### 빌드 검증
```bash
# Watch 빌드
xcodebuild build -project Dailve/Dailve.xcodeproj -scheme DailveWatch \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=26.2'

# iOS 빌드 (동기화 코드 변경)
scripts/build-ios.sh
```

## Edge Cases

| 시나리오 | 대응 |
|---------|------|
| `exercise.equipment == nil` | SF Symbol `dumbbell.fill` fallback |
| Equipment SVG 에셋 미존재 | SF Symbol fallback (Image(named:) nil 체크) |
| 운동 이름 2줄 이상 | `.lineLimit(1)` + truncation |
| 템플릿 운동 0개 | 빈 아이콘 행 숨김 |
| 템플릿 운동 10개+ | 아이콘 4개 + "+N" 표시 |
| 최근 무게 없음 (첫 수행) | 무게 텍스트 숨김, sets×reps만 표시 |
| Watch Asset Catalog에 Equipment 폴더 미포함 | 전체 SF Symbol fallback (기능 정상 동작) |
| WatchExerciseInfo equipment 필드 nil (구버전 iOS) | Optional이므로 기존 동작 유지 |

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|-----------|
| SVG 에셋 렌더링 성능 (25종 × 스크롤) | Medium | `.renderingMode(.template)` 단색이므로 GPU 부담 낮음. 필요 시 rasterize |
| 38mm 화면에서 타일 높이 부족 | Low | 60pt 타일은 38mm에서도 2개 동시 표시 가능. 40mm+ 기준 3개 |
| iOS→Watch 동기화 equipment 필드 누락 | Low | Optional 필드, fallback 보장. 구버전 호환 |
| CarouselListStyle 퍼포먼스 | Medium | MVP에서 제외 (표준 List 유지). Future로 이관 |

## Phase별 의존성

```
Phase 1 (DS 확장) ──→ Phase 3 (공통 컴포넌트) ──→ Phase 4 (운동 선택)
                                                  ──→ Phase 5 (템플릿+홈)
Phase 2 (DTO 확장) ──→ Phase 3 (공통 컴포넌트)

Phase 1 (DS 확장) ──→ Phase 6 (워크아웃 DS 통일)
```

- Phase 1, 2는 병렬 가능
- Phase 3은 Phase 1, 2 완료 후
- Phase 4, 5는 Phase 3 완료 후 (병렬 가능)
- Phase 6은 Phase 1 완료 후 (독립)

## 관련 문서

- Brainstorm: `docs/brainstorms/2026-02-27-watch-ux-renewal.md`
- 이전 설계: `docs/brainstorms/2026-02-18-watch-design-overhaul.md`
- 이전 설계: `docs/brainstorms/2026-02-18-watch-first-workout-ux.md`
- 에셋 참조: `docs/brainstorms/2026-02-23-equipment-svg-images.md`
