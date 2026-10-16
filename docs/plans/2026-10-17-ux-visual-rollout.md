---
tags: [ux, visual-system, theme, release, implementation]
date: 2026-10-17
category: plan
status: in-progress
confidence: medium
related_solutions: [hero-cta-button-pattern, multi-theme-architecture]
related_brainstorms: [today-tab-ux-unification, dashboard-ux-redesign]
---

# Implementation Plan: DUNE UX·비주얼 명세 적용

## 2026-10-17 상세 레이아웃 재계획

이 절은 기존 출시 명세와 PR #819의 적용 결과를 실제 캡처와 대조해 다시 정한 구현 기준이다. 시각 기준은 [4탭 레이아웃 맵](../design/layout-map/index.html), 테마의 색·장면·움직임 기준은 [테마 맵](../design/theme-map/index.html), 구현 증거는 [실제 화면 디자인맵](../design/phone-design-map/actual/index.html)으로 분리한다. 레이아웃 맵과 앱이 다르면 먼저 차이를 기록하고 앱 또는 맵 중 어느 쪽이 잘못됐는지 판단해 같은 변경에서 동기화한다.

### 현재 화면에서 확인한 차이

| 화면 | 이미 적용된 것 | 남은 레이아웃 차이 |
|---|---|---|
| Today T03 | 상태 링, 기간이 표시된 실제 7일 그래프, 근거 2개, 작동하는 주 행동 | 작은 글자·좁은 창에서 히어로와 행동의 첫 화면 가시성을 계속 확인 |
| Activity A01 | 준비도 히어로 직후 운동 기록, 근육 지도를 다음 섹션에 배치 | 공통 `HeroScoreCard`가 일반 iPhone에서도 세로 배치되어 링 옆이 비고 추세·행동이 아래로 밀림 |
| Wellness H01 | 현재 상태와 미래 수면 예측을 별도 카드에 표시 | Activity와 같은 히어로 세로 배치로 추세와 예측이 아래로 밀림 |
| Life L01 | 오늘의 습관과 완료 가능한 항목이 차트보다 앞섬 | 완료 버튼·수치가 긴 언어와 큰 글씨에서도 보이는지 실제 캡처로 확인 |

### 공통 화면 구조와 치수

1. **상단 장면**: 시스템 navigation title·toolbar를 유지하고, 테마 배경은 safe area까지 확장한다. 장식은 터치를 받지 않고 제목·카드 텍스트와 겹치지 않는다.
2. **히어로**: compact 일반 글씨에서는 링과 상태 문장을 한 행에, accessibility 글씨에서는 링 다음에 상태 문장을 세로로 둔다. 링의 고정 직경은 기존 토큰(compact 88–100pt, regular 128–140pt)을 시작값으로 유지하되 숫자와 상태 이름은 자르지 않는다. 카드 내부 간격은 `DS.Spacing`을 사용한다.
3. **추세**: 히어로의 전체 내부 폭을 사용한다. 실제 표본 2개 이상이면 기간(`Today`/`24h`/`7d`)과 값·기준을 표시한다. 표본이 부족하면 같은 높이의 설명 영역을 두고 가짜 선을 그리지 않는다. 능선·오로라·포말은 이 영역 뒤에서 충분히 약해야 한다.
4. **근거와 행동**: 히어로 근거는 최대 2개, 상세 링크는 명시적으로 표시한다. CTA는 히어로 밖에서 44pt 이상 높이를 가지며 실제 목적지 또는 기록 흐름으로 연결한다. 히어로 전체 링크 안에 CTA를 넣지 않는다.
5. **본문**: 첫 행동 다음에 가장 관련 있는 한 블록을 놓고 나머지 분석은 스크롤 아래에 둔다. 빈 데이터는 지표를 0으로 꾸미지 않고 측정/기록 조건을 설명한다.

### 탭별 배치 계약

