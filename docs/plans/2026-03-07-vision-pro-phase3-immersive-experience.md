---
topic: vision-pro-phase3-immersive-experience
date: 2026-03-07
status: approved
confidence: medium
related_solutions:
  - docs/solutions/architecture/2026-03-07-vision-pro-volumetric-phase2.md
related_brainstorms:
  - docs/brainstorms/2026-03-05-vision-pro-features.md
---

# Implementation Plan: Vision Pro Phase 3 Immersive Experience

## Context

`DUNEVision`은 Shared Space 대시보드, 3D charts, volumetric recovery window까지는 구현됐지만, roadmap의 다음 단계인 `ImmersiveSpace` 경험은 비어 있다. 이번 단계의 목적은 Vision Pro에서 컨디션/회복/수면 데이터를 더 몰입감 있게 체험하도록 만드는 것이다.

다만 브레인스토밍 초안에 적힌 "호흡 감지 API"는 공개 visionOS 앱에서 바로 사용할 수 있는 안정적 공용 API로 보기 어렵다. `ImmersiveSpace`/`progressive immersion`/`SurroundingsEffect`는 현재 SDK에서 확인되지만, main camera access는 enterprise API 계열이다. 따라서 이번 구현은 **자동 호흡 감지 대신 guided cadence 기반 회복 세션**으로 범위를 조정한다.

## Requirements

### Functional

- `DUNEVisionApp`에 `ImmersiveSpace`를 추가한다.
- Today surface에서 immersive experience를 열 수 있어야 한다.
- immersive space 내부에서 다음 3개 experience를 전환할 수 있어야 한다.
  - Condition Atmosphere
  - Guided Recovery Session
  - Sleep Journey
- Condition score 기반으로 surroundings / color / copy가 달라져야 한다.
- Shared sleep stages 기반으로 Sleep Journey timeline을 구성해야 한다.
- Guided Recovery Session 완료 시 HealthKit `mindfulSession` 저장을 시도해야 한다.
- 데이터가 부족할 때는 graceful fallback copy/state를 제공해야 한다.

### Non-functional

- shared data transformation은 `DUNE/Domain`에 두어 테스트 가능해야 한다.
- visionOS UI-specific 로직은 `DUNEVision/` 하위에 격리한다.
- 새 로직은 Swift Testing으로 검증한다.
- localization leak 없이 새 사용자 문자열을 `Localizable.xcstrings`에 등록한다.
- 기존 volumetric / shared snapshot 구조를 재사용하고, 새 asset dependency는 추가하지 않는다.

## Approach

`SharedHealthSnapshot`을 immersive-friendly scene summary로 변환하는 shared analyzer를 새로 추가한다. 이 analyzer는 condition score, sleep stages, sleep totals를 기반으로 atmosphere preset, recovery recommendation, sleep journey segments를 만든다.

`DUNEVision`에서는 이 analyzer 결과를 `VisionImmersiveExperienceViewModel`이 받아 `ImmersiveSpace` 안의 SwiftUI + simple RealityKit scene에 공급한다. surroundings tint/dimming은 `preferredSurroundingsEffect`로 처리하고, 3D geometry는 primitive mesh와 glass panel을 조합해 구현한다. Guided Recovery Session은 cadence-driven breathing loop와 manual completion 버튼으로 구성하고, completion 시 `HealthKitManager.saveMindfulSession(start:end:)`를 호출한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 공개 SDK 범위에서 guided immersive session + shared analyzer | 테스트 가능, compile risk 낮음, 현재 구조와 잘 맞음 | 자동 호흡 감지 없음 | 채택 |
| main camera / sensor 기반 breath tracking까지 포함 | 브레인스토밍 원안에 가장 가까움 | enterprise API/권한 리스크, 구현/검증 불안정 | 기각 |
| Reality Composer Pro / custom skybox asset 중심 구현 | 시각적 임팩트 큼 | 새 asset pipeline, target/CI 복잡도 증가 | 기각 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `docs/plans/2026-03-07-vision-pro-phase3-immersive-experience.md` | new | 이번 구현 계획서 |
| `DUNE/Domain/Models/ImmersiveRecoverySummary.swift` | new | immersive scene summary model |
| `DUNE/Domain/UseCases/ImmersiveRecoveryAnalyzer.swift` | new | snapshot -> immersive summary analyzer |
| `DUNETests/ImmersiveRecoveryAnalyzerTests.swift` | new | analyzer transformation tests |
| `DUNE/Data/HealthKit/HealthKitManager.swift` | modify | mindful session share/save helper 추가 |
| `DUNEVision/App/DUNEVisionApp.swift` | modify | `ImmersiveSpace` scene 추가 |
| `DUNEVision/App/VisionContentView.swift` | modify | immersive open action wiring |
| `DUNEVision/Presentation/Dashboard/VisionDashboardView.swift` | modify | immersive quick action / toolbar entry 추가 |
| `DUNEVision/Presentation/Immersive/VisionImmersiveExperienceViewModel.swift` | new | immersive state orchestration |
| `DUNEVision/Presentation/Immersive/VisionImmersiveExperienceView.swift` | new | immersive control surface + layout |
| `DUNEVision/Presentation/Immersive/VisionImmersiveSceneView.swift` | new | simple RealityKit/SwiftUI immersive scene |
| `DUNE/Resources/Localizable.xcstrings` | modify | 새 immersive copy 추가 |
| `todos/019-ready-p2-vision-pro-phase3-immersive-experience.md` | modify | 완료 후 status 갱신 |

