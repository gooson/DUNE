---
tags: [swiftui, today, pinned-metrics, list, dynamic-type, accessibility, selection-order]
category: general
date: 2026-11-06
status: done
severity: important
related_files: [DUNE/Presentation/Dashboard/Components/PinnedMetricsEditorView.swift, DUNEUITests/Full/TodaySettingsRegressionTests.swift, Shared/Resources/Localizable.xcstrings]
related_solutions:
  - docs/solutions/general/2026-10-26-today-compact-density-and-pin-hit-area.md
  - docs/solutions/testing/2026-11-04-native-settings-scroll-chrome-and-large-text.md
---

# Solution: 큰 글씨에서도 선택 순서를 보여주는 고정 지표 편집기

## Problem

### Symptoms

기존 편집기는 현재 선택한 지표의 순서를 한눈에 보여주지 않았고 여섯 개 제한도 눈에 잘 띄지 않았다. MAX에서 고정 폭 아이콘이나 한 줄 미리보기는 레이블을 밀어낼 수 있었다. 좁은 Duo의 native List를 스크롤하면 시트는 열린 채로 toolbar 버튼이 현재 AX 영역에서 사라지기도 했다.

### Root Cause

`workingSelection` 배열에 순서가 저장돼 있지만 별도 미리보기가 없었다. 첫 레이아웃은 큰 글씨에서 미리보기가 여러 줄로 감길 공간을 확보하지 않았다. Hero 컨테이너 식별자는 제목 리프를 가렸고 UI 검사는 List 위치와 관계없이 toolbar가 항상 보인다고 가정했다.

## Solution

### Changes Made

| File | Change | Reason |
| --- | --- | --- |
| `PinnedMetricsEditorView.swift` | “Top 6 Metrics” HeroCard와 `workingSelection.indices` 기반 `LazyVGrid`를 표시한다. MAX에서는 80–120pt adaptive 열과 아이콘의 최소 프레임을 쓴다. | 실제 선택 순서를 반영하고 여섯 아이콘을 카드 안에서 줄바꿈한다. |
| Same | native List 행, 원래 category SF Symbols, selected trait, 일곱째 disabled 상태, 여섯 개 footer, Cancel/Done을 유지한다. 제목 ID는 `Text`에 둔다. | 데이터 순서와 기존 조작을 유지하며 AX 선택을 명확히 한다. |
| `TodaySettingsRegressionTests.swift` | 초기 HRV/RHR, 여섯 선택, 비활성 BMI, Cancel 폐기, Done 저장·재열기와 MAX 미리보기를 확인한다. 정확한 toolbar 버튼이 안 보일 때만 List를 위로 되돌린다. 한국어 iPad에서는 제목·footer를 정확히 읽고 Cancel·복귀를 확인한다. | 다른 종료 경로 없이 실제 native control을 조작한다. |
| `Shared/Resources/Localizable.xcstrings` | `Top %lld Metrics`와 `Select up to %lld metrics shown at the top of Today.`에 en/ko/ja 수동 번역을 등록하고 기존 빈 `%@` 항목은 보존한다. | SwiftUI의 실제 `Int` 보간 키와 번역의 인자 타입을 맞춘다. |

### Key Code

```swift
ForEach(workingSelection.indices, id: \.self) { index in
    Image(systemName: workingSelection[index].iconName)
}
```

미리보기는 기존 순서 배열을 읽는다. `toggle`의 추가·제거와 `TodayPinnedMetricsStore.maxPinnedCount`(6) 제한은 그대로다.

## Prevention

- [ ] 순서 있는 선택 미리보기는 `Set`이나 예시 아이콘 대신 저장 배열에 직접 연결한다.
- [ ] MAX의 좁은 native List에서 여섯 아이콘과 일곱째 disabled 행을 함께 본다.
- [ ] 스크롤 후 정확한 Cancel/Done을 다시 드러내고 폐기 또는 저장 결과를 확인한다.
- [ ] 정수 보간은 기존 카탈로그의 `%@`를 추정하지 말고 실제 추출 키(`%lld`)를 확인한다. Lazy List footer는 존재 검증 전에 소유 List를 제한적으로 스크롤해 materialize한다.

## Lessons Learned

미리보기는 저장·선택 로직을 바꾸지 않고 순서를 설명할 수 있다. AX `exists`만으로 현재 List 위치에서 toolbar 버튼을 누를 수 있다고 말할 수 없다. 제한된 역방향 스크롤과 정확한 버튼 확인이 native 이동 경로를 지킨다. 한국어 검증은 보존된 `Top %@ Metrics` 항목이 아닌 실제 `Top %lld Metrics` 키를 번역해야 통과하며, 보이지 않는 Lazy List footer를 먼저 찾아야 했다.

## Validation

T18의 기본 5개 메서드·프로필 조합(iPhone·iPad·Duo 접힘·Duo 펼침 일반, Duo 접힘 MAX)이 선택 SDK와 독립 PNG/AX 리뷰를 통과했다. 접힘 MAX에서는 실제 여섯 미리보기 아이콘이 두 줄로 구분되고 제목·footer·disabled BMI가 보였다. 일반 실행은 Cancel 폐기와 Done 저장·재열기를 확인했다. 추가 한국어 iPad selector의 첫 실행은 제목 `주요 지표 6개`까지 통과한 뒤 Lazy List footer가 AX에 생성되기 전에 실패했다. 정확한 List에서 최대 8회 천천히 스크롤하고 한국어 footer 전체 문장을 확인하도록 수정한 첫 원인 기반 재시도는 SDK 1/1 통과했다. 부모가 새 PNG에서 제목과 footer를 확인했으며 독립 한국어 PNG/AX 리뷰도 통과했다. 이전 영어 캡처를 한국어 증거로 재분류하지 않는다. 앱 동작·선택 순서는 그대로다. 해당 실제 디자인맵 행은 이 발행에서 갱신한다. PR·CI 완료, Dark, 실기기, VoiceOver 순회, 전체 테스트는 주장하지 않는다.

## Publication evidence

[T18 paired native PNG/AX and method provenance](../../design/full-redesign-map/review/t18-pinned-metrics-editor-native-2026-11-06/index.html) document the selected passing SDK methods and independent visual review. The scoped actual-map primary rows are published. This does not claim full CI or PR merge.
