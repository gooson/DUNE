---
tags: [design-system, consistency, color, watch, ds-tokens, accessibility, dark-mode]
date: 2026-02-26
category: plan
status: draft
source: docs/brainstorms/2026-02-26-design-consistency-audit.md
---

# Plan: 디자인 일관성 전체 감사 및 재통합

## Summary

앱 전체(iOS 15+ 뷰 + watchOS 10 뷰)의 디자인 시스템 준수율을 100%로 끌어올리는 작업.
5단계로 나누어 각 단계가 독립 빌드+검증 가능하도록 설계.

**예상 변경**: ~25개 파일, 시각적 동작 변경 없음 (토큰 교체 중심)

---

## Phase 1: DS 토큰 확장 (기반 작업)

### 1-1. Opacity 토큰 추가

**파일**: `DUNE/Presentation/Shared/DesignSystem.swift`

현재 코드베이스에서 반복되는 opacity 값을 토큰화:

```swift
enum Opacity {
    static let subtle: Double = 0.06    // 배경 wave, 장식 요소
    static let light: Double = 0.08     // 카드 shadow, badge 배경
    static let medium: Double = 0.10    // 탭 배경 gradient
    static let emphasis: Double = 0.15  // 카드 보더 (다크 모드)
    static let strong: Double = 0.30    // Hero 카드 보더 상단
}
```

### 1-2. `.accentColor` → `DS.Color.warmGlow` 교체 (11건)

| 파일 | 라인 | 현재 | 변경 |
|------|------|------|------|
| GlassCard.swift | 25 | `SwiftUI.Color.accentColor.opacity(0.10)` | `DS.Color.warmGlow.opacity(DS.Opacity.medium)` |
| GlassCard.swift | 39 | `SwiftUI.Color.accentColor.opacity(0.30)` | `DS.Color.warmGlow.opacity(DS.Opacity.strong)` |
| GlassCard.swift | 40 | `SwiftUI.Color.accentColor.opacity(0.06)` | `DS.Color.warmGlow.opacity(DS.Opacity.subtle)` |
| GlassCard.swift | 74 | `SwiftUI.Color.accentColor.opacity(0.15/0.0)` | `DS.Color.warmGlow.opacity(dark ? DS.Opacity.emphasis : 0)` |
| GlassCard.swift | 82 | `SwiftUI.Color.accentColor.opacity(0.08)` | `DS.Color.warmGlow.opacity(DS.Opacity.light)` |
| WaveShape.swift | 80 | `var color: Color = .accentColor` | `var color: Color = DS.Color.warmGlow` |
| HeroScoreCard.swift | 47 | `Color.accentColor` × 2 | `DS.Color.warmGlow` × 2 |
| ProgressRingView.swift | 60 | `Color.accentColor.opacity(0.6/0.8)` | `DS.Color.warmGlow.opacity(0.6/0.8)` |
| EmptyStateView.swift | 41, 43 | `Color.accentColor.opacity(0.06)` | `DS.Color.warmGlow.opacity(DS.Opacity.subtle)` |
| WaveRefreshIndicator.swift | 7 | `var color: Color = .accentColor` | `var color: Color = DS.Color.warmGlow` |
| WaveRefreshIndicator.swift | 136 | `color: Color = .accentColor` | `color: Color = DS.Color.warmGlow` |

### 1-3. iOS 매직넘버 제거 (6건)

| 파일 | 라인 | 현재 | 변경 |
|------|------|------|------|
| ConditionScoreDetailView.swift | ~265 | `HStack(spacing: 2)` | `HStack(spacing: DS.Spacing.xxs)` |
| ConditionScoreDetailView.swift | ~273 | `.padding(.horizontal, 6)` | `.padding(.horizontal, DS.Spacing.sm)` |
| ConditionScoreDetailView.swift | ~275 | `.padding(.vertical, 2)` | `.padding(.vertical, DS.Spacing.xxs)` |
| ExerciseMixDetailView.swift | ~101 | `VStack(spacing: 2)` | `VStack(spacing: DS.Spacing.xxs)` |
| ExerciseTypeDetailView.swift | ~219 | `spacing: 4` | `spacing: DS.Spacing.xs` |
| ExerciseSessionDetailView.swift | ~113 | `.opacity(0.08)` | `.opacity(DS.Opacity.light)` |

**검증**: iOS 빌드 (`scripts/build-ios.sh`)

---

## Phase 2: 카테고리 컬러 재검토

### 2-1. 유사색 분리

**원칙**: 인접 표시 가능한 카테고리 간 hue 차이 20°+ 확보

