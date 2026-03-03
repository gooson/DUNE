---
topic: artic-theme-performance-compat
date: 2026-03-04
status: implemented
confidence: high
related_solutions:
  - docs/solutions/design/2026-03-03-arctic-dawn-theme.md
  - docs/solutions/performance/2026-03-04-arctic-aurora-lod-frame-stability.md
related_brainstorms:
  - docs/brainstorms/2026-03-04-arctic-aurora-performance-preserve-quality.md
---

# Implementation Plan: Artic Theme Compatibility + Arctic Render Trim

## Context

사용자 입력은 `artic` 테마 추가 요청이었고, 코드베이스 기준 정식 테마명은 `arcticDawn`이다.
이미 시각 품질은 확보되어 있어, 이번 범위는 다음 두 가지다:

- 저장값/동기화값에서 `artic` 오탈자를 안전하게 `arcticDawn`으로 정규화
- Arctic 오로라 오버레이 내부의 불필요한 런타임 할당/중복 애니메이션 시작 경로를 줄여 프레임 비용을 낮춤

## Requirements

### Functional

- `artic`/`articDawn` 입력이 들어와도 Arctic Dawn 테마로 해석되어야 한다.
- iOS 앱, Watch 앱, WatchConnectivity 경로 모두 동일 정규화 규칙을 사용한다.

### Non-functional

- 기존 Arctic Dawn 시각 퀄리티(레이어 구성, 색감)는 유지한다.
- 오버레이 루프 최적화는 동작/출력 회귀 없이 적용한다.

## Approach

`AppTheme`에 rawValue 정규화 유틸리티를 추가하고, theme rawValue를 읽고 전달하는 지점을 모두 이 유틸리티로 통일한다.
Arctic 오버레이는 `Array(...enumerated())` 기반 루프를 index 기반 순회로 바꿔 프레임마다 생기는 임시 배열 생성 비용을 줄인다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| `AppTheme`에 `artic` 신규 enum case 추가 | 입력 즉시 수용 | 실질적으로 중복 테마, CaseIterable/UI 노출 혼선 | 기각 |
| 파서 정규화로 alias 처리 | 중복 없이 호환성 확보 | 정규화 호출 지점 정리 필요 | 채택 |
| 오버레이 구조 대규모 재작성(Canvas 등) | 최대 성능 여지 | 회귀 리스크 큼 | 기각 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Domain/Models/AppTheme.swift` | Modify | storage key 상수화 + `artic` alias 정규화 유틸리티 추가 |
| `DUNE/App/DUNEApp.swift` | Modify | 앱 시작 시 persisted theme 정규화/마이그레이션 |
| `DUNE/App/ContentView.swift` | Modify | AppStorage key를 단일 상수로 통일 |
| `DUNE/Presentation/Settings/Components/ThemePickerSection.swift` | Modify | AppStorage key를 단일 상수로 통일 |
| `DUNE/Data/WatchConnectivity/WatchSessionManager.swift` | Modify | Watch 전송 theme rawValue 정규화 |
| `DUNEWatch/DUNEWatchApp.swift` | Modify | Watch 수신 theme rawValue 정규화 해석 |
| `DUNEWatch/WatchConnectivityManager.swift` | Modify | iPhone에서 받은 theme rawValue 정규화 저장 |
| `DUNE/Presentation/Shared/Components/OceanWaveBackground.swift` | Modify | Arctic overlay 루프 할당 최소화 + curtain 중복 애니메이션 시작 제거 |
| `DUNETests/AppThemeTests.swift` | Modify | `artic` alias 정규화 테스트 추가 |

## Implementation Steps

### Step 1: Theme rawValue 정규화 경로 추가

- **Files**: `AppTheme.swift`, `DUNEApp.swift`, `DUNEWatchApp.swift`, `WatchSessionManager.swift`, `WatchConnectivityManager.swift`
- **Changes**:
  - `AppTheme.resolvedTheme(...)` / `normalizedRawValue(...)` 추가
  - 앱 시작 시 저장된 테마값 마이그레이션
  - watch 송수신 경로 정규화 적용
- **Verification**:
  - `AppThemeTests` alias 정규화 케이스 통과

### Step 2: Arctic 오버레이 렌더 루프 최적화

- **Files**: `OceanWaveBackground.swift`
- **Changes**:
  - `Array(...enumerated())` 제거, index 기반 순회로 변경
  - micro palette를 static 상수로 승격
  - curtain overlay의 중복 `.onAppear` 애니메이션 시작 제거 (`.task` 단일화)
- **Verification**:
  - `WaveShapeTests` 통과
  - 빌드 성공 및 UI 품질 회귀 없음

## Edge Cases

| Case | Handling |
|------|----------|
| 저장값이 `"articDawn"` | `.arcticDawn`으로 정규화 후 재저장 |
| 저장값이 공백 포함 (`" artic "`) | trim 후 alias 규칙 적용 |
| 알 수 없는 테마 rawValue | nil 처리 후 기존 fallback(`.desertWarm`) 유지 |

## Testing Strategy

- Unit tests:
  - `DUNETests/AppThemeTests` (`artic` alias 정규화 케이스 포함)
  - `DUNETests/WaveShapeTests`
- Integration tests:
  - `scripts/test-unit.sh` 실행 (현재 베이스라인의 기존 실패 2건 존재)
- Manual verification:
  - Settings에서 Arctic Dawn 선택/유지 확인
  - watch 동기화 후 동일 테마 반영 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| alias 범위 과확장으로 오탐 매핑 | Low | Medium | `artic` 계열로만 제한 |
| 루프 변경으로 미세 시각 차이 | Low | Medium | 수치/레이어 파라미터 불변 유지 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 시각 파라미터를 바꾸지 않고 입력 정규화와 할당 최적화만 적용해 회귀 위험이 낮다.
