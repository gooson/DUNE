---
tags: [simulator, mock-data, visionos, swiftui, healthkit, swiftdata]
date: 2026-03-08
category: solution
status: implemented
---

# Simulator Advanced Mock Data

## Problem

시뮬레이터에서 설정 한 번으로 고급 수준의 건강 데이터와 운동 데이터를 채워 넣고, iOS 앱과 visionOS 앱에서 동일하게 검증할 수 있는 mock 진입점이 없었다.

특히 visionOS는 HealthKit이 실기기처럼 항상 사용 가능하지 않고, 자체 `ModelContainer`도 mirror snapshot 중심으로 제한되어 있어서 iOS와 같은 persistence 시딩 방식을 그대로 가져가면 빌드와 런타임이 쉽게 깨질 수 있었다.

## Root Cause

- 기존 mock 시드는 UI 테스트 전용으로 묶여 있어 런타임에서 수동 실행할 수 없었다.
- 건강 지표, workout summary, 심박 샘플, 수면, 걸음, 체성분, 운동별 기록이 하나의 일관된 시나리오로 연결되어 있지 않았다.
- 공용 서비스 레이어에서 iOS 전용 SwiftData 모델을 직접 참조하면 visionOS 타깃 컴파일과 mirror-only schema가 충돌했다.

## Solution

simulator에서만 활성화되는 `SimulatorAdvancedMockDataProvider`를 추가하고, 각 HealthKit query service가 mock mode 활성화 시 이 provider를 우선 읽도록 구성했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Data/Services/SimulatorAdvancedMockData.swift` | Advanced Athlete dataset, enable/reset state, persisted reference date, snapshot/workout/vitals/body mock builder 추가 | 앱 재실행 후에도 동일한 mock 상태를 유지하고 simulator 전용 데이터 소스를 일원화 |
| `DUNE/Presentation/Settings/SettingsView.swift` | simulator 전용 Mock Data section과 seed/reset 액션 추가 | iOS simulator에서 수동 진입점 제공 |
| `DUNEVision/App/DUNEVisionApp.swift` 외 vision view들 | mock mode 변경 notification을 받아 refresh/reload 하도록 연결 | visionOS simulator에서 HealthKit 없이도 즉시 화면 갱신 |
| `DUNE/Data/HealthKit/*QueryService.swift` | mock mode 활성화 시 provider 데이터를 반환하도록 분기 추가 | 기존 화면/뷰모델을 바꾸지 않고도 mock 데이터 사용 |
| `DUNE/Data/HealthKit/BodyCompositionWriteService.swift` | `BodyCompositionRecord` 브리징 생성자를 iOS 전용으로 제한 | visionOS target compile break 방지 |
| `DUNEVision/Presentation/Chart3D/Chart3DContainerView.swift` | chart content를 별도 `@ViewBuilder`로 분리하고 refresh id 적용 | visionOS SwiftUI 컴파일 오류 없이 3D 차트 새로고침 지원 |
| `DUNETests/SimulatorAdvancedMockDataTests.swift` | seed/reset/query fallback 테스트 추가 | mock provider와 query integration 회귀 방지 |
| `DUNEUITests/Smoke/SettingsSmokeTests.swift` | simulator mock controls 존재 확인 테스트 추가 | 설정 진입점 누락 방지 |

## Prevention

- simulator-only 기능이라도 공용 서비스에 넣을 때는 target별로 사용할 수 있는 모델 타입과 schema 범위를 먼저 확인한다.
- visionOS가 mirror-only container를 쓰는 경우에는 persistence 시딩보다 query fallback으로 기능을 설계한다.
- SwiftUI `switch` 블록에 refresh modifier를 직접 붙이기보다 별도 `@ViewBuilder`로 추출해 타깃별 컴파일 차이를 줄인다.
- mock dataset는 enable flag와 reference date를 함께 저장해서 재실행 시 drift가 생기지 않도록 한다.

## Verification

- `scripts/test-unit.sh --ios-only --no-regen --no-stream-log`
- `scripts/test-ui.sh --no-regen --no-stream-log --test-plan DUNEUITests-PR --only-testing DUNEUITests/SettingsSmokeTests/testSimulatorMockDataControlsExist`
- `xcodebuild -project DUNE/DUNE.xcodeproj -scheme DUNEVision -destination 'generic/platform=visionOS' -derivedDataPath .deriveddata/vision-build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build`

## Lessons Learned

- simulator mock 기능은 단순 fixture 추가보다 "데이터 소스 우선순위"를 명확히 정의하는 쪽이 유지보수에 유리하다.
- iOS와 visionOS가 같은 서비스 코드를 공유하더라도 SwiftData model availability는 동일하지 않으므로, persistence 경로와 query 경로를 분리하는 편이 안전하다.