| 탭 | compact 첫 화면 순서 | regular·Duo 펼침 배치 | 주 행동/빈 상태 |
|---|---|---|---|
| Today | 상태+짧은 문장 → 실제 추세 → HRV/RHR 근거 → 상태에 맞는 Activity/Wellness 행동 → 시간대 관련 카드 1개 | 최대 읽기 폭의 히어로를 중앙에 두고, 아래 보조 지표만 두 열로 확장 | 유효 점수가 없으면 권한·기록 없음·기준선 수집을 구분한다. 주 행동의 문구는 도착 탭과 일치한다. |
| Activity | 준비도 → 추세 → HRV/수면/회복 근거 → 운동 기록 → 근육 회복 → 최근 운동 | 히어로는 링/상태와 추세/근거의 두 영역, 근육 지도와 주간 통계는 그 아래 두 열 | 운동 기록은 운동 선택기를 연다. 준비도 데이터가 없으면 점수 대신 수집 조건을 표시한다. |
| Wellness | 현재 웰니스 점수 → 추세 → 핵심 원인 → 신체 기록 → 수면 예측(미래·신뢰도 명시) → 중요한 신체/활동 지표 | 히어로 폭을 제한하고 예측·기록 영역을 보조 열에 배치할 수 있으나 읽기 순서는 유지 | 신체 기록은 로딩·클라우드 동기화 대기·기록 없음에서도 입력을 연다. 예측값을 현재 점수처럼 그리지 않는다. |
| Life | 오늘 완료 수 → 지금 완료할 수 있는 습관 → 자동 기록 → 충분한 표본이 있을 때만 추세 | 완료 목록과 자동 기록은 두 열로, 진행 상태는 한 번만 요약 | 습관이 없으면 생성 행동을 먼저 보여 준다. 표본 부족 시 큰 빈 차트를 숨긴다. |

### 화면 폭·접근성 규칙

- iPhone과 Duo 접힘은 한 열이다. 텍스트가 길어지면 상태 문장을 줄바꿈하고 핵심 숫자의 과도한 축소를 피한다.
- iPad와 Duo 펼침은 루트 콘텐츠의 최대 폭을 760pt로 제한한다. 보조 섹션에 실제 내용이 둘 다 있을 때만 두 열을 사용한다. 히어로와 주 행동은 중앙 읽기 열에서 순서를 유지하고 빈 오른쪽 열을 만들지 않는다.
- Dynamic Type 접근성 크기에서는 링/상태를 세로로 전환하고 버튼·근거·그래프를 숨기지 않는다. 한국어·영어·일본어, VoiceOver 순서는 위 탭별 순서와 같다.
- Reduce Motion에서는 테마 장면과 링 광택을 정지시키되 값·상태·기간·동작은 동일하다. 밝음/어두움·Increase Contrast에서 글자와 데이터 선의 대비를 캡처로 확인한다.

### 7개 테마를 같은 레이아웃에 적용하는 규칙

테마 전환은 위의 카드 순서, 그래프 높이, CTA 목적지, 상태 의미를 바꾸지 않는다. 각 테마의 최신 원본은 테마 맵 `themes/`의 보존본이며, 앱 구현은 다음 라우터를 사용한다.

| 테마 | 상단 장면 구현 | 히어로·그래프 확인점 |
|---|---|---|
| DUNE | `DesertTabWaveBackground` · 두 모래 능선 | 능선은 카드 밖, 링은 건강 상태색, 데이터 선은 능선보다 진하게 |
| OCEAN | `OceanTabWaveBackground` · 교차 해류와 굵은 포말 | 포말이 축·값과 겹치지 않음 |
| FOREST | `ForestTabWaveBackground` · 안개와 숲 능선 | 숲의 초록을 건강 상태의 좋음 표시로 대신 쓰지 않음 |
| SAKURA | `SakuraTabWaveBackground` · 가지와 적은 꽃잎 | 밝은 배경에서 문장·데이터 선 대비 유지 |
| ARCTIC | `OceanLegacyArcticTabWaveBackground` · 오로라 띠 | 오로라만 이동하며 그래프와 글자는 정지 |
| SOLAR | `SolarTabWaveBackground` · 고정 코어와 궤적 | 링 광택이 값이나 그래프를 가리지 않음 |
| CONTOUR | `ContourBackground(style: .tab)` · 등고선 | 등고선과 데이터 선의 굵기·색·축을 구별 |

