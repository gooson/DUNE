---
topic: today-compact-layout-and-ring
date: 2026-10-26
category: plan
tags: [today, compact, ring, dynamic-type, design]
status: implemented-with-coverage-limits
direction: Compact selected by user
confidence: high
related_solutions:
  - ../solutions/general/hero-ring-label-consistency.md
  - ../solutions/general/2026-10-19-four-tab-hero-ring-parity.md
  - ../solutions/general/2026-10-22-contextual-first-fold-hero.md
  - ../solutions/general/2026-10-25-today-reading-hierarchy.md
related_brainstorms:
  - ../brainstorms/2026-03-14-hero-card-detail-unification.md
---

# Implementation Plan: Today Compact 적용과 링 안정화

## Context

사용자가 Today의 방향으로 **Compact**를 선택했다. 현재 Compact·Metrics·Editorial의 차이는 상단 컨디션 히어로 표현이며, 아래 진행·브리프·수면·스트레스·인사이트·고정 지표·활동/신체 기록·Q&A의 디자인과 상태 계약은 공통이다. 세 가지 완전히 다른 전체 화면을 만든 것은 아니다. Activity·Wellness·Life 개편은 이번 범위가 아니다.

비교 화면에서 Compact 링이 깨졌다. 브라우저 실제 측정상 328px 열에서 링이 86px로 축소됐지만 숫자와 CONDITION 라벨은 같은 방식으로 배치되지 않았다. 숫자 52의 중심은 원보다 약 9.6px 왼쪽이었다. 글씨 125%의 100은 약 82.7px 폭으로, 당시 링 안쪽 지름 약 66.5px를 넘었다. 이는 시안 자체의 배치 오류이며 실제 SwiftUI 앱에서 같은 원인이 발생했다고 단정하지 않는다.

초기 계획은 시안의 링을 바로잡고 선택·구현 기준을 확정하는 것이었다. 이후 사용자가 `/run`을 요청해 아래 SwiftUI 구현을 실행했다. 실제 결과는 [네이티브 갤러리](../design/full-redesign-map/review/today-compact-2026-10-26/index.html)와 [검토 기록](../reviews/2026-10-26-today-compact.md)에 구분해 남긴다.

## Requirements

### Functional

- Today에는 Compact를 적용한다. 하단 공통 구성을 포함한 전체 계약은 [Today 상태·배치 계약](../design/layout-map/today-case-matrix.md)을 따른다.
- 기존 DUNE/Desert Warm의 브라운·골드·능선·상태별 의미를 유지한다. 다른 탭의 링이나 테마 기본값을 바꾸지 않는다.
- 링 안에는 점수만 두고 정확히 중앙 정렬한다. CONDITION은 삭제하지 않고 카드 상단의 외부 레이블로 유지한다.
- 큰 글씨에서는 점수를 외부의 확장 가능한 텍스트로 표시하고 장식 링을 제거한다. 정보나 상세 진입을 잃지 않는다.
- 점수 0과 점수 없음은 다르게 취급한다. 0은 트랙+숫자 0, 점수 없음/기준선 수집 중은 기존 별도 상태다.
- 카드 전체와 상세 힌트는 같은 컨디션 상세로 연결한다. 추세의 현재 값과 링의 현재 점수는 같아야 한다.

### Non-functional

- 여백·그래프·원 지름을 글씨 배율과 함께 확대하지 않는다. 내용은 자연스럽게 줄바꿈하고 필요한 높이만 늘어난다.
- 화면을 좁혔다고 원만 축소하거나, 숫자를 `minimumScaleFactor`로 억지로 넣지 않는다.
- 아이콘–수치 간격은 4–6pt, 링–설명은 12pt, 카드 안쪽은 14–16pt를 기본으로 한다. 글씨 확대가 이 여백을 함께 키우지 않는다. 단위·수치의 가독성과 겹침 방지를 위한 최소 공간은 유지한다.
- HealthKit 조회·점수 계산·저장·핀 선택·시간대 분기 의미는 변경하지 않는다.
- 기본 사용자 흐름, 루트 NavigationStack 소유권, 접근성 식별자와 한 카드 한 목적지를 보존한다.

## Approach

### 링의 확정 배치 기준

