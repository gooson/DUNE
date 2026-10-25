---
tags: [swiftui, today, compact, dynamic-type, ring, hit-testing, ui-seed, xcresult]
category: general
date: 2026-10-26
severity: important
related_files:
  - DUNE/Presentation/Dashboard/Components/CompactConditionRing.swift
  - DUNE/Presentation/Dashboard/Components/TodayMetricCard.swift
  - DUNE/Presentation/Dashboard/Components/PinnedMetricsEditorView.swift
  - DUNE/Presentation/Dashboard/DashboardView.swift
  - DUNEUITests/Visual/TodayCompactUITests.swift
related_solutions:
  - 2026-10-25-today-reading-hierarchy.md
  - 2026-10-19-four-tab-hero-ring-parity.md
---

# Solution: Today의 장식 크기·정보 밀도와 고정 편집 터치 분리

## Problem

Today에서 글씨 크기에 따라 그래프·패딩·게이지가 함께 커지고, 빈 그래프 자리와 중첩 카드가 반복돼 정보보다 여백이 크게 보였다. 기존 DUNE 테마를 유지하면서 Compact로 다시 설계해야 했다.

### Symptoms

- 시안에서는 링만86px로 축소돼100점 숫자와 내부 라벨이 원을 벗어났다.
- 수면 차트와 스트레스 게이지가 Dynamic Type과 함께 커지고 지표마다 빈 점선 영역이 남았다.
- 고정 지표를 세 개로 만드는 UI 검사에서 수면 행 tap 후에도 두 개만 저장됐다.

### Root Cause

장식 기하와 읽을 텍스트의 크기 정책을 같은 확대 규칙으로 처리했다. 수치·날짜·설명을 읽는 데 필요한 높이와 장식용 예약 높이도 분리되지 않았다. 공용 컴포넌트의 기본값을 변경하면 다른 세 탭까지 영향을 받기 때문에 Today에 한정한 표현이 필요했다.

고정 편집은 별도 원인이었다. 운영 fallback은3개지만 UI seed는 `configureTodayDefaults()`에서 HRV/RHR2개를 명시한다. 이를 처음에 혼동했다. 실제 화면 녹화로 확인하니 `.buttonStyle(.plain)` label의 투명 Spacer 가운데 tap이 선택 동작을 만들지 않았다. 실제 선택 상태를 확인하기 전에 저장하고 카드 폭만 비교한 검사가 잘못된 원인 추정을 키웠다.

## Solution

### Changes Made

| File | Change | Reason |
|---|---|---|
| CompactConditionRing | Today 전용104pt·획7pt, 중앙 점수,0호 숨김/100원형 | 점수와 폭에 무관한 기하 |
| DesertHorizonConditionHeroView | 외부 CONDITION, 접근성 글씨에서 링 제거·외부 점수·제목/상세 세로 배치, 낮은 플롯 | 텍스트는 자연 확장하고 장식은 고정 |
| TodayMetricCard / DashboardView | 패딩14pt, 실제 날짜·값, 빈 차트 제거, 최대2열/큰 글씨1열, singleton 전체 폭 직접 표시 | 빈 영역과 중첩 chrome 제거 |
| RecoverySleep / CumulativeStress / DailyProgress | 낮은 차트·점수/막대·좁은 폭 전환 | 실제 데이터와 조작을 가깝게 배치 |
| PinnedMetricsEditorView | 전체 폭·최소44pt·contentShape, 선택 접근성 trait | 행 가운데도 실제 선택 가능 |
| TodayCompactUITests | 실제 seed2개 확인 → 수면 tap → selected 확인 → Done → pinned grid에서3개/전체 폭 확인 | 실패 지점을 관찰하고 잘못된 성공 방지 |

### Key Code

```swift
HStack {
    // icon, label, spacer, selected indicator
}
.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
.contentShape(Rectangle())
```

최소 높이는 하한이며 큰 글씨의 자연 높이를 제한하지 않는다. Button에는 실제 선택 상태에 따라 `.isSelected` trait을 추가한다. 테스트는 `selected == true`를 기다린 뒤 저장한다.

```swift
if row.count == 1 {
    metricCard(for: row[0])
} else {
    ViewThatFits(in: .horizontal) { /* paired / vertical fallback */ }
}
```

singleton의 layout path를 명확히 해 빈 반쪽과 ViewThatFits의 intrinsic proposal 모호성을 제거한다. 공용 TabHeroScoreRing/VitalCard는 변경하지 않는다.

## Prevention

- 먼저 해당 test base/seed가 실제 저장하는 값을 읽는다. 운영 fallback이나 이전 화면의 핀 개수를 추정하지 않는다.
- tap 직후 선택·펼침 등 실제 상태를 확인하고 다음 행동으로 넘어간다. 버튼 존재·tap 호출 자체는 상태 변경 증거가 아니다.
- plain Button에 Spacer가 있으면 label 전체 폭의 contentShape와44pt 이상 터치 영역을 확인한다.
- 같은 UI 실패를 가정만 바꿔 재실행하지 않는다. AX·실제 PNG·실패 전후 영상으로 어디서 상태가 바뀌지 않았는지 먼저 격리한다. 저장소 재시도 한도를 phase/turn 전환으로 초기화하지 않는다.
- 글씨가 커져야 하는 값·본문·범례와 고정해야 하는 링·플롯·패딩을 각각 설계한다. 텍스트를 강제 축소해 장식 안에 맞추지 않는다.
- Xcode가 과거 xcresult를 정리하기 전에 성공/실패 receipt와 원본 PNG를 즉시 보존한다. 자동 수집기가 동반 화면을 덮어썼는지 screen ID별로 대조한다.

### Checklist Addition

- [ ] 일반/최대 글씨·0/1/99/100점·단일/복수 표본을 구분했는가?
- [ ] 지표의 상대 날짜와 실제 측정 날짜·시간, 누락과 관측0을 보존했는가?
- [ ] 고정 편집에서 행 중앙 tap과 저장 후 실제 grid를 확인했는가?
- [ ] 프로토타입·native seeded capture·미검증 상태가 분명한가?

### Rule Addition

기존 디자인·접근성·테스트 규칙으로 포괄된다. 새 `.claude/rules` 파일은 추가하지 않고 `docs/corrections-active.md`에 seed/선택 확인 교정만 남긴다. `.claude/**` 원본은 수정하지 않는다.

## Lessons Learned

테스트가 같은 줄에서 실패해도 원인은 fixture, hit-testing, 실제 배치로 나뉠 수 있다. 화면의 이전 상태와 다음 상태를 직접 관찰하면 기대값을 완화하지 않고 제품 문제를 고칠 수 있다. 글씨 확대에 필요한 공간과 장식의 공간도 구분해야 정보 밀도와 접근성을 함께 유지한다.

검증 결과와 범위·기존 별도 실패·Duo 내부 가로의 제한은 [검토 기록](../../reviews/2026-10-26-today-compact.md)에 보존한다. 기본 글씨 캡처를 모든 상태의 성공으로 승격하지 않는다.

자동 검사가 통과한 뒤 원본 육안 검토에서 최대 글씨의 영문 CONDITION 중간 줄바꿈을 추가 발견했다. 접근성 크기의 제목/상세 안내를 세로로 전환하고 해당 selector만 다시 실행해1/1 통과와 새 원본을 확인했다. 요소 존재·경로 검사와 시각적 품질 검토를 서로 대체하지 않는다.
