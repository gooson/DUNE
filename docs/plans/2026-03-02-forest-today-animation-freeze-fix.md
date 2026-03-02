---
topic: forest-today-animation-freeze-fix
date: 2026-03-02
status: implemented
confidence: high
related_solutions:
  - docs/solutions/design/theme-wave-visual-upgrade.md
  - docs/solutions/design/2026-03-01-forest-green-theme.md
related_brainstorms:
  - docs/brainstorms/2026-03-01-forest-green-theme.md
---

# Implementation Plan: Forest Theme Today Animation Freeze Fix

## Context

Settings 탭에서 Forest Green 테마를 선택한 뒤 Today 탭으로 복귀하면 `ForestTabWaveBackground`의 실루엣 드리프트 애니메이션이 정지된 상태로 보이는 문제가 보고되었다. 동일 계열 구현인 Desert/Ocean 배경은 탭 재진입 시 애니메이션 재시작 로직이 있으나 Forest 오버레이에는 누락되어 있다.

## Requirements

### Functional

- Settings에서 Forest Green 선택 후 Today 탭 복귀 시 배경 애니메이션이 계속 동작해야 한다.
- 기존 Reduce Motion 가드(`accessibilityReduceMotion`)를 유지해야 한다.
- Forest 탭/디테일/시트 배경 모두 동일 오버레이 재시작 동작을 가져야 한다.

### Non-functional

- 변경 범위를 최소화하여 시각 스타일/색상/성능 특성은 유지한다.
- 기존 테마 배경 패턴(Desert/Ocean)의 lifecycle handling과 일관성을 맞춘다.

## Approach

`ForestWaveOverlayView`에 `.onAppear` 재시작 블록을 추가해 뷰 재진입 시 `phase`를 0으로 초기화한 뒤 `repeatForever` 선형 애니메이션을 다시 시작한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| `.onAppear`에서 phase 리셋 + 재시작 | 기존 Desert/Ocean 패턴과 동일, 변경 최소 | 중복( `.task` + `.onAppear`) 코드 구조 유지 | 채택 |
| `.task(id:)`로 통합 | 선언적으로 깔끔 | 기존 테마 구현과 불일치, 리스크 증가 | 미채택 |
| 상위 `TabWaveBackground`에서 강제 `.id` 재부여 강화 | 재구성 강제 가능 | 근본 원인(오버레이 재시작 누락) 해결 아님 | 미채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Shared/Components/ForestWaveBackground.swift` | Modify | `ForestWaveOverlayView`에 `onAppear` 기반 phase reset + animation restart 추가 |

## Implementation Steps

### Step 1: 재현/패턴 비교

- **Files**: `ForestWaveBackground.swift`, `DesertWaveBackground.swift`, `OceanWaveShape.swift`
- **Changes**: 없음 (분석)
- **Verification**: Forest만 `.onAppear` 재시작이 누락된 것을 확인

### Step 2: Forest 오버레이 재시작 로직 추가

- **Files**: `ForestWaveBackground.swift`
- **Changes**: `.onAppear { phase = 0; withAnimation(...repeatForever...) }` 추가
- **Verification**: 컴파일 통과 + 탭 복귀 시 애니메이션 재개

### Step 3: 회귀 검증

- **Files**: 없음 (검증만)
- **Changes**: 없음
- **Verification**: `xcodebuild test`로 관련 테스트 타깃 실행

## Edge Cases

| Case | Handling |
|------|----------|
| Reduce Motion 활성화 | 기존 guard(`!reduceMotion`) 유지로 애니메이션 비활성 보장 |
| 뷰 재진입 반복 | 매번 phase를 0으로 초기화해 정지 상태 누적 방지 |
| 탭/시트/디테일 공통 오버레이 사용 | 오버레이 단일 수정으로 전 영역 반영 |

## Testing Strategy

- Unit tests: 뷰 lifecycle 기반이라 신규 유닛 테스트는 생략(기존 규칙상 SwiftUI View body 면제)
- Integration tests: 없음
- Manual verification:
  - Settings에서 Forest Green 선택
  - Today 탭으로 복귀
  - 배경 실루엣 드리프트가 지속 재생되는지 확인
- Automated check:
  - `xcodebuild test -project DUNE/DUNE.xcodeproj -scheme DUNETests -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:DUNETests/ForestSilhouetteShapeTests -quiet`

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| `.task`와 `.onAppear` 중복으로 초기 프레임 점프 가능성 | Low | Low | 기존 Desert/Ocean 동일 패턴 채택으로 일관성 확보 |
| 실제 탭 전환 시점에서 onAppear 호출 차이 | Low | Medium | 오버레이 단위 재시작으로 상위 구조 의존 제거 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 동일 클래스의 기존 테마 구현에서 검증된 패턴을 Forest에 맞춘 최소 수정이며, 재현 시나리오와 직접적으로 대응한다.
