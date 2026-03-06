---
tags: [widget, ios-widget, layout, readability, progress-ring, design]
date: 2026-03-07
category: brainstorm
status: draft
---

# Brainstorm: 위젯 가독성 강화 + 히어로 링 감성 정렬

## Problem Statement

현재 위젯은 점수 자체는 전달하지만, 각 아이템 사이 간격이 넓고 내부 여백이 커서 제한된 WidgetKit 캔버스를 충분히 활용하지 못한다. 특히 Medium은 3개 점수가 서로 멀리 떨어져 보여 한눈에 비교하기 어렵고, Large도 정보 밀도가 낮아 빈 공간이 크게 느껴진다.  
이번 개선의 핵심은 **점수를 더 빨리 읽게 하면서**, 앱의 히어로 카드가 주는 **링 기반 시각적 효과를 위젯에 이식**해 시선 유도와 브랜드 일관성을 동시에 강화하는 것이다.

## Target Users

- 홈 화면에서 오늘 상태를 빠르게 확인하려는 기존 DUNE 사용자
- 앱을 열기 전에 Condition / Readiness / Wellness를 한 번에 비교하려는 사용자
- 숫자만 보는 것보다 시각적 상태 표현을 통해 점수 차이를 빠르게 파악하고 싶은 사용자

## Success Criteria

1. 모든 위젯 사이즈에서 기존 대비 빈 공간이 줄고 콘텐츠 밀도가 높아진다.
2. 점수 3개를 이전보다 더 빠르게 비교할 수 있다.
3. 히어로 카드와 동일한 구현 복제는 아니더라도, 링 중심의 시각적 인상이 일관되게 느껴진다.
4. 점수가 비어 있는 경우에는 레이아웃 붕괴 대신 명시적 placeholder로 상태를 설명한다.
5. Large 위젯은 단순 확장이 아니라 정보 밀도와 시선 흐름이 개선된다.

## Proposed Approach

### Design Direction

- 현재의 `숫자 + 상태 텍스트 + 도트` 중심 구조에서 `링 + 숫자 + 상태` 중심 구조로 전환
- 히어로 카드의 **느낌만 동일하게** 가져오고, 위젯 제약에 맞게 더 단순화
- 컬럼 간 간격과 카드 내부 패딩을 줄여 실제 콘텐츠가 차지하는 비율 확대
- 숫자를 가장 먼저 읽게 하고, 상태 텍스트는 그 다음 레이어로 재배치
- 도트 인디케이터는 유지보다 축소/제거를 우선 검토

### Size-by-Size Layout Concept

#### Small

```text
┌─────────────┐
│    링+점수    │
│  59  67  71 │
│ Fair / Good │
│ placeholder │
└─────────────┘
```

- 3개를 모두 독립 카드로 나누기보다, 가장 작은 캔버스에서 읽기 우선 구조 채택
- 우선안 1: 가장 중요한 1개 대표 점수 + 나머지 2개 축약 표시
- 우선안 2: 3개 미니 링을 매우 촘촘하게 배치하되 상태 텍스트는 최소화
- 데이터 부족 시에는 억지 배치보다 `"Waiting for today's data"` 유형의 placeholder 우선

#### Medium

```text
┌───────────────────────────────┐
│   ○59      ○67      ○71       │
│ Condition Readiness Wellness  │
│   Fair   Moderate    Good     │
└───────────────────────────────┘
```

- 가장 직접적인 개선 대상
- 3개 컬럼은 유지하되, 각 컬럼을 `미니 링 + 중앙 점수 + 짧은 상태` 조합으로 재구성
- 타이틀은 작게, 숫자는 크게, 상태는 1줄로 정리
- 컬럼 간 spacing과 전체 horizontal padding을 줄여 카드 폭을 더 많이 사용
- 도트 인디케이터는 제거하거나 가장 약한 보조 요소로 내림

#### Large

```text
┌───────────────────────────────┐
│ Today                         │
│ ○59  Condition   Fair         │
│ ○67  Readiness   Moderate     │
│ ○71  Wellness    Good         │
│ Updated 8:30 AM / placeholder │
└───────────────────────────────┘
```