| 쌍 | 현재 문제 | 해결 방안 |
|----|----------|----------|
| MetricHRV ↔ WellnessVitals | RGB 차이 < 5% | WellnessVitals hue를 cool 방향으로 이동 (amber → sage/olive) |
| MetricBody ↔ ScoreFair | 동일 RGB | MetricBody를 warm amber → copper/terracotta로 조정 |
| MetricRHR ↔ MetricHeartRate | R채널 유사 | RHR을 더 따뜻한 peach/salmon, HeartRate는 crimson 유지 |

**변경 파일**: Asset catalog colorset JSON 수정
- `DUNE/Resources/Assets.xcassets/Colors/WellnessVitals.colorset/Contents.json`
- `DUNE/Resources/Assets.xcassets/Colors/MetricBody.colorset/Contents.json`
- `DUNE/Resources/Assets.xcassets/Colors/MetricRHR.colorset/Contents.json`
- Watch 동일 colorset도 동기 수정

### 2-2. 다크 모드 variant 추가

현재 universal(단일값) 컬러에 다크 모드 전용 값 추가.
**원칙**: 다크 배경 위 밝기 +10~15%, 채도 유지 또는 미세 감소

대상 colorset (14개):
- MetricHeartRate, MetricActivity, MetricSteps, MetricSleep, MetricBody
- WellnessVitals, WellnessFitness
- ScoreExcellent, ScoreGood, ScoreFair, ScoreTired, ScoreWarning
- HRZone1 ~ HRZone5 (5개)
- AccentColor

각 colorset의 Contents.json에 `"appearances": [{"appearance": "luminosity", "value": "dark"}]` 항목 추가.

### 2-3. Score 그라데이션 통합

**결정 필요**: Condition Score와 Wellness Score의 색상 체계를 통합할 것인지?

**권장안**: 통합. 동일 5단계 (Excellent/Good/Fair/Tired/Warning) 사용.
- Wellness Score는 현재 4단계 → 5단계로 확장 (Tired 추가)
- 또는 Wellness 전용 색상을 삭제하고 Condition Score 색상 공유

**변경 파일**:
- `DesignSystem.swift` — wellnessExcellent/Good/Fair/Warning 정의 수정
- 해당 colorset JSON 수정 또는 삭제 후 Score* colorset으로 통합
- `WellnessScoreDetailView.swift` — 색상 참조 업데이트

**검증**: iOS 빌드 + 다크/라이트 모드 시뮬레이터 스크린샷 비교

---

## Phase 3: watchOS DS 레이어 생성

### 3-1. Watch Asset Catalog에 누락 컬러 추가

현재 Watch에 없는 colorset 추가 (iOS에서 복사):

| 추가 대상 | 용도 |
|-----------|------|
| Positive.colorset | `.green` → `DS.Color.positive` |
| Negative.colorset | `.red` → `DS.Color.negative` |
| Caution.colorset | `.yellow` → `DS.Color.caution` |

**위치**: `DUNEWatch/Resources/Assets.xcassets/Colors/`

### 3-2. WatchDesignSystem.swift 생성

**위치**: `DUNEWatch/Sources/DesignSystem.swift` (또는 Views와 동일 레벨)

```swift
import SwiftUI

enum DS {
    enum Color {
        // Metric Colors (asset catalog 참조)
        static let hrv       = SwiftUI.Color("MetricHRV")
        static let rhr       = SwiftUI.Color("MetricRHR")
        static let heartRate = SwiftUI.Color("MetricHeartRate")
        static let sleep     = SwiftUI.Color("MetricSleep")
        static let activity  = SwiftUI.Color("MetricActivity")
        static let steps     = SwiftUI.Color("MetricSteps")
        static let body      = SwiftUI.Color("MetricBody")
        static let vitals    = SwiftUI.Color("WellnessVitals")
        static let fitness   = SwiftUI.Color("WellnessFitness")

        // Feedback Colors
        static let positive  = SwiftUI.Color("Positive")
        static let negative  = SwiftUI.Color("Negative")
        static let caution   = SwiftUI.Color("Caution")

        // Brand
        static let warmGlow  = SwiftUI.Color("AccentColor")
    }

    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
    }
}
```

### 3-3. Watch 뷰 하드코딩 교체 (28건)