## Implementation Steps

### Step 1: Shared analyzer와 domain model 추가

- **Files**: `DUNE/Domain/Models/ImmersiveRecoverySummary.swift`, `DUNE/Domain/UseCases/ImmersiveRecoveryAnalyzer.swift`
- **Changes**:
  - `ConditionAtmospherePreset`, `RecoveryRecommendation`, `BreathingCadence`, `SleepJourneySegment` 등을 포함한 summary model 정의
  - `SharedHealthSnapshot`에서 condition/sleep 정보를 읽어 immersive summary 생성
  - sleep stages는 contiguous stage 기준으로 압축하고, `todaySleepStages`가 비면 `latestSleepStages` fallback 사용
- **Verification**: analyzer가 high/medium/low condition, sleep fallback, no-data 케이스를 올바르게 생성

### Step 2: HealthKit mindful session 저장 경로 추가

- **Files**: `DUNE/Data/HealthKit/HealthKitManager.swift`
- **Changes**:
  - `mindfulSession` share permission 추가
  - `saveMindfulSession(start:end:)` async helper 추가
  - visionOS에서도 안전하게 no-op/error handling 되도록 로깅 정리
- **Verification**: compile 통과, analyzer/UI에서 completion 호출 가능

### Step 3: visionOS immersive space 진입점 추가

- **Files**: `DUNEVision/App/DUNEVisionApp.swift`, `DUNEVision/App/VisionContentView.swift`, `DUNEVision/Presentation/Dashboard/VisionDashboardView.swift`
- **Changes**:
  - `ImmersiveSpace(id: ...)` 추가
  - Today dashboard에서 immersive space 열기 버튼 연결
  - open state/result handling 및 multiple windows guard 적용
- **Verification**: visionOS target build 통과, immersive entry action이 wiring 됨

### Step 4: immersive view model / scene 구현

- **Files**: `DUNEVision/Presentation/Immersive/VisionImmersiveExperienceViewModel.swift`, `DUNEVision/Presentation/Immersive/VisionImmersiveExperienceView.swift`, `DUNEVision/Presentation/Immersive/VisionImmersiveSceneView.swift`
- **Changes**:
  - shared snapshot fetch + analyzer orchestration
  - `Condition Atmosphere`, `Guided Recovery`, `Sleep Journey` 3개 mode 전환
  - `preferredSurroundingsEffect`와 primitive scene으로 ambience 표현
  - recovery completion 버튼과 success/failure messaging 연결
- **Verification**: mode switch, no-data fallback, recovery completion flow가 동작

### Step 5: localization / tests / todo 마감

- **Files**: `DUNETests/ImmersiveRecoveryAnalyzerTests.swift`, `DUNE/Resources/Localizable.xcstrings`, `todos/019-ready-p2-vision-pro-phase3-immersive-experience.md`
- **Changes**:
  - 새 copy 번역 추가
  - analyzer test 추가
  - 구현 완료 후 todo status를 `done`으로 갱신
- **Verification**: unit tests 통과, localization review checkpoint 충족

## Edge Cases

| Case | Handling |
|------|----------|
| condition score가 없음 | neutral fallback atmosphere + explanatory copy 표시 |
| 오늘 수면 단계가 비어 있음 | `latestSleepStages` fallback 사용, historical indicator 노출 |
| 수면 단계가 전혀 없음 | Sleep Journey mode를 empty state로 표시 |
| shared snapshot service가 없음 | immersive summary를 unavailable state로 구성 |
| mindful session save 실패 | UI는 session completion 유지, failure message만 표시 |
| openImmersiveSpace 결과가 실패/취소 | dashboard에서 non-blocking message 또는 no-op 처리 |

## Testing Strategy

- Unit tests:
  - `ImmersiveRecoveryAnalyzerTests`
  - condition threshold -> atmosphere preset 매핑
  - recovery recommendation severity/cadence
  - sleep stage compression + latest fallback
- Integration tests:
  - `xcodebuild build -project DUNE/DUNE.xcodeproj -scheme DUNEVision -destination 'generic/platform=visionOS'`
- Manual verification:
  - Today에서 immersive experience open
  - 3개 mode 전환
  - low condition mock/fallback copy 확인
  - recovery completion 후 mindful session save path 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| `ImmersiveSpace` modifier 문법 차이로 compile issue 발생 | medium | high | local SDK swiftinterface 기준으로 scene modifier 적용 |
| guided recovery animation이 시각적으로 약할 수 있음 | medium | medium | surroundings effect + floating primitives + glass panel 조합으로 보강 |
| mindful session write authorization이 기존 flow와 충돌 | medium | medium | `HealthKitManager`의 share set 확장만 최소 반영하고 save 실패는 non-fatal 처리 |
| sleep stage 데이터가 visionOS 환경에서 빈 경우가 많음 | high | medium | latest fallback + empty-state copy로 degrade |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: `ImmersiveSpace`/`SurroundingsEffect`/`mindfulSession` 저장 경로는 SDK에서 확인 가능하지만, scene modifier 조합과 실제 시각 품질은 visionOS build/runtime에서 추가 검증이 필요하다.