WATER LILIES는 이번 구현 범위에 넣지 않는다. 색이나 장면을 조정할 때는 앱보다 먼저 해당 테마 HTML·manifest·README를 갱신하고 생성 스크립트 `--check`를 통과시킨다.

### 구현 순서와 합격 게이트

1. **맵 고정**: `docs/design/layout-map/index.html`에 compact/regular·4탭·데이터 유무를 표현하고 테마 맵과 실제 화면 맵을 링크한다. 시안임을 명시한다.
2. **공통 히어로 수정**: `HeroScoreCard.swift`의 일반 글씨 가로 배치를 안정화하고 큰 글씨 세로 배치를 유지한다. 호출부 Activity/Wellness와 모든 테마에서 상태색과 배경색을 혼동하지 않는다.
3. **차이 확인**: T03/A01/H01/L01의 새 배치가 맵의 순서와 맞는지 코드와 실제 이미지를 대조한다. 필요할 때만 탭별 코드·문구를 조정한다.
4. **검증**: iOS 빌드, 관련 UI 행동 테스트, 각 영향 화면의 일반 iPhone·iPad·Duo 접힘/펼침 실제 캡처를 실행한다. 캡처 이미지를 눈으로 확인한 후 actual 맵의 출처와 갱신 시간을 재생성한다. 테마 표현을 변경했다면 테마 맵의 보존본·manifest·README를 동기화하고 `build-theme-map.py --check`를 통과시킨다.
5. **완료 조건**: 4탭 각각에서 상태→변화→다음 행동이 읽히고, 버튼이 작동하며, 필요한 기기·상태의 actual 캡처가 새 구현을 가리킨다. 캡처 불가 상태는 화면 ID·기기·이유를 남기고 완료 증거로 표시하지 않는다.

### 이번 실행 결과와 남은 게이트

- 4탭 읽기 폭을 `DS.Layout.rootContentMaxWidth` 760pt로 통일하고, Activity/Wellness 공통 히어로를 보통 글씨에서 가로, 접근성 큰 글씨에서 세로로 배치했다. Wellness 히어로 다음의 신체 기록 버튼과 기록이 없는 상태의 진입 버튼은 같은 입력 화면을 연다.
- `scripts/build-ios.sh --no-regen` 빌드와 `swift scripts/format-xcstrings.swift --check`, `python3 docs/design/theme-map/build-theme-map.py --check`, `git diff --check`가 통과했다. Wellness의 기록 진입 UI 테스트는 데이터 유무 2개 상태에서 모두 통과했다.
- 실제 화면 디자인맵의 영향 화면 12개를 새 앱 빌드로 다시 캡처했다: 일반 iPhone A01·H01(2/2), iPad T03·A01·H01·L01(4/4), Duo 접힘 A01·H01(2/2), Duo 펼침 T03·A01·H01·L01(4/4). 각 `capture-index.json`의 출처와 시각을 갱신하고 새 PNG 및 보드를 눈으로 확인했다. 이 12개에는 이전 PNG나 pending 표시가 남아 있지 않다.
- 첫 Duo 펼침 시뮬레이터에서는 테스트 실행기가 멈추고 재부팅 뒤 데이터 이전 오류가 났다. 해당 임시 기기를 제거하고 새 Duo를 펼침 상태로 부팅해 위 4개 캡처 테스트를 통과시켰다. Watch 화면은 이번 코드 변경 범위에 포함되지 않아 Watch UI 테스트와 전체 회귀 테스트는 실행하지 않았다.

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
