---
topic: T09 morning briefing redesign
date: 2026-10-31
status: in-progress
confidence: medium
related_solutions:
  - docs/solutions/general/2026-03-14-morning-briefing-feature.md
related_brainstorms: []
---

# Implementation Plan: T09 아침 브리핑 재설계

> 이 정식 Plan 문서는 부모 감사에서 누락이 발견되어 **소스 구현 뒤에** 작성했다. `docs/design/layout-map/morning-briefing-proposal.md`와 보존 테마 시안·manifest·인덱스는 앱 코드보다 먼저 작성했다. 따라서 이 문서를 구현 전 승인 계획이나 당시 완료된 Plan 게이트의 증거로 소급하지 않는다. 남은 검증과 리뷰에 사용할 현재 범위 계약이다.

## Context and research

승인된 `.codex-checks/t09/reviewed-proposal.json`은 T09를 Today 카드 또는 아침 자동 표시로 여는 sheet로 정의한다. 아침의 일출 인상과 회복·가이드·주간·조건부 날씨 전부의 뚜렷한 시각 표현을 요청한다. 원본 `MorningBriefingView.swift`는 네 섹션을 `BriefingTemplateEngine.Sections`에서 받아 `InlineCard`로 표시하고, 날씨 제목과 메시지가 모두 있을 때만 네 번째 카드를 만든다. `DashboardViewModel.buildBriefingData()`가 이미 수집한 값으로 `MorningBriefingData`를 구성한다. `MorningBriefingViewModel`은 오늘 한 번 표시 조건과 `.onDisappear` 시 기록을 담당한다.

관련 해결 기록 [Morning Briefing Feature](../solutions/general/2026-03-14-morning-briefing-feature.md)는 새 HealthKit 조회 금지, 템플릿 기반 문구, `markBriefingShown()` 호출 시점, Reduce Motion 대응을 설명한다. 현재 재설계도 이를 보존한다. [T09 레이아웃 계약](../design/layout-map/morning-briefing-proposal.md)과 [보존 테마 시안](../design/theme-map/themes/dune-morning-briefing.html)은 구현 전에 동기화되었으며 예시 수치·문장은 앱 캡처가 아니다.

## Requirements

### Functional

- 원본 회복·가이드·주간·조건부 날씨 순서, 제목·메시지·추천 로직, `heart.text.clipboard`·`figure.run.circle`·`chart.bar.fill`·`cloud.sun.fill` 아이콘을 유지한다.
- 일출 히어로와 각 카드의 정적 그림을 더한다. 주간 그림은 측정값처럼 보이는 막대 없이 추상 능선을, 날씨 그림은 실제 조건을 주장하지 않는 구름을 사용한다.
- 기존 완료 버튼, 닫기와 `markBriefingShown()`, stagger 표시를 유지한다. 비활성 장면과 Reduce Motion에서는 남은 섹션을 즉시 표시한다.

### Non-functional

- DS 색·간격·카드 토큰만 사용하고 새 RGB·허구 수치·쿼리·권한·문구를 추가하지 않는다.
- iPhone·iPad·Duo 폭 및 큰 접근성 글씨에서 문장이 읽히고 제목 탐색이 가능해야 한다. 장식은 VoiceOver에서 숨긴다.
- 현재 `.claude/**` 설정과 다른 화면을 수정하지 않는다. `Localizable.xcstrings` 신규 키가 없더라도 최종 형식 검사를 수행한다.

## Approach

`MorningBriefingView` 안에 SwiftUI `Shape`, SF Symbols, DS 그라데이션으로 히어로와 각 카드의 장식을 구현한다. 본문은 기존 템플릿 문자열을 그대로 렌더링한다. 접근성 크기에는 카드 장식을 숨기고 히어로·섹션 제목을 header로 노출한다. 화면 최대 읽기 폭은 `DS.Layout.rootContentMaxWidth`로 제한한다.

| Alternative | Reason for decision |
|---|---|
| 새 이미지 자산 | 이 화면은 단순 곡선·빛·심벌로 충분하며 테마별 색 대응을 SwiftUI 토큰으로 유지할 수 있다. |
| 그래프형 주간 장식 | 실제 주간 측정값으로 오인될 수 있어 사용하지 않는다. |
| 날씨 상태별 새 계산·조회 | 현재 `weatherSnapshot` 조건과 원본 템플릿을 바꾸므로 범위에서 제외한다. |

## Affected files

| File | Work |
|---|---|
| `DUNE/Presentation/Dashboard/MorningBriefingView.swift` | T09 히어로·카드 장식·접근성·stagger 생명주기 |
| `DUNEUITests/Full/TodaySettingsRegressionTests.swift` | seeded 진입/완료·날씨 존재와 dark/max AX 대상 UI 테스트 |
| `docs/design/layout-map/morning-briefing-proposal.md`, `README.md`, `index.html` | T09 화면별 배치 계약 및 연결 |
| `docs/design/theme-map/themes/dune-morning-briefing.html`, `manifest.json`, `README.md`, `index.html` | 보존 시안·테마 맵 동기화 |
| `docs/design/phone-design-map/actual/**` | UI 실행 뒤 새 T09 캡처와 출처가 확보될 때만 갱신. 현재 미변경 |