- 현재의 넓은 빈 공간을 줄이기 위해 `행(row) 밀도`를 높임
- 각 행에서 링을 왼쪽 anchor로 두고, 오른쪽에 상태/메시지를 붙이는 구조 검토
- 메시지는 1줄만 허용하고, 점수와 상태가 먼저 읽히도록 위계 조정
- 하단 업데이트 정보 또는 placeholder를 작게 배치해 빈 공간을 마감

### Ring Treatment

- 히어로 카드와 **완전히 동일한 구현**이 아니라, 아래 요소만 공통 언어로 맞춤
- 원형 track + progress arc
- 상태 컬러 기반 진행 링
- 중앙 score 숫자
- warm/desert 계열 gradient 느낌
- 위젯에서는 line width, size, gradient complexity를 단순화하여 legibility 우선

### Placeholder Strategy

- 점수가 일부 비어 있을 때는 억지로 균형을 맞추는 대신 placeholder slot 사용
- 예시:
  - `"No score yet"`
  - `"Open DUNE to refresh"`
  - `"Calibrating"`
- 3칸 구조가 필요한 Medium에서는 missing item도 같은 footprint를 유지해 정렬 안정성 확보
- Large에서는 행 단위 placeholder로 정보 누락 사유를 직접 설명 가능

## Constraints

### Technical Constraints

- WidgetKit은 공간이 매우 제한적이므로 hero card 수준의 디테일을 그대로 이식하기 어렵다.
- 위젯은 animation, gradient, typography 복잡도가 올라갈수록 오히려 판독성이 떨어질 수 있다.
- Widget target은 app theme/environment 의존성이 제한적이므로 링 구현은 widget-safe subset으로 옮겨야 한다.
- 점수 누락 상태를 처리할 때도 레이아웃 안정성이 유지되어야 한다.

### Product Constraints

- 목적은 “예쁘게 보이기”보다 “홈 화면에서 더 빨리 읽히기”가 우선이다.
- 모든 사이즈를 동시에 개선해야 하므로 Small/Medium/Large 간 시각 언어는 통일되어야 한다.
- 링은 시각 효과를 강화하지만, 텍스트 정보가 밀리면 안 된다.

## Edge Cases

1. 3개 점수 중 1개 또는 2개만 있을 때도 정렬이 어색하지 않아야 한다.
2. 낮은 점수(warning/tired)에서 어두운 배경 대비가 충분해야 한다.
3. 긴 상태 라벨(`Moderate`, `Readiness`)이 Small/Medium에서 잘리지 않도록 축약 규칙이 필요할 수 있다.
4. Large에서 narrative message가 너무 길면 점수 가독성을 해치므로 1줄 고정이 안전하다.
5. placeholder가 여러 개 동시에 보일 때도 “오류처럼” 보이지 않고 의도된 비어 있음으로 읽혀야 한다.

## Scope

### MVP (Must-have)

- Small / Medium / Large 전체 레이아웃 재조정
- 내부 padding 및 item spacing 축소
- 링 기반 시각 요소 도입
- 상태 정보 포함한 전면 재배치 허용
- missing score placeholder 설계 반영
- Large 빈 공간 감소

### Nice-to-have (Future)

- 점수 우선순위 기반 Small adaptive layout
- 상태 길이에 따른 약어/축약 규칙
- 링 내부/주변 subtle glow
- Large에서 trend 또는 delta 보조 정보 추가

## Open Questions

1. Small에서 3개를 모두 동등하게 노출할지, 대표 점수 중심으로 재구성할지 결정 필요
2. 도트 인디케이터를 완전히 제거할지, Large에서만 보조 정보로 남길지 결정 필요
3. 링 구현을 기존 `ProgressRingView` 축소 재사용으로 갈지, widget 전용 lightweight ring으로 분리할지 판단 필요

## Next Steps

- [ ] `/plan widget-visual-refresh`로 구현 계획 구체화
- [ ] Medium 우선 시안으로 spacing, ring size, typography hierarchy 결정
- [ ] Small/Large에 동일한 시각 언어로 확장
- [ ] placeholder 문구와 localization 범위 확정
