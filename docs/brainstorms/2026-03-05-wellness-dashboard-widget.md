---
tags: [widget, widgetkit, condition, readiness, wellness, ios-widget]
date: 2026-03-05
category: brainstorm
status: draft
---

# Brainstorm: 컨디션 + 준비도 + 웰니스 통합 위젯

## Problem Statement

앱을 열지 않고도 오늘의 건강 상태를 한눈에 파악할 수 있어야 한다. 현재 3가지 핵심 점수(Condition, Training Readiness, Wellness)가 각각 다른 탭에 분산되어 있어 빠른 확인이 불가능하다. WidgetKit을 활용한 홈 화면 위젯으로 이 3가지를 통합 표시한다.

## Target Users

- DUNE 앱의 기존 사용자
- 매일 아침 컨디션 확인 후 운동 계획을 조정하는 사용자
- 앱을 자주 열지 않지만 홈 화면에서 상태를 모니터링하고 싶은 사용자

## Success Criteria

1. 홈 화면에서 3개 점수(Condition, Readiness, Wellness)를 동시에 확인 가능
2. 위젯 탭 시 앱의 관련 상세 화면으로 딥링크
3. Small/Medium/Large 3가지 크기 지원
4. 데이터가 부분적일 때도 가용 항목만 표시 (graceful degradation)

## 기존 모델 분석

### ConditionScore (Dashboard 탭)
- 0-100 점수, Status: excellent/good/fair/tired/warning
- HRV 기반 z-score + RHR penalty
- `ConditionScore.Status.label` → "Excellent"/"Good"/"Fair"/"Tired"/"Warning"
- `ConditionScore.Status.emoji` → 😊/🙂/😐/😴/⚠️
- Color: `DS.Color.scoreExcellent/Good/Fair/Tired/Warning`

### TrainingReadiness (Activity 탭)
- 0-100 점수, Status: ready/moderate/light/rest
- HRV + RHR + Sleep + Fatigue + Trend 복합
- `TrainingReadiness.Status.label` → "Ready to Train"/"Moderate"/"Light Activity"/"Rest Day"
- `TrainingReadiness.Status.iconName` → flame.fill/figure.walk/leaf.fill/bed.double.fill

### WellnessScore (Wellness 탭)
- 0-100 점수, Status: excellent/good/fair/tired/warning
- Sleep + Condition + Body 복합
- `WellnessScore.Status.label` → "Excellent"/"Good"/"Fair"/"Tired"/"Warning"
- `WellnessScore.Status.iconName` → checkmark.circle.fill/hand.thumbsup.fill/...

## Proposed Approach

### Widget Extension 구조

```
DUNE/
├── DUNEWidget/                    ← 새 WidgetKit Extension target
│   ├── WellnessDashboardWidget.swift  ← Widget definition + TimelineProvider
│   ├── WellnessDashboardEntry.swift   ← TimelineEntry (3 scores)
│   ├── Views/
│   │   ├── SmallWidgetView.swift
│   │   ├── MediumWidgetView.swift
│   │   └── LargeWidgetView.swift
│   ├── WidgetDataProvider.swift       ← HealthKit query for widget
│   └── Info.plist
├── Domain/Models/                     ← 기존 모델 재사용
│   ├── ConditionScore.swift           (Shared target membership)
│   ├── TrainingReadiness.swift        (Shared target membership)
│   └── WellnessScore.swift            (Shared target membership)
```

### TimelineEntry 설계

```swift
struct WellnessDashboardEntry: TimelineEntry {
    let date: Date
    let conditionScore: Int?
    let conditionStatus: ConditionScore.Status?
    let readinessScore: Int?
    let readinessStatus: TrainingReadiness.Status?
    let wellnessScore: Int?
    let wellnessStatus: WellnessScore.Status?
}
```

### 위젯 크기별 레이아웃

#### Small (2×2)
```
┌─────────────┐
│   DUNE      │
│  C:82  R:75 │
│  W:68       │
│  Good ☀️    │
└─────────────┘
```
- 3개 점수를 숫자로 간결 표시
- 가장 낮은 점수의 status label 표시

#### Medium (4×2)
```
┌───────────────────────────────┐
│  Condition  │  Readiness │ Wellness │
│     82      │     75     │    68    │
│   Good 🙂  │  Moderate  │   Fair   │
│  ●●●●○     │   ●●●○○   │  ●●○○○  │
└───────────────────────────────┘
```
- 3개 점수 나란히, 각각 점수 + status label + 5단계 도트 인디케이터
- 각 점수별 status color 적용