## Steps and evidence

1. **Research and map**: 원본 뷰, ViewModel, 엔진, 데이터 조립, Today 진입·기존 UI selector 및 관련 해결 기록을 확인했다. 레이아웃 계약과 테마 보존본·manifest·인덱스를 앱 편집 전에 작성했다.
2. **Native source**: 히어로·네 장식·본문과 접근성 구조를 구현했다. 원본 값·문구·조건을 그대로 넘기는지 diff로 확인한다.
3. **Scoped source checks**: `xcrun swiftc -frontend -parse`로 뷰와 UI 테스트 구문, `git diff --check`, `python3 docs/design/theme-map/build-theme-map.py --check`, `swift -module-cache-path /private/tmp/t09-swift-module-cache scripts/format-xcstrings.swift --check --check-manual`을 확인했다. 이는 타입 검사·빌드·실행 통과를 의미하지 않는다.
4. **Pending execution**: 부모의 T06 소유 무거운 실행이 끝난 뒤 T09 전용 시뮬레이터에서 표준 실행기로 대상 UI selector를 순차 실행하고 실제 화면을 수집한다. 동일 증거를 다음 phase에 재사용한다.
5. **Pending review/closeout**: 최종 diff와 실행 receipt로 남은 reviewer 관점 및 실제 캡처 출처를 판정한다. 기존 T09 PNG는 새 구현의 근거로 재사용하지 않는다.

## Exact validation contract

| Changed behavior | Platform/state | Selector or evidence | Stop condition |
|---|---|---|---|
| 자동 브리핑 진입, 회복·가이드·주간·seeded 날씨, Done | iPhone normal | `TodaySettingsRegressionTests/testMorningBriefingSectionsAndDismissal` | 네 카드·닫기 동작 확인 또는 원인 기록 |
| 히어로·제목·본문 읽기 폭 | iPhone dark, maximum accessibility size | `TodaySettingsRegressionTests/testMorningBriefingAtDarkMaximumAccessibilitySize` | AX 제목과 카드 경계 확인 또는 원인 기록 |
| 실제 레이아웃 | iPhone regular, iPad, Duo folded/unfolded; 영향받는 밝음·어두움·큰 글씨 상태 | T09 새 PNG와 capture-index 및 육안 확인 | 새 출처와 화면 ID 연결 또는 미검증 기기·이유 기록 |
| 템플릿 값·추천 | 기존 로직 미변경 | 신규 unit selector 없음; source diff로 불변 확인 | 데이터 생성 diff가 없음을 확인 |

실행 selector의 전체 식별자는 `DUNEUITests/TodaySettingsRegressionTests/testMorningBriefingSectionsAndDismissal`과 `DUNEUITests/TodaySettingsRegressionTests/testMorningBriefingAtDarkMaximumAccessibilitySize`다. 새 Domain·ViewModel 분기를 만들지 않았으므로 unit selector는 없다.

UI 캡처에 필요하면 기존 opt-in `TodaySettingsRegressionTests/testVisualAuditMorningBriefing`을 같은 실행에서 사용한다. 로컬 전체 회귀는 요청되지 않았으므로 실행하지 않는다. worktree당 무거운 실행 하나, build jobs 2, index store off, 테스트 병렬 off를 유지한다. 표준 build/targeted UI deadline은 각각 900초/1200초이며 같은 구성의 UI 테스트가 컴파일에 성공하면 별도 build-only를 반복하지 않는다. 실패는 원인 대응 변경 후 최대 한 번만 재시도한다.

## Edge cases and risks

| Case/risk | Handling |
|---|---|
| 날씨 미수신 | 원본의 제목·메시지 nil 분기를 유지해 카드 미표시; 새 날씨 값을 만들지 않음 |
| 기록 부족 | 원본 템플릿 분기 유지; 점수·수면·추천을 장식에서 추정하지 않음 |
| 최대 글씨와 긴 번역 | 카드 그림 숨김, 세로 확장, 읽기 폭 제한, AX 제목 분리; 실제 기기 확인 대기 |
| Dark mode contrast | DS 동적 색과 원본 텍스트 스타일 사용; 실제 dark 캡처 확인 대기 |
| 상태처럼 보이는 장식 | 고정 막대와 추가 태양을 제거하고 주간 능선·날씨 구름을 사용함 |
| motion/offscreen | 기존 일회성 stagger 유지, Reduce Motion 즉시 표시, task 취소와 inactive scene 처리; 반복 애니메이션 없음 |
| 이전 실제 화면 이미지 | 새 실행 결과와 출처가 생기기 전에는 완료 캡처로 표시하지 않음 |

## Preliminary review and confidence

부모가 전달한 예비 source review는 2개 agent의 5개 관점과 SwiftUI·Apple UX·성능 확인을 포함했다. 이 과정의 P2 두 건(주간 막대/날씨 장식의 데이터 오인, 접근성 제목 부재)을 소스에서 수정했다. 이는 최종 reviewer 판정이나 네이티브 실행 통과가 아니다.

**Confidence: medium.** 데이터 경계와 정적 구문·맵 동기화는 확인했다. 타입 검사, 대상 UI 실행, iPad/Duo 실제 화면과 새 캡처는 남아 있다.
