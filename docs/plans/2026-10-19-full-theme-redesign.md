---
topic: full-theme-redesign
date: 2026-10-19
status: approved
confidence: medium
related_solutions: [docs/solutions/design/2026-03-04-adding-new-theme.md, docs/solutions/design/2026-03-01-multi-theme-architecture.md]
related_brainstorms: []
---

# Implementation Plan: 8개 테마 전체 디자인 개편

## Context

`docs/design/full-redesign-map/`은 8개 테마의 목표를 정의하지만 앱에는 기존 7개 테마의 부분 표현만 있다. WATER LILIES는 선택 값조차 없다. 사용자가 기대한 결과는 맵 자체가 아니라 실제 앱 화면의 개편이다.

## Requirements

### Functional

- 8개 테마가 선택·저장·복원되고 iPhone 4탭과 상세·시트·운동 화면군에 전달된다.
- 테마별 장면·표면·링 광택·그래프 위계가 맵의 방향과 일치한다.
- Watch·Widget·Vision에서 새 테마가 안전하게 전달되거나 지원 범위가 명확하다.

### Non-functional

- 건강 상태색·실데이터·CTA 의미를 장식과 분리한다.
- Reduce Motion, Dynamic Type, VoiceOver, 밝음·어두움·고대비를 지킨다.
- 변경 화면의 실제 기기 캡처를 새로 수집하고 기존 시안과 구분한다.

## Approach

기존 `AppTheme` 접두사 asset, 세 종류의 공유 배경 라우터, 공통 카드·링을 확장한다. 테마별 화면을 복제하지 않고 화면군에서 장식 강도만 조정한다. 먼저 WATER LILIES의 종단 경로를 만든 뒤 기존 7개 테마를 원본 시안과 대조해 강화한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|---|---|---|---|
| 화면마다 별도 테마 View | 독립 조정 | 106개 화면의 중복과 불일치 | 제외 |
| 공통 토큰·배경·표면 확장 | 기존 화면군에 전파 | 공통 컴포넌트 검증 범위 큼 | 채택 |

## Affected Files

| File | Change Type | Description |
|---|---|---|
| `DUNE/Domain/Models/AppTheme.swift` | 수정 | 8번째 영속 값 |
| `DUNE/Presentation/Shared/Extensions/AppTheme+View.swift` | 수정 | asset, 이름, 표면 역할 |
| `DUNE/Presentation/Shared/Components/*Background.swift`, `WaveShape.swift` | 추가·수정 | 테마별 탭·상세·시트 장면 |
| `DUNE/Presentation/Shared/Components/GlassCard.swift`, `ProgressRingView.swift`, `SectionGroup.swift` | 수정 | 표면·상태색·장식 분리 |
| `Shared/Resources/Colors.xcassets/`, `Shared/Resources/Localizable.xcstrings` | 추가·수정 | 색상과 3개 언어 |
| `DUNEWatch/`, `DUNEVision/`, Widget 소스 | 수정 | 새 테마 전달과 fallback |
| `DUNETests/`, `DUNEUITests/` | 수정 | 값 보존·선택·실제 화면 |
| `docs/design/phone-design-map/actual/` | 갱신 | 영향 기기·상태의 새 캡처 |
| `docs/design/theme-map/`, `docs/design/full-redesign-map/` | 갱신 | 구현 상태와 시안 동기화 |

## Implementation Steps

### Step 1: 8번째 테마의 종단 경로

- **Files**: `AppTheme.swift`, `AppTheme+View.swift`, 색상 asset, `WaterLiliesBackground.swift`, `WaveShape.swift`, 관련 카드·링·Watch 경로·카탈로그.
- **Changes**: 수련 선택값과 시각 언어를 루트·상세·시트에 연결한다. 기존 저장값은 보존한다.
- **Verification**: 테마 단위 테스트, 선택 UI 테스트, iOS 빌드, 대표 4탭 실제 캡처.

### Step 2: 기존 7개 테마의 시안 차이 해소

- **Files**: 각 테마 배경, 공통 표면·링·그래프 컴포넌트.
- **Changes**: 먼저 4탭 히어로의 링을 Today 기준으로 통일한다. Today·Activity·Wellness는 실제 점수, Life는 완료 수/대상 수를 표시하며 큰 글씨에서는 세로로 배치한다. 이후 모티프 층·깊이·탭별 강도·데이터 대비를 원본 시안과 맞춘다.
- **Verification**: 각 테마 4탭의 정지 화면·밝음·어두움 대조와 Reduce Motion 확인.