| 항목 | 기준 |
|---|---|
| 전체 원 외경 | 104pt 고정, 가로·세로 동일 |
| 획 | 7pt, 프레임 안쪽에 포함 |
| 중심 경로 | 지름 97pt, 반지름 48.5pt |
| 내부 지름 | 90pt, 숫자 외곽이 이 원 안에 들어가야 함 |
| 숫자 | 기본 시안 36pt tabular 숫자, 원과 숫자 박스 중심 일치 |
| 레이블 | CONDITION을 카드 상단에 표시, 원 안에 긴 라벨을 같이 넣지 않음 |
| 일반 좁은 폭 | 104pt 원+12pt 간격+나머지 설명 폭. 설명이 줄바꿈하며 원을 축소하지 않음 |
| 큰 글씨/내용이 들어가지 않는 경우 | 외부 점수 텍스트·전체 폭 설명. 장식 링을 위에 새 행으로 쌓지 않음 |
| 0 | 진행 호 숨김. 둥근 cap이 작은 점으로 남지 않음 |
| 1–99 | 정상화된 0–100 길이의 호, 원 중심과 획은 점수와 무관하게 불변 |
| 100 | 한 바퀴 완료. 숫자 100을 포함해 내부 경계와 겹치지 않음 |

이 치수는 이번 디자인 제안이며 HIG의 의무 수치가 아니다. 원의 크기를 고정하는 대신 중요한 텍스트를 외부로 옮기는 기준은 [Apple의 Dynamic Type 안내](https://developer.apple.com/videos/play/wwdc2024/10074/)의 필수 콘텐츠 우선·레이아웃 전환 원칙을 참고한다.

### Native 구현 범위

`TabHeroScoreRing`은 Today·Activity·Wellness·Life 네 곳이 공유하는 124pt 기본 컴포넌트다. 전역 기본값을 104pt로 바꾸면 다른 탭까지 바뀐다. 이번에는 Today의 `CompactConditionRing`을 해당 feature에 두고, 기존 부모가 제공하던 테마 색과 점수를 전달한다. 두 원과 점수의 명시적인 기하를 사용하며 전역 링 API나 다른 탭의 호출부를 변경하지 않는다. 현재 legacy `ConditionHeroView`는 이번 Today의 실제 호출 경로가 아니므로 함께 수정하지 않는다.

기존 솔루션의 ‘링 의미 레이블 보존’은 유지하되, 이번 Compact에서는 CONDITION의 위치를 링 내부에서 같은 카드 상단으로 이동한다. 예전 4탭 공통 링 계약 전체를 소급 변경하지 않는다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|---|---|---|---|
| text-align만 수정 | 작고 빠름 | 86px 축소·125%/100점 넘침은 남음 | 제외 |
| 모든 글씨·링을 비례 축소 | 같은 모양 유지 | 사용자 글씨 설정과 가독성 훼손 | 제외 |
| 공유 링 기본값 변경 | 코드 변경 한 곳 | 다른 세 탭까지 배치 회귀 | 제외 |
| Today 전용 고정 기하+외부 레이블 | 범위 명확, 중앙 정렬과 큰 글씨 규칙 분리 | 작은 presentation View 추가 | 선택 |

## Affected Files

| File | Change Type | Description |
|---|---|---|
| `docs/design/theme-map/themes/assets/today-restart-fragment.html` | 시안 수정 | 링 중앙·104/7 기하·외부 CONDITION·0점 호 |
| `docs/design/theme-map/themes/assets/today-comparison-fragment.html` | 시안 수정 | 같은 Compact 수정. 나머지 두 안의 본문은 유지 |
| `docs/design/theme-map/themes/dune-today-restart.html`, `dune-today-comparison.html` | 재생성 | 수정된 시안 보존 |
| `docs/design/layout-map/today-restart-proposal.md`, `today-case-matrix.md` | 계약 | Compact 선택·링 기준·하단 공통 범위 |
| `DUNE/Presentation/Dashboard/Components/CompactConditionRing.swift` | 예정: 추가 | Today 전용 점수 링, 테마 색 입력, 접근성 의미 |
| `DUNE/Presentation/Dashboard/Components/DesertHorizonConditionHeroView.swift` | 예정: 수정 | Compact 상단, CONDITION 레이블, 외부 점수 전환 |
| `DUNE/Presentation/Dashboard/DashboardView.swift` | 예정: 수정 | Compact 전체 흐름 연결, 기존 분기·경로 유지 |
| `DUNE/Presentation/Dashboard/Components/RecoverySleepCard.swift`, `CumulativeStressCard.swift` | 예정: 수정 | Compact 하단의 낮은 카드·근거 펼침. 실제 소비자 범위 재확인 |
| `DUNE/Presentation/Dashboard/Components/TodayBriefCard.swift`, `DailyProgressRingCard.swift`, `SmartInsightsSection.swift` | 예정: 수정 | 공통 시안의 정보 밀도·실제 데이터 의미 유지 |
| `DUNE/Presentation/Dashboard/Components/TodayMetricCard.swift`, `TodayWorkoutHistoryRow.swift` | 예정: 추가 후보 | Today에만 적용하는 지표/운동 행. 공용 VitalCard 기본 스타일은 변경하지 않음 |
| `DUNEUITests/Smoke/DashboardSmokeTests.swift` | 예정: 보강 | 기존 상세 진입·추세 현재 값 회귀 방지 |
| `DUNEUITests/Visual/TodayReadingUITests.swift` | 예정: 보강 | 작은 폭/큰 글씨/0·100/방향 전환 캡처. 현재 경로 확인 완료, native 적용 때 수정 |
| 실제 디자인맵·테마 맵·새 캡처 인덱스 | 예정: 갱신 | 구현 후 영향받는 T03을 새로 캡처 |

## Implementation Steps

### Step 1: 시안·선택 확정

- **Files**: HTML 편집 원본·보존본·레이아웃/테마 맵.
- **Changes**: Compact 선택 기록, 잘못된 86px 축소 제거, 숫자 중앙/외부 레이블/0점 처리. 나머지 두 안은 비교 자료로 유지.
- **Verification**: 브라우저에서 원·숫자 중심, 숫자 외곽의 내부 원 포함, 0/100, 100/125/130/160/200% 전환을 확인.

### Step 2: Today 히어로만 먼저 구현

- **Files**: CompactConditionRing, DesertHorizonConditionHeroView.
- **Changes**: 104pt 외경/7pt 획, 점수만 중앙, 외부 레이블, 접근성 크기는 외부 점수. 상태/점수 접근성 읽기를 한 번 제공. `dashboard-hero-ring`, `dashboard-hero-condition`, `dashboard-hero-trend` 의미 보존.
- **Verification**: 0·1·52·99·100의 새 캡처, 원형/카드 포함 여부, 기존 컨디션 상세 진입·동일 현재 점수의 추세.

### Step 3: 하단의 공통 Compact 구성 적용

- **Files**: DashboardView와 Today components.
- **Changes**: 진행/브리프/수면/스트레스/인사이트/핀/운동·신체 지표/Q&A 전체를 선택한 시안과 대조. 빈 차트 자리를 없애고 히어로의 추세 부족 안내를 유지. 기존 종목별 운동 집계는 날짜와 거리/시간을 가진 행. shared component의 다른 소비자가 있으면 Today opt-in을 사용.
- **Verification**: [상태 계약](../design/layout-map/today-case-matrix.md)의 표시 조건·목적지·기록일을 항목별 대조. 데이터가 없으면 섹션/그래프를 빈 높이로 예약하지 않음.

### Step 4: 접근성·상태·네이티브 확인

- **Files**: 관련 Today UI tests와 새 실제 캡처.
- **Changes**: 실제 Dynamic Type 크기에서 레이아웃 전환. VoiceOver 중복 점수 제거. 밝음/어두움·한국어/영어/일본어·회전/새로고침·탭 바 safe area 확인.
- **Verification**: 소유 전용 시뮬레이터와 표준 실행기를 사용한다. `plan-ui-tests.py --base main` 판정 및 변경 symbol의 소비자를 확인하고 관련 TodayReading/DashboardSmoke를 선택한다. 전체 테스트는 명시 요청 없으면 실행하지 않는다. 브라우저 비율을 네이티브 Dynamic Type 통과로 대신하지 않는다.

## Edge Cases

| Case | Handling |
|---|---|
| 작은 폭에서 100점 | 링 104pt 유지, 3자리 숫자 포함 확인. 설명만 줄바꿈 |
| 125%에서 130% 경계 | 시안은 130%에서 외부 점수. native는 실제 접근성 분류와 사용 가능한 폭으로 판단 |
| 200%+긴 번역 | 원을 숨기고 큰 점수·설명을 전체 폭에 표시 |
| 점수 없음/부분 데이터 | 기존 기준선/대기/접근 안내. 가짜 0점 금지 |
| 0점 | 유효한 0 표시, 진행 cap 점은 숨김 |
| 100점 | 완료 원, 고정 중심/반지름, 현재 추세 값 일치 |
| theme 변경·Reduce Motion·Bold Text | 기존 색을 입력, 장식 움직임 정지, 숫자 획·내부 여유를 실제 캡처로 확인 |
| 핀 전부 해제·홀수 개 | 기존 그룹 복귀, 빈 반쪽 셀을 만들지 않음 |
| 새로고침·오래된 값 | 기존 데이터 유지, 측정 날짜와 업데이트 시간 분리 |
| 다른 탭 | 공유 링 기본값과 호출부 보존. Today 전용 변경이 전파되지 않는지 diff 확인 |

## Testing Strategy

- Unit tests: 점수 계산은 변경하지 않는다. View body를 그대로 재현하는 단위 테스트는 추가하지 않는다. 새 데이터 로직이 생기면 해당 로직에 한정해 작성한다.
- Browser: 링 중심 오차 0.5px 이내, 원 크기 불변, 숫자 외곽의 내부 원 포함, CONDITION 존재, 0 호 숨김, 100 호 정상화, 큰 글씨 외부 점수.
- Integration/UI: seeded 0/1/52/99/100, iPhone 대표 두 폭·iPad·Duo 영향 자세의 관련 상태만 확인. 기존 상세 진입/추세 테스트 재사용, 추가된 링 기하는 새 캡처와 프레임으로 확인.
- Manual: 원 안의 숫자 잉크 잘림·광택·실제 VoiceOver 읽기, 기본/최대 글씨 스크롤, 마지막 Q&A가 탭 바 아래에 가려지지 않는지 확인.

## Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| 공유 링 변경의 다른 탭 회귀 | 중간 | 높음 | Today 전용 View, 공유 기본값 유지 |
| 고정 원 안의 글씨 확대 | 높음 | 높음 | 외부 점수 전환, 축소로 해결하지 않음 |
| HTML 수정만으로 앱 해결로 오해 | 중간 | 높음 | 시안 수정/SwiftUI 계획/실제 캡처 상태를 분리 |
| 하단 공통=현재 앱과 동일로 오해 | 중간 | 중간 | 세 시안끼리 공통임을 명시. 현재 앱의 빈 차트·큰 운동 카드 등은 별도 구현 대상 |

## Confidence Assessment

- **Overall**: High for prototype root cause and direction; native completion is unverified.
- **Reasoning**: 실제 브라우저 수치와 현재 SwiftUI 소비자를 확인했다. 고정 링·외부 레이블로 실패 원인을 직접 제거하며 다른 세 탭은 범위에서 분리한다.

## 이번 계획 단계의 확인 결과

- 시안 링 기하58조합: 점수0/1/52/99/100, 두 폭, 기본/125%, 큰 글씨130/160/200%와 3개 언어에서 중심·내부 원 포함·호·외부 점수를 확인했다.
- 최종 간격 보완 후 두 비교 폭×글씨100/125/160%에서 링–설명12px·지표 수치 간격6px·가로 넘침 없음을 확인했다. Compact 상단 확인용 미리보기는 한 화면만 노출한다.
- 세 전체 시안 PNG와 보존 HTML을 새 내용으로 갱신하고 맵 동기화·문서 구조·JavaScript 구문을 검사했다.
- SwiftUI 소스 변경·앱 빌드·네이티브 UI 테스트·실제 디자인맵 캡처는 이번 계획 단계에서 실행하지 않았다.

## /run 실행 확정 (2026-10-26)

사용자가 시안 완료 후 `/run`을 명시하여 native 구현·검증·리뷰·문서화·PR 생성/머지를 승인했다. 동일 채팅에서 작성한 시안·계획 파일은 이번 작업의 선행 산출물로 함께 보존한다. 무관한 사용자 baseline 변경은 없다.

작업 소유: 히어로/전용 링, Today 전용 회복·스트레스·브리프/진행 카드, UI 테스트는 파일을 분리해 위임한다. parent는 DashboardView의 지표/운동 행 연결·표시 상태·문자열/카탈로그·빌드·단일 시뮬레이터 실행·캡처·커밋/배포를 통합한다. 공유 링과 VitalCard의 기존 기본값은 유지한다.

UI는 표준 실행기와 현재 worktree 소유 기기만 사용한다. TodayReading·DashboardSmoke 및 변경에 대응하는 Compact 검사를 우선하며 iPad/Duo는 영향 상태의 캡처를 순차 실행한다. 전체 UI suite는 별도 명시 요청이 없으므로 실행하지 않는다. 현재 변경과 무관한 실패를 수정하거나 같은 원인을 변화 없이 재시도하지 않는다.

## Work 검토로 확정한 데이터 표현

- 기존 Today 운동 데이터는 개별 세션 목록이 아니라 종목별 현재 일자 합계 또는 마지막 운동이다. 쿼리·집계·상세 목적지를 바꾸지 않는 이번 개편에서는 이 의미를 보존하고 `Exercise by Type` 제목, 최신 2종목과 나머지 전체 펼침을 제공한다. 브라우저 시안의 개별 2+5세션 표현을 네이티브 완료로 주장하지 않는다.
- 지표의 sparklineData는 현재 모두 빈 배열이다. 빈 차트를 없애고 값·실제 측정일을 함께 표시한다. 반복되는 추세 부족 문구를 모든 작은 카드에 더하지 않으며, 히어로의 실제 표본 부족 안내는 유지한다.
- 일반 큰 글씨 `.xxLarge`부터 지표·목표를 한 열로 바꾸고, 더 작은 화면에서는 150pt 최소 지표 폭을 확보할 수 없을 때 행을 세로로 전환한다.
