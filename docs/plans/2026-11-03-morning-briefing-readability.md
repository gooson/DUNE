---
topic: morning-briefing-readability
date: 2026-11-03
status: implemented
confidence: high
related_solutions:
  - ../solutions/testing/2026-11-02-morning-briefing-native-layout-and-compact-toolbar.md
---

# T09 아침 브리핑 읽기 비중 개선

## Context

사용자 제공 화면에서 일출 헤더와 카드의 장식 배너가 텍스트보다 큰 면적을 차지한다. 기존 분위기를 유지하면서 정보가 먼저 읽히도록 개선한다.

## Affected Files

| File | Change Type | Description |
|---|---|---|
| `DUNE/Presentation/Dashboard/MorningBriefingView.swift` | 수정 | 헤더 축소, 제목 옆 썸네일, 큰 제목·본문과 전체 읽기 폭 |
| `docs/design/layout-map/morning-briefing-proposal.md` | 수정 | 배치 계약 |
| `docs/design/theme-map/` | 수정 | 같은 표현의 시안·manifest·README 동기화 |
| `docs/design/phone-design-map/` | 수정 | 새 실제 캡처와 검증 범위 기록 |

## Implementation Steps

1. 레이아웃·테마 계약에 읽기 중심 배치를 기록한다. 단순 글씨 확대안보다 장식 면적도 함께 줄이는 안을 선택한다.
2. 205→140pt 헤더, 72×52pt 썸네일, title3.bold/body, 전체 폭 본문을 적용한다. 데이터·문구·조건·닫기·애니메이션은 유지한다.
3. 기존 T09 기본 글씨·어두운 최대 접근성 글씨 selector로 렌더링·스크롤·닫기를 검증하고 새 PNG를 확인한다. 영향 기기는 iPhone·iPad·Duo 접힘/펼침이며 Watch와 visionOS는 소비자가 아니다.

## Testing Strategy

선택 UI: `TodaySettingsRegressionTests/testMorningBriefingSectionsAndDismissal`, `TodaySettingsRegressionTests/testMorningBriefingAtDarkMaximumAccessibilitySize`. 표준 실행기·worktree 소유 기기·순차 실행·1200초 deadline을 사용한다. UI 실행에서 컴파일하면 별도 빌드는 반복하지 않는다. 새 로직이 없어 unit은 추가하지 않는다. 밝음/어두움·한국어·큰 글씨에서 본문 잘림과 읽기 폭을 새 캡처로 확인한다. 기기 또는 실행 환경이 막히면 미갱신 T09 범위를 명시하고 이전 PNG로 대체하지 않는다.

## Risks

| Case | Handling |
|---|---|
| 긴 번역·큰 글씨 | 제목·본문 무제한 자연 확장, AX 썸네일 숨김 |
| 날씨 없음 | 기존 nil 분기 유지 |
| 장식이 측정값으로 오인 | 기존 추상 능선과 원본 아이콘 유지 |
| 기존 dirty 카탈로그 | baseline으로 보존하고 자동 커밋에서 제외 |

## 사용자 후속 요청

2026-11-03 “시안부터”에 따라 앱 수정은 원복하고 UI 실행은 컴파일 중 중단했다(exit130, 테스트 미실행). 현재 산출물은 정보 강조·풍경 유지 두 시안이며 사용자 선택 전에는 구현·캡처를 재개하지 않는다.

## 선택 후 구현 계약

사용자가1번 정보 강조를 선택했다. 기존 간단 썸네일 구현안 대신 수면·HRV·운동 일수·평균을 구조화해 크게 표시한다. 관련 템플릿 단위 테스트에서 nil/0/부호/잘못된 실수/주간 완료를 검증한다. T04 HRV·RHR 카드 높이 보완도 같은 요청 범위에 추가한다. 초기 컴파일 중 사용자 중단은 실패 재시도 예산으로 세지 않는다. UI 검증은 한국어 정보 강조·최대 접근성 브리핑·이전 RHR 동등 높이 selector로 한정한다.

## 최종 검증

관련 단위33개와 iPhone 핵심 UI4개·iPad 관련2개가 통과했다. 최초 컨디션 제목2.667pt 차이는 아이콘 영역 보정 후 재검증했다. 새 실제 화면과 Duo 두 자세의 미갱신 범위는 `../design/full-redesign-map/review/briefing-condition-readability-2026-11-03/README.md`에 기록했다.
