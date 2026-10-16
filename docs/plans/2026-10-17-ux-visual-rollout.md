---
tags: [ux, visual-system, theme, release, implementation]
date: 2026-10-17
category: plan
status: approved
confidence: medium
related_solutions: [hero-cta-button-pattern, multi-theme-architecture]
related_brainstorms: [today-tab-ux-unification, dashboard-ux-redesign]
---

# Implementation Plan: DUNE UX·비주얼 명세 적용

## Context

[확정된 UX·비주얼 명세](../design/2026-10-17-ux-visual-spec.md)를 현재 4탭에 적용한다. 저장된 [실제 화면 디자인맵](../design/phone-design-map/actual/index.html)에서 Today 그래프가 약하고, Activity의 행동이 아래로 밀리고, Wellness는 예측·현재 상태가 중복되고, Life는 표본이 적은 큰 그래프가 주 행동을 가린다. Today의 운동 버튼과 첫 체중 기록은 무반응 경로가 있다. 7개 구현 테마의 표현을 테마 맵의 방향에 맞추되 WATER LILIES는 시안으로 보존한다.

## Requirements

### Functional

- Today의 상태→변화 그래프→근거→실제 동작하는 행동을 첫 화면에 배치한다.
- 운동 추천 버튼은 실제 Activity 목적지로 이동시키거나 행동과 맞는 이름으로 표시한다. 첫 체중 기록도 유효한 입력 경로를 제공한다.
- Activity의 운동 행동을 준비도 직후로 올리고 2D 근육 지도와 상세 분석 경로를 보존한다.
- Wellness는 종합 상태와 수면 예측을 분리하며, Life는 오늘 완료 가능한 습관을 추세보다 앞세운다.
- DUNE과 기존 6개 테마의 상단 장면·링·그래프가 일관된 계약을 따르고, 그래프가 장식에 묻히지 않는다.
- 기존 기록·알림·딥링크·4탭 내비게이션을 보존한다. WATER LILIES 앱 테마 추가는 제외한다.

### Non-functional

- Dynamic Type, Reduce Motion, Increase Contrast, VoiceOver, 밝음/어두움, 한국어·영어·일본어에서 의미와 조작을 유지한다.
- 상단 장면과 링 애니메이션은 스크롤·탭 전환을 방해하지 않는다.
- 화면 배치·문구·상태가 바뀐 T03/A01/H01/L01 및 영향받는 상세·빈 상태를 새 시뮬레이터 캡처로 디자인맵에 반영한다.
- 테마 표현을 바꾼 작업에서 테마 맵의 해당 시안·설명·manifest를 동기화한다.

## Approach

기존 SwiftUI 화면과 `DS` 토큰, `TabWaveBackground` 테마 라우터, `ProgressRingView`를 재사용한다. 먼저 행동·데이터 상태를 고친 뒤 시각 위계를 재배치한다. 화면마다 자체 애니메이션 시스템을 새로 만들지 않는다. 앱의 테마 선택값과 건강 기록 모델은 바꾸지 않는다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|---|---|---|---|
| 카드 색·모션만 확대 | 빠른 시각 변화 | 무반응 행동과 약한 그래프가 남음 | 기각 |
| 기능·모델과 탭을 대거 삭제 | 첫 화면 단순화 | 기록·딥링크·마이그레이션 위험 | 기각 |
| 기존 데이터와 라우팅을 유지한 채 상단 위계·행동·테마 장면을 단계적으로 교체 | 핵심 루프를 검증할 수 있음 | 기기별 UI 캡처 필요 | 채택 |

## Affected Files

| File | Change Type | Description |
|---|---|---|
| `DUNE/Presentation/Dashboard/DashboardView.swift`, `DashboardViewModel.swift` | modify | Today 상태·행동·섹션 순서, 빈 상태 구분 |
| `DUNE/Presentation/Dashboard/Components/ConditionHeroView.swift`, `ExerciseIntelligenceCard.swift`, `QuickActionsRow.swift` | modify | 히어로 그래프·문구·버튼 |
| `DUNE/App/ContentView.swift` | conditional modify | Today→Activity 행동 라우팅 |
| `DUNE/Presentation/Activity/ActivityView.swift` 및 준비도 컴포넌트 | modify | 운동 행동과 근육 지도 위계 |
| `DUNE/Presentation/Wellness/WellnessView.swift`, `Components/WellnessHeroCard.swift` | modify | 종합 추세와 예측 분리 |
| `DUNE/Presentation/Life/LifeView.swift` | modify | 습관 행동 우선, sparse 차트 처리 |
| `DUNE/Presentation/Shared/Components/DesertWaveBackground.swift`, `WaveShape.swift`, 테마별 배경·링 컴포넌트 | conditional modify | 테마별 지속 모션·가독성 |
| `DUNE/Presentation/Shared/DesignSystem.swift`, 색상 assets, `Localizable.xcstrings` | conditional modify | 공통 타입·색·문구 |
| `DUNETests/**`, `DUNEUITests/**` | modify | 상태·동작·레이아웃 회귀 테스트 |
| `docs/design/theme-map/**`, `docs/design/phone-design-map/**` | modify | 방향과 새 실제 화면 증거 동기화 |

## Implementation Steps

### Step 1: 상태와 행동 경로 복구

- **Files**: DashboardView, ViewModel, ExerciseIntelligenceCard, QuickActionsRow, 필요한 라우터·입력 화면.
- **Changes**: 무반응 운동 CTA와 첫 체중 입력을 연결하고, 권한 거부·기록 없음·기준선 수집 상태를 분리한다. 버튼의 문구는 실제 목적지와 맞춘다.
- **Verification**: 추천 유무, 첫 체중 기록, 권한 허용·거부, 빈 기록의 단위/UI 테스트. 활성 버튼 무반응 0개.

