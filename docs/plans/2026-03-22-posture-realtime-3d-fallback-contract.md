---
topic: posture-realtime-3d-fallback-contract
date: 2026-03-22
status: approved
confidence: high
related_solutions:
  - docs/solutions/architecture/2026-03-16-realtime-dual-pipeline-posture.md
  - docs/solutions/performance/2026-03-16-cvpixelbuffer-pool-starvation-fix.md
  - docs/solutions/performance/2026-03-21-posture-front-camera-cgimage-fix.md
related_brainstorms:
  - docs/brainstorms/2026-03-16-realtime-video-posture-analysis.md
---

# Implementation Plan: Posture Realtime 3D Fallback Contract

## Context

latest `main`에서 `PostureCaptureService.detectPoseFromVideoFrame()`는 3D request 실패 시 2D fallback joint를 반환하도록 바뀌었다. 하지만 `RealtimePoseTracker`는 이 결과를 여전히 "정밀 3D 성공"으로 해석해 `is3DActive`를 올리고 최근 2D score를 precise 3D score로 덮어쓴다. 전면 카메라에서 3D가 실패하는 바로 그 조건에서 UI 배지와 score smoothing이 잘못된 상태를 보여준다.

## Requirements

### Functional

- realtime 경로가 `PostureCaptureResult`가 true 3D인지 2D fallback인지 구분할 수 있어야 한다.
- `RealtimePoseTracker`는 true 3D 결과에서만 `is3DActive`를 `true`로 만들고 score override를 수행해야 한다.
- 2D fallback 결과에서는 기존 2D skeleton/angle/score 흐름을 유지해야 한다.
- photo capture 및 저장 경로는 기존 동작을 유지해야 한다.

### Non-functional

- Domain/Data/Presentation 경계를 유지한다.
- 기존 `PostureCaptureResult` call site를 명시적으로 갱신해 계약 불일치를 남기지 않는다.
- 기존 로직 변경에 맞는 unit test를 추가한다.
- 기존 unrelated test/build 실패가 있더라도 이번 변경의 검증 결과와 분리해서 보고한다.

## Approach

`PostureCaptureResult`에 pose source metadata를 추가하고, 3D/2D fallback 반환 경로에서 명시적으로 채운다. `RealtimePoseTracker`는 이 metadata를 기준으로만 3D success 처리를 수행한다. 추론성 휴리스틱(`heightEstimation`, `z == 0`)은 사용하지 않는다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| `heightEstimation` 또는 `z == 0`로 2D fallback 추론 | 모델 추가 변경이 적음 | true 3D + `.reference`와 충돌 가능, 휴리스틱 오탐 위험 | Rejected |
| realtime 전용 wrapper 반환 | realtime에 필요한 정보만 분리 가능 | photo/realtime 계약이 다시 분기되고 call site가 늘어남 | Rejected |
| `PostureCaptureResult`에 source enum 추가 | 명시적 계약, photo/realtime 공통 사용, 테스트 가능 | 기존 initializer/반환 지점 업데이트 필요 | Selected |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Data/Services/PostureCaptureService.swift` | modify | `PostureCaptureResult`에 pose source 추가, 3D/2D fallback/averaging 반환 경로 갱신 |
| `DUNE/Data/Services/RealtimePoseTracker.swift` | modify | true 3D 결과에서만 `is3DActive`/score override 수행 |
| `DUNE/DUNETests/PostureCaptureServiceTests.swift` | add | `PostureCaptureResult` source contract 및 helper 검증 |
| `DUNE/DUNETests/RealtimePoseTrackerTests.swift` | add | fallback 결과를 3D 성공으로 승격하지 않는 정책 검증 |
| `docs/solutions/general/2026-03-22-posture-realtime-3d-fallback-contract.md` | add | 해결 배경과 예방책 문서화 |

## Implementation Steps

### Step 1: Capture Result Contract Explicit화

- **Files**: `DUNE/Data/Services/PostureCaptureService.swift`
- **Changes**:
  - `PostureCaptureResult`에 pose source enum/computed property 추가
  - 3D 성공 반환, 2D fallback 반환, 빈/averaging 반환 경로 모두 source를 명시적으로 채움
  - 필요하면 averaging 시 source 승격/유지 규칙을 명확히 정함
- **Verification**:
  - `rg -n "PostureCaptureResult\\(" DUNE DUNETests` 결과의 모든 call site가 새 계약을 반영

### Step 2: Realtime 3D Success Gate 정정

- **Files**: `DUNE/Data/Services/RealtimePoseTracker.swift`
- **Changes**:
  - fallback 결과일 때 `is3DActive = true`와 `scoreBuffer.replaceLast()`를 수행하지 않도록 분기
  - 필요 시 helper를 추출해 test seam 확보
- **Verification**:
  - 코드상 true 3D 결과에서만 precise path로 들어가는지 확인

### Step 3: Tests 추가

- **Files**: `DUNE/DUNETests/PostureCaptureServiceTests.swift`, `DUNE/DUNETests/RealtimePoseTrackerTests.swift`
- **Changes**:
  - source enum/helper 테스트
  - tracker helper/policy 테스트
- **Verification**:
  - targeted `xcodebuild test` 시도
  - repo 전체 unrelated test failure는 별도로 기록

## Edge Cases

| Case | Handling |
|------|----------|
| 3D request throws but 2D joints exist | fallback source로 반환하고 realtime 3D success UI를 올리지 않음 |
| 3D request succeeds but bodyHeight는 reference fallback | pose source는 `.threeD`로 유지, height/source를 혼동하지 않음 |
| averaging 결과가 2D fallback만 포함 | averaged result도 fallback source 유지 |
| no pose / insufficient confidence | 기존 error path 유지 |

## Testing Strategy

- Unit tests: `PostureCaptureResult` source contract, `RealtimePoseTracker`의 3D promotion policy
- Integration tests: `xcodebuild build -project DUNE.xcodeproj -scheme DUNE -destination 'generic/platform=iOS Simulator' -quiet`
- Manual verification: front camera에서 3D unavailable 상황에서도 realtime badge/score가 2D 상태로 유지되는지 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| source enum 추가로 기존 call site 누락 | medium | medium | `rg`로 모든 initializer 위치를 확인 |
| averaging source 정책이 애매함 | low | medium | `lastResult` 또는 fallback-only 보수 규칙을 문서와 코드에 같이 명시 |
| test target unrelated compile failure | high | low | targeted command 결과와 unrelated failure를 분리 기록 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 문제 지점과 수정 지점이 좁고, 휴리스틱 대신 명시적 계약으로 정리할 수 있어 회귀 위험이 낮다.
