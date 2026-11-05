---
topic: h09-injury-history-redesign
date: 2026-11-05
status: approved
confidence: high
related_solutions:
  - architecture/2026-02-23-injury-ui-bilingual-radio-list-patterns
  - architecture/2026-02-20-injury-tracking-review-fixes
related_brainstorms:
  - 2026-02-23-injury-ui-improvements
---

# H09 부상 이력의 상태 아이콘·기록 위계

## Context

기준은 실제 병합된 `ca9a62460f541c5cabf7034491751beae6afb885`다. H08은 별도 브랜치에 실패·수정 기록을 보존한 상태이며 H09는 그 미병합 코드에 의존하지 않는다. 기존 부상 이력의 `Active`·`Recovered` 구분, 원래 심각도 심볼·날짜·기간·정렬·편집·회복·삭제·통계·H10 이동을 유지하면서 비슷한 목록의 아이콘과 읽기 위계를 통일한다.

원래 H09 파일 SHA는 `56ec6da2d758c21199fc6f0da02ebdf758659689b1ea286f439242c1f61bccec`다. 과거 날짜/기간 공통화 및 부상 UI 해결책, 완료된 이력 E2E TODO를 확인했다. 네 기존 H09 PNG는 화면 정체성 참고이며 현재 소스의 동일 조건 before로 계산하지 않는다.

## Requirements and Approach

- 두 상태 헤더는 기존 `bandage.fill`·`checkmark.circle`의 시스템 Label로 만든다. 명시적인 `DS.Color.textSecondary`를 사용한다.
- 행의 기존 심각도 아이콘은 title3과 ScaledMetric 폭을 쓰고 Light에서만 원래 색을 진하게 섞는다. Dark 상태색은 그대로 둔다. 부위 이름은 headline, 날짜는 읽을 수 있는 보조색으로 표시한다.
- 실제 기록값·측면·심각도·기간·날짜·Active 배지를 보존한다. MAX의 기존 세로 행 배치와 원래 목록 행동·AX ID·캐시·쿼리·내비게이션·삭제 확인을 유지한다. 새 의료 점수나 범주를 만들지 않는다.
- 기본 seed는 Active 한 건이므로 기존 DEBUG seeder에 `--uitesting`과 전용 opt-in 플래그가 함께 있을 때만 Recovered 예시 한 건을 더한다. 다른 테스트의 기본 seed와 실제 앱 저장을 바꾸지 않는다.
- 정상 글씨의 기존 History→Detail→Edit→Save 사례는 같은 opt-in 두 상태 목록을 먼저 캡처한다. MAX는 목록 자체만 확인하는 사례로 분리하며 H08 Form·키보드 경로에 의존하지 않는다.

## Affected Files

| 파일 | 변경 |
| --- | --- |
| `DUNE/Presentation/Injury/InjuryHistoryView.swift` | H09 헤더·행 전경과 글자 위계. 같은 파일의 H10 코드는 유지 |
| `DUNE/App/TestDataSeeder.swift` | DEBUG·UITest opt-in의 두 상태 예시 데이터 |
| `DUNEUITests/Full/WellnessRegressionTests.swift` | 기존 Edit 플로우의 명시적 H09 캡처, 목록만 확인하는 MAX 사례 |
| layout/theme 맵과 인덱스 | 별도 배치·정적 시안과 검증 상태 |
| 실제 디자인맵 H09 네 프로필·보조 갤러리 | 새 PNG/AX·실제 UID·소스·자세 연결 |
| 계획·해결책 문서 | 결과와 미검증 범위 |

## Implementation Steps

1. 배치·테마 시안을 저장하고 인덱스에서 연결한다. 같은 인덱스에 남은 H07/P06 대기 설명도 이미 병합된 실제 갤러리 상태로 맞춘다.
2. 한 H09 View의 좁은 변경을 적용하고 독립 Data/Security/Simplicity 검토를 재사용한다. fixture·UI 후보는 별도로 검토한 후 적용한다.
3. 전용 기기를 한 번에 한 대만 사용하며 표준 실행기로 아래 다섯 사례를 순차 확인한다. 첫 필요한 UI 실행의 App/UI 컴파일을 빌드 증거로 사용한다.
4. 상태별 실제 프레임·아이콘·대비와 H10/편집 복귀를 검토한다. H09 대표만 갱신하고 나머지 실제 맵 행·보드 타일은 보존한다. 기존 이미지를 새 검증으로 표시하지 않는다.
5. 리뷰·품질·해결·문서화를 마친 후 별도 PR을 만들고 정상 머지한다. 끝난 소유 기기·중복 SDK 원본만 보존 근거를 확인해 정리한다.

## Testing Strategy

- `DUNEUITests/WellnessRegressionTests/testInjuryHistoryRowOpensDetailAndEditForm`: 일반 iPhone·iPad·Duo 접힘·펼침 각각 한 번. 두 상태 목록과 기존 상세·편집·저장·복귀를 확인한다.
- 새 `testInjuryHistoryAtMaximumAccessibilityTextSize`: Duo 접힘 한 번. 같은 두 상태 fixture와 AXXXL에서 각 행 전체·기간·날짜·상태 아이콘을 실제 List/window 프레임 기반의 유한 스크롤로 확인한다. lazy List의 AX 행 개수를 모델의 기록 수로 해석하지 않는다.
- 총 **고유 5사례·4런**이다. 일반 기기는 DesignCapture, Duo는 DuoAudit와 기존 host observer를 사용하고 실제 0°/180° 및 활성 LCD를 전후 확인한다. 90°·회전·H08 Form 검사는 범위 밖이다.
- UI 실행 1200초, 외부 소유 프로세스 deadline 1250초, pipeline 1300초. jobs2/index OFF/병렬 검사 OFF와 기존 UI 캐시를 사용한다. 실패와 횟수를 보존하며 원인에 대응한 수정 후에만 한 번 재시도한다.
- iOS Presentation·DEBUG UI fixture 변경이다. 모델·계산·저장 로직이 없어 새 unit/full/smoke를 추가하지 않는다. Watch·Vision은 이 두 소스의 소비자가 아니다. 카탈로그 check/manual, 테마 맵 check, diff 검사는 유지한다.

## Risks and Unverified Scope

MAX에서는 두 행이 동시에 화면에 존재하지 않을 수 있다. 각 상태를 별도로 드러내고 전체 프레임을 캡처하며 합성한 한 장을 실제 화면으로 쓰지 않는다. 색만으로 상태를 구분하지 않는다. 기본 seed와 정상 앱의 동작은 opt-in 여부로 분리한다. 새 검증은 English·Light의 두 상태와 MAX에 한정하며 Dark·빈 목록·삭제·회복·통계 동작의 새 실행으로 확장하지 않는다. 기존 행동 코드는 정적 소비자 검토로 보존한다.
