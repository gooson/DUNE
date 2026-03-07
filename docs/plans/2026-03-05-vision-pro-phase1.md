---
tags: [visionos, vision-pro, phase1, porting, spatial-widgets, chart3d]
date: 2026-03-05
category: plan
status: draft
---

# Plan: Vision Pro Phase 1 — 기본 포팅 + Spatial Widgets + Chart3D

## 개요

DUNE iOS 앱을 visionOS 26에 포팅하고, Spatial Widgets 및 Chart3D 3D 차트를 추가한다.
brainstorm 문서(`docs/brainstorms/2026-03-05-vision-pro-features.md`)의 Phase 1-2를 통합 구현.

## 범위

### In Scope (이번 구현)
1. **project.yml에 visionOS 타겟 추가** (DUNEVision)
2. **플랫폼 호환성 처리** (`#if os(visionOS)` 가드)
3. **visionOS 전용 App Entry Point** (DUNEVisionApp)
4. **Glass material 기반 Shared Space 윈도우**
5. **Spatial Widgets** (Condition Score, Training Readiness, Sleep Summary)
6. **Chart3D 3D 차트** (Condition Scatter, Training Volume)
7. **TODO 파일: Phase 2-5 잔여 기능 등록**

### Out of Scope (향후)
- RealityKit 3D 인체 모델 (Phase 3)
- ImmersiveSpace 몰입 경험 (Phase 4)
- SharePlay 소셜 기능 (Phase 5)
- 실제 빌드 검증 (visionOS 시뮬레이터 환경 필요)

---

## 영향 파일 분석

### 신규 생성

| 파일 | 목적 |
|------|------|
| `DUNEVision/App/DUNEVisionApp.swift` | visionOS 전용 앱 진입점 |
| `DUNEVision/App/VisionContentView.swift` | visionOS 메인 뷰 (TabView + glass) |
| `DUNEVision/Resources/Info.plist` | visionOS Info.plist |
| `DUNEVision/Resources/DUNEVision.entitlements` | visionOS entitlements |
| `DUNEVision/Presentation/Chart3D/ConditionScatter3DView.swift` | HRV×RHR×Sleep 3D 산점도 |
| `DUNEVision/Presentation/Chart3D/TrainingVolume3DView.swift` | 근육그룹×주차×볼륨 3D 차트 |
| `DUNEVision/Presentation/Chart3D/Chart3DContainerView.swift` | 3D 차트 네비게이션 컨테이너 |
| `DUNEVision/Presentation/Dashboard/VisionDashboardView.swift` | visionOS 대시보드 (glass material) |
| `DUNEVisionWidgets/DUNEVisionWidgets.swift` | Widget Bundle 진입점 |
| `DUNEVisionWidgets/ConditionScoreWidget.swift` | 컨디션 점수 Spatial Widget |
| `DUNEVisionWidgets/TrainingReadinessWidget.swift` | 훈련 준비도 Spatial Widget |
| `DUNEVisionWidgets/SleepSummaryWidget.swift` | 수면 요약 Spatial Widget |
| `DUNEVisionWidgets/Shared/WidgetDataProvider.swift` | Widget 데이터 공급 (HealthKit + SwiftData) |
| `DUNEVisionWidgets/Resources/Info.plist` | Widget Extension Info.plist |
| `todos/XXX-ready-p2-vision-pro-phase2-volumetric.md` | Phase 2 TODO |
| `todos/XXX-ready-p2-vision-pro-phase3-immersive.md` | Phase 3 TODO |
| `todos/XXX-ready-p3-vision-pro-phase4-social.md` | Phase 4 TODO |

### 수정

| 파일 | 변경 | 이유 |
|------|------|------|
| `DUNE/project.yml` | DUNEVision + DUNEVisionWidgets 타겟 추가 | visionOS 빌드 대상 |
| `DUNE/DUNE/Presentation/Shared/Components/DesertWaveBackground.swift` | `UIGraphicsImageRenderer` → `#if os(visionOS)` 가드 | UIKit 미지원 |
| `DUNE/DUNE/Presentation/Shared/Components/ForestWaveBackground.swift` | UIKit 의존 가드 | UIKit 미지원 |
| `DUNE/DUNE/Presentation/Shared/Components/HanokWaveBackground.swift` | UIKit 의존 가드 | UIKit 미지원 |
| `DUNE/DUNE/Presentation/Shared/Components/SakuraWaveBackground.swift` | UIKit 의존 가드 | UIKit 미지원 |
| `DUNE/DUNE/Presentation/Shared/Components/ShanksWaveBackground.swift` | UIKit 의존 가드 | UIKit 미지원 |
| `DUNE/DUNE/Presentation/Shared/Components/WaveRefreshIndicator.swift` | UIKit 의존 가드 | UIKit 미지원 |
| `DUNE/DUNE/Data/HealthKit/CardioSessionManager.swift` | CLLocationManager `#if os(iOS)` | GPS 미지원 |
| `DUNE/DUNE/Data/Location/LocationTrackingService.swift` | `#if os(iOS)` 전체 래핑 | GPS 미지원 |
| `DUNE/DUNE/Data/Motion/MotionTrackingService.swift` | `#if os(iOS)` 전체 래핑 | CMPedometer 미지원 |
| `DUNE/DUNE/Data/WatchConnectivity/WatchSessionManager.swift` | `#if os(iOS)` 전체 래핑 | WatchConnectivity 미지원 |
| `DUNE/DUNE/App/DUNEApp.swift` | Watch/Location/Motion 초기화 `#if os(iOS)` | 플랫폼 분기 |