| 파일 | 변경 수 | 주요 교체 |
|------|---------|----------|
| MetricsView.swift | 9 | `.green` → `DS.Color.positive`, `.red` → `DS.Color.negative` |
| ControlsView.swift | 3 | `.red` → `DS.Color.negative`, `.yellow` → `DS.Color.caution`, `.gray` → `.secondary` |
| RestTimerView.swift | 5 | `.green` → `DS.Color.positive`, `.red` → `DS.Color.negative` |
| SessionSummaryView.swift | 2 | `.green` → `DS.Color.positive` |
| SetInputSheet.swift | 5 | `.green` → `DS.Color.positive`, `.gray` → `.secondary` |
| WorkoutPreviewView.swift | 1 | `.green` → `DS.Color.positive` |
| RoutineListView.swift | 3 | `.green` → `DS.Color.positive` |

**`.gray` 처리**: Watch에서 `.gray`는 secondary 버튼 용도. SwiftUI의 `.secondary` semantic color 또는 `Color.secondary` 사용 (watchOS에서 적절한 명암 제공).

**검증**: Watch 빌드 (`xcodebuild -scheme DailveWatch ...`)

---

## Phase 4: xcodegen + 빌드 검증

### 4-1. project.yml 업데이트

새 파일 추가 시:
- `DUNEWatch/Sources/DesignSystem.swift` → Watch 타겟 sources에 포함
- 새 colorset → Watch asset catalog에 포함

```bash
cd Dailve && xcodegen generate
```

### 4-2. iOS 빌드 검증

```bash
scripts/build-ios.sh
```

### 4-3. Watch 빌드 검증

```bash
xcodebuild build -project Dailve/Dailve.xcodeproj \
  -scheme DailveWatch \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=26.2'
```

### 4-4. 테스트 실행

```bash
xcodebuild test -project Dailve/Dailve.xcodeproj \
  -scheme DailveTests \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.2' \
  -only-testing DailveTests
```

---

## Phase 5: 최종 감사 + Grep 검증

### 5-1. 잔여 `.accentColor` 검색

```bash
grep -rn "\.accentColor" DUNE/ DUNEWatch/ --include="*.swift"
```

기대 결과: 0건 (DesignSystem.swift의 `warmGlow` 정의 1건 제외)

### 5-2. 하드코딩 컬러 검색 (Watch)

```bash
grep -rn "\.\(green\|red\|yellow\|gray\|blue\)\b" DUNEWatch/ --include="*.swift"
```

기대 결과: 0건

### 5-3. 매직넘버 검색 (iOS)

```bash
grep -rn "spacing: [0-9]\|padding.*[0-9])" DUNE/Presentation/ --include="*.swift" | grep -v "DS\."
```

잔여 매직넘버 확인 후 추가 교체.

---

## Affected Files

### Phase 1 (DS 토큰 확장 + iOS 교체)

| 파일 | 변경 유형 | 라인 수 |
|------|----------|---------|
| `DUNE/Presentation/Shared/DesignSystem.swift` | Opacity enum 추가 | +8 |
| `DUNE/Presentation/Shared/Components/GlassCard.swift` | `.accentColor` 교체 5건 | ~5 |
| `DUNE/Presentation/Shared/Components/WaveShape.swift` | `.accentColor` 교체 1건 | ~1 |
| `DUNE/Presentation/Shared/Components/HeroScoreCard.swift` | `.accentColor` 교체 2건 | ~2 |
| `DUNE/Presentation/Shared/Components/ProgressRingView.swift` | `.accentColor` 교체 2건 | ~2 |
| `DUNE/Presentation/Shared/Components/EmptyStateView.swift` | `.accentColor` 교체 2건 | ~2 |
| `DUNE/Presentation/Shared/Components/WaveRefreshIndicator.swift` | `.accentColor` 교체 2건 | ~2 |
| `DUNE/Presentation/Dashboard/ConditionScoreDetailView.swift` | 매직넘버 3건 | ~3 |
| `DUNE/Presentation/Activity/ExerciseMix/ExerciseMixDetailView.swift` | 매직넘버 1건 | ~1 |
| `DUNE/Presentation/Activity/TrainingVolume/ExerciseTypeDetailView.swift` | 매직넘버 1건 | ~1 |
| `DUNE/Presentation/Exercise/ExerciseSessionDetailView.swift` | opacity 1건 | ~1 |

### Phase 2 (카테고리 컬러)

