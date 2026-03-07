---
tags: [visionos, data-flow, verification, healthkit, localization, dry]
date: 2026-03-07
category: plan
status: approved
---

# Vision Pro 데이터 구조 검증

## Problem Statement

visionOS 앱(DUNEVision)의 데이터 플로우에 구조적 결함이 있다.
`SharedHealthDataService`가 앱 진입점에서 주입되지만, 하위 View에 전달되지 않거나 전혀 소비되지 않는 경로가 존재한다.
또한 fatigue label 중복, 비국제화 문자열, 데모 데이터 고착 등의 문제가 확인되었다.

## Scope

**검증 대상**: DUNEVision 타겟 내 데이터 플로우 무결성
**범위 외**: 실제 HealthKit 연동 구현 (Phase 4 범위), RealityKit 렌더링 로직

## Identified Issues

### Issue 1: Chart3DContainerView 데이터 미전달 (P2)

- `Chart3DContainerView`가 `sharedHealthDataService`를 받지만 자식 뷰에 전달하지 않음
- `ConditionScatter3DView`, `TrainingVolume3DView` 모두 자체 데모 데이터만 사용
- 코드 주석에 "In production, this will be replaced" 명시 — 향후 연결 대비 파라미터 준비 필요

**수정**: 3D View들에 `sharedHealthDataService` 파라미터 추가 + 데모 fallback 유지

### Issue 2: Chart3DType.displayName 비국제화 (P1)

- `Chart3DType.displayName`이 `String(localized:)` 없이 하드코딩
- localization.md Leak Pattern 4 위반

**수정**: `String(localized:)` 래핑 + xcstrings 등록

### Issue 3: fatigueLabel 중복 + 불일치 (P2)

- `VisionMuscleMapExperienceView.fatigueLabel(for:)` — private func
- `VisionSpatialSceneSupport` `MuscleLoad.fatigueLabel` — computed property
- `.fullyRecovered` 케이스: "Fully Recovered" vs "Recovered" 불일치

**수정**: `FatigueLevel`에 `displayName` computed property 추가 → 두 곳 모두 이를 참조

### Issue 4: VisionDashboardView가 sharedHealthDataService 미소비 (P3)

- `sharedHealthDataService`를 받지만 어디서도 호출하지 않음
- 모든 메트릭이 "--" placeholder

**수정**: 현재 Phase에서는 TODO 주석으로 명시. 실제 데이터 연결은 별도 Phase 대상

### Issue 5: VisionDashboardView.metricCard의 String 파라미터 (P2)

- `metricCard(title:value:unit:icon:)` 함수가 `title: String`을 받아 `Text(title)` 전달
- localization.md Leak Pattern 1 위반

**수정**: `title` 파라미터를 `LocalizedStringKey`로 변경

## Affected Files

| 파일 | 변경 유형 | 이유 |
|------|----------|------|
| `DUNE/Domain/Models/FatigueLevel.swift` | 수정 | `displayName` computed property 추가 |
| `DUNEVision/Presentation/Chart3D/Chart3DContainerView.swift` | 수정 | Chart3DType.displayName 국제화 + 데이터 서비스 전달 |
| `DUNEVision/Presentation/Chart3D/ConditionScatter3DView.swift` | 수정 | sharedHealthDataService 파라미터 추가 (옵셔널, 데모 fallback) |
| `DUNEVision/Presentation/Chart3D/TrainingVolume3DView.swift` | 수정 | sharedHealthDataService 파라미터 추가 (옵셔널, 데모 fallback) |
| `DUNEVision/Presentation/Activity/VisionMuscleMapExperienceView.swift` | 수정 | private fatigueLabel 제거 → FatigueLevel.displayName 사용 |
| `DUNEVision/Presentation/Volumetric/VisionSpatialSceneSupport.swift` | 수정 | MuscleLoad.fatigueLabel 제거 → FatigueLevel.displayName 사용 |
| `DUNEVision/Presentation/Dashboard/VisionDashboardView.swift` | 수정 | metricCard title LocalizedStringKey + TODO 주석 |
| `Shared/Resources/Localizable.xcstrings` | 수정 | 새 문자열 키 등록 (en/ko/ja) |

## Implementation Steps

### Step 1: FatigueLevel.displayName 추가

`DUNE/Domain/Models/FatigueLevel.swift`에 `displayName: String` computed property 추가.
`String(localized:)` 패턴으로 11개 case 모두 커버.

**Verification**: FatigueLevel.allCases.map(\.displayName) 가 모두 비어있지 않은 String 반환

### Step 2: fatigueLabel 중복 제거

- `VisionMuscleMapExperienceView.fatigueLabel(for:)` → `level.displayName`으로 대체
- `VisionSpatialSceneSupport MuscleLoad.fatigueLabel` → `fatigueLevel.displayName`으로 대체

**Verification**: 두 파일 모두 컴파일 성공 + fatigueLabel 관련 private func/computed 없음

### Step 3: Chart3DType.displayName 국제화

`String(localized:)` 래핑.

**Verification**: `Localizable.xcstrings`에 "Condition", "Training" 키 존재

### Step 4: Chart3D 자식 뷰에 데이터 서비스 파라미터 추가

- `ConditionScatter3DView(sharedHealthDataService:)` — 옵셔널 파라미터
- `TrainingVolume3DView(sharedHealthDataService:)` — 옵셔널 파라미터
- `Chart3DContainerView`에서 전달

**Verification**: Chart3DContainerView가 자식 뷰에 서비스 전달. 자식 뷰는 nil이면 기존 데모 데이터 사용

### Step 5: VisionDashboardView metricCard 국제화

- `metricCard(title: String, ...)` → `metricCard(title: LocalizedStringKey, ...)`

**Verification**: 기존 호출부 컴파일 성공

### Step 6: xcstrings 등록

새 문자열 키를 `Shared/Resources/Localizable.xcstrings`에 en/ko/ja 3개 언어로 등록:
- FatigueLevel displayName 11개
- Chart3DType displayName 2개

**Verification**: xcstrings에 키 존재 + 3개 언어 번역 포함

## Test Strategy

- **빌드 검증**: `scripts/build-ios.sh` 통과
- **기존 테스트**: DUNETests 전체 통과 (regression 없음)
- **FatigueLevel.displayName**: Domain 모델이므로 유닛 테스트 추가 대상 (allCases가 빈 문자열 아닌지)

## Risks

| 리스크 | 영향 | 완화 |
|--------|------|------|
| FatigueLevel 변경 시 iOS 기존 참조 | 낮음 | displayName은 신규 프로퍼티, 기존 코드 영향 없음 |
| Chart3D 파라미터 추가로 호출부 깨짐 | 낮음 | 옵셔널 + 기본값 nil 사용 |
| xcstrings 충돌 | 낮음 | main 기준 최신 xcstrings 확인 |
