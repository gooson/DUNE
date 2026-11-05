---
tags: [swiftui, health-data-qa, foundation-models, ui-fixture, health-query, accessibility, sf-symbol]
category: testing
date: 2026-11-06
status: done
severity: important
related_files: [DUNE/Presentation/Dashboard/HealthDataQASheet.swift, DUNE/App/ContentView.swift, DUNEUITests/Full/DesignMapAdditionalRoutesTests.swift]
related_solutions:
  - docs/solutions/architecture/2026-03-09-health-data-qa-tool-calling.md
  - docs/solutions/testing/2026-11-04-native-settings-scroll-chrome-and-large-text.md
---

# Solution: Health Q&A의 표시 상태와 기록 조회를 분리해 검증

## Problem

### Symptoms

첫 native UI 실행에서 Q&A 내용은 보였지만 부모 컨테이너 식별자가 개요, 질문, 입력란, Send의 자식 식별자를 덮었다. 지원 불가 hero에서는 `sparkles.slash`가 렌더링되지 않아 아이콘 배지가 비었고, 밝은 카드의 Fallback answer 캡션은 너무 옅었다. Browse로 들어가는 `HealthQueryView`는 합성 UI 실행 중에도 별도의 production query router로 운동 기록을 자동 조회할 수 있었다.

### Root Cause

SwiftUI 부모에 둔 AX 식별자가 자식 요소의 식별자를 대체했다. 지원 불가 배지는 존재하지 않는 SF Symbol 이름에 의존했다. Q&A fixture는 답변 서비스만 제어하고 Browse가 여는 별도 HealthQuery 서비스는 격리하지 않았다.

## Solution

### Changes Made

| File | Change | Reason |
| --- | --- | --- |
| `HealthDataQASheet.swift` | 전송 후 소개 카드를 메시지 스크롤 안에 두고 실제 텍스트·버튼·입력 리프에 식별자를 둔다. `sparkles`와 `nosign`을 조합하고 fallback 캡션에 secondary 색을 쓴다. | MAX 답변 공간과 읽을 수 있는 두 상태를 확보한다. |
| `DesignMapAdditionalRoutesTests.swift` | 정확한 리프를 선택해 첫 fixture 답변, 키보드, Browse·복귀·Done을 확인한다. Q&A launch에만 기존 `--ui-health-query-fixture`를 추가한다. | 실제 이동 경로를 유지하면서 하위 기록 조회만 합성 데이터로 격리한다. |
| `ContentView.swift` | 기존 available/unavailable Q&A fixture는 `--uitesting`에서만 활성화된다. | production 답변 동작을 건드리지 않고 결과를 재현한다. |

### Key Code

```swift
configuration.additionalArguments.append("--ui-health-query-fixture")
configuration.additionalArguments.append(availableFixture
    ? "--ui-health-qa-available-fixture" : "--ui-health-qa-unavailable-fixture")
```

기존 지원 기기 설명과 첫 추천 질문, production query routing, 메시지 전송 및 Foundation Models 서비스 동작은 그대로다.

## Prevention

- [ ] UI selector는 실제 `Text`·`Button`·입력 리프에 둔다. ScrollView 자체를 조회할 때만 그 컨테이너 ID를 사용한다.
- [ ] SF Symbol 존재 여부와 실제 테마의 배지·보조 캡션을 native 화면에서 확인한다.
- [ ] fixture 화면이 다른 데이터 화면으로 이동하면 같은 launch에서 하위 서비스도 격리한다.

## Lessons Learned

결정적인 답변 fixture만으로 Browse 경로까지 결정적이 되지 않는다. 별도 query fixture는 실제 navigation contract를 유지하면서 테스트 데이터 경계를 닫았다. PNG와 AX 쌍은 소스 정적 리뷰가 놓친 빈 아이콘과 부모 ID 충돌을 드러냈다.

## Validation

T17의 서로 다른 5개 메서드·프로필 조합(iPhone·iPad·Duo 접힘·Duo 펼침 일반, Duo 접힘 MAX)이 선택 SDK와 독립 PNG/AX 리뷰를 통과했다. 첫 질문의 fixture 답변, 실제 소프트웨어 키보드, 지원 불가 설명·조합 아이콘, Browse·Done 복귀가 해당 범위에서 확인됐다. 마지막 하위 query fixture 플래그는 iPad 일반 실행에서 실제 컴파일·통과했고, 그 자식 화면에 합성 `Sample bench press`가 나타났다. 이전 phone/Duo 캡처를 새 플래그의 증거로 표기하지 않는다. 두 번째 입력 답변의 완료, 실제 모델 추론, Dark, 실기기, VoiceOver 순회, 전체 테스트와 PR·CI 완료는 주장하지 않는다. 해당 실제 디자인맵 행은 이 발행에서 갱신한다.

## Publication evidence

[T17 paired native PNG/AX and method provenance](../../design/full-redesign-map/review/t17-health-data-qa-native-2026-11-06/index.html) document the selected passing SDK methods and independent visual review. The scoped actual-map primary rows are published. This does not claim full CI or PR merge.
