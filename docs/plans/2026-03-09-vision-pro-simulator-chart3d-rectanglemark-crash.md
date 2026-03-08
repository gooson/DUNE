---
topic: vision-pro-simulator-chart3d-rectanglemark-crash
date: 2026-03-09
status: draft
confidence: high
related_solutions:
  - docs/solutions/architecture/2026-03-08-visionos-real-data-pipeline.md
  - docs/solutions/general/2026-03-08-common-chart-selection-overlay.md
related_brainstorms:
  - docs/brainstorms/2026-03-08-vision-pro-production-roadmap.md
---

# Implementation Plan: Vision Pro Simulator Chart3D RectangleMark Crash

## Context

`DUNEVision`를 Vision Pro simulator에서 실행하면 Swift Charts runtime이 `A rectangle mark needs to have exactly two extents.` fatal error로 중단된다. 현재 가장 유력한 원인은 `TrainingVolume3DView`의 `Chart3D`에서 `RectangleMark(x:y:z:)`에 scalar 값 3개를 전달하는 잘못된 구성이다. Apple RectangleMark 문서는 3D rectangle mark에 대해 "값 1개 + range 2개"를 요구한다.

## Requirements

### Functional

- Vision Pro simulator에서 `DUNEVision`의 Chart3D 화면 진입 시 더 이상 runtime crash가 발생하지 않아야 한다.
- `TrainingVolume3DView`는 기존 축 의미(muscle group, volume, week)를 유지한 채 데이터를 계속 시각화해야 한다.
- invalid / non-finite 데이터는 기존과 동일하게 plotting에서 제외되어야 한다.

### Non-functional

- 수정 범위는 crash 원인 파일과 필요한 테스트로 제한한다.
- 기존 visionOS 실데이터 파이프라인과 UI 구조는 유지한다.
- 순수 계산은 가능하면 testable helper로 분리해 회귀를 막는다.

## Approach

`TrainingVolume3DView`의 `RectangleMark`를 Chart3D contract에 맞게 고친다. 각 mark는 `x`와 `y`를 range로 제공하고 `z`는 주차 중심값으로 고정해, category 폭과 volume 높이를 가진 vertical rectangle plane으로 렌더링한다. 이를 위해 `TrainingVolumePoint`에 x/y plotting range helper를 추가하거나 동등한 로컬 helper를 둔다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| `PointMark`로 교체 | API misuse를 즉시 제거 | 차트 의미가 scatter로 바뀌고 volume surface가 사라짐 | 기각 |
| `RectangleMark`를 2-range + 1-scalar로 수정 | 현재 시각 구조를 최대한 유지, 크래시 원인 직접 제거 | 3D bar가 아닌 plane 표현 | 선택 |
| Chart3D를 다른 mark 타입으로 전면 교체 | 더 풍부한 시각화 가능성 | 범위가 커지고 검증 비용 증가 | 기각 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNEVision/Presentation/Chart3D/TrainingVolume3DView.swift` | modify | invalid 3D `RectangleMark` inputs를 valid range-based inputs로 수정 |
| `DUNETests/TrainingVolume3DViewTests.swift` | add | plotting range helper가 Chart3D contract를 만족하는지 검증 |

## Implementation Steps

### Step 1: Confirm the crash source and plotting contract

- **Files**: `DUNEVision/Presentation/Chart3D/TrainingVolume3DView.swift`
- **Changes**: existing `RectangleMark` usage를 확인하고 Apple docs 기준으로 valid 3D initializer contract를 정리한다.
- **Verification**: current file inspection + Apple docs note 확인

### Step 2: Replace scalar-only RectangleMark inputs with valid extents

- **Files**: `DUNEVision/Presentation/Chart3D/TrainingVolume3DView.swift`
- **Changes**: muscle/week center values 주변에 plotting range를 계산하고, volume은 `0..<volume` range로 전달한다.
- **Verification**: code review로 `RectangleMark`가 range 2개 / scalar 1개 구성을 만족하는지 확인

### Step 3: Add regression coverage for plotting math

- **Files**: `DUNETests/TrainingVolume3DViewTests.swift`
- **Changes**: range helper가 expected width/height center를 유지하는지 검증한다.
- **Verification**: Swift Testing unit test 추가 및 실행

### Step 4: Build and target-specific verification

- **Files**: none
- **Changes**: build/test 및 가능하면 visionOS target build를 실행한다.
- **Verification**: `scripts/build-ios.sh`, 관련 `xcodebuild test`, visionOS build command

## Edge Cases

| Case | Handling |
|------|----------|
| `volume == 0` | 기존 `isPlottable` 필터로 plotting 제외 유지 여부를 확인하고, 포함 시에도 zero-height range를 피한다 |
| `volume`이 매우 작음 | `0..<volume` range가 finite면 그대로 사용 |
| `muscleIndex` 또는 `week`가 non-finite | 기존 `isPlottable`로 제외 |
| detached HEAD 상태 | 수정/검증은 진행하되 ship 단계에서 PR 생성/merge 불가 사유로 기록 |

## Testing Strategy

- Unit tests: plotting range helper의 폭/높이/center를 검증하는 Swift Testing 추가
- Integration tests: 없음
- Manual verification: Vision Pro simulator에서 Chart3D 화면 진입 시 crash 재현이 사라졌는지 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Rectangle plane orientation이 기대 시각과 다를 수 있음 | medium | medium | 축 의미를 유지하는 최소 수정으로 제한하고, 필요 시 follow-up UX polish로 분리 |
| DUNEVision 타입이 `DUNETests`에서 직접 접근 불가할 수 있음 | medium | low | helper visibility를 조정하거나 build-only 검증으로 대체 |
| ship 자동화가 detached HEAD 때문에 중단될 수 있음 | high | low | fix 자체와 검증을 완료하고 ship blocker로 명시 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: runtime assert 메시지와 Apple RectangleMark 3D 공식 문서 요구사항이 현재 코드와 직접 일치한다. 수정 범위도 단일 mark 구성에 집중되어 있다.