### Step 2: Today 히어로와 DUNE 기준 장면

- **Files**: ConditionHeroView, DashboardView, DesertWaveBackground, 링·그래프 관련 컴포넌트.
- **Changes**: 시간별/7일 추세를 충분한 폭·높이·대비로 히어로에 고정하고 상태·근거·행동의 시선 순서를 재구성한다. 상단 모래 능선은 지속 이동, 링의 하이라이트는 호 위에서 순환하며 Reduce Motion에서는 정지한다. 중복 Quick Actions·브리핑의 첫 화면 노출을 줄인다.
- **Verification**: 그래프 데이터/없음/7일 대체 상태, 접근성 요소, Reduce Motion, T03 실제 캡처.

### Step 3: Activity·Wellness·Life 첫 화면

- **Files**: 각 탭 View·히어로 컴포넌트.
- **Changes**: Activity 준비도 바로 뒤에 운동 행동, Wellness 현재 상태와 미래 수면 예측의 역할 분리, Life 오늘 습관 우선 및 sparse 추세 축소. 기존 상세 경로 보존.
- **Verification**: 각 탭의 핵심 행동 UI 테스트, A01/H01/L01의 일반 iPhone·영향받는 iPad/Duo 캡처.

### Step 4: 구현된 7개 테마에 공통 계약 전개

- **Files**: 테마별 기존 배경 컴포넌트, AppTheme+View, 공통 링/카드, 테마 맵.
- **Changes**: DUNE/OCEAN/FOREST/SAKURA/ARCTIC/SOLAR/CONTOUR의 고유 모티프, 대비, 그래프 분리를 확인·조정한다. 기존 리듬을 재사용하고 ARCTIC는 오로라만 이동하도록 한다.
- **Verification**: 각 테마 루트 화면의 애니메이션·정지 상태, 밝음/어두움 대비, 기존 테마 테스트, `build-theme-map.py --check`.

### Step 5: 검증·디자인맵 동기화

- **Files**: 영향받는 단위/UI 테스트, 실제 화면 디자인맵, 테마 맵.
- **Changes**: `plan-ui-tests.py`로 최종 영향 범위를 재판정한다. 관련 UI/단위 테스트를 실행하고 일반 iPhone·iPad·Duo 접힘/펼침 중 영향받는 화면만 새로 캡처한다. 실제 캡처가 불가능한 화면은 완료로 표시하지 않는다.
- **Verification**: `scripts/build-ios.sh`, 선택된 테스트 결과 로그, 새 PNG의 타임스탬프와 육안 확인, 문서 생성 스크립트 check.

## Edge Cases

| Case | Handling |
|---|---|
| HealthKit 권한 거부와 측정치 없음 | 다른 상태·문구·행동을 보여 줌 |
| 시간별 표본 없음 | 실제 7일 기록이 있으면 기간 표기와 함께 전환; 없으면 그래프 대신 설명 |
| 하루/주간 습관 기록이 sparse | 큰 빈 차트 숨기고 오늘 할 일 표시 |
| 추천 운동이 휴식일/없음 | 운동 시작 CTA를 만들지 않고 유효한 대체 행동 제공 |
| 큰 글자·작은 화면·Duo 접힘 | 히어로를 수직 구성하고 버튼/그래프를 자르지 않음 |
| Reduce Motion·낮은 성능 | 정지 장면과 완성된 링에서도 같은 정보 유지 |
| 저장된 테마·알림·기존 기록 | 사용자 데이터와 목적지 보존 |

## Testing Strategy

- Unit: 상태 분기, 그래프 fallback, 추천 CTA 목적지, sparse 습관 차트 판단.
- UI: T03/A01/H01/L01의 상태·그래프·주 행동 존재와 실제 탐색. `ui-test-expert` 패턴 및 기존 회귀 suite 사용.
- Visual: 영향받은 일반 iPhone/iPad/Duo 자세의 새 디자인맵 캡처, 7테마의 motion/Reduce Motion 관찰.
- Commands: `python3 scripts/plan-ui-tests.py --base main`, `scripts/build-ios.sh`, 판정기의 관련 테스트 명령, `python3 docs/design/theme-map/build-theme-map.py --check`.

## Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| 공통 테마/링 변경이 여러 화면·플랫폼에 영향 | 높음 | 높음 | 재사용 범위 검색 후 플랫폼별 필요한 검증 선택 |
| 장식이 그래프·글자 대비를 낮춤 | 중간 | 높음 | 실제 합성 픽셀, Increase Contrast, 각 테마 화면 확인 |
| 내비게이션 변경으로 알림·딥링크 회귀 | 중간 | 높음 | 탭 path 테스트와 기존 목적지 보존 |
| 실제 디자인맵 캡처의 기기/GUI 제약 | 중간 | 중간 | CLI·기기 상태 readback으로 확인, 불가능하면 미갱신 명시 |
| 건강 데이터와 iCloud 관련 출시 정책 | 높음 | 높음 | 이 UX 작업과 분리된 출시 심사 게이트로 추적; 이 계획은 심사 통과를 주장하지 않음 |

## Confidence Assessment

- **Overall**: Medium.
- **Reasoning**: 화면·라우팅과 테마 컴포넌트가 이미 존재하지만 공통 UI 변경의 영향 범위가 넓고 실제 기기/시뮬레이터 캡처가 최종 판단에 필요하다.
