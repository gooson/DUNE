---
tags: [swiftui, activity, viewthatfits, dynamic-type, accessibility, numeric-truncation, xcuitest, native-capture]
category: testing
date: 2026-10-27
severity: important
related_files: [DUNE/Presentation/Activity/Components/WeeklyStatsGrid.swift, DUNE/Presentation/Activity/Components/PersonalRecordsSection.swift, DUNE/Presentation/Activity/ActivityView.swift, DUNEUITests/Visual/ActivityFlowUITests.swift]
related_solutions: [2026-10-25-today-reading-hierarchy]
---

# Solution: Activity 큰 글씨 지표 누락과 개인 기록 수치 잘림

## Problem

Activity Flow를 iPhone·iPad·Duo에 적용하면서 컴파일과 요소 존재 검사만으로 잡히지 않는 두 문제가 나타났다. 최대 접근성 글씨에서6개 지표 그룹이 사라졌고, 넓은 화면의 두 열 안에 개인 기록을 다시 두 열로 놓으니 큰 숫자가 말줄임표로 잘렸다. 준비도 이력은 펼쳐졌지만 상위 DisclosureGroup의 AXID가 자식 차트 식별자를 덮어 검사가 실패했다.

### Root Cause

ViewThatFits의 첫 후보 안에 `if !isAccessibilitySize`를 두면 AX에서 EmptyView가 유효한 작은 후보가 된다. fallback VStack까지 진행하지 않는다. 개인 기록의 숫자·단위·고정48pt sparkline을 한 줄에 넣은 것은 실제 카드 폭을 과대평가했다. 상위 접근성 컨트롤과 자식 그래프에 독립 식별자가 필요한 구조도 고려해야 했다.

## Solution

| File | Change | Reason |
|---|---|---|
| WeeklyStatsGrid.swift | ActivityMetricsLayout의 AX 분기를 ViewThatFits 밖으로 이동 | AX에서는 명시적인 VStack, 일반 크기만 적합한 HStack/VStack 선택 |
| PersonalRecordsSection.swift | 값은 전체 폭, 단위와 sparkline은 아래 줄, 링크 높이 최소44pt | 숫자를 읽을 공간과 기존 상세 동작을 함께 보존 |
| ActivityView.swift |44pt 이력 Button과 조건부 형제 WeeklyHeroTrendView | 버튼 상태·차트 AXID 독립 유지 |
| ActivityFlowUITests.swift | 최대 글씨 개인 기록 전체 프레임과5개 지표의 실제 크기/도달성 검사 | 존재만 확인하는 검사 보강 |

핵심 배치는 다음과 같다.

```swift
if dynamicTypeSize.isAccessibilitySize {
    VStack(alignment: .leading) { content() }
} else {
    ViewThatFits(in: .horizontal) {
        HStack { content() }
        VStack(alignment: .leading) { content() }
    }
}
```

최종 iPad PNG에서8개 값이 모두 보였고 iPhone 최대 글씨 숫자 프레임도 가용 viewport 안에 들어왔다. 최대 글씨 지표 기능 검사는 보고서 볼륨·시간·칼로리·근력/유산소 비율을 확인했다. 원본81개와 SHA256, 실행별 결과는 [실제 갤러리](../../design/full-redesign-map/review/activity-flow-2026-10-27/index.html)에 있다.

## Prevention

- 적응형 후보가 조건에 따라 EmptyView가 되는지 확인한다. 접근성 분기는 후보 밖에서 결정한다.
- 큰 수치는 값 자체의 전체 프레임과 가장 좁은 실제 카드 폭을 확인한다. 고정 폭 장식은 별도 줄로 둔다.
- 접근성 식별자는 상위 컨트롤과 자식 콘텐츠에서 서로 덮이지 않는지 실제 XCTest 조회로 확인한다.
- 기능 검사와 긴 사진 수집을 분리한다. 이번19장 전체 AX 수집은 본문 검사 뒤300초 teardown 제한으로 실패했다. 별도의 짧은 기능 검사 성공을 수집 실패의 통과로 바꾸지 않는다.
- 실측 드래그는 작은 거리·느린 속도·끝 hold를 사용해 관성으로 같은 위치를 오가는 수집을 막는다. 최대 보정 횟수를 둔다.
- 원래 실패 로그, 시도 제한, 명시적 재시도 허용을 보존한다. 전용 소유 실행기·유휴 시뮬레이터만 정리한다.
- 소스와 문서가 동결된 상태에서 자동 receipt를 만든다. 문서 변경으로 stale이 된 자동 증거를 수동 리뷰로 갱신하지 않는다.

새 전역 규칙은 추가하지 않는다. 기존 SwiftUI/테스트/실행기 규칙으로 방지할 수 있고 `.claude/**`는 source of truth로 보존한다. 반복 방지 지식은 이 검색 가능한 문서에 한정했다.

## Lessons Learned

컴파일·요소 존재·실제 가독성은 서로 다른 증거다. 두 열 화면의 카드 내부는 휴대폰보다 좁을 수 있다. 사진이 생성됐다는 사실과 테스트가 정상 종료됐다는 사실도 구분해야 한다. 단위·분모·누락 의미를 먼저 지키고 실제 숫자가 온전히 읽히는지를 확인한다.
