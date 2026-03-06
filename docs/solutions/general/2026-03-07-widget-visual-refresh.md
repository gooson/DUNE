---
tags: [widget, widgetkit, layout, progress-ring, localization, ios-widget]
category: general
date: 2026-03-07
severity: important
related_files:
  - DUNEWidget/Views/WidgetScoreComponents.swift
  - DUNEWidget/Views/SmallWidgetView.swift
  - DUNEWidget/Views/MediumWidgetView.swift
  - DUNEWidget/Views/LargeWidgetView.swift
  - DUNEWidget/DesignSystem.swift
  - DUNE/project.yml
  - DUNE/Resources/Localizable.xcstrings
related_solutions:
  - docs/solutions/architecture/widget-extension-data-sharing.md
  - docs/solutions/general/hero-ring-label-consistency.md
---

# Solution: Widget Visual Refresh with Shared Ring Components

## Problem

기존 위젯은 점수는 표시했지만 텍스트와 도트 인디케이터 위주라 Medium의 3개 아이템 간격이 넓고, Large는 정보 밀도에 비해 빈 공간이 크게 느껴졌다. 앱 히어로 카드의 시각 언어와도 연결감이 약해 홈 화면에서의 첫 인상이 분산됐다.

### Symptoms

- Medium 위젯에서 3개 점수가 서로 멀리 떨어져 보여 빠른 비교가 어려움
- Large 위젯에서 상태 메시지 대비 빈 영역이 커서 정보 밀도가 낮아 보임
- 위젯과 앱 히어로 카드 사이에 링 기반 시각 일관성이 부족함
- widget target이 app string catalog를 공유하지 않아 일부 문자열이 번역 경로에 올라오지 않음

### Root Cause

- 각 widget family가 개별 텍스트 레이아웃으로 구현되어 공통 시각 구조가 없었음
- 점수 표현이 `숫자 + 라벨 + 도트`에 머물러 제한된 캔버스를 충분히 활용하지 못했음
- DUNEWidget target이 `Localizable.xcstrings`를 포함하지 않아 localization 적용 범위가 좁았음

## Solution

widget 전용 lightweight ring 컴포넌트와 metric 공통 모델을 추가하고, Small/Medium/Large가 같은 시각 언어를 공유하도록 재배치했다. 점수 누락 시에는 slot을 없애지 않고 placeholder footprint를 유지해 정렬 안정성도 확보했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNEWidget/Views/WidgetScoreComponents.swift` | CREATE | 공통 metric 모델, 링, compact/tile/row 컴포넌트 추가 |
| `DUNEWidget/Views/SmallWidgetView.swift` | MODIFY | 3개 미니 링 + 요약 라인 구조로 재배치 |
| `DUNEWidget/Views/MediumWidgetView.swift` | MODIFY | 3컬럼 미니 링 레이아웃으로 전환, spacing 축소 |
| `DUNEWidget/Views/LargeWidgetView.swift` | MODIFY | 왼쪽 링 + 오른쪽 상태/메시지 row 구조로 밀도 향상 |
| `DUNEWidget/DesignSystem.swift` | MODIFY | widget 전용 spacing, stroke, ring gradient 토큰 추가 |
| `DUNEWidget/Views/WidgetPlaceholderView.swift` | MODIFY | 새 시각 언어와 균형 맞도록 placeholder 정리 |
| `DUNE/project.yml` | MODIFY | DUNEWidget target에 `Localizable.xcstrings` 공유 |
| `DUNE/Resources/Localizable.xcstrings` | MODIFY | widget 신규/재사용 문자열 등록 |

### Key Code

```swift
struct WidgetMetric: Identifiable {
    let id: String
    let title: String
    let compactTitle: String
    let score: Int?
    let statusLabel: String
    let message: String?
    let color: Color
    let icon: String

    var progress: Double {
        Double(Swift.max(0, Swift.min(score ?? 0, 100))) / 100.0
    }
}

struct WidgetRingView: View {
    let metric: WidgetMetric
    let size: CGFloat
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle().stroke(WidgetDS.Color.ringTrack, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            Circle()
                .trim(from: 0, to: metric.progress)
                .stroke(
                    AngularGradient(
                        colors: WidgetDS.ringGradient(for: metric.tintColor),
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
    }
}
```

## Prevention

### Checklist Addition

- [ ] widget family 2개 이상이 같은 점수 정보를 쓰면 공통 component로 먼저 추출한다
- [ ] widget target에 새 사용자 대면 문자열을 추가할 때 `Localizable.xcstrings` target 포함 여부를 먼저 확인한다
- [ ] 점수 누락 상태는 slot 삭제보다 placeholder footprint 유지가 가능한지 먼저 검토한다

### Rule Addition (if applicable)

이번 변경은 기존 규칙 범위 안에서 해결되어 별도 rule 추가는 필요하지 않았다.

## Lessons Learned

- WidgetKit에서는 앱의 hero card를 그대로 복제하기보다, ring/spacing/typography hierarchy만 추려서 가져오는 편이 가독성과 일관성 균형이 좋다.
- Medium/Large의 “비어 보이는 문제”는 단순 padding 축소보다 공통 metric 구조를 만든 뒤 row/tile hierarchy를 재설계할 때 더 깔끔하게 해결된다.
- widget UI도 app string catalog를 공유하게 해두면 후속 텍스트 변경 시 localization 누락 리스크를 크게 줄일 수 있다.