#### Large (4×4)
```
┌───────────────────────────────┐
│          DUNE Today           │
├───────────┬───────────────────┤
│ Condition │  82  Good 🙂     │
│           │  HRV above base  │
├───────────┼───────────────────┤
│ Readiness │  75  Moderate     │
│           │  Normal training  │
├───────────┼───────────────────┤
│ Wellness  │  68  Fair         │
│           │  Sleep needs attn │
├───────────┴───────────────────┤
│       Updated 8:30 AM         │
└───────────────────────────────┘
```
- 3개 점수 각각 점수 + status + narrativeMessage (1줄 요약)
- 마지막 업데이트 시간 표시

### 데이터 흐름

1. **TimelineProvider**: `getTimeline(in:completion:)`
2. **HealthKit Background Delivery** 또는 **앱 실행 시 AppStorage/UserDefaults 공유**
3. Widget Extension은 HealthKit 직접 쿼리 가능 (entitlement 필요)
4. **App Group** shared container로 계산된 점수 캐시 (HealthKit 쿼리 실패 fallback)

### 딥링크

- `dune://dashboard/condition` → Dashboard 탭 Condition 상세
- `dune://activity/readiness` → Activity 탭 Training Readiness 상세
- `dune://wellness` → Wellness 탭

## Constraints

### 기술적 제약
- **WidgetKit Timeline**: 시스템이 새로고침 빈도 제어 (일반적으로 ~15분 단위)
- **HealthKit in Extension**: Widget Extension에서 HK 쿼리 가능하나 background delivery는 main app만
- **App Group**: main app ↔ widget extension 데이터 공유에 App Group 필수
- **SwiftUI Only**: WidgetKit은 SwiftUI 전용 (UIKit 불가)
- **No interactivity**: iOS 17+ `AppIntent` 기반 인터랙션 가능하나 MVP에서는 탭→딥링크만
- **Bundle size**: Domain 모델을 shared framework 또는 target membership으로 공유

### 프로젝트 제약
- xcodegen (`project.yml`) 에 Widget Extension target 추가 필요
- `scripts/build-ios.sh`에 widget scheme 포함 필요
- 기존 DS (Design System) 색상/폰트를 widget에서도 사용 → shared target membership

## Edge Cases

1. **데이터 완전 부재**: 3개 점수 모두 nil → "Waiting for today's data" placeholder
2. **부분 데이터**: 있는 점수만 표시, 없는 항목은 숨김 (사용자 선택)
3. **Baseline 미완성**: Condition 점수 계산 불가 시 "Calibrating..." 표시
4. **자정 넘김**: Timeline이 자정에 새로고침되어 전날 데이터 표시 방지
5. **HealthKit 권한 미승인**: "Grant HealthKit access in DUNE app" 안내
6. **App Group 데이터 손실**: HealthKit 직접 쿼리 fallback

## Scope

### MVP (Must-have)
- Small + Medium + Large 3가지 크기
- 3개 점수 숫자 + status label 표시
- 가용 데이터만 표시 (부분 데이터 graceful)
- 위젯 탭 → 앱 열기 (딥링크)
- App Group을 통한 점수 캐시 공유
- DS 색상 체계 적용

### Nice-to-have (Future)
- 미니 트렌드 스파크라인 차트 (7일)
- 전날 대비 변화량 표시 (↑↓)
- Lock Screen 위젯 (accessoryRectangular, accessoryCircular)
- watchOS complication 연동
- Interactive Widget (iOS 17+ AppIntent)으로 특정 점수 탭 → 인앱 상세
- 위젯 설정에서 표시할 점수 선택 (Configurable Widget)
- Live Activity로 운동 중 실시간 표시

## Open Questions

1. **Score 계산 위치**: Widget Extension에서 UseCase를 직접 실행할지, main app에서 계산한 결과를 App Group으로 전달할지?
   - 권장: main app에서 계산 → UserDefaults(suiteName: appGroup)에 저장 → widget이 읽기
   - 이유: UseCase 의존성(HRV baseline 등)이 복잡하여 extension에서 재현 비용 높음
2. **새로고침 전략**: Timeline reload policy를 `.atEnd`로 할지, `.after(date)`로 특정 시간(아침 7시 등)에 맞출지?
3. **watchOS Widget**: Apple Watch의 Smart Stack 위젯도 동시 지원할지? (별도 target 필요)

## Next Steps

- [ ] `/plan wellness-dashboard-widget`으로 구현 계획 생성
- [ ] project.yml에 Widget Extension target 구조 설계
- [ ] App Group identifier 결정 및 entitlement 설정