### Step 3: 전체 화면군과 플랫폼

- **Files**: T/A/W/H/P/L/S 화면군 소스, Watch·Widget·Vision 테마 소비자.
- **Changes**: 상세·입력·운동에서 장식 강도를 낮추고 테마 전파를 확인한다.
- **Verification**: 화면 ID별 코드·진입 경로 대조, 영향 기기 UI 테스트 및 Watch 62상태 회귀.

### Step 4: 증거와 완료 판정

- **Files**: 실제 디자인맵 PNG·출처, 맵 README/manifest/index, 테스트 결과.
- **Changes**: 새 빌드의 실제 캡처만 등록하고 미캡처 상태를 분리한다.
- **Verification**: 맵 생성 `--check`, 이미지·출처·기기·접근성 확인, 빌드 및 영향 범위 테스트.

### 2026-10-22 재개 단위: Duo 4탭 링 배치

- **Files**: `DUNEUITests/Visual/ThemeMatrixUITests.swift`, `DUNEUITests/Helpers/UITestHelpers.swift`, 영향받은 실제 디자인맵과 개편 맵.
- **Changes**: 기본 Today 시작 상태를 내비게이션 판정에 포함하고, 탭별 직접 진입으로 124pt 링·전체 frame·행동 도달성·Wellness 설명 폭을 검사한다. 현재 worktree 소유 Duo만 사용한다.
- **Verification**: `testDesertHeroRingsByInitialTab` 하나를 자세별로 실행한다. `DUNEUITests-DuoAudit`과 기존 host 캡처 도구로 활성 디스플레이 PNG를 보존하고 픽셀·배치를 검토한다. 탭 레일 전환·다른 테마·최대 글씨는 이 단위의 통과 범위에 포함하지 않는다. 각 실행은 표준 실행기의 30분 deadline·잠금 대기 60초 제한을 적용한다.

### 2026-10-22 후속 단위: Life 히어로 정보 중복 해소

- **Files**: `LifeView.swift`, Life UI 테스트, 4탭 레이아웃 맵과 영향받은 실제 화면맵.
- **Changes**: 링 옆의 습관 이름 3개를 기존 `LifeViewModel.heroNarrative` 진행 설명으로 바꾼다. 링·체크리스트 행동·아래 습관 목록은 유지한다. 새 문자열이나 데이터 로직은 추가하지 않는다.
- **Verification**: Life 단일 배치 테스트로 밝음·어두움·최대 접근성 글씨를 확인한다. 공유 레이아웃의 영향 기기인 iPhone 402pt·440pt, iPad, Duo 접힘·펼침에서 L01만 새로 촬영한다. 앞서 검증한 다른 3탭을 재실행하지 않는다. 최종 집중 검사 5건 통과·실제 화면 15장을 보존했다.

## Edge Cases

| Case | Handling |
|---|---|
| 기존 저장 테마 | raw value 유지, 신규 케이스만 추가 |
| 알 수 없는 저장값 | 기존 desert fallback 유지 |
| 데이터 부족 | 장식 곡선을 실데이터처럼 제시하지 않음 |
| Reduce Motion | 완성된 정지 장면·링 표시 |
| 캡처 불가 | 해당 화면 ID와 기기·이유를 미완료로 기록 |

## Testing Strategy

- Unit: 테마 Codable·복원·asset 계약·의미색.
- UI: 설정 선택, 4탭 전환, 대표 상세·시트·운동 흐름.
- Manual: iPhone, iPad, Duo 접힘·펼침, Watch 및 접근성 상태의 실제 PNG 대조.

## Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| 공유 테마 변경의 광범위한 UI 영향 | 높음 | 높음 | 작은 구현 단위와 영향 화면 캡처 |
| 시안과 건강 상태색 혼동 | 중간 | 높음 | 링·그래프 의미색 계약 고정 |
| 시뮬레이터·Duo 캡처 장애 | 중간 | 중간 | 기존 이미지를 새 증거로 쓰지 않고 미완료 기록 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: 기존 접두사 asset·공통 배경 구조가 재사용 가능하지만 화면군과 여러 기기의 실제 검증량이 크다.