---

## 구현 단계

### Step 1: project.yml에 visionOS 타겟 추가

```yaml
# project.yml에 추가할 내용
options:
  deploymentTarget:
    visionOS: "26.0"

targets:
  DUNEVision:
    type: application
    platform: visionOS
    sources:
      - path: ../DUNEVision
      - path: Domain      # 100% 공유
      - path: Data/Persistence  # SwiftData 공유
      - path: Data/HealthKit    # HealthKit 공유
      - path: Data/Services     # CloudKit 등
      - path: ../Shared/Resources/Colors.xcassets
    settings:
      PRODUCT_BUNDLE_IDENTIFIER: com.raftel.dailve.vision
      XROS_DEPLOYMENT_TARGET: "26.0"
    dependencies:
      - sdk: HealthKit.framework
    entitlements:
      properties:
        com.apple.developer.healthkit: true

  DUNEVisionWidgets:
    type: app-extension
    platform: visionOS
    sources:
      - path: ../DUNEVisionWidgets
    settings:
      PRODUCT_BUNDLE_IDENTIFIER: com.raftel.dailve.vision.widgets
    dependencies:
      - sdk: WidgetKit.framework
      - sdk: SwiftUI.framework
```

### Step 2: 플랫폼 호환성 처리

UIKit 의존 파일에 `#if canImport(UIKit)` 가드 추가.
visionOS에서는 UIKit이 제한적으로 가용하므로 `UIGraphicsImageRenderer` 등 특정 API 가드.

```swift
// DesertWaveBackground.swift 예시
#if canImport(UIKit) && !os(visionOS)
private static let shimmerImage: UIImage = { ... }()
#endif
```

### Step 3: visionOS 앱 진입점

DUNEVisionApp.swift — iOS DUNEApp.swift 기반이되, Watch/Location/Motion 제외.

### Step 4: Glass Material 기반 메인 뷰

VisionContentView.swift — TabView를 visionOS 스타일로 구성.
`.tabViewStyle(.automatic)` 사용 (`.sidebarAdaptable`는 visionOS 미지원 가능성).

### Step 5: Chart3D 3D 차트

- `ConditionScatter3DView`: Chart3D + PointMark(x:y:z:) — HRV, RHR, Sleep 3축
- `TrainingVolume3DView`: Chart3D + BarMark/SurfacePlot — 근육그룹별 주간 볼륨

### Step 6: Spatial Widgets

WidgetKit extension으로 3개 위젯 구현:
- `.supportedMountingStyles([.elevated, .recessed])`
- `.containerBackground(.fill.tertiary, for: .widget)`
- Timeline Provider로 HealthKit 데이터 공급

### Step 7: TODO 파일 등록

나머지 Phase 2-5를 todos/ 디렉토리에 등록.

---

## 기술 결정

| 결정 | 선택 | 근거 |
|------|------|------|
| 앱 구조 | 별도 타겟 (DUNEVision) | iOS 앱과 독립 빌드/배포, 플랫폼별 UI 최적화 |
| Domain/Data 공유 | source reference로 공유 | watchOS 패턴과 동일, DRY |
| Wave Background | visionOS에서는 단순 gradient로 대체 | UIKit 의존 제거, glass material과 조화 |
| Chart3D | visionOS 전용 뷰로 격리 | iOS 26에서도 Chart3D 지원하나, 3D는 visionOS 특화 UX |
| Widget 데이터 | App Group + SwiftData 공유 | 위젯에서 직접 HealthKit 접근은 제한적 |

---

## 검증 계획

1. project.yml 구문 유효성 (xcodegen dry-run)
2. 각 신규 파일 Swift 컴파일 가능 여부
3. `#if os(visionOS)` 가드가 iOS 빌드를 깨뜨리지 않는지 확인
4. Widget TimelineProvider 데이터 흐름 검증
5. Chart3D API 사용법 정확성 (Apple 문서 기반)

---

## 리스크

| 리스크 | 대응 |
|--------|------|
| visionOS 시뮬레이터 부재로 실제 빌드 불가 | 코드 구조와 API 정확성에 집중, 컴파일은 환경 구축 후 |
| Chart3D API가 visionOS 전용일 수 있음 | Apple 문서 확인 — iOS 26+에서도 지원 확인됨 |
| WidgetKit Spatial Widget API 변경 가능 | 최신 WWDC25 세션 기반 구현 |
| UIKit 가드가 기존 iOS 빌드 영향 | `#if canImport(UIKit) && !os(visionOS)` 패턴으로 안전 분기 |