| 파일 | 변경 유형 |
|------|----------|
| `DUNE/Resources/Assets.xcassets/Colors/WellnessVitals.colorset/Contents.json` | RGB 값 조정 |
| `DUNE/Resources/Assets.xcassets/Colors/MetricBody.colorset/Contents.json` | RGB 값 조정 |
| `DUNE/Resources/Assets.xcassets/Colors/MetricRHR.colorset/Contents.json` | RGB 값 조정 |
| `DUNE/Resources/Assets.xcassets/Colors/AccentColor.colorset/Contents.json` | 다크 variant 추가 |
| + 13개 colorset | 다크 variant 추가 |
| `DUNEWatch/Resources/Assets.xcassets/Colors/` 동일 파일들 | Watch 동기 수정 |
| `DUNE/Presentation/Shared/DesignSystem.swift` | Wellness Score 색상 통합 (선택) |

### Phase 3 (watchOS DS)

| 파일 | 변경 유형 |
|------|----------|
| `DUNEWatch/Resources/Assets.xcassets/Colors/Positive.colorset/` | 신규 생성 |
| `DUNEWatch/Resources/Assets.xcassets/Colors/Negative.colorset/` | 신규 생성 |
| `DUNEWatch/Resources/Assets.xcassets/Colors/Caution.colorset/` | 신규 생성 |
| `DUNEWatch/Sources/DesignSystem.swift` | 신규 생성 |
| `DUNEWatch/Views/MetricsView.swift` | 하드코딩 교체 9건 |
| `DUNEWatch/Views/ControlsView.swift` | 하드코딩 교체 3건 |
| `DUNEWatch/Views/RestTimerView.swift` | 하드코딩 교체 5건 |
| `DUNEWatch/Views/SessionSummaryView.swift` | 하드코딩 교체 2건 |
| `DUNEWatch/Views/SetInputSheet.swift` | 하드코딩 교체 5건 |
| `DUNEWatch/Views/WorkoutPreviewView.swift` | 하드코딩 교체 1건 |
| `DUNEWatch/Views/RoutineListView.swift` | 하드코딩 교체 3건 |

---

## Risks & Mitigations

| 리스크 | 영향 | 완화 |
|--------|------|------|
| 카테고리 컬러 변경 → 차트/sparkline 연쇄 변경 | 시각적 변화 | Asset catalog 수정이므로 코드 변경 없이 자동 반영 |
| Score 그라데이션 통합 → Wellness 뷰 깨짐 | 기능 영향 | 통합 전 Wellness Score 렌더 경로 전수 확인 |
| Watch DS 생성 → xcodegen 타겟 설정 | 빌드 실패 | project.yml에 새 파일 명시 후 generate |
| 다크 모드 variant → 기존 UI 미세 변화 | 시각적 | Correction #129: v1(보수적 밝기 조정) → 확인 후 v2 |

## Alternatives Considered

| 대안 | 장점 | 단점 | 결정 |
|------|------|------|------|
| SPM shared package로 DS 통합 | 코드 중복 제거 | 빌드 복잡도 증가, 현 시점 과잉 | ❌ 추후 검토 |
| Watch DS 없이 Color("name") 직접 사용 | 파일 1개 덜 생성 | 토큰 타입 안전성 없음 | ❌ |
| Wellness Score 색상 유지 (통합 안 함) | 변경 최소화 | 사용자 혼란 지속 | ⚠️ 사용자 결정 필요 |

## Dependencies

- Phase 1은 독립 실행 가능 (다른 Phase에 영향 없음)
- Phase 2는 Phase 1 완료 후 (Opacity 토큰 참조)
- Phase 3는 Phase 2 완료 후 (Watch colorset이 iOS와 동기화 필요)
- Phase 4, 5는 Phase 3 완료 후

## Open Decision

**Score 그라데이션 통합 여부**: Condition Score(5단계)와 Wellness Score(4단계)를 통합하면 색상 관리가 단순해지지만, 의도적으로 다르게 디자인된 것일 수 있음. 사용자 결정 필요.

---

## Checklist

- [ ] Phase 1: DS.Opacity 토큰 추가
- [ ] Phase 1: `.accentColor` 교체 11건
- [ ] Phase 1: 매직넘버 제거 6건
- [ ] Phase 1: iOS 빌드 검증
- [ ] Phase 2: 유사색 3쌍 분리 (colorset 수정)
- [ ] Phase 2: 다크 모드 variant 14개+ 추가
- [ ] Phase 2: Score 그라데이션 통합/정리
- [ ] Phase 2: iOS 빌드 + 시각 검증
- [ ] Phase 3: Watch colorset 3개 추가
- [ ] Phase 3: WatchDesignSystem.swift 생성
- [ ] Phase 3: Watch 뷰 28건 교체
- [ ] Phase 3: xcodegen + Watch 빌드 검증
- [ ] Phase 4: 전체 빌드 (iOS + Watch)
- [ ] Phase 5: grep 잔여 검사 + 최종 감사
